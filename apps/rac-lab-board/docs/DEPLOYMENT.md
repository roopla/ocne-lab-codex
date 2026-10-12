# Future deployment walkthrough - NOT executed

This chapter changes the live lab when you run it. Development stopped before these steps, as requested. It is a manual procedure, not an auto-run installer. Finish the preflight, schemas and image checks before creating app pods. Use the existing lab; do not rerun VM creation, OS cloning, RAC provisioning or disk formatting.

## 1. Read-only preflight

From Windows PowerShell:

```powershell
Set-Location D:\OCNE19-Lab
ssh ocne-cp
```

The following commands run in **Bash on ocne-cp**, using its existing authorized kubectl context:

```bash
set -euo pipefail
kubectl config current-context
kubectl get nodes -o wide
kubectl get nodes -l raccluster=raccluster01 -o wide
kubectl -n rac get pods -o wide
kubectl -n rac get services racnode1-0-lsnr racnode2-0-lsnr
kubectl get services -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,NODEPORT:.spec.ports[*].nodePort
kubectl describe node ocne-w1.lab.test
kubectl describe node ocne-w2.lab.test
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
```

Expected: both workers Ready, worker label on both, both RAC instances running, application service running on both, and listener Services exposing 31522 and 31523. Port 30080 must be unused, or already owned by this exact app on a subsequent run. If another project uses it, choose a free NodePort and consistently update the frontend manifest and SSH commands. Do not delete conflicting resources.

Confirm one replica of each service's additional 325m CPU / 512 MiB memory fits **each** worker's current requests. Inspect actual host/container use and disk space too. Requests are scheduling reservations, not spare physical RAM. Reassess admission after every material lab change. The existing single control plane and undersized OP/CP are lab limitations. Keep workers at 22 GiB unless separately changed by the user.

Check that `rac-app`, the four board Deployments, and LAB_TASKS/LAB_NOTES do not belong to another project. If a partial earlier run exists, inspect it and continue the missing steps. Never use delete/recreate as a naming-conflict remedy.

## 2. Prepare local secrets without printing them

On Windows, from the app root:

```powershell
Set-Location D:\OCNE19-Lab\apps\rac-lab-board
python scripts/make_secrets.py
if ($LASTEXITCODE -ne 0) { throw 'Secret preparation failed' }
```

Equivalent Bash from the app root:

```bash
python3 scripts/make_secrets.py
```

This creates four files in the project's ignored `private/rac-app-secrets`: tasks/notes username and password files. Usernames are LAB_TASKS and LAB_NOTES; passwords are different 32-character random lowercase hexadecimal strings. There are no newline bytes in these files. The helper restricts the directory ACL on Windows or uses mode 0700/0600 on POSIX. It refuses to overwrite an existing directory. It was **not run** during development.

Do not put passwords into YAML, environment-example files, shell history or source control. Reuse these exact passwords at the Oracle prompts and when creating Kubernetes Secrets. Password rotation later requires a coordinated database change, Secret update and controlled app rollout; changing the Secret alone does not change an Oracle password or existing process environment.

## 3. Create the two application schemas once

Inspect the SQL first: [01-create-schemas.sql](../database/01-create-schemas.sql). It targets LABPDB, requires AL32UTF8 and an existing online USERS tablespace, rejects pre-existing app users, grants only CREATE SESSION, and caps each user's quota at 100 MiB. It does not create a tablespace or format/attach storage. An administrator creates the tables and indexes in the two schemas; runtime services do not migrate schema.

Windows PowerShell, app root:

```powershell
ssh ocne-cp 'mkdir -p ~/rac-app/database ~/rac-app/kubernetes'
scp database/01-create-schemas.sql database/02-verify.sql ocne-cp:rac-app/database/
scp kubernetes/00-namespace.yaml kubernetes/10-config.yaml kubernetes/20-workloads.yaml kubernetes/kustomization.yaml ocne-cp:rac-app/kubernetes/
```

The same `ssh` and `scp` commands work from Bash in the app root. For a different environment, adjust this known lab's SSH alias, PDB/service/listener addresses, worker selector, usernames and tablespace **together**, based on observed state. The configuration here does not dynamically rewrite an existing cluster.

On ocne-cp:

```bash
kubectl cp "$HOME/rac-app/database/01-create-schemas.sql" rac/racnode1-0:/tmp/rac-board-create-schemas.sql
kubectl exec -it -n rac racnode1-0 -- su - oracle -c 'ORACLE_SID=RACCDB1 /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -L / as sysdba @/tmp/rac-board-create-schemas.sql'
```

At each hidden ACCEPT prompt, paste the corresponding protected file's password, not the file path. Do not enable SQL echo/spooling. On Windows you can copy one value into the clipboard without printing it:

```powershell
Get-Content -Raw D:\OCNE19-Lab\private\rac-app-secrets\tasks-password.txt | Set-Clipboard
# Paste only into the LAB_TASKS hidden SQL prompt.
Get-Content -Raw D:\OCNE19-Lab\private\rac-app-secrets\notes-password.txt | Set-Clipboard
# Paste only into the LAB_NOTES hidden SQL prompt, then clear the clipboard.
Set-Clipboard -Value ''
```

On a Linux graphical workstation, use your protected password manager/file viewer, or `xclip -selection clipboard -i ../../private/rac-app-secrets/tasks-password.txt` from the app root if xclip is installed; repeat for notes, then `printf '' | xclip -selection clipboard`. Password entry is intentionally interactive. Do not paste a password into a shell command. The scripts accept exactly the generated hexadecimal format, avoiding SQL quoting ambiguity.

Expected final SQL rows: `LAB_NOTES BOARD_NOTES` and `LAB_TASKS BOARD_TASKS`. Oracle DDL auto-commits; failure halfway through can leave some objects created. Inspect `dba_users`, `dba_tables`, indexes and grants, and execute only missing DDL. Do not blindly rerun the create-users script or drop existing application records.

Verify on ocne-cp:

```bash
kubectl cp "$HOME/rac-app/database/02-verify.sql" rac/racnode1-0:/tmp/rac-board-verify.sql
kubectl exec -i -n rac racnode1-0 -- su - oracle -c 'ORACLE_SID=RACCDB1 /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -L -s / as sysdba @/tmp/rac-board-verify.sql'
```

Expected: LABPDB, two tables, zero initial records, OPEN user accounts, CREATE SESSION grants and labpdb_app active on both instances. Application writes are verified after deployment, not by inserting dummy administrator-owned data now.

## 4. Build and stage the four container images

Follow [local build instructions](LOCAL-DEVELOPMENT.md). After a successful build/export on Windows:

```powershell
Get-FileHash D:\OCNE19-Lab\private\rac-app-images-1.0.0.tar -Algorithm SHA256
scp D:\OCNE19-Lab\private\rac-app-images-1.0.0.tar ocne-w1:rac-app-images-1.0.0.tar
scp D:\OCNE19-Lab\private\rac-app-images-1.0.0.tar ocne-w2:rac-app-images-1.0.0.tar
ssh ocne-w1
```

Bash workstation equivalent, app root:

```bash
sha256sum ../../private/rac-app-images-1.0.0.tar
scp ../../private/rac-app-images-1.0.0.tar ocne-w1:rac-app-images-1.0.0.tar
scp ../../private/rac-app-images-1.0.0.tar ocne-w2:rac-app-images-1.0.0.tar
ssh ocne-w1
```

On **each worker separately**, first inspect the tool/runtime/storage state:

```bash
command -v podman
command -v crictl
df -h "$HOME" /var/lib/containers/storage
sha256sum "$HOME/rac-app-images-1.0.0.tar"
sudo podman info --format '{{.Store.GraphRoot}}'
sudo crictl info
```

Compare the archive hash with the workstation. Do not import a different archive or invent a new CRI-O storage path. With the existing rootful container-storage tooling available:

```bash
sudo podman load --input "$HOME/rac-app-images-1.0.0.tar"
sudo crictl images | grep rac-board
```

Expected: all four exact `localhost/rac-board-*:1.0.0` tags visible through **crictl on both workers**. A rootless Podman import is not sufficient. If Podman is missing, or CRI-O cannot see those tags, stop and resolve the observed tooling/storage mismatch before applying Deployments. The import commands have not been run as part of this development task. Do not install Docker or alter CRI-O just to bypass the check.

Record image IDs and build/base-image digests with the future deployment evidence. Dockerfile tags can move; rebuilds are not assumed bit-for-bit identical.

## 5. Create the namespace and the two Secrets

On ocne-cp, after reviewing the copied files:

```bash
kubectl apply --dry-run=client -f "$HOME/rac-app/kubernetes/00-namespace.yaml"
kubectl apply -f "$HOME/rac-app/kubernetes/00-namespace.yaml"
mkdir -p "$HOME/private/rac-app-secrets"
chmod 700 "$HOME/private/rac-app-secrets"
```

From PowerShell, transfer the four individual secret files over SSH:

```powershell
scp D:\OCNE19-Lab\private\rac-app-secrets\tasks-username.txt D:\OCNE19-Lab\private\rac-app-secrets\tasks-password.txt D:\OCNE19-Lab\private\rac-app-secrets\notes-username.txt D:\OCNE19-Lab\private\rac-app-secrets\notes-password.txt ocne-cp:private/rac-app-secrets/
```

Bash workstation equivalent from app root:

```bash
scp ../../private/rac-app-secrets/tasks-username.txt ../../private/rac-app-secrets/tasks-password.txt ../../private/rac-app-secrets/notes-username.txt ../../private/rac-app-secrets/notes-password.txt ocne-cp:private/rac-app-secrets/
```

On ocne-cp, passwords remain out of command-line arguments and printed output:

```bash
chmod 600 "$HOME/private/rac-app-secrets/"*.txt
kubectl -n rac-app create secret generic board-tasks-db \
  --from-file=username="$HOME/private/rac-app-secrets/tasks-username.txt" \
  --from-file=password="$HOME/private/rac-app-secrets/tasks-password.txt"
kubectl -n rac-app create secret generic board-notes-db \
  --from-file=username="$HOME/private/rac-app-secrets/notes-username.txt" \
  --from-file=password="$HOME/private/rac-app-secrets/notes-password.txt"
kubectl -n rac-app get secret board-tasks-db board-notes-db
```

Expected: two Opaque Secrets with two data entries each. Do not use `-o yaml` or decode them into a transcript. If already present, inspect ownership and intended credentials; do not delete/recreate automatically. Protect or remove the **specific temporary transferred files** according to your credential handling procedure after verification, retaining the protected master copies needed for recovery. No generic recursive cleanup command is provided.

## 6. Validate and apply only the application

On ocne-cp:

```bash
kubectl apply --dry-run=server -k "$HOME/rac-app/kubernetes"
# Review all names/namespaces/images; this next command actually deploys the app.
kubectl apply -k "$HOME/rac-app/kubernetes"
for name in board-frontend board-gateway board-tasks board-notes; do
  kubectl -n rac-app rollout status "deployment/$name" --timeout=180s
done
kubectl -n rac-app get deployments,pods,services,pdb -o wide
kubectl -n rac-app get endpointslices -l kubernetes.io/service-name=board-tasks
kubectl -n rac-app get endpointslices -l kubernetes.io/service-name=board-notes
```

Expected: four Deployments with 2/2 available, eight Ready pods, four Services, four PDBs with one allowed disruption under healthy conditions, and two ready backend endpoints per backend. If all replicas of a service landed on one worker, inspect scheduling/resources; the spread preference is not a guarantee. Do not force a worker drain to fix placement in this RAC lab.

If rollout fails, use [troubleshooting below](#9-troubleshooting). Never treat a Ready RAC TCP probe as proof of SQL availability. The new backend probes execute SQL; their failures can reveal an existing database/service/schema issue.

## 7. Access through SSH and verify real Oracle mode

From Windows PowerShell or Bash on the workstation, keep this session running:

```text
ssh -N -L 8080:192.168.77.12:30080 ocne-cp
```

Use http://localhost:8080. The tunnel goes through the existing SSH alias/NAT forwarding and targets the frontend **Service** via a worker NodePort. A normal frontend pod replacement should not bind the tunnel to the old pod. `kubectl port-forward deployment/...` can be convenient for diagnostics, but its chosen pod connection can end during a pod-replacement test, confounding the result.

For maintenance of worker1, use worker2 as the tunnel destination: `ssh -N -L 8080:192.168.77.13:30080 ocne-cp` after stopping the old tunnel. A tunnel whose fixed destination is powered off will fail independently of app health.

PowerShell verification:

```powershell
Invoke-RestMethod http://localhost:8080/api/status | ConvertTo-Json -Depth 8
$task = @{id=[guid]::NewGuid().ToString();text='First real RAC task'} | ConvertTo-Json -Compress
Invoke-RestMethod http://localhost:8080/api/tasks -Method Post -ContentType application/json -Body $task | ConvertTo-Json -Depth 8
Invoke-RestMethod http://localhost:8080/api/tasks -Method Post -ContentType application/json -Body $task | ConvertTo-Json -Depth 8
$note = @{id=[guid]::NewGuid().ToString();text='Java also writes to LABPDB'} | ConvertTo-Json -Compress
Invoke-RestMethod http://localhost:8080/api/notes -Method Post -ContentType application/json -Body $note | ConvertTo-Json -Depth 8
```

Bash equivalent:

```bash
curl --fail-with-body -sS http://localhost:8080/api/status | python3 -m json.tool
task=$(python3 -c 'import json,uuid; print(json.dumps({"id":str(uuid.uuid4()),"text":"First real RAC task"}))')
curl --fail-with-body -sS http://localhost:8080/api/tasks -H 'Content-Type: application/json' -d "$task"
curl --fail-with-body -sS http://localhost:8080/api/tasks -H 'Content-Type: application/json' -d "$task"
note=$(python3 -c 'import json,uuid; print(json.dumps({"id":str(uuid.uuid4()),"text":"Java also writes to LABPDB"}))')
curl --fail-with-body -sS http://localhost:8080/api/notes -H 'Content-Type: application/json' -d "$note"
```

Expected: `mode=oracle`, `pdb=LABPDB`, real RACCDB1/RACCDB2 names, one created task followed by `deduplicated=true`, and one created note. A connection pool can remain on the same instance for multiple calls; a 50/50 split is not promised. Verify each language can recover through either listener during the controlled scenarios. Repeat the SQL verification from section 3; counts and unique IDs should agree.

## 8. Acceptance gate before fault injection

Capture the context, nodes, resource reservations, pod UIDs/placement, image IDs, both SQL paths, app status and test record IDs. Ensure current database backup/recovery readiness and a maintenance window. Run the no-fault HTTP probe first. Only then follow [FAILOVER.md](FAILOVER.md), starting with app pods. Do not combine multiple faults; restore and verify after each one.

## 9. Troubleshooting

| Symptom | Check | Corrective action |
|---|---|---|
| ErrImageNeverPull | `kubectl -n rac-app describe pod <name>`; `sudo crictl images` on its worker | Load exact image/tag into rootful CRI-O-visible storage on both workers |
| CreateContainerConfigError | Pod events, Secret/ConfigMap names (without printing values) | Create the missing app-only prerequisite; verify key names |
| Pending | `kubectl -n rac-app describe pod <name>`; worker labels and requests | Fix label substitution or capacity after inspection; do not evict RAC or increase worker RAM silently |
| Python/Java live but not ready | Backend logs and `/api/status`; listener Services, PDB, schema | Correct the actual DB service, user/password, account state or missing tables; no blind schema reset |
| ORA-01017 / ORA-28000 | Restricted operator investigation; application log deliberately suppresses raw driver details | Match Secret to the intended Oracle user; investigate account locking instead of repeated bad logins |
| ORA-00942 | Run the read-only schema verification SQL | Finish missing schema objects using the correct owner; do not grant DBA |
| TCP works but database service unavailable | `srvctl status service`; SQL to LABPDB | Restore registered application service/instance; TCP alone is insufficient |
| Browser shows LOCAL DEMO | ConfigMap and Deployment env | Stop acceptance: Kubernetes must use Oracle mode; do not claim data persistence |
| Browser shows 503 while only one backend fails | Status for tasks vs notes, gateway logs | Diagnose that backend independently; the other service should remain usable |
| Unknown write outcome | Saved request ID/body and exact-ID GET | Retry identical payload; never invent a new ID to hide ambiguity |
| OOMKilled or repeated Java restarts | `kubectl describe pod`, previous logs, current resources | Measure workload/heap/native memory and available worker headroom before tuning |
| UI unavailable after frontend pod delete | Whether access used pod-pinned port-forward | Reconnect or use the documented worker NodePort SSH tunnel |

Useful Bash commands on ocne-cp:

```bash
kubectl -n rac-app get pods -o wide
kubectl -n rac-app get events --sort-by=.lastTimestamp
kubectl -n rac-app logs -l app.kubernetes.io/name=board-tasks --prefix --tail=100
kubectl -n rac-app logs -l app.kubernetes.io/name=board-notes --prefix --tail=100
kubectl -n rac-app logs -l app.kubernetes.io/name=board-gateway --prefix --tail=100
```

Use `kubectl logs <pod> --previous` for a container restart. Keep raw logs in the project's ignored `logs/`; sanitize evidence before adding it to documentation. No current app deployment, credentials or database changes are implied by these examples.
