#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
existing=$(kubectl get namespace rac --ignore-not-found -o name)
[[ -z "$existing" ]] || { echo 'Namespace rac exists; inspect before adopting it.'; exit 1; }
kubectl rollout status daemonset/kube-multus-ds -n kube-system --timeout=60s
work=$(mktemp -d)
trap 'rm -f "$work/networks.yaml"; rmdir "$work"' EXIT
cat > "$work/networks.yaml" <<'NETWORK_MANIFEST'
# Local network values; Oracle RAC MACVLAN model and OCNE 1.9 Multus module.
apiVersion: v1
kind: Namespace
metadata:
  name: rac
  labels:
    app.kubernetes.io/part-of: ocne19-lab
---
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf1
  namespace: rac
spec:
  config: >-
    {"cniVersion":"0.3.1","type":"macvlan","master":"enp0s8","mode":"bridge","mtu":1500,"ipam":{"type":"host-local","subnet":"192.168.78.0/24","rangeStart":"192.168.78.120","rangeEnd":"192.168.78.130"}}
---
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: macvlan-conf2
  namespace: rac
spec:
  config: >-
    {"cniVersion":"0.3.1","type":"macvlan","master":"enp0s9","mode":"bridge","mtu":1500,"ipam":{"type":"host-local","subnet":"192.168.79.0/24","rangeStart":"192.168.79.120","rangeEnd":"192.168.79.130"}}
NETWORK_MANIFEST
kubectl apply --dry-run=client -f "$work/networks.yaml"
kubectl create namespace rac
kubectl apply --dry-run=server -f "$work/networks.yaml"
kubectl apply -f "$work/networks.yaml"
kubectl get network-attachment-definitions -n rac
