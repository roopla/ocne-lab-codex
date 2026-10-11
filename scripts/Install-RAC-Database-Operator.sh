#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
cd "$HOME/ocne-rac-prereqs"
[[ -z $(kubectl get ns oracle-database-operator-system --ignore-not-found -o name) ]]
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=60s
kubectl apply --server-side -f oracle-database-operator-2.2.0-rbac.yaml
kubectl apply --server-side -f rac-pv-rbac.yaml -f rac-multus-rbac.yaml -f rac-node-rbac.yaml
identity=system:serviceaccount:oracle-database-operator-system:oracle-database-operator-controller-manager
for namespace in rac oracle-database-operator-system; do
 [[ $(kubectl auth can-i list pods --as="$identity" -n "$namespace") == yes ]]
done
kubectl apply --server-side -f oracle-database-operator-2.2.0-system.yaml
kubectl wait --for=condition=Established crd/racdatabases.database.oracle.com --timeout=120s
kubectl wait --for=condition=Ready certificates --all -n oracle-database-operator-system --timeout=180s
kubectl rollout status deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system --timeout=240s
kubectl get pods,certificates -n oracle-database-operator-system -o wide
kubectl get racdatabases -A
