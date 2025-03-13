$ErrorActionPreference = 'Stop'
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$url        = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'

$packageArgs = @{
  packageName   = $env:ChocolateyPackageName
  unzipLocation = "${env:ProgramFiles(x86)}\$env:ChocolateyPackageName\Local_Script\Tools"
  url           = $url
  checksum      = 'CB7159D134A0A1E7B1ED2ADA9A3CE8CE8F4DE391D14403D55438AF824247CC55'
  checksumType  = 'sha256'
  silentArgs   = ''
}

Install-ChocolateyZipPackage @packageArgs

if (!(Test-Path -Path "${env:ProgramFiles(x86)}\$env:ChocolateyPackageName\Local_Script\Tools\LGPO.exe")){
    $lgpo = Get-ChildItem -Path "${env:ProgramFiles(x86)}\$env:ChocolateyPackageName\Local_Script\Tools\" -Filter '*LGPO.exe' -Recurse
    if ($lgpo) {
        Move-Item -Path $lgpo[0].FullName -Destination "${env:ProgramFiles(x86)}\$env:ChocolateyPackageName\Local_Script\Tools\$($lgpo.name)"
    }
    else {
        throw "Unable to find LGPO.exe"
    }
}

Install-ChocolateyPath "${env:ProgramFiles(x86)}\$env:ChocolateyPackageName\Local_Script\Tools" -PathType 'Machine'
