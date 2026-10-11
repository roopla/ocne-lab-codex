# Local VirtualBox implementation for Oracle RAC prerequisites; no guest formatting.
# Sources: docs/RAC-READINESS.md and VirtualBox 7.2 Virtual Storage (shareable mode).
param([switch]$Apply)
. "$PSScriptRoot\Common.ps1"
$workers=@{
    'ocne-w1'=@{UUID='1756d852-30cd-40b7-bdd0-49a5359ed499';Boot='2a09e7bc-1569-4ca0-8ec2-2ebcd83c4500';Containers='7ccb5a40-7a35-4bd0-87f6-d40e8cce0b51'}
    'ocne-w2'=@{UUID='d4404167-3980-4c69-ae11-9b1e7125446e';Boot='ebbcf406-ef5a-491a-85a7-e1c300557a67';Containers='447ca102-89d5-4635-a3fc-12fd8ca0eabb'}
}
$networks=@('ocne-rac-priv1','ocne-rac-priv2')
$disks=@(
    @{Name='ocne-w1-scratch';File=(Join-Path $LabRoot 'vms\ocne-w1\ocne-w1-scratch.vdi');MiB=131072;Variant='Standard';Type='normal';Nodes=@('ocne-w1');Port=3},
    @{Name='ocne-w2-scratch';File=(Join-Path $LabRoot 'vms\ocne-w2\ocne-w2-scratch.vdi');MiB=131072;Variant='Standard';Type='normal';Nodes=@('ocne-w2');Port=3},
    @{Name='ocne-rac-asm01';File=(Join-Path $LabRoot 'vms\rac-shared\ocne-rac-asm01.vdi');MiB=51200;Variant='Fixed';Type='shareable';Nodes=@('ocne-w1','ocne-w2');Port=4},
    @{Name='ocne-rac-asm02';File=(Join-Path $LabRoot 'vms\rac-shared\ocne-rac-asm02.vdi');MiB=51200;Variant='Fixed';Type='shareable';Nodes=@('ocne-w1','ocne-w2');Port=5}
)
function Assert-OriginalDisks($Node,$Details) {
    if($Details -notcontains ('UUID="'+$workers[$Node].UUID+'"')){throw "VM identity mismatch: $Node"}
    if($Details -notcontains ('"SATA-ImageUUID-0-0"="'+$workers[$Node].Boot+'"')){throw "Boot disk changed: $Node"}
    if($Details -notcontains ('"SATA-ImageUUID-2-0"="'+$workers[$Node].Containers+'"')){throw "Container disk changed: $Node"}
    if($Details -notcontains 'memory=22528' -or $Details -notcontains 'cpus=6'){throw "Worker resources changed: $Node"}
}
foreach($node in @('ocne-w1','ocne-w2')) {
    $details=@(Invoke-LabVBox showvminfo $node --machinereadable)
    Assert-OriginalDisks $node $details
    if($Apply -and $details -notcontains 'VMState="poweroff"'){throw "Gracefully shut down $node first."}
    foreach($port in 3,4,5){if($details -notcontains ('"SATA-'+$port+'-0"="none"')){throw "SATA $port occupied on $node; inspect partial state."}}
    foreach($nic in 2,3){if($details -notcontains ('nic'+$nic+'="none"')){throw "NIC $nic occupied on $node; inspect partial state."}}
    if($details -notcontains 'storagecontrollerportcount0="8"' -or $details -notcontains 'storagecontrollername0="SATA"'){throw 'Unexpected controller layout.'}
}
$existingNetworks=@(Invoke-LabVBox list intnets) -join "`n"
foreach($network in $networks){if($existingNetworks -match [regex]::Escape($network)){throw "Internal network already exists: $network. Inspect rather than recreating."}}
$diskRoot=[IO.Path]::GetFullPath((Join-Path $LabRoot 'vms')).TrimEnd('\')+'\'
foreach($disk in $disks){
    if(-not [IO.Path]::GetFullPath($disk.File).StartsWith($diskRoot,[StringComparison]::OrdinalIgnoreCase)){throw 'Disk path outside project vms/.'}
    if(Test-Path -LiteralPath $disk.File){throw "Disk already exists: $($disk.File). Inspect partial run; never overwrite."}
}
$volume=Get-PSDrive -Name ([IO.Path]::GetPathRoot($LabRoot).Substring(0,1))
if($volume.Free -lt 400GB){throw 'Need 400 GiB free for planned capacity and headroom.'}
$disks | ForEach-Object {Write-Output ("PLAN: {0}, {1} MiB, {2}/{3}, SATA port {4}, nodes {5}" -f $_.File,$_.MiB,$_.Variant,$_.Type,$_.Port,($_.Nodes -join ','))}
Write-Output 'PLAN: worker NIC2/NIC3 -> isolated ocne-rac-priv1/ocne-rac-priv2, Intel 82540EM, allow-vms promiscuity. No host IP/DHCP.'
if(-not $Apply){Write-Output 'Read-only preflight passed. Use -Apply only with both workers powered off.';return}
$backup=Join-Path $LabRoot ('logs\rac-hardware-before-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Path $backup | Out-Null
foreach($node in @('ocne-w1','ocne-w2')){Copy-Item -LiteralPath (Join-Path $LabRoot "vms\$node\$node.vbox") -Destination (Join-Path $backup "$node.vbox")}
New-Item -ItemType Directory -Path (Join-Path $LabRoot 'vms\rac-shared') -Force | Out-Null
foreach($disk in $disks){
    Invoke-LabVBox createmedium disk --filename $disk.File --size $disk.MiB --format VDI --variant $disk.Variant
    if($disk.Type -eq 'shareable'){Invoke-LabVBox modifymedium disk $disk.File --type shareable}
    $medium=@(Invoke-LabVBox showmediuminfo disk $disk.File)
    $uuidLine=@($medium | Where-Object {$_ -match '^UUID:\s+([0-9a-f-]+)$'})
    if($uuidLine.Count -ne 1){throw 'Cannot verify new disk UUID.'}
    $null=$uuidLine[0] -match '^UUID:\s+([0-9a-f-]+)$'
    $disk.UUID=$Matches[1]
    if(-not ($medium -match ('^Capacity:\s+'+$disk.MiB+' MBytes$'))){throw 'New disk capacity mismatch.'}
    if(-not ($medium -match '^Storage format:\s+VDI$')){throw 'New disk format mismatch.'}
    if(-not ($medium -match ('^Type:\s+'+$disk.Type+'( |$)'))){throw 'New disk write mode mismatch.'}
    if($disk.Variant -eq 'Fixed' -and -not ($medium -match '^Format variant:\s+fixed')){throw 'Shared disk is not fixed-size.'}
    $medium | Out-File -LiteralPath (Join-Path $backup ($disk.Name+'-medium.txt')) -Encoding utf8
    foreach($node in $disk.Nodes){Invoke-LabVBox storageattach $node --storagectl SATA --port $disk.Port --device 0 --type hdd --medium $disk.UUID --mtype $disk.Type}
}
foreach($node in @('ocne-w1','ocne-w2')){
    Invoke-LabVBox modifyvm $node --nic2 intnet --intnet2 $networks[0] --nictype2 82540EM --nicpromisc2 allow-vms --cableconnected2 on --nic3 intnet --intnet3 $networks[1] --nictype3 82540EM --nicpromisc3 allow-vms --cableconnected3 on
    $details=@(Invoke-LabVBox showvminfo $node --machinereadable)
    Assert-OriginalDisks $node $details
    foreach($disk in $disks | Where-Object {$node -in $_.Nodes}){
        if($details -notcontains ('"SATA-ImageUUID-'+$disk.Port+'-0"="'+$disk.UUID+'"')){throw "Attachment verification failed: $node $($disk.Name)"}
    }
    if($details -notcontains 'nic2="intnet"' -or $details -notcontains 'nic3="intnet"'){throw 'Network verification failed.'}
    $details | Out-File -LiteralPath (Join-Path $backup "$node-after.txt") -Encoding utf8
}
$disks | ConvertTo-Json -Depth 4 | Out-File -LiteralPath (Join-Path $LabRoot 'logs\rac-hardware-inventory.json') -Encoding utf8
Write-Output 'Hardware attachments verified. Guest disk identity, signatures, network interfaces and initialization still require inspection.'