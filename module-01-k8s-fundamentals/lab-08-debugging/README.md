# Lab 8: Debugging & Troubleshooting

## Objective

Master debugging and troubleshooting techniques for Kubernetes. Learn to diagnose and fix common issues, read logs effectively, and use debugging tools.

## What You'll Learn

- Debug pod failures and crashes
- Analyze container logs effectively
- Use kubectl exec for interactive debugging
- Interpret cluster events
- Debug networking issues
- Troubleshoot storage problems
- Debug authentication and authorization
- Use ephemeral debug containers
- Implement health checks and probes
- Best practices for production debugging

## Prerequisites

- Completed Labs 1-7
- kind cluster running
- All previous concepts understood

## Lab Steps

### Step 1: Setup Environment

```bash
kubectl create namespace lab-08
kubectl config set-context --current --namespace=lab-08
```

### Step 2: Debug Pod Startup Failures

1. **ImagePullBackOff**:

Save as `pod-image-error.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: image-error
spec:
  containers:

  - name: app
    image: nginx:nonexistent-tag
```

Apply and diagnose:
```bash
kubectl apply -f pod-image-error.yaml
kubectl get pods
# STATUS: ImagePullBackOff or ErrImagePull

# Get detailed information

kubectl describe pod image-error

# Look for events

kubectl get events --field-selector involvedObject.name=image-error
```

**Fix**: Use correct image tag.

2. **CrashLoopBackOff**:

Save as `pod-crash.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: crash-pod
spec:
  containers:

  - name: app
    image: busybox:1.36
    command: ["sh", "-c", "echo Starting...; exit 1"]
  restartPolicy: Always
```

Apply and diagnose:
```bash
kubectl apply -f pod-crash.yaml
kubectl get pods -w
# STATUS: CrashLoopBackOff

# Check logs

kubectl logs crash-pod
kubectl logs crash-pod --previous  # Previous container instance

# Describe for restart count

kubectl describe pod crash-pod | grep -A 5 "State\|Last State"
```

**Fix**: Fix the application exit code or command.

3. **CreateContainerConfigError**:

Save as `pod-config-error.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: config-error
spec:
  containers:

  - name: app
    image: nginx:1.25
    env:

    - name: SECRET_VALUE
      valueFrom:
        secretKeyRef:
          name: nonexistent-secret
          key: password
```

Apply and diagnose:
```bash
kubectl apply -f pod-config-error.yaml
kubectl get pods
# STATUS: CreateContainerConfigError

kubectl describe pod config-error
# Event: Secret "nonexistent-secret" not found
```

**Fix**: Create the missing secret.

### Step 3: Advanced Log Analysis

1. **View logs with timestamps**:
```bash
# Create a test pod

kubectl run logger --image=busybox:1.36 -- sh -c 'while true; do echo "$(date) - Log message"; sleep 2; done'

# View logs with timestamps

kubectl logs logger --timestamps

# Follow logs in real-time

kubectl logs logger -f

# Last N lines

kubectl logs logger --tail=10

# Since specific time

kubectl logs logger --since=1m
kubectl logs logger --since=2024-12-02T10:00:00Z
```

2. **Multi-container pod logs**:

Save as `pod-multi-container.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: multi-container
spec:
  containers:

  - name: app
    image: nginx:1.25
    ports:

    - containerPort: 80
  - name: sidecar
    image: busybox:1.36
    command: ["sh", "-c", "while true; do echo 'Sidecar log'; sleep 5; done"]
```

Apply and view logs:
```bash
kubectl apply -f pod-multi-container.yaml

# List containers

kubectl get pod multi-container -o jsonpath='{.spec.containers[*].name}'

# View specific container

kubectl logs multi-container -c app
kubectl logs multi-container -c sidecar

# View all containers

kubectl logs multi-container --all-containers=true

# Follow all containers

kubectl logs multi-container --all-containers=true -f
```

3. **Init container logs**:

Save as `pod-init-debug.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: init-debug
spec:
  initContainers:

  - name: init-fail
    image: busybox:1.36
    command: ["sh", "-c", "echo 'Init failed'; exit 1"]
  containers:

  - name: app
    image: nginx:1.25
```

Apply and debug:
```bash
kubectl apply -f pod-init-debug.yaml
kubectl get pods
# STATUS: Init:Error or Init:CrashLoopBackOff

# View init container logs

kubectl logs init-debug -c init-fail
```

### Step 4: Interactive Debugging with exec

1. **Exec into running container**:
```bash
kubectl run debug-pod --image=nginx:1.25

# Bash shell

kubectl exec -it debug-pod -- /bin/bash

# Inside the container:

ps aux
ls -la /usr/share/nginx/html
cat /etc/nginx/nginx.conf
curl localhost
exit
```

2. **Run commands without interactive shell**:
```bash
kubectl exec debug-pod -- ls -la /etc/nginx
kubectl exec debug-pod -- cat /etc/resolv.conf
kubectl exec debug-pod -- env | sort
```

3. **Exec into specific container**:
```bash
kubectl exec -it multi-container -c sidecar -- sh
```

4. **Copy files to/from container**:
```bash
# Copy from container

kubectl cp debug-pod:/etc/nginx/nginx.conf ./nginx.conf

# Copy to container

echo "Test file" > test.txt
kubectl cp test.txt debug-pod:/tmp/test.txt

# Verify

kubectl exec debug-pod -- cat /tmp/test.txt
```

### Step 5: Ephemeral Debug Containers

Debug containers can be added to running pods without restarting them.

1. **Add debug container to pod**:
```bash
# Create a pod with minimal image (no shell)

kubectl run minimal --image=k8s.gcr.io/pause:3.9

# Can't exec (no shell)

kubectl exec -it minimal -- sh
# Error: executable file not found

# Add ephemeral debug container

kubectl debug minimal -it --image=busybox:1.36 --target=minimal

# Now you have a shell in the pod's namespace!
# Inside debug container:

ps aux  # See processes from main container
exit
```

2. **Debug node by creating pod**:
```bash
# Get node name

NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')

# Create debug pod on node

kubectl debug node/$NODE_NAME -it --image=ubuntu:22.04

# Inside the debug pod (with host access):

chroot /host
ps aux
df -h
systemctl status kubelet
exit
exit
```

### Step 6: Debug Networking Issues

1. **Create test deployment and service**:

Save as `deployment-web.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:

      - name: nginx
        image: nginx:1.25
        ports:

        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web
  ports:

  - port: 80
    targetPort: 80
```

Apply:
```bash
kubectl apply -f deployment-web.yaml
```

2. **Test service connectivity**:
```bash
# DNS resolution

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- nslookup web-svc

# HTTP connectivity

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://web-svc

# Test from specific namespace

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://web-svc.lab-08.svc.cluster.local
```

3. **Debug with netshoot (advanced networking tools)**:
```bash
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -- bash

# Inside netshoot:
# DNS lookup

dig web-svc.lab-08.svc.cluster.local

# Ping (won't work but tests DNS)

ping web-svc

# Curl

curl http://web-svc

# Check routing

ip route

# Traceroute

traceroute web-svc

# Network stats

netstat -an | grep 80

# TCP connection test

nc -zv web-svc 80

exit
```

4. **Check service endpoints**:
```bash
# Service should have endpoints

kubectl get endpoints web-svc

# If no endpoints:
# 1. Check selector matches pod labels

kubectl describe service web-svc | grep Selector
kubectl get pods --show-labels

# 2. Check pods are ready

kubectl get pods -l app=web

# 3. Check port mapping

kubectl describe service web-svc | grep -A 3 "Port:"
```

5. **Test pod-to-pod connectivity**:
```bash
# Get pod IPs

kubectl get pods -l app=web -o wide

# Test direct pod IP

POD_IP=$(kubectl get pod -l app=web -o jsonpath='{.items[0].status.podIP}')
kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- wget -qO- http://$POD_IP
```

### Step 7: Debug Storage Issues

1. **PVC stuck in Pending**:

Save as `pvc-pending.yaml`:
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-pending
spec:
  storageClassName: nonexistent-class
  accessModes:

    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Apply and debug:
```bash
kubectl apply -f pvc-pending.yaml
kubectl get pvc
# STATUS: Pending

kubectl describe pvc pvc-pending
# Events show: storageclass "nonexistent-class" not found

# Check available StorageClasses

kubectl get storageclass
```

2. **Pod can't mount volume**:

Save as `pod-mount-error.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mount-error
spec:
  containers:

  - name: app
    image: nginx:1.25
    volumeMounts:

    - name: data
      mountPath: /data
  volumes:

  - name: data
    persistentVolumeClaim:
      claimName: nonexistent-pvc
```

Apply and debug:
```bash
kubectl apply -f pod-mount-error.yaml
kubectl get pods
# STATUS: ContainerCreating (stuck)

kubectl describe pod mount-error
# Events: persistentvolumeclaim "nonexistent-pvc" not found
```bash
### Step 8: Debug Resource Constraints

1. **Pods pending due to insufficient resources**:

Save as `pod-insufficient-resources.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: huge-resources
spec:
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "100Gi"  # More than cluster has
        cpu: "50"
```

Apply and debug:
```bash
kubectl apply -f pod-insufficient-resources.yaml
kubectl get pods
# STATUS: Pending

kubectl describe pod huge-resources
# Events: 0/3 nodes available: insufficient memory

# Check node capacity

kubectl describe nodes | grep -A 5 "Allocatable"

# Check current resource usage

kubectl top nodes
```

2. **ResourceQuota exceeded**:
```bash
# Create strict quota

kubectl create quota strict --hard=pods=2

# Try to create 3 pods

kubectl create deployment test --image=nginx:1.25 --replicas=3

# Check deployment

kubectl describe deployment test
# ReplicaSet events show quota exceeded

# Check quota

kubectl describe quota strict
```

### Step 9: Debug RBAC Issues

1. **Create ServiceAccount with no permissions**:
```bash
kubectl create serviceaccount limited-sa
```

2. **Run pod with ServiceAccount**:
```bash
kubectl run rbac-test --image=bitnami/kubectl:latest --serviceaccount=limited-sa -- sleep 3600

# Try to list pods from inside

kubectl exec rbac-test -- kubectl get pods
# Error: forbidden
```

3. **Check permissions**:
```bash
# Check what ServiceAccount can do

kubectl auth can-i list pods --as=system:serviceaccount:lab-08:limited-sa
# Output: no

# Check with system:serviceaccount format

kubectl auth can-i --list --as=system:serviceaccount:lab-08:limited-sa
```

4. **Grant permissions**:
```bash
# Create Role and RoleBinding

kubectl create role pod-reader --verb=get,list --resource=pods
kubectl create rolebinding pod-reader-binding --role=pod-reader --serviceaccount=lab-08:limited-sa

# Test again

kubectl auth can-i list pods --as=system:serviceaccount:lab-08:limited-sa
# Output: yes

kubectl exec rbac-test -- kubectl get pods
# Now works!
```

### Step 10: Implement Health Checks

Proper health checks prevent many debugging scenarios.

1. **Liveness probe (restart if failing)**:

Save as `pod-liveness.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:

  - name: app
    image: busybox:1.36
    command:

    - sh
    - -c
    - |
      touch /tmp/healthy
      sleep 30
      rm -f /tmp/healthy
      sleep 600
    livenessProbe:
      exec:
        command:

        - cat
        - /tmp/healthy
      initialDelaySeconds: 5
      periodSeconds: 5
      failureThreshold: 3
```

Apply and observe:
```bash
kubectl apply -f pod-liveness.yaml

# Watch pod

kubectl get pod liveness-demo --watch

# After 30s, healthcheck fails, pod restarts
# Check events

kubectl describe pod liveness-demo | grep -A 10 Events
```

2. **Readiness probe (remove from service if failing)**:

Save as `deployment-readiness.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: readiness-demo
spec:
  replicas: 3
  selector:
    matchLabels:
      app: readiness-demo
  template:
    metadata:
      labels:
        app: readiness-demo
    spec:
      containers:

      - name: app
        image: nginx:1.25
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 3
          successThreshold: 1
          failureThreshold: 2
---
apiVersion: v1
kind: Service
metadata:
  name: readiness-svc
spec:
  selector:
    app: readiness-demo
  ports:

  - port: 80
```

Apply:
```bash
kubectl apply -f deployment-readiness.yaml

# All pods ready

kubectl get pods -l app=readiness-demo

# Check service endpoints

kubectl get endpoints readiness-svc

# Simulate readiness failure

POD=$(kubectl get pod -l app=readiness-demo -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- rm /usr/share/nginx/html/index.html

# Pod becomes NotReady but not restarted

kubectl get pods -l app=readiness-demo

# Removed from service endpoints

kubectl get endpoints readiness-svc
```

3. **Startup probe (for slow-starting apps)**:

Save as `pod-startup.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: startup-demo
spec:
  containers:

  - name: app
    image: nginx:1.25
    startupProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 0
      periodSeconds: 10
      failureThreshold: 30  # 300s total (5min)
    livenessProbe:
      httpGet:
        path: /
        port: 80
      periodSeconds: 10
```

Startup probe runs first, then liveness takes over.

### Step 11: Debugging Checklist

**Pod not starting?**
```bash
# 1. Check pod status

kubectl get pods
kubectl describe pod <name>

# 2. Check events

kubectl get events --sort-by='.lastTimestamp' | grep <pod-name>

# 3. Check logs

kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # If crashed

# 4. Check resource availability

kubectl describe nodes
kubectl top nodes

# 5. Check image exists

kubectl describe pod <pod-name> | grep Image:
```

**Service not accessible?**
```bash
# 1. Check service exists

kubectl get service <name>
kubectl describe service <name>

# 2. Check endpoints

kubectl get endpoints <name>

# 3. Check selector matches pods

kubectl describe service <name> | grep Selector
kubectl get pods --show-labels

# 4. Test DNS

kubectl run test --image=busybox:1.36 --rm -it -- nslookup <service-name>

# 5. Test connectivity

kubectl run test --image=busybox:1.36 --rm -it -- wget -qO- http://<service-name>
```

**Storage issues?**
```bash
# 1. Check PVC status

kubectl get pvc
kubectl describe pvc <name>

# 2. Check StorageClass

kubectl get storageclass

# 3. Check PV status

kubectl get pv

# 4. Check pod events

kubectl describe pod <name> | grep -A 20 Events
```

**General debugging**:
```bash
# View all resources

kubectl get all

# Check all events in namespace

kubectl get events --sort-by='.lastTimestamp'

# Check resource usage

kubectl top nodes
kubectl top pods

# Check API server logs (on node)

kubectl logs -n kube-system kube-apiserver-*

# Check scheduler logs

kubectl logs -n kube-system kube-scheduler-*

# Check controller logs

kubectl logs -n kube-system kube-controller-manager-*
```

## Validation

Test your debugging skills:

```bash
# 1. Find all pods not in Running state

kubectl get pods -A --field-selector=status.phase!=Running

# 2. Find recent errors in events

kubectl get events -A --sort-by='.lastTimestamp' | grep -i error | tail -10

# 3. Find pods with high restart count

kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].restartCount}{"\n"}{end}' | awk '$2>0'

# 4. Check all services have endpoints

kubectl get endpoints -A

# 5. Find pods using most memory

kubectl top pods --sort-by=memory | head -10
```bash
## Practice Challenges

Test your troubleshooting skills:

1. **Challenge 1**: Debug a pod stuck in Pending state
   <details>
   <summary>Steps</summary>
   1. `kubectl describe pod`
   2. Check events for reason
   3. Common causes: insufficient resources, PVC issues, node selectors
   </details>

2. **Challenge 2**: Fix a service that has no endpoints
   <details>
   <summary>Checklist</summary>
   - Selector matches pod labels?
   - Pods are Running and Ready?
   - Correct namespace?
   - Ports configured correctly?
   </details>

3. **Challenge 3**: Debug a pod crashing with OOMKilled
   <details>
   <summary>Solution</summary>
   - Check logs: `kubectl logs <pod> --previous`
   - Increase memory limits
   - Optimize application memory usage
   </details>

4. **Challenge 4**: Pod can't pull image from private registry
   <details>
   <summary>Fix</summary>
   Create docker-registry secret and add `imagePullSecrets` to pod spec
   </details>

5. **Challenge 5**: Debug DNS resolution not working in pods
   <details>
   <summary>Checks</summary>
   - CoreDNS pods running? `kubectl get pods -n kube-system -l k8s-app=kube-dns`
   - Check pod's `/etc/resolv.conf`
   - Test with nslookup/dig
   </details>

## Cleanup

Remove all resources:

```bash
kubectl delete namespace lab-08
```bash
## Key Takeaways

- ✅ **kubectl describe**: First debugging tool - shows events, status, configuration
- ✅ **kubectl logs**: View container stdout/stderr, use `-f` for live, `--previous` for crashed
- ✅ **kubectl exec**: Interactive debugging inside containers
- ✅ **kubectl debug**: Add ephemeral containers to running pods
- ✅ **Events**: Chronicle of what happened - sort by timestamp
- ✅ **Liveness probe**: Restarts unhealthy containers
- ✅ **Readiness probe**: Controls service endpoint inclusion
- ✅ **Startup probe**: For slow-starting applications
- ✅ **Service endpoints**: Must exist for service to work
- ✅ **Common issues**: ImagePull, CrashLoop, ResourceQuota, RBAC, Network, Storage
- ✅ **Systematic approach**: Status → Describe → Events → Logs → Exec

## Additional Resources

- [Troubleshooting Applications](https://kubernetes.io/docs/tasks/debug/debug-application/)
- [Debugging Pods](https://kubernetes.io/docs/tasks/debug/debug-application/debug-pods/)
- [Debugging Services](https://kubernetes.io/docs/tasks/debug/debug-application/debug-service/)
- [Debugging Clusters](https://kubernetes.io/docs/tasks/debug/debug-cluster/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Module 1 Complete!

Congratulations on completing all 8 labs of Module 1: Kubernetes Fundamentals!

**What you've mastered:**
- ✅ Cluster setup and kubectl
- ✅ Pods and multi-container patterns
- ✅ Deployments and scaling
- ✅ Services and networking
- ✅ Configuration and secrets
- ✅ Persistent storage
- ✅ Resource management
- ✅ Debugging and troubleshooting

**Next Steps:**
- Review any challenging labs
- Complete the [Module 1 Assessment](../assessment/)
- Proceed to [Module 2: GitOps & ArgoCD](../../module-02-gitops/)

---

**Estimated Time**: 120-150 minutes
