# 🏆 CNPE Capstone Project

## Building a Production-Ready Cloud Native Platform

This capstone project integrates all skills learned across the 8 modules to build and operate a complete cloud native platform from scratch.

---

## 📋 Project Overview

**Duration:** 8-12 hours  
**Difficulty:** Advanced  
**Prerequisites:** Completion of Modules 1-8

### Scenario

You are the Platform Engineer for **TechCorp**, a growing technology company. Your mission is to build a production-ready Kubernetes platform that hosts their flagship application: **BookStore** - a microservices-based e-commerce application.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TechCorp Platform Architecture                       │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                   │
│   │   GitHub    │────►│   ArgoCD    │────►│ Kubernetes  │                   │
│   │ (GitOps)    │     │ (Delivery)  │     │  Cluster    │                   │
│   └─────────────┘     └─────────────┘     └──────┬──────┘                   │
│                                                   │                          │
│         ┌─────────────────────────────────────────┼─────────────────────┐   │
│         │                                         │                     │   │
│         ▼                                         ▼                     ▼   │
│   ┌───────────┐    ┌───────────┐    ┌───────────┐    ┌───────────┐         │
│   │  Frontend │    │    API    │    │  Catalog  │    │   Order   │         │
│   │  (React)  │───►│  Gateway  │───►│  Service  │    │  Service  │         │
│   └───────────┘    └───────────┘    └─────┬─────┘    └─────┬─────┘         │
│                                           │                │                │
│                                           ▼                ▼                │
│                                     ┌───────────┐    ┌───────────┐         │
│                                     │  MongoDB  │    │   Redis   │         │
│                                     │ (Catalog) │    │  (Cache)  │         │
│                                     └───────────┘    └───────────┘         │
│                                                                               │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                        Observability Stack                           │   │
│   │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐            │   │
│   │  │Prometheus│  │ Grafana  │  │   Loki   │  │ Alertmgr │            │   │
│   │  └──────────┘  └──────────┘  └──────────┘  └──────────┘            │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 🎯 Project Objectives

By completing this capstone, you will demonstrate proficiency in:

| Module | Skills Applied |
|--------|----------------|
| **Module 1** | Kubernetes fundamentals, deployments, services |
| **Module 2** | GitOps with ArgoCD, application patterns |
| **Module 3** | CI/CD pipelines, container builds |
| **Module 4** | Prometheus, Grafana, Loki observability |
| **Module 5** | Platform engineering, golden paths |
| **Module 6** | Security hardening, network policies |
| **Module 7** | Backup strategies, disaster recovery |
| **Module 8** | Day 2 operations, troubleshooting |

---

## 📁 Project Structure

```
capstone-project/
├── README.md                    # This file
├── phase-1-foundation/          # Cluster setup and GitOps
├── phase-2-application/         # Application deployment
├── phase-3-observability/       # Monitoring and logging
├── phase-4-security/            # Security hardening
├── phase-5-reliability/         # DR and operations
├── phase-6-assessment/          # Final validation
└── solutions/                   # Reference solutions
```

---

## 🚀 Phase 1: Foundation (Modules 1 & 2)

### Objectives
- Set up a production-ready Kubernetes cluster
- Configure GitOps with ArgoCD
- Establish namespace strategy

### Tasks

#### 1.1 Cluster Setup

Create a Kubernetes cluster with:
- 1 control plane node (or 3 for HA)
- 3 worker nodes
- Proper node labels and taints

```bash
# Create cluster (Kind example)
cat > cluster-config.yaml << 'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: techcorp-platform
nodes:
  - role: control-plane
  - role: worker
    labels:
      workload-type: general
  - role: worker
    labels:
      workload-type: general
  - role: worker
    labels:
      workload-type: database
    kubeadmConfigPatches:
      - |
        kind: JoinConfiguration
        nodeRegistration:
          taints:
            - key: "database"
              value: "true"
              effect: "NoSchedule"
EOF

kind create cluster --config cluster-config.yaml
```

#### 1.2 Namespace Strategy

Create the following namespaces with appropriate labels and resource quotas:

| Namespace | Purpose | Resource Quota |
|-----------|---------|----------------|
| `bookstore-prod` | Production workloads | CPU: 8, Memory: 16Gi |
| `bookstore-staging` | Staging environment | CPU: 4, Memory: 8Gi |
| `platform` | Platform services (ArgoCD) | CPU: 4, Memory: 8Gi |
| `monitoring` | Observability stack | CPU: 4, Memory: 8Gi |
| `backup` | Velero and backups | CPU: 2, Memory: 4Gi |

```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookstore-prod
  labels:
    environment: production
    team: bookstore
    cost-center: engineering
---
apiVersion: v1
kind: ResourceQuota
metadata:
  name: bookstore-prod-quota
  namespace: bookstore-prod
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "50"
# Continue for other namespaces...
```

#### 1.3 ArgoCD Setup

Install and configure ArgoCD:

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=300s

# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

#### 1.4 Create GitOps Repository Structure

Set up your GitOps repository:

```
bookstore-gitops/
├── apps/
│   ├── staging/
│   │   └── kustomization.yaml
│   └── production/
│       └── kustomization.yaml
├── base/
│   ├── frontend/
│   ├── api-gateway/
│   ├── catalog-service/
│   ├── order-service/
│   ├── mongodb/
│   └── redis/
├── platform/
│   ├── argocd/
│   ├── monitoring/
│   └── backup/
└── clusters/
    └── techcorp/
        └── apps.yaml
```

#### 1.5 App of Apps Pattern

Create an App of Apps configuration:

```yaml
# clusters/techcorp/apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/YOUR_ORG/bookstore-gitops
    targetRevision: main
    path: platform
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Phase 1 Deliverables

- [ ] Running Kubernetes cluster with proper node configuration
- [ ] Namespaces with resource quotas created
- [ ] ArgoCD installed and accessible
- [ ] GitOps repository structure created
- [ ] App of Apps pattern implemented

---

## 🛒 Phase 2: Application Deployment (Module 3)

### Objectives
- Deploy the BookStore microservices
- Configure services and ingress
- Set up CI/CD pipeline

### Tasks

#### 2.1 Deploy MongoDB

```yaml
# base/mongodb/deployment.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      tolerations:
        - key: "database"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
      nodeSelector:
        workload-type: database
      containers:
        - name: mongodb
          image: mongo:6.0
          ports:
            - containerPort: 27017
          env:
            - name: MONGO_INITDB_ROOT_USERNAME
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: username
            - name: MONGO_INITDB_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret
                  key: password
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 1
              memory: 2Gi
          volumeMounts:
            - name: data
              mountPath: /data/db
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

#### 2.2 Deploy Catalog Service

```yaml
# base/catalog-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service
spec:
  replicas: 2
  selector:
    matchLabels:
      app: catalog-service
  template:
    metadata:
      labels:
        app: catalog-service
    spec:
      containers:
        - name: catalog
          image: bookstore/catalog-service:v1.0.0
          ports:
            - containerPort: 8080
          env:
            - name: MONGODB_URI
              valueFrom:
                secretKeyRef:
                  name: catalog-secrets
                  key: mongodb-uri
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
spec:
  selector:
    app: catalog-service
  ports:
    - port: 80
      targetPort: 8080
```

#### 2.3 Deploy Frontend

```yaml
# base/frontend/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 3
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
          image: bookstore/frontend:v1.0.0
          ports:
            - containerPort: 80
          env:
            - name: API_URL
              value: "http://api-gateway"
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 200m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
spec:
  selector:
    app: frontend
  ports:
    - port: 80
      targetPort: 80
```

#### 2.4 Configure Ingress

```yaml
# base/ingress/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: bookstore-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  rules:
    - host: bookstore.techcorp.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: frontend
                port:
                  number: 80
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-gateway
                port:
                  number: 80
```

#### 2.5 GitHub Actions CI Pipeline

```yaml
# .github/workflows/ci.yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Tests
        run: |
          cd catalog-service
          go test ./... -v -cover
          
  build:
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Build and Push Image
        uses: docker/build-push-action@v5
        with:
          context: ./catalog-service
          push: true
          tags: |
            ghcr.io/${{ github.repository }}/catalog-service:${{ github.sha }}
            ghcr.io/${{ github.repository }}/catalog-service:latest
            
  update-manifests:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          repository: YOUR_ORG/bookstore-gitops
          token: ${{ secrets.GITOPS_TOKEN }}
          
      - name: Update Image Tag
        run: |
          cd apps/staging
          kustomize edit set image catalog-service=ghcr.io/${{ github.repository }}/catalog-service:${{ github.sha }}
          
      - name: Commit and Push
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Update catalog-service to ${{ github.sha }}"
          git push
```

### Phase 2 Deliverables

- [ ] All microservices deployed and running
- [ ] Services properly configured
- [ ] Ingress exposing the application
- [ ] CI/CD pipeline working
- [ ] GitOps-based deployments functional

---

## 📊 Phase 3: Observability (Module 4)

### Objectives
- Deploy monitoring stack
- Configure dashboards and alerts
- Set up log aggregation

### Tasks

#### 3.1 Deploy Prometheus Stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=techcorp123 \
  --set prometheus.prometheusSpec.retention=7d
```

#### 3.2 Create BookStore Dashboard

```yaml
# monitoring/dashboards/bookstore-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: bookstore-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  bookstore.json: |
    {
      "title": "BookStore Application",
      "panels": [
        {
          "title": "Request Rate",
          "targets": [{
            "expr": "sum(rate(http_requests_total{namespace=\"bookstore-prod\"}[5m])) by (service)"
          }]
        },
        {
          "title": "Error Rate",
          "targets": [{
            "expr": "sum(rate(http_requests_total{namespace=\"bookstore-prod\",status=~\"5..\"}[5m])) by (service) / sum(rate(http_requests_total{namespace=\"bookstore-prod\"}[5m])) by (service) * 100"
          }]
        },
        {
          "title": "P99 Latency",
          "targets": [{
            "expr": "histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace=\"bookstore-prod\"}[5m])) by (le, service))"
          }]
        }
      ]
    }
```

#### 3.3 Configure Alerts

```yaml
# monitoring/alerts/bookstore-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: bookstore-alerts
  namespace: monitoring
spec:
  groups:
    - name: bookstore.availability
      rules:
        - alert: BookStoreHighErrorRate
          expr: |
            sum(rate(http_requests_total{namespace="bookstore-prod",status=~"5.."}[5m])) /
            sum(rate(http_requests_total{namespace="bookstore-prod"}[5m])) > 0.01
          for: 5m
          labels:
            severity: critical
            team: bookstore
          annotations:
            summary: "High error rate in BookStore"
            description: "Error rate is {{ $value | humanizePercentage }}"
            
        - alert: BookStoreHighLatency
          expr: |
            histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{namespace="bookstore-prod"}[5m])) by (le)) > 0.5
          for: 5m
          labels:
            severity: warning
            team: bookstore
          annotations:
            summary: "High latency in BookStore"
            description: "P99 latency is {{ $value }}s"
            
        - alert: CatalogServiceDown
          expr: up{job="catalog-service"} == 0
          for: 1m
          labels:
            severity: critical
            team: bookstore
          annotations:
            summary: "Catalog service is down"
```

#### 3.4 Deploy Loki for Logging

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set promtail.enabled=true \
  --set loki.persistence.enabled=true \
  --set loki.persistence.size=10Gi
```

#### 3.5 Configure SLOs

```yaml
# monitoring/slos/bookstore-slo.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: bookstore-slo
  namespace: monitoring
spec:
  groups:
    - name: bookstore.slo
      rules:
        # SLO: 99.9% availability
        - record: bookstore:availability:ratio
          expr: |
            1 - (
              sum(rate(http_requests_total{namespace="bookstore-prod",status=~"5.."}[30d])) /
              sum(rate(http_requests_total{namespace="bookstore-prod"}[30d]))
            )
            
        # Error budget remaining
        - record: bookstore:error_budget:remaining
          expr: |
            (0.999 - (1 - bookstore:availability:ratio)) / 0.001
            
        - alert: ErrorBudgetBurnRate
          expr: bookstore:error_budget:remaining < 0.25
          labels:
            severity: warning
          annotations:
            summary: "BookStore error budget below 25%"
```

### Phase 3 Deliverables

- [ ] Prometheus and Grafana deployed
- [ ] Application metrics being collected
- [ ] Custom BookStore dashboard created
- [ ] Alert rules configured
- [ ] Loki logging stack operational
- [ ] SLOs defined and tracked

---

## 🔒 Phase 4: Security (Module 6)

### Objectives
- Implement network policies
- Configure pod security
- Manage secrets securely
- Set up RBAC

### Tasks

#### 4.1 Network Policies

```yaml
# security/network-policies/default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: bookstore-prod
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# security/network-policies/allow-frontend.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: bookstore-prod
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
      ports:
        - port: 80
---
# security/network-policies/catalog-to-mongodb.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: catalog-to-mongodb
  namespace: bookstore-prod
spec:
  podSelector:
    matchLabels:
      app: mongodb
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: catalog-service
      ports:
        - port: 27017
```

#### 4.2 Pod Security Standards

```yaml
# security/pod-security/namespace-labels.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bookstore-prod
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

#### 4.3 Secure Secrets Management

```yaml
# Use External Secrets Operator or Sealed Secrets
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: mongodb-credentials
  namespace: bookstore-prod
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: vault-backend
    kind: ClusterSecretStore
  target:
    name: mongodb-secret
  data:
    - secretKey: username
      remoteRef:
        key: bookstore/mongodb
        property: username
    - secretKey: password
      remoteRef:
        key: bookstore/mongodb
        property: password
```

#### 4.4 RBAC Configuration

```yaml
# security/rbac/bookstore-team.yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: bookstore-developer
  namespace: bookstore-prod
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: bookstore-developers
  namespace: bookstore-prod
subjects:
  - kind: Group
    name: bookstore-team
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: bookstore-developer
  apiGroup: rbac.authorization.k8s.io
```

#### 4.5 Security Scanning Policy

```yaml
# security/policies/image-scan-policy.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-scan
spec:
  validationFailureAction: enforce
  rules:
    - name: check-image-scan
      match:
        resources:
          kinds:
            - Pod
          namespaces:
            - bookstore-prod
      validate:
        message: "Images must be scanned and approved"
        pattern:
          spec:
            containers:
              - image: "ghcr.io/techcorp/*"
```

### Phase 4 Deliverables

- [ ] Network policies restricting traffic
- [ ] Pod security standards enforced
- [ ] Secrets managed securely (not in Git)
- [ ] RBAC roles defined for team members
- [ ] Security policies enforced with Kyverno/OPA

---

## 🛡️ Phase 5: Reliability (Modules 7 & 8)

### Objectives
- Configure backups
- Create disaster recovery plan
- Set up operational procedures
- Implement autoscaling

### Tasks

#### 5.1 Velero Backup Configuration

```bash
# Install Velero
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket techcorp-backups \
  --backup-location-config region=us-west-2 \
  --snapshot-location-config region=us-west-2 \
  --secret-file ./credentials-velero
```

```yaml
# backup/schedules/bookstore-backup.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: bookstore-daily
  namespace: velero
spec:
  schedule: "0 2 * * *"
  template:
    includedNamespaces:
      - bookstore-prod
    includedResources:
      - deployments
      - services
      - configmaps
      - secrets
      - persistentvolumeclaims
    ttl: 168h  # 7 days
```

#### 5.2 PodDisruptionBudgets

```yaml
# reliability/pdbs/catalog-pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: catalog-service-pdb
  namespace: bookstore-prod
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: catalog-service
---
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: frontend-pdb
  namespace: bookstore-prod
spec:
  maxUnavailable: 1
  selector:
    matchLabels:
      app: frontend
```

#### 5.3 Horizontal Pod Autoscaling

```yaml
# reliability/autoscaling/catalog-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: catalog-service-hpa
  namespace: bookstore-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
```

#### 5.4 Disaster Recovery Runbook

Create `reliability/runbooks/disaster-recovery.md`:

```markdown
# BookStore Disaster Recovery Runbook

## RTO: 1 hour | RPO: 1 hour

## Scenario 1: Single Service Failure

1. Check service status:
   ```bash
   kubectl get pods -n bookstore-prod -l app=<service>
   ```

2. Check recent events:
   ```bash
   kubectl describe deployment <service> -n bookstore-prod
   ```

3. Restart deployment:
   ```bash
   kubectl rollout restart deployment/<service> -n bookstore-prod
   ```

4. If persistent issue, rollback:
   ```bash
   kubectl rollout undo deployment/<service> -n bookstore-prod
   ```

## Scenario 2: Database Corruption

1. Stop all services writing to MongoDB:
   ```bash
   kubectl scale deployment catalog-service --replicas=0 -n bookstore-prod
   ```

2. Restore from Velero backup:
   ```bash
   velero restore create --from-backup bookstore-daily-<date> \
     --include-resources persistentvolumeclaims,persistentvolumes
   ```

3. Verify data integrity
4. Resume services

## Scenario 3: Complete Cluster Failure

1. Provision new cluster
2. Install platform components (ArgoCD, monitoring)
3. Connect ArgoCD to GitOps repo
4. Restore stateful workloads from Velero
5. Verify application functionality
```

#### 5.5 Maintenance Procedures

```bash
#!/bin/bash
# reliability/scripts/maintenance-window.sh

echo "=== BookStore Maintenance Window Script ==="

# Pre-maintenance checks
echo "1. Taking pre-maintenance backup..."
velero backup create pre-maintenance-$(date +%Y%m%d) \
  --include-namespaces bookstore-prod

echo "2. Checking PDB status..."
kubectl get pdb -n bookstore-prod

echo "3. Current pod distribution..."
kubectl get pods -n bookstore-prod -o wide

# Perform rolling maintenance
for node in $(kubectl get nodes -l workload-type=general -o jsonpath='{.items[*].metadata.name}'); do
    echo "=== Maintaining $node ==="
    
    kubectl cordon $node
    kubectl drain $node --ignore-daemonsets --delete-emptydir-data --grace-period=300
    
    echo "Perform maintenance on $node now..."
    read -p "Press enter when maintenance complete..."
    
    kubectl uncordon $node
    
    # Wait for pods to stabilize
    sleep 60
done

echo "Maintenance complete. Verifying cluster health..."
kubectl get nodes
kubectl get pods -n bookstore-prod
```

### Phase 5 Deliverables

- [ ] Velero installed with backup schedules
- [ ] PodDisruptionBudgets configured
- [ ] HPA configured for autoscaling
- [ ] Disaster recovery runbook created
- [ ] Maintenance scripts prepared

---

## ✅ Phase 6: Final Validation

### Assessment Criteria

Complete the following validation checklist:

#### Infrastructure (20 points)
- [ ] Cluster running with proper node configuration
- [ ] Namespaces with resource quotas
- [ ] ArgoCD managing all deployments

#### Application (20 points)
- [ ] All microservices healthy
- [ ] End-to-end request flow working
- [ ] CI/CD pipeline deploying changes

#### Observability (20 points)
- [ ] Metrics being collected
- [ ] Dashboards showing application health
- [ ] Alerts configured and functional
- [ ] Logs queryable in Loki

#### Security (20 points)
- [ ] Network policies blocking unauthorized traffic
- [ ] Pod security standards enforced
- [ ] Secrets not in plaintext
- [ ] RBAC limiting access appropriately

#### Reliability (20 points)
- [ ] Backups running on schedule
- [ ] PDBs protecting availability
- [ ] Autoscaling responding to load
- [ ] DR runbook tested

### Validation Script

```bash
#!/bin/bash
# phase-6-assessment/validate.sh

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        CNPE Capstone Project - Final Validation           ║"
echo "╚═══════════════════════════════════════════════════════════╝"

PASS=0
FAIL=0

check() {
    if eval "$2" > /dev/null 2>&1; then
        echo "✅ PASS: $1"
        ((PASS++))
    else
        echo "❌ FAIL: $1"
        ((FAIL++))
    fi
}

echo ""
echo "=== Infrastructure Checks ==="
check "Cluster nodes ready" "kubectl get nodes | grep -c ' Ready' | grep -q '[3-9]'"
check "ArgoCD running" "kubectl get pods -n argocd | grep -c Running | grep -q '[5-9]'"
check "Namespaces created" "kubectl get ns bookstore-prod"

echo ""
echo "=== Application Checks ==="
check "Frontend running" "kubectl get pods -n bookstore-prod -l app=frontend | grep Running"
check "Catalog service running" "kubectl get pods -n bookstore-prod -l app=catalog-service | grep Running"
check "MongoDB running" "kubectl get pods -n bookstore-prod -l app=mongodb | grep Running"

echo ""
echo "=== Observability Checks ==="
check "Prometheus running" "kubectl get pods -n monitoring -l app=prometheus | grep Running"
check "Grafana running" "kubectl get pods -n monitoring | grep grafana | grep Running"
check "Alerts configured" "kubectl get prometheusrules -n monitoring | grep bookstore"

echo ""
echo "=== Security Checks ==="
check "Network policies exist" "kubectl get networkpolicy -n bookstore-prod | grep -c . | grep -q '[3-9]'"
check "Pod security labels" "kubectl get ns bookstore-prod -o yaml | grep pod-security"

echo ""
echo "=== Reliability Checks ==="
check "PDBs configured" "kubectl get pdb -n bookstore-prod | grep -c . | grep -q '[2-9]'"
check "HPA configured" "kubectl get hpa -n bookstore-prod | grep catalog"
check "Velero backups" "velero backup get 2>/dev/null | grep -c Completed"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed"
echo "Score: $(( PASS * 100 / (PASS + FAIL) ))%"
echo "═══════════════════════════════════════════════════════════"
```

---

## 🏅 Completion Criteria

To successfully complete the capstone:

| Requirement | Minimum Score |
|-------------|---------------|
| Infrastructure | 80% |
| Application | 80% |
| Observability | 80% |
| Security | 80% |
| Reliability | 80% |
| **Overall** | **80%** |

---

## 🎓 Certificate of Completion

Upon successful validation, you have demonstrated proficiency in:

- ☁️ Cloud Native Platform Engineering
- 🔄 GitOps and Continuous Delivery
- 📊 Observability and SRE Practices
- 🔒 Security Hardening
- 🛡️ Disaster Recovery and Operations

**Congratulations, Platform Engineer!** 🎉

---

## 📚 Additional Challenges

For extra credit, implement:

1. **Multi-cluster Federation** - Extend to multiple clusters
2. **Service Mesh** - Add Istio or Linkerd
3. **Progressive Delivery** - Implement canary deployments with Argo Rollouts
4. **Chaos Engineering** - Add chaos experiments with Litmus
5. **Cost Optimization** - Integrate Kubecost and optimize resources

---

## 🆘 Need Help?

- Review module quick references
- Check solution files in `solutions/` directory
- Refer to official Kubernetes documentation
- Join CNCF Slack community
