set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes -o wide
kubectl get deployments --all-namespaces
kubectl get pods --all-namespaces -o wide
kubectl get nodes -o json | python3 -c 'import json,sys; a=json.load(sys.stdin)["items"]; assert len(a)==3; assert all(any(c["type"]=="Ready" and c["status"]=="True" for c in n["status"]["conditions"]) for n in a); print("All three Kubernetes nodes Ready")'
kubectl get deployments -A -o json | python3 -c 'import json,sys; a=json.load(sys.stdin)["items"]; assert a; assert all(d["status"].get("availableReplicas",0)==d["spec"].get("replicas",1) and d["status"].get("updatedReplicas",0)==d["spec"].get("replicas",1) for d in a); print("All deployments have intended replicas available and updated")'
kubectl get pods -A -o json | python3 -c 'import json,sys; a=json.load(sys.stdin)["items"]; bad=[p["metadata"]["namespace"]+"/"+p["metadata"]["name"] for p in a if p["status"].get("phase")!="Running" or not any(c["type"]=="Ready" and c["status"]=="True" for c in p["status"].get("conditions",[]))]; assert a and not bad, "Pods not yet ready: "+str(bad); print("Every current pod is Running and Ready")'