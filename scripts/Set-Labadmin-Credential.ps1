param([Parameter(Mandatory=$true)][ValidateSet('ocne-op','ocne-cp','ocne-w1','ocne-w2')][string]$Node)
. "$PSScriptRoot\Common.ps1"
$credentialPath=Join-Path $LabRoot 'private\labadmin-credential.clixml'
if (-not (Test-Path -LiteralPath $credentialPath)) {
    $randomBytes=New-Object byte[] 32
    $rng=[Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($randomBytes) } finally { $rng.Dispose() }
    $securePassword=ConvertTo-SecureString ([Convert]::ToBase64String($randomBytes)) -AsPlainText -Force
    $labCredential=New-Object Management.Automation.PSCredential('labadmin',$securePassword)
    $labCredential | Export-Clixml -LiteralPath $credentialPath
}
$labCredential=Import-Clixml -LiteralPath $credentialPath
$rootCredential=Import-Clixml -LiteralPath (Join-Path $LabRoot 'private\golden-credential.clixml')
$endpoints=Get-Content -LiteralPath (Join-Path $LabRoot 'private\ssh-endpoints.json') -Raw | ConvertFrom-Json
$endpoint=$endpoints.$Node
if (-not $endpoint.fingerprint.StartsWith('SHA256:')) { throw 'Verified host key required' }
$passwordFile=Join-Path $LabRoot "private\account-$Node-password.tmp"
try {
    [IO.File]::WriteAllText($passwordFile,$rootCredential.GetNetworkCredential().Password,(New-Object Text.UTF8Encoding($false)))
    $ErrorActionPreference='Continue'
    ('labadmin:'+$labCredential.GetNetworkCredential().Password) | & 'C:\Program Files\PuTTY\plink.exe' -ssh -batch -no-antispoof -T -hostkey $endpoint.fingerprint -P $endpoint.port -pwfile $passwordFile -l $rootCredential.UserName $endpoint.address "tr -d '\r' | chpasswd"
    $accountExit=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    if ($accountExit -ne 0) { throw 'Account password setup failed' }
    [IO.File]::WriteAllText($passwordFile,$labCredential.GetNetworkCredential().Password,(New-Object Text.UTF8Encoding($false)))
    $ErrorActionPreference='Continue'
    $labCredential.GetNetworkCredential().Password | & 'C:\Program Files\PuTTY\plink.exe' -ssh -batch -no-antispoof -T -hostkey $endpoint.fingerprint -P $endpoint.port -pwfile $passwordFile -l labadmin $endpoint.address "tr -d '\r' | sudo -S -p '' id -u"
    $sudoExit=$LASTEXITCODE
    $ErrorActionPreference='Stop'
    if ($sudoExit -ne 0) { throw 'labadmin SSH/sudo verification failed' }
} finally { if (Test-Path -LiteralPath $passwordFile) { Remove-Item -LiteralPath $passwordFile -Force } }
Write-Output "Verified labadmin SSH and password-required sudo on $Node. Password remains DPAPI-encrypted in private/."