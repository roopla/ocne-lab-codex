param([Parameter(Mandatory=$true)][ValidateSet('ocne-w1','ocne-w2')][string]$VMName)
. "$PSScriptRoot\Common.ps1"
$Details = @(Invoke-LabVBox showvminfo $VMName --machinereadable)
if ($Details -notcontains 'VMState="poweroff"') { throw 'Shut down this worker cleanly first.' }
$ControllerLine = @($Details | Where-Object { $_ -match '^storagecontrollername(\d+)="SATA"$' })
if ($ControllerLine.Count -ne 1) { throw 'Expected a SATA controller named SATA.' }
$null = $ControllerLine[0] -match '^storagecontrollername(\d+)="SATA"$'
$Index = $Matches[1]
$Pattern = '^storagecontrollerportcount' + $Index + '="?(\d+)"?$'
$PortLine = @($Details | Where-Object { $_ -match $Pattern })
if ($PortLine.Count -ne 1) { throw 'Cannot determine controller port count.' }
$null = $PortLine[0] -match $Pattern
$Ports = [int]$Matches[1]
foreach ($Line in $Details) {
    if ($Line -match '^"SATA-2-0"="(.*)"$') {
        if ($Matches[1] -notin @('none','emptydrive')) { throw 'SATA port 2 is occupied; inspect it.' }
    }
}
$VMFolder = Join-Path (Join-Path $LabRoot 'vms') $VMName
if (-not (Test-Path -LiteralPath $VMFolder -PathType Container)) { throw 'Expected project VM folder is missing.' }
$Disk = Join-Path $VMFolder "$VMName-containers.vdi"
if (Test-Path -LiteralPath $Disk) { throw 'Container VDI exists. Inspect partial runs; never overwrite it.' }
if ($Ports -lt 3) { Invoke-LabVBox storagectl $VMName --name SATA --portcount 3 }
Invoke-LabVBox createmedium disk --filename $Disk --size 102400 --format VDI --variant Standard
Invoke-LabVBox storageattach $VMName --storagectl SATA --port 2 --device 0 --type hdd --medium $Disk
Invoke-LabVBox showmediuminfo disk $Disk
Write-Output 'Blank 100 GiB worker container disk attached. Follow the cloning guide before formatting.'
