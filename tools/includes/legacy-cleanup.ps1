$ErrorActionPreference = 'Stop'

function Remove-PathEntry {
    param(
        [Parameter(Mandatory=$true)][string] $PathToRemove,
        [Parameter(Mandatory=$true)][System.EnvironmentVariableTarget] $Scope
    )
    Update-SessionEnvironment
    $current = Get-EnvironmentVariable -Name 'Path' -Scope $Scope -PreserveVariables
    if ([string]::IsNullOrWhiteSpace($current)) { return }

    $needle = ($PathToRemove.TrimEnd('\')).ToLower()
    if ($current.ToLower().IndexOf($needle) -lt 0) { return }

    $quoted   = '"' + ($PathToRemove.TrimEnd('\')) + '"'
    $patterns = @(
        "(?i)(^|;)" + [Regex]::Escape($PathToRemove) + "(;|$)",
        "(?i)(^|;)" + [Regex]::Escape($PathToRemove.TrimEnd('\')) + "(;|$)",
        "(?i)(^|;)" + [Regex]::Escape($quoted) + "(;|$)"
    )

    $newPath = $current
    foreach ($p in $patterns) {
        $newPath = [Regex]::Replace($newPath, $p, {
            param($m)
            if ($m.Groups[1].Value -eq ';' -and $m.Groups[2].Value -eq ';') { ';' }
            else { $m.Groups[1].Value + $m.Groups[2].Value }
        })
    }
    $newPath = $newPath -replace ';{2,}', ';'
    $newPath = $newPath.Trim(';')

    if ($newPath -ne $current) {
        if ($Scope -eq [System.EnvironmentVariableTarget]::Machine -and -not (Test-ProcessAdminRights)) {
            Write-Warning "Legacy PATH entry found but cannot remove Machine-scope entry without elevation."
            return
        }
        Set-EnvironmentVariable -Name 'Path' -Value $newPath -Scope $Scope
        $env:PATH = $newPath
        Write-Verbose "Removed legacy PATH entry '$PathToRemove' from $Scope."
    }
}

function Remove-EmptyDir {
    param([Parameter(Mandatory=$true)][string]$Dir)
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return }
    if (-not (Get-ChildItem -LiteralPath $Dir -Force -ErrorAction SilentlyContinue)) {
        Remove-Item -LiteralPath $Dir -Force -ErrorAction SilentlyContinue
        Write-Verbose "Removed empty directory: $Dir"
    }
}

function Test-IsSafeLegacyPath {
    param([Parameter(Mandatory=$true)][string]$Path, [Parameter(Mandatory=$true)][string]$PackageName)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    if (-not ${env:ProgramFiles(x86)}) { return $false } # 32-bit OS or env missing

    $pf86 = [IO.Path]::GetFullPath(${env:ProgramFiles(x86)})
    $full = [IO.Path]::GetFullPath($Path)
    if ($full.StartsWith($pf86, [StringComparison]::OrdinalIgnoreCase) -eq $false) { return $false }

    $leaf        = Split-Path -Leaf $full
    $parent      = Split-Path -Parent $full
    $parentLeaf  = if ($parent) { Split-Path -Leaf $parent } else { '' }
    $grandParent = if ($parent) { Split-Path -Parent $parent } else { $null }
    $grandLeaf   = if ($grandParent) { Split-Path -Leaf $grandParent } else { '' }

    return ($leaf -ieq 'Tools' -and $parentLeaf -ieq 'Local_Script' -and $grandLeaf -ieq $PackageName)
}

function Invoke-LegacyCleanup {
    param([Parameter(Mandatory=$true)][string]$PackageName)

    # Resolve legacy path
    $legacyPath = $null
    try {
        if (${env:ProgramFiles(x86)}) {
            $legacyPath = Join-Path ${env:ProgramFiles(x86)} "$PackageName\Local_Script\Tools"
        }
    } catch { $legacyPath = $null }

    if (-not $legacyPath) {
        Write-Verbose "Legacy path not found, skipping cleanup"
        return 
    }

    # Remove PATH entries (both scopes) if present
    Remove-PathEntry -PathToRemove $legacyPath -Scope ([System.EnvironmentVariableTarget]::Machine)
    Remove-PathEntry -PathToRemove $legacyPath -Scope ([System.EnvironmentVariableTarget]::User)

    # Optional: remove legacy files/folders
    if (-not (Test-IsSafeLegacyPath -Path $legacyPath -PackageName $PackageName)) { return }

    if (-not (Test-ProcessAdminRights)) {
        Write-Verbose "Skipping legacy directory deletion without elevation: $legacyPath"
        return
    }

    try {
        if (Test-Path -LiteralPath $legacyPath -PathType Container) {
            # Remove our known portable payload
            $lgpoExe  = Join-Path $legacyPath 'LGPO.exe'
            $lgpo30   = Join-Path $legacyPath 'LGPO_30'

            if (Test-Path -LiteralPath $lgpoExe -PathType Leaf) {
                try { [IO.File]::SetAttributes($lgpoExe, 'Normal') } catch { }
                Remove-Item -LiteralPath $lgpoExe -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed legacy file: $lgpoExe"
            }

            if (Test-Path -LiteralPath $lgpo30 -PathType Container) {
                try {
                    Get-ChildItem -LiteralPath $lgpo30 -Recurse -Force -ErrorAction SilentlyContinue |
                        ForEach-Object { try { [IO.File]::SetAttributes($_.FullName, 'Normal') } catch { } }
                } catch { }
                Remove-Item -LiteralPath $lgpo30 -Recurse -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed legacy directory: $lgpo30"
            }

            # Remove empty dirs upward
            Remove-EmptyDir -Dir $legacyPath
            $localScriptDir = Split-Path -Parent $legacyPath
            Remove-EmptyDir -Dir $localScriptDir
            $pkgRoot = Split-Path -Parent $localScriptDir
            Remove-EmptyDir -Dir $pkgRoot
        }
    } catch {
        Write-Verbose "Legacy directory cleanup skipped: $($_.Exception.Message)"
    }
}
