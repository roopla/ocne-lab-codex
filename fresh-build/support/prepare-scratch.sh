#!/bin/bash
# One-time local provisioning using the inspected new scratch-disk serials.
# XFS/mount procedure: Oracle Linux filesystem sources cited in guide Part D.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
read -r -p 'Verified NEW 128 GiB scratch disk serial: ' serial
[[ -n "$serial" ]]
label=rac-scratch
mapfile -t matches < <(lsblk -dnpo NAME,SERIAL | awk -v serial="$serial" '$2==serial {print $1}')
[[ ${#matches[@]} == 1 ]] || { echo 'Expected exactly one scratch serial'; exit 1; }
disk=${matches[0]}
[[ $(blockdev --getsize64 "$disk") == 137438953472 ]]
[[ $(lsblk -dnro TYPE "$disk") == disk ]]
[[ $(lsblk -nrpo NAME "$disk" | wc -l) == 1 ]]
[[ -z $(lsblk -nrpo MOUNTPOINTS "$disk") ]]
signatures=$(wipefs --no-act --noheadings --output TYPE "$disk")
[[ -z "$signatures" ]]
[[ -z $(ls -A "/sys/class/block/${disk##*/}/holders") ]]
! findmnt -rn -S "$disk" >/dev/null
! mountpoint -q /scratch
! awk '$1 !~ /^#/ && $2=="/scratch" {found=1} END {exit !found}' /etc/fstab
[[ ! -e /scratch || ( -d /scratch && -z $(ls -A /scratch) ) ]]
printf 'Identified blank scratch device: %s serial=%s\n' "$disk" "$serial"
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$disk"
mkfs.xfs -L "$label" "$disk"
uuid=$(blkid -s UUID -o value "$disk")
[[ $uuid =~ ^[0-9a-f-]{36}$ && $(blkid -s TYPE -o value "$disk") == xfs ]]
cp -a /etc/fstab "/etc/fstab.before-rac-scratch-$(date +%Y%m%d%H%M%S)"
mkdir -p /scratch
printf 'UUID=%s /scratch xfs defaults 0 0\n' "$uuid" >> /etc/fstab
systemctl daemon-reload
mount /scratch
[[ $(findmnt -nro UUID -M /scratch) == "$uuid" ]]
[[ $(findmnt -nro FSTYPE -M /scratch) == xfs ]]
findmnt -n -o SOURCE,UUID,FSTYPE,TARGET -M /scratch
df -h /scratch
printf 'Scratch mounted; ASM disks and existing root/container filesystems were not modified.\n'
