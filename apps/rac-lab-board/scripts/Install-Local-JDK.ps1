# Optional portable Windows JDK. Writes only under the lab's private/app-tools.
$ErrorActionPreference = 'Stop'
$labRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$toolDir = Join-Path $labRoot 'private/app-tools'
New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
$archive = Join-Path $toolDir 'temurin21.zip'
$url = 'https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jdk_x64_windows_hotspot_21.0.12.1_1.zip'
if (-not (Test-Path -LiteralPath $archive)) { Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive }
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant() -ne 'f9d6e191ab098c0d416e7d588a24420a8621cd2f4720dab2459b8b7b2d2d8b4e') { throw 'JDK checksum mismatch' }
$jdkDir = Join-Path $toolDir 'jdk-21.0.12.1+1'
if (-not (Test-Path -LiteralPath (Join-Path $jdkDir 'bin/javac.exe'))) { Expand-Archive -LiteralPath $archive -DestinationPath $toolDir }
& (Join-Path $jdkDir 'bin/java.exe') -version
if ($LASTEXITCODE -ne 0) { throw 'Java version check failed' }
