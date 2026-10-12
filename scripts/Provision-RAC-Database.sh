#!/bin/bash
# Historical first-create script, pinned to the original reviewed manifest hash.
# It is not the current fresh-build entry point; use MANUAL-03-RAC.md.
# User authorized provisioning on 10 October 2026 after reviewing prerequisites.
set -euo pipefail
[[ $(hostname -s) == ocne-cp && $(id -un) == labadmin ]]
export KUBECONFIG="$HOME/.kube/config"
manifest=$HOME/ocne-rac-prereqs/rac-database.yaml
printf '%s  %s\n' 70595906a3ddbb89bc031b24938814f8df99891619547fd7c6e453ce439e9ca3 "$manifest" | sha256sum -c -
[[ -z $(kubectl get racdatabases -A -o name) ]]
[[ -z $(kubectl get pods -n rac -o name) ]]
kubectl get nodes -o json | python3 -c 'import json,sys; ns=json.load(sys.stdin)["items"]; assert len(ns)==3; assert all(any(c["type"]=="Ready" and c["status"]=="True" for c in n["status"]["conditions"]) for n in ns); ws=[n for n in ns if n["metadata"].get("labels",{}).get("raccluster")=="raccluster01"]; assert len(ws)==2; print("Nodes Ready; original manifest hash verified separately.")'
kubectl create --dry-run=server -f "$manifest"
kubectl apply -f "$manifest"
kubectl get racdatabase rac19c -n rac -o custom-columns=NAME:.metadata.name,UID:.metadata.uid,CREATED:.metadata.creationTimestamp,STATE:.status.state
