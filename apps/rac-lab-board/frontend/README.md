# Frontend

Vanilla browser UI in public/. server.mjs serves only its known assets and proxies /api to the gateway. It contains no Oracle driver or credentials.

See the [application README](../README.md) and [local-development instructions](../docs/LOCAL-DEVELOPMENT.md). The four-process demo launcher is the simplest way to run everything; it explicitly selects memory mode. Direct backend startup defaults to Oracle and requires credentials. Do not point development runs at the live database accidentally.

Default port: 8080. All processes accept PORT, HOST and POD_NAME. Service-specific configuration: GATEWAY_URL (default http://127.0.0.1:8081).

From this folder, after prerequisites are prepared:

```text
node server.mjs
```

Container build, only when a Linux container engine is available:

```text
docker build --platform linux/amd64 -t localhost/rac-board-frontend:1.0.0 .
```

No container build or deployment was performed during local development. API details, probe behavior and future deployment are in the application docs.
