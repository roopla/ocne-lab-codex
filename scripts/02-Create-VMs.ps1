param(
    [Parameter(Mandatory=$true)]
    [string]$IsoFile
)
. "$PSScriptRoot\Common.ps1"
if ([IO.Path]::GetFileName($IsoFile) -ne $IsoFile -or [IO.Path]::GetExtension($IsoFile) -ine '.iso') {
    throw 'Pass only the ISO filename, not a path. Put the ISO inside the project ISO folder.'
}
$IsoPath = Join-Path (Join-Path $LabRoot 'ISO') $IsoFile
if (-not (Test-Path -LiteralPath $IsoPath -PathType Leaf)) {
    throw "ISO not found: $IsoPath"
}
$Networks = (Invoke-LabVBox list natnetworks) -join "`n"
$NetworkPattern = '(?m)^\s*(?:NetworkName|Name):\s*' + [regex]::Escape($LabConfig.NetworkName) + '\s*$'
if ($Networks -notmatch $NetworkPattern) {
    throw 'Configured NAT Network not found. Complete 01-Create-Network.ps1 first.'
}
$VMRoot = Join-Path $LabRoot 'vms'
$ExistingVMs = (Invoke-LabVBox list vms) -join "`n"
# Preflight every name/path before creating any VM.
foreach ($VM in $LabConfig.VMs) {
    $NamePattern = '(?m)^"' + [regex]::Escape($VM.Name) + '"\s'
    if ($ExistingVMs -match $NamePattern -or (Test-Path -LiteralPath (Join-Path $VMRoot $VM.Name))) {
        throw "VM name or directory already exists: $($VM.Name). Inspect it; this script creates fresh VMs only."
    }
}
New-Item -ItemType Directory -Path $VMRoot -Force | Out-Null
foreach ($VM in $LabConfig.VMs) {
    $Name = $VM.Name
    $Disk = Join-Path (Join-Path $VMRoot $Name) "$Name.vdi"
    Invoke-LabVBox createvm --name $Name --ostype 'Oracle_64' --basefolder $VMRoot --register
    Invoke-LabVBox modifyvm $Name --memory $VM.RAM --cpus $VM.CPU `
        --ioapic on --graphicscontroller vmsvga --vram 32 `
        --boot1 dvd --boot2 disk --boot3 none --boot4 none `
        --nic1 natnetwork --nat-network1 $LabConfig.NetworkName `
        --nictype1 82540EM --cableconnected1 on
    Invoke-LabVBox createmedium disk --filename $Disk --size $VM.DiskMB --format VDI --variant Standard
    Invoke-LabVBox storagectl $Name --name 'SATA' --add sata --controller IntelAhci --portcount 2 --bootable on
    Invoke-LabVBox storageattach $Name --storagectl 'SATA' --port 0 --device 0 --type hdd --medium $Disk
    Invoke-LabVBox storageattach $Name --storagectl 'SATA' --port 1 --device 0 --type dvddrive --medium $IsoPath
}
Write-Output 'VMs created under the project vms folder. Install the guest OS using guide A5 before script 03.'
