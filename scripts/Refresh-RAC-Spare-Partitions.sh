#!/bin/bash
# Refresh only the two identified new disks; do not create a second partition table.
set -euo pipefail
[[ $(id -u) == 0 && $(hostname -s) == ocne-w2 ]]
serials=(VBc4bffe32-d7efc6fc VB35658d62-769d5796)
names=(ocne-rac-asm03 ocne-rac-asm04)
uuids=(4ada60ba-ae3c-45b0-9a86-aa656fbb57e6 1bd08689-797c-4d7b-834c-cee370025d39)
for i in 0 1; do
 mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="${serials[$i]}" '$2==serial {print $1}')
 [[ ${#matches[@]} == 1 ]]
 disk=${matches[0]}
 [[ $(blockdev --getsize64 "$disk") == 53687091200 ]]
 partprobe "$disk"
 udevadm settle
 part=/dev/disk/by-partlabel/${names[$i]}
 [[ -b $part && $(blkid -s PARTUUID -o value "$part") == "${uuids[$i]}" ]]
 [[ $(lsblk -nro PKNAME "$part") == "${disk##*/}" ]]
 [[ -z $(wipefs -n --noheadings --output TYPE "$part") ]]
 [[ -z $(lsblk -nro MOUNTPOINTS "$part") ]]
 lsblk -b -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,PARTUUID,SERIAL "$disk"
done
