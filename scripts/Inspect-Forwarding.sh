set -euo pipefail
hostname
nft list chain inet firewalld filter_FORWARD_POLICIES_post
systemctl show forward-policies.service -p ActiveState -p SubState -p Result -p ExecMainStatus
journalctl -u forward-policies.service --no-pager -n 15
printf '\nWorker candidate disks and signatures\n'
lsblk -b -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL