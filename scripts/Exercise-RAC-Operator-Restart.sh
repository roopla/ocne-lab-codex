#!/bin/bash
# User-authorized sequential instance/service/scheduling exercises, with recovery.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
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
healthy();network(1);network(2)
before=json.loads(k('-n','rac','get','pods','-o','json'))
uids={p['metadata']['name']:p['metadata']['uid'] for p in before['items']}
print('SCENARIO S21: restart Database Operator deployment only',flush=True)
k('-n','oracle-database-operator-system','get','pods','-o','wide')
k('-n','oracle-database-operator-system','rollout','restart','deployment/oracle-database-operator-controller-manager')
k('-n','oracle-database-operator-system','rollout','status','deployment/oracle-database-operator-controller-manager','--timeout=120s')
k('-n','oracle-database-operator-system','get','pods','-o','wide')
after=json.loads(k('-n','rac','get','pods','-o','json'))
assert uids=={p['metadata']['name']:p['metadata']['uid'] for p in after['items']}
healthy();network(1);network(2)
k('get','nodes','-o','wide')
k('-n','rac','get','pvc');k('get','pv')
for p in after['items']:
 print('FINAL POD',p['metadata']['name'],p['metadata']['uid'],p['status']['podIP'],p['spec']['nodeName'],json.dumps(p['spec']['containers'][0]['resources']),flush=True)
 assert 'hugepages-2Mi' not in p['spec']['containers'][0]['resources']['requests']
k('-n','rac','get','events','--sort-by=.metadata.creationTimestamp')
print('S21 passed: controller replaced, RAC pod UIDs unchanged, both SQL paths healthy.',flush=True)
PY
