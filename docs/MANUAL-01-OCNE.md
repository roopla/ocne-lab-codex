# 1. Set up the OCNE 1.9 lab

[Manual start](OCNE-RAC-END-TO-END-MANUAL.md) | Next: [2. Database Operator](MANUAL-02-DATABASE-OPERATOR.md)

## 1a. Prerequisites for setting up the OCNE lab

### 1a.1 Prepare tools, capacity and an inventory

Install VirtualBox, Windows OpenSSH client, Git (including Git Bash), and Python 3 for local documentation/media checks. Have console administrator access to the golden VM and permission to create lab resources. Do not download an ISO for this cloning path. Existing source software must satisfy Oracle's [OCNE host requirements](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/hosts.html).

Use an empty project checkout for a separate build. On this completed lab, inventory only; existing resources are not a reason to delete/recreate them. Windows PowerShell:

```powershell
Set-Location D:\OCNE19-Lab
$VBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
Get-Command git,ssh,scp,python
& $VBox --version
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,TotalVisibleMemorySize,FreePhysicalMemory
Get-CimInstance Win32_Processor | Select-Object Name,NumberOfLogicalProcessors
Get-Volume | Select-Object DriveLetter,FileSystem,Size,SizeRemaining
Get-NetRoute -AddressFamily IPv4 | Select-Object DestinationPrefix,NextHop,InterfaceAlias
& $VBox list vms
& $VBox list runningvms
& $VBox list natnetworks
& $VBox list intnets
& $VBox list hdds
Get-Content .\config\lab.psd1
```

Inspect and parse the supplied Windows scripts before running them:

```powershell
Get-ChildItem .\scripts\*.ps1 | ForEach-Object {
    $tokens=$null; $errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if ($errors.Count) { throw ($errors | Out-String) }
}
.\scripts\00-Inspect-Host.ps1
```

Equivalent host inventory in **Windows Git Bash**, not inside a guest:

```bash
cd /d/OCNE19-Lab
VBOX='/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'
"$VBOX" --version
"$VBOX" list vms
"$VBOX" list runningvms
"$VBOX" list natnetworks
"$VBOX" list hdds
df -h /d
```

Record these values before changing anything:

| Value to confirm | This lab's example |
|---|---|
| Project root / source VM | D:\OCNE19-Lab / ol9-golden |
| Golden VM UUID, boot UUID, snapshot parents | Obtain from showvminfo/showmediuminfo; never substitute a disk by size alone |
| NAT network / gateway | ocne19-net / 192.168.77.0/24 / 192.168.77.1 |
| Reachable DNS resolver | Site-specific; the source used 192.168.137.1, which must not be assumed elsewhere |
| Operator / control plane / workers | ocne-op .10, ocne-cp .11, ocne-w1 .12, ocne-w2 .13 |
| FQDN suffix / admin UID:GID | lab.test / labadmin 1001:1001 after collision checks |
| RAM / vCPU | 4/2, 8/4, 22/6, 22/6 |
| Loopback SSH ports | 2220, 2221, 2222, 2223 |
| Golden disk layout / root filesystem | Observed source: 40 GiB, plain partition 2, XFS; inspect yours |
| Scratch/ASM private NIC slots | Later stage used SATA3/4/5 and NIC2/3; confirm free slots |

VM RAM totals 56 GiB; the recorded Windows host has 61.66 GiB visible RAM. Allow host overhead and actual free RAM. The final build has **1056 GiB virtual disk capacity**: four 100 GiB OS disks, two 100 GiB container disks, 100 GiB NFS, two 128 GiB scratch disks and two shared 50 GiB disks counted once. The 100 GiB shared capacity is fixed allocation; other VDI files grow. Allow additional physical space for ZIPs, images, logs, backups and the preserved source. Do not equate virtual capacity with current disk consumption.

Check Windows sleep before long installs:

```powershell
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
# Record the original AC setting first. For this lab session on AC:
powercfg /change standby-timeout-ac 0
```

Modern Standby previously paused guests and caused time jumps/stalls. This setting does not prevent explicit sleep/hibernate. Restore your original AC timeout only after an orderly lab shutdown; this host's original value was 60 minutes.

**Gate:** non-overlapping subnets, enough storage/RAM, working tools, identified source and administrator login. Stop if any required input is unknown.

## 2. Oracle source map

| ID | Source | Exact part used |
|---|---|---|
| C1 | [VirtualBox VBoxManage reference](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/vboxmanage.html) | clonevm: mode, basefolder, register, Link and Keep options; modifyvm; showvminfo; storagectl; storageattach; createmedium |
| C2 | [Oracle Linux 9: Clone Existing KVM Instance](https://docs.oracle.com/en/operating-systems/oracle-linux/9/kvm-user/kvm-CloningVirtualMachines.html) | Prepare KVM for Cloning: Manually — network identity, SSH host keys, other unique identifiers, hostname; these are guest preparation principles, not instructions to install KVM |
| C3 | [OL9: Creating a keyfile Connection Profile Using nmcli](https://docs.oracle.com/en/operating-systems/oracle-linux/9/network/network-CreateKeyfileConnectionProfile-nmcli.html) | Device inspection, connection creation, activation, verification; referenced nmcli(1) manual |
| C4 | [OCNE 1.9 Host Requirements](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/hosts.html) | OS Requirements, Table 1-1; role-specific storage/RAM requirements |
| C5 | [OL9: Creating and Mounting an XFS File System](https://docs.oracle.com/en/operating-systems/oracle-linux/9/xfs/xfs-CreatinganXFSFileSystem.html) | Identify the device; mkfs.xfs; mount; xfs_info |
| C6 | [OL9: Managing the File System Mount Table](https://docs.oracle.com/en/operating-systems/oracle-linux/9/fsadmin/fsadmin-AbouttheFileSystemMountTable.html) | UUID-based persistent mounts; /etc/fstab |
| C7 | Oracle Linux installed system manuals: machine-id(5), systemd-machine-id-setup(1), ssh-keygen(1), hostnamectl(1), nmcli(1) | OS command semantics used for unique clone identities; see section 7 |

C2 covers KVM, not VirtualBox. Only its Linux guest preparation guidance is applied here; VirtualBox cloning itself uses C1. This distinction is deliberate. The shell guards, host naming, directory paths, script numbering, and resource allocations are this lab's implementation, not verbatim Oracle requirements.


### 1a.2 Inspect the golden VM and choose the source

### 4. Inspect the golden VM before cloning

**Run inside the golden VM, read-only. Sources C2 and C4; inspection commands are local checks.**

```bash
cat /etc/oracle-release
uname -r
hostnamectl
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS
findmnt -T /var
findmnt -T /var/lib/containers
df -hT / /var
id
id labadmin
sudo pvs
sudo vgs
sudo lvs
nmcli device status
nmcli connection show
rpm -qa | sort | grep -E '^(olcne|kubelet|kubeadm|cri-o|cloud-init|openssh-server|NetworkManager)'
sudo ls -ld /etc/kubernetes /var/lib/kubelet /var/lib/etcd /etc/olcne /etc/sysconfig/rhn/systemid 2>/dev/null
sudo systemctl is-enabled cloud-init.service
```

Missing `labadmin`, absent directories, an uninstalled LVM tool, or a missing cloud-init service may produce nonzero results in this inspection block. Read the outputs; absence is different from a command failing unexpectedly.

Check these conditions before choosing this template:

- Oracle Linux 9 and the selected UEK R7 branch meet C4. A newer kernel is not automatically equivalent to UEK R7.
- It is an OS baseline, without an existing Kubernetes cluster, etcd/kubelet state, deployed OCNE certificates, database/ASM disks, or application-specific registrations needing a separate cleanup procedure. Package presence alone does not prove cluster membership; inspect it.
- You have a working local console login and sudo access. Clones initially have no network connection.
- `/var` has capacity for every target role: Oracle lists 40 GB for control plane and 15 GB for operator/workers. Check actual free space as well as filesystem capacity. A 40 GB virtual disk does not by itself satisfy 40 GB in `/var`.
- The worker must have a dedicated XFS mount at `/var/lib/containers`. Section 10 provides a new blank disk if it does not already have one.
- Any cloud-init, ULN registration, configuration-management agent, or first-boot automation has been reviewed. A template that automatically restores its old hostname/network or registration requires preparation before this manual path. This guide does not automatically disable unknown software or unregister a source VM.

If the OS or /var capacity fails the requirement, resolve the observed mismatch before OCNE installation. For this source, OS/kernel checks passed and storage was enlarged only on independent clones. See section 9.1; do not guess resize commands or modify the golden disk.

In Windows PowerShell:

```powershell
Set-Location D:\OCNE19-Lab
.\scripts\00-Inspect-Host.ps1
$VBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
& $VBox list vms
$GoldenVM = Read-Host 'Enter the EXACT golden VM name from the list'
& $VBox showvminfo $GoldenVM
& $VBox showvminfo $GoldenVM --machinereadable
```

The current wrapper expects one boot disk on **SATA port 0/device 0**, an existing adapter 1 and no extra attached media. It accepts an inspected accessible normal snapshot chain for full current-state cloning. Machine/transient host shares remain rejected; the observed global Downloads mapping requires the explicit reviewed exception below. Empty optical drives are allowed. Review other layouts before adapting the script.

Review the source for encrypted disks, snapshots, extra NICs, shared folders, and external disk dependencies. The script turns off extra adapters on clones and preserves the existing boot firmware/controller. It does not claim to handle every specialized template.

Once inspection is complete, shut down the golden VM from inside it:

```bash
sudo shutdown -h now
```

Wait until VirtualBox reports **Powered Off**, not Saved. Keep it powered off during cloning. If an ISO is mounted, detach that optical medium through VirtualBox settings; do not detach the boot disk.

## 1b. Setting up the OCNE lab

Run the following sequence only for a new lab. Sections 5-10 below retain the cloning guide's step numbers so source references remain easy to cross-check. This is the **cloning workflow**: do not run fresh-ISO scripts 02 or 03.

### 5. Create or verify the lab network

**Run on Windows. Source C1 → natnetwork.**

```powershell
Set-Location D:\OCNE19-Lab
& $VBox list natnetworks
Get-NetRoute -AddressFamily IPv4 |
    Select-Object DestinationPrefix, NextHop, InterfaceAlias
```

Confirm `192.168.77.0/24` does not overlap your LAN/VPN. If `ocne19-net` is absent, create it using the supplied script:

```powershell
.\scripts\01-Create-Network.ps1
```

If it already exists, inspect it instead of recreating it. It must have the documented subnet, DHCP disabled, and loopback SSH forwarding 2220/2221/2222/2223 to .10/.11/.12/.13 port 22. The clone script verifies the network name, not every rule; you must review the actual network output.

For an existing matching network that is stopped:

```powershell
& $VBox natnetwork start --netname ocne19-net
```

### 6. Create the four full clones

**Run on Windows. Source C1 → VBoxManage clonevm and modifyvm.**

For the inspected source (ol9-golden), these were the reviewed options. Recheck the snapshot chain and global Downloads share before future use. Do not blindly approve another mapping. Existing destinations cause a stop and must be inspected, not deleted. First perform the script's read-only preflight:

```powershell
.\scripts\06-Clone-Golden-VM.ps1 -GoldenVM $GoldenVM -ReviewedGlobalShare Downloads -BootDiskMB 102400
```

After reviewing its output and completing section 4:

```powershell
.\scripts\06-Clone-Golden-VM.ps1 -GoldenVM $GoldenVM -ReviewedGlobalShare Downloads -BootDiskMB 102400 -Create
```

The script uses `clonevm --mode machine --register --basefolder`, without `Link`, `KeepAllMACs`, or `KeepHwUUIDs`. It clones the current state without copying snapshot history. Each clone has independent virtual disks, new VirtualBox identities, and its assigned RAM/CPU. The new machines remain powered off with adapter 1's cable disconnected and any extra adapters disabled.

The source VM is not modified by the script. It never deletes an existing destination; if a command fails partway through, inspect the partially created VMs instead of rerunning creation or deleting them.

Check all four registrations and their MAC/VM identities:

```powershell
& $VBox list vms
foreach ($Name in @('ocne-op','ocne-cp','ocne-w1','ocne-w2')) {
    & $VBox showvminfo $Name --machinereadable |
        Select-String '^(name|UUID|hardwareuuid|memory|cpus|nic1|macaddress1|cableconnected1)='
}
```

Expect 4096, 8192, 22528, 22528 MiB. All four MAC addresses and VM UUIDs must differ. Cloning does not change Linux hostnames, static IPs, machine IDs, or SSH host keys; the next sections do that.

### 7. Prepare each clone while its network is disconnected

The manual sections 7–9 explain one-time preparation. The recorded run used `Prepare-Clone-Identity.sh` through disconnected consoles and a nonbootable preparation ISO; **do not also perform manual resets after using that helper**. Its UUID/MAC guards are specific to these clones, including observed SMBIOS UUID byte-order representations. See [Script reference](SCRIPT-REFERENCE.md).

For a separately reviewed manual build, repeat sections 7–9 for **one clone at a time**. Use its VirtualBox console window, not SSH. Check the window title so you do not run these commands on the golden VM.

On Windows, start the first clone:

```powershell
& $VBox startvm ocne-op --type gui
```

Log in using the golden VM's existing administrator account and password. Subsequent clones use `ocne-cp`, `ocne-w1`, and `ocne-w2` in the same start command.

#### 7.1 Select the clone identity

**Sources C2 → change hostname / remove unique settings; C7 → hostnamectl(1).**

Run this prompt block in the clone console. Enter the name shown in the VM window:

```bash
read -r -p 'This clone name (ocne-op / ocne-cp / ocne-w1 / ocne-w2): ' LAB_NODE
case "$LAB_NODE" in
  ocne-op) LAB_IP=192.168.77.10 ;;
  ocne-cp) LAB_IP=192.168.77.11 ;;
  ocne-w1) LAB_IP=192.168.77.12 ;;
  ocne-w2) LAB_IP=192.168.77.13 ;;
  *) echo 'Invalid clone name. Stop and repeat this block.'; LAB_IP='' ;;
esac
if [ -n "$LAB_IP" ]; then
  sudo hostnamectl set-hostname "$LAB_NODE.lab.test"
  printf 'Clone %s will use %s\n' "$LAB_NODE" "$LAB_IP"
fi
```

Verify the chosen identity before continuing:

```bash
hostnamectl --static
```

#### 7.2 Replace copied host identities and reboot

**Source C2 → manual preparation, SSH key removal and other unique identifiers. Command references: C7, the Oracle Linux `machine-id(5)` and `ssh-keygen(1)` manuals.** Machine IDs must be unique. The upstream systemd explanation of the same mechanism is [Building Images Safely → Resources to Reset](https://systemd.io/BUILDING_IMAGES/); this supplements the OS manual, not OCNE installation instructions.

Record the old ID for comparison. Stop SSH, remove the clone's copied host keys, and reset its machine ID for the next boot. The network cable must still be disconnected.

```bash
sudo bash <<'CLONE_IDENTITIES'
set -euo pipefail
case "$(hostname -s)" in
  ocne-op|ocne-cp|ocne-w1|ocne-w2) ;;
  *) echo 'Expected a named clone. Stop.'; exit 1 ;;
esac
if [ -e /root/ocne-clone-identity-reset ]; then
  echo 'Identity reset was already requested; verify it instead of repeating.'; exit 1
fi
cp /etc/machine-id /root/ocne-template-machine-id
systemctl stop sshd
rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub
# Empty machine-id is initialized on the next boot. Remove the copied D-Bus fallback too.
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
touch /root/ocne-clone-identity-reset
sync
systemctl reboot
CLONE_IDENTITIES
```

After reboot, log in again through the console. Shell variables from before the reboot are gone; later steps derive the node name again.

```bash
hostnamectl --static
cat /etc/machine-id
sudo cat /root/ocne-template-machine-id
sudo ssh-keygen -A
sudo systemctl enable --now sshd
sudo ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub
```

The new machine ID must differ from the copied ID. Across the four clones, machine IDs and SSH host-key fingerprints must all differ. `ssh-keygen -A` generates missing host keys; it does not generate a user login key. In a template with a custom host-key type or a FIPS policy, inspect `sshd -T` and fingerprint the configured host key instead of assuming Ed25519 exists.

Do not regenerate host identities again after the machine has been deployed. The old ID recorded in `/root` is for verification only; never copy SSH private host keys into Git.

### 8. Configure the clone's account, network, and name resolution

#### 8.1 Keep a consistent installation account

The main guide uses `labadmin`. If the golden VM already has it, keep it and confirm sudo works:

```bash
id labadmin
sudo -v
```

If it is absent, use the same existing administrator consistently in the OCNE guide, or create `labadmin` on each clone with Oracle Linux's standard account tools. To retain the supplied guide's account name, inspect existing UIDs/GIDs first with `getent passwd 1001` and `getent group 1001` on all clones. This run found 1001 unused and selected it consistently. If either ID is occupied, investigate instead of reusing or renumbering it. For that verified branch:

```bash
# Use 1001 only after confirming both IDs are unused on every clone.
sudo groupadd -g 1001 labadmin
sudo useradd -m -u 1001 -g labadmin -G wheel labadmin
sudo passwd labadmin
id labadmin
```

Run the creation commands only when `id labadmin` showed that the user was absent. Use a password interactively, not in a script or Git file. Confirm `labadmin` can log in locally and use sudo. Compare its numeric UID and primary GID across all four clones; NFS later relies on matching identities. Do not add blanket passwordless sudo. Reference: the Oracle Linux `useradd(8)`, `passwd(1)`, and `sudo(8)` manuals; the installation account is a local provisioning choice.

#### 8.2 Configure a new static network profile

**Source C3 and its referenced nmcli(1) manual.** Remain in the clone console. First identify the actual Ethernet interface and inherited connection profiles:

```bash
nmcli device status
nmcli -f NAME,UUID,TYPE,DEVICE connection show
ip -br link
```

The interface might be `enp0s3`, but do not assume it. Because only adapter 1 is enabled, there should be one lab Ethernet device. If it is unmanaged or multiple unexpected interfaces exist, resolve that observed state first.

For each inherited **Ethernet** profile that could bind to this interface, disable autoconnect by its actual UUID. Repeat only for the relevant copied profiles:

```bash
read -r -p 'Actual inherited Ethernet profile UUID to disable: ' OLD_PROFILE
sudo nmcli connection modify uuid "$OLD_PROFILE" connection.autoconnect no
```

This preserves the old profiles for inspection. Create a new profile with the actual device and reachable DNS IPs. All addressing below is the lab's chosen configuration:

```bash
LAB_NODE=$(hostname -s)
case "$LAB_NODE" in
  ocne-op) LAB_IP=192.168.77.10 ;;
  ocne-cp) LAB_IP=192.168.77.11 ;;
  ocne-w1) LAB_IP=192.168.77.12 ;;
  ocne-w2) LAB_IP=192.168.77.13 ;;
  *) LAB_IP='' ;;
esac
read -r -p 'Actual Ethernet device name from nmcli: ' LAB_IFACE
read -r -p 'Reachable DNS server IPs, separated by spaces: ' LAB_DNS
if [ -z "$LAB_IP" ] || [ -z "$LAB_IFACE" ] || [ -z "$LAB_DNS" ]; then
  echo 'Missing/invalid input. Stop and repeat this block.'
else
  sudo nmcli connection add type ethernet ifname "$LAB_IFACE" \
    con-name ocne-lab ip4 "$LAB_IP/24" gw4 192.168.77.1
  sudo nmcli connection modify ocne-lab \
    ipv4.method manual ipv4.dns "$LAB_DNS" \
    connection.autoconnect yes connection.autoconnect-priority 100
fi
```

Create `ocne-lab` only once. If it already exists, inspect and modify that profile instead of creating duplicate names. A newly created profile avoids the copied MAC-address binding noted in C2. The recorded run used enp0s3 and reachable LAN DNS server 192.168.137.1. Recheck these observed inputs if host networking changes.

#### 8.3 Add lab hostnames

Back up and edit the hosts file, preserving localhost entries and unrelated valid mappings:

```bash
sudo cp -p /etc/hosts /etc/hosts.before-ocne-clone
sudo vi /etc/hosts
```

Remove stale mappings for the golden VM's hostname/IP that would conflict with this clone. Add these four entries once:

```text
192.168.77.10 ocne-op.lab.test ocne-op
192.168.77.11 ocne-cp.lab.test ocne-cp
192.168.77.12 ocne-w1.lab.test ocne-w1
192.168.77.13 ocne-w2.lab.test ocne-w2
```

These are local hostname-resolution inputs for the OCNE guide. They do not require a new DNS server.

### 9. Reconnect only the prepared clone and verify SSH

After identity and network preparation, shut down this clone from its console:

```bash
sudo shutdown -h now
```

Wait for Powered Off. **Run on Windows. Source C1 → modifyvm and startvm.** Persistently reconnect the prepared clone's adapter, then start it. Set `$CloneName` to the clone you just prepared:

```powershell
$CloneName = Read-Host 'Prepared clone name'
if ($CloneName -notin @('ocne-op','ocne-cp','ocne-w1','ocne-w2')) {
    throw 'Unexpected clone name'
}
& $VBox modifyvm $CloneName --cableconnected1 on
& $VBox startvm $CloneName --type gui
```

Inside that clone's console, activate the new profile immediately:

```bash
sudo nmcli connection up ocne-lab
ip -br address
ip route
getent hosts ocne-op.lab.test ocne-cp.lab.test ocne-w1.lab.test ocne-w2.lab.test
sudo systemctl status sshd --no-pager
```

Confirm there is only the intended lab IPv4 on the interface and the default route uses `.1`. If the old profile activated, bring it down by its UUID and reactivate `ocne-lab` from the console.

Check SSH access through the active firewalld zone. **Source:** [Oracle Linux: Configuring firewalld Zones → Controlling Access to Services](https://docs.oracle.com/en/operating-systems/oracle-linux/9/firewall/firewall-ConfiguringfirewalldZones.html). Inspect before changing it:

```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --get-default-zone
```

If that zone does not already allow SSH, use the actual lab-interface zone:

```bash
read -r -p 'Actual firewalld zone for the lab interface: ' LAB_ZONE
sudo firewall-cmd --zone="$LAB_ZONE" --add-service=ssh
sudo firewall-cmd --permanent --zone="$LAB_ZONE" --add-service=ssh
```

This permits host access; later OCNE firewall rules still come from Part B. Keep SELinux enabled. If the template does not have firewalld or OpenSSH installed, stop and complete the documented host baseline before treating it as ready.

In Windows, use the matching command:

```powershell
ssh -p 2220 labadmin@127.0.0.1
# Control plane after preparing it:
ssh -p 2221 labadmin@127.0.0.1
# Worker 1 after preparing it:
ssh -p 2222 labadmin@127.0.0.1
# Worker 2 after preparing it:
ssh -p 2223 labadmin@127.0.0.1
```

At first connection, compare the displayed SSH fingerprint to the one recorded in that VM's console. Do not bypass host-key checking. If a port was used by an older lab, verify the new identity before removing that specific stale known_hosts entry.

Once all four hosts are prepared, verify reachability from the operator:

```bash
for node in ocne-cp.lab.test ocne-w1.lab.test ocne-w2.lab.test; do
  ssh "labadmin@$node" 'hostname; cat /etc/machine-id; uname -r'
done
```

This initial check can use passwords if permitted by the template's SSH policy. The original guide's B7 configures the operator's user-key SSH access; do not copy the golden VM's private login keys to establish it.

#### 9.1 Grow the clone root before OCNE prerequisites

The recorded clones have 100 GiB VDIs, but initially inherited the source's 40 GiB partition layout. Expanding the VDI alone does not expand /var.

Inspect each clone using lsblk, findmnt, blkid and the partition table. This run verified plain XFS on partition 2, start sector 2099200, original size 79691776 sectors, inherited root UUID 7ca3aaf4-86fd-4ec7-83f8-1e7e18f27651, and a 107374182400-byte independent parent disk. These are recorded values, not defaults for another source.

The reviewed [Grow-Clone-Root.sh](../scripts/Grow-Clone-Root.sh) checked those values, saved the partition table, ran growpart in dry-run mode, grew partition 2 without changing its start, then ran xfs_growfs on the mounted root. It verified at least 40 GiB available under /var afterward. Final root size was approximately 99 GiB on all four clones. Never shrink, recreate or move the root partition; do not use this helper to repair an unknown layout.

These are local provisioning steps. Sources: [Oracle's growpart/XFS expansion example](https://docs.oracle.com/en/database/other-databases/essbase/19.3/essad/resize-block-storage-volumes.html) (only the Linux expansion operations apply), [OL9 Growing an XFS File System](https://docs.oracle.com/en/operating-systems/oracle-linux/9/xfs/xfs-GrowinganXFSFileSystem.html), and C1 modifymedium. Verify growth before Part B.

#### 9.2 Completed Windows and guest SSH integration

The later user-requested workstation and all-node key access is documented in [SSH access](SSH-ACCESS.md). Windows hosts maps the actual .10–.13 guest addresses; SSH aliases separately select loopback NAT forwards with pinned host keys. Hosts entries alone do not create a route. Every guest keeps its own private key; only public keys were exchanged. Password-required sudo remains.

### 10. Provide dedicated XFS container storage on each worker

**Sources C4 → Worker Node Hardware; C5 and C6.** Do this before installing OCNE/CRI-O or pulling container images.

Inspect each worker:

```bash
findmnt -M /var/lib/containers
findmnt -T /var/lib/containers
sudo ls -la /var/lib/containers
```

If a suitable dedicated XFS filesystem is already mounted there, keep it and skip adding/formatting another disk. `findmnt -T` showing `/` or `/var` alone does not prove a dedicated mount exists.

In the recorded run, Podman left only empty sigstore/storage/tmp scaffolding. [Prepare-Worker-XFS.sh](../scripts/Prepare-Worker-XFS.sh) rejected other content, preserved the directories in /var/lib/containers.before-ocne-xfs and copied metadata onto the new filesystem before relabeling. It selected each disk by its observed VBox serial and required a blank whole 100 GiB device. The inline block below is the alternative strictly-empty-directory branch; do not run both.

If the path contains existing container data, do not hide it with a mount or delete it. This guide's new disk branch requires an empty/absent target on a clean clone. For each worker that needs a disk, shut it down cleanly:

```bash
sudo shutdown -h now
```

Run the matching Windows command only after that worker is Powered Off:

```powershell
.\scripts\07-Add-Worker-Container-Disk.ps1 -VMName ocne-w1
.\scripts\07-Add-Worker-Container-Disk.ps1 -VMName ocne-w2
```

Each invocation attaches one blank 100 GiB VDI at SATA port 2. Restart each worker through VirtualBox Manager. Reconnect through SSH or its console.

Inspect disks and explicitly identify the new disk. **Never infer its name from this document; the OS disk may also be 100 GiB.**

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ls -l /dev/disk/by-id/
```

Run once on each worker requiring the new mount:

```bash
read -r -p 'Actual NEW blank container disk path: ' CONTAINER_DISK
sudo bash -s -- "$CONTAINER_DISK" <<'WORKER_XFS'
set -euo pipefail
case "$(hostname -s)" in
  ocne-w1|ocne-w2) ;;
  *) echo 'This step is for a worker only'; exit 1 ;;
esac
disk=$(readlink -f -- "$1")
[[ -b "$disk" ]] || { echo 'Not a block device'; exit 1; }
[[ $(lsblk -dn -o TYPE "$disk") == disk ]] || { echo 'Not a whole disk'; exit 1; }
[[ $(blockdev --getsize64 "$disk") == 107374182400 ]] || { echo 'Expected new 100 GiB disk'; exit 1; }
[[ $(lsblk -nr -o NAME "$disk" | wc -l) -eq 1 ]] || { echo 'Disk has child devices'; exit 1; }
[[ -z $(lsblk -nr -o MOUNTPOINTS "$disk" | tr -d '[:space:]') ]] || { echo 'Disk is mounted'; exit 1; }
signatures=$(wipefs -n --noheadings "$disk")
[[ -z "$signatures" ]] || { echo 'Disk has existing signatures'; exit 1; }
target=/var/lib/containers
if mountpoint -q "$target" || grep -Eq '^[^#]*[[:space:]]/var/lib/containers[[:space:]]' /etc/fstab; then
    echo 'Existing container mount/configuration; inspect it'; exit 1
fi
if [[ -d "$target" ]] && [[ -n $(ls -A "$target") ]]; then
    echo 'Container directory is not empty; stop'; exit 1
fi
mkfs.xfs "$disk"
uuid=$(blkid -s UUID -o value "$disk")
[[ -n "$uuid" ]]
mkdir -p "$target"
cp -p /etc/fstab "/etc/fstab.before-container-disk-$(date +%Y%m%d%H%M%S)"
printf 'UUID=%s %s xfs defaults 0 0\n' "$uuid" "$target" >> /etc/fstab
systemctl daemon-reload
mount "$target"
mountpoint -q "$target"
restorecon -v "$target"
xfs_info "$target"
WORKER_XFS
```

The device guard and UUID insertion are local wrappers around Oracle's documented format/mount procedure. `restorecon` applies the installed SELinux policy's default label to the mount root; do not disable SELinux. The `restorecon(8)` manual documents this command.

Verify:

```bash
findmnt -M /var/lib/containers
df -hT /var /var/lib/containers
```

The container disk belongs to that worker alone. It is not a shared ASM disk and is not the NFS share.

### 1b.11 Root growth when the inspected source needs it

If the clone's root is XFS on a plain partition at the end of its boot disk, the following manual procedure explains the growth used here. If it is LVM, encrypted, another filesystem, or not the last partition, stop and use the matching storage procedure. This block is **clone only**, after VBox has enlarged its independent VDI to 100 GiB.

Run as root inside one clone at a time:

```bash
set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
rootdev=$(findmnt -nro SOURCE /)
test "$(findmnt -nro FSTYPE /)" = xfs
part=${rootdev##*/}
test -r "/sys/class/block/$part/partition"
number=$(cat "/sys/class/block/$part/partition")
disk=/dev/$(lsblk -dnro PKNAME "$rootdev")
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$disk"
parted -s "$disk" unit s print free
# Inspect the printed map: root must be the final partition followed by free space.
read -r -p 'Enter the verified clone boot disk serial: ' expected_serial
test -n "$expected_serial"
test "$(lsblk -dnro SERIAL "$disk" | xargs)" = "$expected_serial"
test "$(blockdev --getsize64 "$disk")" = 107374182400
before_uuid=$(blkid -s UUID -o value "$rootdev")
before_start=$(cat "/sys/class/block/$part/start")
dnf install -y cloud-utils-growpart
backup="/root/clone-root-$(date -u +%Y%m%dT%H%M%SZ).sfdisk"
sfdisk --dump "$disk" > "$backup"
chmod 600 "$backup"
growpart -N "$disk" "$number"
# Review the dry run before proceeding to these commands:
growpart "$disk" "$number"
udevadm settle
test "$(cat "/sys/class/block/$part/start")" = "$before_start"
test "$(blkid -s UUID -o value "$rootdev")" = "$before_uuid"
xfs_growfs -d /
df -hT / /var
```

Expected: unchanged start sector and filesystem UUID, expanded XFS, enough /var capacity/free space for the chosen role. If growpart says NOCHANGE, inspect existing geometry rather than rerunning blindly.

### 1b.12 Workstation and guest SSH without login passwords

Create one workstation key under ignored private/, then install **only its public key** on all four guests. Passphrase-protected keys can use an SSH agent; an unencrypted lab key needs restrictive Windows ACLs. Verify the guest host fingerprint at its console before accepting the first SSH connection.

Windows PowerShell, project root:

```powershell
New-Item -ItemType Directory -Force .\private | Out-Null
ssh-keygen -t ed25519 -f D:\OCNE19-Lab\private\workstation_ed25519 -C ocne-workstation
$LabPorts = @(2220,2221,2222,2223)
foreach ($Port in $LabPorts) {
    Get-Content .\private\workstation_ed25519.pub | ssh -p $Port labadmin@127.0.0.1 'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
}
```

For a fresh project, place this pattern in the Windows user's `.ssh/config`, with one block per guest; preserve unrelated entries. Use absolute key paths, and verify permissions with `icacls` if OpenSSH reports bad owner/permissions.

```sshconfig
Host ocne-op ocne-op.lab.test
    HostName 127.0.0.1
    Port 2220
    User labadmin
    IdentityFile D:/OCNE19-Lab/private/workstation_ed25519
    IdentitiesOnly yes
Host ocne-cp ocne-cp.lab.test
    HostName 127.0.0.1
    Port 2221
    User labadmin
    IdentityFile D:/OCNE19-Lab/private/workstation_ed25519
    IdentitiesOnly yes
Host ocne-w1 ocne-w1.lab.test
    HostName 127.0.0.1
    Port 2222
    User labadmin
    IdentityFile D:/OCNE19-Lab/private/workstation_ed25519
    IdentitiesOnly yes
Host ocne-w2 ocne-w2.lab.test
    HostName 127.0.0.1
    Port 2223
    User labadmin
    IdentityFile D:/OCNE19-Lab/private/workstation_ed25519
    IdentitiesOnly yes
```

Windows hosts entries should contain the **actual guest IPs**, not 127.0.0.1. From an elevated PowerShell, inspect the existing file, back it up, and edit only conflicting lab entries. The reviewed `Update-Windows-Lab-Hosts.ps1` automates this project-specific update. Manual edit:

```powershell
$HostsFile = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
Get-Content $HostsFile
Copy-Item -LiteralPath $HostsFile -Destination (Join-Path (Get-Location) ('logs\hosts-before-' + (Get-Date -Format yyyyMMddHHmmss) + '.txt'))
notepad.exe $HostsFile
```

Add the four mapping lines shown in section 8.3 once. Hosts entries resolve names; VirtualBox NAT still needs the SSH loopback forwards above. Test each alias:

```powershell
foreach ($Node in @('ocne-op','ocne-cp','ocne-w1','ocne-w2')) {
    ssh -o BatchMode=yes $Node 'hostname -f; id -un'
    if ($LASTEXITCODE -ne 0) { throw "SSH verification failed: $Node" }
}
```

Equivalent public-key installation in Git Bash:

```bash
for port in 2220 2221 2222 2223; do
  ssh-copy-id -i private/workstation_ed25519.pub -p "$port" labadmin@127.0.0.1
done
```

On **each guest as labadmin**, create a unique user key only if absent, install its public key on all four nodes, and verify the mesh. First connections require matching each console fingerprint; ssh-copy-id prompts for the destination account password during this one-time setup.

```bash
test -e ~/.ssh/id_rsa || ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
  ssh-copy-id -i ~/.ssh/id_rsa.pub "labadmin@$node.lab.test"
done
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
  ssh -o BatchMode=yes "$node.lab.test" 'hostname -f; id -un' || break
done
```

Passwordless SSH does not imply passwordless sudo. Never copy private keys between guests. The certificate-copy privilege issue is addressed before B10 below.

### 1b.13 Install OCNE through Oracle's full procedure

The following B/C/D sections are reproduced from the sourced installation guide, **excluding its fresh-ISO Part A**. Keep the section source IDs below; local names are explicit substitutions. Complete each verification before moving on.

## Source map

| ID | Oracle source | Sections used |
|---|---|---|
| S1 | [Host Requirements](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/hosts.html) | Role hardware requirements; OS Requirements |
| S2 | [Prerequisites](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html) | OL9 repositories; time; swap; agent access; non-HA firewall; OL9 nftables; bridge networking; SSH |
| S3 | [Installing Oracle Cloud Native Environment](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html) | Operator/agent packages; certificates; starting services |
| S4 | [Creating an Environment](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/env-create.html) | Creating an Environment using Certificates |
| S5 | [Creating a Kubernetes Cluster](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/deploy-kube-intro.html) | Single control plane; validate; install; report |
| S6 | [Setting up kubectl](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/kubectl-intro.html) | Setting up kubectl on a Control Plane Node |
| S7 | [Using Kubernetes](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/kube-using.html) | Getting Information about Nodes |
| V1 | [VirtualBox networking](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/networkingdetails.html) | NAT Network Service |
| V2 | [VBoxManage reference](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/vboxmanage.html) | VM, disk, storage, and network commands |
| N1 | [OL9: Editing the /etc/exports File](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/editing-exports-file_task.html) | NFS package, exports, identity domain, firewall, service, verification; referenced exports(5) manual |
| N2 | [OL9: Mounting an NFS Share](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/mounting_task.html) | Client package, mount, fstab; referenced nfs(5)/mount(8) manuals |
| N3 | [OL9: Creating and Mounting an XFS File System](https://docs.oracle.com/en/operating-systems/oracle-linux/9/xfs/xfs-CreatinganXFSFileSystem.html) | Device identification, mkfs.xfs, mount, xfs_info |
| N4 | [OL9: Managing the File System Mount Table](https://docs.oracle.com/en/operating-systems/oracle-linux/9/fsadmin/fsadmin-AbouttheFileSystemMountTable.html) | UUID identifiers and persistent filesystem mounts |
| N5 | [OL9: Using the exportfs Command](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/exportfs-command_reference.html) | Refresh and inspect exports |

The section titles above are the navigation pointers if the Oracle site does not position the page at a subsection. S1–S4 are the original Installation book. S5–S7 are its explicitly linked Kubernetes continuation. No Quick Install instructions are used in Part B. N1–N5 are separate Oracle Linux manuals supporting the user-requested NFS addition in Part D, not OCNE prerequisites.

# Part B — Oracle’s full installation procedure

## Substitutions used in Oracle’s examples

| Oracle example/input | Value used in this lab |
|---|---|
| `operator.example.com` | `ocne-op.lab.test` |
| `control1.example.com` | `ocne-cp.lab.test` |
| `worker1.example.com` | `ocne-w1.lab.test` |
| `worker2.example.com` | `ocne-w2.lab.test` |
| Installation username, e.g. `oracle` | `labadmin` |
| `myenvironment` | `homelab` |
| `mycluster` | `cluster1` |
| Platform API endpoint | `ocne-op.lab.test:8091` |
| ExternalIPs certificate directory | `$HOME/certificates/restrict_external_ip/`, the path recommended by S3’s certificate-generation subsection |

The service account `olcne` is created by packages. It is not the interactive installation user. All `olcnectl` commands below run as `labadmin` on the operator, except where another host is explicitly named. Do not combine these steps with the earlier `olcnectl provision` walkthrough on the same nodes.

## B1. Enable Oracle Linux 9 package repositories

**Observed package resolution:** the oracle-olcne-release-el9 request resolved to oracle-ocne-release-el9 1.0-7. Enabled repository ol9_olcne19 supplied platform 1.9.6. Verify actual packages/repository IDs rather than inferring the OCNE stream from the release-package name. Preserve UEK R7.

**Run on:** all four VMs.  
**Source:** [S2 — Enabling Access to the Software Packages → Oracle Linux 9 → Enabling Repositories with the Oracle Linux Yum Server](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

```bash
sudo dnf install oracle-olcne-release-el9

sudo dnf config-manager --enable ol9_olcne19 ol9_addons ol9_baseos_latest ol9_appstream ol9_UEKR7

sudo dnf config-manager --disable ol9_olcne18 ol9_olcne17

sudo dnf repolist --enabled | grep developer
```

If developer repositories are listed, disable those IDs. Oracle provides this example:

```bash
sudo dnf config-manager --disable ol9_developer
```

Apply it to the actual returned repository IDs, including `ol9_developer_EPEL` if present. Oracle also says software from developer/EPEL repositories must not be installed on the Kubernetes nodes. Merely disabling a repository does not remove packages already installed from it.

This is the UEK R7 branch. If hosts run RHCK instead, S2’s RHCK command omits `ol9_UEKR7`; use that branch consistently rather than mixing kernel assumptions. If `dnf config-manager` is missing, the host is not ready for the documented command; resolve the missing OS tooling using Oracle Linux documentation before proceeding. This revision does not insert an undocumented package-install workaround into the OCNE sequence.

## B2. Confirm time synchronization and registry access

**Applies to:** all hosts; the time requirement specifically covers control-plane and worker nodes.  
**Source:** [S2 — Setting up a Network Time Service; Accessing the Oracle Container Registry; Internet Access](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

Oracle requires synchronized node time and recommends chronyd; it states chronyd is enabled and started by default on Oracle Linux. Ensure your host installation has working time synchronization before certificate generation. This section of the manual gives requirements rather than a copy/paste chrony configuration, so none is invented here.

For this branch, every node needs access to Oracle’s registry. The module will use `container-registry.oracle.com/olcne`. If access requires a proxy or a registry mirror, use the corresponding sections in S2 and S3; the commands later in this guide assume direct access without a proxy.

## B3. Disable swap on Kubernetes nodes

**Run on:** `ocne-cp`, `ocne-w1`, `ocne-w2`.  
**Source:** [S2 — Setting up the OS → Disabling Swap](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

```bash
sudo swapoff -a
sudo cat /etc/fstab
sudo cp /etc/fstab /etc/fstab_copy
sudo sed -i '/\bswap\b/s/^/#/' /etc/fstab
sudo cat /etc/fstab
```

Inspect the before/after file contents as Oracle instructs. Preserve an existing backup if you are revisiting this step. This requirement is for Kubernetes control-plane and worker nodes; the separate operator is not assigned a Kubernetes role in this topology.

## B4. Configure the non-HA firewall rules

**Source:** [S2 — Setting up the Network → Setting up the Firewall Rules → Non-HA Cluster Firewall Rules](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

This branch keeps the default Oracle Linux firewalld service and uses Flannel. An external firewall, if present, must also allow the documented node-to-node traffic. Do not substitute Calico while retaining this procedure; Oracle documents different Calico prerequisites.

**On `ocne-op`:**

```bash
sudo firewall-cmd --add-port=8091/tcp --permanent
sudo systemctl restart firewalld.service
```

**On each worker, `ocne-w1` and `ocne-w2`:**

```bash
sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
sudo firewall-cmd --add-port=8090/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent
sudo firewall-cmd --add-port=10255/tcp --permanent
sudo firewall-cmd --add-port=8472/udp --permanent
sudo systemctl restart firewalld.service
```

**On `ocne-cp`:**

```bash
sudo firewall-cmd --zone=trusted --add-interface=cni0 --permanent
sudo firewall-cmd --add-port=8090/tcp --permanent
sudo firewall-cmd --add-port=10250/tcp --permanent
sudo firewall-cmd --add-port=10255/tcp --permanent
sudo firewall-cmd --add-port=8472/udp --permanent
sudo firewall-cmd --add-port=6443/tcp --permanent
sudo systemctl restart firewalld.service
```

Port 10255 is included because it is explicitly in Oracle’s non-HA instructions; this guide has not silently edited that port list. The HA-only ports and load-balancer steps are not applicable to this single-control-plane branch.

## B5. Add Oracle’s persistent OL9 nftables rule

**Run on:** `ocne-cp`, `ocne-w1`, `ocne-w2`.  
**Source:** [S2 — Setting up Other Network Options → nftables Rule on Oracle Linux 9](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

Oracle requires this when using OL9 with firewalld and recommends persistence across reboots. These are the rule and service from that section. They assume the referenced paths and firewalld chain exist; if a command fails, stop and inspect the mismatch rather than silently changing the rule.

```bash
sudo sh -c "cat > /etc/nftables/forward-policies.nft << EOF
flush chain inet firewalld filter_FORWARD_POLICIES_post

table inet firewalld {
        chain filter_FORWARD_POLICIES_post {
                accept
        }
}
EOF"
```

```bash
sudo sh -c "cat > /etc/systemd/system/forward-policies.service << EOF
[Unit]
Description=Idempotent nftables rules for forward-policies
PartOf=firewalld.service

[Service]
ExecStart=/sbin/nft -f /etc/nftables/forward-policies.nft
ExecReload=/sbin/nft -f /etc/nftables/forward-policies.nft
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF"
```

```bash
sudo systemctl enable forward-policies.service
sudo systemctl restart forward-policies.service
```

The recorded service successfully applied the rule and auto-restarted every 10 seconds, matching Restart=always. Verify Result/exit status and the actual accept rule after reboot; a restarting substate alone is not proof of failure. See [Troubleshooting](TROUBLESHOOTING.md).

## B6. Check bridge networking prerequisites

**Run on:** control plane and workers.  
**Source:** [S2 — Flannel Network; br_netfilter Module; Bridge Tunable Parameters](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

Check the module:

```bash
sudo lsmod|grep br_netfilter
```

If it is not loaded, Oracle supplies these commands:

```bash
sudo modprobe br_netfilter
sudo sh -c 'echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf'
```

Oracle states the kubeadm package creates `/etc/sysctl.d/k8s.conf` with the following values. This block is a reference, not a shell command to run now:

```text
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
```

Only if you change that file or create equivalent configuration, Oracle instructs you to reload it:

```bash
sudo /sbin/sysctl -p /etc/sysctl.d/k8s.conf
```

Do not run the conditional reload before the file exists. This guide does not install kubeadm independently; module installation handles the Kubernetes packages later.

## B7. Establish SSH key authentication

**Run on:** operator as `labadmin`.  
**Source:** [S2 — Setting Up SSH Key-based Authentication](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/prereq.html).

```bash
ssh-keygen
```

Follow Oracle’s example: accept the key location and leave the passphrase empty for this installation workflow. Do not overwrite an existing key. The subsequent commands assume `~/.ssh/id_rsa`, matching Oracle’s example; use the actual generated path if different.

```bash
ls -l /home/labadmin/.ssh/

ssh-copy-id labadmin@ocne-op.lab.test
ssh-copy-id labadmin@ocne-cp.lab.test
ssh-copy-id labadmin@ocne-w1.lab.test
ssh-copy-id labadmin@ocne-w2.lab.test
```

Enter the target account password when requested. Verify the identity of each host before accepting its SSH key. Test login to each node using the following commands **one at a time**, exiting the remote session before testing the next:

```bash
ssh labadmin@ocne-op.lab.test
ssh labadmin@ocne-cp.lab.test
ssh labadmin@ocne-w1.lab.test
ssh labadmin@ocne-w2.lab.test
```

Authentication should succeed without an account-password prompt. Oracle includes the Platform API Server host among the targets, which is the operator in this layout.

Completed access also includes Windows aliases and a full guest key mesh; see [SSH access](SSH-ACCESS.md). Password-free SSH does not grant noninteractive sudo. Read B10 before certificate distribution.

## B8. Install the platform software by role

**Source:** [S3 — Setting up the Nodes → Setting up the Operator Node / Setting up Kubernetes Nodes](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html).

**On the operator:**

```bash
sudo dnf install olcnectl olcne-api-server olcne-utils
sudo systemctl enable olcne-api-server.service
```

**On the control plane and each worker:**

```bash
sudo dnf install olcne-agent olcne-utils
sudo systemctl enable olcne-agent.service
```

Enable these services now; do not start them before certificate configuration.

On Kubernetes nodes, **only if the respective service is running**, S3 instructs you to stop and disable Docker/containerd:

```bash
sudo systemctl disable --now docker.service
sudo systemctl disable --now containerd.service
```

These are conditional instructions; absent services on a clean host do not need to be installed or created.

**Service-account requirement:** S2 → Configuring Access for the Platform Agent requires the package-created `olcne` user to use sudo without a real tty and to run scripts in `/etc/olcne/scripts` without a password. S3 says not to use that service user for another purpose. Verify the package-provided configuration meets those requirements. Neither section supplies the earlier blanket `labadmin NOPASSWD: ALL` rule, so it is not included. If local policy blocks the documented operations, retain the exact error and resolve that access requirement explicitly.

## B9. Prepare the operator user for certificate management

**Run on:** operator.  
**Source:** [S3 — Setting up Certificates for Kubernetes Nodes → Setting up Private CA Certificates → Distribute Node Certificates](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html).

```bash
sudo usermod -a -G olcne labadmin
```

Log out and log back in as `labadmin` so the new group membership applies. The account-name substitution is the only change to Oracle’s example at this step.

Oracle recommends a secrets manager such as Vault for certificate lifecycle management, and also documents private CA certificates for testing. This walkthrough selects the latter documented branch; these certificates require manual renewal.

## B10. Generate node certificates and copy with interactive sudo

**Run first on ocne-op as labadmin. Source S3: node certificate generation/distribution.** The original automated distribute command generated certificates then failed on noninteractive sudo. This manual alternative uses the same Oracle-generated files and verified destination ownership, with local scp/interactive-sudo transport so the reader does not need blanket passwordless sudo or temporary root SSH. It is a documented manual alternative, not a claim this exact alternative was executed during the original build.

For a **new PKI only**, after confirming no certificates directory exists:

```bash
cd "$HOME"
umask 077
test ! -e "$HOME/certificates"
olcnectl certificates generate --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test --cert-dir "$HOME/certificates"
ls -ld "$HOME/certificates" "$HOME/certificates/ca"
```

If certificates already exist after a failed distribute, **skip generation** and inspect/reuse them. Never regenerate the CA as a transport retry. For each node, verify node.cert against ca/ca.cert before copying:

```bash
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
  openssl verify -CAfile "$HOME/certificates/ca/ca.cert" "$HOME/certificates/$node.lab.test/node.cert"
  openssl x509 -in "$HOME/certificates/$node.lab.test/node.cert" -noout -subject -dates -ext subjectAltName
done
```

Expected: each certificate verifies OK and names/validity match the intended node. Using the already-verified SSH mesh, stage only that node's certificate/key and CA **certificate**, never the CA private key:

```bash
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
  ssh "$node.lab.test" 'umask 077; test ! -e ~/.ocne-cert-stage; mkdir -m 0700 ~/.ocne-cert-stage' || break
  scp "$HOME/certificates/ca/ca.cert" "$HOME/certificates/$node.lab.test/node.cert" "$HOME/certificates/$node.lab.test/node.key" "$node.lab.test:.ocne-cert-stage/" || break
done
```

Inspect completion for all four nodes. If staging exists from a partial run, inspect its hashes/permissions rather than overwriting blindly. **Log into each node as labadmin**, use interactive sudo and run:

```bash
set -euo pipefail
sudo -v
sudo test ! -e /etc/olcne/certificates/node.key
# If a destination already exists, stop and compare it rather than replacing trust.
sudo install -d -o olcne -g olcne -m 0755 /etc/olcne/certificates
sudo install -o olcne -g olcne -m 0600 ~/.ocne-cert-stage/ca.cert /etc/olcne/certificates/ca.cert
sudo install -o olcne -g olcne -m 0600 ~/.ocne-cert-stage/node.cert /etc/olcne/certificates/node.cert
sudo install -o olcne -g olcne -m 0600 ~/.ocne-cert-stage/node.key /etc/olcne/certificates/node.key
sudo restorecon -RF /etc/olcne/certificates
sudo openssl verify -CAfile /etc/olcne/certificates/ca.cert /etc/olcne/certificates/node.cert
sudo stat -c '%a %U:%G %n' /etc/olcne/certificates/ca.cert /etc/olcne/certificates/node.cert /etc/olcne/certificates/node.key
```

Expected metadata matches the executed lab: owner/group olcne:olcne, file modes0600. Verify the public key derived from the private key matches the certificate; these commands display only hashes:

```bash
sudo openssl pkey -in /etc/olcne/certificates/node.key -pubout -outform DER | sha256sum
sudo openssl x509 -in /etc/olcne/certificates/node.cert -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum
```

The hashes must match, and each preceding command must succeed. This is not a dump of private-key contents. After verifying the installed copy, remove only the temporary staging files:

```bash
rm -- ~/.ocne-cert-stage/ca.cert ~/.ocne-cert-stage/node.cert ~/.ocne-cert-stage/node.key
rmdir -- ~/.ocne-cert-stage
```

Keep the protected source PKI on the operator for B11/B12; securely back up its CA key separately. The actual run instead used Oracle certificates copy with temporary restricted root SSH, then removed that access; its detailed historical recovery is included later in this chapter. Do not perform both paths on the same certificates.

## B11. Generate certificates for the CLI-to-API connection

**Run on:** operator as `labadmin`.  
**Source:** [S3 — Setting up Certificates for the Platform CLI to the Platform API Server → Generate Certificates for the Platform CLI to the Platform API Server](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html).

Use the operator’s actual hostname and IP as the documented substitutions:

```bash
olcnectl certificates generate \
  --nodes ocne-op.lab.test,192.168.77.10 \
  --cert-dir $HOME/.olcne/certificates/ocne-op.lab.test:8091/ \
  --byo-ca-cert $HOME/certificates/ca/ca.cert \
  --byo-ca-key $HOME/certificates/ca/ca.key \
  --one-cert

cp $HOME/certificates/ca/ca.cert \
  $HOME/.olcne/certificates/ocne-op.lab.test:8091/
```

The endpoint in B14 uses this same hostname and port so it matches the CLI certificate directory. Do not switch the endpoint to `127.0.0.1:8091` while expecting a hostname-specific directory to be selected automatically.

## B12. Generate the externalIPs service certificates

**Run on:** operator as `labadmin`.  
**Source:** [S3 — Setting up Certificates for the externalIPs Kubernetes Service → Setting up Private CA Certificates → Generate Certificates for ExternalIPs Service](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html).

The service names below are Oracle’s service DNS names. Do not replace them with VM hostnames.

```bash
olcnectl certificates generate \
  --nodes externalip-validation-webhook-service.externalip-validation-system.svc,externalip-validation-webhook-service.externalip-validation-system.svc.cluster.local \
  --cert-dir $HOME/certificates/restrict_external_ip/ \
  --byo-ca-cert $HOME/certificates/ca/ca.cert \
  --byo-ca-key $HOME/certificates/ca/ca.key \
  --one-cert

cp $HOME/certificates/ca/ca.cert $HOME/certificates/restrict_external_ip/
```

S3 recommends the home-directory path in this generation subsection. S5’s module example uses an `/etc/olcne/...` path; C1 substitutes the actual path generated here, as S3 explicitly instructs.

## B13. Start the services using file certificates

**Source:** [S3 — Starting the Platform API Server and Platform Agent Services → Starting the Services Using Certificates](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html).

**On the operator:**

```bash
sudo /etc/olcne/bootstrap-olcne.sh \
  --secret-manager-type file \
  --olcne-component api-server

systemctl status olcne-api-server.service
```

**On the control plane and each worker:**

```bash
sudo /etc/olcne/bootstrap-olcne.sh \
  --secret-manager-type file \
  --olcne-component agent

systemctl status olcne-agent.service
```

These commands use `/etc/olcne/certificates/`, the default node-certificate directory populated in B10. Check that the services are running before creating the environment.

## B14. Create the environment

**Run on:** operator as `labadmin`.  
**Source:** [S4 — Creating an Environment using Certificates](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/env-create.html).

Because B11 configured the CLI’s default certificate directory, use the documented form without explicit key paths:

```bash
olcnectl environment create \
  --api-server ocne-op.lab.test:8091 \
  --environment-name homelab \
  --secret-manager-type file \
  --update-config
```

`--update-config` records the environment connection settings for later CLI calls. Oracle states that a node must not be used in more than one environment.

# Part C — Kubernetes continuation linked by Oracle

## C1. Create the single-control-plane module

**Run on:** operator as `labadmin`.  
**Source:** [S5 — Creating a Kubernetes Module → Creating a Cluster with a Single Control Plane Node](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/deploy-kube-intro.html).

```bash
olcnectl module create \
  --environment-name homelab \
  --module kubernetes --name cluster1 \
  --container-registry container-registry.oracle.com/olcne \
  --control-plane-nodes ocne-cp.lab.test:8090 \
  --worker-nodes ocne-w1.lab.test:8090,ocne-w2.lab.test:8090 \
  --selinux enforcing \
  --restrict-service-externalip-ca-cert $HOME/certificates/restrict_external_ip/ca.cert \
  --restrict-service-externalip-tls-cert $HOME/certificates/restrict_external_ip/node.cert \
  --restrict-service-externalip-tls-key $HOME/certificates/restrict_external_ip/node.key
```

This is Oracle’s single-control-plane command with the substitution table applied. S5 documents Flannel as the default CNI and no load balancer for this topology. It also describes enforcing as the default/recommended OS SELinux mode and requires the corresponding module option when the hosts use it. This guide does not disable SELinux.

## C2. Validate before installing

**Run on:** operator.  
**Source:** S5 → Validating a Kubernetes Module.

```bash
olcnectl module validate \
  --environment-name homelab \
  --name cluster1
```

If validation reports failures, Oracle’s documented way to produce node-specific corrective scripts is:

```bash
olcnectl module validate \
  --environment-name homelab \
  --name cluster1 \
  --generate-scripts
```

Oracle names the generated scripts using `hostname:8090.sh`. Review the generated commands and run each script on its corresponding Linux node, then repeat validation. Do not proceed to installation while validation failures remain. Keep these files on Linux; their colon-containing filenames are not suitable for an ordinary Windows filename.

## C3. Install and report

**Run on:** operator.  
**Source:** S5 → Installing a Kubernetes Module; Reporting Information about the Kubernetes Module.

```bash
olcnectl module install \
  --environment-name homelab \
  --name cluster1
```

After it completes successfully:

```bash
olcnectl module report \
  --environment-name homelab \
  --name cluster1 \
  --children
```

Flannel image downloads took several minutes, and worker2 restarted twice while dependencies initialized. Inspect events, transfer progress and service logs before treating a slow install as stalled; do not launch a second installation. After install/report, continue through C5. See [Troubleshooting](TROUBLESHOOTING.md) for the later report-detail discrepancy.

Oracle describes Kubernetes package installation and starting CRI-O/kubelet as part of module installation. Do not create a parallel cluster using a separate kubeadm installation procedure.

## C4. Configure kubectl on the control plane

**Run on:** `ocne-cp`, as `labadmin`, from the user’s home directory.  
**Source:** [S6 — Setting up kubectl on a Control Plane Node](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/kubectl-intro.html).

```bash
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
export KUBECONFIG=$HOME/.kube/config
echo 'export KUBECONFIG=$HOME/.kube/config' >> $HOME/.bashrc

kubectl get deployments --all-namespaces
```

These are Oracle’s commands. Apply the persistent shell-profile addition once. This configuration gives the user administrative access to the cluster.

## C5. Verify the node state

**Run on:** `ocne-cp`.  
**Source:** [S7 — Getting Information about Nodes](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/kube-using.html).

```bash
kubectl get nodes
```

Expected shape, with actual ages and versions supplied by your installation:

```text
NAME                STATUS   ROLES
ocne-cp.lab.test     Ready    control-plane
ocne-w1.lab.test     Ready    <none>
ocne-w2.lab.test     Ready    <none>
```

Oracle’s example also shows `<none>` for worker roles. The separate operator is not a Kubernetes node in this design. To inspect one worker, substitute its name into Oracle’s documented describe command:

```bash
kubectl describe nodes ocne-w1.lab.test
```

Completion requires successful validation/install, all three nodes Ready, intended deployment replicas available/updated, and **live pod Ready conditions**, not deployment counters alone:

```bash
kubectl get deployments --all-namespaces
kubectl get pods --all-namespaces -o wide
kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=180s
```

These local acceptance checks supplement Oracle's node/report procedure. Verify-Kubernetes-Ready.sh also checks node, deployment and pod JSON; see [Operating the lab](OPERATING-LAB.md). It applies to the original base lab without completed Jobs. Repeat after an ordered power cycle.

At final acceptance, three nodes, 15 pods and all four deployments were Ready/available. The later report returned healthy but contained kernel/firewall details inconsistent with direct guest checks; see [Troubleshooting](TROUBLESHOOTING.md). Do not infer readiness from report status alone. Database Operator, database, ASM and RAC remain separate tasks.

# Part D — Additional 100 GiB NFS server on the operator

This is the user's requested addition. **It is not a requirement or procedure in the OCNE 1.9 Host Requirements page.** It follows Oracle Linux 9's NFS, XFS, and filesystem manuals, identified below. The disk size, paths, addresses, account, and selection of NFSv4.1 are lab inputs. Shell guards and validation checks are local implementation around the documented commands.

| Item | Configuration |
|---|---|
| NFS server | `ocne-op.lab.test` / `192.168.77.10` |
| Additional disk | 100 GiB (102400 MiB), separate from the existing 100 GiB OS disk |
| Windows disk file | `D:\OCNE19-Lab\vms\ocne-op\ocne-op-nfs.vdi` |
| Server filesystem | XFS mounted at `/srv/nfs` |
| Export | `/srv/nfs/share` |
| Allowed hosts | Operator `.10`, control plane `.11`, worker 1 `.12`, worker 2 `.13` |
| Remote client mount | `/mnt/ocne-share` on the control plane and both workers |
| Operator access | Directly through `/srv/nfs/share`, the same underlying files |
| Protocol | NFSv4.1 over the internal VM network |

This is **one shared 100 GiB capacity**, not 100 GiB per client. Filesystem metadata reduces usable space. RAM remains 4/8/22/22 GiB. The operator now performs both OCNE management and NFS service; the existing low-memory exception still applies. All virtual disks together have 700 GiB capacity. Dynamic VDI files grow as written; plan physical Windows storage for growth and snapshots.

Complete Parts A–C first. Add NFS before deploying workloads that need shared files. Do not restart or shut down the operator while clients are actively using NFS. Start the operator before clients; stop clients before the operator.

## D1. Add the dedicated disk — Windows/VirtualBox

**Source:** V2 → `VBoxManage createmedium`, `storagectl`, `storageattach`, and `showmediuminfo`. Disk placement and size are local choices. Use the checked-in project script below.

On `ocne-op`, record the existing disks, then shut down cleanly:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
sudo shutdown -h now
```

After VirtualBox shows **Powered Off**, run in Windows PowerShell:

```powershell
Set-Location D:\OCNE19-Lab
.\scripts\05-Add-NFS-Disk.ps1
```

The script attaches a fresh disk on SATA port 2. It refuses to overwrite an existing VDI or occupied disk attachment. Start `ocne-op` in VirtualBox Manager and reconnect:

```powershell
ssh -p 2220 labadmin@127.0.0.1
```

## D2. Identify and format ONLY the new blank disk — operator

**Source:** [N3 — Creating and Mounting an XFS File System](https://docs.oracle.com/en/operating-systems/oracle-linux/9/xfs/xfs-CreatinganXFSFileSystem.html), steps 1–4. Oracle allows an entire disk as the XFS device. [N4 — Managing the File System Mount Table](https://docs.oracle.com/en/operating-systems/oracle-linux/9/fsadmin/fsadmin-AbouttheFileSystemMountTable.html), Editing `/etc/fstab` For Persistent Mounts.

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ls -l /dev/disk/by-id/
```

Compare with D1 and the newly attached VirtualBox medium. **Do not assume `/dev/sdb`. Both operator disks are 100 GiB. Formatting the OS disk would destroy it.** Identify the new blank whole disk with no partitions, filesystem, or mounts. Enter its actual path at the prompt below. The guards reject common mismatches; they do not replace checking the disk's identity.

Run this block only once for a fresh disk. If it stops, inspect the state before continuing. For an existing NFS disk, mount its existing filesystem; do not format it again.

```bash
read -r -p 'Actual NEW blank NFS disk path (for example a /dev/disk/by-id/ path): ' NFS_DISK
sudo bash -s -- "$NFS_DISK" <<'NFS_DISK_SETUP'
set -euo pipefail
disk=$(readlink -f -- "$1")
[[ -b "$disk" ]] || { echo 'Not a block device'; exit 1; }
[[ $(lsblk -dn -o TYPE "$disk") == disk ]] || { echo 'Not a whole disk'; exit 1; }
[[ $(blockdev --getsize64 "$disk") == 107374182400 ]] || { echo 'Not the expected 100 GiB disk'; exit 1; }
[[ $(lsblk -nr -o NAME "$disk" | wc -l) -eq 1 ]] || { echo 'Disk has child devices; stop'; exit 1; }
[[ -z $(lsblk -nr -o MOUNTPOINTS "$disk" | tr -d '[:space:]') ]] || { echo 'Disk is mounted'; exit 1; }
signatures=$(wipefs -n --noheadings "$disk")
[[ -z "$signatures" ]] || { echo 'Disk has existing signatures'; exit 1; }
if mountpoint -q /srv/nfs || grep -Eq '^[^#]*[[:space:]]/srv/nfs[[:space:]]' /etc/fstab; then
    echo 'Existing /srv/nfs mount/configuration: inspect instead of repeating'; exit 1
fi
if [[ -d /srv/nfs ]] && [[ -n $(ls -A /srv/nfs) ]]; then
    echo '/srv/nfs is not empty'; exit 1
fi
mkfs.xfs "$disk"
uuid=$(blkid -s UUID -o value "$disk")
[[ -n "$uuid" ]]
mkdir -p /srv/nfs
cp -p /etc/fstab "/etc/fstab.before-nfs-$(date +%Y%m%d%H%M%S)"
printf 'UUID=%s /srv/nfs xfs defaults 0 0\n' "$uuid" >> /etc/fstab
systemctl daemon-reload
mount /srv/nfs
mountpoint -q /srv/nfs
xfs_info /srv/nfs
NFS_DISK_SETUP
```

Check the block completed successfully, then verify:

```bash
findmnt /srv/nfs
df -hT /srv/nfs
```

The server's data disk is a required boot mount. If it becomes unavailable, repair that mount before starting NFS; do not create a replacement share on the operator's OS filesystem.

## D3. Install NFS utilities and check identities — all four nodes

**Source:** [N1 — Editing the /etc/exports File](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/editing-exports-file_task.html), steps 1 and 3; [N2 — Mounting an NFS Share](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/mounting_task.html), step 1. N1 refers to `exports(5)` for access/identity options.

Run on each of `ocne-op`, `ocne-cp`, `ocne-w1`, and `ocne-w2`:

```bash
sudo dnf install nfs-utils
id labadmin
sudo vi /etc/idmapd.conf
```

In the existing `[General]` section, set exactly one active Domain entry:

```ini
[General]
Domain = lab.test
```

Preserve the rest of the file. Use the same domain on all four hosts before their first NFS use. Confirm that `labadmin` has the same numeric UID and primary GID on every node. NFS filesystem permissions use these identities. If they differ, resolve the account mapping before continuing; do not blindly renumber an account already owning files. The `id` check is a local preflight check, not an OCNE installation requirement.

## D4. Create and export the shared directory — operator only

**Source:** [N1 — Editing the /etc/exports File](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/editing-exports-file_task.html), steps 2–4 and 6–8. For export options, use the `exports(5)` manual referenced by that page (`man 5 exports` on the operator). [N5 — Using the exportfs Command](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/exportfs-command_reference.html).

First confirm the XFS data disk is mounted. Create a directory writable by the shared `labadmin` identity:

```bash
sudo bash <<'NFS_SHARE_DIRECTORY'
set -euo pipefail
mountpoint -q /srv/nfs || { echo 'NFS data disk is not mounted'; exit 1; }
mkdir -p /srv/nfs/share
chown labadmin:"$(id -gn labadmin)" /srv/nfs/share
chmod 0770 /srv/nfs/share
NFS_SHARE_DIRECTORY
```

Preserve any existing exports. Back up and edit the file:

```bash
sudo cp -p /etc/exports "/etc/exports.before-ocne-nfs-$(date +%Y%m%d%H%M%S)"
sudo vi /etc/exports
```

Add this **single line**, once:

```text
/srv/nfs/share 192.168.77.10(rw,sync,root_squash) 192.168.77.11(rw,sync,root_squash) 192.168.77.12(rw,sync,root_squash) 192.168.77.13(rw,sync,root_squash)
```

`rw` permits writes subject to filesystem permissions; `sync` waits for stable storage; `root_squash` retains the normal protection against remote root being treated as server root. Test writes as `labadmin`, not with `sudo`. This permits the four lab addresses only.

Inspect the zone used by the operator's lab network interface:

```bash
sudo firewall-cmd --get-active-zones
sudo firewall-cmd --get-default-zone
```

Enter the actual zone associated with that interface (or its default zone when no explicit interface zone is assigned). Apply Oracle's NFSv4 firewall rule in both runtime and permanent configuration:

```bash
read -r -p 'Actual firewalld zone for the lab interface: ' NFS_ZONE
sudo firewall-cmd --zone="$NFS_ZONE" --add-service=nfs
sudo firewall-cmd --permanent --zone="$NFS_ZONE" --add-service=nfs
sudo systemctl enable --now nfs-server
sudo exportfs -ra
sudo /usr/sbin/exportfs -v
sudo cat /proc/fs/nfsd/versions
```

Confirm the export lists the four intended addresses and that the versions include `+4.1`. These firewall changes are on the operator only and permit NFSv4 on TCP 2049. No Windows port-forward is needed for VM-to-VM NFS. Preserve the existing OCNE rules and SELinux configuration. Remote `showmount` requires additional RPC access; this walkthrough verifies exports on the server and tests actual NFSv4 mounts instead.

## D5. Mount the share persistently — control plane and both workers

**Source:** [N2 — Mounting an NFS Share](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/mounting_task.html), steps 3–4 and its referenced `nfs(5)`/`mount(8)` manual pages. The source illustrates read-only mounting; this lab selects read/write access matching D4, and explicitly requests NFSv4.1.

Run on each of `ocne-cp`, `ocne-w1`, and `ocne-w2` after completing D3 there:

```bash
sudo mkdir -p /mnt/ocne-share
ls -la /mnt/ocne-share
findmnt -M /mnt/ocne-share
```

**For existing clients, inspect findmnt first.** If the correct source/version/options are mounted, verify them and the persistent entry instead of mounting again. The helper’s redundant second mount caused access denied on an already-mounted root-squashed path and was removed; protections were retained.

Before the first mount, the directory must be empty and not already mounted (`findmnt` returns no match). Inspect existing content rather than covering it with a mount. Then:

```bash
sudo mount -t nfs -o rw,vers=4.1,hard,nosuid 192.168.77.10:/srv/nfs/share /mnt/ocne-share
findmnt /mnt/ocne-share
df -hT /mnt/ocne-share
```

For persistence, back up and edit `/etc/fstab`:

```bash
sudo cp -p /etc/fstab "/etc/fstab.before-ocne-nfs-$(date +%Y%m%d%H%M%S)"
sudo vi /etc/fstab
```

Add this single entry once:

```text
192.168.77.10:/srv/nfs/share /mnt/ocne-share nfs rw,vers=4.1,hard,nosuid,_netdev 0 0
```

Then:

```bash
sudo systemctl daemon-reload
# Already mounted above: verify the mount directly; persistence is tested at D6.
findmnt -M /mnt/ocne-share
```

`hard` mounts wait for the server to recover during an outage; this can block file access. `_netdev` identifies network storage for boot ordering. The operator accesses these same files locally at `/srv/nfs/share`; it does not need to mount its own export over NFS.

## D6. Verify sharing from all four nodes

These are local acceptance checks for the documented export and mounts. They do not claim Kubernetes storage integration.

On each remote client, logged in as `labadmin`:

```bash
printf 'NFS write from %s\n' "$(hostname -s)" > "/mnt/ocne-share/nfs-check-$(hostname -s).txt"
ls -ln /mnt/ocne-share
```

On the operator, also as `labadmin`:

```bash
printf 'NFS write from operator\n' > /srv/nfs/share/nfs-check-ocne-op.txt
cat /srv/nfs/share/nfs-check-*.txt
```

Back on each client:

```bash
cat /mnt/ocne-share/nfs-check-*.txt
```

All four messages should be visible on every node. Permission failures require checking numeric IDs, ownership, mode, export entries, and any actual SELinux denials; do not fix them with `chmod 777`, `no_root_squash`, or disabling SELinux.

Before putting workload data here, verify persistence across an orderly lab shutdown/startup: stop clients first; start the operator first and verify `/srv/nfs` and its export; then start clients and check `/mnt/ocne-share`. Record actual results in `docs/RUN-LOG.md`.

**Scope:** this creates host-level shared storage. It does not create a Kubernetes PV, PVC, StorageClass, or NFS provisioner, and it does not establish suitability for Oracle Database/RAC storage. Those require their own documented configuration. The operator and its Windows disk remain a single point of failure; the Git repository contains setup instructions, not NFS data backups.

### 1b.14 Certificate distribution recovery reference


This supplements installation guide B9–B13. The completed lab already has functioning certificates and services; do not regenerate or redistribute them as a routine health check.

Oracle procedure: [Installing OCNE 1.9](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html), certificate and startup sections; [Platform CLI commands](https://docs.oracle.com/en/operating-systems/olcne/1.9/olcnectl/commands.html), Certificates Copy/Distribute. The temporary SSH authorization and transport cleanup below are local orchestration, not additional Oracle requirements.

## Check privileges before distribution

Password-free SSH as labadmin does not imply password-free sudo. In this lab, labadmin keeps password-required sudo; the package-created olcne account has its separate package-provided scope for /etc/olcne/scripts.

Before a new installation's distribution step, verify node resolution, time, host-key pins, SSH authentication, the operator's olcne group membership, and the actual remote privilege path. A noninteractive copy cannot depend on an unseen password prompt. Do not solve this with blanket labadmin NOPASSWD rules.

If generation succeeded but copying failed, inspect existing files and retain the CA/node material. Determine which destination copies completed before attempting recovery. Regenerating the CA can break trust in already configured components.

## What happened in this lab

1. Guide B10's distribute operation ran as labadmin and generated the PKI, then failed on noninteractive sudo.
2. The generated material under /home/labadmin/certificates was preserved.
3. A temporary operator public key was added to root's authorized_keys on the four clones, restricted to source 192.168.77.10, with agent/port/X11 forwarding and PTY disabled. Existing root keys were preserved.
4. The documented copy command ran as root on the operator, using the existing PKI and pinned SSH identities.
5. Destination certificate files, ownership, chain validation and subsequently running services were independently checked.
6. The copy transport remained stuck after copying. The specifically identified copy process and orphaned SSH transports were terminated after verification; this was not recorded as a normal successful command exit.
7. The exact temporary root authorization was removed from every clone and absence verified.

The recorded copy command, for reference only:

```bash
# Historical recovery: root on ocne-op, after reviewed temporary access was established.
cd /home/labadmin
olcnectl certificates copy \
  --cert-dir /home/labadmin/certificates \
  --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test \
  --ssh-identity-file /home/labadmin/.ssh/id_rsa \
  --ssh-login-name root \
  --remote-command 'ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/labadmin/.ssh/known_hosts'
```

Do not paste this onto a healthy lab. A future failed distribution requires a fresh inspection of policy, identity, PKI and process state. Temporary root access was removed, not retained as the permanent mesh.

## Verification before service bootstrap

On each intended guest, as an authorized administrator:

```bash
sudo test -s /etc/olcne/certificates/ca.cert
sudo test -s /etc/olcne/certificates/node.cert
sudo test -s /etc/olcne/certificates/node.key
sudo openssl verify \
  -CAfile /etc/olcne/certificates/ca.cert \
  /etc/olcne/certificates/node.cert
sudo openssl x509 -in /etc/olcne/certificates/node.cert \
  -noout -subject -issuer -dates -ext subjectAltName
sudo stat -c '%a %U:%G %n' /etc/olcne/certificates/ca.cert \
  /etc/olcne/certificates/node.cert /etc/olcne/certificates/node.key
```

Check every command result, intended certificate identity, validity, correct ownership for the platform service and restrictive private-key access. These commands display metadata, not private-key contents. Then follow guide B11/B12 for the CLI and externalIPs certificates and B13 for bootstrap. Verify olcne-api-server on the operator and olcne-agent on each cluster node.

Keep the labadmin CLI endpoint and directory consistent: ocne-op.lab.test:8091 and /home/labadmin/.olcne/certificates/ocne-op.lab.test:8091/. Keep the externalIPs certificate path consistent with module creation.

## Recovery helpers are historical

Authorize-Certificate-Copy.sh and Remove-Certificate-Copy-Key.sh embed this run's public key. Stop-Stalled-Certificate-Copy.sh and **Inspect-Certificate-Transports.sh** contain historical process IDs and can send SIGTERM. The latter is not read-only despite its name. Do not rerun them against today's process table.

Review a new incident and match the full current process identity before any termination; never kill by a recorded PID alone. Preserve evidence and remove temporary access even if a later stage fails.

Certificate renewal/rotation and restoration from backup were not exercised in this installation. Follow the cited Oracle lifecycle guidance for that separate operation, preserving the current trust chain until a reviewed replacement procedure is ready.

Actual results: [cloning log](CLONING-RUN-LOG.md). Execution contexts: [script reference](SCRIPT-REFERENCE.md).


### 1b.15 Foundation completion gate

On ocne-cp: all three nodes Ready, intended system deployments available, active system pods Ready. On each worker: dedicated XFS /var/lib/containers mounted. On operator: /srv/nfs mounted before nfs-server exports. All four nodes must read each other's NFS test files with labadmin UID/GID 1001. Confirm unique machine IDs/host keys, working workstation SSH and synchronized clocks.

The manual NFS section accesses files locally on the server; the completed lab also mounted its own export at /mnt/ocne-share for a uniform path. To reproduce that optional convenience, use the same client mount/fstab commands on the operator **after** /srv/nfs and nfs-server are healthy. This remains host NFS, not a Kubernetes PV or ASM disk.

Do not proceed to chapter 2 with failed foundational checks. See the [actual foundation troubleshooting table](TROUBLESHOOTING.md) and chapter 4's consolidated incident catalogue.

[Continue to 2. Database Operator](MANUAL-02-DATABASE-OPERATOR.md)

## Attribution and license

NFS addition: **Oracle Linux 9 Managing the Network File System**, G26606-03, September 2025, **Copyright © 2025, Oracle and/or its affiliates.** Its [title and license page](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/index.html) specifies CC-BY-SA. XFS and filesystem instructions are attributed to the Oracle Linux 9 manuals linked as N3 and N4. Changes in Part D include lab addresses, paths, a dedicated disk, read/write NFSv4.1 mounts, and local safety/verification wrappers.


Oracle source manuals: **Oracle Cloud Native Environment Installation for Release 1.9**, F93849-05, March 2026; and **Oracle Cloud Native Environment Kubernetes Module for Release 1.9**, F93851-02, March 2026. **Copyright © 2022, 2026, Oracle and/or its affiliates.**

Their Prefaces identify the documentation license as [Creative Commons Attribution–ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/). See the [Installation Preface](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/preface.html) and [Kubernetes Preface](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/preface.html).

This adapted guide is provided under the same CC BY-SA 4.0 license. Changes include selecting documented branches, organizing a step-by-step lab workflow, substituting lab identities and certificate paths, and adding the explicitly separate Windows/VirtualBox implementation. It is not an Oracle-authored or Oracle-endorsed guide. Oracle source links are provided throughout.
