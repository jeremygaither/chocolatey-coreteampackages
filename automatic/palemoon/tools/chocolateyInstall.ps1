$ErrorActionPreference = 'Stop';

$packageArgs = @{
  packageName   = 'palemoon'
  fileType      = 'exe'
  url           = 'https://rm-eu.palemoon.org/release/palemoon-34.2.2.win32.installer.exe'
  url64         = 'https://rm-eu.palemoon.org/release/palemoon-34.2.2.win64.installer.exe'

  softwareName  = 'Pale Moon*'

  checksum      = '6d74120c64e0da85be587275ca1638e2fecf88a843dc81cda112bcf6058cee49'
  checksumType  = 'sha256'
  checksum64    = '209505787b339026d1ccac3f3bccfff22a3cbaf855cc895d854437d8ffc8c81c'
  checksumType64= 'sha256'

  silentArgs    = "/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-"
  validExitCodes= @(0)
}

Install-ChocolateyPackage @packageArgs
