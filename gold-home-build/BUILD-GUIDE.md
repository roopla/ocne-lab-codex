# Step-by-step: build the patched 19.32 home archives

[Overview, architecture, manifest, and recorded fingerprints](README.md)

## 1. Scope and execution locations

This guide reconstructs the owner's workflow and supplies commands for a future build. **The commands were statically checked, not executed against a new VM.** Expected outputs are examples/acceptance criteria; actual historical results are labeled in the overview. Installer screens and patch READMEs remain explicit checkpoints.

| Location / user | Work |
|---|---|
| Separate OL9 build VM / root | Packages, accounts/groups, directories, prompted root scripts |
| Build VM / grid | Grid extraction, OPatch upgrade, GI RU, inventory, archive |
| Build VM / oracle | DB extraction, OPatch upgrade, DB RU, inventory, archive |
| Windows workstation | Receive/check ZIPs under `D:\OCNE19-Lab\ISO` |
| ocne-w1 and ocne-w2 | Stage archives at the same worker path |
| ocne-cp / labadmin | Review manifest; check the provisioned RAC database |

Use a dedicated preparation VM with fresh software homes. Shared ASM disks, Kubernetes, and a running database are not needed merely to prepare media. Do not run build steps on live RAC pods or their mounted homes. `/build/rac-gold` is an example local layout, not an Oracle requirement.

## 2. Inspect the build VM and install prerequisites

**Build VM / root, Bash:**

```bash
set -euo pipefail
cat /etc/oracle-release
uname -r
uname -m
free -h
df -h / /tmp
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
getenforce
dnf repolist
```

Expected: Linux x86-64 and the intended OS/kernel, with adequate existing filesystem space. Inspect where `/u01` and `/build` will reside. The historical OS was reported as OL9.8; its kernel/resource transcript was not captured. Check [19c Grid OL9 platform/package requirements](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/supported-oracle-linux-9-distributions-for-x86-64.html). Do not format a guessed device.

Allow space for base media, extracted patch bundles, homes, patch backups, and output ZIPs. The supplied homes expand to **21.7 GiB**, with another **9.5 GiB** for their ZIPs. **100 GiB free** across the build filesystems is a local planning allowance, not an Oracle minimum or a measured original peak.

**Build VM / root:**

```bash
dnf install -y oracle-database-preinstall-19c unzip zip
rpm -q oracle-database-preinstall-19c
getent passwd oracle
getent group oinstall dba
rpm -ql oracle-database-preinstall-19c
```

Expected: package installed; `oracle`, `oinstall`, `dba` exist. If unavailable, correct OL9 repository configuration. This is the **preinstallation** RPM, not the database software RPM. It prepares dependencies/settings, but does not install these ZIP homes or create the extra Grid owner. Its user limits apply to `oracle`; check `grid` separately. [Oracle RPM behavior](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/Chunk1092467399.html).

## 3. Prepare accounts, groups, and directories

**Build VM / root:** inspect identities first.

```bash
id oracle
getent passwd grid || true
getent passwd 54332 || true
getent group oinstall dba oper backupdba dgdba kmdba racdba asmadmin asmdba asmoper || true
```

The supplied slim image has Oracle UID **54321**, Grid UID **54332**, primary GID **54321**. Plan identities consistently with your target image; do not renumber existing users or reuse occupied IDs. Oracle's [19c account/path example](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/example-of-creating-minimal-users-roles-groups.html) explains separate owners and the inventory group. Additional groups below implement the lab roles; check numeric group IDs against your image/site policy.

**Build VM / root, after identity review:**

```bash
for group in oper backupdba dgdba kmdba racdba asmadmin asmdba asmoper; do
  getent group "$group" >/dev/null || groupadd "$group"
done
if ! id grid >/dev/null 2>&1; then
  if getent passwd 54332 >/dev/null; then
    echo 'UID 54332 occupied: resolve identity plan first' >&2
    exit 1
  fi
  useradd -m -u 54332 -g oinstall -G asmadmin,asmdba,asmoper,dba,racdba grid
fi
test "$(id -gn grid)" = oinstall
test "$(id -gn oracle)" = oinstall
usermod -aG asmadmin,asmdba,asmoper,dba,racdba grid
usermod -aG dba,oper,backupdba,dgdba,kmdba,racdba,asmdba oracle
id grid
id oracle
```

Expected: primary group `oinstall`; Grid has ASM administration groups; Oracle accesses ASM through `asmdba`. Start new login sessions after group changes. Authenticate through normal console/SSH policy; no passwords are embedded here.

**Build VM / root:** check each owner's login limits.

```bash
rpm -ql oracle-database-preinstall-19c | grep '/limits.d/'
su - grid -c 'ulimit -Sn; ulimit -Hn; ulimit -Su; ulimit -Hu; ulimit -Ss; ulimit -Hs; ulimit -Sl; ulimit -Hl'
su - oracle -c 'ulimit -Sn; ulimit -Hn; ulimit -Su; ulimit -Hu; ulimit -Ss; ulimit -Hs; ulimit -Sl; ulimit -Hl'
```

If Grid limits are missing, add a reviewed Grid-specific file under `/etc/security/limits.d/`, following [19c installation-user limits](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/checking-resource-limits-for-oracle-software-installation-users.html), and verify a new login session. RPM installation alone does not prove both users are ready. Preserve SELinux and normal sudo boundaries.

**Build VM / root:** this guard stops if an installation path exists. Inspect existing paths instead of deleting them or recursively changing ownership.

```bash
for path in /u01/app/19c/grid /u01/app/grid /u01/app/oracle /u01/app/oraInventory /build/rac-gold; do
  if test -e "$path"; then
    echo "Inspect existing path first: $path" >&2
    exit 1
  fi
done
install -d -m 0755 /u01/app/19c /build
install -d -o grid -g oinstall -m 0775 /u01/app/19c/grid /u01/app/grid /u01/app/oraInventory
install -d -o oracle -g oinstall -m 0775 /u01/app/oracle
install -d -o oracle -g oinstall -m 0775 /u01/app/oracle/product/19c/dbhome_1
install -d -o root -g oinstall -m 0750 /build/rac-gold /build/rac-gold/media /build/rac-gold/patches
install -d -o grid -g oinstall -m 0750 /build/rac-gold/grid-output /build/rac-gold/grid-backup
install -d -o oracle -g oinstall -m 0750 /build/rac-gold/db-output /build/rac-gold/db-backup
stat -c '%U:%G %a %n' /u01/app/19c/grid /u01/app/grid /u01/app/oracle /u01/app/oraInventory
```

Expected: Grid owns its home/base and the initial shared inventory; Oracle owns its base/home. **Grid home is outside Grid base.** Paths match the RAC manifest, but these preparation-VM filesystems are separate from Windows and the worker stage.

## 4. Download and verify media

Obtain base media from [Oracle's 19c Linux x86-64 downloads](https://www.oracle.com/database/technologies/oracle19c-linux-downloads.html). Obtain patches through authorized [My Oracle Support](https://support.oracle.com/) access and retain their READMEs. No unauthenticated RU download command is available here.

| Input | Selected artifact / check |
|---|---|
| Grid base | `LINUX.X64_193000_grid_home.zip` |
| Database base | `LINUX.X64_193000_db_home.zip` |
| GI RU bundle | **39467003**, 19.32 Linux x86-64 |
| DB RU | **39472050**, 19.32; use the patch directory required by its README |
| OPatch | Patch **6880880**, correct 19c Linux x86-64 selection; supplied homes record **12.2.0.1.53** |
| Additional patches | Match approved inventory; OJVM **39222882** appears in the supplied homes |

The local source-media review recorded minimum OPatch **12.2.0.1.52** in both RU READMEs. Confirm against your exact downloads. Reproducing every component requires the applicable additional patch READMEs and conflict checks; the RU filename alone is insufficient.

**Build VM / root:** transfer media to `/build/rac-gold/media` using authenticated SCP or approved downloads. Make selected files readable by `oinstall`; keep binaries and credentials private. Then:

```bash
find /build/rac-gold/media -maxdepth 1 -type f -printf '%f\n'
cd /build/rac-gold/media
sha256sum LINUX.X64_193000_grid_home.zip LINUX.X64_193000_db_home.zip
unzip -tq LINUX.X64_193000_grid_home.zip
unzip -tq LINUX.X64_193000_db_home.zip
```

Expected: CRC passes and hashes match Oracle's page for the exact base files. Published base checksums checked for this guide:

```text
d668002664d9399cf61eb03c0d1e3687121fc890b1ddd50b35dcbe13c5307d2e  LINUX.X64_193000_grid_home.zip
ba8329c757133da313ed3b6d7f86c5ac42cd9970a28bf2e6233f3235233aa8d8  LINUX.X64_193000_db_home.zip
```

Extract RU downloads into separate empty directories under `/build/rac-gold/patches`, following their READMEs. Locate the GI bundle directory `39467003` and the DB patch directory (possibly nested in that bundle); do not guess an extraction level. Both owners must be able to read/traverse their selected directories.

## 5. Extract each home and upgrade OPatch

**Build VM / grid, new login session:**

```bash
set -euo pipefail
export ORACLE_HOME=/u01/app/19c/grid
export ORACLE_BASE=/u01/app/grid
umask 022
test -z "$(find "$ORACLE_HOME" -mindepth 1 -maxdepth 1 -print -quit)"
cd "$ORACLE_HOME"
unzip -q /build/rac-gold/media/LINUX.X64_193000_grid_home.zip
test -x ./gridSetup.sh
./OPatch/opatch version
```

**Build VM / oracle, separate login session:**

```bash
set -euo pipefail
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_BASE=/u01/app/oracle
umask 022
test -z "$(find "$ORACLE_HOME" -mindepth 1 -maxdepth 1 -print -quit)"
cd "$ORACLE_HOME"
unzip -q /build/rac-gold/media/LINUX.X64_193000_db_home.zip
test -x ./runInstaller
./OPatch/opatch version
```

Expected: installer directly in each home; base OPatch may be too old. For **each owner in the same session**, identify the exact OPatch ZIP. This backup/extraction example assumes patch 6880880's README and archive specify an `OPatch/` root directory:

```bash
read -r -p 'Absolute path to verified OPatch ZIP: ' OPATCH_ZIP
test -f "$OPATCH_ZIP"
unzip -tq "$OPATCH_ZIP"
unzip -Z1 "$OPATCH_ZIP" | sed -n '1,12p'
```

Check the displayed layout and README before continuing. **Grid session:**

```bash
test "$ORACLE_HOME" = /u01/app/19c/grid
test ! -e /build/rac-gold/grid-backup/OPatch-original
mv "$ORACLE_HOME/OPatch" /build/rac-gold/grid-backup/OPatch-original
unzip -q "$OPATCH_ZIP" -d "$ORACLE_HOME"
"$ORACLE_HOME/OPatch/opatch" version
```

**Oracle session:**

```bash
test "$ORACLE_HOME" = /u01/app/oracle/product/19c/dbhome_1
test ! -e /build/rac-gold/db-backup/OPatch-original
mv "$ORACLE_HOME/OPatch" /build/rac-gold/db-backup/OPatch-original
unzip -q "$OPATCH_ZIP" -d "$ORACLE_HOME"
"$ORACLE_HOME/OPatch/opatch" version
```

Expected for the original artifacts:

```text
OPatch Version: 12.2.0.1.53
OPatch succeeded.
```

If extraction fails, stop and inspect; preserve the external backup. Do not continue with mixed old/new OPatch files. Use absolute home paths to avoid checking another home's utility.

## 6. Apply 19.32 RU through the installers

Use a desktop/X11 session able to display Oracle's wizard. These are interactive installation commands. Read the [19c Linux release notes](https://docs.oracle.com/en/database/oracle/oracle-database/19/rnrdm/database-release-notes.pdf) for OL9 before starting 19.3 media. Apply prerequisites/workarounds relevant to the chosen RU; do not suppress all prerequisite failures or copy a client-only workaround into a server installation.

**Build VM / grid:** select the extracted **GI bundle** identified by its README.

```bash
export ORACLE_HOME=/u01/app/19c/grid
export ORACLE_BASE=/u01/app/grid
read -r -p 'Absolute extracted GI RU directory (39467003): ' GI_RU_DIR
test -d "$GI_RU_DIR"
cd "$ORACLE_HOME"
./gridSetup.sh -applyRU "$GI_RU_DIR"
```

Select **Set Up Software Only**, base `/u01/app/grid`, inventory `/u01/app/oraInventory` with group `oinstall`, and the prepared ASM role groups. Resolve failed prerequisites and inspect patch/install logs. Follow the wizard's specific root-script prompts on the build VM, retaining their output. Do not continue into configuring a build-VM RAC cluster or ASM diskgroup for this preparation task. [Oracle 19c Grid software-only installation and `-applyRU`](https://docs.oracle.com/en/database/oracle/oracle-database/19/cwlin/installing-software-binaries-for-oracle-grid-infrastructure-for-a-cluster.html).

**Build VM / oracle:** select the **DB RU** path required by its README.

```bash
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_BASE=/u01/app/oracle
read -r -p 'Absolute extracted DB RU directory (39472050): ' DB_RU_DIR
test -d "$DB_RU_DIR"
cd "$ORACLE_HOME"
./runInstaller -applyRU "$DB_RU_DIR"
```

Choose **Set Up Software Only**, the intended **Enterprise Edition** home, base `/u01/app/oracle`, shared inventory, and database role groups. Do not create `RACCDB` or `LABPDB` on the build VM. [Oracle's DB `-applyRU` procedure](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/apply-patches-during-db-install.html).

**Installer checkpoint:** the owner's database installation-type selection was not recorded. A preparation VM without configured Clusterware cannot be treated as an already-configured RAC cluster. Resolve the software-only installation choice for your gold-image method; do not fabricate cluster nodes to satisfy the wizard. The target RAC image performs its own RAC installation/configuration. A standalone software-only build alone does not prove compatibility with that image: require inventory, archive, and target RAC acceptance below.

Apply any required OJVM/component/one-off patches using their own README and conflict checks before packaging. No guessed `opatch apply` order is supplied. Metadata establishes what was present, not whether the owner used `-applyOneOffs` or later OPatch commands for each additional patch.

**Build VM / each owner with its own ORACLE_HOME:**

```bash
"$ORACLE_HOME/OPatch/opatch" version
"$ORACLE_HOME/OPatch/opatch" lspatches
"$ORACLE_HOME/OPatch/opatch" lsinventory -detail
```

Expected: successful inventory access, intended 19.32 components/IDs, selected OPatch version. Review missing components against the approved patch list. Older 19.3 records can remain; do not delete inventory records to alter the displayed version. Preserve results privately. Launching an installer or naming a ZIP does not prove patch success.

## 7. Create the two archives

The owner reported zipping the patched homes; **the exact original command is unrecorded**. For a future build, Oracle documents `-createGoldImage` for both installers. This is the recommended packaging example here, not a claim about the original command. [Oracle 19c image-creation options](https://docs.oracle.com/en/database/oracle/oracle-database/19/ladbi/setup-wizard-installation-options.html).

**Build VM / grid:**

```bash
cd /u01/app/19c/grid
./gridSetup.sh -createGoldImage -destinationLocation /build/rac-gold/grid-output
find /build/rac-gold/grid-output -maxdepth 1 -type f -name '*.zip' -printf '%f\n'
```

**Build VM / oracle:**

```bash
cd /u01/app/oracle/product/19c/dbhome_1
./runInstaller -createGoldImage -destinationLocation /build/rac-gold/db-output
find /build/rac-gold/db-output -maxdepth 1 -type f -name '*.zip' -printf '%f\n'
```

Expected: successful creation and the generated archive path. Consult the actual 19c executable's help/logs if prompted for further input. Output stays outside the source home. Do not exclude inventory or patch metadata merely to shrink files, or include database files, ASM storage, passwords, wallets, or host-specific runtime configuration.

**Each owner separately:** rename the identified new file without overwriting an existing final artifact.

```bash
read -r -p 'Absolute path of archive just generated: ' GENERATED_ZIP
test -f "$GENERATED_ZIP"
# Grid: /build/rac-gold/grid-output/oracle-gridhome-19.32.zip
# Oracle: /build/rac-gold/db-output/oracle-dbhome-19.32.zip
read -r -p 'Absolute final archive pathname: ' FINAL_ZIP
test -n "$FINAL_ZIP"
test ! -e "$FINAL_ZIP"
mv -n -- "$GENERATED_ZIP" "$FINAL_ZIP"
unzip -tq "$FINAL_ZIP"
sha256sum "$FINAL_ZIP"
```

For a manual ZIP, validate symlinks, executable modes, hidden content, inventory, and root layout. Zipping the enclosing `grid/`, `dbhome_1/`, or `/u01` directory produces the wrong extraction shape. This guide does not assert that an arbitrary `zip -r` invocation is equivalent to Oracle's procedure.

## 8. Inspect archives and transfer to Windows

**Build VM / each owner**, with `FINAL_ZIP` still set:

```bash
unzip -Z1 "$FINAL_ZIP" | sed -n '1,25p'
unzip -Z1 "$FINAL_ZIP" | grep -E '^(gridSetup.sh|runInstaller|OPatch/version.txt|inventory/)' | sed -n '1,20p'
```

Expected: the appropriate root installer, OPatch, and home inventory. No enclosing directory. CRC establishes integrity, not patch correctness or runtime compatibility.

**Windows workstation / PowerShell:** replace `BUILD_VM` with the separate build VM's configured SSH host/IP. Commands refuse to overwrite existing artifacts.

```powershell
Set-Location D:\OCNE19-Lab
$buildHost = 'BUILD_VM'
if ($buildHost -eq 'BUILD_VM') { throw 'Set the actual build VM destination.' }
if (Test-Path ISO/oracle-gridhome-19.32.zip) { throw 'Inspect existing Grid ZIP first.' }
if (Test-Path ISO/oracle-dbhome-19.32.zip) { throw 'Inspect existing DB ZIP first.' }
scp "grid@${buildHost}:/build/rac-gold/grid-output/oracle-gridhome-19.32.zip" ISO/
if ($LASTEXITCODE -ne 0) { throw 'Grid copy failed.' }
scp "oracle@${buildHost}:/build/rac-gold/db-output/oracle-dbhome-19.32.zip" ISO/
if ($LASTEXITCODE -ne 0) { throw 'DB copy failed.' }
Get-FileHash ISO/oracle-gridhome-19.32.zip,ISO/oracle-dbhome-19.32.zip -Algorithm SHA256
python scripts/Inspect-RAC-Gold.py
if ($LASTEXITCODE -ne 0) { throw 'Gold-home inspection failed.' }
```

Expected: hashes match the **new build's source hashes**; inspector passes CRC, path, and source-stability checks. It writes `logs/rac-gold-inventory.json` (ignored). Inspect selected metadata fields rather than printing its large full inventories. Compare patch IDs/OPatch before accepting. Verify existing accepted files in place instead of replacing them.

**Equivalent Git Bash workstation commands**, with `BUILD_VM` replaced and no existing destination files:

```bash
set -euo pipefail
cd /d/OCNE19-Lab
test ! -e ISO/oracle-gridhome-19.32.zip
test ! -e ISO/oracle-dbhome-19.32.zip
scp grid@BUILD_VM:/build/rac-gold/grid-output/oracle-gridhome-19.32.zip ISO/
scp oracle@BUILD_VM:/build/rac-gold/db-output/oracle-dbhome-19.32.zip ISO/
sha256sum ISO/oracle-gridhome-19.32.zip ISO/oracle-dbhome-19.32.zip
python scripts/Inspect-RAC-Gold.py
```

On a Linux workstation, change only the checkout path and use the installed Python 3 executable if named `python3`.

## 9. Stage on both workers and reference the manifest

Use the guarded [worker staging procedure](../docs/RAC-PROVISIONING-HANDOFF.md): PowerShell/Bash transfer alternatives, mount checks, ownership, SELinux labeling, and hashes. Helpers contain lab-specific hostname/filesystem guards; adapt them only to observed identities on a new build. A directory's existence does not prove the intended filesystem is mounted.

**Each worker (ocne-w1, then ocne-w2) / Bash:** read-only acceptance after staging.

```bash
findmnt -M /scratch -o SOURCE,UUID,TARGET,FSTYPE
ls -ldZ /scratch/software/stage/19c/19.32-gold
ls -lZ /scratch/software/stage/19c/19.32-gold/oracle-gridhome-19.32.zip
ls -lZ /scratch/software/stage/19c/19.32-gold/oracle-dbhome-19.32.zip
cd /scratch/software/stage/19c/19.32-gold
sha256sum oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
df -h /scratch
```

Expected: correct mounted filesystem, hashes matching accepted workstation files, container-readable archives, and correct SELinux access. Historical staging used **54321:54321**, mode **0755**, and **container_file_t**. Execute permission is not an inherent ZIP requirement; that mode records this lab's helper. Preserve SELinux and diagnose mounts/labels/permissions if access fails.

Use the [configParams fragment](README.md#the-manifest-mapping) within the appropriate full manifest for a new deployment. Do not apply the fragment alone, or use a fresh-create manifest to reconcile an existing resource with immutable fields. This documentation update does not apply cluster resources.

## 10. Verify after provisioning

The [deployment guide](../docs/RAC-DEPLOYMENT.md) covers full provisioning and acceptance. These checks illustrate the distinction between patched software and a working database.

**ocne-cp / labadmin:**

```bash
kubectl get pods -n rac -o wide
kubectl exec -n rac racnode1-0 -- su - grid -c '/u01/app/19c/grid/OPatch/opatch lspatches'
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/OPatch/opatch lspatches'
kubectl exec -n rac racnode2-0 -- su - grid -c '/u01/app/19c/grid/OPatch/opatch lspatches'
kubectl exec -n rac racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/OPatch/opatch lspatches'
```

**Inside a RAC pod / oracle, SQL*Plus connected `/ as sysdba` to CDB root:**

```sql
SELECT inst_id, instance_name, version_full, status FROM gv$instance ORDER BY inst_id;
SELECT con_id, patch_id, action, status, description
FROM cdb_registry_sqlpatch
ORDER BY con_id, action_time;
SELECT inst_id, name, open_mode FROM gv$pdbs ORDER BY inst_id, name;
```

Expected: both instances OPEN at 19.32, LABPDB READ WRITE, and the latest required RU/OJVM SQL actions `APPLY` / `SUCCESS` in each relevant container. Earlier patch history can remain. For incomplete SQL patch state, inspect DBCA/datapatch logs and follow the patch README; `opatch lspatches` alone cannot establish SQL success. The overview links historical acceptance; these commands were not rerun for this update.

## 11. Troubleshooting and acceptance checklist

| Symptom / check | Expected | Corrective action |
|---|---|---|
| Preinstall RPM unavailable | OL9 package resolves | Check `dnf repolist`; correct repositories |
| Grid prerequisites fail | Grid groups/limits/filesystem access satisfy installer | Check `id grid`, new login's `ulimit`, directory ownership |
| Original 19.3 installer rejects OL9 | Applicable patched-installer path on eligible OS/kernel | Consult 19c release notes/RU README; do not ignore all checks |
| Invalid `-applyRU` path | Correct extracted bundle/component | Inspect extraction tree and README; do not pass ZIP filename |
| OPatch too old/wrong home | Selected version in both absolute home paths | Upgrade separately and verify each utility |
| RU missing in inventory | Intended component IDs/versions | Read patch logs and resolve failures before packaging |
| OJVM missing | Approved additional patch combination | Follow matching README/conflict checks; RU alone does not establish OJVM coverage |
| Inventory permission errors | Owner can access home/shared inventory | Check ownership and inventory pointer; avoid broad recursive ownership changes |
| CRC/root-layout/path failure | Intact ZIP, safe relative members, root installer | Recreate from verified home; do not flatten/drop files afterward |
| Hash mismatch | Same artifact on source, Windows, both workers | Identify partial/stale transfer and recopy the intended file |
| Container cannot read ZIP | Correct mount/access/SELinux labels | Check `findmnt`, `ls -lZ`, image identities, guarded staging steps |
| Binary patch present, SQL incomplete | Required SQL patch applied successfully | Inspect DBCA/datapatch logs; use patch-specific post-install steps |
| GI restart failure after deployment | Instances/services recover | Read [known image recovery issues](../docs/RAC-DEPLOYMENT.md); home ZIPs alone do not fix duplicate-CRS-start logic |

Before accepting new archives, retain build OS/kernel/architecture, account IDs/groups, source checksums, exact patch READMEs, actual installer commands/choices/status, inventories, archive command, CRC/layout results, final checksums, worker verification, and later RAC/SQL acceptance. Keep raw logs/private response files outside Git.

**Recorded for the supplied files:** archive and worker acceptance passed; later RAC/SQL acceptance passed. **Not claimed:** a newly executed clean rebuild, exact recovery of unrecorded original commands/choices, or support certification of every environment combination.
