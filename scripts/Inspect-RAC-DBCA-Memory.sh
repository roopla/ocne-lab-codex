#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import subprocess,pathlib,re
passwords=[p.read_text().strip() for p in (pathlib.Path.home()/'.local/share/ocne-rac-secrets').rglob('*password.txt')]
def clean(s):
 for pw in passwords:
  if pw:s=s.replace(pw,'<redacted>')
 return re.sub(r'(?i)((?:password|passwd)\s*[=:]\s*)[^\s,;]+',r'\1<redacted>',s)
for pod in ('racnode1-0','racnode2-0'):
 print(pod)
 commands=[['bash','-c','ps -eo pid,comm,etime | grep -E "PID|pmon|dbca|python3"; cat /tmp/orod/.statefile; /u01/app/19c/grid/bin/crsctl check crs;  sysctl kernel.shmall kernel.shmmax vm.hugetlb_shm_group; grep -E "Huge|MemAvailable" /proc/meminfo; ipcs -m; su - oracle -c "ulimit -l; id"; cat /sys/fs/cgroup/hugetlb.2MB.max /sys/fs/cgroup/hugetlb.2MB.current /sys/fs/cgroup/hugetlb.2MB.events'],['bash','-c','find /u01/app/oracle/diag/rdbms -name "alert_*.log" -exec tail -n 35 {} \; 2>/dev/null; tail -n 16 /u01/app/oracle/cfgtoollogs/dbca/RACCDB/RACCDB.log 2>/dev/null']]
 for cmd in commands:
  p=subprocess.run(['kubectl','exec','-n','rac',pod,'--',*cmd],capture_output=True,text=True)
  print(clean(p.stdout));print(clean(p.stderr))
PY
