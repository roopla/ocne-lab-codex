# Backend services

Each microservice owns a separate folder and container build:

- [node-gateway](node-gateway/README.md): routes browser API requests and aggregates health.
- [python-tasks](python-tasks/README.md): tasks API, Oracle LAB_TASKS schema.
- [java-notes](java-notes/README.md): notes API, Oracle LAB_NOTES schema.

The gateway does not connect to Oracle. Python and Java independently connect to the same RAC application service using different credentials. See [architecture](../docs/ARCHITECTURE.md) and [API](../docs/API.md).
