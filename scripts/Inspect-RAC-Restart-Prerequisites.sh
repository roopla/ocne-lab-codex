#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
for pod in racnode1-0 racnode2-0; do
 echo "=== $pod restart-state inspection ==="
 kubectl exec -n rac "$pod" -- find /u01/app/grid -maxdepth 3 -type d -name '*backup*'
 kubectl exec -n rac "$pod" -- find /u01/app/19c/grid -maxdepth 3 -type d -name '*backup*'
 kubectl exec -n rac "$pod" -- ls -la /etc/oracle
 kubectl exec -n rac "$pod" -- grep -n -E 'def restore_gi_files|def backup_gi|etcoraclebackup|backup.*oracle|G_BASE|GRID_BASE' /opt/scripts/startup/scripts/oracommon.py
 kubectl exec -n rac "$pod" -- sha256sum /opt/scripts/startup/scripts/oracommon.py /opt/scripts/startup/scripts/oraracprov.py
 kubectl exec -n rac "$pod" -- sed -n '1920,2085p' /opt/scripts/startup/scripts/oracommon.py
 done
