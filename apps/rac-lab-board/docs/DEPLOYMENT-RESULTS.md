# Actual application deployment and test results - 13 October 2026

The user authorized deployment after the earlier local-only development. Four images were built on ocne-op, imported into both workers' rootful CRI-O-visible storage, and deployed in rac-app. Both Oracle-backed APIs passed SQL readiness, live writes, concurrent deduplication and conflict checks. Eight app pods were Ready across the two workers. No RAC resource, VM sizing, SELinux policy, firewall rule or disk layout was changed.

Deployment/test times below are UTC (local workstation EDT is UTC-4). Actual initial rollout was about 11:11 UTC; application pod exercises ran 11:14:53-11:16:35 UTC. Initial acceptance counts at 11:17 UTC were **165 tasks and 164 notes**, with the same numbers of unique IDs. Later manual tests can increase those counts.

![Live application connected to Oracle](diagrams/application-live.png)

## Results table

Commands are from the Windows app root unless a guest is named. Use python3 instead of python on a Bash workstation. Each probe output filename must be new.

| Scenario / purpose | Command syntax | Expected result | Actual result |
|---|---|---|---|
| Build images without starting Docker Desktop | On operator: `python3 ~/rac-app-build/scripts/build_images.py --engine podman --archive ~/rac-app-images-1.0.0.tar` | Four linux/amd64 images; locked jars match | PASS, Podman 5.8.2 rootless; sequential 1 GiB build memory limit |
| Stage into CRI-O storage | Each worker: `sudo podman load -i ~/rac-app-images-1.0.0.tar`; `sudo crictl images` | Four exact tags visible on both workers | PASS; archive SHA256 checked before each import |
| Oracle application schemas | `python scripts/provision_access.py create-schemas`; `... verify` | Two users, two tables, four indexes; CREATE SESSION only; zero initial rows | PASS after correcting the password-length bug below |
| API admission | On CP: `kubectl apply --dry-run=server -k ~/rac-app/kubernetes` | All 14 manifest objects accepted | PASS |
| Deployment | On CP: `kubectl apply -k ~/rac-app/kubernetes`; four rollout status commands | Four Deployments 2/2, eight Ready pods | PASS; one replica of each tier on each worker |
| Browser access | `ssh -N -L 127.0.0.1:8080:192.168.77.12:30080 ocne-cp` | localhost UI and healthy Oracle services | PASS; both worker NodePorts reachable; existing firewall sufficient |
| Actual Oracle writes and concurrent retries | `python scripts/verify_live.py --allow-writes` | 201 create, four simultaneous 200 deduplicated replies, 409 conflict, one exact-ID row | PASS for both Python and Java |
| Browser lost-response recovery | `node tests/browser.cjs --live-oracle` | Keep UUID across reload; retry returns one existing committed note | PASS; response hidden deliberately in browser after real Oracle write; no DB fault |
| Browser layout/escaping | Same browser command | Desktop/mobile fit, text rendered literally, no page errors | PASS at 1440/390px; live screenshot above |
| F01 no-fault baseline | `python scripts/load_probe.py --kind tasks --seconds 5 --interval 0.5 --allow-writes --out <new-jsonl>`; repeat notes | All acknowledged IDs found | PASS: 10 created/10 verified per language, zero failed/missing |
| F02 replace one frontend pod | On CP: `kubectl -n rac-app delete pod board-frontend-6d45679b8c-phfmw --wait=true --timeout=120s`; two concurrent probes | New pod UID, two Ready replicas restored, every record retained | PASS: 38 tasks + 38 notes created/verified; 0 failed/missing; delete plus rollout 3.39s |
| F03 replace one gateway pod | On CP: `kubectl -n rac-app delete pod board-gateway-654f76bb55-44qbc --wait=true --timeout=120s`; two concurrent probes | New pod UID, two Ready replicas restored, every record retained | PASS: 38 tasks + 38 notes created/verified; 0 failed/missing; delete plus rollout 3.05s |
| F04 replace one tasks pod | On CP: `kubectl -n rac-app delete pod board-tasks-6cb95b78dd-jwgrb --wait=true --timeout=120s`; two concurrent probes | New pod UID, two Ready replicas restored, every record retained | PASS: 38 tasks + 38 notes created/verified; 0 failed/missing; delete plus rollout 4.69s |
| F05 replace one notes pod | On CP: `kubectl -n rac-app delete pod board-notes-558f6cb9fd-dc62h --wait=true --timeout=120s`; two concurrent probes | New pod UID, two Ready replicas restored, every record retained | PASS: 38 tasks + 38 notes created/verified; 0 failed/missing; delete plus rollout 4.33s |
| Database instance attribution | Inspect each probe's meta.instance | Real SQL reports RACCDB1/RACCDB2 in LABPDB | PASS: both languages observed both instances; this is not an instance-outage test |
| Database persistence/uniqueness | `python scripts/provision_access.py verify` | Counts equal unique IDs; both users OPEN | PASS: tasks 165/165, notes 164/164; labpdb_app active on instances 1 and 2 |
| RAC preservation | Compare RAC pod UIDs/restart counts before/after app tests | Same RAC pods, zero new restarts | PASS; recorded identities below |
| Teardown safety tests | `python tests/test_teardown.py` | Plan has no writes; reject other ownership; preserve namespace/RAC; check replaced UID | PASS: five mocked tests, no actual deletion |
| Teardown live plan | On CP: `python3 ~/rac-app/remove_app.py` | Only 13 named app objects planned | PASS; exact plan below, no deletion |
| Destroy / reinstall / optional schema drop | [DESTROY.md](DESTROY.md) | App-only teardown; preserve data by default | DOCUMENTED, NOT EXECUTED; app deliberately left running |
| RAC instance/service/worker failure | [FAILOVER.md](FAILOVER.md), F09 onward | Measured pool recovery and retained data | NOT EXECUTED during this deployment; known RAC image startup defects still limit destructive restart exercises |

The 3-5 second values above measure the delete command plus rollout completion, not an outage duration or SLA. Probes sent roughly two requests per second per language for 20 seconds per scenario. No failed requests were observed in that sample; higher load and other timings can produce transient errors. These tests do not establish zero interruption, production sizing or arbitrary transaction replay.

## Issues encountered and exact fixes

| Issue / symptom | Diagnosis | Fix and verification |
|---|---|---|
| Docker Linux engine stopped | Docker CLI existed but the engine was unavailable | Used already-installed rootless Podman on operator; built all four images with SELinux enabled and a 1 GiB build-memory cap. No Docker Desktop startup or CRI-O replacement |
| ORA-00972 on CREATE USER | Generated 32-character passwords exceeded Oracle 19c's 30-byte maximum | Queried dba_users and verified neither app user existed; corrected generator, SQL prompts/validation and helper to 30 hex characters (120 random bits); replaced only unused protected values; creation and both runtime logins then passed |
| Nested PowerShell/SSH quoting lost Podman template arguments | Initial `podman info --format` inspection reported extra arguments | Used Python subprocess argument arrays and JSON-formatted Podman info for reliable inspection |
| Large image copy through workstation NAT forwarding was slow | Archive was 594 MiB; transferred file length showed slow progress | Sent worker copies directly from operator over pre-existing verified inter-VM SSH using scp -C; both hashes matched. Workstation archive retained under private/ |

The Oracle password limit is documented in [Oracle 19c minimum password requirements](https://docs.oracle.com/en/database/oracle/oracle-database/19/dbseg/minimum-requirements-passwords.html). No existing database account was reset. The first DDL attempt failed before either user existed; no DROP USER was used as a repair.

## Image provenance

Archive SHA256: `5b137845b7afbb0ebd53ecda966c3275b2e4a76cbef8e047eb1f2e8005401145`.

The same configuration image IDs were confirmed by rootful Podman/CRI-O on each worker:

| Image (tag 1.0.0) | Configuration image ID |
|---|---|
| localhost/rac-board-frontend | ea382de767638c7545bf36da2c9bb5e3afbb8044cb24178671309dd87ab76ea2 |
| localhost/rac-board-gateway | 23645feb5688795f6beb7c2371de8a8076ffed627efc0e6d1ea0dc8fdaab2cbf |
| localhost/rac-board-tasks | 18f34c964f13836f614f141fae0e0ef313c408634f77dd5d91ad7d36580699cc |
| localhost/rac-board-notes | 969ca462864c943fc65bf0a6d65bb0edd4c926a5e74dae3e33e65899d125e4af |

Captured builder base-image and app manifest digests (tags may move on a future rebuild):

```text
REPOSITORY                         TAG                 DIGEST                                                                   IMAGE ID                                                                 CREATED         SIZE
localhost/rac-board-notes          1.0.0               sha256:f33a6d1672e28ae016323c23f92ee395b79db9be3f16f5389f83851d3337020b  sha256:969ca462864c943fc65bf0a6d65bb0edd4c926a5e74dae3e33e65899d125e4af  14 minutes ago  303 MB
<none>                             <none>              sha256:8df8eb82aecd6ee6627f6de242435d49e4a70fa7121ff7c2745b2c10172109fa  sha256:c777b9a90420fbb593c8af2559a4b95264a680cc4aa877b12f534f470c61a2e4  14 minutes ago  456 MB
localhost/rac-board-tasks          1.0.0               sha256:a17f509b68e43d88034fc6f212978c509a965d893e9864ca46540f8b5ea63a70  sha256:18f34c964f13836f614f141fae0e0ef313c408634f77dd5d91ad7d36580699cc  14 minutes ago  162 MB
localhost/rac-board-gateway        1.0.0               sha256:0a0e81cd97c259ebc5275025c9138ed38ef41203c60d80481e3ef2930ea1ecb2  sha256:23645feb5688795f6beb7c2371de8a8076ffed627efc0e6d1ea0dc8fdaab2cbf  14 minutes ago  235 MB
localhost/rac-board-frontend       1.0.0               sha256:6dded35f5aadcfbbd7ade8dc219fbb62d4725d546645cd88e886df2e87e068d7  sha256:ea382de767638c7545bf36da2c9bb5e3afbb8044cb24178671309dd87ab76ea2  14 minutes ago  235 MB
docker.io/library/python           3.12-slim-bookworm  sha256:34386ef0cb081344d7ec1c103ba398e6e9f64e9ab3a1509accc92a4e24a07258  sha256:4f228bc1cbcfc794e4878312cfc241d368eff55a21c08d1e2bb263116c4ef524  7 days ago      136 MB
docker.io/library/node             24-bookworm-slim    sha256:d6aa754f16b3197301076f047b5def2f02ea1dbbc2ca920407d46d7ec7f87b20  sha256:470015c1ab1577c19efce2e80cdad4afd9c682cf8f4dcf3dccae5abfd9113397  7 days ago      235 MB
docker.io/library/eclipse-temurin  21-jdk-jammy        sha256:e0c60c487345d1dc9d0fc7b6f0496f3cc941e5132e09296cc17a6decc71b902b  sha256:058087133c713a27c0304192dc317338becb37b409758cbe1097c97b3fe82a59  11 days ago     448 MB
docker.io/library/eclipse-temurin  21-jre-jammy        sha256:f04fb34e053148344e83317976114ec3f37e4b830ec8bdab5a2fe3cecd7d010b  sha256:2561a2ccd826e11237d306d7d39413f425f5b46fb92898325d72ca9bcd07dae9  11 days ago     292 MB
```

## Actual rollout and final cluster output

Initial apply/rollout command: `kubectl apply -k ~/rac-app/kubernetes`, followed by `kubectl -n rac-app rollout status deployment/<each-board-name> --timeout=180s`.

```text
namespace/rac-app unchanged
configmap/rac-board-config created
service/board-frontend created
service/board-gateway created
service/board-notes created
service/board-tasks created
deployment.apps/board-frontend created
deployment.apps/board-gateway created
deployment.apps/board-notes created
deployment.apps/board-tasks created
poddisruptionbudget.policy/board-frontend created
poddisruptionbudget.policy/board-gateway created
poddisruptionbudget.policy/board-notes created
poddisruptionbudget.policy/board-tasks created
Waiting for deployment "board-frontend" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "board-frontend" rollout to finish: 1 of 2 updated replicas are available...
deployment "board-frontend" successfully rolled out
deployment "board-gateway" successfully rolled out
Waiting for deployment "board-tasks" rollout to finish: 0 of 2 updated replicas are available...
Waiting for deployment "board-tasks" rollout to finish: 1 of 2 updated replicas are available...
deployment "board-tasks" successfully rolled out
Waiting for deployment "board-notes" rollout to finish: 1 of 2 updated replicas are available...
deployment "board-notes" successfully rolled out
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                               SELECTOR
deployment.apps/board-frontend   2/2     2            2           6s    frontend     localhost/rac-board-frontend:1.0.0   app.kubernetes.io/name=board-frontend
deployment.apps/board-gateway    2/2     2            2           6s    gateway      localhost/rac-board-gateway:1.0.0    app.kubernetes.io/name=board-gateway
deployment.apps/board-notes      2/2     2            2           6s    notes        localhost/rac-board-notes:1.0.0      app.kubernetes.io/name=board-notes
deployment.apps/board-tasks      2/2     2            2           6s    tasks        localhost/rac-board-tasks:1.0.0      app.kubernetes.io/name=board-tasks

NAME                                  READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
pod/board-frontend-6d45679b8c-phfmw   1/1     Running   0          6s    10.244.1.16   ocne-w1.lab.test   <none>           <none>
pod/board-frontend-6d45679b8c-wps22   1/1     Running   0          6s    10.244.2.12   ocne-w2.lab.test   <none>           <none>
pod/board-gateway-654f76bb55-44qbc    1/1     Running   0          6s    10.244.2.13   ocne-w2.lab.test   <none>           <none>
pod/board-gateway-654f76bb55-qdvmb    1/1     Running   0          6s    10.244.1.14   ocne-w1.lab.test   <none>           <none>
pod/board-notes-558f6cb9fd-dc62h      1/1     Running   0          6s    10.244.2.14   ocne-w2.lab.test   <none>           <none>
pod/board-notes-558f6cb9fd-wqlq9      1/1     Running   0          6s    10.244.1.13   ocne-w1.lab.test   <none>           <none>
pod/board-tasks-6cb95b78dd-jwgrb      1/1     Running   0          6s    10.244.2.15   ocne-w2.lab.test   <none>           <none>
pod/board-tasks-6cb95b78dd-l42vz      1/1     Running   0          6s    10.244.1.15   ocne-w1.lab.test   <none>           <none>

NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE   SELECTOR
service/board-frontend   NodePort    10.111.152.185   <none>        8080:30080/TCP   6s    app.kubernetes.io/name=board-frontend
service/board-gateway    ClusterIP   10.111.29.66     <none>        8081/TCP         6s    app.kubernetes.io/name=board-gateway
service/board-notes      ClusterIP   10.97.138.126    <none>        8083/TCP         6s    app.kubernetes.io/name=board-notes
service/board-tasks      ClusterIP   10.97.151.25     <none>        8082/TCP         6s    app.kubernetes.io/name=board-tasks

NAME                                        MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/board-frontend   1               N/A               1                     6s
poddisruptionbudget.policy/board-gateway    1               N/A               1                     6s
poddisruptionbudget.policy/board-notes      1               N/A               1                     6s
poddisruptionbudget.policy/board-tasks      1               N/A               1                     6s
```

After the four app-pod replacements:

```text
NAME               STATUS   ROLES           AGE   VERSION          INTERNAL-IP     EXTERNAL-IP   OS-IMAGE                  KERNEL-VERSION                     CONTAINER-RUNTIME
ocne-cp.lab.test   Ready    control-plane   11d   v1.29.14+2.el9   192.168.77.11   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
ocne-w1.lab.test   Ready    <none>          11d   v1.29.14+2.el9   192.168.77.12   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
ocne-w2.lab.test   Ready    <none>          11d   v1.29.14+2.el9   192.168.77.13   <none>        Oracle Linux Server 9.8   5.15.0-324.217.5.3.el9uek.x86_64   cri-o://1.29.1
NAME                             READY   UP-TO-DATE   AVAILABLE   AGE     CONTAINERS   IMAGES                               SELECTOR
deployment.apps/board-frontend   2/2     2            2           5m47s   frontend     localhost/rac-board-frontend:1.0.0   app.kubernetes.io/name=board-frontend
deployment.apps/board-gateway    2/2     2            2           5m47s   gateway      localhost/rac-board-gateway:1.0.0    app.kubernetes.io/name=board-gateway
deployment.apps/board-notes      2/2     2            2           5m47s   notes        localhost/rac-board-notes:1.0.0      app.kubernetes.io/name=board-notes
deployment.apps/board-tasks      2/2     2            2           5m47s   tasks        localhost/rac-board-tasks:1.0.0      app.kubernetes.io/name=board-tasks

NAME                                  READY   STATUS    RESTARTS   AGE     IP            NODE               NOMINATED NODE   READINESS GATES
pod/board-frontend-6d45679b8c-wps22   1/1     Running   0          5m47s   10.244.2.12   ocne-w2.lab.test   <none>           <none>
pod/board-frontend-6d45679b8c-z8rfb   1/1     Running   0          2m29s   10.244.1.17   ocne-w1.lab.test   <none>           <none>
pod/board-gateway-654f76bb55-krsr2    1/1     Running   0          2m3s    10.244.2.16   ocne-w2.lab.test   <none>           <none>
pod/board-gateway-654f76bb55-qdvmb    1/1     Running   0          5m47s   10.244.1.14   ocne-w1.lab.test   <none>           <none>
pod/board-notes-558f6cb9fd-ccvk6      1/1     Running   0          74s     10.244.2.18   ocne-w2.lab.test   <none>           <none>
pod/board-notes-558f6cb9fd-wqlq9      1/1     Running   0          5m47s   10.244.1.13   ocne-w1.lab.test   <none>           <none>
pod/board-tasks-6cb95b78dd-l42vz      1/1     Running   0          5m47s   10.244.1.15   ocne-w1.lab.test   <none>           <none>
pod/board-tasks-6cb95b78dd-xtd2h      1/1     Running   0          99s     10.244.2.17   ocne-w2.lab.test   <none>           <none>

NAME                     TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE     SELECTOR
service/board-frontend   NodePort    10.111.152.185   <none>        8080:30080/TCP   5m47s   app.kubernetes.io/name=board-frontend
service/board-gateway    ClusterIP   10.111.29.66     <none>        8081/TCP         5m47s   app.kubernetes.io/name=board-gateway
service/board-notes      ClusterIP   10.97.138.126    <none>        8083/TCP         5m47s   app.kubernetes.io/name=board-notes
service/board-tasks      ClusterIP   10.97.151.25     <none>        8082/TCP         5m47s   app.kubernetes.io/name=board-tasks

NAME                                        MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
poddisruptionbudget.policy/board-frontend   1               N/A               1                     5m47s
poddisruptionbudget.policy/board-gateway    1               N/A               1                     5m47s
poddisruptionbudget.policy/board-notes      1               N/A               1                     5m47s
poddisruptionbudget.policy/board-tasks      1               N/A               1                     5m47s
NAME         READY   STATUS    RESTARTS   AGE   IP            NODE               NOMINATED NODE   READINESS GATES
racnode1-0   1/1     Running   0          35h   10.244.1.11   ocne-w1.lab.test   <none>           <none>
racnode2-0   1/1     Running   0          35h   10.244.2.10   ocne-w2.lab.test   <none>           <none>
```

Worker `free -m` snapshots after tests showed 11086 MiB available on worker1 and 12466 MiB on worker2. These are Linux instantaneous estimates including reclaimable memory, not Kubernetes scheduling capacity. Workers remain 22 GiB each; OP/CP remain below Oracle minimum sizing. No OOM/restart was observed in this short app acceptance.

## Actual HTTP and SQL acceptance output

```text
{"kind": "tasks", "id": "ae2d2f94-66c4-4a78-9010-89f7016b77c5", "create": 201, "concurrentRetryStatuses": [200, 200, 200, 200], "conflict": 409, "exactIdRows": 1, "meta": {"mode": "oracle", "pod": "board-tasks-6cb95b78dd-jwgrb", "instance": "RACCDB1", "pdb": "LABPDB", "databaseService": "labpdb_app", "service": "python-tasks"}, "retryInstances": ["RACCDB1"]}
{"kind": "notes", "id": "60bf4334-9005-4832-8c17-bb6841ab62d3", "create": 201, "concurrentRetryStatuses": [200, 200, 200, 200], "conflict": 409, "exactIdRows": 1, "meta": {"instance": "RACCDB1", "databaseService": "labpdb_app", "pdb": "LABPDB", "service": "java-notes", "mode": "oracle", "pod": "board-notes-558f6cb9fd-dc62h"}, "retryInstances": ["RACCDB1", "RACCDB2"]}
PASS: both Oracle backends create, concurrently deduplicate, reject conflicts and return exactly one matching row
PASS: live Oracle desktop UI, mode banner, create task, lost-response retry across reload, one stored note, mobile width, escaped markup, no browser errors
```

Read-only SQL verification after probes:

```text

Session altered.


PDB
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
LABPDB


OWNER
--------------------------------------------------------------------------------------------------------------------------------
TABLE_NAME
--------------------------------------------------------------------------------------------------------------------------------
LAB_NOTES
BOARD_NOTES

LAB_TASKS
BOARD_TASKS



KIND  ROWS_TOTAL UNIQUE_IDS
----- ---------- ----------
tasks	     165	165
notes	     164	164


USERNAME															 ACCOUNT_STATUS
-------------------------------------------------------------------------------------------------------------------------------- --------------------------------
LAB_NOTES															 OPEN
LAB_TASKS															 OPEN


GRANTEE 															 PRIVILEGE
-------------------------------------------------------------------------------------------------------------------------------- ----------------------------------------
LAB_NOTES															 CREATE SESSION
LAB_TASKS															 CREATE SESSION


   INST_ID NAME
---------- ----------------------------------------------------------------
	 1 labpdb_app
	 2 labpdb_app

Defaulted container "racnode1-0" out of: racnode1-0, racnode1-init1 (init)
```

## Per-scenario full command results and probe summaries

Reproduce all four app-only tests from the workstation app root:

```powershell
python scripts/exercise_app_pods.py --allow-pod-replacement
```

Bash workstation:

```bash
python3 scripts/exercise_app_pods.py --allow-pod-replacement
```

This opt-in helper writes test records, deletes just one pod of each named application tier in sequence, waits for two Ready replicas, verifies every request ID, and compares RAC pod UIDs/restarts after each scenario. It does not stop a database instance or delete RAC pods. For one scenario at a time with manual commands, use [FAILOVER.md](FAILOVER.md).

The following is the actual captured results.json. Each referenced JSONL also contains every HTTP write and exact-ID verification; those raw logs are retained locally under logs/rac-app-pod-exercises-20261013T111453Z, outside Git.

```json
{
  "racBefore": {
    "racnode1-0": {
      "uid": "590e8b8f-3a93-43d1-a8ea-3549e6b83201",
      "restarts": [
        0
      ]
    },
    "racnode2-0": {
      "uid": "e5fb5f48-cfcc-4476-97d9-07338262095d",
      "restarts": [
        0
      ]
    }
  },
  "results": [
    {
      "tier": "frontend",
      "command": "kubectl -n rac-app delete pod board-frontend-6d45679b8c-phfmw --wait=true --timeout=120s",
      "output": "pod \"board-frontend-6d45679b8c-phfmw\" deleted\nWaiting for deployment \"board-frontend\" rollout to finish: 1 of 2 updated replicas are available...\ndeployment \"board-frontend\" successfully rolled out",
      "oldUid": "bbcec152-8540-491c-b5a3-4e0c2f071f15",
      "readyPodsAfter": [
        {
          "name": "board-frontend-6d45679b8c-wps22",
          "uid": "75ffe7bd-98e8-43f7-805c-e285e22d89c5",
          "node": "ocne-w2.lab.test"
        },
        {
          "name": "board-frontend-6d45679b8c-z8rfb",
          "uid": "a832821f-8db2-4e7f-9e96-0631a6c983c0",
          "node": "ocne-w1.lab.test"
        }
      ],
      "deleteAndRolloutSeconds": 3.39,
      "probes": {
        "frontend-tasks": {
          "time": "2026-10-13T11:15:18.453521+00:00",
          "run": "6a8a9296",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        },
        "frontend-notes": {
          "time": "2026-10-13T11:15:19.263761+00:00",
          "run": "6b891724",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        }
      }
    },
    {
      "tier": "gateway",
      "command": "kubectl -n rac-app delete pod board-gateway-654f76bb55-44qbc --wait=true --timeout=120s",
      "output": "pod \"board-gateway-654f76bb55-44qbc\" deleted\nWaiting for deployment \"board-gateway\" rollout to finish: 1 of 2 updated replicas are available...\ndeployment \"board-gateway\" successfully rolled out",
      "oldUid": "daaea308-3fe3-40ad-b5d4-7e20f576e81a",
      "readyPodsAfter": [
        {
          "name": "board-gateway-654f76bb55-krsr2",
          "uid": "b173f908-1c66-497c-a41a-1a2fe79af0e9",
          "node": "ocne-w2.lab.test"
        },
        {
          "name": "board-gateway-654f76bb55-qdvmb",
          "uid": "71af6890-3998-4959-929d-ef77b4e2eee0",
          "node": "ocne-w1.lab.test"
        }
      ],
      "deleteAndRolloutSeconds": 3.05,
      "probes": {
        "gateway-tasks": {
          "time": "2026-10-13T11:15:44.492887+00:00",
          "run": "bac216a4",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        },
        "gateway-notes": {
          "time": "2026-10-13T11:15:45.544936+00:00",
          "run": "caad021e",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        }
      }
    },
    {
      "tier": "tasks",
      "command": "kubectl -n rac-app delete pod board-tasks-6cb95b78dd-jwgrb --wait=true --timeout=120s",
      "output": "pod \"board-tasks-6cb95b78dd-jwgrb\" deleted\nWaiting for deployment \"board-tasks\" rollout to finish: 1 of 2 updated replicas are available...\ndeployment \"board-tasks\" successfully rolled out",
      "oldUid": "aeae2f0e-3bcf-4f99-b3ad-dc6246bd2d18",
      "readyPodsAfter": [
        {
          "name": "board-tasks-6cb95b78dd-l42vz",
          "uid": "c967d908-f0b6-44d1-a727-2269b12616b0",
          "node": "ocne-w1.lab.test"
        },
        {
          "name": "board-tasks-6cb95b78dd-xtd2h",
          "uid": "ff0d45b5-6032-45f5-8020-afa2fcba11fa",
          "node": "ocne-w2.lab.test"
        }
      ],
      "deleteAndRolloutSeconds": 4.69,
      "probes": {
        "tasks-tasks": {
          "time": "2026-10-13T11:16:09.308247+00:00",
          "run": "5c773f85",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        },
        "tasks-notes": {
          "time": "2026-10-13T11:16:10.145940+00:00",
          "run": "bd8985bc",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        }
      }
    },
    {
      "tier": "notes",
      "command": "kubectl -n rac-app delete pod board-notes-558f6cb9fd-dc62h --wait=true --timeout=120s",
      "output": "pod \"board-notes-558f6cb9fd-dc62h\" deleted\nWaiting for deployment \"board-notes\" rollout to finish: 1 of 2 updated replicas are available...\ndeployment \"board-notes\" successfully rolled out",
      "oldUid": "016b7ca8-f64e-47f6-80dc-40045c5291ca",
      "readyPodsAfter": [
        {
          "name": "board-notes-558f6cb9fd-ccvk6",
          "uid": "e2f1b918-c2c2-4c47-8756-600c9c49bf4b",
          "node": "ocne-w2.lab.test"
        },
        {
          "name": "board-notes-558f6cb9fd-wqlq9",
          "uid": "59e25ebb-14be-40e4-a634-87b1fd2968de",
          "node": "ocne-w1.lab.test"
        }
      ],
      "deleteAndRolloutSeconds": 4.33,
      "probes": {
        "notes-tasks": {
          "time": "2026-10-13T11:16:33.918613+00:00",
          "run": "070d8fde",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        },
        "notes-notes": {
          "time": "2026-10-13T11:16:34.853677+00:00",
          "run": "a3ec9ee9",
          "phase": "summary",
          "attempts": 38,
          "created": 38,
          "deduplicated": 0,
          "failedAttempts": 0,
          "verified": 38,
          "missingOrUnknown": 0,
          "acknowledgedIds": 38,
          "unresolvedAtWriteEnd": [],
          "interpretation": "Verification errors need investigation; they are not proof of data loss."
        }
      }
    }
  ]
}
```

## Actual teardown plan output

```text
Context: kubernetes-admin@kubernetes
PLAN rac-app:deployment/board-frontend
PLAN rac-app:deployment/board-gateway
PLAN rac-app:deployment/board-tasks
PLAN rac-app:deployment/board-notes
PLAN rac-app:service/board-frontend
PLAN rac-app:service/board-gateway
PLAN rac-app:service/board-tasks
PLAN rac-app:service/board-notes
PLAN rac-app:poddisruptionbudget/board-frontend
PLAN rac-app:poddisruptionbudget/board-gateway
PLAN rac-app:poddisruptionbudget/board-tasks
PLAN rac-app:poddisruptionbudget/board-notes
PLAN rac-app:configmap/rac-board-config
Preserving namespace, all Oracle schemas/data, RAC resources, volumes, images and VMs.
No changes. Add --execute only when ready to uninstall the application.
```

No --execute removal or DROP USER was run. See [DESTROY.md](DESTROY.md) for pause, uninstall, optional Secret removal, data-preserving redeploy and separately confirmed permanent data deletion.

## Final documentation and helper checks

- Five mocked teardown safety tests passed; the live plans identified 13 default objects or 15 including the two app Secrets, without deleting anything.
- Application checker passed 59 local documentation links, Python syntax and all 14 manifest cross-references.
- All 40 documented Bash blocks and both new guest shell scripts passed bash -n; commands in those blocks were not executed by this check.
- All 23 documented PowerShell blocks parsed successfully; browser-test JavaScript syntax passed.
- Existing lab renderer check passed 31 Markdown files, 298 local links and all generated HTML copies.

A first Windows Bash-validation harness used subprocess text mode, which translated stdin line endings to CRLF and produced a do\r syntax error. Repeating with explicit UTF-8 bytes preserved LF and all blocks passed; the Linux scripts themselves required no change.

The later illustrated-manual expansion passed96application documentation links,76documented Bash blocks and50PowerShell blocks. Its generated Markdown/HTML consistency check passed. Edge loaded all6diagrams/screenshots, found no broken contents anchors, and confirmed no horizontal overflow at1440px or390px. The manual and full output are reachable from the application README. The final workstation image archive matched the recorded SHA256.
