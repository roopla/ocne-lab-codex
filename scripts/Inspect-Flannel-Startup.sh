set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -u) == 0 ]]
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl -n kube-system get pods -l app=flannel -o json | python3 -c 'import json,sys; a=json.load(sys.stdin)["items"]; [(print(p["metadata"]["name"],p["spec"]["nodeName"]),print(json.dumps(p["status"].get("initContainerStatuses",[]))), print(json.dumps(p["status"].get("containerStatuses",[])))) for p in a]'
kubectl -n kube-system get events --sort-by=.metadata.creationTimestamp | tail -20