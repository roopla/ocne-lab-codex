#!/bin/bash
# Read-only final acceptance for the two additional raw ASM candidates.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 - "$@" <<'PY'
import json,subprocess,sys
paths=[f'/dev/disk/by-partlabel/ocne-rac-asm{i:02}' for i in (1,2,3,4)]
def k(*a,stdin=None):
 p=subprocess.run(['kubectl',*a],input=stdin,text=True,capture_output=True)
 print(p.stdout,end='');print(p.stderr,end='')
 if p.returncode: raise RuntimeError('kubectl failed')
 return p.stdout
pvs=json.loads(subprocess.check_output(['kubectl','get','pv','-o','json']))['items']
for path in paths:
 pv=next(p for p in pvs if p['spec'].get('local',{}).get('path')==path)
 assert pv['spec']['volumeMode']=='Block' and pv['status']['phase']=='Bound'
 print(path,pv['metadata']['name'],'Bound Block')
for n in ([int(x) for x in sys.argv[1:]] or [1,2]):
 pod=f'racnode{n}-0'
 p=json.loads(subprocess.check_output(['kubectl','get','pod',pod,'-n','rac','-o','json']))
 assert {v['devicePath'] for v in p['spec']['containers'][0]['volumeDevices']}==set(paths)
 assert any(c['type']=='Ready' and c['status']=='True' for c in p['status']['conditions'])
 print(pod,'UID',p['metadata']['uid'],'all four devices mapped')
 k('exec','-n','rac',pod,'--','ls','-l',*paths)
 perms=k('exec','-n','rac',pod,'--','stat','-c','%U:%G %a',*paths[2:])
 assert perms.splitlines()==['grid:asmadmin 660','grid:asmadmin 660'], 'Candidate permissions changed'
 sql="""whenever oserror exit failure
whenever sqlerror exit failure
set lines 200 pages 100
column path format a52
column name format a18
show parameter asm_diskstring
select path,header_status,mount_status,mode_status,state,group_number,total_mb from v$asm_disk order by path;
select name,type,state,total_mb,free_mb from v$asm_diskgroup;
select 1 / case when count(*)=2 then 1 else 0 end as candidate_check
from v$asm_disk where path in ('/dev/disk/by-partlabel/ocne-rac-asm03','/dev/disk/by-partlabel/ocne-rac-asm04') and header_status='CANDIDATE' and group_number=0;
select 1 / case when count(*)=2 then 1 else 0 end as member_check
from v$asm_disk where path in ('/dev/disk/by-partlabel/ocne-rac-asm01','/dev/disk/by-partlabel/ocne-rac-asm02') and header_status='MEMBER' and group_number>0;
select 1 / case when count(*)=1 then 1 else 0 end as data_check
from v$asm_diskgroup where name='DATA' and state='MOUNTED' and total_mb=102392;
select 1 / case when count(*)=0 then 1 else 0 end as placeholder_check
from v$asm_diskgroup where name='SPAREDISKS';
exit
"""
 k('exec','-i','-n','rac',pod,'--','su','-','grid','-c',f"export ORACLE_HOME=/u01/app/19c/grid ORACLE_SID=+ASM{n}; /u01/app/19c/grid/bin/sqlplus -s '/ as sysasm'",stdin=sql)
print('PASS: selected ASM instances discover two CANDIDATE disks; DATA unchanged')
PY
