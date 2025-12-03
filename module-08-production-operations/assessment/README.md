# Module 8: Production Operations - Assessment

## 📋 Assessment Overview

**Time Limit:** 2.5 hours  
**Total Points:** 100  
**Passing Score:** 70%

### Environment Requirements

- Kubernetes cluster (kubeadm-based preferred for full exercises)
- Admin access to cluster and nodes
- Metrics Server installed
- etcdctl available on control plane

---

## Section 1: Day 2 Operations (20 points)

### Task 1.1: Node Maintenance (5 points)

Perform maintenance on a worker node named `worker-ops-1` (or use any available worker node in your cluster):

1. Create a namespace `ops-assessment`
2. Deploy an nginx application with 4 replicas that has anti-affinity to spread across nodes
3. Create a PodDisruptionBudget allowing at most 1 pod unavailable
4. Safely drain `worker-ops-1` respecting the PDB
5. Verify pods are redistributed and the PDB is honored

**Validation:**
```bash
# Verify PDB
kubectl get pdb -n ops-assessment

# Verify pod distribution
kubectl get pods -n ops-assessment -o wide
```

### Task 1.2: Certificate Check (5 points)

1. Check all Kubernetes certificate expirations
2. Create a script that identifies certificates expiring within 30 days
3. Document the output showing which certificates exist and their expiry dates

**Save your script as:** `cert-check.sh`

### Task 1.3: Etcd Maintenance (5 points)

1. Perform an etcd health check
2. Take an etcd backup and save it to `/var/backups/etcd/assessment-backup.db`
3. Verify the backup integrity
4. Document the database size

**Validation:**
```bash
etcdctl snapshot status /var/backups/etcd/assessment-backup.db --write-out=table
```

### Task 1.4: Create Operational Runbook (5 points)

Create a runbook for handling "Pod stuck in Terminating state" that includes:
1. Symptoms/detection
2. Root cause analysis steps
3. Resolution procedures (including force deletion)
4. Prevention measures

**Save as:** `runbook-pod-terminating.md`

---

## Section 2: Cluster Upgrades (25 points)

### Task 2.1: Pre-Upgrade Validation (8 points)

Create a comprehensive pre-upgrade validation script that checks:
1. Current cluster and component versions
2. Node health status
3. All pods running/completed
4. No deprecated APIs in use (check deployments, services)
5. PVC status (all bound)
6. etcd cluster health
7. Creates an etcd backup

**Save your script as:** `pre-upgrade-check.sh`

**The script should:**
- Exit with code 0 if all checks pass
- Exit with code 1 if any critical check fails
- Print a summary of all checks

### Task 2.2: Upgrade Planning (7 points)

Your cluster is running Kubernetes 1.28.5 and needs to be upgraded to 1.30.2.

Create an upgrade plan document that includes:
1. Required upgrade path (1.28 → 1.29 → 1.30)
2. Pre-upgrade checklist
3. Control plane upgrade steps (for HA cluster with 3 control planes)
4. Worker node upgrade strategy (rolling, 1 at a time)
5. Rollback procedure
6. Post-upgrade validation steps

**Save as:** `upgrade-plan.md`

### Task 2.3: Post-Upgrade Validation (5 points)

Create a post-upgrade validation script that verifies:
1. All nodes are Ready and at the correct version
2. Control plane components are running
3. CoreDNS is functional (test DNS resolution)
4. API server is healthy (/readyz endpoint)
5. A test deployment can be created and exposed

**Save your script as:** `post-upgrade-validate.sh`

### Task 2.4: Rollback Procedure (5 points)

Document and create a script for rolling back a failed kubelet upgrade on a worker node:
1. Script should stop kubelet
2. Downgrade kubelet package to previous version
3. Restart kubelet
4. Verify node rejoins cluster

**Save your script as:** `rollback-kubelet.sh`

---

## Section 3: Troubleshooting (25 points)

### Task 3.1: Debug Broken Application (8 points)

A deployment named `broken-app` in namespace `troubleshoot` is not working.

Apply the following (broken) manifest:

```yaml
# broken-app.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: troubleshoot
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: broken-app
  namespace: troubleshoot
spec:
  replicas: 3
  selector:
    matchLabels:
      app: broken-app
  template:
    metadata:
      labels:
        app: broken-app
    spec:
      containers:
      - name: app
        image: nginx:invalid-tag-12345
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /healthz
            port: 8080  # Wrong port
          initialDelaySeconds: 5
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8080  # Wrong port
---
apiVersion: v1
kind: Service
metadata:
  name: broken-app
  namespace: troubleshoot
spec:
  selector:
    app: wrong-label  # Wrong selector
  ports:
  - port: 80
    targetPort: 80
```

Tasks:
1. Identify all issues with the deployment
2. Fix each issue
3. Verify the application is working
4. Document each issue and fix

**Submit:** `broken-app-fixed.yaml` and `troubleshooting-report.md`

### Task 3.2: Node Troubleshooting (7 points)

A node in your cluster is showing `NotReady` status. Create a troubleshooting script that:

1. Checks node conditions and events
2. Connects to the node (via kubectl debug node or SSH) and checks:
   - kubelet status and logs
   - Container runtime status
   - Disk space
   - Memory usage
   - System load
3. Outputs a diagnostic report

**Save your script as:** `node-troubleshoot.sh`

### Task 3.3: Network Troubleshooting (5 points)

Create a network debugging pod and use it to:

1. Test DNS resolution for `kubernetes.default.svc.cluster.local`
2. Test connectivity to the Kubernetes API server
3. Test connectivity to a service in another namespace
4. Capture the output of these tests

**Submit:** `network-debug-results.txt`

### Task 3.4: Create Troubleshooting Toolkit (5 points)

Create a comprehensive troubleshooting script `k8s-diagnose.sh` that:

1. Takes a pod name and namespace as arguments
2. Gathers:
   - Pod status and description
   - Container logs (current and previous)
   - Related events
   - Node status where pod is scheduled
   - Service endpoints if pod is part of a service
3. Outputs a formatted diagnostic report

---

## Section 4: Cost Optimization (15 points)

### Task 4.1: Resource Right-Sizing (5 points)

1. Create namespace and deploy the following workload:

```bash
kubectl create namespace cost-assessment
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oversized-app
  namespace: cost-assessment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: oversized-app
  template:
    metadata:
      labels:
        app: oversized-app
    spec:
      containers:
      - name: app
        image: nginx
        resources:
          requests:
            cpu: "2"
            memory: 4Gi
          limits:
            cpu: "4"
            memory: 8Gi
```

2. Wait for deployment to be ready
3. Analyze actual resource usage (wait 2-3 minutes for metrics)
4. Create an optimized version with appropriate resource settings
5. Calculate the resource savings (percentage reduction)

**Submit:** `optimized-app.yaml` and `resource-analysis.txt`

### Task 4.2: Implement HPA (5 points)

1. Create a deployment with appropriate resource requests
2. Create an HPA that:
   - Scales based on CPU utilization (target: 70%)
   - Minimum 2 replicas, maximum 8 replicas
   - Has appropriate scale-down behavior (gradual)
3. Document the HPA configuration rationale

**Submit:** `hpa-deployment.yaml`

### Task 4.3: Cost Allocation (5 points)

1. Create the namespace first: `kubectl create namespace team-alpha`
2. Create a ResourceQuota for namespace `team-alpha` with:
   - Max 10 CPU requests
   - Max 20Gi memory requests
   - Max 20 pods
   
2. Create a LimitRange with:
   - Default CPU limit: 500m
   - Default memory limit: 512Mi
   - Default CPU request: 100m
   - Default memory request: 128Mi

3. Create a sample deployment that uses these defaults

**Submit:** `quota-limitrange.yaml`

---

## Section 5: Capacity Planning (15 points)

### Task 5.1: Capacity Analysis (5 points)

Create a capacity analysis script that outputs:

1. Total cluster capacity (CPU, memory, pods)
2. Current allocations (requests) per node
3. Current usage per node
4. Available headroom (percentage)
5. Recommendations based on utilization thresholds

**Save as:** `capacity-report.sh`

### Task 5.2: Capacity Alerts (5 points)

Create Prometheus alerting rules for:

1. Node CPU capacity > 85% allocated
2. Node memory capacity > 85% allocated
3. Cluster approaching pod limit (< 10% pods available)
4. Predictive alert: capacity will be exhausted in 7 days

**Save as:** `capacity-alerts.yaml`

### Task 5.3: Scaling Strategy Document (5 points)

Create a scaling strategy document that covers:

1. When to scale vertically vs horizontally
2. Node pool strategy (different instance types for different workloads)
3. Spot instance usage policy
4. Cluster autoscaler configuration recommendations
5. Capacity planning review schedule

**Save as:** `scaling-strategy.md`

---

## 📝 Submission Checklist

### Files to Submit

**Section 1: Day 2 Operations**
- [ ] Evidence of PDB creation and node drain
- [ ] `cert-check.sh`
- [ ] Evidence of etcd backup
- [ ] `runbook-pod-terminating.md`

**Section 2: Cluster Upgrades**
- [ ] `pre-upgrade-check.sh`
- [ ] `upgrade-plan.md`
- [ ] `post-upgrade-validate.sh`
- [ ] `rollback-kubelet.sh`

**Section 3: Troubleshooting**
- [ ] `broken-app-fixed.yaml`
- [ ] `troubleshooting-report.md`
- [ ] `node-troubleshoot.sh`
- [ ] `network-debug-results.txt`
- [ ] `k8s-diagnose.sh`

**Section 4: Cost Optimization**
- [ ] `optimized-app.yaml`
- [ ] `resource-analysis.txt`
- [ ] `hpa-deployment.yaml`
- [ ] `quota-limitrange.yaml`

**Section 5: Capacity Planning**
- [ ] `capacity-report.sh`
- [ ] `capacity-alerts.yaml`
- [ ] `scaling-strategy.md`

---

## 🎯 Grading Criteria

| Criterion | Points |
|-----------|--------|
| **Correctness** | 40% |
| **Completeness** | 25% |
| **Best Practices** | 20% |
| **Documentation** | 15% |

### Scoring Guide

| Grade | Score | Description |
|-------|-------|-------------|
| **Excellent** | 90-100 | Exceeds expectations, production-ready solutions |
| **Good** | 80-89 | Meets all requirements with minor issues |
| **Satisfactory** | 70-79 | Meets most requirements, some gaps |
| **Needs Improvement** | 60-69 | Significant gaps in understanding |
| **Unsatisfactory** | <60 | Does not meet minimum requirements |

---

## 💡 Tips for Success

1. **Read each task carefully** - Understand what's being asked before starting
2. **Test your solutions** - Verify everything works before submitting
3. **Document your work** - Explain your reasoning and approach
4. **Follow best practices** - Use proper YAML formatting, comments, and structure
5. **Manage your time** - Allocate time based on point values
6. **Handle errors gracefully** - Scripts should handle edge cases

---

## 🧹 Cleanup

After completing the assessment:

```bash
# Delete assessment namespaces
kubectl delete namespace ops-assessment
kubectl delete namespace troubleshoot
kubectl delete namespace cost-assessment
kubectl delete namespace team-alpha

# Remove any test resources
kubectl delete deployment,svc,pdb -l assessment=module-8 -A

# Uncordon any cordoned nodes
kubectl uncordon worker-ops-1 2>/dev/null || true
```

---

**Good luck! 🚀**
