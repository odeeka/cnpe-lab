# Lab 2: Grafana Dashboards

## Introduction

Grafana is the leading open-source platform for monitoring and observability visualization. In this lab, you'll learn to create effective dashboards, use variables for dynamic filtering, and implement dashboard-as-code practices.

## Learning Objectives

After completing this lab, you will be able to:

- Navigate and configure Grafana
- Create dashboards with various panel types
- Use variables for dynamic dashboards
- Implement dashboard provisioning
- Design effective visualizations
- Share and export dashboards

## Prerequisites

- Completed Lab 1: Prometheus Fundamentals
- Running Prometheus with Grafana (kube-prometheus-stack)
- Access to Grafana UI

## Duration

Estimated time: 90-120 minutes

---

## Exercise 1: Grafana Basics

### Step 1: Access Grafana

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &

# Access in browser
# URL: http://localhost:3000
# Default credentials: admin / admin123 (or prom-operator if using defaults)
```

### Step 2: Grafana Interface Overview

```text
┌─────────────────────────────────────────────────────────────────┐
│                      GRAFANA INTERFACE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ [≡] Home    Search    [+] Create    Dashboards    Admin  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌─────────────┐  ┌────────────────────────────────────────┐   │
│  │             │  │                                        │   │
│  │  Sidebar    │  │           Dashboard Area               │   │
│  │             │  │                                        │   │
│  │  - Home     │  │  ┌──────────┐  ┌──────────┐           │   │
│  │  - Search   │  │  │  Panel   │  │  Panel   │           │   │
│  │  - Starred  │  │  │    1     │  │    2     │           │   │
│  │  - Dashboards│ │  └──────────┘  └──────────┘           │   │
│  │  - Explore  │  │                                        │   │
│  │  - Alerting │  │  ┌──────────┐  ┌──────────┐           │   │
│  │  - Config   │  │  │  Panel   │  │  Panel   │           │   │
│  │  - Admin    │  │  │    3     │  │    4     │           │   │
│  │             │  │  └──────────┘  └──────────┘           │   │
│  └─────────────┘  └────────────────────────────────────────┘   │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Time Range: [Last 1 hour ▼]    Refresh: [5s ▼]  [↻]     │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3: Explore Data Sources

```bash
# Navigate to Configuration → Data Sources
# Prometheus should be pre-configured

# Verify connection
# Click on Prometheus data source → "Test" button
```

### Step 4: Use Explore Feature

The Explore feature is useful for ad-hoc queries:

1. Click **Explore** in sidebar
2. Select **Prometheus** data source
3. Try these queries:

```promql
# Simple metric
up

# Rate query
rate(node_cpu_seconds_total{mode="idle"}[5m])

# With legend formatting
sum by (instance) (rate(node_cpu_seconds_total{mode!="idle"}[5m]))
```

### Validation 1

Verify Grafana access:

```bash
# Check Grafana is running
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

# Verify data source
curl -s -u admin:admin123 http://localhost:3000/api/datasources | jq '.[].name'

# Should show "Prometheus"
```

---

## Exercise 2: Creating Your First Dashboard

### Step 1: Create New Dashboard

1. Click **+** → **Dashboard**
2. Click **Add visualization**
3. Select **Prometheus** data source

### Step 2: Create CPU Usage Panel

Configure the panel:

**Query**:

```promql
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Panel Settings**:

- Title: `CPU Usage`
- Description: `CPU usage percentage per node`
- Visualization: `Time series`

**Legend**:

- Mode: `Table`
- Placement: `Bottom`
- Values: `Last`, `Max`, `Mean`

**Axes**:

- Unit: `Percent (0-100)`
- Min: `0`
- Max: `100`

### Step 3: Create Memory Usage Panel

Add another panel with:

**Query**:

```promql
100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))
```

**Panel Settings**:

- Title: `Memory Usage`
- Visualization: `Gauge`

**Thresholds**:

- Base: Green
- 70: Yellow
- 85: Red

### Step 4: Create Stat Panel

Add a stat panel for quick metrics:

**Query**:

```promql
count(kube_pod_info)
```

**Panel Settings**:

- Title: `Total Pods`
- Visualization: `Stat`
- Calculation: `Last`
- Color mode: `Value`

### Step 5: Save Dashboard

1. Click the **Save** icon (disk)
2. Enter name: `Cluster Overview`
3. Choose folder: `General`
4. Click **Save**

### Validation 2

Verify dashboard creation:

```bash
# List dashboards via API
curl -s -u admin:admin123 http://localhost:3000/api/search?type=dash-db | jq '.[].title'

# Should include "Cluster Overview"
```

---

## Exercise 3: Panel Types and Visualizations

### Step 1: Time Series Panel

Best for metrics over time:

```promql
# Network traffic
rate(node_network_receive_bytes_total[5m])
```

Options:

- Draw modes: Lines, Bars, Points
- Line interpolation: Smooth, Linear, Step
- Fill opacity: 0-100
- Stacking: Normal, 100%

### Step 2: Gauge Panel

Best for current values with thresholds:

```promql
# Disk usage
100 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} * 100)
```

Options:

- Show threshold labels
- Show threshold markers
- Text size modes

### Step 3: Stat Panel

Best for single values:

```promql
# Uptime
time() - process_start_time_seconds{job="prometheus"}
```

Options:

- Calculation: Last, Mean, Max, Min, Total
- Color mode: Value, Background
- Graph mode: None, Area

### Step 4: Table Panel

Best for detailed data:

```promql
# Pod information
kube_pod_info
```

Options:

- Transform: Filter, Organize, Reduce
- Cell display: Colored text, Colored background
- Column filtering

### Step 5: Bar Gauge Panel

Best for comparing values:

```promql
# Namespace CPU usage
sum by (namespace) (rate(container_cpu_usage_seconds_total{container!=""}[5m]))
```

Options:

- Orientation: Horizontal, Vertical
- Display mode: Basic, Retro LCD
- Show unfilled area

### Step 6: Pie Chart Panel

Best for proportions:

```promql
# Pods per namespace
count by (namespace) (kube_pod_info)
```

Options:

- Pie chart type: Pie, Donut
- Labels: Name, Percent, Value
- Legend placement

### Step 7: Heatmap Panel

Best for distribution over time:

```promql
# Request latency distribution
sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
```

Options:

- Calculate from: Raw data, Buckets
- Cell display: Color
- Y-axis: Buckets

### Step 8: Create Comprehensive Panel Layout

Create a dashboard with this layout:

```text
┌─────────────────────────────────────────────────────────────────┐
│                    Cluster Overview Dashboard                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐    │
│  │   Pods    │  │   Nodes   │  │ CPU Total │  │ Mem Total │    │
│  │   [Stat]  │  │   [Stat]  │  │   [Stat]  │  │   [Stat]  │    │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘    │
│                                                                  │
│  ┌─────────────────────────────┐  ┌─────────────────────────┐  │
│  │       CPU Usage             │  │      Memory Usage       │  │
│  │     [Time Series]           │  │     [Time Series]       │  │
│  │                             │  │                         │  │
│  └─────────────────────────────┘  └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────┐  ┌─────────────────────────┐  │
│  │     Network I/O             │  │      Disk Usage         │  │
│  │     [Time Series]           │  │      [Bar Gauge]        │  │
│  │                             │  │                         │  │
│  └─────────────────────────────┘  └─────────────────────────┘  │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                  Pods by Namespace [Table]               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Validation 3

Create all panels and verify they display data:

```bash
# Open dashboard in browser
# Verify all panels show data
# Test time range changes
# Test refresh
```

---

## Exercise 4: Variables and Templating

### Step 1: Understanding Variables

Variables make dashboards dynamic and reusable:

```text
Variable Types:
- Query: Values from data source query
- Custom: Manually defined values
- Text box: User input
- Constant: Fixed value
- Data source: List of data sources
- Interval: Time interval values
- Ad hoc filters: Key-value filters
```

### Step 2: Create Namespace Variable

1. Go to Dashboard Settings → Variables → New variable

```yaml
Name: namespace
Label: Namespace
Type: Query
Data source: Prometheus
Query: label_values(kube_pod_info, namespace)
Regex: 
Sort: Alphabetical (asc)
Multi-value: true
Include All option: true
```

### Step 3: Create Node Variable

```yaml
Name: node
Label: Node
Type: Query
Data source: Prometheus
Query: label_values(kube_node_info, node)
Sort: Alphabetical (asc)
Multi-value: true
Include All option: true
```

### Step 4: Create Interval Variable

```yaml
Name: interval
Label: Interval
Type: Interval
Values: 1m,5m,10m,30m,1h,6h,12h,1d
Auto option: true
Min interval: 1m
```

### Step 5: Use Variables in Queries

Update panel queries to use variables:

```promql
# CPU by namespace
sum by (namespace) (
  rate(container_cpu_usage_seconds_total{
    namespace=~"$namespace",
    container!=""
  }[5m])
)

# Memory by namespace
sum by (namespace) (
  container_memory_usage_bytes{
    namespace=~"$namespace",
    container!=""
  }
)

# Pod count by namespace
count by (namespace) (
  kube_pod_info{namespace=~"$namespace"}
)

# Node metrics
100 - (avg by (instance) (
  irate(node_cpu_seconds_total{
    mode="idle",
    instance=~"$node.*"
  }[$interval])
) * 100)
```

### Step 6: Variable Chaining

Create dependent variables:

```yaml
# First variable: namespace
Name: namespace
Query: label_values(kube_pod_info, namespace)

# Dependent variable: pod
Name: pod
Query: label_values(kube_pod_info{namespace=~"$namespace"}, pod)
# This updates when namespace changes
```

### Step 7: Ad-hoc Filters

Enable ad-hoc filters for flexible filtering:

```yaml
Name: Filters
Type: Ad hoc filters
Data source: Prometheus
```

Usage in queries:

- Automatically adds label filters
- No query modification needed

### Validation 4

Test variable functionality:

```bash
# Open dashboard
# Change namespace dropdown
# Verify panels update
# Test multi-select
# Test "All" option
```

---

## Exercise 5: Dashboard Provisioning

### Step 1: Understanding Provisioning

```text
Dashboard as Code Benefits:
- Version control
- Consistent deployments
- GitOps integration
- Automated updates
- Disaster recovery
```

### Step 2: Export Dashboard JSON

1. Open dashboard
2. Click Settings → JSON Model
3. Copy JSON
4. Or use API:

```bash
# Get dashboard by uid
curl -s -u admin:admin123 http://localhost:3000/api/dashboards/uid/<dashboard-uid> | jq '.dashboard' > dashboard.json
```

### Step 3: Create Dashboard ConfigMap

```yaml
# dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-overview-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  cluster-overview.json: |
    {
      "annotations": {
        "list": []
      },
      "editable": true,
      "fiscalYearStartMonth": 0,
      "graphTooltip": 0,
      "id": null,
      "links": [],
      "liveNow": false,
      "panels": [
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "palette-classic"
              },
              "custom": {
                "axisCenteredZero": false,
                "axisColorMode": "text",
                "axisLabel": "",
                "axisPlacement": "auto",
                "barAlignment": 0,
                "drawStyle": "line",
                "fillOpacity": 10,
                "gradientMode": "none",
                "hideFrom": {
                  "legend": false,
                  "tooltip": false,
                  "viz": false
                },
                "lineInterpolation": "smooth",
                "lineWidth": 2,
                "pointSize": 5,
                "scaleDistribution": {
                  "type": "linear"
                },
                "showPoints": "never",
                "spanNulls": false,
                "stacking": {
                  "group": "A",
                  "mode": "none"
                },
                "thresholdsStyle": {
                  "mode": "off"
                }
              },
              "mappings": [],
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "yellow",
                    "value": 70
                  },
                  {
                    "color": "red",
                    "value": 85
                  }
                ]
              },
              "unit": "percent"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 0,
            "y": 0
          },
          "id": 1,
          "options": {
            "legend": {
              "calcs": ["mean", "max", "last"],
              "displayMode": "table",
              "placement": "bottom",
              "showLegend": true
            },
            "tooltip": {
              "mode": "multi",
              "sort": "desc"
            }
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "expr": "100 - (avg by (instance) (irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
              "legendFormat": "{{instance}}",
              "refId": "A"
            }
          ],
          "title": "CPU Usage",
          "type": "timeseries"
        },
        {
          "datasource": {
            "type": "prometheus",
            "uid": "prometheus"
          },
          "fieldConfig": {
            "defaults": {
              "color": {
                "mode": "thresholds"
              },
              "mappings": [],
              "max": 100,
              "min": 0,
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {
                    "color": "green",
                    "value": null
                  },
                  {
                    "color": "yellow",
                    "value": 70
                  },
                  {
                    "color": "red",
                    "value": 85
                  }
                ]
              },
              "unit": "percent"
            },
            "overrides": []
          },
          "gridPos": {
            "h": 8,
            "w": 12,
            "x": 12,
            "y": 0
          },
          "id": 2,
          "options": {
            "orientation": "auto",
            "reduceOptions": {
              "calcs": ["lastNotNull"],
              "fields": "",
              "values": false
            },
            "showThresholdLabels": false,
            "showThresholdMarkers": true
          },
          "targets": [
            {
              "datasource": {
                "type": "prometheus",
                "uid": "prometheus"
              },
              "expr": "100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))",
              "legendFormat": "{{instance}}",
              "refId": "A"
            }
          ],
          "title": "Memory Usage",
          "type": "gauge"
        }
      ],
      "refresh": "30s",
      "schemaVersion": 38,
      "style": "dark",
      "tags": ["kubernetes", "infrastructure"],
      "templating": {
        "list": []
      },
      "time": {
        "from": "now-1h",
        "to": "now"
      },
      "timepicker": {},
      "timezone": "browser",
      "title": "Cluster Overview",
      "uid": "cluster-overview",
      "version": 1
    }
```

### Step 4: Apply Dashboard ConfigMap

```bash
# Apply the ConfigMap
kubectl apply -f dashboard-configmap.yaml

# Grafana sidecar will pick it up automatically
# Wait a few seconds and refresh Grafana
```

### Step 5: Helm-based Provisioning

Configure in Helm values:

```yaml
# grafana-values.yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: 'default'
          orgId: 1
          folder: 'Provisioned'
          type: file
          disableDeletion: true
          editable: false
          options:
            path: /var/lib/grafana/dashboards/default

  dashboards:
    default:
      node-exporter:
        gnetId: 1860
        revision: 30
        datasource: Prometheus
      
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
```

### Step 6: Grafana Dashboard Library

Import popular dashboards from Grafana.com:

```text
Recommended Dashboards:

Node Exporter Full:     ID: 1860
Kubernetes Cluster:     ID: 7249
Kubernetes Pods:        ID: 6417
ArgoCD Dashboard:       ID: 14584
Tekton Dashboard:       ID: 16653
```

Import via UI:

1. Click **+** → **Import**
2. Enter dashboard ID
3. Select data source
4. Click **Import**

### Validation 5

Verify provisioned dashboards:

```bash
# Check ConfigMap
kubectl get configmap -n monitoring -l grafana_dashboard=1

# List dashboards via API
curl -s -u admin:admin123 http://localhost:3000/api/search | jq '.[].title'

# Verify dashboard loads correctly in UI
```

---

## Exercise 6: Advanced Dashboard Features

### Step 1: Annotations

Add event markers to graphs:

```yaml
# In dashboard JSON annotations section
{
  "annotations": {
    "list": [
      {
        "datasource": "-- Grafana --",
        "enable": true,
        "hide": false,
        "iconColor": "rgba(0, 211, 255, 1)",
        "name": "Deployments",
        "type": "dashboard"
      },
      {
        "datasource": "Prometheus",
        "enable": true,
        "expr": "changes(kube_deployment_status_observed_generation[5m]) > 0",
        "iconColor": "blue",
        "name": "K8s Deployments",
        "titleFormat": "Deployment"
      }
    ]
  }
}
```

### Step 2: Links

Add navigation links:

```yaml
# Dashboard links
{
  "links": [
    {
      "asDropdown": false,
      "icon": "external link",
      "includeVars": true,
      "keepTime": true,
      "tags": ["kubernetes"],
      "targetBlank": true,
      "title": "Related Dashboards",
      "type": "dashboards"
    },
    {
      "icon": "doc",
      "tags": [],
      "targetBlank": true,
      "title": "Documentation",
      "type": "link",
      "url": "https://wiki.example.com/monitoring"
    }
  ]
}
```

### Step 3: Row Organization

Organize panels into collapsible rows:

```yaml
# Row panel
{
  "collapsed": false,
  "gridPos": {
    "h": 1,
    "w": 24,
    "x": 0,
    "y": 0
  },
  "id": 100,
  "panels": [],
  "title": "Cluster Health",
  "type": "row"
}
```

### Step 4: Thresholds and Overrides

Configure field overrides:

```yaml
# Field overrides example
{
  "fieldConfig": {
    "defaults": {
      "thresholds": {
        "mode": "absolute",
        "steps": [
          { "color": "green", "value": null },
          { "color": "yellow", "value": 70 },
          { "color": "red", "value": 85 }
        ]
      }
    },
    "overrides": [
      {
        "matcher": {
          "id": "byName",
          "options": "Critical Service"
        },
        "properties": [
          {
            "id": "thresholds",
            "value": {
              "mode": "absolute",
              "steps": [
                { "color": "green", "value": null },
                { "color": "red", "value": 50 }
              ]
            }
          }
        ]
      }
    ]
  }
}
```

### Step 5: Transformations

Apply data transformations:

1. Add transformation in panel edit
2. Available transformations:

```text
- Reduce: Aggregate multiple series
- Merge: Combine data from multiple queries
- Filter by name: Filter series
- Organize fields: Rename, reorder, hide
- Join by field: Combine tables
- Group by: Group and aggregate
- Sort by: Order results
- Limit: Limit number of results
```

Example - Join metrics:

```yaml
# Query A: Pod CPU
sum by (pod) (rate(container_cpu_usage_seconds_total{namespace="default"}[5m]))

# Query B: Pod Memory
sum by (pod) (container_memory_usage_bytes{namespace="default"})

# Transformation: Join by field "pod"
```

### Step 6: Repeated Panels

Create panels dynamically from variables:

1. Create variable with multi-value enabled
2. In panel options:

```yaml
Repeat options:
  Repeat by variable: namespace
  Direction: Horizontal
  Max per row: 4
```

### Validation 6

Verify advanced features:

```bash
# Open dashboard with annotations
# Verify annotations appear on timeline

# Test row collapsing
# Verify transformations work

# Test repeated panels with multi-value variable
```

---

## Exercise 7: Best Practices

### Step 1: Dashboard Design Principles

```text
┌─────────────────────────────────────────────────────────────────┐
│                 DASHBOARD DESIGN PRINCIPLES                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. HIERARCHY                                                   │
│     ├── Most important metrics at top                           │
│     ├── Summary stats → Details                                 │
│     └── Use rows to group related panels                        │
│                                                                  │
│  2. CONSISTENCY                                                 │
│     ├── Consistent color schemes                                │
│     ├── Same units for similar metrics                          │
│     └── Standard panel sizes                                    │
│                                                                  │
│  3. CLARITY                                                     │
│     ├── Descriptive titles                                      │
│     ├── Add descriptions to panels                              │
│     └── Use appropriate visualizations                          │
│                                                                  │
│  4. PERFORMANCE                                                 │
│     ├── Limit number of panels                                  │
│     ├── Use recording rules for complex queries                 │
│     └── Set appropriate refresh intervals                       │
│                                                                  │
│  5. USABILITY                                                   │
│     ├── Variables for filtering                                 │
│     ├── Links to related dashboards                             │
│     └── Drill-down capabilities                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2: Color Scheme Best Practices

```text
Standard Colors:
- Green:  Good / Normal / Healthy
- Yellow: Warning / Degraded
- Orange: Concerning / High
- Red:    Critical / Error / Unhealthy
- Blue:   Informational / Neutral
- Purple: Unusual / Special attention

Threshold Guidelines:
- CPU:    <70% Green, 70-85% Yellow, >85% Red
- Memory: <70% Green, 70-85% Yellow, >85% Red
- Disk:   <80% Green, 80-90% Yellow, >90% Red
- Errors: 0 Green, >0 Red
```

### Step 3: Panel Size Guidelines

```text
Stat/Gauge panels:   4-6 width, 3-4 height
Time series panels:  12-24 width, 8-12 height
Table panels:        12-24 width, 8-16 height
Heatmaps:           12-24 width, 8-12 height
Pie charts:         6-12 width, 6-8 height
```

### Step 4: Documentation Template

Create a dashboard documentation panel:

```yaml
# Text panel (markdown)
{
  "type": "text",
  "title": "Dashboard Info",
  "options": {
    "mode": "markdown",
    "content": "## Cluster Overview Dashboard\n\n**Purpose:** Monitor overall cluster health\n\n**Owner:** Platform Team\n\n**Metrics Source:** Prometheus\n\n**Related Dashboards:**\n- [Node Details](link)\n- [Pod Details](link)\n\n**Runbook:** [Link to runbook](url)"
  }
}
```

### Validation 7

Review your dashboard against best practices:

```bash
# Checklist:
# □ Clear hierarchy with summary at top
# □ Consistent colors and themes
# □ Descriptive panel titles
# □ Variables for filtering
# □ Appropriate visualizations
# □ Reasonable number of panels
# □ Documentation panel
```

---

## Troubleshooting

### Common Issues

#### Issue 1: No Data in Panel

```text
Causes:
1. Wrong data source selected
2. Query syntax error
3. Time range doesn't have data
4. Metric doesn't exist

Solutions:
1. Check data source in panel
2. Test query in Explore
3. Adjust time range
4. Verify metric in Prometheus
```

#### Issue 2: Dashboard Not Showing After Provisioning

```bash
# Check ConfigMap labels
kubectl get configmap -n monitoring -l grafana_dashboard=1

# Check Grafana sidecar logs
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana -c grafana-sc-dashboard

# Verify JSON is valid
cat dashboard.json | jq .
```

#### Issue 3: Variables Not Working

```text
Solutions:
1. Test query in Explore
2. Check regex filter
3. Verify variable is used correctly: $variable or ${variable}
4. Check multi-value setting matches query syntax
```

#### Issue 4: Slow Dashboard Loading

```text
Solutions:
1. Use recording rules for complex queries
2. Reduce number of panels
3. Increase step interval for long time ranges
4. Check data source query limits
```

---

## Summary

In this lab, you learned:

1. **Grafana Navigation**: Interface and data sources
2. **Panel Types**: Time series, gauge, stat, table, and more
3. **Variables**: Dynamic dashboards with templating
4. **Provisioning**: Dashboard as code practices
5. **Advanced Features**: Annotations, links, transformations
6. **Best Practices**: Design principles for effective dashboards

---

## What's Next?

Continue to [Lab 3: Logging with Loki](../lab-03-loki/README.md) to learn:

- Deploying Loki for log aggregation
- Configuring Promtail for log shipping
- Writing LogQL queries
- Correlating logs with metrics
