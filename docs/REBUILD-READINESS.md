# Rebuild readiness audit and procedure contract

**Inspection date:** 16 October 2026, America/New_York. Final identity/configuration observations returned 17 October 2026 02:42 UTC (16 October 22:42 EDT). Checks below were separate point-in-time observations, not continuous availability monitoring.

**Verdict: conditionally ready to follow the documented rebuild workflow; not yet a verified wipe-and-recover package.** The source VM, supplied media, manifests, and application archive are available. The live checks passed. An external backup destination/copy has not been verified, complete offline image/RPM preservation has not been established, and a clean rebuild/database restore has not been rehearsed.

This audit follows [the consolidated instructions](USER-INSTRUCTIONS.md). It does not authorize deletion, recreate resources, change the chosen architecture, or silently replace versions. No VM, database, filesystem, deployment, or security configuration was changed by this audit. Oracle installers, disk formatting, backups, restores, pod deletion, and fault injection were not run.

## Subsequent preservation decision

The owner subsequently declined database/application data preservation, required the golden VM to remain untouched, and approved `E:\OCNE19-Rebuild-Backup`. See the [backup preparation and receipt](REBUILD-BACKUP.md) for current results. The audit findings below describe the earlier read-only inspection; statements that no destination/copy was supplied are historical. This decision removes the current-data recovery requirement for the planned fresh rebuild, but does not authorize deletion or establish a tested restore.

## 1. What "the same lab" means

Preserve the approved functional configuration below. A new installation must generate its own VM UUIDs, MAC addresses, Linux machine IDs, SSH host keys, Kubernetes object UIDs, and disk/filesystem identities. Rediscovering those values and updating identity guards from observation is required by the existing instructions; copying old identities would violate them.

| Component | Rebuild target / observed baseline |
|---|---|
| Workflow | Full clones of the inspected `ol9-golden`; no fresh-ISO scripts 02/03 |
| VM allocations | op 4 GiB / 2 vCPU; cp 8 / 4; w1 and w2 each 22 / 6 |
| Platform | OL9.8, UEK R7 `5.15.0-324.217.5.3.el9uek.x86_64` observed; retain the documented eligible-update policy |
| OCNE | CLI/API/agent packages observed as `1.9.6-1.el9.x86_64` on their respective roles |
| Kubernetes / runtime | `kubelet-1.29.14-2.el9.x86_64`, `cri-o-1.29.1-2.el9.x86_64`; nodes report `v1.29.14+2.el9` |
| Database Operator | Checked-in 2.2.0 manifests; live image digest `sha256:f378d66fd0b47b6089f01caf4ca86f90f3b3593cdca75292ff6491955c451cc0` |
| cert-manager | v1.17.4; checked-in manifests and live controller/cainjector/webhook tags agree |
| RAC software | Supplied 19.32 patched Grid/DB homes; supplied slim image pinned below |
| RAC database | RACCDB, LABPDB, two OPEN instances, `labpdb_app` on both |
| RAC resources | SGA 3 GiB, PGA 2 GiB; HugePages disabled; 4 CPU / 16 GiB ordinary memory per RAC pod |
| Application | RAC Lab Board: frontend + Node.js + Python + Java; four deployments, two replicas each, same cluster, LABPDB backend |
| Additional storage | Operator NFS 100 GiB; worker scratch/container disks; four shared ASM disks, with asm03/04 left as candidates |

The operator/control-plane resource exceptions remain unchanged. A successful lab check does not establish Oracle minimum compliance or general workload capacity. If an exact package/image version is unavailable, stop and report that dependency rather than choosing a newer version or another installation workflow. Do not freeze an ineligible OS/kernel simply to match a string: resolve any conflict against the original Oracle eligibility rules before installation.

### Complete storage layout

The original README's base-lab disk table predates RAC additions. Use this full target inventory when planning the same completed exercise:

| Device | VM(s) | Capacity / purpose |
|---|---|---|
| Clone boot VDI | Each of the four nodes | 100 GiB each |
| NFS VDI | ocne-op | 100 GiB, XFS mounted at `/srv/nfs`, export `/srv/nfs/share` |
| Container VDI | Each worker | 100 GiB each, XFS at `/var/lib/containers` |
| Scratch VDI | Each worker | 128 GiB each, XFS at `/scratch` |
| asm01 and asm02 | Same two shareable VDIs attached to both workers | 50 GiB each; existing DATA members |
| asm03 and asm04 | Same two additional shareable VDIs attached to both workers | 50 GiB each; unused ASM candidates |

Logical capacity totals **1,156 GiB**, counting shared disks once. Dynamic VDI capacity is not physical host consumption. Four fixed shared ASM disks alone require approximately 200 GiB of backing storage. D: reported **467.92 GiB free** during this audit; recalculate before any future allocation or backup. Host RAM is approximately **61.7 GiB visible**, with 28 logical processors; the VM RAM allocation totals 56 GiB.

`00-Inspect-Host.ps1` contains a static statement about 8 GiB remaining on a nominal 64 GiB host. Use the observed physical-memory value instead: about 5.7 GiB nominal headroom here, before runtime overhead. Its mixed PowerShell output also required an explicit formatted drive query to display free space clearly; the audit used that separate query rather than assuming blank table cells meant no storage.

### Network details to retain

- Lab NAT network `ocne19-net`: `192.168.77.0/24`, gateway `.1`, DHCP disabled.
- op/cp/w1/w2 use `.10/.11/.12/.13`; Windows `.lab.test` entries match. Loopback SSH forwards remain 2220-2223.
- Workers have isolated NIC2/NIC3 networks `ocne-rac-priv1` / `ocne-rac-priv2`; pod interconnects use the documented 192.168.78/79 networks.
- **Operator NIC2 also exists:** bridged to `Killer E3100G 2.5 Gigabit Ethernet Controller`, guest `enp0s8`, observed DHCP address `192.168.137.229/24`. It was already preserved in the [cloning log](CLONING-RUN-LOG.md); it is not created by the basic four-node resource table. Record/reconcile it explicitly on a rebuild. Its DHCP lease and physical adapter name are environment-derived, not portable constants. The lab NAT route currently has metric 100, the bridged route metric 101.
- Unrelated VirtualBox network/media registrations and old `.lab.local` Windows entries were left untouched. Their existence is not permission to remove them.

## 2. Checks actually performed

| Area | Read-only inspection / verification | Result and limit |
|---|---|---|
| Host | Parsed/reran script 00; queried drives, VM configurations, networks, snapshot/media registration | VirtualBox 7.2.18; four lab VMs running with requested RAM/CPU; golden powered off |
| Golden chain | Verified registered base/child identities and file presence/size | Both media accessible as `created`; no boot test, export, backup, or restore test performed |
| Access | SSH to op, cp, w1, w2 using strict host-key checking and workstation key | All succeeded; inter-VM SSH mesh was not retested |
| Kubernetes | Nodes, deployments, daemonsets, RAC/app pods, PVCs | Three Ready nodes; two RAC pods and eight app pods Ready; operator and cert-manager deployments available |
| RAC | Ran the reviewed `Verify-RAC-Database.sh` over SSH stdin | Both instances OPEN/ACTIVE; LABPDB READ WRITE; GI online; SGA/PGA/HugePages match; RU/OJVM SQL actions SUCCESS; service active on both |
| ASM candidates | Ran reviewed `Verify-RAC-Spare-Candidates.sh` | Four Bound Block PVs; asm01/02 MEMBER, asm03/04 CANDIDATE/group 0 on both; DATA 102392 MiB; no SPAREDISKS diskgroup |
| Live manifest | Compared every declared field of `rac-database-live.yaml` with the live spec | Match; extra server defaults for mount locations are expected, not configuration drift |
| Home media | Recomputed SHA256 on Windows and both worker stage copies | Both home hashes match recorded acceptance on all three hosts |
| CVU media | Recomputed local ZIP SHA256 | Matches recorded supplied CVU fingerprint; CVU execution was not repeated |
| Application images | Recomputed local tar SHA256; inspected archive manifest | Matches deployment record; contains all four `localhost/rac-board-*:1.0.0` images; no load/rebuild performed |
| Application API | GET `/api/status` through each worker's NodePort 30080 | Both return healthy Python/Java Oracle services, LABPDB and `labpdb_app`; no data writes or faults injected |
| Storage / NFS | Worker scratch/container/NFS mounts; operator NFS mount and services | Intended mounts present; NFS/API services active; no new NFS write test performed |
| Worker HugePages | Read `/proc/meminfo` | `HugePages_Total: 0` on both |
| Vendor assets | Checked six files against `config/vendor/SHA256SUMS` | All six match |
| Helpers | Parsed all 15 PowerShell scripts under scripts/ | Syntax passed; this is not execution acceptance for fresh provisioning |
| Existing backup | Listed known RMAN backup directory in RAC node 1 | October 11 pieces still present; no fresh backup/read validation/restore performed |

Inspection corrections: the initial whole-object manifest comparison flagged additional server defaults; comparison of declared fields passed. A checksum parser initially treated the SHA256SUMS comment as an entry and was corrected. Windows-to-SSH quoting broke a `find -printf` query; rerunning through Bash stdin with `find -ls`/`-print` verified the intended paths. These inspection errors did not modify lab resources.

## 3. Preservation requirements before deleting anything

### Golden VM is outside the project

Preserve a consistent complete source VM, including all dependent media, rather than copying only its latest snapshot file:

| Observed source dependency | Present size |
|---|---:|
| `D:\VMs\ol9-golden\ol9-golden.vdi` | 11,897,143,296 bytes |
| `C:\Users\pradeep reddy\VirtualBox VMs\ol9-golden\Snapshots\{8eca724c-66ce-4188-a40f-436bb21a9197}.vdi` | 309,329,920 bytes |
| `C:\Users\pradeep reddy\VirtualBox VMs\ol9-golden\ol9-golden.vbox` | 7,448 bytes |

VM UUID: `90aaa385-c8d3-49ce-aad9-50f65ada16d4`. Base media UUID: `f81b5de4-85e9-4a94-b950-330dd454f9ee`; attached differencing media UUID: `8eca724c-66ce-4188-a40f-436bb21a9197`. Snapshot `00-golden` is recorded. These identify the **existing source**, not IDs to assign to new clones.

An archive/copy must preserve the complete source configuration and dependency chain, with its restore/import procedure verified separately. A backup of `D:\OCNE19-Lab` alone misses these files. Free capacity was observed on E:, but no E: backup was requested or verified; free space is not backup evidence.

### Verified local artifact fingerprints

| File | SHA256 |
|---|---|
| `ISO/oracle-gridhome-19.32.zip` | `d02d04276e767d7715006fa3690851f2203ff578ff35e963e18b67b15ddcc917` |
| `ISO/oracle-dbhome-19.32.zip` | `da75d72a2c1491d129e70ac0c3cdbb86c19024d5d80931f0e9c7714d25ef7e5f` |
| `ISO/cvupack_linux_ol8_x86_64.zip` | `23da73fed4b9403f933a5bbb8e75e9b6931ed5fd33fd1dbfc6503227de70bdc8` |
| `private/rac-app-images-1.0.0.tar` | `5b137845b7afbb0ebd53ecda966c3275b2e4a76cbef8e047eb1f2e8005401145` |

Base Grid/DB ZIPs, RU downloads, OPatch ZIP, and preparation ISO are present under `ISO/`; their existence was checked, but this audit did not rehash every source download or repeat ZIP CRC scans. The final home fingerprints match the archives that previously passed full CRC/path checks. Use [artifact acceptance](RAC-ARTIFACT-ACCEPTANCE.md) and [gold-home build documentation](../gold-home-build/README.md) for provenance.

The running RAC image is pinned to:

```text
docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
```

No separate RAC slim-image archive or complete RPM reinstall kit was identified in the inspected project `ISO/` and `private/` archive inventory. The checked guest home directories contained application archives, not a verified comprehensive offline kit. This is scoped inventory, not a claim that no copy exists anywhere. Installed CRI-O stores inside VMs do not survive deleting those VMs.

Before relying on an offline rebuild, preserve and test import of the exact RAC image, Database Operator, cert-manager, OCNE/Kubernetes/Multus images, and required packages/dependencies. Otherwise the build remains dependent on repositories/registries and required authentication. This audit did not pull images, refresh repositories, or prove all exact package versions can still be downloaded. Existing manifests and running images do not prove future registry availability.

### Credentials and current data

- Retain protected access material and required private inputs outside the deletion scope; never put them in Git. Validate credential usability in the intended restored Windows account/context, rather than assuming encrypted credential files are portable.
- A fresh lab can generate new guest identities, platform certificates, kubeconfigs and database/application credentials through the documented procedures. Coordinate credentials consistently; do not reuse old host fingerprints for new clones.
- If current data must survive, obtain a current, consistent database backup plus required recovery metadata/logs, copy it outside the lab, and test the restore procedure in an isolated target.
- Existing RMAN pieces are at `/u01/app/oracle/recovery-backups/manual-exercises-20261011` on RAC node 1's persistent worker scratch. They are **inside the lab's failure/deletion scope**, are dated **October 11**, and predate the **October 13 application deployment**. They are not evidence that current application records can be recovered.
- The previous `RESTORE DATABASE VALIDATE` read backup pieces; it did not restore a database. See [recorded recovery evidence](RAC-EXERCISE-RECOVERY-OUTPUT.md).

## 4. Exact sequence to follow on a future rebuild

This fixes the order and scope; detailed commands remain in the existing cited manuals. Each stage requires its documented result before proceeding.

| Order | Use | Required outcome / reconciliation |
|---|---|---|
| 0 | This audit + [user instructions](USER-INSTRUCTIONS.md) | Confirm deletion scope, independently protected source/media/access/data, actual host capacity and package/image availability |
| 1 | [Cloning entry point](../README-CLONING.md), [cloning guide](OCNE-1.9-Golden-VM-Cloning-Guide.md), [manual part 1](MANUAL-01-OCNE.md) | Inspect source and host; full clones with selected RAM/CPU; rediscover all identity/disk guards; preserve unrelated resources; account for operator's second NIC |
| 2 | [Full OCNE setup guide](OCNE-1.9-OL9-Setup-Guide.md) | Oracle Installation procedure and linked Kubernetes continuation; unique identities, SSH/hosts, correct storage, 100 GiB NFS with real client writes |
| 3 | [Operator manual](MANUAL-02-DATABASE-OPERATOR.md) | Approved vendored versions/hashes, cert-manager/RBAC/operator Ready |
| 4 | [RAC manual](MANUAL-03-RAC.md) | 128 GiB scratch per worker, two initial shared ASM disks, private networks, verified supplied image/homes/CVU, secrets and fresh manifest review |
| 5 | Same RAC manual | Provision; verify GI/ASM/SQL, patch state, LABPDB and actual `labpdb_app`; SGA 3 GiB/PGA 2 GiB/HugePages off |
| 6 | [Application manual](../apps/rac-lab-board/docs/MANUAL.md) | Four image archive import or reviewed rebuild; schemas/secrets; eight app replicas; main URL and API/SQL verification |
| 7 | [Additional shared disks](RAC-ADD-SHARED-CANDIDATE-DISKS.md) | Add asm03/04, apply OTHERS entries to the **new resource's** current manifest; verify candidates on both ASM instances |
| 8 | [Operations manual](MANUAL-04-RAC-OPERATIONS.md), [scenario matrix](RAC-TEST-SCENARIO-MATRIX.md), app failover workbook | Capture results one scenario at a time; preserve known recovery limits; leave unexecuted tests labeled |
| 9 | Existing run logs and manuals | Record actual identities/versions/results/fixes; review sanitized Git changes for requested publication |

### Fresh versus live YAML matters

`config/rac-database.yaml` creates the initial two-disk database with the intended `labpdb_app` service. It intentionally does **not** include the later spare disks. `config/rac-database-live.yaml` describes today's resource, with four disk paths and its immutable legacy service metadata (`labpdb`); the actual working service is `labpdb_app`.

For a new build, retain the fresh manifest's service settings when adding SPAREDISKS later. Do not switch a new resource to today's live YAML merely to gain two disk entries, and do not carry old PV/PVC names, CR UIDs, disk serials, or filesystem UUIDs into a new cluster. This is the existing fresh/live distinction, made explicit at the rebuild handoff.

### Historical helpers are not a blind replay script

The [script reference](SCRIPT-REFERENCE.md) identifies one-time identity, filesystem, certificate and recovery helpers. Some embed this lab's disk serials, machine IDs, resource UIDs, or process IDs. Follow their inspection gates and update only observed identity inputs. Never remove those guards to force a rebuild through.

Likewise, the shorter [fresh-build guide](../fresh-build/README.md) begins with generic prepared hosts, uses different minimum OP/CP sizing examples, and treats NFS as an optional addition. For this specific reconstruction, the original cloning path, chosen 4/8/22/22 GiB allocations, additional NFS, application, and later ASM candidates remain part of the agreed target.

## 5. Remaining readiness gates

| Gate | Audit status | Before relying on a wipe/rebuild |
|---|---|---|
| Complete golden source backup outside deletion scope | **Unverified** | Identify destination; copy/export consistently; verify files and a usable restore/import path |
| Oracle media and application archive backup | **Local files verified; external copy unverified** | Preserve copies with matching hashes outside the intended wipe scope |
| Exact package/container availability | **Not fully preserved or download-verified** | Confirm exact repository/registry availability or prepare and test a complete offline kit |
| Current data recovery, if required | **Not ready** | Fresh backup outside the lab and an isolated restore test; old scratch backup is insufficient |
| Fresh rebuild rehearsal | **Not executed** | Perform an isolated, separately authorized rebuild through every acceptance gate |
| GI image restart behavior | **Known limitation retained** | Follow documented recovery precautions; patched homes do not prove the image's restart logic is fixed |

The user was asked for an existing external backup location; none was supplied during this inspection. No backup destination was invented or populated. These gates explain why healthy live services and complete-looking documentation are insufficient grounds to delete the lab now.
