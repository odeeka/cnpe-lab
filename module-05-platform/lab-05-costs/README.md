# Lab 5: Cost Management and FinOps

## Overview

Cost management is critical for sustainable platform operations. This lab covers implementing cost visibility, allocation, optimization strategies, and FinOps practices using Kubernetes-native tools like Kubecost, along with resource quota management and budget policies.

## Learning Objectives

By the end of this lab, you will be able to:

- Deploy and configure Kubecost for cost visibility
- Implement cost allocation and showback/chargeback
- Set up resource quotas and limit ranges
- Create budget alerts and policies
- Optimize resource utilization
- Implement spot/preemptible instance strategies

## Prerequisites

- Completed Labs 1-4 (Backstage, Crossplane, Golden Paths, Automation)
- Kubernetes cluster with metrics-server
- Prometheus stack deployed (from Module 4)
- kubectl configured with cluster access

---

## Part 1: Understanding Kubernetes Cost Management

### Cost Components in Kubernetes

```
┌─────────────────────────────────────────────────────────────────┐
│                    KUBERNETES COST MODEL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    INFRASTRUCTURE                         │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐     │   │
│  │  │ Compute │  │ Storage │  │ Network │  │  Other  │     │   │
│  │  │  (CPU)  │  │  (PVC)  │  │(Egress) │  │(License)│     │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘     │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                  ALLOCATION MODEL                         │   │
│  │                                                           │   │
│  │   Namespace ──► Team ──► Project ──► Environment         │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   VISIBILITY                              │   │
│  │                                                           │   │
│  │   Showback ◄──────────────────────────────► Chargeback   │   │
│  │   (Inform)                                    (Invoice)   │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### FinOps Principles for Kubernetes

1. **Visibility**: Know what you're spending and why
2. **Allocation**: Attribute costs to teams/projects
3. **Optimization**: Right-size resources and reduce waste
4. **Governance**: Set policies and budgets
5. **Accountability**: Teams own their costs

---

## Part 2: Deploying Kubecost

### Exercise 1: Install Kubecost

Deploy Kubecost for cost monitoring:

```bash
# Add Kubecost Helm repository
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update

# Create namespace
kubectl create namespace kubecost

# Install Kubecost
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  --set kubecostToken="your-token" \
  --set prometheus.enabled=false \
  --set prometheus.fqdn=http://prometheus-server.monitoring.svc:9090 \
  --set persistentVolume.enabled=true \
  --set persistentVolume.size=10Gi
```

Alternatively, use a values file:

```yaml
# kubecost-values.yaml
kubecostProductConfigs:
  clusterName: "platform-cluster"
  currencyCode: "USD"
  
prometheus:
  enabled: false
  fqdn: http://prometheus-server.monitoring.svc:9090

persistentVolume:
  enabled: true
  size: 10Gi
  storageClass: "standard"

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: kubecost.platform.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: kubecost-tls
      hosts:
        - kubecost.platform.example.com

# Cost allocation settings
kubecostModel:
  # Enable shared cost allocation
  shareTenancyCosts: true
  # Idle cost distribution
  idleCostDistribution: "weighted"

# Enable network cost monitoring
networkCosts:
  enabled: true
  
# GPU cost monitoring
kubecostMetrics:
  exporter:
    enabled: true
```

Apply:

```bash
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  -f kubecost-values.yaml

# Wait for deployment
kubectl rollout status deployment/kubecost-cost-analyzer -n kubecost

# Port-forward to access UI
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090
```

### Exercise 2: Configure Cloud Provider Pricing

Configure accurate pricing from your cloud provider:

```yaml
# cloud-integration-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cloud-integration
  namespace: kubecost
type: Opaque
stringData:
  # AWS Configuration
  aws-service-key.json: |
    {
      "aws_access_key_id": "AKIAXXXXXXXX",
      "aws_secret_access_key": "secret-key"
    }
  
  # Or GCP Configuration
  gcp-service-key.json: |
    {
      "type": "service_account",
      "project_id": "my-project",
      "private_key_id": "key-id",
      "private_key": "-----BEGIN PRIVATE KEY-----\n...",
      "client_email": "kubecost@my-project.iam.gserviceaccount.com"
    }
---
# Cloud provider integration ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: pricing-configs
  namespace: kubecost
data:
  # Custom pricing for on-prem or custom rates
  default.json: |
    {
      "provider": "custom",
      "description": "Custom pricing",
      "CPU": "0.031611",
      "spotCPU": "0.006655",
      "RAM": "0.004237",
      "spotRAM": "0.000892",
      "GPU": "0.95",
      "storage": "0.00005479452",
      "zoneNetworkEgress": "0.01",
      "regionNetworkEgress": "0.01",
      "internetNetworkEgress": "0.12"
    }
```

### Exercise 3: Set Up Cost Allocation Labels

Define standard labels for cost allocation:

```yaml
# cost-allocation-policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: allocation-config
  namespace: kubecost
data:
  allocation.yaml: |
    # Required labels for cost allocation
    requiredLabels:
      - name: "team"
        description: "Team owning the resource"
        validation: "^[a-z0-9-]+$"
      - name: "project"
        description: "Project or application name"
        validation: "^[a-z0-9-]+$"
      - name: "environment"
        description: "Deployment environment"
        allowedValues:
          - "development"
          - "staging"
          - "production"
      - name: "cost-center"
        description: "Finance cost center code"
        validation: "^CC[0-9]{4}$"

    # Aggregation hierarchy
    aggregations:
      - name: "by-team"
        labels: ["team"]
      - name: "by-project"
        labels: ["team", "project"]
      - name: "by-environment"
        labels: ["team", "project", "environment"]

    # Shared cost distribution
    sharedCosts:
      - name: "platform-services"
        namespaces:
          - "monitoring"
          - "logging"
          - "ingress-nginx"
        distribution: "proportional"  # or "even"
```

Create a validating webhook to enforce labels:

```yaml
# label-validation-webhook.yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: cost-labels-validator
webhooks:
  - name: cost-labels.platform.example.com
    admissionReviewVersions: ["v1"]
    clientConfig:
      service:
        name: cost-labels-webhook
        namespace: kubecost
        path: /validate
    rules:
      - operations: ["CREATE", "UPDATE"]
        apiGroups: ["apps"]
        apiVersions: ["v1"]
        resources: ["deployments", "statefulsets", "daemonsets"]
    failurePolicy: Warn
    sideEffects: None
---
# Webhook implementation
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cost-labels-webhook
  namespace: kubecost
spec:
  replicas: 2
  selector:
    matchLabels:
      app: cost-labels-webhook
  template:
    metadata:
      labels:
        app: cost-labels-webhook
    spec:
      containers:
        - name: webhook
          image: ghcr.io/example/cost-labels-webhook:v1
          ports:
            - containerPort: 8443
          env:
            - name: REQUIRED_LABELS
              value: "team,project,environment"
            - name: ENFORCE_MODE
              value: "warn"  # or "deny"
          volumeMounts:
            - name: certs
              mountPath: /etc/webhook/certs
              readOnly: true
      volumes:
        - name: certs
          secret:
            secretName: cost-labels-webhook-certs
```

---

## Part 3: Resource Quotas and Limits

### Exercise 4: Namespace Resource Quotas

Create resource quotas for teams:

```yaml
# team-quota-template.yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-backend  # Apply per team namespace
  labels:
    team: backend
spec:
  hard:
    # Compute resources
    requests.cpu: "20"
    requests.memory: 40Gi
    limits.cpu: "40"
    limits.memory: 80Gi
    
    # Storage resources
    requests.storage: 100Gi
    persistentvolumeclaims: "20"
    
    # Object counts
    pods: "50"
    services: "20"
    secrets: "50"
    configmaps: "50"
    
    # Special resource types
    count/deployments.apps: "20"
    count/statefulsets.apps: "10"
    count/jobs.batch: "30"
    
  # Scopes for quota
  scopes: []
  scopeSelector:
    matchExpressions: []
---
# Production-specific quota (higher limits)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: production-quota
  namespace: team-backend-prod
spec:
  hard:
    requests.cpu: "100"
    requests.memory: 200Gi
    limits.cpu: "200"
    limits.memory: 400Gi
    pods: "200"
---
# Development quota (lower limits, BestEffort allowed)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: team-backend-dev
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "30"
  # Allow BestEffort pods in dev
  scopes:
    - NotBestEffort
```

### Exercise 5: Limit Ranges

Set default resource limits:

```yaml
# limit-range-template.yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: team-backend
spec:
  limits:
    # Container defaults
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      max:
        cpu: "4"
        memory: "8Gi"
      min:
        cpu: "50m"
        memory: "64Mi"
      maxLimitRequestRatio:
        cpu: "10"
        memory: "4"
    
    # Pod limits
    - type: Pod
      max:
        cpu: "8"
        memory: "16Gi"
      min:
        cpu: "50m"
        memory: "64Mi"
    
    # PVC limits
    - type: PersistentVolumeClaim
      max:
        storage: "50Gi"
      min:
        storage: "1Gi"
```

### Exercise 6: Quota Management Operator

Create an operator to manage quotas dynamically:

```yaml
# quota-manager-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: teamquotas.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: TeamQuota
    listKind: TeamQuotaList
    plural: teamquotas
    singular: teamquota
    shortNames:
      - tq
  scope: Cluster
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - team
                - tier
              properties:
                team:
                  type: string
                tier:
                  type: string
                  enum: ["starter", "standard", "enterprise"]
                customLimits:
                  type: object
                  properties:
                    cpu:
                      type: string
                    memory:
                      type: string
                    storage:
                      type: string
                    pods:
                      type: integer
                namespaces:
                  type: array
                  items:
                    type: string
            status:
              type: object
              properties:
                applied:
                  type: boolean
                namespaces:
                  type: array
                  items:
                    type: object
                    properties:
                      name:
                        type: string
                      quotaStatus:
                        type: string
      additionalPrinterColumns:
        - name: Team
          type: string
          jsonPath: .spec.team
        - name: Tier
          type: string
          jsonPath: .spec.tier
        - name: Applied
          type: boolean
          jsonPath: .status.applied
---
# Example TeamQuota
apiVersion: platform.example.com/v1alpha1
kind: TeamQuota
metadata:
  name: backend-team
spec:
  team: backend
  tier: standard
  namespaces:
    - backend-dev
    - backend-staging
    - backend-prod
  customLimits:
    cpu: "50"
    memory: "100Gi"
```

Quota tier definitions:

```yaml
# quota-tiers-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: quota-tiers
  namespace: platform-system
data:
  tiers.yaml: |
    tiers:
      starter:
        description: "For small teams and experiments"
        limits:
          cpu: "10"
          memory: "20Gi"
          storage: "50Gi"
          pods: 20
          pvcs: 5
        
      standard:
        description: "For regular development teams"
        limits:
          cpu: "50"
          memory: "100Gi"
          storage: "200Gi"
          pods: 100
          pvcs: 20
        
      enterprise:
        description: "For large teams with production workloads"
        limits:
          cpu: "200"
          memory: "400Gi"
          storage: "1Ti"
          pods: 500
          pvcs: 100
```

---

## Part 4: Budget Alerts and Policies

### Exercise 7: Cost Budget CRD

Define budget constraints:

```yaml
# budget-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: costbudgets.finops.example.com
spec:
  group: finops.example.com
  names:
    kind: CostBudget
    listKind: CostBudgetList
    plural: costbudgets
    singular: costbudget
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - amount
                - period
              properties:
                amount:
                  type: number
                  description: "Budget amount in currency units"
                currency:
                  type: string
                  default: "USD"
                period:
                  type: string
                  enum: ["daily", "weekly", "monthly"]
                selector:
                  type: object
                  properties:
                    matchLabels:
                      type: object
                      additionalProperties:
                        type: string
                    namespaces:
                      type: array
                      items:
                        type: string
                thresholds:
                  type: array
                  items:
                    type: object
                    properties:
                      percentage:
                        type: integer
                        minimum: 1
                        maximum: 100
                      action:
                        type: string
                        enum: ["notify", "warn", "block"]
                notifications:
                  type: object
                  properties:
                    slack:
                      type: string
                    email:
                      type: array
                      items:
                        type: string
                    pagerduty:
                      type: string
            status:
              type: object
              properties:
                currentSpend:
                  type: number
                percentUsed:
                  type: number
                lastUpdated:
                  type: string
                  format: date-time
                alerts:
                  type: array
                  items:
                    type: object
                    properties:
                      threshold:
                        type: integer
                      triggeredAt:
                        type: string
                        format: date-time
                      acknowledged:
                        type: boolean
---
# Example budget
apiVersion: finops.example.com/v1alpha1
kind: CostBudget
metadata:
  name: backend-monthly
  namespace: team-backend
spec:
  amount: 5000
  currency: USD
  period: monthly
  selector:
    matchLabels:
      team: backend
  thresholds:
    - percentage: 50
      action: notify
    - percentage: 80
      action: warn
    - percentage: 100
      action: block
  notifications:
    slack: "#backend-costs"
    email:
      - backend-lead@example.com
      - finops@example.com
```

### Exercise 8: Budget Controller

Implement budget monitoring:

```go
// internal/controller/costbudget_controller.go
package controller

import (
	"context"
	"fmt"
	"time"

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	finopsv1alpha1 "github.com/example/finops-operator/api/v1alpha1"
)

type CostBudgetReconciler struct {
	client.Client
	Scheme      *runtime.Scheme
	CostClient  *KubecostClient
	Notifier    *NotificationService
}

func (r *CostBudgetReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the CostBudget
	budget := &finopsv1alpha1.CostBudget{}
	if err := r.Get(ctx, req.NamespacedName, budget); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Get current cost from Kubecost
	currentCost, err := r.CostClient.GetNamespaceCost(
		budget.Namespace,
		budget.Spec.Period,
		budget.Spec.Selector,
	)
	if err != nil {
		logger.Error(err, "Failed to get cost data")
		return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
	}

	// Update status
	budget.Status.CurrentSpend = currentCost
	budget.Status.PercentUsed = (currentCost / budget.Spec.Amount) * 100
	budget.Status.LastUpdated = &metav1.Time{Time: time.Now()}

	// Check thresholds
	for _, threshold := range budget.Spec.Thresholds {
		if budget.Status.PercentUsed >= float64(threshold.Percentage) {
			if !r.isAlertTriggered(budget, threshold.Percentage) {
				// Trigger alert
				alert := finopsv1alpha1.BudgetAlert{
					Threshold:   threshold.Percentage,
					TriggeredAt: &metav1.Time{Time: time.Now()},
				}
				budget.Status.Alerts = append(budget.Status.Alerts, alert)

				// Send notification
				r.sendNotification(ctx, budget, threshold)

				// Take action if needed
				if threshold.Action == "block" {
					r.blockNewResources(ctx, budget)
				}
			}
		}
	}

	// Update status
	if err := r.Status().Update(ctx, budget); err != nil {
		return ctrl.Result{}, err
	}

	// Requeue for periodic checking
	return ctrl.Result{RequeueAfter: 15 * time.Minute}, nil
}

func (r *CostBudgetReconciler) sendNotification(ctx context.Context, budget *finopsv1alpha1.CostBudget, threshold finopsv1alpha1.Threshold) {
	message := fmt.Sprintf(
		"🚨 Budget Alert: %s/%s\n"+
			"Threshold: %d%% reached\n"+
			"Current Spend: $%.2f / $%.2f\n"+
			"Action: %s",
		budget.Namespace, budget.Name,
		threshold.Percentage,
		budget.Status.CurrentSpend, budget.Spec.Amount,
		threshold.Action,
	)

	if budget.Spec.Notifications.Slack != "" {
		r.Notifier.SendSlack(budget.Spec.Notifications.Slack, message)
	}

	for _, email := range budget.Spec.Notifications.Email {
		r.Notifier.SendEmail(email, "Budget Alert", message)
	}
}

func (r *CostBudgetReconciler) blockNewResources(ctx context.Context, budget *finopsv1alpha1.CostBudget) error {
	// Create a ResourceQuota with 0 limits to block new resources
	blockingQuota := &corev1.ResourceQuota{
		ObjectMeta: metav1.ObjectMeta{
			Name:      budget.Name + "-budget-block",
			Namespace: budget.Namespace,
			Labels: map[string]string{
				"finops.example.com/budget": budget.Name,
				"finops.example.com/type":   "budget-block",
			},
		},
		Spec: corev1.ResourceQuotaSpec{
			Hard: corev1.ResourceList{
				corev1.ResourcePods: resource.MustParse("0"),
			},
			Scopes: []corev1.ResourceQuotaScope{
				corev1.ResourceQuotaScopeNotTerminating,
			},
		},
	}

	return r.Create(ctx, blockingQuota)
}

func (r *CostBudgetReconciler) isAlertTriggered(budget *finopsv1alpha1.CostBudget, threshold int) bool {
	for _, alert := range budget.Status.Alerts {
		if alert.Threshold == threshold {
			return true
		}
	}
	return false
}
```

### Exercise 9: Prometheus Alerting Rules

Create Prometheus alerts for cost monitoring:

```yaml
# cost-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cost-alerts
  namespace: monitoring
spec:
  groups:
    - name: cost.rules
      interval: 15m
      rules:
        # High cost workload alert
        - alert: HighCostWorkload
          expr: |
            sum by (namespace, owner_name) (
              kubecost_container_cpu_allocation_cost 
              + kubecost_container_memory_allocation_cost
            ) > 100
          for: 1h
          labels:
            severity: warning
            category: cost
          annotations:
            summary: "High cost workload detected"
            description: "Workload {{ $labels.owner_name }} in {{ $labels.namespace }} is costing more than $100/day"

        # Idle resources alert
        - alert: IdleResources
          expr: |
            (
              sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"})
              - sum by (namespace) (rate(container_cpu_usage_seconds_total[1h]))
            ) 
            / sum by (namespace) (kube_pod_container_resource_requests{resource="cpu"}) 
            > 0.8
          for: 4h
          labels:
            severity: info
            category: optimization
          annotations:
            summary: "High idle CPU in namespace"
            description: "Namespace {{ $labels.namespace }} has >80% idle CPU resources"

        # Budget threshold alert
        - alert: BudgetThresholdReached
          expr: |
            kubecost_namespace_monthly_cost / on(namespace) kubecost_namespace_budget > 0.8
          for: 30m
          labels:
            severity: warning
            category: budget
          annotations:
            summary: "Budget threshold reached"
            description: "Namespace {{ $labels.namespace }} has used 80% of monthly budget"

        # Unallocated costs alert
        - alert: HighUnallocatedCosts
          expr: |
            sum(kubecost_cluster_cost{type="idle"}) 
            / sum(kubecost_cluster_cost) 
            > 0.3
          for: 1h
          labels:
            severity: warning
            category: efficiency
          annotations:
            summary: "High unallocated cluster costs"
            description: "More than 30% of cluster costs are unallocated/idle"

        # Spot instance failures
        - alert: SpotInstanceInterruptions
          expr: |
            increase(kubecost_node_spot_interruption_total[1h]) > 5
          labels:
            severity: info
            category: spot
          annotations:
            summary: "Multiple spot instance interruptions"
            description: "{{ $value }} spot instances interrupted in the last hour"

    - name: cost.recording
      rules:
        # Namespace daily cost
        - record: namespace:daily_cost:sum
          expr: |
            sum by (namespace) (
              kubecost_container_cpu_allocation_cost * 24
              + kubecost_container_memory_allocation_cost * 24
              + kubecost_pv_allocation_cost * 24
              + kubecost_network_cost * 24
            )

        # Team daily cost
        - record: team:daily_cost:sum
          expr: |
            sum by (team) (
              namespace:daily_cost:sum 
              * on(namespace) group_left(team) 
              kube_namespace_labels{label_team!=""}
            )

        # Cost per pod
        - record: pod:hourly_cost:sum
          expr: |
            sum by (namespace, pod) (
              kubecost_container_cpu_allocation_cost
              + kubecost_container_memory_allocation_cost
            )
```

---

## Part 5: Cost Optimization

### Exercise 10: Right-Sizing Recommendations

Create a tool to analyze and recommend resource adjustments:

```yaml
# rightsizing-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: rightsizing-analyzer
  namespace: kubecost
spec:
  schedule: "0 6 * * 1"  # Weekly on Monday at 6 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: rightsizing-analyzer
          containers:
            - name: analyzer
              image: ghcr.io/example/rightsizing-analyzer:v1
              env:
                - name: PROMETHEUS_URL
                  value: "http://prometheus-server.monitoring:9090"
                - name: ANALYSIS_WINDOW
                  value: "7d"
                - name: CPU_PERCENTILE
                  value: "95"
                - name: MEMORY_PERCENTILE
                  value: "95"
                - name: MIN_SAMPLES
                  value: "100"
                - name: SLACK_WEBHOOK
                  valueFrom:
                    secretKeyRef:
                      name: slack-webhook
                      key: url
              command:
                - /analyzer
                - --output-format=slack
                - --threshold-cpu=0.3
                - --threshold-memory=0.3
          restartPolicy: OnFailure
```

Right-sizing analyzer script:

```python
#!/usr/bin/env python3
# rightsizing_analyzer.py

import os
import json
import requests
from datetime import datetime, timedelta

PROMETHEUS_URL = os.environ.get('PROMETHEUS_URL', 'http://prometheus:9090')
ANALYSIS_WINDOW = os.environ.get('ANALYSIS_WINDOW', '7d')
CPU_PERCENTILE = int(os.environ.get('CPU_PERCENTILE', '95'))
MEMORY_PERCENTILE = int(os.environ.get('MEMORY_PERCENTILE', '95'))

def query_prometheus(query):
    """Execute PromQL query"""
    response = requests.get(
        f"{PROMETHEUS_URL}/api/v1/query",
        params={'query': query}
    )
    return response.json()['data']['result']

def get_recommendations():
    """Generate right-sizing recommendations"""
    recommendations = []
    
    # Get CPU usage vs requests
    cpu_query = f'''
    avg by (namespace, pod, container) (
        rate(container_cpu_usage_seconds_total{{container!=""}}[{ANALYSIS_WINDOW}])
    ) 
    / on(namespace, pod, container) 
    kube_pod_container_resource_requests{{resource="cpu"}}
    '''
    
    cpu_results = query_prometheus(cpu_query)
    
    for result in cpu_results:
        namespace = result['metric']['namespace']
        pod = result['metric']['pod']
        container = result['metric']['container']
        usage_ratio = float(result['value'][1])
        
        if usage_ratio < 0.3:  # Using less than 30% of requested
            # Get current request
            current_request = query_prometheus(f'''
                kube_pod_container_resource_requests{{
                    namespace="{namespace}",
                    pod="{pod}",
                    container="{container}",
                    resource="cpu"
                }}
            ''')
            
            if current_request:
                current = float(current_request[0]['value'][1])
                recommended = current * (usage_ratio / 0.7)  # Target 70% utilization
                
                savings = (current - recommended) * 0.031611 * 24 * 30  # Monthly savings
                
                recommendations.append({
                    'namespace': namespace,
                    'workload': pod.rsplit('-', 2)[0],  # Extract deployment name
                    'container': container,
                    'resource': 'cpu',
                    'current': f"{current*1000:.0f}m",
                    'recommended': f"{recommended*1000:.0f}m",
                    'savings_monthly': f"${savings:.2f}"
                })
    
    # Similar analysis for memory
    memory_query = f'''
    avg by (namespace, pod, container) (
        container_memory_usage_bytes{{container!=""}}
    ) 
    / on(namespace, pod, container) 
    kube_pod_container_resource_requests{{resource="memory"}}
    '''
    
    memory_results = query_prometheus(memory_query)
    
    for result in memory_results:
        namespace = result['metric']['namespace']
        pod = result['metric']['pod']
        container = result['metric']['container']
        usage_ratio = float(result['value'][1])
        
        if usage_ratio < 0.3:
            current_request = query_prometheus(f'''
                kube_pod_container_resource_requests{{
                    namespace="{namespace}",
                    pod="{pod}",
                    container="{container}",
                    resource="memory"
                }}
            ''')
            
            if current_request:
                current = float(current_request[0]['value'][1])
                recommended = current * (usage_ratio / 0.7)
                
                savings = ((current - recommended) / (1024**3)) * 0.004237 * 24 * 30
                
                recommendations.append({
                    'namespace': namespace,
                    'workload': pod.rsplit('-', 2)[0],
                    'container': container,
                    'resource': 'memory',
                    'current': f"{current/(1024**2):.0f}Mi",
                    'recommended': f"{recommended/(1024**2):.0f}Mi",
                    'savings_monthly': f"${savings:.2f}"
                })
    
    return recommendations

def format_slack_message(recommendations):
    """Format recommendations as Slack message"""
    if not recommendations:
        return {"text": "✅ No right-sizing recommendations at this time."}
    
    total_savings = sum(
        float(r['savings_monthly'].replace('$', ''))
        for r in recommendations
    )
    
    blocks = [
        {
            "type": "header",
            "text": {
                "type": "plain_text",
                "text": "📊 Weekly Right-Sizing Report"
            }
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*Potential Monthly Savings: ${total_savings:.2f}*\n{len(recommendations)} recommendations found"
            }
        },
        {"type": "divider"}
    ]
    
    # Group by namespace
    by_namespace = {}
    for rec in recommendations:
        ns = rec['namespace']
        if ns not in by_namespace:
            by_namespace[ns] = []
        by_namespace[ns].append(rec)
    
    for namespace, recs in list(by_namespace.items())[:5]:  # Top 5 namespaces
        ns_savings = sum(float(r['savings_monthly'].replace('$', '')) for r in recs)
        
        blocks.append({
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": f"*{namespace}* - ${ns_savings:.2f}/month\n" + 
                       "\n".join([
                           f"• {r['workload']}/{r['container']}: {r['resource']} {r['current']} → {r['recommended']}"
                           for r in recs[:3]
                       ])
            }
        })
    
    return {"blocks": blocks}

if __name__ == "__main__":
    recommendations = get_recommendations()
    
    slack_webhook = os.environ.get('SLACK_WEBHOOK')
    if slack_webhook:
        message = format_slack_message(recommendations)
        requests.post(slack_webhook, json=message)
    else:
        print(json.dumps(recommendations, indent=2))
```

### Exercise 11: Spot Instance Strategy

Configure workloads for spot/preemptible instances:

```yaml
# spot-nodepool-config.yaml
# For GKE
apiVersion: container.google.com/v1
kind: NodePool
metadata:
  name: spot-pool
spec:
  autoscaling:
    enabled: true
    minNodeCount: 0
    maxNodeCount: 50
  config:
    preemptible: true
    machineType: n2-standard-4
    labels:
      node-type: spot
      workload-type: batch
    taints:
      - key: cloud.google.com/gke-preemptible
        value: "true"
        effect: NoSchedule
---
# Workload configuration for spot
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor
  namespace: batch-jobs
spec:
  replicas: 10
  selector:
    matchLabels:
      app: batch-processor
  template:
    metadata:
      labels:
        app: batch-processor
    spec:
      # Tolerate spot taints
      tolerations:
        - key: cloud.google.com/gke-preemptible
          operator: Equal
          value: "true"
          effect: NoSchedule
        - key: kubernetes.azure.com/scalesetpriority
          operator: Equal
          value: spot
          effect: NoSchedule
      
      # Prefer spot nodes
      affinity:
        nodeAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              preference:
                matchExpressions:
                  - key: node-type
                    operator: In
                    values:
                      - spot
                      - preemptible
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: workload-type
                    operator: In
                    values:
                      - batch
                      - spot-eligible
      
      # Handle preemption gracefully
      terminationGracePeriodSeconds: 30
      
      containers:
        - name: processor
          image: batch-processor:v1
          resources:
            requests:
              cpu: "1"
              memory: "2Gi"
            limits:
              cpu: "2"
              memory: "4Gi"
          # Checkpoint before termination
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - /app/checkpoint.sh
```

Spot instance fallback with Pod Disruption Budget:

```yaml
# spot-fallback-config.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: batch-processor-pdb
  namespace: batch-jobs
spec:
  minAvailable: 5
  selector:
    matchLabels:
      app: batch-processor
---
# Fallback to on-demand if spot unavailable
apiVersion: apps/v1
kind: Deployment
metadata:
  name: batch-processor-fallback
  namespace: batch-jobs
  annotations:
    spot-fallback/enabled: "true"
    spot-fallback/threshold: "3"  # Fallback after 3 spot failures
spec:
  replicas: 0  # Scaled up by fallback controller
  selector:
    matchLabels:
      app: batch-processor
      tier: fallback
  template:
    metadata:
      labels:
        app: batch-processor
        tier: fallback
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node-type
                    operator: In
                    values:
                      - on-demand
      containers:
        - name: processor
          image: batch-processor:v1
          resources:
            requests:
              cpu: "1"
              memory: "2Gi"
```

---

## Part 6: Cost Dashboards and Reports

### Exercise 12: Grafana Cost Dashboard

Create a comprehensive cost dashboard:

```yaml
# cost-dashboard-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cost-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  cost-overview.json: |
    {
      "title": "Platform Cost Overview",
      "uid": "cost-overview",
      "tags": ["cost", "finops"],
      "timezone": "browser",
      "panels": [
        {
          "title": "Daily Cluster Cost",
          "type": "stat",
          "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
          "targets": [
            {
              "expr": "sum(kubecost_cluster_cost)",
              "legendFormat": "Total"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "currencyUSD",
              "thresholds": {
                "mode": "absolute",
                "steps": [
                  {"color": "green", "value": null},
                  {"color": "yellow", "value": 500},
                  {"color": "red", "value": 1000}
                ]
              }
            }
          }
        },
        {
          "title": "Cost by Namespace",
          "type": "piechart",
          "gridPos": {"h": 8, "w": 8, "x": 6, "y": 0},
          "targets": [
            {
              "expr": "topk(10, sum by (namespace) (namespace:daily_cost:sum))",
              "legendFormat": "{{namespace}}"
            }
          ]
        },
        {
          "title": "Cost by Team",
          "type": "piechart",
          "gridPos": {"h": 8, "w": 8, "x": 14, "y": 0},
          "targets": [
            {
              "expr": "sum by (team) (team:daily_cost:sum)",
              "legendFormat": "{{team}}"
            }
          ]
        },
        {
          "title": "Cost Trend (30 days)",
          "type": "timeseries",
          "gridPos": {"h": 8, "w": 24, "x": 0, "y": 8},
          "targets": [
            {
              "expr": "sum(kubecost_cluster_cost)",
              "legendFormat": "Cluster Total"
            },
            {
              "expr": "sum by (namespace) (namespace:daily_cost:sum)",
              "legendFormat": "{{namespace}}"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "currencyUSD"
            }
          }
        },
        {
          "title": "Efficiency Score",
          "type": "gauge",
          "gridPos": {"h": 6, "w": 6, "x": 0, "y": 16},
          "targets": [
            {
              "expr": "1 - (sum(kubecost_cluster_cost{type='idle'}) / sum(kubecost_cluster_cost))",
              "legendFormat": "Efficiency"
            }
          ],
          "fieldConfig": {
            "defaults": {
              "unit": "percentunit",
              "min": 0,
              "max": 1,
              "thresholds": {
                "mode": "percentage",
                "steps": [
                  {"color": "red", "value": null},
                  {"color": "yellow", "value": 50},
                  {"color": "green", "value": 70}
                ]
              }
            }
          }
        },
        {
          "title": "Top 10 Expensive Workloads",
          "type": "table",
          "gridPos": {"h": 8, "w": 12, "x": 6, "y": 16},
          "targets": [
            {
              "expr": "topk(10, sum by (namespace, owner_name) (pod:hourly_cost:sum * 24))",
              "format": "table",
              "instant": true
            }
          ],
          "transformations": [
            {
              "id": "organize",
              "options": {
                "renameByName": {
                  "namespace": "Namespace",
                  "owner_name": "Workload",
                  "Value": "Daily Cost ($)"
                }
              }
            }
          ]
        },
        {
          "title": "Budget Status",
          "type": "table",
          "gridPos": {"h": 8, "w": 6, "x": 18, "y": 16},
          "targets": [
            {
              "expr": "kubecost_namespace_monthly_cost / on(namespace) kubecost_namespace_budget * 100",
              "format": "table",
              "instant": true
            }
          ],
          "transformations": [
            {
              "id": "organize",
              "options": {
                "renameByName": {
                  "namespace": "Namespace",
                  "Value": "Budget Used (%)"
                }
              }
            }
          ],
          "fieldConfig": {
            "overrides": [
              {
                "matcher": {"id": "byName", "options": "Budget Used (%)"},
                "properties": [
                  {
                    "id": "thresholds",
                    "value": {
                      "mode": "absolute",
                      "steps": [
                        {"color": "green", "value": null},
                        {"color": "yellow", "value": 80},
                        {"color": "red", "value": 100}
                      ]
                    }
                  }
                ]
              }
            ]
          }
        }
      ]
    }
```

### Exercise 13: Automated Cost Reports

Create automated cost reporting:

```yaml
# cost-report-cronjob.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: weekly-cost-report
  namespace: kubecost
spec:
  schedule: "0 9 * * 1"  # Monday 9 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
            - name: reporter
              image: ghcr.io/example/cost-reporter:v1
              env:
                - name: KUBECOST_URL
                  value: "http://kubecost-cost-analyzer:9090"
                - name: REPORT_TYPE
                  value: "weekly"
                - name: RECIPIENTS
                  value: "finops@example.com,engineering-leads@example.com"
                - name: SMTP_HOST
                  valueFrom:
                    secretKeyRef:
                      name: smtp-config
                      key: host
              volumeMounts:
                - name: templates
                  mountPath: /templates
          volumes:
            - name: templates
              configMap:
                name: report-templates
          restartPolicy: OnFailure
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: report-templates
  namespace: kubecost
data:
  weekly-report.html: |
    <!DOCTYPE html>
    <html>
    <head>
      <style>
        body { font-family: Arial, sans-serif; }
        .header { background: #2196F3; color: white; padding: 20px; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .card { border: 1px solid #ddd; padding: 15px; border-radius: 8px; }
        .card h3 { margin-top: 0; }
        .increase { color: #f44336; }
        .decrease { color: #4caf50; }
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #f5f5f5; }
      </style>
    </head>
    <body>
      <div class="header">
        <h1>Weekly Cost Report</h1>
        <p>{{ .Period.Start }} - {{ .Period.End }}</p>
      </div>
      
      <div class="summary">
        <div class="card">
          <h3>Total Spend</h3>
          <h2>${{ printf "%.2f" .TotalCost }}</h2>
          <p class="{{ if gt .CostChange 0 }}increase{{ else }}decrease{{ end }}">
            {{ if gt .CostChange 0 }}▲{{ else }}▼{{ end }}
            {{ printf "%.1f" .CostChange }}% vs last week
          </p>
        </div>
        <div class="card">
          <h3>Efficiency</h3>
          <h2>{{ printf "%.0f" .Efficiency }}%</h2>
        </div>
        <div class="card">
          <h3>Active Namespaces</h3>
          <h2>{{ .NamespaceCount }}</h2>
        </div>
      </div>
      
      <h2>Cost by Team</h2>
      <table>
        <tr>
          <th>Team</th>
          <th>Cost</th>
          <th>Change</th>
          <th>Budget Used</th>
        </tr>
        {{ range .TeamCosts }}
        <tr>
          <td>{{ .Team }}</td>
          <td>${{ printf "%.2f" .Cost }}</td>
          <td class="{{ if gt .Change 0 }}increase{{ else }}decrease{{ end }}">
            {{ printf "%.1f" .Change }}%
          </td>
          <td>{{ printf "%.0f" .BudgetUsed }}%</td>
        </tr>
        {{ end }}
      </table>
      
      <h2>Top Optimization Opportunities</h2>
      <table>
        <tr>
          <th>Workload</th>
          <th>Recommendation</th>
          <th>Potential Savings</th>
        </tr>
        {{ range .Recommendations }}
        <tr>
          <td>{{ .Namespace }}/{{ .Workload }}</td>
          <td>{{ .Recommendation }}</td>
          <td>${{ printf "%.2f" .Savings }}/month</td>
        </tr>
        {{ end }}
      </table>
    </body>
    </html>
```

---

## Validation Checkpoint

Verify your cost management setup:

```bash
# 1. Check Kubecost is running
kubectl get pods -n kubecost
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090

# 2. Verify cost data is being collected
curl http://localhost:9090/api/v1/allocation?window=1d

# 3. Check resource quotas
kubectl get resourcequota -A

# 4. Verify budget alerts
kubectl get costbudgets -A

# 5. Check Prometheus rules
kubectl get prometheusrule -n monitoring

# 6. Test right-sizing analyzer
kubectl create job --from=cronjob/rightsizing-analyzer test-analyze -n kubecost
kubectl logs -n kubecost job/test-analyze

# 7. Verify Grafana dashboard
kubectl port-forward -n monitoring svc/grafana 3000:3000
# Open http://localhost:3000 and check cost dashboard
```

---

## Troubleshooting

### Kubecost Not Showing Data

```bash
# Check Prometheus connectivity
kubectl exec -n kubecost deploy/kubecost-cost-analyzer -- \
  curl -s http://prometheus-server.monitoring:9090/api/v1/query?query=up

# Verify metrics are being scraped
kubectl exec -n monitoring deploy/prometheus-server -- \
  wget -q -O- "http://localhost:9090/api/v1/targets" | grep kubecost

# Check Kubecost logs
kubectl logs -n kubecost deploy/kubecost-cost-analyzer -c cost-model
```

### Resource Quota Issues

```bash
# Check quota status
kubectl describe resourcequota -n <namespace>

# Find pods blocked by quota
kubectl get events -n <namespace> --field-selector reason=FailedCreate

# Temporarily increase quota
kubectl patch resourcequota team-quota -n <namespace> \
  --type merge -p '{"spec":{"hard":{"pods":"100"}}}'
```

### Budget Alerts Not Firing

```bash
# Check budget status
kubectl get costbudget -A -o wide

# Verify alert conditions in Prometheus
kubectl port-forward -n monitoring svc/prometheus-server 9090:9090
# Query: kubecost_namespace_monthly_cost / kubecost_namespace_budget

# Check AlertManager
kubectl logs -n monitoring deploy/alertmanager
```

---

## Best Practices

### 1. Label Everything

```yaml
# Standard cost allocation labels
metadata:
  labels:
    team: backend
    project: checkout-service
    environment: production
    cost-center: CC1234
```

### 2. Set Appropriate Defaults

```yaml
# LimitRange for sensible defaults
spec:
  limits:
    - type: Container
      default:
        cpu: "200m"
        memory: "256Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
```

### 3. Regular Right-Sizing Reviews

- Weekly automated analysis
- Monthly optimization reviews
- Quarterly budget adjustments

### 4. Use Spot Instances Wisely

- Batch jobs and dev environments
- Stateless workloads with proper PDBs
- Always have on-demand fallback

---

## Summary

In this lab, you learned:

1. **Kubecost Deployment**
   - Installation and configuration
   - Cloud provider pricing integration
   - Cost allocation labels

2. **Resource Management**
   - ResourceQuotas per namespace/team
   - LimitRanges for defaults
   - Quota management operators

3. **Budget and Alerting**
   - CostBudget custom resources
   - Prometheus alerting rules
   - Threshold-based actions

4. **Cost Optimization**
   - Right-sizing analysis
   - Spot instance strategies
   - Automated recommendations

5. **Reporting and Visibility**
   - Grafana dashboards
   - Automated reports
   - Team showback

---

**Next Lab: [Lab 6 - Multi-Tenancy Patterns](../lab-06-multitenancy/README.md)**
