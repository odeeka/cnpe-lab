# Lab 4: GitOps Workflows & Best Practices

## Objective

Design and implement production-ready GitOps workflows including repository structures, environment promotion strategies, secret management, and operational best practices.

## What You'll Learn

- Design GitOps repository structures (monorepo vs polyrepo)
- Implement environment promotion workflows
- Configure sync policies, waves, and hooks
- Manage secrets securely in GitOps
- Implement drift detection and remediation
- Establish naming conventions and standards

## Prerequisites

- Completed Labs 1-3
- ArgoCD running with CLI configured
- Git basics (branching, PRs)

## Lab Steps

### Step 1: Repository Structure Patterns

#### Pattern 1: Monorepo (Single Repository)

All applications and configurations in one repository:

```
gitops-repo/
├── apps/                      # Application definitions
│   ├── frontend/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── dev/
│   │       ├── staging/
│   │       └── prod/
│   ├── backend/
│   │   ├── base/
│   │   └── overlays/
│   └── database/
│       ├── base/
│       └── overlays/
├── infrastructure/            # Platform components
│   ├── cert-manager/
│   ├── ingress-nginx/
│   └── monitoring/
├── clusters/                  # Cluster-specific configs
│   ├── dev-cluster/
│   ├── staging-cluster/
│   └── prod-cluster/
└── argocd/                    # ArgoCD Application definitions
    ├── apps.yaml              # App of Apps
    └── projects/
```

**Pros:**

- Single source of truth
- Easy to understand relationships
- Atomic changes across components
- Simplified access control

**Cons:**

- Can become large and unwieldy
- Longer clone times
- Blast radius of mistakes is larger

#### Pattern 2: Polyrepo (Multiple Repositories)

Separate repositories for different concerns:

```
# Application repos (owned by dev teams)
frontend-app/
├── src/                       # Application code
├── Dockerfile
├── helm/                      # Helm chart
└── .github/workflows/

backend-app/
├── src/
├── Dockerfile
└── helm/

# GitOps config repo (owned by platform team)
gitops-config/
├── apps/
│   ├── frontend/
│   │   ├── dev/values.yaml
│   │   ├── staging/values.yaml
│   │   └── prod/values.yaml
│   └── backend/
├── infrastructure/
└── argocd/

# Infrastructure repo (owned by platform team)
infrastructure/
├── terraform/
├── crossplane/
└── helm-charts/
```

**Pros:**

- Clear ownership boundaries
- Independent release cycles
- Smaller, focused repositories
- Better for large organizations

**Cons:**

- More complex to manage
- Cross-repo changes require coordination
- More repositories to maintain

#### Pattern 3: Environment Branches

Use branches for environments (simpler but has drawbacks):

```
main         → prod
staging      → staging  
development  → dev
```

**Not Recommended Because:**

- Difficult to track what's deployed where
- Merge conflicts between environments
- No clear promotion path
- Harder to audit

#### Recommended: Monorepo with Directory-Based Environments

```
gitops/
├── base/                      # Shared base configs
├── environments/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   └── patches/
│   └── prod/
│       ├── kustomization.yaml
│       └── patches/
└── argocd/
    └── applicationsets.yaml
```

### Step 2: Create a GitOps Repository Structure

Let's create a complete GitOps structure:

```bash
mkdir -p gitops-demo/{apps,infrastructure,argocd}
mkdir -p gitops-demo/apps/web-app/{base,overlays/{dev,staging,prod}}
cd gitops-demo
```

Save as `apps/web-app/base/deployment.yaml`:

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
      - name: web-app
        image: nginx:1.25
        ports:
        - containerPort: 80
        env:
        - name: ENVIRONMENT
          value: "base"
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 15
          periodSeconds: 20
```

Save as `apps/web-app/base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-app
spec:
  type: ClusterIP
  selector:
    app: web-app
  ports:
  - port: 80
    targetPort: 80
```

Save as `apps/web-app/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app.kubernetes.io/name: web-app
  app.kubernetes.io/managed-by: argocd
```

Save as `apps/web-app/overlays/dev/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

resources:
  - ../../base

namePrefix: dev-

commonLabels:
  environment: dev

patches:
  - target:
      kind: Deployment
      name: web-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 1
      - op: replace
        path: /spec/template/spec/containers/0/env/0/value
        value: "development"
```

Save as `apps/web-app/overlays/staging/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: staging

resources:
  - ../../base

namePrefix: staging-

commonLabels:
  environment: staging

patches:
  - target:
      kind: Deployment
      name: web-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 2
      - op: replace
        path: /spec/template/spec/containers/0/env/0/value
        value: "staging"
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "128Mi"
```

Save as `apps/web-app/overlays/prod/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: prod

resources:
  - ../../base

namePrefix: prod-

commonLabels:
  environment: prod

patches:
  - target:
      kind: Deployment
      name: web-app
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 3
      - op: replace
        path: /spec/template/spec/containers/0/env/0/value
        value: "production"
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "256Mi"
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: "512Mi"
```

### Step 3: Environment Promotion Strategies

#### Strategy 1: Pull Request Promotion

```
Feature Branch → dev → PR to staging → staging → PR to prod → prod
```

Workflow:

1. Developer creates feature branch
2. CI builds and tests
3. Merge to `main` triggers dev deployment
4. Create PR from `dev/` to `staging/` overlay
5. Review and approve
6. Merge triggers staging deployment
7. Create PR from `staging/` to `prod/` overlay
8. Review, approve, merge for prod deployment

#### Strategy 2: Image Tag Promotion

Same config, different image tags:

```yaml
# dev overlay
images:
  - name: myapp
    newTag: dev-abc123

# staging overlay  
images:
  - name: myapp
    newTag: staging-abc123

# prod overlay
images:
  - name: myapp
    newTag: v1.2.3  # Semantic versioning for prod
```

Promotion flow:

1. CI builds image with commit SHA
2. Update dev overlay with new tag
3. After validation, update staging with same digest
4. After staging validation, tag as release version
5. Update prod overlay with release tag

#### Strategy 3: Automated Promotion with ArgoCD Image Updater

ArgoCD Image Updater can automatically update image tags:

Save as `argocd/image-updater-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app-dev
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: myapp=myregistry/myapp
    argocd-image-updater.argoproj.io/myapp.update-strategy: latest
    argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^dev-.*
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  # ... application spec
```

### Step 4: Sync Policies and Configuration

#### Configure Sync Options

Save as `argocd/app-with-sync-policy.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: web-app-prod
  namespace: argocd
spec:
  project: production
  source:
    repoURL: https://github.com/org/gitops.git
    targetRevision: HEAD
    path: apps/web-app/overlays/prod
  destination:
    server: https://kubernetes.default.svc
    namespace: prod
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
      - ApplyOutOfSyncOnly=true
      - Validate=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Sync Options Explained:**

| Option | Purpose |
|--------|---------|
| `CreateNamespace=true` | Create namespace if missing |
| `PrunePropagationPolicy` | How to delete resources (foreground/background/orphan) |
| `PruneLast=true` | Prune after sync, not during |
| `ApplyOutOfSyncOnly=true` | Only apply changed resources |
| `Validate=true` | Validate manifests before applying |
| `ServerSideApply=true` | Use server-side apply |
| `RespectIgnoreDifferences=true` | Honor ignoreDifferences during sync |

#### Sync Waves for Dependencies

Create ordered deployments with sync waves:

```yaml
# Wave -1: Namespace and RBAC
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  annotations:
    argocd.argoproj.io/sync-wave: "-1"
---
# Wave 0: ConfigMaps and Secrets
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  annotations:
    argocd.argoproj.io/sync-wave: "0"
---
# Wave 1: Database
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: database
  annotations:
    argocd.argoproj.io/sync-wave: "1"
---
# Wave 2: Application (depends on database)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app
  annotations:
    argocd.argoproj.io/sync-wave: "2"
---
# Wave 3: Ingress (depends on app)
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
  annotations:
    argocd.argoproj.io/sync-wave: "3"
```

#### Hooks for Pre/Post Actions

```yaml
# Pre-sync: Database migration
apiVersion: batch/v1
kind: Job
metadata:
  name: db-migrate
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: myapp:latest
        command: ["./migrate.sh"]
      restartPolicy: Never
  backoffLimit: 1
---
# Post-sync: Smoke test
apiVersion: batch/v1
kind: Job
metadata:
  name: smoke-test
  annotations:
    argocd.argoproj.io/hook: PostSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
spec:
  template:
    spec:
      containers:
      - name: test
        image: curlimages/curl:latest
        command: ["curl", "-f", "http://app-service/health"]
      restartPolicy: Never
  backoffLimit: 3
```

### Step 5: Secret Management in GitOps

Secrets should NEVER be stored in plain text in Git.

#### Option 1: Sealed Secrets

1. **Install Sealed Secrets controller:**

```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

2. **Install kubeseal CLI:**

```bash
# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/kubeseal-0.24.0-linux-amd64.tar.gz
tar -xvzf kubeseal-0.24.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

3. **Create and seal a secret:**

```bash
# Create a regular secret
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=supersecret \
  --dry-run=client -o yaml > secret.yaml

# Seal it
kubeseal --format yaml < secret.yaml > sealed-secret.yaml
```

4. **The sealed secret can be committed to Git:**

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: db-creds
  namespace: default
spec:
  encryptedData:
    password: AgBy8h...encrypted...
    username: AgCtr...encrypted...
```

#### Option 2: External Secrets Operator

1. **Install External Secrets:**

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
```

2. **Create a SecretStore (AWS Secrets Manager example):**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: default
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
```

3. **Create an ExternalSecret:**

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-creds
  namespace: default
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: db-creds
    creationPolicy: Owner
  data:
    - secretKey: username
      remoteRef:
        key: prod/database
        property: username
    - secretKey: password
      remoteRef:
        key: prod/database
        property: password
```

#### Option 3: SOPS (Secrets OPerationS)

1. **Encrypt secrets with SOPS:**

```bash
# Using age encryption
sops --encrypt --age age1... secret.yaml > secret.enc.yaml
```

2. **Configure ArgoCD to decrypt:**

```yaml
# In argocd-cm ConfigMap
data:
  kustomize.buildOptions: --enable-alpha-plugins
```

3. **Use ksops plugin in your kustomization:**

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

generators:
  - secret-generator.yaml
```

### Step 6: ArgoCD Projects for Multi-Tenancy

Projects provide isolation and access control:

Save as `argocd/projects/production.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: production
  namespace: argocd
spec:
  description: Production environment project
  
  # Source repositories
  sourceRepos:
    - 'https://github.com/org/gitops-prod.git'
    - 'https://charts.bitnami.com/*'
  
  # Destination clusters and namespaces
  destinations:
    - namespace: 'prod-*'
      server: https://kubernetes.default.svc
    - namespace: 'production'
      server: https://kubernetes.default.svc
  
  # Allowed cluster resources
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: 'networking.k8s.io'
      kind: Ingress
  
  # Namespace-scoped resources
  namespaceResourceWhitelist:
    - group: ''
      kind: '*'
    - group: 'apps'
      kind: '*'
  
  # Deny destructive actions
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange
  
  # Roles for the project
  roles:
    - name: developer
      description: Read-only access for developers
      policies:
        - p, proj:production:developer, applications, get, production/*, allow
        - p, proj:production:developer, applications, sync, production/*, deny
      groups:
        - developers
    
    - name: deployer
      description: Deployment access
      policies:
        - p, proj:production:deployer, applications, *, production/*, allow
      groups:
        - sre-team
  
  # Sync windows (only sync during business hours)
  syncWindows:
    - kind: allow
      schedule: '0 9-17 * * 1-5'  # Mon-Fri 9am-5pm
      duration: 8h
      applications:
        - '*'
    - kind: deny
      schedule: '0 0 * * 0'  # No Sunday deploys
      duration: 24h
      applications:
        - '*'
```

### Step 7: Notifications Configuration

Configure notifications for deployment events:

Save as `argocd/notifications-cm.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Slack service configuration
  service.slack: |
    token: $slack-token
  
  # Notification templates
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} has been deployed!
      Sync Status: {{.app.status.sync.status}}
      Health: {{.app.status.health.status}}
      Revision: {{.app.status.sync.revision}}
  
  template.app-health-degraded: |
    message: |
      :warning: Application {{.app.metadata.name}} is degraded!
      Health: {{.app.status.health.status}}
      Message: {{.app.status.health.message}}
  
  # Triggers
  trigger.on-deployed: |
    - when: app.status.sync.status == 'Synced' and app.status.health.status == 'Healthy'
      send: [app-deployed]
  
  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]
  
  # Default subscriptions
  subscriptions: |
    - recipients:
        - slack:deployments
      triggers:
        - on-deployed
        - on-health-degraded
```

Apply notifications to an application:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-deployed.slack: deployments-channel
    notifications.argoproj.io/subscribe.on-health-degraded.slack: alerts-channel
```

### Step 8: Naming Conventions and Standards

Establish consistent naming:

**Applications:**

```
<app-name>-<environment>
Examples:
  web-app-dev
  web-app-staging
  web-app-prod
```

**Namespaces:**

```
<team>-<app>-<environment>
Examples:
  frontend-web-dev
  backend-api-prod
```

**Labels:**

```yaml
labels:
  app.kubernetes.io/name: web-app
  app.kubernetes.io/instance: web-app-prod
  app.kubernetes.io/version: "1.2.3"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: ecommerce
  app.kubernetes.io/managed-by: argocd
  environment: prod
  team: frontend
```

**Annotations:**

```yaml
annotations:
  argocd.argoproj.io/sync-wave: "1"
  owner: frontend-team@company.com
  documentation: https://wiki.company.com/web-app
```

## Validation

Verify your lab completion:

```bash
# Check repository structure exists
ls -la gitops-demo/

# Verify overlays work with Kustomize
kustomize build gitops-demo/apps/web-app/overlays/dev
kustomize build gitops-demo/apps/web-app/overlays/prod

# Check sealed-secrets controller (if installed)
kubectl get pods -n kube-system | grep sealed

# List ArgoCD projects
argocd proj list
```

## Practice Challenges

### Challenge 1: Complete GitOps Repository

Create a complete GitOps repository with:

- 3 applications (frontend, backend, database)
- 3 environments (dev, staging, prod)
- Proper Kustomize overlays
- Sync waves for dependencies
- Pre-sync migration hook

### Challenge 2: Sealed Secrets Workflow

1. Install Sealed Secrets
2. Create a secret with database credentials
3. Seal and commit to Git
4. Deploy via ArgoCD
5. Verify secret is created in cluster

### Challenge 3: Project with Sync Windows

Create a project that:

- Only allows syncs during business hours
- Restricts which namespaces can be used
- Has separate roles for viewers and deployers
- Limits which resource types can be deployed

### Challenge 4: Environment Promotion Pipeline

Implement a promotion workflow:

1. App deployed to dev automatically
2. PR-based promotion to staging
3. Manual approval for prod
4. Notifications at each stage

## Cleanup

```bash
# Remove demo directory
rm -rf gitops-demo/

# Remove sealed-secrets (if installed)
kubectl delete -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
```

## Key Takeaways

- Monorepo with directory-based environments is often the best starting point
- PR-based promotion provides audit trail and review process
- Sync waves ensure proper resource ordering
- Never store plain secrets in Git - use Sealed Secrets or External Secrets
- Projects provide multi-tenancy and access control
- Sync windows prevent accidental off-hours deployments
- Notifications keep teams informed of changes
- Consistent naming conventions improve maintainability

## Additional Resources

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [External Secrets Operator](https://external-secrets.io/)
- [GitOps Patterns](https://www.gitops.tech/)
- [ArgoCD Notifications](https://argocd-notifications.readthedocs.io/)

## Next Lab

Continue to [Lab 5: Multi-Cluster GitOps](../lab-05-multi-cluster/) to learn about managing multiple clusters with ArgoCD.

---

[Back to Module 2 README](../README.md) | [Previous: Lab 3](../lab-03-rollouts/) | [Next: Lab 5](../lab-05-multi-cluster/)
