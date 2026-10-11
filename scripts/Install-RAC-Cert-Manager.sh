#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
cd "$HOME/ocne-rac-prereqs"
[[ -z $(kubectl get ns cert-manager --ignore-not-found -o name) ]]
sha256sum cert-manager-v1.17.4.yaml
kubectl apply --server-side -f cert-manager-v1.17.4.yaml
for deployment in cert-manager cert-manager-cainjector cert-manager-webhook; do
 kubectl rollout status deployment/$deployment -n cert-manager --timeout=240s
done
kubectl get pods -n cert-manager -o wide
