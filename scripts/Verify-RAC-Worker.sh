#!/bin/bash
# Read-only prerequisite verification on the prepared workers; no installer execution.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) uuid=48e2e0e8-d37d-4262-a2d3-67b40eacf76b; container_uuid=1ca6c397-b848-4e95-a24a-a96ea11a55cc;;
 ocne-w2) uuid=8d744a6a-39bf-4cb4-9ab3-739dbff7c319; container_uuid=50e55c0d-a63c-41c4-b66c-7a46cae288ab;;
 *) exit 1;;
esac
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(findmnt -nro UUID -M /var/lib/containers) == "$container_uuid" ]]
[[ $(getenforce) == Enforcing ]]
[[ $(wc -l < /proc/swaps) == 1 ]]
[[ $(cat /sys/devices/system/clocksource/clocksource0/current_clocksource) == tsc ]]
[[ $(sysctl -n vm.nr_hugepages) == 1536 ]]
grep -F '[never]' /sys/kernel/mm/transparent_hugepage/enabled
[[ $(awk '/Hugepagesize:/{print $2}' /proc/meminfo) == 2048 ]]
grep -F -- '--allowed-unsafe-sysctls=kernel.shm*,net.*,kernel.sem' /etc/sysconfig/kubelet
semodule -l | grep '^rac-ocne'
for pair in fs.file-max:6815744 net.core.rmem_default:262144 net.core.rmem_max:4194304 net.core.wmem_default:262144 net.core.wmem_max:1048576 fs.aio-max-nr:1048576; do
 [[ $(sysctl -n "${pair%:*}") == "${pair#*:}" ]]
done
for n in 1 2; do
 if [[ $n == 1 ]]; then iface=enp0s8; else iface=enp0s9; fi
 [[ $(nmcli -g 802-3-ethernet.accept-all-mac-addresses connection show ocne-rac-private$n) == 1 ]]
 ip -d link show "$iface" | grep PROMISC
 [[ -z $(ip -4 -o addr show dev "$iface") ]]
 [[ $(stat -c '%u:%g' /scratch/rac/cluster01/racnode$n) == 54321:54321 ]]
 ls -Zd /scratch/rac/cluster01/racnode$n | grep container_file_t
done
chronyc waitsync 12 0.1 0 5
systemctl is-active kubelet crio chronyd firewalld
findmnt -M /mnt/ocne-share
grep -E 'MemTotal|MemAvailable|HugePages|Hugepagesize' /proc/meminfo
printf 'boot_id='; cat /proc/sys/kernel/random/boot_id
printf 'kernel='; uname -r
printf 'Persistent worker prerequisite checks passed. Gold media, image and CVU are separate gates.\n'
