# Add only the two new shared candidate disks. Local VirtualBox implementation.
param([ValidateRange(1,100)][int]$SizeGiB=50,[switch]$Apply)
. "$PSScriptRoot\Common.ps1"
$workers=@{'ocne-w1'='1756d852-30cd-40b7-bdd0-49a5359ed499';'ocne-w2'='d4404167-3980-4c69-ae11-9b1e7125446e'}
$before=@{}
foreach($node in @('ocne-w1','ocne-w2')) {
 $details=@(Invoke-LabVBox showvminfo $node --machinereadable)
 if($details -notcontains ('UUID="'+$workers[$node]+'"')){throw 'VM UUID mismatch'}
 if($details -notcontains 'storagecontrollername0="SATA"' -or $details -notcontains 'storagecontrollertype0="IntelAhci"' -or $details -notcontains 'storagecontrollerportcount0="8"'){throw 'Controller mismatch'}
 foreach($port in 6,7){if($details -notcontains ('"SATA-'+$port+'-0"="none"')){throw "Occupied port $port on ${node}: inspect partial run"}}
 if($details -notcontains '"SATA-ImageUUID-4-0"="db34f551-0ee8-4aca-a1aa-cde35a0f7d50"' -or $details -notcontains '"SATA-ImageUUID-5-0"="c280454f-b4c7-4b30-be79-e7cabc280f7e"'){throw 'Existing ASM disks differ'}
 $before[$node]=$details
}
$disks=@(3,4 | ForEach-Object {@{Name=('ocne-rac-asm{0:00}' -f $_);Port=($_+3);File=(Join-Path $LabRoot ('vms\rac-shared\ocne-rac-asm{0:00}.vdi' -f $_))}})
foreach($d in $disks){if(Test-Path -LiteralPath $d.File){throw "Existing file: $($d.File); inspect and resume explicitly"}}
if((Get-PSDrive D).Free -lt (($SizeGiB*2+100)*1GB)){throw 'Insufficient disk space including 100 GiB reserve'}
$disks | ForEach-Object {Write-Output "PLAN $($_.Name): $SizeGiB GiB fixed/shareable, both workers SATA $($_.Port)"}
if(-not $Apply){return}
$run=Join-Path $LabRoot ('logs\asm-spares-'+(Get-Date -Format yyyyMMdd-HHmmss))
New-Item -ItemType Directory -Path $run | Out-Null
foreach($node in $workers.Keys){$before[$node] | Out-File (Join-Path $run "$node-before.txt")}
foreach($d in $disks){
 Invoke-LabVBox createmedium disk --filename $d.File --size ($SizeGiB*1024) --format VDI --variant Fixed
 Invoke-LabVBox modifymedium disk $d.File --type shareable
 $info=@(Invoke-LabVBox showmediuminfo disk $d.File)
 $info | Out-File (Join-Path $run ($d.Name+'-medium.txt'))
 $uuidLine=@($info | Where-Object {$_ -match '^UUID:\s+([0-9a-f-]+)$'})
 if($uuidLine.Count -ne 1){throw 'Cannot identify new UUID'}
 $null=$uuidLine[0] -match '^UUID:\s+([0-9a-f-]+)$'; $d.UUID=$Matches[1];$d.SizeGiB=$SizeGiB
 if(-not ($info -match '^Type:\s+shareable') -or -not ($info -match '^Format variant:\s+fixed') -or -not ($info -match ('^Capacity:\s+'+($SizeGiB*1024)+' MBytes$'))){throw 'Unexpected disk format/type/size'}
 # No hotpluggable flag change on a running VM. Attach only to verified empty slots.
 foreach($node in @('ocne-w1','ocne-w2')) {
  $now=@(Invoke-LabVBox showvminfo $node --machinereadable)
  if($now -notcontains ('"SATA-'+$d.Port+'-0"="none"')){throw 'Slot no longer empty'}
  Invoke-LabVBox storageattach $node --storagectl SATA --port $d.Port --device 0 --type hdd --medium $d.UUID
  $after=@(Invoke-LabVBox showvminfo $node --machinereadable)
  if($after -notcontains ('"SATA-ImageUUID-'+$d.Port+'-0"="'+$d.UUID+'"')){throw 'New attachment verification failed'}
  foreach($line in ($before[$node] | Where-Object {$_ -match '^"SATA-ImageUUID-[0-5]-0"='})){if($after -notcontains $line){throw 'Existing disk attachment changed'}}
  $after | Out-File (Join-Path $run "$node-after.txt")
 }
 $disks | ConvertTo-Json -Depth 4 | Out-File (Join-Path $run 'inventory.json') -Encoding utf8
}
Write-Output "Verified new shared attachments. Inventory: $run"
