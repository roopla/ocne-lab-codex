#!/bin/bash
# Local clone provisioning; documented in cloning guide adaptation appendix.
set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
rootdev=$(findmnt -n -o SOURCE /)
[[ $(findmnt -n -o FSTYPE /) == xfs ]]
[[ $(blkid -s UUID -o value "$rootdev") == 7ca3aaf4-86fd-4ec7-83f8-1e7e18f27651 ]]
part=${rootdev##*/}
[[ $(cat "/sys/class/block/$part/partition") == 2 ]]
[[ $(cat "/sys/class/block/$part/start") == 2099200 ]]
disk=/dev/$(lsblk -dn -o PKNAME "$rootdev")
[[ -b "$disk" && $(blockdev --getsize64 "$disk") == 107374182400 ]]
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL "$disk"
parted -sm "$disk" unit s print free
if [[ $(df -B1 --output=avail /var | tail -1) -ge 42949672960 ]]; then
  echo 'Root already has at least 40 GiB available; no growth needed'; exit 0
fi
[[ $(cat "/sys/class/block/$part/size") == 79691776 ]] || { echo 'Unexpected partition size; inspect partial growth'; exit 1; }
command -v growpart || dnf -y --disablerepo='*' --enablerepo=ol9_baseos_latest,ol9_appstream install cloud-utils-growpart
[[ ! -e /root/ocne-root-partition-before.sfdisk ]]
sfdisk --dump "$disk" > /root/ocne-root-partition-before.sfdisk
chmod 600 /root/ocne-root-partition-before.sfdisk
growpart -N "$disk" 2
growpart "$disk" 2
udevadm settle
[[ $(cat "/sys/class/block/$part/start") == 2099200 ]]
[[ $(cat "/sys/class/block/$part/size") -gt 79691776 ]]
xfs_growfs -d /
[[ $(df -B1 --output=avail /var | tail -1) -ge 42949672960 ]]
df -hT / /var
xfs_info /
printf 'Clone root expansion verified\n'