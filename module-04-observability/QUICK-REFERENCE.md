# Module 4: Observability & Monitoring - Quick Reference

## Prometheus & PromQL

### Data Types

| Type | Description | Example |
|------|-------------|---------|
| Counter | Monotonically increasing | `http_requests_total` |
| Gauge | Can go up or down | `node_memory_available_bytes` |
| Histogram | Observations in buckets | `http_request_duration_seconds` |
| Summary | Pre-calculated quantiles | `go_gc_duration_seconds` |

### Essential PromQL Functions

```promql
# Rate (per-second rate of increase)
rate(http_requests_total[5m])

# Increase (total increase in range)
increase(http_requests_total[1h])

# Histogram percentile
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Aggregations
sum(rate(http_requests_total[5m])) by (service)
avg(node_cpu_seconds_total) by (instance)
max(container_memory_usage_bytes) by (pod)
topk(5, sum(rate(http_requests_total[5m])) by (endpoint))

# Math
(requests_success / requests_total) * 100
rate(errors[5m]) / rate(requests[5m])

# Time functions
time() - process_start_time_seconds  # Uptime
timestamp(up)                         # Timestamp of sample

# Label manipulation
label_replace(up, "short_instance", "$1", "instance", "(.*):.+")
label_join(up, "full_name", "-", "job", "instance")
```

### Common Patterns

```promql
# Error rate percentage
sum(rate(http_requests_total{status=~"5.."}[5m])) 
/ sum(rate(http_requests_total[5m])) * 100

# Availability (uptime)
avg_over_time(up[24h])

# Memory usage percentage
container_memory_working_set_bytes / container_spec_memory_limit_bytes * 100

# Disk space remaining
node_filesystem_avail_bytes / node_filesystem_size_bytes * 100

# Saturation
rate(container_cpu_cfs_throttled_periods_total[5m]) 
/ rate(container_cpu_cfs_periods_total[5m])

# Apdex Score (T=0.5s)
(
  sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
  + sum(rate(http_request_duration_seconds_bucket{le="2.0"}[5m])) / 2
) / sum(rate(http_request_duration_seconds_count[5m]))
```

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-service
  namespace: monitoring
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: my-service
  namespaceSelector:
    matchNames:
      - default
  endpoints:
    - port: metrics
      interval: 15s
      path: /metrics
```

### PrometheusRule

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-rules
  namespace: monitoring
  labels:
    prometheus: k8s
spec:
  groups:
    - name: example
      rules:
        # Recording rule
        - record: job:http_requests:rate5m
          expr: sum(rate(http_requests_total[5m])) by (job)
        
        # Alert rule
        - alert: HighErrorRate
          expr: rate(http_errors_total[5m]) > 0.1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value }}"
```

## Grafana

### Dashboard Variables

```
# Label values
label_values(http_requests_total, service)

# Label values with filter
label_values(http_requests_total{env="$environment"}, service)

# Query result
query_result(topk(10, sum(rate(http_requests_total[5m])) by (service)))

# Custom values
dev, staging, production

# Interval
$__interval, $__rate_interval
```

### Panel Types

| Type | Use Case |
|------|----------|
| Time series | Metrics over time |
| Stat | Single value with thresholds |
| Gauge | Current value with min/max |
| Bar gauge | Comparative values |
| Table | Tabular data |
| Heatmap | Distribution over time |
| Logs | Loki log display |
| Traces | Tempo trace display |
| Node Graph | Service dependencies |

### Useful Transformations

- **Reduce**: Aggregate rows to single values
- **Group by**: Group data by field values
- **Join by field**: Merge data frames
- **Organize fields**: Rename, reorder, hide fields
- **Filter by value**: Remove rows based on conditions

## Loki & LogQL

### Stream Selectors

```logql
# Basic selector
{namespace="production", app="nginx"}

# Regex match
{namespace=~"prod.*", container!~"sidecar.*"}

# Combined
{namespace="production"} | app="my-app"
```

### Line Filters

```logql
# Contains
{app="nginx"} |= "error"

# Does not contain
{app="nginx"} != "healthcheck"

# Regex match
{app="nginx"} |~ "status=[45].."

# Case insensitive
{app="nginx"} |~ "(?i)error"
```

### Parser Stages

```logql
# JSON
{app="api"} | json

# Logfmt
{app="api"} | logfmt

# Regex extraction
{app="nginx"} | regexp `(?P<ip>\d+\.\d+\.\d+\.\d+) .* "(?P<method>\w+) (?P<path>\S+)"`

# Pattern (simplified)
{app="nginx"} | pattern `<ip> - - [<timestamp>] "<method> <path> <_>" <status>`
```

### Label Filters

```logql
# After parsing
{app="api"} | json | level="error"
{app="api"} | json | status >= 400
{app="api"} | logfmt | duration > 1s
```

### Metric Queries

```logql
# Count logs per second
count_over_time({app="nginx"}[5m])

# Rate of logs
rate({app="nginx"} |= "error" [5m])

# Bytes rate
bytes_rate({app="nginx"}[5m])

# Average from extracted value
avg_over_time({app="api"} | json | unwrap duration [5m])

# Quantile
quantile_over_time(0.99, {app="api"} | json | unwrap duration [5m])
```

## Distributed Tracing

### OpenTelemetry SDK Setup

```python
# Python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider())
trace.get_tracer_provider().add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(endpoint="http://otel-collector:4317"))
)
tracer = trace.get_tracer(__name__)
```

```go
// Go
import (
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

exporter, _ := otlptracegrpc.New(ctx, otlptracegrpc.WithEndpoint("otel-collector:4317"))
tp := trace.NewTracerProvider(trace.WithBatcher(exporter))
otel.SetTracerProvider(tp)
tracer := otel.Tracer("my-service")
```

### TraceQL Queries (Tempo)

```
# Find by service
{resource.service.name="api-gateway"}

# Find slow traces
{span.http.status_code=200} | duration > 5s

# Find errors
{status=error}

# Find by attribute
{span.http.method="POST" && span.http.target="/api/order"}

# Aggregate
{} | count() by (resource.service.name)
```

### Trace Context Propagation

```
# W3C Trace Context Headers
traceparent: 00-{trace-id}-{parent-span-id}-{flags}
tracestate: vendor1=value1,vendor2=value2

# Example
traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
```

## Alertmanager

### Configuration Structure

```yaml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/...'

route:
  receiver: 'default'
  group_by: ['alertname', 'namespace']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'

receivers:
  - name: 'default'
    slack_configs:
      - channel: '#alerts'
  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '<key>'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'namespace']
```

### Silence API

```bash
# Create silence
curl -X POST http://alertmanager:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "alertname", "value": "TestAlert", "isRegex": false}],
    "startsAt": "2024-01-01T00:00:00Z",
    "endsAt": "2024-01-01T04:00:00Z",
    "createdBy": "admin",
    "comment": "Maintenance window"
  }'

# List silences
curl http://alertmanager:9093/api/v2/silences

# Delete silence
curl -X DELETE http://alertmanager:9093/api/v2/silence/{id}
```

## SLOs & Error Budgets

### Formulas

```
# Error Budget
Error Budget = 1 - SLO Target
Example: 1 - 0.999 = 0.001 (0.1%)

# Budget in Minutes (30-day window)
Budget Minutes = Error Budget × 30 × 24 × 60
Example: 0.001 × 43200 = 43.2 minutes

# Error Budget Consumption
Consumed = (1 - Current SLI) / Error Budget
Example: (1 - 0.998) / 0.001 = 2 (200% consumed)

# Burn Rate
Burn Rate = Error Rate / Error Budget
Example: 0.002 / 0.001 = 2x burn rate
```

### Multi-Window Burn Rate Thresholds

| Severity | Burn Rate | Long Window | Short Window | Budget Consumed |
|----------|-----------|-------------|--------------|-----------------|
| Critical | 14.4x | 1h | 5m | 2% in 1h |
| High | 6x | 6h | 30m | 5% in 6h |
| Warning | 1x | 3d | 6h | 10% in 3d |

### SLI Recording Rules

```yaml
groups:
  - name: sli.rules
    rules:
      # Availability
      - record: sli:availability:ratio_rate5m
        expr: |
          sum(rate(http_requests_total{status!~"5.."}[5m])) by (service)
          / sum(rate(http_requests_total[5m])) by (service)
      
      # Latency
      - record: sli:latency:ratio_rate5m
        expr: |
          sum(rate(http_request_duration_seconds_bucket{le="0.2"}[5m])) by (service)
          / sum(rate(http_request_duration_seconds_count[5m])) by (service)
```

## Kubernetes Metrics

### Key Metrics

```promql
# Container CPU usage
rate(container_cpu_usage_seconds_total[5m])

# Container memory
container_memory_working_set_bytes

# Pod restarts
kube_pod_container_status_restarts_total

# Node capacity
kube_node_status_capacity

# Deployment status
kube_deployment_status_replicas_available

# PVC usage
kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes
```

### Health Indicators

```promql
# Node not ready
kube_node_status_condition{condition="Ready", status="true"} == 0

# Pod not running
kube_pod_status_phase{phase!~"Running|Succeeded"} == 1

# Deployment not available
kube_deployment_status_replicas_available < kube_deployment_spec_replicas

# HPA at max
kube_horizontalpodautoscaler_status_current_replicas 
== kube_horizontalpodautoscaler_spec_max_replicas
```

## Quick Commands

```bash
# Port-forward Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Port-forward Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Port-forward Alertmanager
kubectl port-forward -n monitoring svc/alertmanager 9093:9093

# Check Prometheus targets
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Query Prometheus
curl -s 'http://localhost:9090/api/v1/query?query=up' | jq '.data.result'

# Check firing alerts
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | select(.status.state=="active")'

# Query Loki
curl -s 'http://localhost:3100/loki/api/v1/query?query={app="nginx"}' | jq

# Check Tempo status
curl -s http://localhost:3200/ready
```

## Troubleshooting Checklist

### Metrics Not Appearing

- [ ] ServiceMonitor exists with correct labels
- [ ] Service has matching labels
- [ ] Pod has prometheus.io annotations
- [ ] Prometheus can reach target (network policies)
- [ ] Metrics endpoint returns data

### Alerts Not Firing

- [ ] Rule is loaded (check /api/v1/rules)
- [ ] Expression returns data
- [ ] `for` duration has passed
- [ ] Alert is not inhibited
- [ ] Alert is not silenced

### Logs Not Appearing in Loki

- [ ] Promtail is running
- [ ] Promtail can access pod logs
- [ ] Pipeline stages are correct
- [ ] Labels are within cardinality limits
- [ ] Loki is receiving data

### Traces Not Visible

- [ ] Application is instrumented
- [ ] OTEL Collector is running
- [ ] Exporter is configured correctly
- [ ] Traces are being sampled (check sampling rate)
- [ ] Storage backend is accessible
