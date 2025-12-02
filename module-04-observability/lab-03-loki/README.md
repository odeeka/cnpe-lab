# Lab 3: Logging with Loki

## Introduction

Loki is a horizontally scalable, highly available log aggregation system inspired by Prometheus. Unlike other logging systems, Loki indexes only the metadata (labels) rather than the log content, making it cost-effective and efficient.

## Learning Objectives

After completing this lab, you will be able to:

- Understand Loki architecture and design principles
- Deploy Loki and Promtail using Helm
- Write LogQL queries to search and analyze logs
- Create Grafana dashboards with log panels
- Correlate logs with metrics
- Implement log-based alerting

## Prerequisites

- Completed Lab 1: Prometheus Fundamentals
- Completed Lab 2: Grafana Dashboards
- Running Kubernetes cluster
- Helm 3.x installed

## Duration

Estimated time: 90-120 minutes

---

## Exercise 1: Understanding Loki Architecture

### Step 1: Loki vs Traditional Logging

```text
┌─────────────────────────────────────────────────────────────────┐
│           TRADITIONAL LOGGING vs LOKI                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  TRADITIONAL (Elasticsearch)          LOKI                      │
│  ───────────────────────────          ────                      │
│                                                                  │
│  ┌─────────────────────┐         ┌─────────────────────┐       │
│  │ Full-text indexing  │         │ Label-based indexing │       │
│  │ of log content      │         │ only (like Prometheus)│       │
│  └─────────────────────┘         └─────────────────────┘       │
│           │                               │                     │
│           ▼                               ▼                     │
│  • High storage cost              • Low storage cost            │
│  • Complex operations             • Simple operations           │
│  • Fast arbitrary search          • Fast label queries          │
│  • Resource intensive             • Resource efficient          │
│                                                                  │
│  Use case: Complex log analytics  Use case: Operational logs    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2: Loki Components

```text
┌─────────────────────────────────────────────────────────────────┐
│                     LOKI ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                                               │
│  │   Promtail   │ ──┐                                           │
│  │  (DaemonSet) │   │                                           │
│  └──────────────┘   │                                           │
│                     │    ┌────────────────────────────────┐     │
│  ┌──────────────┐   │    │          LOKI                  │     │
│  │   Promtail   │ ──┼───▶│  ┌──────────┐  ┌───────────┐  │     │
│  │  (DaemonSet) │   │    │  │Distributor│  │  Ingester │  │     │
│  └──────────────┘   │    │  └──────────┘  └───────────┘  │     │
│                     │    │         │              │       │     │
│  ┌──────────────┐   │    │         ▼              ▼       │     │
│  │   Promtail   │ ──┘    │  ┌──────────────────────────┐ │     │
│  │  (DaemonSet) │        │  │      Chunk Storage       │ │     │
│  └──────────────┘        │  │  (S3 / GCS / Filesystem) │ │     │
│                          │  └──────────────────────────┘ │     │
│                          │         │              │       │     │
│  ┌──────────────┐        │         ▼              ▼       │     │
│  │   Grafana    │◀───────│  ┌──────────┐  ┌───────────┐  │     │
│  │              │        │  │  Querier │  │Index Store│  │     │
│  └──────────────┘        │  └──────────┘  └───────────┘  │     │
│                          └────────────────────────────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘

Components:
- Distributor: Receives and validates logs, forwards to ingesters
- Ingester: Builds compressed chunks and flushes to storage
- Querier: Handles queries, reads from storage and ingesters
- Index Store: Stores chunk metadata and labels
- Chunk Storage: Stores compressed log data
```

### Step 3: Key Concepts

```text
Labels:
- Same concept as Prometheus
- Key-value pairs that identify log streams
- Avoid high cardinality labels

Streams:
- Unique combination of labels
- All logs with same labels = one stream
- Each stream is stored and queried together

Chunks:
- Compressed blocks of logs
- Typically 1-2 MB each
- Flushed based on size/time
```

### Validation 1

Understanding check:

```bash
# Answer these questions:
# 1. Why does Loki only index labels, not log content?
# 2. What is a log stream in Loki?
# 3. When should you use Loki vs Elasticsearch?
```

---

## Exercise 2: Deploy Loki Stack

### Step 1: Add Grafana Helm Repository

```bash
# Add Grafana repo (if not already added)
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### Step 2: Create Loki Values File

```yaml
# loki-values.yaml
loki:
  auth_enabled: false
  
  commonConfig:
    replication_factor: 1
  
  storage:
    type: filesystem
  
  schemaConfig:
    configs:
      - from: 2024-01-01
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: index_
          period: 24h

  limits_config:
    ingestion_rate_mb: 10
    ingestion_burst_size_mb: 20
    max_streams_per_user: 10000
    max_line_size: 256kb

  ruler:
    storage:
      type: local
      local:
        directory: /var/loki/rules
    rule_path: /tmp/loki/rules
    alertmanager_url: http://prometheus-kube-prometheus-alertmanager:9093
    ring:
      kvstore:
        store: inmemory
    enable_api: true

singleBinary:
  replicas: 1
  resources:
    limits:
      cpu: 1
      memory: 1Gi
    requests:
      cpu: 100m
      memory: 256Mi
  persistence:
    enabled: true
    size: 10Gi

gateway:
  enabled: true
  replicas: 1

monitoring:
  selfMonitoring:
    enabled: false
  lokiCanary:
    enabled: false

test:
  enabled: false
```

### Step 3: Install Loki

```bash
# Install Loki
helm install loki grafana/loki \
  --namespace monitoring \
  --values loki-values.yaml \
  --wait

# Verify installation
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Expected output:
# NAME                            READY   STATUS    RESTARTS
# loki-0                          1/1     Running   0
# loki-gateway-xxx                1/1     Running   0
```

### Step 4: Create Promtail Values File

```yaml
# promtail-values.yaml
config:
  clients:
    - url: http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
      tenant_id: 1

  snippets:
    pipelineStages:
      - cri: {}
      - multiline:
          firstline: '^\d{4}-\d{2}-\d{2}'
          max_wait_time: 3s
      - labeldrop:
          - filename
          - stream

  positions:
    filename: /run/promtail/positions.yaml

resources:
  limits:
    cpu: 200m
    memory: 128Mi
  requests:
    cpu: 50m
    memory: 64Mi

tolerations:
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule

serviceMonitor:
  enabled: true
  labels:
    release: prometheus
```

### Step 5: Install Promtail

```bash
# Install Promtail
helm install promtail grafana/promtail \
  --namespace monitoring \
  --values promtail-values.yaml \
  --wait

# Verify installation
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail

# Promtail runs as a DaemonSet on each node
kubectl get daemonset -n monitoring promtail
```

### Step 6: Configure Loki Data Source in Grafana

```bash
# Access Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Add Loki data source via API
curl -X POST -H "Content-Type: application/json" \
  -u admin:admin123 \
  http://localhost:3000/api/datasources \
  -d '{
    "name": "Loki",
    "type": "loki",
    "url": "http://loki-gateway.monitoring.svc.cluster.local",
    "access": "proxy",
    "isDefault": false
  }'
```

Or add manually in Grafana:

1. Configuration → Data Sources → Add data source
2. Select Loki
3. URL: `http://loki-gateway.monitoring.svc.cluster.local`
4. Click Save & Test

### Validation 2

Verify Loki installation:

```bash
# Check Loki is receiving logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=20

# Check Promtail status
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=20

# Query Loki API
kubectl port-forward -n monitoring svc/loki-gateway 3100:80 &
curl -s http://localhost:3100/loki/api/v1/labels | jq

# Should return list of labels
```

---

## Exercise 3: LogQL Fundamentals

### Step 1: Access Grafana Explore

1. Open Grafana at http://localhost:3000
2. Click **Explore** in sidebar
3. Select **Loki** data source

### Step 2: Basic Log Queries

```logql
# All logs from a namespace
{namespace="monitoring"}

# Logs from specific pod
{namespace="default", pod="myapp-xxx"}

# Logs from specific container
{container="nginx"}

# Multiple label matching
{namespace="default", app="frontend"}

# Regex matching
{namespace=~"kube-.*"}

# Exclude namespace
{namespace!="kube-system"}
```

### Step 3: Line Filters

```logql
# Contains string
{namespace="default"} |= "error"

# Does not contain
{namespace="default"} != "debug"

# Regex match
{namespace="default"} |~ "error|warn"

# Regex not match
{namespace="default"} !~ "health|ready"

# Case insensitive
{namespace="default"} |~ "(?i)error"

# Multiple filters (AND)
{namespace="default"} |= "error" != "timeout"
```

### Step 4: Parser Expressions

```logql
# JSON parser
{app="myapp"} | json

# Extract specific JSON fields
{app="myapp"} | json | level="error"

# Logfmt parser
{app="myapp"} | logfmt

# Pattern parser
{app="nginx"} | pattern `<ip> - - [<_>] "<method> <path> <_>" <status> <size>`

# Regex parser
{app="myapp"} | regexp `(?P<timestamp>\d{4}-\d{2}-\d{2}) (?P<level>\w+) (?P<message>.*)`

# Line format (rewrite log line)
{app="myapp"} | json | line_format "{{.level}}: {{.message}}"
```

### Step 5: Label Filters (Post-parsing)

```logql
# After JSON parsing, filter by extracted field
{app="myapp"} | json | level="error"

# Numeric comparison
{app="myapp"} | json | status >= 500

# Multiple conditions
{app="myapp"} | json | level="error" | duration > 1s
```

### Step 6: Metric Queries

```logql
# Count logs per second
count_over_time({namespace="default"}[5m])

# Rate of logs
rate({namespace="default"}[5m])

# Sum by label
sum by (pod) (count_over_time({namespace="default"}[5m]))

# Average value from log field
avg_over_time({app="myapp"} | json | unwrap duration [5m])

# Bytes processed
bytes_over_time({namespace="default"}[1h])

# Top 5 pods by log volume
topk(5, sum by (pod) (bytes_over_time({namespace="default"}[1h])))
```

### Step 7: Aggregation Examples

```logql
# Error count by pod
sum by (pod) (
  count_over_time({namespace="default"} |= "error" [5m])
)

# Error rate as percentage
sum(count_over_time({app="myapp"} |= "error" [5m])) /
sum(count_over_time({app="myapp"} [5m])) * 100

# 99th percentile response time from logs
quantile_over_time(0.99,
  {app="myapp"} | json | unwrap response_time [5m]
)

# Request rate from access logs
sum(rate(
  {app="nginx"} | pattern `<_> - - <_> "<method> <_> <_>" <status> <_>` [5m]
)) by (method, status)
```

### Validation 3

Practice LogQL in Grafana Explore:

```bash
# Try these queries:

# 1. Find all error logs in the cluster
{namespace=~".+"} |= "error"

# 2. Count logs per namespace in last hour
sum by (namespace) (count_over_time({namespace=~".+"}[1h]))

# 3. Find specific error patterns
{namespace="kube-system"} |~ "failed|error|timeout"
```

---

## Exercise 4: Advanced Promtail Configuration

### Step 1: Understanding Pipeline Stages

```text
Pipeline Stages Flow:
┌────────────┐   ┌────────────┐   ┌────────────┐   ┌────────────┐
│   Source   │──▶│   Parse    │──▶│  Transform │──▶│   Output   │
│            │   │            │   │            │   │            │
│ - journal  │   │ - json     │   │ - labels   │   │ - match    │
│ - file     │   │ - regex    │   │ - template │   │ - drop     │
│ - syslog   │   │ - logfmt   │   │ - replace  │   │            │
└────────────┘   └────────────┘   └────────────┘   └────────────┘
```

### Step 2: Custom Pipeline Configuration

```yaml
# promtail-advanced.yaml
config:
  clients:
    - url: http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push

  snippets:
    pipelineStages:
      # Parse container runtime logs
      - cri: {}
      
      # Handle multiline logs (e.g., stack traces)
      - multiline:
          firstline: '^\d{4}-\d{2}-\d{2}|^[A-Z][a-z]{2} \d{2}'
          max_wait_time: 3s
          max_lines: 128
      
      # Parse JSON logs
      - json:
          expressions:
            level: level
            message: msg
            timestamp: ts
            trace_id: trace_id
      
      # Add labels from parsed fields
      - labels:
          level:
          trace_id:
      
      # Only keep error and warn levels for certain apps
      - match:
          selector: '{app="verbose-app"}'
          stages:
            - drop:
                expression: ".*"
                drop_counter_reason: "debug_logs"
              source: level
              value: "debug"
      
      # Rewrite log line
      - output:
          source: message

  scrapeConfigs:
    # Kubernetes pods
    - job_name: kubernetes-pods
      kubernetes_sd_configs:
        - role: pod
      relabel_configs:
        - source_labels: [__meta_kubernetes_pod_node_name]
          target_label: node
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container
        - source_labels: [__meta_kubernetes_pod_label_app]
          target_label: app
      pipeline_stages:
        - cri: {}
```

### Step 3: Add Labels from Pod Metadata

```yaml
# Additional relabel configurations
relabel_configs:
  # Add common labels
  - source_labels: [__meta_kubernetes_namespace]
    target_label: namespace
  - source_labels: [__meta_kubernetes_pod_name]
    target_label: pod
  - source_labels: [__meta_kubernetes_pod_container_name]
    target_label: container
  
  # Add app label from pod labels
  - source_labels: [__meta_kubernetes_pod_label_app]
    target_label: app
  - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
    target_label: app
    
  # Add environment label
  - source_labels: [__meta_kubernetes_namespace]
    regex: "(prod|staging|dev)-.+"
    target_label: environment
    replacement: "${1}"
```

### Step 4: Structured Logging Extraction

```yaml
# For structured JSON logs
pipeline_stages:
  - json:
      expressions:
        level: level
        message: message
        user_id: context.user_id
        request_id: context.request_id
        duration_ms: duration_ms
  
  - labels:
      level:
      user_id:
      request_id:
  
  - metrics:
      request_duration:
        type: Histogram
        description: "Request duration in ms"
        source: duration_ms
        config:
          buckets: [10, 50, 100, 250, 500, 1000, 2500, 5000]
```

### Step 5: Drop Unwanted Logs

```yaml
pipeline_stages:
  # Drop health check logs
  - drop:
      expression: '.*health.*|.*ready.*|.*live.*'
      drop_counter_reason: health_check
  
  # Drop specific log levels
  - match:
      selector: '{namespace="production"}'
      stages:
        - drop:
            source: level
            value: debug
            drop_counter_reason: debug_logs
```

### Validation 4

Apply and verify advanced configuration:

```bash
# Apply updated Promtail config
helm upgrade promtail grafana/promtail \
  --namespace monitoring \
  --values promtail-advanced.yaml

# Check Promtail logs for pipeline processing
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50

# Verify new labels in Loki
curl -s http://localhost:3100/loki/api/v1/labels | jq
```

---

## Exercise 5: Grafana Log Panels

### Step 1: Create Log Panel

1. Create new dashboard or edit existing
2. Add new panel
3. Select **Logs** visualization

Configure query:

```logql
{namespace="monitoring"} |= ""
```

### Step 2: Log Panel Options

```yaml
Panel Options:
  - Show time: true
  - Show unique labels: true
  - Show common labels: false
  - Wrap lines: true
  - Prettify JSON: true
  - Enable log details: true
  - Order: Newest first
  - Deduplication: none | exact | numbers | signature
```

### Step 3: Create Dashboard with Logs and Metrics

```text
┌─────────────────────────────────────────────────────────────────┐
│                Application Dashboard                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────┐  ┌─────────────────────────┐  │
│  │     Request Rate            │  │     Error Rate          │  │
│  │     [Time Series]           │  │     [Time Series]       │  │
│  └─────────────────────────────┘  └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  Error Logs                              │   │
│  │                  [Log Panel]                             │   │
│  │  2024-01-15 10:30:00  ERROR  Connection timeout          │   │
│  │  2024-01-15 10:30:01  ERROR  Database unavailable        │   │
│  │  2024-01-15 10:30:02  ERROR  Retry failed               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  Log Volume                              │   │
│  │                  [Time Series]                           │   │
│  │  Query: sum(count_over_time({app="$app"}[$__interval])) │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 4: Dashboard JSON for Logs

```json
{
  "panels": [
    {
      "title": "Application Logs",
      "type": "logs",
      "datasource": {
        "type": "loki",
        "uid": "loki"
      },
      "targets": [
        {
          "expr": "{namespace=\"$namespace\", app=\"$app\"} |= \"$search\"",
          "refId": "A"
        }
      ],
      "options": {
        "showTime": true,
        "showLabels": false,
        "showCommonLabels": false,
        "wrapLogMessage": true,
        "prettifyLogMessage": true,
        "enableLogDetails": true,
        "sortOrder": "Descending",
        "dedupStrategy": "none"
      },
      "gridPos": {
        "h": 12,
        "w": 24,
        "x": 0,
        "y": 0
      }
    },
    {
      "title": "Log Volume",
      "type": "timeseries",
      "datasource": {
        "type": "loki",
        "uid": "loki"
      },
      "targets": [
        {
          "expr": "sum by (level) (count_over_time({namespace=\"$namespace\", app=\"$app\"}[$__interval]))",
          "legendFormat": "{{level}}",
          "refId": "A"
        }
      ],
      "gridPos": {
        "h": 8,
        "w": 24,
        "x": 0,
        "y": 12
      }
    }
  ]
}
```

### Step 5: Log Context and Drill-down

Enable drill-down from metrics to logs:

```yaml
# In metric panel, add data link
Data links:
  - Title: View Logs
    URL: /explore?orgId=1&left={"queries":[{"expr":"{namespace=\"${__field.labels.namespace}\"}","refId":"A"}],"datasource":"Loki"}
    Target blank: true
```

### Validation 5

Verify log dashboard:

```bash
# Open dashboard
# Verify log panel shows data
# Test filtering with variables
# Click on log entry to see details
# Test drill-down links
```

---

## Exercise 6: Log-Metric Correlation

### Step 1: Derived Metrics from Logs

Configure Promtail to extract metrics:

```yaml
# In Promtail pipeline
pipeline_stages:
  - json:
      expressions:
        status: status
        duration: duration
        method: method
        path: path
  
  - metrics:
      http_requests_total:
        type: Counter
        description: "Total HTTP requests"
        match_all: true
        config:
          action: inc
      
      http_request_duration_seconds:
        type: Histogram
        description: "HTTP request duration"
        source: duration
        config:
          buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10]
```

### Step 2: Recording Rules for Logs

```yaml
# loki-rules.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-rules
  namespace: monitoring
data:
  rules.yaml: |
    groups:
      - name: log-metrics
        interval: 1m
        rules:
          - record: log:error_rate:1m
            expr: |
              sum(count_over_time({namespace="default"} |= "error" [1m]))
              /
              sum(count_over_time({namespace="default"} [1m]))
          
          - record: log:volume_bytes:5m
            expr: |
              sum by (namespace) (bytes_over_time({namespace=~".+"} [5m]))
```

### Step 3: Correlate with Trace IDs

```logql
# Find logs for specific trace
{app="myapp"} | json | trace_id="abc123def456"

# Find all services involved in a trace
{trace_id="abc123def456"}

# Find errors in a trace
{trace_id="abc123def456"} |= "error"
```

### Step 4: Unified Dashboard

Create a dashboard that shows:

1. Request rate (Prometheus)
2. Error logs (Loki)
3. Traces (Tempo/Jaeger)

```text
┌─────────────────────────────────────────────────────────────────┐
│                 Unified Observability Dashboard                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Request Rate (Prometheus)                    │  │
│  │  sum(rate(http_requests_total[5m])) by (service)         │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Error Logs (Loki)                            │  │
│  │  {namespace="$namespace"} |= "error"                      │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  Click on log entry with trace_id → Link to trace view          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Validation 6

Test correlation:

```bash
# Generate some logs with errors
kubectl run test-logger --image=busybox --restart=Never -- \
  sh -c 'while true; do echo "{\"level\":\"error\",\"msg\":\"test error\",\"trace_id\":\"abc123\"}"; sleep 5; done'

# Query in Loki
# {pod="test-logger"} | json | level="error"

# Cleanup
kubectl delete pod test-logger
```

---

## Exercise 7: Log Alerting

### Step 1: Configure Loki Ruler

Loki can evaluate LogQL queries and send alerts:

```yaml
# loki-ruler-values.yaml
loki:
  ruler:
    enabled: true
    alertmanager_url: http://prometheus-kube-prometheus-alertmanager:9093
    ring:
      kvstore:
        store: inmemory
    rule_path: /tmp/loki/rules
    storage:
      type: local
      local:
        directory: /var/loki/rules
```

### Step 2: Create Log Alert Rules

```yaml
# loki-alerts.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-alerting-rules
  namespace: monitoring
  labels:
    loki_rule: "true"
data:
  alerts.yaml: |
    groups:
      - name: log-alerts
        rules:
          - alert: HighErrorRate
            expr: |
              sum(rate({namespace="production"} |= "error" [5m])) > 10
            for: 5m
            labels:
              severity: warning
            annotations:
              summary: High error rate in logs
              description: "Error rate is {{ $value }} errors per second"
          
          - alert: CriticalLogPattern
            expr: |
              count_over_time({namespace="production"} |~ "OutOfMemory|OOMKilled|panic" [5m]) > 0
            for: 1m
            labels:
              severity: critical
            annotations:
              summary: Critical error pattern detected
              description: "Found critical error pattern in production logs"
          
          - alert: NoLogsReceived
            expr: |
              sum(count_over_time({namespace="production"}[5m])) == 0
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: No logs received from production
              description: "No logs received from production namespace for 10 minutes"
```

### Step 3: Apply Alert Rules

```bash
# Apply the ConfigMap
kubectl apply -f loki-alerts.yaml

# Verify rules are loaded
kubectl exec -n monitoring loki-0 -- cat /var/loki/rules/fake/alerts.yaml
```

### Step 4: Test Alerts

```bash
# Generate error logs to trigger alert
kubectl run error-generator --image=busybox --restart=Never -n production -- \
  sh -c 'for i in $(seq 1 100); do echo "ERROR: Test error $i"; sleep 0.1; done'

# Check alert in Alertmanager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093 &
curl http://localhost:9093/api/v2/alerts | jq

# Cleanup
kubectl delete pod error-generator -n production
```

### Validation 7

Verify log alerting:

```bash
# Check Loki ruler status
kubectl exec -n monitoring loki-0 -- wget -qO- http://localhost:3100/loki/api/v1/rules

# Verify alerts are firing
curl http://localhost:9093/api/v2/alerts | jq '.[].labels.alertname'
```

---

## Troubleshooting

### Common Issues

#### Issue 1: No Logs in Loki

```bash
# Check Promtail is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail

# Check Promtail targets
kubectl port-forward -n monitoring <promtail-pod> 3101:3101
curl http://localhost:3101/targets

# Check Promtail logs
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50

# Verify Loki is receiving logs
kubectl logs -n monitoring -l app.kubernetes.io/name=loki --tail=50
```

#### Issue 2: High Cardinality

```bash
# Check stream count
curl -s http://localhost:3100/loki/api/v1/query?query=count(count%20by%20(__name__)(%7B__name__%3D~%22.%2B%22%7D)) | jq

# If too high, review labels
# Avoid labels with high cardinality like:
# - request_id
# - user_id
# - session_id
# - trace_id (unless needed for correlation)
```

#### Issue 3: Queries Timeout

```text
Solutions:
1. Reduce time range
2. Add more specific label selectors
3. Use regexp last (after label selectors)
4. Increase query timeout in Loki config
5. Use recording rules for frequent queries
```

#### Issue 4: Disk Full

```bash
# Check Loki storage
kubectl exec -n monitoring loki-0 -- df -h /var/loki

# Configure retention in Loki
retention_enabled: true
retention_period: 168h  # 7 days

# Or use compaction
compactor:
  working_directory: /var/loki/compactor
  retention_enabled: true
  retention_delete_delay: 2h
```

---

## Summary

In this lab, you learned:

1. **Loki Architecture**: Label-based indexing for efficient log storage
2. **Deployment**: Installing Loki and Promtail with Helm
3. **LogQL**: Query language for searching and analyzing logs
4. **Promtail Pipelines**: Parsing and transforming logs
5. **Grafana Integration**: Creating dashboards with log panels
6. **Log Alerting**: Setting up alerts based on log patterns

---

## What's Next?

Continue to [Lab 4: Distributed Tracing](../lab-04-tracing/README.md) to learn:

- OpenTelemetry fundamentals
- Deploying Jaeger for trace collection
- Instrumenting applications for tracing
- Analyzing traces to debug issues
