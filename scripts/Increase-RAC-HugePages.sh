#!/bin/bash
# Increase unused lab HugePages to 3 GiB; no RAC workloads may exist.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(awk '/Hugepagesize:/{print $2}' /proc/meminfo) == 2048 ]]
[[ $(awk '/HugePages_Total:/{print $2}' /proc/meminfo) == $(awk '/HugePages_Free:/{print $2}' /proc/meminfo) ]]
[[ $(awk '/HugePages_Rsvd:/{print $2}' /proc/meminfo) == 0 ]]
current=$(sysctl -n vm.nr_hugepages)
[[ $current == 1024 || $current == 1536 ]]
conf=/etc/sysctl.d/98-ocne-rac.conf
[[ $(grep -Ec '^vm.nr_hugepages = (1024|1536)$' "$conf") == 1 ]]
backup=/var/opt/ocne-rac-hugepages-backup-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup"
cp -a "$conf" "$backup/"
sysctl -w vm.nr_hugepages=1536
[[ $(sysctl -n vm.nr_hugepages) == 1536 ]] || { echo 'Reservation incomplete; inspect before continuing.'; exit 1; }
sed -i 's/^vm.nr_hugepages = .*/vm.nr_hugepages = 1536/' "$conf"
grep -Fx 'vm.nr_hugepages = 1536' "$conf"
systemctl restart kubelet
systemctl is-active kubelet crio
grep -E 'MemAvailable|HugePages|Hugepagesize' /proc/meminfo
printf 'Backup: %s\n' "$backup"
