# Kubernetes assets - future use

The kustomization contains 14 resources: one Namespace, one ConfigMap, four Deployments, four Services and four PodDisruptionBudgets. It creates no RAC resources or volumes. Two application Secrets must be created separately from protected files. All four images must be staged on both workers; imagePullPolicy is Never.

Read [the deployment walkthrough](../docs/DEPLOYMENT.md) before any kubectl apply. These manifests have been checked against the Kubernetes 1.29.14 schema, but have not been deployed or tested by server-side admission.
