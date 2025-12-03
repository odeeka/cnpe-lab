# Module 8: Production Operations

## 🎯 Module Overview

This module covers the essential skills for running Kubernetes in production. You'll learn day-2 operations, cluster upgrades, advanced troubleshooting, cost optimization, and capacity planning strategies.

## ⏱️ Estimated Time: 8-10 hours

---

## 📚 Module Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                Module 8: Production Operations                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Lab 1: Day 2 Operations                                          │
│  ├── Node management and maintenance                             │
│  ├── Cluster maintenance windows                                 │
│  ├── Certificate management                                      │
│  └── Etcd maintenance                                            │
│                                                                   │
│  Lab 2: Cluster Upgrades                                          │
│  ├── Upgrade planning and strategies                             │
│  ├── Control plane upgrades                                      │
│  ├── Worker node upgrades                                        │
│  └── Rollback procedures                                         │
│                                                                   │
│  Lab 3: Troubleshooting                                           │
│  ├── Systematic debugging approach                               │
│  ├── Common failure patterns                                     │
│  ├── Log analysis and correlation                                │
│  └── Performance troubleshooting                                 │
│                                                                   │
│  Lab 4: Cost Optimization                                         │
│  ├── Resource right-sizing                                       │
│  ├── Spot/Preemptible instances                                  │
│  ├── Cluster autoscaling                                         │
│  └── FinOps practices                                            │
│                                                                   │
│  Lab 5: Capacity Planning                                         │
│  ├── Resource forecasting                                        │
│  ├── Scaling strategies                                          │
│  ├── Multi-cluster management                                    │
│  └── SLA/SLO management                                          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔑 Key Concepts

### Production Readiness Checklist

```
┌─────────────────────────────────────────────────────────────────┐
│                  Production Readiness Matrix                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  Infrastructure                    Operations                    │
│  ┌─────────────────────┐          ┌─────────────────────┐       │
│  │ ✓ HA control plane  │          │ ✓ Runbooks          │       │
│  │ ✓ Multi-AZ nodes    │          │ ✓ On-call rotation  │       │
│  │ ✓ Network policies  │          │ ✓ Incident process  │       │
│  │ ✓ Storage classes   │          │ ✓ Change management │       │
│  │ ✓ Ingress/LB        │          │ ✓ Documentation     │       │
│  └─────────────────────┘          └─────────────────────┘       │
│                                                                   │
│  Security                          Observability                 │
│  ┌─────────────────────┐          ┌─────────────────────┐       │
│  │ ✓ RBAC configured   │          │ ✓ Metrics (Prom)    │       │
│  │ ✓ Pod security      │          │ ✓ Logging (Loki)    │       │
│  │ ✓ Network policies  │          │ ✓ Tracing (Tempo)   │       │
│  │ ✓ Secrets mgmt      │          │ ✓ Dashboards        │       │
│  │ ✓ Image scanning    │          │ ✓ Alerting          │       │
│  └─────────────────────┘          └─────────────────────┘       │
│                                                                   │
│  Reliability                       Cost                          │
│  ┌─────────────────────┐          ┌─────────────────────┐       │
│  │ ✓ Backup/DR         │          │ ✓ Resource limits   │       │
│  │ ✓ Chaos testing     │          │ ✓ Right-sizing      │       │
│  │ ✓ SLOs defined      │          │ ✓ Autoscaling       │       │
│  │ ✓ Error budgets     │          │ ✓ Cost monitoring   │       │
│  │ ✓ Graceful degrade  │          │ ✓ Showback/chargeback│      │
│  └─────────────────────┘          └─────────────────────┘       │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Operational Maturity Model

| Level | Characteristics | Focus Areas |
|-------|-----------------|-------------|
| **Level 1: Reactive** | Manual operations, firefighting | Basic monitoring, runbooks |
| **Level 2: Managed** | Documented processes, some automation | Alerting, incident management |
| **Level 3: Defined** | Standardized practices, metrics-driven | SLOs, capacity planning |
| **Level 4: Quantified** | Data-driven decisions, proactive | Cost optimization, FinOps |
| **Level 5: Optimizing** | Continuous improvement, self-healing | AIOps, predictive scaling |

### Day 2 Operations Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    Day 2 Operations Cycle                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│                        ┌──────────┐                              │
│                        │  Monitor │                              │
│                        └────┬─────┘                              │
│                             │                                     │
│              ┌──────────────┼──────────────┐                     │
│              ▼              │              ▼                     │
│        ┌──────────┐         │        ┌──────────┐               │
│        │  Alert   │         │        │  Report  │               │
│        └────┬─────┘         │        └────┬─────┘               │
│             │               │             │                      │
│             ▼               │             ▼                      │
│        ┌──────────┐         │        ┌──────────┐               │
│        │ Respond  │◄────────┼────────│ Analyze  │               │
│        └────┬─────┘         │        └────┬─────┘               │
│             │               │             │                      │
│             ▼               │             ▼                      │
│        ┌──────────┐         │        ┌──────────┐               │
│        │ Resolve  │─────────┼───────►│ Improve  │               │
│        └──────────┘         │        └──────────┘               │
│                             │                                     │
│                        ┌────┴─────┐                              │
│                        │ Automate │                              │
│                        └──────────┘                              │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Tools Covered

| Tool | Purpose | Lab |
|------|---------|-----|
| **kubectl** | Cluster management | All Labs |
| **kubeadm** | Cluster upgrades | Lab 2 |
| **kubectx/kubens** | Context management | Lab 1 |
| **k9s** | Terminal UI | Lab 3 |
| **stern** | Multi-pod logging | Lab 3 |
| **kubectl-debug** | Ephemeral debugging | Lab 3 |
| **Kubecost** | Cost monitoring | Lab 4 |
| **VPA/HPA/KEDA** | Autoscaling | Lab 4, 5 |
| **Karpenter** | Node provisioning | Lab 5 |

---

## 📋 Prerequisites

Before starting this module, ensure you have:

- ✅ Completed Modules 1-7
- ✅ Production-like cluster access (kubeadm or managed)
- ✅ Admin privileges on cluster
- ✅ Monitoring stack deployed (Prometheus/Grafana)
- ✅ Understanding of Kubernetes architecture

### Cluster Requirements

```bash
# Verify cluster access
kubectl cluster-info
kubectl auth can-i '*' '*'

# Check node count (minimum 3 for HA exercises)
kubectl get nodes

# Verify monitoring stack
kubectl get pods -n monitoring
```

---

## 🎯 Learning Objectives

By the end of this module, you will be able to:

### Day 2 Operations
- [ ] Perform node maintenance with minimal disruption
- [ ] Manage cluster certificates
- [ ] Execute etcd maintenance tasks
- [ ] Plan and execute maintenance windows

### Cluster Upgrades
- [ ] Plan upgrade strategies
- [ ] Upgrade control plane components
- [ ] Upgrade worker nodes safely
- [ ] Rollback failed upgrades

### Troubleshooting
- [ ] Apply systematic debugging methodology
- [ ] Diagnose common failure patterns
- [ ] Analyze and correlate logs
- [ ] Troubleshoot performance issues

### Cost Optimization
- [ ] Right-size resources based on usage
- [ ] Implement autoscaling strategies
- [ ] Use spot/preemptible instances effectively
- [ ] Set up cost monitoring and alerting

### Capacity Planning
- [ ] Forecast resource requirements
- [ ] Design scaling strategies
- [ ] Manage SLOs and error budgets
- [ ] Plan multi-cluster architectures

---

## 🔬 Lab Environments

### Recommended Setup

```yaml
# Production-like cluster for exercises
clusters:
  production-sim:
    type: kubeadm
    control_plane_nodes: 3
    worker_nodes: 5
    features:
      - etcd HA
      - multi-AZ
      - monitoring
      - logging

# Or use managed Kubernetes
managed_options:
  - EKS with node groups
  - GKE with node pools
  - AKS with VMSS
```

### Lab Environment Options

| Environment | Complexity | Best For |
|-------------|------------|----------|
| Kind (3 nodes) | Low | Basic exercises |
| kubeadm cluster | Medium | Upgrade labs |
| Managed K8s | Medium | Cost/scaling labs |
| Production mirror | High | Full simulation |

---

## 📊 Module Assessment Preview

The module assessment will test:

| Section | Points | Focus |
|---------|--------|-------|
| Day 2 Operations | 20 | Maintenance, certificates |
| Cluster Upgrades | 25 | Upgrade execution, rollback |
| Troubleshooting | 25 | Debugging methodology |
| Cost Optimization | 15 | Right-sizing, autoscaling |
| Capacity Planning | 15 | Forecasting, SLOs |
| **Total** | **100** | |

---

## 🚀 Getting Started

Begin with [Lab 1: Day 2 Operations →](lab-01-day2-operations/README.md)

### Lab Sequence

```
Lab 1: Day 2 Operations
    ↓
Lab 2: Cluster Upgrades
    ↓
Lab 3: Troubleshooting
    ↓
Lab 4: Cost Optimization
    ↓
Lab 5: Capacity Planning
    ↓
Assessment
```

---

## 📖 Additional Resources

### Documentation
- [Kubernetes Operations Best Practices](https://kubernetes.io/docs/setup/production-environment/)
- [Cluster Administration](https://kubernetes.io/docs/tasks/administer-cluster/)
- [Troubleshooting Guide](https://kubernetes.io/docs/tasks/debug/)

### Books
- "Kubernetes Best Practices" by Brendan Burns et al.
- "Production Kubernetes" by Josh Rosso et al.
- "Cloud Native DevOps with Kubernetes" by John Arundel

### SRE Resources
- [Google SRE Book](https://sre.google/sre-book/table-of-contents/)
- [SRE Workbook](https://sre.google/workbook/table-of-contents/)

---

## ⚠️ Important Notes

### Production Safety

```
┌─────────────────────────────────────────────────────────────────┐
│                    ⚠️  PRODUCTION WARNING  ⚠️                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  When working with production clusters:                          │
│                                                                   │
│  1. ALWAYS have a rollback plan                                  │
│  2. NEVER skip the staging environment                           │
│  3. USE maintenance windows for changes                          │
│  4. COMMUNICATE with stakeholders                                │
│  5. MONITOR during and after changes                             │
│  6. DOCUMENT everything                                          │
│                                                                   │
│  "Move fast, but don't break production"                         │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Change Management

All production changes should follow:
1. **Plan** - Document the change and rollback
2. **Review** - Peer review the plan
3. **Approve** - Get stakeholder approval
4. **Schedule** - Use maintenance windows
5. **Execute** - Follow the runbook
6. **Verify** - Confirm success
7. **Document** - Update documentation

---

**Ready to begin?** [Start Lab 1: Day 2 Operations →](lab-01-day2-operations/README.md)
