set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
id labadmin
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,MODEL,SERIAL
ls -l /dev/disk/by-id/
for disk in $(lsblk -dn -o PATH,TYPE | awk '$2=="disk" {print $1}'); do wipefs -n "$disk"; done
rpm -q nfs-utils || true
if [[ -f /etc/idmapd.conf ]]; then sed -n '1,85p' /etc/idmapd.conf; fi
if [[ -f /etc/exports ]]; then cat /etc/exports; fi
if [[ -d /etc/exports.d ]]; then find /etc/exports.d -type f -maxdepth 1; fi
findmnt -M /srv/nfs || true
findmnt -M /mnt/ocne-share || true
systemctl show nfs-server.service -p ActiveState -p SubState || true
getenforce