# 2. Installing Oracle Database Operator

[Start](README.md) | [Previous: OCNE](01-OCNE.md) | [Next: RAC](03-RAC.md)

The **OCNE operator host** runs olcnectl. The **Database Operator** is a Kubernetes controller that turns a RacDatabase resource into database workloads. Installing the controller does not create RAC. cert-manager supplies its webhook TLS certificates.

## 2a. Prerequisites

### 2a.1 Check cluster health and authority

**Run:** control plane as labadmin.

```bash
export KUBECONFIG="$HOME/.kube/config"
chmod 600 "$KUBECONFIG"
kubectl config current-context
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A -o wide
kubectl get deployments -A
kubectl auth can-i create customresourcedefinitions.apiextensions.k8s.io
kubectl auth can-i create clusterroles.rbac.authorization.k8s.io
kubectl auth can-i create namespaces
kubectl get ns cert-manager oracle-database-operator-system rac
```

**Expected:** three Ready nodes, healthy base workloads and yes for all authorization checks. Namespace NotFound is expected before a new installation.

**If not:** repair chapter 1 first. An existing operator/cert-manager namespace requires version and ownership inspection; do not install a second controller over it. Keep administrative kubeconfig private.

### 2a.2 Select the reproducible versions

| Component | This walkthrough |
|---|---|
| OCNE / Kubernetes | 1.9 / 1.29, as installed by the OCNE module |
| Database Operator | 2.2.0, source commit ff6f9178c1650df30afbf203ebdb633e9b80760a |
| cert-manager | 1.17.4, historical Kubernetes 1.29-compatible branch |
| Controller scope | oracle-database-operator-system,rac; one replica |

Use the six reviewed YAML files in [config/vendor](../config/vendor/README.md), which records image digest, upstream sources, adaptations and licenses. This historical stack is not a current production recommendation. Changing a version requires a fresh compatibility review.

### 2a.3 Copy the six prerequisite manifests

**Run:** workstation Bash/Git Bash, from the repository root.

```bash
# On Windows Git Bash: cd /d/OCNE19-Lab
sha256sum config/vendor/*.yaml
ssh labadmin@ocne-cp.lab.test 'install -d -m 0755 ~/ocne-rac-prereqs'
scp config/vendor/cert-manager-v1.17.4.yaml config/vendor/oracle-database-operator-2.2.0-rbac.yaml config/vendor/oracle-database-operator-2.2.0-system.yaml config/vendor/rac-pv-rbac.yaml config/vendor/rac-multus-rbac.yaml config/vendor/rac-node-rbac.yaml labadmin@ocne-cp.lab.test:~/ocne-rac-prereqs/
```

Then on the control plane:

```bash
cd ~/ocne-rac-prereqs
sha256sum *.yaml
```

**Expected:** all six source/destination hashes match.

**If not:** repair SSH routing/keys or recopy only a mismatched file. Use your verified SSH alias when guests are behind NAT. Never recursively apply config/: it contains database creation and diagnostic resources.

## 2b. Setting up

All following commands run on the control plane as labadmin, in `~/ocne-rac-prereqs`, using the chapter 1 kubeconfig. Stop on an unexpected command failure.

### 2b.1 Create the RAC namespace

**Run:** control plane.

```bash
kubectl get namespace rac --ignore-not-found
# Run only if the result above is empty:
kubectl create namespace rac
```

**Expected:** namespace/rac created.

**If not:** if it exists, inspect it and skip creation; it must match the controller watch list.

### 2b.2 Install cert-manager

**Run:** control plane.

```bash
cd ~/ocne-rac-prereqs
kubectl apply --server-side -f cert-manager-v1.17.4.yaml
kubectl rollout status deployment/cert-manager -n cert-manager --timeout=240s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=240s
kubectl rollout status deployment/cert-manager-webhook -n cert-manager --timeout=240s
kubectl get deployments,pods -n cert-manager -o wide
```

**Expected:** all three deployments successfully roll out and show 1/1 Ready.

**If not:** run `kubectl get events -n cert-manager --sort-by=.metadata.creationTimestamp` and `kubectl describe pod -n cert-manager POD`. For ImagePullBackOff repair registry access; for Pending inspect capacity. Continue only with a working webhook.

### 2b.3 Apply namespace and RAC permissions

**Run:** control plane.

```bash
kubectl apply --server-side -f oracle-database-operator-2.2.0-rbac.yaml
kubectl apply --server-side -f rac-pv-rbac.yaml
kubectl apply --server-side -f rac-multus-rbac.yaml
kubectl apply --server-side -f rac-node-rbac.yaml
```

```bash
identity=system:serviceaccount:oracle-database-operator-system:oracle-database-operator-controller-manager
kubectl auth can-i list pods --as="$identity" -n rac
kubectl auth can-i list pods --as="$identity" -n oracle-database-operator-system
kubectl auth can-i get nodes --as="$identity"
kubectl auth can-i create persistentvolumes --as="$identity"
kubectl auth can-i list network-attachment-definitions.k8s.cni.cncf.io --as="$identity" -n rac
```

**Expected:** yes for every authorization check. Before Multus exists, NAD discovery may warn; repeat after chapter 3.

**If not:** apply the specific missing RAC PV/node/Multus RBAC file; compare denied resource/verb and exact service account. Do not grant cluster-admin as a workaround.

### 2b.4 Install the controller and APIs

**Run:** control plane.

```bash
kubectl apply --server-side -f oracle-database-operator-2.2.0-system.yaml
kubectl wait --for=condition=Established crd/racdatabases.database.oracle.com --timeout=120s
kubectl wait --for=condition=Ready certificates --all -n oracle-database-operator-system --timeout=180s
kubectl rollout status deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system --timeout=240s
```

**Expected:** RacDatabase CRD Established, both certificates Ready, controller rollout successful.

**If not:** run `kubectl describe certificate -n oracle-database-operator-system` and `kubectl get endpoints -n oracle-database-operator-system`. Repair cert-manager/CA injection and time before retrying; do not bypass admission TLS.

### 2b.5 Verify the operator

**Run:** control plane.

```bash
kubectl get pods,certificates -n oracle-database-operator-system -o wide
kubectl get crd racdatabases.database.oracle.com
kubectl api-resources --api-group=database.oracle.com
kubectl explain racdatabase --api-version=database.oracle.com/v4
kubectl explain racdatabase.spec --api-version=database.oracle.com/v4
kubectl get racdatabases -A
kubectl get validatingwebhookconfigurations
```

```bash
kubectl get events -n oracle-database-operator-system --sort-by=.metadata.creationTimestamp
kubectl describe deployment oracle-database-operator-controller-manager -n oracle-database-operator-system
kubectl logs deployment/oracle-database-operator-controller-manager -n oracle-database-operator-system --tail=100
```

**Expected:** controller pod 1/1 Running, certificates True, API database.oracle.com/v4 visible, no RacDatabase objects on a fresh build.

**If not:** use the included events/describe/logs to identify the failing layer; resolve denied permissions, certificate conditions or capacity. Inspect logs privately before sharing.

**Chapter complete:** controller, certificates, CRD and RBAC are healthy. No database has been created. Continue to worker storage/network/media preparation in chapter 3.

Sources: [pinned Oracle namespace generator](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/scripts/generate-namespace-install.sh), [RAC prerequisite permissions](https://github.com/oracle/oracle-database-operator/blob/ff6f9178c1650df30afbf203ebdb633e9b80760a/docs/rac/provisioning/prerequisites_oracle_rac_db.md), [cert-manager release compatibility](https://cert-manager.io/docs/releases/). Oracle code/manifests retain their [UPL license](../config/vendor/ORACLE-UPL.txt); cert-manager retains its [Apache license](../config/vendor/CERT-MANAGER-LICENSE.txt).
