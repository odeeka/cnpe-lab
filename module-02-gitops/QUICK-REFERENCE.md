# Module 2: GitOps and Continuous Delivery - Quick Reference

## ArgoCD CLI Commands

### Authentication

```bash
# Login to ArgoCD
argocd login <ARGOCD_SERVER> --username admin --password <password>

# Login with SSO
argocd login <ARGOCD_SERVER> --sso

# Get current context
argocd context

# Logout
argocd logout <ARGOCD_SERVER>
```

### Application Management

```bash
# List all applications
argocd app list

# Create application
argocd app create <name> \
  --repo <repo-url> \
  --path <path> \
  --dest-server <cluster-url> \
  --dest-namespace <namespace>

# Get application details
argocd app get <name>

# Sync application
argocd app sync <name>

# Sync with specific resources
argocd app sync <name> --resource <group>:<kind>:<name>

# Sync with prune
argocd app sync <name> --prune

# Diff application
argocd app diff <name>

# Delete application
argocd app delete <name>

# Delete with cascade (delete resources)
argocd app delete <name> --cascade

# Refresh application
argocd app get <name> --refresh

# Hard refresh (clear cache)
argocd app get <name> --hard-refresh

# View application history
argocd app history <name>

# Rollback to previous revision
argocd app rollback <name> <history-id>
```

### Cluster Management

```bash
# List clusters
argocd cluster list

# Add cluster
argocd cluster add <context-name> --name <display-name>

# Remove cluster
argocd cluster rm <server-url>

# Get cluster info
argocd cluster get <server-url>
```

### Repository Management

```bash
# List repositories
argocd repo list

# Add repository (HTTPS)
argocd repo add <repo-url> --username <user> --password <token>

# Add repository (SSH)
argocd repo add <repo-url> --ssh-private-key-path <key-path>

# Remove repository
argocd repo rm <repo-url>
```

### Project Management

```bash
# List projects
argocd proj list

# Create project
argocd proj create <name>

# Get project details
argocd proj get <name>

# Delete project
argocd proj delete <name>

# Add source repo to project
argocd proj add-source <project> <repo-url>

# Add destination to project
argocd proj add-destination <project> <cluster-url> <namespace>
```

## Application Manifest Templates

### Basic Application

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: HEAD
    path: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
```

### Application with Auto-Sync

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: HEAD
    path: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### Application with Kustomize

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/repo
    targetRevision: HEAD
    path: overlays/production
    kustomize:
      namePrefix: prod-
      commonLabels:
        env: production
      images:
        - myapp=myregistry/myapp:v1.2.3
  destination:
    server: https://kubernetes.default.svc
    namespace: production
```

### Application with Helm

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.example.com
    chart: my-chart
    targetRevision: 1.0.0
    helm:
      releaseName: my-release
      valueFiles:
        - values-production.yaml
      parameters:
        - name: replicaCount
          value: "3"
        - name: image.tag
          value: v1.2.3
  destination:
    server: https://kubernetes.default.svc
    namespace: production
```

### AppProject

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-project
  namespace: argocd
spec:
  description: Team Project
  sourceRepos:
    - 'https://github.com/org/*'
  destinations:
    - namespace: 'team-*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
  roles:
    - name: developer
      policies:
        - p, proj:team-project:developer, applications, sync, team-project/*, allow
      groups:
        - developers
```

### ApplicationSet with List Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-appset
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - cluster: dev
            url: https://dev-cluster:6443
          - cluster: prod
            url: https://prod-cluster:6443
  template:
    metadata:
      name: 'myapp-{{cluster}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo
        targetRevision: HEAD
        path: 'deploy/{{cluster}}'
      destination:
        server: '{{url}}'
        namespace: myapp
```

### ApplicationSet with Cluster Generator

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-appset
  namespace: argocd
spec:
  generators:
    - clusters:
        selector:
          matchLabels:
            environment: production
  template:
    metadata:
      name: 'myapp-{{name}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/org/repo
        targetRevision: HEAD
        path: deploy
      destination:
        server: '{{server}}'
        namespace: myapp
```

## Argo Rollouts Commands

### Rollout Management

```bash
# Get rollout status
kubectl argo rollouts get rollout <name> -n <namespace>

# Watch rollout
kubectl argo rollouts get rollout <name> -n <namespace> -w

# Promote rollout
kubectl argo rollouts promote <name> -n <namespace>

# Abort rollout
kubectl argo rollouts abort <name> -n <namespace>

# Retry rollout
kubectl argo rollouts retry rollout <name> -n <namespace>

# Undo rollout
kubectl argo rollouts undo <name> -n <namespace>

# Set image
kubectl argo rollouts set image <name> <container>=<image> -n <namespace>

# Pause rollout
kubectl argo rollouts pause <name> -n <namespace>

# Resume rollout
kubectl argo rollouts resume <name> -n <namespace>

# List rollouts
kubectl argo rollouts list rollouts -n <namespace>
```

### Rollout Dashboard

```bash
# Start dashboard
kubectl argo rollouts dashboard -n <namespace>
```

## Rollout Templates

### Canary Rollout

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-rollout
spec:
  replicas: 5
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: myapp:v1
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 1m}
        - setWeight: 50
        - pause: {duration: 2m}
        - setWeight: 80
        - pause: {duration: 1m}
      canaryService: my-app-canary
      stableService: my-app-stable
```

### Blue/Green Rollout

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: my-rollout
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: myapp:v1
  strategy:
    blueGreen:
      activeService: my-app-active
      previewService: my-app-preview
      autoPromotionEnabled: false
      prePromotionAnalysis:
        templates:
          - templateName: smoke-test
      postPromotionAnalysis:
        templates:
          - templateName: integration-test
```

### AnalysisTemplate

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 1m
      count: 5
      successCondition: result[0] >= 0.95
      provider:
        prometheus:
          address: http://prometheus:9090
          query: |
            sum(rate(http_requests_total{service="{{args.service-name}}",status=~"2.."}[5m])) /
            sum(rate(http_requests_total{service="{{args.service-name}}"}[5m]))
```

## Sync Waves and Hooks

### Sync Wave Annotations

```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Deploy first
    argocd.argoproj.io/sync-wave: "0"   # Default
    argocd.argoproj.io/sync-wave: "1"   # Deploy later
```

### Resource Hooks

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync    # Before sync
    argocd.argoproj.io/hook: Sync       # During sync
    argocd.argoproj.io/hook: PostSync   # After sync
    argocd.argoproj.io/hook: SyncFail   # On sync failure
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
```

## Sealed Secrets Commands

```bash
# Install kubeseal CLI
brew install kubeseal

# Seal a secret
kubeseal --format yaml < secret.yaml > sealed-secret.yaml

# Seal with specific controller
kubeseal --controller-name=sealed-secrets \
         --controller-namespace=kube-system \
         --format yaml < secret.yaml > sealed-secret.yaml

# Fetch certificate
kubeseal --fetch-cert --controller-name=sealed-secrets \
         --controller-namespace=kube-system > cert.pem

# Seal using certificate
kubeseal --cert cert.pem --format yaml < secret.yaml > sealed-secret.yaml
```

## Common Troubleshooting

### Application Issues

```bash
# Check application status
argocd app get <name>

# View application events
kubectl get events -n argocd --field-selector involvedObject.name=<app-name>

# Check sync status
argocd app get <name> --show-operation

# View resource tree
argocd app resources <name>

# Check application conditions
argocd app get <name> --show-conditions
```

### Sync Issues

```bash
# Dry run sync
argocd app sync <name> --dry-run

# Force sync
argocd app sync <name> --force

# Sync with replace
argocd app sync <name> --replace

# Sync specific resource
argocd app sync <name> --resource <group>:<kind>:<name>
```

### Controller Logs

```bash
# Application controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Repo server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server

# API server
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server

# ApplicationSet controller
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller

# Image updater
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

### Common Errors

| Error | Cause | Solution |
|-------|-------|----------|
| ComparisonError | Resource comparison failed | Check resource customizations |
| OutOfSync | Desired vs live mismatch | Sync or adjust ignore differences |
| SyncError | Sync operation failed | Check resource manifests |
| HealthError | Resource health check failed | Check pods/deployments |
| Degraded | Application unhealthy | Check underlying resources |

## RBAC Quick Reference

### Policy Format

```text
p, <subject>, <resource>, <action>, <object>, <effect>
g, <user/group>, <role>
```

### Resources and Actions

| Resource | Actions |
|----------|---------|
| applications | get, create, update, delete, sync, override, action/* |
| clusters | get, create, update, delete |
| repositories | get, create, update, delete |
| projects | get, create, update, delete |
| logs | get |
| exec | create |

### Common Policies

```csv
# Admin access
p, role:admin, *, *, */*, allow

# Developer access (read + sync)
p, role:developer, applications, get, */*, allow
p, role:developer, applications, sync, */*, allow

# Read-only access
p, role:viewer, applications, get, */*, allow
p, role:viewer, repositories, get, *, allow

# Team-specific access
p, role:team-a, applications, *, team-a/*, allow
```

## Useful kubectl Commands

```bash
# Get all ArgoCD resources
kubectl get applications,appprojects,applicationsets -n argocd

# Watch application status
kubectl get applications -n argocd -w

# Get application in YAML
kubectl get application <name> -n argocd -o yaml

# Patch application
kubectl patch application <name> -n argocd --type merge -p '{"spec":{"syncPolicy":{"automated":{"prune":true}}}}'

# Get ArgoCD ConfigMaps
kubectl get configmap -n argocd

# Get ArgoCD Secrets
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| ARGOCD_SERVER | ArgoCD server address |
| ARGOCD_AUTH_TOKEN | API token for authentication |
| ARGOCD_OPTS | Additional CLI options |
| ARGOCD_GRPC_WEB | Use gRPC-web protocol |

## Important Ports

| Service | Port | Description |
|---------|------|-------------|
| argocd-server | 443/80 | API/UI server |
| argocd-server | 8083 | Metrics |
| argocd-repo-server | 8081 | Repository server |
| argocd-repo-server | 8084 | Metrics |
| argocd-dex-server | 5556 | Dex OIDC |
| argocd-redis | 6379 | Redis cache |
