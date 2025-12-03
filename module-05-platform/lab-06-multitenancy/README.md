# Lab 6: Multi-Tenancy Patterns

## Overview

Multi-tenancy is essential for platform efficiency, allowing multiple teams to share cluster resources while maintaining isolation and security. This lab covers namespace-based isolation, virtual clusters, hierarchical namespaces, and comprehensive RBAC strategies for multi-tenant Kubernetes environments.

## Learning Objectives

By the end of this lab, you will be able to:

- Implement namespace-based tenant isolation
- Deploy and manage virtual clusters with vCluster
- Configure hierarchical namespace controllers
- Design network policies for tenant isolation
- Implement RBAC for multi-tenant environments
- Set up resource quotas per tenant

## Prerequisites

- Completed Labs 1-5 (Platform Engineering fundamentals)
- Kubernetes cluster with NetworkPolicy support (Calico/Cilium)
- kubectl configured with cluster-admin access
- Helm 3.x installed

---

## Part 1: Understanding Multi-Tenancy Models

### Multi-Tenancy Spectrum

```
┌─────────────────────────────────────────────────────────────────┐
│                  MULTI-TENANCY MODELS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SOFT MULTI-TENANCY                    HARD MULTI-TENANCY       │
│  (Shared Cluster)                       (Isolated Clusters)      │
│                                                                  │
│  ┌─────────────┐                       ┌─────────────┐          │
│  │  Namespace  │                       │   vCluster  │          │
│  │  Isolation  │                       │  per Tenant │          │
│  └─────────────┘                       └─────────────┘          │
│        │                                      │                  │
│        ▼                                      ▼                  │
│  ┌─────────────┐                       ┌─────────────┐          │
│  │ NetworkPolicy│                      │  Full API   │          │
│  │    + RBAC   │                       │  Isolation  │          │
│  └─────────────┘                       └─────────────┘          │
│        │                                      │                  │
│        ▼                                      ▼                  │
│  ┌─────────────┐                       ┌─────────────┐          │
│  │   Resource  │                       │  Dedicated  │          │
│  │   Quotas    │                       │  Resources  │          │
│  └─────────────┘                       └─────────────┘          │
│                                                                  │
│  Cost: Low ◄─────────────────────────────────────► Cost: High   │
│  Isolation: Low ◄───────────────────────────► Isolation: High   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### When to Use Each Model

| Model | Use Case | Pros | Cons |
|-------|----------|------|------|
| **Namespace** | Internal teams, dev/staging | Simple, low overhead | Limited isolation |
| **Hierarchical NS** | Large organizations | Delegated admin, inheritance | Complexity |
| **vCluster** | External tenants, strong isolation | Full Kubernetes API | Resource overhead |
| **Dedicated Cluster** | Compliance, maximum isolation | Complete separation | High cost, management |

---

## Part 2: Namespace-Based Multi-Tenancy

### Exercise 1: Tenant Namespace Structure

Create a standardized namespace structure for tenants:

```yaml
# tenant-namespace-template.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-{{ .TenantName }}
  labels:
    # Tenant identification
    tenant.platform.example.com/name: "{{ .TenantName }}"
    tenant.platform.example.com/tier: "{{ .Tier }}"
    tenant.platform.example.com/owner: "{{ .Owner }}"
    
    # Cost allocation
    cost-center: "{{ .CostCenter }}"
    
    # Policy selectors
    pod-security.kubernetes.io/enforce: "{{ .PodSecurityLevel }}"
    pod-security.kubernetes.io/warn: "{{ .PodSecurityLevel }}"
    
    # Network policy labels
    network.platform.example.com/isolation: "enabled"
  annotations:
    # Metadata
    tenant.platform.example.com/created-at: "{{ .CreatedAt }}"
    tenant.platform.example.com/contact: "{{ .ContactEmail }}"
    
    # Scheduler hints
    scheduler.alpha.kubernetes.io/defaultTolerations: '[{"key":"tenant","operator":"Equal","value":"{{ .TenantName }}","effect":"NoSchedule"}]'
---
# Apply default resources
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tenant-admin
  namespace: tenant-{{ .TenantName }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: tenant-config
  namespace: tenant-{{ .TenantName }}
data:
  tenant-name: "{{ .TenantName }}"
  tier: "{{ .Tier }}"
  support-email: "{{ .SupportEmail }}"
```

### Exercise 2: Tenant Onboarding Operator

Create a CRD for tenant management:

```yaml
# tenant-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: Tenant
    listKind: TenantList
    plural: tenants
    singular: tenant
    shortNames:
      - tn
  scope: Cluster
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            spec:
              type: object
              required:
                - name
                - owner
              properties:
                name:
                  type: string
                  pattern: "^[a-z0-9-]+$"
                  maxLength: 32
                owner:
                  type: object
                  required:
                    - name
                    - email
                  properties:
                    name:
                      type: string
                    email:
                      type: string
                      format: email
                    group:
                      type: string
                tier:
                  type: string
                  enum: ["starter", "standard", "enterprise"]
                  default: "standard"
                namespaces:
                  type: array
                  items:
                    type: object
                    properties:
                      name:
                        type: string
                      environment:
                        type: string
                        enum: ["dev", "staging", "prod"]
                quota:
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
                networkPolicy:
                  type: object
                  properties:
                    isolationLevel:
                      type: string
                      enum: ["none", "namespace", "tenant", "strict"]
                      default: "namespace"
                    allowedExternalCIDRs:
                      type: array
                      items:
                        type: string
                    allowedNamespaces:
                      type: array
                      items:
                        type: string
            status:
              type: object
              properties:
                phase:
                  type: string
                namespaces:
                  type: array
                  items:
                    type: object
                    properties:
                      name:
                        type: string
                      status:
                        type: string
                conditions:
                  type: array
                  items:
                    type: object
                    properties:
                      type:
                        type: string
                      status:
                        type: string
                      lastTransitionTime:
                        type: string
                        format: date-time
                      reason:
                        type: string
                      message:
                        type: string
      additionalPrinterColumns:
        - name: Owner
          type: string
          jsonPath: .spec.owner.name
        - name: Tier
          type: string
          jsonPath: .spec.tier
        - name: Phase
          type: string
          jsonPath: .status.phase
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
      subresources:
        status: {}
---
# Example tenant
apiVersion: platform.example.com/v1alpha1
kind: Tenant
metadata:
  name: team-backend
spec:
  name: backend
  owner:
    name: "John Doe"
    email: "john.doe@example.com"
    group: "backend-team"
  tier: standard
  namespaces:
    - name: backend-dev
      environment: dev
    - name: backend-staging
      environment: staging
    - name: backend-prod
      environment: prod
  quota:
    cpu: "50"
    memory: "100Gi"
    storage: "200Gi"
    pods: 100
  networkPolicy:
    isolationLevel: namespace
    allowedNamespaces:
      - monitoring
      - logging
```

### Exercise 3: Tenant Controller

Implement the tenant controller:

```go
// internal/controller/tenant_controller.go
package controller

import (
	"context"
	"fmt"

	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	rbacv1 "k8s.io/api/rbac/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

type TenantReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

func (r *TenantReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the Tenant
	tenant := &platformv1alpha1.Tenant{}
	if err := r.Get(ctx, req.NamespacedName, tenant); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// Initialize status
	if tenant.Status.Phase == "" {
		tenant.Status.Phase = "Provisioning"
		if err := r.Status().Update(ctx, tenant); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Reconcile each namespace
	for _, nsSpec := range tenant.Spec.Namespaces {
		nsName := nsSpec.Name

		// Create namespace
		if err := r.reconcileNamespace(ctx, tenant, nsSpec); err != nil {
			logger.Error(err, "Failed to reconcile namespace", "namespace", nsName)
			return ctrl.Result{}, err
		}

		// Create resource quota
		if err := r.reconcileResourceQuota(ctx, tenant, nsName); err != nil {
			logger.Error(err, "Failed to reconcile quota", "namespace", nsName)
			return ctrl.Result{}, err
		}

		// Create limit range
		if err := r.reconcileLimitRange(ctx, tenant, nsName); err != nil {
			logger.Error(err, "Failed to reconcile limit range", "namespace", nsName)
			return ctrl.Result{}, err
		}

		// Create network policies
		if err := r.reconcileNetworkPolicies(ctx, tenant, nsName); err != nil {
			logger.Error(err, "Failed to reconcile network policies", "namespace", nsName)
			return ctrl.Result{}, err
		}

		// Create RBAC
		if err := r.reconcileRBAC(ctx, tenant, nsName); err != nil {
			logger.Error(err, "Failed to reconcile RBAC", "namespace", nsName)
			return ctrl.Result{}, err
		}
	}

	// Update status
	tenant.Status.Phase = "Ready"
	if err := r.Status().Update(ctx, tenant); err != nil {
		return ctrl.Result{}, err
	}

	return ctrl.Result{}, nil
}

func (r *TenantReconciler) reconcileNamespace(ctx context.Context, tenant *platformv1alpha1.Tenant, nsSpec platformv1alpha1.NamespaceSpec) error {
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: nsSpec.Name,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, ns, func() error {
		// Set labels
		if ns.Labels == nil {
			ns.Labels = make(map[string]string)
		}
		ns.Labels["tenant.platform.example.com/name"] = tenant.Spec.Name
		ns.Labels["tenant.platform.example.com/tier"] = tenant.Spec.Tier
		ns.Labels["environment"] = nsSpec.Environment

		// Pod security
		securityLevel := r.getPodSecurityLevel(nsSpec.Environment)
		ns.Labels["pod-security.kubernetes.io/enforce"] = securityLevel
		ns.Labels["pod-security.kubernetes.io/warn"] = securityLevel

		// Network isolation label
		ns.Labels["network.platform.example.com/isolation"] = "enabled"

		// Annotations
		if ns.Annotations == nil {
			ns.Annotations = make(map[string]string)
		}
		ns.Annotations["tenant.platform.example.com/owner"] = tenant.Spec.Owner.Email

		return nil
	})

	return err
}

func (r *TenantReconciler) reconcileResourceQuota(ctx context.Context, tenant *platformv1alpha1.Tenant, namespace string) error {
	// Get tier-based quotas
	quotaLimits := r.getQuotaForTier(tenant.Spec.Tier)

	// Override with custom limits if specified
	if tenant.Spec.Quota.CPU != "" {
		quotaLimits["requests.cpu"] = resource.MustParse(tenant.Spec.Quota.CPU)
		quotaLimits["limits.cpu"] = resource.MustParse(tenant.Spec.Quota.CPU)
	}
	if tenant.Spec.Quota.Memory != "" {
		quotaLimits["requests.memory"] = resource.MustParse(tenant.Spec.Quota.Memory)
		quotaLimits["limits.memory"] = resource.MustParse(tenant.Spec.Quota.Memory)
	}

	quota := &corev1.ResourceQuota{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "tenant-quota",
			Namespace: namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, quota, func() error {
		quota.Labels = map[string]string{
			"tenant.platform.example.com/name": tenant.Spec.Name,
		}
		quota.Spec.Hard = quotaLimits
		return nil
	})

	return err
}

func (r *TenantReconciler) reconcileLimitRange(ctx context.Context, tenant *platformv1alpha1.Tenant, namespace string) error {
	lr := &corev1.LimitRange{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "tenant-limits",
			Namespace: namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, lr, func() error {
		lr.Spec = corev1.LimitRangeSpec{
			Limits: []corev1.LimitRangeItem{
				{
					Type: corev1.LimitTypeContainer,
					Default: corev1.ResourceList{
						corev1.ResourceCPU:    resource.MustParse("500m"),
						corev1.ResourceMemory: resource.MustParse("512Mi"),
					},
					DefaultRequest: corev1.ResourceList{
						corev1.ResourceCPU:    resource.MustParse("100m"),
						corev1.ResourceMemory: resource.MustParse("128Mi"),
					},
					Max: corev1.ResourceList{
						corev1.ResourceCPU:    resource.MustParse("4"),
						corev1.ResourceMemory: resource.MustParse("8Gi"),
					},
					Min: corev1.ResourceList{
						corev1.ResourceCPU:    resource.MustParse("50m"),
						corev1.ResourceMemory: resource.MustParse("64Mi"),
					},
				},
			},
		}
		return nil
	})

	return err
}

func (r *TenantReconciler) reconcileNetworkPolicies(ctx context.Context, tenant *platformv1alpha1.Tenant, namespace string) error {
	// Default deny all ingress
	denyAll := &networkingv1.NetworkPolicy{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "default-deny-ingress",
			Namespace: namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, denyAll, func() error {
		denyAll.Spec = networkingv1.NetworkPolicySpec{
			PodSelector: metav1.LabelSelector{},
			PolicyTypes: []networkingv1.PolicyType{
				networkingv1.PolicyTypeIngress,
			},
		}
		return nil
	})
	if err != nil {
		return err
	}

	// Allow intra-namespace traffic
	allowSameNS := &networkingv1.NetworkPolicy{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "allow-same-namespace",
			Namespace: namespace,
		},
	}

	_, err = controllerutil.CreateOrUpdate(ctx, r.Client, allowSameNS, func() error {
		allowSameNS.Spec = networkingv1.NetworkPolicySpec{
			PodSelector: metav1.LabelSelector{},
			PolicyTypes: []networkingv1.PolicyType{
				networkingv1.PolicyTypeIngress,
			},
			Ingress: []networkingv1.NetworkPolicyIngressRule{
				{
					From: []networkingv1.NetworkPolicyPeer{
						{
							PodSelector: &metav1.LabelSelector{},
						},
					},
				},
			},
		}
		return nil
	})
	if err != nil {
		return err
	}

	// Allow from monitoring namespace
	for _, allowedNS := range tenant.Spec.NetworkPolicy.AllowedNamespaces {
		allowFromNS := &networkingv1.NetworkPolicy{
			ObjectMeta: metav1.ObjectMeta{
				Name:      fmt.Sprintf("allow-from-%s", allowedNS),
				Namespace: namespace,
			},
		}

		_, err = controllerutil.CreateOrUpdate(ctx, r.Client, allowFromNS, func() error {
			allowFromNS.Spec = networkingv1.NetworkPolicySpec{
				PodSelector: metav1.LabelSelector{},
				PolicyTypes: []networkingv1.PolicyType{
					networkingv1.PolicyTypeIngress,
				},
				Ingress: []networkingv1.NetworkPolicyIngressRule{
					{
						From: []networkingv1.NetworkPolicyPeer{
							{
								NamespaceSelector: &metav1.LabelSelector{
									MatchLabels: map[string]string{
										"kubernetes.io/metadata.name": allowedNS,
									},
								},
							},
						},
					},
				},
			}
			return nil
		})
		if err != nil {
			return err
		}
	}

	return nil
}

func (r *TenantReconciler) reconcileRBAC(ctx context.Context, tenant *platformv1alpha1.Tenant, namespace string) error {
	// Create tenant admin role
	role := &rbacv1.Role{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "tenant-admin",
			Namespace: namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, role, func() error {
		role.Rules = []rbacv1.PolicyRule{
			{
				APIGroups: []string{"", "apps", "batch", "networking.k8s.io"},
				Resources: []string{"*"},
				Verbs:     []string{"*"},
			},
			{
				APIGroups: []string{"autoscaling"},
				Resources: []string{"horizontalpodautoscalers"},
				Verbs:     []string{"*"},
			},
		}
		return nil
	})
	if err != nil {
		return err
	}

	// Create role binding for owner group
	rb := &rbacv1.RoleBinding{
		ObjectMeta: metav1.ObjectMeta{
			Name:      "tenant-admin-binding",
			Namespace: namespace,
		},
	}

	_, err = controllerutil.CreateOrUpdate(ctx, r.Client, rb, func() error {
		rb.RoleRef = rbacv1.RoleRef{
			APIGroup: "rbac.authorization.k8s.io",
			Kind:     "Role",
			Name:     "tenant-admin",
		}
		rb.Subjects = []rbacv1.Subject{
			{
				Kind:     "Group",
				Name:     tenant.Spec.Owner.Group,
				APIGroup: "rbac.authorization.k8s.io",
			},
		}
		return nil
	})

	return err
}

func (r *TenantReconciler) getQuotaForTier(tier string) corev1.ResourceList {
	tiers := map[string]corev1.ResourceList{
		"starter": {
			corev1.ResourceRequestsCPU:    resource.MustParse("5"),
			corev1.ResourceRequestsMemory: resource.MustParse("10Gi"),
			corev1.ResourceLimitsCPU:      resource.MustParse("10"),
			corev1.ResourceLimitsMemory:   resource.MustParse("20Gi"),
			corev1.ResourcePods:           resource.MustParse("20"),
		},
		"standard": {
			corev1.ResourceRequestsCPU:    resource.MustParse("20"),
			corev1.ResourceRequestsMemory: resource.MustParse("40Gi"),
			corev1.ResourceLimitsCPU:      resource.MustParse("40"),
			corev1.ResourceLimitsMemory:   resource.MustParse("80Gi"),
			corev1.ResourcePods:           resource.MustParse("100"),
		},
		"enterprise": {
			corev1.ResourceRequestsCPU:    resource.MustParse("100"),
			corev1.ResourceRequestsMemory: resource.MustParse("200Gi"),
			corev1.ResourceLimitsCPU:      resource.MustParse("200"),
			corev1.ResourceLimitsMemory:   resource.MustParse("400Gi"),
			corev1.ResourcePods:           resource.MustParse("500"),
		},
	}

	if quota, ok := tiers[tier]; ok {
		return quota
	}
	return tiers["standard"]
}

func (r *TenantReconciler) getPodSecurityLevel(environment string) string {
	switch environment {
	case "prod":
		return "restricted"
	case "staging":
		return "baseline"
	default:
		return "baseline"
	}
}

func (r *TenantReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.Tenant{}).
		Owns(&corev1.Namespace{}).
		Owns(&corev1.ResourceQuota{}).
		Owns(&corev1.LimitRange{}).
		Owns(&networkingv1.NetworkPolicy{}).
		Complete(r)
}
```

---

## Part 3: Network Isolation

### Exercise 4: Comprehensive Network Policies

Create layered network policies for tenant isolation:

```yaml
# tenant-network-policies.yaml
---
# 1. Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: tenant-backend
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# 2. Allow DNS resolution
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: tenant-backend
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
---
# 3. Allow intra-namespace communication
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-namespace
  namespace: tenant-backend
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
  egress:
    - to:
        - podSelector: {}
---
# 4. Allow ingress from ingress controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress-controller
  namespace: tenant-backend
spec:
  podSelector:
    matchLabels:
      network.platform.example.com/allow-ingress: "true"
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: istio-system
---
# 5. Allow Prometheus scraping
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: tenant-backend
spec:
  podSelector:
    matchLabels:
      prometheus.io/scrape: "true"
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: monitoring
      ports:
        - protocol: TCP
          port: 9090
        - protocol: TCP
          port: metrics
---
# 6. Allow same-tenant cross-namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-same-tenant
  namespace: tenant-backend
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              tenant.platform.example.com/name: backend
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              tenant.platform.example.com/name: backend
---
# 7. Allow egress to external services
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-egress
  namespace: tenant-backend
spec:
  podSelector:
    matchLabels:
      network.platform.example.com/external-access: "true"
  policyTypes:
    - Egress
  egress:
    # Allow HTTPS
    - ports:
        - protocol: TCP
          port: 443
    # Allow specific external CIDRs
    - to:
        - ipBlock:
            cidr: 10.0.0.0/8
            except:
              - 10.244.0.0/16  # Pod CIDR
```

### Exercise 5: Cilium Network Policies

Use Cilium for advanced network policies:

```yaml
# cilium-tenant-policies.yaml
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-backend
spec:
  description: "Tenant isolation with Cilium"
  endpointSelector:
    matchLabels: {}
  
  ingress:
    # Allow from same namespace
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: tenant-backend
    
    # Allow from monitoring
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: monitoring
      toPorts:
        - ports:
            - port: "9090"
              protocol: TCP
  
  egress:
    # Allow DNS
    - toEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: kube-system
            k8s-app: kube-dns
      toPorts:
        - ports:
            - port: "53"
              protocol: UDP
    
    # Allow same tenant
    - toEndpoints:
        - matchLabels:
            tenant.platform.example.com/name: backend
    
    # Allow specific FQDNs
    - toFQDNs:
        - matchName: "api.github.com"
        - matchName: "registry.npmjs.org"
        - matchPattern: "*.amazonaws.com"
      toPorts:
        - ports:
            - port: "443"
              protocol: TCP
---
# L7 policy for API access
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: api-l7-policy
  namespace: tenant-backend
spec:
  endpointSelector:
    matchLabels:
      app: api-gateway
  
  ingress:
    - fromEndpoints:
        - matchLabels:
            io.kubernetes.pod.namespace: tenant-backend
      toPorts:
        - ports:
            - port: "8080"
              protocol: TCP
          rules:
            http:
              - method: "GET"
                path: "/api/v1/.*"
              - method: "POST"
                path: "/api/v1/.*"
                headers:
                  - "Content-Type: application/json"
```

---

## Part 4: Virtual Clusters with vCluster

### Exercise 6: Deploy vCluster

Install and configure vCluster for strong isolation:

```bash
# Install vCluster CLI
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"
chmod +x vcluster
sudo mv vcluster /usr/local/bin/

# Verify installation
vcluster --version
```

Create a vCluster for a tenant:

```yaml
# vcluster-tenant.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: vcluster-tenant-acme
  labels:
    tenant.platform.example.com/name: acme
    tenant.platform.example.com/type: vcluster
---
apiVersion: v1
kind: Secret
metadata:
  name: vcluster-acme-values
  namespace: vcluster-tenant-acme
type: Opaque
stringData:
  values.yaml: |
    # vCluster configuration
    vcluster:
      image: rancher/k3s:v1.28.3-k3s1
      
    # Sync configuration
    sync:
      nodes:
        enabled: true
        syncAllNodes: false
        nodeSelector: "tenant=acme"
      persistentVolumes:
        enabled: true
      storageclasses:
        enabled: true
      ingresses:
        enabled: true
      networkpolicies:
        enabled: true
    
    # Resource limits for vCluster
    syncer:
      resources:
        limits:
          cpu: "1"
          memory: "1Gi"
        requests:
          cpu: "100m"
          memory: "256Mi"
      extraArgs:
        - --tls-san=acme.vclusters.platform.example.com
    
    # Isolation settings
    isolation:
      enabled: true
      namespace: null
      podSecurityStandard: baseline
      resourceQuota:
        enabled: true
        quota:
          requests.cpu: "10"
          requests.memory: "20Gi"
          limits.cpu: "20"
          limits.memory: "40Gi"
          pods: "100"
      limitRange:
        enabled: true
        default:
          cpu: "500m"
          memory: "512Mi"
        defaultRequest:
          cpu: "100m"
          memory: "128Mi"
      networkPolicy:
        enabled: true
        outgoingConnections:
          ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 169.254.0.0/16
              - 100.64.0.0/10
    
    # Enable high availability
    replicas: 1
    
    # Storage
    storage:
      persistence: true
      size: 5Gi
    
    # CoreDNS
    coredns:
      enabled: true
      replicas: 1
```

Deploy vCluster:

```bash
# Create vCluster using Helm
helm upgrade --install vcluster-acme vcluster \
  --repo https://charts.loft.sh \
  --namespace vcluster-tenant-acme \
  --values vcluster-values.yaml \
  --create-namespace

# Wait for vCluster to be ready
kubectl wait --for=condition=ready pod -l app=vcluster \
  -n vcluster-tenant-acme --timeout=300s

# Connect to vCluster
vcluster connect vcluster-acme -n vcluster-tenant-acme

# Verify in vCluster context
kubectl get nodes
kubectl get namespaces
```

### Exercise 7: vCluster Management Operator

Create a CRD to manage vClusters:

```yaml
# vcluster-crd.yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: virtualclusters.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: VirtualCluster
    listKind: VirtualClusterList
    plural: virtualclusters
    singular: virtualcluster
    shortNames:
      - vc
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
                - tenant
              properties:
                tenant:
                  type: string
                kubernetesVersion:
                  type: string
                  default: "1.28"
                size:
                  type: string
                  enum: ["small", "medium", "large"]
                  default: "small"
                highAvailability:
                  type: boolean
                  default: false
                sync:
                  type: object
                  properties:
                    nodes:
                      type: boolean
                      default: false
                    persistentVolumes:
                      type: boolean
                      default: true
                    ingresses:
                      type: boolean
                      default: true
                exposeViaIngress:
                  type: boolean
                  default: true
                ingressHost:
                  type: string
            status:
              type: object
              properties:
                phase:
                  type: string
                endpoint:
                  type: string
                kubeconfig:
                  type: string
                version:
                  type: string
      additionalPrinterColumns:
        - name: Tenant
          type: string
          jsonPath: .spec.tenant
        - name: Phase
          type: string
          jsonPath: .status.phase
        - name: Endpoint
          type: string
          jsonPath: .status.endpoint
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
---
# Example VirtualCluster
apiVersion: platform.example.com/v1alpha1
kind: VirtualCluster
metadata:
  name: acme-production
  namespace: platform-vclusters
spec:
  tenant: acme
  kubernetesVersion: "1.28"
  size: medium
  highAvailability: true
  sync:
    nodes: true
    persistentVolumes: true
    ingresses: true
  exposeViaIngress: true
  ingressHost: acme.vclusters.platform.example.com
```

---

## Part 5: Hierarchical Namespaces

### Exercise 8: Install Hierarchical Namespace Controller

Deploy HNC for delegated namespace management:

```bash
# Install HNC
kubectl apply -f https://github.com/kubernetes-sigs/hierarchical-namespaces/releases/download/v1.1.0/default.yaml

# Verify installation
kubectl get pods -n hnc-system

# Install kubectl plugin
kubectl krew install hns
```

### Exercise 9: Configure Hierarchical Namespaces

Set up parent-child namespace relationships:

```yaml
# hnc-tenant-hierarchy.yaml
---
# Parent namespace for tenant
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-acme
  labels:
    tenant.platform.example.com/name: acme
    hnc.x-k8s.io/included-namespace: "true"
---
# Configure HNC for parent
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HierarchyConfiguration
metadata:
  name: hierarchy
  namespace: tenant-acme
spec:
  # No parent (root tenant namespace)
  allowCascadingDeletion: true
---
# Child namespace: development
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-acme-dev
  labels:
    hnc.x-k8s.io/included-namespace: "true"
---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HierarchyConfiguration
metadata:
  name: hierarchy
  namespace: tenant-acme-dev
spec:
  parent: tenant-acme
---
# Child namespace: staging
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-acme-staging
  labels:
    hnc.x-k8s.io/included-namespace: "true"
---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HierarchyConfiguration
metadata:
  name: hierarchy
  namespace: tenant-acme-staging
spec:
  parent: tenant-acme
---
# Child namespace: production
apiVersion: v1
kind: Namespace
metadata:
  name: tenant-acme-prod
  labels:
    hnc.x-k8s.io/included-namespace: "true"
---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HierarchyConfiguration
metadata:
  name: hierarchy
  namespace: tenant-acme-prod
spec:
  parent: tenant-acme
```

Configure resource propagation:

```yaml
# hnc-propagation-config.yaml
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HNCConfiguration
metadata:
  name: config
spec:
  resources:
    # Propagate Secrets
    - resource: secrets
      mode: Propagate
    
    # Propagate ConfigMaps
    - resource: configmaps
      mode: Propagate
    
    # Propagate NetworkPolicies
    - resource: networkpolicies.networking.k8s.io
      mode: Propagate
    
    # Propagate ResourceQuotas (but allow override)
    - resource: resourcequotas
      mode: Propagate
    
    # Propagate LimitRanges
    - resource: limitranges
      mode: Propagate
    
    # Propagate Roles but not RoleBindings (security)
    - resource: roles.rbac.authorization.k8s.io
      mode: Propagate
    
    # Don't propagate RoleBindings
    - resource: rolebindings.rbac.authorization.k8s.io
      mode: Remove
```

Create resources in parent that propagate to children:

```yaml
# parent-resources.yaml
---
# Shared secret in parent (propagates to children)
apiVersion: v1
kind: Secret
metadata:
  name: shared-registry-credentials
  namespace: tenant-acme
  labels:
    hnc.x-k8s.io/propagate: "true"
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: eyJhdXRocyI6e319
---
# Shared ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: tenant-config
  namespace: tenant-acme
  labels:
    hnc.x-k8s.io/propagate: "true"
data:
  TENANT_NAME: acme
  SUPPORT_EMAIL: support@acme.com
  LOG_LEVEL: info
---
# Network policy that propagates
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-default-deny
  namespace: tenant-acme
  labels:
    hnc.x-k8s.io/propagate: "true"
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# RBAC Role that propagates
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: tenant-acme
  labels:
    hnc.x-k8s.io/propagate: "true"
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "jobs", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
```

Verify propagation:

```bash
# View hierarchy
kubectl hns tree tenant-acme

# Check propagated resources
kubectl get secrets -n tenant-acme-dev
kubectl get configmaps -n tenant-acme-staging
kubectl get networkpolicies -n tenant-acme-prod

# View hierarchy details
kubectl hns describe tenant-acme
```

---

## Part 6: RBAC for Multi-Tenancy

### Exercise 10: Comprehensive RBAC Design

Create a multi-level RBAC structure:

```yaml
# rbac-multitenancy.yaml
---
# Cluster-level: Platform Admin
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - nonResourceURLs: ["*"]
    verbs: ["*"]
---
# Cluster-level: Tenant Admin (can manage own tenant resources)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: tenant-admin
rules:
  # View namespaces (limited by RoleBinding)
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list"]
  # Manage tenant CRD
  - apiGroups: ["platform.example.com"]
    resources: ["tenants"]
    verbs: ["get", "list", "watch"]
  # View nodes and cluster info
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list"]
---
# Namespace-level: Developer
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-developer
rules:
  # Core resources
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec", "pods/portforward"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  - apiGroups: [""]
    resources: ["services", "endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  
  # Apps
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  
  # Batch
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  
  # Autoscaling
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  
  # Networking (limited)
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
  
  # Events (read-only)
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["get", "list", "watch"]
---
# Namespace-level: Viewer
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-viewer
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
# Namespace-level: Deployer (CI/CD)
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: namespace-deployer
rules:
  # Limited to deployments and related
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
# Bind tenant admin to tenant namespaces
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tenant-admin
  namespace: tenant-acme
subjects:
  - kind: Group
    name: acme-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: tenant-admin
  apiGroup: rbac.authorization.k8s.io
---
# Bind developers to dev namespace
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developers
  namespace: tenant-acme-dev
subjects:
  - kind: Group
    name: acme-developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-developer
  apiGroup: rbac.authorization.k8s.io
---
# Bind viewers to production (read-only)
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: viewers
  namespace: tenant-acme-prod
subjects:
  - kind: Group
    name: acme-developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: namespace-viewer
  apiGroup: rbac.authorization.k8s.io
---
# Bind deployer for CI/CD service account
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cicd-deployer
  namespace: tenant-acme-prod
subjects:
  - kind: ServiceAccount
    name: github-actions
    namespace: cicd
roleRef:
  kind: ClusterRole
  name: namespace-deployer
  apiGroup: rbac.authorization.k8s.io
```

### Exercise 11: RBAC Aggregation

Use aggregated ClusterRoles for extensibility:

```yaml
# rbac-aggregation.yaml
---
# Base developer role with aggregation
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-base
  labels:
    rbac.platform.example.com/aggregate-to-developer: "true"
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        rbac.platform.example.com/aggregate-to-developer: "true"
rules: []  # Rules are aggregated
---
# Core resources for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-core
  labels:
    rbac.platform.example.com/aggregate-to-developer: "true"
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["*"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
---
# Argo resources for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-argo
  labels:
    rbac.platform.example.com/aggregate-to-developer: "true"
rules:
  - apiGroups: ["argoproj.io"]
    resources: ["applications", "rollouts", "workflows"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
---
# Prometheus resources for developers
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: developer-monitoring
  labels:
    rbac.platform.example.com/aggregate-to-developer: "true"
rules:
  - apiGroups: ["monitoring.coreos.com"]
    resources: ["servicemonitors", "podmonitors", "prometheusrules"]
    verbs: ["get", "list", "watch", "create", "update", "delete"]
```

---

## Validation Checkpoint

Verify your multi-tenancy setup:

```bash
# 1. Check tenant resources
kubectl get tenants
kubectl describe tenant team-backend

# 2. Verify namespaces and labels
kubectl get namespaces -l tenant.platform.example.com/name=backend

# 3. Check network policies
kubectl get networkpolicies -n tenant-backend

# 4. Test network isolation
kubectl run test-pod --image=busybox -n tenant-backend -- sleep 3600
kubectl exec -n tenant-backend test-pod -- wget -qO- http://service.other-tenant.svc

# 5. Verify RBAC
kubectl auth can-i create deployments -n tenant-backend --as=user@example.com
kubectl auth can-i delete namespaces --as=user@example.com

# 6. Check HNC hierarchy
kubectl hns tree tenant-acme
kubectl get secrets -n tenant-acme-dev

# 7. Test vCluster (if deployed)
vcluster connect vcluster-acme -n vcluster-tenant-acme
kubectl get nodes
```

---

## Troubleshooting

### Network Policy Issues

```bash
# Debug network policies
kubectl describe networkpolicy -n tenant-backend

# Test connectivity
kubectl run debug --image=nicolaka/netshoot -n tenant-backend -- sleep 3600
kubectl exec -n tenant-backend debug -- curl -v http://service.monitoring.svc

# Check Cilium (if using)
kubectl exec -n kube-system cilium-xxxxx -- cilium endpoint list
kubectl exec -n kube-system cilium-xxxxx -- cilium policy get
```

### RBAC Issues

```bash
# Check who can do what
kubectl auth can-i --list --as=user@example.com -n tenant-backend

# Debug role bindings
kubectl get rolebindings -n tenant-backend -o wide
kubectl describe rolebinding developer -n tenant-backend

# Check effective permissions
kubectl auth can-i create pods -n tenant-backend --as-group=developers
```

### HNC Issues

```bash
# Check HNC status
kubectl get hnc -n hnc-system

# Debug hierarchy
kubectl hns describe tenant-acme
kubectl get hierarchyconfiguration -n tenant-acme -o yaml

# Check propagation status
kubectl get secrets -n tenant-acme-dev --show-labels
```

---

## Best Practices

### 1. Defense in Depth

- Combine namespace isolation + network policies + RBAC
- Use Pod Security Standards
- Implement admission controllers

### 2. Label Everything

```yaml
metadata:
  labels:
    tenant.platform.example.com/name: acme
    tenant.platform.example.com/tier: standard
    environment: production
```

### 3. Least Privilege

- Start with deny-all network policies
- Use minimal RBAC permissions
- Audit regularly

### 4. Resource Isolation

- Always set ResourceQuotas
- Use LimitRanges for defaults
- Consider node pools per tenant

---

## Summary

In this lab, you learned:

1. **Multi-Tenancy Models**
   - Namespace-based soft tenancy
   - vCluster for hard tenancy
   - Choosing the right model

2. **Tenant Management**
   - Tenant CRD and controller
   - Automated namespace provisioning
   - Tier-based quotas

3. **Network Isolation**
   - Default deny policies
   - Intra-tenant communication
   - Cilium advanced policies

4. **Virtual Clusters**
   - vCluster deployment
   - Sync configuration
   - Management automation

5. **Hierarchical Namespaces**
   - HNC installation
   - Resource propagation
   - Delegated administration

6. **RBAC Strategies**
   - Multi-level permissions
   - Role aggregation
   - Tenant isolation

---

## Module 5 Complete

Congratulations! You have completed Module 5: Platform Engineering. You have learned:

| Lab | Topics |
|-----|--------|
| Lab 1 | Developer Portals with Backstage |
| Lab 2 | Self-Service Infrastructure with Crossplane |
| Lab 3 | Golden Paths and Software Templates |
| Lab 4 | Platform Automation (Operators, Events, APIs) |
| Lab 5 | Cost Management and FinOps |
| Lab 6 | Multi-Tenancy Patterns |

**Next: Complete the [Module 5 Assessment](../assessment/README.md)**
