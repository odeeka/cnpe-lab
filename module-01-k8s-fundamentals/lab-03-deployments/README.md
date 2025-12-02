# Lab 3: Deployments & ReplicaSets

## Objective

Master Kubernetes Deployments - the standard way to run stateless applications. Learn scaling, rolling updates, rollbacks, and deployment strategies.

## What You'll Learn

- Understand the relationship between Deployments, ReplicaSets, and Pods
- Create and manage Deployments
- Scale applications horizontally
- Perform rolling updates with zero downtime
- Rollback failed deployments
- Implement different deployment strategies
- Configure update parameters (maxSurge, maxUnavailable)

## Prerequisites

- Completed Labs 1 & 2
- kind cluster running
- Basic understanding of Pods

## Lab Steps

### Step 1: Understanding the Hierarchy

```text
Deployment
    └── ReplicaSet
            ├── Pod 1
            ├── Pod 2
            └── Pod 3
```

- **Deployment**: Declarative updates, rollback capability
- **ReplicaSet**: Ensures desired number of pod replicas
- **Pod**: The actual running container(s)

1. **Create namespace**:

```bash
kubectl create namespace lab-03
kubectl config set-context --current --namespace=lab-03
```

### Step 2: Create Your First Deployment

1. **Create deployment imperatively**:

```bash
kubectl create deployment nginx --image=nginx:1.25 --replicas=3
```

2. **Observe the cascade**:

```bash
# View deployment

kubectl get deployment nginx

# View replicaset (note the hash suffix)

kubectl get replicaset

# View pods (note they include RS hash)

kubectl get pods

# View all together

kubectl get deployment,replicaset,pod
```

3. **Understand naming**:

- Deployment: `nginx`
- ReplicaSet: `nginx-<template-hash>`
- Pods: `nginx-<template-hash>-<random>`

4. **Describe the deployment**:

```bash
kubectl describe deployment nginx
```

Notice:

- Replicas: desired, current, ready
- StrategyType: RollingUpdate
- Events: Scaled up replica set

### Step 3: Declarative Deployment with YAML

1. **Create a comprehensive deployment**:

Save as `deployment-webapp.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
  labels:
    app: webapp
spec:
  replicas: 3
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
        version: v1
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
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
```

2. **Apply the deployment**:

```bash
kubectl apply -f deployment-webapp.yaml
```

3. **Watch rollout status**:

```bash
kubectl rollout status deployment webapp
```

4. **Verify all replicas are ready**:

```bash
kubectl get deployment webapp
# READY should show 3/3
```

### Step 4: Scaling Applications

1. **Scale up imperatively**:

```bash
kubectl scale deployment webapp --replicas=5
```

2. **Watch the scaling**:

```bash
kubectl get pods -l app=webapp --watch
```

3. **Scale down**:

```bash
kubectl scale deployment webapp --replicas=2
```

Notice pods are terminated gracefully.

4. **Scale via YAML** (declarative approach):

Edit `deployment-webapp.yaml` and change `replicas: 2` to `replicas: 4`, then:

```bash
kubectl apply -f deployment-webapp.yaml
```

5. **Autoscaling** (preview - covered more in Lab 7):

```bash
kubectl autoscale deployment webapp --min=2 --max=10 --cpu-percent=80
kubectl get hpa
```

### Step 5: Rolling Updates (Zero Downtime)

1. **Check current image version**:

```bash
kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
```

2. **Update to new version**:

```bash
kubectl set image deployment webapp nginx=nginx:1.26
```

3. **Watch the rolling update**:

```bash
# Terminal 1 - watch rollout

kubectl rollout status deployment webapp

# Terminal 2 - watch pods

kubectl get pods -l app=webapp --watch

# Terminal 3 - watch replicasets

kubectl get replicaset -l app=webapp --watch
```

You'll observe:

- New ReplicaSet is created
- New pods are created progressively
- Old pods are terminated progressively
- Both old and new versions coexist briefly

4. **Check rollout history**:
```bash
kubectl rollout history deployment webapp
```

5. **View specific revision**:
```bash
kubectl rollout history deployment webapp --revision=2
```

### Step 6: Rollback Deployments

1. **Simulate a bad deployment**:
```bash
kubectl set image deployment webapp nginx=nginx:bad-tag
```

2. **Watch it fail**:
```bash
kubectl rollout status deployment webapp
```

It will hang because the new pods can't start (ImagePullBackOff).

3. **Check pod status**:
```bash
kubectl get pods -l app=webapp
```

Notice old pods are still running (deployment ensures availability).

4. **Rollback to previous version**:
```bash
kubectl rollout undo deployment webapp
```

5. **Verify rollback**:
```bash
kubectl rollout status deployment webapp
kubectl get pods -l app=webapp
```

6. **Rollback to specific revision**:
```bash
# View history

kubectl rollout history deployment webapp

# Rollback to specific revision

kubectl rollout undo deployment webapp --to-revision=1
```

### Step 7: Deployment Strategies

1. **Configure Rolling Update parameters**:

Save as `deployment-rolling.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-rolling
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 3          # Max pods above desired during update
      maxUnavailable: 2    # Max pods unavailable during update
  selector:
    matchLabels:
      app: webapp-rolling
  template:
    metadata:
      labels:
        app: webapp-rolling
    spec:
      containers:

      - name: nginx
        image: nginx:1.25
        ports:

        - containerPort: 80
```

Apply and update:
```bash
kubectl apply -f deployment-rolling.yaml
kubectl set image deployment webapp-rolling nginx=nginx:1.26
kubectl get pods -l app=webapp-rolling --watch
```

Observe the update pattern with maxSurge=3 and maxUnavailable=2.

2. **Recreate Strategy** (brief downtime):

Save as `deployment-recreate.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-recreate
spec:
  replicas: 5
  strategy:
    type: Recreate  # Kill all old pods, then start new ones
  selector:
    matchLabels:
      app: webapp-recreate
  template:
    metadata:
      labels:
        app: webapp-recreate
    spec:
      containers:

      - name: nginx
        image: nginx:1.25
        ports:

        - containerPort: 80
```

Apply and update:
```bash
kubectl apply -f deployment-recreate.yaml
kubectl set image deployment webapp-recreate nginx=nginx:1.26
kubectl get pods -l app=webapp-recreate --watch
```

Notice all old pods terminate before new ones start.

### Step 8: Pause and Resume Rollouts

Useful when making multiple changes.

1. **Pause a deployment**:
```bash
kubectl rollout pause deployment webapp
```

2. **Make multiple changes**:
```bash
kubectl set image deployment webapp nginx=nginx:1.27
kubectl set resources deployment webapp -c=nginx --limits=cpu=300m,memory=256Mi
```

3. **Verify no rollout happened**:
```bash
kubectl rollout status deployment webapp
# Shows: "deployment is paused"
```

4. **Resume the rollout**:
```bash
kubectl rollout resume deployment webapp
```

All changes are applied in a single rollout.

### Step 9: Deployment with Annotations and Record

1. **Use --record flag** (deprecated but useful to know):
```bash
kubectl set image deployment webapp nginx=nginx:1.26 --record
```

2. **Add change-cause annotation**:
```bash
kubectl annotate deployment webapp kubernetes.io/change-cause="Updated to nginx 1.26 for security patch"
```

3. **View in history**:
```bash
kubectl rollout history deployment webapp
```

The CHANGE-CAUSE column shows your annotation.

### Step 10: Selector and Template Labels

Understanding label matching is crucial.

1. **Create deployment with specific selectors**:

Save as `deployment-labels.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-labels
spec:
  replicas: 3
  selector:
    matchLabels:      # Pods must have ALL these labels
      app: webapp
      tier: frontend
  template:
    metadata:
      labels:         # Pod template labels (must include selector labels)
        app: webapp
        tier: frontend
        version: v1
        env: production
    spec:
      containers:

      - name: nginx
        image: nginx:1.25
```

2. **Apply and verify**:
```bash
kubectl apply -f deployment-labels.yaml
kubectl get pods --show-labels -l app=webapp,tier=frontend
```

3. **Demonstrate selector immutability**:

Try to change selector (this will fail):
```bash
# Edit and try to change matchLabels

kubectl edit deployment webapp-labels
```

Selectors are immutable after creation!

### Step 11: Manual Pod Deletion (Self-Healing)

1. **Delete a pod manually**:
```bash
# Get a pod name

POD_NAME=$(kubectl get pod -l app=webapp -o jsonpath='{.items[0].metadata.name}')

# Delete it

kubectl delete pod $POD_NAME

# Immediately check

kubectl get pods -l app=webapp
```

A new pod is immediately created to maintain desired replicas!

2. **Simulate node failure**:
```bash
# Delete multiple pods at once

kubectl delete pods -l app=webapp --force --grace-period=0

# Watch recovery

kubectl get pods -l app=webapp --watch
```

ReplicaSet ensures desired state is maintained.

## Validation

Verify your understanding:

```bash
# 1. Check webapp deployment has 4 replicas running

kubectl get deployment webapp -o jsonpath='{.status.readyReplicas}'
# Should show: 4

# 2. Verify rollout history exists

kubectl rollout history deployment webapp | grep -c "REVISION"
# Should be > 1

# 3. Check all deployments are ready

kubectl get deployments -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="Available")].status}{"\n"}{end}'
# All should show True

# 4. Count total pods managed by deployments

kubectl get pods -o jsonpath='{range .items[*]}{.metadata.ownerReferences[0].kind}{"\n"}{end}' | grep ReplicaSet | wc -l
```bash
## Practice Challenges

Test your skills:

1. **Challenge 1**: Create a deployment with 5 replicas, then update it with maxUnavailable=0 and maxSurge=1. What happens during update?
   <details>
   <summary>Hint</summary>
   Only one pod above desired count at a time, no pods go down until new ones are ready.
   </details>

2. **Challenge 2**: Create a deployment, perform 3 image updates, then rollback to the first version.
   <details>
   <summary>Solution Steps</summary>
   ```bash
   kubectl create deployment test --image=nginx:1.25
   kubectl set image deployment test nginx=nginx:1.26
   kubectl set image deployment test nginx=nginx:1.27
   kubectl rollout history deployment test
   kubectl rollout undo deployment test --to-revision=1
   ```
   </details>

3. **Challenge 3**: Create a deployment that uses matchExpressions selector (not matchLabels).
   <details>
   <summary>Hint</summary>
   ```yaml
   selector:
     matchExpressions:

     - key: app
       operator: In
       values: [webapp, web]
   ```
   </details>

4. **Challenge 4**: Deploy an app with 10 replicas. Update with maxSurge=50% and maxUnavailable=50%. Observe the update behavior.
   <details>
   <summary>Explanation</summary>
   With 10 replicas: maxSurge allows up to 5 extra pods, maxUnavailable allows 5 to be down. Update will be aggressive with up to 15 pods during rollout.
   </details>

## Cleanup

Remove all resources:

```bash
kubectl delete namespace lab-03
```bash
## Troubleshooting Guide

| Issue | Diagnostic Command | Common Cause |
|-------|-------------------|--------------|
| Deployment not progressing | `kubectl describe deployment <name>` | Image pull errors, resource constraints |
| Pods keep restarting | `kubectl logs <pod>` | Application crashes, liveness probe failing |
| Rollout stuck | `kubectl rollout status deployment <name>` | Readiness probe failing on new pods |
| Old pods not terminating | `kubectl describe pod <name>` | PreStop hooks taking too long |
| Can't update selector | Check if editing existing deployment | Selectors are immutable |

**Key debugging commands**:
```bash
kubectl describe deployment <name>
kubectl rollout status deployment <name>
kubectl rollout history deployment <name>
kubectl get events --sort-by='.lastTimestamp'
kubectl logs deployment/<name>
```

## Key Takeaways

- ✅ Deployments provide declarative updates and rollback capability
- ✅ ReplicaSets ensure desired number of pod replicas
- ✅ Rolling updates enable zero-downtime deployments
- ✅ maxSurge and maxUnavailable control update aggressiveness
- ✅ Rollback can restore any previous revision
- ✅ Selectors are immutable after deployment creation
- ✅ Self-healing: pods are automatically recreated if deleted
- ✅ Pause/Resume allows batching multiple changes
- ✅ Deployments are ideal for stateless applications

## Additional Resources

- [Deployments Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)
- [Rolling Update Tutorial](https://kubernetes.io/docs/tutorials/kubernetes-basics/update/update-intro/)
- [ReplicaSet Documentation](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/)

## Next Lab

[Lab 4: Services & Networking](../lab-04-services/) - Learn how to expose and access your applications

---

**Estimated Time**: 90-120 minutes
