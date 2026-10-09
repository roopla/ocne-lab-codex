set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
cd "$HOME"
olcnectl module install --environment-name homelab --name cluster1
olcnectl module report --environment-name homelab --name cluster1 --children