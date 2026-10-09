set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
cd "$HOME"
umask 077
[[ ! -e "$HOME/.olcne/certificates/ocne-op.lab.test:8091/node.key" ]]
olcnectl certificates generate --nodes ocne-op.lab.test,192.168.77.10 --cert-dir "$HOME/.olcne/certificates/ocne-op.lab.test:8091/" --byo-ca-cert "$HOME/certificates/ca/ca.cert" --byo-ca-key "$HOME/certificates/ca/ca.key" --one-cert
cp "$HOME/certificates/ca/ca.cert" "$HOME/.olcne/certificates/ocne-op.lab.test:8091/"
[[ ! -e "$HOME/certificates/restrict_external_ip/node.key" ]]
olcnectl certificates generate --nodes externalip-validation-webhook-service.externalip-validation-system.svc,externalip-validation-webhook-service.externalip-validation-system.svc.cluster.local --cert-dir "$HOME/certificates/restrict_external_ip/" --byo-ca-cert "$HOME/certificates/ca/ca.cert" --byo-ca-key "$HOME/certificates/ca/ca.key" --one-cert
cp "$HOME/certificates/ca/ca.cert" "$HOME/certificates/restrict_external_ip/"
openssl verify -CAfile "$HOME/certificates/ca/ca.cert" "$HOME/.olcne/certificates/ocne-op.lab.test:8091/node.cert" "$HOME/certificates/restrict_external_ip/node.cert"