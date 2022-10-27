﻿import-module au

Add-Type -Assembly System.IO.Compression

$release_files_url = 'https://www.python.org/api/v2/downloads/release_file/'

function global:au_SearchReplace {
  @{
    ".\tools\helpers.ps1"      = @{
      "(?i)(^\s*packageName\s*=\s*)('.*')"              = "`$1'$($Latest.PackageName)'"
      "(?i)(^\s*fileType\s*=\s*)('.*')"                 = "`$1'$($Latest.FileType)'"
      "(?i)(^\s*file\s*=\s*`"[$]toolsPath\\)(.*)`""     = "`$1$($Latest.FileName32)`""
      "(?i)(\['file64'\]\s*=\s*`"[$]toolsPath\\)(.*)`"" = "`$1$($Latest.FileName64)`""
    }

    ".\legal\VERIFICATION.txt" = @{
      "(?i)(^\s*location on\:?\s*)\<.*\>"      = "`${1}<$release_files_url>"
      "(?i)(\s+x32:).*"                        = "`${1} $($Latest.URL32)"
      "(?i)(\s+x64:).*"                        = "`${1} $($Latest.URL64)"
      "(?i)(checksum32:).*"                    = "`${1} $($Latest.Checksum32)"
      "(?i)(checksum64:).*"                    = "`${1} $($Latest.Checksum64)"
      "(?i)3.\d+(\s*Documentation archive\s*)\<.*\>" = "$($Latest.VersionTwoPart)`${1}<$($Latest.ZipUrl)>"
      "(?i)(\s*can also be found at\s*)\<.*\>" = "`${1}<$($Latest.LicenseUrl)>"
    }
  }
}

function global:au_BeforeUpdate {
  rm tools\*.msi, tools\*.exe -ea 0

  Get-RemoteFiles -Purge -NoSuffix

  # download Python documentation archive
  $webrequest = [System.Net.HttpWebRequest]::Create($Latest.ZipUrl)
  $response_stream = $webrequest.GetResponse().GetResponseStream()
  $zip = [IO.Compression.ZipArchive]::new($response_stream)

  # license text for legal/LICENSE.txt
  $license_entry = $zip.GetEntry("$($Latest.ZipName)/license.txt")
  $Latest.License = [System.IO.StreamReader]::new($license_entry.Open()).ReadToEnd()

  # copyright information for nuspec
  $copyright_entry = $zip.GetEntry("$($Latest.ZipName)/copyright.txt")
  $reader = [System.IO.StreamReader]::new($copyright_entry.Open())
  (1..5) | % {$reader.ReadLine()}  # skip header
  $copyright = ''
  $reading_copyright = $false
  while (($line = $reader.ReadLine()) -ne $null) {
      if (!$line) {
          $copyright += "`n"
          $reading_copyright = $false
          continue
      }
      if ($line.StartsWith('Copyright')) {
          if ($reading_copyright) {
              $copyright += "`n"
          }
          $copyright += $line
          $reading_copyright = $true
      } elseif ($reading_copyright) {
          $copyright += " $line"
      } else {
          break
      }
  }
  $Latest.Copyright = $copyright.Trim()
}

function global:au_AfterUpdate($Package) {
    $cdata = $Package.NuspecXml.CreateCDataSection($Latest.Copyright)
    $xml_Copyright = $Package.NuspecXml.GetElementsByTagName('copyright')[0]
    $xml_Copyright.RemoveAll()
    $xml_Copyright.AppendChild($cdata) | Out-Null
    $Package.NuspecXml.package.metadata.licenseUrl = $Latest.LicenseUrl
    $Package.NuspecXml.package.metadata.title = $Latest.Title
    $Package.SaveNuspec()
    $Latest.License | Out-File './legal/LICENSE.txt'
}

function GetStreams() {
  param($release_files)

  $version_re = '3\.(?<minor>\d+)\.(?<micro>\d+)(?:(?<releaselevel>a|b|rc)(?<serial>\d+))?'
  $re = '^python-(?<version>' + $version_re + ')(?<amd64>-amd64)?\.exe$'
  # collect URL pairs for all Python versions
  $all_versions = @{ }
  foreach ($file in $release_files) {
      $file_name = $file.url.Split('/')[-1]
      if ($file_name -match $re) {
          $version = $matches['version']
          $amd64 = $matches['amd64']
          if (!$all_versions.containsKey($version)) {
              $all_versions[$version] = @{ }
          }
          if ($amd64) {
              $all_versions[$version]['64'] = $file.url
          } else {
              $all_versions[$version]['86'] = $file.url
          }
      }
  }

  # find latest version of each Python minor (3.x) version
  $latest_versions = @{ }
  foreach ($version_data in $all_versions.GetEnumerator()) {
    # skip release files that don't have both x64 and x86 installers
    if ($version_data.Value.Count -ne 2) {
      continue
    }
    $version = Get-Version $version_data.Name
    if ($latest_versions.ContainsKey($version.Version.Minor)) {
      $known_latest_version = Get-Version $latest_versions[$version.Version.Minor]
    } else {
      $known_latest_version = Get-Version '0.0.0'
    }
    if ($version -gt $known_latest_version) {
      $latest_versions[$version.Version.Minor] = $version_data.Name
    }
  }

  # generate two version streams per version, one for python3 and one for python3x package
  $streams = @{ }
  foreach ($version_data in $latest_versions.GetEnumerator()) {
    $minor_version = $version_data.Name
    $latest_version = $version_data.Value
    $versionTwoPart = "3.$minor_version"
    $version = Get-Version $latest_version

    $urls = $all_versions[$latest_version]
    $zip_name = "python-$latest_version-docs-text"
    $zip_url = "https://docs.python.org/$versionTwoPart/archives/$zip_name.zip"
    $license_url = "https://docs.python.org/$versionTwoPart/license.html"
    $streams[$versionTwoPart] = @{
      URL32          = $urls['86']
      URL64          = $urls['64']
      Version        = $version
      VersionTwoPart = $versionTwoPart
      ZipName        = $zip_name
      ZipUrl         = $zip_url
      LicenseUrl     = $license_url
      PackageName    = 'python3'
      Title          = 'Python 3.x'
    }
    $streams["$versionTwoPart-minor"] = $streams[$versionTwoPart].Clone()
    $streams["$versionTwoPart-minor"]['PackageName'] += $minor_version
    $streams["$versionTwoPart-minor"]['Title'] = "Python 3.$minor_version"
  }

  Write-Host $streams.Count 'streams collected'
  $streams
}

function global:au_GetLatest {
  $release_files = Invoke-RestMethod $release_files_url

  @{ Streams = GetStreams $release_files }
}

if ($MyInvocation.InvocationName -ne '.') {
  # run the update only if script is not sourced by the virtual package python
  update -ChecksumFor none
}
