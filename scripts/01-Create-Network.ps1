# Local VirtualBox orchestration; see README and guide Part A.
. "$PSScriptRoot\Common.ps1"
$Existing = (Invoke-LabVBox list natnetworks) -join "`n"
$NetworkPattern = '(?m)^\s*(?:NetworkName|Name):\s*' + [regex]::Escape($LabConfig.NetworkName) + '\s*$'
if ($Existing -match $NetworkPattern) {
    throw "Network $($LabConfig.NetworkName) already exists. Inspect it against config/lab.psd1; do not recreate it."
}
Invoke-LabVBox natnetwork add --netname $LabConfig.NetworkName `
    --network $LabConfig.NetworkCIDR --dhcp off --enable
foreach ($VM in $LabConfig.VMs) {
    $Rule = 'ssh-{0}:tcp:[127.0.0.1]:{1}:[{2}]:22' -f $VM.Name, $VM.SSHPort, $VM.IP
    Invoke-LabVBox natnetwork modify --netname $LabConfig.NetworkName --port-forward-4 $Rule
}
Invoke-LabVBox natnetwork start --netname $LabConfig.NetworkName
