# Lab 1: Day 2 Operations

## 🎯 Objective

Master the essential day-2 operations required for maintaining Kubernetes clusters in production, including node management, certificate management, etcd maintenance, and maintenance window procedures.

---

## 📚 What You'll Learn

- Node lifecycle management (cordon, drain, uncordon)
- Cluster certificate management and rotation
- Etcd backup, restore, and maintenance
- Maintenance window planning and execution
- Operational runbook creation

---

## 🔧 Prerequisites

- Running Kubernetes cluster (kubeadm preferred for full exercises)
- Admin access to cluster
- kubectl configured
- etcdctl installed (for etcd exercises)

```bash
# Verify access
kubectl cluster-info
kubectl auth can-i '*' '*'

# Install etcdctl if needed
ETCD_VER=v3.5.9
curl -L https://github.com/etcd-io/etcd/releases/download/${ETCD_VER}/etcd-${ETCD_VER}-linux-amd64.tar.gz -o etcd.tar.gz
tar xzf etcd.tar.gz
sudo mv etcd-${ETCD_VER}-linux-amd64/etcdctl /usr/local/bin/
```

---

## 📖 Concepts

### Node Lifecycle States

```
┌─────────────────────────────────────────────────────────────────┐
│                     Node Lifecycle States                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│     ┌──────────┐     ┌──────────┐     ┌──────────┐              │
│     │  Ready   │────►│ Cordoned │────►│ Drained  │              │
│     │(Healthy) │     │(NoSched) │     │(NoWorkload)│             │
│     └──────────┘     └────┬─────┘     └────┬─────┘              │
│          ▲               │                 │                     │
│          │               │    uncordon     │ Maintenance         │
│          │               ◄─────────────────┘                     │
│          │                                                        │
│          └──────────────── Node Ready ◄─────────────────────────│
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

States:
- Ready: Node accepts new pods, running workloads
- Cordoned: Node rejects new pods, keeps running workloads  
- Drained: Node empty, safe for maintenance
```

### Maintenance Types

| Type | Impact | Planning Required | Examples |
|------|--------|-------------------|----------|
| **Emergency** | High | Minimal | Security patches, critical fixes |
| **Scheduled** | Medium | 1-2 weeks | Upgrades, hardware maintenance |
| **Rolling** | Low | Standard | Application updates |
| **Blue-Green** | Minimal | Extensive | Major upgrades |

---

## 🛠️ Exercises

### Exercise 1: Node Management

#### 1.1 View Node Status

```bash
# List all nodes with details
kubectl get nodes -o wide

# Show node conditions
kubectl describe node <node-name> | grep -A5 Conditions

# Check node resources
kubectl top nodes

# View node labels
kubectl get nodes --show-labels
```

#### 1.2 Node Cordoning

```bash
# Cordon a node (prevent new pods)
kubectl cordon <node-name>

# Verify node is cordoned
kubectl get nodes
# Output shows SchedulingDisabled

# Check node taints
kubectl describe node <node-name> | grep Taints
```

#### 1.3 Draining Nodes

```bash
# Drain node (evict pods)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# For production with PDBs
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=300 \
  --timeout=600s

# Force drain (use with caution)
kubectl drain <node-name> \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --force

# Watch pod migration
kubectl get pods -o wide -w
```

#### 1.4 Returning Node to Service

```bash
# Uncordon the node
kubectl uncordon <node-name>

# Verify node is schedulable
kubectl get nodes

# Force pod rebalancing (optional)
kubectl rollout restart deployment <deployment-name>
```

### Exercise 2: Pod Disruption Budgets

#### 2.1 Create PDB for Critical Applications

```yaml
# pdb-critical-app.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: critical-app-pdb
  namespace: production
spec:
  minAvailable: 2
  # OR use maxUnavailable: 1
  selector:
    matchLabels:
      app: critical-app
```

```bash
kubectl apply -f pdb-critical-app.yaml
```

#### 2.2 PDB with Percentage

```yaml
# pdb-percentage.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-pdb
  namespace: production
spec:
  maxUnavailable: 25%
  selector:
    matchLabels:
      app: web-frontend
```

#### 2.3 Verify PDB Status

```bash
# Check PDB status
kubectl get pdb -A

# Detailed PDB info
kubectl describe pdb critical-app-pdb -n production

# Watch during maintenance
kubectl get pdb -n production -w
```

### Exercise 3: Certificate Management

#### 3.1 Check Certificate Expiration

```bash
# Check API server certificates (kubeadm)
sudo kubeadm certs check-expiration

# Check certificate files directly
sudo openssl x509 -in /etc/kubernetes/pki/apiserver.crt -noout -text | grep -A2 Validity

# Check all certificates
for cert in /etc/kubernetes/pki/*.crt; do
  echo "=== $cert ==="
  sudo openssl x509 -in $cert -noout -enddate
done
```

#### 3.2 Certificate Renewal

```bash
# Renew all certificates (kubeadm)
sudo kubeadm certs renew all

# Renew specific certificate
sudo kubeadm certs renew apiserver

# Restart control plane components after renewal
sudo systemctl restart kubelet

# For static pods, they auto-restart when certs change
```

#### 3.3 Certificate Monitoring Script

```bash
#!/bin/bash
# cert-monitor.sh

WARN_DAYS=30
CRIT_DAYS=7

check_cert() {
  cert_file=$1
  expiry=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
  expiry_epoch=$(date -d "$expiry" +%s)
  now_epoch=$(date +%s)
  days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
  
  if [ $days_left -lt $CRIT_DAYS ]; then
    echo "CRITICAL: $cert_file expires in $days_left days"
  elif [ $days_left -lt $WARN_DAYS ]; then
    echo "WARNING: $cert_file expires in $days_left days"
  else
    echo "OK: $cert_file expires in $days_left days"
  fi
}

for cert in /etc/kubernetes/pki/*.crt; do
  check_cert "$cert"
done
```

### Exercise 4: Etcd Maintenance

#### 4.1 Etcd Health Check

```bash
# Set etcd connection parameters
export ETCDCTL_API=3
export ETCDCTL_CACERT=/etc/kubernetes/pki/etcd/ca.crt
export ETCDCTL_CERT=/etc/kubernetes/pki/etcd/server.crt
export ETCDCTL_KEY=/etc/kubernetes/pki/etcd/server.key
export ETCDCTL_ENDPOINTS=https://127.0.0.1:2379

# Check endpoint health
etcdctl endpoint health

# Check cluster status
etcdctl endpoint status --write-out=table

# Check member list
etcdctl member list --write-out=table
```

#### 4.2 Etcd Backup

```bash
# Take etcd snapshot
etcdctl snapshot save /var/backups/etcd/snapshot-$(date +%Y%m%d-%H%M%S).db

# Verify snapshot
etcdctl snapshot status /var/backups/etcd/snapshot-*.db --write-out=table
```

#### 4.3 Etcd Defragmentation

```bash
# Check database size
etcdctl endpoint status --write-out=table | awk '{print $4}'

# Defragment etcd (run on each member)
etcdctl defrag --endpoints=https://127.0.0.1:2379

# For all endpoints
etcdctl defrag --endpoints=https://etcd1:2379,https://etcd2:2379,https://etcd3:2379
```

#### 4.4 Etcd Compaction

```bash
# Get current revision
rev=$(etcdctl endpoint status --write-out="json" | jq -r '.[0].Status.header.revision')

# Compact old revisions
etcdctl compact $rev

# After compaction, defragment
etcdctl defrag
```

### Exercise 5: Maintenance Window Procedure

#### 5.1 Pre-Maintenance Checklist

```bash
#!/bin/bash
# pre-maintenance-check.sh

echo "=== Pre-Maintenance Checklist ==="

# Check cluster health
echo "1. Cluster Health:"
kubectl get nodes
kubectl get cs

# Check pending PVCs
echo "2. Pending PVCs:"
kubectl get pvc -A | grep -v Bound

# Check failing pods
echo "3. Failing Pods:"
kubectl get pods -A | grep -v Running | grep -v Completed

# Check deployments not at desired replicas
echo "4. Deployment Status:"
kubectl get deployments -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
AVAILABLE:.status.availableReplicas | grep -v "DESIRED.*AVAILABLE"

# Check PDBs
echo "5. Pod Disruption Budgets:"
kubectl get pdb -A

# Etcd health
echo "6. Etcd Health:"
etcdctl endpoint health

# Take pre-maintenance backup
echo "7. Taking backup..."
etcdctl snapshot save /var/backups/etcd/pre-maintenance-$(date +%Y%m%d-%H%M%S).db
```

#### 5.2 Maintenance Window Script

```bash
#!/bin/bash
# maintenance-window.sh

NODE=$1
MAINTENANCE_MSG="Scheduled maintenance in progress"

# Announce maintenance
echo "Starting maintenance on $NODE"

# Step 1: Cordon the node
echo "Cordoning node..."
kubectl cordon $NODE

# Step 2: Wait for confirmation
read -p "Node cordoned. Proceed with drain? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    kubectl uncordon $NODE
    exit 1
fi

# Step 3: Drain the node
echo "Draining node..."
kubectl drain $NODE \
  --ignore-daemonsets \
  --delete-emptydir-data \
  --grace-period=300 \
  --timeout=600s

# Step 4: Verify pods evacuated
echo "Verifying pod evacuation..."
kubectl get pods -A -o wide | grep $NODE

# Step 5: Perform maintenance
echo "Node $NODE is ready for maintenance"
read -p "Press enter when maintenance is complete..."

# Step 6: Return node to service
echo "Returning node to service..."
kubectl uncordon $NODE

# Step 7: Verify node health
echo "Verifying node health..."
kubectl get node $NODE
kubectl describe node $NODE | grep -A5 Conditions

echo "Maintenance complete on $NODE"
```

### Exercise 6: Operational Runbooks

#### 6.1 Node Not Ready Runbook

```markdown
# Runbook: Node Not Ready

## Symptoms
- Node shows NotReady status
- Pods on node show Unknown state
- Kubelet not responding

## Diagnosis Steps

1. Check node status:
   ```bash
   kubectl describe node <node-name>
   ```

2. SSH to node and check kubelet:
   ```bash
   ssh <node-ip>
   sudo systemctl status kubelet
   sudo journalctl -u kubelet -n 100
   ```

3. Check system resources:
   ```bash
   df -h
   free -m
   top
   ```

4. Check container runtime:
   ```bash
   sudo systemctl status containerd
   sudo crictl ps
   ```

## Resolution Steps

### If disk full:
```bash
# Clean up unused images
sudo crictl rmi --prune

# Clean up old logs
sudo journalctl --vacuum-time=2d
```

### If kubelet crashed:
```bash
sudo systemctl restart kubelet
```

### If container runtime issue:
```bash
sudo systemctl restart containerd
```

## Escalation
- If not resolved in 15 minutes, drain node and replace
- Contact infrastructure team if hardware issue suspected
```

#### 6.2 High API Server Latency Runbook

```markdown
# Runbook: High API Server Latency

## Symptoms
- kubectl commands slow
- API server response time > 1s
- Timeouts in applications

## Diagnosis Steps

1. Check API server metrics:
   ```bash
   kubectl get --raw /metrics | grep apiserver_request_duration
   ```

2. Check etcd performance:
   ```bash
   etcdctl endpoint status --write-out=table
   ```

3. Check API server logs:
   ```bash
   kubectl logs -n kube-system kube-apiserver-<node> --tail=100
   ```

4. Check resource usage:
   ```bash
   kubectl top pods -n kube-system
   ```

## Resolution Steps

### If etcd slow:
```bash
# Defragment etcd
etcdctl defrag

# Check for large keys
etcdctl get / --prefix --keys-only | wc -l
```

### If too many requests:
```bash
# Check request rates by client
kubectl get --raw /metrics | grep apiserver_request_total
```

### If resource constrained:
- Scale API server replicas
- Increase resource limits

## Escalation
- Alert on-call if not resolved in 10 minutes
- Consider read-only mode if cluster at risk
```

### Exercise 7: Cluster Health Dashboard

#### 7.1 Health Check Script

```bash
#!/bin/bash
# cluster-health.sh

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║              Kubernetes Cluster Health Report                 ║"
echo "║              $(date)                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"

# Node Health
echo ""
echo "═══ NODE HEALTH ═══"
total_nodes=$(kubectl get nodes --no-headers | wc -l)
ready_nodes=$(kubectl get nodes --no-headers | grep -c " Ready")
echo "Nodes: $ready_nodes/$total_nodes Ready"
kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion

# Control Plane
echo ""
echo "═══ CONTROL PLANE ═══"
kubectl get pods -n kube-system -l tier=control-plane -o custom-columns=COMPONENT:.metadata.labels.component,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount

# Etcd
echo ""
echo "═══ ETCD STATUS ═══"
etcdctl endpoint health 2>/dev/null || echo "Cannot connect to etcd"

# Workload Summary
echo ""
echo "═══ WORKLOAD SUMMARY ═══"
echo "Pods:"
kubectl get pods -A --no-headers | awk '{print $4}' | sort | uniq -c | sort -rn

# Resource Usage
echo ""
echo "═══ RESOURCE USAGE ═══"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"

# Persistent Volumes
echo ""
echo "═══ PERSISTENT VOLUMES ═══"
kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,CLAIM:.spec.claimRef.name 2>/dev/null

# Recent Events
echo ""
echo "═══ RECENT WARNING EVENTS ═══"
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10

# Certificate Status
echo ""
echo "═══ CERTIFICATE STATUS ═══"
if command -v kubeadm &> /dev/null; then
    kubeadm certs check-expiration 2>/dev/null | head -15
fi

echo ""
echo "═══ HEALTH CHECK COMPLETE ═══"
```

#### 7.2 Prometheus Alerts for Operations

```yaml
# ops-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: cluster-operations
  namespace: monitoring
spec:
  groups:
    - name: node-operations
      rules:
        - alert: NodeNotReady
          expr: kube_node_status_condition{condition="Ready",status="true"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Node {{ $labels.node }} is not ready"
            runbook_url: "https://wiki/runbooks/node-not-ready"

        - alert: NodeDiskPressure
          expr: kube_node_status_condition{condition="DiskPressure",status="true"} == 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.node }} has disk pressure"
            
        - alert: NodeMemoryPressure
          expr: kube_node_status_condition{condition="MemoryPressure",status="true"} == 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Node {{ $labels.node }} has memory pressure"

    - name: certificate-operations
      rules:
        - alert: CertificateExpiringSoon
          expr: apiserver_client_certificate_expiration_seconds_count{job="kube-apiserver"} > 0 and on(job) apiserver_client_certificate_expiration_seconds_bucket{job="kube-apiserver", le="604800"} > 0
          labels:
            severity: warning
          annotations:
            summary: "Client certificate expiring within 7 days"
            
    - name: etcd-operations
      rules:
        - alert: EtcdHighLatency
          expr: histogram_quantile(0.99, rate(etcd_disk_wal_fsync_duration_seconds_bucket[5m])) > 0.5
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Etcd fsync taking too long"
            
        - alert: EtcdDatabaseSize
          expr: etcd_mvcc_db_total_size_in_bytes > 6e+9
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Etcd database size exceeds 6GB"
```

---

## 🔍 Verification

After completing all exercises, verify your knowledge:

```bash
# Create a namespace for testing
kubectl create namespace day2-ops-test

# Test 1: Create deployment
kubectl create deployment test-app --image=nginx --replicas=3 -n day2-ops-test

# Test 2: Create PDB
kubectl apply -f - <<EOF
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: test-pdb
  namespace: day2-ops-test
spec:
  minAvailable: 2
  selector:
    matchLabels:
      app: test-app
EOF

# Test 3: Cordon and drain
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl cordon $NODE
kubectl drain $NODE --ignore-daemonsets --delete-emptydir-data --dry-run=client

# Test 4: Verify PDB prevents excessive disruption
kubectl uncordon $NODE

# Cleanup
kubectl delete namespace day2-ops-test
```

---

## 📝 Key Takeaways

1. **Cordon before drain** - Always cordon first to prevent new scheduling
2. **Respect PDBs** - They protect application availability during maintenance
3. **Certificate management is critical** - Expired certs = cluster outage
4. **Regular etcd maintenance** - Prevents performance degradation
5. **Document everything** - Runbooks save time during incidents
6. **Automate health checks** - Proactive monitoring prevents issues

---

## 🔗 Next Lab

Continue to [Lab 2: Cluster Upgrades →](../lab-02-cluster-upgrades/README.md)

---

## 📚 Additional Resources

- [Kubernetes Node Management](https://kubernetes.io/docs/concepts/cluster-administration/cluster-administration-overview/)
- [Pod Disruption Budgets](https://kubernetes.io/docs/tasks/run-application/configure-pdb/)
- [Certificate Management](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-certs/)
- [Etcd Operations Guide](https://etcd.io/docs/v3.5/op-guide/)
