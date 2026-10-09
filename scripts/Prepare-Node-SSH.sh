set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -un) == labadmin ]]
cd "$HOME"
umask 077
mkdir -p .ssh
if [[ ! -e .ssh/id_rsa && ! -e .ssh/id_rsa.pub ]]; then ssh-keygen -q -t rsa -b 3072 -N '' -f .ssh/id_rsa -C "labadmin@$(hostname)"; fi
test -s .ssh/id_rsa.pub
ssh-keygen -lf .ssh/id_rsa.pub
cat .ssh/id_rsa.pub