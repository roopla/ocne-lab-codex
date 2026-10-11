#!/bin/bash
# Oracle CVU container-host checks only; no fixup and no RAC provisioning.
set -euo pipefail
[[ $(id -un) == labadmin ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
cvu=/scratch/tools/cvu-23.26.3/bin/cluvfy
[[ -x $cvu ]]
report="$HOME/cvu-reports/$(date -u +%Y%m%dT%H%M%SZ)"
install -d -m 0700 "$report"
"$cvu" -version
"$cvu" comp containerhost -type k8 -verbose -text -savedir "$report"
printf 'CVU container-host validation passed; report: %s\n' "$report"
