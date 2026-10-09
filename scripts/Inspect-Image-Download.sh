set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -u) == 0 ]]
ss -tinp '( dport = :443 )'
df -hT /var/lib/containers
free -h
curl -sS -I --connect-timeout 10 --max-time 20 https://container-registry.oracle.com/v2/
find /var/lib/containers/storage -maxdepth 2 -type f -mmin -10 -printf '%s %p\n' | head -15
journalctl -u crio --since '-8 minutes' --no-pager -o cat | grep -E 'Pulling image|Pulled image|error|Error|timeout|flannel' | tail -15