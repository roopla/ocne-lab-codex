set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -u) == 0 ]]
mountpoint -q /srv/nfs
[[ $(findmnt -n -o FSTYPE -M /srv/nfs) == xfs ]]
findmnt -M /srv/nfs
df -hT /srv/nfs
systemctl is-active nfs-server olcne-api-server
exportfs -v
grep -q '+4.1' /proc/fs/nfsd/versions
[[ $(getenforce) == Enforcing ]]
[[ $(nfsidmap -d) == lab.test ]]
uptime -s
cat /proc/sys/kernel/random/boot_id