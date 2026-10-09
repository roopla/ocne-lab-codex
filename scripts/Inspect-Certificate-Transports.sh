set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -u) == 0 ]]
python3 - <<'PY'
from pathlib import Path
import os,signal
for pid in (35138,35141,35142):
 p=Path(f'/proc/{pid}/cmdline')
 if not p.exists(): continue
 a=p.read_bytes().split(b'\0')
 if not a[0]:
  print(f'PID {pid} exited'); continue
 hosts=[h for h in ('ocne-cp.lab.test','ocne-w1.lab.test','ocne-w2.lab.test') if any(h.encode() in x for x in a)]
 print(f'PID {pid}: executable={Path(a[0].decode()).name}, recognized destinations={hosts}')
 if Path(a[0].decode()).name=='ssh' and hosts:
  os.kill(pid,signal.SIGTERM)
  print('Stopped confirmed orphaned certificate transport')
PY