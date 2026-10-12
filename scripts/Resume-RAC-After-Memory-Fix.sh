#!/bin/bash
# Resume the failed DBCA phase after the user-requested no-HugePages correction.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import subprocess,json

def k(*args):
 p=subprocess.run(['kubectl',*args],capture_output=True,text=True)
 if p.returncode: raise RuntimeError('Guard failed; inspect safely before retry: '+p.stderr)
 return p.stdout
cr=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
assert cr['spec']['configParams']['sgaSize']=='3G'
assert 'hugepages-2Mi' not in cr['spec']['resources']['limits']
for pod in ('racnode1-0','racnode2-0'):
 assert 'ora_pmon' not in k('exec','-n','rac',pod,'--','ps','-eo','comm')
 assert k('exec','-n','rac',pod,'--','sysctl','-n','kernel.shmall','kernel.shmmax').split()==['2097152','8589934592']
 assert 'online' in k('exec','-n','rac',pod,'--','/u01/app/19c/grid/bin/crsctl','check','crs')
 assert any(line.split()==['HugePages_Total:','0'] for line in k('exec','-n','rac',pod,'--','cat','/proc/meminfo').splitlines())
 check="import pathlib; procs=[p.read_bytes().split(bytes([0])) for p in pathlib.Path('/proc').glob('[0-9]*/cmdline') if p.exists()]; assert not any(any(a==b'main.py' or a.endswith(b'/main.py') for a in args) for args in procs)"
 k('exec','-n','rac',pod,'--','python3','-c',check)
assert k('exec','-n','rac','racnode1-0','--','cat','/tmp/orod/.statefile').strip()=='failed'
assert 'ora.raccdb.db' not in k('exec','-n','rac','racnode1-0','--','/u01/app/19c/grid/bin/crsctl','stat','res','-t').lower()
cmd='umask 077; test ! -e /tmp/orod/resume-nohugepages.stdout; export TOTAL_MEMORY=16384; nohup bash /opt/scripts/startup/runOracle.sh >/tmp/orod/resume-nohugepages.stdout 2>&1 </dev/null & echo resume_pid=$!'
print(k('exec','-n','rac','racnode1-0','--','bash','-c',cmd))
PY
