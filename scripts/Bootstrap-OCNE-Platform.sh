set -euo pipefail
case $(hostname -s) in ocne-op) component=api-server;; ocne-cp|ocne-w1|ocne-w2) component=agent;; *) exit 1;; esac
[[ $(id -u) == 0 && $(getenforce) == Enforcing ]]
certdir=/etc/olcne/certificates
for file in ca.cert node.cert node.key; do test -s "$certdir/$file"; done
openssl verify -CAfile "$certdir/ca.cert" "$certdir/node.cert"
openssl x509 -in "$certdir/node.cert" -noout -subject -dates
stat -c '%a %U:%G %n' "$certdir"/*
/etc/olcne/bootstrap-olcne.sh --secret-manager-type file --olcne-component "$component"
systemctl is-active "olcne-$component.service"
systemctl show "olcne-$component.service" -p ActiveState -p SubState -p Result