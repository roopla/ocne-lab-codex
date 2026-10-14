#!/bin/bash
# One-time GPT labels for two additional inspected blank shared ASM candidate disks, on worker1 only.
# No filesystem or ASM disk group is created here.
# https://docs.oracle.com/en/operating-systems/oracle-linux/9/stordev/stordev-UsingDiskPartitions.html
set -euo pipefail
[[ $(id -u) == 0 && $(hostname -s) == ocne-w1 ]]
[[ $(cat /etc/machine-id) == 7417ec2ac09a4e3c8439774fc7eaa7e5 ]]
serials=(VBc4bffe32-d7efc6fc VB35658d62-769d5796)
names=(ocne-rac-asm03 ocne-rac-asm04)
disks=()
for i in 0 1; do
 serial=${serials[$i]}
 mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="$serial" '$2==serial {print $1}')
 [[ ${#matches[@]} == 1 ]]
 disk=${matches[0]}
 [[ $(blockdev --getsize64 "$disk") == 53687091200 ]]
 [[ $(lsblk -nrpo NAME "$disk" | wc -l) == 1 ]]
 mounts=$(lsblk -nrpo MOUNTPOINTS "$disk")
 [[ -z "$mounts" ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$disk")
 [[ -z "$signatures" ]]
 [[ -z $(ls -A "/sys/class/block/${disk##*/}/holders") ]]
 [[ ! -e /dev/disk/by-partlabel/${names[$i]} ]]
 disks+=("$disk")
 printf 'Verified blank 50 GiB ASM disk: %s %s\n' "$disk" "$serial"
done
for i in 0 1; do
 disk=${disks[$i]}
 name=${names[$i]}
 parted -s -a optimal "$disk" mklabel gpt mkpart "$name" 1MiB 100%
 partprobe "$disk"
 udevadm settle
 partition=/dev/disk/by-partlabel/$name
 [[ -b $partition ]]
 [[ $(lsblk -nro PKNAME "$partition") == "${disk##*/}" ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$partition")
 [[ -z "$signatures" ]]
 lsblk -b -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,PARTUUID,SERIAL "$disk"
done
