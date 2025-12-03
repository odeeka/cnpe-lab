# Lab 5: Capacity Planning

## 🎯 Objective

Learn to plan and manage Kubernetes cluster capacity including resource forecasting, scaling strategies, multi-cluster management, and SLA/SLO management.

---

## 📚 What You'll Learn

- Resource forecasting and trend analysis
- Node capacity planning
- Scaling strategies (vertical vs horizontal)
- Multi-cluster architectures
- SLO/SLA management
- Capacity planning automation

---

## 🔧 Prerequisites

- Running Kubernetes cluster with monitoring
- Prometheus/Grafana stack deployed
- kubectl configured
- Historical metrics data (or ability to generate)

```bash
# Verify monitoring stack
kubectl get pods -n monitoring

# Check metrics availability
kubectl top nodes
kubectl top pods -A
```

---

## 📖 Concepts

### Capacity Planning Framework

```
┌─────────────────────────────────────────────────────────────────┐
│                  Capacity Planning Cycle                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│                      ┌───────────┐                               │
│                      │  Monitor  │                               │
│                      │  Current  │                               │
│                      │  Usage    │                               │
│                      └─────┬─────┘                               │
│                            │                                      │
│              ┌─────────────┼─────────────┐                       │
│              ▼             │             ▼                       │
│        ┌───────────┐       │       ┌───────────┐                 │
│        │  Analyze  │       │       │  Forecast │                 │
│        │  Trends   │       │       │  Demand   │                 │
│        └─────┬─────┘       │       └─────┬─────┘                 │
│              │             │             │                        │
│              └─────────────┼─────────────┘                       │
│                            ▼                                      │
│                      ┌───────────┐                               │
│                      │   Plan    │                               │
│                      │  Capacity │                               │
│                      └─────┬─────┘                               │
│                            │                                      │
│              ┌─────────────┼─────────────┐                       │
│              ▼             │             ▼                       │
│        ┌───────────┐       │       ┌───────────┐                 │
│        │ Implement │       │       │  Review   │                 │
│        │  Changes  │       │       │  & Tune   │                 │
│        └───────────┘       │       └───────────┘                 │
│                            │                                      │
│                            ▼                                      │
│                     (Repeat Cycle)                               │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Key Capacity Metrics

| Metric | Description | Target Range |
|--------|-------------|--------------|
| **CPU Utilization** | Actual CPU usage vs allocatable | 60-80% |
| **Memory Utilization** | Actual memory usage vs allocatable | 70-85% |
| **Pod Density** | Pods running per node | Depends on workload |
| **Request Saturation** | Requested resources vs allocatable | 80-90% |
| **Headroom** | Available capacity for growth | 20-30% |

---

## 🛠️ Exercises

### Exercise 1: Current Capacity Analysis

#### 1.1 Node Capacity Overview

```bash
# Get node capacity and allocatable resources
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU_CAP:.status.capacity.cpu,\
MEM_CAP:.status.capacity.memory,\
CPU_ALLOC:.status.allocatable.cpu,\
MEM_ALLOC:.status.allocatable.memory,\
PODS_CAP:.status.capacity.pods

# Detailed node resource analysis
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== $node ==="
    kubectl describe node $node | grep -A10 "Allocated resources:"
done
```

#### 1.2 Capacity Analysis Script

```bash
#!/bin/bash
# capacity-analysis.sh

echo "╔════════════════════════════════════════════════════════════╗"
echo "║           Kubernetes Cluster Capacity Analysis             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Get total cluster capacity
total_cpu=0
total_mem=0
alloc_cpu=0
alloc_mem=0

echo "═══ Per-Node Capacity ═══"
printf "%-30s %10s %15s %10s %15s\n" "NODE" "CPU_CAP" "MEM_CAP" "CPU_ALLOC" "MEM_ALLOC"

for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    cpu_cap=$(kubectl get node $node -o jsonpath='{.status.capacity.cpu}')
    mem_cap=$(kubectl get node $node -o jsonpath='{.status.capacity.memory}')
    cpu_alloc=$(kubectl get node $node -o jsonpath='{.status.allocatable.cpu}')
    mem_alloc=$(kubectl get node $node -o jsonpath='{.status.allocatable.memory}')
    
    printf "%-30s %10s %15s %10s %15s\n" "$node" "$cpu_cap" "$mem_cap" "$cpu_alloc" "$mem_alloc"
done

echo ""
echo "═══ Resource Requests vs Capacity ═══"

# Calculate total requests across all pods
total_cpu_req=$(kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}{end}' | \
    awk '{
        if(/m$/) { sub(/m$/,"",$1); total+=$1 }
        else { total+=$1*1000 }
    } END { printf "%.0fm", total }')

total_mem_req=$(kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.resources.requests.memory}{"\n"}{end}{end}' | \
    awk '{
        if(/Ki$/) { sub(/Ki$/,"",$1); total+=$1/1024 }
        else if(/Mi$/) { sub(/Mi$/,"",$1); total+=$1 }
        else if(/Gi$/) { sub(/Gi$/,"",$1); total+=$1*1024 }
        else { total+=$1/1048576 }
    } END { printf "%.0fMi", total }')

echo "Total CPU Requests: $total_cpu_req"
echo "Total Memory Requests: $total_mem_req"

echo ""
echo "═══ Actual Usage (requires metrics-server) ═══"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

echo ""
echo "═══ Pod Distribution ═══"
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c | sort -rn | head -10
```

#### 1.3 Prometheus Capacity Queries

```yaml
# capacity-dashboard.yaml (Grafana dashboard queries)

# CPU Request Saturation per Node
sum by (node) (
  kube_pod_container_resource_requests{resource="cpu"}
) / on(node) group_left() 
sum by (node) (
  kube_node_status_allocatable{resource="cpu"}
) * 100

# Memory Request Saturation per Node  
sum by (node) (
  kube_pod_container_resource_requests{resource="memory"}
) / on(node) group_left()
sum by (node) (
  kube_node_status_allocatable{resource="memory"}
) * 100

# Available Headroom (pods)
sum by (node) (
  kube_node_status_allocatable{resource="pods"}
) - on(node) group_left()
sum by (node) (
  kube_pod_info
)

# Actual CPU Usage Rate
1 - avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle"}[5m])
)

# Actual Memory Usage
1 - (
  node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
)
```

### Exercise 2: Demand Forecasting

#### 2.1 Trend Analysis Queries

```yaml
# Prometheus queries for trend analysis

# CPU usage trend (7-day)
avg_over_time(
  sum(rate(container_cpu_usage_seconds_total[5m]))[7d:1h]
)

# Memory usage trend (7-day)
avg_over_time(
  sum(container_memory_working_set_bytes)[7d:1h]
)

# Pod count trend
avg_over_time(
  sum(kube_pod_status_phase{phase="Running"})[7d:1h]
)

# Linear regression for CPU forecast (using Prometheus recording rule)
# predict_linear(metric[time_range], seconds_ahead)
predict_linear(
  sum(rate(container_cpu_usage_seconds_total[5m]))[7d:1h],
  86400 * 30  # 30 days ahead
)
```

#### 2.2 Growth Rate Calculation

```bash
#!/bin/bash
# growth-analysis.sh

echo "═══ Resource Growth Analysis ═══"

# Get current metrics
current_pods=$(kubectl get pods -A --no-headers | wc -l)
current_cpu=$(kubectl top nodes --no-headers | awk '{sum+=$3} END {print sum}')
current_mem=$(kubectl top nodes --no-headers | awk '{sum+=$5} END {print sum}')

echo "Current State:"
echo "  Pods: $current_pods"
echo "  CPU Usage: ${current_cpu}%"
echo "  Memory Usage: ${current_mem}%"

# Query Prometheus for historical data (requires promtool or API)
echo ""
echo "For detailed growth analysis, use Grafana with these queries:"
echo ""
echo "Weekly Growth Rate:"
echo '  (sum(kube_pod_status_phase{phase="Running"}) - sum(kube_pod_status_phase{phase="Running"} offset 7d)) / sum(kube_pod_status_phase{phase="Running"} offset 7d) * 100'
echo ""
echo "Monthly Growth Rate:"
echo '  (sum(kube_pod_status_phase{phase="Running"}) - sum(kube_pod_status_phase{phase="Running"} offset 30d)) / sum(kube_pod_status_phase{phase="Running"} offset 30d) * 100'
```

#### 2.3 Capacity Planning Spreadsheet

```markdown
# Capacity Planning Template

## Current State
| Resource | Capacity | Allocated | Used | Available |
|----------|----------|-----------|------|-----------|
| CPU (cores) | 48 | 36 | 24 | 12 |
| Memory (GB) | 192 | 144 | 96 | 48 |
| Pods | 330 | - | 245 | 85 |

## Growth Projections
| Timeframe | Pod Growth | CPU Growth | Memory Growth |
|-----------|------------|------------|---------------|
| Current | 245 | 24 cores | 96 GB |
| +3 months | 294 (+20%) | 29 cores | 115 GB |
| +6 months | 343 (+40%) | 34 cores | 134 GB |
| +12 months | 441 (+80%) | 43 cores | 173 GB |

## Capacity Actions
| Timeframe | Action Required |
|-----------|-----------------|
| Now | None - 25% headroom |
| +3 months | Monitor closely |
| +6 months | Add 2 nodes |
| +12 months | Add 4-6 nodes |
```

### Exercise 3: Scaling Strategies

#### 3.1 Vertical vs Horizontal Scaling Decision Matrix

```
┌─────────────────────────────────────────────────────────────────┐
│            Scaling Strategy Decision Matrix                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Choose VERTICAL when:          Choose HORIZONTAL when:          │
│  ┌─────────────────────────┐   ┌─────────────────────────────┐  │
│  │ • Single-threaded app   │   │ • Stateless application    │  │
│  │ • Database workloads    │   │ • Web services             │  │
│  │ • Legacy applications   │   │ • API servers              │  │
│  │ • Cache with large mem  │   │ • Microservices            │  │
│  │ • Cost-sensitive        │   │ • High availability needs  │  │
│  └─────────────────────────┘   └─────────────────────────────┘  │
│                                                                   │
│  Hybrid Approach:                                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ 1. Right-size individual pods (vertical)                   ││
│  │ 2. Scale number of pods (horizontal)                       ││
│  │ 3. Scale cluster capacity (nodes)                          ││
│  └─────────────────────────────────────────────────────────────┘│
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

#### 3.2 Node Pool Strategy

```yaml
# node-pool-strategy.yaml

# Production Node Pools
node_pools:
  # General purpose - most workloads
  general:
    instance_type: m5.xlarge
    min_nodes: 3
    max_nodes: 10
    labels:
      workload-type: general
    taints: []
    
  # Memory optimized - caching, databases
  memory:
    instance_type: r5.xlarge
    min_nodes: 2
    max_nodes: 5
    labels:
      workload-type: memory
    taints:
      - key: workload-type
        value: memory
        effect: NoSchedule
        
  # Compute optimized - batch processing
  compute:
    instance_type: c5.2xlarge
    min_nodes: 0
    max_nodes: 20
    labels:
      workload-type: compute
    taints:
      - key: workload-type
        value: compute
        effect: NoSchedule
        
  # Spot instances - fault-tolerant workloads
  spot:
    instance_types: [m5.xlarge, m5.2xlarge, m4.xlarge]
    spot: true
    min_nodes: 0
    max_nodes: 30
    labels:
      workload-type: spot
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule
```

#### 3.3 Karpenter for Dynamic Provisioning

```yaml
# karpenter-provisioner.yaml
apiVersion: karpenter.sh/v1alpha5
kind: Provisioner
metadata:
  name: default
spec:
  requirements:
    - key: karpenter.sh/capacity-type
      operator: In
      values: ["spot", "on-demand"]
    - key: kubernetes.io/arch
      operator: In
      values: ["amd64"]
    - key: node.kubernetes.io/instance-type
      operator: In
      values: ["m5.large", "m5.xlarge", "m5.2xlarge", "c5.large", "c5.xlarge"]
  limits:
    resources:
      cpu: 100
      memory: 400Gi
  providerRef:
    name: default
  ttlSecondsAfterEmpty: 30
  ttlSecondsUntilExpired: 604800  # 7 days
---
apiVersion: karpenter.k8s.aws/v1alpha1
kind: AWSNodeTemplate
metadata:
  name: default
spec:
  subnetSelector:
    karpenter.sh/discovery: my-cluster
  securityGroupSelector:
    karpenter.sh/discovery: my-cluster
  instanceProfile: KarpenterNodeInstanceProfile-my-cluster
  blockDeviceMappings:
    - deviceName: /dev/xvda
      ebs:
        volumeSize: 100Gi
        volumeType: gp3
```

### Exercise 4: Multi-Cluster Strategies

#### 4.1 Multi-Cluster Architecture Patterns

```
┌─────────────────────────────────────────────────────────────────┐
│              Multi-Cluster Architecture Patterns                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Regional Failover                                            │
│  ┌─────────────────┐     ┌─────────────────┐                    │
│  │   Cluster A     │     │   Cluster B     │                    │
│  │   (Primary)     │────►│   (Standby)     │                    │
│  │   Region: US-E  │     │   Region: US-W  │                    │
│  └─────────────────┘     └─────────────────┘                    │
│                                                                   │
│  2. Active-Active                                                │
│  ┌─────────────────┐     ┌─────────────────┐                    │
│  │   Cluster A     │◄───►│   Cluster B     │                    │
│  │   Region: US-E  │     │   Region: EU-W  │                    │
│  └────────┬────────┘     └────────┬────────┘                    │
│           │       Global LB       │                              │
│           └───────────┬───────────┘                              │
│                       ▼                                          │
│                   [ Users ]                                      │
│                                                                   │
│  3. Federation/Fleet                                             │
│  ┌─────────────────────────────────────────┐                    │
│  │            Control Plane                 │                    │
│  │         (Fleet Management)               │                    │
│  └────────────────┬────────────────────────┘                    │
│           ┌───────┼───────┬───────┐                             │
│           ▼       ▼       ▼       ▼                             │
│        [Prod]  [Stage]  [Dev]  [Edge]                           │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

#### 4.2 Cluster Sizing Guidelines

```yaml
# cluster-sizing-guidelines.yaml

cluster_sizes:
  small:
    description: "Development, testing, small applications"
    control_plane:
      nodes: 1
      instance_type: m5.large
    workers:
      min_nodes: 2
      max_nodes: 5
      instance_type: m5.large
    capacity:
      max_pods: 100
      max_cpu: 20
      max_memory: 80Gi
      
  medium:
    description: "Production workloads, moderate scale"
    control_plane:
      nodes: 3  # HA
      instance_type: m5.xlarge
    workers:
      min_nodes: 5
      max_nodes: 20
      instance_type: m5.xlarge
    capacity:
      max_pods: 1000
      max_cpu: 80
      max_memory: 320Gi
      
  large:
    description: "Enterprise production, high scale"
    control_plane:
      nodes: 3
      instance_type: m5.2xlarge
    workers:
      min_nodes: 20
      max_nodes: 100
      instance_type: m5.2xlarge
    capacity:
      max_pods: 10000
      max_cpu: 800
      max_memory: 3200Gi
```

#### 4.3 Cross-Cluster Configuration

```yaml
# kubefed-config.yaml (Federation v2 example)
apiVersion: core.kubefed.io/v1beta1
kind: KubeFedConfig
metadata:
  name: kubefed
  namespace: kube-federation-system
spec:
  scope: Namespaced
  controllerDuration:
    availableDelay: 20s
    unavailableDelay: 60s
  leaderElect:
    leaseDuration: 15s
    renewDeadline: 10s
    retryPeriod: 5s
    resourceLock: configmaps
  featureGates:
  - name: PushReconciler
    configuration: Enabled
  - name: SchedulerPreferences
    configuration: Enabled
---
apiVersion: core.kubefed.io/v1beta1
kind: FederatedDeployment
metadata:
  name: web-app
  namespace: production
spec:
  template:
    metadata:
      labels:
        app: web-app
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: web-app
      template:
        metadata:
          labels:
            app: web-app
        spec:
          containers:
          - name: web
            image: nginx
  placement:
    clusters:
    - name: cluster-us-east
    - name: cluster-us-west
    - name: cluster-eu-west
  overrides:
  - clusterName: cluster-us-east
    clusterOverrides:
    - path: "/spec/replicas"
      value: 5  # More replicas in primary region
```

### Exercise 5: SLO/SLA Management

#### 5.1 Define SLOs

```yaml
# slo-definitions.yaml

slos:
  availability:
    name: "Service Availability"
    target: 99.9%
    measurement: |
      1 - (sum(rate(http_requests_total{status=~"5.."}[30d])) / 
           sum(rate(http_requests_total[30d])))
    error_budget: 43.2 minutes per month
    
  latency:
    name: "API Latency P99"
    target: 200ms
    measurement: |
      histogram_quantile(0.99, 
        sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
      )
    error_budget: 0.1% of requests > 200ms
    
  throughput:
    name: "Minimum Throughput"
    target: 1000 rps
    measurement: |
      sum(rate(http_requests_total[1m]))
```

#### 5.2 Error Budget Tracking

```yaml
# error-budget-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: error-budget-alerts
  namespace: monitoring
spec:
  groups:
    - name: error-budget
      rules:
        - alert: ErrorBudgetBurnRateCritical
          expr: |
            (
              sum(rate(http_requests_total{status=~"5.."}[1h])) /
              sum(rate(http_requests_total[1h]))
            ) > (1 - 0.999) * 14.4
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Error budget burning too fast"
            description: "At current error rate, monthly error budget will be exhausted in {{ $value | humanize }} hours"
            
        - alert: ErrorBudgetLow
          expr: |
            (
              1 - (
                sum(increase(http_requests_total{status=~"5.."}[30d])) /
                sum(increase(http_requests_total[30d]))
              )
            ) < 0.999 * 0.25
          labels:
            severity: warning
          annotations:
            summary: "Error budget below 25%"
            description: "Only {{ $value | humanizePercentage }} of monthly error budget remaining"
```

#### 5.3 SLO Dashboard

```yaml
# slo-dashboard-queries.yaml

panels:
  - title: "Availability SLO"
    query: |
      1 - (
        sum(rate(http_requests_total{status=~"5.."}[30d])) /
        sum(rate(http_requests_total[30d]))
      )
    target: 0.999
    
  - title: "Error Budget Remaining"
    query: |
      (
        0.001 - (
          sum(increase(http_requests_total{status=~"5.."}[30d])) /
          sum(increase(http_requests_total[30d]))
        )
      ) / 0.001 * 100
      
  - title: "Error Budget Burn Rate"
    query: |
      (
        sum(rate(http_requests_total{status=~"5.."}[1h])) /
        sum(rate(http_requests_total[1h]))
      ) / 0.001
      
  - title: "P99 Latency"
    query: |
      histogram_quantile(0.99, 
        sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
      )
    target: 0.2  # 200ms
```

### Exercise 6: Capacity Planning Automation

#### 6.1 Automated Capacity Alerts

```yaml
# capacity-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: capacity-planning-alerts
  namespace: monitoring
spec:
  groups:
    - name: capacity
      rules:
        # Node capacity alerts
        - alert: NodeCPUCapacityReaching
          expr: |
            (
              sum by (node) (kube_pod_container_resource_requests{resource="cpu"}) /
              sum by (node) (kube_node_status_allocatable{resource="cpu"})
            ) > 0.85
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.node }} CPU capacity at {{ $value | humanizePercentage }}"
            runbook: "Consider adding nodes or rightsizing workloads"
            
        - alert: NodeMemoryCapacityReaching
          expr: |
            (
              sum by (node) (kube_pod_container_resource_requests{resource="memory"}) /
              sum by (node) (kube_node_status_allocatable{resource="memory"})
            ) > 0.85
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.node }} memory capacity at {{ $value | humanizePercentage }}"
            
        # Cluster-wide capacity
        - alert: ClusterCPUCapacityCritical
          expr: |
            (
              sum(kube_pod_container_resource_requests{resource="cpu"}) /
              sum(kube_node_status_allocatable{resource="cpu"})
            ) > 0.90
          for: 15m
          labels:
            severity: critical
          annotations:
            summary: "Cluster CPU capacity at {{ $value | humanizePercentage }}"
            
        # Predictive alert
        - alert: ClusterCapacityPrediction
          expr: |
            predict_linear(
              sum(kube_pod_container_resource_requests{resource="cpu"})[7d:1h],
              86400 * 7  # 7 days ahead
            ) > sum(kube_node_status_allocatable{resource="cpu"}) * 0.9
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "Predicted CPU capacity exhaustion within 7 days"
```

#### 6.2 Capacity Report Generator

```bash
#!/bin/bash
# weekly-capacity-report.sh

REPORT_DATE=$(date +%Y-%m-%d)
REPORT_FILE="/tmp/capacity-report-${REPORT_DATE}.md"

cat > $REPORT_FILE << EOF
# Weekly Capacity Report
**Generated:** ${REPORT_DATE}

## Cluster Overview
EOF

echo "### Node Summary" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get nodes -o wide >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "### Resource Utilization" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl top nodes >> $REPORT_FILE 2>/dev/null || echo "Metrics unavailable" >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "### Capacity Analysis" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== $node ===" >> $REPORT_FILE
    kubectl describe node $node | grep -A10 "Allocated resources:" >> $REPORT_FILE
done
echo '```' >> $REPORT_FILE

echo "### Pod Distribution" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c | sort -rn >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "### Namespaces by Resource Usage" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
kubectl top pods -A --sort-by=cpu 2>/dev/null | head -20 >> $REPORT_FILE
echo '```' >> $REPORT_FILE

echo "### Recommendations" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Calculate recommendations
total_cpu_req=$(kubectl get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.resources.requests.cpu}{"\n"}{end}{end}' | \
    awk '{if(/m$/) {sub(/m$/,"",$1); total+=$1} else {total+=$1*1000}} END {print total}')
total_cpu_alloc=$(kubectl get nodes -o jsonpath='{.items[*].status.allocatable.cpu}' | tr ' ' '\n' | \
    awk '{if(/m$/) {sub(/m$/,"",$1); total+=$1} else {total+=$1*1000}} END {print total}')

cpu_util=$((total_cpu_req * 100 / total_cpu_alloc))

if [ $cpu_util -gt 85 ]; then
    echo "⚠️ **HIGH PRIORITY:** CPU capacity at ${cpu_util}% - add nodes within 1 week" >> $REPORT_FILE
elif [ $cpu_util -gt 70 ]; then
    echo "📊 **MEDIUM PRIORITY:** CPU capacity at ${cpu_util}% - plan for growth in 2-4 weeks" >> $REPORT_FILE
else
    echo "✅ **LOW PRIORITY:** CPU capacity at ${cpu_util}% - healthy headroom" >> $REPORT_FILE
fi

echo "" >> $REPORT_FILE
echo "---" >> $REPORT_FILE
echo "Report generated by capacity-report.sh" >> $REPORT_FILE

echo "Report generated: $REPORT_FILE"
cat $REPORT_FILE
```

#### 6.3 GitOps Capacity Configuration

```yaml
# capacity-config.yaml (ArgoCD managed)
apiVersion: v1
kind: ConfigMap
metadata:
  name: capacity-config
  namespace: kube-system
data:
  config.yaml: |
    clusters:
      production:
        min_nodes: 5
        max_nodes: 50
        target_utilization:
          cpu: 70
          memory: 75
        scale_up_threshold:
          cpu: 80
          memory: 85
        scale_down_threshold:
          cpu: 50
          memory: 55
        node_pools:
          general:
            instance_type: m5.xlarge
            min: 3
            max: 20
          compute:
            instance_type: c5.2xlarge
            min: 0
            max: 20
        alerts:
          capacity_warning: 80%
          capacity_critical: 90%
```

---

## 🔍 Verification

Test your capacity planning setup:

```bash
# 1. Check current capacity utilization
kubectl describe nodes | grep -A5 "Allocated resources"

# 2. Verify autoscaler is configured
kubectl get hpa,vpa -A
kubectl get pods -n kube-system | grep cluster-autoscaler

# 3. Test scaling
kubectl create deployment scale-test --image=nginx --replicas=50
kubectl get pods -w  # Watch for new node provisioning

# 4. Cleanup
kubectl delete deployment scale-test
```

---

## 📝 Key Takeaways

1. **Know your current state** - Monitor and analyze before planning
2. **Use historical data** - Base forecasts on actual trends
3. **Maintain headroom** - Keep 20-30% capacity buffer
4. **Automate monitoring** - Set up alerts before capacity issues occur
5. **Plan for growth** - Factor in business projections
6. **Right-size first** - Optimize before adding capacity
7. **SLOs drive decisions** - Let reliability targets guide capacity

---

## 🎉 Module Complete!

Congratulations on completing Module 8: Production Operations! You've learned:

- Day 2 Operations (Lab 1)
- Cluster Upgrades (Lab 2)
- Troubleshooting (Lab 3)
- Cost Optimization (Lab 4)
- Capacity Planning (Lab 5)

Continue to the [Assessment →](../assessment/README.md)

---

## 📚 Additional Resources

- [Kubernetes Cluster Capacity](https://kubernetes.io/docs/concepts/cluster-administration/cluster-administration-overview/)
- [Karpenter Documentation](https://karpenter.sh/docs/)
- [SRE Book - Capacity Planning](https://sre.google/sre-book/software-engineering-in-sre/)
- [FinOps for Kubernetes](https://www.finops.org/wg/containers-kubernetes/)
