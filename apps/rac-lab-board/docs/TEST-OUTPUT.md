# Captured local test output

Actual output from the final local acceptance run on 12 October 2026. Workstation-specific interpreter/log paths are normalized. Temporary memory records and dummy closed-loopback connection failures are not RAC results.

```text
Local acceptance UTC 20261012T233048Z
All service data stores are temporary local memory. Driver failure test uses only a closed loopback socket. No RAC or Kubernetes actions.

$ python tests/test_contract.py
test_01_health_and_mode (__main__.Contracts) ... ok
test_02_create_read_trace (__main__.Contracts) ... ok
test_03_lost_response_retry_same_id (__main__.Contracts) ... ok
test_04_conflicting_id (__main__.Contracts) ... ok
test_05_concurrent_retries (__main__.Contracts) ... ok
test_06_invalid_input (__main__.Contracts) ... ok
test_07_utf8_byte_limit (__main__.Contracts) ... ok
test_08_body_limit (__main__.Contracts) ... ok
test_09_methods_routes_and_missing_id (__main__.Contracts) ... ok
test_10_origin_guard (__main__.Contracts) ... ok
test_11_markup_is_data (__main__.Contracts) ... ok
test_12_no_password_in_status (__main__.Contracts) ... ok
test_13_bounded_list (__main__.Contracts) ... ok
test_90_backend_loss_is_isolated (__main__.Contracts) ... ok
test_91_gateway_loss_is_reported (__main__.Contracts) ... ok

----------------------------------------------------------------------
Ran 15 tests in 3.282s

OK

Exit code: 0

$ python tests/test_oracle_transaction.py
test_duplicate_different_text_conflicts (__main__.Transactions) ... ok
test_duplicate_rolls_back_then_reads (__main__.Transactions) ... ok
test_other_integrity_error_not_deduplicated (__main__.Transactions) ... ok
test_success_bound_variables_and_commit (__main__.Transactions) ... ok
test_unknown_commit_is_not_replayed (__main__.Transactions) ... ok

----------------------------------------------------------------------
Ran 5 tests in 0.000s

OK

Exit code: 0

$ python tests/test_driver_failure.py
test_drivers_start_without_database_and_keep_liveness (__main__.DriverFailure) ... ok

----------------------------------------------------------------------
Ran 1 test in 12.920s

OK

Exit code: 0

$ node --check frontend/server.mjs

Exit code: 0

$ node --check frontend/public/app.js

Exit code: 0

$ node --check backend/node-gateway/server.mjs

Exit code: 0

$ node tests/browser.cjs
PASS: desktop UI, demo banner, create task, lost-response retry across reload, one stored note, mobile width, escaped markup, no browser errors

Exit code: 0

$ python scripts/load_probe.py --kind tasks --seconds 2 --interval 0.4 --allow-writes --out logs/rac-app-local-probe-20261012T233048Z-tasks.jsonl
{"time": "2026-10-12T23:31:10.333728+00:00", "run": "c01d7096", "phase": "write", "id": "696dbd23-e0e5-44e6-9c43-99ec37fa4797", "status": 201, "elapsedMs": 0, "meta": {"mode": "memory", "pod": "tasks-local", "instance": "DEMO (no RAC)", "pdb": "none", "service": "python-tasks"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:10.751000+00:00", "run": "c01d7096", "phase": "write", "id": "4bcd9d3b-e947-49f6-aa5d-340533aa830f", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "tasks-local", "instance": "DEMO (no RAC)", "pdb": "none", "service": "python-tasks"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:11.169860+00:00", "run": "c01d7096", "phase": "write", "id": "f4846a05-e364-4c6d-af16-05c6479725b2", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "tasks-local", "instance": "DEMO (no RAC)", "pdb": "none", "service": "python-tasks"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:11.584883+00:00", "run": "c01d7096", "phase": "write", "id": "2a4d34e7-ab05-461a-9852-150840dfe437", "status": 201, "elapsedMs": 0, "meta": {"mode": "memory", "pod": "tasks-local", "instance": "DEMO (no RAC)", "pdb": "none", "service": "python-tasks"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:12.001940+00:00", "run": "c01d7096", "phase": "write", "id": "5a77bde2-473c-40df-aab0-847171133eb9", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "tasks-local", "instance": "DEMO (no RAC)", "pdb": "none", "service": "python-tasks"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:12.418622+00:00", "run": "c01d7096", "phase": "verify", "id": "696dbd23-e0e5-44e6-9c43-99ec37fa4797", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:12.434522+00:00", "run": "c01d7096", "phase": "verify", "id": "4bcd9d3b-e947-49f6-aa5d-340533aa830f", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:12.448325+00:00", "run": "c01d7096", "phase": "verify", "id": "f4846a05-e364-4c6d-af16-05c6479725b2", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:12.465247+00:00", "run": "c01d7096", "phase": "verify", "id": "2a4d34e7-ab05-461a-9852-150840dfe437", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:12.469561+00:00", "run": "c01d7096", "phase": "verify", "id": "5a77bde2-473c-40df-aab0-847171133eb9", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:12.469561+00:00", "run": "c01d7096", "phase": "summary", "attempts": 5, "created": 5, "deduplicated": 0, "failedAttempts": 0, "verified": 5, "missingOrUnknown": 0, "acknowledgedIds": 5, "unresolvedAtWriteEnd": [], "interpretation": "Verification errors need investigation; they are not proof of data loss."}

Exit code: 0

$ python scripts/load_probe.py --kind notes --seconds 2 --interval 0.4 --allow-writes --out logs/rac-app-local-probe-20261012T233048Z-notes.jsonl
{"time": "2026-10-12T23:31:12.532894+00:00", "run": "3ec0d569", "phase": "write", "id": "5df23b3c-6c94-4003-aa37-b85476cd20ec", "status": 201, "elapsedMs": 0, "meta": {"mode": "memory", "pod": "notes-local", "instance": "DEMO (no RAC)", "service": "java-notes", "pdb": "none"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:12.951563+00:00", "run": "3ec0d569", "phase": "write", "id": "9f2586af-0bf0-477a-8c7d-7816217974b1", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "notes-local", "instance": "DEMO (no RAC)", "service": "java-notes", "pdb": "none"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:13.372367+00:00", "run": "3ec0d569", "phase": "write", "id": "68211b41-ff40-4240-aaa9-e0bde375dc22", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "notes-local", "instance": "DEMO (no RAC)", "service": "java-notes", "pdb": "none"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:13.789303+00:00", "run": "3ec0d569", "phase": "write", "id": "94ba7495-dd96-4849-a3fc-ec20232d8224", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "notes-local", "instance": "DEMO (no RAC)", "service": "java-notes", "pdb": "none"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:14.208473+00:00", "run": "3ec0d569", "phase": "write", "id": "f2a92e8a-8cc3-45f2-b998-58d70568dd50", "status": 201, "elapsedMs": 16, "meta": {"mode": "memory", "pod": "notes-local", "instance": "DEMO (no RAC)", "service": "java-notes", "pdb": "none"}, "gateway": "gateway-local", "deduplicated": false}
{"time": "2026-10-12T23:31:14.625098+00:00", "run": "3ec0d569", "phase": "verify", "id": "5df23b3c-6c94-4003-aa37-b85476cd20ec", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:14.629383+00:00", "run": "3ec0d569", "phase": "verify", "id": "9f2586af-0bf0-477a-8c7d-7816217974b1", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:14.644025+00:00", "run": "3ec0d569", "phase": "verify", "id": "68211b41-ff40-4240-aaa9-e0bde375dc22", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:14.660365+00:00", "run": "3ec0d569", "phase": "verify", "id": "94ba7495-dd96-4849-a3fc-ec20232d8224", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:14.676594+00:00", "run": "3ec0d569", "phase": "verify", "id": "f2a92e8a-8cc3-45f2-b998-58d70568dd50", "status": 200, "verified": true, "previouslyAcknowledged": true}
{"time": "2026-10-12T23:31:14.676594+00:00", "run": "3ec0d569", "phase": "summary", "attempts": 5, "created": 5, "deduplicated": 0, "failedAttempts": 0, "verified": 5, "missingOrUnknown": 0, "acknowledgedIds": 5, "unresolvedAtWriteEnd": [], "interpretation": "Verification errors need investigation; they are not proof of data loss."}

Exit code: 0

```

Kubernetes schema validation (separate local check):

```text
Summary: 14 resources found in 3 files - Valid: 14, Invalid: 0, Errors: 0, Skipped: 0
```
