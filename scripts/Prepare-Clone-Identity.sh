#!/bin/bash
# Local clone preparation: cloning guide sections 7-8, C2/C3/C7.
set -euo pipefail
uuid=$(tr '[:upper:]' '[:lower:]' </sys/class/dmi/id/product_uuid)
case "$uuid" in
  2e3fc9be-6c02-4e7d-b631-0ce61fb20dc9|bec93f2e-026c-7d4e-b631-0ce61fb20dc9) node=ocne-op; ip=192.168.77.10; mac=08:00:27:53:00:51 ;;
  c965ec77-36cb-40aa-aa61-95f3b008708c|77ec65c9-cb36-aa40-aa61-95f3b008708c) node=ocne-cp; ip=192.168.77.11; mac=08:00:27:27:ab:67 ;;
  1756d852-30cd-40b7-bdd0-49a5359ed499|52d85617-cd30-b740-bdd0-49a5359ed499) node=ocne-w1; ip=192.168.77.12; mac=08:00:27:dd:0a:d1 ;;
  d4404167-3980-4c69-ae11-9b1e7125446e|674140d4-8039-694c-ae11-9b1e7125446e) node=ocne-w2; ip=192.168.77.13; mac=08:00:27:f0:9d:3a ;;
  *) echo 'Not an inspected clone UUID'; exit 1 ;;
esac
[[ $(id -u) == 0 ]]
[[ ! -e /root/ocne-clone-identity-reset ]]
iface=''
for candidate in /sys/class/net/*; do
  if [[ $(cat "$candidate/address") == "$mac" ]]; then iface=${candidate##*/}; fi
done
[[ -n "$iface" ]]
# Host also verifies VirtualBox cableconnected1=off before transmitting this script.
[[ $(cat "/sys/class/net/$iface/carrier" 2>/dev/null || echo 0) != 1 ]]
if nmcli -t -f TYPE con show | grep -qx '802-3-ethernet'; then
  echo 'Unexpected inherited Ethernet profile; inspect before changing'; exit 1
fi
hostnamectl set-hostname "$node.lab.test"
nmcli con add type ethernet ifname "$iface" con-name ocne-lab ipv4.method manual ipv4.addresses "$ip/24" ipv4.gateway 192.168.77.1 ipv4.dns 192.168.137.1 connection.autoconnect yes connection.autoconnect-priority 100
cp -p /etc/hosts /etc/hosts.before-ocne-clone
python3 - <<'PY'
from pathlib import Path
p=Path('/etc/hosts')
rows=[]
for line in p.read_text().splitlines():
    fields=line.split('#',1)[0].split()
    if any(n in fields[1:] for n in ['ol9-golden','ol9-golden.lab.test','ocne-op','ocne-op.lab.test','ocne-cp','ocne-cp.lab.test','ocne-w1','ocne-w1.lab.test','ocne-w2','ocne-w2.lab.test']):
        continue
    rows.append(line)
for i,n in enumerate(['ocne-op','ocne-cp','ocne-w1','ocne-w2'],10):
    rows.append(f'192.168.77.{i} {n}.lab.test {n}')
p.write_text('\n'.join(rows)+'\n')
PY
if ! id labadmin >/dev/null 2>&1; then
  if getent passwd 1001 || getent group 1001; then echo 'UID/GID conflict'; exit 1; fi
  groupadd -g 1001 labadmin
  useradd -m -u 1001 -g labadmin -G wheel labadmin
fi
[[ $(id -u labadmin) == 1001 && $(id -g labadmin) == 1001 ]]
if findmnt -rn -t vboxsf | grep -q .; then echo 'Unexpected host share mount'; exit 1; fi
cp /etc/machine-id /root/ocne-template-machine-id
chmod 600 /root/ocne-template-machine-id
systemctl stop sshd
rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub
truncate -s 0 /etc/machine-id
rm -f /var/lib/dbus/machine-id
ln -s /etc/machine-id /var/lib/dbus/machine-id
touch /root/ocne-clone-identity-reset
sync
systemctl reboot