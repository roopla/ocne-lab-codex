# Manual RAC prerequisite setup on the OCNE 1.9 cloning lab

This guide records the local Windows/VirtualBox implementation and the Oracle Linux/Kubernetes prerequisites used on 9-10 October 2026. It stops before RAC provisioning. The user will build and pre-stage an OL9 RAC slim image and fully patched 19.32 GI/database gold home ZIPs, then apply the database manifest themselves.

For the complete foundation, first follow [golden VM cloning](OCNE-1.9-Golden-VM-Cloning-Guide.md) and the full [OCNE installation guide](OCNE-1.9-OL9-Setup-Guide.md). Do not substitute Quick Install, olcnectl provision, standalone kubeadm, OCNE2, or fresh ISO scripts02/03. [The run log](CLONING-RUN-LOG.md) records what actually ran; commands below are instructions for a future build, not assertions they have all run again.

## 1. Inspect and establish a healthy foundation

Windows PowerShell, from D:\OCNE19-Lab:

```powershell
.\scripts\00-Inspect-Host.ps1
$vbox = 'C:\Program Files\Oracle\VirtualBox\VBoxManage.exe'
& $vbox list vms
& $vbox list runningvms
& $vbox list natnetworks
& $vbox list intnets
Get-PSDrive D
powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE
```

Read AGENTS.md, README.md, config/lab.psd1 and both foundation guides before changes. Preserve the identified golden VM, unrelated VMs/networks/disks and current project assets. Never delete something to resolve a name conflict. Current allocations are op4GiB/2 CPU, cp8GiB/4 CPU and workers22GiB/6 CPU each. OP/CP remain below Oracle's published minimums; this home lab is not an Oracle-validated resource configuration.

Automatic Windows Modern Standby caused guest time jumps and kernel stalls in this run. We recorded the original AC timeout (60 minutes), then ran `powercfg /change standby-timeout-ac 0`. DC timeout and display settings were preserved. After the lab is shut down, restore with `powercfg /change standby-timeout-ac 60` if wanted. Keep the workstation on AC; explicit sleep/hibernate still pauses the VMs. See [operating instructions](OPERATING-LAB.md) for shutdown/startup order.

On every guest, check `date -u`, `chronyc tracking`, `systemctl --failed`, `getenforce`, `uname -r`, mounts and available memory. On ocne-cp as labadmin, check `kubectl get nodes`, `kubectl get pods -A` and deployment readiness. Check fresh NFS writes/reads from all four VMs. Preserve journal/VBox evidence before recovering a stalled guest; do not treat a running VM as healthy or erase historic failures to make a check pass.

## 2. Add dedicated scratch/shared storage and isolated NICs

This section is local VirtualBox provisioning, not an Oracle-specified hypervisor configuration. Gracefully shut down only the two workers and confirm their state is poweroff. Inspect SATA attachments and NICs; this run had SATA3/4/5 and NIC2/3 free. New builds may differ.

| Purpose | Per-worker attachment | Capacity and VirtualBox mode |
|---|---|---|
| Scratch/homes/staging | SATA3, independent disk for each worker | 128 GiB dynamic VDI, normal |
| ASM01 | SATA4, same disk UUID on both workers | 50 GiB fixed VDI, shareable |
| ASM02 | SATA5, same disk UUID on both workers | 50 GiB fixed VDI, shareable |
| Private network1 | NIC2, Intel82540EM | internal network ocne-rac-priv1, allow-vms promiscuity |
| Private network2 | NIC3, Intel82540EM | internal network ocne-rac-priv2, allow-vms promiscuity |

The reviewed [hardware helper](../scripts/08-Prepare-RAC-Hardware.ps1) contains the full command sequence and fail-closed checks. It is one-time and embeds this build's VM/boot/container UUIDs. For a new cloning run, replace those guards only from inspection; do not remove them. Parse before executing:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
  'D:\OCNE19-Lab\scripts\08-Prepare-RAC-Hardware.ps1',
  [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count) { throw ($errors | Out-String) }
.\scripts\08-Prepare-RAC-Hardware.ps1
# Only on an inspected new build with both workers off:
.\scripts\08-Prepare-RAC-Hardware.ps1 -Apply
```

For manual execution, use that script as a command ledger: `createmedium disk --size 131072 --variant Standard` for each scratch disk; `--size 51200 --variant Fixed`, then `modifymedium disk <path> --type shareable` for each shared disk. Use `showmediuminfo disk <path>` to record UUID, capacity and mode, then `storageattach` the recorded UUID to the inspected slot. VirtualBox7.2 showmediuminfo does not accept --machinereadable. Keep all paths under vms/. Attach the same shared UUID on both workers, not copies. Never reuse D:\VMs\shared\asm3.vdi. Shared disks are not protected by ordinary VM snapshots.

Configure NIC2/NIC3 as follows on each inspected worker, retaining its existing NIC1:

```powershell
& $vbox modifyvm ocne-w1 --nic2 intnet --intnet2 ocne-rac-priv1 --nictype2 82540EM --nicpromisc2 allow-vms --cableconnected2 on --nic3 intnet --intnet3 ocne-rac-priv2 --nictype3 82540EM --nicpromisc3 allow-vms --cableconnected3 on
# Repeat for ocne-w2 after checking its free NIC slots.
```

Verify both VM configurations, start the workers, then inspect guest storage as root:

```bash
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL,UUID,PARTUUID
findmnt
ls -l /dev/disk/by-id/
```

Map each new device to the VBox UUID, attachment, serial and exact size. Before initialization, inspect its partitions, signatures (`wipefs --no-act <identified-device>`), holders and mounts. A failed inspection is not evidence of an empty disk. Device letters changed on worker 2 during this build; never assume /dev/sdb.

On each worker, follow [Prepare-RAC-Scratch.sh](../scripts/Prepare-RAC-Scratch.sh) manually after substituting its newly observed serial/machine ID. It verifies blankness and size, uses non-forcing mkfs.xfs, appends a UUID-based /scratch fstab entry without replacing other entries, mounts it and checks the mounted UUID. Do not rerun formatting on this completed lab.

For ASM, follow [Prepare-RAC-ASM-Partitions.sh](../scripts/Prepare-RAC-ASM-Partitions.sh) on **one worker only**, after identifying both blank shared disks. Create GPT and one aligned partition on each, labeled ocne-rac-asm01 and ocne-rac-asm02. Do not run mkfs and do not create ASM disk groups. On both workers, partprobe/udevadm settle and verify by-partlabel paths, matching PARTUUIDs, size, no filesystem/mount and matching header hashes. [Verify-RAC-Shared-Disks.sh](../scripts/Verify-RAC-Shared-Disks.sh) contains this build's exact verification.

## 3. Prepare the private interfaces and Multus

Inspect MAC addresses first. Here the new interfaces are enp0s8 and enp0s9. As root on each worker, create the two profiles only if they do not already exist:

```bash
nmcli connection add type ethernet ifname enp0s8 con-name ocne-rac-private1 ipv4.method disabled ipv6.method disabled ethernet.mtu 1500 connection.autoconnect yes
nmcli connection add type ethernet ifname enp0s9 con-name ocne-rac-private2 ipv4.method disabled ipv6.method disabled ethernet.mtu 1500 connection.autoconnect yes
nmcli connection modify ocne-rac-private1 802-3-ethernet.accept-all-mac-addresses 1
nmcli connection modify ocne-rac-private2 802-3-ethernet.accept-all-mac-addresses 1
nmcli connection up ocne-rac-private1
nmcli connection up ocne-rac-private2
ip -d link show enp0s8
ip -d link show enp0s9
ip -4 address show
ip route
```

Both private parents must be UP/PROMISC and have no host IPv4/IPv6 address or default route. We used verified MTU 1500; do not claim jumbo support without testing the whole path. The guest promiscuous setting was necessary for VirtualBox/macvlan unicast reception. If modifying an already active profile, this NetworkManager version cannot reapply accept-all-mac-addresses in place: persist it and use `ip link set dev <verified-private-interface> promisc on` until the next activation. Never apply this to NIC1/LAN interfaces.

On ocne-op as labadmin, use the OCNE1.9 module procedure:

```bash
olcnectl module instances --environment-name homelab
olcnectl module create --environment-name homelab --module multus --name rac-multus --multus-kubernetes-module cluster1
olcnectl module install --environment-name homelab --name rac-multus
olcnectl module report --environment-name homelab --name rac-multus --children
```

If the module already exists, inspect its state instead of creating another. On ocne-cp, apply the reviewed [rac-networks.yaml](../config/rac-networks.yaml) and verify the Multus daemonset is 3/3Ready and both NADs exist in rac. They use macvlan bridge mode, host-local IPAM, enp0s8/enp0s9, and subnets192.168.78/24 and192.168.79/24. The operator assigns explicit per-node addresses from rangeStart120; host-local alone does not coordinate allocation across workers. Dedicate these NADs to this RAC cluster.

Run [Test-RAC-Private-Networks.sh](../scripts/Test-RAC-Private-Networks.sh) as labadmin on ocne-cp (it embeds [the test manifest](../config/rac-network-check.yaml)). Its disposable pods use .128/.129 on both networks, NET_RAW for ping, and test both directions with 1472-byte payloads plus Kubernetes DNS. The final test uses node selectors so the scheduler must place each pod with 4CPU,16 GiB ordinary memory and2GiB HugePages requests; it also verifies the HugePages mount and an allowed pod sysctl. Inspect any existing test pods before replacing them. Remove only those named diagnostic pods after success. No RAC pod is created by this test.

## 4. Configure each worker's OS

Use [Prepare-RAC-Worker.sh](../scripts/Prepare-RAC-Worker.sh) as the complete reviewed root command sequence. For a fresh build update its scratch UUID guard from inspection. Back up /etc/sysconfig/kubelet, boot settings and current sysctls. Its final configuration writes /etc/sysctl.d/98-ocne-rac.conf:

```ini
fs.file-max = 6815744
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
vm.nr_hugepages = 1024
```

Load with `sysctl -p /etc/sysctl.d/98-ocne-rac.conf`; require1024 pages of 2048KiB (2 GiB). Keep swap disabled. TSC was already selected; verify it rather than blindly changing clocksources. Disable THP with `grubby --update-kernel=ALL --args='transparent_hugepage=never'` and write never to /sys/kernel/mm/transparent_hugepage/enabled. Retain existing boot arguments.

Preserve all existing kubelet arguments while adding `--allowed-unsafe-sysctls=kernel.shm*,net.*,kernel.sem` to KUBELET_EXTRA_ARGS. This run's original extra argument was --fail-swap-on=false. Run systemctl daemon-reload and restart kubelet. The unsafe-sysctl allowance is Oracle's documented RAC requirement; do not disable SELinux/firewalld.

Install selinux-policy-devel and policycoreutils-python-utils if absent. The helper contains the complete Oracle rac-ocne.te module, builds it using the SELinux development Makefile and installs it with semodule. It grants only the documented container_init_t accesses. Preserve Enforcing and verify the module appears in semodule -l.

Create /scratch/rac/cluster01/racnode1 and racnode2 on both workers, owner54321:54321/mode 0755. Persist container_file_t file contexts for `/scratch/rac/cluster01(/.*)?` and `/scratch/software/stage(/.*)?`, then restorecon -RF those paths. Recursive expressions are our local extension so future files receive the correct type.

Reboot workers one at a time and verify boot IDs changed, all settings survived, private NICs are still PROMISC, original storage is mounted, Chrony synchronized and Kubernetes nodes recovered. [Verify-RAC-Worker.sh](../scripts/Verify-RAC-Worker.sh) performs these prerequisite checks. Check NFS again. Never reboot both workers simultaneously during an active RAC workload without a planned shutdown.

Memory rationale: the operator 2.2.0 webhook requires a16GiB ordinary-memory limit. The lab manifest requests/limits16GiB ordinary memory plus 2GiB HugePages, and4CPUs per worker. SGA1G/PGA2G leaves headroom for GI/ASM in this small lab. HugePages are separately reserved by Kubernetes; adding them to16GiB gives18GiB, not 16GiB total. We did not enable the development-mode validation bypass or ignore Oracle prerequisite failures. Runtime capacity remains untested until the user provisions RAC.

## 5. Install cert-manager and Oracle Database Operator

The reproducible manifests are in [config/vendor](../config/vendor/README.md). Original sources, versions, hashes, licensing and local adaptations are recorded there. Cert-manager1.17.4 matches Kubernetes 1.29 but is outside community maintenance. A currently maintained cert-manager release cannot simply be substituted on this fixed OCNE1.9 cluster without checking its Kubernetes support matrix.

Copy the individual prerequisite YAML files to ocne-cp. Never apply all of config/ recursively: it also contains the database manifest. On ocne-cp as labadmin:

```bash
cd ~/ocne-rac-prereqs
kubectl apply --server-side -f cert-manager-v1.17.4.yaml
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=240s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=240s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=240s
kubectl apply --server-side -f oracle-database-operator-2.2.0-rbac.yaml
kubectl apply --server-side -f rac-pv-rbac.yaml -f rac-multus-rbac.yaml -f rac-node-rbac.yaml
kubectl apply --server-side -f oracle-database-operator-2.2.0-system.yaml
kubectl wait --for=condition=Established crd/racdatabases.database.oracle.com --timeout=120s
kubectl wait --for=condition=Ready certificates --all -n oracle-database-operator-system --timeout=180s
kubectl rollout status deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system --timeout=240s
kubectl get racdatabases -A
```

The operator watches only rac and its own namespace and runs one lab replica. Its amd64 image is digest-pinned to the observed2.2.0 tag. Cluster-level read access to nodes/NADs and PV lifecycle access are required by the source; no database PV/PVC is precreated. Installing CRDs/controller does not provision a database.

## 6. Create prerequisite secrets and label workers

On ocne-cp as labadmin, read and run [Prepare-RAC-Secrets-And-Labels.sh](../scripts/Prepare-RAC-Secrets-And-Labels.sh) for its exact manual sequence. It refuses existing names, uses umask077, generates a strong random password without displaying it, encrypts it with RSA-OAEP/SHA256 and checks decryption by comparison. It creates a separate4096-bit RSA SSH key pair for RAC (not the workstation SSH key), then creates these Kubernetes secrets:

| Secret | Required keys |
|---|---|
| rac-db-password | key.pem, pwdfile.enc |
| rac-ssh-key | ssh-privkey, ssh-pubkey |

The manifest uses encryptionType:pkeyutl and matching OAEP options. There is no TDE block or TDE secret in this lab manifest. Protected recovery files reside at ~/.local/share/ocne-rac-secrets on ocne-cp. Never print them in logs, commit them, or include secret YAML in the handoff. The directory is 0700 and private files 0600. Keep backups through a protected credential mechanism.

Label only the two worker nodes with `raccluster=raccluster01`; retain existing labels. Verify `kubectl get nodes -L raccluster` and the secret names/key counts without displaying values. If names already exist, inspect and reuse intentionally rather than deleting secrets blindly.

## 7. User-supplied image and gold homes; final handoff

Continue with [RAC-PROVISIONING-HANDOFF.md](RAC-PROVISIONING-HANDOFF.md) for artifact names, staging commands, CVU gate, dry-run validation, user-only apply and post-deployment checks. The YAML has no deployment-time RU/OPatch fields. Do not run the historical RU extraction helpers when following the gold-home route.

No gold homes or slim image have yet been accepted by this run. CVU container-host validation subsequently passed on both workers; see [the results and commands](RAC-CVU-RESULTS.md). Artifact acceptance remains required before the user's provisioning step.

## Sources and attribution

Oracle retains attribution and licensing for its source material; the existing project LICENSE is preserved. Linux/RAC configuration is based on [Oracle RAC on OCNE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rackb/install-configure-rac-olcne.html) and the [pinned Oracle Database Operator 2.2.0 prerequisites](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/prerequisites_oracle_rac_db.md). The Windows/VirtualBox orchestration and observed fixes are local implementation.

Additional references: [OCNE1.9 Multus](https://docs.oracle.com/en/operating-systems/olcne/1.9/multus/install.html), [VirtualBox shared storage](https://docs.oracle.com/en/virtualization/virtualbox/7.2/user/storage.html), [Oracle Linux partitions](https://docs.oracle.com/en/operating-systems/oracle-linux/9/stordev/stordev-UsingDiskPartitions.html), [NetworkManager accept-all-mac-addresses](https://networkmanager.dev/docs/api/latest/settings-802-3-ethernet.html), [Kubernetes HugePages](https://kubernetes.io/docs/tasks/manage-hugepages/scheduling-hugepages/), [cert-manager releases](https://cert-manager.io/docs/releases/), [latest Oracle CVU](https://www.oracle.com/database/technologies/cvu-downloads.html), and [Oracle gold images](https://support.oracle.com/support/?kmContentId=2965269.1).

## Direct Bash command appendix

These are the exact reviewed guest-side command bodies, included here so a manual setup does not depend on the PowerShell SSH wrapper. Run them in Bash on the stated guest as the stated account. `set -euo pipefail` stops on a failed guard. The disk, MAC, machine-ID and UUID guards identify **this run**: for a new lab, inspect and record replacements first. A guard refusing to run on an already prepared machine is intentional. Do not paste the entire appendix as one script; verify each stage before the next.

The snippets are generated from the linked checked-in scripts. Host PowerShell only handles Windows orchestration and credential transport; every Linux mutation below is Bash.

### Scratch filesystem: root, each worker, new blank disk only

Source: [Prepare-RAC-Scratch.sh](../scripts/Prepare-RAC-Scratch.sh)

```bash
#!/bin/bash
# One-time local provisioning using the inspected new scratch-disk serials.
# XFS/mount procedure: Oracle Linux filesystem sources cited in guide Part D.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) serial=VB323d540b-8e123255; identity=7417ec2ac09a4e3c8439774fc7eaa7e5; label=rac-scratch1;;
 ocne-w2) serial=VBa7088f24-017bb508; identity=58e1f11845c44bcb9b82d2b5998beb45; label=rac-scratch2;;
 *) exit 1;;
esac
[[ $(cat /etc/machine-id) == "$identity" ]]
mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="$serial" '$2==serial {print $1}')
[[ ${#matches[@]} == 1 ]] || { echo 'Expected exactly one scratch serial'; exit 1; }
disk=${matches[0]}
[[ $(blockdev --getsize64 "$disk") == 137438953472 ]]
[[ $(lsblk -dnro TYPE "$disk") == disk ]]
[[ $(lsblk -nrpo NAME "$disk" | wc -l) == 1 ]]
[[ -z $(lsblk -nrpo MOUNTPOINTS "$disk") ]]
signatures=$(wipefs --no-act --noheadings --output TYPE "$disk")
[[ -z "$signatures" ]]
[[ -z $(ls -A "/sys/class/block/${disk##*/}/holders") ]]
! findmnt -rn -S "$disk" >/dev/null
! mountpoint -q /scratch
! awk '$1 !~ /^#/ && $2=="/scratch" {found=1} END {exit !found}' /etc/fstab
[[ ! -e /scratch || ( -d /scratch && -z $(ls -A /scratch) ) ]]
printf 'Identified blank scratch device: %s serial=%s\n' "$disk" "$serial"
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$disk"
mkfs.xfs -L "$label" "$disk"
uuid=$(blkid -s UUID -o value "$disk")
[[ $uuid =~ ^[0-9a-f-]{36}$ && $(blkid -s TYPE -o value "$disk") == xfs ]]
cp -a /etc/fstab "/etc/fstab.before-rac-scratch-$(date +%Y%m%d%H%M%S)"
mkdir -p /scratch
printf 'UUID=%s /scratch xfs defaults 0 0\n' "$uuid" >> /etc/fstab
systemctl daemon-reload
mount /scratch
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(findmnt -nro FSTYPE -M /scratch) == xfs ]]
findmnt -n -o SOURCE,UUID,FSTYPE,TARGET -M /scratch
df -h /scratch
printf 'Scratch mounted; ASM disks and existing root/container filesystems were not modified.\n'
```

### Shared ASM partitions: root, worker 1 only, new blank shared disks only

Source: [Prepare-RAC-ASM-Partitions.sh](../scripts/Prepare-RAC-ASM-Partitions.sh)

```bash
#!/bin/bash
# One-time GPT labels for two inspected blank shared ASM disks, on worker1 only.
# No filesystem or ASM disk group is created here.
# https://docs.oracle.com/en/operating-systems/oracle-linux/9/stordev/stordev-UsingDiskPartitions.html
set -euo pipefail
[[ $(id -u) == 0 && $(hostname -s) == ocne-w1 ]]
[[ $(cat /etc/machine-id) == 7417ec2ac09a4e3c8439774fc7eaa7e5 ]]
serials=(VBdb34f551-507d0f5a VBc280454f-7e0f28bc)
names=(ocne-rac-asm01 ocne-rac-asm02)
disks=()
for i in 0 1; do
 serial=${serials[$i]}
 mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="$serial" '$2==serial {print $1}')
 [[ ${#matches[@]} == 1 ]]
 disk=${matches[0]}
 [[ $(blockdev --getsize64 "$disk") == 53687091200 ]]
 [[ $(lsblk -nrpo NAME "$disk" | wc -l) == 1 ]]
 mounts=$(lsblk -nrpo MOUNTPOINTS "$disk")
 [[ -z "$mounts" ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$disk")
 [[ -z "$signatures" ]]
 [[ -z $(ls -A "/sys/class/block/${disk##*/}/holders") ]]
 [[ ! -e /dev/disk/by-partlabel/${names[$i]} ]]
 disks+=("$disk")
 printf 'Verified blank 50 GiB ASM disk: %s %s\n' "$disk" "$serial"
done
for i in 0 1; do
 disk=${disks[$i]}
 name=${names[$i]}
 parted -s -a optimal "$disk" mklabel gpt mkpart "$name" 1MiB 100%
 partprobe "$disk"
 udevadm settle
 partition=/dev/disk/by-partlabel/$name
 [[ -b $partition ]]
 [[ $(lsblk -nro PKNAME "$partition") == "${disk##*/}" ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$partition")
 [[ -z "$signatures" ]]
 lsblk -b -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,PARTUUID,SERIAL "$disk"
done
```

### Shared disk acceptance: root, both workers, before RAC uses them

Source: [Verify-RAC-Shared-Disks.sh](../scripts/Verify-RAC-Shared-Disks.sh)

```bash
#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
serials=(VBdb34f551-507d0f5a VBc280454f-7e0f28bc)
names=(ocne-rac-asm01 ocne-rac-asm02)
uuids=(c25151a5-4557-444f-916f-cc359f3fd43b 14cb5bdb-e6ff-4706-b82f-b0f748df5157)
for i in 0 1; do
 mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="${serials[$i]}" '$2==serial {print $1}')
 [[ ${#matches[@]} == 1 ]]
 disk=${matches[0]}
 [[ $(blockdev --getsize64 "$disk") == 53687091200 ]]
 partprobe "$disk"
 udevadm settle
 partition=/dev/disk/by-partlabel/${names[$i]}
 [[ -b $partition ]]
 [[ $(lsblk -nro PKNAME "$partition") == "${disk##*/}" ]]
 [[ $(blkid -s PARTUUID -o value "$partition") == "${uuids[$i]}" ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$partition")
 [[ -z "$signatures" ]]
 [[ -z $(lsblk -nro MOUNTPOINTS "$partition") ]]
 printf '%s %s %s\n' "$(hostname -s)" "${serials[$i]}" "${uuids[$i]}"
 dd if="$disk" bs=1M count=1 status=none | sha256sum
 lsblk -b -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,PARTUUID,SERIAL "$disk"
done
```

### Private NIC profiles: root, both workers, new profiles only

Source: [Configure-RAC-Private-NICs.sh](../scripts/Configure-RAC-Private-NICs.sh)

```bash
#!/bin/bash
# Observed VirtualBox NIC identities; isolated, unnumbered MACVLAN parent links.
# Oracle RAC controller prerequisites: private interfaces have no host IP addresses.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) mac1=08:00:27:be:02:40; mac2=08:00:27:2e:39:10;;
 ocne-w2) mac1=08:00:27:23:3e:b8; mac2=08:00:27:4f:c6:7f;;
 *) exit 1;;
esac
[[ $(cat /sys/class/net/enp0s8/address) == "$mac1" ]]
[[ $(cat /sys/class/net/enp0s9/address) == "$mac2" ]]
[[ -z $(ip -4 -o address show dev enp0s8) && -z $(ip -4 -o address show dev enp0s9) ]]
for i in 1 2; do
 if nmcli -g NAME connection show | grep -qxF "ocne-rac-private$i"; then echo 'Connection already exists; inspect partial run.'; exit 1; fi
done
for row in '1 enp0s8' '2 enp0s9'; do
 read -r number interface <<< "$row"
 nmcli connection add type ethernet ifname "$interface" con-name "ocne-rac-private$number" ipv4.method disabled ipv6.method disabled ethernet.mtu 1500 connection.autoconnect yes
 nmcli connection up "ocne-rac-private$number"
 [[ $(nmcli -g ipv4.method connection show "ocne-rac-private$number") == disabled ]]
 [[ $(nmcli -g ipv6.method connection show "ocne-rac-private$number") == disabled ]]
 [[ -z $(ip -4 -o address show dev "$interface") && -z $(ip -6 -o address show dev "$interface") ]]
done
ip -br link
ip -4 route
```

### Persistent macvlan reception: root, both workers

Source: [Enable-RAC-Private-Promiscuous.sh](../scripts/Enable-RAC-Private-Promiscuous.sh)

```bash
#!/bin/bash
set -euo pipefail
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
for number in 1 2; do
 if [[ $number == 1 ]]; then iface=enp0s8; else iface=enp0s9; fi
 profile=ocne-rac-private$number
 [[ $(nmcli -g connection.interface-name connection show "$profile") == "$iface" ]]
 [[ $(nmcli -g ipv4.method connection show "$profile") == disabled ]]
 nmcli connection modify "$profile" 802-3-ethernet.accept-all-mac-addresses 1
 # This NetworkManager property takes effect at next activation; set runtime below.
 ip link set dev "$iface" promisc on
 nmcli -g 802-3-ethernet.accept-all-mac-addresses connection show "$profile"
 ip -d link show "$iface" | grep PROMISC
done
```

### Worker OS settings and complete SELinux policy: root, both workers

Source: [Prepare-RAC-Worker.sh](../scripts/Prepare-RAC-Worker.sh)

```bash
#!/bin/bash
# Oracle RAC/OCNE prerequisites, locally sized for 22 GiB workers.
set -euo pipefail
[[ $(id -u) == 0 && $(getenforce) == Enforcing ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(wc -l < /proc/swaps) == 1 ]]
[[ $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource) == tsc ]]
for path in /etc/sysctl.d/98-ocne-rac.conf /var/opt/rac-ocne.te /scratch/rac/cluster01; do
 [[ ! -e $path ]] || { echo "Existing prerequisite asset: $path; inspect before continuing."; exit 1; }
done
grep -Fx 'KUBELET_EXTRA_ARGS="--fail-swap-on=false"' /etc/sysconfig/kubelet
rpm -q selinux-policy-devel policycoreutils-python-utils
backup=/var/opt/ocne-rac-backup-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup"
cp -a /etc/sysconfig/kubelet /etc/default/grub "$backup/"
grubby --info=ALL > "$backup/grubby-before.txt"
sysctl fs.file-max net.core.rmem_default net.core.rmem_max net.core.wmem_default net.core.wmem_max fs.aio-max-nr vm.nr_hugepages > "$backup/sysctl-before.txt"
cat > /etc/sysctl.d/98-ocne-rac.conf <<'SYSCTL'
# Oracle RAC on OCNE kernel prerequisites; HugePages sized for this lab.
fs.file-max = 6815744
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
vm.nr_hugepages = 1024
SYSCTL
sysctl -p /etc/sysctl.d/98-ocne-rac.conf
[[ $(sysctl -n vm.nr_hugepages) == 1024 ]]
# Oracle recommends disabling THP; use grubby for OL9 boot entries.
grubby --update-kernel=ALL --args='transparent_hugepage=never'
printf 'never\n' > /sys/kernel/mm/transparent_hugepage/enabled
sed -i 's/^KUBELET_EXTRA_ARGS=.*/KUBELET_EXTRA_ARGS="--fail-swap-on=false --allowed-unsafe-sysctls=kernel.shm*,net.*,kernel.sem"/' /etc/sysconfig/kubelet
cat > /var/opt/rac-ocne.te <<'POLICY'
module rac-ocne 1.0;
require {
 type kernel_t;
 class system syslog_read;
 type container_runtime_t;
 type container_init_t;
 type container_file_t;
 type lib_t;
 type textrel_shlib_t;
 type bin_t;
 class file { getattr execmod execute map setattr };
}
allow container_init_t container_runtime_t:file getattr;
allow container_init_t bin_t:file { map execute };
allow container_init_t container_file_t:file execmod;
allow container_init_t lib_t:file execmod;
allow container_init_t textrel_shlib_t:file setattr;
allow container_init_t kernel_t:system syslog_read;
POLICY
cd /var/opt
make -f /usr/share/selinux/devel/Makefile rac-ocne.pp
semodule -i rac-ocne.pp
for n in 1 2; do install -d -m 0755 -o 54321 -g 54321 /scratch/rac/cluster01/racnode$n; done
semanage fcontext -a -t container_file_t '/scratch/rac/cluster01(/.*)?'
semanage fcontext -a -t container_file_t '/scratch/software/stage(/.*)?'
restorecon -RF /scratch/rac/cluster01 /scratch/software/stage
systemctl daemon-reload
systemctl restart kubelet
systemctl is-active kubelet
semodule -l | grep '^rac-ocne'
getent passwd 54321 || true
ls -Zd /scratch/rac/cluster01/racnode{1,2} /scratch/software/stage
grep -E 'MemTotal|MemAvailable|HugePages|Hugepagesize' /proc/meminfo
cat /sys/kernel/mm/transparent_hugepage/enabled
printf 'RAC worker settings applied; backup: %s\n' "$backup"
```

### Empty gold-home staging: root, both workers

Source: [Prepare-RAC-Gold-Staging.sh](../scripts/Prepare-RAC-Gold-Staging.sh)

```bash
#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;; ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;; *) exit 1;; esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
path=/scratch/software/stage/19c/19.32-gold
[[ ! -e $path ]]
install -d -m 0755 -o labadmin -g labadmin "$path"
restorecon -RF "$path"
stat -c '%u:%g %a %n' "$path"
ls -Zd "$path"
```

### Secrets and labels: labadmin, ocne-cp, absent secret names only

Source: [Prepare-RAC-Secrets-And-Labels.sh](../scripts/Prepare-RAC-Secrets-And-Labels.sh)

```bash
#!/bin/bash
# Creates prerequisite secrets only. Never creates a RacDatabase.
set -euo pipefail
set +x
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
secret_dir="$HOME/.local/share/ocne-rac-secrets"
[[ ! -e $secret_dir ]]
for secret in rac-db-password rac-ssh-key; do
 existing=$(kubectl get secret -n rac "$secret" --ignore-not-found -o name)
 [[ -z $existing ]] || { echo "Secret exists: $secret; inspect before continuing."; exit 1; }
done
umask 077
install -d -m 0700 "$secret_dir"
python3 - "$secret_dir/db-password.txt" <<'PY'
import secrets,string,sys
alphabet=string.ascii_letters+string.digits
with open(sys.argv[1],'x') as target:
 target.write('Rac_' + ''.join(secrets.choice(alphabet) for _ in range(28)))
PY
openssl genrsa -out "$secret_dir/key.pem" 3072 2>/dev/null
openssl rsa -in "$secret_dir/key.pem" -out "$secret_dir/key.pub" -pubout 2>/dev/null
openssl pkeyutl -encrypt -pubin -inkey "$secret_dir/key.pub" -in "$secret_dir/db-password.txt" -out "$secret_dir/pwdfile.enc" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -pkeyopt rsa_mgf1_md:sha256
openssl pkeyutl -decrypt -inkey "$secret_dir/key.pem" -in "$secret_dir/pwdfile.enc" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256 -pkeyopt rsa_mgf1_md:sha256 | cmp - "$secret_dir/db-password.txt"
ssh-keygen -q -t rsa -b 4096 -N '' -C ocne-rac-lab -f "$secret_dir/id_rsa"
kubectl create secret generic rac-db-password -n rac --from-file=key.pem="$secret_dir/key.pem" --from-file=pwdfile.enc="$secret_dir/pwdfile.enc"
kubectl create secret generic rac-ssh-key -n rac --from-file=ssh-privkey="$secret_dir/id_rsa" --from-file=ssh-pubkey="$secret_dir/id_rsa.pub"
# Only names, key counts and file permissions are displayed; no secret content.
kubectl get secret -n rac rac-db-password rac-ssh-key
stat -c '%a %U %n' "$secret_dir" "$secret_dir/db-password.txt" "$secret_dir/id_rsa"
for node in ocne-w1.lab.test ocne-w2.lab.test; do
 existing=$(kubectl get node "$node" -o jsonpath='{.metadata.labels.raccluster}')
 [[ -z $existing || $existing == raccluster01 ]]
 kubectl label node "$node" raccluster=raccluster01 --overwrite=false
done
kubectl get nodes -L raccluster
```

### Worker acceptance after reboot: root, both workers

Source: [Verify-RAC-Worker.sh](../scripts/Verify-RAC-Worker.sh)

```bash
#!/bin/bash
# Read-only prerequisite verification on the prepared workers; no installer execution.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b; container_uuid=1ca6c397-b848-4e95-a24a-a96ea11a55cc;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319; container_uuid=50e55c0d-a63c-41c4-b66c-7a46cae288ab;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(findmnt -nro UUID -M /var/lib/containers) == "$container_uuid" ]]
[[ $(getenforce) == Enforcing ]]
[[ $(wc -l < /proc/swaps) == 1 ]]
[[ $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource) == tsc ]]
[[ $(sysctl -n vm.nr_hugepages) == 1024 ]]
grep -F '[never]' /sys/kernel/mm/transparent_hugepage/enabled
[[ $(awk '/Hugepagesize:/{print $2}' /proc/meminfo) == 2048 ]]
grep -F -- '--allowed-unsafe-sysctls=kernel.shm*,net.*,kernel.sem' /etc/sysconfig/kubelet
semodule -l | grep '^rac-ocne'
for pair in fs.file-max:6815744 net.core.rmem_default:262144 net.core.rmem_max:4194304 net.core.wmem_default:262144 net.core.wmem_max:1048576 fs.aio-max-nr:1048576; do
 [[ $(sysctl -n "${pair%:*}") == "${pair#*:}" ]]
done
for n in 1 2; do
 if [[ $n == 1 ]]; then iface=enp0s8; else iface=enp0s9; fi
 [[ $(nmcli -g 802-3-ethernet.accept-all-mac-addresses connection show ocne-rac-private$n) == 1 ]]
 ip -d link show "$iface" | grep PROMISC
 [[ -z $(ip -4 -o addr show dev "$iface") ]]
 [[ $(stat -c '%u:%g' /scratch/rac/cluster01/racnode$n) == 54321:54321 ]]
 ls -Zd /scratch/rac/cluster01/racnode$n | grep container_file_t
done
chronyc waitsync 12 0.1 0 5
systemctl is-active kubelet crio chronyd firewalld
findmnt -M /mnt/ocne-share
grep -E 'MemTotal|MemAvailable|HugePages|Hugepagesize' /proc/meminfo
printf 'boot_id='; cat /proc/sys/kernel/random/boot_id
printf 'kernel='; uname -r
printf 'Persistent worker prerequisite checks passed. Gold media, image and CVU are separate gates.\n'
```

### Equivalent host commands in Windows Git Bash

Use these only on a new inspected build, with both workers powered off and the chosen SATA/NIC slots empty. Do not run these on the prepared lab. Git Bash uses the Windows VirtualBox executable; `D:/OCNE19-Lab` keeps new assets in the project. The PowerShell helper adds the exact VM/original-disk guards described above; retain equivalent checks when working manually.

```bash
set -euo pipefail
VBOX='/c/Program Files/Oracle/VirtualBox/VBoxManage.exe'
LAB_ROOT='D:/OCNE19-Lab'
"$VBOX" list vms
"$VBOX" list runningvms
"$VBOX" list intnets
for node in ocne-w1 ocne-w2; do
 "$VBOX" showvminfo "$node" --machinereadable
 # Review VM UUID, original disks, free SATA3/4/5 and free NIC2/NIC3 here.
 "$VBOX" showvminfo "$node" --machinereadable | grep -Fx 'VMState="poweroff"'
done
# After inspection: every intended disk path must be absent.
for node in ocne-w1 ocne-w2; do
 test ! -e "$LAB_ROOT/vms/$node/$node-scratch.vdi"
done
for number in 01 02; do
 test ! -e "$LAB_ROOT/vms/rac-shared/ocne-rac-asm$number.vdi"
done
mkdir -p "$LAB_ROOT/vms/rac-shared"
for node in ocne-w1 ocne-w2; do
 disk="$LAB_ROOT/vms/$node/$node-scratch.vdi"
 "$VBOX" createmedium disk --filename "$disk" --size 131072 --format VDI --variant Standard
 "$VBOX" showmediuminfo disk "$disk"
 "$VBOX" storageattach "$node" --storagectl SATA --port 3 --device 0 --type hdd --medium "$disk" --mtype normal
done
for number in 01 02; do
 if [[ $number == 01 ]]; then port=4; else port=5; fi
 disk="$LAB_ROOT/vms/rac-shared/ocne-rac-asm$number.vdi"
 "$VBOX" createmedium disk --filename "$disk" --size 51200 --format VDI --variant Fixed
 "$VBOX" modifymedium disk "$disk" --type shareable
 "$VBOX" showmediuminfo disk "$disk"
 for node in ocne-w1 ocne-w2; do
  "$VBOX" storageattach "$node" --storagectl SATA --port "$port" --device 0 --type hdd --medium "$disk" --mtype shareable
 done
done
for node in ocne-w1 ocne-w2; do
 "$VBOX" modifyvm "$node" --nic2 intnet --intnet2 ocne-rac-priv1 --nictype2 82540EM --nicpromisc2 allow-vms --cableconnected2 on --nic3 intnet --intnet3 ocne-rac-priv2 --nictype3 82540EM --nicpromisc3 allow-vms --cableconnected3 on
 "$VBOX" showvminfo "$node"
done
```

The Bash host equivalent has been syntax-checked, not executed as a second provisioning run. Compare every result with the intended inventory and stop on partial state. Do not rerun creation to recover an error. On a Linux VirtualBox host, set VBOX to its installed executable and LAB_ROOT to the intended project directory instead; Windows host inspection/power settings do not apply there.
