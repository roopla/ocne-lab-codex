#!/bin/bash
set -euo pipefail
case $(hostname -s) in ocne-w1|ocne-w2) ;; *) exit 1;; esac
for number in 1 2; do
 if [[ $number == 1 ]]; then iface=enp0s8; else iface=enp0s9; fi
 profile=ocne-rac-private$number
 [[ $(nmcli -g connection.interface-name connection show "$profile") == "$iface" ]]
 [[ $(nmcli -g ipv4.method connection show "$profile") == disabled ]]
 nmcli connection modify "$profile" 802-3-ethernet.accept-all-mac-addresses 1
 # This NetworkManager property takes effect at next activation; set runtime below.
 ip link set dev "$iface" promisc on
 nmcli -g 802-3-ethernet.accept-all-mac-addresses connection show "$profile"
 ip -d link show "$iface" | grep PROMISC
done
