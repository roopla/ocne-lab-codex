set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -u) == 0 ]]
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n kube-system logs kube-flannel-ds-9gz6b -c kube-flannel --previous --tail=12 || true
kubectl -n kube-system get events --field-selector involvedObject.name=kube-flannel-ds-zrktf --sort-by=.metadata.creationTimestamp
journalctl -u crio --since '-6 minutes' --no-pager -o cat | grep -E 'flannel|error|Error|timeout' | tail -12 || true
kubectl get nodes