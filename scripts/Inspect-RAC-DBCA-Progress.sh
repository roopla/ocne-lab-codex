#!/bin/bash
# Read-only concise DBCA progress, including timestamped retry logs.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import pathlib,subprocess,re
passwords=[p.read_text().strip() for p in (pathlib.Path.home()/'.local/share/ocne-rac-secrets').rglob('*password.txt')]
cmd='find /u01/app/oracle/cfgtoollogs/dbca/RACCDB -maxdepth 1 -type f -name "*.log" -printf "%T@ %p\\n" | sort -nr | head -n 5; for f in $(find /u01/app/oracle/cfgtoollogs/dbca/RACCDB -maxdepth 1 -type f -name "*.log" -printf "%T@ %p\\n" | sort -nr | head -n 2 | cut -d" " -f2-); do echo "$f"; tail -n 10 "$f"; done; ps -eo args | grep "^ora_pmon_"'
p=subprocess.run(['kubectl','exec','-n','rac','racnode1-0','--','bash','-c',cmd],capture_output=True,text=True)
s=p.stdout
for pw in passwords:
 if pw:s=s.replace(pw,'<redacted>')
s=re.sub(r'(?i)((?:password|passwd)\s*[=:]\s*)[^\s,;]+',r'\1<redacted>',s)
print(s)
PY
