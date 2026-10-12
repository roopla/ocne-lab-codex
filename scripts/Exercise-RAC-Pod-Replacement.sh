#!/bin/bash
# Historical first pod-replacement attempt; SQL gate stopped the run at node2.
# Use the corrected manual and recovery gates, not a blind rerun of this evidence script.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import datetime,json,os,pathlib,shlex,subprocess,time
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
cr=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1' and cr['status']['state']=='AVAILABLE'
for n in (2,1):
 healthy();network(3-n)
 pod=f'racnode{n}-0'
 before=json.loads(k('-n','rac','get','pod',pod,'-o','json'))
 old=before['metadata']['uid']
 assert before['spec']['nodeName']==f'ocne-w{n}.lab.test'
 k('exec','-n','rac',pod,'--','cmp','/etc/oracle/olr.loc','/u01/app/grid/.etcoraclebackup/oracle/olr.loc')
 k('exec','-n','rac',pod,'--','cmp','/etc/oracle/ocr.loc','/u01/app/grid/.etcoraclebackup/oracle/ocr.loc')
 print(f'SCENARIO S0{6+n}: normal replacement of {pod}; old UID={old}',flush=True)
 k('-n','rac','delete','pod',pod,'--grace-period=120','--wait=false')
 deadline=time.monotonic()+900
 while time.monotonic()<deadline:
  listing=json.loads(subprocess.check_output(['kubectl','-n','rac','get','pods','-o','json']))
  p=next((x for x in listing['items'] if x['metadata']['name']==pod),None)
  if p:
   ready=any(x['type']=='Ready' and x['status']=='True' for x in p['status'].get('conditions',[]))
   print(datetime.datetime.now(datetime.timezone.utc).isoformat(),pod,p['metadata']['uid'],p['status']['phase'],'Ready='+str(ready),'deleting='+str(bool(p['metadata'].get('deletionTimestamp'))),flush=True)
   if p['metadata']['uid']!=old and ready:break
  else:print(pod,'temporarily absent',flush=True)
  time.sleep(15)
 else:
  k('-n','rac','get','events','--sort-by=.metadata.creationTimestamp')
  raise RuntimeError('Replacement did not become Ready in 15 minutes; stop and diagnose; do not delete peer')
 k('-n','rac','get','pods','-o','wide')
 k('exec','-n','rac',pod,'--','/u01/app/19c/grid/bin/crsctl','check','crs')
 healthy();network(n);network(3-n)
 after=json.loads(k('-n','rac','get','pod',pod,'-o','json'))
 assert after['metadata']['uid']!=old
 assert 'hugepages-2Mi' not in after['spec']['containers'][0]['resources'].get('requests',{})
 print(f'SCENARIO S0{6+n}: PASS; new UID='+after['metadata']['uid'],flush=True)
print('Both sequential pod replacements passed database and network SQL checks.',flush=True)
PY
