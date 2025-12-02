# Module 1 Assessment: Kubernetes Fundamentals

## Assessment Overview

This assessment tests your practical knowledge of Kubernetes fundamentals through real-world scenarios. Complete all challenges to validate your mastery of Module 1.

**Time Limit**: 3-4 hours
**Passing Score**: 70% (14/20 tasks)
**Open Book**: You may reference Kubernetes documentation

## Prerequisites

- Completed all 8 labs in Module 1
- kind cluster running
- kubectl configured

## Setup

```bash
# Create assessment namespace

kubectl create namespace cnpe-assessment

# Set context

kubectl config set-context --current --namespace=cnpe-assessment

# Record start time

date
```

## Assessment Tasks

### Part 1: Pod Management (20 points)

#### Task 1.1: Multi-Container Pod (5 points)

Create a pod named `log-processor` with:

- Main container: `nginx:1.25` serving on port 80
- Sidecar container: `busybox:1.36` tailing logs from shared volume
- Init container: Creates initial log file with message "System initialized"
- Shared emptyDir volume mounted at `/var/log/app` in both containers

<details>
<summary>Validation</summary>

```bash
kubectl get pod log-processor
# Should show 2/2 READY

kubectl logs log-processor -c sidecar
# Should show log content
```
</details>

#### Task 1.2: Resource-Constrained Pod (5 points)

Create a pod named `resource-pod` with:

- Image: `nginx:1.25`
- CPU request: 100m, limit: 200m
- Memory request: 128Mi, limit: 256Mi
- QoS class must be: Burstable
- Labels: `tier=backend`, `env=prod`

<details>
<summary>Validation</summary>

```bash
kubectl get pod resource-pod -o jsonpath='{.status.qosClass}'
# Should output: Burstable

kubectl describe pod resource-pod | grep -A 4 "Limits\|Requests"
```
</details>

#### Task 1.3: Pod with Probes (5 points)

Create a pod named `healthy-app` with:

- Image: `nginx:1.25`
- Liveness probe: HTTP GET on port 80, path `/`, every 10s
- Readiness probe: HTTP GET on port 80, path `/`, every 5s
- Startup probe: HTTP GET on port 80, path `/`, 30 attempts, 10s interval

<details>
<summary>Validation</summary>

```bash
kubectl describe pod healthy-app | grep -A 5 "Liveness\|Readiness\|Startup"
```
</details>

#### Task 1.4: Pod Debugging (5 points)

A pod named `broken-pod` has been created but is failing. Debug and fix it.

```bash
# Create the broken pod

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: broken-pod
spec:
  containers:

  - name: app
    image: nginx:1.25
    volumeMounts:

    - name: config
      mountPath: /etc/config
  volumes:

  - name: config
    configMap:
      name: missing-config
EOF
```bash
**Your task**: Identify the issue and fix it by creating the necessary resource.

<details>
<summary>Hint</summary>
Check what's missing with `kubectl describe pod broken-pod`
</details>

---

### Part 2: Deployments & Scaling (20 points)

#### Task 2.1: Create and Scale Deployment (5 points)

Create a deployment named `webapp` with:

- Image: `nginx:1.25`
- Initial replicas: 3
- Labels: `app=webapp`
- Rolling update strategy: maxSurge=1, maxUnavailable=0
- Each pod should have CPU request of 100m and memory request of 128Mi

Then scale it to 5 replicas.

<details>
<summary>Validation</summary>

```bash
kubectl get deployment webapp
# Should show 5/5 READY

kubectl describe deployment webapp | grep -A 2 "RollingUpdate"
```bash
</details>

#### Task 2.2: Perform Rolling Update (5 points)

Update the `webapp` deployment to use `nginx:1.26` and verify:

- Update is performed using rolling update strategy
- No downtime occurs (all replicas don't go down simultaneously)
- Rollout completes successfully

<details>
<summary>Validation</summary>

```bash
kubectl rollout history deployment webapp
# Should show at least 2 revisions

kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should output: nginx:1.26
```bash
</details>

#### Task 2.3: Rollback Deployment (5 points)

Perform a bad update on `webapp` (use image `nginx:invalid-tag`), then rollback to the previous working version.

<details>
<summary>Validation</summary>

```bash
kubectl get deployment webapp
# Should show all replicas ready

kubectl get deployment webapp -o jsonpath='{.spec.template.spec.containers[0].image}'
# Should output: nginx:1.26 (rolled back)
```
</details>

#### Task 2.4: Deployment with Annotations (5 points)

Add a change-cause annotation to the current deployment revision explaining the rollback.

<details>
<summary>Validation</summary>

```bash
kubectl rollout history deployment webapp
# Should show CHANGE-CAUSE with your annotation
```
</details>

---

### Part 3: Services & Networking (15 points)

#### Task 3.1: ClusterIP Service (5 points)

Create a ClusterIP service named `webapp-svc` that:

- Selects pods with label `app=webapp`
- Exposes port 8080 (service port)
- Targets port 80 (container port)
- Verify DNS resolution works

<details>
<summary>Validation</summary>

```bash
kubectl get service webapp-svc
# Should show ClusterIP type

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- nslookup webapp-svc
# Should resolve successfully

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://webapp-svc:8080
# Should return nginx page
```
</details>

#### Task 3.2: Headless Service (5 points)

Create a headless service named `webapp-headless` for the webapp pods and verify it returns all pod IPs.

<details>
<summary>Validation</summary>

```bash
kubectl get service webapp-headless -o jsonpath='{.spec.clusterIP}'
# Should output: None

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- nslookup webapp-headless
# Should show multiple A records (one per pod)
```
</details>

#### Task 3.3: NodePort Service (5 points)

Create a NodePort service named `webapp-nodeport` that:

- Exposes webapp pods
- Uses NodePort 30080
- Service port is 80

<details>
<summary>Validation</summary>

```bash
kubectl get service webapp-nodeport -o jsonpath='{.spec.ports[0].nodePort}'
# Should output: 30080

kubectl get service webapp-nodeport
# Should show NodePort type
```
</details>

---

### Part 4: Configuration & Secrets (15 points)

#### Task 4.1: ConfigMap Creation (5 points)

Create a ConfigMap named `app-config` with:

- Key `database_url` with value `postgres://db.example.com:5432/mydb`
- Key `log_level` with value `info`
- Key `app.properties` with multi-line content:
  ```
  app.name=MyApp
  app.version=2.0
  max.connections=100
  ```

<details>
<summary>Validation</summary>

```bash
kubectl get configmap app-config -o yaml
# Should show all three keys with correct values
```
</details>

#### Task 4.2: Secret Creation (5 points)

Create a Secret named `db-secret` with:

- Type: Opaque
- Key `username` with value `admin`
- Key `password` with value `SecurePass123!`
- Key `api_token` with value `token-xyz-789`

<details>
<summary>Validation</summary>

```bash
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d
# Should output: SecurePass123!
```
</details>

#### Task 4.3: Use ConfigMap and Secret (5 points)

Create a pod named `config-consumer` that:

- Uses image `busybox:1.36`
- Mounts ConfigMap `app-config` at `/config`
- Injects Secret `db-secret` values as environment variables:

  - `DB_USER` from secret key `username`
  - `DB_PASS` from secret key `password`
- Command: prints env vars and sleeps 3600s

<details>
<summary>Validation</summary>

```bash
kubectl logs config-consumer
# Should show DB_USER and DB_PASS values

kubectl exec config-consumer -- ls /config
# Should show app.properties and other keys
```
</details>

---

### Part 5: Storage (15 points)

#### Task 5.1: PVC Creation (5 points)

Create a PersistentVolumeClaim named `data-pvc` with:

- StorageClass: `standard`
- Access mode: ReadWriteOnce
- Storage request: 1Gi

<details>
<summary>Validation</summary>

```bash
kubectl get pvc data-pvc
# Should show Bound or Pending status
```
</details>

#### Task 5.2: Pod with PVC (5 points)

Create a pod named `data-pod` that:

- Uses image `nginx:1.25`
- Mounts `data-pvc` at `/data`
- Writes a file `/data/test.txt` with content "Persistent data test"

<details>
<summary>Validation</summary>

```bash
kubectl exec data-pod -- cat /data/test.txt
# Should output: Persistent data test
```
</details>

#### Task 5.3: StatefulSet with Storage (5 points)

Create a StatefulSet named `stateful-app` with:

- Replicas: 3
- Image: `nginx:1.25`
- Service name: `stateful-svc` (create headless service)
- VolumeClaimTemplate requesting 500Mi storage

<details>
<summary>Validation</summary>

```bash
kubectl get statefulset stateful-app
# Should show 3/3 ready

kubectl get pvc
# Should show 3 PVCs: www-stateful-app-0, www-stateful-app-1, www-stateful-app-2
```bash
</details>

---

### Part 6: Resource Management (10 points)

#### Task 6.1: LimitRange (5 points)

Create a LimitRange named `resource-limits` that sets:

- Default CPU limit: 500m
- Default memory limit: 512Mi
- Default CPU request: 100m
- Default memory request: 128Mi
- Max CPU: 2
- Max memory: 2Gi

<details>
<summary>Validation</summary>

```bash
kubectl describe limitrange resource-limits
# Should show all configured limits
```
</details>

#### Task 6.2: ResourceQuota (5 points)

Create a ResourceQuota named `namespace-quota` that limits:

- Total CPU requests: 4
- Total memory requests: 8Gi
- Max pods: 20
- Max services: 10

<details>
<summary>Validation</summary>

```bash
kubectl describe resourcequota namespace-quota
# Should show all configured quotas and current usage
```
</details>

---

### Part 7: Debugging Challenge (5 points)

Three broken resources have been deployed. Debug and fix all of them:

```bash
# Deploy broken resources

kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: debug-challenge-1
spec:
  containers:

  - name: app
    image: nginx:wrong
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: debug-challenge-2
spec:
  replicas: 3
  selector:
    matchLabels:
      app: debug-app
  template:
    metadata:
      labels:
        app: wrong-label
    spec:
      containers:

      - name: app
        image: nginx:1.25
---
apiVersion: v1
kind: Service
metadata:
  name: debug-challenge-3
spec:
  selector:
    app: nonexistent
  ports:

  - port: 80
EOF
```

**Your task**: Identify and fix all three issues.

<details>
<summary>Issues</summary>

1. Pod: Wrong image tag
2. Deployment: Selector doesn't match template labels
3. Service: Selector doesn't match any pods
</details>

---

## Submission Checklist

Before considering the assessment complete, verify:

```bash
# 1. All pods are running (except completed/intended failures)

kubectl get pods

# 2. All deployments have desired replicas ready

kubectl get deployments

# 3. All services have endpoints

kubectl get endpoints

# 4. All PVCs are bound

kubectl get pvc

# 5. No error events

kubectl get events --sort-by='.lastTimestamp' | grep -i error

# 6. ResourceQuota is not exceeded

kubectl describe resourcequota

# 7. Export your work

kubectl get all,cm,secret,pvc,limitrange,resourcequota -o yaml > assessment-results.yaml
```bash
## Scoring Guide

| Category | Points | Your Score |
|----------|--------|------------|
| Pod Management | 20 | ___ |
| Deployments & Scaling | 20 | ___ |
| Services & Networking | 15 | ___ |
| Configuration & Secrets | 15 | ___ |
| Storage | 15 | ___ |
| Resource Management | 10 | ___ |
| Debugging Challenge | 5 | ___ |
| **Total** | **100** | ___ |

**Passing Score**: 70/100

## Cleanup

```bash
# Remove assessment namespace

kubectl delete namespace cnpe-assessment

# Record completion time

date
```

## Review Areas

If you scored below 70%, review these labs:

- **<60%**: Review all Module 1 labs
- **60-69%**: Focus on areas where you lost points
- **70-84%**: Good! Minor review recommended
- **85-100%**: Excellent! Ready for Module 2

## Congratulations!

If you passed, you're ready to proceed to:

- [Module 2: GitOps & ArgoCD](../../module-02-gitops/)
- [Module 3: Infrastructure as Code](../../module-03-iac/)

## Answer Key

<details>
<summary>Show sample solutions (only after attempting!)</summary>

Available in `assessment-solutions.md` file.

</details>

---

**Time to complete**: 3-4 hours
**Difficulty**: Intermediate
**Real-world relevance**: High - these are common day-to-day Kubernetes tasks
