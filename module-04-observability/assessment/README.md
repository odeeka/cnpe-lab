# Module 4: Observability & Monitoring - Assessment

## Assessment Overview

This assessment validates your observability and monitoring skills through practical exercises covering the three pillars of observability: metrics, logs, and traces. You'll configure monitoring infrastructure, create SLOs, and build unified observability solutions.

**Time Limit:** 3 hours
**Passing Score:** 70% (14 out of 20 tasks)
**Environment:** Kubernetes cluster with Prometheus Operator installed

## Prerequisites

Ensure you have:

- Completed all labs in Module 4
- Access to a Kubernetes cluster
- Prometheus Operator installed
- Grafana, Loki, and Tempo/Jaeger available
- kubectl configured

## Assessment Tasks

### Section 1: Prometheus & Metrics (5 Tasks)

#### Task 1: Create Recording Rules

Create a PrometheusRule resource with recording rules for an e-commerce service.

**Requirements:**

- Create recording rules in namespace `assessment`
- Rule group name: `ecommerce.recording.rules`
- Include the following recording rules:
  - `job:http_requests:rate5m` - Request rate per job
  - `job:http_request_errors:rate5m` - Error rate per job
  - `job:http_request_latency:p99_5m` - P99 latency per job

**Validation:**

```bash
kubectl get prometheusrule -n assessment | grep ecommerce
curl -s "http://prometheus:9090/api/v1/query?query=job:http_requests:rate5m" | jq '.data.result'
```

#### Task 2: Create Alert Rules

Create alert rules for the e-commerce service.

**Requirements:**

- Alert name: `HighCartAbandonmentRate`
- Condition: Cart abandonment rate > 30%
- For duration: 10 minutes
- Severity: warning
- Include annotations: summary, description, runbook_url

**Validation:**

```bash
curl -s "http://prometheus:9090/api/v1/rules" | jq '.data.groups[].rules[] | select(.name == "HighCartAbandonmentRate")'
```

#### Task 3: ServiceMonitor Configuration

Create a ServiceMonitor for a multi-port application.

**Requirements:**

- Monitor service `payment-service` in namespace `assessment`
- Scrape both `metrics` port (8080) and `admin-metrics` port (9090)
- Different scrape intervals: 15s for metrics, 60s for admin
- Add label `team: payments`

**Validation:**

```bash
kubectl get servicemonitor payment-service -n assessment -o yaml
```

#### Task 4: Custom Metrics Query

Write PromQL queries for the following scenarios:

**Requirements:**

1. Calculate the percentage of HTTP 500 errors over total requests for the last hour
2. Find the top 5 endpoints by request count
3. Calculate the rate of increase in memory usage per pod

**Validation:** Provide working PromQL expressions that return correct results.

#### Task 5: Histogram Analysis

Analyze request latency using histogram metrics.

**Requirements:**

1. Calculate the 50th, 90th, 95th, and 99th percentile latencies
2. Calculate the Apdex score with T=0.5s
3. Create a query that shows latency distribution by bucket

**Validation:** Provide working PromQL expressions.

### Section 2: Grafana Dashboards (4 Tasks)

#### Task 6: Create Service Dashboard

Create a Grafana dashboard for monitoring the payment service.

**Requirements:**

- Dashboard title: "Payment Service Overview"
- Include panels:
  - Request rate (time series)
  - Error rate percentage (stat panel)
  - Latency heatmap
  - Active connections gauge
- Use template variables for `namespace` and `service`
- Set appropriate thresholds

**Validation:**

```bash
kubectl get configmap payment-dashboard -n monitoring -o yaml | grep "Payment Service"
```

#### Task 7: Dashboard Variables

Enhance the dashboard with advanced variables.

**Requirements:**

- Add variable `environment` with values from label
- Add variable `instance` dependent on environment selection
- Add variable `time_range` with custom intervals
- Use regex to filter variable values

**Validation:** Dashboard loads with working variable dropdowns.

#### Task 8: Dashboard Provisioning

Set up automated dashboard provisioning.

**Requirements:**

- Create ConfigMap with dashboard JSON
- Configure Grafana provisioning to load dashboard
- Dashboard should auto-update when ConfigMap changes
- Include proper labels for Grafana sidecar

**Validation:**

```bash
kubectl get configmap -n monitoring -l grafana_dashboard=1
```

#### Task 9: Dashboard Alerts

Configure dashboard-based alerts.

**Requirements:**

- Create alert rule from a dashboard panel
- Configure contact point (webhook receiver)
- Set up notification policy
- Include silence configuration for maintenance

**Validation:** Alert fires when condition is met.

### Section 3: Logging with Loki (4 Tasks)

#### Task 10: LogQL Queries

Write LogQL queries for the following scenarios.

**Requirements:**

1. Find all error logs from namespace `production` in the last hour
2. Extract and count unique error messages
3. Calculate the rate of warnings per minute per service
4. Find logs containing JSON and extract specific fields

**Validation:** Provide working LogQL expressions.

#### Task 11: Log Pipeline Configuration

Configure Promtail with custom pipeline stages.

**Requirements:**

- Parse JSON logs
- Extract timestamp from `@timestamp` field
- Add static label `environment: production`
- Drop logs matching pattern `health-check`
- Relabel logs based on container name

**Validation:**

```bash
kubectl get configmap promtail-config -n monitoring -o yaml
```

#### Task 12: Log Aggregation Dashboard

Create a Grafana dashboard for log analysis.

**Requirements:**

- Logs panel showing error logs
- Stat panel showing log volume
- Time series showing log rate by level
- Table showing top error messages

**Validation:** Dashboard displays log data correctly.

#### Task 13: Log-Based Alerts

Create alerts based on log patterns.

**Requirements:**

- Alert on error rate exceeding threshold
- Use LogQL for alert expression
- Configure routing to appropriate team
- Include log context in notification

**Validation:** Alert configuration is correct.

### Section 4: Distributed Tracing (3 Tasks)

#### Task 14: Trace Instrumentation

Configure OpenTelemetry instrumentation.

**Requirements:**

- Deploy OpenTelemetry Collector
- Configure OTLP receiver
- Set up Tempo/Jaeger exporter
- Add resource attributes for service identification

**Validation:**

```bash
kubectl get deployment otel-collector -n tracing -o yaml
```

#### Task 15: Trace Queries

Write trace queries for investigation.

**Requirements (TraceQL/Jaeger):**

1. Find traces with duration > 5 seconds
2. Find traces with errors in specific service
3. Find traces spanning multiple services
4. Aggregate trace statistics

**Validation:** Provide working trace query expressions.

#### Task 16: Trace-to-Logs Correlation

Configure correlation between traces and logs.

**Requirements:**

- Add trace ID to application logs
- Configure Grafana data source linking
- Create dashboard with trace and log panels
- Enable drill-down from trace to logs

**Validation:** Click on trace shows related logs.

### Section 5: SLOs & Advanced Observability (4 Tasks)

#### Task 17: Define SLIs and SLOs

Create SLI and SLO definitions for a service.

**Requirements:**

- Define availability SLI (successful requests / total requests)
- Define latency SLI (requests < 200ms / total requests)
- Set SLO targets: 99.9% availability, 99% latency
- Create recording rules for SLIs

**Validation:**

```bash
curl -s "http://prometheus:9090/api/v1/query?query=sli:availability:ratio_rate5m" | jq '.data.result'
```

#### Task 18: Error Budget Tracking

Implement error budget calculation and tracking.

**Requirements:**

- Calculate error budget consumption
- Create dashboard showing budget remaining
- Set up burn rate calculations (1h, 6h, 1d windows)
- Configure alerts for budget depletion

**Validation:**

```bash
curl -s "http://prometheus:9090/api/v1/query?query=slo:error_budget:remaining_ratio" | jq '.data.result'
```

#### Task 19: Multi-Window Burn Rate Alerts

Implement Google SRE-style multi-window alerting.

**Requirements:**

- Create 14.4x burn rate alert (critical)
- Create 6x burn rate alert (warning)
- Create 1x burn rate alert (ticket)
- Use both long and short windows for each

**Validation:**

```bash
curl -s "http://prometheus:9090/api/v1/rules" | jq '.data.groups[].rules[] | select(.labels.slo_alert == "true")'
```

#### Task 20: Unified Observability Dashboard

Create a comprehensive unified dashboard.

**Requirements:**

- Single pane of glass for service health
- Include metrics, logs, and traces panels
- SLO status and error budget display
- Service dependency visualization
- Correlation links between all signals

**Validation:** Dashboard provides complete service observability.

## Submission Requirements

For each task, provide:

1. YAML manifests or configuration files
2. PromQL/LogQL/TraceQL expressions
3. Screenshots or command outputs showing validation
4. Brief explanation of your approach

## Scoring Rubric

| Task | Points | Criteria |
|------|--------|----------|
| Task 1 | 5 | Recording rules correctly defined and evaluated |
| Task 2 | 5 | Alert rules with proper conditions and annotations |
| Task 3 | 5 | ServiceMonitor scraping both endpoints correctly |
| Task 4 | 5 | Valid PromQL expressions returning expected results |
| Task 5 | 5 | Histogram quantiles and Apdex correctly calculated |
| Task 6 | 5 | Dashboard with all required panels and functionality |
| Task 7 | 5 | Variables working with proper dependencies |
| Task 8 | 5 | Dashboard auto-provisioned from ConfigMap |
| Task 9 | 5 | Alerts configured and firing correctly |
| Task 10 | 5 | Valid LogQL expressions for all scenarios |
| Task 11 | 5 | Pipeline stages processing logs correctly |
| Task 12 | 5 | Dashboard displaying log analytics |
| Task 13 | 5 | Log-based alerts configured and working |
| Task 14 | 5 | OTEL Collector receiving and exporting traces |
| Task 15 | 5 | Valid trace queries returning results |
| Task 16 | 5 | Trace-to-log correlation working |
| Task 17 | 5 | SLIs and SLOs correctly defined |
| Task 18 | 5 | Error budget calculation accurate |
| Task 19 | 5 | Multi-window alerts configured correctly |
| Task 20 | 5 | Unified dashboard with all signals correlated |

**Total: 100 points**
**Passing: 70 points (14 tasks)**

## Assessment Environment Setup

```bash
# Create assessment namespace
kubectl create namespace assessment

# Deploy sample applications
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
  namespace: assessment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: payment-service
  template:
    metadata:
      labels:
        app: payment-service
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
        - name: service
          image: quay.io/brancz/prometheus-example-app:v0.4.0
          ports:
            - containerPort: 8080
              name: metrics
            - containerPort: 9090
              name: admin-metrics
---
apiVersion: v1
kind: Service
metadata:
  name: payment-service
  namespace: assessment
spec:
  selector:
    app: payment-service
  ports:
    - name: metrics
      port: 8080
    - name: admin-metrics
      port: 9090
EOF

# Verify setup
kubectl get pods -n assessment
kubectl get svc -n assessment
```

## Tips for Success

1. **Read requirements carefully** - Each task has specific requirements
2. **Test incrementally** - Validate each component before moving on
3. **Use recording rules** - They improve query performance and readability
4. **Label consistently** - Proper labeling enables effective querying
5. **Document your work** - Clear documentation aids troubleshooting
6. **Check syntax** - YAML indentation and PromQL syntax errors are common
7. **Verify data flow** - Ensure metrics, logs, and traces are being collected
8. **Use Grafana Explore** - Test queries before adding to dashboards

## Common Mistakes to Avoid

1. Missing `for` duration in alert rules
2. Incorrect label matchers in PromQL
3. Wrong time ranges in rate() functions
4. Missing ServiceMonitor label selectors
5. Incorrect JSON escaping in ConfigMaps
6. Not considering absent data in SLO calculations
7. Hardcoding values instead of using variables
8. Missing correlation IDs in logs

Good luck!
