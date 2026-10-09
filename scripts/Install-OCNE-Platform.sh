#!/bin/bash
# Guide B8-B9, original Oracle OCNE 1.9 installation.
set -euo pipefail
node=$(hostname -s)
case "$node" in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 && $(getenforce) == Enforcing && $(uname -r) == 5.15.*el9uek* ]]
case "$node" in
 ocne-op)
  dnf install -y olcnectl olcne-api-server olcne-utils
  systemctl enable olcne-api-server.service
  usermod -a -G olcne labadmin
  rpm -q olcnectl olcne-api-server olcne-utils
  olcnectl certificates distribute --help
  ;;
 *)
  dnf install -y olcne-agent olcne-utils
  systemctl enable olcne-agent.service
  for svc in docker containerd; do
    if systemctl is-active --quiet "$svc.service"; then systemctl disable --now "$svc.service"; fi
  done
  rpm -q olcne-agent olcne-utils
  ;;
esac
id olcne
sudo -l -U olcne
visudo -c
printf 'Platform packages installed and services enabled; certificates/startup pending\n'