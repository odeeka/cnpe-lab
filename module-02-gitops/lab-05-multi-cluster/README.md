# Lab 5: Multi-Cluster GitOps

## Overview

This lab covers multi-cluster GitOps strategies with ArgoCD, including cluster bootstrapping, ApplicationSets with cluster generators, hub-and-spoke patterns, and cross-cluster deployments. You will learn how to manage applications across multiple Kubernetes clusters from a single ArgoCD instance.

## Time to Complete

Estimated time: 3-4 hours

## Prerequisites

Before starting this lab, ensure you have:

- Completed Labs 1-4 of this module
- `kubectl` configured
- ArgoCD CLI installed
- Understanding of ApplicationSets (Lab 2)
- Sufficient resources for multiple kind clusters

## Learning Objectives

By the end of this lab, you will be able to:

1. Register external clusters with ArgoCD
2. Configure cluster secrets for multi-cluster management
3. Use ApplicationSets with cluster generators
4. Implement hub-and-spoke GitOps patterns
5. Deploy applications across multiple clusters
6. Handle cluster-specific configurations
7. Implement cross-cluster networking considerations

## Multi-Cluster Architecture Patterns

### Pattern Overview

```text
Hub-and-Spoke Pattern:
                          ┌─────────────────┐
                          │   Management    │
                          │    Cluster      │
                          │   (ArgoCD)      │
                          └────────┬────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              │                    │                    │
              ▼                    ▼                    ▼
     ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
     │  Development   │   │    Staging     │   │   Production   │
     │    Cluster     │   │    Cluster     │   │    Cluster     │
     └────────────────┘   └────────────────┘   └────────────────┘

Standalone Pattern:
     ┌────────────────┐   ┌────────────────┐   ┌────────────────┐
     │  Dev Cluster   │   │ Stage Cluster  │   │  Prod Cluster  │
     │    + ArgoCD    │   │    + ArgoCD    │   │    + ArgoCD    │
     └────────────────┘   └────────────────┘   └────────────────┘
            │                    │                    │
            └────────────────────┼────────────────────┘
                                 ▼
                          ┌─────────────────┐
                          │    Git Repo     │
                          │  (Single Source │
                          │   of Truth)     │
                          └─────────────────┘
```

## Lab Exercises

### Exercise 1: Creating Multiple kind Clusters

First, let's create a multi-cluster environment using kind.

#### Step 1: Create Management Cluster

Create the hub cluster that will host ArgoCD:

```yaml
# management-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: management
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "cluster-type=management"
    extraPortMappings:
      - containerPort: 30080
        hostPort: 30080
        protocol: TCP
      - containerPort: 30443
        hostPort: 30443
        protocol: TCP
networking:
  podSubnet: "10.244.0.0/16"
  serviceSubnet: "10.96.0.0/16"
```

Create the cluster:

```bash
kind create cluster --config management-cluster.yaml
```

#### Step 2: Create Workload Clusters

Create development cluster:

```yaml
# dev-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: dev
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "cluster-type=workload,environment=dev"
networking:
  podSubnet: "10.245.0.0/16"
  serviceSubnet: "10.97.0.0/16"
```

Create staging cluster:

```yaml
# staging-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: staging
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "cluster-type=workload,environment=staging"
networking:
  podSubnet: "10.246.0.0/16"
  serviceSubnet: "10.98.0.0/16"
```

Create production cluster:

```yaml
# prod-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: prod
nodes:
  - role: control-plane
    kubeadmConfigPatches:
      - |
        kind: InitConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "cluster-type=workload,environment=prod"
  - role: worker
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          kubeletExtraArgs:
            node-labels: "cluster-type=workload,environment=prod"
networking:
  podSubnet: "10.247.0.0/16"
  serviceSubnet: "10.99.0.0/16"
```

Create all workload clusters:

```bash
kind create cluster --config dev-cluster.yaml
kind create cluster --config staging-cluster.yaml
kind create cluster --config prod-cluster.yaml
```

#### Step 3: Verify Clusters

List all clusters:

```bash
kind get clusters
```

Expected output:

```text
dev
management
prod
staging
```

View all contexts:

```bash
kubectl config get-contexts
```

### Exercise 2: Installing ArgoCD on Management Cluster

#### Step 1: Switch to Management Cluster

```bash
kubectl config use-context kind-management
```

#### Step 2: Install ArgoCD

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for ArgoCD to be ready:

```bash
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s
```

#### Step 3: Expose ArgoCD (Optional for UI Access)

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "NodePort", "ports": [{"port": 443, "nodePort": 30443}]}}'
```

Get the initial admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Exercise 3: Registering Clusters with ArgoCD

ArgoCD can manage applications on external clusters. Let's register our workload clusters.

#### Step 1: Understanding Cluster Registration Methods

There are two methods to register clusters:

1. **ArgoCD CLI**: `argocd cluster add`
2. **Declarative Cluster Secrets**: Kubernetes secrets with cluster credentials

#### Step 2: Register Clusters Using CLI

First, log in to ArgoCD:

```bash
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:30443 --username admin --password $ARGOCD_PASSWORD --insecure
```

Register the dev cluster:

```bash
argocd cluster add kind-dev --name dev-cluster
```

Register staging cluster:

```bash
argocd cluster add kind-staging --name staging-cluster
```

Register production cluster:

```bash
argocd cluster add kind-prod --name prod-cluster
```

#### Step 3: Verify Registered Clusters

```bash
argocd cluster list
```

Expected output:

```text
SERVER                          NAME             VERSION  STATUS   MESSAGE
https://kubernetes.default.svc  in-cluster       1.28     Successful
https://172.18.0.x:6443         dev-cluster      1.28     Successful
https://172.18.0.x:6443         staging-cluster  1.28     Successful
https://172.18.0.x:6443         prod-cluster     1.28     Successful
```

#### Step 4: Examine Cluster Secrets

ArgoCD stores cluster credentials as secrets:

```bash
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster
```

Examine a cluster secret (sanitized):

```bash
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=cluster -o yaml | head -50
```

### Exercise 4: Declarative Cluster Registration

For GitOps, you should manage cluster registrations declaratively.

#### Step 1: Create Cluster Secret Template

```yaml
# cluster-secret-template.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
type: Opaque
stringData:
  name: ${CLUSTER_NAME}
  server: ${CLUSTER_SERVER}
  config: |
    {
      "bearerToken": "${CLUSTER_TOKEN}",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "${CLUSTER_CA_DATA}"
      }
    }
```

#### Step 2: Create Service Account for ArgoCD

On each workload cluster, create a service account for ArgoCD:

```yaml
# argocd-manager-sa.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: argocd-manager
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: argocd-manager-role
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: argocd-manager-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: argocd-manager-role
subjects:
  - kind: ServiceAccount
    name: argocd-manager
    namespace: kube-system
---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-manager-token
  namespace: kube-system
  annotations:
    kubernetes.io/service-account.name: argocd-manager
type: kubernetes.io/service-account-token
```

Apply to each workload cluster:

```bash
for cluster in dev staging prod; do
  kubectl --context kind-$cluster apply -f argocd-manager-sa.yaml
done
```

#### Step 3: Create Script to Generate Cluster Secrets

```bash
#!/bin/bash
# generate-cluster-secrets.sh

CLUSTER_NAME=$1
CONTEXT="kind-$CLUSTER_NAME"

# Get cluster server
SERVER=$(kubectl config view -o jsonpath="{.clusters[?(@.name==\"$CONTEXT\")].cluster.server}")

# Get CA data
CA_DATA=$(kubectl --context $CONTEXT get secret argocd-manager-token -n kube-system -o jsonpath='{.data.ca\.crt}')

# Get bearer token
TOKEN=$(kubectl --context $CONTEXT get secret argocd-manager-token -n kube-system -o jsonpath='{.data.token}' | base64 -d)

cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${CLUSTER_NAME}-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: $CLUSTER_NAME
type: Opaque
stringData:
  name: $CLUSTER_NAME
  server: $SERVER
  config: |
    {
      "bearerToken": "$TOKEN",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "$CA_DATA"
      }
    }
EOF
```

#### Step 4: Add Cluster Labels for ApplicationSets

Update cluster secrets with additional metadata:

```yaml
# cluster-with-labels.yaml
apiVersion: v1
kind: Secret
metadata:
  name: dev-cluster
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: cluster
    environment: dev
    region: us-west-2
    tier: non-prod
type: Opaque
stringData:
  name: dev-cluster
  server: https://172.18.0.2:6443
  config: |
    {
      "bearerToken": "<token>",
      "tlsClientConfig": {
        "insecure": false,
        "caData": "<ca-data>"
      }
    }
```

### Exercise 5: ApplicationSets with Cluster Generators

ApplicationSets are ideal for deploying applications across multiple clusters.

#### Step 1: Basic Cluster Generator

```yaml
# cluster-generator-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-multi-cluster
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: dev
        values:
          environment: dev
    - clusters:
        selector:
          matchLabels:
            environment: staging
        values:
          environment: staging
    - clusters:
        selector:
          matchLabels:
            environment: prod
        values:
          environment: prod
  template:
    metadata:
      name: 'guestbook-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps
        targetRevision: HEAD
        path: kustomize-guestbook/overlays/{{values.environment}}
      destination:
        server: '{{server}}'
        namespace: guestbook
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
          - CreateNamespace=true
```

Apply the ApplicationSet:

```bash
kubectl apply -f cluster-generator-appset.yaml
```

#### Step 2: Cluster Generator with Label Selector

```yaml
# tier-based-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: monitoring-stack
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchExpressions:
            - key: tier
              operator: In
              values:
                - prod
                - non-prod
  template:
    metadata:
      name: 'monitoring-{{name}}'
      labels:
        cluster: '{{name}}'
        tier: '{{metadata.labels.tier}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/platform-apps
        targetRevision: HEAD
        path: monitoring/base
      destination:
        server: '{{server}}'
        namespace: monitoring
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

#### Step 3: Cluster Generator with Values

```yaml
# cluster-values-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: platform-ingress
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            argocd.argoproj.io/secret-type: cluster
        values:
          # Default values
          replicas: "2"
          memory: "256Mi"
    - clusters:
        selector:
          matchLabels:
            environment: prod
        values:
          # Override for production
          replicas: "4"
          memory: "512Mi"
  template:
    metadata:
      name: 'ingress-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/platform-apps
        targetRevision: HEAD
        path: ingress-controller
        helm:
          valueFiles:
            - values.yaml
          parameters:
            - name: replicaCount
              value: '{{values.replicas}}'
            - name: resources.memory
              value: '{{values.memory}}'
      destination:
        server: '{{server}}'
        namespace: ingress-nginx
      syncPolicy:
        automated:
          selfHeal: true
```

### Exercise 6: Matrix and Merge Generators for Multi-Cluster

#### Step 1: Matrix Generator for Environments x Clusters

```yaml
# matrix-env-cluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: multi-env-multi-cluster
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
          - list:
              elements:
                - component: frontend
                  port: "80"
                - component: backend
                  port: "8080"
                - component: cache
                  port: "6379"
  template:
    metadata:
      name: '{{component}}-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/microservices
        targetRevision: HEAD
        path: '{{component}}'
        helm:
          parameters:
            - name: service.port
              value: '{{port}}'
            - name: cluster.name
              value: '{{name}}'
      destination:
        server: '{{server}}'
        namespace: microservices
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

#### Step 2: Merge Generator for Cluster-Specific Overrides

```yaml
# merge-cluster-overrides.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: app-with-cluster-overrides
  namespace: argocd
spec:
  generators:
    - merge:
        mergeKeys:
          - server
        generators:
          # Base configuration from all clusters
          - clusters:
              selector:
                matchLabels:
                  argocd.argoproj.io/secret-type: cluster
              values:
                replicas: "1"
                logLevel: "info"
                enableMetrics: "true"
          # Dev cluster overrides
          - clusters:
              selector:
                matchLabels:
                  environment: dev
              values:
                logLevel: "debug"
                enableMetrics: "false"
          # Production cluster overrides
          - clusters:
              selector:
                matchLabels:
                  environment: prod
              values:
                replicas: "5"
                logLevel: "warn"
  template:
    metadata:
      name: 'myapp-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/myapp
        targetRevision: HEAD
        path: deploy
        helm:
          parameters:
            - name: replicas
              value: '{{values.replicas}}'
            - name: logging.level
              value: '{{values.logLevel}}'
            - name: metrics.enabled
              value: '{{values.enableMetrics}}'
      destination:
        server: '{{server}}'
        namespace: myapp
```

### Exercise 7: Hub-and-Spoke Pattern Implementation

#### Step 1: Central ArgoCD Project Structure

```yaml
# hub-spoke-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: multi-cluster-platform
  namespace: argocd
spec:
  description: Multi-cluster platform applications
  sourceRepos:
    - 'https://github.com/your-org/*'
  destinations:
    # Allow deployments to all registered clusters
    - namespace: '*'
      server: '*'
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
  roles:
    - name: admin
      description: Admin access to all cluster applications
      policies:
        - p, proj:multi-cluster-platform:admin, applications, *, multi-cluster-platform/*, allow
        - p, proj:multi-cluster-platform:admin, clusters, get, *, allow
      groups:
        - platform-team
    - name: developer
      description: Read-only access to cluster applications
      policies:
        - p, proj:multi-cluster-platform:developer, applications, get, multi-cluster-platform/*, allow
        - p, proj:multi-cluster-platform:developer, applications, sync, multi-cluster-platform/*, allow
      groups:
        - developers
```

#### Step 2: Bootstrap Application for Each Cluster

```yaml
# cluster-bootstrap-appset.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-bootstrap
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            argocd.argoproj.io/secret-type: cluster
  template:
    metadata:
      name: 'bootstrap-{{name}}'
    spec:
      project: multi-cluster-platform
      source:
        repoURL: https://github.com/your-org/cluster-bootstrap
        targetRevision: HEAD
        path: 'clusters/{{name}}'
      destination:
        server: '{{server}}'
        namespace: argocd
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
```

#### Step 3: Per-Cluster Bootstrap Directory Structure

```text
cluster-bootstrap/
├── base/
│   ├── namespaces.yaml
│   ├── network-policies.yaml
│   └── resource-quotas.yaml
├── clusters/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── cluster-config.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── cluster-config.yaml
│   └── prod/
│       ├── kustomization.yaml
│       └── cluster-config.yaml
└── applications/
    ├── monitoring.yaml
    ├── logging.yaml
    └── ingress.yaml
```

Example base kustomization:

```yaml
# cluster-bootstrap/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespaces.yaml
  - network-policies.yaml
  - resource-quotas.yaml
```

Example dev overlay:

```yaml
# cluster-bootstrap/clusters/dev/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base
  - cluster-config.yaml
  - ../../applications/monitoring.yaml

patches:
  - path: patches/resource-quota-patch.yaml
```

### Exercise 8: Cross-Cluster Application Dependencies

#### Step 1: Sync Waves for Ordered Deployment

```yaml
# cross-cluster-sync-waves.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: ordered-multi-cluster-deploy
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            server: https://172.18.0.2:6443
            wave: "1"
          - cluster: staging
            server: https://172.18.0.3:6443
            wave: "2"
          - cluster: prod
            server: https://172.18.0.4:6443
            wave: "3"
  template:
    metadata:
      name: 'app-{{cluster}}'
      annotations:
        argocd.argoproj.io/sync-wave: '{{wave}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/myapp
        targetRevision: HEAD
        path: 'deploy/{{cluster}}'
      destination:
        server: '{{server}}'
        namespace: myapp
      syncPolicy:
        automated:
          selfHeal: true
```

#### Step 2: Progressive Delivery Across Clusters

```yaml
# progressive-multi-cluster.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: progressive-rollout
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: canary
            server: https://172.18.0.2:6443
            percentage: "5"
          - cluster: staging
            server: https://172.18.0.3:6443
            percentage: "20"
          - cluster: prod
            server: https://172.18.0.4:6443
            percentage: "100"
  strategy:
    type: RollingSync
    rollingSync:
      steps:
        - matchExpressions:
            - key: cluster
              operator: In
              values:
                - canary
        - matchExpressions:
            - key: cluster
              operator: In
              values:
                - staging
        - matchExpressions:
            - key: cluster
              operator: In
              values:
                - prod
  template:
    metadata:
      name: 'app-{{cluster}}'
      labels:
        cluster: '{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/myapp
        targetRevision: HEAD
        path: deploy
        helm:
          parameters:
            - name: trafficPercentage
              value: '{{percentage}}'
      destination:
        server: '{{server}}'
        namespace: myapp
```

### Exercise 9: Multi-Cluster Networking Considerations

#### Step 1: Service Discovery Across Clusters

When applications span multiple clusters, consider service discovery:

```yaml
# external-service-reference.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-external
  namespace: frontend
spec:
  type: ExternalName
  externalName: backend.myapp.svc.cluster-2.local
  ports:
    - port: 8080
```

#### Step 2: Cluster-Aware Configuration

```yaml
# cluster-aware-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-config
  namespace: myapp
data:
  cluster-name: "{{name}}"
  cluster-region: "{{metadata.labels.region}}"
  cluster-environment: "{{metadata.labels.environment}}"
  # Cross-cluster service endpoints
  BACKEND_URL: "http://backend.myapp.svc.{{name}}.local:8080"
  CACHE_URL: "redis://cache.myapp.svc.{{name}}.local:6379"
```

### Exercise 10: Monitoring Multi-Cluster Deployments

#### Step 1: ArgoCD Metrics for Multi-Cluster

```yaml
# argocd-metrics-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  endpoints:
    - port: metrics
      interval: 30s
  namespaceSelector:
    matchNames:
      - argocd
```

#### Step 2: Dashboard Configuration

Key metrics to monitor:

```text
Multi-Cluster Metrics:
├── argocd_app_info{dest_server="*"}        # Apps per cluster
├── argocd_app_sync_total{dest_server="*"}  # Syncs per cluster
├── argocd_cluster_info                      # Cluster status
├── argocd_cluster_api_requests_total        # API calls to clusters
└── argocd_cluster_connection_status         # Cluster connectivity
```

Prometheus query for cluster health:

```promql
# Applications out of sync per cluster
sum by (dest_server) (
  argocd_app_info{sync_status!="Synced"}
)

# Cluster connection failures
increase(argocd_cluster_api_requests_total{response_code!="200"}[5m])
```

## Clean Up Resources

### Remove Applications

```bash
kubectl delete applicationset --all -n argocd
```

### Delete Workload Clusters

```bash
kind delete cluster --name dev
kind delete cluster --name staging
kind delete cluster --name prod
```

### Delete Management Cluster

```bash
kind delete cluster --name management
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Create and configure multiple kind clusters
- [ ] Install ArgoCD on a management cluster
- [ ] Register external clusters using CLI and declarative methods
- [ ] Create cluster secrets with appropriate labels
- [ ] Deploy ApplicationSets with cluster generators
- [ ] Use matrix and merge generators for complex deployments
- [ ] Implement hub-and-spoke GitOps patterns
- [ ] Configure cluster-specific overrides
- [ ] Understand cross-cluster networking considerations

## Troubleshooting

### Cluster Connection Issues

```bash
# Check cluster connectivity
argocd cluster list

# Test kubectl access to cluster
kubectl --context kind-dev get nodes

# Check ArgoCD cluster secrets
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster

# Verify service account token
kubectl --context kind-dev get secret argocd-manager-token -n kube-system -o yaml
```

### ApplicationSet Not Generating Apps

```bash
# Check ApplicationSet status
kubectl get applicationset -n argocd -o yaml

# Check ApplicationSet controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Verify cluster labels match selectors
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=cluster --show-labels
```

### Cross-Cluster Sync Failures

```bash
# Check application sync status
argocd app list

# Get detailed app status
argocd app get <app-name>

# Check events on target cluster
kubectl --context kind-dev get events -n <namespace>
```

## Key Takeaways

1. **Hub-and-Spoke Pattern**: Central ArgoCD instance managing multiple clusters is most common
2. **Cluster Secrets**: Store cluster credentials as Kubernetes secrets with proper labels
3. **ApplicationSets**: Essential for managing applications across multiple clusters efficiently
4. **Generator Types**: Cluster, matrix, and merge generators enable flexible multi-cluster deployments
5. **Labels Matter**: Cluster labels enable targeted deployments with ApplicationSet selectors
6. **Progressive Delivery**: Use sync waves and rolling strategies for safe multi-cluster rollouts
7. **Service Accounts**: Create dedicated service accounts with minimal permissions for ArgoCD

## Next Steps

In Lab 6, we will cover:

- ArgoCD SSO/OIDC integration
- Advanced RBAC configuration
- ArgoCD notifications
- ArgoCD Image Updater
- Troubleshooting and monitoring best practices
