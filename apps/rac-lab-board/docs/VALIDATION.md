# Actual validation and remaining acceptance

**Final local acceptance: 12 October 2026, 23:30:48-23:31:14 UTC.** All temporary app processes were stopped afterward. No application deployment, database schema/user creation, image staging, RAC fault injection or GitHub push was performed.

Read the [full captured output](TEST-OUTPUT.md), [preview](diagrams/application-preview.png) and [future failover matrix](FAILOVER.md). The suite uses real Node/Python/Java processes, with explicitly temporary memory stores; the separate driver test connects only to a reserved, non-listening loopback port.

## Results table

| Check / description | Command from app root | Expected result | Actual result |
|---|---|---|---|
| Java source and locked jars | `python scripts/prepare.py` | Hashes match; javac 21 compiles | PASS; all five jars verified, Java compiled |
| 15 HTTP contract methods covering both languages | `python tests/test_contract.py` | Create/read, tracing, idempotency, concurrency, errors and isolation pass | PASS: 15 tests |
| Five Oracle transaction logic tests with a fake Python driver | `python tests/test_oracle_transaction.py` | Bound SQL, commit, duplicate rollback, conflict, no replay on lost commit reply | PASS: 5 tests; not an Oracle SQL execution test |
| Actual drivers without a database | `python tests/test_driver_failure.py` | Python and JDBC/Hikari start; live=200, ready=503, write=503 with unknown outcome | PASS: 1 test with two service subtests; no RAC connection |
| Frontend/gateway JavaScript syntax | `node --check` for the three JS modules | No parse errors | PASS |
| Browser UI, lost-response retry, reload and escaping | `node tests/browser.cjs` while local demo runs | One note after response loss/retry; request UUID retained; markup rendered as text | PASS; no page errors |
| Desktop/mobile layout | Same browser test | 1440px desktop preview and no horizontal overflow at 390px | PASS; desktop and mobile screenshots saved |
| Future failover workload tool, local tasks | `python scripts/load_probe.py --kind tasks --seconds 2 --interval 0.4 --allow-writes --out <new-file>` | Every created request found exactly once | PASS: 5 attempts, 5 created, 5 verified, 0 failed, 0 missing/unknown; memory only |
| Future failover workload tool, local notes | Same command with `--kind notes` | Same contract for Java | PASS: 5 attempts, 5 created, 5 verified, 0 failed, 0 missing/unknown; memory only |
| Kubernetes 1.29.14 strict schema | `kubeconform -strict -summary -kubernetes-version 1.29.14 kubernetes/00-namespace.yaml kubernetes/10-config.yaml kubernetes/20-workloads.yaml` | All 14 resources valid, none skipped | PASS: 14 valid, 0 invalid, 0 errors, 0 skipped |
| Asset references, links and syntax | `python tests/check_assets.py` | Local links exist; selectors/ports/Secret refs agree; no unintended RAC/PV/Secret manifests | PASS: 42 local links plus syntax and cross-reference checks |
| Docker builds / container runtime | Future `python scripts/build_images.py ...` | Four linux/amd64 images build and pass runtime checks | NOT RUN: Docker Linux engine was stopped; left stopped |
| Oracle users/tables, actual Thin-driver writes and pool reconnection | Future deployment walkthrough | Both backends write LABPDB and recover via each listener | NOT RUN; requires future schema creation/deployment |
| Kubernetes admission/scheduling/probes/RAC failover | Future deployment and failover workbook | Eight app pods, SQL readiness, measured recovery with all IDs accounted for | NOT RUN |

The 21 unittest methods comprise 15 HTTP, five transaction and one real-driver failure test; browser/probe/schema checks are additional. Passing local tests does not establish performance, persistence, SQL correctness on Oracle, native-encryption compatibility, RAC failover, container security behavior or server-side Kubernetes admission. Container base images are tagged, not digest-locked, and were not vulnerability-scanned.

## Issues found and fixed during development

| Issue | What exposed it | Fix / verification |
|---|---|---|
| Same-origin browser POST rejected by gateway | HTTP contract test returned 403 on a valid frontend-origin request | Validate browser Origin at frontend, then proxy internally without misrepresenting that origin; gateway retains its own direct-client guard. Foreign origin=403 and correct origin=201 now pass |
| Header-case assumption in test | Node emitted lowercase x-frontend-pod | Compare HTTP header names case-insensitively; no application change needed |
| JSON parsing inconsistency in Java | Review and strict-invalid-JSON cases | Gson strict reader plus explicit trailing-token check; malformed-JSON exception maps to 400 instead of a database 503. Both services reject the invalid cases |
| Potentially misleading RAC instance metadata | Initial code inspection showed Python could borrow a second pooled session for metadata | Pin one Oracle session for metadata and SQL throughout each Python request; Java uses one connection per operation. Real instance attribution still needs Oracle acceptance |
| Windows shell typography corruption | Visual inspection showed question marks in place of arrows/bullets | Use HTML entities and JavaScript Unicode escapes; regenerated/reviewed desktop and mobile screenshots |
| Mermaid punctuation parsed as statement separator | Sequence diagram render failed | Replaced prose semicolons with commas; both diagram sources render |
| Slow localhost probe measurements | Initial Python probe measured about 2 seconds per local call | Default probe endpoint changed to explicit 127.0.0.1; repeat local probes completed in roughly 0-32ms. This isolates address-fallback overhead; it is not a RAC performance result |
| Minimal non-root image account resolution | Dockerfile review | Added named UID/GID 10001 account for OS-user lookup by drivers/JVM. Container build/runtime verification remains pending |
| Need useful DB diagnostics without exposing data | Source review | Log service, status, pod, request trace and error type/Oracle code; do not log passwords, request text or SQL bind values |

Formatting tools were installed under private/ only; the system interpreter's global packages and existing OCI CLI were not modified. Source was formatted for readability and the final acceptance suite rerun afterward.

## Environment and evidence

Windows: Node 24.19.0, Python 3.10.8, portable Temurin JDK 21.0.12.1+1. Backend dependencies are pinned in their respective lock files. Mermaid diagrams use the existing local diagram tooling. Kubeconform v0.8.0 was downloaded to private/app-tools, verified against its release checksum file and used without contacting the Kubernetes API.

Raw local output is in the ignored lab logs directory; the sanitized transcript above includes commands, test names, statuses and probe JSONL. Browser screenshot is a memory-mode demonstration. No new DB credentials were generated; make_secrets.py and both SQL scripts remain unexecuted. No background demo listener is intentionally left running.

## Re-run locally

```powershell
Set-Location D:\OCNE19-Lab\apps\rac-lab-board
python tests/run_local.py
python tests/check_assets.py
```

The acceptance runner requires the prepared Java/Python tools and the optional existing Puppeteer/Edge setup; see [local development](LOCAL-DEVELOPMENT.md). It reserves ports 8080-8083, 18080-18083 and driver-test ports 18182/18183. Do not run another demo on those ports at the same time. Use `python3` in Bash where appropriate.

## Final static checks

```text
PASS: 42 local documentation links, Python syntax, 14 manifest resources and service/secret/port/security references
PASS: PowerShell script and 14 documented PowerShell blocks
PASS: 28 documented Bash blocks parse; no commands executed
PASS: 31 existing lab Markdown files, 298 local links, fence/code preservation, heading IDs, project paths, UTF-8, and all generated HTML copies
PASS: git diff --check
```

Both Mermaid sources rendered to SVG. The application preview and architecture were visually inspected. Git ignore checks confirmed Java jars/classes, the private JDK and Python environment are excluded. The planned application-secret directory did not exist at final inspection. Windows reported no listening sockets on the temporary application/test ports after cleanup.
