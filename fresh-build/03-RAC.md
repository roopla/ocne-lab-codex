# 3. Provisioning the RAC database

[Start](README.md) | [Previous: Database Operator](02-DATABASE-OPERATOR.md)

This chapter creates a **new** database from a compatible slim container and already-patched GI/database gold homes. It does not apply binary RU/OPatch updates during deployment. SQL dictionary patching during DBCA still needs verification. The operator creates StatefulSets, block PV/PVCs, listeners and GI/ASM/database configuration.

## 3a. Prerequisites

### 3a.1 Prepare the hardware and select deployment values

| Requirement | Example | Check / correction |
|---|---|---|
| Two workers | Each 22 GiB / 6 vCPU; one RAC pod each at 16 GiB / 4 CPU | Inspect kubectl describe nodes; leave room for OS/system pods |
| Local homes/staging | Independent 128 GiB XFS /scratch per worker | Record separate UUIDs; this is not shared ASM |
| Image storage | Dedicated 100 GiB XFS /var/lib/containers per worker | Must be mounted before storing images |
| Shared ASM | Same two writable 50 GiB shared disks visible on both workers | Match storage IDs and guest serials/PARTUUIDs, not size alone |
| Private network 1 | Isolated 192.168.78.0/24 on enp0s8 | MTU 1500; hypervisor and guest permit extra MACs |
| Private network 2 | Isolated 192.168.79.0/24 on enp0s9 | Separate network; no host IP/default route on private parents |
| Database | RACCDB; PDB LABPDB; application service labpdb_app | Finalize before immutable CR creation |
| Memory | SGA 3 GiB; PGA target 2 GiB; HugePages 0; THP never | Local choice; PGA target is not a process memory cap |

Attach blank disks and private NICs before continuing. For VirtualBox, the [hardware appendix](VIRTUALBOX-HARDWARE.md) provides the copy/paste branch using **shareable** fixed disks attached to both workers. Do not use multiattach disks: their separate differencing writes are not shared ASM storage. Other platforms need their own supported shared-block mechanism. EXTERNAL redundancy has no ASM mirroring; two disks provide capacity, not a backup.

### 3a.2 Inventory disks and copy preparation files

**Run:** each worker, then workstation.

Each worker (the package list supplies local command-line tools used below):

```bash
sudo dnf install -y parted xfsprogs unzip python3 openssl
hostname -f
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL,UUID,PARTUUID
findmnt
ls -l /dev/disk/by-id/
ip -br link
sudo wipefs --no-act /dev/disk/by-id/YOUR_VERIFIED_DISK_ID
```

Replace the disk ID only after matching its serial/size/attachment. Inspect every scratch/ASM candidate. Workstation repository root:

```bash
for host in ocne-w1.lab.test ocne-w2.lab.test ocne-cp.lab.test; do
  ssh "labadmin@$host" 'install -d -m 0700 ~/ocne-fresh-support'
  scp fresh-build/support/*.sh "labadmin@$host:~/ocne-fresh-support/"
done
```

**Expected:** tool installation succeeds; scratch is an unused independent 128 GiB disk per worker, ASM candidates are the same blank 50 GiB disks on both workers; helpers copied.

**If not:** stop on signatures, partitions, mounts, holders, ambiguous serials or inspection errors. Resolve identity using hypervisor inventory. Helpers retain example hostname/account guards; customize only to your verified hosts.

### 3a.3 Initialize scratch once

**Run:** each worker before RAC.

```bash
cat ~/ocne-fresh-support/prepare-scratch.sh
bash -n ~/ocne-fresh-support/prepare-scratch.sh
sudo bash ~/ocne-fresh-support/prepare-scratch.sh
findmnt -M /scratch -o SOURCE,UUID,FSTYPE,TARGET
df -h /scratch
```

**Expected:** prompt for verified serial; blank/unused disk checks, XFS and UUID-based fstab entry; /scratch verified. Record UUID for 3a.7.

**If not:** read the guard failure. If already mounted, verify identity/persistence instead of reinitializing. [Full commands](support/prepare-scratch.sh) show every check, mkfs and mount; no /dev/sdb assumption.

### 3a.4 Partition shared ASM once

**Run:** worker1 only, then inspect both workers.

```bash
cat ~/ocne-fresh-support/prepare-asm.sh
bash -n ~/ocne-fresh-support/prepare-asm.sh
sudo bash ~/ocne-fresh-support/prepare-asm.sh
```

Both workers:

```bash
sudo partprobe
sudo udevadm settle
for label in ocne-rac-asm01 ocne-rac-asm02; do
  path=/dev/disk/by-partlabel/$label
  test -b "$path" || break
  lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,PARTLABEL,PARTUUID,SERIAL "$path"
  sudo blkid -s PARTUUID -o value "$path"
  sudo wipefs --no-act "$path"
done
```

**Expected:** ocne-rac-asm01/02 partitions with matching PARTUUIDs across workers; no filesystem/mount. Both blank disks are checked before partitioning; no mkfs.

**If not:** different IDs mean different backing storage: stop. Existing signatures require inspection, not wiping. [Full commands](support/prepare-asm.sh) run only on worker1. Never repeat after RAC writes ASM signatures.

### 3a.5 Configure private NICs

**Run:** root on each worker.

```bash
nmcli connection show
nmcli connection add type ethernet ifname enp0s8 con-name ocne-rac-private1 ipv4.method disabled ipv6.method disabled ethernet.mtu 1500 connection.autoconnect yes
nmcli connection add type ethernet ifname enp0s9 con-name ocne-rac-private2 ipv4.method disabled ipv6.method disabled ethernet.mtu 1500 connection.autoconnect yes
nmcli connection modify ocne-rac-private1 802-3-ethernet.accept-all-mac-addresses 1
nmcli connection modify ocne-rac-private2 802-3-ethernet.accept-all-mac-addresses 1
nmcli connection up ocne-rac-private1
nmcli connection up ocne-rac-private2
ip -d link show enp0s8
ip -d link show enp0s9
ip -4 address show
ip -6 address show
ip route
```

**Expected:** private parents UP/PROMISC, MTU 1500, no host IP/default gateway; SSH NIC unchanged.

**If not:** match MACs to hypervisor adapters before substituting names. Inspect existing profiles instead of adding duplicates. If NetworkManager cannot reapply the property, persist it then use `ip link set dev enp0s8 promisc on` and likewise enp0s9. Verify after reboot; host allow-vms alone was insufficient.

### 3a.6 Install Multus and network definitions

**Run:** operator, workstation, then control plane.

Operator as labadmin:

```bash
olcnectl module instances --environment-name homelab
# Only when rac-multus is absent:
olcnectl module create --environment-name homelab --module multus --name rac-multus --multus-kubernetes-module cluster1
olcnectl module install --environment-name homelab --name rac-multus
olcnectl module report --environment-name homelab --name rac-multus --children
```

Workstation root; review/customize both YAMLs first:

```bash
scp config/rac-networks.yaml config/rac-network-check.yaml labadmin@ocne-cp.lab.test:~/ocne-rac-prereqs/
```

Control plane:

```bash
kubectl apply -f ~/ocne-rac-prereqs/rac-networks.yaml
kubectl rollout status daemonset/kube-multus-ds -n kube-system --timeout=240s
kubectl get daemonset kube-multus-ds -n kube-system
kubectl get network-attachment-definitions -n rac
kubectl get network-attachment-definition macvlan-conf1 -n rac -o yaml
kubectl get network-attachment-definition macvlan-conf2 -n rac -o yaml
```

**Expected:** Multus 3/3 Ready, macvlan-conf1/2 NADs present; parent names match 3a.5.

**If not:** inspect Multus events/logs and NAD JSON. Dedicate host-local ranges to this RAC cluster; host-local is not global IP allocation. Keep diagnostic .128/.129 separate. [NAD YAML](../config/rac-networks.yaml) and [diagnostic YAML](../config/rac-network-check.yaml) must match your names/subnets.

### 3a.7 Prepare persistent worker settings

**Run:** root on each worker.

Check scratch before creating directories:

```bash
findmnt -M /scratch -o SOURCE,UUID,FSTYPE,TARGET
mountpoint -q /scratch || exit 1
```

```bash
dnf install -y selinux-policy-devel policycoreutils-python-utils make
install -d -m 0755 /scratch/software/stage
findmnt -M /scratch -o SOURCE,UUID,FSTYPE,TARGET
cat /etc/sysconfig/kubelet
getenforce
cat /proc/swaps
cat /sys/devices/system/clocksource/clocksource0/current_clocksource
```

```bash
cat /home/labadmin/ocne-fresh-support/prepare-worker.sh
bash -n /home/labadmin/ocne-fresh-support/prepare-worker.sh
bash /home/labadmin/ocne-fresh-support/prepare-worker.sh
```

**Expected:** prompted UUID matches; sysctls applied, HugePages zero, THP never, kubelet permits RAC sysctls; SELinux module installed and paths labeled container_file_t; kubelet active.

**If not:** [full worker commands](support/prepare-worker.sh) preserve existing kubelet arguments/backups and stop on occupied files or unknown formats. Inspect before adapting. Resolve non-TSC clocksource using Oracle requirements. Inspect SELinux AVCs with `ausearch -m AVC -ts recent`; retain enforcing.

### 3a.8 Check reboot persistence

**Run:** one worker at a time, then control plane.

```bash
sudo reboot
```

Reconnect to that worker:

```bash
cat /proc/sys/kernel/random/boot_id
findmnt -M /scratch
findmnt -M /var/lib/containers
getenforce
sysctl vm.nr_hugepages fs.file-max fs.aio-max-nr
cat /sys/kernel/mm/transparent_hugepage/enabled
ip -d link show enp0s8
ip -d link show enp0s9
sudo semodule -l | grep '^rac-ocne'
systemctl is-active kubelet crio chronyd firewalld
chronyc tracking
```

Control plane, use the node just rebooted:

```bash
kubectl wait --for=condition=Ready node/ocne-w1.lab.test --timeout=300s
kubectl get nodes -o wide
```

**Expected:** mounts restored, Enforcing, HugePages 0, THP [never], private NICs PROMISC, services active, synchronized NTP, worker Ready. Repeat for worker2.

**If not:** repair failed fstab/service/profile persistence before restarting the other worker. These are empty workers before RAC; later reboots require database maintenance and tested recovery.

### 3a.9 Test scheduling and private paths

**Run:** control plane as labadmin.

```bash
kubectl get racdatabases -n rac
kubectl get pods -n rac
# Continue only after confirming the absence described above.
kubectl apply -f ~/ocne-rac-prereqs/rac-network-check.yaml
kubectl wait -n rac --for=condition=Ready pod/rac-netcheck-w1 pod/rac-netcheck-w2 --timeout=180s
kubectl get pods -n rac -o wide
kubectl exec -n rac rac-netcheck-w1 -- ip -4 address show
kubectl exec -n rac rac-netcheck-w2 -- ip -4 address show
kubectl exec -n rac rac-netcheck-w1 -- ping -c 3 -s 1472 -I ens1 192.168.78.129
kubectl exec -n rac rac-netcheck-w1 -- ping -c 3 -s 1472 -I ens2 192.168.79.129
kubectl exec -n rac rac-netcheck-w2 -- ping -c 3 -s 1472 -I ens1 192.168.78.128
kubectl exec -n rac rac-netcheck-w2 -- ping -c 3 -s 1472 -I ens2 192.168.79.128
kubectl exec -n rac rac-netcheck-w1 -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -n rac rac-netcheck-w2 -- nslookup kubernetes.default.svc.cluster.local
kubectl exec -n rac rac-netcheck-w1 -- sysctl kernel.shmmax kernel.shmall
kubectl exec -n rac rac-netcheck-w2 -- sysctl kernel.shmmax kernel.shmall
# After checking results, remove ONLY these diagnostics to release resources:
kubectl delete pod -n rac rac-netcheck-w1 rac-netcheck-w2
```

**Expected:** two diagnostic pods schedule with RAC-sized requests; bidirectional pings on both interfaces, working DNS and matching sysctls. Delete only these diagnostics after checks.

**If not:** use `kubectl describe pod -n rac rac-netcheck-w1` and worker2 counterpart. Pending: resources/selector; sandbox error: CNI/sysctl; one-way unicast: MAC/promiscuity. Do not reduce below operator minimum memory.

### 3a.10 Stage the slim image

**Run:** each worker.

```bash
RAC_IMAGE='docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d'
sudo crictl pull "$RAC_IMAGE"
sudo crictl images
sudo crictl inspecti "$RAC_IMAGE"
```

**Expected:** same immutable image digest in both CRI-O stores and database YAML.

**If not:** Docker/rootless Podman uses a different image store. Check CRI-O endpoint and registry access. This is an owner-supplied example, not an Oracle publisher image. [Image contract checks](../docs/RAC-ARTIFACT-ACCEPTANCE.md) cover user IDs, systemd and startup scripts. This digest has known GI restart defects; see 3b.7.

### 3a.11 Stage patched gold homes

**Run:** workers then workstation.

Each worker as labadmin, verified scratch only:

```bash
mountpoint -q /scratch || exit 1
sudo install -d -m 0755 -o labadmin -g labadmin /scratch/software/stage/19c/19.32-gold
sudo restorecon -RF /scratch/software/stage
ls -la /scratch/software/stage/19c/19.32-gold
```

Workstation root; destinations must be empty. Put your gold ZIPs under ISO/:

```bash
python fresh-build/support/check-archives.py
sha256sum ISO/oracle-gridhome-19.32.zip ISO/oracle-dbhome-19.32.zip
for host in ocne-w1.lab.test ocne-w2.lab.test; do
  scp ISO/oracle-gridhome-19.32.zip ISO/oracle-dbhome-19.32.zip "labadmin@$host:/scratch/software/stage/19c/19.32-gold/"
done
```

Both workers:

```bash
cd /scratch/software/stage/19c/19.32-gold
sha256sum oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
unzip -tq oracle-gridhome-19.32.zip
unzip -tq oracle-dbhome-19.32.zip
sudo chown 54321:54321 oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
sudo chmod 0755 oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
sudo restorecon -RF /scratch/software/stage/19c/19.32-gold
ls -lZ oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
df -h /scratch /var/lib/containers
```

**Expected:** archive CRC/path checks pass, installer at each home root, hashes match both destinations, numeric ownership/labels correct and enough expansion space.

**If not:** reject damaged/wrapped archives or mismatched versions/hashes. Never overwrite unchecked staging. Filename is not patch evidence; compare producer inventories now and runtime inventories later. 19.32 is RU level, not OPatch version. Owner deemed DBCA fix 34436514 unnecessary for these homes; reassess for different media.

### 3a.12 Run CVU on both final configurations

**Run:** workers, workstation, then workers.

Each worker, verified scratch:

```bash
sudo install -d -m 0755 -o labadmin -g labadmin /scratch/tools/cvu-23.26.3
```

Workstation root, downloaded Oracle CVU:

```bash
sha256sum ISO/cvupack_linux_ol8_x86_64.zip
scp ISO/cvupack_linux_ol8_x86_64.zip labadmin@ocne-w1.lab.test:/scratch/tools/cvu-23.26.3/
scp ISO/cvupack_linux_ol8_x86_64.zip labadmin@ocne-w2.lab.test:/scratch/tools/cvu-23.26.3/
```

Each worker as labadmin; compare hash before extracting:

```bash
set -euo pipefail
cd /scratch/tools/cvu-23.26.3
sha256sum cvupack_linux_ol8_x86_64.zip
unzip -tq cvupack_linux_ol8_x86_64.zip
test ! -e bin
unzip -q -n cvupack_linux_ol8_x86_64.zip
./bin/cluvfy -version
./bin/cluvfy comp -help
report="$HOME/cvu-reports/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$report"
./bin/cluvfy comp containerhost -type k8 -verbose -text -savedir "$report"
```

**Expected:** version/help match actual archive, hash matches source, containerhost exits 0 and applicable checks pass on both workers.

**If not:** review saved reports and correct each reported issue before rerun. No -n/-r switch for this component; avoid automatic fixups. Historical CVU passed before HugePages were disabled. If current CVU rejects this no-HugePages profile, stop and resolve/document applicability; do not call it a pass. [Oracle CVU](https://www.oracle.com/database/technologies/cvu-downloads.html).

### 3a.13 Create protected secrets and worker labels

**Run:** control plane as labadmin.

```bash
cat ~/ocne-fresh-support/create-secrets.sh
bash -n ~/ocne-fresh-support/create-secrets.sh
bash ~/ocne-fresh-support/create-secrets.sh
```

**Expected:** two Secrets with two keys each, recovery directory 700/files 600; both workers labeled raccluster=raccluster01.

**If not:** [full commands](support/create-secrets.sh) generate 24 characters (avoiding GI limit 30), encrypt using RSA-OAEP/SHA256 and compare decryption without exposing plaintext. Existing objects stop the script; never overwrite live secrets. Securely back up recovery files.

**Prerequisites gate:** all steps pass on the final configuration; chapter 2 controller/certificates remain healthy, diagnostics removed, media hashes match, and names/storage IDs recorded. Do not create RAC with an unresolved gate.

## 3b. Setting up

### 3b.1 Review the full manifest

Use [config/rac-database.yaml](../config/rac-database.yaml), adapted from Oracle's [2.2.0 provisioning sample](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/racdb_prov.yaml). It is the fresh-build manifest; rac-database-live.yaml is for the existing lab only.

| Field | Must match |
|---|---|
| spec.image | Immutable digest actually staged on both workers |
| instanceDetails.workerNodeSelector | raccluster label on intended workers |
| instanceDetails.privateIPDetails | NAD names and pod interfaces ens1/ens2 |
| asmDiskGroupDetails | Two verified shared partition labels, EXTERNAL redundancy |
| dbSecret / sshKeySecret | Names, keys and encryption options from 3a.13 |
| configParams | Actual home/staging paths, ZIP names, RACCDB/LABPDB, SGA 3G/PGA 2G |
| serviceDetails | labpdb_app attached to LABPDB, distinct from reserved service labpdb |
| envVars | ORACLE_PDB_NAME=LABPDB for this image |
| resources | 4 CPU / 16Gi requests and limits per pod; no hugepages resources |

This image reads ORACLE_PDB_NAME while operator 2.2.0 emits ORACLE_PDB; the explicit variable prevents the original ORCLPDB mismatch. Gold-home deployment has no ruPatchLocation/oPatchLocation/oneOffLocation.

### 3b.2 Transfer and validate admission

**Run:** workstation then control plane.

Workstation root:

```bash
sha256sum config/rac-database.yaml
scp config/rac-database.yaml labadmin@ocne-cp.lab.test:~/ocne-rac-prereqs/
```

Control plane, compare hashes:

```bash
set -euo pipefail
cd ~/ocne-rac-prereqs
sha256sum rac-database.yaml
kubectl get racdatabases -A
kubectl get pods,pvc,services -n rac
kubectl get pv
test -z "$(kubectl get racdatabase rac19c -n rac --ignore-not-found -o name)"
kubectl create --dry-run=server -f rac-database.yaml
```

**Expected:** rac19c absent, no unexpected RAC resources, created (server dry run) without creating a CR.

**If not:** an existing CR means this is not a fresh target. Compare schema using `kubectl explain racdatabase.spec --api-version=database.oracle.com/v4`; repair chapter 2 for webhook errors. Never delete a live CR or bypass immutable validation. Dry-run does not validate disk/image contents.

### 3b.3 Create once and monitor

**Run:** control plane as labadmin.

```bash
kubectl create -f ~/ocne-rac-prereqs/rac-database.yaml
kubectl get racdatabase rac19c -n rac -w
```

```bash
kubectl get pods,statefulsets,pvc,services -n rac -o wide
kubectl get pv
kubectl get events -n rac --sort-by=.metadata.creationTimestamp
```

```bash
kubectl describe pod racnode1-0 -n rac
kubectl describe pod racnode2-0 -n rac
kubectl logs deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system --tail=100
kubectl exec -n rac racnode1-0 -- ls -lt /u01/app/oracle/cfgtoollogs/dbca/RACCDB
kubectl get racdatabase rac19c -n rac -o jsonpath='{.status.state}{"\n"}'
```

**Expected:** operator creates volumes/StatefulSets/services, extracts/configures homes, GI/ASM and DBCA. Eventually state AVAILABLE and both pods Ready. Ctrl+C ends only the watch.

**If not:** inspect events/describe for scheduling, image, CNI and volume failures; controller logs for reconciliation; newest GI/DBCA logs for installer progress. Read logs privately: they can contain passwords. Slow installation is not a reason to submit a second create.

### 3b.4 Verify GI and ASM

**Run:** control plane as labadmin.

```bash
kubectl wait -n rac --for=condition=Ready pod/racnode1-0 pod/racnode2-0 --timeout=300s
kubectl exec -n rac racnode1-0 -- /u01/app/19c/grid/bin/crsctl check crs
kubectl exec -n rac racnode2-0 -- /u01/app/19c/grid/bin/crsctl check crs
kubectl exec -n rac racnode1-0 -- /u01/app/19c/grid/bin/olsnodes -n
kubectl exec -n rac racnode1-0 -- /u01/app/19c/grid/bin/crsctl stat res -t
kubectl exec -n rac racnode1-0 -- su - grid -c 'export ORACLE_SID=+ASM1; /u01/app/19c/grid/bin/asmcmd lsdg'
kubectl exec -n rac racnode2-0 -- su - grid -c 'export ORACLE_SID=+ASM2; /u01/app/19c/grid/bin/asmcmd lsdg'
```

```bash
kubectl exec -n rac racnode1-0 -- /u01/app/19c/grid/bin/crsctl query css votedisk
```

**Expected:** CRS online on both, two cluster nodes, DATA MOUNTED/EXTERN with zero offline disks and online voting files.

**If not:** inspect CRS resources/logs, private connectivity and actual shared device mappings. A Ready TCP probe is not database acceptance. Never repartition/reformat ASM to fix status.

### 3b.5 Verify SQL, memory and patches; disable database HugePages

**Run:** control plane as labadmin.

```bash
kubectl exec -i -n rac racnode1-0 -- su - oracle -c "export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'" <<'SQL'
whenever oserror exit failure
whenever sqlerror exit failure
set lines 200 pages 100
select inst_id,instance_name,status,database_status from gv$instance order by inst_id;
select name,open_mode,database_role from v$database;
select inst_id,name,open_mode from gv$pdbs order by inst_id,con_id;
select inst_id,name,value from gv$parameter where name in ('sga_target','sga_max_size','pga_aggregate_target','use_large_pages') order by name,inst_id;
select con_id,patch_id,action,status,description from cdb_registry_sqlpatch order by con_id,action_time;
select con_id,comp_id,status from cdb_registry where status <> 'VALID';
exit
SQL
for pod in racnode1-0 racnode2-0; do
  kubectl exec -n rac "$pod" -- su - grid -c '/u01/app/19c/grid/OPatch/opatch lspatches'
  kubectl exec -n rac "$pod" -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/OPatch/opatch lspatches'
done
```

Only after DBCA finishes and both instances are OPEN, explicitly disable database HugePages and restart the database before workloads:

```bash
set -euo pipefail
kubectl exec -i -n rac racnode1-0 -- su - oracle -c "export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'" <<'SQL'
whenever sqlerror exit failure
alter system set use_large_pages='FALSE' scope=spfile sid='*';
alter pluggable database LABPDB save state instances=all;
exit
SQL
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop database -db RACCDB -stopoption IMMEDIATE'
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start database -db RACCDB'
```

**Expected:** two OPEN/ACTIVE instances, RACCDB PRIMARY/READ WRITE, LABPDB READ WRITE on both, SGA target/max 3221225472 and PGA target 2147483648. Expected binary inventories and successful SQL patch records; no invalid components. After the database restart repeat the first query block, requiring USE_LARGE_PAGES=FALSE.

**If not:** run the restart block only once DBCA finishes and both instances are OPEN. Compare dictionary records with your gold-home inventory before following Oracle datapatch guidance. No binary patch application is configured. For allocation errors inspect ordinary-memory headroom and cgroup limits; preserve 3G/2G targets rather than assuming all worker RAM belongs to Oracle.

### 3b.6 Test service registration and both listeners

**Run:** control plane, then SQL prompt.

Control plane:

```bash
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl config service -db RACCDB -service labpdb_app'
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
kubectl get services,endpointslices -n rac
```

```bash
kubectl exec -it -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus /nolog'
```

Retrieve the password from the protected recovery file `~/.local/share/ocne-rac-secrets/db-password.txt` only in a private, unrecorded session. At SQL>, connect and enter it only at the password prompt:

```sql
connect system@//192.168.77.12:31522/labpdb_app
select sys_context('USERENV','CON_NAME'),sys_context('USERENV','INSTANCE_NAME') from dual;
connect system@//192.168.77.13:31523/labpdb_app
select sys_context('USERENV','CON_NAME'),sys_context('USERENV','INSTANCE_NAME') from dual;
exit
```

**Expected:** labpdb_app runs on both instances and maps to LABPDB. Queries return LABPDB/RACCDB1 and LABPDB/RACCDB2 via the respective worker listeners.

**If not:** ORA-12514: verify srvctl registration, Service/EndpointSlices and service name rather than SID. Timeout: check actual NodePorts/routes/firewall. ORA-44314: the application service must differ from automatic PDB service. TCP reachability alone is not SQL acceptance.

### 3b.7 Completion and recovery gate

Retain your own sanitized outputs from 3b.4-3b.6. Expected summary (illustrative, not a fresh execution transcript):

```text
RacDatabase: AVAILABLE
racnode1-0 / racnode2-0: 1/1 Running, Ready
RACCDB1 / RACCDB2: OPEN / ACTIVE
LABPDB on both instances: READ WRITE
DATA: MOUNTED; offline disks 0
SGA: 3221225472; PGA target: 2147483648; USE_LARGE_PAGES: FALSE
labpdb_app: on both instances; both network SQL tests return LABPDB
```

Take an RMAN backup and preserve each node's /etc/oracle in its persistent /u01 location **before pod replacement**. The supplied image needed assisted GI recovery on one replacement and logged a duplicate CRS start on another. Use the exact [backup/GI recovery commands](../docs/RAC-POD-EXERCISES.md#s05-s08-instances-and-one-pod-replacement) and [RMAN procedure](../docs/RAC-POD-EXERCISES.md#s23-s26-planned-outages-backups-and-template-updates). These defects remain a limitation; successful initial creation does not establish unattended restart safety.

## Quick failure lookup

| Symptom | Inspect command / check | Correction and success check |
|---|---|---|
| Pod Pending | kubectl describe pod -n rac racnode1-0 | Release diagnostics; correct labels/resources; RAC pods schedule on distinct intended workers |
| SysctlForbidden | kubectl get events -n rac --sort-by=.metadata.creationTimestamp | Compare kubelet allowance from 3a.7, restart/recheck kubelet |
| Private pings fail | ip -d link show enp0s8 (and enp0s9), both workers | Correct parent/MTU and hypervisor/guest promiscuity; repeat four pings |
| Home permission denied | ls -ldZ /scratch/rac/cluster01 /scratch/software/stage | Correct ownership and restorecon using 3a.7 policy; keep Enforcing |
| GI INS-30003 password limit | Inspect GI installer error privately | New-install password <=30 characters; helper uses 24. Do not change only a Secret on a partial DB |
| ORCLPDB instead of LABPDB | gv$pdbs query from 3b.5 | Correct fresh image variable before create; existing DB needs incident recovery |
| OOMKilled / memory allocation failure | kubectl describe pod -n rac racnode1-0; free -h on its worker | Restore ordinary-memory headroom and inspect Oracle/cgroup limits; rerun SQL checks |
| Immutable-field rejection | kubectl get racdatabase rac19c -n rac | Stop fresh path; inspect existing-lab procedure, preserve CR/data |
| GI failure after pod replacement | Current startup/GI logs, privately | Linked assisted recovery and backup prerequisites; no repeated pod deletions |

Sources: [Oracle RAC on OCNE](https://docs.oracle.com/en/database/oracle/oracle-database/19/rackb/install-configure-rac-olcne.html), [pinned prerequisites](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/prerequisites_oracle_rac_db.md), [provisioning](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/provisioning_oracle_rac_db.md), [OCNE Multus](https://docs.oracle.com/en/operating-systems/olcne/1.9/multus/install.html), [Oracle Linux partitions](https://docs.oracle.com/en/operating-systems/oracle-linux/9/stordev/stordev-UsingDiskPartitions.html), [USE_LARGE_PAGES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/USE_LARGE_PAGES.html). support/ contains local guarded manual commands adapted from the longer manual, not Oracle installers.
