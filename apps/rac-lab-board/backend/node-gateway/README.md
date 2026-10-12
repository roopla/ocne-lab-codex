# Node.js gateway

Built-in Node HTTP/fetch service. /api/tasks goes to Python, /api/notes to Java, /api/status aggregates readiness. Writes are forwarded once; an unavailable downstream returns an unknown outcome.

See the [application README](../../README.md) and [local-development instructions](../../docs/LOCAL-DEVELOPMENT.md). The four-process demo launcher is the simplest way to run everything; it explicitly selects memory mode. Direct backend startup defaults to Oracle and requires credentials. Do not point development runs at the live database accidentally.

Default port: 8081. All processes accept PORT, HOST and POD_NAME. Service-specific configuration: TASKS_URL and NOTES_URL (defaults localhost:8082 and localhost:8083).

From this folder, after prerequisites are prepared:

```text
node server.mjs
```

Container build, only when a Linux container engine is available:

```text
docker build --platform linux/amd64 -t localhost/rac-board-gateway:1.0.0 .
```

No container build or deployment was performed during local development. API details, probe behavior and future deployment are in the application docs.
