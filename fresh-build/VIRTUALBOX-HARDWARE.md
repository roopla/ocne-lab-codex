# Optional VirtualBox RAC hardware branch

[Back to RAC prerequisites](03-RAC.md)

Local Windows implementation for the example worker names, before RAC exists. Other platforms need their own shared-block setup. Run on each worker:

```bash
sudo shutdown -h now
```

**Expected:** both workers powered off. **If not:** inspect the VM console; do not force power off a running database.

On Windows PowerShell in D:\OCNE19-Lab, parse the existing inspection script and inspect host/VM/network state before hardware changes:

```powershell
$ParseTokens = $null
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path scripts/00-Inspect-Host.ps1), [ref]$ParseTokens, [ref]$ParseErrors) | Out-Null
if ($ParseErrors.Count) { throw ($ParseErrors | Out-String) }
.\scripts\00-Inspect-Host.ps1
Get-Volume -DriveLetter D | Select-Object DriveLetter,Size,SizeRemaining
```

**Expected:** room for 100 GiB fixed shared disks plus growth of two 128 GiB scratch disks and other lab disks. **If not:** add capacity; preserve unrelated files.

Windows Git Bash, repository root. SATA3/4/5 and NIC2/3 must be unused. The block inventories attachments before asking for confirmation; customize slots/controller only from inspected state:

```bash
set -euo pipefail
VBOX='/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'
for node in ocne-w1 ocne-w2; do
  "$VBOX" showvminfo "$node" --machinereadable
  "$VBOX" showvminfo "$node" --machinereadable | grep -Fx 'VMState="poweroff"'
done
read -r -p 'Type FREE after checking SATA3/4/5 and NIC2/3 are unused on both VMs: ' answer
test "$answer" = FREE
mkdir -p /d/OCNE19-Lab/vms/rac-shared
for node in ocne-w1 ocne-w2; do test ! -e "/d/OCNE19-Lab/vms/$node/rac-scratch.vdi"; done
for n in 1 2; do test ! -e "/d/OCNE19-Lab/vms/rac-shared/asm0$n.vdi"; done
for node in ocne-w1 ocne-w2; do
  "$VBOX" createmedium disk --filename "D:/OCNE19-Lab/vms/$node/rac-scratch.vdi" --size 131072 --format VDI --variant Standard
  "$VBOX" storageattach "$node" --storagectl SATA --port 3 --device 0 --type hdd --medium "D:/OCNE19-Lab/vms/$node/rac-scratch.vdi"
done
for n in 1 2; do
  disk="D:/OCNE19-Lab/vms/rac-shared/asm0$n.vdi"
  "$VBOX" createmedium disk --filename "$disk" --size 51200 --format VDI --variant Fixed
  "$VBOX" modifymedium disk "$disk" --type shareable
  "$VBOX" showmediuminfo disk "$disk"
  for node in ocne-w1 ocne-w2; do
    "$VBOX" storageattach "$node" --storagectl SATA --port "$((n+3))" --device 0 --type hdd --medium "$disk"
  done
done
for node in ocne-w1 ocne-w2; do
  "$VBOX" modifyvm "$node" --nic2 intnet --intnet2 ocne-rac-priv1 --nictype2 82540EM --nicpromisc2 allow-vms --cableconnected2 on --nic3 intnet --intnet3 ocne-rac-priv2 --nictype3 82540EM --nicpromisc3 allow-vms --cableconnected3 on
  "$VBOX" showvminfo "$node" --machinereadable
done
```

**Expected:** independent scratch disks, same two fixed **shareable** disks on both workers, private NICs with allow-vms. Compare backing UUIDs in showvminfo; ASM01 must match across workers, and ASM02 likewise.

**If not:** stop. Inventory the partial run and perform only missing steps; never overwrite disks or detach existing devices to free a port. Multiattach is not equivalent to shareable storage.

After reviewing attachments, Windows Git Bash:

```bash
VBOX='/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'
"$VBOX" startvm ocne-w1 --type headless
"$VBOX" startvm ocne-w2 --type headless
```

**Expected:** both VMs running, SSH reachable, original filesystems intact. **If not:** inspect showvminfo and console before continuing. Match guest NIC MACs and disk serials to attachments in chapter 3; device letters can change.

Source: [VirtualBox storage/sharing modes](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/storage.html). This local implementation is not a production certification claim.
