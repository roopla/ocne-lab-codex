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
for pod in ('racnode1-0','racnode2-0'):
 print('=== Restart incident: '+pod+' ===')
 p=subprocess.run(['kubectl','exec','-n','rac',pod,'--','cat','/tmp/orod/oracle_db_setup.log'],capture_output=True,text=True)
 lines=clean(p.stdout).splitlines();chosen=set()
 for i,line in enumerate(lines):
  if any(x in line for x in ('restoregifiles','CRS-4640','CRS-4000','INS-40401','Failed to restore','already been started','start crs')):
   chosen.update(range(max(0,i-4),min(len(lines),i+12)))
 print('Selected restart contexts; original line numbers retained')
 for i in sorted(chosen):print(str(i+1)+': '+lines[i])
 print(clean(p.stderr));print('exit code',p.returncode)
PY
