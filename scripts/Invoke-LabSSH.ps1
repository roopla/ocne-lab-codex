param(
    [Parameter(Mandatory=$true)][ValidateSet('ol9-golden','ocne-op','ocne-cp','ocne-w1','ocne-w2')][string]$Node,
    [Parameter(Mandatory=$true)][string]$ScriptPath,
    [ValidateSet('golden','labadmin')][string]$CredentialName = 'golden'
)
. "$PSScriptRoot\Common.ps1"
$fullScript = [IO.Path]::GetFullPath($ScriptPath)
$scriptRoot = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + [IO.Path]::DirectorySeparatorChar
if (-not $fullScript.StartsWith($scriptRoot,[StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $fullScript -PathType Leaf)) { throw 'Guest script must be a file under project scripts/.' }
$endpoints = Get-Content -LiteralPath (Join-Path $LabRoot 'private\ssh-endpoints.json') -Raw | ConvertFrom-Json
$endpoint = $endpoints.$Node
if (-not $endpoint -or -not $endpoint.fingerprint.StartsWith('SHA256:')) { throw 'Missing console-verified SSH endpoint.' }
$credential = Import-Clixml -LiteralPath (Join-Path $LabRoot "private\$CredentialName-credential.clixml")
$runId = [Guid]::NewGuid().ToString('N')
$passwordFile = Join-Path $LabRoot "private\plink-$Node-$runId-password.tmp"
$wrapperPath = Join-Path $LabRoot "private\ssh-$Node-$runId-script.tmp"
$payload = [IO.File]::ReadAllText($fullScript).Replace("`r`n","`n")
$delimiter = 'LAB_SCRIPT_' + [Guid]::NewGuid().ToString('N')
$wrapper = "set -e`nbash -n <<'$delimiter'`n" + $payload + "`n$delimiter`nbash <<'$delimiter'`n" + $payload + "`n$delimiter`n"
[IO.File]::WriteAllText($wrapperPath,$wrapper,(New-Object System.Text.UTF8Encoding($false)))
$logPath = Join-Path $LabRoot ('logs\ssh-{0}-{1}-{2}.txt' -f $Node,[IO.Path]::GetFileNameWithoutExtension($fullScript),(Get-Date -Format 'yyyyMMdd-HHmmss'))
try {
    [IO.File]::WriteAllText($passwordFile,$credential.GetNetworkCredential().Password,(New-Object System.Text.UTF8Encoding($false)))
    $ErrorActionPreference = 'Continue'
    & 'C:\Program Files\PuTTY\plink.exe' -ssh -batch -no-antispoof -T -hostkey $endpoint.fingerprint -P $endpoint.port -pwfile $passwordFile -l $credential.UserName $endpoint.address -m $wrapperPath 2>&1 | ForEach-Object { $_.ToString() } | Tee-Object -FilePath $logPath
    $guestExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($guestExit -ne 0) { throw "Guest script returned $guestExit; see $logPath" }
} finally {
    if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile -Force }
    if (Test-Path -LiteralPath $wrapperPath) { Remove-Item -LiteralPath $wrapperPath -Force }
}
Write-Output "SSH result saved: $logPath"