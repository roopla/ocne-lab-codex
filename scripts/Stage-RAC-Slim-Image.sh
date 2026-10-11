#!/bin/bash
# Stage the user-supplied image in rootful CRI-O storage; never start it.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=1ca6c397-b848-4e95-a24a-a96ea11a55cc;;
 ocne-w2) uuid=50e55c0d-a63c-41c4-b66c-7a46cae288ab;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /var/lib/containers) == "$uuid" ]]
[[ $(df --output=avail -B1 /var/lib/containers | tail -1) -gt 15000000000 ]]
systemctl is-active crio
image=docker.io/roopla/oracle-rac@sha256:d4aa7fecb15b4f62caed83a0f445a275cc5bd8fbd1b01c7ac6216037b656566d
crictl pull "$image"
crictl inspecti "$image" | python3 -c 'import json,sys; d=json.load(sys.stdin); s=d["status"]; print(json.dumps({k:s.get(k) for k in ("id","repoTags","repoDigests","size")},indent=2))'
podman image inspect "$image" --format '{{.Os}}/{{.Architecture}} user={{.Config.User}} entrypoint={{.Config.Entrypoint}} cmd={{.Config.Cmd}}'
df -h /var/lib/containers
