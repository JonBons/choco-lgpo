# chocolateyinstall.ps1
$ErrorActionPreference = 'Stop'

# Always work inside the package's tools directory; Chocolatey will create shims automatically.
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# Source archive (update as versions change)
# If the package is truly architecture-agnostic, you can point both url and url64bit to the same file and reuse the checksum.
# Replace these with the current, verified values when updating the package.
$url      = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'
$checksum = 'CB7159D134A0A1E7B1ED2ADA9A3CE8CE8F4DE391D14403D55438AF824247CC55' # sha256 of LGPO.zip

$packageArgs = @{
  packageName    = $env:ChocolateyPackageName
  unzipLocation  = $toolsDir
  url            = $url
  checksum       = $checksum
  checksumType   = 'sha256'
  # If you ever have a different 64-bit asset, populate these:
  # url64bit     = 'https://.../LGPO-x64.zip'
  # checksum64   = '<sha256>'
  # checksumType64 = 'sha256'
}

Install-ChocolateyZipPackage @packageArgs

# Normalize LGPO.exe into the tools root so Chocolatey creates a shim (no PATH edits needed).
$targetExe = Join-Path $toolsDir 'LGPO.exe'

if (-not (Test-Path -LiteralPath $targetExe)) {
    $candidate = Get-ChildItem -Path $toolsDir -Recurse -Filter 'LGPO.exe' -File | Select-Object -First 1
    if ($null -ne $candidate) {
        # Ensure any existing file is replaced cleanly
        if (Test-Path -LiteralPath $targetExe) { Remove-Item -LiteralPath $targetExe -ErrorAction SilentlyContinue -Force }
        Move-Item -LiteralPath $candidate.FullName -Destination $targetExe
    }
    else {
        throw 'LGPO.exe was not found after extraction. Verify the archive layout and URL.'
    }
}

# Handle legacy migration.
$helpers = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'includes\legacy-cleanup.ps1'
if (Test-Path -LiteralPath $helpers) { . $helpers }
Invoke-LegacyCleanup -PackageName $env:ChocolateyPackageName

# DO NOT add to PATH. Chocolatey generates a shim for any exe under tools (unless .ignore is present).
# Users will be able to run `lgpo` directly via the Chocolatey shim located under %ChocolateyInstall%\bin.
