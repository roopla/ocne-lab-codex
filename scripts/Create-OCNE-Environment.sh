set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
cd "$HOME"
olcnectl environment create --api-server ocne-op.lab.test:8091 --environment-name homelab --secret-manager-type file --update-config