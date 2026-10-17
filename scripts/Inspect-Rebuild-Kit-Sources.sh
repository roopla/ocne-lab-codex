#!/bin/bash
# Read-only discovery for preparing the separately authorized rebuild kit.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
rpm -q podman skopeo dnf-plugins-core olcne-utils oracle-ocne-release-el9 || true
if command -v podman >/dev/null; then
 podman images --format json | python3 -c 'import json,sys; print(json.dumps([{k:i.get(k) for k in ("Id","Names","Digest","Size")} for i in json.load(sys.stdin)],indent=2))'
 podman save --help | head -45
fi
if command -v skopeo >/dev/null; then skopeo copy --help | head -45; fi
dnf download --help >/dev/null 2>&1 && echo DNF_DOWNLOAD_AVAILABLE || true
find /var/cache/dnf -type f -name '*.rpm' | wc -l
findmnt -n -o TARGET,AVAIL -T /scratch 2>/dev/null || df -h /var/tmp
