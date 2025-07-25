﻿$ErrorActionPreference = 'Stop'

$packageArgs = @{
  packageName    = 'blender'
  softwareName   = 'Blender'
  fileType       = 'MSI'
  url64bit       = 'https://download.blender.org/release/Blender4.5/blender-4.5.0-windows-x64.msi'
  checksum64     = 'a18cd3f2863cfef80f26ebae4a468d4771737c69e7c1b2cb917f76aee41495c7'
  checksumType64 = 'sha256'
  silentArgs     = '/quiet /norestart'
  validExitCodes = @(0, 2010, 1641)
}

Install-ChocolateyPackage @packageArgs
