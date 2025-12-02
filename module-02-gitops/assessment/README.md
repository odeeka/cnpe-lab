# Module 2: GitOps and Continuous Delivery - Assessment

## Overview

This assessment evaluates your understanding and practical skills in GitOps and continuous delivery with ArgoCD. Complete all tasks to demonstrate your proficiency in the concepts covered in Module 2.

## Assessment Information

- **Time Limit**: 3 hours
- **Total Tasks**: 20
- **Passing Score**: 70% (14 out of 20 tasks)
- **Environment**: kind cluster with ArgoCD installed

## Prerequisites

Before starting the assessment:

1. Ensure you have a running kind cluster
2. Install ArgoCD on the cluster
3. Have the ArgoCD CLI configured
4. Access to a Git repository for testing

## Setup Instructions

Create a fresh environment:

```bash
# Create kind cluster
kind create cluster --name gitops-assessment

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Assessment Tasks

### Task 1: ArgoCD Application Creation (CLI)

Create an ArgoCD Application using the CLI with the following specifications:

- **Application Name**: `guestbook-cli`
- **Project**: `default`
- **Repository**: `https://github.com/argoproj/argocd-example-apps`
- **Path**: `guestbook`
- **Destination Server**: `https://kubernetes.default.svc`
- **Destination Namespace**: `guestbook`
- **Sync Policy**: Manual

**Verification**:

```bash
argocd app get guestbook-cli
```

---

### Task 2: Declarative Application

Create a declarative ArgoCD Application manifest file for:

- **Application Name**: `nginx-declarative`
- **Repository**: `https://github.com/argoproj/argocd-example-apps`
- **Path**: `nginx`
- **Namespace**: `nginx-app`
- **Auto-sync enabled with self-heal and prune**
- **CreateNamespace sync option enabled**

Apply the manifest to the cluster.

**Verification**:

```bash
kubectl get application nginx-declarative -n argocd -o yaml
```

---

### Task 3: Sync Waves

Create an Application with resources that use sync waves:

1. Create a ConfigMap with sync-wave: "-1"
2. Create a Deployment with sync-wave: "0"
3. Create a Service with sync-wave: "1"

The Application should deploy these in order.

**Verification**:

```bash
argocd app get <app-name> --show-operation
```

---

### Task 4: AppProject Configuration

Create an AppProject named `team-backend` with:

- Only allow sources from `https://github.com/your-org/backend-*`
- Only allow deployments to namespaces starting with `backend-`
- Only allow deployment to the in-cluster Kubernetes
- Define a `developer` role with sync and get permissions

**Verification**:

```bash
kubectl get appproject team-backend -n argocd -o yaml
```

---

### Task 5: Kustomize Application

Create an Application that uses Kustomize overlays:

1. Set up a base directory with a Deployment and Service
2. Create a `dev` overlay that changes replica count to 1
3. Create a `prod` overlay that changes replica count to 3
4. Deploy the `dev` overlay using ArgoCD

**Verification**:

```bash
argocd app get <app-name>
kubectl get deployment -n <namespace> -o jsonpath='{.items[0].spec.replicas}'
```

---

### Task 6: Helm Application with Values

Create an ArgoCD Application that deploys a Helm chart with:

- Custom values file
- Parameter overrides
- Release name specified

Use any public Helm chart (e.g., bitnami/nginx).

**Verification**:

```bash
argocd app get <app-name>
```

---

### Task 7: App of Apps Pattern

Implement the App of Apps pattern:

1. Create a parent Application that manages child Applications
2. The parent should deploy at least 3 child Applications
3. Each child Application should deploy a different component

**Verification**:

```bash
argocd app list
# Should show parent and all child applications
```

---

### Task 8: ApplicationSet with List Generator

Create an ApplicationSet that deploys the same application to multiple namespaces using a List generator:

- Deploy to `dev`, `staging`, and `prod` namespaces
- Each should have environment-specific labels

**Verification**:

```bash
kubectl get applicationset -n argocd
argocd app list
```

---

### Task 9: ApplicationSet with Git Generator

Create an ApplicationSet using a Git directory generator that:

- Scans a directory structure
- Creates an Application for each subdirectory found

**Verification**:

```bash
kubectl get applicationset -n argocd -o yaml
```

---

### Task 10: Argo Rollouts - Canary

Install Argo Rollouts and create a Canary deployment:

1. Install the Argo Rollouts controller
2. Create a Rollout with canary strategy
3. Configure steps: 20% -> pause -> 50% -> pause -> 100%
4. Create an AnalysisTemplate for the rollout

**Verification**:

```bash
kubectl get rollout -n <namespace>
kubectl argo rollouts get rollout <name> -n <namespace>
```

---

### Task 11: Argo Rollouts - Blue/Green

Create a Blue/Green deployment using Argo Rollouts:

1. Create a Rollout with blueGreen strategy
2. Configure preview and active services
3. Set autoPromotionEnabled to false
4. Perform a rollout and manually promote

**Verification**:

```bash
kubectl argo rollouts get rollout <name> -n <namespace>
```

---

### Task 12: Sealed Secrets

Set up Sealed Secrets for GitOps:

1. Install the Sealed Secrets controller
2. Create a regular Secret
3. Seal the Secret using kubeseal
4. Deploy the SealedSecret via ArgoCD

**Verification**:

```bash
kubectl get sealedsecret -n <namespace>
kubectl get secret -n <namespace>
```

---

### Task 13: Sync Policies

Create an Application with specific sync policies:

- Auto-sync enabled
- Self-heal enabled
- Prune enabled
- Retry on failure (5 attempts, 5s backoff, max 3m)
- Replace instead of apply for a specific resource

**Verification**:

```bash
kubectl get application <name> -n argocd -o yaml | grep -A 30 syncPolicy
```

---

### Task 14: Resource Hooks

Create an Application that uses resource hooks:

1. PreSync hook: Job that validates configuration
2. PostSync hook: Job that sends notification
3. SyncFail hook: Job that logs failure details

**Verification**:

```bash
kubectl get jobs -n <namespace>
argocd app get <app-name> --show-operation
```

---

### Task 15: Multi-Cluster Registration

Register an external cluster with ArgoCD:

1. Create a second kind cluster
2. Register it with ArgoCD
3. Deploy an application to the external cluster

**Verification**:

```bash
argocd cluster list
argocd app get <app-name>
```

---

### Task 16: RBAC Configuration

Configure RBAC for ArgoCD:

1. Create a policy that grants `developers` group:
   - Read access to all applications
   - Sync access to applications in `dev-*` projects only
2. Create a policy that grants `admins` group full access

**Verification**:

```bash
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

---

### Task 17: Notifications Setup

Configure ArgoCD Notifications:

1. Create a webhook notification service
2. Create templates for sync success and failure
3. Create triggers for the templates
4. Subscribe an application to the notifications

**Verification**:

```bash
kubectl get configmap argocd-notifications-cm -n argocd -o yaml
kubectl get application <name> -n argocd -o yaml | grep notifications
```

---

### Task 18: Repository Credentials

Configure repository credentials in ArgoCD:

1. Add a private repository using SSH key authentication
2. Add a private repository using HTTPS with username/password
3. Add a Helm repository with credentials

**Verification**:

```bash
argocd repo list
```

---

### Task 19: Health Assessment Customization

Create custom health checks for a CRD:

1. Add a custom resource health check in argocd-cm
2. The health check should evaluate based on a custom status field

**Verification**:

```bash
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 20 "resource.customizations"
```

---

### Task 20: Disaster Recovery

Demonstrate ArgoCD disaster recovery:

1. Export all ArgoCD Applications
2. Export all AppProjects
3. Export ArgoCD settings (ConfigMaps and Secrets)
4. Create a script that can restore ArgoCD from backups

**Verification**:

Provide the backup files and restoration script.

---

## Assessment Completion

### Submission Checklist

For each task, ensure you have:

- [ ] Completed the required configuration
- [ ] Verified the task using the provided commands
- [ ] Documented any issues encountered
- [ ] Captured screenshots or output as evidence

### Cleanup

After completing the assessment:

```bash
# Delete assessment cluster
kind delete cluster --name gitops-assessment

# Delete any secondary clusters
kind delete cluster --name external-cluster
```

## Scoring Rubric

Each task is worth 5 points:

| Points | Criteria |
|--------|----------|
| 5 | Task completed correctly with all requirements met |
| 4 | Task completed with minor issues |
| 3 | Task partially completed (50-75% of requirements) |
| 2 | Task attempted but significantly incomplete |
| 1 | Task attempted with minimal progress |
| 0 | Task not attempted |

**Passing Score**: 70 points (14 tasks fully completed)

## Additional Notes

- You may use official ArgoCD documentation during the assessment
- Focus on understanding the concepts, not just copying commands
- If a task cannot be completed, document what you attempted and why it failed
- Time management is important - don't spend too long on any single task

## Tips for Success

1. **Read Each Task Carefully**: Ensure you understand all requirements before starting
2. **Verify Your Work**: Use the provided verification commands
3. **Document Issues**: If something doesn't work, document what you tried
4. **Manage Time**: Allocate roughly 9 minutes per task
5. **Use Resources Wisely**: Reference documentation when needed

Good luck with your assessment!
