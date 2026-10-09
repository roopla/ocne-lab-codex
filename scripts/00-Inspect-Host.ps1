# Read-only inspection. No VM or network changes.
. "$PSScriptRoot\Common.ps1"
Get-CimInstance Win32_ComputerSystem |
    Select-Object Name, NumberOfLogicalProcessors,
        @{Name='InstalledRAMGiB';Expression={[math]::Round($_.TotalPhysicalMemory / 1GB, 1)}}
Get-PSDrive -PSProvider FileSystem |
    Select-Object Name, Root, @{Name='FreeGiB';Expression={[math]::Round($_.Free / 1GB, 1)}}
Get-NetRoute -AddressFamily IPv4 |
    Select-Object DestinationPrefix, NextHop, InterfaceAlias
Invoke-LabVBox --version
Invoke-LabVBox list vms
Invoke-LabVBox list natnetworks
Write-Output "Project root: $LabRoot"
Write-Output 'Configured RAM: operator 4 GiB, control plane 8 GiB, each worker 22 GiB.'
Write-Output 'This allocates 56 GiB, leaving 8 GiB on a 64 GiB Windows host.'
