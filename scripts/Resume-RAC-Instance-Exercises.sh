#!/bin/bash
# User-authorized sequential instance/service/scheduling exercises, with recovery.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export RAC_RESUME_INSTANCE2=1
python3 <<'PY'
import datetime,json,os,pathlib,shlex,subprocess
password=(pathlib.Path.home()/'.local/share/ocne-rac-secrets/db-password.txt').read_text().strip()
def run(args,stdin=None):
 print('\nUTC',datetime.datetime.now(datetime.timezone.utc).isoformat(),'$',shlex.join(args),flush=True)
 p=subprocess.run(args,input=stdin,capture_output=True,text=True,timeout=180)
 print((p.stdout+p.stderr).replace(password,'[REDACTED]'),end='',flush=True)
 print('Exit code:',p.returncode,flush=True)
 if p.returncode:raise RuntimeError('Command failed; review captured output')
 return p.stdout
def k(*args,stdin=None):return run(['kubectl',*args],stdin)
def srv(pod,arguments):return k('exec','-n','rac',pod,'--','su','-','oracle','-c','/u01/app/oracle/product/19c/dbhome_1/bin/srvctl '+arguments)
def sql(n,query):
 body='whenever oserror exit failure\nwhenever sqlerror exit failure\nset lines 180 pages 100\n'+query+'\nexit\n'
 return k('exec','-i','-n','rac',f'racnode{n}-0','--','su','-','oracle','-c',f"export ORACLE_SID=RACCDB{n}; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'",stdin=body)
def healthy():
 sql(1,"select inst_id,instance_name,status,database_status from gv$instance order by inst_id;\nselect inst_id,name,open_mode from gv$pdbs where name='LABPDB' order by inst_id;\ndeclare n number; begin select count(*) into n from gv$instance where status='OPEN' and database_status='ACTIVE'; if n<>2 then raise_application_error(-20001,'Both instances must be open'); end if; end;\n/")
 srv('racnode1-0','status service -db RACCDB')
 k('-n','rac','get','pods','-o','wide')
def network(n):
 port=31521+n;host=f'192.168.77.{11+n}'
 descriptor=f'(DESCRIPTION=(CONNECT_TIMEOUT=10)(TRANSPORT_CONNECT_TIMEOUT=5)(ADDRESS=(PROTOCOL=TCP)(HOST={host})(PORT={port}))(CONNECT_DATA=(SERVICE_NAME=labpdb_app)))'
 text=f'''whenever oserror exit failure
whenever sqlerror exit failure
connect system/"{password}"@"{descriptor}"
set lines 160 pages 100
column pdb format a20
column instance_name format a20
select sys_context('USERENV','CON_NAME') as pdb,sys_context('USERENV','INSTANCE_NAME') as instance_name from dual;
declare begin if sys_context('USERENV','CON_NAME')<>'LABPDB' or sys_context('USERENV','INSTANCE_NAME')<>'RACCDB{n}' then raise_application_error(-20001,'Wrong instance/PDB'); end if; end;
/
exit
'''
 k('exec','-i','-n','rac',f'racnode{n}-0','--','su','-','oracle','-c','/u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s /nolog',stdin=text)
assert k('exec','-n','rac','racnode1-0','--','cat','/u01/app/oracle/recovery-backups/manual-exercises-20261011/exit-code').strip()=='0'
healthy()
network(1)
for n in ((2,) if os.environ.get('RAC_RESUME_INSTANCE2') == '1' else (1,2)):
 print(f'\nSCENARIO S0{4+n}: stop/start only RACCDB{n}',flush=True)
 pod=f'racnode{n}-0';survivor=3-n
 instance_stopped=False
 service_stopped=False
 try:
  srv(pod,f'stop service -db RACCDB -service labpdb_app -instance RACCDB{n}')
  service_stopped=True
  srv(pod,f'stop instance -db RACCDB -instance RACCDB{n} -stopoption IMMEDIATE')
  instance_stopped=True
  srv(f'racnode{survivor}-0','status database -db RACCDB -verbose')
  k('-n','rac','get','pods','-o','wide')
  network(survivor)
 finally:
  if instance_stopped:srv(pod,f'start instance -db RACCDB -instance RACCDB{n}')
  if service_stopped:
   status=srv(pod,'status service -db RACCDB -service labpdb_app')
   if f'RACCDB{n}' not in status:srv(pod,f'start service -db RACCDB -service labpdb_app -instance RACCDB{n}')
 healthy();network(n)
 print(f'SCENARIO S0{4+n}: PASS',flush=True)
print('\nSCENARIO S10: application service stop/start on instance1 only',flush=True)
try:
 srv('racnode1-0','stop service -db RACCDB -service labpdb_app -instance RACCDB1')
 srv('racnode2-0','status service -db RACCDB')
 k('-n','rac','get','pods','-o','wide')
 network(2)
finally:
 srv('racnode1-0','start service -db RACCDB -service labpdb_app -instance RACCDB1')
healthy();network(1)
print('SCENARIO S10: PASS',flush=True)
for node in ('ocne-w1.lab.test','ocne-w2.lab.test'):
 print('\nSCENARIO S12: cordon/uncordon '+node,flush=True)
 try:
  k('cordon',node);k('get','node',node);k('-n','rac','get','pods','-o','wide')
 finally:k('uncordon',node)
 k('get','node',node)
healthy()
print('Sequential instance, service and cordon exercises passed; no pod deleted.',flush=True)
PY
