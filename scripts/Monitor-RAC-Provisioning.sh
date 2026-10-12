#!/bin/bash
# Observe provisioning for up to 45 minutes; no retries or state changes.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 -u <<'PY'
import subprocess,json,re,pathlib,time,datetime

def clean(s):
 d=pathlib.Path.home()/'.local/share/ocne-rac-secrets'
 for file in d.rglob('*password.txt'):
  pw=file.read_text().strip()
  if pw: s=s.replace(pw,'<redacted>')
 s=re.sub(r'(?i)((?:password|passwd|sysPassword|systemPassword|pdbAdminPassword)\s*[=:]\s*)[^\s,;]+',r'\1<redacted>',s)
 return s
for attempt in range(60):
 p=subprocess.run(['kubectl','get','racdatabase','rac19c','-n','rac','-o','json'],capture_output=True,text=True,check=True)
 state=json.loads(p.stdout).get('status',{})
 print(datetime.datetime.now(datetime.timezone.utc).isoformat(),'state='+str(state.get('state')),'database='+str(state.get('dbState')),flush=True)
 for pod in ('racnode1-0','racnode2-0'):
  p=subprocess.run(['kubectl','exec','-n','rac',pod,'--','tail','-n','3','/tmp/orod/oracle_db_setup.log'],capture_output=True,text=True)
  print(pod+': '+clean(p.stdout[-1800:]),flush=True)
 if state.get('state') in ('AVAILABLE','FAILED'): break
 time.sleep(45)
PY
