# Module 4: Observability & Monitoring

## Overview

This module covers the three pillars of observability: metrics, logs, and traces. You'll learn to implement comprehensive monitoring solutions using industry-standard tools like Prometheus, Grafana, Loki, and OpenTelemetry.

## Learning Objectives

By the end of this module, you will be able to:

- Deploy and configure Prometheus for metrics collection
- Create informative Grafana dashboards
- Implement centralized logging with Loki
- Set up distributed tracing with Jaeger and OpenTelemetry
- Configure alerting with Alertmanager
- Build comprehensive observability for Kubernetes workloads

## Prerequisites

- Completed Module 1: Kubernetes Fundamentals
- Completed Module 2: GitOps & Continuous Delivery
- Completed Module 3: CI/CD Pipelines
- Running Kubernetes cluster
- Basic understanding of YAML

## Duration

Estimated time: 10-14 hours

---

## The Three Pillars of Observability

```text
┌─────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐        │
│   │   METRICS   │    │    LOGS     │    │   TRACES    │        │
│   │             │    │             │    │             │        │
│   │ Prometheus  │    │    Loki     │    │   Jaeger    │        │
│   │  Grafana    │    │  Promtail   │    │   Tempo     │        │
│   │             │    │             │    │ OpenTelemetry│        │
│   └─────────────┘    └─────────────┘    └─────────────┘        │
│         │                  │                  │                 │
│         ▼                  ▼                  ▼                 │
│   ┌─────────────────────────────────────────────────────┐      │
│   │              UNIFIED DASHBOARD (Grafana)             │      │
│   └─────────────────────────────────────────────────────┘      │
│                           │                                     │
│                           ▼                                     │
│   ┌─────────────────────────────────────────────────────┐      │
│   │              ALERTING (Alertmanager)                 │      │
│   └─────────────────────────────────────────────────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Module Structure

### Lab 1: Prometheus Fundamentals

Deploy Prometheus and learn metrics collection:

- Prometheus architecture
- PromQL query language
- Service discovery
- Recording rules
- Metrics types (counter, gauge, histogram, summary)

### Lab 2: Grafana Dashboards

Create effective visualizations:

- Dashboard design principles
- Panel types and configurations
- Variables and templating
- Dashboard provisioning
- Sharing and embedding

### Lab 3: Logging with Loki

Implement centralized logging:

- Loki architecture
- Promtail configuration
- LogQL queries
- Log aggregation patterns
- Correlation with metrics

### Lab 4: Distributed Tracing

Trace requests across services:

- OpenTelemetry introduction
- Jaeger deployment
- Trace instrumentation
- Context propagation
- Trace analysis

### Lab 5: Alerting & Incident Response

Configure effective alerting:

- Alertmanager setup
- Alert rules and routing
- Notification channels
- Alert grouping and inhibition
- Runbooks and documentation

### Lab 6: Advanced Observability

Production-ready patterns:

- Service Level Objectives (SLOs)
- Custom metrics instrumentation
- Observability for CI/CD
- Cost optimization
- Multi-cluster monitoring

---

## Tools Covered

| Tool | Purpose | Category |
|------|---------|----------|
| Prometheus | Metrics collection and storage | Metrics |
| Grafana | Visualization and dashboards | Visualization |
| Loki | Log aggregation | Logs |
| Promtail | Log shipping | Logs |
| Jaeger | Distributed tracing | Traces |
| Tempo | Trace storage | Traces |
| OpenTelemetry | Telemetry collection | All |
| Alertmanager | Alert routing | Alerting |

---

## Assessment

After completing all labs, test your knowledge with the [Assessment](./assessment/README.md) which includes:

- 20 practical observability tasks
- Dashboard creation challenges
- Alert configuration scenarios
- Troubleshooting exercises
- Passing score: 70%

---

## Quick Reference

Use the [Quick Reference](./QUICK-REFERENCE.md) during and after the labs for:

- PromQL query syntax
- LogQL query syntax
- Grafana dashboard JSON
- Alert rule templates
- Common patterns and commands

---

## Getting Started

Begin with [Lab 1: Prometheus Fundamentals](./lab-01-prometheus/README.md)

---

## Key Concepts Preview

### Metrics

```text
# Prometheus metric types

Counter:    http_requests_total{method="GET", status="200"} 1234
            ↑ Only increases (requests, errors, bytes)

Gauge:      node_memory_used_bytes 1073741824
            ↑ Can increase or decrease (memory, CPU, temperature)

Histogram:  http_request_duration_seconds_bucket{le="0.1"} 50000
            ↑ Observations in buckets (latency, sizes)

Summary:    http_request_duration_seconds{quantile="0.99"} 0.234
            ↑ Pre-computed quantiles (similar to histogram)
```

### Logs

```text
# Loki log entry format

{app="frontend", env="prod"} 2024-01-15T10:30:00Z level=info msg="Request processed" duration=0.045s
      ↑ Labels                ↑ Timestamp              ↑ Log line content
```

### Traces

```text
# Distributed trace structure

[Trace ID: abc123]
├── [Span: frontend] 150ms
│   ├── [Span: api-gateway] 120ms
│   │   ├── [Span: user-service] 30ms
│   │   └── [Span: order-service] 80ms
│   │       └── [Span: database] 50ms
│   └── [Span: cache-lookup] 5ms
```

---

## Connection to Other Modules

```text
Module 1: K8s Fundamentals     → Monitor Kubernetes resources
Module 2: GitOps               → Observe ArgoCD deployments
Module 3: CI/CD                → Track pipeline metrics
Module 4: Observability        → THIS MODULE
Module 5: Security             → Security monitoring
Module 6: Service Mesh         → Mesh observability
Module 7: Autoscaling          → Metrics-driven scaling
Module 8: Disaster Recovery    → Health monitoring
```

---

## What You'll Build

By the end of this module, you'll have:

1. **Complete monitoring stack** with Prometheus, Grafana, and Alertmanager
2. **Centralized logging** with Loki and Promtail
3. **Distributed tracing** with Jaeger and OpenTelemetry
4. **Production dashboards** for Kubernetes and applications
5. **Alert configurations** with proper routing and escalation
6. **SLO definitions** with error budget tracking

Let's begin! → [Lab 1: Prometheus Fundamentals](./lab-01-prometheus/README.md)
