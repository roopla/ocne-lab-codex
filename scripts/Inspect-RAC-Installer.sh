#!/bin/bash
# Read-only installer diagnostics; redact all known current/recovery passwords.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import pathlib,subprocess,re
secrets=[p.read_text().strip() for p in (pathlib.Path.home()/'.local/share/ocne-rac-secrets').rglob('*password.txt')]
def clean(s):
 for pw in secrets:
  if pw: s=s.replace(pw,'<redacted>')
 return re.sub(r'(?i)((?:password|passwd)\s*[=:]\s*)[^\s,;]+',r'\1<redacted>',s)
for pod in ('racnode1-0','racnode2-0'):
 cmd='ps -eo pid,comm,etime,pcpu,pmem; for f in $(find /u01/app/oraInventory/logs -type f -name "gridSetupActions*.log" -printf "%T@ %p\\n" | sort -n | tail -1 | cut -d" " -f2-); do echo "$f"; tail -n 12 "$f"; grep -E "INS-|PRVG-|PRVF-|PRVE-|failed|FAILED" "$f" | tail -n 35; done'
 p=subprocess.run(['kubectl','exec','-n','rac',pod,'--','bash','-c',cmd],capture_output=True,text=True)
 print(pod); print(clean(p.stdout))
PY
