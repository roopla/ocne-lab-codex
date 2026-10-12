#!/bin/bash
# Run only after DBCA exits and both instances are OPEN. Uses OS authentication.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import subprocess,json

def k(*args):
 p=subprocess.run(['kubectl',*args],capture_output=True,text=True)
 if p.returncode:raise RuntimeError('kubectl check failed: '+p.stderr)
 return p.stdout
cr=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
for pod in ('racnode1-0','racnode2-0'):
 check="import pathlib; procs=[p.read_bytes().split(bytes([0])) for p in pathlib.Path('/proc').glob('[0-9]*/cmdline') if p.exists()]; assert not any(args[-2:-1] and (args[-2]==b'main.py' or args[-2].endswith(b'/main.py')) for args in procs)"
 k('exec','-n','rac',pod,'--','python3','-c',check)
assert 'Database creation complete' in k('exec','-n','rac','racnode1-0','--','cat','/u01/app/oracle/cfgtoollogs/dbca/RACCDB/RACCDB0.log')
print('DBCA completion and absence of an active setup process verified.')
PY
sqlplus_cmd="export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1 ORACLE_SID=RACCDB1; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'"
kubectl exec -i -n rac racnode1-0 -- su - oracle -c "$sqlplus_cmd" <<'SQL'
whenever oserror exit failure
whenever sqlerror exit failure
set lines 200
select inst_id,instance_name,status from gv$instance;
select name,open_mode from v$pdbs;
declare n number; begin
 select count(*) into n from gv$instance where status='OPEN';
 if n<>2 then raise_application_error(-20001,'Both instances must be OPEN'); end if;
 select count(*) into n from v$pdbs where name='ORCLPDB';
 if n<>1 then raise_application_error(-20002,'Expected original default ORCLPDB'); end if;
 select count(*) into n from v$pdbs where name='LABPDB';
 if n<>0 then raise_application_error(-20003,'LABPDB already exists; inspect'); end if;
end;
/
exit
SQL
# Remove only the newly generated root-container service whose name would clash
# with the desired PDB's automatic default service.
svc=/u01/app/oracle/product/19c/dbhome_1/bin/srvctl
if kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc config service -db RACCDB -service labpdb" >/dev/null 2>&1; then
 kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc stop service -db RACCDB -service labpdb"
 kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc remove service -db RACCDB -service labpdb -force"
fi
kubectl exec -i -n rac racnode1-0 -- su - oracle -c "$sqlplus_cmd" <<'SQL'
whenever oserror exit failure
whenever sqlerror exit failure
alter pluggable database ORCLPDB close immediate instances=all;
alter pluggable database ORCLPDB open read write restricted;
alter session set container=ORCLPDB;
alter pluggable database rename global_name to LABPDB;
alter pluggable database close immediate;
alter session set container=CDB$ROOT;
alter pluggable database LABPDB open read write instances=all;
alter pluggable database LABPDB save state instances=all;
alter system set use_large_pages='FALSE' scope=spfile sid='*';
select inst_id,name,open_mode from gv$pdbs order by inst_id,con_id;
exit
SQL
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc stop database -db RACCDB -stopoption IMMEDIATE"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc start database -db RACCDB"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc add service -db RACCDB -service labpdb_app -pdb LABPDB -preferred RACCDB1,RACCDB2"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc start service -db RACCDB -service labpdb_app"
kubectl exec -n rac racnode1-0 -- su - oracle -c "$svc status database -db RACCDB -verbose; $svc config service -db RACCDB -service labpdb_app; $svc status service -db RACCDB"
