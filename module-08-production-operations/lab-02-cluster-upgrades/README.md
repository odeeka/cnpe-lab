# Lab 2: Cluster Upgrades

## 🎯 Objective

Learn to safely plan and execute Kubernetes cluster upgrades, including control plane and worker node upgrades, with proper rollback procedures.

---

## 📚 What You'll Learn

- Upgrade planning and version skew policies
- Pre-upgrade validation and backup procedures
- Control plane upgrade process
- Worker node upgrade strategies
- Rollback procedures for failed upgrades
- Testing upgrades in staging environments

---

## 🔧 Prerequisites

- kubeadm-based Kubernetes cluster
- Admin access to all nodes
- SSH access to control plane and worker nodes
- Current cluster version noted

```bash
# Check current versions
kubectl version
kubeadm version
kubelet --version

# Check node versions
kubectl get nodes -o wide
```

---

## 📖 Concepts

### Version Skew Policy

```
┌─────────────────────────────────────────────────────────────────┐
│                   Kubernetes Version Skew Policy                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  kube-apiserver (most recent)                                    │
│        │                                                          │
│        ├── kube-controller-manager:  within 1 minor version      │
│        ├── kube-scheduler:           within 1 minor version      │
│        ├── cloud-controller-manager: within 1 minor version      │
│        │                                                          │
│        ├── kubelet:  within 2 minor versions (older only)        │
│        │   Example: apiserver 1.30, kubelet can be 1.30-1.28     │
│        │                                                          │
│        ├── kube-proxy: within 2 minor versions (older only)      │
│        │                                                          │
│        └── kubectl:  within 1 minor version (older or newer)     │
│            Example: apiserver 1.30, kubectl can be 1.29-1.31     │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Upgrade Path

```
┌─────────────────────────────────────────────────────────────────┐
│                    Cluster Upgrade Order                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. Primary Control Plane                                        │
│     ├── kubeadm                                                  │
│     ├── kubelet                                                  │
│     └── kubectl                                                  │
│              │                                                    │
│              ▼                                                    │
│  2. Additional Control Plane Nodes (if HA)                       │
│     ├── kubeadm                                                  │
│     ├── kubelet                                                  │
│     └── kubectl                                                  │
│              │                                                    │
│              ▼                                                    │
│  3. Worker Nodes (rolling or batch)                              │
│     ├── kubeadm                                                  │
│     ├── kubelet                                                  │
│     └── kubectl (optional)                                       │
│                                                                   │
│  Note: Only upgrade ONE minor version at a time                  │
│  Example: 1.28 → 1.29 → 1.30 (NOT 1.28 → 1.30)                  │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Upgrade Strategies

| Strategy | Description | Downtime | Risk |
|----------|-------------|----------|------|
| **In-place Rolling** | Upgrade nodes one by one | Minimal | Medium |
| **Blue-Green** | Create new cluster, migrate | Zero | Low |
| **Canary** | Upgrade subset first | Minimal | Low |
| **Big Bang** | All at once | High | High |

---

## 🛠️ Exercises

### Exercise 1: Pre-Upgrade Planning

#### 1.1 Version Discovery

```bash
# Check current cluster version
kubectl version --short

# Check available versions (apt-based)
apt-cache madison kubeadm | head -10

# Check available versions (yum-based)
yum list kubeadm --showduplicates | sort -r | head -10

# Determine target version
TARGET_VERSION="1.30.0-1.1"  # Example
```

#### 1.2 Release Notes Review

```bash
# Check Kubernetes CHANGELOG
# Review: 
# - Deprecations
# - API removals
# - Breaking changes
# - New features

# Key areas to review:
# 1. API deprecations/removals
# 2. Feature gates changes
# 3. Component changes
# 4. Known issues
```

#### 1.3 Compatibility Check

```bash
# Check for deprecated APIs in use
kubectl get --raw /apis | jq .

# Use kubectl deprecations plugin (if available)
kubectl deprecations

# Check for removed APIs
kubectl api-versions | sort

# Scan manifests for deprecated APIs
cat manifest.yaml | kubectl apply --dry-run=server -f -
```

#### 1.4 Pre-Upgrade Validation Script

```bash
#!/bin/bash
# pre-upgrade-check.sh

echo "=== Pre-Upgrade Validation ==="

# Current versions
echo "1. Current Versions:"
kubectl version --short
echo ""

# Cluster health
echo "2. Cluster Health:"
kubectl get nodes
kubectl get cs
echo ""

# Pending operations
echo "3. Pending Operations:"
kubectl get pods -A | grep -v Running | grep -v Completed
echo ""

# Check for deprecated APIs
echo "4. Deprecated API Usage:"
# Check for extensions/v1beta1
kubectl get deployments.extensions -A 2>/dev/null && echo "WARNING: extensions/v1beta1 in use"
# Check for apps/v1beta1
kubectl get deployments.apps.v1beta1 -A 2>/dev/null && echo "WARNING: apps/v1beta1 in use"
echo ""

# PDB status
echo "5. Pod Disruption Budgets:"
kubectl get pdb -A
echo ""

# Etcd backup
echo "6. Taking pre-upgrade etcd backup..."
BACKUP_FILE="/var/backups/etcd/pre-upgrade-$(date +%Y%m%d-%H%M%S).db"
etcdctl snapshot save $BACKUP_FILE 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Backup saved: $BACKUP_FILE"
    etcdctl snapshot status $BACKUP_FILE
else
    echo "WARNING: Could not backup etcd"
fi
echo ""

# Resource usage
echo "7. Current Resource Usage:"
kubectl top nodes 2>/dev/null || echo "Metrics server not available"
echo ""

# Storage
echo "8. Persistent Volumes:"
kubectl get pv -o custom-columns=NAME:.metadata.name,STATUS:.status.phase
echo ""

echo "=== Pre-Upgrade Check Complete ==="
```

### Exercise 2: Control Plane Upgrade (Primary Node)

#### 2.1 Update Package Repository

```bash
# On the primary control plane node

# For Debian/Ubuntu
sudo apt-get update

# Check available kubeadm versions
apt-cache madison kubeadm | head -5
```

#### 2.2 Upgrade kubeadm

```bash
# Unhold kubeadm
sudo apt-mark unhold kubeadm

# Install specific version
sudo apt-get update && sudo apt-get install -y kubeadm=1.30.0-1.1

# Hold kubeadm again
sudo apt-mark hold kubeadm

# Verify version
kubeadm version
```

#### 2.3 Verify Upgrade Plan

```bash
# Check upgrade plan
sudo kubeadm upgrade plan

# Sample output shows:
# - Current cluster version
# - Latest stable version
# - Components to upgrade
# - Available add-on upgrades
```

#### 2.4 Apply Control Plane Upgrade

```bash
# Upgrade control plane (first node only uses 'apply')
sudo kubeadm upgrade apply v1.30.0

# Watch the upgrade progress
# This upgrades:
# - kube-apiserver
# - kube-controller-manager
# - kube-scheduler
# - kube-proxy
# - CoreDNS
# - etcd (if managed by kubeadm)
```

#### 2.5 Drain Control Plane Node

```bash
# Drain the control plane node
kubectl drain <control-plane-node-name> --ignore-daemonsets
```

#### 2.6 Upgrade kubelet and kubectl

```bash
# Unhold packages
sudo apt-mark unhold kubelet kubectl

# Upgrade kubelet and kubectl
sudo apt-get update && sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1

# Hold packages
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet
```

#### 2.7 Uncordon Control Plane Node

```bash
# Uncordon the node
kubectl uncordon <control-plane-node-name>

# Verify node status
kubectl get nodes
```

### Exercise 3: Additional Control Plane Nodes (HA Setup)

#### 3.1 Upgrade Additional Control Plane Nodes

```bash
# For each additional control plane node:

# SSH to the node
ssh control-plane-2

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.30.0-1.1
sudo apt-mark hold kubeadm

# Upgrade node configuration
# Note: Use 'node' instead of 'apply' for additional control plane nodes
sudo kubeadm upgrade node

# Drain the node (run from a different node)
kubectl drain control-plane-2 --ignore-daemonsets

# Upgrade kubelet and kubectl
sudo apt-mark unhold kubelet kubectl
sudo apt-get update && sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Uncordon (run from a different node)
kubectl uncordon control-plane-2
```

### Exercise 4: Worker Node Upgrades

#### 4.1 Rolling Upgrade Strategy

```bash
#!/bin/bash
# upgrade-worker-nodes.sh

WORKERS=$(kubectl get nodes --selector='!node-role.kubernetes.io/control-plane' -o jsonpath='{.items[*].metadata.name}')
TARGET_VERSION="1.30.0-1.1"

for worker in $WORKERS; do
    echo "=== Upgrading $worker ==="
    
    # Cordon and drain
    kubectl cordon $worker
    kubectl drain $worker --ignore-daemonsets --delete-emptydir-data --grace-period=300
    
    # Upgrade via SSH (adjust command for your environment)
    ssh $worker << EOF
        sudo apt-mark unhold kubeadm kubelet kubectl
        sudo apt-get update
        sudo apt-get install -y kubeadm=$TARGET_VERSION kubelet=$TARGET_VERSION kubectl=$TARGET_VERSION
        sudo apt-mark hold kubeadm kubelet kubectl
        sudo kubeadm upgrade node
        sudo systemctl daemon-reload
        sudo systemctl restart kubelet
EOF
    
    # Uncordon
    kubectl uncordon $worker
    
    # Wait for node ready
    kubectl wait --for=condition=Ready node/$worker --timeout=300s
    
    # Verify version
    kubectl get node $worker
    
    echo "=== $worker upgrade complete ==="
    sleep 30  # Pause between nodes
done
```

#### 4.2 Upgrade Single Worker Node

```bash
# Cordon the worker node
kubectl cordon worker-1

# Drain the node
kubectl drain worker-1 --ignore-daemonsets --delete-emptydir-data

# SSH to worker node
ssh worker-1

# Upgrade kubeadm
sudo apt-mark unhold kubeadm
sudo apt-get update && sudo apt-get install -y kubeadm=1.30.0-1.1
sudo apt-mark hold kubeadm

# Upgrade node configuration
sudo kubeadm upgrade node

# Upgrade kubelet
sudo apt-mark unhold kubelet kubectl
sudo apt-get update && sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1
sudo apt-mark hold kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# Exit SSH session
exit

# Uncordon the node
kubectl uncordon worker-1

# Verify
kubectl get nodes
```

### Exercise 5: Post-Upgrade Validation

#### 5.1 Verify Cluster Health

```bash
#!/bin/bash
# post-upgrade-validation.sh

echo "=== Post-Upgrade Validation ==="

# Version check
echo "1. Version Verification:"
kubectl version
echo ""

# Node status
echo "2. Node Status:"
kubectl get nodes -o wide
echo ""

# Control plane pods
echo "3. Control Plane Components:"
kubectl get pods -n kube-system -l tier=control-plane
echo ""

# CoreDNS
echo "4. CoreDNS Status:"
kubectl get pods -n kube-system -l k8s-app=kube-dns
echo ""

# Etcd
echo "5. Etcd Health:"
etcdctl endpoint health 2>/dev/null || echo "Check etcd manually"
echo ""

# Test DNS
echo "6. DNS Test:"
kubectl run dns-test --image=busybox:1.28 --restart=Never --rm -it -- nslookup kubernetes.default
echo ""

# Test API
echo "7. API Test:"
kubectl get --raw='/readyz?verbose'
echo ""

# Check all pods
echo "8. Pod Status (non-running):"
kubectl get pods -A | grep -v Running | grep -v Completed
echo ""

# Check events for errors
echo "9. Recent Warning Events:"
kubectl get events -A --field-selector type=Warning --sort-by='.lastTimestamp' | tail -10
echo ""

# Storage check
echo "10. PVC Status:"
kubectl get pvc -A | grep -v Bound
echo ""

echo "=== Validation Complete ==="
```

#### 5.2 Application Smoke Tests

```bash
# Create test deployment
kubectl create deployment upgrade-test --image=nginx --replicas=3

# Wait for deployment
kubectl wait --for=condition=available deployment/upgrade-test --timeout=120s

# Expose service
kubectl expose deployment upgrade-test --port=80

# Test connectivity
kubectl run test-pod --image=busybox --restart=Never --rm -it -- wget -qO- upgrade-test

# Cleanup
kubectl delete deployment upgrade-test
kubectl delete svc upgrade-test
```

### Exercise 6: Rollback Procedures

#### 6.1 Prepare Rollback Plan

```markdown
# Upgrade Rollback Plan

## Triggers for Rollback
- Control plane components not starting
- Kubelet failing to restart
- Critical application failures
- Network connectivity issues
- etcd cluster instability

## Rollback Steps

### Option 1: Restore from etcd backup (nuclear option)
Use when: Complete cluster failure

### Option 2: Downgrade packages
Use when: Components upgraded but not working

### Option 3: Blue-green failover
Use when: Blue-green upgrade strategy used
```

#### 6.2 Downgrade Procedure

```bash
#!/bin/bash
# rollback-upgrade.sh

PREVIOUS_VERSION="1.29.0-1.1"  # Your previous version

echo "=== Starting Rollback ==="

# Stop kubelet
sudo systemctl stop kubelet

# Downgrade packages
sudo apt-mark unhold kubeadm kubelet kubectl
sudo apt-get install -y kubeadm=$PREVIOUS_VERSION kubelet=$PREVIOUS_VERSION kubectl=$PREVIOUS_VERSION
sudo apt-mark hold kubeadm kubelet kubectl

# Restart kubelet
sudo systemctl daemon-reload
sudo systemctl start kubelet

echo "=== Package Rollback Complete ==="
```

#### 6.3 Etcd Restore (Last Resort)

```bash
# Stop API server and etcd
sudo systemctl stop kubelet

# Move current etcd data
sudo mv /var/lib/etcd /var/lib/etcd.backup.$(date +%Y%m%d)

# Restore from backup
sudo etcdctl snapshot restore /var/backups/etcd/pre-upgrade-TIMESTAMP.db \
  --data-dir=/var/lib/etcd \
  --name=<etcd-node-name> \
  --initial-cluster=<initial-cluster-config> \
  --initial-advertise-peer-urls=https://<ip>:2380

# Fix permissions
sudo chown -R etcd:etcd /var/lib/etcd

# Restart services
sudo systemctl start kubelet

# Wait for control plane to stabilize
sleep 60
kubectl get nodes
```

### Exercise 7: Upgrade Automation

#### 7.1 Ansible Playbook for Upgrade

```yaml
# upgrade-cluster.yaml
---
- name: Upgrade Kubernetes Cluster
  hosts: all
  become: yes
  vars:
    kubernetes_version: "1.30.0-1.1"
  
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
      
    - name: Unhold kubernetes packages
      dpkg_selections:
        name: "{{ item }}"
        selection: install
      loop:
        - kubeadm
        - kubelet
        - kubectl

- name: Upgrade Control Plane
  hosts: control_plane
  become: yes
  serial: 1
  
  tasks:
    - name: Install kubeadm
      apt:
        name: "kubeadm={{ kubernetes_version }}"
        state: present
        
    - name: Upgrade control plane (first node)
      command: kubeadm upgrade apply v1.30.0 -y
      when: inventory_hostname == groups['control_plane'][0]
      
    - name: Upgrade control plane (additional nodes)
      command: kubeadm upgrade node
      when: inventory_hostname != groups['control_plane'][0]
      
    - name: Drain node
      command: kubectl drain {{ inventory_hostname }} --ignore-daemonsets --delete-emptydir-data
      delegate_to: localhost
      
    - name: Install kubelet and kubectl
      apt:
        name:
          - "kubelet={{ kubernetes_version }}"
          - "kubectl={{ kubernetes_version }}"
        state: present
        
    - name: Restart kubelet
      systemd:
        name: kubelet
        state: restarted
        daemon_reload: yes
        
    - name: Uncordon node
      command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: localhost

- name: Upgrade Worker Nodes
  hosts: workers
  become: yes
  serial: 1
  
  tasks:
    - name: Install kubeadm
      apt:
        name: "kubeadm={{ kubernetes_version }}"
        state: present
        
    - name: Drain node
      command: kubectl drain {{ inventory_hostname }} --ignore-daemonsets --delete-emptydir-data
      delegate_to: localhost
      
    - name: Upgrade node config
      command: kubeadm upgrade node
      
    - name: Install kubelet and kubectl
      apt:
        name:
          - "kubelet={{ kubernetes_version }}"
          - "kubectl={{ kubernetes_version }}"
        state: present
        
    - name: Restart kubelet
      systemd:
        name: kubelet
        state: restarted
        daemon_reload: yes
        
    - name: Uncordon node
      command: kubectl uncordon {{ inventory_hostname }}
      delegate_to: localhost
```

#### 7.2 CI/CD Pipeline for Upgrades

```yaml
# .github/workflows/upgrade-staging.yaml
name: Upgrade Staging Cluster

on:
  workflow_dispatch:
    inputs:
      target_version:
        description: 'Target Kubernetes version'
        required: true
        default: '1.30.0'

jobs:
  pre-upgrade:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        
      - name: Setup kubectl
        uses: azure/setup-kubectl@v3
        
      - name: Configure kubeconfig
        run: |
          echo "${{ secrets.KUBECONFIG_STAGING }}" | base64 -d > kubeconfig
          
      - name: Pre-upgrade validation
        run: |
          export KUBECONFIG=kubeconfig
          ./scripts/pre-upgrade-check.sh
          
      - name: Backup etcd
        run: |
          # Trigger etcd backup job
          kubectl create job etcd-backup-pre-upgrade-$(date +%s) --from=cronjob/etcd-backup
          
  upgrade:
    needs: pre-upgrade
    runs-on: ubuntu-latest
    steps:
      - name: Trigger upgrade
        run: |
          # Trigger Ansible playbook via AWX/Tower
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.AWX_TOKEN }}" \
            -H "Content-Type: application/json" \
            -d '{"extra_vars": {"kubernetes_version": "${{ github.event.inputs.target_version }}"}}' \
            https://awx.example.com/api/v2/job_templates/upgrade-k8s/launch/
            
  post-upgrade:
    needs: upgrade
    runs-on: ubuntu-latest
    steps:
      - name: Post-upgrade validation
        run: |
          export KUBECONFIG=kubeconfig
          ./scripts/post-upgrade-validation.sh
          
      - name: Run smoke tests
        run: |
          export KUBECONFIG=kubeconfig
          ./scripts/smoke-tests.sh
```

---

## 🔍 Verification

Complete these checks after the lab:

```bash
# 1. Verify all nodes are upgraded and ready
kubectl get nodes -o wide

# 2. Verify control plane components
kubectl get pods -n kube-system -l tier=control-plane

# 3. Test cluster functionality
kubectl run verify-upgrade --image=nginx --restart=Never
kubectl wait --for=condition=Ready pod/verify-upgrade
kubectl delete pod verify-upgrade

# 4. Check for any issues
kubectl get events -A --field-selector type=Warning | head -20
```

---

## 📝 Key Takeaways

1. **One minor version at a time** - Never skip versions (1.28→1.29→1.30)
2. **Control plane first** - Always upgrade control plane before workers
3. **Backup before upgrade** - Always have etcd backup ready
4. **Test in staging** - Never upgrade production without testing
5. **Have a rollback plan** - Know how to restore if things go wrong
6. **Monitor during upgrade** - Watch for issues during the process
7. **Validate after upgrade** - Run comprehensive tests post-upgrade

---

## 🔗 Next Lab

Continue to [Lab 3: Troubleshooting →](../lab-03-troubleshooting/README.md)

---

## 📚 Additional Resources

- [Kubernetes Upgrade Documentation](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)
- [Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [Release Notes](https://kubernetes.io/releases/)
- [Cluster Upgrade Best Practices](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/ha-topology/)
