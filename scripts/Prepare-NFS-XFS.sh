#!/bin/bash
# Guide Part D2, observed new VDI 8ca09977-3c8d-4da8-a838-ed001246028d.
set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -u) == 0 ]]
serial=VB8ca09977-8d024612
disk=$(readlink -f "/dev/disk/by-id/ata-VBOX_HARDDISK_$serial")
[[ -b "$disk" && $(lsblk -dn -o SERIAL "$disk") == "$serial" ]]
[[ $(lsblk -dn -o TYPE "$disk") == disk ]]
[[ $(blockdev --getsize64 "$disk") == 107374182400 ]]
[[ $(lsblk -nr -o NAME "$disk" | wc -l) -eq 1 ]]
[[ -z $(lsblk -nr -o MOUNTPOINTS "$disk" | tr -d '[:space:]') ]]
wipefs -n "$disk"
[[ -z $(wipefs -n --noheadings "$disk") ]]
if mountpoint -q /srv/nfs || grep -Eq '^[^#]*[[:space:]]/srv/nfs[[:space:]]' /etc/fstab; then echo 'Existing NFS mount configuration; stop'; exit 1; fi
if [[ -d /srv/nfs ]]; then [[ -z $(ls -A /srv/nfs) ]]; fi
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$disk"
mkfs.xfs "$disk"
uuid=$(blkid -s UUID -o value "$disk")
[[ -n "$uuid" ]]
mkdir -p /srv/nfs
cp -p /etc/fstab "/etc/fstab.before-nfs-$(date +%Y%m%d%H%M%S)"
printf 'UUID=%s /srv/nfs xfs defaults 0 0\n' "$uuid" >> /etc/fstab
systemctl daemon-reload
mount /srv/nfs
mountpoint -q /srv/nfs
xfs_info /srv/nfs
findmnt -M /srv/nfs
df -hT /srv/nfs