set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
uname -r
cat /etc/machine-id
findmnt -T /var
df -hT /var
case $(hostname -s) in
  ocne-w1|ocne-w2)
    mountpoint -q /var/lib/containers
    [[ $(findmnt -n -o FSTYPE -M /var/lib/containers) == xfs ]]
    findmnt -M /var/lib/containers
    df -hT /var/lib/containers
    ;;
esac
[[ $(getenforce) == Enforcing ]]
printf 'Storage mounts verified after restart\n'