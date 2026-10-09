# Run only after OS installation has completed on every VM.
. "$PSScriptRoot\Common.ps1"
Assert-LabVMsPoweredOff
foreach ($VM in $LabConfig.VMs) {
    Invoke-LabVBox storageattach $VM.Name --storagectl 'SATA' --port 1 --device 0 --type dvddrive --medium none
    Invoke-LabVBox modifyvm $VM.Name --boot1 disk --boot2 none
}
foreach ($VM in $LabConfig.VMs) {
    Invoke-LabVBox startvm $VM.Name --type headless
}
