# Lab 6: Advanced Observability Practices

## Introduction

This lab covers advanced observability concepts including Service Level Objectives (SLOs), error budgets, observability-driven development, and correlating signals across metrics, logs, and traces. These practices transform raw telemetry data into actionable insights for reliability engineering.

## Prerequisites

- Completed Labs 1-5 of this module
- Understanding of golden signals (latency, traffic, errors, saturation)
- Familiarity with Prometheus, Grafana, Loki, and tracing
- Working alerting setup

## Learning Objectives

By the end of this lab, you will be able to:

- Define and implement Service Level Indicators (SLIs)
- Create Service Level Objectives (SLOs) with error budgets
- Implement multi-window burn rate alerting
- Correlate metrics, logs, and traces for incident investigation
- Build unified observability dashboards
- Apply observability-driven development practices
- Implement chaos engineering for observability validation

## Service Level Objectives (SLOs)

### The SLO Framework

```
┌─────────────────────────────────────────────────────────────────┐
│                         SLO Framework                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SLI (Service Level Indicator)                                   │
│  └── Quantitative measure of service behavior                    │
│      Example: Proportion of requests < 200ms                     │
│                                                                  │
│  SLO (Service Level Objective)                                   │
│  └── Target value for an SLI over a time window                  │
│      Example: 99.9% of requests < 200ms over 30 days             │
│                                                                  │
│  Error Budget                                                    │
│  └── 100% - SLO = Acceptable unreliability                       │
│      Example: 0.1% = ~43 minutes/month of allowed downtime       │
│                                                                  │
│  SLA (Service Level Agreement)                                   │
│  └── Contractual commitment with consequences                    │
│      Example: 99.9% availability or service credits              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Defining SLIs

```yaml
# SLI recording rules for common patterns
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sli-recording-rules
  namespace: monitoring
spec:
  groups:
    - name: sli.recording.rules
      interval: 30s
      rules:
        # Availability SLI - ratio of successful requests
        - record: sli:availability:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)
        
        # Latency SLI - ratio of requests under threshold
        - record: sli:latency:ratio_rate5m
          expr: |
            sum(rate(http_request_duration_seconds_bucket{le="0.2"}[5m])) by (service)
            /
            sum(rate(http_request_duration_seconds_count[5m])) by (service)
        
        # Throughput SLI - requests per second
        - record: sli:throughput:rate5m
          expr: |
            sum(rate(http_requests_total[5m])) by (service)
        
        # Error rate SLI (inverse of availability)
        - record: sli:error_rate:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)

    - name: sli.multi-window.rules
      # Multiple time windows for burn rate calculation
      rules:
        # 5-minute windows
        - record: sli:availability:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)
        
        # 30-minute windows
        - record: sli:availability:ratio_rate30m
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[30m])) by (service)
            /
            sum(rate(http_requests_total[30m])) by (service)
        
        # 1-hour windows
        - record: sli:availability:ratio_rate1h
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[1h])) by (service)
            /
            sum(rate(http_requests_total[1h])) by (service)
        
        # 6-hour windows
        - record: sli:availability:ratio_rate6h
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[6h])) by (service)
            /
            sum(rate(http_requests_total[6h])) by (service)
        
        # 1-day windows
        - record: sli:availability:ratio_rate1d
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[1d])) by (service)
            /
            sum(rate(http_requests_total[1d])) by (service)
        
        # 3-day windows
        - record: sli:availability:ratio_rate3d
          expr: |
            sum(rate(http_requests_total{status!~"5.."}[3d])) by (service)
            /
            sum(rate(http_requests_total[3d])) by (service)
```

### SLO Configuration

```yaml
# SLO definitions using recording rules
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-definitions
  namespace: monitoring
spec:
  groups:
    - name: slo.targets
      rules:
        # SLO target definitions (stored as metrics for flexibility)
        - record: slo:availability:target
          expr: vector(0.999)  # 99.9% availability
          labels:
            service: api-gateway
            slo_name: availability
        
        - record: slo:availability:target
          expr: vector(0.995)  # 99.5% availability
          labels:
            service: batch-processor
            slo_name: availability
        
        - record: slo:latency:target
          expr: vector(0.99)  # 99% of requests < threshold
          labels:
            service: api-gateway
            slo_name: latency_p99
        
        # Error budget remaining
        - record: slo:error_budget:remaining_ratio
          expr: |
            1 - (
              (1 - sli:availability:ratio_rate30d)
              /
              (1 - slo:availability:target)
            )
          labels:
            window: "30d"

    - name: slo.error_budget
      rules:
        # Error budget consumption over different windows
        - record: slo:error_budget:consumed_ratio_1d
          expr: |
            (1 - sli:availability:ratio_rate1d)
            /
            (1 - slo:availability:target)
        
        - record: slo:error_budget:consumed_ratio_7d
          expr: |
            (1 - sli:availability:ratio_rate7d)
            /
            (1 - slo:availability:target)
        
        - record: slo:error_budget:consumed_ratio_30d
          expr: |
            (1 - sli:availability:ratio_rate30d)
            /
            (1 - slo:availability:target)
        
        # Minutes of budget remaining
        - record: slo:error_budget:remaining_minutes
          expr: |
            (
              slo:error_budget:remaining_ratio
              * (1 - slo:availability:target)
              * 30 * 24 * 60  # 30 days in minutes
            )
```

### Multi-Window Burn Rate Alerts

```yaml
# Google SRE multi-window burn rate alerting
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-burn-rate-alerts
  namespace: monitoring
spec:
  groups:
    - name: slo.alerts.availability
      rules:
        # Fast burn - 2% budget in 1 hour (14.4x burn rate)
        # Alerts within 2 minutes, consumes 2% budget before alert
        - alert: SLOBurnRateCritical
          expr: |
            (
              sli:availability:ratio_rate1h < (1 - 14.4 * (1 - slo:availability:target))
              and
              sli:availability:ratio_rate5m < (1 - 14.4 * (1 - slo:availability:target))
            )
          for: 2m
          labels:
            severity: critical
            slo_alert: "true"
            burn_rate: "14.4x"
          annotations:
            summary: "Critical SLO burn rate for {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} is burning error budget at 14.4x rate.
              At this rate, the 30-day budget will be exhausted in 2 days.
              
              Current 1h availability: {{ $value | humanizePercentage }}
              Target: {{ printf "slo:availability:target{service='%s'}" $labels.service }}
            runbook_url: "https://runbooks.example.com/slo-burn-critical"
        
        # Fast burn - 5% budget in 6 hours (6x burn rate)
        # Alerts within 5 minutes, consumes 5% budget before alert
        - alert: SLOBurnRateHigh
          expr: |
            (
              sli:availability:ratio_rate6h < (1 - 6 * (1 - slo:availability:target))
              and
              sli:availability:ratio_rate30m < (1 - 6 * (1 - slo:availability:target))
            )
          for: 5m
          labels:
            severity: warning
            slo_alert: "true"
            burn_rate: "6x"
          annotations:
            summary: "High SLO burn rate for {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} is burning error budget at 6x rate.
              At this rate, the 30-day budget will be exhausted in 5 days.
        
        # Slow burn - 10% budget in 3 days (1x burn rate)
        # Alerts within 1 hour, consumes 10% budget before alert
        - alert: SLOBurnRateSlow
          expr: |
            (
              sli:availability:ratio_rate3d < (1 - 1 * (1 - slo:availability:target))
              and
              sli:availability:ratio_rate6h < (1 - 1 * (1 - slo:availability:target))
            )
          for: 1h
          labels:
            severity: warning
            slo_alert: "true"
            burn_rate: "1x"
          annotations:
            summary: "Slow SLO burn for {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} is slowly consuming error budget.
              Investigation recommended to prevent budget exhaustion.

    - name: slo.alerts.latency
      rules:
        - alert: LatencySLOBurnRateCritical
          expr: |
            (
              sli:latency:ratio_rate1h < (1 - 14.4 * (1 - slo:latency:target))
              and
              sli:latency:ratio_rate5m < (1 - 14.4 * (1 - slo:latency:target))
            )
          for: 2m
          labels:
            severity: critical
            slo_alert: "true"
          annotations:
            summary: "Critical latency SLO burn for {{ $labels.service }}"
            description: |
              Latency SLO is being violated at a critical rate.
              Only {{ $value | humanizePercentage }} of requests are under threshold.
```

## Correlating Signals

### Unified Observability Dashboard

```yaml
# Grafana dashboard combining all three pillars
apiVersion: v1
kind: ConfigMap
metadata:
  name: unified-observability-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  unified-observability.json: |
    {
      "title": "Unified Service Observability",
      "uid": "unified-observability",
      "tags": ["slo", "unified", "three-pillars"],
      "templating": {
        "list": [
          {
            "name": "service",
            "type": "query",
            "query": "label_values(http_requests_total, service)",
            "refresh": 2
          },
          {
            "name": "namespace",
            "type": "query",
            "query": "label_values(http_requests_total{service=\"$service\"}, namespace)",
            "refresh": 2
          }
        ]
      },
      "panels": [
        {
          "title": "SLO Status",
          "type": "stat",
          "gridPos": {"x": 0, "y": 0, "w": 6, "h": 4},
          "targets": [
            {
              "expr": "sli:availability:ratio_rate30d{service=\"$service\"}",
              "legendFormat": "Availability"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "red", "value": null},
                  {"color": "yellow", "value": 0.99},
                  {"color": "green", "value": 0.999}
                ]
              }
            }
          }
        },
        {
          "title": "Error Budget Remaining",
          "type": "gauge",
          "gridPos": {"x": 6, "y": 0, "w": 6, "h": 4},
          "targets": [
            {
              "expr": "slo:error_budget:remaining_ratio{service=\"$service\"}",
              "legendFormat": "Budget"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "min": 0,
              "max": 1,
              "thresholds": {
                "steps": [
                  {"color": "red", "value": 0},
                  {"color": "yellow", "value": 0.25},
                  {"color": "green", "value": 0.5}
                ]
              }
            }
          }
        },
        {
          "title": "Request Rate & Errors",
          "type": "timeseries",
          "gridPos": {"x": 0, "y": 4, "w": 12, "h": 6},
          "targets": [
            {
              "expr": "sum(rate(http_requests_total{service=\"$service\"}[5m]))",
              "legendFormat": "Total Requests/s"
            },
            {
              "expr": "sum(rate(http_requests_total{service=\"$service\",status=~\"5..\"}[5m]))",
              "legendFormat": "5xx Errors/s"
            }
          ]
        },
        {
          "title": "Latency Distribution",
          "type": "heatmap",
          "gridPos": {"x": 12, "y": 4, "w": 12, "h": 6},
          "targets": [
            {
              "expr": "sum(rate(http_request_duration_seconds_bucket{service=\"$service\"}[5m])) by (le)",
              "format": "heatmap"
            }
          ]
        },
        {
          "title": "Application Logs",
          "type": "logs",
          "gridPos": {"x": 0, "y": 10, "w": 12, "h": 8},
          "datasource": "Loki",
          "targets": [
            {
              "expr": "{namespace=\"$namespace\", app=\"$service\"} | json | level=~\"error|warn\"",
              "legendFormat": ""
            }
          ],
          "options": {
            "showTime": true,
            "showLabels": true,
            "wrapLogMessage": true,
            "enableLogDetails": true
          }
        },
        {
          "title": "Traces",
          "type": "traces",
          "gridPos": {"x": 12, "y": 10, "w": 12, "h": 8},
          "datasource": "Tempo",
          "targets": [
            {
              "query": "{service.name=\"$service\"}",
              "queryType": "traceql"
            }
          ]
        },
        {
          "title": "Service Dependencies",
          "type": "nodeGraph",
          "gridPos": {"x": 0, "y": 18, "w": 24, "h": 8},
          "datasource": "Tempo",
          "targets": [
            {
              "query": "{resource.service.name=\"$service\"}",
              "queryType": "serviceMap"
            }
          ]
        }
      ],
      "links": [
        {
          "title": "Jump to Traces",
          "type": "link",
          "url": "/explore?left=[\"now-1h\",\"now\",\"Tempo\",{\"query\":\"{service.name=\\\"${service}\\\"}\"},{\"mode\":\"Metrics\"},{\"ui\":[true,true,true,\"none\"]}]"
        }
      ]
    }
```

### Trace-to-Logs Correlation

```yaml
# Grafana data source configuration for correlation
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources-correlation
  namespace: monitoring
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus:9090
        access: proxy
        isDefault: true
        jsonData:
          exemplarTraceIdDestinations:
            - name: trace_id
              datasourceUid: tempo
        
      - name: Loki
        type: loki
        url: http://loki:3100
        access: proxy
        jsonData:
          derivedFields:
            - name: TraceID
              matcherRegex: "trace_id=(\\w+)"
              url: '$${__value.raw}'
              datasourceUid: tempo
        
      - name: Tempo
        type: tempo
        url: http://tempo:3100
        access: proxy
        uid: tempo
        jsonData:
          tracesToLogs:
            datasourceUid: loki
            tags: ['service.name', 'namespace']
            mappedTags: [{ key: 'service.name', value: 'app' }]
            mapTagNamesEnabled: true
            spanStartTimeShift: '-5m'
            spanEndTimeShift: '5m'
            filterByTraceID: true
            filterBySpanID: false
          tracesToMetrics:
            datasourceUid: prometheus
            tags: [{ key: 'service.name', value: 'service' }]
            queries:
              - name: 'Request Rate'
                query: 'sum(rate(http_requests_total{service="$${__tags.service}"}[5m]))'
              - name: 'Error Rate'
                query: 'sum(rate(http_requests_total{service="$${__tags.service}",status=~"5.."}[5m]))'
          serviceMap:
            datasourceUid: prometheus
          nodeGraph:
            enabled: true
          lokiSearch:
            datasourceUid: loki
```

### Exemplar-Based Correlation

```yaml
# Application instrumentation for exemplars
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-instrumentation-config
  namespace: default
data:
  instrumentation.py: |
    # Python example with exemplars
    from prometheus_client import Histogram, Counter, REGISTRY
    from prometheus_client.openmetrics.exposition import generate_latest
    from opentelemetry import trace
    import time
    
    # Histogram with exemplars
    REQUEST_DURATION = Histogram(
        'http_request_duration_seconds',
        'HTTP request duration',
        ['method', 'path', 'status'],
        buckets=[0.01, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5, 5.0, 10.0]
    )
    
    def instrument_request(method, path, status, duration):
        """Record request metrics with trace exemplar."""
        # Get current trace context
        span = trace.get_current_span()
        span_context = span.get_span_context()
        
        # Create exemplar with trace_id
        exemplar = {'trace_id': format(span_context.trace_id, '032x')}
        
        # Record with exemplar
        REQUEST_DURATION.labels(
            method=method,
            path=path,
            status=status
        ).observe(duration, exemplar)
    
    # Usage in request handler
    @app.route('/api/endpoint')
    def handle_request():
        start = time.time()
        try:
            result = process_request()
            status = '200'
            return result
        except Exception as e:
            status = '500'
            raise
        finally:
            duration = time.time() - start
            instrument_request('GET', '/api/endpoint', status, duration)
  
  instrumentation.go: |
    // Go example with exemplars
    package main
    
    import (
        "context"
        "github.com/prometheus/client_golang/prometheus"
        "github.com/prometheus/client_golang/prometheus/promhttp"
        "go.opentelemetry.io/otel/trace"
    )
    
    var requestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration in seconds",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "path", "status"},
    )
    
    func instrumentRequest(ctx context.Context, method, path, status string, duration float64) {
        // Get trace context
        span := trace.SpanFromContext(ctx)
        traceID := span.SpanContext().TraceID().String()
        
        // Observe with exemplar
        requestDuration.WithLabelValues(method, path, status).(prometheus.ExemplarObserver).
            ObserveWithExemplar(duration, prometheus.Labels{"trace_id": traceID})
    }
```

### Log Correlation with Traces

```yaml
# Structured logging with trace context
apiVersion: v1
kind: ConfigMap
metadata:
  name: logging-config
  namespace: default
data:
  log-config.yaml: |
    # Python logging configuration
    version: 1
    formatters:
      json:
        class: pythonjsonlogger.jsonlogger.JsonFormatter
        format: '%(timestamp)s %(level)s %(name)s %(message)s'
    
    handlers:
      console:
        class: logging.StreamHandler
        formatter: json
    
    loggers:
      app:
        level: INFO
        handlers: [console]
  
  trace-context-logger.py: |
    import logging
    import json
    from opentelemetry import trace
    from opentelemetry.trace import format_trace_id, format_span_id
    
    class TraceContextFilter(logging.Filter):
        """Add trace context to all log records."""
        
        def filter(self, record):
            span = trace.get_current_span()
            if span.is_recording():
                ctx = span.get_span_context()
                record.trace_id = format_trace_id(ctx.trace_id)
                record.span_id = format_span_id(ctx.span_id)
                record.trace_flags = ctx.trace_flags
            else:
                record.trace_id = None
                record.span_id = None
                record.trace_flags = None
            return True
    
    # Configure logger
    logger = logging.getLogger('app')
    logger.addFilter(TraceContextFilter())
    
    # Usage
    with tracer.start_as_current_span("process_order") as span:
        logger.info("Processing order", extra={
            'order_id': order_id,
            'customer_id': customer_id,
            'amount': amount
        })
        # Log output includes trace_id automatically
```

## Observability-Driven Development

### Testing Observability

```yaml
# Integration tests for observability
apiVersion: batch/v1
kind: Job
metadata:
  name: observability-tests
  namespace: monitoring
spec:
  template:
    spec:
      containers:
        - name: tester
          image: alpine/curl:latest
          command:
            - /bin/sh
            - -c
            - |
              set -e
              
              echo "Testing Prometheus metrics..."
              # Verify service metrics exist
              curl -sf "http://prometheus:9090/api/v1/query?query=up{job='sample-app'}" | \
                grep '"status":"success"'
              
              # Verify SLI recording rules
              curl -sf "http://prometheus:9090/api/v1/query?query=sli:availability:ratio_rate5m" | \
                grep '"status":"success"'
              
              echo "Testing Loki logs..."
              # Verify logs are being collected
              curl -sf "http://loki:3100/loki/api/v1/query?query={namespace='default'}" | \
                grep '"status":"success"'
              
              echo "Testing Grafana datasources..."
              # Verify datasources are configured
              curl -sf -u admin:admin "http://grafana:3000/api/datasources" | \
                grep 'Prometheus'
              
              echo "Testing trace collection..."
              # Verify Tempo is receiving traces
              curl -sf "http://tempo:3200/ready" | grep "ready"
              
              echo "All observability tests passed!"
      restartPolicy: Never
---
# Chaos test for observability
apiVersion: batch/v1
kind: Job
metadata:
  name: observability-chaos-test
  namespace: monitoring
spec:
  template:
    spec:
      containers:
        - name: chaos
          image: alpine/curl:latest
          command:
            - /bin/sh
            - -c
            - |
              echo "Simulating failures to test alerting..."
              
              # Generate errors for 2 minutes
              for i in $(seq 1 120); do
                curl -s "http://sample-app/error" || true
                sleep 1
              done
              
              echo "Waiting for alerts..."
              sleep 60
              
              # Check if alerts fired
              FIRING=$(curl -s "http://alertmanager:9093/api/v2/alerts" | \
                grep -c '"status":"firing"')
              
              if [ "$FIRING" -gt 0 ]; then
                echo "SUCCESS: Alerts fired as expected"
              else
                echo "FAILURE: No alerts fired"
                exit 1
              fi
      restartPolicy: Never
```

### Observability Maturity Model

```yaml
# Assessment checklist as ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: observability-maturity-checklist
  namespace: monitoring
data:
  maturity-model.md: |
    # Observability Maturity Model
    
    ## Level 1: Reactive (Monitoring)
    - [ ] Basic health checks (up/down)
    - [ ] Manual log inspection
    - [ ] Simple alerts on thresholds
    - [ ] No correlation between signals
    
    ## Level 2: Proactive (Observability Basics)
    - [ ] Structured logging
    - [ ] Request tracing implemented
    - [ ] Custom application metrics
    - [ ] Alert deduplication
    - [ ] Basic dashboards
    
    ## Level 3: Informed (Full Observability)
    - [ ] SLIs defined for all services
    - [ ] SLOs established and tracked
    - [ ] Correlation across metrics, logs, traces
    - [ ] Automated runbooks
    - [ ] Error budgets in use
    - [ ] Context propagation working
    
    ## Level 4: Optimized (Advanced Practices)
    - [ ] Multi-window burn rate alerting
    - [ ] Chaos engineering for observability
    - [ ] Automated remediation
    - [ ] Observability as code
    - [ ] Cost optimization for telemetry
    - [ ] Cross-service SLOs
    
    ## Level 5: Autonomous (Self-Healing)
    - [ ] ML-based anomaly detection
    - [ ] Automatic scaling based on SLOs
    - [ ] Self-healing infrastructure
    - [ ] Predictive alerting
    - [ ] Business KPI correlation
```

### Implementing Observability as Code

```yaml
# GitOps-managed observability configuration
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/observability-config.git
    targetRevision: main
    path: overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: monitoring
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
---
# Kustomization for observability
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: observability-kustomization
namespace: monitoring
resources:
  - prometheus-rules/
  - grafana-dashboards/
  - loki-config/
  - alertmanager-config/
  - servicemonitors/
configMapGenerator:
  - name: slo-config
    files:
      - slo-definitions.yaml
  - name: runbooks
    files:
      - runbooks/
```

## Exercises

### Exercise 1: Implement SLOs

Define and track SLOs for a service:

```bash
# Deploy sample application with metrics
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: slo-demo
  namespace: default
spec:
  replicas: 3
  selector:
    matchLabels:
      app: slo-demo
  template:
    metadata:
      labels:
        app: slo-demo
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
    spec:
      containers:
        - name: app
          image: quay.io/brancz/prometheus-example-app:v0.4.0
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: slo-demo
  namespace: default
spec:
  selector:
    app: slo-demo
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: slo-demo
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: slo-demo
  endpoints:
    - port: http
      interval: 15s
EOF

# Create SLI recording rules
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-demo-slis
  namespace: monitoring
  labels:
    prometheus: k8s
spec:
  groups:
    - name: slo-demo.slis
      interval: 30s
      rules:
        - record: sli:slo_demo:availability:ratio_rate5m
          expr: |
            sum(rate(http_requests_total{job="slo-demo",status!~"5.."}[5m]))
            /
            sum(rate(http_requests_total{job="slo-demo"}[5m]))
        
        - record: sli:slo_demo:latency:ratio_rate5m
          expr: |
            sum(rate(http_request_duration_seconds_bucket{job="slo-demo",le="0.2"}[5m]))
            /
            sum(rate(http_request_duration_seconds_count{job="slo-demo"}[5m]))
EOF

# Create SLO targets
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-demo-targets
  namespace: monitoring
  labels:
    prometheus: k8s
spec:
  groups:
    - name: slo-demo.targets
      rules:
        - record: slo:slo_demo:availability:target
          expr: vector(0.999)
        
        - record: slo:slo_demo:latency:target
          expr: vector(0.99)
        
        - record: slo:slo_demo:error_budget:remaining
          expr: |
            1 - (
              (1 - sli:slo_demo:availability:ratio_rate5m)
              /
              (1 - 0.999)
            )
EOF

# Verify SLI metrics
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
sleep 5

echo "Current availability SLI:"
curl -s "http://localhost:9090/api/v1/query?query=sli:slo_demo:availability:ratio_rate5m" | jq '.data.result'

echo "Error budget remaining:"
curl -s "http://localhost:9090/api/v1/query?query=slo:slo_demo:error_budget:remaining" | jq '.data.result'
```

### Exercise 2: Build Burn Rate Alerts

Implement multi-window burn rate alerting:

```bash
# Create burn rate alert rules
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: slo-demo-burn-alerts
  namespace: monitoring
  labels:
    prometheus: k8s
spec:
  groups:
    - name: slo-demo.burn-rate
      rules:
        # 14.4x burn rate (2% budget in 1 hour)
        - alert: SLODemoBurnCritical
          expr: |
            (
              1 - sli:slo_demo:availability:ratio_rate1h > 14.4 * 0.001
            )
            and
            (
              1 - sli:slo_demo:availability:ratio_rate5m > 14.4 * 0.001
            )
          for: 2m
          labels:
            severity: critical
            service: slo-demo
          annotations:
            summary: "Critical SLO burn rate for slo-demo"
            description: "Burning error budget at 14.4x rate"
        
        # 6x burn rate (5% budget in 6 hours)
        - alert: SLODemoBurnHigh
          expr: |
            (
              1 - sli:slo_demo:availability:ratio_rate6h > 6 * 0.001
            )
            and
            (
              1 - sli:slo_demo:availability:ratio_rate30m > 6 * 0.001
            )
          for: 5m
          labels:
            severity: warning
            service: slo-demo
          annotations:
            summary: "High SLO burn rate for slo-demo"
            description: "Burning error budget at 6x rate"
EOF

# Simulate error spike to test alerts
echo "Generating errors to trigger burn rate alert..."
for i in $(seq 1 100); do
  curl -s "http://localhost:8080/err" || true
  sleep 0.1
done

# Check for firing alerts
sleep 120
curl -s "http://localhost:9093/api/v2/alerts" | jq '.[] | select(.labels.alertname | contains("SLODemo"))'
```

### Exercise 3: Correlate Signals

Practice correlating metrics, logs, and traces:

```bash
# Deploy instrumented application
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: correlation-demo
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: correlation-demo
  template:
    metadata:
      labels:
        app: correlation-demo
    spec:
      containers:
        - name: app
          image: ghcr.io/open-telemetry/demo:latest-frontendproxy
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector:4317"
            - name: OTEL_SERVICE_NAME
              value: "correlation-demo"
          ports:
            - containerPort: 8080
EOF

# Create Grafana dashboard for correlation
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: correlation-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  correlation.json: |
    {
      "title": "Signal Correlation Demo",
      "panels": [
        {
          "title": "Request Metrics",
          "type": "timeseries",
          "gridPos": {"x": 0, "y": 0, "w": 12, "h": 6},
          "targets": [{"expr": "rate(http_requests_total[5m])"}]
        },
        {
          "title": "Error Logs",
          "type": "logs",
          "gridPos": {"x": 12, "y": 0, "w": 12, "h": 6},
          "datasource": "Loki",
          "targets": [{"expr": "{app=\"correlation-demo\"} |= \"error\""}]
        },
        {
          "title": "Traces",
          "type": "traces",
          "gridPos": {"x": 0, "y": 6, "w": 24, "h": 8},
          "datasource": "Tempo"
        }
      ]
    }
EOF

# Access Grafana and explore correlation
kubectl port-forward -n monitoring svc/grafana 3000:3000 &
echo "Open http://localhost:3000 - use Explore to:"
echo "1. Click on a metric spike"
echo "2. Follow exemplar link to trace"
echo "3. From trace, click 'Logs for this span'"
```

### Exercise 4: Error Budget Dashboard

Create an error budget tracking dashboard:

```bash
# Create comprehensive error budget dashboard
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: error-budget-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  error-budget.json: |
    {
      "title": "Error Budget Dashboard",
      "templating": {
        "list": [
          {
            "name": "service",
            "type": "query",
            "query": "label_values(sli:availability:ratio_rate5m, service)"
          }
        ]
      },
      "panels": [
        {
          "title": "Error Budget Status",
          "type": "stat",
          "gridPos": {"x": 0, "y": 0, "w": 8, "h": 4},
          "targets": [
            {
              "expr": "slo:error_budget:remaining_ratio{service=\"\$service\"}",
              "legendFormat": "Budget Remaining"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "thresholds": {
                "steps": [
                  {"color": "red", "value": 0},
                  {"color": "yellow", "value": 0.25},
                  {"color": "green", "value": 0.5}
                ]
              }
            }
          }
        },
        {
          "title": "Budget Minutes Remaining",
          "type": "stat",
          "gridPos": {"x": 8, "y": 0, "w": 8, "h": 4},
          "targets": [
            {
              "expr": "slo:error_budget:remaining_minutes{service=\"\$service\"}",
              "legendFormat": "Minutes"
            }
          ]
        },
        {
          "title": "Current SLI vs Target",
          "type": "gauge",
          "gridPos": {"x": 16, "y": 0, "w": 8, "h": 4},
          "targets": [
            {
              "expr": "sli:availability:ratio_rate30d{service=\"\$service\"}",
              "legendFormat": "Availability"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "min": 0.99,
              "max": 1,
              "thresholds": {
                "steps": [
                  {"color": "red", "value": 0.99},
                  {"color": "yellow", "value": 0.999},
                  {"color": "green", "value": 0.9999}
                ]
              }
            }
          }
        },
        {
          "title": "Error Budget Burn Over Time",
          "type": "timeseries",
          "gridPos": {"x": 0, "y": 4, "w": 24, "h": 8},
          "targets": [
            {
              "expr": "1 - slo:error_budget:remaining_ratio{service=\"\$service\"}",
              "legendFormat": "Budget Consumed"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit"
            }
          }
        },
        {
          "title": "Burn Rate",
          "type": "timeseries",
          "gridPos": {"x": 0, "y": 12, "w": 12, "h": 6},
          "targets": [
            {
              "expr": "(1 - sli:availability:ratio_rate1h{service=\"\$service\"}) / 0.001",
              "legendFormat": "1h burn rate"
            },
            {
              "expr": "14.4",
              "legendFormat": "Critical threshold (14.4x)"
            },
            {
              "expr": "6",
              "legendFormat": "Warning threshold (6x)"
            }
          ]
        },
        {
          "title": "SLO Breaches History",
          "type": "table",
          "gridPos": {"x": 12, "y": 12, "w": 12, "h": 6},
          "targets": [
            {
              "expr": "count_over_time((sli:availability:ratio_rate5m{service=\"\$service\"} < 0.999)[7d:5m])",
              "legendFormat": "Breaches (7d)"
            }
          ]
        }
      ]
    }
EOF
```

### Exercise 5: Chaos Engineering for Observability

Validate observability with controlled chaos:

```bash
# Deploy chaos test job
kubectl apply -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: chaos-observability-test
  namespace: default
spec:
  template:
    spec:
      containers:
        - name: chaos
          image: alpine/curl:latest
          command:
            - /bin/sh
            - -c
            - |
              echo "=== Chaos Observability Test ==="
              
              # Phase 1: Baseline (2 minutes)
              echo "Phase 1: Collecting baseline..."
              for i in \$(seq 1 120); do
                curl -s "http://slo-demo/success" > /dev/null
                sleep 1
              done
              
              # Phase 2: Inject errors (3 minutes)
              echo "Phase 2: Injecting errors..."
              for i in \$(seq 1 180); do
                if [ \$((i % 5)) -eq 0 ]; then
                  curl -s "http://slo-demo/error" > /dev/null || true
                else
                  curl -s "http://slo-demo/success" > /dev/null
                fi
                sleep 1
              done
              
              # Phase 3: Recovery (2 minutes)
              echo "Phase 3: Recovering..."
              for i in \$(seq 1 120); do
                curl -s "http://slo-demo/success" > /dev/null
                sleep 1
              done
              
              echo "=== Test Complete ==="
              echo "Check Grafana for:"
              echo "1. SLI degradation during Phase 2"
              echo "2. Error budget consumption"
              echo "3. Alert firing"
              echo "4. Correlated logs and traces"
      restartPolicy: Never
EOF

# Watch metrics during chaos test
watch -n 5 'curl -s "http://localhost:9090/api/v1/query?query=sli:slo_demo:availability:ratio_rate5m" | jq -r ".data.result[0].value[1]"'
```

## Validation Checklist

Before completing this module, verify you can:

- [ ] Define SLIs for availability and latency
- [ ] Create SLOs with appropriate targets
- [ ] Calculate and track error budgets
- [ ] Implement multi-window burn rate alerting
- [ ] Correlate metrics with traces using exemplars
- [ ] Link logs to traces via trace IDs
- [ ] Build unified observability dashboards
- [ ] Apply observability-driven development practices
- [ ] Validate observability with chaos testing

## Key Takeaways

1. **SLOs drive reliability** - Define what "good enough" means for your users
2. **Error budgets balance velocity and reliability** - Spend budget on innovation
3. **Multi-window alerts reduce noise** - Different windows catch different issues
4. **Correlation is key** - Connect metrics, logs, and traces for faster debugging
5. **Exemplars bridge metrics and traces** - Click through from graph to trace
6. **Observability enables confidence** - You can only improve what you can measure
7. **Test your observability** - Chaos engineering validates your setup
8. **Observability as code** - Version control and review observability configuration

## Troubleshooting

### SLI Metrics Not Appearing

```bash
# Check recording rules
kubectl get prometheusrules -n monitoring
kubectl describe prometheusrule slo-demo-slis -n monitoring

# Verify rule evaluation
curl -s "http://localhost:9090/api/v1/rules" | jq '.data.groups[] | select(.name | contains("slo"))'

# Check for errors
kubectl logs -n monitoring prometheus-k8s-0 | grep -i "error.*rule"
```

### Error Budget Calculation Issues

```bash
# Verify all required metrics exist
curl -s "http://localhost:9090/api/v1/query?query=sli:availability:ratio_rate5m" | jq '.data.result'
curl -s "http://localhost:9090/api/v1/query?query=slo:availability:target" | jq '.data.result'

# Check calculation manually
echo "Error rate: $(curl -s 'http://localhost:9090/api/v1/query?query=1-sli:availability:ratio_rate5m' | jq -r '.data.result[0].value[1]')"
echo "Budget: $(curl -s 'http://localhost:9090/api/v1/query?query=1-slo:availability:target' | jq -r '.data.result[0].value[1]')"
```

### Correlation Not Working

```bash
# Verify trace IDs in logs
kubectl logs -n default -l app=correlation-demo | grep -o 'trace_id=[a-f0-9]*'

# Check exemplars in Prometheus
curl -s "http://localhost:9090/api/v1/query_exemplars?query=http_request_duration_seconds_bucket&start=$(date -d '1 hour ago' +%s)&end=$(date +%s)"

# Verify Grafana data source configuration
kubectl get configmap -n monitoring grafana-datasources -o yaml
```

## Next Steps

Congratulations on completing the Observability & Monitoring module! You now have comprehensive skills in:

- Prometheus metrics and PromQL
- Grafana dashboard creation
- Loki log aggregation
- Distributed tracing
- Alerting and incident response
- SLOs and error budgets

Continue to Module 5: Platform Engineering to learn about building internal developer platforms with Kubernetes.

---

## Quick Reference

### SLO Formulas

```
# Error Budget
Error Budget = 100% - SLO Target
Example: 100% - 99.9% = 0.1% (43.2 min/month)

# Budget Consumption
Budget Consumed = (1 - Current SLI) / (1 - SLO Target)
Example: (1 - 0.998) / (1 - 0.999) = 2x (burned 2x expected)

# Burn Rate
Burn Rate = (Error Rate) / (Error Budget)
Example: 0.002 / 0.001 = 2x burn rate

# Multi-Window Thresholds
Critical: 14.4x burn rate (2% budget in 1 hour)
High:     6x burn rate (5% budget in 6 hours)
Slow:     1x burn rate (10% budget in 3 days)
```

### Exemplar Configuration

```yaml
# Prometheus scrape config for exemplars
scrape_configs:
  - job_name: 'app'
    scrape_interval: 15s
    honor_labels: true
    metrics_path: /metrics
    params:
      format: ['openmetrics']  # Required for exemplars
```

### Correlation Headers

```
# Trace Context (W3C)
traceparent: 00-{trace-id}-{span-id}-{flags}

# Baggage
baggage: key1=value1,key2=value2

# Log Pattern
{"level":"info","trace_id":"abc123","span_id":"def456","msg":"request processed"}
```
