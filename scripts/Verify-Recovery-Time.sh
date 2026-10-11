#!/bin/bash
# Read-only acceptance of timekeeping after the 2026-10-09 recovery.
set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
printf 'HOST: %s\n' "$(hostname -s)"
date -u --iso-8601=seconds
cat /proc/sys/kernel/random/boot_id
uptime
systemctl is-active chronyd sshd
chronyc waitsync 6 0.1 0 5
chronyc tracking
chronyc -n sources
failed=$(systemctl --failed --no-legend --plain --no-pager)
[[ -z "$failed" ]] || { printf '%s\n' "$failed"; exit 1; }
if journalctl -b -k --no-pager | grep -Ei 'BUG: soft lockup|rcu.*(stall|starved|timer wakeup)|Out of memory:|Killed process .*total-vm'; then
    echo 'Current boot contains kernel stalls or OOM evidence; investigate.'
    exit 1
fi
[[ $(getenforce) == Enforcing ]]
printf 'Time offset below 100 ms, no failed units or matching current-boot stall/OOM messages.\n'
