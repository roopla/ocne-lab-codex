#!/bin/bash
# Cloning guide section 10, Oracle OL9 XFS and fstab manuals.
set -euo pipefail
case $(hostname -s) in
  ocne-w1) serial=VB7ccb5a40-510bce8c ;;
  ocne-w2) serial=VB447ca102-bbeaa08c ;;
  *) echo 'Not an inspected worker'; exit 1 ;;
esac
link="/dev/disk/by-id/ata-VBOX_HARDDISK_$serial"
disk=$(readlink -f -- "$link")
[[ -b "$disk" ]]
[[ $(lsblk -dn -o SERIAL "$disk") == "$serial" ]]
[[ $(lsblk -dn -o TYPE "$disk") == disk ]]
[[ $(blockdev --getsize64 "$disk") == 107374182400 ]]
[[ $(lsblk -nr -o NAME "$disk" | wc -l) -eq 1 ]]
[[ -z $(lsblk -nr -o MOUNTPOINTS "$disk" | tr -d '[:space:]') ]]
wipefs -n "$disk"
[[ -z $(wipefs -n --noheadings "$disk") ]]
target=/var/lib/containers
backup=/var/lib/containers.before-ocne-xfs
if mountpoint -q "$target" || grep -Eq '^[^#]*[[:space:]]/var/lib/containers[[:space:]]' /etc/fstab; then
  echo 'Existing container mount/configuration; inspect instead of formatting'; exit 1
fi
[[ ! -e "$backup" ]]
if [[ -d "$target" ]]; then
  [[ -z $(find "$target" -mindepth 1 ! -type d -print -quit) ]] || { echo 'Existing container data; stop'; exit 1; }
  while IFS= read -r entry; do
    case "$entry" in sigstore|storage|storage/tmp) ;; *) echo "Unexpected directory: $entry"; exit 1;; esac
  done < <(find "$target" -mindepth 1 -printf '%P\n')
fi
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$disk"
mkfs.xfs "$disk"
uuid=$(blkid -s UUID -o value "$disk")
[[ -n "$uuid" ]]
if [[ -d "$target" ]]; then mv "$target" "$backup"; fi
mkdir -p "$target"
cp -p /etc/fstab /etc/fstab.before-ocne-container-xfs
printf 'UUID=%s %s xfs defaults 0 0\n' "$uuid" "$target" >> /etc/fstab
systemctl daemon-reload
mount "$target"
mountpoint -q "$target"
if [[ -d "$backup" ]]; then rsync -aHAX "$backup/" "$target/"; fi
restorecon -Rv "$target"
findmnt -M "$target"
xfs_info "$target"
df -hT /var "$target"
printf 'Dedicated worker XFS verified; reboot persistence still pending\n'