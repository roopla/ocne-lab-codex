#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
python3 <<'PY'
import subprocess
for pod in ('racnode1-0','racnode2-0'):
 print(pod)
 cmds=[['ps','-eo','pid,comm,state'],['systemctl','list-units','--all','--no-pager','*oracle*','*rac*'],['bash','-c','ls -la /tmp/orod; find /u01/app/oraInventory/logs -maxdepth 2 -name "*.err"; test ! -e /etc/oracle/ocr.loc; echo ocr_absent=$?'],['bash','-c','sed -n "545,590p" /opt/scripts/startup/scripts/orasetupenv.py; sed -n "900,960p" /opt/scripts/startup/scripts/orasetupenv.py']]
 for cmd in cmds:
  p=subprocess.run(['kubectl','exec','-n','rac',pod,'--']+cmd,capture_output=True,text=True)
  print(p.stdout)
PY
