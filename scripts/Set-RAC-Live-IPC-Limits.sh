#!/bin/bash
# Correct only the existing RAC container's namespaced SysV limits.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1) pod=racnode1-0;; ocne-w2) pod=racnode2-0;; *) exit 1;; esac
export RAC_POD="$pod"
python3 <<'PY'
import subprocess,json,os
p=json.loads(subprocess.check_output(['crictl','ps','-o','json']))
c=[c for c in p['containers'] if c.get('labels',{}).get('io.kubernetes.pod.name')==os.environ['RAC_POD'] and c.get('metadata',{}).get('name')==os.environ['RAC_POD']]
assert len(c)==1
info=json.loads(subprocess.check_output(['crictl','inspect',c[0]['id']]))
pid=info['info']['pid']; assert isinstance(pid,int) and pid>1
assert os.readlink(f'/proc/{pid}/ns/ipc')!=os.readlink('/proc/1/ns/ipc')
# Enter IPC only; host procfs remains writable, but these keys affect the target IPC namespace.
cmd=['nsenter','--target',str(pid),'--ipc','sysctl']
subprocess.run(cmd+['-w','kernel.shmall=2097152','kernel.shmmax=8589934592'],check=True)
subprocess.run(cmd+['kernel.shmall','kernel.shmmax'],check=True)
print('Verified target pod:',os.environ['RAC_POD'])
PY
