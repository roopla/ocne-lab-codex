set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -u) == 0 ]]
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl get pods --all-namespaces -o wide
kubectl get deployments --all-namespaces
kubectl get events -A --field-selector type=Warning --sort-by=.metadata.creationTimestamp | tail -15