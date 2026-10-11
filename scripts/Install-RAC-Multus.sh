#!/bin/bash
# Oracle OCNE 1.9 Multus module workflow (not a replacement cluster installation).
# https://docs.oracle.com/en/operating-systems/olcne/1.9/multus/install.html
set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
instances=$(olcnectl module instances --environment-name homelab)
printf '%s\n' "$instances"
printf '%s\n' "$instances" | awk '$1=="cluster1" && $2=="kubernetes" && $3=="installed" {found=1} END {exit !found}'
if printf '%s\n' "$instances" | awk '$1=="rac-multus" {found=1} END {exit !found}'; then
 echo 'rac-multus already exists; inspect its state and resume only the required step.'
 exit 1
fi
olcnectl module create --environment-name homelab --module multus --name rac-multus --multus-kubernetes-module cluster1
olcnectl module install --environment-name homelab --name rac-multus
instances=$(olcnectl module instances --environment-name homelab)
printf '%s\n' "$instances"
printf '%s\n' "$instances" | awk '$1=="rac-multus" && $2=="multus" && $3=="installed" {found=1} END {exit !found}'
olcnectl module report --environment-name homelab --name rac-multus --children
