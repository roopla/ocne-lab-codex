# RAC pod scenario workbook

[Manual start](OCNE-RAC-END-TO-END-MANUAL.md) | [Commands and expected/actual test table](RAC-TEST-SCENARIO-MATRIX.md) | [Chapter 4: commands and explanations](MANUAL-04-RAC-OPERATIONS.md)

This workbook covers the principal RAC/Kubernetes operating and failure scenarios for this two-worker lab. It is not a claim to exhaust every possible software, storage or infrastructure failure. Each scenario separates an actual observation from a proposed fault injection. **A documented command is not a recorded test result.**

## Execution ledger and coverage

**Updated 12 October 2026, 11:44 UTC.** Controlled instance/service/cordon, sequential pod replacement and operator-restart exercises were executed. Both instances and SQL paths are healthy. Pod2 needed assisted GI recovery after an SELinux-label failure; pod1 recovered but its startup script still logged a duplicate-CRS-start/INS-40401 defect. Recovery was verified; clean unattended image startup is not established. RMAN backup plus read validation passed; no actual restore, disk/network fault, worker reboot or full post-RAC power cycle was injected.

Complete dated evidence: [baseline/precheck](RAC-EXERCISE-BASELINE-OUTPUT.md), [services](RAC-EXERCISE-SERVICES-OUTPUT.md), [backup and instance/service/cordon tests](RAC-EXERCISE-RECOVERY-OUTPUT.md), [pod replacement and recovery](RAC-EXERCISE-PODS-OUTPUT.md), [operator restart and next-morning health](RAC-EXERCISE-FINAL-OUTPUT.md).

| ID | Scenario | Status / output evidence | Impact if exercised |
|---|---|---|---|
| S01 | Nodes, pods, UID/ownership, resources/probes | Captured [baseline](RAC-EXERCISE-BASELINE-OUTPUT.md) and chapter4 | Read-only |
| S02 | Services, endpoints, private/public addressing | Captured baseline and chapter4 | Read-only |
| S03 | CRS, ASM, PDB, patch and memory health | Verified deployment; [chapter3 commands](MANUAL-03-RAC.md) / chapter4 capture | Read-only |
| S04 | SQL through each node listener | Passed, full chapter4 output | Read-only SQL connections |
| S05 | Stop/start RACCDB1 | Passed; [complete recovery output](RAC-EXERCISE-RECOVERY-OUTPUT.md) | Interrupts instance1 sessions |
| S06 | Stop/start RACCDB2 | Passed; complete recovery output | Interrupts instance2 sessions |
| S07 | Delete/recreate pod1 | Replaced, SQL passed; startup duplicate-start defect remains | Pod1/GI/instance interruption |
| S08 | Delete/recreate pod2 | Replaced; SELinux repair + assisted GI recovery passed | Pod2/GI/instance interruption |
| S09 | Container restart versus pod replacement | UID/restart baseline captured; no crash injected | Entire container/GI interruption |
| S10 | One listener/service unavailable | Service stop/start passed; listener-stop not injected | New connections/service sessions affected |
| S11 | Readiness failure while container still runs | Readiness stayed True during DB/service outage; preceded SQL recovery after pod2 replacement | Service endpoint removed after threshold |
| S12 | Cordon/uncordon a worker | Both workers cordoned/uncordoned; existing pods stayed running | New scheduling blocked, running pod stays |
| S13 | Worker reboot or NotReady | Recovery procedure below; not injected after RAC | One instance unavailable; hostPath placement constraint |
| S14 | Insufficient resources / Pending pod | Allocatable/request state captured; no pressure injected | Replacement may fail to schedule |
| S15 | ImagePullBackOff / registry outage | Pinned/prestaged image verified; no outage injected | Replacement cannot start if image unavailable |
| S16 | Missing Secret / invalid password | Real INS-30003 incident documented; no new Secret deletion | Startup/configuration failure |
| S17 | CNI/private interconnect failure | Healthy addresses/routes captured; previous promisc fix documented | GI eviction or degraded interconnect possible |
| S18 | Kubernetes DNS / client route failure | Prior DNS tests and live NodePort SQL passed; no outage injected | Discovery/connection failure |
| S19 | Scratch mount missing / wrong hostPath | /u01 XFS captured; no mount disruption | GI homes inaccessible or wrong empty directory |
| S20 | ASM disk loss/PVC failure | Bound/Retain storage captured; no disk removal | **Potential database-wide data loss**, EXTERNAL redundancy |
| S21 | Operator restart/unavailable webhook | Controller restart passed; RAC pod UIDs unchanged | Reconciliation/admission delayed; existing DB may continue |
| S22 | API/control-plane outage | Foundation healthy; no outage injected | kubectl/operator unavailable, not proof DB is down |
| S23 | Whole database stop/start | Executed during memory repair; procedure4b.6 | Planned database outage |
| S24 | Full lab shutdown/startup | OCNE foundation tested1October; post-RAC cycle untested | Whole lab unavailable |
| S25 | Backup/restore / point-in-time recovery | RMAN backup + RESTORE VALIDATE passed; **actual restore/PITR not tested** | Separate recovery project / test destination needed |
| S26 | Rolling template change / OnDelete | Both replacement pods adopted ordinary16Gi/4CPU, no HugePages request | Updated template applies on replacement |
| S27 | Application reconnection, transactions and failover | New connections to survivor passed; existing-session/transaction replay not tested | Sessions/transactions can fail; client design matters |
| S28 | Stuck Terminating / forced deletion | Diagnosis below; not injected | Duplicate identity/split-brain risk if forced |

## How to record each exercise

For each run record: ID/date/UTC timestamps, operator version, image digest, precheck output, original pod UID/node, action, exit code, complete watch/events output, Oracle state on the surviving node, replacement UID, recovery actions, final SQL/service checks, interruption duration and pass/fail. Keep raw logs private and review before publication. Do not log passwords, Secret data or installer command lines.

**ocne-cp as labadmin**, a protected output directory for selected safe commands:

```bash
umask 077
exercise_dir="$HOME/rac-exercises/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$exercise_dir"
set -o pipefail
kubectl -n rac get pods -o wide 2>&1 | tee "$exercise_dir/pods-before.txt"
kubectl -n rac get statefulsets -o wide 2>&1 | tee "$exercise_dir/statefulsets-before.txt"
kubectl -n rac get services,endpointslices 2>&1 | tee "$exercise_dir/endpoints-before.txt"
```

Do not use an unrestricted terminal recorder around password prompts or raw installer logs. For an expected failing command, record its nonzero code explicitly; do not hide it with a blanket `|| true`. The full baseline captures retain the missing-directory error and exit2.

## S01-S04: baseline and connections

Run the read-only commands in chapters3/4. Full output is linked above. Interpret Ready correctly: the observed readiness probe is a TCP socket on31522/31523, initial delay180seconds, period5seconds, failure threshold3. There is **no liveness or startup probe** in the captured pod spec. Therefore an open listener socket can make the pod Ready even if the intended PDB/service fails. A failed readiness probe changes endpoint eligibility; it does not, by itself, restart this container.

The network SQL checks are decisive: SYS_CONTEXT must show LABPDB and the intended instance. NodePort31521 currently selects pod1; it is not an independently demonstrated highly available SCAN endpoint. Per-node services remain separate paths. See the captured Service selectors and EndpointSlices.

## S05-S08: instances and one-pod replacement

Use chapter4b.4 for instance stop/start, first RACCDB1, fully recover, then RACCDB2. Use4b.5 for normal one-pod deletion only after its preconditions pass, fully recover, then repeat for pod2. Do not delete both pods at once to demonstrate RAC.

**New failed precheck:** actual code in both images reads `/u01/app/grid/.etcoraclebackup/oracle` to restore `/etc/oracle` after container replacement. Both directories were absent. Existing `/etc/oracle` exists only in each current container filesystem, outside the mounted /u01 path. Image file oracommon.py SHA256 was `3d472092128f1eac62de552cf3b9bec8f1ac5fac7781ba65b01633a62cd4582b` on both. The code was inspected in the actual pods, not inferred solely from the repository. This gap must be resolved and verified before destruction of a current container. Do not assume persistent Oracle home binaries alone preserve node identity.

**Remediation executed at 23:38 UTC:** each node?s own `/etc/oracle` was copied with `cp -a` to `/u01/app/grid/.etcoraclebackup/oracle`, preserving modes/ownership. `cmp` on OCR/OLR pointers and recursive directory comparison passed. The image?s 19c backup function skips this copy unless CRS_GPC is enabled; a populated Oracle home alone therefore did not establish this prerequisite. The persistent parent was created root-owned mode0700. [Full preparation output and RMAN log](RAC-EXERCISE-RECOVERY-OUTPUT.md).

Run these commands once **after GI configuration**, in Bash on ocne-cp, before replacing a pod. If the destination already exists, inspect/compare it; do not overwrite a recovery copy blindly.

```bash
for pod in racnode1-0 racnode2-0; do
  kubectl exec -i -n rac "$pod" -- bash -s <<'GI_BACKUP'
set -euo pipefail
[[ $(findmnt -nro FSTYPE -T /u01/app/grid) == xfs ]]
[[ -s /etc/oracle/ocr.loc && -s /etc/oracle/olr.loc ]]
path=/u01/app/grid/.etcoraclebackup
[[ ! -e "$path" ]] || { echo 'Existing recovery path: inspect before continuing'; exit 1; }
install -d -m 0700 -o root -g root "$path"
cp -a /etc/oracle "$path/oracle"
cmp /etc/oracle/ocr.loc "$path/oracle/ocr.loc"
cmp /etc/oracle/olr.loc "$path/oracle/olr.loc"
diff -qr /etc/oracle "$path/oracle"
GI_BACKUP
done
```

**SELinux follow-up is mandatory for this copy method.** `cp -a` also preserved the original container MCS category (for example s0:c589,c809). A replacement container has a different category and initially received Permission denied. On each corresponding worker, restore the pre-established scratch policy label; do not disable SELinux. Run as root on worker1 with n=1 and worker2 with n=2:

```bash
n=1  # Set 2 on worker2; verify hostname before proceeding.
[[ $(hostname -s) == ocne-w$n ]]
path=/scratch/rac/cluster01/racnode$n/app/grid/.etcoraclebackup
ls -ldZ "$path/oracle"
matchpathcon "$path/oracle"
# Expected policy from chapter3: container_file_t:s0 for this scratch subtree.
restorecon -RFv "$path"
ls -ldZ "$path/oracle"
```

This targeted relabel was executed on both workers. It retains file content, permissions and ownership. It does not make the files world-readable. This copy is not a database backup. The executed RMAN sequence and its limits are in S25 below.

### Assisted GI recovery observed after node2 replacement

At 23:47:54 UTC a normal deletion with 120-second grace was issued. StatefulSet created replacement UID `e5fb5f48-cfcc-4476-97d9-07338262095d` at about23:49:55; public IP changed from10.244.2.9 to10.244.2.10. Both private addresses and ASM block mappings returned. The image completed its machine/SSH setup, but /etc/oracle was absent and later an empty directory, and CRS reported CRS-4047. The controller retained AVAILABLE/OPEN status while the replacement was not ready. These observations demonstrate why neither a created pod nor cached CR status proves recovery.

After the worker-side SELinux relabel above, the following **assisted recovery** restored this already-configured node. These are the OS reconstruction/start operations implemented in the inspected image `oracommon.py`; they do not run a new GI installation or DBCA. Run only on the affected replacement, with its own verified home/backup, no active installer, and an empty /etc/oracle. If the directory is populated or CRS is already configured, stop and diagnose rather than rerun blindly.

**Bash on ocne-cp** (node2 example; substitute node1 only for its separate verified replacement):

```bash
kubectl exec -i -n rac racnode2-0 -- bash -s <<'RECOVER'
set -euo pipefail
[[ $(hostname -s) == racnode2-0 ]]
[[ $(findmnt -nro FSTYPE -T /u01/app/grid) == xfs ]]
[[ -s /u01/app/grid/.etcoraclebackup/oracle/olr.loc ]]
[[ -d /etc/oracle && -z $(find /etc/oracle -mindepth 1 -maxdepth 1 -print -quit) ]]
[[ -f /u01/app/19c/grid/crs/install/crsconfig_params ]]
# Preserve content/ownership/modes without importing the old SELinux category.
cp -rp /u01/app/grid/.etcoraclebackup/oracle/. /etc/oracle/
cmp /etc/oracle/olr.loc /u01/app/grid/.etcoraclebackup/oracle/olr.loc
/u01/app/19c/grid/crs/install/rootcrs.sh -updateosfiles
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19c/grid/bin/crsctl start crs
RECOVER
```

CRS then came online. TCP readiness became True at23:54:57 before ASM/database finished starting; an immediate SQL assertion correctly failed because only one instance was open. ASM mounted DATA at23:55:01 and RACCDB2 followed. Full acceptance at23:56 passed both nodes. Wait for Oracle readiness separately with a bounded retry; if it fails, do not replace the peer. No force deletion, CR/PVC removal, ASM formatting or GI reinstall was used.

**Node1 follow-up:** after both recovery copies were relabeled, node1 was deleted at23:56:58UTC. Replacement UID `590e8b8f-3a93-43d1-a8ea-3549e6b83201` /10.244.1.11 appeared at23:59. The image restored GI and started CRS itself, then wrongly called start-CRS again. CRS-4640/CRS-4000 was treated as not-installed; the redundant GI installer rejected reinstallation with INS-40401. Existing CRS/ASM/database stayed healthy, and SQL through both nodes passed at00:02UTC12October. Do not follow the generic installer suggestion to deinstall a working cluster. No manual node1 GI restoration script was executed.

Both pods adopted the no-HugePages template. Full patch/SQL/memory acceptance passed at00:04UTC, and both SQL paths remained healthy at11:44UTC12October. [Full output and exact startup log contexts](RAC-EXERCISE-PODS-OUTPUT.md). The duplicate-start image defect remains; rebuilding/retesting the image is separate work. Node2 has not been retested for unattended recovery after relabel. Worker restart, container crash and whole-lab shutdown tests are left unexecuted until that startup behavior is corrected and validated. Their diagnostic/recovery procedures remain below. This limits disruption while leaving the operating evidence honest.

## S09: container restart versus a new pod

Read-only inspection:

```bash
kubectl -n rac get pod racnode1-0 -o jsonpath='{.metadata.uid}{"\n"}{range .status.containerStatuses[*]}{.name}{" "}{.restartCount}{" "}{.containerID}{"\n"}{end}'
kubectl -n rac get pod racnode1-0 -o jsonpath='{.spec.restartPolicy}{"\n"}'
```

If a container exits, kubelet normally recreates it according to restartPolicy; UID stays the same and restartCount increases. A StatefulSet pod replacement changes UID. With no liveness probe, hanging GI is not guaranteed to trigger kubelet recovery. Do not `kill -9 1` to manufacture a success demo before the persistence checks pass. A deliberate CRI container stop is a disruptive host-level operation needing the exact container identity and the same recovery/backup gates as pod replacement; it remains unexecuted.

## S10-S11: service, listener and readiness

Read-only starting commands:

```bash
kubectl -n rac get services,endpointslices -o wide
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
kubectl exec -n rac racnode1-0 -- su - grid -c '/u01/app/19c/grid/bin/srvctl status listener'
```

**Optional service maintenance exercise, after the maintenance/backup gates:** stop only labpdb_app on instance1, test the instance2 connection, then restore it:

```bash
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB1'
kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
# Perform the password-prompted SQL test to worker2 from chapter3.
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start service -db RACCDB -service labpdb_app -instance RACCDB1'
```

**Captured behavior:** application service absent on1 while remaining on2, then restored on both; new SQL connection to LABPDB/RACCDB2 passed during the outage. See the full recovery transcript. Existing sessions may be affected according to stop/drain options; inspect `srvctl stop service -help` for the installed version before choosing workload handling. The TCP listener remained open and both pods stayed Ready during the service outage. That contrast is the learning objective. Listener-stop testing must use the actual listener name/node from SRVCTL configuration; do not guess it or stop all listeners at once.

## S12-S14: scheduling, worker maintenance and insufficient resources

Read-only:

```bash
kubectl get nodes
kubectl describe node ocne-w1.lab.test
kubectl -n rac get statefulset racnode1 -o jsonpath='{.spec.template.spec.affinity}{"\n"}'
kubectl -n rac get events --field-selector=reason=FailedScheduling
```

A controlled **cordon/uncordon** exercise does not stop the running pod. It blocks new ordinary scheduling on that node:

```bash
kubectl cordon ocne-w1.lab.test
kubectl get node ocne-w1.lab.test
kubectl -n rac get pods -o wide
# Restore scheduling immediately after observing:
kubectl uncordon ocne-w1.lab.test
kubectl get node ocne-w1.lab.test
```

Expected status during the exercise is Ready,SchedulingDisabled, then Ready. **Not executed here.** Do not combine pod deletion with cordon and expect a pinned replacement to schedule elsewhere. If it is Pending, restore scheduling to the original healthy worker and inspect Events. Do not move node affinity onto a worker with an empty home.

For a worker reboot: verify backup/restart prerequisites, survivor SQL/service, cleanly stop the affected DB instance, plan GI/container shutdown, then shut down/restart only that VM. Preserve exact mounts/NICs and verify time, kubelet/CRI-O, Node Ready, CRS/ASM/SQL/services afterward. A post-RAC worker reboot has not run, so there is no actual failure-watch output to claim. Do not use a forced VBox poweroff for a routine exercise.

For Pending/insufficient-memory, inspect requested CPU/memory, other pod requests, node allocatable and any stale hugepage advertisement. Correct actual capacity/configuration; do not remove requests below admission minimums or evict unrelated pods. Worker RAM remains22GiB. OOM testing is not achieved by allocating all host RAM: inspect lastState.reason=OOMKilled and kernel/cgroup evidence if it occurs naturally.

## S15-S16: image and credential failures

```bash
kubectl -n rac describe pod racnode1-0
kubectl -n rac get events --sort-by=.metadata.creationTimestamp
kubectl -n rac get secrets rac-db-password rac-ssh-key
# On the relevant worker:
sudo crictl images
sudo crictl inspecti docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
```

ImagePullBackOff: distinguish DNS, TLS, credentials, architecture and unavailable digest in Events; validate the CRI-O store, not rootless Podman. Restore access to the exact approved image or pre-stage it. Do not change a running deployment to a guessed latest tag to induce/test failure.

CreateContainerConfigError/missing Secret: check namespace, name and key names without printing values. Recreate only from protected known-good recovery material after verifying ownership, not from fresh random passwords. The real INS-30003 occurred before CRS/database creation and was repaired with a24-character secret; applying that recovery to an existing DB would not rotate its actual passwords correctly. No Secret deletion or invalid-password injection has been performed for this workbook.

## S17-S18: private interconnect, DNS and client routing

```bash
kubectl exec -n rac racnode1-0 -- ip -br address
kubectl exec -n rac racnode2-0 -- ip -br address
kubectl exec -n rac racnode1-0 -- ip route
kubectl get network-attachment-definitions -n rac
kubectl get daemonset kube-multus-ds -n kube-system
# On each worker:
ip -d link show enp0s8
ip -d link show enp0s9
nmcli connection show ocne-rac-private1
nmcli connection show ocne-rac-private2
```

Two interfaces are present, but actual interconnect failover under load has not been tested. A single-network failure test needs confirmed GI interface classification, a timed restore mechanism and console access. A dual-network partition can cause eviction and is **not** a casual beginner command. Diagnose actual interface/promisc/MTU/NAD/IP duplication first. Do not disable NIC1, SELinux or all firewall rules as a test.

For client failures: distinguish Windows SSH tunnel availability, worker NodePort, Service endpoints, listener registration and the Oracle service/PDB. ORA-12514 means the listener does not know the requested service; a TCP timeout points to a different layer. `labpdb_app` is the verified service; ORCLPDB in the CR summary is stale. DNS/hosts resolution alone does not create a route into VBox NAT.

## S19-S20: storage failures

```bash
kubectl get pv
kubectl -n rac get pvc
kubectl -n rac describe pod racnode1-0
kubectl exec -n rac racnode1-0 -- df -hT /u01
kubectl exec -n rac racnode1-0 -- su - grid -c 'export ORACLE_SID=+ASM1; /u01/app/19c/grid/bin/asmcmd lsdg'
# On the relevant worker, read-only:
findmnt -M /scratch
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS,SERIAL,UUID,PARTUUID
ls -l /dev/disk/by-partlabel/ocne-rac-asm01 /dev/disk/by-partlabel/ocne-rac-asm02
```

If /scratch is unmounted, an empty path on the OS filesystem may exist; do not create/extract another home into it. Recover the identified existing XFS mount first. If a PVC is Pending, inspect PV claim references, access/volume mode, device path and Events. RWX here describes shared block access; it does not turn arbitrary unshared disks into shared storage.

DATA uses EXTERNAL redundancy. Removing/corrupting one of its two disks can lose database files or voting/OCR data. Such a test requires an isolated disposable restore target and recovery validation; **no disk-detach, wipefs or format command is supplied as a live exercise**. Retain only changes Kubernetes reclaim behavior, not disk redundancy or backup.

## S21-S22: controller, webhook and control plane

```bash
kubectl -n oracle-database-operator-system get deployment,pods,certificates
kubectl -n cert-manager get deployment,pods
kubectl get validatingwebhookconfigurations
kubectl get nodes
```

If the controller is down, existing Oracle processes may keep running while reconciliation stops. If the webhook is unavailable, create/update admission may fail even while SQL works. A Kubernetes API outage prevents kubectl observations; test SQL through the established listener separately and inspect the control-plane VM/time/services. Do not conclude the database stopped merely because kubectl cannot reach the API.

A controller-only restart is a separate maintenance exercise:

```bash
kubectl rollout restart deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system
kubectl rollout status deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system --timeout=240s
```

**Not executed for this workbook.** Capture SQL availability throughout, then confirm both certificates, controller Ready and the CR state. Do not delete the operator namespace or CRDs as a restart method. The original lab's immutable legacy service metadata needs monitoring during reconciliation.

### Executed controller restart commands (S21)

After both database nodes passed acceptance, in Bash on ocne-cp:

```bash
kubectl -n rac get pods -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,NODE:.spec.nodeName'
kubectl -n oracle-database-operator-system get pods -o wide
kubectl -n oracle-database-operator-system rollout restart deployment/oracle-database-operator-controller-manager
kubectl -n oracle-database-operator-system rollout status deployment/oracle-database-operator-controller-manager --timeout=120s
kubectl -n oracle-database-operator-system get pods -o wide
kubectl -n rac get pods -o custom-columns='NAME:.metadata.name,UID:.metadata.uid,NODE:.spec.nodeName'
```

RAC pod UIDs were identical before/after; network SQL returned LABPDB/RACCDB1 and LABPDB/RACCDB2. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). A controller restart is distinct from restarting database containers; it can briefly delay reconciliation/admission. The test did not submit a CR mutation during the restart and therefore does not validate webhook outage behavior.

## S23-S26: planned outages, backups and template updates

Use4b.6 for DB stop/start. A full VM cycle adds GI, Kubernetes, storage and time dependencies; it is not the same test. The earlier read-only capture showed no RMAN jobs. At 23:38?23:39 UTC an online backup and read validation were executed successfully; [complete RMAN output](RAC-EXERCISE-RECOVERY-OUTPUT.md).

**Manual backup procedure, Bash on ocne-cp.** This lab directory is already populated; inspect it rather than overwrite it. For a new run choose a new date/run suffix consistently in every path. The observed destination was on worker1 persistent scratch; check capacity and plan an independent off-host copy/retention policy before relying on it for host-loss protection. NFS is not mounted inside the RAC containers.

```bash
kubectl exec -n rac racnode1-0 -- df -h /u01
kubectl exec -i -n rac racnode1-0 -- bash -s <<'PREP'
set -euo pipefail
backup=/u01/app/oracle/recovery-backups/manual-exercises-20261011
[[ ! -e "$backup" ]] || { echo 'Existing backup: inspect; choose a new run path'; exit 1; }
[[ $(findmnt -nro FSTYPE -T /u01/app/oracle) == xfs ]]
[[ $(df -B1 --output=avail /u01 | tail -1) -gt 34359738368 ]]
install -d -m 0700 -o oracle -g oinstall "$backup"
PREP
kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'export ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/rman target /' <<'RMAN'
run {
 allocate channel c1 device type disk format '/u01/app/oracle/recovery-backups/manual-exercises-20261011/%U.bkp' maxpiecesize 8G;
 backup database plus archivelog;
 backup current controlfile;
 backup spfile;
 restore database validate;
 release channel c1;
}
list backup summary;
exit;
RMAN
```

Capture the command exit code and complete output. The automation used a protected RMAN command file/background launcher and recorded exit-code0; the equivalent foreground commands above expose the same RMAN sequence. The 32GiB free-space guard is a local allowance for this small database, not a capacity-sizing formula. No archived logs were deleted. `RESTORE DATABASE VALIDATE` reads backups without restoring database files; **actual restoration, recovery and point-in-time recovery remain untested**. A complete recovery drill requires a separate destination, archived redo coverage, controlfile/SPFILE handling, open verification and application-data checks. [Oracle RMAN backup procedure](https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/backing-up-database.html), [complete database recovery](https://docs.oracle.com/en/database/oracle/oracle-database/19/bradv/rman-complete-database-recovery.html).

OnDelete template changes affect replacement pods. Compare desired and running specs before maintenance. A successful apply is not proof both existing pods adopted the change. The baseline showed the former no-HugePages template versus older pod declarations. Both replacement pods now declare4CPU/16Gi ordinary memory without HugePages requests; the final transcript captures the new resources and SQL settings. OnDelete remains configured.

## S27: transactions and client failover

The service capture reports **TAF policy NONE, failover restore NONE, AQ HA notifications false**. Two preferred instances do not imply transparent transaction replay. Distinguish: new connection succeeds on the survivor, existing connection reconnects, uncommitted work rolls back, and committed work persists. Each is a different assertion.

For a future disposable application schema, use a dedicated test table/row and two client sessions, never SYS-owned application objects. Record committed and uncommitted marker values before a single-instance/pod event; reconnect through a properly configured multi-address service; verify transaction outcome afterward. Define the driver/connect descriptor and retry/replay policy before asserting failover. No application schema or workload was created for this documentation pass.

## S28: stuck termination

```bash
kubectl -n rac get pod racnode1-0 -o yaml
kubectl -n rac describe pod racnode1-0
kubectl get node ocne-w1.lab.test
kubectl -n rac get events --sort-by=.metadata.creationTimestamp
```

Check node reachability, deletion timestamp, grace period, hooks, finalizers and CRI state. A disconnected kubelet can leave the old process alive even while the API is uncertain. Do not force-delete a StatefulSet pod until the old instance is known stopped/fenced and Oracle/storage recovery is planned. Two processes claiming one RAC node identity are not a successful replacement exercise.

## Pass/fail rule for every disruptive scenario

Pass only when the intended event actually occurred, all output/exit codes are recorded, the survivor behaved as observed, the affected component recovered, and final CRS/ASM/two-instance/PDB/service/network/memory checks pass. A failed precheck means **not executed**, not passed. A failed recovery remains failed until its fix and recheck are documented. Unknown or unexecuted scenarios retain that label in the ledger.

References: [Kubernetes pod lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/), [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/), [Oracle2.2.0 RAC documentation](https://github.com/oracle/oracle-database-operator/tree/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac), [SRVCTL19c reference](https://docs.oracle.com/en/database/oracle/oracle-database/19/racad/server-control-utility-reference.html). Use installed command help and the pinned version when a current Kubernetes page describes features newer than1.29.
