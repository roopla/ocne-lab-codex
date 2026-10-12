#!/bin/bash
# Read-only RAC acceptance. Run only after the controller reports AVAILABLE.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
kubectl get racdatabase rac19c -n rac -o json | python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["status"]["state"]=="AVAILABLE"; print("RacDatabase AVAILABLE")'
kubectl wait --for=condition=Ready pod/racnode1-0 pod/racnode2-0 -n rac --timeout=30s
for n in 1 2; do
 pod=racnode$n-0
 kubectl exec -n rac "$pod" -- /u01/app/19c/grid/bin/crsctl check crs
 kubectl exec -n rac "$pod" -- /u01/app/19c/grid/bin/olsnodes -n
 kubectl exec -n rac "$pod" -- su - grid -c "export ORACLE_HOME=/u01/app/19c/grid ORACLE_SID=+ASM$n; /u01/app/19c/grid/bin/asmcmd lsdg"
 kubectl exec -n rac "$pod" -- su - grid -c '/u01/app/19c/grid/OPatch/opatch lspatches'
 kubectl exec -n rac "$pod" -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/OPatch/opatch lspatches'
 kubectl exec -i -n rac "$pod" -- su - oracle -c "export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1 ORACLE_SID=RACCDB$n; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'" <<'SQL'
whenever oserror exit failure
whenever sqlerror exit failure
set linesize 220 pagesize 100
select inst_id, instance_name, status, database_status from gv$instance order by inst_id;
select name, open_mode, database_role from v$database;
select inst_id, name, open_mode from gv$pdbs order by inst_id,con_id;
select inst_id,name,value from gv$parameter where name in ('sga_target','pga_aggregate_target','cluster_database','use_large_pages') order by name,inst_id;
select con_id, patch_id, action, status, description from cdb_registry_sqlpatch order by con_id,action_time;
select con_id,comp_id,status from cdb_registry where status<>'VALID' order by con_id,comp_id;
declare n number; begin
 select count(*) into n from gv$instance where status='OPEN' and database_status='ACTIVE';
 if n<>2 then raise_application_error(-20001,'Expected two open active RAC instances'); end if;
 select count(*) into n from gv$pdbs where name='LABPDB' and open_mode='READ WRITE';
 if n<>2 then raise_application_error(-20002,'Expected LABPDB open read/write on both instances'); end if;
 select count(*) into n from gv$parameter where name='sga_target' and value='3221225472';
 if n<>2 then raise_application_error(-20003,'Expected SGA target 3 GiB on both instances'); end if;
 select count(*) into n from gv$parameter where name='use_large_pages' and value='FALSE';
 if n<>2 then raise_application_error(-20004,'HugePages must be explicitly disabled on both instances'); end if;
 select count(*) into n from cdb_registry_sqlpatch where patch_id=39472050 and action='APPLY' and status='SUCCESS' and con_id in (1,3);
 if n<>2 then raise_application_error(-20005,'19.32 SQL RU must succeed in root and LABPDB'); end if;
end;
/
exit
SQL
done
kubectl exec -n rac racnode1-0 -- /u01/app/19c/grid/bin/crsctl stat res -t
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status database -db RACCDB -verbose'
kubectl exec -n rac racnode1-0 -- su - oracle -c '/u01/app/oracle/product/19c/dbhome_1/bin/srvctl status service -db RACCDB'
