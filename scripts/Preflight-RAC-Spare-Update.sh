#!/bin/bash
# Read-only cluster preflight; saves non-secret CR/StatefulSet snapshots locally on CP.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import datetime,json,pathlib,subprocess
out=pathlib.Path.home()/'asm-spares-20261014'
out.mkdir(mode=0o700,exist_ok=True)
def k(*args): return subprocess.check_output(['kubectl',*args],text=True)
live=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert live['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
assert live['status']['state']=='AVAILABLE'
for resource in ('racdatabase','sts','pods','pvc'):
 path=out/(resource+'-before.json')
 if not path.exists(): path.write_text(k('get',resource,'-n','rac','-o','json'))
for n in (1,2):
 pod=f'racnode{n}-0'
 for name in ('olr.loc','ocr.loc'):
  k('exec','-n','rac',pod,'--','cmp',f'/etc/oracle/{name}',f'/u01/app/grid/.etcoraclebackup/oracle/{name}')
new=json.loads(k('apply','--dry-run=server','-f',str(out/'rac-database-live.yaml'),'-o','json'))
a=live['spec'].copy(); b=new['spec'].copy()
old=a.pop('asmDiskGroupDetails'); added=b.pop('asmDiskGroupDetails')
assert len(old)==1 and old[0]['name']=='DATA'
assert added[0]==old[0], 'Existing DATA settings changed'
assert added[1]['name']=='SPAREDISKS' and added[1]['type']=='OTHERS' and added[1]['autoUpdate']=='false'
assert len(added)==2 and len(added[1]['disks'])==2
changes=[key for key in sorted(set(a)|set(b)) if a.get(key)!=b.get(key)]
print('Other spec fields changed:',changes)
assert not changes, 'Stop: unrelated spec drift'
print(json.dumps(added,indent=2))
print('PASS: server dry-run accepted; only spare disk group entry changes')
print('Snapshots:',out)
PY
