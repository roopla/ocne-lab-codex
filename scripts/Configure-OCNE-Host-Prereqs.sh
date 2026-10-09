#!/bin/bash
# Guide B3-B6; Oracle OCNE 1.9 prerequisites, non-HA Flannel/firewalld branch.
set -euo pipefail
node=$(hostname -s)
case "$node" in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
[[ $(id -u) == 0 && $(getenforce) == Enforcing ]]
systemctl is-active --quiet firewalld
zone=$(firewall-cmd --get-default-zone)
iface=$(ip -o route show default | awk '{print $5;exit}')
assigned=$(firewall-cmd --get-zone-of-interface "$iface")
[[ "$assigned" == "$zone" ]] || { echo 'Default-zone commands do not match active interface; inspect'; exit 1; }
if [[ "$node" == ocne-op ]]; then
  firewall-cmd --add-port=8091/tcp --permanent
  systemctl restart firewalld.service
  firewall-cmd --query-port=8091/tcp
else
  swapoff -a
  [[ -e /etc/fstab.before-ocne-swap ]] || cp -p /etc/fstab /etc/fstab.before-ocne-swap
  sed -i '/\bswap\b/s/^/#/' /etc/fstab
  [[ -z $(swapon --show --noheadings) ]]
  firewall-cmd --zone=trusted --add-interface=cni0 --permanent
  for port in 8090/tcp 10250/tcp 10255/tcp 8472/udp; do firewall-cmd --add-port="$port" --permanent; done
  if [[ "$node" == ocne-cp ]]; then firewall-cmd --add-port=6443/tcp --permanent; fi
  systemctl restart firewalld.service
  nft list chain inet firewalld filter_FORWARD_POLICIES_post
  install -d -m 0755 /etc/nftables
  if [[ -e /etc/nftables/forward-policies.nft || -e /etc/systemd/system/forward-policies.service ]]; then
    echo 'Existing forward policies configuration: review before changing'; exit 1
  fi
  cat > /etc/nftables/forward-policies.nft <<'NFT'
flush chain inet firewalld filter_FORWARD_POLICIES_post

table inet firewalld {
        chain filter_FORWARD_POLICIES_post {
                accept
        }
}
NFT
  cat > /etc/systemd/system/forward-policies.service <<'UNIT'
[Unit]
Description=Idempotent nftables rules for forward-policies
PartOf=firewalld.service

[Service]
ExecStart=/sbin/nft -f /etc/nftables/forward-policies.nft
ExecReload=/sbin/nft -f /etc/nftables/forward-policies.nft
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  nft -c -f /etc/nftables/forward-policies.nft
  systemctl enable forward-policies.service
  systemctl restart forward-policies.service
  nft list chain inet firewalld filter_FORWARD_POLICIES_post
  systemctl show forward-policies.service -p ActiveState -p SubState -p Result -p ExecMainStatus
  if ! lsmod | grep -q '^br_netfilter '; then
    modprobe br_netfilter
    [[ -e /etc/modules-load.d/br_netfilter.conf ]] || printf 'br_netfilter\n' > /etc/modules-load.d/br_netfilter.conf
  fi
  lsmod | grep '^br_netfilter '
fi
firewall-cmd --list-all
printf 'Role-specific prerequisites applied; SELinux remains %s\n' "$(getenforce)"