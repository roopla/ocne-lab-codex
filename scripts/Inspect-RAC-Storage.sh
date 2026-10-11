#!/bin/bash
set -euo pipefail
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
hostname
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINTS,MODEL,SERIAL
findmnt -t xfs,nfs4
while read -r device kind; do
    [[ $kind == disk ]] || continue
    printf '\nSIGNATURES %s\n' "$device"
    wipefs -n "$device"
    udevadm info -q property -n "$device" | grep -e '^ID_SERIAL=' -e '^ID_PATH='
done < <(lsblk -dnpo NAME,TYPE)
ip -br link
nmcli -t -f NAME,UUID,DEVICE,TYPE connection show
for interface in /sys/class/net/enp*; do printf '%s ' "$interface"; cat "$interface/address"; done
command -v parted
command -v mkfs.xfs
