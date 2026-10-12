# RAC deployment and acceptance

RAC provisioning completed on 11 October 2026. Both instances are OPEN/ACTIVE, LABPDB is READ WRITE on both, binary/SQL patch acceptance passed, SGA is 3 GiB, PGA 2 GiB and USE_LARGE_PAGES=FALSE. Network SQL through worker1:31522 and worker2:31523 to labpdb_app passed at18:45UTC. The user authorized provisioning on10October, superseding the earlier prerequisite-only boundary.

For the full manual use [the four-part guide](OCNE-RAC-END-TO-END-MANUAL.md) and [test scenario matrix](RAC-TEST-SCENARIO-MATRIX.md). Controlled exercises are recorded in [the workbook](RAC-POD-EXERCISES.md): both pod replacements recovered, with assisted recovery for pod2 and a remaining startup-script defect on pod1. Full SQL health passed again on12October11:44UTC.

## Applied configuration

- Resource: `rac/rac19c`, UID `6be9de9e-f884-4b82-848b-52eadd7213d1`, created `2026-10-11T02:14:00Z` (10 October 22:14 EDT).
- Original applied manifest fingerprint (historical; the fresh-build YAML has since been corrected): SHA256 `8c76f48256eb145460033b2499b80a7a736d77d14fd95931200dfa4a0a7790b2`.
- Two RAC instances, database `RACCDB`, target PDB `LABPDB`, target application service `labpdb_app` (distinct from the PDB default service).
- Per instance: SGA 3 GiB, PGA 2 GiB. Per pod: 4 CPUs, 16 GiB ordinary memory, HugePages disabled.
- User-built OL9.8 image pinned by digest and the two verified 19.32 gold ZIPs. No deployment-time patch inputs.
- Dedicated shared ASM partitions only: `ocne-rac-asm01` and `ocne-rac-asm02`, DATA / EXTERNAL redundancy. The existing NFS share is separate.

See [manifest provenance and adaptations](RAC-PROVISIONING-HANDOFF.md#manifest-source-and-lab-adaptations), [artifact checks](RAC-ARTIFACT-ACCEPTANCE.md), and [manual prerequisite commands](RAC-PREREQUISITES-GUIDE.md).

## Observed progress

The final preflight confirmed all nodes Ready, operator certificates Ready, required secrets present, and both shared ASM partition identities and blank signatures unchanged. The operator created two bound block PV/PVC pairs and scheduled racnode1-0 on worker1 and racnode2-0 on worker2. Both pods obtained their two private network addresses. Both gold homes were extracted. GI/ASM configuration subsequently succeeded on both nodes. The first DBCA startup failed due to shared-memory limits; the corrected attempt resumed at 09:40:59 EDT on 11 October. DBCA completed at10:19EDT; SQL/patch acceptance passed after the10:55-10:57 database restart. Both network SQL paths passed at18:45UTC.

Do not rerun the blank-ASM checks, partition preparation, formatting, identity reset or first-time worker preparation scripts after provisioning starts. Do not delete the RacDatabase, its PVs or home directories to retry an error; inspect current state and preserve evidence first.

## Manual provisioning and monitoring

Fresh-build procedure only; this existing database must not be recreated. On ocne-cp as labadmin, with the reviewed YAML in ~/ocne-rac-prereqs:

```bash
kubectl create --dry-run=server -f ~/ocne-rac-prereqs/rac-database.yaml
# Applied once in this run after user authorization:
kubectl apply -f ~/ocne-rac-prereqs/rac-database.yaml
kubectl get racdatabase rac19c -n rac
kubectl get pods,pvc,services -n rac -o wide
kubectl get pv
```

[Provision-RAC-Database.sh](../scripts/Provision-RAC-Database.sh) records the guarded initial apply, including exact manifest fingerprint and absence checks. Its fingerprint now matches the revised no-HugePages manifest; the original applied fingerprint above is retained as historical evidence. It intentionally refuses to create another deployment if a RacDatabase already exists.

For this Windows workspace, the equivalent script invocation was:

```powershell
.\scripts\Invoke-LabSSH.ps1 -Node ocne-cp -CredentialName labadmin -ScriptPath D:\OCNE19-Lab\scripts\Provision-RAC-Database.sh
```

Copy [Inspect-RAC-Provisioning.sh](../scripts/Inspect-RAC-Provisioning.sh) or [Monitor-RAC-Provisioning.sh](../scripts/Monitor-RAC-Provisioning.sh) to ocne-cp and run as labadmin for sanitized diagnostics:

```bash
bash Inspect-RAC-Provisioning.sh
# Periodic read-only monitoring, at most 45 minutes per invocation:
bash Monitor-RAC-Provisioning.sh
```

These helpers suppress the known database password using the protected recovery file, without displaying it, and redact common password argument forms. Treat logs as potentially sensitive even after automated redaction; never commit raw output or credentials. [Inspect-RAC-Worker-Load.sh](../scripts/Inspect-RAC-Worker-Load.sh), run as root on a worker, reports extraction size, memory and kernel failures without exposing process arguments.

## Database acceptance (executed 11 October 2026)

The read-only [Verify-RAC-Database.sh](../scripts/Verify-RAC-Database.sh) requires the operator state AVAILABLE before checking both pods, CRS, cluster membership, ASM, patch inventories and SQL. Copy it to ocne-cp and run as labadmin:

```bash
bash -n Verify-RAC-Database.sh
bash Verify-RAC-Database.sh
```

SQL uses OS authentication inside each pod; no password is put into command arguments. Assertions require two OPEN/ACTIVE instances, LABPDB open READ WRITE on both, and a 3 GiB SGA target on both. Inspect live binary and SQL patch inventories, service status and network connections before declaring completion. Pod readiness alone does not establish a usable RAC database. Worker/pod failure and recovery testing is a separate operating exercise after a healthy baseline.

Sources: the pinned [Oracle RAC provisioning procedure](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/provisioning_oracle_rac_db.md), [connection procedure](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/database_connection.md), and [Oracle RAC on OCNE guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/rackb/install-configure-rac-olcne.html). Windows/VirtualBox orchestration and the constrained resource profile are local lab choices.

## Observed INS-30003 recovery

The first GI configuration attempt failed at 22:22 EDT because our original secret helper generated a 32-character password. The installer reported a maximum of 30. [Oracle's password guidance](https://docs.oracle.com/en/database/oracle/oracle-database/19/ntdbi/unlocking-and-resetting-user-passwords.html) also documents the 8-30 character range. [Prepare-RAC-Secrets-And-Labels.sh](../scripts/Prepare-RAC-Secrets-And-Labels.sh) now generates 24 characters with required character classes.

Before any CRS or database creation, we verified both pods had no OCR location file and no active installer. [Repair-RAC-Preinstall-Password.sh](../scripts/Repair-RAC-Preinstall-Password.sh) then saved a protected recovery backup, encrypted and verified a replacement credential, replaced only pwdfile.enc in the existing Kubernetes secret, and checked both projected files. Recovery passwords and keys remain exclusively in the protected guest directory. No existing database password was changed because a database did not yet exist.

The existing image's runOracle.sh/main.py setup was resumed at 22:31 EDT using [Resume-RAC-After-Password-Fix.sh](../scripts/Resume-RAC-After-Password-Fix.sh). The helper is deliberately guarded for this CR UID and pre-CRS failure, and refuses a blind rerun. It keeps both extracted homes, pods and all storage. Equivalent Bash commands on ocne-cp, after copying and reviewing these files, were:

```bash
bash -n Repair-RAC-Preinstall-Password.sh
bash Repair-RAC-Preinstall-Password.sh
bash -n Resume-RAC-After-Password-Fix.sh
bash Resume-RAC-After-Password-Fix.sh
bash Inspect-RAC-Provisioning.sh
```

For a fresh manual rebuild, use the corrected secret generator initially; these incident-specific recovery scripts are not normal prerequisite steps. For a different failure, inspect state first instead of changing their guards or deleting resources.

## DBCA shared-memory recovery and user-requested HugePages disable

Clusterware and DATA were verified online on both nodes on 11 October. The first DBCA startup had failed with ORA-27125 / ENOSPC: its 3 GiB SGA required 1537 two-MiB pages, but the pool contained 1536; kernel.shmall also capped all SysV segments at exactly 3 GiB. The user then requested disabling HugePages. This supersedes the earlier allocation tests recorded in artifact acceptance.

Actual changes at 09:37-09:41 EDT:

- Both workers: vm.nr_hugepages=0, persisted and verified; THP remains never.
- Desired CR and StatefulSet templates: no hugepages-2Mi requests/limits; 16Gi ordinary memory, 4 CPUs, TOTAL_MEMORY=16384. SGA3G/PGA2G unchanged.
- Pod IPC ceilings: kernel.shmall=2097152 and kernel.shmmax=8589934592, allowing up to 8 GiB of shared memory without reserving it.
- Existing GI and ASM kept running. StatefulSets temporarily use OnDelete to avoid an automatic restart during recovery. Existing pods retain immutable old resource fields until controlled recreation, although no actual HugePages exist. Kubelet resource advertisement is not yet refreshed.

Equivalent Bash workflow for this incident, after copying/reviewing the linked helpers:

```bash
# On each worker, as an administrator:
sudo bash Disable-RAC-HugePages.sh
sudo bash Set-RAC-Live-IPC-Limits.sh
# On ocne-cp as labadmin:
bash Set-RAC-NoHugePages-Profile.sh
bash Resume-RAC-After-Memory-Fix.sh
bash Inspect-RAC-Provisioning.sh
```

[Disable-RAC-HugePages.sh](../scripts/Disable-RAC-HugePages.sh) refuses to release in-use pages. [Set-RAC-Live-IPC-Limits.sh](../scripts/Set-RAC-Live-IPC-Limits.sh) resolves the actual CRI container PID by exact pod/container name, verifies a distinct IPC namespace, and uses nsenter into IPC only. This is needed because Kubernetes mounts the pod's sysctl procfs read-only; host IPC settings stay separate. [Set-RAC-NoHugePages-Profile.sh](../scripts/Set-RAC-NoHugePages-Profile.sh) checks the actual zero pool and live limits before reconciling desired resources. [Resume-RAC-After-Memory-Fix.sh](../scripts/Resume-RAC-After-Memory-Fix.sh) checks that no RACCDB instance/resource or installer is active, then resumes the existing setup. [Inspect-RAC-DBCA-Memory.sh](../scripts/Inspect-RAC-DBCA-Memory.sh) captures sanitized memory and alert-log evidence.

Oracle documents [shared-memory limits](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/minimum-parameter-settings-for-installation.html) and [USE_LARGE_PAGES](https://docs.oracle.com/en/database/oracle/oracle-database/19/refrn/USE_LARGE_PAGES.html). With zero reserved pages, the normal TRUE default falls back to regular pages. Verify the final database parameter and page allocation after DBCA; do not infer it from the YAML alone. This is the user's lab choice; Oracle recommends large pages for production consistency.

The earlier GI optional PRVE-10323 warning came from a failed, unused rpc_pipefs mount in pod2. There were no NFS mounts inside the RAC container. After preserving the error, we cleared only that recorded failure with `systemctl reset-failed var-lib-nfs-rpc_pipefs.mount` and verified systemd running. This does not make NFS mounting inside the pod work; host-mounted NFS and shared-block ASM remain separate. Oracle's container source includes reset-failed handling; no global periodic failure reset or SELinux disable was introduced.

## PDB/service correction and final verification

The operator emitted ORACLE_PDB but the image consumed ORACLE_PDB_NAME, so DBCA initially created ORCLPDB. After DBCA completed, the PDB was closed on all instances, opened restricted on one, renamed to LABPDB and reopened/saved on both. An original labpdb service in CDB root was removed before the rename. Application service labpdb_app was created with -pdb LABPDB and preferred RACCDB1,RACCDB2.

Changing the CR's original serviceDetails.name was rejected by the immutable-field webhook. Domain-name experiments encountered ORA-65042 and then PRCD-1278: qualifying LABPDB.lab.test did not make its reserved default service name available for a custom service. The working labpdb_app service was restored; no PDB/data/CR/PV was deleted. The fresh-build manifest now uses labpdb_app/PDB mapping and explicit ORACLE_PDB_NAME initially. The existing [live manifest](../config/rac-database-live.yaml) retains the legacy CR service field. Its stale ORCLPDB connection summary is documented; SQL is the verified identity.

Verify-RAC-Database.sh completed at10:58EDT: CRS online, two instances, DATA MOUNTED/EXTERN/zero offline disks, matching live19.32 binary inventories, SQL RU39472050/OJVM39222882 SUCCESS in root and LABPDB, no invalid registry components, SGA3GiB/PGA2GiB and explicit FALSE. Capture-RAC-Manual-Evidence.sh later verified both NodePort SQL paths and final memory/PDB/service identity at18:45UTC. Full sanitized output is in [chapter4](MANUAL-04-RAC-OPERATIONS.md).

At this earlier acceptance, existing pods retained old hugepage resource declarations. The later controlled replacements adopted4CPU/16Gi ordinary memory with no HugePages request, verified in the final exercise output. StatefulSets remain OnDelete. RMAN backup/read validation and both pod recoveries were exercised; actual restore, worker reboot and full post-RAC power cycle were not. See the scenario matrix for exact outcomes and image startup limitations.
