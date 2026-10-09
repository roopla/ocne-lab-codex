# Optional: existing VMs only; all must be powered off. Does not move their files.
. "$PSScriptRoot\Common.ps1"
Assert-LabVMsPoweredOff
foreach ($VM in $LabConfig.VMs) {
    Invoke-LabVBox modifyvm $VM.Name --memory $VM.RAM
}
Write-Output 'RAM updated using config/lab.psd1. No VMs were started.'
