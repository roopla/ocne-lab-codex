# Run once after OS installation, with the operator fully powered off.
# Creates an additional blank disk; never formats a guest device.
. "$PSScriptRoot\Common.ps1"
$NFS = $LabConfig.NFS
$Details = @(Invoke-LabVBox showvminfo $NFS.Server --machinereadable)
if ($Details -notcontains 'VMState="poweroff"') {
    throw 'Shut down the operator cleanly first. Saved state is not sufficient.'
}
$ControllerPattern = '^storagecontrollername(\d+)="' + [regex]::Escape($NFS.Controller) + '"$'
$ControllerLine = @($Details | Where-Object { $_ -match $ControllerPattern })
if ($ControllerLine.Count -ne 1) {
    throw 'Expected one existing SATA controller. Inspect the operator storage configuration.'
}
$null = $ControllerLine[0] -match $ControllerPattern
$ControllerIndex = $Matches[1]
$PortCountPattern = '^storagecontrollerportcount' + $ControllerIndex + '="?(\d+)"?$'
$PortCountLine = @($Details | Where-Object { $_ -match $PortCountPattern })
if ($PortCountLine.Count -ne 1) { throw 'Cannot determine SATA port count.' }
$null = $PortCountLine[0] -match $PortCountPattern
$CurrentPortCount = [int]$Matches[1]
$AttachmentPattern = '^"' + [regex]::Escape($NFS.Controller) + '-' + $NFS.Port + '-0"="(.*)"$'
foreach ($Line in $Details) {
    if ($Line -match $AttachmentPattern) {
        if ($Matches[1] -notin @('none', 'emptydrive')) {
            throw 'The intended NFS disk port is occupied. Do not replace the attached medium.'
        }
    }
}
$VMFolder = Join-Path (Join-Path $LabRoot 'vms') $NFS.Server
if (-not (Test-Path -LiteralPath $VMFolder -PathType Container)) {
    throw 'Operator folder missing under project vms/. Inspect existing VM paths before proceeding.'
}
$Disk = Join-Path $VMFolder $NFS.DiskFile
if (Test-Path -LiteralPath $Disk) {
    throw "Disk already exists: $Disk. Inspect partial runs; never recreate or overwrite it."
}
if ($CurrentPortCount -le $NFS.Port) {
    Invoke-LabVBox storagectl $NFS.Server --name $NFS.Controller --portcount ($NFS.Port + 1)
}
Invoke-LabVBox createmedium disk --filename $Disk --size $NFS.DiskMB --format VDI --variant Standard
Invoke-LabVBox storageattach $NFS.Server --storagectl $NFS.Controller --port $NFS.Port --device 0 --type hdd --medium $Disk
Invoke-LabVBox showmediuminfo disk $Disk
Write-Output 'Additional blank NFS disk attached. Start the operator and follow guide Part D.'
Write-Output 'If a command failed, inspect the existing disk and attachment before retrying.'
