#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
date -u
ps -eo pid,comm,state,pcpu,pmem --sort=-pcpu | head -15
du -sh /scratch/rac/cluster01/racnode*
df -h /scratch /var/lib/containers
grep -E 'MemAvailable|HugePages|Hugepagesize' /proc/meminfo
journalctl -k --since '-10 min' --no-pager | grep -Ei 'out of memory|oom-kill|killed process|soft lockup|I/O error' || true
