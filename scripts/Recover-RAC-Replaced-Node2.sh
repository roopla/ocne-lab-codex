#!/bin/bash
# Assisted recovery of an existing configured node after container replacement.
# Does not install GI, create a database, format ASM or touch the peer node.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
kubectl exec -i -n rac racnode2-0 -- bash -s <<'RECOVER'
set -euo pipefail
[[ $(hostname -s) == racnode2-0 ]]
[[ $(findmnt -nro FSTYPE -T /u01/app/grid) == xfs ]]
[[ -s /u01/app/grid/.etcoraclebackup/oracle/olr.loc ]]
[[ -d /etc/oracle && -z $(find /etc/oracle -mindepth 1 -maxdepth 1 -print -quit) ]]
[[ -f /u01/app/19c/grid/crs/install/crsconfig_params ]]
cp -rp /u01/app/grid/.etcoraclebackup/oracle/. /etc/oracle/
cmp /etc/oracle/olr.loc /u01/app/grid/.etcoraclebackup/oracle/olr.loc
/u01/app/19c/grid/crs/install/rootcrs.sh -updateosfiles
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19c/grid/bin/crsctl start crs
RECOVER
