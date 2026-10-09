set -euo pipefail
[[ $(hostname -s) == ocne-op && $(id -un) == labadmin ]]
umask 077
while read -r host fingerprint; do
 scan=$(mktemp)
 ssh-keyscan -T 5 -t ed25519 "$host" 2>/dev/null > "$scan"
 actual=$(ssh-keygen -lf "$scan" | awk '{print $2}')
 [[ "$actual" == "$fingerprint" ]] || { rm -f "$scan"; echo "Host-key mismatch for $host"; exit 1; }
 touch "$HOME/.ssh/known_hosts"
 while IFS= read -r key; do grep -qxF "$key" "$HOME/.ssh/known_hosts" || printf '%s\n' "$key" >> "$HOME/.ssh/known_hosts"; done < "$scan"
 rm -f "$scan"
 ssh -o BatchMode=yes -o StrictHostKeyChecking=yes -i "$HOME/.ssh/id_rsa" "labadmin@$host" 'hostname; id -u; cat /proc/sys/kernel/random/boot_id; uptime -s'
done <<'HOSTS'
ocne-op.lab.test SHA256:sbEzbVaiskLB3AsZkZGztp7GMRLKhFAQRWWs1Ah6neQ
ocne-cp.lab.test SHA256:j7qeYO6HxrtLrSqnmUa8yNhZGqRHH7IrkyFoe6mzvR0
ocne-w1.lab.test SHA256:4pH76g+KL5tm0/UcypWclkXThs77R5YZzhePAJgk9YA
ocne-w2.lab.test SHA256:33T0uJa3NJTanAV+4fHan2PQobkRQPho82LdJac7tSw
HOSTS