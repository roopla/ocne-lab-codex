set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
olcnectl module report --environment-name homelab --name cluster1 --children