set -euo pipefail
case $(hostname -s) in ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 ]]
mountpoint -q /mnt/ocne-share
if touch /mnt/ocne-share/ocne-root-squash-check; then
 echo 'Unexpected remote root write access; investigate'
 exit 1
fi
printf 'Remote root write denied as expected; labadmin write tested separately\n'
grep -F '192.168.77.10:/srv/nfs/share' /etc/fstab