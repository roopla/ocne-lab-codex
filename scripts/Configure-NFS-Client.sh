set -euo pipefail
case $(hostname -s) in ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(getenforce) == Enforcing && $(id -u labadmin) == 1001 && $(id -g labadmin) == 1001 ]]
mkdir -p /mnt/ocne-share
if ! mountpoint -q /mnt/ocne-share; then
 [[ -z $(ls -A /mnt/ocne-share) ]] || { echo 'Mount directory has existing data'; exit 1; }
 mount -t nfs -o rw,vers=4.1,hard,nosuid 192.168.77.10:/srv/nfs/share /mnt/ocne-share
fi
[[ $(findmnt -n -o SOURCE -M /mnt/ocne-share) == 192.168.77.10:/srv/nfs/share ]]
entry='192.168.77.10:/srv/nfs/share /mnt/ocne-share nfs rw,vers=4.1,hard,nosuid,_netdev 0 0'
if grep -Eq '^[^#]*[[:space:]]/mnt/ocne-share[[:space:]]' /etc/fstab; then grep -qxF "$entry" /etc/fstab; else
 cp -p /etc/fstab "/etc/fstab.before-ocne-nfs-$(date +%Y%m%d%H%M%S)"
 printf '%s\n' "$entry" >> /etc/fstab
fi
systemctl daemon-reload
mountpoint -q /mnt/ocne-share
findmnt -M /mnt/ocne-share
df -hT /mnt/ocne-share