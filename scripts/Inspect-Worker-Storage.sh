set -euo pipefail
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL
ls -l /dev/disk/by-id/
while read -r device type; do
  if [[ "$type" == disk ]]; then printf 'Signatures: %s\n' "$device"; wipefs -n "$device"; fi
done < <(lsblk -dnpo NAME,TYPE)
findmnt -M /var/lib/containers || test $? = 1
find /var/lib/containers -maxdepth 4 -printf '%y %s %p\n'