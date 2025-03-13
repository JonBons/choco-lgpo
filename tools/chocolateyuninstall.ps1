$toolsDir = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
if (!(Test-Path function:\Uninstall-ChocolateyPath)) {
  function Uninstall-ChocolateyPath {
    param(
      [string]$pathToRemove,
      [System.EnvironmentVariableTarget] $pathType = [System.EnvironmentVariableTarget]::User
    )

    Write-Debug "Running 'Uninstall-ChocolateyPath' with pathToRemove: `'$pathToRemove`'"

    # get the PATH variable
    Update-SessionEnvironment
    $envPath = $env:PATH
    if ($envPath.ToLower().Contains($pathToRemove.ToLower())) {
      Write-Host "The PATH environment variable already contains the directory '$pathToRemove'. Removing..."
      $actualPath = Get-EnvironmentVariable -Name 'Path' -Scope $pathType -PreserveVariables

      $newPath = $actualPath -replace [regex]::Escape($pathToRemove + ';'),'' -replace ';;',';'

      if (($pathType -eq [System.EnvironmentVariableTarget]::Machine) -and !(Test-ProcessAdminRights)) {
        Write-Warning "Removing path from machine environment variable is not supported when not running as an elevated user!"
      } else {
        Set-EnvironmentVariable -Name 'Path' -Value $newPath -Scope $pathType
      }

      $env:PATH = $newPath
    }
  }
}

$ErrorActionPreference = 'Stop'
$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  ZipFileName   = 'LGPO.zip'
}

Uninstall-ChocolateyZipPackage @packageArgs
Uninstall-ChocolateyPath "${env:ProgramFiles(x86)}\$env:ChocolateyPackageName\Local_Script\Tools" -PathType 'Machine'
