set -euo pipefail
case $(hostname -s) in ocne-op) svc=olcne-api-server;; ocne-cp|ocne-w1|ocne-w2) svc=olcne-agent;; *) exit 1;; esac
hostname
journalctl -u "$svc" -n 45 --no-pager -o cat | grep -vE 'COMMAND=|command continued' | sed -E 's/[a-z0-9]{6}\.[a-z0-9]{16}/[redacted-bootstrap-token]/g; s/(--token|--certificate-key|--password)[= ]+[^ ]+/\1 [redacted]/g'
ps -eo pid,ppid,etime,comm | grep -E 'dnf|yum|rpm|olcne|curl|skopeo|crio|kube' || true