# RAC provisioning handoff

RAC has **not** been provisioned. The operator's server-side create dry-run accepted [config/rac-database.yaml](../config/rac-database.yaml), and no RacDatabase resource exists. The manifest is for the user to apply after resolving the remaining patch-applicability check below. A successful dry-run validates API/admission rules, not image availability, gold-home contents or a working database.

For a manual rebuild, follow [the prerequisite guide](RAC-PREREQUISITES-GUIDE.md), including its direct Bash command appendix. Actual results are in [the run log](CLONING-RUN-LOG.md) and [readiness inventory](RAC-READINESS.md).

## Manifest source and lab adaptations

[config/rac-database.yaml](../config/rac-database.yaml) follows Oracle Database Operator 2.2.0's [RAC provisioning sample, docs/rac/provisioning/racdb_prov.yaml](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/racdb_prov.yaml), pinned to commit `ff6f9178c1650df30afbf203ebdb633e9b80760a`. The accompanying [provisioning procedure](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/provisioning_oracle_rac_db.md) explains the slim-image and staged-home workflow. The separate `config/samples/database_v4_racdatabase.yaml` in that repository is only a skeleton with a TODO; the detailed provisioning sample is the relevant reference.

The sample provides the two-node structure, Oracle home paths, private-network references, worker selector, ASM disk-group structure and secret references. Our values are local lab adaptations:

| Setting | Oracle sample | This lab and reason |
|---|---|---|
| Resource identity | `racdbprov-sample`, namespace `rac` | `rac19c`, namespace `rac` |
| Container image | `dbocir/oracle/database-rac:19.3.0-slim`, policy `Always` | User's `roopla/oracle-rac:19.3.0-slim`, pinned to the verified digest with `IfNotPresent`; identical image staged in both CRI-O stores |
| Home archives | `grid_home.zip`, `db_home.zip`; stage under `19.28GoldImageSoftware` | `oracle-gridhome-19.32.zip`, `oracle-dbhome-19.32.zip`; `/scratch/software/stage/19c/19.32-gold` |
| ASM devices | `qck-ocne19-asmdisk1` and `qck-ocne19-asmdisk2` partition labels | Verified shared partitions `ocne-rac-asm01` and `ocne-rac-asm02`; retained `DATA`, `EXTERNAL`, `CRSDG` |
| Networks and placement | Two nodes, `macvlan-conf1`/`macvlan-conf2`, `ens1`/`ens2`, `raccluster=raccluster01` | Retained and matched to the installed NADs and worker labels; ONS/listener base target ports explicitly set to 30200/31522 |
| Credentials | `ssh-key-secret`, `db-user-pass`; pkeyutl options commented | Existing `rac-ssh-key` and `rac-db-password`; explicit pkeyutl OAEP/SHA256 options matching the prepared secret |
| TDE | Includes `tdeWalletSecret` | Omitted; TDE was not configured for this lab |
| CPU and memory | No explicit resource block in this sample | Each pod requests/limits 4 CPUs, 16 GiB ordinary memory and 2 GiB HugePages on a 22 GiB/6 CPU worker; adds pod sysctls matching prepared host settings |
| Database settings | `PORCLCDB`, service `soepdb` | `RACCDB`, PDB `LABPDB`, service `labpdb`; SGA 1G, PGA 2G, 500 processes, cpuCount 4 and TOTAL_MEMORY 18432 for this constrained lab |
| Patch application | Base gold-home example has no patch-application fields | Retained the gold-home route; no RU/OPatch/one-off application fields, because supplied homes are already patched |

The added fields were checked against the pinned [RacDatabase API types](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/apis/database/v4/racdatabase_types.go), [admission validation](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/apis/database/v4/racdatabase_webhook.go), and [pod construction code](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/commons/crs/rac/racprovcluster.go). In particular, the operator requires at least 16 GiB ordinary memory; HugePages are additional. These resource choices are lab sizing, not Oracle-validated RAC capacity. Prerequisite-ignore and webhook development-mode flags are not enabled.

Validation already performed: YAML parsing, image/ZIP staging checks, exact Windows/control-plane manifest SHA256 match, and successful server-side create dry-run on 10 October at 21:39 EDT. The resource has **not been applied**. API acceptance does not prove database runtime behavior; the remaining DBCA fix applicability question and post-provisioning checks are documented below and in [artifact acceptance](RAC-ARTIFACT-ACCEPTANCE.md).

## Prepared infrastructure

- Two 22 GiB/6 CPU workers, each with 128GiB scratch and its existing 100 GiB container disk.
- Two shared 50 GiB ASM partitions, identified by persistent labels; unformatted and unused by ASM.
- Two tested private macvlan interconnects, OCNE Multus, worker labels, and mounted host NFS.
- Kernel settings, 2 GiB HugePages per worker, disabled THP, Oracle's SELinux module with Enforcing retained, and Oracle home directories.
- Cert-manager1.17.4, Database Operator 2.2.0, required RBAC and Ready operator certificates.
- Protected database-password and RAC SSH secrets.

Cert-manager1.17.4 is outside community maintenance, chosen for this fixed Kubernetes 1.29 lab. The small worker sizing has not been validated by provisioning RAC. The final acceptance entry in the run log records persistence/network/NFS checks separately.

## 1. Verified image staged on both workers

The supplied `roopla/oracle-rac:19.3.0-slim` was pulled into rootful CRI-O on both workers on 10 October. Both report the same immutable digest, now pinned in the YAML. Image inspection found OL9.8, linux/amd64, expected Oracle IDs, systemd and the controller scripts; all 19 top-level Python scripts parsed. No image entrypoint or installer was executed. See [artifact acceptance](RAC-ARTIFACT-ACCEPTANCE.md) for exact evidence and limits.

Run these commands on **each worker**, substituting the actual image reference:

```bash
RAC_IMAGE='docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d'
# Authenticate interactively first if your registry requires it; never put passwords in arguments.
sudo crictl pull "$RAC_IMAGE"
sudo crictl images
sudo crictl inspecti "$RAC_IMAGE"
```

Use the configured CRI-O endpoint; inspect /etc/crictl.yaml if required. A rootless Podman pull uses a different image store. Do not assume podman images proves CRI-O availability; verify with crictl. Record matching image IDs/digests and inspect the built image's OS, scripts and user/group mapping. `imagePullPolicy: IfNotPresent` uses the local image if available. If later using registry authentication from Kubernetes, create a protected imagePullSecret in rac and set spec.imagePullSecret; do not commit its data.

## 2. Verified gold homes staged on both workers

Expected paths on **both workers**:

```text
/scratch/software/stage/19c/19.32-gold/oracle-gridhome-19.32.zip
/scratch/software/stage/19c/19.32-gold/oracle-dbhome-19.32.zip
```

These exact files are staged on both workers and referenced by configParams.gridSwZipFile/dbSwZipFile. Full source CRC/path checks and all four destination SHA256 comparisons passed. Files are owned by 54321:54321, mode 0755, labeled container_file_t. Each worker retains about 101 GiB free scratch space. Existing base/RU files in the separate 19.32 directory are preserved and unused. The following commands reproduce the transfer on a new build; do not overwrite an existing staged file without first checking its hash.

Windows PowerShell:

```powershell
Get-FileHash .\ISO\oracle-gridhome-19.32.zip -Algorithm SHA256
Get-FileHash .\ISO\oracle-dbhome-19.32.zip -Algorithm SHA256
scp .\ISO\oracle-gridhome-19.32.zip .\ISO\oracle-dbhome-19.32.zip ocne-w1:/scratch/software/stage/19c/19.32-gold/
scp .\ISO\oracle-gridhome-19.32.zip .\ISO\oracle-dbhome-19.32.zip ocne-w2:/scratch/software/stage/19c/19.32-gold/
```

Equivalent Bash from the project root in Git Bash or another workstation with the configured SSH aliases:

```bash
sha256sum ISO/oracle-gridhome-19.32.zip ISO/oracle-dbhome-19.32.zip
scp ISO/oracle-gridhome-19.32.zip ISO/oracle-dbhome-19.32.zip ocne-w1:/scratch/software/stage/19c/19.32-gold/
scp ISO/oracle-gridhome-19.32.zip ISO/oracle-dbhome-19.32.zip ocne-w2:/scratch/software/stage/19c/19.32-gold/
```

On each worker, verify the mounted scratch UUID against this build's inventory, then:

```bash
findmnt -M /scratch -o SOURCE,UUID,FSTYPE,TARGET
cd /scratch/software/stage/19c/19.32-gold
sha256sum oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
unzip -tq oracle-gridhome-19.32.zip
unzip -tq oracle-dbhome-19.32.zip
unzip -Z1 oracle-gridhome-19.32.zip | head
unzip -Z1 oracle-dbhome-19.32.zip | head
sudo chmod 0755 oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
sudo chown 54321:54321 oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
sudo restorecon -RF /scratch/software/stage/19c/19.32-gold
ls -lZ oracle-gridhome-19.32.zip oracle-dbhome-19.32.zip
```

The verified hashes, root installers, expanded sizes and archived 19.32 patch inventory are recorded in [artifact acceptance](RAC-ARTIFACT-ACCEPTANCE.md). Archived OPatch is 12.2.0.1.53. **Remaining check:** DBCA fix 34436514 is absent from the archived patch/bug inventories. Confirm with build evidence or Oracle Support whether it is included by another route, superseded or required for 19.32 before provisioning. Do not apply the guide's 19.28 one-off blindly. Archive metadata is not a live OPatch inventory or runtime database test.

The YAML intentionally omits ruPatchLocation, oPatchLocation, oPatchSwZipFile, oneOffLocation and gridOneOffIds. Provisioning must use the already-patched homes, with no deployment-time patch step configured.

## 3. CVU host validation completed

The user supplied cvupack_linux_ol8_x86_64.zip. Its README identifies OL8/OL9/RHEL8/RHEL9 and the July 2026 standalone release; actual version output is 23.26.3.0.0, build 090726x8664. Local CRC checks and both destination SHA256 comparisons passed. Both workers then passed `cluvfy comp containerhost -type k8 -verbose -text -savedir ...` as labadmin with exit code 0 on 10 October. No fixup option was used.

Reproduce on each worker as labadmin:

```bash
CVU_HOME=/scratch/tools/cvu-23.26.3
report="$HOME/cvu-reports/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$report"
"$CVU_HOME/bin/cluvfy" -version
"$CVU_HOME/bin/cluvfy" comp containerhost -type k8 -verbose -text -savedir "$report"
```

This component checks the local host, so run it on each worker. Its help has no -r option: do not add -r19 to this particular command. Other CVU checks that support -r require the correct target release; do not default database checks to26ai. Host validation does not validate the future slim image, gold homes, an ASM disk group or a running RAC database. See [the CVU results](RAC-CVU-RESULTS.md) for versions, hashes and report paths.

## 4. Verify and dry-run without provisioning

On ocne-cp as labadmin:

```bash
kubectl get nodes -L raccluster
kubectl get pods -A
kubectl get daemonset kube-multus-ds -n kube-system
kubectl get network-attachment-definitions -n rac
kubectl get certificates -n oracle-database-operator-system
kubectl get secrets -n rac rac-db-password rac-ssh-key
kubectl get racdatabases -A
kubectl get pv
kubectl get pvc -n rac
kubectl create --dry-run=server -f ~/ocne-rac-prereqs/rac-database.yaml
```

After editing the Windows YAML, copy that exact version to ocne-cp before the dry-run. Inspect the worker resource budgets and both gold files/images as above. Re-run the worker/network/NFS checks if any relevant setting changed. The final YAML requests 4CPUs,16 GiB ordinary memory and2GiB HugePages per pod; it sets SGA1G and PGA2G for this limited lab. Do not set prerequisite-ignore or webhook development-mode flags to make acceptance pass.

Credential recovery is local to ocne-cp: ~/.local/share/ocne-rac-secrets/db-password.txt, protected 0600 under a0700 directory. Retrieve it only in your private interactive session; do not paste it into chat, documentation or Git. Kubernetes secrets already exist and are referenced by name in the YAML.

## 5. User-only provisioning step (not executed by Codex)

Only after the preceding gates pass, the user may run on ocne-cp:

```bash
kubectl apply -f ~/ocne-rac-prereqs/rac-database.yaml
kubectl get racdatabase rac19c -n rac -w
kubectl get pods,pvc,services -n rac -o wide
kubectl get pv
kubectl logs -n oracle-database-operator-system deployment/oracle-database-operator-controller-manager --tail=100
```

Treat operator logs as potentially sensitive; inspect locally rather than publishing them unreviewed. Follow the [pinned RAC provisioning procedure](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/provisioning_oracle_rac_db.md) for GI/ASM/database acceptance. Verify that there is one RAC node on each worker, CRS/ASM and database services are healthy, the intended patch inventories are present, SQL connections work and pod/worker recovery behaves correctly. None of these database tests has run in this prerequisite-only handoff.

The current YAML uses cluster services and has no Windows database port-forward configuration. Establish and test the intended client access route after provisioning; Windows hosts entries alone do not route into the VirtualBox NAT subnet. Do not delete the RacDatabase or its storage as a troubleshooting shortcut.
