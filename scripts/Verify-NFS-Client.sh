set -euo pipefail
case $(hostname -s) in ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
mountpoint -q /mnt/ocne-share
findmnt -M /mnt/ocne-share
[[ $(findmnt -n -o SOURCE -M /mnt/ocne-share) == 192.168.77.10:/srv/nfs/share ]]
findmnt -n -o OPTIONS -M /mnt/ocne-share | grep -q 'vers=4.1'
[[ $(getenforce) == Enforcing && $(nfsidmap -d) == lab.test ]]
uptime -s
cat /proc/sys/kernel/random/boot_id