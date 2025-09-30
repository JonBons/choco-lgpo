# chocolateyuninstall.ps1
$ErrorActionPreference = 'Stop'

# Tools directory for this package (Chocolatey manages removal of files here automatically).
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# --- No-op for current versions ---
# With the new install script:
# - Files live under $toolsDir
# - Chocolatey created a shim for LGPO.exe under %ChocolateyInstall%\bin
# Chocolatey removes these during uninstall, so nothing else is required.

# --- Migration cleanup for legacy installs (pre-change) ---
# If older versions added a Program Files (x86)\<pkg>\Local_Script\Tools path to PATH, remove it.
try {
    $legacyPath = Join-Path ${env:ProgramFiles(x86)} "$($env:ChocolateyPackageName)\Local_Script\Tools"
} catch {
    # On 32-bit OS or if ProgramFiles(x86) is not present, skip.
    $legacyPath = $null
}

function Remove-PathEntry {
    param(
        [Parameter(Mandatory)]
        [string] $PathToRemove,
        [Parameter(Mandatory)]
        [System.EnvironmentVariableTarget] $Scope
    )

    # Normalize comparison (handle quoted/unquoted and trailing slash variants).
    $norm = [Regex]::Escape(($PathToRemove.TrimEnd('\')).ToLower())

    # Refresh current process env
    Update-SessionEnvironment

    $current = Get-EnvironmentVariable -Name 'Path' -Scope $Scope -PreserveVariables
    if ([string]::IsNullOrWhiteSpace($current)) { return }

    $currentCompare = $current.ToLower()

    if ($currentCompare -notmatch $norm) { return }

    # Build a regex that strips: ;<path>;  "<path>";  at ends, and collapses ;; -> ;
    $quoted   = '"' + ($PathToRemove.TrimEnd('\')) + '"'
    $patterns = @(
        "(?i)(^|;)" + [Regex]::Escape($PathToRemove) + "(;|$)",
        "(?i)(^|;)" + [Regex]::Escape($PathToRemove.TrimEnd('\')) + "(;|$)",
        "(?i)(^|;)" + [Regex]::Escape($quoted) + "(;|$)"
    )

    $newPath = $current
    foreach ($p in $patterns) {
        $newPath = [Regex]::Replace($newPath, $p, { param($m) if ($m.Groups[1].Value -eq ';' -and $m.Groups[2].Value -eq ';') { ';' } else { $m.Groups[1].Value + $m.Groups[2].Value } })
    }
    # Tidy up any accidental double semicolons or leading/trailing semicolons
    $newPath = $newPath -replace ';{2,}', ';'
    $newPath = $newPath.Trim(';')

    if ($newPath -ne $current) {
        if ($Scope -eq [System.EnvironmentVariableTarget]::Machine -and -not (Test-ProcessAdminRights)) {
            Write-Warning "Found legacy PATH entry but cannot remove it at Machine scope without elevation."
            return
        }
        Set-EnvironmentVariable -Name 'Path' -Value $newPath -Scope $Scope
        # Update current process PATH so subsequent steps in the same session reflect the change
        $env:PATH = $newPath
        Write-Verbose "Removed legacy PATH entry '$PathToRemove' from $Scope scope."
    }
}

if ($legacyPath) {
    # Attempt removal at both scopes; only removes if present.
    Remove-PathEntry -PathToRemove $legacyPath -Scope ([System.EnvironmentVariableTarget]::Machine)
    Remove-PathEntry -PathToRemove $legacyPath -Scope ([System.EnvironmentVariableTarget]::User)
}

# Nothing else to do. Do not attempt to remove shims; Chocolatey manages them.
