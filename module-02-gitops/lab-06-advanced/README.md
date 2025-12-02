# Lab 6: ArgoCD Administration

## Overview

This lab covers advanced ArgoCD administration topics essential for production environments. You will learn to configure SSO/OIDC authentication, implement fine-grained RBAC, set up notifications, use ArgoCD Image Updater for automated image updates, and apply best practices for monitoring and troubleshooting.

## Time to Complete

Estimated time: 3-4 hours

## Prerequisites

Before starting this lab, ensure you have:

- Completed Labs 1-5 of this module
- ArgoCD running on your cluster
- `kubectl` and `argocd` CLI configured
- Basic understanding of OAuth2/OIDC (for SSO section)

## Learning Objectives

By the end of this lab, you will be able to:

1. Configure SSO authentication with OIDC providers
2. Implement RBAC policies and AppProjects
3. Set up ArgoCD notifications for Slack and webhooks
4. Configure ArgoCD Image Updater for automated deployments
5. Monitor ArgoCD with Prometheus and Grafana
6. Troubleshoot common ArgoCD issues
7. Implement ArgoCD high availability

## Lab Exercises

### Exercise 1: ArgoCD Configuration Management

ArgoCD configuration is managed through ConfigMaps and Secrets.

#### Step 1: Understanding ArgoCD ConfigMaps

Key ConfigMaps:

```bash
kubectl get configmaps -n argocd
```

Important ConfigMaps:

- `argocd-cm`: Main configuration
- `argocd-rbac-cm`: RBAC policies
- `argocd-cmd-params-cm`: Server parameters
- `argocd-ssh-known-hosts-cm`: SSH known hosts
- `argocd-tls-certs-cm`: TLS certificates

#### Step 2: View Current Configuration

```bash
kubectl get configmap argocd-cm -n argocd -o yaml
```

#### Step 3: Configure ArgoCD Settings

```yaml
# argocd-cm-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-cm
    app.kubernetes.io/part-of: argocd
data:
  # URL of the ArgoCD server
  url: https://argocd.example.com

  # Enable status badge
  statusbadge.enabled: "true"

  # Resource tracking method
  application.resourceTrackingMethod: annotation

  # Timeout for sync operations
  timeout.reconciliation: 180s

  # Admin account status
  admin.enabled: "true"

  # Application sync parallel limit
  controller.app.sync.max.parallelism: "10"

  # Resource exclusions
  resource.exclusions: |
    - apiGroups:
        - tekton.dev
      kinds:
        - TaskRun
        - PipelineRun

  # Resource customizations
  resource.customizations: |
    admissionregistration.k8s.io/MutatingWebhookConfiguration:
      ignoreDifferences: |
        jsonPointers:
          - /webhooks/0/clientConfig/caBundle
```

### Exercise 2: SSO/OIDC Integration

Configure ArgoCD to use external identity providers for authentication.

#### Step 1: OIDC Configuration with Dex

ArgoCD uses Dex as an identity broker by default.

```yaml
# argocd-cm-oidc.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
      # GitHub connector
      - type: github
        id: github
        name: GitHub
        config:
          clientID: $dex.github.clientID
          clientSecret: $dex.github.clientSecret
          orgs:
            - name: your-organization
              teams:
                - platform-team
                - developers

      # OIDC connector (e.g., Okta, Azure AD)
      - type: oidc
        id: okta
        name: Okta
        config:
          issuer: https://your-org.okta.com
          clientID: $dex.oidc.clientID
          clientSecret: $dex.oidc.clientSecret
          requestedScopes:
            - openid
            - profile
            - email
            - groups
```

#### Step 2: Store OIDC Secrets

```yaml
# argocd-secret-oidc.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  # Dex GitHub OAuth credentials
  dex.github.clientID: your-github-client-id
  dex.github.clientSecret: your-github-client-secret

  # Dex OIDC credentials
  dex.oidc.clientID: your-oidc-client-id
  dex.oidc.clientSecret: your-oidc-client-secret
```

#### Step 3: Configure Azure AD SSO

```yaml
# argocd-cm-azure.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  dex.config: |
    connectors:
      - type: microsoft
        id: microsoft
        name: Microsoft
        config:
          clientID: $dex.azure.clientID
          clientSecret: $dex.azure.clientSecret
          tenant: your-tenant-id
          redirectURI: https://argocd.example.com/api/dex/callback
          groups:
            - platform-engineers
            - developers
```

#### Step 4: Direct OIDC (Without Dex)

For direct OIDC integration:

```yaml
# argocd-cm-direct-oidc.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  url: https://argocd.example.com
  oidc.config: |
    name: Okta
    issuer: https://your-org.okta.com
    clientID: $oidc.okta.clientID
    clientSecret: $oidc.okta.clientSecret
    requestedScopes:
      - openid
      - profile
      - email
      - groups
    requestedIDTokenClaims:
      groups:
        essential: true
```

### Exercise 3: RBAC Configuration

Implement fine-grained access control for ArgoCD.

#### Step 1: Understanding RBAC Model

ArgoCD RBAC uses Casbin policies with the format:

```text
p, <subject>, <resource>, <action>, <object>, <effect>
g, <user/group>, <role>
```

Resources:

- `applications`: Application operations
- `clusters`: Cluster management
- `repositories`: Repository access
- `projects`: AppProject management
- `logs`: Application logs
- `exec`: Pod exec access

Actions:

- `get`: Read access
- `create`: Create resources
- `update`: Modify resources
- `delete`: Delete resources
- `sync`: Sync applications
- `override`: Override sync
- `action/*`: Custom actions

#### Step 2: Configure RBAC Policies

```yaml
# argocd-rbac-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  # Default policy for authenticated users
  policy.default: role:readonly

  # Policy CSV
  policy.csv: |
    # Roles
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, logs, get, */*, allow
    p, role:admin, exec, create, */*, allow

    # Developer role - can sync but not delete
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */*, allow
    p, role:developer, applications, action/*, */*, allow
    p, role:developer, logs, get, */*, allow
    p, role:developer, repositories, get, *, allow

    # Viewer role - read only
    p, role:viewer, applications, get, */*, allow
    p, role:viewer, repositories, get, *, allow
    p, role:viewer, clusters, get, *, allow
    p, role:viewer, projects, get, *, allow

    # Team-specific access
    p, role:team-a-admin, applications, *, team-a/*, allow
    p, role:team-a-admin, logs, get, team-a/*, allow

    # Group to role mappings
    g, platform-team, role:admin
    g, developers, role:developer
    g, stakeholders, role:viewer
    g, team-a, role:team-a-admin

  # SSO group scopes (for OIDC groups claim)
  scopes: '[groups, email]'
```

#### Step 3: AppProject-Based RBAC

```yaml
# team-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-frontend
  namespace: argocd
spec:
  description: Frontend team project
  sourceRepos:
    - 'https://github.com/your-org/frontend-*'
  destinations:
    - namespace: 'frontend-*'
      server: https://kubernetes.default.svc
    - namespace: 'frontend-*'
      server: https://prod-cluster:6443
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
    - group: ''
      kind: LimitRange
  roles:
    - name: admin
      description: Frontend team admin
      policies:
        - p, proj:team-frontend:admin, applications, *, team-frontend/*, allow
        - p, proj:team-frontend:admin, repositories, get, *, allow
      groups:
        - frontend-admins
    - name: developer
      description: Frontend developer
      policies:
        - p, proj:team-frontend:developer, applications, get, team-frontend/*, allow
        - p, proj:team-frontend:developer, applications, sync, team-frontend/*, allow
      groups:
        - frontend-developers
```

#### Step 4: Testing RBAC

```bash
# Check if user has permission
argocd admin settings rbac can <subject> <action> <resource> <subresource> --policy-file policy.csv

# Example
argocd admin settings rbac can developer get applications 'team-a/*' --policy-file policy.csv

# Validate RBAC config
argocd admin settings rbac validate --policy-file policy.csv
```

### Exercise 4: ArgoCD Notifications

Set up notifications for application events.

#### Step 1: Install ArgoCD Notifications

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/notifications_catalog/install.yaml
```

#### Step 2: Configure Notification Services

```yaml
# argocd-notifications-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Service configurations
  service.slack: |
    token: $slack-token
    signingSecret: $slack-signing-secret

  service.webhook.teams: |
    url: https://outlook.office.com/webhook/xxx
    headers:
      - name: Content-Type
        value: application/json

  service.email: |
    host: smtp.gmail.com
    port: 587
    username: $email-username
    password: $email-password
    from: argocd@example.com

  # Context for templates
  context: |
    argocdUrl: https://argocd.example.com

  # Templates
  template.app-sync-succeeded: |
    message: |
      Application {{.app.metadata.name}} has been successfully synced.
      Sync Status: {{.app.status.sync.status}}
      Health Status: {{.app.status.health.status}}
    slack:
      attachments: |
        [{
          "color": "#18be52",
          "title": "{{.app.metadata.name}} Sync Succeeded",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "fields": [
            {"title": "Sync Status", "value": "{{.app.status.sync.status}}", "short": true},
            {"title": "Repository", "value": "{{.app.spec.source.repoURL}}", "short": true},
            {"title": "Revision", "value": "{{.app.status.sync.revision}}", "short": true}
          ]
        }]

  template.app-sync-failed: |
    message: |
      Application {{.app.metadata.name}} sync has failed.
      Error: {{.app.status.operationState.message}}
    slack:
      attachments: |
        [{
          "color": "#E96D76",
          "title": "{{.app.metadata.name}} Sync Failed",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "fields": [
            {"title": "Sync Status", "value": "{{.app.status.sync.status}}", "short": true},
            {"title": "Error", "value": "{{.app.status.operationState.message}}", "short": false}
          ]
        }]

  template.app-health-degraded: |
    message: |
      Application {{.app.metadata.name}} health is degraded.
    slack:
      attachments: |
        [{
          "color": "#f4c030",
          "title": "{{.app.metadata.name}} Health Degraded",
          "title_link": "{{.context.argocdUrl}}/applications/{{.app.metadata.name}}",
          "fields": [
            {"title": "Health Status", "value": "{{.app.status.health.status}}", "short": true}
          ]
        }]

  # Triggers
  trigger.on-sync-succeeded: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-sync-succeeded]

  trigger.on-sync-failed: |
    - when: app.status.operationState.phase in ['Error', 'Failed']
      send: [app-sync-failed]

  trigger.on-health-degraded: |
    - when: app.status.health.status == 'Degraded'
      send: [app-health-degraded]

  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded'] and app.status.health.status == 'Healthy'
      oncePer: app.status.sync.revision
      send: [app-sync-succeeded]
```

#### Step 3: Store Notification Secrets

```yaml
# argocd-notifications-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: argocd-notifications-secret
  namespace: argocd
type: Opaque
stringData:
  slack-token: xoxb-your-slack-bot-token
  slack-signing-secret: your-signing-secret
  email-username: argocd@example.com
  email-password: your-app-password
```

#### Step 4: Subscribe Applications to Notifications

```yaml
# app-with-notifications.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-sync-succeeded.slack: platform-alerts
    notifications.argoproj.io/subscribe.on-sync-failed.slack: platform-alerts
    notifications.argoproj.io/subscribe.on-health-degraded.slack: platform-alerts
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/my-app
    path: deploy
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
```

#### Step 5: Default Subscriptions

Configure default subscriptions for all applications:

```yaml
# argocd-notifications-cm-subscriptions.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-notifications-cm
  namespace: argocd
data:
  # Default triggers for all apps
  defaultTriggers: |
    - on-sync-failed
    - on-health-degraded

  # Subscriptions
  subscriptions: |
    - recipients:
        - slack:platform-alerts
      triggers:
        - on-sync-failed
        - on-health-degraded
    - recipients:
        - slack:deployments
      triggers:
        - on-sync-succeeded
      selector: app.kubernetes.io/env=production
```

### Exercise 5: ArgoCD Image Updater

Automatically update container images in GitOps repositories.

#### Step 1: Install ArgoCD Image Updater

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
```

Verify installation:

```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

#### Step 2: Configure Image Registries

```yaml
# argocd-image-updater-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
  namespace: argocd
data:
  registries.conf: |
    registries:
      - name: Docker Hub
        api_url: https://registry-1.docker.io
        prefix: docker.io
        default: true
        credentials: pullsecret:argocd/dockerhub-creds

      - name: GitHub Container Registry
        api_url: https://ghcr.io
        prefix: ghcr.io
        credentials: pullsecret:argocd/ghcr-creds

      - name: ECR
        api_url: https://123456789.dkr.ecr.us-west-2.amazonaws.com
        prefix: 123456789.dkr.ecr.us-west-2.amazonaws.com
        credentials: ext:/scripts/ecr-login.sh

  log.level: info
  git.commit-message-template: |
    build: automatic update of {{ .AppName }}

    {{ range .AppChanges -}}
    updates image {{ .Image }} tag '{{ .OldTag }}' to '{{ .NewTag }}'
    {{ end -}}
```

#### Step 3: Configure Registry Credentials

```yaml
# registry-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: dockerhub-creds
  namespace: argocd
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-creds
  namespace: argocd
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
```

#### Step 4: Configure Application for Image Updates

```yaml
# app-with-image-updater.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    # Image list to track
    argocd-image-updater.argoproj.io/image-list: myapp=ghcr.io/your-org/my-app

    # Update strategy (semver, latest, digest)
    argocd-image-updater.argoproj.io/myapp.update-strategy: semver

    # SemVer constraint
    argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$

    # Write back method
    argocd-image-updater.argoproj.io/write-back-method: git

    # Git branch for updates
    argocd-image-updater.argoproj.io/git-branch: main

    # Helm value to update
    argocd-image-updater.argoproj.io/myapp.helm.image-tag: image.tag
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/my-app
    path: deploy
    targetRevision: HEAD
    helm:
      valueFiles:
        - values.yaml
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
```

#### Step 5: Update Strategies

```yaml
# Semver strategy - follow semantic versioning
argocd-image-updater.argoproj.io/myapp.update-strategy: semver
argocd-image-updater.argoproj.io/myapp.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$

# Latest strategy - always use newest tag
argocd-image-updater.argoproj.io/myapp.update-strategy: latest

# Digest strategy - track specific image by digest
argocd-image-updater.argoproj.io/myapp.update-strategy: digest

# Name strategy - alphabetically latest
argocd-image-updater.argoproj.io/myapp.update-strategy: name
```

#### Step 6: Write-Back Methods

```yaml
# Git write-back (commits changes to Git)
argocd-image-updater.argoproj.io/write-back-method: git
argocd-image-updater.argoproj.io/git-branch: main

# ArgoCD write-back (only updates ArgoCD, no Git commit)
argocd-image-updater.argoproj.io/write-back-method: argocd
```

### Exercise 6: Monitoring and Observability

#### Step 1: ArgoCD Metrics

ArgoCD exposes Prometheus metrics on port 8083:

```bash
# Port-forward to metrics endpoint
kubectl port-forward svc/argocd-metrics -n argocd 8083:8083

# View metrics
curl http://localhost:8083/metrics
```

Key metrics:

```text
# Application metrics
argocd_app_info                          # Application information
argocd_app_sync_total                    # Sync operations count
argocd_app_reconcile_count               # Reconciliation count
argocd_app_reconcile_bucket              # Reconciliation duration

# Controller metrics
argocd_kubectl_exec_total                # kubectl exec count
argocd_redis_request_total               # Redis operations

# Cluster metrics
argocd_cluster_api_requests_total        # API server requests
argocd_cluster_events_total              # Cluster events
argocd_cluster_info                      # Cluster information
```

#### Step 2: ServiceMonitor for Prometheus

```yaml
# argocd-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics
```

#### Step 3: Grafana Dashboard

Import the ArgoCD dashboard (ID: 14584) or create custom panels:

```json
{
  "panels": [
    {
      "title": "Application Sync Status",
      "targets": [
        {
          "expr": "sum(argocd_app_info{sync_status=\"Synced\"}) or vector(0)",
          "legendFormat": "Synced"
        },
        {
          "expr": "sum(argocd_app_info{sync_status=\"OutOfSync\"}) or vector(0)",
          "legendFormat": "OutOfSync"
        }
      ]
    },
    {
      "title": "Application Health Status",
      "targets": [
        {
          "expr": "sum(argocd_app_info{health_status=\"Healthy\"}) or vector(0)",
          "legendFormat": "Healthy"
        },
        {
          "expr": "sum(argocd_app_info{health_status=\"Degraded\"}) or vector(0)",
          "legendFormat": "Degraded"
        }
      ]
    },
    {
      "title": "Sync Operations",
      "targets": [
        {
          "expr": "sum(rate(argocd_app_sync_total[5m])) by (phase)",
          "legendFormat": "{{phase}}"
        }
      ]
    }
  ]
}
```

#### Step 4: Alert Rules

```yaml
# argocd-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: argocd
spec:
  groups:
    - name: argocd
      rules:
        - alert: ArgoCDAppOutOfSync
          expr: argocd_app_info{sync_status="OutOfSync"} == 1
          for: 15m
          labels:
            severity: warning
          annotations:
            summary: "Application {{ $labels.name }} is out of sync"
            description: "Application {{ $labels.name }} has been out of sync for more than 15 minutes"

        - alert: ArgoCDAppHealthDegraded
          expr: argocd_app_info{health_status="Degraded"} == 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Application {{ $labels.name }} health is degraded"
            description: "Application {{ $labels.name }} health has been degraded for more than 5 minutes"

        - alert: ArgoCDSyncFailed
          expr: increase(argocd_app_sync_total{phase="Failed"}[5m]) > 0
          labels:
            severity: critical
          annotations:
            summary: "ArgoCD sync failure detected"
            description: "ArgoCD application sync has failed"

        - alert: ArgoCDClusterConnectionFailed
          expr: argocd_cluster_info{connection_status!="Successful"} == 1
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Cluster {{ $labels.name }} connection failed"
            description: "ArgoCD cannot connect to cluster {{ $labels.name }}"
```

### Exercise 7: High Availability Configuration

#### Step 1: HA Architecture

```text
ArgoCD HA Components:
┌─────────────────────────────────────────────────────────┐
│                     Load Balancer                       │
└─────────────────────────────────────────────────────────┘
                          │
          ┌───────────────┼───────────────┐
          ▼               ▼               ▼
    ┌──────────┐    ┌──────────┐    ┌──────────┐
    │ ArgoCD   │    │ ArgoCD   │    │ ArgoCD   │
    │ Server 1 │    │ Server 2 │    │ Server 3 │
    └──────────┘    └──────────┘    └──────────┘
          │               │               │
          └───────────────┼───────────────┘
                          ▼
    ┌─────────────────────────────────────────────────────┐
    │                Redis HA Cluster                      │
    │  ┌─────────┐  ┌─────────┐  ┌─────────┐              │
    │  │ Master  │  │ Replica │  │ Replica │              │
    │  └─────────┘  └─────────┘  └─────────┘              │
    └─────────────────────────────────────────────────────┘
```

#### Step 2: Install ArgoCD HA

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/ha/install.yaml
```

#### Step 3: Configure Redis HA

```yaml
# redis-ha-values.yaml
redis-ha:
  enabled: true
  haproxy:
    enabled: true
  replicas: 3
  redis:
    config:
      maxmemory: 256mb
      maxmemory-policy: allkeys-lru
```

#### Step 4: Scale ArgoCD Components

```bash
# Scale application controller (leader election enabled)
kubectl scale statefulset argocd-application-controller -n argocd --replicas=3

# Scale server
kubectl scale deployment argocd-server -n argocd --replicas=3

# Scale repo server
kubectl scale deployment argocd-repo-server -n argocd --replicas=3
```

#### Step 5: Configure PodDisruptionBudgets

```yaml
# argocd-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-server-pdb
  namespace: argocd
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-repo-server-pdb
  namespace: argocd
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: argocd-application-controller-pdb
  namespace: argocd
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
```

### Exercise 8: Troubleshooting ArgoCD

#### Step 1: Common Issues and Solutions

**Application Stuck in Syncing:**

```bash
# Check application status
argocd app get <app-name>

# Check sync operation
argocd app sync <app-name> --dry-run

# Force refresh
argocd app get <app-name> --refresh

# Hard refresh (clear cache)
argocd app get <app-name> --hard-refresh
```

**Repository Connection Issues:**

```bash
# Test repository connectivity
argocd repo list

# Add repository with debug
argocd repo add <repo-url> --username <user> --password <pass>

# Check repo server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server
```

**Cluster Connection Issues:**

```bash
# List clusters
argocd cluster list

# Check cluster details
argocd cluster get <cluster-name>

# Check application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

#### Step 2: Debug Commands

```bash
# Enable debug logging
kubectl patch configmap argocd-cmd-params-cm -n argocd -p '{"data":{"server.log.level":"debug"}}'

# Restart components to apply
kubectl rollout restart deployment argocd-server -n argocd

# View logs
kubectl logs -n argocd deployment/argocd-server -f

# Check Redis connectivity
kubectl exec -n argocd deployment/argocd-server -- redis-cli -h argocd-redis ping
```

#### Step 3: Resource Health Issues

```bash
# Get resource tree
argocd app resources <app-name>

# Check specific resource health
argocd app get <app-name> --show-conditions

# Manual sync with specific resources
argocd app sync <app-name> --resource <group>/<kind>/<name>
```

#### Step 4: Performance Tuning

```yaml
# argocd-cmd-params-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # Controller settings
  controller.status.processors: "50"
  controller.operation.processors: "25"
  controller.repo.server.timeout.seconds: "300"

  # Repo server settings
  reposerver.parallelism.limit: "10"

  # Server settings
  server.insecure: "true"  # For testing only
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Configure SSO with OIDC providers
- [ ] Implement RBAC policies for teams
- [ ] Set up AppProjects with role-based access
- [ ] Configure notifications for Slack and email
- [ ] Install and configure ArgoCD Image Updater
- [ ] Set up Prometheus monitoring for ArgoCD
- [ ] Create alerting rules for ArgoCD issues
- [ ] Troubleshoot common ArgoCD problems
- [ ] Configure ArgoCD for high availability

## Troubleshooting Guide

### SSO Not Working

```bash
# Check Dex logs
kubectl logs -n argocd deployment/argocd-dex-server

# Verify OIDC configuration
kubectl get configmap argocd-cm -n argocd -o yaml | grep -A 20 "dex.config"

# Check callback URL
# Ensure it matches: https://argocd.example.com/api/dex/callback
```

### RBAC Permissions Denied

```bash
# Validate policy
argocd admin settings rbac validate -f /path/to/policy.csv

# Test permission
argocd admin settings rbac can <user> <action> <resource> <object>

# Check groups claim
kubectl logs -n argocd deployment/argocd-server | grep groups
```

### Image Updater Not Working

```bash
# Check Image Updater logs
kubectl logs -n argocd deployment/argocd-image-updater

# Verify application annotations
kubectl get application <app-name> -n argocd -o yaml | grep argocd-image-updater

# Check registry connectivity
kubectl exec -n argocd deployment/argocd-image-updater -- argocd-image-updater test <image>
```

## Key Takeaways

1. **SSO/OIDC**: Essential for enterprise environments; use Dex or direct OIDC
2. **RBAC**: Combine global policies with AppProject-based access control
3. **Notifications**: Critical for team awareness of deployment status
4. **Image Updater**: Enables true continuous deployment with GitOps
5. **Monitoring**: Prometheus metrics and Grafana dashboards are essential
6. **High Availability**: Required for production ArgoCD deployments
7. **Troubleshooting**: Know the key logs and debug commands

## Next Steps

You have completed all labs in Module 2: GitOps and Continuous Delivery. Proceed to:

- Complete the Module Assessment
- Review the Quick Reference Guide
- Move on to Module 3: CI/CD Pipelines
