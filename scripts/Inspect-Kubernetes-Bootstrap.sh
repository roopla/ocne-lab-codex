set -euo pipefail
case $(hostname -s) in ocne-cp|ocne-w1|ocne-w2) ;; *) exit 1;; esac
hostname
systemctl show kubelet crio -p Id -p ActiveState -p SubState
if command -v crictl >/dev/null; then crictl --runtime-endpoint unix:///var/run/crio/crio.sock images; fi
if [[ $(hostname -s) == ocne-cp && -s /etc/kubernetes/admin.conf ]]; then kubectl --kubeconfig /etc/kubernetes/admin.conf get nodes -o wide --request-timeout=10s; fi