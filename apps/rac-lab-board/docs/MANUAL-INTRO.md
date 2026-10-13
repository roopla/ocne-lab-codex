# RAC Lab Board: complete illustrated manual

**Deployed and verified on 13 October 2026.** This manual explains the application from prerequisites to browser access, internal request flow, verification, troubleshooting and teardown. It assumes the OCNE cluster and Oracle RAC database already exist. For a new platform, first follow the [OCNE/RAC end-to-end manual](../../../docs/OCNE-RAC-END-TO-END-MANUAL.md).

**Main URL: [http://localhost:8080](http://localhost:8080)** on your workstation, while the SSH tunnel runs. This lab is already deployed: start at **section 7**, then section 10 to understand the request flow. Sections1-6 are for a first installation; do not rerun one-time credential/user creation against this running app. Section 12 explains how to uninstall and redeploy while preserving records.

This document includes the full deployment and teardown procedures plus the internal-workings chapter. It is generated from those reviewed source documents by scripts/render_manual.py, so corrections can be kept consistent. [Full actual results](DEPLOYMENT-RESULTS.md) include complete command transcripts, image digests, SQL output and per-scenario probe summaries. Actual and expected outputs are labelled; pod names, UIDs, timestamps and new-install ClusterIPs will differ next time.

## Before you start: requirements and execution locations

| Location | This lab | Use it for |
|---|---|---|
| Windows workstation | D:\OCNE19-Lab | Source, protected files, SSH/SCP, browser and probes |
| Operator | ocne-op | Existing rootless Podman builder |
| Control plane | ocne-cp  / 192.168.77.11 | Existing authorized kubectl context |
| Worker1 | ocne-w1.lab.test  / 192.168.77.12 | Rootful image import; application pods and RACCDB1 |
| Worker2 | ocne-w2.lab.test  / 192.168.77.13 | Rootful image import; application pods and RACCDB2 |
| Application namespace | rac-app | Four Deployments/Services/PDBs, ConfigMap and two Secrets |
| Database namespace | rac | Existing RAC resources; preserved by app teardown |
| Oracle target | LABPDB  / labpdb_app | Separate LAB_TASKS and LAB_NOTES schemas |
| Protected workstation files | private/ | Credentials, tools, image archives, tunnel PID |
| Raw evidence | logs/ | Local command output and per-request JSONL |

Prerequisites: verified SSH aliases for all four VMs; existing kubectl access on ocne-cp; root/sudo access for image import on workers; both workers Ready and labelled raccluster=raccluster01; both RAC instances open; LABPDB READ WRITE; labpdb_app active on both instances; USERS online and AL32UTF8. First installation also requires unused LAB_TASKS/LAB_NOTES usernames and available NodePort 30080. Names already belonging to another project are investigated, never deleted to resolve conflicts.

The application adds 325m CPU/512 MiB requested memory per worker,650m/1 GiB total. Inspect requests and actual usage before applying. Workers remain22 GiB each. OP/CP remain the user's 4/8 GiB, below Oracle minimum sizing; this app acceptance does not validate those platform choices.

**Shell rule:** PowerShell means your Windows workstation. A block labelled Bash on ocne-cp, operator or worker runs after SSH to that VM. Type exit to return to Windows before a workstation command. Linux workstation examples use the checkout's actual path and python3; Git Bash on this Windows host uses /d/OCNE19-Lab and may name the interpreter python. Choose one alternative for each creation step, not both.

If adapting to your own environment, map your actual SSH aliases, node labels, PDB/service, listener DNS names/ports, namespace, tablespace and NodePort first. Update YAML, SQL and commands consistently. lab.psd1 does not dynamically rewrite these app files or a live cluster. There are no VM creation, disk formatting or RAC provisioning commands in the application procedure.

## Architecture and source orientation

![Deployed architecture](diagrams/architecture.svg)

The browser loads HTML/CSS/JavaScript from the frontend. Frontend proxies same-origin /api requests to Node.js. Node routes tasks to Python and notes to Java. Each database service has its own account/table in the same Oracle PDB. RAC's two instances access the same database; an acknowledged record is not tied to its original app pod or Oracle instance.

| Folder | Contents | Runtime responsibility |
|---|---|---|
| frontend/public | HTML/CSS/browser JavaScript | Forms, lists, health, saved retry UUID |
| frontend/server.mjs | Node static server/proxy | Port 8080, routes /api to gateway |
| backend/node-gateway | Node HTTP router | Port 8081, routing and aggregated health |
| backend/python-tasks | Python HTTP API and Oracle Thin pool | Port 8082, LAB_TASKS.BOARD_TASKS |
| backend/java-notes/src | Java HTTP API, JDBC Thin / HikariCP | Port 8083, LAB_NOTES.BOARD_NOTES |
| database | Create, verify and optional drop SQL | Administrator-only schema lifecycle |
| kubernetes | Namespace, ConfigMap, workloads and Services | Two replicas per component |
| scripts | Individually invoked helpers | Build, credentials, verification, pod tests, teardown |

No Oracle Instant Client is needed. Runtime users do not receive DBA privileges. Containers run as UID/GID 10001 with read-only root filesystems, dropped capabilities, no service-account token and a small disk-backed /tmp. Each Python/Java replica allows at most two Oracle connections; eight total across those four replicas. Java heap is capped at 128 MiB. See [ARCHITECTURE.md](ARCHITECTURE.md) for the full resource/timeout table.

This is an unauthenticated learning app for the isolated lab. The SSH tunnel listens only on workstation loopback, but it does not make the underlying cluster NodePort private. Do not expose the app publicly.

## Prepare workstation dependencies before the image-build step

The running lab already has these dependencies. On a new Windows checkout, from PowerShell:

```powershell
Set-Location D:\OCNE19-Lab\apps\rac-lab-board
node --version
python --version
# Only if JDK21 is not already installed:
.\scripts\Install-Local-JDK.ps1
python scripts/prepare.py
if ($LASTEXITCODE -ne 0) { throw 'Dependency preparation failed' }
```

Expected: Node.js 24, Python 3.10+, Java 21; five Java jars match their locked hashes; Java compiles; pinned Python packages install in the private virtual environment. Actual runtime packages include python-oracledb3.4.2, ojdbc11 23.9.0.25.07, HikariCP5.1.0, Gson2.13.2 and SLF4J2.0.17. Containers use Linux Python 3.12 and Java 21; all four image builds passed.

Equivalent Bash workstation, with Node.js 24/Python 3.10+/JDK 21 already installed:

```bash
cd /path/to/OCNE19-Lab/apps/rac-lab-board
node --version
python3 --version
javac -version
python3 scripts/prepare.py
```

Do not run scripts/dev.py for the live deployment. That is a separate memory-only demonstration, and its port 8080 conflicts with the live SSH tunnel. [LOCAL-DEVELOPMENT.md](LOCAL-DEVELOPMENT.md) explains that optional mode.
