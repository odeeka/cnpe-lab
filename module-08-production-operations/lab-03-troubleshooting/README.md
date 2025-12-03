# Lab 3: Troubleshooting

## 🎯 Objective

Develop systematic troubleshooting skills for Kubernetes clusters, including debugging methodology, common failure patterns, log analysis, and performance troubleshooting.

---

## 📚 What You'll Learn

- Systematic debugging methodology
- Common failure patterns and solutions
- Log collection and analysis
- Network troubleshooting
- Performance diagnostics
- Using debugging tools effectively

---

## 🔧 Prerequisites

- Running Kubernetes cluster
- kubectl configured with admin access
- Familiarity with Linux troubleshooting
- Access to node SSH (for some exercises)

```bash
# Verify access
kubectl cluster-info
kubectl get nodes

# Install useful tools
# kubectl plugins
kubectl krew install debug
kubectl krew install trace
kubectl krew install node-shell
```

---

## 📖 Concepts

### Troubleshooting Methodology

```
┌─────────────────────────────────────────────────────────────────┐
│                 Systematic Debugging Approach                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  1. OBSERVE                                                       │
│     ├── Gather symptoms                                          │
│     ├── Note error messages                                      │
│     └── Identify scope (pod, node, cluster)                      │
│                                                                   │
│  2. GATHER DATA                                                   │
│     ├── Check events                                             │
│     ├── Collect logs                                             │
│     ├── Check resource status                                    │
│     └── Review metrics                                           │
│                                                                   │
│  3. ANALYZE                                                       │
│     ├── Correlate events with time                               │
│     ├── Identify patterns                                        │
│     └── Form hypothesis                                          │
│                                                                   │
│  4. TEST                                                          │
│     ├── Validate hypothesis                                      │
│     ├── Try potential fixes                                      │
│     └── Verify resolution                                        │
│                                                                   │
│  5. DOCUMENT                                                      │
│     ├── Record root cause                                        │
│     ├── Document solution                                        │
│     └── Update runbooks                                          │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

### Troubleshooting Layers

```
┌─────────────────────────────────────────────────────────────────┐
│                   Kubernetes Troubleshooting Layers              │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────┐            │
│  │                    Application                    │ ◄ App logs │
│  └──────────────────────────────────────────────────┘            │
│  ┌──────────────────────────────────────────────────┐            │
│  │                    Kubernetes                     │ ◄ Events  │
│  │              (Pods, Services, Ingress)           │            │
│  └──────────────────────────────────────────────────┘            │
│  ┌──────────────────────────────────────────────────┐            │
│  │                   Container Runtime               │ ◄ crictl  │
│  │                  (containerd, CRI-O)             │            │
│  └──────────────────────────────────────────────────┘            │
│  ┌──────────────────────────────────────────────────┐            │
│  │                    Operating System               │ ◄ syslog  │
│  │                  (kernel, systemd)               │            │
│  └──────────────────────────────────────────────────┘            │
│  ┌──────────────────────────────────────────────────┐            │
│  │                    Infrastructure                 │ ◄ cloud   │
│  │               (Network, Storage, Compute)        │   logs    │
│  └──────────────────────────────────────────────────┘            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Exercises

### Exercise 1: Basic Diagnostic Commands

#### 1.1 Cluster Overview

```bash
# Quick cluster health check
kubectl cluster-info
kubectl get nodes
kubectl top nodes

# Component status (deprecated but still useful)
kubectl get cs

# API server health
kubectl get --raw='/healthz'
kubectl get --raw='/readyz?verbose'
kubectl get --raw='/livez?verbose'
```

#### 1.2 Resource Status Commands

```bash
# Pods with issues
kubectl get pods -A | grep -v Running | grep -v Completed

# Pods not ready
kubectl get pods -A -o jsonpath='{range .items[?(@.status.phase!="Running")]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Deployments not at desired replicas
kubectl get deployments -A -o custom-columns=\
NAMESPACE:.metadata.namespace,\
NAME:.metadata.name,\
DESIRED:.spec.replicas,\
CURRENT:.status.replicas,\
READY:.status.readyReplicas

# Nodes with conditions
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
STATUS:.status.conditions[-1].type,\
REASON:.status.conditions[-1].reason
```

#### 1.3 Events Analysis

```bash
# All events sorted by time
kubectl get events -A --sort-by='.lastTimestamp'

# Warning events only
kubectl get events -A --field-selector type=Warning

# Events for specific namespace
kubectl get events -n production --sort-by='.lastTimestamp'

# Events for specific resource
kubectl get events --field-selector involvedObject.name=my-pod

# Watch events in real-time
kubectl get events -w -A
```

### Exercise 2: Pod Troubleshooting

#### 2.1 Pod Debugging Workflow

```bash
# Check pod status
kubectl get pod <pod-name> -o wide

# Describe pod for details
kubectl describe pod <pod-name>

# Key sections to check:
# - Status
# - Conditions
# - Events
# - Container states

# Check pod logs
kubectl logs <pod-name>
kubectl logs <pod-name> --previous  # Previous container
kubectl logs <pod-name> -c <container-name>  # Specific container
kubectl logs <pod-name> --all-containers  # All containers
```

#### 2.2 Common Pod States and Solutions

```bash
# Pending - Check why not scheduled
kubectl describe pod <pending-pod> | grep -A10 Events

# Common causes:
# - Insufficient resources
# - Node selector/affinity not matching
# - PVC pending
# - Image pull issues

# ImagePullBackOff
kubectl describe pod <pod> | grep -A5 "Image:"
# Verify: image name, registry access, pull secrets

# CrashLoopBackOff
kubectl logs <pod> --previous
kubectl describe pod <pod> | grep -A20 "State:"
# Check: application errors, missing config, resource limits

# OOMKilled
kubectl describe pod <pod> | grep -A5 "Last State:"
kubectl top pod <pod>
# Solution: Increase memory limits
```

#### 2.3 Debug with Ephemeral Containers

```bash
# Add debug container to running pod
kubectl debug -it <pod-name> --image=busybox --target=<container-name>

# Debug with network tools
kubectl debug -it <pod-name> --image=nicolaka/netshoot

# Copy pod for debugging
kubectl debug <pod-name> -it --copy-to=debug-pod --container=debug-container --image=busybox

# Debug on same node as failing pod
kubectl debug node/<node-name> -it --image=busybox
```

#### 2.4 Exec Into Containers

```bash
# Execute command in container
kubectl exec -it <pod-name> -- /bin/sh

# Execute specific command
kubectl exec <pod-name> -- cat /etc/config/app.conf

# Multiple containers
kubectl exec -it <pod-name> -c <container-name> -- /bin/bash
```

### Exercise 3: Service and Network Troubleshooting

#### 3.1 Service Debugging

```bash
# Check service configuration
kubectl get svc <service-name> -o wide
kubectl describe svc <service-name>

# Check endpoints
kubectl get endpoints <service-name>
kubectl describe endpoints <service-name>

# Test service DNS
kubectl run dns-test --image=busybox:1.28 --rm -it --restart=Never -- \
  nslookup <service-name>.<namespace>.svc.cluster.local

# Test service connectivity
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -v http://<service-name>.<namespace>.svc.cluster.local:<port>
```

#### 3.2 Network Debugging Pod

```yaml
# netshoot-debug.yaml
apiVersion: v1
kind: Pod
metadata:
  name: netshoot
  namespace: default
spec:
  containers:
  - name: netshoot
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
    securityContext:
      capabilities:
        add: ["NET_ADMIN", "NET_RAW"]
```

```bash
kubectl apply -f netshoot-debug.yaml

# DNS tests
kubectl exec -it netshoot -- nslookup kubernetes.default
kubectl exec -it netshoot -- dig kubernetes.default.svc.cluster.local

# Connectivity tests
kubectl exec -it netshoot -- curl -v http://service-name:port
kubectl exec -it netshoot -- nc -zv service-name port

# Network tracing
kubectl exec -it netshoot -- traceroute <ip>
kubectl exec -it netshoot -- tcpdump -i eth0 port 80
```

#### 3.3 Common Network Issues

```bash
# DNS not resolving
# 1. Check CoreDNS pods
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns

# 3. Check CoreDNS config
kubectl get configmap coredns -n kube-system -o yaml

# Service not reachable
# 1. Check service exists
kubectl get svc -A | grep <service-name>

# 2. Check endpoints populated
kubectl get endpoints <service-name>

# 3. Check pod labels match service selector
kubectl get pods --show-labels
kubectl get svc <service-name> -o jsonpath='{.spec.selector}'

# 4. Check NetworkPolicy blocking traffic
kubectl get networkpolicy -A
```

### Exercise 4: Node Troubleshooting

#### 4.1 Node Health Checks

```bash
# Check node status
kubectl get nodes -o wide
kubectl describe node <node-name>

# Key sections:
# - Conditions (Ready, MemoryPressure, DiskPressure, PIDPressure)
# - Capacity vs Allocatable
# - Pods running on node
# - Events

# Check node resources
kubectl top node <node-name>

# Check node capacity
kubectl describe node <node-name> | grep -A10 "Allocatable:"
```

#### 4.2 SSH and System Checks

```bash
# SSH to node (or use kubectl debug)
ssh node-1

# Check kubelet status
sudo systemctl status kubelet
sudo journalctl -u kubelet -n 100

# Check container runtime
sudo systemctl status containerd
sudo crictl ps
sudo crictl pods

# Check system resources
df -h
free -m
top

# Check network
ip addr
ip route
cat /etc/resolv.conf
```

#### 4.3 Common Node Issues

```bash
# Node NotReady - Check kubelet
sudo systemctl status kubelet
sudo journalctl -u kubelet -f

# Disk pressure
df -h /var/lib/kubelet
df -h /var/lib/containerd
# Clean up: images, logs, old files

# Memory pressure
free -m
ps aux --sort=-%mem | head -20
# Check for memory leaks in pods

# PID pressure
cat /proc/sys/kernel/pid_max
ls /proc | grep -E '^[0-9]+$' | wc -l
# Find processes consuming PIDs
```

### Exercise 5: Log Analysis

#### 5.1 Kubernetes Component Logs

```bash
# API server logs (kubeadm)
kubectl logs -n kube-system kube-apiserver-<control-plane-node>

# Or via journald
ssh control-plane-node
sudo journalctl -u kubelet | grep apiserver

# Controller manager logs
kubectl logs -n kube-system kube-controller-manager-<node>

# Scheduler logs
kubectl logs -n kube-system kube-scheduler-<node>

# Etcd logs
kubectl logs -n kube-system etcd-<node>
```

#### 5.2 Multi-Pod Log Streaming with Stern

```bash
# Install stern
brew install stern  # macOS
# or download from https://github.com/stern/stern

# Stream logs from all pods matching pattern
stern -n production "api-.*"

# Stream logs with context
stern -n production --context=5 "api-.*"

# Filter by container
stern -n production -c nginx "web-.*"

# Since time
stern -n production --since=1h "api-.*"

# Output as JSON
stern -n production -o json "api-.*"
```

#### 5.3 Log Aggregation Query (Loki/Grafana)

```bash
# Example LogQL queries for Loki

# All error logs
{namespace="production"} |= "error"

# Specific pod logs
{pod="api-server-abc123"} |~ "ERROR|WARN"

# Rate of errors
sum(rate({namespace="production"} |= "error" [5m])) by (pod)

# Parse JSON logs
{app="myapp"} | json | level="error"
```

### Exercise 6: Performance Troubleshooting

#### 6.1 Resource Analysis

```bash
# Pod resource usage
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Node resource usage
kubectl top nodes

# Detailed pod resource usage
kubectl get pods -o custom-columns=\
NAME:.metadata.name,\
CPU_REQ:.spec.containers[0].resources.requests.cpu,\
CPU_LIM:.spec.containers[0].resources.limits.cpu,\
MEM_REQ:.spec.containers[0].resources.requests.memory,\
MEM_LIM:.spec.containers[0].resources.limits.memory

# Check for pods without limits
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.containers[].resources.limits == null) |
  [.metadata.namespace, .metadata.name] |
  @tsv'
```

#### 6.2 API Server Performance

```bash
# Check API server request latency
kubectl get --raw /metrics | grep apiserver_request_duration

# Check request rate
kubectl get --raw /metrics | grep apiserver_request_total

# Check current connections
kubectl get --raw /metrics | grep apiserver_current_inflight_requests

# Identify slow requests
kubectl get --raw /metrics | grep 'apiserver_request_duration_seconds_bucket.*le="10"'
```

#### 6.3 Etcd Performance

```bash
# Etcd latency metrics
etcdctl endpoint status --write-out=table

# Check slow operations
kubectl logs -n kube-system etcd-<node> | grep -i slow

# Database size
etcdctl endpoint status --write-out=json | jq '.[] | .Status.dbSize'

# Check for high MVCC revision
etcdctl endpoint status --write-out=json | jq '.[] | .Status.header.revision'
```

### Exercise 7: Creating Debugging Scenarios

#### 7.1 Simulate OOMKilled Pod

```yaml
# oom-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: oom-test
spec:
  containers:
  - name: oom-test
    image: polinux/stress
    command: ["stress"]
    args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
    resources:
      limits:
        memory: "100Mi"
```

```bash
kubectl apply -f oom-test.yaml

# Watch the pod
kubectl get pods -w

# Check the reason
kubectl describe pod oom-test | grep -A5 "Last State:"
```

#### 7.2 Simulate Pending Pod

```yaml
# pending-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: pending-test
spec:
  containers:
  - name: nginx
    image: nginx
    resources:
      requests:
        cpu: "100"  # Impossibly high
        memory: "1000Gi"
```

```bash
kubectl apply -f pending-test.yaml

# Check why pending
kubectl describe pod pending-test
# Should show: Insufficient resources
```

#### 7.3 Simulate Image Pull Error

```yaml
# imagepull-test.yaml
apiVersion: v1
kind: Pod
metadata:
  name: imagepull-test
spec:
  containers:
  - name: test
    image: nonexistent-registry.io/fake-image:v1
```

```bash
kubectl apply -f imagepull-test.yaml

# Check status
kubectl describe pod imagepull-test
# Should show: ImagePullBackOff or ErrImagePull
```

### Exercise 8: Troubleshooting Tools

#### 8.1 k9s Terminal UI

```bash
# Install k9s
brew install k9s  # macOS
# or download from https://github.com/derailed/k9s

# Run k9s
k9s

# Key bindings:
# : - Command mode
# / - Filter
# d - Describe
# l - Logs
# s - Shell
# y - YAML
# ctrl-d - Delete
# ? - Help
```

#### 8.2 kubectl-debug Plugin

```bash
# Install kubectl-debug
kubectl krew install debug

# Debug running pod
kubectl debug mypod -it --image=busybox

# Copy pod for debugging
kubectl debug mypod --copy-to=mypod-debug --share-processes

# Debug node
kubectl debug node/worker-1 -it --image=ubuntu
```

#### 8.3 Troubleshooting Script

```bash
#!/bin/bash
# k8s-troubleshoot.sh

POD=$1
NAMESPACE=${2:-default}

if [ -z "$POD" ]; then
    echo "Usage: $0 <pod-name> [namespace]"
    exit 1
fi

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Kubernetes Pod Troubleshooting Report              ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "═══ POD STATUS ═══"
kubectl get pod $POD -n $NAMESPACE -o wide
echo ""

echo "═══ POD DESCRIPTION ═══"
kubectl describe pod $POD -n $NAMESPACE
echo ""

echo "═══ POD LOGS (last 50 lines) ═══"
kubectl logs $POD -n $NAMESPACE --tail=50 2>/dev/null || echo "No logs available"
echo ""

echo "═══ PREVIOUS CONTAINER LOGS ═══"
kubectl logs $POD -n $NAMESPACE --previous --tail=50 2>/dev/null || echo "No previous logs"
echo ""

echo "═══ RELATED EVENTS ═══"
kubectl get events -n $NAMESPACE --field-selector involvedObject.name=$POD --sort-by='.lastTimestamp'
echo ""

echo "═══ NODE STATUS ═══"
NODE=$(kubectl get pod $POD -n $NAMESPACE -o jsonpath='{.spec.nodeName}')
if [ -n "$NODE" ]; then
    kubectl describe node $NODE | head -50
else
    echo "Pod not scheduled to any node"
fi
echo ""

echo "═══ RESOURCE USAGE ═══"
kubectl top pod $POD -n $NAMESPACE 2>/dev/null || echo "Metrics not available"
echo ""

echo "═══ END OF REPORT ═══"
```

---

## 🔍 Verification

Test your troubleshooting skills:

```bash
# Create a problematic deployment
kubectl create deployment trouble-test --image=nginx --replicas=3

# Introduce various issues and fix them:
# 1. Scale with impossible resources
# 2. Use wrong image
# 3. Create service with wrong selector
# 4. Apply restrictive NetworkPolicy

# Practice diagnosing and resolving each issue
```

---

## 📝 Key Takeaways

1. **Follow methodology** - Don't jump to conclusions, gather data first
2. **Layer by layer** - Check each layer from application to infrastructure
3. **Events are gold** - Kubernetes events tell you what's happening
4. **Logs tell the story** - Container and component logs reveal root causes
5. **Right tools matter** - k9s, stern, and debug plugins save time
6. **Document solutions** - Build runbooks for common issues

---

## 🔗 Next Lab

Continue to [Lab 4: Cost Optimization →](../lab-04-cost-optimization/README.md)

---

## 📚 Additional Resources

- [Kubernetes Debugging Guide](https://kubernetes.io/docs/tasks/debug/)
- [Application Troubleshooting](https://kubernetes.io/docs/tasks/debug/debug-application/)
- [Cluster Troubleshooting](https://kubernetes.io/docs/tasks/debug/debug-cluster/)
- [Debug Pods with Ephemeral Containers](https://kubernetes.io/docs/tasks/debug/debug-application/debug-running-pod/)
