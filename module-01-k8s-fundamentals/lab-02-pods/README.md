# Lab 2: Working with Pods

## Objective

Master Kubernetes Pods - the smallest deployable unit. Learn pod lifecycle, multi-container patterns, and troubleshooting techniques.

## What You'll Learn

- Create pods using kubectl and YAML manifests
- Understand pod lifecycle and phases
- Implement multi-container patterns (sidecar, init containers)
- Configure resource requests and limits
- Use labels and annotations effectively
- Debug and troubleshoot pods

## Prerequisites

- Completed Lab 1
- kind cluster running
- kubectl configured

## Lab Steps

### Step 1: Create Your First Pod (Imperative)

1. **Create a namespace for this lab**:
```bash
kubectl create namespace lab-02
kubectl config set-context --current --namespace=lab-02
```

2. **Create a simple nginx pod**:
```bash
kubectl run nginx --image=nginx:1.25
```

3. **Check pod status**:
```bash
kubectl get pods
kubectl get pods -o wide
```

4. **Describe the pod**:
```bash
kubectl describe pod nginx
```bash
Observe:

- Events (pulled image, started container)
- Status and conditions
- Container information
- IP address assigned

5. **View pod details in YAML**:
```bash
kubectl get pod nginx -o yaml
```

6. **Delete the pod**:
```bash
kubectl delete pod nginx
```

### Step 2: Create Pods from YAML Manifests

1. **Create a basic pod manifest**:

Save this as `pod-basic.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp
  labels:
    app: webapp
    tier: frontend
  annotations:
    description: "Basic web application pod"
spec:
  containers:

  - name: nginx
    image: nginx:1.25
    ports:

    - containerPort: 80
      name: http
```

2. **Apply the manifest**:
```bash
kubectl apply -f pod-basic.yaml
```

3. **Verify the pod**:
```bash
kubectl get pod webapp
kubectl get pod webapp --show-labels
```

4. **Test the application** (port-forward to access):
```bash
kubectl port-forward pod/webapp 8080:80
```

Open another terminal and test:
```bash
curl http://localhost:8080
```

You should see nginx welcome page HTML. Press `Ctrl+C` to stop port-forward.

### Step 3: Pod Lifecycle and Phases

1. **Create a pod that takes time to start**:

Save as `pod-lifecycle.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: lifecycle-demo
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: 

    - sh
    - -c
    - |
      echo "Container starting..."
      sleep 10
      echo "Container ready!"
      sleep 3600
    livenessProbe:
      exec:
        command:

        - cat
        - /tmp/healthy
      initialDelaySeconds: 15
      periodSeconds: 5
    readinessProbe:
      exec:
        command:

        - sh
        - -c
        - echo "ready"
      initialDelaySeconds: 5
      periodSeconds: 3
```

2. **Apply and watch**:
```bash
kubectl apply -f pod-lifecycle.yaml
kubectl get pod lifecycle-demo --watch
```

You'll see phases: Pending → ContainerCreating → Running

3. **Check pod conditions**:
```bash
kubectl describe pod lifecycle-demo | grep -A 10 Conditions
```

Conditions include:

- `PodScheduled`: Pod assigned to a node
- `Initialized`: Init containers completed
- `ContainersReady`: All containers are ready
- `Ready`: Pod can serve traffic

4. **Make the liveness probe succeed**:
```bash
kubectl exec lifecycle-demo -- touch /tmp/healthy
```

### Step 4: Multi-Container Pods (Sidecar Pattern)

1. **Create a pod with sidecar logging**:

Save as `pod-sidecar.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-with-logging
spec:
  containers:
  # Main application container
  - name: webapp
    image: nginx:1.25
    ports:

    - containerPort: 80
    volumeMounts:

    - name: logs
      mountPath: /var/log/nginx
  
  # Sidecar logging container
  - name: log-aggregator
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      while true; do
        if [ -f /logs/access.log ]; then
          tail -f /logs/access.log
        fi
        sleep 5
      done
    volumeMounts:

    - name: logs
      mountPath: /logs
  
  volumes:

  - name: logs
    emptyDir: {}
```

2. **Apply the pod**:
```bash
kubectl apply -f pod-sidecar.yaml
```

3. **Verify both containers are running**:
```bash
kubectl get pod webapp-with-logging
# Should show 2/2 in READY column
```

4. **View logs from specific container**:
```bash
# Main app logs

kubectl logs webapp-with-logging -c webapp

# Sidecar logs

kubectl logs webapp-with-logging -c log-aggregator
```

5. **Generate some traffic**:
```bash
# In terminal 1 - port forward

kubectl port-forward pod/webapp-with-logging 8080:80

# In terminal 2 - generate requests

for i in {1..10}; do curl http://localhost:8080; done

# In terminal 3 - watch sidecar logs

kubectl logs webapp-with-logging -c log-aggregator -f
```bash
### Step 5: Init Containers

Init containers run before app containers and are used for setup tasks.

1. **Create a pod with init container**:

Save as `pod-init.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: webapp-with-init
spec:
  initContainers:
  # Init container downloads data
  - name: init-data
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      echo "Downloading configuration..."
      sleep 5
      echo "Configuration data" > /data/config.txt
      echo "Init complete!"
    volumeMounts:

    - name: data
      mountPath: /data
  
  # Init container waits for dependency
  - name: wait-for-db
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      echo "Waiting for database..."
      sleep 10
      echo "Database ready!"
  
  containers:

  - name: webapp
    image: nginx:1.25
    volumeMounts:

    - name: data
      mountPath: /usr/share/nginx/html
  
  volumes:

  - name: data
    emptyDir: {}
```

2. **Apply and watch init process**:
```bash
kubectl apply -f pod-init.yaml
kubectl get pod webapp-with-init --watch
```

You'll see:

- `Init:0/2` → `Init:1/2` → `Init:2/2` → `PodInitializing` → `Running`

3. **Check init container logs**:
```bash
kubectl logs webapp-with-init -c init-data
kubectl logs webapp-with-init -c wait-for-db
```

4. **Verify data was initialized**:
```bash
kubectl exec webapp-with-init -- cat /usr/share/nginx/html/config.txt
```bash
### Step 6: Resource Requests and Limits

1. **Create pod with resource constraints**:

Save as `pod-resources.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: resource-demo
spec:
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

2. **Apply the pod**:
```bash
kubectl apply -f pod-resources.yaml
```bash
3. **Check resource allocation**:
```bash
kubectl describe pod resource-demo | grep -A 5 "Limits\|Requests"
```bash
4. **View node resource usage**:
```bash
kubectl top nodes
kubectl top pod resource-demo
```bash
*Note: If `kubectl top` doesn't work, metrics-server isn't installed in kind by default.*

### Step 7: Labels and Selectors

1. **Create multiple pods with different labels**:

Save as `pods-labels.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-prod
  labels:
    app: frontend
    env: production
    version: v1
spec:
  containers:

  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: frontend-dev
  labels:
    app: frontend
    env: development
    version: v2
spec:
  containers:

  - name: nginx
    image: nginx:1.25
---
apiVersion: v1
kind: Pod
metadata:
  name: backend-prod
  labels:
    app: backend
    env: production
    version: v1
spec:
  containers:

  - name: busybox
    image: busybox:1.36
    command: ["sh", "-c", "sleep 3600"]
```

2. **Apply all pods**:
```bash
kubectl apply -f pods-labels.yaml
```

3. **Query using label selectors**:
```bash
# All production pods

kubectl get pods -l env=production

# All frontend pods

kubectl get pods -l app=frontend

# Production frontend pods (AND condition)

kubectl get pods -l app=frontend,env=production

# Show all labels

kubectl get pods --show-labels

# Add custom columns

kubectl get pods -L app,env,version
```bash
4. **Set-based selectors**:
```bash
# Pods with env label (any value)

kubectl get pods -l env

# Pods in production OR development

kubectl get pods -l 'env in (production,development)'

# Pods NOT in development

kubectl get pods -l 'env notin (development)'
```

5. **Update labels**:
```bash
# Add new label

kubectl label pod frontend-dev team=blue

# Update existing label

kubectl label pod frontend-dev version=v3 --overwrite

# Remove label

kubectl label pod frontend-dev team-
```

### Step 8: Debugging and Troubleshooting

1. **Create a pod that fails**:

Save as `pod-failing.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: failing-pod
spec:
  containers:

  - name: app
    image: nginx:wrong-tag
```

2. **Apply and observe**:
```bash
kubectl apply -f pod-failing.yaml
kubectl get pod failing-pod
```

Status will show `ImagePullBackOff` or `ErrImagePull`

3. **Investigate the issue**:
```bash
# Describe shows events

kubectl describe pod failing-pod

# Check events separately

kubectl get events --field-selector involvedObject.name=failing-pod
```

4. **Create a crashing pod**:

Save as `pod-crashing.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crashing-pod
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "exit 1"]
  restartPolicy: Always
```

5. **Apply and observe restart behavior**:
```bash
kubectl apply -f pod-crashing.yaml
kubectl get pod crashing-pod --watch
```

You'll see `CrashLoopBackOff` with increasing restart delays.

6. **Exec into running pod**:
```bash
kubectl exec -it webapp -- /bin/bash

# Once inside:

ls -la
cat /etc/nginx/nginx.conf
exit
```

7. **Copy files to/from pod**:
```bash
# Copy from pod

kubectl cp webapp:/etc/nginx/nginx.conf ./nginx.conf

# Copy to pod

echo "test" > test.txt
kubectl cp test.txt webapp:/tmp/test.txt
```

## Validation

Verify your understanding:

```bash
# 1. Count running pods in lab-02

kubectl get pods --field-selector=status.phase=Running | tail -n +2 | wc -l

# 2. List all pods with frontend label

kubectl get pods -l app=frontend --no-headers | wc -l
# Should be: 2

# 3. Verify multi-container pod has 2 containers

kubectl get pod webapp-with-logging -o jsonpath='{.spec.containers[*].name}'
# Should show: webapp log-aggregator

# 4. Check init containers ran successfully

kubectl get pod webapp-with-init -o jsonpath='{.status.initContainerStatuses[*].state.terminated.reason}'
# Should show: Completed Completed
```

## Practice Challenges

Test your skills:

1. **Challenge 1**: Create a pod that runs redis:7 with 100m CPU request and 200m limit
   <details>
   <summary>Solution</summary>
   ```yaml
   apiVersion: v1
   kind: Pod
   metadata:
     name: redis
   spec:
     containers:

     - name: redis
       image: redis:7
       resources:
         requests:
           cpu: "100m"
         limits:
           cpu: "200m"
   ```
   </details>

2. **Challenge 2**: Create a pod with 2 containers sharing a volume at /shared
   <details>
   <summary>Hint</summary>
   Use emptyDir volume and mount it in both containers
   </details>

3. **Challenge 3**: Find all pods in any namespace that are NOT running
   <details>
   <summary>Solution</summary>
   ```bash
   kubectl get pods -A --field-selector=status.phase!=Running
   ```
   </details>

4. **Challenge 4**: Create a pod that waits for a service "database" before starting (simulated with sleep)
   <details>
   <summary>Hint</summary>
   Use init container with a command that sleeps then completes
   </details>

## Cleanup

Remove all resources from this lab:

```bash
kubectl delete namespace lab-02
```bash
## Troubleshooting Guide

| Issue | Cause | Solution |
|-------|-------|----------|
| ImagePullBackOff | Image doesn't exist | Check image name/tag with `kubectl describe` |
| CrashLoopBackOff | Container keeps exiting | Check logs with `kubectl logs` |
| Pending | Can't schedule | Check events with `kubectl describe` |
| Init:Error | Init container failed | Check init logs: `kubectl logs <pod> -c <init-container>` |
| 0/2 Ready | Container not ready | Check readiness probe and logs |

## Key Takeaways

- ✅ Pods are the smallest deployable units in Kubernetes
- ✅ Each pod has a unique IP address within the cluster
- ✅ Multi-container pods share network and storage
- ✅ Init containers run sequentially before app containers
- ✅ Sidecar pattern extends functionality without modifying main app
- ✅ Resource requests affect scheduling; limits prevent overuse
- ✅ Labels are key-value pairs for organizing and selecting resources
- ✅ kubectl describe and logs are primary debugging tools

## Additional Resources

- [Pod Lifecycle](https://kubernetes.io/docs/concepts/workloads/pods/pod-lifecycle/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Multi-Container Patterns](https://kubernetes.io/blog/2015/06/the-distributed-system-toolkit-patterns/)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

## Next Lab

[Lab 3: Deployments & ReplicaSets](../lab-03-deployments/) - Learn production-grade workload management

---

**Estimated Time**: 90-120 minutes
