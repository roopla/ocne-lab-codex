#!/bin/bash
# Sanitize controller diagnostics using the local recovery password without printing it.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import subprocess,json,re,pathlib
secret=pathlib.Path.home()/'.local/share/ocne-rac-secrets/db-password.txt'

def clean(s):
 d=pathlib.Path.home()/'.local/share/ocne-rac-secrets'
 for file in d.rglob('*password.txt'):
  pw=file.read_text().strip()
  if pw: s=s.replace(pw,'<redacted>')
 s=re.sub(r'-----BEGIN [^-]*PRIVATE KEY-----.*?-----END [^-]*PRIVATE KEY-----','<redacted private key>',s,flags=re.S)
 s=re.sub(r'(?i)((?:password|passwd|sysPassword|systemPassword|pdbAdminPassword)\s*[=:]\s*)[^\s,;]+',r'\1<redacted>',s)
 return s
cmd=['kubectl','get','racdatabase','rac19c','-n','rac','-o','json']
p=subprocess.run(cmd,capture_output=True,text=True,check=True)
d=json.loads(p.stdout)
status=d.get('status',{}); print(clean(json.dumps({k:status.get(k) for k in ('state','dbState','releaseUpdate','conditions','racNodes')},indent=2)))
p=subprocess.run(['kubectl','logs','-n','oracle-database-operator-system','deployment/oracle-database-operator-controller-manager','--tail=120'],capture_output=True,text=True)
lines=[line for line in p.stdout.splitlines() if not any(x in line for x in ('Service reconciled','PV Found','PVC Found','Entering reconcile phase','Reconcile requested','RAC spec annotation','Returning from updateReconcileStatus'))]
print(clean('\n'.join(lines[-8:]))); print(clean(p.stderr))
for pod in ('racnode1-0','racnode2-0'):
 print('--- '+pod+' ---')
 cmd=['kubectl','exec','-n','rac',pod,'--','bash','-c','tail -n 16 /tmp/orod/oracle_db_setup.log 2>/dev/null; systemctl is-system-running; systemctl --failed --no-pager']
 p=subprocess.run(cmd,capture_output=True,text=True)
 print(clean(p.stdout)); print(clean(p.stderr))
PY
kubectl get pods -n rac -o wide
