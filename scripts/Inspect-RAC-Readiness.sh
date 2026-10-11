#!/bin/bash
# Read-only RAC readiness diagnostics. No restart, package, storage or network mutation.
set -u
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]] || exit 1
printf '\nHOST AND TIME\n'
hostname
date -u --iso-8601=seconds
uptime
timedatectl
chronyc tracking
chronyc sources -v
printf '\nSERVICE STATE\n'
systemctl --failed --no-pager
systemctl show systemd-journald systemd-logind systemd-udevd sshd chronyd -p Id -p ActiveState -p SubState -p Result -p ExecMainCode -p ExecMainStatus -p NRestarts
printf '\nRECENT SERVICE ERRORS\n'
journalctl --no-pager -n 100 -p warning -u sshd -u chronyd -u systemd-journald -u systemd-logind -u systemd-udevd
printf '\nKERNEL WARNINGS\n'
journalctl -k --no-pager -n 70 -p warning
printf '\nCOREDUMP EXECUTABLE LIST ONLY\n'
coredumpctl --no-pager list
printf '\nNFS STATE\n'
findmnt -t nfs,nfs4,xfs
printf '\nMEMORY AND CLOCK SOURCE\n'
grep -e MemTotal -e MemAvailable -e HugePages -e Hugepagesize /proc/meminfo
cat /sys/devices/system/clocksource/clocksource0/current_clocksource
cat /sys/devices/system/clocksource/clocksource0/available_clocksource
printf '\nREAD-ONLY DIAGNOSTICS COMPLETE\n'
