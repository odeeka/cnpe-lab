# Lab 1: ArgoCD Installation & Basics

## Objective

Install ArgoCD in your Kubernetes cluster, understand GitOps principles in practice, and deploy your first application using the GitOps approach.

## What You'll Learn

- Install ArgoCD using manifests
- Access ArgoCD UI and CLI
- Understand GitOps core principles
- Create and sync your first ArgoCD Application
- Monitor sync status and application health
- Perform manual and automatic sync operations

## Prerequisites

- Running kind cluster (from Module 1)
- kubectl configured
- GitHub account
- Git installed locally

## Lab Steps

### Step 1: Understanding GitOps Principles

Before installing ArgoCD, let's understand what makes GitOps different:

**The Four GitOps Principles (OpenGitOps):**

1. **Declarative**: The entire system is described declaratively (YAML/JSON)
2. **Versioned and Immutable**: Desired state is stored in Git (versioned, auditable)
3. **Pulled Automatically**: Agents automatically pull and apply state from Git
4. **Continuously Reconciled**: Agents ensure actual state matches desired state

**Traditional CI/CD (Push Model):**

```text
Developer → CI Pipeline → kubectl apply → Cluster
           (credentials needed)
```

**GitOps (Pull Model):**

```text
Developer → Git Commit → Git Repository ← ArgoCD → Cluster
           (no cluster credentials needed in CI)
```

**Why GitOps matters for Platform Engineers:**

- **Audit trail**: Every change is a Git commit
- **Disaster recovery**: Recreate entire cluster from Git
- **Consistency**: Same process for all environments
- **Security**: No cluster credentials in CI pipelines
- **Self-healing**: Automatic drift correction

### Step 2: Create Lab Namespace

```bash
kubectl create namespace argocd
```

### Step 3: Install ArgoCD

1. **Install ArgoCD using the official manifests:**

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

2. **Wait for all pods to be ready:**

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

3. **Verify the installation:**

```bash
kubectl get pods -n argocd
```

Expected output:

```text
NAME                                                READY   STATUS    RESTARTS   AGE
argocd-application-controller-0                     1/1     Running   0          2m
argocd-applicationset-controller-xxx                1/1     Running   0          2m
argocd-dex-server-xxx                               1/1     Running   0          2m
argocd-notifications-controller-xxx                 1/1     Running   0          2m
argocd-redis-xxx                                    1/1     Running   0          2m
argocd-repo-server-xxx                              1/1     Running   0          2m
argocd-server-xxx                                   1/1     Running   0          2m
```

### Step 4: Understand ArgoCD Components

Let's examine what was installed:

```bash
kubectl get all -n argocd
```

**Key Components:**

| Component | Purpose |
|-----------|---------|
| **argocd-server** | API server and Web UI |
| **argocd-repo-server** | Clones Git repos, generates manifests |
| **argocd-application-controller** | Watches applications, syncs state |
| **argocd-dex-server** | SSO/OIDC integration |
| **argocd-redis** | Caching layer |
| **argocd-applicationset-controller** | Manages ApplicationSets |
| **argocd-notifications-controller** | Sends notifications |

View the Custom Resource Definitions (CRDs) installed:

```bash
kubectl get crd | grep argo
```

Expected output:

```text
applications.argoproj.io
applicationsets.argoproj.io
appprojects.argoproj.io
```

### Step 5: Access ArgoCD UI

1. **Get the initial admin password:**

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo  # Add newline for readability
```

Save this password - you'll need it to log in.

2. **Port-forward to access the UI:**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

3. **Access the UI:**

Open https://localhost:8080 in your browser (accept the self-signed certificate warning).

- **Username**: `admin`
- **Password**: (from step 1)

4. **Explore the UI:**

- **Applications**: List of deployed applications (empty for now)
- **Settings**: Repositories, clusters, projects, accounts
- **User Info**: Current user and permissions

### Step 6: Install ArgoCD CLI

The CLI is essential for scripting and quick operations.

**Linux:**

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

**macOS:**

```bash
brew install argocd
```

**Verify installation:**

```bash
argocd version --client
```

### Step 7: Login to ArgoCD CLI

```bash
# Login (use the password from Step 5)
argocd login localhost:8080 --insecure --username admin --password <your-password>
```

Verify connection:

```bash
argocd cluster list
```

You should see your current cluster listed.

### Step 8: Create a GitOps Repository

For this lab, we'll use a public sample repository. In real scenarios, you'd create your own.

1. **Fork the sample repository (recommended) or use it directly:**

We'll use the official ArgoCD example apps:

```
https://github.com/argoproj/argocd-example-apps
```

This repository contains:

- `guestbook/`: Simple guestbook application
- `helm-guestbook/`: Same app as Helm chart
- `kustomize-guestbook/`: Same app with Kustomize
- Various other examples

### Step 9: Create Your First ArgoCD Application

**Method 1: Using the CLI**

```bash
argocd app create guestbook \
  --repo https://github.com/argoproj/argocd-example-apps.git \
  --path guestbook \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace default
```

**Method 2: Using YAML manifest (Declarative - Recommended)**

Save as `guestbook-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

Apply it:

```bash
kubectl apply -f guestbook-app.yaml
```

### Step 10: View Application Status

1. **Check via CLI:**

```bash
argocd app get guestbook
```

Expected output:

```text
Name:               argocd/guestbook
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          default
URL:                https://localhost:8080/applications/guestbook
Repo:               https://github.com/argoproj/argocd-example-apps.git
Target:             HEAD
Path:               guestbook
SyncWindow:         Sync Allowed
Sync Policy:        <none>
Sync Status:        OutOfSync from HEAD
Health Status:      Missing

GROUP  KIND        NAMESPACE  NAME          STATUS     HEALTH   HOOK  MESSAGE
       Service     default    guestbook-ui  OutOfSync  Missing
apps   Deployment  default    guestbook-ui  OutOfSync  Missing
```

Note the **Sync Status: OutOfSync** - this means the application exists in ArgoCD but hasn't been deployed yet.

2. **Check via UI:**

Refresh https://localhost:8080 - you should see the guestbook application card showing "OutOfSync".

### Step 11: Sync the Application

**Method 1: CLI**

```bash
argocd app sync guestbook
```

**Method 2: UI**

Click on the guestbook application → Click "SYNC" → Click "SYNCHRONIZE"

**Method 3: Auto-sync (we'll configure this later)**

Watch the sync progress:

```bash
argocd app get guestbook --refresh
```

Expected output after sync:

```text
Name:               argocd/guestbook
...
Sync Status:        Synced to HEAD
Health Status:      Healthy

GROUP  KIND        NAMESPACE  NAME          STATUS  HEALTH   HOOK  MESSAGE
       Service     default    guestbook-ui  Synced  Healthy
apps   Deployment  default    guestbook-ui  Synced  Healthy
```

### Step 12: Verify Deployment

```bash
# Check the deployed resources
kubectl get all -l app=guestbook-ui

# Check pods are running
kubectl get pods -l app=guestbook-ui
```

Access the guestbook application:

```bash
kubectl port-forward svc/guestbook-ui 9090:80 &
```

Open http://localhost:9090 in your browser.

### Step 13: Understand Sync Status and Health

ArgoCD tracks two main states:

**Sync Status:**

| Status | Meaning |
|--------|---------|
| **Synced** | Live state matches Git |
| **OutOfSync** | Live state differs from Git |
| **Unknown** | Unable to determine sync status |

**Health Status:**

| Status | Meaning |
|--------|---------|
| **Healthy** | All resources are healthy |
| **Progressing** | Resources are being created/updated |
| **Degraded** | Some resources have issues |
| **Suspended** | Resources are suspended (e.g., paused Rollout) |
| **Missing** | Resources don't exist yet |
| **Unknown** | Unable to determine health |

View detailed health:

```bash
argocd app get guestbook --show-operation
```

### Step 14: Simulate Drift Detection

One of GitOps' key features is detecting when someone manually changes the cluster.

1. **Make a manual change (simulating drift):**

```bash
kubectl scale deployment guestbook-ui --replicas=3
```

2. **Check ArgoCD status:**

```bash
argocd app get guestbook
```

Notice the status is now **OutOfSync** because the cluster state differs from Git.

3. **View the diff:**

```bash
argocd app diff guestbook
```

This shows exactly what changed.

4. **Self-heal (sync back to Git state):**

```bash
argocd app sync guestbook
```

The deployment is scaled back to 1 replica (matching Git).

### Step 15: Enable Auto-Sync

Auto-sync ensures ArgoCD automatically applies changes from Git:

```bash
argocd app set guestbook --sync-policy automated
```

Or update the Application YAML:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true      # Delete resources removed from Git
      selfHeal: true   # Revert manual changes
    syncOptions:
      - CreateNamespace=true
```

**Sync Policy Options:**

| Option | Purpose |
|--------|---------|
| `automated` | Enable auto-sync |
| `prune` | Delete resources no longer in Git |
| `selfHeal` | Automatically revert manual changes |
| `allowEmpty` | Allow syncing when no resources exist |

### Step 16: Configure Sync Options

Sync options control how resources are applied:

```yaml
syncPolicy:
  syncOptions:
    - CreateNamespace=true      # Create namespace if missing
    - PruneLast=true            # Prune after other resources synced
    - ApplyOutOfSyncOnly=true   # Only apply changed resources
    - Validate=true             # Validate manifests before applying
    - RespectIgnoreDifferences=true  # Respect ignore rules
```

### Step 17: View Application History

ArgoCD tracks all sync operations:

```bash
argocd app history guestbook
```

This shows:

- Revision deployed
- Time of deployment
- Who initiated the sync
- Sync result

### Step 18: Rollback (If Needed)

Rollback to a previous revision:

```bash
# List history
argocd app history guestbook

# Rollback to specific revision
argocd app rollback guestbook <REVISION_NUMBER>
```

Note: This creates a new sync to the old Git commit, not a Kubernetes rollback.

## Validation

Verify your lab completion:

```bash
# Check ArgoCD is installed
kubectl get pods -n argocd | grep -c Running

# Check application exists and is synced
argocd app get guestbook | grep "Sync Status"

# Check application is healthy
argocd app get guestbook | grep "Health Status"

# Verify resources exist
kubectl get deployment guestbook-ui
```

Expected results:

- All ArgoCD pods running (7 pods)
- Sync Status: Synced
- Health Status: Healthy
- guestbook-ui deployment exists

## Practice Challenges

### Challenge 1: Deploy Helm Guestbook

Create an ArgoCD Application for the Helm version:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-helm
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: helm-guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: helm-guestbook
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

### Challenge 2: Deploy with Kustomize

Create an Application for the Kustomize version:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: guestbook-kustomize
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: kustomize-guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: kustomize-guestbook
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
```

### Challenge 3: Test Self-Healing

1. Enable self-heal on the guestbook app
2. Manually delete the deployment: `kubectl delete deployment guestbook-ui`
3. Watch ArgoCD automatically recreate it
4. Check the ArgoCD events/logs

### Challenge 4: Change Admin Password

Change the admin password for security:

```bash
argocd account update-password
```

## Cleanup

To remove applications but keep ArgoCD:

```bash
argocd app delete guestbook --cascade
argocd app delete guestbook-helm --cascade
argocd app delete guestbook-kustomize --cascade
```

To completely remove ArgoCD (end of module):

```bash
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

## Troubleshooting

### ArgoCD server not starting

Check events:

```bash
kubectl describe pod -n argocd -l app.kubernetes.io/name=argocd-server
```

Common issues:

- Insufficient resources (increase kind node resources)
- Network policies blocking traffic

### Application stuck in "Progressing"

Check application events:

```bash
argocd app get guestbook --show-operation
kubectl describe application guestbook -n argocd
```

Common causes:

- Image pull errors
- Insufficient resources
- Pod scheduling issues

### Sync failed

View sync details:

```bash
argocd app sync guestbook --dry-run
argocd app manifests guestbook
```

Check for:

- Invalid YAML syntax
- Missing CRDs
- RBAC issues

### Cannot access UI

Ensure port-forward is running:

```bash
# Kill existing port-forward
pkill -f "port-forward.*argocd"

# Start new one
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

## Key Takeaways

- ArgoCD implements GitOps by continuously reconciling cluster state with Git
- Applications are defined declaratively as Kubernetes resources
- Sync status shows whether cluster matches Git
- Health status shows whether resources are functioning
- Auto-sync enables hands-off deployments
- Self-heal automatically reverts manual changes
- ArgoCD tracks history for audit and rollback
- CLI and UI provide different but complementary workflows

## Additional Resources

- [ArgoCD Getting Started Guide](https://argo-cd.readthedocs.io/en/stable/getting_started/)
- [ArgoCD Core Concepts](https://argo-cd.readthedocs.io/en/stable/core_concepts/)
- [Application Specification](https://argo-cd.readthedocs.io/en/stable/operator-manual/application.yaml)
- [Sync Options](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)

## Next Lab

Continue to [Lab 2: Application Deployment Patterns](../lab-02-app-patterns/) to learn about Kustomize, Helm, App of Apps, and ApplicationSets.

---

[Back to Module 2 README](../README.md) | [Next: Lab 2 - App Patterns](../lab-02-app-patterns/)
