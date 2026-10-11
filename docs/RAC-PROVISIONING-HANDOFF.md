# RAC provisioning handoff

RAC has **not** been provisioned. The operator's server-side create dry-run accepted [config/rac-database.yaml](../config/rac-database.yaml), and no RacDatabase resource exists. The manifest is for the user to apply after completing the artifact gates below. A successful dry-run validates API/admission rules, not image availability, gold-home contents or a working database.

For a manual rebuild, follow [the prerequisite guide](RAC-PREREQUISITES-GUIDE.md), including its direct Bash command appendix. Actual results are in [the run log](CLONING-RUN-LOG.md) and [readiness inventory](RAC-READINESS.md).

## Prepared infrastructure

- Two22GiB/6 CPU workers, each with 128GiB scratch and its existing100GiB container disk.
- Two shared50GiB ASM partitions, identified by persistent labels; unformatted and unused by ASM.
- Two tested private macvlan interconnects, OCNE Multus, worker labels, and mounted host NFS.
- Kernel settings,2 GiB HugePages per worker, disabled THP, Oracle's SELinux module with Enforcing retained, and Oracle home directories.
- Cert-manager1.17.4, Database Operator 2.2.0, required RBAC and Ready operator certificates.
- Protected database-password and RAC SSH secrets.

Cert-manager1.17.4 is outside community maintenance, chosen for this fixed Kubernetes 1.29 lab. The small worker sizing has not been validated by provisioning RAC. The final acceptance entry in the run log records persistence/network/NFS checks separately.

## 1. Supply and verify the image

The user is building the slim image and will pre-pull it on both workers. It must be an OL9 image compatible with the 2.2.0 RAC controller, its startup scripts, paths, secret format and the supplied19.32 homes. Replace `example.invalid/ocne/rac-slim:19.32-ol9` in the YAML with the **exact same fully qualified image reference** present on both workers, preferably an immutable digest. The placeholder is deliberately not deployable.

Run these commands on **each worker**, substituting the actual image reference:

```bash
RAC_IMAGE='registry.example.com/your-project/rac-slim:19.32-ol9'
# Authenticate interactively first if your registry requires it; never put passwords in arguments.
sudo crictl pull "$RAC_IMAGE"
sudo crictl images
sudo crictl inspecti "$RAC_IMAGE"
```

Use the configured CRI-O endpoint; inspect /etc/crictl.yaml if required. A rootless Podman pull uses a different image store. Do not assume podman images proves CRI-O availability; verify with crictl. Record matching image IDs/digests and inspect the built image's OS, scripts and user/group mapping. `imagePullPolicy: IfNotPresent` uses the local image if available. If later using registry authentication from Kubernetes, create a protected imagePullSecret in rac and set spec.imagePullSecret; do not commit its data.

## 2. Stage fully patched gold homes

Expected paths on **both workers**:

```text
/scratch/software/stage/19c/19.32-gold/gi-home-19.32-gold.zip
/scratch/software/stage/19c/19.32-gold/db-home-19.32-gold.zip
```

Use those filenames or update configParams.gridSwZipFile/dbSwZipFile consistently. The directories already exist, labeled container_file_t and owned by labadmin for transfer. The user will supply the actual archives; they are not the previously checked base19.3 ZIPs. Existing base/RU files in the separate19.32 directory are preserved and unused by this YAML.

Windows PowerShell:

```powershell
Get-FileHash .\ISO\gi-home-19.32-gold.zip -Algorithm SHA256
Get-FileHash .\ISO\db-home-19.32-gold.zip -Algorithm SHA256
scp .\ISO\gi-home-19.32-gold.zip .\ISO\db-home-19.32-gold.zip ocne-w1:/scratch/software/stage/19c/19.32-gold/
scp .\ISO\gi-home-19.32-gold.zip .\ISO\db-home-19.32-gold.zip ocne-w2:/scratch/software/stage/19c/19.32-gold/
```

Equivalent Bash from the project root in Git Bash or another workstation with the configured SSH aliases:

```bash
sha256sum ISO/gi-home-19.32-gold.zip ISO/db-home-19.32-gold.zip
scp ISO/gi-home-19.32-gold.zip ISO/db-home-19.32-gold.zip ocne-w1:/scratch/software/stage/19c/19.32-gold/
scp ISO/gi-home-19.32-gold.zip ISO/db-home-19.32-gold.zip ocne-w2:/scratch/software/stage/19c/19.32-gold/
```

On each worker, verify the mounted scratch UUID against this build's inventory, then:

```bash
findmnt -M /scratch -o SOURCE,UUID,FSTYPE,TARGET
cd /scratch/software/stage/19c/19.32-gold
sha256sum gi-home-19.32-gold.zip db-home-19.32-gold.zip
unzip -tq gi-home-19.32-gold.zip
unzip -tq db-home-19.32-gold.zip
unzip -Z1 gi-home-19.32-gold.zip | head
unzip -Z1 db-home-19.32-gold.zip | head
sudo chmod 0755 gi-home-19.32-gold.zip db-home-19.32-gold.zip
sudo chown 54321:54321 gi-home-19.32-gold.zip db-home-19.32-gold.zip
sudo restorecon -RF /scratch/software/stage/19c/19.32-gold
ls -lZ gi-home-19.32-gold.zip db-home-19.32-gold.zip
```

Compare hashes to the originals on Windows and to each other. Confirm the archives are valid home images with installer contents at the archive root, no unsafe paths, and the desired19.32 inventory. Preserve sanitized build/OPatch inventory evidence from the source homes. Resolve release-specific recommended fix applicability during gold-image creation, including the DBCA memory fix discussed in Oracle's guide. Do not infer patch inclusion from the filename or blindly apply19.28 one-offs to19.32.

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
