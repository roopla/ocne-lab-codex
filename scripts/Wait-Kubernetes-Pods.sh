set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
kubectl wait --for=condition=Ready pods --all --all-namespaces --timeout=180s