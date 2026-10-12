# Python tasks service

server.py contains validation, a memory adapter and the python-oracledb Thin adapter. SQL uses binds and one pinned Oracle session per request. requirements.lock.txt pins dependencies.

See the [application README](../../README.md) and [local-development instructions](../../docs/LOCAL-DEVELOPMENT.md). The four-process demo launcher is the simplest way to run everything; it explicitly selects memory mode. Direct backend startup defaults to Oracle and requires credentials. Do not point development runs at the live database accidentally.

Default port: 8082. All processes accept PORT, HOST and POD_NAME. Service-specific configuration: STORE_MODE (oracle by default), DB_USER, DB_PASSWORD, DB_DSN, EXPECTED_PDB (LABPDB).

From this folder, after prerequisites are prepared:

```text
D:\OCNE19-Lab\private\rac-app-venv\Scripts\python.exe server.py
```

Container build, only when a Linux container engine is available:

```text
docker build --platform linux/amd64 -t localhost/rac-board-tasks:1.0.0 .
```

No container build or deployment was performed during local development. API details, probe behavior and future deployment are in the application docs.
