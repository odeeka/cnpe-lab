# Lab 1: Setting Up Your Environment

## Objective

Learn to create and manage a local Kubernetes cluster using kind, explore the cluster architecture, and master basic kubectl commands.

## What You'll Learn

- Create a multi-node kind cluster
- Understand Kubernetes cluster components
- Navigate cluster resources with kubectl
- Explore nodes, namespaces, and system pods
- Use kubectl contexts and configurations

## Prerequisites

- Docker running
- kind installed
- kubectl installed

Verify installations:

```bash
docker --version
kind --version
kubectl version --client
```

## Lab Steps

### Step 1: Create a Multi-Node Cluster

We'll create a cluster with 1 control plane and 2 worker nodes.

1. **Review the cluster configuration** (already exists in your repo):

```bash
cd /home/admin_pet/github/cnpe-lab/base
cat kind-cluster.yaml
```

2. **Create the cluster**:

```bash
kind create cluster --name cnpe-lab --config kind-cluster.yaml
```

Expected output:

```text
Creating cluster "cnpe-lab" ...
 ✓ Ensuring node image (kindest/node:v1.27.3) 🖼
 ✓ Preparing nodes 📦 📦 📦
 ✓ Writing configuration 📜
 ✓ Starting control-plane 🕹️
 ✓ Installing CNI 🔌
 ✓ Installing StorageClass 💾
 ✓ Joining worker nodes 🚜
Set kubectl context to "kind-cnpe-lab"
```

3. **Verify cluster is running**:

```bash
kind get clusters
```

### Step 2: Explore Cluster Architecture

1. **Check cluster information**:

```bash
kubectl cluster-info
```

You should see:

- Kubernetes control plane URL
- CoreDNS URL

2. **List all nodes**:

```bash
kubectl get nodes
kubectl get nodes -o wide
```

Expected: 1 control-plane node + 2 worker nodes

3. **Describe a node** (replace node-name):

```bash
kubectl describe node cnpe-lab-control-plane
```

Observe:

- Node capacity (CPU, memory, pods)
- Allocatable resources
- Conditions (Ready, MemoryPressure, etc.)
- System info (OS, kernel, container runtime)
- Running pods

### Step 3: Explore Namespaces

Namespaces provide logical separation in Kubernetes.

1. **List all namespaces**:
```bash
kubectl get namespaces
# or shorthand:

kubectl get ns
```

You should see:

- `default` - default namespace for resources
- `kube-system` - Kubernetes system components
- `kube-public` - publicly accessible resources
- `kube-node-lease` - node heartbeat information
- `local-path-storage` - kind's storage provisioner

2. **View resources in kube-system**:
```bash
kubectl get pods -n kube-system
```

Key system pods:

- `etcd` - cluster datastore
- `kube-apiserver` - API server
- `kube-controller-manager` - controllers
- `kube-scheduler` - pod scheduler
- `kube-proxy` - network proxy on each node
- `coredns` - DNS server
- `kindnet` - CNI plugin

3. **Get all resources in a namespace**:
```bash
kubectl get all -n kube-system
```bash
### Step 4: Master kubectl Basics

1. **Create a namespace for your labs**:
```bash
kubectl create namespace lab-01
```

2. **Set the default namespace** (so you don't need `-n` flag):
```bash
kubectl config set-context --current --namespace=lab-01
```

3. **Verify current context**:
```bash
kubectl config current-context
kubectl config get-contexts
```

4. **View your kubeconfig**:
```bash
kubectl config view
```bash
This shows:

- Clusters configured
- Users/credentials
- Contexts (cluster + user + namespace)

### Step 5: Explore API Resources

1. **List all available resource types**:
```bash
kubectl api-resources
```bash
Notice the columns:

- NAME: resource name (plural)
- SHORTNAMES: shortcuts (e.g., `po` for pods)
- APIVERSION: API group and version
- NAMESPACED: whether resource is namespaced
- KIND: resource type in manifests

2. **Get API versions**:
```bash
kubectl api-versions
```bash
3. **Explain a resource type**:
```bash
kubectl explain pod
kubectl explain pod.spec
kubectl explain pod.spec.containers
```bash
This is invaluable for understanding resource schemas!

### Step 6: Practice kubectl Commands

1. **Different output formats**:
```bash
# Get nodes in YAML

kubectl get nodes -o yaml

# Get nodes in JSON

kubectl get nodes -o json

# Get specific fields with JSONPath

kubectl get nodes -o jsonpath='{.items[*].metadata.name}'

# Custom columns

kubectl get nodes -o custom-columns=NAME:.metadata.name,STATUS:.status.conditions[-1].type,VERSION:.status.nodeInfo.kubeletVersion
```

2. **Watch resources** (live updates):
```bash
# In a new terminal window:

kubectl get pods -n kube-system --watch
```bash
Press `Ctrl+C` to stop watching.

3. **Use labels and selectors**:
```bash
# Show labels

kubectl get nodes --show-labels

# Filter by label

kubectl get pods -n kube-system -l k8s-app=kube-dns
```

### Step 7: Explore Cluster Events

1. **View cluster events**:
```bash
kubectl get events -n kube-system --sort-by='.lastTimestamp'
```

2. **Watch events in real-time**:
```bash
kubectl get events -n kube-system --watch
```

## Validation

Run these commands to verify your setup:

```bash
# 1. Cluster is running

kind get clusters | grep cnpe-lab

# 2. Three nodes are Ready

kubectl get nodes | grep Ready | wc -l
# Should output: 3

# 3. All system pods are running

kubectl get pods -n kube-system --field-selector=status.phase!=Running
# Should be empty (no output)

# 4. lab-01 namespace exists

kubectl get ns lab-01

# 5. Current context is set correctly

kubectl config current-context | grep kind-cnpe-lab
```bash
## Practice Challenges

Try these exercises to reinforce learning:

1. **Challenge 1**: Find the container runtime version used by worker nodes
   <details>
   <summary>Hint</summary>
   Use `kubectl get nodes -o wide` or `kubectl describe node`
   </details>

2. **Challenge 2**: Count how many pods are running in kube-system namespace
   <details>
   <summary>Hint</summary>
   `kubectl get pods -n kube-system --no-headers | wc -l`
   </details>

3. **Challenge 3**: Find the internal IP address of all nodes
   <details>
   <summary>Hint</summary>
   `kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}'`
   </details>

4. **Challenge 4**: Create three namespaces: dev, staging, prod
   <details>
   <summary>Solution</summary>
   ```bash
   kubectl create ns dev
   kubectl create ns staging
   kubectl create ns prod
   ```
   </details>

## Cleanup

Don't delete the cluster yet - we'll use it for subsequent labs!

If you want to reset:
```bash
# Delete the namespace (if you created test resources)

kubectl delete namespace lab-01

# Recreate it

kubectl create namespace lab-01

# Or delete entire cluster and start fresh

kind delete cluster --name cnpe-lab
```bash
## Troubleshooting

### Cluster won't create

- **Issue**: Docker not running
- **Solution**: Start Docker Desktop or docker daemon

### kubectl commands hang

- **Issue**: API server not reachable
- **Solution**: Check cluster is running with `kind get clusters`

### "connection refused" errors

- **Issue**: Wrong context or cluster not started
- **Solution**: Verify context with `kubectl config current-context`

## Key Takeaways

- ✅ kind provides easy local Kubernetes clusters for development
- ✅ kubectl is the primary tool for interacting with Kubernetes
- ✅ Namespaces provide logical resource isolation
- ✅ System components run as pods in kube-system namespace
- ✅ kubectl explain is your friend for understanding resource schemas
- ✅ Different output formats help with automation and debugging

## Additional Resources

- [kubectl Quick Reference](https://kubernetes.io/docs/reference/kubectl/quick-reference/)
- [kind User Guide](https://kind.sigs.k8s.io/docs/user/quick-start/)
- [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)

## Next Lab

[Lab 2: Working with Pods](../lab-02-pods/) - Learn the fundamental unit of Kubernetes: Pods

---

**Estimated Time**: 45-60 minutes
