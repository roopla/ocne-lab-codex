set -euo pipefail
case $(hostname -s) in
 ocne-op) target=/srv/nfs/share; mountpoint -q /srv/nfs;;
 ocne-cp|ocne-w1|ocne-w2) target=/mnt/ocne-share; mountpoint -q "$target";;
 *) exit 1;;
esac
[[ $(id -u) == 1001 && $(getenforce) == Enforcing ]]
for node in ocne-op ocne-cp ocne-w1 ocne-w2; do
 grep -qxF "NFS write from $node" "$target/nfs-check-$node.txt"
 [[ $(stat -c '%u:%g' "$target/nfs-check-$node.txt") == 1001:1001 ]]
done
cat "$target"/nfs-check-*.txt
printf 'All four writes visible with matching ownership on %s\n' "$(hostname -s)"