set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -u) == 0 ]]
# Copy's commands finished and all four certificates/services verified independently.
# Stop only the observed stuck copy invocation and its identified orphaned SSH transports.
python3 - <<'PY'
from pathlib import Path
import os,signal
p=Path('/proc/35086/cmdline')
if p.exists():
 a=p.read_bytes().split(b'\0')
 if a[:3] != [b'olcnectl',b'certificates',b'copy']:
  raise SystemExit('PID identity changed; not stopping it')
 os.kill(35086, signal.SIGTERM)
 print('Stopped stalled certificates copy process after independent verification')
for pid in (35138,35141,35142):
 p=Path(f'/proc/{pid}/cmdline')
 if p.exists():
  a=p.read_bytes().split(b'\0')
  if a[0] not in (b'ssh',b'/usr/bin/ssh') or not any(x in (b'ocne-cp.lab.test',b'ocne-w1.lab.test',b'ocne-w2.lab.test') for x in a):
   raise SystemExit(f'PID {pid} identity changed; inspect')
  os.kill(pid, signal.SIGTERM)
  print(f'Stopped orphaned certificate SSH transport {pid}')
PY