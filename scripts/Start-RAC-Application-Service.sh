#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
svc=/u01/app/oracle/product/19c/dbhome_1/bin/srvctl
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc start service -db RACCDB -service labpdb_app"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc status service -db RACCDB; $svc config service -db RACCDB -service labpdb_app"
