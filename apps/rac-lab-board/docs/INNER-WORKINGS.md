# Application internal workings and hands-on verification

This chapter is also included in the [complete manual](MANUAL.md). Commands marked Bash on ocne-cp use its existing kubectl context. Workstation Python commands run from the app root; use python3 in Bash. Read-only inspections are distinguished from tests that write records or replace app pods.

## 10. Follow a request through every layer

### 10a. Main URL and the SSH path

**Main application: [http://localhost:8080](http://localhost:8080)**. In this deployment a hidden SSH tunnel already runs. After a workstation reboot or closed SSH session, reopen it from a dedicated PowerShell or Bash workstation terminal:

```text
ssh -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -N -L 127.0.0.1:8080:192.168.77.12:30080 ocne-cp
```

Success is normally silent; leave the terminal open. This means:

1. Browser connects to 127.0.0.1:8080 on Windows.
2. SSH encrypts the connection to the existing ocne-cp SSH endpoint.
3. From inside the guest network, ocne-cp connects to worker1 at192.168.77.12:30080.
4. Kubernetes NodePort routes to a Ready frontend pod, possibly on either worker.

-N runs no remote command; -L forwards the local port. ExitOnForwardFailure catches bind errors, and ServerAliveInterval detects broken SSH connectivity. The tunnel targets a Service via a worker address, not a specific frontend pod. App-pod replacement therefore does not require retargeting it. If worker1 itself is unavailable, use 192.168.77.13 after verifying worker2 and stopping the previous tunnel. Do not bind two tunnels to the same localhost port.

If port 8080 is already used, inspect it before stopping anything. PowerShell:

```powershell
Get-NetTCPConnection -State Listen -LocalPort 8080 | Select-Object LocalAddress,OwningProcess
$status = Invoke-RestMethod http://127.0.0.1:8080/api/status
$status | ConvertTo-Json -Depth 8
if (-not $status.services.tasks.healthy -or -not $status.services.notes.healthy) { throw 'A backend is unhealthy' }
if ($status.services.tasks.mode -ne 'oracle' -or $status.services.notes.mode -ne 'oracle') { throw 'Not in Oracle mode' }
```

Bash workstation:

```bash
ss -ltnp 'sport = :8080'
curl --fail-with-body -sS http://127.0.0.1:8080/api/status | python3 -m json.tool
```

A closed workstation tunnel does not stop the cluster app. Reopen it before redeploying anything. The hidden tunnel PID is recorded in private/rac-app-tunnel.json; verify the actual process before stopping it, because PIDs can be reused.

### 10b. What the browser should show

Open localhost:8080. The health card should say **All services reachable**, the banner **ORACLE MODE**, and both panels Ready. Add a task and a note, then refresh: both remain because Oracle stores them. The panel footers identify the gateway/backend pod and RACCDB1 or RACCDB2. Pool reuse means an instance can appear repeatedly; 50/50 routing is not promised.

![Actual Oracle-mode browser capture](diagrams/application-live.png)

Live mobile-size capture from the same acceptance:

<img src="diagrams/application-live-mobile.png" alt="Live app at a 390-pixel mobile viewport" width="390">

/api/status is JSON health, not a second UI. It can return HTTP 200 while a backend is unhealthy: inspect both healthy fields, both mode=oracle values and PDB=LABPDB. Actual response captured at 11:34:40 UTC13 October:

```json
{
  "gateway": "board-gateway-654f76bb55-qdvmb",
  "services": {
    "tasks": {
      "healthy": true,
      "ok": true,
      "mode": "oracle",
      "pod": "board-tasks-6cb95b78dd-l42vz",
      "instance": "RACCDB2",
      "pdb": "LABPDB",
      "databaseService": "labpdb_app",
      "service": "python-tasks"
    },
    "notes": {
      "healthy": true,
      "databaseService": "labpdb_app",
      "pdb": "LABPDB",
      "service": "java-notes",
      "mode": "oracle",
      "pod": "board-notes-558f6cb9fd-wqlq9",
      "instance": "RACCDB1"
    }
  },
  "checkedAt": "2026-10-13T11:34:40.092Z"
}
```

![Rendered actual health response](diagrams/health-response.png)

Use localhost for the browser. UUID creation relies on its secure-context API available on localhost; raw worker-IP HTTP is not the documented browser entry point. The worker NodePort URLs are useful for command-line diagnostics from ocne-cp.

### 10c. Routing table

| Browser route | Frontend forwards to | Gateway forwards to | Oracle operation |
|---|---|---|---|
| GET / | Static local files | None | None |
| GET /api/status | board-gateway:8081/api/status | Both backend /readyz endpoints | Connection/PDB/table checks |
| POST /api/tasks | board-gateway:8081/api/tasks | board-tasks:8082/tasks | Insert/commit LAB_TASKS.BOARD_TASKS |
| POST /api/notes | board-gateway:8081/api/notes | board-notes:8083/notes | Insert/commit LAB_NOTES.BOARD_NOTES |
| GET /api/tasks or /api/notes | Corresponding /api route | /tasks or /notes | Latest100 records |
| GET /api/tasks/UUID or /api/notes/UUID | Exact-ID route | Exact-ID route | That UUID, including records older than100 |

Kubernetes DNS resolves short Service names within rac-app. Service ClusterIPs remain stable while a pod is replaced; EndpointSlices change to the new pod IP. No component needs a hard-coded peer pod address.

Bash on ocne-cp:

```bash
kubectl -n rac-app get services -o wide
kubectl -n rac-app get endpointslices -o wide
kubectl -n rac-app get pods -o wide
```

Actual EndpointSlices after the replacement tests:

```text
NAME                   ADDRESSTYPE   PORTS   ENDPOINTS                 AGE
board-frontend-s8pzp   IPv4          8080    10.244.2.12,10.244.1.17   22m
board-gateway-7kpgh    IPv4          8081    10.244.1.14,10.244.2.16   22m
board-notes-5wgwm      IPv4          8083    10.244.1.13,10.244.2.18   22m
board-tasks-rcd96      IPv4          8082    10.244.1.15,10.244.2.17   22m

```

### 10d. Test internal connectivity without an extra diagnostic image

The frontend contains Node, so use its fetch implementation. This read-only check runs on ocne-cp:

```bash
kubectl -n rac-app exec deployment/board-frontend -- node -e 'Promise.all(["http://board-gateway:8081/readyz","http://board-tasks:8082/readyz","http://board-notes:8083/readyz"].map(async u=>{const r=await fetch(u);console.log(u,r.status,await r.text());})).catch(e=>{console.error(e.message);process.exitCode=1;})'
```

Actual output:

```text
http://board-gateway:8081/readyz 200 {"ok":true,"pod":"board-gateway-654f76bb55-qdvmb"}
http://board-tasks:8082/readyz 200 {"ok": true, "mode": "oracle", "pod": "board-tasks-6cb95b78dd-l42vz", "instance": "RACCDB2", "pdb": "LABPDB", "databaseService": "labpdb_app", "service": "python-tasks"}
http://board-notes:8083/readyz 200 {"pod":"board-notes-558f6cb9fd-ccvk6","instance":"RACCDB2","databaseService":"labpdb_app","pdb":"LABPDB","service":"java-notes","mode":"oracle"}

```

This checks Service DNS/routing and real backend SQL readiness. A Service selects one endpoint per connection; inspect individual pod logs/events when diagnosing just one replica.

### 10e. What each Kubernetes object does

| Object or setting | Purpose here |
|---|---|
| Deployment | Maintains two replicas; creates a replacement when a pod disappears |
| Service | Stable address selecting current Ready pods |
| NodePort | Maps worker port 30080 to frontend Service port 8080 |
| EndpointSlice | Current pod addresses behind each Service |
| ConfigMap | Oracle mode, expected PDB, two-listener connect descriptor |
| Secret | Per-backend username/password; browser never receives these |
| Backend readiness probe | Checks Oracle connection, PDB and required table |
| Liveness probe | Checks the process, not Oracle availability |
| PDB | PodDisruptionBudget, minAvailable=1; different meaning from Oracle pluggable database LABPDB |
| nodeSelector/spreading | Limits placement to labelled workers and prefers balanced replicas |
| imagePullPolicy Never | Requires exact staged tags in both workers' CRI-O storage |

There is no app PV/PVC; durable records live in Oracle. Each container's small /tmp is disposable. PDBs govern voluntary eviction, not direct kubectl delete pod or host failure. Rolling updates use maxSurge=0 / maxUnavailable=1 to avoid extra pod reservations in this small lab.

The recorded post-test kubectl transcript:

![Rendered actual cluster acceptance transcript](diagrams/cluster-acceptance.png)

This is a rendering of real captured text, not an invented terminal screen. Full selectable output is in [DEPLOYMENT-RESULTS.md](DEPLOYMENT-RESULTS.md).

### 10f. How database connections and retries work

The ConfigMap's DESCRIPTION contains both racnode1-0-lsnr.rac.svc.cluster.local:31522 and racnode2-0-lsnr.rac.svc.cluster.local:31523, requesting labpdb_app and checking LABPDB. It enables address load balancing/connect-time failover with bounded connect timeouts. The existing SCAN Service selected node1, so the app does not use it as its sole connection endpoint.

Python and Java maintain small connection pools. A request may reuse a session rather than reconnect. Each reports the instance/PDB from the connection used for its SQL. Both languages observed both RAC instances during real tests; this is not an injected instance-outage test.

![Write and retry sequence](diagrams/write-retry.svg)

1. Browser creates a lowercase UUID and saves UUID/text in localStorage before POST.
2. API validates JSON, request size, UUID and UTF-8 text length.
3. Parameter-bound SQL inserts the row and commits. HTTP 201 acknowledges a new row.
4. A timeout or missing reply leaves the outcome unknown; it does not prove rollback.
5. Browser retains the payload and offers **Retry same request**, including after reload.
6. The UUID primary key prevents another row. Identical text returns 200/deduplicated=true; changed text returns 409 and preserves the original.

The live browser test deliberately hid a completed response after a real commit, then reloaded and retried; exactly one note remained. This is application idempotency for these append-only records, not Oracle Application Continuity, Transaction Guard, FAN/FCF or arbitrary transaction replay. Tasks and notes are independent transactions, with no cross-service atomicity.

## 11. Hands-on writes and application pod recovery

### 11a. Manual write/retry test

This writes one real task. PowerShell, with the tunnel running:

```powershell
$id = [guid]::NewGuid().ToString()
$payload = @{id=$id;text='Manual task: verify Oracle persistence'} | ConvertTo-Json -Compress
Invoke-RestMethod http://127.0.0.1:8080/api/tasks -Method Post -ContentType application/json -Body $payload | ConvertTo-Json -Depth 8
Invoke-RestMethod http://127.0.0.1:8080/api/tasks -Method Post -ContentType application/json -Body $payload | ConvertTo-Json -Depth 8
Invoke-RestMethod "http://127.0.0.1:8080/api/tasks/$id" | ConvertTo-Json -Depth 8
```

Bash equivalent:

```bash
id=$(python3 -c 'import uuid; print(uuid.uuid4())')
payload=$(python3 -c 'import json,sys; print(json.dumps({"id":sys.argv[1],"text":"Manual task: verify Oracle persistence"}))' "$id")
curl --fail-with-body -sS http://127.0.0.1:8080/api/tasks -H 'Content-Type: application/json' -d "$payload"
curl --fail-with-body -sS http://127.0.0.1:8080/api/tasks -H 'Content-Type: application/json' -d "$payload"
curl --fail-with-body -sS "http://127.0.0.1:8080/api/tasks/$id"
```

Expected: first deduplicated=false, second=true, same UUID/text, exact-ID GET one item; meta.mode=oracle and meta.pdb=LABPDB. Repeat with /api/notes and a fresh UUID to exercise Java. Reusing a UUID with different text returns 409.

For the recorded concurrent acceptance, workstation app root:

```powershell
python scripts/verify_live.py --allow-writes
if ($LASTEXITCODE -ne 0) { throw 'Live acceptance failed' }
python scripts/provision_access.py verify
```

Bash uses python3 for both commands. Actual: first POST 201 per language, four concurrent retries all 200/deduplicated, conflicting text 409, exact-ID row count 1. SQL checkpoint after initial acceptance/probes:

```text
KIND   ROWS_TOTAL  UNIQUE_IDS
tasks         165         165
notes         164         164
```

Both accounts were OPEN with CREATE SESSION only; labpdb_app active on both instances. Counts will increase with your tests. The UI deliberately shows only 100 recent records; use exact-ID GET for older accepted rows.

### 11b. Start workloads, then replace one pod

Begin with eight Ready app pods and both APIs healthy. Use **two workstation terminals**, one command per terminal, from the app root:

```powershell
python scripts/load_probe.py --kind tasks --seconds 120 --interval 1 --allow-writes --out ../../logs/manual-frontend-tasks-01.jsonl
```

```powershell
python scripts/load_probe.py --kind notes --seconds 120 --interval 1 --allow-writes --out ../../logs/manual-frontend-notes-01.jsonl
```

Bash uses python3 with the same relative paths. These create real test rows. Use new filenames each time; the probe refuses to overwrite earlier evidence. It retains one unresolved UUID and verifies each exact ID afterward; it does not inject a fault.

In a third terminal, **Bash on ocne-cp**:

```bash
set -euo pipefail
kubectl -n rac-app get pods -l app.kubernetes.io/name=board-frontend -o wide
pod=$(kubectl -n rac-app get pods -l app.kubernetes.io/name=board-frontend -o jsonpath='{.items[0].metadata.name}')
test -n "$pod"
kubectl -n rac-app get pod "$pod" -o custom-columns=NAME:.metadata.name,UID:.metadata.uid
kubectl -n rac-app delete pod "$pod" --wait=true --timeout=120s
kubectl -n rac-app rollout status deployment/board-frontend --timeout=120s
kubectl -n rac-app get pods -l app.kubernetes.io/name=board-frontend -o wide
```

Expected: one pod disappears, a new name/UID appears, two Ready replicas return and Oracle rows remain. The Service/tunnel keeps its stable address. A request in flight can still fail: preserve its UUID and retry identical text if the outcome is unknown.

Actual frontend output:

```text
pod "board-frontend-6d45679b8c-phfmw" deleted
Waiting for deployment "board-frontend" rollout to finish: 1 of 2 updated replicas are available...
deployment "board-frontend" successfully rolled out
```

New UID a832821f-8db2-4e7f-9e96-0631a6c983c0; delete+rollout3.39 seconds. Each backend created/verified38 records in that20-second sample with zero failures/missing IDs. This is sampled behavior, not a zero-interruption guarantee.

Repeat independently for gateway, tasks and notes only after healthy recovery, using their exact Deployment/label names and new probe filenames. The explicitly opt-in automated equivalent is:

```powershell
python scripts/exercise_app_pods.py --allow-pod-replacement
```

Bash: `python3 scripts/exercise_app_pods.py --allow-pod-replacement`. It replaces one app pod per tier sequentially, runs both probes, records new UIDs, and verifies RAC pod identities/restarts stayed unchanged.

### 11c. Actual results and limits

| Replaced tier | Tasks created/verified | Notes created/verified | Failed attempts / missing IDs | Delete plus rollout |
|---|---|---|---|---|
| Frontend |38/38|38/38|0/0|3.39s|
| Node gateway |38/38|38/38|0/0|3.05s|
| Python tasks |38/38|38/38|0/0|4.69s|
| Java notes |38/38|38/38|0/0|4.33s|

All ended with eight Ready app pods, zero container restarts and unchanged RAC pod UIDs/restarts. Times measure delete plus rollout completion, not outage duration. [Full actual output](DEPLOYMENT-RESULTS.md) includes commands, IDs and probe summaries.

RAC instance/service outages remain separate future exercises in [FAILOVER.md](FAILOVER.md). RAC pod/container replacement and worker power failure remain deferred due the supplied RAC image's startup defects. App-pod recovery does not prove Oracle-container restart safety. Backup restoration and sustained production performance were not tested.
