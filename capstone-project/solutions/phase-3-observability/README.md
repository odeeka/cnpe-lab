# Phase 3: Observability Solutions

This directory contains the observability stack configuration for the BookStore application.

## Directory Structure

```
phase-3-observability/
├── prometheus/
│   ├── prometheus-config.yaml     # Prometheus configuration
│   ├── servicemonitors.yaml       # ServiceMonitor definitions
│   └── alerting-rules.yaml        # Alert rules
├── grafana/
│   ├── datasources.yaml           # Grafana datasources
│   └── dashboards/                # Dashboard configurations
├── loki/
│   └── loki-config.yaml           # Loki logging configuration
└── tracing/
    └── jaeger-config.yaml         # Jaeger distributed tracing
```

## Quick Deploy

```bash
# Install Prometheus Stack using Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --values prometheus/values.yaml

# Install Loki Stack
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace observability \
  --values loki/values.yaml

# Apply custom ServiceMonitors
kubectl apply -f prometheus/servicemonitors.yaml

# Import Grafana dashboards
kubectl apply -f grafana/dashboards/
```
