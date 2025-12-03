# Module 8: Production Operations - Quick Reference

## 🚀 Day 2 Operations

### Node Management

```bash
# Cordon node (prevent scheduling)
kubectl cordon <node-name>

# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Drain with grace period
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data --grace-period=300

# Uncordon node (allow scheduling)
kubectl uncordon <node-name>

# Check node conditions
kubectl describe node <node-name> | grep -A5 Conditions
```

### Pod Disruption Budgets

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: app-pdb
spec:
  minAvailable: 2    # OR maxUnavailable: 1
  selector:
    matchLabels:
      app: myapp
```

### Certificate Management (kubeadm)

```bash
# Check certificate expiration
sudo kubeadm certs check-expiration

# Renew all certificates
sudo kubeadm certs renew all

# Renew specific certificate
sudo kubeadm certs renew apiserver
```

### Etcd Operations

```bash
# Set environment
export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

# Health check
etcdctl endpoint health

# Cluster status
etcdctl endpoint status --write-out=table

# Take backup
etcdctl snapshot save /path/to/backup.db

# Verify backup
etcdctl snapshot status /path/to/backup.db

# Defragment
etcdctl defrag
```

---

## 🔄 Cluster Upgrades

### Pre-Upgrade Checks

```bash
# Check versions
kubectl version
kubeadm version

# Check upgrade plan
sudo kubeadm upgrade plan

# Backup etcd
etcdctl snapshot save /backup/pre-upgrade-$(date +%Y%m%d).db
```

### Control Plane Upgrade

```bash
# First control plane node
sudo apt-mark unhold kubeadm
sudo apt-get install -y kubeadm=1.30.0-1.1
sudo apt-mark hold kubeadm
sudo kubeadm upgrade apply v1.30.0

# Drain, upgrade kubelet, uncordon
kubectl drain <node> --ignore-daemonsets
sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon <node>
```

### Additional Control Plane Nodes

```bash
# Use 'node' instead of 'apply'
sudo kubeadm upgrade node
```

### Worker Node Upgrade

```bash
kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data
# SSH to worker, upgrade packages
sudo kubeadm upgrade node
sudo systemctl daemon-reload && sudo systemctl restart kubelet
kubectl uncordon <worker>
```

---

## 🔧 Troubleshooting

### Quick Diagnostics

```bash
# Cluster health
kubectl cluster-info
kubectl get nodes
kubectl get cs  # Component status

# API server health
kubectl get --raw='/healthz'
kubectl get --raw='/readyz?verbose'

# Pods with issues
kubectl get pods -A | grep -v Running | grep -v Completed

# Events
kubectl get events -A --sort-by='.lastTimestamp'
kubectl get events -A --field-selector type=Warning
```

### Pod Debugging

```bash
# Pod details
kubectl describe pod <pod-name>
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container

# Debug with ephemeral container
kubectl debug -it <pod-name> --image=busybox

# Debug with network tools
kubectl debug -it <pod-name> --image=nicolaka/netshoot

# Exec into container
kubectl exec -it <pod-name> -- /bin/sh
```

### Common Issues

| Symptom | Check | Common Causes |
|---------|-------|---------------|
| **Pending** | `kubectl describe pod` | Resources, node selector, PVC |
| **ImagePullBackOff** | Image name, registry | Wrong image, no pull secret |
| **CrashLoopBackOff** | `kubectl logs --previous` | App error, missing config |
| **OOMKilled** | Memory limits | Insufficient memory limit |
| **Node NotReady** | `kubectl describe node` | kubelet, disk, network |

### Service/Network Debug

```bash
# Check service endpoints
kubectl get endpoints <service>

# DNS test
kubectl run dns-test --image=busybox:1.28 --rm -it -- nslookup kubernetes.default

# Connectivity test
kubectl run curl-test --image=curlimages/curl --rm -it -- curl -v <service>:<port>
```

### Component Logs

```bash
# API server (kubeadm)
kubectl logs -n kube-system kube-apiserver-<node>

# Kubelet
sudo journalctl -u kubelet -n 100

# Container runtime
sudo journalctl -u containerd -n 100
```

---

## 💰 Cost Optimization

### Resource Analysis

```bash
# Current usage vs requests
kubectl top pods -A
kubectl top nodes

# Pods without limits
kubectl get pods -A -o json | jq -r '.items[] | 
  select(.spec.containers[].resources.limits == null) | 
  [.metadata.namespace, .metadata.name] | @tsv'
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

### Vertical Pod Autoscaler

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"  # Recommendation only
```

### Resource Quotas

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: 20Gi
    limits.cpu: "20"
    limits.memory: 40Gi
    pods: "50"
```

### Spot Instance Tolerations

```yaml
spec:
  nodeSelector:
    node-type: spot
  tolerations:
  - key: "spot"
    operator: "Equal"
    value: "true"
    effect: "NoSchedule"
  terminationGracePeriodSeconds: 120
```

---

## 📊 Capacity Planning

### Capacity Metrics

```bash
# Node capacity
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
CPU:.status.allocatable.cpu,\
MEM:.status.allocatable.memory,\
PODS:.status.allocatable.pods

# Per-node allocation
kubectl describe node <node> | grep -A10 "Allocated resources:"

# Pod distribution
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c | sort -rn
```

### Prometheus Capacity Queries

```promql
# CPU request saturation
sum(kube_pod_container_resource_requests{resource="cpu"}) / 
sum(kube_node_status_allocatable{resource="cpu"}) * 100

# Memory request saturation
sum(kube_pod_container_resource_requests{resource="memory"}) / 
sum(kube_node_status_allocatable{resource="memory"}) * 100

# Predict CPU in 7 days
predict_linear(
  sum(kube_pod_container_resource_requests{resource="cpu"})[7d:1h],
  86400 * 7
)
```

### Cluster Autoscaler Settings

| Parameter | Recommended | Purpose |
|-----------|-------------|---------|
| `scale-down-utilization-threshold` | 0.5 | Node utilization before scale down |
| `scale-down-delay-after-add` | 10m | Wait after adding node |
| `scale-down-unneeded-time` | 10m | How long node must be unneeded |
| `max-empty-bulk-delete` | 10 | Max empty nodes to delete at once |

---

## 📈 SLO/SLA Metrics

### Key Formulas

```promql
# Availability SLO
1 - (
  sum(rate(http_requests_total{status=~"5.."}[30d])) /
  sum(rate(http_requests_total[30d]))
)

# Error Budget Remaining
(target_availability - actual_availability) / (1 - target_availability)

# P99 Latency
histogram_quantile(0.99, 
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

### Error Budget

| SLO | Error Budget (monthly) |
|-----|------------------------|
| 99% | 7.2 hours |
| 99.9% | 43.2 minutes |
| 99.95% | 21.6 minutes |
| 99.99% | 4.32 minutes |

---

## 🛠️ Essential Tools

| Tool | Purpose | Install |
|------|---------|---------|
| **k9s** | Terminal UI | `brew install k9s` |
| **stern** | Multi-pod logs | `brew install stern` |
| **kubectx/kubens** | Context switching | `brew install kubectx` |
| **kubectl-debug** | Debug pods | `kubectl krew install debug` |
| **kubecost** | Cost monitoring | Helm install |

---

## 🔍 Health Check Script

```bash
#!/bin/bash
echo "=== Quick Cluster Health Check ==="
echo "Nodes:"
kubectl get nodes
echo ""
echo "Component Status:"
kubectl get --raw='/readyz?verbose' | grep -E '^\[|ok|failed'
echo ""
echo "Problem Pods:"
kubectl get pods -A | grep -v Running | grep -v Completed | head -10
echo ""
echo "Recent Warnings:"
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -5
```

---

## 📚 Key Commands Summary

| Task | Command |
|------|---------|
| Drain node | `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data` |
| Check certs | `sudo kubeadm certs check-expiration` |
| Etcd backup | `etcdctl snapshot save /path/backup.db` |
| Upgrade plan | `sudo kubeadm upgrade plan` |
| Pod logs | `kubectl logs <pod> --previous` |
| Debug pod | `kubectl debug -it <pod> --image=busybox` |
| Resource usage | `kubectl top pods/nodes` |
| Events | `kubectl get events --sort-by='.lastTimestamp'` |
| Capacity | `kubectl describe node | grep -A10 Allocated` |
