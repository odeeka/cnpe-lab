# Lab 4: Cost Optimization

## 🎯 Objective

Learn techniques to optimize Kubernetes infrastructure costs including resource right-sizing, autoscaling strategies, spot/preemptible instance usage, and FinOps practices.

---

## 📚 What You'll Learn

- Resource right-sizing based on actual usage
- Horizontal Pod Autoscaling (HPA)
- Vertical Pod Autoscaling (VPA)
- Cluster Autoscaler configuration
- Spot/Preemptible instance strategies
- Cost monitoring and allocation
- FinOps practices for Kubernetes

---

## 🔧 Prerequisites

- Running Kubernetes cluster
- Metrics Server installed
- kubectl configured
- (Optional) Kubecost for cost visibility

```bash
# Verify metrics server
kubectl top nodes
kubectl top pods -A

# Install Kubecost (optional but recommended)
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer -n kubecost --create-namespace
```

---

## 📖 Concepts

### Cost Optimization Pillars

```
┌─────────────────────────────────────────────────────────────────┐
│                 Kubernetes Cost Optimization                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────┐ │
│  │   Right     │  │    Auto     │  │   Spot/     │  │  Cost   │ │
│  │   Sizing    │  │   Scaling   │  │ Preemptible │  │ Visible │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └────┬────┘ │
│         │                │                │               │      │
│         ▼                ▼                ▼               ▼      │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                                                              ││
│  │  • Match requests    • HPA for pods   • Tolerations       ││
│  │    to actual usage   • VPA for pods   • Node selectors    ││
│  │  • Set appropriate   • Cluster AS     • Spot nodegroups   ││
│  │    limits            • KEDA for       • Fallback to       ││
│  │  • Remove unused       events           on-demand         ││
│  │    resources                                               ││
│  │                                                              ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                   │
│                  ┌─────────────────────────┐                     │
│                  │     Cost Reduction      │                     │
│                  │      20-60% typical     │                     │
│                  └─────────────────────────┘                     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### FinOps Maturity Model

| Phase | Focus | Activities |
|-------|-------|------------|
| **Crawl** | Visibility | Cost allocation, tagging, basic monitoring |
| **Walk** | Optimization | Right-sizing, autoscaling, spot instances |
| **Run** | Operations | Continuous optimization, automation, culture |

---

## 🛠️ Exercises

### Exercise 1: Resource Right-Sizing

#### 1.1 Analyze Current Resource Usage

```bash
# Check pod resource requests vs actual usage
kubectl top pods -A --containers

# Compare requests to actual
kubectl get pods -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
POD:.metadata.name,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory

# Create resource analysis script
cat > analyze-resources.sh << 'EOF'
#!/bin/bash

echo "Resource Usage Analysis"
echo "========================"
echo ""

for ns in $(kubectl get ns -o jsonpath='{.items[*].metadata.name}'); do
    echo "Namespace: $ns"
    kubectl top pods -n $ns --containers 2>/dev/null | while read line; do
        pod=$(echo $line | awk '{print $1}')
        container=$(echo $line | awk '{print $2}')
        cpu=$(echo $line | awk '{print $3}')
        mem=$(echo $line | awk '{print $4}')
        
        if [ "$pod" != "POD" ]; then
            req=$(kubectl get pod $pod -n $ns -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null)
            echo "  $pod/$container: Using $cpu (Requested: $req)"
        fi
    done
    echo ""
done
EOF
chmod +x analyze-resources.sh
```

#### 1.2 Identify Oversized Workloads

```bash
# Find pods with high request but low usage
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].resources.requests.cpu != null) |
  [.metadata.namespace, .metadata.name, .spec.containers[0].resources.requests.cpu] |
  @tsv' | while read ns pod cpu; do
    actual=$(kubectl top pod $pod -n $ns --containers 2>/dev/null | tail -1 | awk '{print $3}')
    echo "$ns/$pod: Requested=$cpu, Actual=$actual"
done
```

#### 1.3 Create Right-Sized Deployment

```yaml
# right-sized-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: right-sized-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: right-sized-app
  template:
    metadata:
      labels:
        app: right-sized-app
    spec:
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            # Set based on observed P95 usage + 20% buffer
            cpu: 100m
            memory: 128Mi
          limits:
            # CPU limit 2-3x request for bursting
            cpu: 300m
            # Memory limit closer to request (no burst)
            memory: 192Mi
```

### Exercise 2: Horizontal Pod Autoscaler (HPA)

#### 2.1 Basic CPU-Based HPA

```yaml
# hpa-cpu.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 15
      selectPolicy: Max
```

#### 2.2 Memory-Based HPA

```yaml
# hpa-memory.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cache-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: cache-service
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

#### 2.3 Custom Metrics HPA

```yaml
# hpa-custom-metrics.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: queue-worker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: queue-worker
  minReplicas: 1
  maxReplicas: 20
  metrics:
  - type: External
    external:
      metric:
        name: queue_messages_waiting
        selector:
          matchLabels:
            queue: jobs
      target:
        type: AverageValue
        averageValue: 30
```

#### 2.4 HPA Verification

```bash
# Create test deployment
kubectl create deployment hpa-test --image=nginx --replicas=1
kubectl set resources deployment hpa-test --requests=cpu=100m,memory=128Mi
kubectl expose deployment hpa-test --port=80

# Create HPA
kubectl autoscale deployment hpa-test --min=1 --max=10 --cpu-percent=50

# Check HPA status
kubectl get hpa hpa-test -w

# Generate load
kubectl run load-gen --image=busybox --restart=Never -- \
  /bin/sh -c "while true; do wget -q -O- http://hpa-test; done"

# Watch scaling
kubectl get pods -l app=hpa-test -w
```

### Exercise 3: Vertical Pod Autoscaler (VPA)

#### 3.1 Install VPA

```bash
# Clone VPA repository
git clone https://github.com/kubernetes/autoscaler.git
cd autoscaler/vertical-pod-autoscaler

# Install VPA
./hack/vpa-up.sh

# Verify installation
kubectl get pods -n kube-system | grep vpa
```

#### 3.2 VPA in Recommendation Mode

```yaml
# vpa-recommend.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"  # Recommendations only, no auto-update
  resourcePolicy:
    containerPolicies:
    - containerName: '*'
      minAllowed:
        cpu: 50m
        memory: 64Mi
      maxAllowed:
        cpu: 2
        memory: 4Gi
      controlledResources: ["cpu", "memory"]
```

```bash
kubectl apply -f vpa-recommend.yaml

# Wait for recommendations
sleep 120

# Get recommendations
kubectl describe vpa my-app-vpa
```

#### 3.3 VPA in Auto Mode

```yaml
# vpa-auto.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: batch-processor-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: batch-processor
  updatePolicy:
    updateMode: "Auto"  # Automatically update and restart pods
  resourcePolicy:
    containerPolicies:
    - containerName: processor
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 4
        memory: 8Gi
```

> ⚠️ **Warning**: VPA in Auto mode will restart pods to apply new resource settings. Use with caution in production.

### Exercise 4: Cluster Autoscaler

#### 4.1 Cluster Autoscaler Configuration

```yaml
# cluster-autoscaler-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: registry.k8s.io/autoscaling/cluster-autoscaler:v1.29.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws  # or gce, azure
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<cluster-name>
        - --balance-similar-node-groups
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
```

#### 4.2 Node Group Configuration for Autoscaling

```yaml
# Example AWS EKS nodegroup with autoscaling annotations
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: my-cluster
  region: us-west-2

nodeGroups:
  - name: general
    instanceType: m5.large
    desiredCapacity: 2
    minSize: 1
    maxSize: 10
    labels:
      node-type: general
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/my-cluster: "owned"

  - name: spot
    instanceTypes: ["m5.large", "m5.xlarge", "m4.large"]
    spot: true
    desiredCapacity: 2
    minSize: 0
    maxSize: 20
    labels:
      node-type: spot
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule
```

#### 4.3 Pod Priority for Autoscaling

```yaml
# priority-classes.yaml
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
  name: low-priority
value: 100
globalDefault: false
preemptionPolicy: Never  # Won't preempt other pods
description: "Low priority for batch workloads"
```

### Exercise 5: Spot/Preemptible Instances

#### 5.1 Spot-Friendly Deployment

```yaml
# spot-tolerant-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
spec:
  replicas: 5
  selector:
    matchLabels:
      app: batch-processor
  template:
    metadata:
      labels:
        app: batch-processor
    spec:
      # Prefer spot nodes
      nodeSelector:
        node-type: spot
      tolerations:
      - key: "spot"
        operator: "Equal"
        value: "true"
        effect: "NoSchedule"
      # Handle interruption gracefully
      terminationGracePeriodSeconds: 120
      containers:
      - name: processor
        image: batch-processor:latest
        lifecycle:
          preStop:
            exec:
              command: ["/bin/sh", "-c", "/app/save-checkpoint.sh"]
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
```

#### 5.2 Mixed On-Demand and Spot Strategy

```yaml
# mixed-nodepool-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
spec:
  replicas: 6
  selector:
    matchLabels:
      app: web-app
  template:
    metadata:
      labels:
        app: web-app
    spec:
      # Spread across on-demand and spot
      topologySpreadConstraints:
      - maxSkew: 2
        topologyKey: node-type
        whenUnsatisfiable: ScheduleAnyway
        labelSelector:
          matchLabels:
            app: web-app
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 80
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values:
                - spot
          - weight: 20
            preference:
              matchExpressions:
              - key: node-type
                operator: In
                values:
                - on-demand
      containers:
      - name: web
        image: nginx
```

#### 5.3 Spot Interruption Handler (AWS)

```yaml
# spot-handler-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: spot-interrupt-handler
  namespace: kube-system
spec:
  selector:
    matchLabels:
      app: spot-interrupt-handler
  template:
    metadata:
      labels:
        app: spot-interrupt-handler
    spec:
      nodeSelector:
        node-type: spot
      serviceAccountName: spot-handler
      hostNetwork: true
      containers:
      - name: handler
        image: amazon/aws-node-termination-handler:v1.19.0
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: ENABLE_SPOT_INTERRUPTION_DRAINING
          value: "true"
```

### Exercise 6: Cost Monitoring with Kubecost

#### 6.1 Kubecost Installation

```bash
# Install Kubecost
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --create-namespace \
  --set kubecostToken="<your-token>"

# Access Kubecost UI
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
# Open http://localhost:9090
```

#### 6.2 Cost Allocation Labels

```yaml
# cost-labeled-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-service
  labels:
    app: api-service
    team: backend
    environment: production
    cost-center: engineering
spec:
  replicas: 3
  selector:
    matchLabels:
      app: api-service
  template:
    metadata:
      labels:
        app: api-service
        team: backend
        environment: production
        cost-center: engineering
    spec:
      containers:
      - name: api
        image: api-service:latest
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 512Mi
```

#### 6.3 Cost Allocation API

```bash
# Query Kubecost API for cost data
# Total cluster cost
curl -s http://localhost:9090/model/allocation?window=today

# Cost by namespace
curl -s "http://localhost:9090/model/allocation?window=7d&aggregate=namespace" | jq

# Cost by label
curl -s "http://localhost:9090/model/allocation?window=7d&aggregate=label:team" | jq
```

### Exercise 7: Resource Quotas and Limits

#### 7.1 Namespace Resource Quota

```yaml
# resource-quota.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-alpha
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
    persistentvolumeclaims: "10"
    services: "10"
```

#### 7.2 LimitRange for Defaults

```yaml
# limit-range.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-alpha
spec:
  limits:
  - default:
      cpu: 500m
      memory: 512Mi
    defaultRequest:
      cpu: 100m
      memory: 128Mi
    max:
      cpu: 2
      memory: 4Gi
    min:
      cpu: 50m
      memory: 64Mi
    type: Container
```

#### 7.3 Enforce Resource Requirements

```yaml
# Kyverno policy to enforce resource limits
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-resource-limits
spec:
  validationFailureAction: enforce
  rules:
  - name: require-limits
    match:
      resources:
        kinds:
        - Pod
    validate:
      message: "CPU and memory limits are required"
      pattern:
        spec:
          containers:
          - resources:
              limits:
                memory: "?*"
                cpu: "?*"
```

### Exercise 8: Cost Optimization Checklist

```bash
#!/bin/bash
# cost-optimization-audit.sh

echo "╔════════════════════════════════════════════════════════════╗"
echo "║            Kubernetes Cost Optimization Audit              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Check for pods without resource requests
echo "═══ Pods Without Resource Requests ═══"
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].resources.requests == null) |
  [.metadata.namespace, .metadata.name] |
  @tsv' | head -20
echo ""

# Check for pods without resource limits
echo "═══ Pods Without Resource Limits ═══"
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].resources.limits == null) |
  [.metadata.namespace, .metadata.name] |
  @tsv' | head -20
echo ""

# Check for idle deployments (0 replicas for >7 days)
echo "═══ Deployments with 0 Replicas ═══"
kubectl get deployments -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
REPLICAS:.spec.replicas | grep " 0$"
echo ""

# Check for HPA not present
echo "═══ Deployments Without HPA ═══"
for deploy in $(kubectl get deployments -A -o jsonpath='{range .items[*]}{.metadata.namespace}:{.metadata.name}{"\n"}{end}'); do
    ns=$(echo $deploy | cut -d: -f1)
    name=$(echo $deploy | cut -d: -f2)
    hpa=$(kubectl get hpa -n $ns -o jsonpath='{.items[?(@.spec.scaleTargetRef.name=="'$name'")].metadata.name}' 2>/dev/null)
    if [ -z "$hpa" ]; then
        echo "  $ns/$name"
    fi
done | head -20
echo ""

# Check for unused PVCs
echo "═══ Potentially Unused PVCs ═══"
kubectl get pvc -A -o json | jq -r '
  .items[] |
  select(.status.phase == "Bound") |
  [.metadata.namespace, .metadata.name, .spec.resources.requests.storage] |
  @tsv'
echo ""

# Check resource quotas
echo "═══ Namespaces Without Resource Quotas ═══"
kubectl get ns -o name | while read ns; do
    ns=${ns#namespace/}
    quota=$(kubectl get resourcequota -n $ns 2>/dev/null | wc -l)
    if [ "$quota" -eq 0 ]; then
        echo "  $ns"
    fi
done | head -20
echo ""

echo "═══ Audit Complete ═══"
```

---

## 🔍 Verification

Test your cost optimization setup:

```bash
# 1. Verify VPA recommendations
kubectl get vpa -A -o custom-columns=\
NAME:.metadata.name,\
MODE:.spec.updatePolicy.updateMode,\
PROVIDED:.status.recommendation.containerRecommendations[0].target

# 2. Verify HPA is working
kubectl get hpa -A
kubectl describe hpa <hpa-name>

# 3. Check resource quotas
kubectl describe quota -A

# 4. Check cost allocation labels
kubectl get pods -A --show-labels | grep cost-center
```

---

## 📝 Key Takeaways

1. **Right-size first** - Analyze actual usage before setting resources
2. **Set requests AND limits** - Requests for scheduling, limits for protection
3. **Use HPA for load-based workloads** - Scale pods with demand
4. **Consider VPA for recommendations** - Get data-driven sizing suggestions
5. **Embrace spot instances** - 60-90% savings for fault-tolerant workloads
6. **Make costs visible** - Use labels for cost allocation
7. **Automate optimization** - Continuous improvement, not one-time fixes

---

## 🔗 Next Lab

Continue to [Lab 5: Capacity Planning →](../lab-05-capacity-planning/README.md)

---

## 📚 Additional Resources

- [Kubernetes Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler)
- [Kubecost Documentation](https://docs.kubecost.com/)
- [FinOps Foundation](https://www.finops.org/)
