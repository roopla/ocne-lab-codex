set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
id
cd "$HOME"
[[ ! -e certificates ]] || { echo 'Existing PKI: inspect before retry'; exit 1; }
umask 077
olcnectl certificates distribute --nodes ocne-op.lab.test,ocne-cp.lab.test,ocne-w1.lab.test,ocne-w2.lab.test --ssh-identity-file "$HOME/.ssh/id_rsa" --ssh-login-name labadmin