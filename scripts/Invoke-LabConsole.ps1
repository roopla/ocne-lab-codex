param(
    [Parameter(Mandatory=$true)][ValidateSet('ol9-golden','ocne-op','ocne-cp','ocne-w1','ocne-w2')][string]$Node,
    [Parameter(Mandatory=$true)][ValidateSet('Capture','Text','LoginName','LoginPassword','TTY','IdentityScript')][string]$Action,
    [string]$Text,
    [ValidateRange(0,20)][int]$WaitSeconds = 2
)
. "$PSScriptRoot\Common.ps1"
$info = @(Invoke-LabVBox showvminfo $Node --machinereadable)
if ($info -notcontains 'VMState="running"') { throw 'Console requires a running VM.' }
if ($Node -eq 'ol9-golden' -and $info -notcontains 'UUID="90aaa385-c8d3-49ce-aad9-50f65ada16d4"') { throw 'Golden identity mismatch.' }
if ($Node -ne 'ol9-golden') {
    $cfg = @($info | Where-Object { $_ -match '^CfgFile=' }) -join ''
    if ($cfg -notlike '*OCNE19-Lab*vms*') { throw 'Clone is not in project storage.' }
}
if ($Action -in @('LoginName','LoginPassword')) {
    $credential = Import-Clixml -LiteralPath (Join-Path $LabRoot 'private\golden-credential.clixml')
}
switch ($Action) {
    'TTY' { Invoke-LabVBox controlvm $Node keyboardputscancode 1d 38 3d bd b8 9d }
    'IdentityScript' {
        if ($Node -eq 'ol9-golden' -or $info -notcontains 'cableconnected1="off"') { throw 'Identity script requires a disconnected clone.' }
        $scriptBytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'Prepare-Clone-Identity.sh'))
        $encoded = [Convert]::ToBase64String($scriptBytes)
        for ($i=0; $i -lt $encoded.Length; $i+=500) {
            $chunk = $encoded.Substring($i,[Math]::Min(500,$encoded.Length-$i))
            $redirect = if ($i -eq 0) { '>' } else { '>>' }
            Invoke-LabVBox controlvm $Node keyboardputstring "printf %s $chunk $redirect /run/ocne-identity.b64"
            Invoke-LabVBox controlvm $Node keyboardputscancode 1c 9c
        }
        Invoke-LabVBox controlvm $Node keyboardputstring 'base64 -d /run/ocne-identity.b64 > /root/ocne-prepare-identity.sh && bash -n /root/ocne-prepare-identity.sh && bash /root/ocne-prepare-identity.sh'
        Invoke-LabVBox controlvm $Node keyboardputscancode 1c 9c
    }
    'LoginName' {
        Invoke-LabVBox controlvm $Node keyboardputstring $credential.UserName
        Invoke-LabVBox controlvm $Node keyboardputscancode 1c 9c
    }
    'LoginPassword' {
        # Call only after visually verifying the console Password prompt.
        $inputFile = Join-Path $LabRoot "private\console-$Node-input.tmp"
        try {
            [IO.File]::WriteAllText($inputFile,$credential.GetNetworkCredential().Password,(New-Object System.Text.UTF8Encoding($false)))
            & $VBox controlvm $Node keyboardputfile $inputFile *> $null
            if ($LASTEXITCODE -ne 0) { throw 'Password entry failed; details suppressed.' }
        } finally {
            if (Test-Path -LiteralPath $inputFile) { Remove-Item -LiteralPath $inputFile -Force }
        }
        Invoke-LabVBox controlvm $Node keyboardputscancode 1c 9c
    }
    'Text' {
        if ([string]::IsNullOrWhiteSpace($Text)) { throw 'Text is required.' }
        Invoke-LabVBox controlvm $Node keyboardputstring $Text
        Invoke-LabVBox controlvm $Node keyboardputscancode 1c 9c
    }
}
if ($WaitSeconds) { Start-Sleep -Seconds $WaitSeconds }
$info = @(Invoke-LabVBox showvminfo $Node --machinereadable)
if ($info -contains 'VMState="running"') {
    $screenPath = Join-Path $LabRoot "logs\console-$Node.png"
    Invoke-LabVBox controlvm $Node screenshotpng $screenPath
    Write-Output "Console screenshot: $screenPath"
} else { $info | Select-String '^VMState=' }