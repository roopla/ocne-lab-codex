# Stop, destroy and redeploy RAC Lab Board

This procedure concerns **only the application in rac-app**. The existing Oracle operator, RAC namespace, database instances, service labpdb_app, ASM disks, PVCs, NFS, OCNE nodes and VirtualBox VMs are preserved. App tasks and notes are in LABPDB, not in pod filesystems.

**Execution status:** the removal helper's plan is checked against the live cluster; uninstall and data deletion are documented for your later exercise and have not been executed. Commands marked destructive below are deliberate future actions.

## Choose the result you want

| Choice | Application pods | Kubernetes configuration | Oracle records | Use case |
|---|---|---|---|---|
| Pause | Scaled to zero | Retained | Retained | Stop the app temporarily |
| Uninstall (default) | Removed | Exact four Deployments, Services, PDBs and app ConfigMap removed; namespace and two Secrets retained | Retained | Practice deploy/destroy without losing records |
| Uninstall with Secrets | Removed | Same as above plus two app Secrets removed; namespace retained | Retained | Remove app access objects; protected master credentials remain on workstation |
| Delete app data (separate) | Must already be removed | As chosen above | Both LAB_TASKS/LAB_NOTES schemas and all their records permanently deleted | Intentionally start with empty app data |

The namespace remains so that unrelated resources someone may later add are not accidentally removed. Do not use `kubectl delete -k kubernetes`: the kustomization includes the namespace, so that command can remove everything in it. No image pruning or VM deletion is part of app teardown.

## 1. Inspect and capture before changing anything

From PowerShell:

```powershell
Set-Location D:\OCNE19-Lab\apps\rac-lab-board
ssh ocne-cp
```

From Bash on your workstation, run `ssh ocne-cp`. The following block is **Bash on ocne-cp**:

```bash
set -euo pipefail
kubectl config current-context
kubectl get namespace rac-app --show-labels
kubectl -n rac-app get deployments,pods,services,pdb,configmaps
kubectl -n rac-app get secret board-tasks-db board-notes-db
kubectl -n rac get pods -o wide
```

Check the context and app ownership label `app.kubernetes.io/part-of=rac-lab-board`. Do not print Secret YAML. Save wanted tasks/notes or take an appropriate database export before any optional data deletion. Pausing/uninstalling alone does not erase them.

## 2. Pause and resume (alternative to uninstall)

Bash on ocne-cp:

```bash
kubectl -n rac-app scale deployment board-frontend board-gateway board-tasks board-notes --replicas=0
kubectl -n rac-app wait --for=delete pod -l app.kubernetes.io/part-of=rac-lab-board --timeout=120s
kubectl -n rac-app get deployments
```

Expected: desired replicas zero, no app pods, database still running. PDBs do not prevent an explicit Deployment scale-down. Existing requests may be interrupted; retain the same request UUID when resolving an unknown write outcome.

Resume:

```bash
kubectl -n rac-app scale deployment board-frontend board-gateway board-tasks board-notes --replicas=2
for name in board-frontend board-gateway board-tasks board-notes; do
  kubectl -n rac-app rollout status "deployment/$name" --timeout=180s
done
```

PowerShell equivalent from the workstation for the scale commands:

```powershell
ssh ocne-cp 'kubectl -n rac-app scale deployment board-frontend board-gateway board-tasks board-notes --replicas=0'
# Later, resume:
ssh ocne-cp 'kubectl -n rac-app scale deployment board-frontend board-gateway board-tasks board-notes --replicas=2'
```

Run only the intended action, not both sequentially as a pause test.

## 3. Uninstall the application, preserving records

First copy the reviewed helper from the app root (same commands in PowerShell and Bash):

```text
scp scripts/remove_app.py ocne-cp:rac-app/remove_app.py
ssh ocne-cp 'python3 ~/rac-app/remove_app.py'
```

The default is a read-only **plan**. It checks namespace ownership and all 13 named object labels before any deletion. It reports the current kubectl context. It stops if a resource belongs to someone else, and rechecks object UIDs before deleting.

When you intentionally want to remove the app, run from either workstation shell:

```text
ssh ocne-cp 'python3 ~/rac-app/remove_app.py --execute'
```

Expected output: deletion of the four Deployments, four Services, four PodDisruptionBudgets and rac-board-config. Dependent ReplicaSets/pods are removed by Kubernetes. The namespace, two Secrets and Oracle data remain. A partial failure is inspected before rerunning; absent named resources are skipped.

If you also want the two Kubernetes Secrets removed, use this **instead**, or after the default uninstall:

```text
ssh ocne-cp 'python3 ~/rac-app/remove_app.py --execute --remove-secrets'
```

This does not change Oracle passwords. Keep the matching protected files in D:\OCNE19-Lab\private\rac-app-secrets for redeployment. There is no need to delete those master files or generate new passwords just because pods were removed.

Inspect afterward, Bash on ocne-cp:

```bash
kubectl -n rac-app get deployments,pods,services,pdb,configmaps
kubectl -n rac get pods -o wide
kubectl get nodes
```

Expected: no named board workloads/Services/PDBs/ConfigMap; RAC still running and nodes Ready. Kubernetes may retain the namespace's automatic kube-root-ca.crt ConfigMap and default ServiceAccount. These are not app workloads. Any unrelated resources are preserved.

## 4. Redeploy with the existing records

**Do not rerun make_secrets.py or create-schemas.** Verify the retained schemas and image tags using [deployment sections 3-4](DEPLOYMENT.md). If you removed Secrets, recreate just the two Secrets from the matching protected files:

PowerShell, app root:

```powershell
python scripts/provision_access.py verify
# Only if both app Secrets were removed:
python scripts/provision_access.py create-secrets
```

Bash workstation equivalent:

```bash
python3 scripts/provision_access.py verify
# Only if both app Secrets were removed:
python3 scripts/provision_access.py create-secrets
```

If only one Secret is absent, create only that missing Secret using the per-Secret commands in the deployment guide. The helper deliberately does not overwrite existing ones.

On ocne-cp, after verifying the copied manifests match your intended version:

```bash
kubectl apply --dry-run=server -k "$HOME/rac-app/kubernetes"
kubectl apply -k "$HOME/rac-app/kubernetes"
for name in board-frontend board-gateway board-tasks board-notes; do
  kubectl -n rac-app rollout status "deployment/$name" --timeout=180s
done
kubectl -n rac-app get pods -o wide
```

Reopen the SSH tunnel from [deployment section 7](DEPLOYMENT.md). Existing IDs/text should be readable again. Verify /api/status reports Oracle and LABPDB. GET both collections and use exact-ID GET for older rows beyond the latest 100. Retrying an earlier successful UUID with its identical text returns deduplicated=true and must not create a second row.

## 5. Optional permanent deletion of the application schemas

**This is data loss, not normal uninstall. It was not executed.** Export any records you want to keep. First uninstall all app pods and stop any direct clients using LAB_TASKS or LAB_NOTES. Review [03-drop-app-schemas.sql](../database/03-drop-app-schemas.sql). It targets only LABPDB, checks for active app sessions, unexpected schema objects and foreign keys from other schemas, and requires the exact confirmation DELETE_RAC_BOARD_DATA. It will not remove the database or PDB.

From the workstation app root (same PowerShell/Bash commands):

```text
scp database/03-drop-app-schemas.sql ocne-cp:rac-app/database/03-drop-app-schemas.sql
ssh ocne-cp
```

Bash on ocne-cp:

```bash
kubectl cp "$HOME/rac-app/database/03-drop-app-schemas.sql" rac/racnode1-0:/tmp/rac-board-drop-schemas.sql
kubectl exec -it -n rac racnode1-0 -- su - oracle -c 'ORACLE_SID=RACCDB1 /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -L / as sysdba @/tmp/rac-board-drop-schemas.sql'
```

Read the prompt. Press Enter to refuse, or type the confirmation only if you intend permanent deletion. Expected successful end: both users dropped and no rows for those usernames. Oracle DDL auto-commits; a partial failure is inspected and completed deliberately. Do not change the PDB name to CDB$ROOT or broaden the usernames.

To reinstall after this optional deletion, use the original protected credentials with create-schemas, verify zero initial rows, recreate any missing Secrets and apply the manifests. Reusing the existing protected values avoids an accidental mismatch with retained Kubernetes Secrets. If you intentionally rotate credentials, coordinate database and Kubernetes changes before starting pods.

## 6. Close the workstation tunnel

If you ran ssh -N interactively, Ctrl+C closes just that tunnel. The deployed lab may also have a hidden tunnel started by Codex, with its PID recorded in private/rac-app-tunnel.json. Inspect the process before stopping it:

```powershell
$info = Get-Content D:\OCNE19-Lab\private\rac-app-tunnel.json -Raw | ConvertFrom-Json
Get-CimInstance Win32_Process -Filter "ProcessId = $($info.pid)" | Select-Object ProcessId,Name,CommandLine
# Only after confirming this is the app's exact ssh -N -L process:
Stop-Process -Id $info.pid
```

On a Bash workstation, use `ps -p <recorded-pid> -o pid,args` and then `kill <recorded-pid>` after the same check. Never kill every ssh process. Closing the tunnel does not stop cluster pods. A stale PID file is not proof the original process is still running.

## References

- [Kubernetes Deployment scaling and rollout](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes disruption budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/)
- [Oracle DROP USER](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/DROP-USER.html)
