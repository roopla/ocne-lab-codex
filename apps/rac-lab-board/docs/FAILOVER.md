# Application and RAC failover exercises

**Future runbook. No application pods are deployed and no cluster faults were injected for this project.** Local test results are in [VALIDATION.md](VALIDATION.md). The database-only tests in the older lab manual do not prove this new application's failover behavior.

## 1. Learning objectives and boundaries

Observe separately: browser/tunnel availability, frontend and gateway routing, Python/Java replica replacement, SQL readiness, Oracle connection recovery, and committed data persistence. Expect short request failures while endpoints and connection pools recover. Measure them; do not call failover seamless because a pod is Ready.

Start with app-only faults. Restore a healthy baseline after each scenario. Database instance/service maintenance requires a maintenance window, verified surviving instance/service, current backups and the existing recovery procedure. Do not delete the RacDatabase CR, StatefulSets, PVCs, ASM disks or storage exports. Do not disable SELinux/firewall rules or kill Oracle background processes manually.

The supplied RAC image has a documented GI restoration/duplicate-start defect. **RAC pod deletion, container crash, worker reboot and full-cluster power loss are deferred**, even though the new application is designed to reconnect. The app cannot repair a database image's startup procedure. No commands to force those deferred faults are provided here.

## 2. Establish a baseline and evidence folder

Complete [deployment acceptance](DEPLOYMENT.md) first. On ocne-cp (Bash):

```bash
set -euo pipefail
run=$(date -u +%Y%m%dT%H%M%SZ)
mkdir -p "$HOME/rac-app-evidence/$run"
kubectl config current-context | tee "$HOME/rac-app-evidence/$run/context.txt"
kubectl -n rac-app get deployments,pods,services,pdb -o wide | tee "$HOME/rac-app-evidence/$run/baseline.txt"
kubectl -n rac-app get pods -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,NODE:.spec.nodeName,RESTARTS:.status.containerStatuses[*].restartCount | tee "$HOME/rac-app-evidence/$run/pod-identities.txt"
kubectl -n rac get pods -o wide | tee "$HOME/rac-app-evidence/$run/rac-baseline.txt"
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
```

Keep the SSH frontend tunnel running in another workstation terminal. Open the UI and confirm Oracle mode for both backends. Create a baseline task/note and retain their IDs. Test the same ID twice to establish deduplication before introducing a fault.

## 3. Run a measured HTTP workload

The probe writes small append-only records and checks each exact ID afterward. It never uses kubectl or injects faults. `--allow-writes` is required. Output paths are exclusive-create, so each scenario needs a new filename. Run **one probe per language concurrently** in two workstation terminals while injecting just one selected fault in a third terminal.

PowerShell from the app root, change the scenario suffix each time:

```powershell
python scripts/load_probe.py --kind tasks --seconds 180 --interval 1 --allow-writes --out D:\OCNE19-Lab\logs\app-F01-tasks.jsonl
python scripts/load_probe.py --kind notes --seconds 180 --interval 1 --allow-writes --out D:\OCNE19-Lab\logs\app-F01-notes.jsonl
```

These two lines are alternatives for **two terminals**, not a claim they run concurrently when pasted into one terminal. Bash equivalent, in separate terminals:

```bash
python3 scripts/load_probe.py --kind tasks --seconds 180 --interval 1 --allow-writes --out ../../logs/app-F01-tasks.jsonl
python3 scripts/load_probe.py --kind notes --seconds 180 --interval 1 --allow-writes --out ../../logs/app-F01-notes.jsonl
```

Run F01 with **no fault** first. If it fails, troubleshoot before proceeding. The probe keeps one unresolved request at a time per language and retries that same UUID; this avoids accumulating ambiguous writes. It records timestamp, status, latency, pod, gateway, RAC instance and deduplication. A request can overrun the nominal duration by its timeout. Final verification adds time and looks up **all acknowledged IDs plus the last unresolved ID**, even when more than 100 entries were created.

Expected final summary fields are `missingOrUnknown: 0` and one verified row per ID. `failedAttempts` may be nonzero during a fault. The same UUID returning once with 201 and later with 200/deduplicated=true is expected recovery, not a duplicate. `unresolvedAtWriteEnd` lists writes whose acknowledgement was missing at the time writing stopped; a subsequent successful exact-ID verification can establish their committed result. Exit 2 means verification was incomplete/failed; it is not proof of lost data. Restore service and inspect/retry those IDs before concluding.

A shortened **illustrative** record, not an actual cluster result:

```json
{"phase":"write","id":"same-uuid-on-retry","status":200,"elapsedMs":24,"meta":{"mode":"oracle","pod":"board-tasks-example","instance":"RACCDB2","pdb":"LABPDB"},"deduplicated":true}
```

## 4. Scenario table

Commands below assume Bash on ocne-cp unless stated otherwise. The helper `replace_one` is defined in section 5. Each row is an independent experiment; use a fresh probe output filename and restore the baseline before moving on.

| ID | Scenario / purpose | Command syntax or section | Expected result / evidence | Actual app-cluster result |
|---|---|---|---|---|
| F01 | Healthy baseline | Two probes, no fault | Both backends Oracle mode; all acknowledged IDs verified; establish normal latency | NOT RUN |
| F02 | Replace one frontend pod | `replace_one board-frontend` | New UID; other frontend serves; tunnel remains connected to Service; backend data unchanged | NOT RUN |
| F03 | Replace one Node gateway | `replace_one board-gateway` | Other gateway serves; trace shows new gateway; brief in-flight 503 possible | NOT RUN |
| F04 | Replace one Python pod | `replace_one board-tasks` | Python recovery; Java continues; all task IDs persist in RAC | NOT RUN |
| F05 | Replace one Java pod | `replace_one board-notes` | Java recovery; Python continues; all note IDs persist | NOT RUN |
| F06 | Restart one gateway container | Section 6 | Same pod UID, restart count increases; separate from pod replacement | NOT RUN |
| F07 | Rolling update/restart | `kubectl -n rac-app rollout restart deployment/board-gateway` | One replica available during rollout, new pod UIDs; verify workload | NOT RUN |
| F08 | Entire Python tier unavailable | Scale board-tasks to 0 then back to 2; section 7 | Tasks fail, notes continue, UI reports partial outage; stored task data returns | NOT RUN |
| F09 | Remove service from RAC instance1 | Section 8 | Subsequent new connections use RACCDB2; old sessions may fail or persist depending on stop behavior | NOT RUN |
| F10 | Stop RAC instance1 with service dependency handled | Section 9 | Both languages reconnect to RACCDB2; uncertain writes retried; no missing acknowledged IDs | NOT RUN |
| F11 | Mirror instance2 test | Section 9 explicit node2 commands | RACCDB1 serves both languages; proves both directions instead of one favored pool | NOT RUN |
| F12 | Lose workstation SSH tunnel | Stop only tunnel terminal, then reopen section 10 | Browser/probe network failure while app pods/DB stay healthy; same-ID retry after reconnect | NOT RUN |
| F13 | Cordon one worker | Section 11 | Existing app/RAC pods remain; proves scheduling control, not worker failover | NOT RUN |
| F14 | Bad Java image update and rollback | Section 12 | One old Java replica stays available; bad new image fails visibly; rollback restores two | NOT RUN |
| F15 | Duplicate request/retry after lost reply | API example and browser Retry same request | One committed row for same UUID/text; 200 deduplicated on retry | Local tests PASS; RAC test NOT RUN |
| F16 | Conflicting UUID payload | Reuse UUID with changed text | HTTP 409, original text unchanged | Local tests PASS; RAC test NOT RUN |
| F17 | Read-only liveness while DB unavailable | Observe probes during approved DB outage, without causing an extra fault | /livez remains reachable; backend /readyz fails; no false DB health claim | Actual drivers tested against closed localhost port; RAC outage NOT RUN |
| F18 | Worker power failure | Deferred; no fault command | Requires image startup fix, capacity plan, independent tunnel path and host-local RAC recovery acceptance | DEFERRED |
| F19 | RAC pod/container replacement | Deferred; see existing recovery evidence | Application can only recover after Oracle itself has recovered | DEFERRED |
| F20 | Both instances/storage/control-plane unavailable | Separate recovery exercise, no fault command | No survivor SQL possible; app must report unavailable, preserve IDs and recover after dependency restoration | DEFERRED |

## 5. Replace one application pod safely

Define this helper in the ocne-cp Bash terminal. It accepts only the four app Deployment names and requires two available replicas. It never targets namespace rac.

```bash
replace_one() {
  local app="$1" pod ready
  case "$app" in board-frontend|board-gateway|board-tasks|board-notes) ;; *) echo 'Unknown app'; return 1;; esac
  ready=$(kubectl -n rac-app get deployment "$app" -o jsonpath='{.status.availableReplicas}')
  [ "$ready" = 2 ] || { echo 'Require two available replicas before this exercise'; return 1; }
  pod=$(kubectl -n rac-app get pods -l "app.kubernetes.io/name=$app" --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}')
  [ -n "$pod" ] || { echo 'No eligible app pod'; return 1; }
  kubectl -n rac-app get pod "$pod" -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,NODE:.spec.nodeName
  date -u
  kubectl -n rac-app delete pod "$pod" --wait=true --timeout=90s
  kubectl -n rac-app rollout status "deployment/$app" --timeout=180s
  kubectl -n rac-app get pods -l "app.kubernetes.io/name=$app" -o wide
}
# Execute just the selected scenario while the two probes are running:
replace_one board-frontend
```

Use the other three allowed names for F03-F05. Normal deletion honors termination handling; no force deletion or zero grace period. Watch until two new/current pods are Ready and available. `rollout status` by itself can return before replacement state has fully refreshed, so verify the final pod count/UIDs and deployment availability. Compare probe failures, route metadata and exact-ID results. Repeat sequentially, never simultaneously across tiers.

## 6. Restart a single Node gateway container

First require two available gateway replicas as in section 5. This sends SIGTERM only to PID 1 inside one **app** pod, using Node already present in its image:

```bash
pod=$(kubectl -n rac-app get pods -l app.kubernetes.io/name=board-gateway -o jsonpath='{.items[0].metadata.name}')
test -n "$pod"
kubectl -n rac-app get pod "$pod" -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,RESTARTS:.status.containerStatuses[*].restartCount
kubectl -n rac-app exec "$pod" -- node -e 'process.kill(1,"SIGTERM")'
kubectl -n rac-app get pod "$pod" -w
```

The exec connection may close as its container stops; inspect the actual result. Stop the watch with Ctrl+C after Ready returns. The pod UID should remain unchanged and its container restart count increase. `kubectl -n rac-app logs "$pod" --previous` shows the terminated container's logs. If a different UID appears, a pod replacement also occurred; record that instead of claiming a pure container restart.

## 7. Stop the Python tier, keep Java serving

```bash
kubectl -n rac-app scale deployment/board-tasks --replicas=0
kubectl -n rac-app get pods -l app.kubernetes.io/name=board-tasks -w
# After observing task failures and successful notes, Ctrl+C the watch and restore:
kubectl -n rac-app scale deployment/board-tasks --replicas=2
kubectl -n rac-app rollout status deployment/board-tasks --timeout=180s
```

Scaling to zero deliberately changes desired state; Kubernetes will not recreate tasks until you scale back. The PDB does not prevent this Deployment scaling operation. Oracle rows should persist because the pods own no database files. Memory-mode replicas would fail this persistence expectation, which is why deployment acceptance must verify Oracle mode.

## 8. Service-only RAC maintenance on instance1

Require both instances/service healthy, no other active fault, agreed maintenance and backup/recovery readiness. Keep both HTTP probes running long enough to observe before, during and after. In this existing lab, stop only the working application service on instance1:

```bash
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB1'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
# Restore after recording the survivor observation:
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start service -db RACCDB -service labpdb_app -instance RACCDB1'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
```

Service stop/draining options influence existing connections; consult the installed `srvctl stop service -help` before selecting different semantics. This application does not use FAN to evacuate pools. Existing sessions may remain usable until recycled or may fail; inspect actual traces. A service-only stop is not equivalent to instance death. Database-instance maintenance below is the clearer survivor test.

## 9. Controlled RAC instance stop/start

Prior database-only testing hit CRS-2974 when stopping an instance before its dependent service. Handle the service first. Use the observed names and the Oracle home shown here; these commands do not recreate RAC.

**Instance1 scenario**, with instance2 verified online first:

```bash
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB1'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop instance -db RACCDB -instance RACCDB1 -stopoption IMMEDIATE'
kubectl -n rac exec racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB'
# Observe both probes returning RACCDB2; retain failures and deduplication events.
# Restore this instance before proceeding to any other scenario:
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start instance -db RACCDB -instance RACCDB1'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
```

Automatic service policy may already restart the service. **Only if status shows it absent on instance1**, run the instance1 `srvctl start service` command from section 8. A redundant start returning already-running is not evidence the recovery failed. Verify database/PDB/service and both backend readiness paths before continuing.

**Separate instance2 scenario**, after full baseline restoration:

```bash
kubectl -n rac exec racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop service -db RACCDB -service labpdb_app -instance RACCDB2'
kubectl -n rac exec racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl stop instance -db RACCDB -instance RACCDB2 -stopoption IMMEDIATE'
kubectl -n rac exec racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB'
# Observe both probes returning RACCDB1, then restore:
kubectl -n rac exec racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start instance -db RACCDB -instance RACCDB2'
kubectl -n rac exec racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB -service labpdb_app'
# Only if the service remains absent on instance2:
# kubectl -n rac exec racnode2-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl start service -db RACCDB -service labpdb_app -instance RACCDB2'
```

Do not run both stop sequences together. Stop/start behavior does not prove crash recovery or an actual restore. Capture both language streams: Python and JDBC pools can recover differently. Any acknowledged record missing after full recovery is a failed acceptance requiring investigation.

## 10. Client tunnel outage

Stop only the `ssh -N -L ...` terminal with Ctrl+C. Keep the cluster/probe terminals running. The UI will become unreachable even though the app and database can remain healthy. Restart the identical tunnel, then retry any unresolved browser request using its saved ID. Verify pod UIDs/restart counts are unchanged. This scenario teaches that an access-path failure is not a RAC failure.

## 11. Cordon and uncordon

```bash
kubectl cordon ocne-w1.lab.test
kubectl get nodes
kubectl -n rac-app get pods -o wide
# Existing pods should remain; do not drain or power off the worker.
kubectl uncordon ocne-w1.lab.test
kubectl get nodes
```

Cordon changes scheduling for new pods; it does not evict current ones. Do not describe this as worker-loss acceptance. If you intentionally combine cordon with a later app-pod replacement, record that as a separate scenario and check survivor capacity first. Never drain the host-local RAC worker casually.

## 12. Bad app image rollout and rollback

Only after the Java Deployment is healthy at two replicas:

```bash
kubectl -n rac-app rollout history deployment/board-notes
kubectl -n rac-app set image deployment/board-notes notes=localhost/rac-board-notes:missing-test
kubectl -n rac-app get pods -l app.kubernetes.io/name=board-notes -w
# Record ErrImageNeverPull and continued service from the old replica; stop the watch.
kubectl -n rac-app rollout undo deployment/board-notes
kubectl -n rac-app rollout status deployment/board-notes --timeout=180s
kubectl -n rac-app get deployment board-notes -o jsonpath='{.spec.template.spec.containers[0].image}'
```

Verify the restored image is the intended known-good tag/digest and two pods are Ready. The manifest's maxSurge=0/maxUnavailable=1 preserves one old replica while the bad replacement fails. This tests deployment recovery; it says nothing about schema rollback. No destructive schema migration exists in this app.

## 13. Finish every exercise

Stop fault injection and restore desired replicas, images, database service/instances and node schedulability. Wait for both backend `/readyz` responses and all eight app pods. Run exact-ID verification and [02-verify.sql](../database/02-verify.sql), recording total/unique counts. Capture:

```bash
kubectl -n rac-app get deployments,pods,services,pdb -o wide | tee "$HOME/rac-app-evidence/$run/final.txt"
kubectl -n rac-app get events --sort-by=.lastTimestamp | tee "$HOME/rac-app-evidence/$run/events.txt"
kubectl -n rac-app logs -l app.kubernetes.io/name=board-tasks --prefix --tail=200 > "$HOME/rac-app-evidence/$run/tasks.txt"
kubectl -n rac-app logs -l app.kubernetes.io/name=board-notes --prefix --tail=200 > "$HOME/rac-app-evidence/$run/notes.txt"
kubectl -n rac-app logs -l app.kubernetes.io/name=board-gateway --prefix --tail=200 > "$HOME/rac-app-evidence/$run/gateway.txt"
```

Copy that specific evidence directory back under `D:\OCNE19-Lab\logs`, sanitize it, and update the scenario's actual result. Include fault time, recovery time, errors, pod/instance changes, attempts, acknowledgements and verified IDs. Do not manufacture an output for an unexecuted scenario. Passing this lab exercise is not proof of HA across the shared VirtualBox host, host disks or single control plane.
