param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$GoldenVM,
    [switch]$Create,
    [string[]]$ReviewedGlobalShare = @(),
    [ValidateRange(0,2097152)][int]$BootDiskMB = 0
)
. "$PSScriptRoot\Common.ps1"
# Local provisioning wrapper around Oracle's VBoxManage commands.
# Default is inspection only. All clones remain powered off with NIC 1 disconnected.
$Info = @(Invoke-LabVBox showvminfo $GoldenVM --machinereadable)
if ($Info -notcontains 'VMState="poweroff"') {
    throw 'The golden VM must be shut down cleanly (Powered Off, not Saved).'
}
if ($GoldenVM -in @($LabConfig.VMs | ForEach-Object { $_.Name })) {
    throw 'The golden VM must not have one of the four destination names.'
}
# This first edition deliberately supports one boot disk on SATA port 0.
# Do not reinterpret unknown controller layouts or copy shared ASM disks.
if (-not ($Info -match '^storagecontrollername\d+="SATA"$')) {
    throw 'This script expects a SATA controller named SATA. Inspect other layouts before adapting the script.'
}
if ($Info -notcontains 'nic1="nat"' -and $Info -notcontains 'nic1="natnetwork"' -and
    $Info -notcontains 'nic1="bridged"' -and $Info -notcontains 'nic1="hostonly"' -and
    $Info -notcontains 'nic1="intnet"') {
    throw 'Inspect the template network configuration; expected an existing adapter 1.'
}
$BootUUIDLine = @($Info | Where-Object { $_ -match '^"SATA-ImageUUID-0-0"="([0-9a-fA-F-]{36})"$' })
if ($BootUUIDLine.Count -ne 1) { throw 'Expected a boot medium at SATA port 0, device 0.' }
$null = $BootUUIDLine[0] -match '^"SATA-ImageUUID-0-0"="([0-9a-fA-F-]{36})"$'
$BootUUID = $Matches[1]
$BootInfo = @(Invoke-LabVBox showmediuminfo disk $BootUUID)
$BootInfo | Write-Output
if (-not ($BootInfo -match '^Type:\s+normal(?:\s|$)')) {
    throw 'Expected a normal independent boot disk. Review snapshots, shared or immutable media first.'
}
# At most the boot disk and an empty optical drive. Detach ISO in the source GUI first.
$Controllers = @($Info | ForEach-Object {
    if ($_ -match '^storagecontrollername\d+="(.*)"$') { $Matches[1] }
})
foreach ($Controller in $Controllers) {
    $AttachmentPattern = '^"' + [regex]::Escape($Controller) + '-\d+-\d+"="(.+)"$'
    foreach ($Line in $Info) {
        if ($Line -notmatch $AttachmentPattern) { continue }
        $Medium = $Matches[1]
        if ($Line -match '^"SATA-0-0"=') { continue }
        if ($Medium -notin @('none','emptydrive')) {
            throw "Unexpected attached medium: $Line. Review extra source media before cloning."
        }
    }
}
# Machine/transient shares remain rejected. Global mappings affect unrelated VMs,
# so preserve them and require an explicit review of every observed share name.
if ($Info -match '^SharedFolderName(?:Machine|Transient)Mapping') {
    throw 'Review VM-specific/transient host shares before cloning.'
}
foreach ($Line in $Info) {
    if ($Line -match '^SharedFolderNameGlobalMapping\d+="(.*)"$') {
        $ShareName = $Matches[1]
        if ($ShareName -notin $ReviewedGlobalShare) { throw "Unreviewed global share: $ShareName" }
        Write-Output "Preserving reviewed global share: $ShareName. Verify no guest mounts/use during clone preparation."
    }
}
# Full current-state clones can flatten a normal snapshot chain. Check every
# parent is accessible and normal before creating anything (VBoxManage clonevm).
$ChainInfo = $BootInfo
$SeenMedia = @($BootUUID)
while ($true) {
    if (-not ($ChainInfo -match '^State:\s+(created|locked read|locked write)\s*$')) { throw 'Source medium inaccessible or unexpected state.' }
    if (-not ($ChainInfo -match '^Type:\s+normal(?:\s|$)')) { throw 'Only a normal source disk chain is supported.' }
    $ParentLine = @($ChainInfo | Where-Object { $_ -match '^Parent UUID:\s+(\S+)' })
    if ($ParentLine.Count -ne 1) { throw 'Cannot determine source disk parent.' }
    $null = $ParentLine[0] -match '^Parent UUID:\s+(\S+)'
    $ParentUUID = $Matches[1]
    if ($ParentUUID -eq 'base') { break }
    if ($ParentUUID -in $SeenMedia) { throw 'Unexpected cycle in source medium chain.' }
    $SeenMedia += $ParentUUID
    $ChainInfo = @(Invoke-LabVBox showmediuminfo disk $ParentUUID)
}
if ($BootDiskMB -gt 0) {
    $CapacityLine = @($BootInfo | Where-Object { $_ -match '^Capacity:\s+(\d+) MBytes' })
    if ($CapacityLine.Count -ne 1) { throw 'Cannot establish source disk capacity.' }
    $null = $CapacityLine[0] -match '^Capacity:\s+(\d+) MBytes'
    if ($BootDiskMB -lt [int]$Matches[1]) { throw 'Clone disk shrinking is not supported.' }
    Write-Output "Clone boot disks will be expanded to $BootDiskMB MiB; guest partition/filesystem growth remains a separate verified step."
}
$ExistingVMs = (Invoke-LabVBox list vms) -join "`n"
$VMRoot = Join-Path $LabRoot 'vms'
foreach ($VM in $LabConfig.VMs) {
    $Pattern = '(?m)^"' + [regex]::Escape($VM.Name) + '"\s'
    if ($ExistingVMs -match $Pattern -or (Test-Path -LiteralPath (Join-Path $VMRoot $VM.Name))) {
        throw "Destination already exists: $($VM.Name). Do not recreate it. Inspect partial runs."
    }
}
$Networks = (Invoke-LabVBox list natnetworks) -join "`n"
$NetworkPattern = '(?m)^\s*(?:NetworkName|Name):\s*' + [regex]::Escape($LabConfig.NetworkName) + '\s*$'
if ($Networks -notmatch $NetworkPattern) {
    throw 'Create or verify the documented lab NAT Network before cloning.'
}
Write-Output "Source VM: $GoldenVM"
Write-Output "Destination folder: $VMRoot"
$LabConfig.VMs | ForEach-Object {
    Write-Output ('{0}: {1} MiB RAM, {2} vCPUs, future IP {3}' -f $_.Name,$_.RAM,$_.CPU,$_.IP)
}
Write-Output 'Clones inherit guest partitions. Optional BootDiskMB expands only new clone media; guest filesystem preparation remains pending.'
if (-not $Create) {
    Write-Output 'Inspection complete. Read the cloning guide, then supply -Create to create the four clones.'
    return
}
New-Item -ItemType Directory -Path $VMRoot -Force | Out-Null
foreach ($VM in $LabConfig.VMs) {
    # Omitting Link / KeepAllMACs / KeepHwUUIDs gives independent disks and new identities.
    Invoke-LabVBox clonevm $GoldenVM --name $VM.Name --basefolder $VMRoot --mode machine --register
    # Verify a new independent disk under this clone before any resize.
    $CloneInfo = @(Invoke-LabVBox showvminfo $VM.Name --machinereadable)
    $DiskLine = @($CloneInfo | Where-Object { $_ -match '^"SATA-ImageUUID-0-0"="([0-9a-fA-F-]{36})"$' })
    if ($DiskLine.Count -ne 1) { throw 'Missing cloned boot medium.' }
    $null = $DiskLine[0] -match '^"SATA-ImageUUID-0-0"="([0-9a-fA-F-]{36})"$'
    $CloneDiskUUID = $Matches[1]
    if ($CloneDiskUUID -in $SeenMedia) { throw 'Clone unexpectedly references source disk.' }
    $CloneDiskInfo = @(Invoke-LabVBox showmediuminfo disk $CloneDiskUUID)
    if (-not ($CloneDiskInfo -match '^Parent UUID:\s+base\s*$')) { throw 'Clone boot disk is not independent.' }
    $LocationLine = @($CloneDiskInfo | Where-Object { $_ -match '^Location:\s+(.+)$' })
    if ($LocationLine.Count -ne 1) { throw 'Cannot establish cloned disk location.' }
    $null = $LocationLine[0] -match '^Location:\s+(.+)$'
    $CloneLocation = [IO.Path]::GetFullPath($Matches[1])
    $ExpectedRoot = [IO.Path]::GetFullPath((Join-Path $VMRoot $VM.Name)).TrimEnd('\') + '\'
    if (-not $CloneLocation.StartsWith($ExpectedRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Clone disk is outside its project VM folder.' }
    if ($BootDiskMB -gt 0) { Invoke-LabVBox modifymedium disk $CloneDiskUUID --resize $BootDiskMB }
    Invoke-LabVBox modifyvm $VM.Name --memory $VM.RAM --cpus $VM.CPU --ioapic on `
        --boot1 disk --boot2 none --boot3 none --boot4 none `
        --nic1 natnetwork --nat-network1 $LabConfig.NetworkName --cableconnected1 off
    $ExtraAdapters = @($Info | ForEach-Object {
        if ($_ -match '^nic(\d+)="' -and [int]$Matches[1] -gt 1) { [int]$Matches[1] }
    })
    foreach ($Adapter in $ExtraAdapters) {
        Invoke-LabVBox modifyvm $VM.Name ("--nic$Adapter") none
    }
    Write-Output "Created $($VM.Name), powered off, with network cable disconnected."
}
Write-Output 'Prepare each clone through its console using the cloning guide before reconnecting NIC 1.'
