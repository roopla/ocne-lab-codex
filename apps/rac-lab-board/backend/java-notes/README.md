# Java notes service

src/NotesServer.java contains the HTTP API, memory adapter and JDBC/HikariCP adapter. dependencies.lock.json pins jar URLs and hashes. lib/ and build/ are local ignored outputs; scripts/prepare.py verifies jars and compiles them.

See the [application README](../../README.md) and [local-development instructions](../../docs/LOCAL-DEVELOPMENT.md). The four-process demo launcher is the simplest way to run everything; it explicitly selects memory mode. Direct backend startup defaults to Oracle and requires credentials. Do not point development runs at the live database accidentally.

Default port: 8083. All processes accept PORT, HOST and POD_NAME. Service-specific configuration: STORE_MODE (oracle by default), DB_USER, DB_PASSWORD, DB_DSN, EXPECTED_PDB (LABPDB).

From this folder, after prerequisites are prepared:

```powershell
& "D:\OCNE19-Lab\private\app-tools\jdk-21.0.12.1+1\bin\java.exe" -cp "build;lib/*" NotesServer
```

On Bash use `java -cp "build:lib/*" NotesServer` instead of the Windows semicolon classpath.

Container build, only when a Linux container engine is available:

```text
docker build --platform linux/amd64 -t localhost/rac-board-notes:1.0.0 .
```

No container build or deployment was performed during local development. API details, probe behavior and future deployment are in the application docs.
