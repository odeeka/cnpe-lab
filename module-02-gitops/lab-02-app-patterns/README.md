# Lab 2: Application Deployment Patterns

## Objective

Master different application deployment patterns with ArgoCD including Kustomize overlays, Helm charts, App of Apps pattern, and ApplicationSets for managing multiple applications at scale.

## What You'll Learn

- Deploy applications using Kustomize overlays
- Configure Helm charts with ArgoCD
- Implement the App of Apps pattern
- Use ApplicationSets for dynamic application generation
- Manage application dependencies and sync waves
- Override values per environment

## Prerequisites

- Completed Lab 1 (ArgoCD installed and running)
- ArgoCD CLI configured
- Understanding of Kustomize and Helm basics

## Lab Steps

### Step 1: Setup Lab Environment

```bash
# Ensure ArgoCD port-forward is running
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Verify CLI connection
argocd app list
```

### Step 2: Understanding Deployment Patterns

ArgoCD supports multiple ways to define applications:

| Pattern | Best For | Complexity |
|---------|----------|------------|
| **Plain YAML** | Simple apps, learning | Low |
| **Kustomize** | Environment variations | Medium |
| **Helm** | Complex apps, community charts | Medium |
| **App of Apps** | Managing related apps | High |
| **ApplicationSets** | Dynamic, large-scale deployments | High |

### Step 3: Kustomize-Based Deployments

Kustomize allows you to customize applications per environment without templates.

#### Understanding Kustomize Structure

```text
app/
├── base/                  # Common resources
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── overlays/
    ├── dev/               # Development overrides
    │   └── kustomization.yaml
    ├── staging/           # Staging overrides
    │   └── kustomization.yaml
    └── prod/              # Production overrides
        └── kustomization.yaml
```

#### Create a Kustomize Application

1. **First, let's explore the existing Kustomize example:**

```bash
# View the kustomize-guestbook structure
argocd app create kustomize-example \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path kustomize-guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace kustomize-example \
  --sync-option CreateNamespace=true
```

2. **Sync and verify:**

```bash
argocd app sync kustomize-example
argocd app get kustomize-example
```

#### Create Your Own Kustomize App (Local Example)

Create a local GitOps repository structure. Save as `kustomize-demo/base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      containers:
      - name: nginx
        image: nginx:1.25
        ports:
        - containerPort: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
```

Save as `kustomize-demo/base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

Save as `kustomize-demo/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  managed-by: argocd
```

Save as `kustomize-demo/overlays/dev/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

namePrefix: dev-

patches:
  - target:
      kind: Deployment
      name: web-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1

commonLabels:
  environment: dev
```

Save as `kustomize-demo/overlays/prod/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: prod

resources:
  - ../../base

namePrefix: prod-

patches:
  - target:
      kind: Deployment
      name: web-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "128Mi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "256Mi"

commonLabels:
  environment: prod
```

### Step 4: Helm-Based Deployments

Helm charts are widely used for complex applications.

#### Deploy a Helm Chart from ArgoCD Example

```bash
argocd app create helm-guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path helm-guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace helm-demo \
  --sync-option CreateNamespace=true
```

Sync it:

```bash
argocd app sync helm-guestbook
```

#### Override Helm Values

**Method 1: Using CLI**

```bash
argocd app set helm-guestbook --helm-set replicaCount=3
argocd app set helm-guestbook --helm-set service.type=NodePort
argocd app sync helm-guestbook
```

**Method 2: Using Application YAML**

Save as `helm-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-nginx
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://charts.bitnami.com/bitnami
    chart: nginx
    targetRevision: 15.4.4
    helm:
      releaseName: my-nginx
      values: |
        replicaCount: 2
        service:
          type: ClusterIP
          port: 80
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
  destination:
    server: https://kubernetes.default.svc
    namespace: nginx-demo
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```bash
kubectl apply -f helm-app.yaml
argocd app sync helm-nginx
```

#### Using Values Files from Git

For more complex configurations, store values in Git:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: helm-from-values-file
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/your-gitops-repo.git
    targetRevision: HEAD
    path: charts/my-app
    helm:
      valueFiles:
        - values.yaml
        - values-prod.yaml    # Environment-specific overrides
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
```

### Step 5: App of Apps Pattern

The App of Apps pattern uses a parent Application to manage child Applications.

#### Create App of Apps Structure

Save as `apps/root-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

The `apps/` directory contains Application manifests:

```
apps/
├── guestbook.yaml
├── helm-guestbook.yaml
└── kustomize-guestbook.yaml
```

Each file is an Application manifest pointing to the actual app:

Save as `apps/guestbook.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: guestbook
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

#### Create a Local App of Apps Demo

Let's create a complete App of Apps structure:

Save as `app-of-apps/root.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
```

Apply the root app:

```bash
kubectl apply -f app-of-apps/root.yaml
```

Watch ArgoCD create all child applications:

```bash
argocd app list
```

### Step 6: ApplicationSets

ApplicationSets dynamically generate Applications based on generators.

#### List Generator (Multiple Clusters/Environments)

Save as `appset-list.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: guestbook-envs
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - env: dev
            namespace: guestbook-dev
            replicas: "1"
          - env: staging
            namespace: guestbook-staging
            replicas: "2"
          - env: prod
            namespace: guestbook-prod
            replicas: "3"
  template:
    metadata:
      name: 'guestbook-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: guestbook
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          selfHeal: true
          prune: true
        syncOptions:
          - CreateNamespace=true
```

Apply and verify:

```bash
kubectl apply -f appset-list.yaml

# Watch applications being created
argocd app list
```

You'll see three applications created automatically:

- `guestbook-dev`
- `guestbook-staging`
- `guestbook-prod`

#### Git Generator (Directory-Based)

Generate apps based on directories in a Git repository:

Save as `appset-git-dirs.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-from-dirs
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        revision: HEAD
        directories:
          - path: "*"
          - path: apps
            exclude: true
  template:
    metadata:
      name: '{{path.basename}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/argoproj/argocd-example-apps.git
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
      syncPolicy:
        syncOptions:
          - CreateNamespace=true
```

#### Git Generator (File-Based)

Generate apps from config files in Git:

Save as `appset-git-files.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: apps-from-config
  namespace: argocd
spec:
  generators:
    - git:
        repoURL: https://github.com/your-org/config-repo.git
        revision: HEAD
        files:
          - path: "config/**/config.json"
  template:
    metadata:
      name: '{{name}}'
    spec:
      project: default
      source:
        repoURL: '{{repoURL}}'
        targetRevision: '{{targetRevision}}'
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
```

Where `config/app1/config.json` contains:

```json
{
  "name": "my-app",
  "repoURL": "https://github.com/org/app.git",
  "targetRevision": "main",
  "path": "deploy",
  "namespace": "my-app"
}
```

#### Matrix Generator (Combining Generators)

Combine multiple generators for complex scenarios:

Save as `appset-matrix.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: cluster-apps
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          # First generator: environments
          - list:
              elements:
                - env: dev
                  url: https://kubernetes.default.svc
                - env: prod
                  url: https://kubernetes.default.svc
          # Second generator: applications
          - list:
              elements:
                - app: frontend
                  path: apps/frontend
                - app: backend
                  path: apps/backend
                - app: database
                  path: apps/database
  template:
    metadata:
      name: '{{app}}-{{env}}'
    spec:
      project: default
      source:
        repoURL: https://github.com/your-org/apps.git
        targetRevision: HEAD
        path: '{{path}}/{{env}}'
      destination:
        server: '{{url}}'
        namespace: '{{app}}-{{env}}'
      syncPolicy:
        automated:
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

This creates: `frontend-dev`, `frontend-prod`, `backend-dev`, `backend-prod`, `database-dev`, `database-prod`

### Step 7: Sync Waves and Hooks

Control the order of resource deployment.

#### Using Sync Waves

Resources with lower wave numbers sync first:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "-1"  # Sync first
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "0"   # Sync second
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "1"   # Sync third
```

#### Using Hooks

Hooks run at specific points in the sync process:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migration
  annotations:
    argocd.argoproj.io/hook: PreSync        # Run before sync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: my-app:latest
        command: ["./migrate.sh"]
      restartPolicy: Never
```

**Hook Types:**

| Hook | When it Runs |
|------|--------------|
| `PreSync` | Before sync begins |
| `Sync` | During sync (with resources) |
| `PostSync` | After all resources synced |
| `SyncFail` | If sync fails |
| `Skip` | Skip this resource during sync |

**Delete Policies:**

| Policy | Behavior |
|--------|----------|
| `HookSucceeded` | Delete after hook succeeds |
| `HookFailed` | Delete if hook fails |
| `BeforeHookCreation` | Delete before creating new hook |

### Step 8: Resource Tracking and Ignore Differences

#### Ignore Specific Fields

Some fields change at runtime (e.g., last-applied-configuration):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  # ... other spec
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas    # Ignore replica changes (for HPA)
    - group: ""
      kind: Service
      jqPathExpressions:
        - .spec.clusterIP   # Ignore clusterIP (auto-assigned)
```

#### Global Ignore Differences

Configure in ArgoCD ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  resource.customizations.ignoreDifferences.all: |
    jsonPointers:
      - /metadata/annotations/kubectl.kubernetes.io~1last-applied-configuration
```

## Validation

Verify your lab completion:

```bash
# Check Kustomize app
argocd app get kustomize-example | grep "Sync Status"

# Check Helm app  
argocd app get helm-nginx | grep "Health Status"

# Check ApplicationSet created apps
argocd app list | grep guestbook

# Count total applications
argocd app list | wc -l
```

## Practice Challenges

### Challenge 1: Multi-Environment Deployment

Create an ApplicationSet that deploys the same app to:

- `dev` namespace with 1 replica
- `staging` namespace with 2 replicas  
- `prod` namespace with 3 replicas

Use labels to identify environments.

### Challenge 2: Helm with Multiple Values Files

Create a Helm-based Application that uses:

- Base `values.yaml`
- Environment-specific `values-prod.yaml`

Configure proper merge behavior.

### Challenge 3: Sync Wave Pipeline

Create a deployment that uses sync waves:

- Wave -1: Namespace
- Wave 0: ConfigMaps and Secrets
- Wave 1: Database Deployment
- Wave 2: Application Deployment
- Wave 3: Ingress

### Challenge 4: Combined ApplicationSet

Create a Matrix ApplicationSet combining:

- 2 clusters (simulated with namespaces)
- 3 applications (frontend, backend, api)

## Cleanup

```bash
# Delete ApplicationSets (this removes generated apps)
kubectl delete applicationset -n argocd --all

# Delete individual apps
argocd app delete helm-nginx --cascade
argocd app delete kustomize-example --cascade

# Verify cleanup
argocd app list
```

## Troubleshooting

### Kustomize build fails

Test Kustomize locally:

```bash
kustomize build overlays/prod
```

Common issues:

- Wrong paths in kustomization.yaml
- Missing base resources
- Invalid patch syntax

### Helm values not applied

Check rendered manifests:

```bash
argocd app manifests helm-nginx
```

Verify values:

```bash
argocd app get helm-nginx -o yaml | grep -A 20 helm
```

### ApplicationSet not creating apps

Check ApplicationSet status:

```bash
kubectl describe applicationset -n argocd <name>
```

Look for generator errors in events.

### Sync waves not working

Ensure annotations are correct:

```bash
kubectl get deployment -o yaml | grep sync-wave
```

Check wave values are strings, not integers.

## Key Takeaways

- Kustomize is ideal for environment-specific overlays without templates
- Helm provides full templating and chart ecosystem access
- App of Apps centralizes management of related applications
- ApplicationSets enable dynamic, scalable app generation
- Sync waves control deployment order for dependencies
- Hooks enable pre/post sync operations (migrations, tests)
- Ignore differences prevent false drift on dynamic fields

## Additional Resources

- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Helm Support](https://argo-cd.readthedocs.io/en/stable/user-guide/helm/)
- [ApplicationSet Controller](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
- [Sync Waves and Hooks](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)

## Next Lab

Continue to [Lab 3: Progressive Delivery with Argo Rollouts](../lab-03-rollouts/) to learn about Canary and Blue/Green deployments.

---

[Back to Module 2 README](../README.md) | [Previous: Lab 1](../lab-01-argocd-setup/) | [Next: Lab 3](../lab-03-rollouts/)
