# Lab 3: Network Security

## Overview

This lab covers Kubernetes network security including Network Policies, default deny strategies, advanced Cilium policies, and service mesh mTLS. Network segmentation is a critical layer of defense in depth for protecting workloads.

## Objectives

- Understand Kubernetes network model
- Implement Network Policies for traffic control
- Configure default deny policies
- Use Cilium for advanced network security
- Implement service mesh mTLS

## Prerequisites

- Completed Lab 2: Pod Security
- Running Kubernetes cluster with CNI that supports Network Policies
- kubectl configured with cluster access

---

## Kubernetes Network Model

```
┌─────────────────────────────────────────────────────────────────┐
│                KUBERNETES NETWORK MODEL                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Default Behavior (No Network Policies):                        │
│  ───────────────────────────────────────                        │
│  • All pods can communicate with all other pods                 │
│  • All pods can communicate with all services                   │
│  • No network segmentation by default                           │
│                                                                  │
│  With Network Policies:                                          │
│  ─────────────────────                                          │
│  • Pod must be selected by NetworkPolicy to be affected         │
│  • Selected pods get isolated (ingress, egress, or both)        │
│  • Traffic must match a rule to be allowed                      │
│                                                                  │
│  ┌──────────┐                        ┌──────────┐               │
│  │  Pod A   │──────────────────────▶│  Pod B   │               │
│  │          │     (blocked by       │          │               │
│  │          │   NetworkPolicy if    │          │               │
│  │          │    no matching rule)  │          │               │
│  └──────────┘                        └──────────┘               │
│       ▲                                                          │
│       │                                                          │
│  NetworkPolicy                                                   │
│  (selects Pod A)                                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### CNI Support for Network Policies

| CNI Plugin | NetworkPolicy Support | Advanced Features |
|------------|----------------------|-------------------|
| Calico | Full | Host policies, global policies |
| Cilium | Full | L7 policies, DNS policies |
| Weave Net | Full | Basic policies |
| Flannel | ❌ None | No policy support |
| Canal | Full (via Calico) | Flannel networking + Calico policies |

---

## Part 1: Network Policy Basics

### Network Policy Anatomy

```
┌─────────────────────────────────────────────────────────────────┐
│                  NETWORK POLICY STRUCTURE                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  apiVersion: networking.k8s.io/v1                               │
│  kind: NetworkPolicy                                            │
│  metadata:                                                       │
│    name: example-policy                                         │
│    namespace: default           ◄── Namespace scoped             │
│  spec:                                                           │
│    podSelector:                 ◄── Which pods this applies to   │
│      matchLabels:                                                │
│        app: myapp                                                │
│    policyTypes:                                                  │
│    - Ingress                    ◄── Traffic directions to control│
│    - Egress                                                      │
│    ingress:                     ◄── Allowed incoming traffic     │
│    - from:                                                       │
│      - podSelector: {}          ◄── Who can send traffic         │
│      - namespaceSelector: {}                                     │
│      - ipBlock: {}                                               │
│      ports:                     ◄── Which ports are allowed      │
│      - port: 80                                                  │
│    egress:                      ◄── Allowed outgoing traffic     │
│    - to:                                                         │
│      - podSelector: {}          ◄── Where traffic can go         │
│      ports:                                                      │
│      - port: 443                                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 1.1: Create Test Environment

```bash
# Create namespaces
kubectl create namespace netpol-lab
kubectl create namespace netpol-external

# Label namespaces
kubectl label namespace netpol-lab purpose=lab
kubectl label namespace netpol-external purpose=external

# Deploy test applications
kubectl apply -f - <<EOF
---
# Frontend application
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: netpol-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: frontend
      tier: frontend
  template:
    metadata:
      labels:
        app: frontend
        tier: frontend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: frontend
  namespace: netpol-lab
spec:
  selector:
    app: frontend
  ports:
  - port: 80
---
# Backend API
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: netpol-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: backend
      tier: backend
  template:
    metadata:
      labels:
        app: backend
        tier: backend
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: backend
  namespace: netpol-lab
spec:
  selector:
    app: backend
  ports:
  - port: 80
---
# Database
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database
  namespace: netpol-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: database
      tier: database
  template:
    metadata:
      labels:
        app: database
        tier: database
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_PASSWORD
          value: "testpassword"
---
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: netpol-lab
spec:
  selector:
    app: database
  ports:
  - port: 5432
---
# External test pod
apiVersion: v1
kind: Pod
metadata:
  name: external-client
  namespace: netpol-external
  labels:
    app: external-client
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "infinity"]
EOF

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n netpol-lab --timeout=120s
kubectl wait --for=condition=Ready pod/external-client -n netpol-external --timeout=60s

# Verify connectivity (should all work - no policies yet)
echo "Testing connectivity before policies..."
kubectl exec -n netpol-external external-client -- curl -s --max-time 5 frontend.netpol-lab.svc.cluster.local
kubectl exec -n netpol-external external-client -- curl -s --max-time 5 backend.netpol-lab.svc.cluster.local
```

### Step 1.2: Create Simple Ingress Policy

```bash
# Allow only specific pods to access backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-allow-frontend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

# Test from frontend (should work)
FRONTEND_POD=$(kubectl get pod -n netpol-lab -l app=frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netpol-lab $FRONTEND_POD -- curl -s --max-time 5 backend.netpol-lab.svc.cluster.local
echo "Frontend -> Backend: Success"

# Test from external (should fail - times out)
kubectl exec -n netpol-external external-client -- curl -s --max-time 5 backend.netpol-lab.svc.cluster.local 2>&1 || echo "External -> Backend: Blocked (as expected)"
```

### Step 1.3: Create Egress Policy

```bash
# Restrict backend to only access database
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  # Allow DNS
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
  # Allow database
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
EOF

# Test backend -> database (should work)
BACKEND_POD=$(kubectl get pod -n netpol-lab -l app=backend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -n netpol-lab $BACKEND_POD -- nc -zv database 5432 2>&1 | head -1

# Test backend -> frontend (should fail)
kubectl exec -n netpol-lab $BACKEND_POD -- curl -s --max-time 3 frontend.netpol-lab.svc.cluster.local 2>&1 || echo "Backend -> Frontend: Blocked (as expected)"
```

---

## Part 2: Default Deny Policies

### Default Deny Strategy

```
┌─────────────────────────────────────────────────────────────────┐
│                  DEFAULT DENY STRATEGY                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Step 1: Apply Default Deny                                     │
│  ─────────────────────────                                      │
│  Block all traffic by default                                   │
│                                                                  │
│  Step 2: Allow Required Traffic                                 │
│  ─────────────────────────────                                  │
│  Create specific allow rules                                    │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  [Default Deny All]                                       │   │
│  │       │                                                   │   │
│  │       ├──▶ [Allow DNS]          (essential)              │   │
│  │       │                                                   │   │
│  │       ├──▶ [Allow Frontend Ingress]                      │   │
│  │       │                                                   │   │
│  │       ├──▶ [Allow Frontend → Backend]                    │   │
│  │       │                                                   │   │
│  │       └──▶ [Allow Backend → Database]                    │   │
│  │                                                           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Benefits:                                                       │
│  • Explicit allow-list approach                                 │
│  • Reduces attack surface                                       │
│  • Clear security boundaries                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2.1: Default Deny All Ingress

```bash
# Create default deny all ingress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: netpol-lab
spec:
  podSelector: {}  # Selects all pods in namespace
  policyTypes:
  - Ingress
EOF

# Test - all ingress should be blocked
kubectl exec -n netpol-external external-client -- curl -s --max-time 3 frontend.netpol-lab.svc.cluster.local 2>&1 || echo "All ingress blocked"
```

### Step 2.2: Default Deny All Egress

```bash
# Create default deny all egress
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: netpol-lab
spec:
  podSelector: {}  # Selects all pods in namespace
  policyTypes:
  - Egress
EOF

# Test - all egress should be blocked (including DNS)
kubectl exec -n netpol-lab $FRONTEND_POD -- curl -s --max-time 3 google.com 2>&1 || echo "All egress blocked"
```

### Step 2.3: Allow Essential Traffic

```bash
# Allow DNS for all pods
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: netpol-lab
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - protocol: UDP
      port: 53
    - protocol: TCP
      port: 53
EOF

# Allow ingress to frontend from anywhere
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-ingress
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - protocol: TCP
      port: 80
EOF

# Allow frontend to backend
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: frontend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-from-frontend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - protocol: TCP
      port: 80
EOF

# Allow backend to database
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-backend-to-database
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-database-from-backend
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
EOF
```

### Step 2.4: Verify Traffic Flow

```bash
# Test the complete flow
echo "=== Testing Network Policies ==="

# External -> Frontend (should work)
echo -n "External -> Frontend: "
kubectl exec -n netpol-external external-client -- curl -s --max-time 5 -o /dev/null -w "%{http_code}" frontend.netpol-lab.svc.cluster.local || echo "BLOCKED"

# Frontend -> Backend (should work)
echo -n "Frontend -> Backend: "
kubectl exec -n netpol-lab $FRONTEND_POD -- curl -s --max-time 5 -o /dev/null -w "%{http_code}" backend.netpol-lab.svc.cluster.local || echo "BLOCKED"

# Backend -> Database (should work)
echo -n "Backend -> Database: "
kubectl exec -n netpol-lab $BACKEND_POD -- nc -zv database 5432 2>&1 | grep -q "open" && echo "OPEN" || echo "BLOCKED"

# Frontend -> Database (should be blocked)
echo -n "Frontend -> Database: "
kubectl exec -n netpol-lab $FRONTEND_POD -- nc -zv -w 3 database 5432 2>&1 | grep -q "open" && echo "OPEN" || echo "BLOCKED (expected)"

# External -> Backend (should be blocked)
echo -n "External -> Backend: "
kubectl exec -n netpol-external external-client -- curl -s --max-time 3 -o /dev/null -w "%{http_code}" backend.netpol-lab.svc.cluster.local 2>&1 || echo "BLOCKED (expected)"
```

---

## Part 3: Cross-Namespace Policies

### Step 3.1: Allow Traffic from Specific Namespace

```bash
# Create monitoring namespace
kubectl create namespace monitoring
kubectl label namespace monitoring purpose=monitoring

# Deploy monitoring pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  containers:
  - name: prometheus
    image: curlimages/curl:latest
    command: ["sleep", "infinity"]
EOF

kubectl wait --for=condition=Ready pod/prometheus -n monitoring --timeout=60s

# Allow monitoring namespace to scrape all pods
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: netpol-lab
spec:
  podSelector: {}  # All pods
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    ports:
    - protocol: TCP
      port: 80
    - protocol: TCP
      port: 9090
EOF

# Test from monitoring namespace
kubectl exec -n monitoring prometheus -- curl -s --max-time 5 -o /dev/null -w "%{http_code}" frontend.netpol-lab.svc.cluster.local
echo " - Monitoring -> Frontend: Success"
```

### Step 3.2: Namespace + Pod Selector (AND Logic)

```bash
# Allow only specific pods from specific namespace
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-specific-monitoring
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
      podSelector:
        matchLabels:
          app: prometheus
    ports:
    - protocol: TCP
      port: 5432
EOF
```

### Step 3.3: Namespace OR Pod Selector (OR Logic)

```bash
# Allow from namespace OR specific pods (note the separate array items)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-admin-or-monitoring
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: database
  policyTypes:
  - Ingress
  ingress:
  - from:
    # OR logic - separate array items
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    - podSelector:
        matchLabels:
          role: admin
    ports:
    - protocol: TCP
      port: 5432
EOF
```

---

## Part 4: IP Block Policies

### Step 4.1: Allow External IP Ranges

```bash
# Allow egress to specific external IPs
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-external-api
  namespace: netpol-lab
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  # Allow specific external API
  - to:
    - ipBlock:
        cidr: 10.0.0.0/8
        except:
        - 10.0.1.0/24  # Exclude sensitive subnet
    ports:
    - protocol: TCP
      port: 443
EOF
```

### Step 4.2: Block Egress to Metadata Service

```bash
# Block access to cloud metadata service (security best practice)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata-service
  namespace: netpol-lab
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  # Allow all except metadata service
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32  # AWS/GCP metadata
        - 100.100.100.200/32  # Azure metadata
EOF
```

---

## Part 5: Cilium Network Policies (Advanced)

### Cilium Policy Types

```
┌─────────────────────────────────────────────────────────────────┐
│                  CILIUM NETWORK POLICIES                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  CiliumNetworkPolicy                                            │
│  ───────────────────                                            │
│  Namespace-scoped, L3/L4/L7 policies                            │
│                                                                  │
│  CiliumClusterwideNetworkPolicy                                 │
│  ───────────────────────────────                                │
│  Cluster-scoped policies                                        │
│                                                                  │
│  Features:                                                       │
│  ─────────                                                       │
│  • L7 HTTP policies (methods, paths, headers)                   │
│  • DNS-based policies (domain names)                            │
│  • Entity-based policies (host, world, cluster)                 │
│  • Service-based policies                                       │
│  • Identity-aware policies                                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 5.1: Install Cilium (if not present)

```bash
# Check if Cilium is installed
kubectl get pods -n kube-system -l k8s-app=cilium

# If not installed, install via Helm
# helm repo add cilium https://helm.cilium.io/
# helm install cilium cilium/cilium --namespace kube-system
```

### Step 5.2: L7 HTTP Policy

```bash
# Create namespace for Cilium demo
kubectl create namespace cilium-lab

# Deploy test app
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-server
  namespace: cilium-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: api-server
  template:
    metadata:
      labels:
        app: api-server
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: api-server
  namespace: cilium-lab
spec:
  selector:
    app: api-server
  ports:
  - port: 80
---
apiVersion: v1
kind: Pod
metadata:
  name: client
  namespace: cilium-lab
  labels:
    app: client
spec:
  containers:
  - name: curl
    image: curlimages/curl:latest
    command: ["sleep", "infinity"]
EOF

kubectl wait --for=condition=Ready pods --all -n cilium-lab --timeout=120s

# L7 HTTP Policy (if Cilium is installed)
cat <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: l7-rule
  namespace: cilium-lab
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
  - fromEndpoints:
    - matchLabels:
        app: client
    toPorts:
    - ports:
      - port: "80"
        protocol: TCP
      rules:
        http:
        - method: "GET"
          path: "/api/v1/.*"
        - method: "POST"
          path: "/api/v1/data"
          headers:
          - 'Content-Type: application/json'
EOF
```

### Step 5.3: DNS-Based Policy

```bash
# Allow egress only to specific domains
cat <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: dns-policy
  namespace: cilium-lab
spec:
  endpointSelector:
    matchLabels:
      app: client
  egress:
  - toEndpoints:
    - matchLabels:
        k8s:io.kubernetes.pod.namespace: kube-system
        k8s-app: kube-dns
    toPorts:
    - ports:
      - port: "53"
        protocol: UDP
      rules:
        dns:
        - matchPattern: "*.kubernetes.io"
        - matchName: "api.github.com"
  - toFQDNs:
    - matchName: "api.github.com"
    - matchPattern: "*.kubernetes.io"
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
EOF
```

### Step 5.4: Entity-Based Policy

```bash
# Cilium entities: host, remote-node, world, cluster, init, health
cat <<EOF
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: entity-policy
  namespace: cilium-lab
spec:
  endpointSelector:
    matchLabels:
      app: api-server
  ingress:
  - fromEntities:
    - cluster  # Allow from within cluster
  egress:
  - toEntities:
    - world  # Allow to internet
    toPorts:
    - ports:
      - port: "443"
        protocol: TCP
EOF
```

---

## Part 6: Service Mesh mTLS

### mTLS Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SERVICE MESH mTLS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Without mTLS:                                                   │
│  ─────────────                                                   │
│  ┌─────────┐     HTTP (plaintext)     ┌─────────┐              │
│  │ Service │────────────────────────▶│ Service │              │
│  │    A    │                          │    B    │              │
│  └─────────┘                          └─────────┘              │
│                                                                  │
│  With mTLS:                                                      │
│  ──────────                                                      │
│  ┌─────────┐                          ┌─────────┐              │
│  │ Service │                          │ Service │              │
│  │    A    │                          │    B    │              │
│  └────┬────┘                          └────┬────┘              │
│       │                                    │                    │
│  ┌────▼────┐     TLS (encrypted)     ┌────▼────┐              │
│  │  Proxy  │────────────────────────▶│  Proxy  │              │
│  │ (Envoy) │◀────────────────────────│ (Envoy) │              │
│  └─────────┘   Mutual Authentication  └─────────┘              │
│                                                                  │
│  Benefits:                                                       │
│  • Encrypted traffic                                            │
│  • Service identity verification                                │
│  • Zero-trust networking                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 6.1: Install Istio (if not present)

```bash
# Download Istio
# curl -L https://istio.io/downloadIstio | sh -
# cd istio-*
# export PATH=$PWD/bin:$PATH

# Install Istio with default profile
# istioctl install --set profile=demo -y

# Check Istio installation
kubectl get pods -n istio-system
```

### Step 6.2: Enable mTLS with PeerAuthentication

```bash
# Create namespace with Istio injection
kubectl create namespace mtls-lab
kubectl label namespace mtls-lab istio-injection=enabled

# Strict mTLS for namespace
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: mtls-lab
spec:
  mtls:
    mode: STRICT
EOF

# Deploy test services
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: httpbin
  namespace: mtls-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: httpbin
  template:
    metadata:
      labels:
        app: httpbin
    spec:
      containers:
      - name: httpbin
        image: kennethreitz/httpbin
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: httpbin
  namespace: mtls-lab
spec:
  selector:
    app: httpbin
  ports:
  - port: 80
EOF
```

### Step 6.3: Authorization Policy

```bash
# Istio Authorization Policy
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: httpbin-policy
  namespace: mtls-lab
spec:
  selector:
    matchLabels:
      app: httpbin
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/mtls-lab/sa/client"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/get", "/headers"]
  - from:
    - source:
        namespaces: ["monitoring"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/metrics"]
EOF
```

### Step 6.4: Verify mTLS

```bash
# Check mTLS status
# istioctl x describe pod httpbin-xxx -n mtls-lab

# Check if traffic is encrypted
# istioctl proxy-config cluster httpbin-xxx -n mtls-lab

# View certificates
# kubectl exec -n mtls-lab httpbin-xxx -c istio-proxy -- \
#   openssl s_client -showcerts -connect httpbin:80
```

---

## Part 7: Network Policy Debugging

### Step 7.1: Debug Connectivity Issues

```bash
# Check network policies affecting a pod
kubectl get networkpolicy -n netpol-lab

# Describe specific policy
kubectl describe networkpolicy backend-allow-frontend -n netpol-lab

# Check if pod is selected by any policy
kubectl get pods -n netpol-lab -o wide
kubectl get networkpolicy -n netpol-lab -o jsonpath='{range .items[*]}{.metadata.name}: {.spec.podSelector}{"\n"}{end}'
```

### Step 7.2: Network Policy Visualization

```bash
# List all policies in table format
echo "=== Network Policies in netpol-lab ==="
kubectl get networkpolicy -n netpol-lab -o custom-columns=\
'NAME:.metadata.name,'\
'POD-SELECTOR:.spec.podSelector.matchLabels,'\
'POLICY-TYPES:.spec.policyTypes'

# Detailed policy analysis
for policy in $(kubectl get networkpolicy -n netpol-lab -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $policy ==="
  kubectl get networkpolicy $policy -n netpol-lab -o yaml | grep -A20 "spec:"
  echo ""
done
```

### Step 7.3: Test Connectivity Script

```bash
cat > /tmp/test-connectivity.sh <<'EOF'
#!/bin/bash

NAMESPACE=${1:-netpol-lab}
TARGET_SVC=${2:-backend}
TARGET_PORT=${3:-80}

echo "=== Connectivity Test to $TARGET_SVC:$TARGET_PORT ==="

for pod in $(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}'); do
  result=$(kubectl exec -n $NAMESPACE $pod -- nc -zv -w 3 $TARGET_SVC $TARGET_PORT 2>&1)
  if echo "$result" | grep -q "open\|succeeded"; then
    echo "✓ $pod -> $TARGET_SVC:$TARGET_PORT (ALLOWED)"
  else
    echo "✗ $pod -> $TARGET_SVC:$TARGET_PORT (BLOCKED)"
  fi
done
EOF

chmod +x /tmp/test-connectivity.sh
```

---

## Verification

### Check All Network Policies

```bash
# List all network policies across namespaces
kubectl get networkpolicy -A

# Verify policies in lab namespace
kubectl get networkpolicy -n netpol-lab -o wide
```

### Test Traffic Matrix

```bash
echo "=== Traffic Matrix ==="
echo ""
echo "Source              -> Target           : Result"
echo "──────────────────────────────────────────────────"
echo "external-client     -> frontend         : $(kubectl exec -n netpol-external external-client -- curl -s --max-time 3 -o /dev/null -w '%{http_code}' frontend.netpol-lab.svc.cluster.local 2>/dev/null || echo 'BLOCKED')"
echo "frontend            -> backend          : $(kubectl exec -n netpol-lab $(kubectl get pod -n netpol-lab -l app=frontend -o jsonpath='{.items[0].metadata.name}') -- curl -s --max-time 3 -o /dev/null -w '%{http_code}' backend.netpol-lab.svc.cluster.local 2>/dev/null || echo 'BLOCKED')"
echo "backend             -> database         : $(kubectl exec -n netpol-lab $(kubectl get pod -n netpol-lab -l app=backend -o jsonpath='{.items[0].metadata.name}') -- nc -zv -w 3 database 5432 2>&1 | grep -q 'open' && echo 'OPEN' || echo 'BLOCKED')"
```

---

## Common Issues and Solutions

### Issue 1: Policy Not Taking Effect

**Symptoms:** Traffic still flows after applying deny policy

**Solutions:**
1. Verify CNI supports Network Policies
2. Check pod selector matches
3. Ensure policy is in correct namespace

```bash
# Check CNI
kubectl get pods -n kube-system | grep -E "calico|cilium|weave"

# Verify selector matches pods
kubectl get pods -n netpol-lab --show-labels
```

### Issue 2: DNS Resolution Failing

**Symptoms:** Pods can't resolve service names

**Solutions:**
1. Add DNS egress rule
2. Check kube-dns labels

```bash
# Check kube-dns labels
kubectl get pods -n kube-system -l k8s-app=kube-dns --show-labels
```

### Issue 3: Cross-Namespace Policy Not Working

**Symptoms:** Policy with namespaceSelector doesn't match

**Solutions:**
1. Label the namespace
2. Check namespace selector syntax

```bash
# Label namespace
kubectl label namespace source-ns app=source
```

---

## Cleanup

```bash
# Remove lab resources
kubectl delete namespace netpol-lab netpol-external monitoring cilium-lab mtls-lab

rm -f /tmp/test-connectivity.sh
```

---

## Key Takeaways

1. **Default Deny** - Start with deny all, then allow specific traffic
2. **Namespace Isolation** - Use namespace selectors for cross-namespace policies
3. **DNS Access** - Always allow DNS (UDP 53) for service discovery
4. **Layer 7 Policies** - Use Cilium or service mesh for HTTP-level rules
5. **mTLS** - Encrypt all service-to-service communication

---

## Next Steps

Continue to [Lab 4: Secrets Management](../lab-04-secrets/README.md) to learn about securing sensitive data with external secret management.

---

## Additional Resources

- [Network Policies](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Cilium Network Policy](https://docs.cilium.io/en/stable/security/policy/)
- [Calico Network Policy](https://docs.projectcalico.org/security/calico-network-policy)
- [Istio Security](https://istio.io/latest/docs/concepts/security/)
- [Network Policy Editor](https://editor.networkpolicy.io/)
