#!/usr/bin/env bash
# Import this recorded app build only; never prune existing worker images.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo 'Run as root for CRI-O-visible image storage'; exit 1; }
case "$(hostname -s)" in ocne-w1|ocne-w2) ;; *) echo 'Not an expected worker'; exit 1;; esac
archive=/home/labadmin/rac-app-images-1.0.0.tar
expected=5b137845b7afbb0ebd53ecda966c3275b2e4a76cbef8e047eb1f2e8005401145
printf '%s  %s\n' "$expected" "$archive" | sha256sum --check -
[ "$(podman info --format '{{.Store.GraphRoot}}')" = /var/lib/containers/storage ]
podman load --input "$archive"
for name in frontend gateway tasks notes; do
  crictl inspecti "localhost/rac-board-$name:1.0.0" >/dev/null
  podman image inspect "localhost/rac-board-$name:1.0.0" --format '{{.Id}} {{.RepoTags}}'
done
crictl images | grep rac-board
