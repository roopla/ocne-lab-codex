set -euo pipefail
case $(hostname -s) in
 ocne-op) target=/srv/nfs/share; mountpoint -q /srv/nfs;;
 ocne-cp|ocne-w1|ocne-w2) target=/mnt/ocne-share; mountpoint -q "$target";;
 *) exit 1;;
esac
[[ $(id -u) == 1001 && $(id -g) == 1001 ]]
printf 'NFS write from %s\n' "$(hostname -s)" > "$target/nfs-check-$(hostname -s).txt"
sync "$target/nfs-check-$(hostname -s).txt"
stat -c '%u:%g %a %n' "$target/nfs-check-$(hostname -s).txt"