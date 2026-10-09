set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
ps -eo pid,ppid,etime,comm | grep -E 'dnf|yum|rpm|olcne|crio|kube' || true
tail -n 18 /var/log/dnf.log
journalctl -u olcne-agent -n 12 --no-pager -o cat | sed -E 's/(token|password|key-data)([=: ]+)[^ ]+/\1\2[redacted]/Ig'