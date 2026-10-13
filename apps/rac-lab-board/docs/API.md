# API contract

Public routes go through the frontend on http://localhost:8080. Tasks and notes have the same contract, implemented separately in Python and Java.

| Method / path | Meaning | Success |
|---|---|---|
| GET /api/status | Backend health, mode, pod, RAC instance; inspect `healthy` | 200 even if a backend is unhealthy |
| GET /api/tasks or /api/notes | Latest 100 entries, newest first | 200, `items` plus `meta` |
| GET /api/tasks/{id} or /api/notes/{id} | Exact ID lookup; useful after uncertain commit | 200 with one item; 404 if absent |
| POST /api/tasks or /api/notes | Insert an immutable record | 201 new; 200 for same ID and same text |
| GET /livez, /readyz | Frontend process probes | 200 when frontend HTTP process is available |

Backends expose `/tasks` or `/notes`, without `/api`, plus their own `/livez` and `/readyz`. Gateway exposes the public `/api` routes and process probes. No edit or delete operation is implemented.

## Create or retry

```json
{"id":"a1ba2907-e8b2-4209-af12-16f06e4d8852","text":"Observe a RAC instance failover"}
```

Supply exactly `id` and `text`. ID must be a lowercase UUID. Text must be nonblank and at most 800 UTF-8 bytes. Maximum HTTP body is 4096 bytes; use `Content-Type: application/json`. Requests with extra fields, malformed JSON or invalid values return 400. Reusing an existing ID with different text returns 409; the original row is preserved. Unrecognized routes return 404, unsupported methods 405, wrong content type 415, and an oversized body 413.

Illustrative response shape; see [actual Oracle responses](DEPLOYMENT-RESULTS.md) for captured output:

```json
{
  "item": {
    "id": "a1ba2907-e8b2-4209-af12-16f06e4d8852",
    "text": "Observe a RAC instance failover",
    "createdAt": "2026-10-12T12:00:00.000Z"
  },
  "deduplicated": false,
  "meta": {
    "mode": "oracle",
    "pod": "board-tasks-example",
    "instance": "RACCDB1",
    "pdb": "LABPDB",
    "databaseService": "labpdb_app",
    "service": "python-tasks"
  },
  "gateway": "board-gateway-example",
  "trace": "another-uuid"
}
```

In memory mode `instance` is `DEMO (no RAC)` and `pdb` is `none`. These are explicit simulated values, never evidence of a database connection. Node adds a gateway pod and trace to forwarded API replies; frontend adds the `x-frontend-pod` HTTP header.

On unavailable service/database, expect 503. A write may return:

```json
{"error":"Database unavailable","outcome":"unknown","retrySameId":true}
```

A 503, timeout or lost network reply does not establish rollback. Retry the **identical** ID/text until you receive a definitive result, then verify with GET by ID. Do not turn an unknown outcome into a new request ID. On recovery, the original committed row returns with `deduplicated: true`; otherwise the retry creates it. A 409 requires inspection rather than an automatic changed-payload retry.

## Copy/paste examples against the deployed app or local demo

PowerShell:

```powershell
$body = @{ id = [guid]::NewGuid().ToString(); text = 'Test a safe retry' } | ConvertTo-Json -Compress
Invoke-RestMethod http://localhost:8080/api/tasks -Method Post -ContentType application/json -Body $body
# Exact same body: expect deduplicated=True and the same id.
Invoke-RestMethod http://localhost:8080/api/tasks -Method Post -ContentType application/json -Body $body
Invoke-RestMethod http://localhost:8080/api/status | ConvertTo-Json -Depth 8
```

Bash (requires Python 3 for UUID/JSON):

```bash
body=$(python3 -c 'import json,uuid; print(json.dumps({"id":str(uuid.uuid4()),"text":"Test a safe retry"}))')
curl --fail-with-body -sS http://localhost:8080/api/tasks -H 'Content-Type: application/json' -d "$body"
curl --fail-with-body -sS http://localhost:8080/api/tasks -H 'Content-Type: application/json' -d "$body"
curl --fail-with-body -sS http://localhost:8080/api/status | python3 -m json.tool
```

Use a localhost URL for the browser. UUID generation relies on the browser's secure-context API, available on localhost. A raw HTTP worker-IP URL is not the documented browser access method.
