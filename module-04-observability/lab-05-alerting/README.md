# Lab 5: Alerting and Incident Response

## Introduction

Effective alerting is the bridge between observability data and human action. This lab teaches you to configure Alertmanager, design meaningful alerts, implement notification routing, and establish incident response workflows that minimize mean time to recovery (MTTR).

## Prerequisites

- Completed Lab 1: Prometheus Fundamentals
- Completed Lab 4: Distributed Tracing
- Running Prometheus installation
- Access to notification channels (Slack, email, or webhook endpoint)
- Understanding of SLIs and error budgets

## Learning Objectives

By the end of this lab, you will be able to:

- Configure Alertmanager for production environments
- Design alert rules that minimize noise and maximize signal
- Implement routing trees for multi-team organizations
- Create notification templates and receivers
- Handle alert grouping, inhibition, and silencing
- Build incident response runbooks
- Integrate alerting with on-call systems

## Alerting Architecture

### The Alerting Pipeline

```
┌─────────────┐     ┌─────────────────┐     ┌──────────────┐
│  Prometheus │────▶│  Alertmanager   │────▶│  Receivers   │
│   (Rules)   │     │  (Routing)      │     │  (Notify)    │
└─────────────┘     └─────────────────┘     └──────────────┘
       │                    │                      │
       │                    │                      │
   Evaluate             Group &               Slack, Email
   Conditions           Dedupe                PagerDuty, etc.
```

### Alertmanager Components

```yaml
# Alertmanager high-availability deployment
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      # Global configuration applied to all receivers
      resolve_timeout: 5m
      smtp_smarthost: 'smtp.example.com:587'
      smtp_from: 'alertmanager@example.com'
      smtp_auth_username: 'alertmanager@example.com'
      smtp_auth_password_file: /etc/alertmanager/secrets/smtp-password
      slack_api_url_file: /etc/alertmanager/secrets/slack-webhook
      pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'
      
    # Templates for notifications
    templates:
      - '/etc/alertmanager/templates/*.tmpl'
    
    # Routing tree
    route:
      receiver: 'default-receiver'
      group_by: ['alertname', 'cluster', 'namespace']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - match:
            severity: critical
          receiver: 'pagerduty-critical'
          continue: true
        - match:
            severity: warning
          receiver: 'slack-warnings'
    
    # Inhibition rules
    inhibit_rules:
      - source_match:
          severity: 'critical'
        target_match:
          severity: 'warning'
        equal: ['alertname', 'cluster', 'namespace']
    
    # Receivers define notification channels
    receivers:
      - name: 'default-receiver'
        email_configs:
          - to: 'team@example.com'
      
      - name: 'pagerduty-critical'
        pagerduty_configs:
          - service_key_file: /etc/alertmanager/secrets/pagerduty-key
            severity: critical
            description: '{{ .CommonAnnotations.summary }}'
            details:
              firing: '{{ template "pagerduty.firing" . }}'
              num_firing: '{{ .Alerts.Firing | len }}'
              num_resolved: '{{ .Alerts.Resolved | len }}'
      
      - name: 'slack-warnings'
        slack_configs:
          - channel: '#alerts-warning'
            send_resolved: true
            title: '{{ template "slack.title" . }}'
            text: '{{ template "slack.text" . }}'
            actions:
              - type: button
                text: 'Runbook'
                url: '{{ (index .Alerts 0).Annotations.runbook_url }}'
              - type: button
                text: 'Dashboard'
                url: '{{ (index .Alerts 0).Annotations.dashboard_url }}'
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  serviceName: alertmanager
  replicas: 3
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
        - name: alertmanager
          image: prom/alertmanager:v0.26.0
          args:
            - '--config.file=/etc/alertmanager/alertmanager.yml'
            - '--storage.path=/alertmanager'
            - '--cluster.listen-address=0.0.0.0:9094'
            - '--cluster.peer=alertmanager-0.alertmanager:9094'
            - '--cluster.peer=alertmanager-1.alertmanager:9094'
            - '--cluster.peer=alertmanager-2.alertmanager:9094'
          ports:
            - containerPort: 9093
              name: http
            - containerPort: 9094
              name: cluster
          volumeMounts:
            - name: config
              mountPath: /etc/alertmanager
            - name: secrets
              mountPath: /etc/alertmanager/secrets
              readOnly: true
            - name: storage
              mountPath: /alertmanager
          livenessProbe:
            httpGet:
              path: /-/healthy
              port: 9093
            initialDelaySeconds: 10
          readinessProbe:
            httpGet:
              path: /-/ready
              port: 9093
      volumes:
        - name: config
          configMap:
            name: alertmanager-config
        - name: secrets
          secret:
            secretName: alertmanager-secrets
  volumeClaimTemplates:
    - metadata:
        name: storage
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

## Designing Effective Alert Rules

### Alert Rule Structure

```yaml
# PrometheusRule CRD for alert definitions
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: application-alerts
  namespace: monitoring
  labels:
    prometheus: k8s
    role: alert-rules
spec:
  groups:
    - name: application.rules
      interval: 30s
      rules:
        # High Error Rate Alert
        - alert: HighErrorRate
          expr: |
            (
              sum(rate(http_requests_total{status=~"5.."}[5m])) by (service, namespace)
              /
              sum(rate(http_requests_total[5m])) by (service, namespace)
            ) > 0.05
          for: 5m
          labels:
            severity: critical
            team: platform
          annotations:
            summary: "High error rate in {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} in namespace {{ $labels.namespace }} 
              has error rate of {{ $value | humanizePercentage }} (threshold: 5%)
            runbook_url: "https://runbooks.example.com/high-error-rate"
            dashboard_url: "https://grafana.example.com/d/service-overview?var-service={{ $labels.service }}"
        
        # Latency SLO Breach
        - alert: LatencySLOBreach
          expr: |
            histogram_quantile(0.99, 
              sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)
            ) > 1.0
          for: 10m
          labels:
            severity: warning
            team: platform
          annotations:
            summary: "P99 latency SLO breach for {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} P99 latency is {{ $value | humanizeDuration }}
              which exceeds the 1s SLO target.
            runbook_url: "https://runbooks.example.com/latency-slo"
        
        # Pod Memory Approaching Limit
        - alert: PodMemoryNearLimit
          expr: |
            (
              container_memory_working_set_bytes{container!=""}
              /
              container_spec_memory_limit_bytes{container!=""}
            ) > 0.85
          for: 15m
          labels:
            severity: warning
            team: "{{ $labels.namespace }}"
          annotations:
            summary: "Pod {{ $labels.pod }} memory near limit"
            description: |
              Pod {{ $labels.pod }} in {{ $labels.namespace }} is using 
              {{ $value | humanizePercentage }} of its memory limit.
              Consider increasing memory limits or investigating memory leaks.
        
        # Disk Space Running Low
        - alert: DiskSpaceLow
          expr: |
            (
              node_filesystem_avail_bytes{mountpoint="/"}
              /
              node_filesystem_size_bytes{mountpoint="/"}
            ) < 0.15
          for: 30m
          labels:
            severity: warning
          annotations:
            summary: "Low disk space on {{ $labels.instance }}"
            description: |
              Node {{ $labels.instance }} has only 
              {{ $value | humanizePercentage }} disk space remaining.
        
        # Disk Space Critical
        - alert: DiskSpaceCritical
          expr: |
            (
              node_filesystem_avail_bytes{mountpoint="/"}
              /
              node_filesystem_size_bytes{mountpoint="/"}
            ) < 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Critical disk space on {{ $labels.instance }}"
            description: |
              Node {{ $labels.instance }} has only 
              {{ $value | humanizePercentage }} disk space remaining.
              Immediate action required!

    - name: kubernetes.rules
      rules:
        # Pod CrashLooping
        - alert: PodCrashLooping
          expr: |
            rate(kube_pod_container_status_restarts_total[15m]) * 60 * 15 > 0
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} is crash looping"
            description: |
              Pod {{ $labels.namespace }}/{{ $labels.pod }} is restarting 
              {{ printf "%.2f" $value }} times per 15 minutes.
        
        # Deployment Replicas Mismatch
        - alert: DeploymentReplicasMismatch
          expr: |
            kube_deployment_spec_replicas
            !=
            kube_deployment_status_replicas_available
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Deployment {{ $labels.deployment }} replicas mismatch"
            description: |
              Deployment {{ $labels.namespace }}/{{ $labels.deployment }} has 
              {{ $value }} available replicas, expected 
              {{ printf "kube_deployment_spec_replicas{deployment='%s'}" $labels.deployment }}.
        
        # Node Not Ready
        - alert: NodeNotReady
          expr: |
            kube_node_status_condition{condition="Ready",status="true"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is not ready"
            description: |
              Node {{ $labels.node }} has been in NotReady state for more than 5 minutes.
        
        # Persistent Volume Almost Full
        - alert: PersistentVolumeFillingUp
          expr: |
            (
              kubelet_volume_stats_available_bytes
              /
              kubelet_volume_stats_capacity_bytes
            ) < 0.15
            and
            predict_linear(kubelet_volume_stats_available_bytes[6h], 4 * 24 * 3600) < 0
          for: 1h
          labels:
            severity: warning
          annotations:
            summary: "PersistentVolume {{ $labels.persistentvolumeclaim }} is filling up"
            description: |
              PVC {{ $labels.persistentvolumeclaim }} in {{ $labels.namespace }} is 
              {{ $value | humanizePercentage }} full and predicted to run out 
              within 4 days.

    - name: slo.rules
      rules:
        # Error Budget Burn Rate (Multi-Window)
        - alert: ErrorBudgetBurnRateFast
          expr: |
            (
              # 1h error rate
              sum(rate(http_requests_total{status=~"5.."}[1h])) by (service)
              /
              sum(rate(http_requests_total[1h])) by (service)
            ) > (14.4 * 0.001)  # 14.4x burn rate against 99.9% SLO
            and
            (
              # 5m error rate (recent confirmation)
              sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
              /
              sum(rate(http_requests_total[5m])) by (service)
            ) > (14.4 * 0.001)
          for: 2m
          labels:
            severity: critical
            slo: "true"
          annotations:
            summary: "Fast error budget burn for {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} is burning error budget at 14.4x rate.
              At this rate, the monthly error budget will be exhausted in 2 days.
        
        - alert: ErrorBudgetBurnRateSlow
          expr: |
            (
              sum(rate(http_requests_total{status=~"5.."}[6h])) by (service)
              /
              sum(rate(http_requests_total[6h])) by (service)
            ) > (1.0 * 0.001)  # 1x burn rate against 99.9% SLO
            and
            (
              sum(rate(http_requests_total{status=~"5.."}[30m])) by (service)
              /
              sum(rate(http_requests_total[30m])) by (service)
            ) > (1.0 * 0.001)
          for: 30m
          labels:
            severity: warning
            slo: "true"
          annotations:
            summary: "Slow error budget burn for {{ $labels.service }}"
            description: |
              Service {{ $labels.service }} is exceeding its error budget.
              Investigation recommended before budget exhaustion.
```

### Alert Quality Guidelines

```yaml
# Example of well-designed alerts following best practices
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: golden-signals-alerts
  namespace: monitoring
spec:
  groups:
    - name: golden-signals
      rules:
        # GOOD: Symptom-based, actionable, with context
        - alert: HighRequestLatency
          expr: |
            (
              histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))
              >
              on(service) group_left()
              (latency_slo_seconds * 1.5)
            )
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "{{ $labels.service }} latency exceeds SLO by 50%"
            description: |
              P95 latency for {{ $labels.service }}: {{ $value | humanizeDuration }}
              SLO target: {{ printf "latency_slo_seconds{service='%s'}" $labels.service }}
              
              Impact: Users experiencing degraded performance.
              
              Possible causes:
              - Increased traffic volume
              - Downstream service degradation
              - Resource constraints
              
              Investigation steps:
              1. Check current request rate vs baseline
              2. Review downstream service health
              3. Examine resource utilization (CPU, memory)
            runbook_url: "https://runbooks.example.com/high-latency"
            dashboard_url: "https://grafana.example.com/d/latency?var-service={{ $labels.service }}"
        
        # GOOD: Uses recording rules for efficiency
        - alert: ServiceAvailabilityBreach
          expr: |
            service_availability:ratio_5m < 0.999
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "{{ $labels.service }} availability below 99.9%"
            description: |
              Current availability: {{ $value | humanizePercentage }}
              
              This indicates a significant service degradation affecting users.

# Recording rules used by alerts (for efficiency)
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: recording-rules
  namespace: monitoring
spec:
  groups:
    - name: service.recording.rules
      interval: 30s
      rules:
        - record: service_availability:ratio_5m
          expr: |
            (
              1 - (
                sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
                /
                sum(rate(http_requests_total[5m])) by (service)
              )
            )
        
        - record: service_error_rate:ratio_5m
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
            /
            sum(rate(http_requests_total[5m])) by (service)
        
        - record: service_request_rate:per_second_5m
          expr: |
            sum(rate(http_requests_total[5m])) by (service)
```

## Routing and Receivers

### Complex Routing Configuration

```yaml
# Advanced routing tree for multi-team organizations
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-routing
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    
    route:
      receiver: 'default'
      group_by: ['alertname', 'cluster', 'namespace', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      
      routes:
        # Critical alerts go to PagerDuty immediately
        - match:
            severity: critical
          receiver: 'pagerduty-critical'
          group_wait: 0s
          group_interval: 1m
          repeat_interval: 1h
          continue: true  # Also send to other matching routes
        
        # Route by team based on namespace
        - match_re:
            namespace: ^(payments|billing|checkout)$
          receiver: 'team-payments'
          routes:
            - match:
                severity: critical
              receiver: 'team-payments-oncall'
        
        - match_re:
            namespace: ^(users|auth|identity)$
          receiver: 'team-identity'
          routes:
            - match:
                severity: critical
              receiver: 'team-identity-oncall'
        
        # Infrastructure alerts
        - match_re:
            alertname: ^(Node.*|Kube.*|etcd.*)$
          receiver: 'team-platform'
          routes:
            - match:
                severity: critical
              receiver: 'team-platform-oncall'
        
        # SLO alerts get special handling
        - match:
            slo: "true"
          receiver: 'slo-team'
          group_by: ['service', 'slo_name']
        
        # Business hours only for warnings
        - match:
            severity: warning
          receiver: 'slack-warnings'
          active_time_intervals:
            - business-hours
          mute_time_intervals:
            - weekends
        
        # Watchdog alert for monitoring health
        - match:
            alertname: Watchdog
          receiver: 'null'  # Suppress but use for dead man's switch
    
    # Time intervals for routing
    time_intervals:
      - name: business-hours
        time_intervals:
          - weekdays: ['monday:friday']
            times:
              - start_time: '09:00'
                end_time: '17:00'
            location: 'America/New_York'
      
      - name: weekends
        time_intervals:
          - weekdays: ['saturday', 'sunday']
    
    # Inhibition to prevent alert storms
    inhibit_rules:
      # Critical suppresses warning for same alert
      - source_match:
          severity: 'critical'
        target_match:
          severity: 'warning'
        equal: ['alertname', 'namespace', 'service']
      
      # Cluster-wide issues suppress namespace alerts
      - source_match:
          scope: 'cluster'
        target_match:
          scope: 'namespace'
        equal: ['cluster']
      
      # Node issues suppress pod alerts on that node
      - source_match:
          alertname: 'NodeNotReady'
        target_match_re:
          alertname: 'Pod.*'
        equal: ['node']
    
    receivers:
      - name: 'default'
        email_configs:
          - to: 'alerts@example.com'
            send_resolved: true
      
      - name: 'null'
        # Empty receiver for suppressed alerts
      
      - name: 'pagerduty-critical'
        pagerduty_configs:
          - service_key_file: /etc/secrets/pagerduty-key
            severity: critical
            client: 'Alertmanager'
            client_url: 'https://alertmanager.example.com'
            description: '{{ template "pagerduty.description" . }}'
            details:
              cluster: '{{ .CommonLabels.cluster }}'
              namespace: '{{ .CommonLabels.namespace }}'
              service: '{{ .CommonLabels.service }}'
      
      - name: 'team-payments'
        slack_configs:
          - api_url_file: /etc/secrets/slack-payments
            channel: '#payments-alerts'
            send_resolved: true
            title: '{{ template "slack.title" . }}'
            text: '{{ template "slack.text" . }}'
        email_configs:
          - to: 'payments-team@example.com'
      
      - name: 'team-payments-oncall'
        pagerduty_configs:
          - service_key_file: /etc/secrets/pagerduty-payments
      
      - name: 'team-identity'
        slack_configs:
          - channel: '#identity-alerts'
      
      - name: 'team-identity-oncall'
        pagerduty_configs:
          - service_key_file: /etc/secrets/pagerduty-identity
      
      - name: 'team-platform'
        slack_configs:
          - channel: '#platform-alerts'
        webhook_configs:
          - url: 'https://incident-bot.example.com/webhook'
      
      - name: 'team-platform-oncall'
        pagerduty_configs:
          - service_key_file: /etc/secrets/pagerduty-platform
      
      - name: 'slo-team'
        slack_configs:
          - channel: '#slo-breaches'
            title: 'SLO Breach'
      
      - name: 'slack-warnings'
        slack_configs:
          - channel: '#alerts-warning'
            send_resolved: true
```

### Notification Templates

```yaml
# Custom notification templates
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-templates
  namespace: monitoring
data:
  slack.tmpl: |
    {{ define "slack.title" }}
    [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] {{ .CommonLabels.alertname }}
    {{ end }}
    
    {{ define "slack.text" }}
    {{ range .Alerts }}
    *Alert:* {{ .Labels.alertname }}{{ if .Labels.severity }} - `{{ .Labels.severity }}`{{ end }}
    *Cluster:* {{ .Labels.cluster }}
    *Namespace:* {{ .Labels.namespace }}
    *Service:* {{ .Labels.service }}
    
    *Description:* {{ .Annotations.description }}
    
    *Details:*
    {{ range .Labels.SortedPairs }}  • {{ .Name }}: `{{ .Value }}`
    {{ end }}
    
    {{ if .Annotations.runbook_url }}:book: <{{ .Annotations.runbook_url }}|Runbook>{{ end }}
    {{ if .Annotations.dashboard_url }}:chart_with_upwards_trend: <{{ .Annotations.dashboard_url }}|Dashboard>{{ end }}
    
    ---
    {{ end }}
    {{ end }}
    
    {{ define "slack.color" }}
    {{ if eq .Status "firing" }}
    {{ if eq (index .Alerts 0).Labels.severity "critical" }}danger{{ else }}warning{{ end }}
    {{ else }}good{{ end }}
    {{ end }}
  
  pagerduty.tmpl: |
    {{ define "pagerduty.description" }}
    {{ range .Alerts.Firing }}
    {{ .Annotations.summary }}
    {{ end }}
    {{ end }}
    
    {{ define "pagerduty.firing" }}
    {{ range .Alerts.Firing }}
    Alert: {{ .Labels.alertname }}
    Severity: {{ .Labels.severity }}
    Namespace: {{ .Labels.namespace }}
    Description: {{ .Annotations.description }}
    Runbook: {{ .Annotations.runbook_url }}
    ---
    {{ end }}
    {{ end }}
  
  email.tmpl: |
    {{ define "email.subject" }}
    [{{ .Status | toUpper }}] {{ .GroupLabels.alertname }} - {{ .CommonLabels.cluster }}
    {{ end }}
    
    {{ define "email.html" }}
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; }
        .alert { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .critical { background-color: #f8d7da; border: 1px solid #f5c6cb; }
        .warning { background-color: #fff3cd; border: 1px solid #ffeeba; }
        .resolved { background-color: #d4edda; border: 1px solid #c3e6cb; }
        .label { display: inline-block; padding: 2px 6px; background: #e9ecef; border-radius: 3px; margin: 2px; }
      </style>
    </head>
    <body>
      <h2>{{ .Status | toUpper }}: {{ .CommonLabels.alertname }}</h2>
      
      {{ range .Alerts }}
      <div class="alert {{ .Labels.severity }}{{ if eq $.Status "resolved" }} resolved{{ end }}">
        <h3>{{ .Labels.alertname }}</h3>
        <p><strong>Severity:</strong> {{ .Labels.severity }}</p>
        <p><strong>Summary:</strong> {{ .Annotations.summary }}</p>
        <p><strong>Description:</strong> {{ .Annotations.description }}</p>
        
        <p><strong>Labels:</strong></p>
        {{ range .Labels.SortedPairs }}
        <span class="label">{{ .Name }}: {{ .Value }}</span>
        {{ end }}
        
        {{ if .Annotations.runbook_url }}
        <p><a href="{{ .Annotations.runbook_url }}">View Runbook</a></p>
        {{ end }}
      </div>
      {{ end }}
      
      <p><a href="https://alertmanager.example.com/#/alerts?filter={{ .CommonLabels | urlquery }}">View in Alertmanager</a></p>
    </body>
    </html>
    {{ end }}
```

## Silencing and Maintenance

### Managing Silences

```yaml
# Silence management via API
---
# Create silence for planned maintenance
apiVersion: batch/v1
kind: Job
metadata:
  name: create-maintenance-silence
  namespace: monitoring
spec:
  template:
    spec:
      containers:
        - name: silence-creator
          image: curlimages/curl:latest
          command:
            - /bin/sh
            - -c
            - |
              # Calculate silence times
              START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
              END=$(date -u -d "+4 hours" +"%Y-%m-%dT%H:%M:%SZ")
              
              # Create silence via Alertmanager API
              curl -X POST http://alertmanager:9093/api/v2/silences \
                -H "Content-Type: application/json" \
                -d '{
                  "matchers": [
                    {
                      "name": "namespace",
                      "value": "production",
                      "isRegex": false
                    },
                    {
                      "name": "maintenance",
                      "value": "planned",
                      "isRegex": false
                    }
                  ],
                  "startsAt": "'"$START"'",
                  "endsAt": "'"$END"'",
                  "createdBy": "maintenance-job",
                  "comment": "Planned maintenance window - Ticket: MAINT-1234"
                }'
      restartPolicy: Never
---
# Script to manage silences
apiVersion: v1
kind: ConfigMap
metadata:
  name: silence-management
  namespace: monitoring
data:
  silence.sh: |
    #!/bin/bash
    
    ALERTMANAGER_URL="${ALERTMANAGER_URL:-http://alertmanager:9093}"
    
    create_silence() {
      local matcher_name=$1
      local matcher_value=$2
      local duration=$3
      local comment=$4
      
      local start=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      local end=$(date -u -d "+${duration}" +"%Y-%m-%dT%H:%M:%SZ")
      
      curl -s -X POST "${ALERTMANAGER_URL}/api/v2/silences" \
        -H "Content-Type: application/json" \
        -d '{
          "matchers": [{"name": "'"$matcher_name"'", "value": "'"$matcher_value"'", "isRegex": false}],
          "startsAt": "'"$start"'",
          "endsAt": "'"$end"'",
          "createdBy": "'"$(whoami)"'",
          "comment": "'"$comment"'"
        }' | jq -r '.silenceID'
    }
    
    list_silences() {
      curl -s "${ALERTMANAGER_URL}/api/v2/silences" | jq '.[] | select(.status.state == "active")'
    }
    
    delete_silence() {
      local silence_id=$1
      curl -s -X DELETE "${ALERTMANAGER_URL}/api/v2/silence/${silence_id}"
    }
    
    # Usage examples:
    # create_silence "alertname" "HighErrorRate" "2h" "Investigating issue"
    # list_silences
    # delete_silence "silence-id-here"
```

### Maintenance Windows

```yaml
# Automated maintenance window handling
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-maintenance-silence
  namespace: monitoring
spec:
  schedule: "0 2 * * 0"  # Every Sunday at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: silence
              image: curlimages/curl:latest
              env:
                - name: ALERTMANAGER_URL
                  value: "http://alertmanager:9093"
              command:
                - /bin/sh
                - -c
                - |
                  # 4-hour maintenance window
                  START=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                  END=$(date -u -d "+4 hours" +"%Y-%m-%dT%H:%M:%SZ")
                  
                  curl -X POST ${ALERTMANAGER_URL}/api/v2/silences \
                    -H "Content-Type: application/json" \
                    -d '{
                      "matchers": [
                        {"name": "alertname", "value": ".*Maintenance.*", "isRegex": true}
                      ],
                      "startsAt": "'"$START"'",
                      "endsAt": "'"$END"'",
                      "createdBy": "maintenance-cronjob",
                      "comment": "Weekly maintenance window"
                    }'
          restartPolicy: OnFailure
```

## Incident Response Integration

### Runbook Structure

```yaml
# Runbook template stored in ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: runbook-templates
  namespace: monitoring
data:
  high-error-rate.md: |
    # High Error Rate Runbook
    
    ## Alert Details
    - **Alert Name:** HighErrorRate
    - **Severity:** Critical
    - **SLO Impact:** Yes - affects availability SLO
    
    ## Quick Assessment
    
    ### 1. Determine Scope
    ```bash
    # Check which services are affected
    kubectl get pods -A -l "affected=true" --field-selector=status.phase!=Running
    
    # Check recent deployments
    kubectl rollout history deployment -n <namespace>
    ```
    
    ### 2. Check Error Details
    
    #### Prometheus Query
    ```promql
    # Error rate by status code
    sum(rate(http_requests_total{status=~"5.."}[5m])) by (service, status)
    
    # Compare with baseline
    sum(rate(http_requests_total{status=~"5.."}[5m])) by (service)
    /
    sum(rate(http_requests_total{status=~"5.."}[5m] offset 1d)) by (service)
    ```
    
    #### Log Query (Loki)
    ```logql
    {namespace="<namespace>", service="<service>"} |= "error" | json | level="error"
    ```
    
    ## Diagnosis Tree
    
    ### Is it deployment-related?
    - [ ] Check if recent deployment correlates with error increase
    - [ ] Review deployment diff for changes
    - [ ] Check rollout status
    
    **If yes:** Rollback deployment
    ```bash
    kubectl rollout undo deployment/<name> -n <namespace>
    ```
    
    ### Is it resource-related?
    - [ ] Check CPU/memory usage
    - [ ] Check for OOMKilled containers
    - [ ] Check node resource pressure
    
    **If yes:** Scale up or adjust resources
    ```bash
    kubectl scale deployment/<name> --replicas=<n> -n <namespace>
    ```
    
    ### Is it dependency-related?
    - [ ] Check downstream service health
    - [ ] Check database connections
    - [ ] Check external API availability
    
    **If yes:** Check dependency runbook
    
    ## Mitigation Actions
    
    ### Immediate
    1. Acknowledge the incident
    2. Start incident channel
    3. Page additional responders if needed
    
    ### Short-term
    1. Implement temporary fix (rollback, scale, redirect)
    2. Update status page
    3. Notify affected stakeholders
    
    ### Long-term
    1. Root cause analysis
    2. Preventive measures
    3. Update runbook with learnings
    
    ## Escalation Path
    
    | Level | Contact | When |
    |-------|---------|------|
    | L1 | On-call engineer | Immediate |
    | L2 | Service owner | 15 min no progress |
    | L3 | Platform team | Infrastructure issue |
    | L4 | Management | Major incident |
    
    ## Related Resources
    - [Service Dashboard](https://grafana.example.com/d/service)
    - [Dependency Map](https://grafana.example.com/d/dependencies)
    - [Previous Incidents](https://incidents.example.com/search?alert=HighErrorRate)

  pod-crashlooping.md: |
    # Pod CrashLooping Runbook
    
    ## Alert Details
    - **Alert Name:** PodCrashLooping
    - **Severity:** Warning/Critical
    
    ## Quick Diagnosis
    
    ### 1. Get Pod Status
    ```bash
    kubectl describe pod <pod-name> -n <namespace>
    kubectl logs <pod-name> -n <namespace> --previous
    ```
    
    ### 2. Check Events
    ```bash
    kubectl get events -n <namespace> --sort-by='.lastTimestamp' | grep <pod-name>
    ```
    
    ## Common Causes
    
    ### Application Error
    - Check application logs for exceptions
    - Verify configuration is correct
    - Check secrets/configmaps are mounted
    
    ### Resource Issues
    - OOMKilled: Increase memory limits
    - CPU throttling: Increase CPU limits
    
    ### Probe Failures
    - Liveness probe failing: Check probe configuration
    - Readiness probe timing: Adjust initial delay
    
    ### Image Issues
    - ImagePullBackOff: Check registry credentials
    - Invalid image: Verify image tag exists
    
    ## Resolution Steps
    
    1. Identify root cause from logs/events
    2. Apply appropriate fix
    3. Monitor pod stability
    4. Update alerts if false positive
```

### Incident Bot Integration

```yaml
# Webhook receiver for incident management
apiVersion: apps/v1
kind: Deployment
metadata:
  name: incident-bot
  namespace: monitoring
spec:
  replicas: 2
  selector:
    matchLabels:
      app: incident-bot
  template:
    metadata:
      labels:
        app: incident-bot
    spec:
      containers:
        - name: incident-bot
          image: incident-bot:latest
          ports:
            - containerPort: 8080
          env:
            - name: SLACK_TOKEN
              valueFrom:
                secretKeyRef:
                  name: incident-bot-secrets
                  key: slack-token
            - name: JIRA_URL
              value: "https://jira.example.com"
            - name: JIRA_TOKEN
              valueFrom:
                secretKeyRef:
                  name: incident-bot-secrets
                  key: jira-token
---
apiVersion: v1
kind: Service
metadata:
  name: incident-bot
  namespace: monitoring
spec:
  selector:
    app: incident-bot
  ports:
    - port: 80
      targetPort: 8080
---
# Sample incident bot webhook handler (conceptual)
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-bot-config
  namespace: monitoring
data:
  config.yaml: |
    webhook:
      path: /webhook/alertmanager
      
    actions:
      on_critical_alert:
        - create_incident_channel:
            name_template: "inc-{{ .Labels.alertname | lower }}-{{ .StartsAt | date \"0102-1504\" }}"
        - create_jira_ticket:
            project: "INC"
            type: "Incident"
            priority_map:
              critical: "P1"
              warning: "P2"
        - page_oncall:
            schedule: "platform-oncall"
        - update_status_page:
            component: "{{ .Labels.service }}"
            status: "degraded_performance"
      
      on_resolved:
        - close_incident_channel:
            after: "24h"
        - update_jira_ticket:
            status: "Resolved"
        - update_status_page:
            status: "operational"
    
    templates:
      incident_channel_topic: |
        Incident: {{ .Labels.alertname }}
        Severity: {{ .Labels.severity }}
        Started: {{ .StartsAt }}
        Runbook: {{ .Annotations.runbook_url }}
```

## Exercises

### Exercise 1: Configure Basic Alerting

Set up a complete alerting pipeline:

```yaml
# Create namespace and basic alert rules
kubectl create namespace alerting-lab

# Deploy a sample application with metrics
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
  namespace: alerting-lab
spec:
  replicas: 3
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
            limits:
              cpu: 200m
              memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app
  namespace: alerting-lab
spec:
  selector:
    app: sample-app
  ports:
    - port: 80
      targetPort: 8080
EOF

# Create alert rules
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: sample-app-alerts
  namespace: alerting-lab
  labels:
    prometheus: k8s
spec:
  groups:
    - name: sample-app
      rules:
        - alert: SampleAppDown
          expr: up{job="sample-app"} == 0
          for: 1m
          labels:
            severity: critical
          annotations:
            summary: "Sample app is down"
            description: "Sample app has been unreachable for more than 1 minute."
        
        - alert: SampleAppHighLatency
          expr: |
            histogram_quantile(0.95, 
              sum(rate(http_request_duration_seconds_bucket{job="sample-app"}[5m])) by (le)
            ) > 0.5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "High latency detected"
            description: "P95 latency is {{ \$value | humanizeDuration }}"
EOF

# Verify alerts are loaded
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.name | contains("SampleApp"))'
```

### Exercise 2: Implement Routing Rules

Configure multi-team alert routing:

```yaml
# Create Alertmanager configuration
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-main
  namespace: monitoring
type: Opaque
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
    
    route:
      receiver: 'default'
      group_by: ['alertname', 'namespace']
      group_wait: 10s
      group_interval: 30s
      repeat_interval: 1h
      
      routes:
        # Critical alerts
        - match:
            severity: critical
          receiver: 'critical-alerts'
          group_wait: 0s
        
        # Team-specific routing
        - match:
            namespace: alerting-lab
          receiver: 'lab-team'
    
    receivers:
      - name: 'default'
        webhook_configs:
          - url: 'http://webhook-receiver.monitoring:5001/'
            send_resolved: true
      
      - name: 'critical-alerts'
        webhook_configs:
          - url: 'http://webhook-receiver.monitoring:5001/critical'
            send_resolved: true
      
      - name: 'lab-team'
        webhook_configs:
          - url: 'http://webhook-receiver.monitoring:5001/lab'
            send_resolved: true
EOF

# Deploy a webhook receiver for testing
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webhook-receiver
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webhook-receiver
  template:
    metadata:
      labels:
        app: webhook-receiver
    spec:
      containers:
        - name: receiver
          image: python:3.9-slim
          command:
            - python
            - -c
            - |
              from http.server import HTTPServer, BaseHTTPRequestHandler
              import json
              import sys
              
              class Handler(BaseHTTPRequestHandler):
                  def do_POST(self):
                      content_length = int(self.headers['Content-Length'])
                      body = self.rfile.read(content_length)
                      data = json.loads(body)
                      print(f"Path: {self.path}", file=sys.stderr)
                      print(f"Alerts: {json.dumps(data, indent=2)}", file=sys.stderr)
                      self.send_response(200)
                      self.end_headers()
                      self.wfile.write(b'OK')
              
              HTTPServer(('', 5001), Handler).serve_forever()
          ports:
            - containerPort: 5001
---
apiVersion: v1
kind: Service
metadata:
  name: webhook-receiver
  namespace: monitoring
spec:
  selector:
    app: webhook-receiver
  ports:
    - port: 5001
EOF

# Trigger an alert and verify routing
kubectl scale deployment sample-app -n alerting-lab --replicas=0

# Check webhook receiver logs
kubectl logs -n monitoring -l app=webhook-receiver --tail=50

# Restore
kubectl scale deployment sample-app -n alerting-lab --replicas=3
```

### Exercise 3: Create Custom Templates

Build notification templates:

```yaml
# Custom Slack-like template
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-templates
  namespace: monitoring
data:
  custom.tmpl: |
    {{ define "custom.title" }}
    {{ if eq .Status "firing" }}:fire:{{ else }}:white_check_mark:{{ end }} {{ .Status | toUpper }}: {{ .CommonLabels.alertname }}
    {{ end }}
    
    {{ define "custom.text" }}
    {{ if eq .Status "firing" }}
    *Firing Alerts: {{ .Alerts.Firing | len }}*
    {{ range .Alerts.Firing }}
    ━━━━━━━━━━━━━━━━━━━━
    *Alert:* \`{{ .Labels.alertname }}\`
    *Severity:* {{ .Labels.severity }}
    *Namespace:* {{ .Labels.namespace }}
    *Summary:* {{ .Annotations.summary }}
    *Started:* {{ .StartsAt.Format "2006-01-02 15:04:05 MST" }}
    {{ range .Labels.SortedPairs }}{{ if not (eq .Name "alertname" "severity" "namespace") }}*{{ .Name }}:* {{ .Value }}
    {{ end }}{{ end }}
    {{ end }}
    {{ end }}
    
    {{ if eq .Status "resolved" }}
    *Resolved Alerts: {{ .Alerts.Resolved | len }}*
    {{ range .Alerts.Resolved }}
    ━━━━━━━━━━━━━━━━━━━━
    *Alert:* \`{{ .Labels.alertname }}\`
    *Resolved:* {{ .EndsAt.Format "2006-01-02 15:04:05 MST" }}
    *Duration:* {{ .EndsAt.Sub .StartsAt }}
    {{ end }}
    {{ end }}
    {{ end }}
    
    {{ define "custom.runbook" }}
    {{ if .Annotations.runbook_url }}
    :book: <{{ .Annotations.runbook_url }}|View Runbook>
    {{ end }}
    {{ end }}
EOF

# Update Alertmanager to use templates
kubectl patch secret alertmanager-main -n monitoring --type=merge -p '{
  "stringData": {
    "alertmanager.yaml": "global:\n  resolve_timeout: 5m\n\ntemplates:\n  - /etc/alertmanager/config/*.tmpl\n\nroute:\n  receiver: default\n\nreceivers:\n  - name: default\n    webhook_configs:\n      - url: http://webhook-receiver.monitoring:5001/"
  }
}'
```

### Exercise 4: Implement Silences

Practice silence management:

```bash
# Port-forward to Alertmanager
kubectl port-forward -n monitoring svc/alertmanager-main 9093:9093 &

# Create a silence for maintenance
SILENCE_ID=$(curl -s -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {"name": "namespace", "value": "alerting-lab", "isRegex": false}
    ],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d "+1 hour" +%Y-%m-%dT%H:%M:%SZ)'",
    "createdBy": "lab-user",
    "comment": "Exercise 4 - Testing silences"
  }' | jq -r '.silenceID')

echo "Created silence: $SILENCE_ID"

# List active silences
curl -s http://localhost:9093/api/v2/silences | jq '.[] | select(.status.state == "active")'

# Trigger an alert (should be silenced)
kubectl scale deployment sample-app -n alerting-lab --replicas=0

# Verify alert is silenced (check Alertmanager UI or API)
curl -s http://localhost:9093/api/v2/alerts | jq '.[] | select(.status.silencedBy | length > 0)'

# Delete the silence
curl -X DELETE "http://localhost:9093/api/v2/silence/$SILENCE_ID"

# Restore application
kubectl scale deployment sample-app -n alerting-lab --replicas=3
```

### Exercise 5: Build Incident Response

Create a complete incident workflow:

```yaml
# Deploy incident response components
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-runbooks
  namespace: alerting-lab
data:
  sample-app-down.md: |
    # Sample App Down Runbook
    
    ## Severity: Critical
    ## Estimated Resolution: 15 minutes
    
    ## 1. Initial Assessment
    \`\`\`bash
    kubectl get pods -n alerting-lab
    kubectl describe deployment sample-app -n alerting-lab
    \`\`\`
    
    ## 2. Check Logs
    \`\`\`bash
    kubectl logs -n alerting-lab -l app=sample-app --tail=100
    \`\`\`
    
    ## 3. Common Issues
    
    ### Pod not starting
    - Check resource quotas
    - Verify image is accessible
    - Check node capacity
    
    ### Pod crashing
    - Check application logs for errors
    - Verify configuration
    - Check health probe settings
    
    ## 4. Resolution Steps
    
    ### Quick Fix: Restart
    \`\`\`bash
    kubectl rollout restart deployment/sample-app -n alerting-lab
    \`\`\`
    
    ### Rollback
    \`\`\`bash
    kubectl rollout undo deployment/sample-app -n alerting-lab
    \`\`\`
    
    ## 5. Post-Incident
    - Document root cause
    - Update this runbook if needed
    - File improvement ticket
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: complete-incident-alerts
  namespace: alerting-lab
  labels:
    prometheus: k8s
spec:
  groups:
    - name: incident-alerts
      rules:
        - alert: SampleAppIncident
          expr: |
            (
              sum(rate(http_requests_total{job="sample-app",status=~"5.."}[5m]))
              /
              sum(rate(http_requests_total{job="sample-app"}[5m]))
            ) > 0.10
          for: 2m
          labels:
            severity: critical
            runbook: sample-app-down
          annotations:
            summary: "Sample App experiencing high error rate"
            description: |
              Error rate: {{ \$value | humanizePercentage }}
              This triggers the incident response process.
            runbook_url: "https://wiki.example.com/runbooks/sample-app-down"
            dashboard_url: "https://grafana.example.com/d/sample-app"
            incident_commander: "platform-team"
EOF

# Simulate incident
kubectl exec -n alerting-lab deploy/sample-app -- sh -c "kill 1" || true

# Follow incident response
echo "
INCIDENT RESPONSE CHECKLIST:
[ ] 1. Acknowledge alert in Alertmanager
[ ] 2. Open incident channel
[ ] 3. Review runbook
[ ] 4. Diagnose issue
[ ] 5. Implement fix
[ ] 6. Verify resolution
[ ] 7. Document learnings
"

# Verify recovery
kubectl rollout restart deployment/sample-app -n alerting-lab
kubectl rollout status deployment/sample-app -n alerting-lab
```

## Validation Checklist

Before proceeding to the next lab, verify you can:

- [ ] Configure Alertmanager with routing rules
- [ ] Create effective PrometheusRule resources
- [ ] Design alerts following best practices (symptom-based, actionable)
- [ ] Implement notification templates
- [ ] Manage silences via API
- [ ] Set up inhibition rules
- [ ] Create and use runbooks
- [ ] Implement multi-team alert routing
- [ ] Integrate alerting with incident response

## Key Takeaways

1. **Alert on symptoms, not causes** - Users care about service impact
2. **Every alert should be actionable** - Include runbook links
3. **Use appropriate severity levels** - Reserve critical for customer impact
4. **Group related alerts** - Reduce notification fatigue
5. **Implement proper routing** - Right alerts to right teams
6. **Maintain silences carefully** - Document reasons and durations
7. **Test your alerting** - Chaos engineering for alerts
8. **Review and iterate** - Continuously improve signal-to-noise ratio

## Troubleshooting

### Alerts Not Firing

```bash
# Check rule evaluation
kubectl port-forward -n monitoring svc/prometheus 9090:9090 &
curl http://localhost:9090/api/v1/rules | jq '.data.groups[].rules[] | select(.state != "inactive")'

# Verify expression manually
curl -g 'http://localhost:9090/api/v1/query?query=up{job="sample-app"}'

# Check for evaluation errors
kubectl logs -n monitoring prometheus-0 | grep -i "rule evaluation"
```

### Notifications Not Received

```bash
# Check Alertmanager status
kubectl port-forward -n monitoring svc/alertmanager 9093:9093 &
curl http://localhost:9093/api/v2/status

# View alert history
curl http://localhost:9093/api/v2/alerts | jq

# Check receiver configuration
curl http://localhost:9093/api/v2/receivers | jq

# Review Alertmanager logs
kubectl logs -n monitoring alertmanager-0 | grep -i error
```

### Routing Issues

```bash
# Test routing with amtool
kubectl exec -n monitoring alertmanager-0 -- amtool config routes test \
  --config.file=/etc/alertmanager/config/alertmanager.yaml \
  alertname=TestAlert severity=critical namespace=production

# Visualize routing tree
kubectl exec -n monitoring alertmanager-0 -- amtool config routes show \
  --config.file=/etc/alertmanager/config/alertmanager.yaml
```

## Next Steps

In Lab 6, we will explore observability best practices including SLOs, error budgets, and correlating metrics, logs, and traces for effective incident response.

---

## Quick Reference

### Alert Rule Template

```yaml
- alert: AlertName
  expr: prometheus_expression > threshold
  for: duration
  labels:
    severity: critical|warning|info
  annotations:
    summary: "Brief description"
    description: "Detailed explanation with {{ $value }}"
    runbook_url: "https://runbooks.example.com/alert-name"
```

### Alertmanager API

```bash
# Create silence
curl -X POST http://alertmanager:9093/api/v2/silences -d @silence.json

# List alerts
curl http://alertmanager:9093/api/v2/alerts

# Delete silence
curl -X DELETE http://alertmanager:9093/api/v2/silence/{id}
```

### Useful PromQL for Alerts

```promql
# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)

# Latency percentile
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))

# Availability
1 - (sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])))

# Error budget burn
(sum(rate(http_requests_total{status=~"5.."}[1h])) / sum(rate(http_requests_total[1h]))) / 0.001
```
