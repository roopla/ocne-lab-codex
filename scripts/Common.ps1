# Dot-source from the numbered scripts. Paths are relative to this project.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$LabRoot = Split-Path -Parent $PSScriptRoot
$LabConfig = Import-PowerShellDataFile (Join-Path $LabRoot 'config\lab.psd1')
$VBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if (-not (Test-Path -LiteralPath $VBox -PathType Leaf)) {
    throw "VBoxManage not found at $VBox. Install VirtualBox or correct its location in Common.ps1."
}
function Invoke-LabVBox {
    & $VBox @args
    if ($LASTEXITCODE -ne 0) {
        throw "VBoxManage failed: $args"
    }
}
function Assert-LabVMsPoweredOff {
    foreach ($VM in $LabConfig.VMs) {
        $Details = @(Invoke-LabVBox showvminfo $VM.Name --machinereadable)
        if ($Details -notcontains 'VMState="poweroff"') {
            throw "$($VM.Name) must be fully powered off. Shut it down cleanly first; saved state is not sufficient."
        }
    }
}
