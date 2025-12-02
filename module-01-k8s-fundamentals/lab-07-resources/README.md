# Lab 7: Resource Management & Autoscaling

## Objective

Master Kubernetes resource management. Learn to configure CPU/memory requests and limits, understand QoS classes, implement autoscaling, and manage resource quotas.

## What You'll Learn

- Configure resource requests and limits
- Understand QoS classes (Guaranteed, Burstable, BestEffort)
- Implement LimitRanges for defaults
- Set ResourceQuotas at namespace level
- Configure Horizontal Pod Autoscaler (HPA)
- Use Vertical Pod Autoscaler (VPA) concepts
- Monitor resource usage
- Implement Pod Priority and Preemption

## Prerequisites

- Completed Labs 1-6
- kind cluster running
- Understanding of Pods and Deployments

## Lab Steps

### Step 1: Setup Environment

```bash
kubectl create namespace lab-07
kubectl config set-context --current --namespace=lab-07
```bash
### Step 2: Resource Requests and Limits

**Requests**: Guaranteed resources (used for scheduling)
**Limits**: Maximum resources allowed (enforced by container runtime)

1. **Pod with CPU and memory resources**:

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
        memory: "64Mi"    # Minimum guaranteed memory
        cpu: "250m"       # 0.25 CPU cores
      limits:
        memory: "128Mi"   # Maximum memory (OOMKilled if exceeded)
        cpu: "500m"       # 0.5 CPU cores (throttled if exceeded)
```

Apply:
```bash
kubectl apply -f pod-resources.yaml
kubectl describe pod resource-demo | grep -A 10 "Limits\|Requests"
```bash
**Resource units**:

- CPU: 1 = 1 vCPU/core, 100m = 0.1 cores (millicores)
- Memory: Ki, Mi, Gi, Ti (1Mi = 1024Ki)

2. **Test CPU limits with stress test**:

Save as `pod-cpu-stress.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cpu-stress
spec:
  containers:

  - name: stress
    image: polinux/stress
    resources:
      requests:
        cpu: "100m"
        memory: "50Mi"
      limits:
        cpu: "200m"
        memory: "100Mi"
    command: ["stress"]
    args: ["--cpu", "2", "--timeout", "60s"]  # Try to use 2 CPUs
```

Apply and monitor:
```bash
kubectl apply -f pod-cpu-stress.yaml

# If metrics-server is installed:
# kubectl top pod cpu-stress --watch

# Check if pod is throttled

kubectl describe pod cpu-stress | grep -i cpu
```

CPU limit is enforced through throttling (not OOMKill).

3. **Test memory limits**:

Save as `pod-memory-stress.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: memory-stress
spec:
  containers:

  - name: stress
    image: polinux/stress
    resources:
      requests:
        memory: "50Mi"
      limits:
        memory: "100Mi"
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "150M", "--vm-hang", "1"]
```

Apply:
```bash
kubectl apply -f pod-memory-stress.yaml
kubectl get pod memory-stress --watch
```

Pod will be **OOMKilled** (Out Of Memory) when exceeding limit.

```bash
kubectl describe pod memory-stress | grep -i oom
```bash
### Step 3: Quality of Service (QoS) Classes

Kubernetes assigns QoS classes based on resource configuration.

1. **Guaranteed QoS** (highest priority):

Save as `pod-qos-guaranteed.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-guaranteed
spec:
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
      limits:
        memory: "100Mi"  # Same as requests
        cpu: "100m"      # Same as requests
```

Requirements: requests = limits for all containers.

2. **Burstable QoS** (medium priority):

Save as `pod-qos-burstable.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-burstable
spec:
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "50Mi"
        cpu: "50m"
      limits:
        memory: "100Mi"  # Different from requests
        cpu: "200m"
```

Requirements: Has requests < limits OR only has requests.

3. **BestEffort QoS** (lowest priority):

Save as `pod-qos-besteffort.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: qos-besteffort
spec:
  containers:

  - name: app
    image: nginx:1.25
    # No resources specified
```

Requirements: No requests or limits specified.

4. **Apply all and check QoS**:
```bash
kubectl apply -f pod-qos-guaranteed.yaml
kubectl apply -f pod-qos-burstable.yaml
kubectl apply -f pod-qos-besteffort.yaml

# Check QoS class

kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass
```

**QoS affects**:

- **Eviction order** when node runs out of resources: BestEffort → Burstable → Guaranteed
- **OOM killer priority**: BestEffort killed first

### Step 4: LimitRange (Default Resources)

LimitRange sets default requests/limits and min/max per namespace.

1. **Create LimitRange**:

Save as `limitrange.yaml`:
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: resource-constraints
spec:
  limits:
  # Constraints for Containers
  - type: Container
    default:  # Default limits
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:  # Default requests
      cpu: "100m"
      memory: "128Mi"
    max:  # Maximum allowed
      cpu: "2"
      memory: "2Gi"
    min:  # Minimum required
      cpu: "50m"
      memory: "64Mi"
  
  # Constraints for Pods (sum of all containers)
  - type: Pod
    max:
      cpu: "4"
      memory: "4Gi"
  
  # Constraints for PVCs
  - type: PersistentVolumeClaim
    max:
      storage: "10Gi"
    min:
      storage: "1Gi"
```

Apply:
```bash
kubectl apply -f limitrange.yaml
kubectl describe limitrange resource-constraints
```

2. **Test default resources**:

Save as `pod-no-resources.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-with-defaults
spec:
  containers:

  - name: app
    image: nginx:1.25
    # No resources specified
```

Apply and check:
```bash
kubectl apply -f pod-no-resources.yaml
kubectl describe pod pod-with-defaults | grep -A 10 "Limits\|Requests"
```

Default resources from LimitRange are applied automatically!

3. **Test max limits**:

Save as `pod-too-large.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pod-too-large
spec:
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        cpu: "3"      # Exceeds max (2)
        memory: "3Gi"
```

Try to apply:
```bash
kubectl apply -f pod-too-large.yaml
# Error: exceeds max cpu constraint
```bash
### Step 5: ResourceQuota (Namespace Limits)

ResourceQuota limits aggregate resource consumption per namespace.

1. **Create ResourceQuota**:

Save as `resourcequota.yaml`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    # Total CPU/memory across all pods
    requests.cpu: "2"
    requests.memory: "2Gi"
    limits.cpu: "4"
    limits.memory: "4Gi"
    
    # Object counts
    pods: "10"
    services: "5"
    persistentvolumeclaims: "5"
    
    # Storage
    requests.storage: "50Gi"
```

Apply:
```bash
kubectl apply -f resourcequota.yaml
kubectl describe resourcequota compute-quota
```

2. **View quota usage**:
```bash
kubectl get resourcequota compute-quota -o yaml
```

Shows `used` vs `hard` limits.

3. **Test quota enforcement**:

Try creating 11 pods (quota allows 10):
```bash
for i in {1..11}; do
  kubectl run pod-$i --image=nginx:1.25 --requests=cpu=100m,memory=128Mi
done

# 11th pod will fail

kubectl get pods
```

4. **Create quota for specific QoS classes**:

Save as `resourcequota-qos.yaml`:
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: guaranteed-quota
spec:
  hard:
    requests.cpu: "1"
    limits.cpu: "2"
  scopeSelector:
    matchExpressions:

    - operator: In
      scopeName: PriorityClass
      values: ["high"]
```bash
### Step 6: Horizontal Pod Autoscaler (HPA)

HPA automatically scales pods based on metrics (CPU, memory, custom).

**Note**: Requires metrics-server. To install in kind:

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# For kind, patch to disable TLS verification

kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# Wait for metrics-server to be ready

kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=120s
```

1. **Create deployment for autoscaling**:

Save as `deployment-hpa.yaml`:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp-hpa
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp-hpa
  template:
    metadata:
      labels:
        app: webapp-hpa
    spec:
      containers:

      - name: php-apache
        image: registry.k8s.io/hpa-example
        ports:

        - containerPort: 80
        resources:
          requests:
            cpu: "100m"
            memory: "50Mi"
          limits:
            cpu: "200m"
            memory: "100Mi"
---
apiVersion: v1
kind: Service
metadata:
  name: webapp-hpa
spec:
  selector:
    app: webapp-hpa
  ports:

  - port: 80
```

Apply:
```bash
kubectl apply -f deployment-hpa.yaml
```

2. **Create HPA**:

Save as `hpa.yaml`:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp-hpa
  minReplicas: 2
  maxReplicas: 10
  metrics:

  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50  # Target 50% CPU
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 60
      policies:

      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:

      - type: Percent
        value: 100
        periodSeconds: 15
```

Or create imperatively:
```bash
kubectl autoscale deployment webapp-hpa --cpu-percent=50 --min=2 --max=10
```

Apply:
```bash
kubectl apply -f hpa.yaml
kubectl get hpa
```

3. **Generate load to trigger autoscaling**:

Terminal 1 - Watch HPA:
```bash
kubectl get hpa webapp-hpa --watch
```

Terminal 2 - Watch pods:
```bash
kubectl get pods -l app=webapp-hpa --watch
```

Terminal 3 - Generate load:
```bash
kubectl run load-generator --image=busybox:1.36 --rm -it --restart=Never -- sh -c "while true; do wget -q -O- http://webapp-hpa; done"
```bash
Watch as CPU increases and HPA scales up pods!

After stopping load (Ctrl+C), pods scale back down after stabilization window.

4. **HPA based on memory**:

Save as `hpa-memory.yaml`:
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: webapp-memory-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp-hpa
  minReplicas: 1
  maxReplicas: 5
  metrics:

  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 70  # Target 70% memory
```bash
### Step 7: Vertical Pod Autoscaler (VPA) - Concepts

VPA recommends and automatically adjusts CPU/memory requests/limits.

**Note**: VPA requires separate installation (not in kind by default).

Conceptual VPA manifest:
```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: webapp-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: webapp-hpa
  updatePolicy:
    updateMode: "Auto"  # Auto, Recreate, Initial, Off
  resourcePolicy:
    containerPolicies:

    - containerName: "*"
      minAllowed:
        cpu: "50m"
        memory: "50Mi"
      maxAllowed:
        cpu: "1"
        memory: "500Mi"
```

**VPA modes**:

- **Off**: Only recommendations, no updates
- **Initial**: Sets resources on pod creation only
- **Recreate**: Restarts pods with new resources
- **Auto**: Recreate + future in-place updates

### Step 8: Pod Priority and Preemption

Priority determines which pods are scheduled first and which are evicted.

1. **Create PriorityClasses**:

Save as `priorityclass.yaml`:
```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority
value: 1000000
globalDefault: false
description: "High priority for critical workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: medium-priority
value: 1000
globalDefault: false
description: "Medium priority for standard workloads"
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: low-priority
value: 100
globalDefault: true
description: "Low priority for batch jobs"
```

Apply:
```bash
kubectl apply -f priorityclass.yaml
kubectl get priorityclass
```

2. **Use priority in pods**:

Save as `pod-priority.yaml`:
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: high-priority-pod
spec:
  priorityClassName: high-priority
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
---
apiVersion: v1
kind: Pod
metadata:
  name: low-priority-pod
spec:
  priorityClassName: low-priority
  containers:

  - name: app
    image: nginx:1.25
    resources:
      requests:
        memory: "100Mi"
        cpu: "100m"
```

Apply:
```bash
kubectl apply -f pod-priority.yaml
kubectl get pods -o custom-columns=NAME:.metadata.name,PRIORITY:.spec.priority
```bash
**Preemption**: If a high-priority pod can't be scheduled due to resource constraints, Kubernetes evicts low-priority pods to make room.

### Step 9: Monitor Resource Usage

1. **Check node resources**:
```bash
kubectl top nodes
kubectl describe nodes | grep -A 5 "Allocated resources"
```

2. **Check pod resources**:
```bash
kubectl top pods
kubectl top pods --containers
```bash
3. **View resource usage over time**:
```bash
# Get metrics for specific pod

kubectl top pod resource-demo --containers

# Watch in real-time

watch kubectl top pods
```bash
4. **Check resource quotas**:
```bash
kubectl get resourcequota
kubectl describe resourcequota compute-quota
```bash
### Step 10: Resource Management Best Practices

1. **Always set requests** (for scheduling):
```yaml
resources:
  requests:
    memory: "64Mi"
    cpu: "100m"
```bash
2. **Set limits to prevent resource hogging**:
```yaml
resources:
  limits:
    memory: "128Mi"  # OOMKill if exceeded
    cpu: "200m"      # Throttle if exceeded
```bash
3. **Use LimitRange for defaults**:

- Prevents pods without resource specs
- Enforces min/max boundaries

4. **Use ResourceQuota for cost control**:

- Limits total resources per team/namespace
- Prevents runaway resource consumption

5. **Choose appropriate QoS**:

- **Critical services**: Guaranteed (requests = limits)
- **Standard apps**: Burstable (requests < limits)
- **Batch jobs**: BestEffort (no resources)

## Validation

Verify your understanding:

```bash
# 1. Check all QoS classes are present

kubectl get pods -o custom-columns=NAME:.metadata.name,QOS:.status.qosClass | grep -E "Guaranteed|Burstable|BestEffort"

# 2. Verify LimitRange is active

kubectl describe limitrange resource-constraints | grep -i default

# 3. Check ResourceQuota usage

kubectl get resourcequota compute-quota -o jsonpath='{.status.used}'

# 4. Verify HPA exists and is working

kubectl get hpa webapp-hpa
# Should show current/target metrics

# 5. Check PriorityClasses

kubectl get priorityclass
# Should show high, medium, low priorities

# 6. View resource usage

kubectl top pods --sort-by=cpu
```bash
## Practice Challenges

Test your skills:

1. **Challenge 1**: Create a pod with Guaranteed QoS class using 500m CPU and 256Mi memory
   <details>
   <summary>Solution</summary>
   Set requests = limits for both CPU and memory
   </details>

2. **Challenge 2**: Create an HPA that scales based on both CPU (50%) and memory (70%)
   <details>
   <summary>Hint</summary>
   Use multiple metrics in HPA spec
   </details>

3. **Challenge 3**: Set up a namespace with quota allowing max 5 pods and 1 CPU total
   <details>
   <summary>Solution</summary>
   ```yaml
   spec:
     hard:
       pods: "5"
       requests.cpu: "1"
   ```bash
   </details>

4. **Challenge 4**: Create a deployment that gets evicted when higher priority pods need resources
   <details>
   <summary>Hint</summary>
   Use low-priority PriorityClass and create resource pressure
   </details>

5. **Challenge 5**: Configure LimitRange to set default CPU request of 100m and limit of 500m
   <details>
   <summary>Solution in limitrange.yaml</summary>
   defaultRequest.cpu: "100m", default.cpu: "500m"
   </details>

## Cleanup

Remove all resources:

```bash
# Delete namespace

kubectl delete namespace lab-07

# Delete cluster-scoped resources

kubectl delete priorityclass high-priority medium-priority low-priority

# If installed metrics-server

kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```bash
## Troubleshooting Guide

| Issue | Diagnostic | Solution |
|-------|-----------|----------|
| Pod pending due to resources | `kubectl describe pod <name>` | Insufficient CPU/memory on nodes |
| OOMKilled | `kubectl describe pod` | Increase memory limits |
| CPU throttling | `kubectl top pod` | Increase CPU limits or reduce usage |
| HPA not scaling | `kubectl describe hpa` | Check metrics-server, resource requests set |
| Quota exceeded | `kubectl describe resourcequota` | Increase quota or delete resources |
| LimitRange rejected pod | `kubectl describe limitrange` | Adjust pod resources to fit constraints |

**Essential debugging**:
```bash
kubectl top nodes
kubectl top pods
kubectl describe node <node-name>
kubectl describe hpa <name>
kubectl get events --sort-by='.lastTimestamp'
```

## Key Takeaways

- ✅ **Requests**: Guaranteed resources, used for scheduling decisions
- ✅ **Limits**: Maximum resources, enforcement varies (OOM vs throttling)
- ✅ **QoS Classes**: Guaranteed > Burstable > BestEffort (eviction order)
- ✅ **LimitRange**: Default resources, min/max per container/pod
- ✅ **ResourceQuota**: Aggregate limits per namespace
- ✅ **HPA**: Horizontal scaling based on metrics (CPU, memory, custom)
- ✅ **VPA**: Vertical scaling - adjusts resource requests/limits
- ✅ **Priority**: Determines scheduling order and preemption
- ✅ **CPU**: Throttled when limit exceeded (not killed)
- ✅ **Memory**: OOMKilled when limit exceeded
- ✅ **Always set requests**: Enables proper scheduling and QoS

## Additional Resources

- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)
- [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/)

## Next Lab

[Lab 8: Debugging & Troubleshooting](../lab-08-debugging/) - Master debugging techniques for production issues

---

**Estimated Time**: 120-150 minutes
