# 📁 Capstone Project Solutions

This directory contains reference solutions for each phase of the capstone project.

## ⚠️ Important Notes

1. **Try First** - Attempt each phase yourself before looking at solutions
2. **Learn, Don't Copy** - Use solutions to understand concepts, not just copy-paste
3. **Adapt** - Solutions may need adjustment for your environment
4. **Multiple Approaches** - These are reference solutions; other valid approaches exist

---

## 📂 Directory Structure

```
solutions/
├── README.md                         # This file
├── phase-1-foundation/               # Cluster, namespaces, ArgoCD
│   ├── cluster-config.yaml           # Kind cluster with 4 nodes
│   ├── namespaces.yaml               # Namespace definitions with quotas
│   └── argocd-apps.yaml              # App of Apps pattern
├── phase-2-application/              # Microservices deployment
│   ├── base/                         # Base Kustomize resources
│   │   ├── kustomization.yaml
│   │   ├── configmaps.yaml
│   │   ├── secrets.yaml
│   │   ├── ingress.yaml
│   │   ├── frontend/
│   │   ├── api-gateway/
│   │   ├── catalog-service/
│   │   ├── order-service/
│   │   ├── user-service/
│   │   ├── payment-service/
│   │   ├── postgres/
│   │   └── redis/
│   └── overlays/                     # Environment-specific overlays
│       ├── dev/
│       ├── staging/
│       └── production/
├── phase-3-observability/            # Monitoring and logging
│   ├── README.md
│   ├── prometheus/
│   │   ├── values.yaml               # Helm values
│   │   ├── servicemonitors.yaml      # ServiceMonitor definitions
│   │   └── alerting-rules.yaml       # PrometheusRules
│   ├── grafana/
│   │   ├── datasources.yaml
│   │   └── dashboards/
│   ├── loki/
│   │   └── values.yaml
│   └── tracing/
│       └── jaeger-config.yaml
├── phase-4-security/                 # Security hardening
│   ├── README.md
│   ├── network-policies/
│   │   ├── default-deny.yaml
│   │   ├── frontend-policy.yaml
│   │   ├── backend-policy.yaml
│   │   └── database-policy.yaml
│   ├── pod-security/
│   │   ├── pod-security-standards.yaml
│   │   └── security-contexts.yaml
│   ├── rbac/
│   │   ├── service-accounts.yaml
│   │   ├── roles.yaml
│   │   └── bindings.yaml
│   └── secrets/
│       └── sealed-secrets.yaml
├── phase-5-reliability/              # DR and high availability
│   ├── README.md
│   ├── velero/
│   │   ├── backup-schedule.yaml
│   │   └── restore-procedures.yaml
│   ├── chaos/
│   │   ├── litmus-experiments.yaml
│   │   └── chaos-schedule.yaml
│   └── high-availability/
│       ├── pod-topology.yaml
│       └── priority-classes.yaml
├── phase-6-validation/               # Validation scripts
│   ├── README.md
│   ├── validate-all.sh               # Master validation script
│   ├── phase-1-validation.sh
│   ├── phase-2-validation.sh
│   ├── phase-3-validation.sh
│   ├── phase-4-validation.sh
│   └── phase-5-validation.sh
└── images/                           # Pre-built demo images
    ├── README.md
    └── overlays/
        └── prebuilt/
            ├── kustomization.yaml
            └── frontend-config.yaml
```

---

## 🚀 Quick Start with Solutions

If you want to deploy the complete solution quickly:

```bash
# 1. Create cluster
kind create cluster --config solutions/phase-1-foundation/cluster-config.yaml

# 2. Apply all namespaces
kubectl apply -f solutions/phase-1-foundation/namespaces.yaml

# 3. Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 4. Deploy applications via ArgoCD
kubectl apply -f solutions/phase-1-foundation/argocd-apps.yaml

# 5. Install monitoring
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n observability --create-namespace \
  -f solutions/phase-3-observability/prometheus/values.yaml

# 6. Apply security policies
kubectl apply -f solutions/phase-4-security/network-policies/
kubectl apply -f solutions/phase-4-security/rbac/

# 7. Configure reliability
kubectl apply -f solutions/phase-5-reliability/high-availability/
```

---

## 📋 Validation

Use the validation scripts to check your solution:

```bash
# Make scripts executable
chmod +x solutions/phase-6-validation/*.sh

# Run all validations
./solutions/phase-6-validation/validate-all.sh

# Or run individual phase validations
./solutions/phase-6-validation/phase-1-validation.sh
./solutions/phase-6-validation/phase-2-validation.sh
```

---

## 🖼️ Pre-Built Images

For students who want to focus on Kubernetes concepts rather than building applications,
pre-built demo images are available:

```bash
# Deploy using demo images
kubectl apply -k solutions/images/overlays/prebuilt
```

See `solutions/images/README.md` for more details.
