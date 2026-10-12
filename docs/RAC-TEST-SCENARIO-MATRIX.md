# RAC test scenarios: commands, expected output and actual results

[Manual start](OCNE-RAC-END-TO-END-MANUAL.md) | [Detailed workbook and recovery instructions](RAC-POD-EXERCISES.md)

**Evidence cutoff: 12 October 2026, 11:44 UTC / 07:44 EDT.** The table covers all28 workbook scenarios. PASS applies only to the scope stated; an observed healthy state is not a fault-injection pass. Commands are copyable Bash equivalents, not a script to run all rows together. Maintenance rows interrupt sessions and require the workbook?s backup/survivor checks. Follow the complete sequence there, including recovery. Expected output describes the acceptance criterion; actual output is linked in full and includes failed attempts.

## Command context and reusable helpers

Log into **ocne-cp as labadmin**, with its existing kubectl access. Paste these local shell functions once; they install nothing. `srv 1 ...` runs the DB-home SRVCTL on pod1, `gi 2 ...` runs CRSCTL on pod2. The functions preserve argument quoting.

```bash
srv() {
  local n=$1 command
  shift
  [[ "$n" == 1 || "$n" == 2 ]] || return 2
  printf -v command '%q ' /u01/app/oracle/product/19c/dbhome_1/bin/srvctl "$@"
  kubectl exec -n rac "racnode$n-0" -- su - oracle -c "$command"
}
gi() {
  local n=$1
  shift
  [[ "$n" == 1 || "$n" == 2 ]] || return 2
  kubectl exec -n rac "racnode$n-0" -- /u01/app/19c/grid/bin/crsctl "$@"
}
sqlnet() {
  local n=$1 host port
  [[ "$n" == 1 || "$n" == 2 ]] || return 2
  host=192.168.77.$((11+n))
  port=$((31521+n))
  kubectl exec -it -n rac racnode1-0 -- su - oracle -c "/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -L system@//$host:$port/labpdb_app"
}
```

`sqlnet` prompts securely for the SYSTEM password. At SQL>, run the following, verify the intended instance, then `exit` before starting the second connection. During a pod1 outage, run the client in surviving racnode2-0 instead by changing the client pod in the function; during instance-only outages its pod remains usable.

```sql
select sys_context('USERENV','CON_NAME') as pdb,
       sys_context('USERENV','INSTANCE_NAME') as instance_name from dual;
exit
```

Expected/observed identity: LABPDB/RACCDB1 through31522; LABPDB/RACCDB2 through31523. The automated captures passed passwords on protected stdin and asserted these identities; no password appears in the commands or transcripts.

## Scenario matrix

| ID | Scenario / purpose | Corresponding command syntax | Expected result / output | Actual result / output evidence |
|---|---|---|---|---|
| S01 | Node/pod identity, ownership, placement and resources | `kubectl get nodes -o wide`<br>`kubectl -n rac get pods -o wide`<br>`kubectl -n rac get statefulsets` | Three Ready nodes; one RAC pod on each intended worker; StatefulSets 1/1. | PASS. Both workers Ready/schedulable; pods1/1 Running. New UIDs after replacement, restartCount 0. Final resources 4 CPU/16 Gi each, no hugepages request. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S02 | Service and endpoint routing | `kubectl -n rac get services,endpointslices -o wide` | Services select intended pods; endpoints follow replacements. | PASS for observed routing and both NodePort SQL paths. SCAN 31521 selects node 1 only; a fully redundant SCAN route was not proven. [Full output](RAC-EXERCISE-BASELINE-OUTPUT.md). |
| S03 | Grid Infrastructure, ASM, database, patches and memory | `gi 1 check crs`<br>`gi 2 check crs`<br>`gi 1 stat res -t`<br>`srv 1 status database -db RACCDB -verbose` | Both CRS stacks online; DATA mounted; two OPEN instances, LABPDB READ WRITE; RU 19.32; SGA 3 GiB and HugePages FALSE. | PASS. Final full verification: DATA MOUNTED/EXTERN, offline disks 0; RU 39472050/OJVM 39222882 SQL SUCCESS; no invalid registry components. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S04 | Connect through each worker listener | `sqlnet 1`<br>`sqlnet 2` | Prompt for password; SQL identity must be LABPDB and RACCDB1/RACCDB2 respectively. | PASS. TCP from control plane and network SQL from a RAC pod passed through .12:31522 and .13:31523. Rechecked 12October 11:44 UTC. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S05 | Stop/start instance 1, verify survivor 2 | `srv 1 stop service -db RACCDB -service labpdb_app -instance RACCDB1`<br>`srv 1 stop instance -db RACCDB -instance RACCDB1 -stopoption IMMEDIATE`<br>`srv 2 status database -db RACCDB -verbose`<br>`srv 1 start instance -db RACCDB -instance RACCDB1` | Only instance 1 stops; fresh SQL connection to instance 2 works; instance 1/service return. | PASS after correction. Instance-only stop initially failed CRS-2974 due service dependency. Stop-service first worked. Restart automatically restored service; redundant manual start returned already-running. Both recovered. [Full output](RAC-EXERCISE-RECOVERY-OUTPUT.md). |
| S06 | Stop/start instance 2, verify survivor 1 | `srv 2 stop service -db RACCDB -service labpdb_app -instance RACCDB2`<br>`srv 2 stop instance -db RACCDB -instance RACCDB2 -stopoption IMMEDIATE`<br>`srv 1 status database -db RACCDB -verbose`<br>`srv 2 start instance -db RACCDB -instance RACCDB2` | Mirror S05; instance 1 remains available. | PASS. Instance2 was not running while SQL to LABPDB/RACCDB1 succeeded; instance 2 then OPEN/ACTIVE and service on both. [Full output](RAC-EXERCISE-RECOVERY-OUTPUT.md). |
| S07 | Delete/recreate pod 1 after peer recovery | `kubectl -n rac delete pod racnode1-0 --grace-period=120 --wait=true --timeout=300s`<br>`kubectl -n rac wait --for=condition=Ready pod/racnode1-0 --timeout=900s` | Same name/new UID; correct persistent home/storage; CRS/ASM/database and SQL recover. Readiness alone insufficient. | RECOVERED WITH STARTUP DEFECT. New UID 590e8b8f-3a93-43d1-a8ea-3549e6b83201, IP 10.244.1.11. Prepared backup restored automatically; duplicate CRS start caused CRS-4640/INS-40401. Existing DB still recovered; both SQL paths passed 00:02 UTC. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S08 | Delete/recreate pod 2 before pod 1 | `kubectl -n rac delete pod racnode2-0 --grace-period=120 --wait=true --timeout=300s`<br>`kubectl -n rac wait --for=condition=Ready pod/racnode2-0 --timeout=900s` | Same name/new UID; node-local GI files must remain usable by new container. | RECOVERED WITH ASSISTANCE. New UIDe5fb5f48-cfcc-4476-97d9-07338262095d, IP 10.244.2.10. Old SELinux MCS label blocked backup copy. Targeted restorecon plus GI OS-file restoration/startup recovered it. Not an unattended-recovery pass. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S09 | Container restart versus pod replacement | `kubectl -n rac get pod racnode1-0 -o jsonpath='{.metadata.uid}{"\n"}{.status.containerStatuses[*].restartCount}{"\n"}'` | Container restart keeps UID and increments restartCount; replacement changes UID. | OBSERVATION ONLY. Replacement UIDs changed; restartCount 0 on new pods. No deliberate container crash injected, pending image startup correction. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S10 | Stop/start only application service on instance 1 | `srv 1 stop service -db RACCDB -service labpdb_app -instance RACCDB1`<br>`srv 2 status service -db RACCDB`<br>`srv 1 start service -db RACCDB -service labpdb_app -instance RACCDB1` | Service absent on 1, available on 2; restore returns it on both. | PASS for service maintenance. SQL to LABPDB/RACCDB2 passed during outage; pods stayed Ready. A separate listener-stop fault was not injected. [Full output](RAC-EXERCISE-RECOVERY-OUTPUT.md). |
| S11 | Compare pod readiness with Oracle readiness | `kubectl -n rac get pods`<br>`srv 1 status database -db RACCDB -verbose` | TCP readiness can remain true while DB/service is unavailable; verify SQL separately. | OBSERVED. Both pods stayed1/1 Ready during instance/service stops. After pod 2 recovery, Ready preceded two-instance SQL acceptance; initial SQL assertion failed then later passed. No liveness probe exists. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S12 | Cordon/uncordon each worker | `kubectl cordon ocne-w1.lab.test`<br>`kubectl get node ocne-w1.lab.test`<br>`kubectl uncordon ocne-w1.lab.test` | SchedulingDisabled while cordoned; running pods remain; uncordon restores scheduling. | PASS on both workers sequentially. Ready,SchedulingDisabled then Ready; RAC pods stayed running; final SQL healthy. Repeat syntax with ocne-w2.lab.test. [Full output](RAC-EXERCISE-RECOVERY-OUTPUT.md). |
| S13 | Worker reboot/NotReady and host-local homes | `kubectl get nodes`<br>`kubectl -n rac describe pod racnode1-0` | A reboot interrupts that instance; correct local home and ASM must return. | NOT INJECTED after RAC. Node readiness/affinity captured. Reboot deferred until image restart path is corrected; chapter4 covers recovery order. [Full output](RAC-EXERCISE-BASELINE-OUTPUT.md). |
| S14 | Scheduling/resource shortage | `kubectl describe node ocne-w1.lab.test`<br>`kubectl -n rac get events --sort-by=.metadata.creationTimestamp` | Events identify insufficient CPU/memory or affinity; never shrink requirements blindly. | OBSERVED resources and successful replacement scheduling. Earlier HugePages/IPC provisioning failure documented. No intentional OOM/resource-exhaustion fault. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S15 | Image availability / ImagePullBackOff | `kubectl -n rac describe pod racnode1-0`<br>`kubectl -n rac get events --sort-by=.metadata.creationTimestamp` | Pinned image cached locally or pull succeeds; failures surface in Events. | CACHE PATH VERIFIED. Replacement events report pinned image already present. No registry outage or bad-image mutation injected. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S16 | Secrets / installer password validity | `kubectl -n rac get secret rac-db-password -o name` | Secret exists and password meets installer constraints; never print payload. | REAL INCIDENT FIXED during provisioning. INS-30003 from32-character credential; regenerated24-character credential before GI/DB creation. No live Secret deletion test. [Full output](RAC-DEPLOYMENT.md). |
| S17 | Private CNI/interconnect reachability | `kubectl exec -n rac racnode1-0 -- ip -4 address show`<br>`kubectl exec -n rac racnode2-0 -- ip -4 address show` | Both .78/.79 interfaces present with unique addresses; peer reachability. | HEALTHY BASELINE and replacement attachments observed. Prior VBox/NM promiscuous-mode fix documented. No deliberate interconnect partition or failover-under-load test. [Full output](RAC-EXERCISE-BASELINE-OUTPUT.md). |
| S18 | DNS/client-route troubleshooting | `kubectl exec -n rac racnode1-0 -- getent hosts racnode-scan`<br>`kubectl -n rac get services,endpointslices` | Service DNS resolves inside cluster; client has an actual route/tunnel to listener. | DNS/network baseline and NodePort connections verified. Windows hosts file alone is not a route; Windows SQL Developer session not claimed. No DNS outage injected. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S19 | Scratch/home persistence and GI recovery copy | `kubectl exec -n rac racnode1-0 -- findmnt -T /u01`<br>`kubectl exec -n rac racnode2-0 -- ls -ldZ /u01/app/grid/.etcoraclebackup/oracle` | Correct persistent XFS homes; own-node GI files readable after replacement. | REAL GAPS FIXED. Missing /etc/oracle backups created; old MCS labels corrected on both workers. Homes persisted across both replacements. No scratch filesystem removal/fill test. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S20 | ASM/PV/PVC availability and disk-loss diagnosis | `kubectl -n rac get pvc`<br>`kubectl get pv`<br>`gi 1 stat res -t` | Block claims Bound/Retain; ASM DATA mounted; no offline disks. | HEALTHY STATE VERIFIED. Both block mappings survived replacement. NO disk-removal/corruption injection: EXTERNAL redundancy has no ASM mirror. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |
| S21 | Restart Database Operator only | `kubectl -n oracle-database-operator-system rollout restart deployment/oracle-database-operator-controller-manager`<br>`kubectl -n oracle-database-operator-system rollout status deployment/oracle-database-operator-controller-manager --timeout=120s` | New controller ready; RAC pods and database remain running. | PASS. New controller pod ready; both RAC UIDs unchanged; both SQL paths passed before/after. Prolonged webhook/API outage not tested. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S22 | Kubernetes API/control-plane outage | `kubectl get --raw=/readyz`<br>`kubectl get nodes` | Healthy API responds; an API outage blocks management, not necessarily running DB processes. | NOT INJECTED. API was usable throughout captures; exact /readyz command is a diagnostic example, not a captured test. No fault-test output exists. |
| S23 | Whole database stop/start | `srv 1 stop service -db RACCDB -service labpdb_app`<br>`srv 1 stop database -db RACCDB -stopoption IMMEDIATE`<br>`srv 1 start database -db RACCDB`<br>`srv 1 status service -db RACCDB` | Planned outage; both instances reopen and intended memory settings apply. | EXECUTED during11 October memory correction; subsequent SQL acceptance passed USE_LARGE_PAGES=FALSE/SGA 3 GiB. Not re-injected during the later workbook run. Check service status before any extra start. [Full output](RAC-DEPLOYMENT.md). |
| S24 | Full lab shutdown/startup | `srv 1 status database -db RACCDB -verbose`<br>`kubectl get nodes` | Coordinate DB/GI, workers, control plane and NFS; verify time/storage before startup. | NOT TESTED after RAC. OCNE-only ordered VM restart passed 1 October. Diagnostic commands here do not shut down anything. No fault-test output exists. |
| S25 | RMAN backup plus validation versus actual restore | `kubectl exec -it -n rac racnode1-0 -- su - oracle` | RMAN backup completes; RESTORE DATABASE VALIDATE reads pieces. An actual restore needs separate execution/evidence. | PASS for database+archivelog, controlfile, SPFILE backup and read validation; exit 0,11October 23:39 UTC. Actual restore/PITR NOT TESTED. Backup is on worker 1 scratch, not an off-host DR copy. Full RMAN command block below. [Full output](RAC-EXERCISE-RECOVERY-OUTPUT.md). |
| S26 | OnDelete template/resource adoption | `kubectl -n rac get statefulsets -o custom-columns='NAME:.metadata.name,STRATEGY:.spec.updateStrategy.type'`<br>`kubectl -n rac get pods -o json` | OnDelete leaves existing pods unchanged; replacement adopts new template. | PASS BY OBSERVATION. Both replacements now request/limit4 CPU and 16 Gi ordinary memory, no hugepages-2Mi; SQL remains FALSE. [Full output](RAC-EXERCISE-FINAL-OUTPUT.md). |
| S27 | New-connection survivor access versus session/transaction failover | `sqlnet 1`<br>`sqlnet 2`<br>`srv 1 config service -db RACCDB -service labpdb_app` | New connection can use survivor; replay needs explicit client/service configuration and a workload test. | PARTIAL. Fresh survivor SQL passed in both instance-stop tests. TAF NONE; no existing-session continuity, transaction replay, committed-marker or rollback workload tested. [Full output](RAC-EXERCISE-RECOVERY-OUTPUT.md). |
| S28 | Termination and force-deletion diagnosis | `kubectl -n rac describe pod racnode1-0`<br>`kubectl -n rac get events --sort-by=.metadata.creationTimestamp` | Normal termination completes before replacement; stuck/fenced state needs investigation. | NORMAL TERMINATION OBSERVED with 120-second grace on both pods. No stuck-node/finalizer fault or force delete used. Each replacement had a new UID. [Full output](RAC-EXERCISE-PODS-OUTPUT.md). |

## Exact RMAN syntax for S25

The destination was created on persistent /u01 with oracle ownership/mode0700 and checked for capacity. In the oracle shell, set the node1 SID, start RMAN with OS authentication and run:

```bash
export ORACLE_SID=RACCDB1
/u01/app/oracle/product/19c/dbhome_1/bin/rman target /
```

```text
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
```

The existing directory contains the recorded backup; use a new run directory for another backup, following [the guarded preparation steps](RAC-POD-EXERCISES.md#s23-s26-planned-outages-backups-and-template-updates). The full RMAN output shows successful database-piece validation and `Recovery Manager complete`; the launcher recorded exit0. The phrase ?Finished restore? in this log belongs to RESTORE VALIDATE and does not establish an actual restored database.

## Failure and correction table

| Observed failure | Expected handling | What was actually changed / result |
|---|---|---|
| Missing persistent GI /etc/oracle recovery copy | Stop before destroying the container; preserve each node?s own configured files | Created own-node backup under /u01/app/grid/.etcoraclebackup/oracle and verified OCR/OLR pointers |
| CRS-2974 on instance-only stop | Account for dependent application service | Stopped labpdb_app on that instance first, then instance stop succeeded |
| PRCR-1120 / CRS-5702 after instance start | Check whether service already auto-started | Replaced unconditional service start with status check; both services were already running |
| Permission denied restoring node2 GI copy | Check SELinux labels as well as Unix mode/owner | cp -a retained old MCS categories; worker-side restorecon restored established container_file_t:s0 policy; SELinux remained Enforcing |
| Node2 no configured CRS after failed copy | Restore only its own verified configuration and OS integration | Copied into verified empty /etc/oracle; rootcrs.sh -updateosfiles, orainstRoot.sh, crsctl start crs; full acceptance passed |
| Pod Ready before database recovered | Wait for Oracle/SQL separately | First immediate SQL assertion failed; later ASM mount/DB open completed and full verification passed |
| Node1 duplicate CRS start, then INS-40401 | Already-active CRS must not trigger fresh installation | Database recovered and passed SQL; did not deinstall or recreate GI. **Image logic defect remains**; future image correction/retest needed |
| CR briefly showed AVAILABLE with Pending DB fields | Cross-check live CRS/SQL; allow controller refresh | Next-morning CR returned OPEN/PRIMARY/19.32. Legacy ORCLPDB connect-string text still stale; use verified LABPDB/labpdb_app |

See [all setup incidents](MANUAL-04-RAC-OPERATIONS.md#4c-troubleshooting-from-the-actual-run) for the earlier cloning, networking, certificate, HugePages, PDB and service-name problems. The source manual/workbook links primary Oracle and Kubernetes references and distinguishes local lab implementation.
