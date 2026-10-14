#!/bin/bash
# Oracle RAC/OCNE prerequisites, locally sized for 22 GiB workers.
set -euo pipefail
[[ $(id -u) == 0 && $(getenforce) == Enforcing ]]
read -r -p 'Recorded XFS UUID for this worker scratch disk: ' uuid
[[ -n $uuid ]]
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(findmnt -nro FSTYPE -M /scratch) == xfs ]]
[[ $(wc -l < /proc/swaps) == 1 ]]
[[ $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource) == tsc ]]
for path in /etc/sysctl.d/98-ocne-rac.conf /var/opt/rac-ocne.te /scratch/rac/cluster01; do
 [[ ! -e $path ]] || { echo "Existing prerequisite asset: $path; inspect before continuing."; exit 1; }
done
cat /etc/sysconfig/kubelet
rpm -q selinux-policy-devel policycoreutils-python-utils
backup=/var/opt/ocne-rac-backup-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup"
cp -a /etc/sysconfig/kubelet /etc/default/grub "$backup/"
grubby --info=ALL > "$backup/grubby-before.txt"
sysctl fs.file-max net.core.rmem_default net.core.rmem_max net.core.wmem_default net.core.wmem_max fs.aio-max-nr vm.nr_hugepages > "$backup/sysctl-before.txt"
cat > /etc/sysctl.d/98-ocne-rac.conf <<'SYSCTL'
# Oracle RAC on OCNE kernel prerequisites; HugePages disabled by user request.
fs.file-max = 6815744
net.core.rmem_default = 262144
net.core.rmem_max = 4194304
net.core.wmem_default = 262144
net.core.wmem_max = 1048576
fs.aio-max-nr = 1048576
vm.nr_hugepages = 0
SYSCTL
sysctl -p /etc/sysctl.d/98-ocne-rac.conf
[[ $(sysctl -n vm.nr_hugepages) == 0 ]]
# Oracle recommends disabling THP; use grubby for OL9 boot entries.
grubby --update-kernel=ALL --args='transparent_hugepage=never'
printf 'never\n' > /sys/kernel/mm/transparent_hugepage/enabled
python3 <<'KUBELET'
from pathlib import Path
import re
p=Path('/etc/sysconfig/kubelet'); text=p.read_text()
matches=list(re.finditer(r'^KUBELET_EXTRA_ARGS="([^"\n]*)"$',text,re.M))
assert len(matches)==1, 'Inspect kubelet file format before editing'
m=matches[0]; current=m.group(1)
assert '--allowed-unsafe-sysctls' not in current, 'Inspect existing sysctl allowance'
updated=current+' --allowed-unsafe-sysctls=kernel.shm*,net.*,kernel.sem'
p.write_text(text[:m.start()]+'KUBELET_EXTRA_ARGS="'+updated+'"'+text[m.end():])
KUBELET
cat > /var/opt/rac-ocne.te <<'POLICY'
module rac-ocne 1.0;
require {
 type kernel_t;
 class system syslog_read;
 type container_runtime_t;
 type container_init_t;
 type container_file_t;
 type lib_t;
 type textrel_shlib_t;
 type bin_t;
 class file { getattr execmod execute map setattr };
}
allow container_init_t container_runtime_t:file getattr;
allow container_init_t bin_t:file { map execute };
allow container_init_t container_file_t:file execmod;
allow container_init_t lib_t:file execmod;
allow container_init_t textrel_shlib_t:file setattr;
allow container_init_t kernel_t:system syslog_read;
POLICY
cd /var/opt
make -f /usr/share/selinux/devel/Makefile rac-ocne.pp
semodule -i rac-ocne.pp
for n in 1 2; do install -d -m 0755 -o 54321 -g 54321 /scratch/rac/cluster01/racnode$n; done
semanage fcontext -a -t container_file_t '/scratch/rac/cluster01(/.*)?'
semanage fcontext -a -t container_file_t '/scratch/software/stage(/.*)?'
restorecon -RF /scratch/rac/cluster01 /scratch/software/stage
systemctl daemon-reload
systemctl restart kubelet
systemctl is-active kubelet
semodule -l | grep '^rac-ocne'
getent passwd 54321 || true
ls -Zd /scratch/rac/cluster01/racnode{1,2} /scratch/software/stage
grep -E 'MemTotal|MemAvailable|HugePages|Hugepagesize' /proc/meminfo
cat /sys/kernel/mm/transparent_hugepage/enabled
printf 'RAC worker settings applied; backup: %s\n' "$backup"
