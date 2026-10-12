#!/bin/bash
# HISTORICAL FAILED EXPERIMENT: ORA-65042. Do not use as a recovery procedure.
# Keep the CR's immutable application-service name; qualify the PDB default service.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
[[ $(kubectl get racdatabase rac19c -n rac -o jsonpath='{.spec.serviceDetails.name}') == labpdb ]]
svc=/u01/app/oracle/product/19c/dbhome_1/bin/srvctl
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc stop service -db RACCDB -service labpdb_app"
kubectl exec -i -n rac racnode1-0 -- su - oracle -c "export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1 ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'" <<'SQL'
whenever oserror exit failure
whenever sqlerror exit failure
set lines 180 pages 60
alter pluggable database LABPDB close immediate instances=all;
alter pluggable database LABPDB open read write restricted;
alter session set container=LABPDB;
select global_name from global_name;
alter pluggable database rename global_name to LABPDB.lab.test;
alter pluggable database close immediate;
alter session set container=CDB$ROOT;
alter pluggable database LABPDB open read write instances=all;
alter pluggable database LABPDB save state instances=all;
select name,network_name,pdb from cdb_services where pdb='LABPDB';
exit
SQL
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc add service -db RACCDB -service labpdb -pdb LABPDB -preferred RACCDB1,RACCDB2"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc start service -db RACCDB -service labpdb"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc config service -db RACCDB -service labpdb; $svc status service -db RACCDB"
