# Lab 4: Distributed Tracing

## Introduction

Distributed tracing allows you to track requests as they flow through multiple services in a microservices architecture. In this lab, you'll learn to deploy Jaeger, instrument applications with OpenTelemetry, and analyze traces to debug performance issues.

## Learning Objectives

After completing this lab, you will be able to:

- Understand distributed tracing concepts
- Deploy Jaeger as a trace backend
- Implement OpenTelemetry instrumentation
- Configure context propagation
- Analyze traces to identify bottlenecks
- Correlate traces with metrics and logs

## Prerequisites

- Completed Labs 1-3 of this module
- Running Kubernetes cluster
- Helm 3.x installed
- Basic understanding of microservices

## Duration

Estimated time: 90-120 minutes

---

## Exercise 1: Distributed Tracing Concepts

### Step 1: Understanding Traces

```text
┌─────────────────────────────────────────────────────────────────┐
│                    DISTRIBUTED TRACE ANATOMY                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Trace ID: abc123-def456-ghi789                                 │
│                                                                  │
│  Time ─────────────────────────────────────────────────────▶   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Span: Frontend                                          │   │
│  │ ID: span-001  Parent: none  Duration: 350ms             │   │
│  │ ├────────────────────────────────────────────────────┤  │   │
│  └─────────────────────────────────────────────────────────┘   │
│      │                                                          │
│      ▼                                                          │
│  ┌───────────────────────────────────────────────────┐         │
│  │ Span: API Gateway                                 │         │
│  │ ID: span-002  Parent: span-001  Duration: 280ms   │         │
│  │ ├──────────────────────────────────────────────┤  │         │
│  └───────────────────────────────────────────────────┘         │
│      │                   │                                      │
│      ▼                   ▼                                      │
│  ┌─────────────────┐  ┌─────────────────────────┐              │
│  │ Span: User Svc  │  │ Span: Order Service     │              │
│  │ ID: span-003    │  │ ID: span-004            │              │
│  │ Duration: 50ms  │  │ Duration: 180ms         │              │
│  │ ├────────────┤  │  │ ├─────────────────────┤ │              │
│  └─────────────────┘  └─────────────────────────┘              │
│                           │                                     │
│                           ▼                                     │
│                       ┌─────────────────┐                      │
│                       │ Span: Database  │                      │
│                       │ ID: span-005    │                      │
│                       │ Duration: 120ms │                      │
│                       │ ├─────────────┤ │                      │
│                       └─────────────────┘                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2: Key Concepts

```text
Trace:
- Represents the entire journey of a request
- Contains multiple spans
- Has a unique trace ID

Span:
- Represents a unit of work (single operation)
- Has a span ID and parent span ID
- Contains timing, tags, and logs

Context Propagation:
- Passing trace context between services
- Headers: traceparent, tracestate (W3C)
- Or: x-b3-traceid, x-b3-spanid (Zipkin/B3)

Span Attributes:
- Key-value pairs describing the span
- Examples: http.method, http.status_code, db.statement
```

### Step 3: OpenTelemetry Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                    OPENTELEMETRY ARCHITECTURE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                  INSTRUMENTATION                        │    │
│  │                                                         │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐    │    │
│  │  │    Auto     │  │   Manual    │  │    SDK      │    │    │
│  │  │ Instrument  │  │ Instrument  │  │   Config    │    │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘    │    │
│  │         │                │                │            │    │
│  │         └────────────────┼────────────────┘            │    │
│  │                          ▼                             │    │
│  │                  ┌─────────────────┐                   │    │
│  │                  │    OTel SDK     │                   │    │
│  │                  │   (Traces,      │                   │    │
│  │                  │    Metrics,     │                   │    │
│  │                  │    Logs)        │                   │    │
│  │                  └─────────────────┘                   │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                  │
│                              ▼                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │               OTEL COLLECTOR (Optional)                 │    │
│  │  ┌──────────┐  ┌──────────────┐  ┌──────────────┐     │    │
│  │  │ Receivers│──│  Processors  │──│   Exporters  │     │    │
│  │  └──────────┘  └──────────────┘  └──────────────┘     │    │
│  └────────────────────────────────────────────────────────┘    │
│                              │                                  │
│              ┌───────────────┼───────────────┐                 │
│              ▼               ▼               ▼                 │
│        ┌──────────┐   ┌──────────┐   ┌──────────┐             │
│        │  Jaeger  │   │  Tempo   │   │ Zipkin   │             │
│        └──────────┘   └──────────┘   └──────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Validation 1

Verify understanding:

```bash
# Answer these questions:
# 1. What is the difference between a trace and a span?
# 2. How does context propagation work?
# 3. Why is OpenTelemetry important?
```

---

## Exercise 2: Deploy Jaeger

### Step 1: Add Jaeger Helm Repository

```bash
# Add Jaeger operator repo
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts
helm repo update
```

### Step 2: Create Jaeger Values File

```yaml
# jaeger-values.yaml
provisionDataStore:
  cassandra: false
  elasticsearch: false
  kafka: false

allInOne:
  enabled: true
  image: jaegertracing/all-in-one
  tag: 1.53
  
  resources:
    limits:
      cpu: 500m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 128Mi
  
  extraEnv:
    - name: SPAN_STORAGE_TYPE
      value: badger
    - name: BADGER_EPHEMERAL
      value: "false"
    - name: BADGER_DIRECTORY_VALUE
      value: /badger/data
    - name: BADGER_DIRECTORY_KEY
      value: /badger/key

  persistence:
    enabled: true
    size: 10Gi

storage:
  type: badger

collector:
  service:
    otlp:
      grpc:
        name: otlp-grpc
        port: 4317
      http:
        name: otlp-http
        port: 4318

query:
  service:
    type: ClusterIP
    port: 16686
```

### Step 3: Install Jaeger

```bash
# Create namespace
kubectl create namespace tracing

# Install Jaeger
helm install jaeger jaegertracing/jaeger \
  --namespace tracing \
  --values jaeger-values.yaml \
  --wait

# Verify installation
kubectl get pods -n tracing

# Expected output:
# NAME                           READY   STATUS
# jaeger-0                       1/1     Running
```

### Step 4: Access Jaeger UI

```bash
# Port forward Jaeger UI
kubectl port-forward -n tracing svc/jaeger-query 16686:16686 &

# Access in browser: http://localhost:16686
```

### Step 5: Add Jaeger Data Source to Grafana

```bash
# Add Jaeger as data source
curl -X POST -H "Content-Type: application/json" \
  -u admin:admin123 \
  http://localhost:3000/api/datasources \
  -d '{
    "name": "Jaeger",
    "type": "jaeger",
    "url": "http://jaeger-query.tracing.svc.cluster.local:16686",
    "access": "proxy",
    "isDefault": false
  }'
```

### Validation 2

Verify Jaeger deployment:

```bash
# Check Jaeger is running
kubectl get pods -n tracing

# Check Jaeger services
kubectl get svc -n tracing

# Test Jaeger UI
curl -s http://localhost:16686/api/services | jq

# Initially returns empty as no traces yet
```

---

## Exercise 3: Deploy OpenTelemetry Collector

### Step 1: Create Collector Configuration

```yaml
# otel-collector-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: otel-collector-config
  namespace: tracing
data:
  config.yaml: |
    receivers:
      otlp:
        protocols:
          grpc:
            endpoint: 0.0.0.0:4317
          http:
            endpoint: 0.0.0.0:4318
      
      # Prometheus receiver for metrics
      prometheus:
        config:
          scrape_configs:
            - job_name: 'otel-collector'
              scrape_interval: 10s
              static_configs:
                - targets: ['localhost:8888']

    processors:
      batch:
        timeout: 1s
        send_batch_size: 1024
      
      memory_limiter:
        check_interval: 1s
        limit_mib: 512
        spike_limit_mib: 128
      
      # Add resource attributes
      resource:
        attributes:
          - key: environment
            value: production
            action: upsert

    exporters:
      # Jaeger exporter
      otlp/jaeger:
        endpoint: jaeger-collector.tracing.svc.cluster.local:4317
        tls:
          insecure: true
      
      # Prometheus exporter for metrics
      prometheus:
        endpoint: "0.0.0.0:8889"
      
      # Loki exporter for logs
      loki:
        endpoint: http://loki-gateway.monitoring.svc.cluster.local/loki/api/v1/push
      
      # Logging exporter for debugging
      logging:
        loglevel: info

    extensions:
      health_check:
        endpoint: 0.0.0.0:13133
      pprof:
        endpoint: 0.0.0.0:1777
      zpages:
        endpoint: 0.0.0.0:55679

    service:
      extensions: [health_check, pprof, zpages]
      pipelines:
        traces:
          receivers: [otlp]
          processors: [memory_limiter, batch, resource]
          exporters: [otlp/jaeger, logging]
        
        metrics:
          receivers: [otlp, prometheus]
          processors: [memory_limiter, batch]
          exporters: [prometheus]
        
        logs:
          receivers: [otlp]
          processors: [memory_limiter, batch]
          exporters: [loki]
```

### Step 2: Deploy Collector

```yaml
# otel-collector-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: otel-collector
  namespace: tracing
spec:
  replicas: 1
  selector:
    matchLabels:
      app: otel-collector
  template:
    metadata:
      labels:
        app: otel-collector
    spec:
      containers:
        - name: collector
          image: otel/opentelemetry-collector-contrib:0.91.0
          args:
            - --config=/conf/config.yaml
          ports:
            - containerPort: 4317  # OTLP gRPC
            - containerPort: 4318  # OTLP HTTP
            - containerPort: 8889  # Prometheus metrics
            - containerPort: 13133 # Health check
          resources:
            limits:
              cpu: 500m
              memory: 512Mi
            requests:
              cpu: 100m
              memory: 128Mi
          volumeMounts:
            - name: config
              mountPath: /conf
          livenessProbe:
            httpGet:
              path: /
              port: 13133
          readinessProbe:
            httpGet:
              path: /
              port: 13133
      volumes:
        - name: config
          configMap:
            name: otel-collector-config
---
apiVersion: v1
kind: Service
metadata:
  name: otel-collector
  namespace: tracing
spec:
  ports:
    - name: otlp-grpc
      port: 4317
      targetPort: 4317
    - name: otlp-http
      port: 4318
      targetPort: 4318
    - name: prometheus
      port: 8889
      targetPort: 8889
  selector:
    app: otel-collector
```

### Step 3: Apply Collector Configuration

```bash
# Apply ConfigMap and Deployment
kubectl apply -f otel-collector-config.yaml
kubectl apply -f otel-collector-deployment.yaml

# Verify collector is running
kubectl get pods -n tracing -l app=otel-collector

# Check collector logs
kubectl logs -n tracing -l app=otel-collector
```

### Validation 3

Verify collector is working:

```bash
# Check collector health
kubectl port-forward -n tracing svc/otel-collector 13133:13133 &
curl http://localhost:13133/

# Check zpages for debugging
kubectl port-forward -n tracing svc/otel-collector 55679:55679 &
# Access http://localhost:55679/debug/tracez
```

---

## Exercise 4: Instrument Sample Application

### Step 1: Create Sample Microservices

```yaml
# sample-app-traced.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: demo
---
# Frontend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: demo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
        - name: frontend
          image: ghcr.io/open-telemetry/demo:1.6.0-frontend
          ports:
            - containerPort: 8080
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.tracing.svc.cluster.local:4317"
            - name: OTEL_SERVICE_NAME
              value: frontend
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "service.namespace=demo,deployment.environment=production"
            - name: BACKEND_URL
              value: "http://backend:8080"
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: demo
spec:
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: frontend
---
# Backend Service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: ghcr.io/open-telemetry/demo:1.6.0-productcatalogservice
          ports:
            - containerPort: 8080
          env:
            - name: OTEL_EXPORTER_OTLP_ENDPOINT
              value: "http://otel-collector.tracing.svc.cluster.local:4317"
            - name: OTEL_SERVICE_NAME
              value: backend
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "service.namespace=demo,deployment.environment=production"
          resources:
            limits:
              cpu: 200m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: demo
spec:
  ports:
    - port: 8080
      targetPort: 8080
  selector:
    app: backend
```

### Step 2: Python Application with OpenTelemetry

```python
# app.py - Example instrumented Python application
from flask import Flask, request
import requests
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes

# Configure tracer
resource = Resource(attributes={
    ResourceAttributes.SERVICE_NAME: "python-service",
    ResourceAttributes.SERVICE_VERSION: "1.0.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production"
})

provider = TracerProvider(resource=resource)
processor = BatchSpanProcessor(
    OTLPSpanExporter(endpoint="http://otel-collector:4317", insecure=True)
)
provider.add_span_processor(processor)
trace.set_tracer_provider(provider)

# Get tracer
tracer = trace.get_tracer(__name__)

# Create Flask app
app = Flask(__name__)

# Auto-instrument Flask and requests
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

@app.route("/")
def index():
    with tracer.start_as_current_span("index-handler") as span:
        span.set_attribute("custom.attribute", "value")
        # Call another service
        response = requests.get("http://backend:8080/api/products")
        return f"Products: {response.json()}"

@app.route("/api/process")
def process():
    with tracer.start_as_current_span("process-data") as span:
        # Simulate work
        span.add_event("Starting processing")
        result = do_work()
        span.add_event("Processing complete", {"items": len(result)})
        return {"status": "ok", "items": result}

def do_work():
    with tracer.start_as_current_span("internal-work") as span:
        span.set_attribute("work.type", "calculation")
        # Simulate work
        return [1, 2, 3, 4, 5]

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080)
```

### Step 3: Dockerfile with OpenTelemetry

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install OpenTelemetry packages
RUN pip install --no-cache-dir \
    flask \
    requests \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc \
    opentelemetry-instrumentation-flask \
    opentelemetry-instrumentation-requests

COPY app.py .

EXPOSE 8080

CMD ["python", "app.py"]
```

### Step 4: Auto-Instrumentation with Operator

For automatic instrumentation without code changes:

```yaml
# opentelemetry-instrumentation.yaml
apiVersion: opentelemetry.io/v1alpha1
kind: Instrumentation
metadata:
  name: demo-instrumentation
  namespace: demo
spec:
  exporter:
    endpoint: http://otel-collector.tracing.svc.cluster.local:4317
  propagators:
    - tracecontext
    - baggage
  sampler:
    type: parentbased_traceidratio
    argument: "1.0"
  python:
    env:
      - name: OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED
        value: "true"
  java:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-java:latest
  nodejs:
    image: ghcr.io/open-telemetry/opentelemetry-operator/autoinstrumentation-nodejs:latest
```

Annotate pods for auto-instrumentation:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-python-app
spec:
  template:
    metadata:
      annotations:
        instrumentation.opentelemetry.io/inject-python: "demo-instrumentation"
    spec:
      containers:
        - name: app
          image: my-python-app:latest
```

### Validation 4

Generate some traces:

```bash
# Deploy sample app
kubectl apply -f sample-app-traced.yaml

# Generate traffic
kubectl run curl --image=curlimages/curl --rm -it --restart=Never -- \
  curl http://frontend.demo:8080/

# Check traces in Jaeger
# http://localhost:16686
# Select service "frontend" and click "Find Traces"
```

---

## Exercise 5: Trace Analysis

### Step 1: Understanding Trace View

```text
┌─────────────────────────────────────────────────────────────────┐
│                    JAEGER TRACE VIEW                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Trace: abc123 | Services: 3 | Spans: 8 | Duration: 450ms       │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Timeline View                                           │   │
│  │                                                         │   │
│  │ frontend ──────────────────────────────────────────────│   │
│  │ └─ HTTP GET /                              [350ms]     │   │
│  │    │                                                    │   │
│  │ backend ─────────────────────────────────────          │   │
│  │ └─ HTTP GET /api/products                  [280ms]     │   │
│  │    │                                                    │   │
│  │ database ────────────────────────                      │   │
│  │ └─ SELECT * FROM products                  [120ms]     │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │ Span Details                                            │   │
│  │                                                         │   │
│  │ Operation: HTTP GET /api/products                       │   │
│  │ Service: backend                                        │   │
│  │ Duration: 280ms                                         │   │
│  │                                                         │   │
│  │ Tags:                                                   │   │
│  │   http.method: GET                                      │   │
│  │   http.status_code: 200                                 │   │
│  │   http.url: /api/products                               │   │
│  │                                                         │   │
│  │ Logs:                                                   │   │
│  │   10:30:00.100 - Query started                          │   │
│  │   10:30:00.220 - Results cached                         │   │
│  │                                                         │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2: Identify Performance Issues

Common patterns to look for:

```text
1. LONG SPANS
   - Database queries taking too long
   - External API calls with high latency
   - CPU-intensive operations

2. SERIAL CALLS
   - Sequential calls that could be parallel
   - N+1 query patterns

3. DEEP CALL STACKS
   - Too many service hops
   - Unnecessary intermediary services

4. ERROR SPANS
   - Spans with error tags
   - Retry patterns
```

### Step 3: Query Traces

In Jaeger UI:

```text
Search Parameters:
- Service: Select specific service
- Operation: Filter by operation name
- Tags: http.status_code=500
- Min Duration: 500ms
- Max Duration: 5s
- Limit: Number of results

Tag Queries:
- error=true
- http.status_code=500
- db.type=postgresql
- custom.user_id=12345
```

### Step 4: Compare Traces

Compare two traces to find differences:

1. Select first trace
2. Click "Compare" button
3. Select second trace
4. View side-by-side comparison

### Step 5: Trace to Logs Correlation

Add trace ID to logs:

```python
import logging
from opentelemetry import trace

# Get current span context
span = trace.get_current_span()
trace_id = span.get_span_context().trace_id

# Format trace ID as hex
trace_id_hex = format(trace_id, '032x')

# Add to log
logging.info(f"Processing request", extra={"trace_id": trace_id_hex})
```

Query in Loki:

```logql
{app="backend"} | json | trace_id="abc123def456..."
```

### Validation 5

Analyze traces in Jaeger:

```bash
# Generate varied traffic
for i in {1..20}; do
  kubectl run curl-$i --image=curlimages/curl --rm -it --restart=Never -- \
    curl http://frontend.demo:8080/
done

# In Jaeger UI:
# 1. Find slowest traces (sort by duration)
# 2. Find error traces (search error=true)
# 3. Compare fast vs slow traces
```

---

## Exercise 6: Sampling Strategies

### Step 1: Understanding Sampling

```text
Why Sample?
- High traffic = many traces
- Storage costs
- Processing overhead

Sampling Types:
- Head-based: Decision at trace start
- Tail-based: Decision after trace complete
- Rate limiting: Fixed rate
- Probabilistic: Random percentage
```

### Step 2: Configure Head-Based Sampling

```yaml
# In OpenTelemetry SDK
from opentelemetry.sdk.trace.sampling import TraceIdRatioBased, ParentBased

# Sample 10% of traces
sampler = ParentBased(
    root=TraceIdRatioBased(0.1)
)

provider = TracerProvider(
    resource=resource,
    sampler=sampler
)
```

### Step 3: Collector-based Sampling

```yaml
# otel-collector config
processors:
  probabilistic_sampler:
    sampling_percentage: 10
  
  tail_sampling:
    decision_wait: 10s
    num_traces: 100
    expected_new_traces_per_sec: 10
    policies:
      # Always sample errors
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      
      # Always sample slow traces
      - name: slow-traces
        type: latency
        latency:
          threshold_ms: 1000
      
      # Sample 10% of rest
      - name: probabilistic
        type: probabilistic
        probabilistic:
          sampling_percentage: 10

service:
  pipelines:
    traces:
      processors: [tail_sampling, batch]
```

### Step 4: Priority Sampling

Always sample important traces:

```python
from opentelemetry import trace

tracer = trace.get_tracer(__name__)

# Force sample important transaction
with tracer.start_as_current_span("payment-processing") as span:
    # Set sampling priority
    span.set_attribute("sampling.priority", 1)
    process_payment()
```

### Validation 6

Verify sampling:

```bash
# Generate traffic
for i in {1..100}; do
  curl http://frontend.demo:8080/ &
done
wait

# Check number of traces in Jaeger
# Should be approximately 10% if using 10% sampling

# Check that error traces are always captured
# Generate an error and verify it appears
```

---

## Exercise 7: Grafana Trace Integration

### Step 1: Add Trace Panel to Dashboard

```json
{
  "panels": [
    {
      "title": "Recent Traces",
      "type": "traces",
      "datasource": {
        "type": "jaeger",
        "uid": "jaeger"
      },
      "targets": [
        {
          "queryType": "search",
          "service": "$service",
          "operation": "$operation",
          "minDuration": "100ms"
        }
      ],
      "gridPos": {
        "h": 12,
        "w": 24,
        "x": 0,
        "y": 0
      }
    }
  ]
}
```

### Step 2: Link Metrics to Traces

Add exemplars to Prometheus metrics:

```python
from prometheus_client import Counter, Histogram
from opentelemetry import trace

# Create metrics with exemplar support
request_count = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'status']
)

request_duration = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method']
)

def handle_request():
    span = trace.get_current_span()
    trace_id = format(span.get_span_context().trace_id, '032x')
    
    # Record with exemplar
    request_count.labels(method='GET', status='200').inc(
        exemplar={'trace_id': trace_id}
    )
```

### Step 3: Link Logs to Traces

Configure Grafana to recognize trace IDs:

```yaml
# In Grafana, configure derived fields in Loki
derivedFields:
  - name: TraceID
    matcherRegex: '"trace_id":"(\w+)"'
    url: '${__value.raw}'
    datasourceUid: jaeger
    urlDisplayLabel: View Trace
```

### Step 4: Create Unified Dashboard

```text
┌─────────────────────────────────────────────────────────────────┐
│                 Service Observability Dashboard                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────┐  ┌─────────────────────────┐  │
│  │     Request Rate            │  │      Error Rate         │  │
│  │   [Prometheus Time Series]  │  │  [Prometheus Time Series]│  │
│  │                             │  │                         │  │
│  │   Click point → View trace  │  │   Click point → View trace│ │
│  └─────────────────────────────┘  └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │            Latency P95/P99 with Exemplars               │   │
│  │           [Prometheus Time Series + Exemplars]          │   │
│  │                                                         │   │
│  │   ★ = Exemplar (click to view trace)                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Error Logs                           │   │
│  │                   [Loki Logs Panel]                     │   │
│  │                                                         │   │
│  │   Click trace_id → View trace in Jaeger                │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Recent Traces                         │   │
│  │                   [Jaeger Traces Panel]                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Validation 7

Test unified observability:

```bash
# Open dashboard
# Click on metric data point with exemplar
# Verify it opens trace in Jaeger
# Click on log entry with trace_id
# Verify it links to correct trace
```

---

## Troubleshooting

### Common Issues

#### Issue 1: No Traces in Jaeger

```bash
# Check collector is receiving traces
kubectl logs -n tracing -l app=otel-collector | grep "Exporting traces"

# Check Jaeger collector
kubectl logs -n tracing jaeger-0 | grep -i error

# Verify endpoint configuration
# Ensure OTEL_EXPORTER_OTLP_ENDPOINT is correct
```

#### Issue 2: Missing Spans

```text
Causes:
- Context not propagated
- Different trace context format
- Service not instrumented

Solutions:
1. Verify propagators match (W3C vs B3)
2. Check instrumentation is applied
3. Verify context is passed in HTTP headers
```

#### Issue 3: High Span Cardinality

```text
Causes:
- Including dynamic values in span names
- Too many attributes

Solutions:
1. Use static operation names
2. Put dynamic values in attributes, not names
3. Use attribute processors to filter
```

#### Issue 4: Trace Gaps

```text
When spans don't connect:
1. Check parent span context is passed
2. Verify trace ID matches
3. Check time synchronization between services
```

---

## Summary

In this lab, you learned:

1. **Tracing Concepts**: Traces, spans, and context propagation
2. **Jaeger Deployment**: Installing trace collection backend
3. **OpenTelemetry**: Collector and instrumentation
4. **Trace Analysis**: Finding and debugging issues
5. **Sampling**: Controlling trace volume
6. **Integration**: Connecting traces with metrics and logs

---

## What's Next?

Continue to [Lab 5: Alerting](../lab-05-alerting/README.md) to learn:

- Configuring Alertmanager
- Creating effective alert rules
- Setting up notification channels
- Alert routing and grouping
