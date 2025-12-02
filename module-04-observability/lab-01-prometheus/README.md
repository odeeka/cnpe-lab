# Lab 1: Prometheus Fundamentals

## Introduction

Prometheus is an open-source monitoring and alerting toolkit that has become the de facto standard for Kubernetes monitoring. In this lab, you'll learn to deploy Prometheus, understand its architecture, and master PromQL for querying metrics.

## Learning Objectives

After completing this lab, you will be able to:

- Understand Prometheus architecture and components
- Deploy Prometheus using Helm and kube-prometheus-stack
- Write PromQL queries to analyze metrics
- Configure service discovery for Kubernetes
- Create recording rules for performance optimization
- Understand metric types and instrumentation

## Prerequisites

- Running Kubernetes cluster
- kubectl configured
- Helm 3.x installed
- Basic understanding of YAML

## Duration

Estimated time: 90-120 minutes

---

## Exercise 1: Understanding Prometheus Architecture

### Step 1: Prometheus Components

```text
┌─────────────────────────────────────────────────────────────────┐
│                     PROMETHEUS ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐     ┌──────────────────────────────────────┐ │
│  │   Targets    │     │          PROMETHEUS SERVER           │ │
│  │              │     │  ┌────────────┐  ┌───────────────┐   │ │
│  │ ┌──────────┐ │     │  │  Retrieval │  │    TSDB       │   │ │
│  │ │ Node     │◀┼─────┼──│   (Pull)   │──│  (Storage)    │   │ │
│  │ │ Exporter │ │     │  └────────────┘  └───────────────┘   │ │
│  │ └──────────┘ │     │                          │           │ │
│  │              │     │  ┌────────────┐          │           │ │
│  │ ┌──────────┐ │     │  │  Service   │          ▼           │ │
│  │ │ App      │◀┼─────┼──│ Discovery  │  ┌───────────────┐   │ │
│  │ │ /metrics │ │     │  └────────────┘  │   PromQL      │   │ │
│  │ └──────────┘ │     │                  │   Engine      │   │ │
│  │              │     │  ┌────────────┐  └───────────────┘   │ │
│  │ ┌──────────┐ │     │  │   Rules    │          │           │ │
│  │ │ kube-    │◀┼─────┼──│  Engine    │          ▼           │ │
│  │ │ state    │ │     │  └────────────┘  ┌───────────────┐   │ │
│  │ └──────────┘ │     │        │         │   HTTP API    │   │ │
│  └──────────────┘     │        ▼         └───────────────┘   │ │
│                       │  ┌────────────┐          │           │ │
│                       │  │ Alerting   │──────────┼───────┐   │ │
│                       │  └────────────┘          │       │   │ │
│                       └──────────────────────────┼───────┼───┘ │
│                                                  │       │     │
│  ┌──────────────┐                               │       │     │
│  │   Grafana    │◀──────────────────────────────┘       │     │
│  └──────────────┘                                       │     │
│                                                         ▼     │
│  ┌──────────────┐                              ┌─────────────┐│
│  │ Alertmanager │◀─────────────────────────────│   Alerts    ││
│  └──────────────┘                              └─────────────┘│
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Step 2: Key Concepts

**Pull-based model**: Prometheus scrapes (pulls) metrics from targets at configured intervals.

**Time Series**: Data stored as time series identified by metric name and key-value labels.

**Service Discovery**: Automatically discovers targets in dynamic environments like Kubernetes.

**PromQL**: Powerful query language for selecting and aggregating time series data.

### Step 3: Metric Types

```text
┌─────────────────────────────────────────────────────────────────┐
│                      PROMETHEUS METRIC TYPES                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  COUNTER                         GAUGE                          │
│  ────────                        ─────                          │
│  Monotonically increasing        Can go up and down             │
│                                                                  │
│      ▲                               ▲                          │
│      │    ╱╱╱                        │   ╱╲   ╱╲                │
│      │  ╱╱                           │  ╱  ╲ ╱  ╲               │
│      │╱╱                             │ ╱    ╲    ╲              │
│      └──────────▶                    └────────────▶             │
│                                                                  │
│  Examples:                       Examples:                      │
│  - http_requests_total           - temperature_celsius          │
│  - errors_total                  - memory_usage_bytes           │
│  - bytes_transmitted             - queue_length                 │
│                                                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  HISTOGRAM                       SUMMARY                        │
│  ─────────                       ───────                        │
│  Counts in configurable buckets  Pre-calculated quantiles       │
│                                                                  │
│      ▲                               ▲                          │
│      │ ▓▓▓                           │  Quantiles:              │
│      │ ▓▓▓ ▓▓                        │  p50 = 0.05s             │
│      │ ▓▓▓ ▓▓ ▓                      │  p90 = 0.10s             │
│      │ ▓▓▓ ▓▓ ▓ ▓                    │  p99 = 0.25s             │
│      └──────────────▶                └──────────────▶           │
│       0.1 0.5 1  5 (seconds)                                    │
│                                                                  │
│  Examples:                       Examples:                      │
│  - http_request_duration         - request_latency              │
│  - response_size_bytes           - gc_duration                  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Validation 1

Verify understanding:

```bash
# Answer these questions:
# 1. What is the difference between Counter and Gauge?
# 2. Why does Prometheus use a pull model?
# 3. What is the role of Service Discovery?
```

---

## Exercise 2: Deploy Prometheus Stack

### Step 1: Add Helm Repository

```bash
# Add prometheus-community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# List available charts
helm search repo prometheus-community
```

### Step 2: Create Monitoring Namespace

```bash
# Create namespace for monitoring stack
kubectl create namespace monitoring

# Verify
kubectl get namespace monitoring
```

### Step 3: Create Values File

Create a custom values file for the Prometheus stack:

```yaml
# prometheus-values.yaml
prometheus:
  prometheusSpec:
    # Resource limits
    resources:
      requests:
        memory: 512Mi
        cpu: 250m
      limits:
        memory: 2Gi
        cpu: 1000m
    
    # Retention
    retention: 15d
    retentionSize: "10GB"
    
    # Storage
    storageSpec:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 20Gi
    
    # Service Monitor selectors
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    
    # Additional scrape configs
    additionalScrapeConfigs: []

grafana:
  enabled: true
  adminPassword: "admin123"  # Change in production!
  
  # Persistence
  persistence:
    enabled: true
    size: 5Gi
  
  # Default dashboards
  defaultDashboardsEnabled: true
  
  # Sidecar for dashboard provisioning
  sidecar:
    dashboards:
      enabled: true
      label: grafana_dashboard
    datasources:
      enabled: true

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 5Gi

# Enable node exporter
nodeExporter:
  enabled: true

# Enable kube-state-metrics
kubeStateMetrics:
  enabled: true

# Prometheus Operator
prometheusOperator:
  enabled: true
  resources:
    limits:
      cpu: 200m
      memory: 200Mi
    requests:
      cpu: 100m
      memory: 100Mi
```

### Step 4: Install kube-prometheus-stack

```bash
# Install the stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values prometheus-values.yaml \
  --wait

# Check installation status
kubectl get pods -n monitoring

# Expected output:
# NAME                                                     READY   STATUS    RESTARTS
# alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running   0
# prometheus-grafana-xxx                                   3/3     Running   0
# prometheus-kube-prometheus-operator-xxx                  1/1     Running   0
# prometheus-kube-state-metrics-xxx                        1/1     Running   0
# prometheus-prometheus-kube-prometheus-prometheus-0       2/2     Running   0
# prometheus-prometheus-node-exporter-xxx                  1/1     Running   0
```

### Step 5: Access Prometheus UI

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090 &

# Access in browser: http://localhost:9090

# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Access in browser: http://localhost:3000
# Default credentials: admin / admin123
```

### Validation 2

Verify Prometheus is working:

```bash
# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets | length'

# Should show multiple targets

# Check a basic metric
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result | length'

# Verify all pods are running
kubectl get pods -n monitoring -o wide
```

---

## Exercise 3: PromQL Fundamentals

### Step 1: Basic Queries

Access Prometheus UI at http://localhost:9090 and try these queries:

```promql
# Simple metric selection
up

# Filter by label
up{job="prometheus"}

# Multiple label filters
up{job="prometheus", namespace="monitoring"}

# Regex matching
up{job=~"prometheus.*"}

# Negative matching
up{job!="prometheus"}
```

### Step 2: Understanding Time Series

```promql
# View raw counter
node_cpu_seconds_total

# Filter to specific CPU and mode
node_cpu_seconds_total{cpu="0", mode="idle"}

# Get the rate of change (for counters)
rate(node_cpu_seconds_total{cpu="0", mode="idle"}[5m])
```

### Step 3: Aggregation Operators

```promql
# Sum all HTTP requests
sum(http_requests_total)

# Sum by label
sum by (method) (http_requests_total)

# Average memory usage across nodes
avg(node_memory_MemAvailable_bytes)

# Maximum CPU usage
max(rate(node_cpu_seconds_total{mode!="idle"}[5m]))

# Count number of targets
count(up)

# Quantile (90th percentile)
quantile(0.9, http_request_duration_seconds)
```

### Step 4: Functions

```promql
# Rate: per-second rate of increase (for counters)
rate(http_requests_total[5m])

# Irate: instant rate (for volatile counters)
irate(http_requests_total[5m])

# Increase: total increase over time range
increase(http_requests_total[1h])

# Histogram quantile
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Absent: returns 1 if metric is missing
absent(up{job="missing-job"})

# Changes: number of value changes
changes(process_start_time_seconds[1h])

# Delta: difference between first and last value (for gauges)
delta(temperature_celsius[1h])

# Predict linear: predict value in future
predict_linear(node_filesystem_free_bytes[1h], 4*3600)
```

### Step 5: Binary Operators

```promql
# Arithmetic operators
node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes

# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Comparison operators (filter results)
node_filesystem_avail_bytes < 1000000000

# Comparison operators (return 0/1)
node_filesystem_avail_bytes < bool 1000000000

# AND operator
up == 1 and on(instance) node_cpu_seconds_total
```

### Step 6: Common Patterns

```promql
# CPU Usage Percentage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage Percentage
100 * (1 - ((node_memory_MemAvailable_bytes) / (node_memory_MemTotal_bytes)))

# Disk Usage Percentage
100 - ((node_filesystem_avail_bytes{mountpoint="/"} * 100) / node_filesystem_size_bytes{mountpoint="/"})

# Request Rate per Second
sum(rate(http_requests_total[5m])) by (service)

# Error Rate Percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100

# 99th Percentile Latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))

# Pods Not Running
kube_pod_status_phase{phase!="Running", phase!="Succeeded"} == 1

# Container Restart Count
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

### Validation 3

Practice PromQL queries:

```bash
# In Prometheus UI, run these queries and understand the results:

# 1. How many targets are being scraped?
count(up)

# 2. What is the average memory usage?
avg(node_memory_MemAvailable_bytes)

# 3. Which pods have restarted in the last hour?
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

---

## Exercise 4: Service Discovery

### Step 1: Understanding Kubernetes SD

Prometheus automatically discovers targets in Kubernetes through these roles:

```yaml
# Kubernetes Service Discovery Roles
node:       # Discover nodes
pod:        # Discover pods
service:    # Discover services
endpoints:  # Discover endpoints
ingress:    # Discover ingresses
```

### Step 2: View Current Configuration

```bash
# View Prometheus configuration
kubectl get secret -n monitoring prometheus-prometheus-kube-prometheus-prometheus -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip | head -100
```

### Step 3: ServiceMonitor Resource

ServiceMonitor defines how Prometheus should scrape a service:

```yaml
# servicemonitor-example.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: myapp-monitor
  namespace: monitoring
  labels:
    release: prometheus  # Must match Prometheus selector
spec:
  selector:
    matchLabels:
      app: myapp
  namespaceSelector:
    matchNames:
      - default
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
      scheme: http
```

### Step 4: Create Sample Application with Metrics

```yaml
# sample-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sample-app
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: sample-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      containers:
        - name: app
          image: prom/prometheus:v2.48.0  # Has /metrics endpoint
          ports:
            - containerPort: 9090
              name: metrics
          resources:
            limits:
              memory: "128Mi"
              cpu: "200m"
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: sample-app
  labels:
    app: sample-app
spec:
  ports:
    - port: 9090
      targetPort: 9090
      name: metrics
  selector:
    app: sample-app
```

### Step 5: Create ServiceMonitor

```yaml
# sample-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: sample-app
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: sample-app
  namespaceSelector:
    matchNames:
      - sample-app
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
```

```bash
# Apply resources
kubectl apply -f sample-app.yaml
kubectl apply -f sample-servicemonitor.yaml

# Verify ServiceMonitor is picked up
kubectl get servicemonitor -n monitoring

# Check in Prometheus targets
# http://localhost:9090/targets
```

### Step 6: PodMonitor Resource

For pods without services:

```yaml
# podmonitor-example.yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: myapp-pods
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: myapp
  namespaceSelector:
    matchNames:
      - default
  podMetricsEndpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

### Validation 4

Verify service discovery:

```bash
# Check targets in Prometheus
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Verify ServiceMonitor
kubectl get servicemonitor -A

# Check sample-app is being scraped
curl -s 'http://localhost:9090/api/v1/query?query=up{job="sample-app"}' | jq
```

---

## Exercise 5: Recording Rules

### Step 1: Understanding Recording Rules

Recording rules pre-compute expensive queries and store results as new time series:

```text
Benefits:
- Faster dashboard loading
- Reduced query load
- Consistent aggregations
- Required for complex alerting
```

### Step 2: Create Recording Rules

```yaml
# recording-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: node-recording-rules
  namespace: monitoring
  labels:
    release: prometheus
spec:
  groups:
    - name: node.rules
      interval: 30s
      rules:
        # CPU usage percentage
        - record: instance:node_cpu_utilization:ratio
          expr: |
            1 - avg by (instance) (
              rate(node_cpu_seconds_total{mode="idle"}[5m])
            )
        
        # Memory usage percentage
        - record: instance:node_memory_utilization:ratio
          expr: |
            1 - (
              node_memory_MemAvailable_bytes /
              node_memory_MemTotal_bytes
            )
        
        # Disk usage percentage
        - record: instance:node_filesystem_utilization:ratio
          expr: |
            1 - (
              node_filesystem_avail_bytes{mountpoint="/"} /
              node_filesystem_size_bytes{mountpoint="/"}
            )

    - name: kubernetes.rules
      interval: 30s
      rules:
        # Pod memory usage
        - record: namespace:container_memory_usage_bytes:sum
          expr: |
            sum by (namespace) (
              container_memory_usage_bytes{container!=""}
            )
        
        # Pod CPU usage
        - record: namespace:container_cpu_usage_seconds_total:sum_rate
          expr: |
            sum by (namespace) (
              rate(container_cpu_usage_seconds_total{container!=""}[5m])
            )
        
        # Number of pods per namespace
        - record: namespace:kube_pod_info:count
          expr: |
            count by (namespace) (kube_pod_info)
```

### Step 3: Apply Recording Rules

```bash
# Apply the rules
kubectl apply -f recording-rules.yaml

# Verify rules are loaded
kubectl get prometheusrule -n monitoring

# Check in Prometheus UI
# http://localhost:9090/rules

# Query the recorded metrics
curl -s 'http://localhost:9090/api/v1/query?query=instance:node_cpu_utilization:ratio' | jq
```

### Step 4: Naming Conventions

Follow the recording rule naming convention:

```text
level:metric:operations

Examples:
- instance:node_cpu_utilization:ratio
- namespace:container_memory:sum
- job:http_requests:rate5m
- cluster:node_cpu:sum_rate5m

Levels:
- cluster: Aggregated across cluster
- namespace: Aggregated by namespace
- job: Aggregated by job
- instance: Per instance
```

### Validation 5

Verify recording rules:

```bash
# Check rules are active
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].name'

# Query recorded metric
curl -s 'http://localhost:9090/api/v1/query?query=instance:node_cpu_utilization:ratio' | jq '.data.result'

# Verify in Prometheus UI
# Navigate to Status → Rules
```

---

## Exercise 6: Metrics Deep Dive

### Step 1: Explore Kubernetes Metrics

```promql
# Kubernetes API Server
apiserver_request_total
apiserver_request_duration_seconds_bucket

# kubelet
kubelet_running_pods
kubelet_running_containers

# Container metrics
container_cpu_usage_seconds_total
container_memory_usage_bytes
container_network_receive_bytes_total

# kube-state-metrics
kube_pod_info
kube_deployment_status_replicas
kube_node_status_condition
```

### Step 2: Node Metrics (node-exporter)

```promql
# CPU
node_cpu_seconds_total
rate(node_cpu_seconds_total{mode="idle"}[5m])

# Memory
node_memory_MemTotal_bytes
node_memory_MemAvailable_bytes
node_memory_Buffers_bytes
node_memory_Cached_bytes

# Disk
node_filesystem_size_bytes
node_filesystem_avail_bytes
node_disk_read_bytes_total
node_disk_written_bytes_total

# Network
node_network_receive_bytes_total
node_network_transmit_bytes_total
```

### Step 3: Useful Dashboard Queries

```promql
# Cluster CPU Usage
sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) / 
sum(machine_cpu_cores) * 100

# Cluster Memory Usage
sum(container_memory_usage_bytes{container!=""}) / 
sum(machine_memory_bytes) * 100

# Top 5 CPU-consuming pods
topk(5, sum by (namespace, pod) (
  rate(container_cpu_usage_seconds_total{container!=""}[5m])
))

# Top 5 Memory-consuming pods
topk(5, sum by (namespace, pod) (
  container_memory_usage_bytes{container!=""}
))

# Pods in CrashLoopBackOff
kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1

# Nodes not ready
kube_node_status_condition{condition="Ready", status="true"} == 0

# PVC usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100
```

### Step 4: Create Custom Metrics Query File

```yaml
# useful-queries.yaml
# Save these queries for reference

queries:
  cluster:
    cpu_usage: |
      sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) / 
      sum(machine_cpu_cores) * 100
    
    memory_usage: |
      sum(container_memory_usage_bytes{container!=""}) / 
      sum(machine_memory_bytes) * 100
    
    pod_count: |
      count(kube_pod_info)

  node:
    cpu_usage: |
      100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
    
    memory_usage: |
      100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
    
    disk_usage: |
      100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)

  application:
    request_rate: |
      sum(rate(http_requests_total[5m])) by (service)
    
    error_rate: |
      sum(rate(http_requests_total{status=~"5.."}[5m])) / 
      sum(rate(http_requests_total[5m])) * 100
    
    latency_p99: |
      histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
```

### Validation 6

Test your understanding:

```bash
# Run these queries in Prometheus UI and verify results

# 1. Get total cluster CPU cores
sum(machine_cpu_cores)

# 2. Get memory usage per namespace
sum by (namespace) (container_memory_usage_bytes{container!=""})

# 3. Find pods that restarted recently
increase(kube_pod_container_status_restarts_total[1h]) > 0
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Prometheus Not Scraping Target

```bash
# Check target status
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090/targets

# Verify ServiceMonitor labels match Prometheus selector
kubectl get prometheus -n monitoring -o yaml | grep -A5 serviceMonitorSelector

# Check ServiceMonitor
kubectl describe servicemonitor <name> -n monitoring

# Verify service endpoints
kubectl get endpoints <service-name> -n <namespace>
```

#### Issue 2: Metrics Not Appearing

```bash
# Check if target is up
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq

# Verify metrics endpoint
kubectl port-forward <pod> 8080:8080
curl localhost:8080/metrics

# Check Prometheus logs
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus
```

#### Issue 3: Recording Rules Not Working

```bash
# Check rule status
curl -s http://localhost:9090/api/v1/rules | jq

# Verify PrometheusRule is valid
kubectl get prometheusrule -n monitoring -o yaml | head -50

# Check for errors in Prometheus
kubectl logs -n monitoring prometheus-prometheus-kube-prometheus-prometheus-0 -c prometheus | grep -i error
```

#### Issue 4: High Cardinality

```promql
# Find metrics with high cardinality
topk(10, count by (__name__) ({__name__=~".+"}))

# Check label cardinality
count(http_requests_total) by (path)
# If this returns thousands of results, 'path' label has high cardinality
```

---

## Summary

In this lab, you learned:

1. **Prometheus Architecture**: Pull-based metrics collection with TSDB storage
2. **Deployment**: Installing kube-prometheus-stack with Helm
3. **PromQL**: Query language for selecting, aggregating, and analyzing metrics
4. **Service Discovery**: Automatic target discovery in Kubernetes
5. **Recording Rules**: Pre-computing expensive queries for performance
6. **Metric Types**: Counter, Gauge, Histogram, Summary

---

## Key Takeaways

```text
Prometheus Best Practices:

□ Use recording rules for dashboard queries
□ Follow naming conventions for metrics
□ Set appropriate scrape intervals (15-60s typical)
□ Configure retention based on storage capacity
□ Use labels wisely to avoid cardinality explosion
□ Monitor Prometheus itself (meta-monitoring)
□ Use ServiceMonitors for service discovery
□ Set resource limits on Prometheus pods
```

---

## What's Next?

Continue to [Lab 2: Grafana Dashboards](../lab-02-grafana/README.md) to learn:

- Creating effective dashboards
- Visualization best practices
- Dashboard provisioning
- Variables and templating
