#!/bin/bash
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
for pod in rac-netcheck-w1 rac-netcheck-w2; do
 existing=$(kubectl -n rac get pod "$pod" --ignore-not-found -o name)
 [[ -z "$existing" ]] || { echo 'A test pod already exists; inspect it.'; exit 1; }
done
manifest=$(mktemp)
trap 'rm -f "$manifest"' EXIT
cat > "$manifest" <<'PODS'
apiVersion: v1
kind: Pod
metadata:
  name: rac-netcheck-w1
  namespace: rac
  labels:
    app: ocne-rac-netcheck
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{"name":"macvlan-conf1","interface":"ens1","ips":["192.168.78.128/24"]},{"name":"macvlan-conf2","interface":"ens2","ips":["192.168.79.128/24"]}]'
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: network-check
    image: docker.io/library/busybox:1.37.0
    command:
    - sleep
    - '1800'
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        add:
        - NET_RAW
    resources:
      requests:
        cpu: '4'
        memory: 16Gi
        hugepages-2Mi: 3Gi
      limits:
        cpu: '4'
        memory: 16Gi
        hugepages-2Mi: 3Gi
    volumeMounts:
    - name: hugepages
      mountPath: /hugepages
  nodeSelector:
    kubernetes.io/hostname: ocne-w1.lab.test
  securityContext:
    sysctls:
    - name: kernel.shmmax
      value: '3221225472'
    - name: kernel.shmall
      value: '786432'
    - name: kernel.sem
      value: 250 32000 100 128
    - name: net.ipv4.conf.all.rp_filter
      value: '2'
  volumes:
  - name: hugepages
    emptyDir:
      medium: HugePages
---
apiVersion: v1
kind: Pod
metadata:
  name: rac-netcheck-w2
  namespace: rac
  labels:
    app: ocne-rac-netcheck
  annotations:
    k8s.v1.cni.cncf.io/networks: '[{"name":"macvlan-conf1","interface":"ens1","ips":["192.168.78.129/24"]},{"name":"macvlan-conf2","interface":"ens2","ips":["192.168.79.129/24"]}]'
spec:
  automountServiceAccountToken: false
  restartPolicy: Never
  containers:
  - name: network-check
    image: docker.io/library/busybox:1.37.0
    command:
    - sleep
    - '1800'
    securityContext:
      allowPrivilegeEscalation: false
      capabilities:
        add:
        - NET_RAW
    resources:
      requests:
        cpu: '4'
        memory: 16Gi
        hugepages-2Mi: 3Gi
      limits:
        cpu: '4'
        memory: 16Gi
        hugepages-2Mi: 3Gi
    volumeMounts:
    - name: hugepages
      mountPath: /hugepages
  nodeSelector:
    kubernetes.io/hostname: ocne-w2.lab.test
  securityContext:
    sysctls:
    - name: kernel.shmmax
      value: '3221225472'
    - name: kernel.shmall
      value: '786432'
    - name: kernel.sem
      value: 250 32000 100 128
    - name: net.ipv4.conf.all.rp_filter
      value: '2'
  volumes:
  - name: hugepages
    emptyDir:
      medium: HugePages
PODS
kubectl create --dry-run=server -f "$manifest"
kubectl create -f "$manifest"
kubectl wait --for=condition=Ready pod/rac-netcheck-w1 pod/rac-netcheck-w2 -n rac --timeout=180s
for i in 1 2; do
 pod=rac-netcheck-w$i
 if [[ $i == 1 ]]; then own=128; peer=129; else own=129; peer=128; fi
 kubectl exec -n rac "$pod" -- cat /proc/mounts | grep -E '^[^ ]+ /hugepages hugetlbfs '
 kubectl exec -n rac "$pod" -- sysctl -n kernel.shmmax | grep -Fx 3221225472
 kubectl exec -n rac "$pod" -- ip -4 address show
 kubectl exec -n rac "$pod" -- ip -4 address show dev ens1 | grep -F "192.168.78.$own/24"
 kubectl exec -n rac "$pod" -- ip -4 address show dev ens2 | grep -F "192.168.79.$own/24"
 kubectl exec -n rac "$pod" -- ping -I ens1 -c 3 -W 3 -s 1472 "192.168.78.$peer"
 kubectl exec -n rac "$pod" -- ping -I ens2 -c 3 -W 3 -s 1472 "192.168.79.$peer"
 kubectl exec -n rac "$pod" -- nslookup kubernetes.default.svc.cluster.local
done
kubectl get pods -n rac -l app=ocne-rac-netcheck -o wide
printf 'Bidirectional traffic passed on both private networks; test pods retained for explicit cleanup.\n'
