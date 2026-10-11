# Pinned prerequisite manifests

These are third-party deployment assets, not database provisioning resources. Apply individually as documented in [the manual guide](../../docs/RAC-PREREQUISITES-GUIDE.md). Never recursively apply the parent config directory.

- cert-manager-v1.17.4.yaml: official [release asset](https://github.com/cert-manager/cert-manager/releases/download/v1.17.4/cert-manager.yaml), original SHA256 eab63a0ddfa87811eaa4818e6721504671fd70a045d5f0e58d289c3d3a0847d2. Apache2.0 [license](https://github.com/cert-manager/cert-manager/blob/v1.17.4/LICENSE). YAML object contents retained unchanged; line endings and one whitespace-only line normalized; the Apache license is copied as CERT-MANAGER-LICENSE.txt. Version1.17 supports Kubernetes1.29 but is outside community maintenance.
- Oracle operator manifests and RAC RBAC: [Oracle Database Operator2.2.0](https://github.com/oracle/oracle-database-operator/tree/ff6f9178c1650df30afbf203ebdb633e9b80760a), commit ff6f9178c1650df30afbf203ebdb633e9b80760a. Copyright Oracle and/or its affiliates; Universal Permissive License1.0, copied as ORACLE-UPL.txt.
- Generated namespace-scoped RBAC/system manifests using the pinned scripts/generate-namespace-install.sh with watch list oracle-database-operator-system,rac. Local adaptations: one controller replica for the lab; replace latest image with the observed2.2.0 amd64 digest sha256:f378d66fd0b47b6089f01caf4ca86f90f3b3593cdca75292ff6491955c451cc0. No other system-manifest changes.
- rac-pv-rbac.yaml, rac-multus-rbac.yaml and rac-node-rbac.yaml are copies of the respective upstream RBAC assets with LF line endings. No storage-class expansion RBAC is added.

The sibling rac-database.yaml is the user-only provisioning manifest. It is deliberately outside this vendor directory. Secrets, keys, kubeconfig, installation archives and VM disks are excluded.
