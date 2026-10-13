#!/usr/bin/env bash
set -euo pipefail
id
hostname
podman info --format '{{.Store.GraphRoot}}'
crictl images | head -15
df -h /var/lib/containers/storage
