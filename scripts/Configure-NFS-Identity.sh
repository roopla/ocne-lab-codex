set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u labadmin) == 1001 && $(id -g labadmin) == 1001 && $(getenforce) == Enforcing ]]
rpm -q nfs-utils || dnf install -y nfs-utils
python3 - <<'PY'
from pathlib import Path
import re, shutil
p=Path('/etc/idmapd.conf')
s=p.read_text(); lines=s.splitlines(keepends=True)
sections=[i for i,l in enumerate(lines) if re.match(r'^\s*\[General\]\s*$',l)]
assert len(sections)==1, 'Expected one General section'
a=sections[0]; b=next((i for i in range(a+1,len(lines)) if re.match(r'^\s*\[',lines[i])),len(lines))
active=[i for i in range(a+1,b) if re.match(r'^\s*Domain\s*=',lines[i])]
assert len(active)<=1, 'Duplicate Domain settings; inspect'
backup=Path('/etc/idmapd.conf.before-ocne-nfs')
if not backup.exists(): shutil.copy2(p,backup)
if active: lines[active[0]]='Domain = lab.test\n'
else: lines.insert(a+1,'Domain = lab.test\n')
p.write_text(''.join(lines))
PY
nfsidmap -d
[[ $(nfsidmap -d) == lab.test ]]
id labadmin