# RAC image and gold-home acceptance — 10 October 2026

The supplied artifacts are staged on both workers. The final [RAC YAML](../config/rac-database.yaml) passed server-side create dry-run at 21:39 EDT. RAC has not been provisioned; no RacDatabase, PV or rac PVC exists. **Prerequisite checks are complete: the user confirmed at 21:56 EDT that DBCA fix 34436514 is unnecessary for the supplied 19.32 home.**

## Image

User tag: `docker.io/roopla/oracle-rac:19.3.0-slim`. Both rootful CRI-O stores report:

```text
docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
image ID: d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52
CRI reported size: 442804639 bytes
```

Read-only file inspection found Oracle Linux 9.8, linux/amd64, oracle UID/GID 54321:54321, grid UID/GID 54332:54321, `/usr/sbin/init` pointing to systemd, Python 3, and `/opt/scripts/startup/scripts/{main.py,cmdExec}`. All 19 top-level RAC Python scripts parsed. The scripts implement pkeyutl secrets and conditional RU/one-off/OPatch paths. The YAML omits all patch-application fields. No container entrypoint, GI installer or DB installer was executed; static inspection does not prove runtime compatibility. The tag is a slim-image label, not proof of a 19.3 database version. The supplied home inventories identify 19.32.

## Gold homes

Both ZIPs passed full source CRC checks, archive-member path checks, and source-stability checks. Installers are at the archive root, with no extra enclosing directory. Destination SHA256 matched on both workers. Fingerprints establish copy integrity; they are not Oracle-published checksums for these user-built homes.

| File | ZIP bytes | Expanded bytes | Entries | Root installer |
|---|---:|---:|---:|---|
| oracle-dbhome-19.32.zip | 5142587720 | 11724672142 | 51787 | runInstaller |
| oracle-gridhome-19.32.zip | 5100099678 | 11540170217 | 47331 | gridSetup.sh |

```text
da75d72a2c1491d129e70ac0c3cdbb86c19024d5d80931f0e9c7714d25ef7e5f  oracle-dbhome-19.32.zip
d02d04276e767d7715006fa3690851f2203ff578ff35e963e18b67b15ddcc917  oracle-gridhome-19.32.zip
```

Archive inventory records: DB RU 39472050 (19.32.0.0.260721), OCW 39526364 and OJVM 39222882 in both homes; Grid also records ACFS 39503034, TOMCAT 39107855 and DBWLM 39107825. Both contain OPatch 12.2.0.1.53. Older 19.3 records also remain in the archive inventory. These observations are archived metadata, not a successful live `opatch lsinventory` or `datapatch` result.

Both workers contain the files under `/scratch/software/stage/19c/19.32-gold`, owner 54321:54321, mode 0755 and SELinux container_file_t. Scratch mount UUIDs were checked before accepting files. Approximately 101 GiB remains free on each scratch filesystem; the two archives expand to about 21.7 GiB combined. Container filesystems retain about 97 GiB free. No homes were extracted or configured.

## DBCA applicability decision - closed by user confirmation

[Oracle's RAC on OCNE guide](https://docs.oracle.com/en/database/oracle/oracle-database/19/rackb/install-configure-rac-olcne.html) specifies DBCA memory fix 34436514 for its 19.28 example. None of the supplied archived patch/bug inventories lists that ID. This does not establish whether 19.32 supersedes it or whether another build step supplied the fix. On 10 October at 21:56 EDT, the user confirmed that fix 34436514 is unnecessary for the supplied 19.32 home. The prerequisite question is closed on that basis. This records the owner's determination; no independent Oracle Support verification or claim of binary inclusion/supersedence is made. The existing verified artifacts and manifest are retained. No deployment-time patch application is configured.

## Manual reproduction

From the project root on the workstation (Git Bash or Linux with configured SSH aliases):

```bash
python scripts/Inspect-RAC-Gold.py
sha256sum ISO/oracle-dbhome-19.32.zip ISO/oracle-gridhome-19.32.zip
# First inspect the destination: copy only to a new empty stage directory.
for node in ocne-w1 ocne-w2; do
  ssh "$node" "findmnt -M /scratch -o UUID,TARGET; ls -l /scratch/software/stage/19c/19.32-gold"
  # For this completed build, use the verification commands below instead of copying again.
done
```

For a new build, the [handoff](RAC-PROVISIONING-HANDOFF.md) gives equivalent PowerShell and Bash transfer commands. On each worker as root, run the checked-in scripts after copying them through your authenticated SSH session:

```bash
bash Stage-RAC-Slim-Image.sh
bash Inspect-RAC-Slim-Image.sh
bash Verify-RAC-Image-Contract.sh
bash Inspect-RAC-Image-Patch-Gates.sh
bash Verify-RAC-Gold-Staging.sh
```

These scripts contain the complete direct Bash commands: [pull](../scripts/Stage-RAC-Slim-Image.sh), [filesystem inspection](../scripts/Inspect-RAC-Slim-Image.sh), [script contract](../scripts/Verify-RAC-Image-Contract.sh), [patch guards](../scripts/Inspect-RAC-Image-Patch-Gates.sh), [gold hashes/permissions](../scripts/Verify-RAC-Gold-Staging.sh). Image inspections mount and unmount an image without starting it. Read the scripts first; hostname and filesystem UUID guards are specific to this lab and require observed identities on a rebuild. Gold verification adjusts only the two named files after matching hashes. The inspector writes its raw report only under ignored logs/.

On ocne-cp as labadmin, after copying the exact final YAML:

```bash
kubectl create --dry-run=server -f ~/ocne-rac-prereqs/rac-database.yaml
kubectl get racdatabases -A
kubectl get pv
kubectl get pvc -n rac
```

Only the separate user-only step in the handoff applies the manifest. CVU host checks passed previously on both workers; RAC runtime, live patch inventories and SQL patch status must be validated after user provisioning. Secrets, ZIPs, image layers and raw output are excluded from Git.

## SGA increase - 10 October, 21:59 EDT

At the user's request, increased sgaSize from 1G to 2G per RAC instance, retaining PGA 2G, 16 GiB ordinary pod memory and 2 GiB HugePages. Both workers reported all 1024 two-MiB HugePages free before provisioning. The revised YAML passed server-side create dry-run; no RacDatabase exists. Windows/control-plane copies match SHA256 `01e10e9c9fef99fc07a34c8f8a5d51f5a2b4b2fe825f8f11ef362484d082fe85`. This supersedes the earlier manifest fingerprint in the chronological logs. Runtime capacity remains untested.

## SGA 3 GiB and matching HugePages - 2026-10-10 22:01-22:08 EDT

The user authorized 3 GiB SGA per RAC instance. Updated sgaSize to 3G, HugePages request/limit to 3Gi, TOTAL_MEMORY to 19456 MiB, kernel.shmmax to 3221225472 bytes and kernel.shmall to 786432 four-KiB pages. PGA remains 2G, ordinary pod memory 16Gi, CPU 4 and worker RAM 22Gi. Updated diagnostic manifests and future-build/verification scripts consistently.

Inspected host state and confirmed no RAC resource/pods existed. On each worker sequentially, guarded by its scratch UUID and completely unused HugePages pool, backed up /etc/sysctl.d/98-ocne-rac.conf under /var/opt/ocne-rac-hugepages-backup-<timestamp>, increased vm.nr_hugepages from 1024 to 1536, saved that setting and restarted kubelet. Both workers remained Ready and advertised 3Gi HugePages; ordinary allocatable memory was 18877204Ki/18877232Ki. No VM reboot was performed. Persistence is configured in sysctl.d; this new value has not yet been verified across reboot.

The two diagnostic pods scheduled with 4CPU, 16Gi ordinary memory and 3Gi HugePages. Both private networks passed bidirectional 1472-byte payload pings and DNS; hugetlbfs mounts and the new shmmax were verified. Removed only the two named test pods. Separately used a temporary hugetlbfs file and mmap on each host to allocate and touch all 1536 HugePages (3 GiB), then unmapped/unlinked it and verified every page was free again. Worker checks passed for SELinux, mounts, private NICs, THP, kernel settings, services and Chrony. This is host allocation and diagnostic scheduling evidence, not a RAC runtime test.

The revised manifest passed server-side create dry-run. Windows/control-plane copies match SHA256 `8c76f48256eb145460033b2499b80a7a736d77d14fd95931200dfa4a0a7790b2`. No RacDatabase or pods remain in namespace rac. The earlier 2G dry-run/fingerprint entries are historical; 3G is now the user-selected configuration. No RAC provisioning was performed.
