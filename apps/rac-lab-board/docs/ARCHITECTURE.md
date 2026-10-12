# Architecture

## 1. The application in plain language

A **task** is an action to try in the lab. A **note** is an observation to leave for another person. Both contain a unique request ID, text and a creation timestamp. Records are append-only; no edit/delete API obscures the outcome of a failover test.

The browser is the frontend. A **microservice** is a separately runnable API process with one responsibility. A **pod** is the Kubernetes unit running one of our containers. A **Deployment** maintains the desired number of pods. A **Service** gives those replaceable pods a stable address. RAC runs two Oracle instances against one shared database; those instances are not independent copies of application data.

![Layers and database paths](diagrams/architecture.svg)

## 2. Components

| Component | Code | Responsibility | Port | Future replicas | Database access |
|---|---|---|---:|---:|---|
| Frontend | HTML/CSS/browser JS plus Node static server | Two forms, lists, health display; same-origin API proxy | 8080 | 2 | None |
| Gateway | Node.js 24 built-in HTTP/fetch | Route tasks to Python, notes to Java; aggregate health; request trace | 8081 | 2 | None |
| Tasks | Python + python-oracledb 3.4.2 Thin | Validate, create/list/find tasks | 8082 | 2 | LAB_TASKS.BOARD_TASKS |
| Notes | Java 21 + JDBC Thin 23.9 + HikariCP 5.1 | Validate, create/list/find notes | 8083 | 2 | LAB_NOTES.BOARD_NOTES |
| Existing RAC | Oracle 19.32, Database Operator 2.2.0 | Shared durable state | Listener ports below | 2 instances | LABPDB |

Thin drivers need no Oracle Instant Client. Java uses the JDK HTTP server instead of a large framework, keeping the code and memory footprint small. Python uses a bounded HTTP worker pool. Node has no third-party runtime packages. These technology choices and manifests are this project's implementation, not an Oracle reference architecture or certification.

A task and a note are independent records. There is no cross-service transaction or implied atomicity between them. The browser never receives database credentials.

## 3. Request flow

1. The user enters text. The browser creates a lowercase UUID and persists the ID and text in localStorage before sending.
2. The frontend proxies `/api/tasks` or `/api/notes` to the Node gateway.
3. The gateway routes once to the appropriate service; it does not transparently retry a write.
4. That service borrows one database connection, checks its PDB and captures the instance name on that same connection.
5. The service inserts with bound variables and commits. Its reply contains the stored row, serving pod and RAC instance.
6. A lost reply leaves the write outcome unknown. The browser retains the same ID/text and offers a retry. A primary-key collision with identical text returns the original record; different text returns HTTP 409.

![Write retry sequence](diagrams/write-retry.svg)

A successful retry can reconnect to the other RAC instance because both see the same committed table. This prevents duplicate records for this API operation; it does not replay arbitrary transactions or provide exactly-once delivery for external side effects. LocalStorage is scoped to the browser/origin; retain the same request ID yourself for scripts or another browser. Clearing localStorage can lose an unresolved request's ID.

## 4. Existing database and networking

Observed on 12 October 2026, using read-only cluster inspection:

| Item | Existing value |
|---|---|
| Cluster | OCNE 1.9.6 / Kubernetes v1.29.14+2.el9 / CRI-O 1.29.1 |
| Worker 1 | ocne-w1.lab.test, 192.168.77.12, 22 GiB, 6 vCPU |
| Worker 2 | ocne-w2.lab.test, 192.168.77.13, 22 GiB, 6 vCPU |
| RAC namespace / CR | rac / rac19c |
| Database / instances | RACCDB / RACCDB1 and RACCDB2 |
| PDB / working application service | LABPDB / labpdb_app |
| Listener 1 from app pods | racnode1-0-lsnr.rac.svc.cluster.local:31522 |
| Listener 2 from app pods | racnode2-0-lsnr.rac.svc.cluster.local:31523 |
| App node selector | raccluster=raccluster01, present on both workers |
| Proposed frontend NodePort | 30080; unused at inspection, must recheck before deployment |

The Oracle descriptor is in [10-config.yaml](../kubernetes/10-config.yaml). It includes both listener addresses, address load balancing, connect-time failover and bounded connect timeouts. It requests `labpdb_app`; do not replace it with the stale `ORCLPDB` text in the existing CR summary. The existing SCAN listener Service selects node1 only, so it is not used as the sole application connection endpoint.

Ordinary application traffic uses the primary Kubernetes network. App pods do not attach to RAC's Multus private interconnects or access ASM devices. Database traffic stays inside the cluster. For browser access, the proposed path is Windows localhost -> SSH through ocne-cp -> worker NodePort 30080 -> frontend Service -> app pods. SSH tunneling avoids a new load balancer or Ingress controller. It does not make the underlying NodePort private to localhost; retain the lab network's isolation.

## 5. Resource budget and scheduling

Per-pod requests and limits in [20-workloads.yaml](../kubernetes/20-workloads.yaml):

| Component | CPU request | Memory request | CPU limit | Memory limit |
|---|---:|---:|---:|---:|
| Frontend | 25m | 32 MiB | 250m | 64 MiB |
| Gateway | 100m | 96 MiB | 500m | 192 MiB |
| Python | 100m | 128 MiB | 500m | 256 MiB |
| Java | 100m | 256 MiB | 750m | 384 MiB |
| One replica of each | 325m | 512 MiB | 2000m | 896 MiB |
| All eight app pods | 650m | 1024 MiB | 4000m | 1792 MiB |

Java heap is capped at 128 MiB, with 96 MiB maximum metaspace. Native memory, threads, JDBC and JVM overhead also consume the pod limit. This is a starting budget to measure under load, not a production sizing result. EmptyDir /tmp is disk-backed and capped at 64 MiB per pod. Each backend pod permits at most two database connections: eight total across both languages and both replicas. Python/Java each have eight HTTP workers and bounded pending work.

Observed existing reservations were 4700m / 16904 MiB on worker1 and 4200m / 16612 MiB on worker2. Kubernetes still advertised about 18 GiB of ordinary allocatable worker memory after the earlier HugePages change; the underlying host pool was disabled in the RAC work. This application work does not restart kubelet or alter that state. Inspect allocatable resources again before deployment. One replica of each service fits the observed reservations; actual usage and overhead must also be measured. Full worker failure includes relocated system workloads and an existing 16 GiB RAC pod, so do not promise that all replacement replicas will fit.

Topology spreading requests a balanced distribution across worker hostnames, with `ScheduleAnyway` to allow consolidation when only one worker is eligible. Placement is a preference, not hard separation. Each Deployment has a PDB with `minAvailable: 1`. PDBs govern voluntary evictions; they do not prevent direct pod deletion, OOM or host failure. Rolling updates use maxSurge=0 / maxUnavailable=1 to reduce transient resource use. This can temporarily reduce that service to one pod.

The existing operator/control-plane VMs remain at the user's 4/8 GiB below Oracle minimums; this project does not validate those undersized platform choices or change VM resources.

## 6. Health and failure behavior

- `/livez`: process reachable, without querying Oracle. A database outage alone should not trigger immediate container restart.
- Backend `/readyz`: borrow a connection, check expected PDB, execute SQL and confirm the required table is present. Kubernetes removes an unready backend from its Service after failed probes.
- Gateway/frontend `/readyz`: their own HTTP process is available. They stay reachable to report a backend outage.
- `/api/status`: each backend's current readiness, mode, pod and database instance. HTTP 200 means the aggregator answered; inspect each `healthy` field.
- Database read/statement calls are bounded; pool checkout is 3 seconds, individual database calls/read timeouts are 5 seconds. Gateway request timeout is 15 seconds, frontend 18, browser 20. These are separate limits, not a guaranteed total recovery time. An outer timeout may occur while the backend finishes a transaction; retry with the same ID.
- Idle sessions can become stale after instance loss. The pools validate/discard invalid sessions and establish new connections; the affected request can still fail. No FAN/ONS, TAF, Application Continuity or Transparent Application Continuity is configured. Connect-time failover does not migrate an in-flight session.
- Backend responses capture metadata before SQL on the same session. The UI's route footer is the latest completed list/write, not an immutable audit log. Use the JSONL probe for per-request evidence.

## 7. Boundaries and security

No PV/PVC is required for these stateless app pods; RAC already owns persistence. Memory mode is local-only and not suitable for multi-replica deployment. Kubernetes explicitly sets Oracle mode. Runtime containers are non-root, read-only, drop capabilities and have no mounted service-account token. Each backend receives only its own database Secret. The SQL script grants CREATE SESSION, a bounded quota and ownership of its own table; it does not grant DBA, RESOURCE or cross-schema access. An owner can modify its own objects; a separate owner/runtime split would be a later hardening step.

The learning app has no login, authorization, TLS termination, rate limiter, audit-retention policy or automatic schema migration. It uses JSON body limits, bound SQL and DOM textContent. Foreign browser origins cannot write through its frontend. HTTP access should remain inside this lab. Standard Kubernetes Secrets require appropriate cluster access control/encryption policies; base64 is not encryption. No NetworkPolicy is claimed: the existing Flannel installation has not been shown to enforce it.

Existing RAC pod replacement required assisted GI recovery on node2; node1 still logged a duplicate CRS startup defect in the supplied image. App pod failover can be exercised independently, but do not escalate to RAC pod deletion, worker reboot or full power failure until that image path is corrected and revalidated. See [the existing recovery evidence](../../../docs/RAC-EXERCISE-RECOVERY-OUTPUT.md).

## 8. References

- [Oracle JDBC driver/database/JDK compatibility](https://www.oracle.com/database/technologies/faq-jdbc.html) and [Oracle JDBC downloads](https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html).
- [python-oracledb 3.4.2 connection pools and connection handling](https://python-oracledb.readthedocs.io/en/v3.4.2/user_guide/connection_handling.html).
- [HikariCP configuration](https://github.com/brettwooldridge/HikariCP#configuration-knobs-baby).
- [Node.js 24 HTTP API](https://nodejs.org/docs/latest-v24.x/api/http.html).
- [Kubernetes disruption budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/), [topology spreading](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/) and [probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/).
- [Existing lab manual](../../../docs/OCNE-RAC-END-TO-END-MANUAL.md) and [observed RAC scenarios](../../../docs/RAC-TEST-SCENARIO-MATRIX.md).
