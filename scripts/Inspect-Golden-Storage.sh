set -u
export LC_ALL=C
printf '\nPartition geometry and XFS\n'
parted -sm /dev/sda unit s print free
xfs_info /
blkid /dev/sda1 /dev/sda2
printf '\nDefault kernel\n'
grubby --default-kernel
printf '\nContainer directory entries\n'
find /var/lib/containers -maxdepth 4 -printf '%y %s %p\n'
for path in /root/.local/share/containers /home/alpoor/.local/share/containers; do
    if [ -e "$path" ]; then find "$path" -maxdepth 3 -printf '%y %s %p\n'; else printf 'ABSENT %s\n' "$path"; fi
done
printf '\nGuest Additions and shared folder support\n'
lsmod | grep -E '^vbox'
rpm -qa | grep -Ei 'vbox|virtualbox'
find /opt -maxdepth 2 -type d -name '*VBox*'
printf '\nRelevant OS tools and identities\n'
command -v growpart parted xfs_growfs rsync python3 dnf
getent passwd 1001
getent group 1001
printf '\nTime synchronization\n'
timedatectl show -p NTPSynchronized -p TimeUSec
chronyc tracking
printf '\nDNS lookup\n'
getent ahostsv4 yum.oracle.com container-registry.oracle.com
printf '\nDetailed inspection completed\n'