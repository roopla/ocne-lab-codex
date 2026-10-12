#!/bin/bash
# Resume this deployment only after the pre-CRS password repair.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import subprocess,json,pathlib,hashlib

def k(*args):
 p=subprocess.run(['kubectl',*args],capture_output=True,text=True)
 if p.returncode: raise RuntimeError('Guard or command failed; inspect safely before retry')
 return p.stdout
cr=json.loads(k('get','racdatabase','rac19c','-n','rac','-o','json'))
assert cr['metadata']['uid']=='6be9de9e-f884-4b82-848b-52eadd7213d1'
assert cr['status']['state']=='PENDING'
d=pathlib.Path.home()/'.local/share/ocne-rac-secrets'
assert len((d/'db-password.txt').read_text())==24
for pod in ('racnode1-0','racnode2-0'):
 k('exec','-n','rac',pod,'--','test','!','-e','/etc/oracle/ocr.loc')
 ps=k('exec','-n','rac',pod,'--','ps','-eo','comm')
 assert not any(x in ps for x in ('ora_pmon','asm_pmon','java','python3'))
assert k('exec','-n','rac','racnode1-0','--','cat','/tmp/orod/.statefile').strip()=='failed'
# Oracle's installed runOracle.sh invokes main.py, which reloads the projected env and secret.
# Its setup detects the existing software and reuses it; no pod/PV/home reset.
cmd='umask 077; test ! -e /tmp/orod/resume-ins30003.stdout; nohup bash /opt/scripts/startup/runOracle.sh >/tmp/orod/resume-ins30003.stdout 2>&1 </dev/null & echo resume_pid=$!'
print(k('exec','-n','rac','racnode1-0','--','bash','-c',cmd))
PY
