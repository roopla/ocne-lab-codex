set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -u) == 0 && $(getenforce) == Enforcing ]]
mountpoint -q /srv/nfs
[[ $(findmnt -n -o FSTYPE -M /srv/nfs) == xfs ]]
mkdir -p /srv/nfs/share
chown labadmin:labadmin /srv/nfs/share
chmod 0770 /srv/nfs/share
restorecon -Rv /srv/nfs
exportline='/srv/nfs/share 192.168.77.10(rw,sync,root_squash) 192.168.77.11(rw,sync,root_squash) 192.168.77.12(rw,sync,root_squash) 192.168.77.13(rw,sync,root_squash)'
if grep -Eq '^[^#]*[/]srv/nfs/share' /etc/exports; then grep -qxF "$exportline" /etc/exports; else
 cp -p /etc/exports "/etc/exports.before-ocne-nfs-$(date +%Y%m%d%H%M%S)"
 printf '%s\n' "$exportline" >> /etc/exports
fi
iface=$(ip -o route show default | awk '{print $5;exit}')
zone=$(firewall-cmd --get-zone-of-interface "$iface")
[[ "$zone" == public ]]
firewall-cmd --zone="$zone" --add-service=nfs
firewall-cmd --permanent --zone="$zone" --add-service=nfs
systemctl daemon-reload
systemctl enable --now nfs-server
exportfs -ra
exportfs -v
cat /proc/fs/nfsd/versions
grep -q '+4.1' /proc/fs/nfsd/versions
systemctl show nfs-server -p RequiresMountsFor -p Requires -p After
getsebool nfs_export_all_rw
findmnt -M /srv/nfs