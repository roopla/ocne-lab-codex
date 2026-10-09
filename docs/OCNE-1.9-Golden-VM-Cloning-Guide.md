# OCNE 1.9 lab — create four VMs from a golden VM

**Windows + VirtualBox • project root D:\OCNE19-Lab • operator, control plane, two workers**

Prepared for Pradeep • Build verified 1 October 2026 • Documentation reconciled 8 October 2026 • Cloning edition 2

## Read this first

This is a separate alternative to the ISO-based VM creation steps. It produces four independent full clones from an existing, clean Oracle Linux VM. No ISO installation is needed when that VM already meets the selected OS/kernel requirements. The original golden VM remains the source; all identity changes happen inside the clones.

**Recorded completion:** the golden VM, OS/kernel, accounts, disks and networks were inspected; four independent clones, OCNE/Kubernetes, SSH and NFS were built and verified through an ordered restart on 1 October 2026. [CLONING-RUN-LOG.md](CLONING-RUN-LOG.md) contains the evidence. This guide documents that build and the procedure for a separately reviewed future build. Use [Operating the lab](OPERATING-LAB.md) for the existing VMs; do not rerun creation, identity resets or formatting.

The intended OS branch remains Oracle Linux 9, x86_64, UEK R7, with an eligible update under Oracle's OCNE 1.9 Host Requirements table. OL8 is another documented branch, but this guide's guest commands target OL9. If the template is another OS/kernel, do not silently apply this branch.

**Source boundary:** the OCNE installation manual begins with existing hosts and does not provide a VirtualBox golden-image procedure. Windows/VirtualBox commands below are local provisioning using Oracle's VirtualBox reference. Linux clone preparation uses Oracle Linux documentation and the system manuals shipped with the OS. It is identified separately from OCNE product installation. Parts B–C of the companion setup guide retain the original OCNE procedure; Part D retains the sourced NFS addition.

## 1. Final layout and storage decisions

| VM | Hostname | IPv4 | RAM | vCPUs | Windows SSH port |
|---|---|---|---:|---:|---:|
| ocne-op | ocne-op.lab.test | 192.168.77.10 | 4 GiB | 2 | 2220 |
| ocne-cp | ocne-cp.lab.test | 192.168.77.11 | 8 GiB | 4 | 2221 |
| ocne-w1 | ocne-w1.lab.test | 192.168.77.12 | 22 GiB | 6 | 2222 |
| ocne-w2 | ocne-w2.lab.test | 192.168.77.13 | 22 GiB | 6 | 2223 |

Total: 56 GiB RAM and 18 vCPUs. The host reported 61.66 GiB visible RAM and 28 logical processors, leaving approximately 5.66 GiB nominal RAM capacity for Windows/overhead. Leave the golden VM off. Operator/control-plane allocations remain below Oracle’s published 8/16 GB minimums. Base-lab acceptance passed with no observed OOM; vendor minimum compliance and database workload capacity are not established.

Network: `ocne19-net`, `192.168.77.0/24`, gateway `192.168.77.1`, no DHCP. DNS servers must be actual reachable resolvers from your environment.

**Full cloning initially preserves guest partitions and filesystem UUIDs.** For this source, script 06 explicitly expanded each newly created independent clone VDI from 40 GiB to 100 GiB using `-BootDiskMB 102400`. Guest partition/XFS growth was a separate guarded step. Neither operation changed the source disk.

| Role | Boot disk | Additional disk in this workflow |
|---|---|---|
| Operator | 100 GiB clone boot disk; root XFS grown to ~99 GiB | 100 GiB NFS disk, added using script 05 |
| Control plane | 100 GiB clone boot disk; root XFS grown to ~99 GiB | None |
| Each worker | 100 GiB clone boot disk; root XFS grown to ~99 GiB | Separate 100 GiB dedicated container XFS disk |

The completed clones have 700 GiB total virtual disk capacity, excluding the preserved golden VM and snapshots. Dynamic VDI files grow as written; virtual capacity is not current physical consumption. Check current free host storage before additional allocations.

The configuration supplies names, RAM, CPUs, IPs and network values. Its `DiskMB` field is used by fresh-ISO creation, not implicit clone resizing. The explicit `BootDiskMB` parameter and verified guest growth govern this cloning workflow.

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

## 3. Project files and workflow boundaries

The project is already installed at `D:\OCNE19-Lab`. For future package updates, compare files in a temporary directory and merge reviewed changes; preserve runtime assets and execution history. The principal cloning files are:

| New file | Purpose |
|---|---|
| README-CLONING.md | Start here for the cloning workflow |
| docs/OCNE-1.9-Golden-VM-Cloning-Guide.md | This guide; Git-friendly source |
| docs/OCNE-1.9-Golden-VM-Cloning-Guide.html | Readable/printable version |
| docs/CLONING-RUN-LOG.md | Separate execution record |
| scripts/06-Clone-Golden-VM.ps1 | Inspect, then create four independent clones |
| scripts/07-Add-Worker-Container-Disk.ps1 | Optional dedicated worker storage |

Common.ps1, configuration, network script, and NFS script are included for a fresh project. Preserve existing custom configuration, RUN-LOG.md, ISO files, VMs, and secrets when merging. The archive contains no ISO or VM disks.

**Do not run scripts 02 or 03 for this workflow.** They implement fresh ISO installation and assume its storage/boot sequence. Script 06 replaces VM creation. Console preparation below replaces the post-install first boot sequence.

## 4. Inspect the golden VM before cloning

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

## 5. Create or verify the lab network

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

## 6. Create the four full clones

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

## 7. Prepare each clone while its network is disconnected

The manual sections 7–9 explain one-time preparation. The recorded run used `Prepare-Clone-Identity.sh` through disconnected consoles and a nonbootable preparation ISO; **do not also perform manual resets after using that helper**. Its UUID/MAC guards are specific to these clones, including observed SMBIOS UUID byte-order representations. See [Script reference](SCRIPT-REFERENCE.md).

For a separately reviewed manual build, repeat sections 7–9 for **one clone at a time**. Use its VirtualBox console window, not SSH. Check the window title so you do not run these commands on the golden VM.

On Windows, start the first clone:

```powershell
& $VBox startvm ocne-op --type gui
```

Log in using the golden VM's existing administrator account and password. Subsequent clones use `ocne-cp`, `ocne-w1`, and `ocne-w2` in the same start command.

### 7.1 Select the clone identity

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

### 7.2 Replace copied host identities and reboot

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

## 8. Configure the clone's account, network, and name resolution

### 8.1 Keep a consistent installation account

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

### 8.2 Configure a new static network profile

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

### 8.3 Add lab hostnames

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

## 9. Reconnect only the prepared clone and verify SSH

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

### 9.1 Grow the clone root before OCNE prerequisites

The recorded clones have 100 GiB VDIs, but initially inherited the source's 40 GiB partition layout. Expanding the VDI alone does not expand /var.

Inspect each clone using lsblk, findmnt, blkid and the partition table. This run verified plain XFS on partition 2, start sector 2099200, original size 79691776 sectors, inherited root UUID 7ca3aaf4-86fd-4ec7-83f8-1e7e18f27651, and a 107374182400-byte independent parent disk. These are recorded values, not defaults for another source.

The reviewed [Grow-Clone-Root.sh](../scripts/Grow-Clone-Root.sh) checked those values, saved the partition table, ran growpart in dry-run mode, grew partition 2 without changing its start, then ran xfs_growfs on the mounted root. It verified at least 40 GiB available under /var afterward. Final root size was approximately 99 GiB on all four clones. Never shrink, recreate or move the root partition; do not use this helper to repair an unknown layout.

These are local provisioning steps. Sources: [Oracle's growpart/XFS expansion example](https://docs.oracle.com/en/database/other-databases/essbase/19.3/essad/resize-block-storage-volumes.html) (only the Linux expansion operations apply), [OL9 Growing an XFS File System](https://docs.oracle.com/en/operating-systems/oracle-linux/9/xfs/xfs-GrowinganXFSFileSystem.html), and C1 modifymedium. Verify growth before Part B.

### 9.2 Completed Windows and guest SSH integration

The later user-requested workstation and all-node key access is documented in [SSH access](SSH-ACCESS.md). Windows hosts maps the actual .10–.13 guest addresses; SSH aliases separately select loopback NAT forwards with pinned host keys. Hosts entries alone do not create a route. Every guest keeps its own private key; only public keys were exchanged. Password-required sudo remains.

## 10. Provide dedicated XFS container storage on each worker

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
[[ -z $(wipefs -n --noheadings "$disk") ]] || { echo 'Disk has existing signatures'; exit 1; }
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

## 11. Continue with OCNE installation, then NFS

The companion `docs/OCNE-1.9-OL9-Setup-Guide.md` and HTML are included in the ZIP. After clone readiness checks, use this handoff:

| Existing guide section | Action for cloned VMs |
|---|---|
| A1 | Keep agreed RAM/CPU; use this guide’s verified 100 GiB clone boot disks plus separate data disks |
| A2–A6 | Replaced by this cloning workflow; no ISO reinstall or duplicate VM creation |
| B1–B7 | Follow the original OCNE prerequisites in order, including repos, time, swap, firewall, forwarding, bridge settings, and SSH |
| B8–B14 | Install packages; read B10 and certificate recovery for noninteractive privileges; verify PKI and services |
| Part C | Create environment and Kubernetes module; validate, install, report, kubectl |
| Part D | Add the requested operator 100 GiB NFS disk and configure server/client mounts |

For NFS, after the base OCNE installation works, shut the operator down cleanly and run on Windows:

```powershell
Set-Location D:\OCNE19-Lab
.\scripts\05-Add-NFS-Disk.ps1
```

Start the operator and follow Part D2–D6. Script 05 uses the project path automatically, including D:. Do not format any disk based on its assumed device name. The operator exports `/srv/nfs/share`; the control plane and workers mount it at `/mnt/ocne-share`; the operator accesses the files locally. Worker RAM remains 22 GiB each.

No Kubernetes PV/PVC/StorageClass, database, ASM, or RAC deployment is included in VM cloning or host-level NFS setup.

## 12. Acceptance checklist and execution record

Record real results in `docs/CLONING-RUN-LOG.md`:

- Four independent clones exist under `D:\OCNE19-Lab\vms`, with the agreed RAM/CPU.
- Golden VM remains intact and powered off; its existing location need not change. All new clone files live in the project.
- Each clone has the correct hostname/IP, unique MAC/VM UUID/machine ID/SSH host key.
- Console and SSH login work; the installation account has sudo access and consistent UID/GID.
- All hosts resolve each other and can reach required Oracle repositories.
- Kernel/OS and actual `/var` space meet the selected OCNE requirements.
- Both workers have a dedicated XFS container filesystem and it survives reboot.
- After continuing the original guide, validation/install complete, all three nodes are Ready, intended deployment replicas are available/updated and live pods report Ready=True. Recheck after the ordered restart.
- After Part D, NFS reads/writes work from every node and mounts survive an orderly restart.

To verify runtime exclusions before committing documentation:

```powershell
Set-Location D:\OCNE19-Lab
git status --short --untracked-files=all
git check-ignore -v vms/ocne-op/ocne-op.vdi
```

Use the existing README's Git setup instructions if this folder is not yet a repository. Never commit VM disks, private keys, raw credentials, or kubeconfigs. Git records the procedure, not a backup of the running lab or NFS data.

## 13. Troubleshooting without rebuilding everything

| Observation | Next step |
|---|---|
| Script says destination exists | Inspect that VM/folder and its last completed step; do not delete or rerun fresh creation |
| Script rejects source storage | Review actual controller names, port mapping, disks, snapshots, and media type; adapt from evidence |
| Clone starts but network is unavailable | Expected initially; use the console until identity/static networking are prepared, then connect NIC 1 |
| Old hostname/IP returns after reboot | Inspect inherited cloud-init or other automation before reconnecting the clone |
| SSH shows a changed key | Compare against the clone console; update only the verified stale known_hosts entry |
| `/var` is too small | Inspect lsblk/findmnt/pvs/vgs/lvs and derive a storage change for that exact layout; cloning alone cannot fix it |
| Worker container directory already has data | Stop the new empty-disk procedure; inspect the existing container setup before planning a migration |
| NFS disk or worker disk already exists | Inspect the partial run and attachment; never recreate/format an existing data disk |

## Validation limits and attribution

The recorded build was executed on this Windows/VirtualBox host and verified after restart. PowerShell parsing and guest-script syntax checks preceded execution. Manual alternatives and fresh-ISO instructions were not all executed; successful helpers do not validate every template or rerun. The 8 October revision changes documentation only. See [the log](CLONING-RUN-LOG.md), [operations](OPERATING-LAB.md), [certificate recovery](CERTIFICATE-DISTRIBUTION.md) and [troubleshooting](TROUBLESHOOTING.md).

Oracle source documentation is attributed by its exact title and section above. Copyright belongs to Oracle and/or its affiliates; the companion OCNE/NFS guide retains its existing copyright and CC BY-SA notices. This adapted cloning guide is provided under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/). It reorganizes the cited operations and substitutes lab values, adds local safety checks, and applies Oracle Linux guest preparation to VirtualBox full clones. It is not an Oracle-authored or Oracle-endorsed guide.

## Observed golden baseline and local provisioning adaptations

Historical inspection/planning notes below were written during the build. The planned clone growth and storage preparation were subsequently completed, as described in sections 6–10 and the final run log. These notes are preserved for provenance.

The source inspected on 2026-09-30 is ol9-golden, Oracle Linux 9.8 x86_64, booted and default UEK R7 5.15.0-324.217.5.3.el9uek.x86_64. UEK R8 is also installed but is not selected. Retain R7 when installing OCNE packages. No source package/kernel changes are authorized by this adaptation.

The source has a 40 GiB normal VDI snapshot chain. Its root is a plain XFS partition (partition 2 starts at sector 2099200, ends at 81790975); /var shares root and has about 31 GiB free. This does not satisfy the control-plane storage check. Preserve the source and resolve capacity on the independent clones before OCNE prerequisites. Script 06 now accepts explicit -BootDiskMB 102400 to expand only newly created, verified independent clone disks under vms/. Guest partition growth and xfs_growfs are separate steps after identifying the clone disk; capacity is not considered resolved until verified in the guest. The normal snapshot chain is checked for accessible parents and flattened by full --mode machine cloning; the source snapshot remains intact.

Partition growth uses the growpart tool after a dry-run against the observed partition layout, followed by xfs_growfs on the mounted filesystem. This is local host provisioning, not an OCNE instruction. Oracle describes growpart followed by xfs_growfs in its block-volume expansion procedure: https://docs.oracle.com/en/database/other-databases/essbase/19.3/essad/resize-block-storage-volumes.html . Only those Linux tool operations are applicable; no OCI/Essbase deployment is being performed. XFS semantics: https://docs.oracle.com/en/operating-systems/oracle-linux/9/xfs/xfs-GrowinganXFSFileSystem.html . Virtual disk resize: VBoxManage modifymedium --resize in C1. Never shrink/delete/re-create the root partition or change its start sector.

The existing global Downloads share affects every VM. Preserve it for unrelated resources. Script 06 requires explicit -ReviewedGlobalShare Downloads for this observed mapping; machine-specific and transient shares remain rejected. No vboxsf filesystem is mounted in the inspected source, and no Guest Additions package or VBox installation under /opt was found. The in-kernel vboxguest module alone is present. Verify clones do not mount or use the global share; do not use it for provisioning or credentials. This is an explicit local exception to the wrapper's original no-shares assumption, based on inspected scope, not a request to remove the global mapping.

The source has no labadmin account; alpoor is UID/GID 1000. Create labadmin consistently on the clones with an unused UID/GID after rechecking. Do not add blanket passwordless sudo. The source has Podman and only empty directory scaffolding under /var/lib/containers (sigstore and storage/tmp); preserve those directories in a clone-local backup before adding each worker's dedicated XFS mount, and restore directory metadata onto the new mounted filesystem. Do not hide or discard existing container data if later inspection differs.

For golden inspection only, a temporary nmcli connection (save no, no autoconnect) supplies DHCP on enp0s3. Its profile is under /run, not /etc. Remove it and shut the source down cleanly before cloning. This follows nmcli's save option: https://networkmanager.dev/docs/api/latest/nmcli.html and C3. SSH uses a host-key fingerprint obtained through the source console. Credentials stay DPAPI-encrypted under private/, with temporary transport files removed after use.

## Actual execution additions (2026-10-01)

See CLONING-RUN-LOG.md for checked results and SSH-ACCESS.md for Windows and guest SSH. The source snapshot chain was reviewed and preserved; clone-only root partitions grew with growpart and mounted XFS with xfs_growfs. The preparation ISO is nonbootable local identity automation, not a fresh OS installation. No scripts 02/03 were executed.

The OCNE 1.9 repository supplied 1.9.6 platform packages. Guide B10 generated the private CA and node certificates but labadmin's password-required sudo prevented noninteractive copying. Without regenerating the CA, the documented `olcnectl certificates copy` command was run as root with the existing PKI path and `--ssh-login-name root`; a temporary operator public key restricted to source IP 192.168.77.10 was installed for this copy and removed from every target afterward. No blanket passwordless sudo was introduced. Its SSH transports stalled after copying; destination files, ownership, certificate chains and running platform services were verified independently before terminating the specific stuck copy/transport processes. Sources: Oracle [Installation, certificate copy and startup](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/install.html) and [Platform CLI Certificates Copy](https://docs.oracle.com/en/operating-systems/olcne/1.9/olcnectl/commands.html). This privilege/transport handling is local orchestration.

The original minimum-memory exception remains: operator 4 GiB and control plane 8 GiB are below Oracle's published minimums. A successful OCNE module validation is an observed CLI result, not a claim that these allocations meet Oracle's requirements.
