#!/bin/bash
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
serials=(VBdb34f551-507d0f5a VBc280454f-7e0f28bc)
names=(ocne-rac-asm01 ocne-rac-asm02)
uuids=(c25151a5-4557-444f-916f-cc359f3fd43b 14cb5bdb-e6ff-4706-b82f-b0f748df5157)
for i in 0 1; do
 mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="${serials[$i]}" '$2==serial {print $1}')
 [[ ${#matches[@]} == 1 ]]
 disk=${matches[0]}
 [[ $(blockdev --getsize64 "$disk") == 53687091200 ]]
 partprobe "$disk"
 udevadm settle
 partition=/dev/disk/by-partlabel/${names[$i]}
 [[ -b $partition ]]
 [[ $(lsblk -nro PKNAME "$partition") == "${disk##*/}" ]]
 [[ $(blkid -s PARTUUID -o value "$partition") == "${uuids[$i]}" ]]
 signatures=$(wipefs --no-act --noheadings --output TYPE "$partition")
 [[ -z "$signatures" ]]
 [[ -z $(lsblk -nro MOUNTPOINTS "$partition") ]]
 printf '%s %s %s\n' "$(hostname -s)" "${serials[$i]}" "${uuids[$i]}"
 dd if="$disk" bs=1M count=1 status=none | sha256sum
 lsblk -b -o NAME,SIZE,TYPE,FSTYPE,PARTLABEL,PARTUUID,SERIAL "$disk"
done
