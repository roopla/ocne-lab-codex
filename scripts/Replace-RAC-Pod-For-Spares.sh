#!/bin/bash
# Replace exactly one RAC pod only after the peer and template pass checks.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
[[ ${1:-} == 1 || ${1:-} == 2 ]]
python3 - "$1" <<'PY'
import datetime,json,subprocess,sys,time
n=int(sys.argv[1]); pod=f'racnode{n}-0'; peer=f'racnode{3-n}-0'
paths={f'/dev/disk/by-partlabel/ocne-rac-asm{i:02}' for i in (1,2,3,4)}
def k(*args,stdin=None,check=True):
 p=subprocess.run(['kubectl',*args],input=stdin,text=True,capture_output=True,timeout=180)
 print(p.stdout,end='',flush=True);print(p.stderr,end='',flush=True)
 if check and p.returncode:raise RuntimeError('kubectl failed: '+' '.join(args))
 return p

def obj(kind,name):return json.loads(subprocess.check_output(['kubectl','get',kind,name,'-n','rac','-o','json']))
def sqlcheck():
 sql="""whenever oserror exit failure
whenever sqlerror exit failure
set lines 180 pages 100
select inst_id,instance_name,status,database_status from gv$instance order by inst_id;
select inst_id,name,open_mode from gv$pdbs where name='LABPDB' order by inst_id;
declare n number; begin
 select count(*) into n from gv$instance where status='OPEN' and database_status='ACTIVE';
 if n<>2 then raise_application_error(-20001,'Both instances must be open'); end if;
 select count(*) into n from gv$pdbs where name='LABPDB' and open_mode='READ WRITE';
 if n<>2 then raise_application_error(-20002,'Both PDBs must be read write'); end if;
end;
/
exit
"""
 return k('exec','-i','-n','rac',peer,'--','su','-','oracle','-c',f"export ORACLE_SID=RACCDB{3-n}; /u01/app/oracle/product/19c/dbhome_1/bin/sqlplus -s '/ as sysdba'",stdin=sql,check=False).returncode==0
s=obj('sts',f'racnode{n}')
assert s['spec']['updateStrategy']['type']=='OnDelete'
assert {v['devicePath'] for v in s['spec']['template']['spec']['containers'][0]['volumeDevices']}==paths
p=obj('pod',pod);old=p['metadata']['uid']
assert not p['metadata'].get('deletionTimestamp')
assert p['spec']['nodeName']==f'ocne-w{n}.lab.test'
if {v['devicePath'] for v in p['spec']['containers'][0]['volumeDevices']}==paths:
 raise SystemExit('Pod already has four devices; do not replace again')
assert sqlcheck(), 'Initial SQL gate failed'
k('exec','-n','rac',peer,'--','/u01/app/19c/grid/bin/crsctl','check','crs')
for name in ('olr.loc','ocr.loc'):
 k('exec','-n','rac',pod,'--','cmp',f'/etc/oracle/{name}',f'/u01/app/grid/.etcoraclebackup/oracle/{name}')
print('START',datetime.datetime.now(datetime.timezone.utc).isoformat(),pod,'old UID',old,flush=True)
k('delete','pod',pod,'-n','rac','--grace-period=120','--wait=false')
for attempt in range(60):
 listing=json.loads(subprocess.check_output(['kubectl','get','pods','-n','rac','-o','json']))['items']
 p=next((x for x in listing if x['metadata']['name']==pod),None)
 if p:
  ready=any(c['type']=='Ready' and c['status']=='True' for c in p['status'].get('conditions',[]))
  print(datetime.datetime.now(datetime.timezone.utc).isoformat(),pod,p['metadata']['uid'],p['status']['phase'],'Ready',ready,flush=True)
  if p['metadata']['uid']!=old and ready:break
 time.sleep(15)
else:raise RuntimeError('Replacement not Ready; inspect before touching peer')
assert {v['devicePath'] for v in p['spec']['containers'][0]['volumeDevices']}==paths
for attempt in range(30):
 crs=k('exec','-n','rac',pod,'--','/u01/app/19c/grid/bin/crsctl','check','crs',check=False)
 if crs.returncode==0 and sqlcheck():break
 time.sleep(10)
else:raise RuntimeError('GI or SQL recovery failed; leave peer untouched and diagnose')
k('get','pods','-n','rac','-o','wide')
print('PASS',pod,'new UID',p['metadata']['uid'],'four mapped devices; both DB instances and PDBs open',flush=True)
PY
