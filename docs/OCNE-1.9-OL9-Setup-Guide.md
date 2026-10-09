# OCNE 1.9 home lab — corrected installation guide

**Windows / VirtualBox • Oracle Linux 9 • UEK R7 • one control plane and two workers**  
Prepared for Pradeep • Build verified 1 October 2026 • Documentation reconciled 8 October 2026 • Revision 6

## How to use this guide

**Project edition:** the completed lab lives under `D:\OCNE19-Lab`. Use [Operating the lab](OPERATING-LAB.md) for routine use and the [cloning guide](OCNE-1.9-Golden-VM-Cloning-Guide.md) for build history/procedure. New disks are under vms/, ISO media under ISO/, host secrets under private/. **Part A2–A6 is a separate fresh-ISO reference, skipped for this lab; do not run scripts 02/03 or duplicate creation blocks on these clones.** Cloning hands off to Part B after identity/storage readiness. Part D is the separate NFS addition.

This revision replaces the earlier chat walkthrough. The starting source is Oracle’s [OCNE 1.9 Host Requirements](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/hosts.html#hosts). The Linux and OCNE procedure follows the subsequent chapters of that same **Installation for Release 1.9** manual. Cluster deployment follows the **Kubernetes Module for Release 1.9** manual that the Installation manual explicitly links to.

Part A is our Windows/VirtualBox implementation. Its machine names, IP addresses, CPU/RAM allocations (including the user-requested reductions below Oracle’s minimum RAM), virtual disks, and disk partition sizes are lab choices. They are not represented as Oracle OCNE requirements. Part B follows Oracle’s documented installation procedure; substitutions for hostnames, account names, environment/module names, and documented certificate paths are identified below. Read the source pointer at each step before running its commands.

The selected branch is **Oracle Linux 9 with UEK R7**, using the Oracle Linux yum server, firewalld, default Flannel networking, file-based private-CA certificates, and a single control plane. These are options in the cited manuals, not a claim that Oracle prefers OL9 over OL8. Vault, ULN, Calico, HA load balancers, private registry mirrors, proxies, and optional modules are not configured by this branch. If your environment requires one of those options, follow its matching source section before continuing.

**Execution status:** the cloning path plus Parts B–D completed and passed recorded acceptance on 1 October 2026, including an ordered power cycle. [CLONING-RUN-LOG.md](CLONING-RUN-LOG.md) records outcomes and adaptations. Check existing resources instead of recreating them. Manual alternatives below were not all executed verbatim. The 8 October documentation revision is not a new live verification.

Oracle’s online manual currently marks OCNE 1.9 as **Sustaining Support**, without new security patches or bug fixes. Its supported-platform discussion refers to My Oracle Support Doc ID 2899157.1; the public host page does not establish VirtualBox certification. This guide is a home-lab procedure, not a support-certification statement.

## What changed from the earlier guide

| Earlier version | Correction in this revision |
|---|---|
| Picked OL8.10 without clearly distinguishing the choice from Oracle’s requirements | Uses the documented OL9/UEK R7 branch; retains Oracle’s update policy rather than inventing a fixed minor version |
| Used the separate Quick Install guide and `olcnectl provision` | Follows Installation chapters 1–4, then the linked Kubernetes Module guide |
| Configured blanket `NOPASSWD: ALL` for `labadmin` | Removes that addition; preserves Oracle’s specific access requirements for the package-created `olcne` service account |
| Added general package upgrades and a broad kernel installation command | Removes those actions; requires a host that already meets the documented OS/kernel baseline |
| Relied on quick installation for firewall setup | Includes Oracle’s role-specific, non-HA firewall commands |
| Did not show the OL9-specific forwarding configuration | Includes the persistent nftables configuration from the OL9 prerequisite section |
| Hid certificate setup inside quick installation | Shows node, CLI/API, and externalIPs-service certificates separately |
| Presented a custom partition layout alongside Oracle requirements | Labels disk sizes and partition allocation as local VM provisioning choices |
| Added general validation commands without source distinctions | Uses the documented module validation/report and kubectl verification sequence |

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

# Part A — Windows and VirtualBox implementation

## A1. Resource allocation and Oracle’s minimums

**Source:** S1 → Kubernetes Control Plane Node Hardware; Kubernetes Worker Node Hardware; Operator Node Hardware.

| Role | Oracle minimum CPU cores | Oracle minimum RAM | Oracle storage/network requirements |
|---|---:|---:|---|
| Operator | 1 | 8 GB | 15 GB in `/var`; 1 Gb Ethernet NIC |
| Control plane | 4 | 16 GB | 40 GB in `/var`; XFS; 1 Gb Ethernet NIC |
| Worker | 1 | 8 GB | 15 GB in `/var`; XFS; dedicated XFS mount at `/var/lib/containers` sized for images; 1 Gb Ethernet NIC |

VM allocation on the observed Windows host (61.66 GiB visible RAM, 28 logical processors):

| VM | vCPUs | RAM | Dynamic virtual-disk capacity | Address |
|---|---:|---:|---:|---|
| `ocne-op` | 2 | 4 GiB | 100 GiB OS + 100 GiB NFS | `192.168.77.10` |
| `ocne-cp` | 4 | 8 GiB | 100 GiB | `192.168.77.11` |
| `ocne-w1` | 6 | 22 GiB | 200 GiB | `192.168.77.12` |
| `ocne-w2` | 6 | 22 GiB | 200 GiB | `192.168.77.13` |

The VMs allocate **56 GiB RAM and 18 vCPUs**, leaving about **5.66 GiB nominal visible capacity** for Windows/VirtualBox overhead. Actual free memory varies. Each cloned worker has a 100 GiB OS disk and separate 100 GiB XFS container disk; Part D adds the operator’s separate 100 GiB NFS disk. Fresh-ISO examples in Part A use a different disk layout. These allocations do not establish database workload capacity.

**Explicit home-lab exception requested by the user:** operator 4 GiB and control plane 8 GiB remain below Oracle’s published 8/16 GB minimums. Base-lab installation/restart checks passed with no observed OOM, but this does not establish vendor minimum compliance or future workload capacity. Disclose observed resource failures before planning allocation changes; workers remain 22 GiB each.

## A2. Select the OS installation media

**Fresh-ISO reference only (A2–A6): not used for this completed cloning lab.** Use the cloning guide instead; scripts 02 and 03 remain excluded.

**Source:** S1 → OS Requirements → Table 1-1 OSs (x86_64).

For Oracle Linux 9, the table lists **Latest and latest-1** update levels with either **UEK R7** or **RHCK**. This walkthrough selects the UEK R7 branch. The page does not name one fixed OL9 minor-version ISO, so this revision does not label an arbitrary ISO as Oracle’s tested/preferred image.

Obtain an Oracle Linux 9 x86_64 ISO with an eligible update level from Oracle’s [ISO download page](https://yum.oracle.com/oracle-linux-isos.html). Confirm the installed and booted kernel is UEK R7 before Part B. A newer kernel supplied with an ISO is not automatically covered by this OCNE 1.9 table. A kernel conversion procedure is outside the linked OCNE installation instructions and is not invented here.

## A3. Create the shared VirtualBox NAT Network

**Run on:** Windows PowerShell. **Source:** V1 → Oracle VirtualBox NAT Network Service. All names, ports, and addresses here are local lab choices.

All VMs share `ocne19-net`, subnet `192.168.77.0/24`, with gateway `192.168.77.1`. DHCP is disabled. Choose a different unused subnet consistently if this one overlaps your LAN, VPN, or existing virtual networks.

```powershell
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
if (-not (Test-Path $VBox)) {
    throw "VBoxManage.exe not found. Check the VirtualBox installation path."
}

& $VBox --version
& $VBox list natnetworks
Get-NetRoute -AddressFamily IPv4 |
    Select-Object DestinationPrefix, NextHop, InterfaceAlias
```

Run the following once for a new network. The function stops subsequent scripted actions when VBoxManage reports an error.

```powershell
function Invoke-LabVBox {
    & $VBox @args
    if ($LASTEXITCODE -ne 0) {
        throw "VirtualBox command failed: $args"
    }
}

Invoke-LabVBox natnetwork add `
    --netname "ocne19-net" --network "192.168.77.0/24" `
    --dhcp off --enable

Invoke-LabVBox natnetwork modify --netname "ocne19-net" `
    --port-forward-4 "ssh-op:tcp:[127.0.0.1]:2220:[192.168.77.10]:22"
Invoke-LabVBox natnetwork modify --netname "ocne19-net" `
    --port-forward-4 "ssh-cp:tcp:[127.0.0.1]:2221:[192.168.77.11]:22"
Invoke-LabVBox natnetwork modify --netname "ocne19-net" `
    --port-forward-4 "ssh-w1:tcp:[127.0.0.1]:2222:[192.168.77.12]:22"
Invoke-LabVBox natnetwork modify --netname "ocne19-net" `
    --port-forward-4 "ssh-w2:tcp:[127.0.0.1]:2223:[192.168.77.13]:22"

Invoke-LabVBox natnetwork start --netname "ocne19-net"
```

The nodes communicate directly on their shared subnet. The NAT service supplies external connectivity; there is no address translation between cluster members. This distinction matters because S2’s Network Address Translation section discusses translation between cluster nodes and does not permit control-plane nodes behind that inter-node NAT arrangement. Our shared-NAT-Network design is a VirtualBox lab interpretation, not an Oracle OCNE-certified topology.

## A4. Create the four VMs

**Run on:** the same Windows PowerShell session. **Source:** V2 → createvm, modifyvm, createmedium, storagectl, storageattach. The following is our local orchestration script.

The project stores new VMs under its vms directory. Supply the ISO filename from the project ISO directory, without surrounding quote characters when prompted.

```powershell
$LabDir = "D:\OCNE19-Lab\vms"
$IsoPath = Join-Path "D:\OCNE19-Lab\ISO" (Read-Host "Filename of the selected Oracle Linux 9 x86_64 ISO")

if (-not (Test-Path $IsoPath -PathType Leaf)) {
    throw "ISO not found: $IsoPath"
}
New-Item -ItemType Directory -Path $LabDir -Force | Out-Null

$LabVMs = @(
    @{ Name = "ocne-op"; CPU = 2; RAM = 4096;  DiskMB = 102400 },
    @{ Name = "ocne-cp"; CPU = 4; RAM = 8192;  DiskMB = 102400 },
    @{ Name = "ocne-w1"; CPU = 6; RAM = 22528; DiskMB = 204800 },
    @{ Name = "ocne-w2"; CPU = 6; RAM = 22528; DiskMB = 204800 }
)

foreach ($VM in $LabVMs) {
    $Name = $VM.Name
    $Disk = Join-Path $LabDir "$Name\$Name.vdi"

    Invoke-LabVBox createvm --name $Name --ostype "Oracle_64" `
        --basefolder $LabDir --register

    Invoke-LabVBox modifyvm $Name --memory $VM.RAM --cpus $VM.CPU `
        --ioapic on --graphicscontroller vmsvga --vram 32 `
        --boot1 dvd --boot2 disk --boot3 none --boot4 none `
        --nic1 natnetwork --nat-network1 "ocne19-net" `
        --nictype1 82540EM --cableconnected1 on

    Invoke-LabVBox createmedium disk --filename $Disk `
        --size $VM.DiskMB --format VDI --variant Standard

    Invoke-LabVBox storagectl $Name --name "SATA" --add sata `
        --controller IntelAhci --portcount 2 --bootable on

    Invoke-LabVBox storageattach $Name --storagectl "SATA" `
        --port 0 --device 0 --type hdd --medium $Disk

    Invoke-LabVBox storageattach $Name --storagectl "SATA" `
        --port 1 --device 0 --type dvddrive --medium $IsoPath
}

& $VBox list vms
```

This block is for creating new VMs, not for rerunning against existing machines with the same names. If a command fails, inspect that error before resuming; do not delete existing VMs to clear a naming conflict.

### Changing RAM on VMs that already exist

**Run on:** Windows PowerShell, after cleanly shutting down all four guests. Each VM must be fully powered off, not running or in a saved state. These are local VirtualBox adjustments, not OCNE installation commands. Do not rerun the VM-creation loop to resize existing machines.

```powershell
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
& $VBox modifyvm "ocne-op" --memory 4096
& $VBox modifyvm "ocne-cp" --memory 8192
& $VBox modifyvm "ocne-w1" --memory 22528
& $VBox modifyvm "ocne-w2" --memory 22528
```

Confirm each command succeeds before starting the VMs. These values correspond to 4, 8, 22, and 22 GiB respectively.

## A5. Install the guest OS and supply the lab identities

The OCNE manual starts from installed hosts; it does not prescribe the Oracle Linux installer’s screen choices. The following provisioning inputs implement the VM layout, rather than adding OCNE product requirements.

Start each VM through VirtualBox Manager and install the selected Oracle Linux 9 media. Create a normal administrator account named `labadmin` with a password you choose. Minimal Install is a local choice. Configure the hostname and IPv4 settings in the installer:

| VM | Fully qualified hostname | IPv4 address | Prefix | Gateway |
|---|---|---|---|---|
| Operator | `ocne-op.lab.test` | `192.168.77.10` | 24 | `192.168.77.1` |
| Control plane | `ocne-cp.lab.test` | `192.168.77.11` | 24 | `192.168.77.1` |
| Worker 1 | `ocne-w1.lab.test` | `192.168.77.12` | 24 | `192.168.77.1` |
| Worker 2 | `ocne-w2.lab.test` | `192.168.77.13` | 24 | `192.168.77.1` |

Use DNS servers reachable from your home network, enable the interface, and enable automatic connection. Do not use `10.244.0.0/16` for a host interface; S2 reserves that default range for Flannel.

Allocate filesystems during installation. The exact capacities below remain local storage-provisioning choices; the requirements they satisfy are in S1.

| Mount | Operator/control plane | Each worker | Filesystem |
|---|---:|---:|---|
| `/boot` | 1 GiB | 1 GiB | XFS |
| `/` | 30 GiB | 30 GiB | XFS |
| `/var` | 60 GiB | 60 GiB | XFS |
| `/var/lib/containers` | Not separately allocated | 100 GiB | Separate XFS filesystem |

LVM may be used and remaining capacity may be left unallocated. The OCNE requirement is to disable swap on Kubernetes nodes; B3 addresses that even if the installer created swap.

Provide consistent hostname resolution on all four guests using your DNS service or the hosts file. For a hosts-file implementation, enter the following mappings in `/etc/hosts` on each VM using its administrator account. This is lab address provisioning, not a copied OCNE command block:

```text
192.168.77.10 ocne-op.lab.test ocne-op
192.168.77.11 ocne-cp.lab.test ocne-cp
192.168.77.12 ocne-w1.lab.test ocne-w1
192.168.77.13 ocne-w2.lab.test ocne-w2
```

Before Part B, ensure the hosts boot the selected OS/kernel, can reach Oracle yum and container registry services, resolve each other, permit SSH for the installation user, and allow that administrator to use sudo. The OCNE guide assumes these host facilities; it is not an OS installation or kernel-migration manual.

## A6. Detach installation media and connect

After installation, shut each VM down cleanly from the guest. Once all are powered off, run in the same Windows PowerShell session:

```powershell
foreach ($Name in @("ocne-op", "ocne-cp", "ocne-w1", "ocne-w2")) {
    Invoke-LabVBox storageattach $Name --storagectl "SATA" `
        --port 1 --device 0 --type dvddrive --medium none
    Invoke-LabVBox modifyvm $Name --boot1 disk --boot2 none
    Invoke-LabVBox startvm $Name --type headless
}
```

Use separate PowerShell tabs for these connections:

```powershell
# Operator
ssh -p 2220 labadmin@127.0.0.1

# Control plane
ssh -p 2221 labadmin@127.0.0.1

# Worker 1
ssh -p 2222 labadmin@127.0.0.1

# Worker 2
ssh -p 2223 labadmin@127.0.0.1
```

If SSH is unavailable, complete the guest’s SSH/network provisioning through the VM console before continuing. Part B does not add a substitute Linux host-setup script.

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

## B10. Generate and distribute node certificates

**Run on:** operator as `labadmin`, from the user’s home directory.  
**Source:** S3 → Distribute Node Certificates.

**Privilege prerequisite and recorded recovery:** labadmin keeps password-required sudo. This command generated PKI but failed during noninteractive copying. Read [Certificate distribution recovery](CERTIFICATE-DISTRIBUTION.md) first. If material exists, preserve it and inspect completed copies; do not regenerate the CA to retry a transport failure. The completed lab needs no distribution rerun.

```bash
olcnectl certificates distribute \
  --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test \
  --ssh-identity-file ~/.ssh/id_rsa \
  --ssh-login-name labadmin
```

Oracle documents generated node directories beneath `$HOME/certificates/`, the private CA beneath `$HOME/certificates/ca/`, and installed node certificates beneath `/etc/olcne/certificates/`. Keep the labadmin paths for B11/B12. On failure, stop before service startup and follow the recovery branch. This run used Oracle’s certificates copy with existing PKI and temporary restricted root SSH access, removed afterward. No blanket passwordless sudo was added. Transport termination was not a normal copy success; independent file/chain/ownership and service checks established the recovered result.

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

**Source:** V2 → `VBoxManage createmedium`, `storagectl`, `storageattach`, and `showmediuminfo`. Disk placement and size are local choices. Use the updated project ZIP for the script below.

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
[[ -z $(wipefs -n --noheadings "$disk") ]] || { echo 'Disk has existing signatures'; exit 1; }
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

## Review limits and items to resolve from actual host state

- The selected OL9 update and the booted kernel must be checked against S1. The manual does not identify one fixed ISO filename or provide a kernel downgrade procedure.
- The OS installer and local address/storage provisioning are Part A choices, not copied OCNE instructions.
- The S2 nftables example assumes its file paths and named firewalld chain are present. Its service contents are retained rather than silently redesigned.
- The noninteractive certificate-copy limitation and verified recovery are documented at B10 and in CERTIFICATE-DISTRIBUTION.md; password-required labadmin sudo remains.
- Live execution and ordered-restart acceptance are recorded in CLONING-RUN-LOG.md. This documentation revision does not rerun VM operations. Fresh-ISO steps remain an unexecuted alternative; backup restoration, certificate renewal and database workload capacity were not tested.

## Attribution and license

NFS addition: **Oracle Linux 9 Managing the Network File System**, G26606-03, September 2025, **Copyright © 2025, Oracle and/or its affiliates.** Its [title and license page](https://docs.oracle.com/en/operating-systems/oracle-linux/9/nfs/index.html) specifies CC-BY-SA. XFS and filesystem instructions are attributed to the Oracle Linux 9 manuals linked as N3 and N4. Changes in Part D include lab addresses, paths, a dedicated disk, read/write NFSv4.1 mounts, and local safety/verification wrappers.


Oracle source manuals: **Oracle Cloud Native Environment Installation for Release 1.9**, F93849-05, March 2026; and **Oracle Cloud Native Environment Kubernetes Module for Release 1.9**, F93851-02, March 2026. **Copyright © 2022, 2026, Oracle and/or its affiliates.**

Their Prefaces identify the documentation license as [Creative Commons Attribution–ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/). See the [Installation Preface](https://docs.oracle.com/en/operating-systems/olcne/1.9/install/preface.html) and [Kubernetes Preface](https://docs.oracle.com/en/operating-systems/olcne/1.9/kubernetes/preface.html).

This adapted guide is provided under the same CC BY-SA 4.0 license. Changes include selecting documented branches, organizing a step-by-step lab workflow, substituting lab identities and certificate paths, and adding the explicitly separate Windows/VirtualBox implementation. It is not an Oracle-authored or Oracle-endorsed guide. Oracle source links are provided throughout.
