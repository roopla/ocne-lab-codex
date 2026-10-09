set -euo pipefail
[[ $(hostname -s) == ocne-w2 && $(id -u) == 0 ]]
sed -n '1,180p' /etc/olcne/scripts/olcne-firewall-check
for port in 8090/tcp 10250/tcp 10255/tcp 8472/udp; do
 printf '%s runtime=' "$port"; firewall-cmd --query-port="$port"
 printf '%s permanent=' "$port"; firewall-cmd --permanent --query-port="$port"
done
printf 'Packaged agent check for 10250: '
/etc/olcne/scripts/olcne-firewall-check 10250 tcp