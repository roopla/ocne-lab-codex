#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(sysctl -n vm.nr_hugepages) == 3072 ]]
[[ $(awk '/HugePages_Free:/{print $2}' /proc/meminfo) == 3072 ]]
grep -Fx 'vm.nr_hugepages = 3072' /etc/sysctl.d/98-ocne-rac.conf
sed -i 's/^vm.nr_hugepages = 3072$/vm.nr_hugepages = 1024/' /etc/sysctl.d/98-ocne-rac.conf
sysctl -p /etc/sysctl.d/98-ocne-rac.conf
[[ $(sysctl -n vm.nr_hugepages) == 1024 ]]
systemctl restart kubelet
systemctl is-active kubelet
grep -E 'MemAvailable|HugePages|Hugepagesize' /proc/meminfo
