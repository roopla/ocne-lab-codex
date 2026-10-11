#!/bin/bash
# Observed VirtualBox NIC identities; isolated, unnumbered MACVLAN parent links.
# Oracle RAC controller prerequisites: private interfaces have no host IP addresses.
set -euo pipefail
[[ $(id -u) == 0 ]]
case $(hostname -s) in
 ocne-w1) mac1=08:00:27:be:02:40; mac2=08:00:27:2e:39:10;;
 ocne-w2) mac1=08:00:27:23:3e:b8; mac2=08:00:27:4f:c6:7f;;
 *) exit 1;;
esac
[[ $(cat /sys/class/net/enp0s8/address) == "$mac1" ]]
[[ $(cat /sys/class/net/enp0s9/address) == "$mac2" ]]
[[ -z $(ip -4 -o address show dev enp0s8) && -z $(ip -4 -o address show dev enp0s9) ]]
for i in 1 2; do
 if nmcli -g NAME connection show | grep -qxF "ocne-rac-private$i"; then echo 'Connection already exists; inspect partial run.'; exit 1; fi
done
for row in '1 enp0s8' '2 enp0s9'; do
 read -r number interface <<< "$row"
 nmcli connection add type ethernet ifname "$interface" con-name "ocne-rac-private$number" ipv4.method disabled ipv6.method disabled ethernet.mtu 1500 connection.autoconnect yes
 nmcli connection up "ocne-rac-private$number"
 [[ $(nmcli -g ipv4.method connection show "ocne-rac-private$number") == disabled ]]
 [[ $(nmcli -g ipv6.method connection show "ocne-rac-private$number") == disabled ]]
 [[ -z $(ip -4 -o address show dev "$interface") && -z $(ip -6 -o address show dev "$interface") ]]
done
ip -br link
ip -4 route
