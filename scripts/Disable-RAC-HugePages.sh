#!/bin/bash
# User-requested HugePages disable; never reclaim pages from a running consumer.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(awk '/HugePages_Total:/{print $2}' /proc/meminfo) == $(awk '/HugePages_Free:/{print $2}' /proc/meminfo) ]]
[[ $(awk '/HugePages_Rsvd:/{print $2}' /proc/meminfo) == 0 ]]
conf=/etc/sysctl.d/98-ocne-rac.conf
[[ $(grep -Ec '^vm.nr_hugepages = (1536|0)$' "$conf") == 1 ]]
backup=/var/opt/ocne-rac-nohugepages-$(date -u +%Y%m%dT%H%M%SZ)
install -d -m 0700 "$backup"
cp -a "$conf" "$backup/"
sysctl -w vm.nr_hugepages=0
[[ $(sysctl -n vm.nr_hugepages) == 0 ]]
sed -i 's/^vm.nr_hugepages = .*/vm.nr_hugepages = 0/' "$conf"
grep -Fx 'vm.nr_hugepages = 0' "$conf"
grep -E 'MemAvailable|HugePages|Hugepagesize' /proc/meminfo
cat /sys/kernel/mm/transparent_hugepage/enabled
# Kubelet restart is coordinated separately with the pod resource migration.
