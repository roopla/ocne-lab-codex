# Rebuild kit on E: - preservation and handoff

**Preparation started:** 16 October 2026, America/New_York. **Asset verification passed:** 17 October 2026, 14:14 UTC (10:14 EDT). Source/Git capture and complete-kit checksum sealing are recorded in the external completion receipt described below.

The owner approved `E:\OCNE19-Rebuild-Backup`, declined preservation of database/application data, and explicitly required preserving the golden VM. This task prepares reconstruction assets. It does **not** authorize destroying the current lab. The intended rebuild creates a fresh RACCDB/LABPDB and fresh application schemas through the existing procedures.

## Location and protection

```text
E:\OCNE19-Rebuild-Backup\kit-20261016\
  media\                  Oracle base, RU, OPatch, CVU and patched-home archives
  golden\base\            Original golden base VDI copy
  golden\config-and-snapshots\  Golden configuration and dependent snapshot disk
  images\                 Application archive and per-node platform image exports
  images\pinned-registry\ Original RAC and Database Operator manifests/layers
  packages\               Exact installed RPM downloads and reports
  protected-access\       Private SSH/account inputs (never publish)
  inventory\              VM metadata, hashes, image/package acceptance receipts
  source\                 Source tree, including documented local changes
  repository.bundle       Git history at the captured baseline
```

The backup root has inheritance disabled and grants access to the current Windows account, SYSTEM and Administrators. This is access control, not encryption. Keep the entire kit private: it includes Oracle software, private keys and application passwords. Windows credential XML is tied to its Windows user/machine context; copying it does not make it portable to another workstation. Existing SSH credentials worked during preparation, but decryption on another Windows installation was not tested.

The Git bundle captures committed history. The separate source snapshot captures the working tree, including local documentation changes and new helpers. Its inventory records the commit, dirty state and individual source hashes; do not mistake the bundle alone for the latest working files. No backup media, passwords, keys or VM disks belong in Git.

## What was checked

| Asset / check | Actual result |
|---|---|
| Original local files | 30 files, 34,636,899,667 bytes; each source/copy SHA256 matched and source size/mtime stayed unchanged |
| Golden VM | Powered off before/after copying; configuration text unchanged; base VDI, dependent snapshot VDI, configuration and existing logs copied |
| Pinned RAC image | Original manifest `sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d`; every downloaded config/layer size and digest checked |
| Pinned Database Operator image | Original manifest `sha256:f378d66fd0b47b6089f01caf4ca86f90f3b3593cdca75292ff6491955c451cc0`; every config/layer checked |
| Isolated import | RAC and Operator original config IDs and pinned references recognized; all four application archive image IDs matched; no containers started |
| Exact RPM export | Worker: 1,288 packages; operator: seven packages including its conmon version; cp: one Multus chart RPM; every exported RPM passed the guest's signature check |
| External platform/RPM copies | All three archive hashes matched; 9/10/12 exported image configurations matched their node inventories; all 1,296 RPM copies (1,292 distinct versions) matched guest-verified hashes |
| Data preservation | Deliberately excluded by owner: no current database/application backup or restore performed |
| Full rebuild / golden restore | Not rehearsed; verified file copies are not proof of a complete restore |

Eight exact installed packages were absent from worker repositories: the `6.12.0-203.76.7.3.el9uek` UEK 8 kernel family (kernel, core, modules, modules-core, modules-desktop, modules-extra-netfilter, modules-usb, modules-wireless). This is not the running UEK R7 kernel required by this lab. Retain the observed R7 kernel and documented Oracle eligibility policy; do not change kernels just to remove an inventory difference. The full per-node package coverage report is in `inventory/package-coverage.json`: exactly those same eight inactive kernel packages are absent for each node. The observed UEK R7 version is present in every inventory and its RPMs are preserved. A collection of RPMs is not a dependency-resolution or offline installation rehearsal.

## How preparation worked

These are **local backup helpers**, not Oracle installation procedures. Their paths, date and node guards intentionally match this approved run. Review them before reuse; the first helper refuses to overwrite an existing kit. They do not destroy, install, format or provision resources.

1. **Windows:** inspect the host, golden disk chain, E: capacity and current VM state. Create the restricted backup root. Run [Prepare-Rebuild-Local-Backup.py](../scripts/Prepare-Rebuild-Local-Backup.py) once to copy media, access files, application archives and the powered-off golden chain with hashes.
2. **Windows:** [Preserve-Pinned-Rebuild-Images.py](../scripts/Preserve-Pinned-Rebuild-Images.py) downloads original immutable registry manifests and verifies every blob. Bearer tokens stay in memory. It uses the public Registry V2 API, not a registry password saved to Git.
3. **Guest root, cp/w1/w2:** [Export-Rebuild-Guest-Kit.sh](../scripts/Export-Rebuild-Guest-Kit.sh) exports installed platform images and RPM inventories. It writes only rebuild staging under `/var/tmp/rebuild-kit-20261016` (cp) or `/scratch/rebuild-kit-20261016` (workers).
4. **Guest root, w1/op/cp:** [Preserve-Rebuild-RPMs.sh](../scripts/Preserve-Rebuild-RPMs.sh) matches exact installed NEVRAs against configured repositories, downloads available matches, checks signatures, and copies RPMs from its private cache into `rpms/`. It performs no RPM transaction. It saves all available exact worker packages, the operator's OCNE/conmon additions and the control-plane Multus chart, then compares coverage against all four node inventories.
5. **Windows:** copy exports to E:. [Copy-Rebuild-Guest-Archives.py](../scripts/Copy-Rebuild-Guest-Archives.py) uses bounded binary SSH reads and checks the entire archive hash before accepting it. RPM file copies are separately checked against the guest report.
6. **Guest root, w1:** [Verify-Rebuild-Image-Imports.sh](../scripts/Verify-Rebuild-Image-Imports.sh) imports into `/scratch/rebuild-kit-20261016/verify-store` with a separate runroot and `vfs` driver. It leaves the running CRI-O store untouched. Both pinned references and four app config IDs passed.
7. **Windows:** [Verify-Rebuild-Backup.py](../scripts/Verify-Rebuild-Backup.py) compares archive hashes, archive config IDs against exported inventories, every copied RPM hash, per-node package coverage and the import receipt. After documentation validation, [Seal-Rebuild-Backup.py](../scripts/Seal-Rebuild-Backup.py) captures reviewed source files and Git history, verifies the bundle, rechecks the unchanged powered-off golden configuration, hashes the complete kit, compares hashes with earlier accepted copies, and writes the completion receipt only after those checks pass.

Example invocation for an **already reviewed** guest helper, from PowerShell in `D:\OCNE19-Lab`:

```powershell
.\scripts\Invoke-LabSSH.ps1 -Node ocne-w1 -ScriptPath D:\OCNE19-Lab\scripts\Verify-Rebuild-Image-Imports.sh
```

Expected: two `PINNED_IMPORT_PASS` lines, four `APP_IMPORT_PASS` lines, and a successful helper exit. The helper uses the protected existing root credential and validates Bash syntax before execution. A failure means stop and inspect the sanitized log; do not switch to the live image store.

## Transfer failures and corrections

| Observation | Correction and verification |
|---|---|
| Exporting the RAC image from Podman's store changed its manifest digest | Retained the original registry manifest and blobs instead. Isolated import recognized the exact original pinned reference |
| Isolated DNF API initially could not open its log directory | Created private cache/persist/log directories before loading repositories |
| Repository URL still contained `$ociregion` / `$ocidomain` | Loaded the guest's existing `/etc/yum/vars` and `/etc/dnf/vars` through DNF substitutions; no repository configuration changed |
| DNF retained packages in its private cache despite the destination setting | Explicitly copied each verified package from `localPkg()` into the export directory; reran signature checks and checked external copies separately |
| Large inbound transfers through loopback NAT stalled with SFTP and legacy SCP; a bounded 32 MiB read also timed out | Used the already-existing operator bridged interface as a jump host. A 32 MiB bridged test completed in 1.09 seconds. Preserved pinned host keys; changed no VM NICs, routes or firewall rules |

The temporary Windows SSH profile is `private/rebuild-ssh.conf`. Its hop uses the **observed** operator bridge address `192.168.137.229`, then reaches cp/w1/w2 at their lab addresses. That DHCP address must be re-observed next time. Copy its profile into the protected kit for reference; it is not a portable fixed network requirement. Incomplete large copies are replaced only after complete-file verification. Guest staging remains available and consumes space; it is not the external backup.

## Verification and recovery use

After the final checksum manifest exists, run this from **Windows PowerShell**. It reads the private kit without printing file contents:

```powershell
$kit = 'E:\OCNE19-Rebuild-Backup\kit-20261016'
$entries = Get-Content -Raw -LiteralPath (Join-Path $kit 'inventory\SHA256.json') | ConvertFrom-Json
foreach ($entry in $entries) {
    $file = [IO.Path]::GetFullPath((Join-Path $kit $entry.path))
    if (-not $file.StartsWith($kit + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Invalid manifest path' }
    if ((Get-Item -LiteralPath $file).Length -ne $entry.bytes) { throw "Size mismatch: $($entry.path)" }
    if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entry.sha256) { throw "Hash mismatch: $($entry.path)" }
}
'PASS: all listed backup files match'
```

Expected: the PASS line and no exceptions. A missing/mismatched file is a failed backup check; recopy from its verified source while that source still exists. The manifest excludes itself and the final human-readable completion receipt. Keep the manifest fingerprint from the final BACKUP-RECEIPT.txt outside the kit to detect accidental manifest changes. This check proves file integrity against that manifest, not installability or protection against malicious modification.

For an isolated image import, stage the kit image directories on a Linux test host with Podman. The tested pattern is:

```bash
# Linux root, isolated test target; substitute the staged directory.
KIT=/scratch/rebuild-kit-20261016
podman --root "$KIT/verify-store" --runroot "$KIT/verify-run" --storage-driver vfs \
  pull "dir:$KIT/pinned-registry/rac-slim"
podman --root "$KIT/verify-store" --runroot "$KIT/verify-run" --storage-driver vfs \
  tag d3f449132a8807319fde044350ef03c0602491fd3cbce1f738146164e6b9aa52 \
  docker.io/roopla/oracle-rac:19.3.0-slim
podman --root "$KIT/verify-store" --runroot "$KIT/verify-run" --storage-driver vfs \
  image exists docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
```

Expected: import succeeds and the final command exits 0. The full helper verifies more than this short example. Preparing a new worker's actual CRI-O store remains a separate documented rebuild stage; this test does not deploy RAC.

**Golden source:** leave the original VM and all its original files untouched. The backup `.vbox` retains the original absolute base path `D:/VMs/ol9-golden/ol9-golden.vdi` and a relative snapshot path. It is not a ready-to-double-click imported VM at the backup location. Restoring elsewhere requires an isolated VirtualBox registration/path reconciliation, preserving the complete parent/child chain and avoiding duplicate UUID registration. That restore has not been tested. Do not register the backup beside the original or edit original UUIDs to bypass a conflict.

**Fresh identities and data:** reconstruct from the protected original golden VM using the [cloning workflow](../README-CLONING.md), then follow the exact [rebuild sequence](REBUILD-READINESS.md). Generate fresh clone identities/certificates/host keys. Create the fresh database/application schemas; no existing application records are expected. Preserve 22 GiB workers, 3 GiB SGA, 2 GiB PGA, disabled HugePages, existing network design, four shared ASM disks and candidate-only asm03/04 behavior. Continue to use the documented fresh/live manifest distinction and GI restart precautions.

## Final receipt

**Sealing completed:** 17 October 2026 at 14:23:38 UTC (10:23:38 EDT). The final manifest covers **1,726 files / 44,378,595,286 bytes**, including **346 source files** and a verified complete-history Git bundle. The original golden configuration remained unchanged.

Manifest SHA256: `38c0fa086113d3c778bfde20af53ce6f6d12f4c279cd263f921825153db40b4c`. The bundle baseline is `7299064ae6c9984441226f72e679bc787d84b679`; the separate source snapshot includes the local changes present when sealing completed. This publication adds the completion record after sealing and does not rewrite the protected backup.

Content acceptance passed at 14:14 UTC on 17 October: three platform archives, both pinned registry images, six isolated image imports, and 1,296 RPM copies. Coverage of all four installed package inventories leaves only the eight identified inactive UEK 8 packages. The running R7 package family is preserved.

**Completion gate:** `E:\OCNE19-Rebuild-Backup\kit-20261016\BACKUP-RECEIPT.txt` is written only after source/Git capture, bundle verification and the complete-file hash pass. It contains the exact final count/size, Git baseline, UTC completion time and SHA256 of `inventory/SHA256.json`. If the receipt is absent or the checksum check fails, do not treat sealing as complete. The source snapshot intentionally includes uncommitted local documentation/helper changes in addition to the bundle's committed history. Nothing was pushed during this preparation.

The 17 October 08:34 EDT point-in-time live check found the same four lab VMs running, all three Kubernetes nodes Ready, both RAC pods 1/1 Running and eight app pods 1/1 Running. No new SQL acceptance, failure injection or restore was performed that morning. The golden VM remained excluded from the running list; the sealing helper additionally compares its full machine-readable configuration with the original capture.

No VM/network/disk was deleted, no database data was removed, and no live container store, package installation or cluster configuration was changed. Backup exports/downloads/import tests occupy guest staging space; the kit is not a VM/data backup of the four running clones. D: reported 452.48 GiB free and E: 2,583.17 GiB free at 10:14 EDT, after staging and copies; recheck capacity before any later allocation. No destructive rebuild is authorized by approving this backup folder.

**Remaining limits:** golden restore and full clean rebuild have not been rehearsed; preserved RPMs have not passed a fresh offline dependency-resolution/install test; the platform image archives have passed hash/configuration checks but were not all import-tested; the image's documented GI restart defect remains. These limits are explicit even though the six RAC/Operator/application imports passed.

## References

- [Distribution Registry HTTP API V2](https://distribution.github.io/distribution/spec/api/) - digest-addressed manifests and blobs.
- [Podman save](https://docs.podman.io/en/latest/markdown/podman-save.1.html) and [Podman pull](https://docs.podman.io/en/latest/markdown/podman-pull.1.html) - archive/directory transports.
- [DNF Base API](https://dnf.readthedocs.io/en/latest/api_base.html) - package download operation; this helper never calls `do_transaction()`.
- [Readiness audit](REBUILD-READINESS.md), [consolidated instructions](USER-INSTRUCTIONS.md), [actual run log](RUN-LOG.md).
