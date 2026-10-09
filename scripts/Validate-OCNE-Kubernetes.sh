set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
cd "$HOME"
olcnectl module validate --environment-name homelab --name cluster1