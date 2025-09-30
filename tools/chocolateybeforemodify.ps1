$ErrorActionPreference = 'Stop'

# Dot-source the shared cleanup so it runs on both upgrade and uninstall
$helpers = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) 'includes\legacy-cleanup.ps1'
if (Test-Path -LiteralPath $helpers) { . $helpers }
Invoke-LegacyCleanup -PackageName $env:ChocolateyPackageName
