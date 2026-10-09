set -euo pipefail
case $(hostname -s) in ocne-op|ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
free -h
systemctl --failed --no-pager
for svc in olcne-api-server olcne-agent crio kubelet; do systemctl show "$svc" -p Id -p ActiveState -p SubState; done
rpm -q kubeadm kubelet kubectl cri-o || true
chronyc tracking | head -12