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
