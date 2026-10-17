#!/bin/bash
# Export one existing image; verify raw manifest identity before choosing format.
set -euo pipefail
[[ $(id -u) == 0 && $(hostname -s) == ocne-w1 ]]
base=/scratch/rebuild-kit-20261016
[[ -d /scratch && $(findmnt -nro TARGET -T /scratch) == /scratch ]]
[[ $(df -B1 --output=avail /scratch | tail -1) -gt 17179869184 ]]
install -d -m 0750 -o labadmin -g labadmin "$base"
[[ ! -e "$base/rac-image-test" ]]
podman save --format docker-dir --output "$base/rac-image-test" docker.io/roopla/oracle-rac:19.3.0-slim
sha256sum "$base/rac-image-test/manifest.json"
podman image inspect docker.io/roopla/oracle-rac:19.3.0-slim --format '{{.Digest}}'
podman pull --help | head -45
