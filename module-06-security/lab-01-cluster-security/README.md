# Lab 1: Cluster Security Fundamentals

## Overview

This lab covers the foundational security concepts for Kubernetes clusters, including authentication, authorization (RBAC), service account security, and audit logging. Understanding these fundamentals is essential for building a secure platform.

## Objectives

- Understand Kubernetes authentication methods
- Implement comprehensive RBAC policies
- Configure secure service accounts
- Enable and configure audit logging
- Apply security best practices

## Prerequisites

- Running Kubernetes cluster (1.28+)
- kubectl configured with admin access
- Basic understanding of TLS/certificates

---

## Kubernetes Security Model

### Authentication Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUTHENTICATION FLOW                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────┐         ┌─────────────┐         ┌───────────────┐  │
│  │  User   │         │ API Server  │         │  Authorizer   │  │
│  │ Request │────────▶│ Authenticate│────────▶│   (RBAC)      │  │
│  └─────────┘         └─────────────┘         └───────────────┘  │
│       │                     │                       │            │
│       │                     ▼                       ▼            │
│       │              ┌─────────────┐         ┌───────────────┐  │
│       │              │ Identity    │         │   Admission   │  │
│       │              │ - X.509     │         │   Control     │  │
│       │              │ - Token     │         └───────────────┘  │
│       │              │ - OIDC      │               │            │
│       │              └─────────────┘               ▼            │
│       │                                      ┌───────────────┐  │
│       └─────────────────────────────────────▶│   Resource    │  │
│                                              │   Access      │  │
│                                              └───────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Authentication Methods

| Method | Use Case | Notes |
|--------|----------|-------|
| X.509 Certificates | Admin users, kubeconfig | Common for initial setup |
| Bearer Tokens | Service accounts | Auto-mounted in pods |
| OIDC | Enterprise SSO | Recommended for users |
| Webhook | Custom authentication | External auth systems |
| Authenticating Proxy | API gateway pattern | Headers-based auth |

---

## Part 1: Understanding Authentication

### Step 1.1: Examine Current Authentication

Check your current authentication context:

```bash
# View current context
kubectl config current-context

# View detailed kubeconfig
kubectl config view

# Check authentication info
kubectl config view --minify -o jsonpath='{.users[0].user}'
```

### Step 1.2: Examine API Server Authentication

```bash
# View API server flags (if using kubeadm)
kubectl get pods -n kube-system kube-apiserver-* -o jsonpath='{.items[0].spec.containers[0].command}' | tr ',' '\n' | grep -E "auth|token|oidc"

# Check current identity
kubectl auth whoami
```

### Step 1.3: Understanding X.509 Authentication

Create a new user certificate:

```bash
# Create a directory for certificates
mkdir -p ~/k8s-certs && cd ~/k8s-certs

# Generate private key
openssl genrsa -out developer.key 2048

# Create Certificate Signing Request
cat > developer-csr.conf <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn

[dn]
CN = developer
O = developers
EOF

openssl req -new -key developer.key -out developer.csr -config developer-csr.conf

# View the CSR
openssl req -in developer.csr -noout -text
```

### Step 1.4: Submit CSR to Kubernetes

```bash
# Base64 encode the CSR
CSR_BASE64=$(cat developer.csr | base64 | tr -d '\n')

# Create Kubernetes CSR resource
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: developer-csr
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # 1 day
  usages:
  - client auth
EOF

# Check CSR status
kubectl get csr developer-csr
```

### Step 1.5: Approve and Use the Certificate

```bash
# Approve the CSR (as admin)
kubectl certificate approve developer-csr

# Get the signed certificate
kubectl get csr developer-csr -o jsonpath='{.status.certificate}' | base64 -d > developer.crt

# View the certificate
openssl x509 -in developer.crt -noout -text | head -20

# Add to kubeconfig
kubectl config set-credentials developer \
  --client-certificate=developer.crt \
  --client-key=developer.key

kubectl config set-context developer-context \
  --cluster=$(kubectl config view -o jsonpath='{.clusters[0].name}') \
  --user=developer

# Test (will fail - no RBAC yet)
kubectl --context=developer-context get pods
```

---

## Part 2: RBAC Deep Dive

### RBAC Components

```
┌─────────────────────────────────────────────────────────────────┐
│                      RBAC COMPONENTS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  NAMESPACE-SCOPED                    CLUSTER-SCOPED             │
│  ─────────────────                   ─────────────              │
│                                                                  │
│  ┌─────────────┐                    ┌─────────────┐             │
│  │    Role     │                    │ ClusterRole │             │
│  │             │                    │             │             │
│  │ - resources │                    │ - resources │             │
│  │ - verbs     │                    │ - verbs     │             │
│  │ - apiGroups │                    │ - apiGroups │             │
│  └──────┬──────┘                    └──────┬──────┘             │
│         │                                   │                    │
│         ▼                                   ▼                    │
│  ┌─────────────┐                    ┌─────────────────────┐     │
│  │RoleBinding  │                    │ClusterRoleBinding   │     │
│  │             │                    │                     │     │
│  │ - subjects  │                    │ - subjects          │     │
│  │   (users,   │                    │   (users, groups,   │     │
│  │    groups,  │                    │    serviceAccounts) │     │
│  │    SAs)     │                    │ - clusterRole       │     │
│  │ - roleRef   │                    │                     │     │
│  └─────────────┘                    └─────────────────────┘     │
│                                                                  │
│  NOTE: RoleBinding can reference ClusterRole                    │
│        (namespace-scoped permissions from ClusterRole)          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2.1: Create a Custom Role

Create a role for developers with limited access:

```bash
# Create namespace for practice
kubectl create namespace security-lab

# Create a Role with read access to pods and deployments
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: security-lab
  name: developer-role
rules:
- apiGroups: [""]
  resources: ["pods", "pods/log", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
EOF

# View the role
kubectl describe role developer-role -n security-lab
```

### Step 2.2: Create Role Binding

Bind the role to our developer user:

```bash
# Create RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: security-lab
subjects:
- kind: User
  name: developer
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: developer-role
  apiGroup: rbac.authorization.k8s.io
EOF

# View the binding
kubectl describe rolebinding developer-binding -n security-lab
```

### Step 2.3: Test RBAC Permissions

```bash
# Test as developer user
kubectl --context=developer-context get pods -n security-lab
# Should succeed (empty list)

kubectl --context=developer-context get secrets -n security-lab
# Should fail (Forbidden)

# Create a deployment
kubectl --context=developer-context apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: security-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test
  template:
    metadata:
      labels:
        app: test
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
EOF

# Verify
kubectl --context=developer-context get deployments -n security-lab
```

### Step 2.4: Using kubectl auth can-i

```bash
# Check if current user can perform actions
kubectl auth can-i create deployments -n security-lab

# Check as developer
kubectl --context=developer-context auth can-i create deployments -n security-lab
kubectl --context=developer-context auth can-i delete deployments -n security-lab
kubectl --context=developer-context auth can-i get secrets -n security-lab

# List all permissions for developer
kubectl --context=developer-context auth can-i --list -n security-lab
```

### Step 2.5: Create ClusterRole for Read-Only Access

```bash
# ClusterRole for read-only access to common resources
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: read-only-viewer
rules:
- apiGroups: [""]
  resources: ["namespaces", "pods", "services", "configmaps", "endpoints"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["get", "list", "watch"]
EOF

# Bind to developers group
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: developers-viewer
subjects:
- kind: Group
  name: developers
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: read-only-viewer
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Step 2.6: RBAC Aggregation

Create aggregated ClusterRoles:

```bash
# Base monitoring role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-base
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: [""]
  resources: ["pods", "services"]
  verbs: ["get", "list", "watch"]
EOF

# Additional metrics role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-metrics
  labels:
    rbac.example.com/aggregate-to-monitoring: "true"
rules:
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list", "watch"]
EOF

# Aggregated role that combines all monitoring roles
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring-aggregated
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: []  # Rules are automatically filled
EOF

# Check the aggregated role
kubectl describe clusterrole monitoring-aggregated
```

---

## Part 3: Service Account Security

### Service Account Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                SERVICE ACCOUNT ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐          ┌──────────────────────────────┐ │
│  │     Pod          │          │     API Server               │ │
│  │  ┌────────────┐  │          │                              │ │
│  │  │ Container  │  │  Token   │  ┌────────────────────────┐  │ │
│  │  │            │──┼──────────┼─▶│ TokenReview API        │  │ │
│  │  │ /var/run/  │  │          │  │                        │  │ │
│  │  │ secrets/   │  │          │  │ - Validate JWT token   │  │ │
│  │  │ kubernetes │  │          │  │ - Extract ServiceAccount│ │ │
│  │  │ .io/       │  │          │  │ - Check expiration     │  │ │
│  │  │ serviceacc │  │          │  └────────────────────────┘  │ │
│  │  │ ount/      │  │          │              │                │ │
│  │  │            │  │          │              ▼                │ │
│  │  │ - token    │  │          │  ┌────────────────────────┐  │ │
│  │  │ - ca.crt   │  │          │  │ Authorization (RBAC)   │  │ │
│  │  │ - namespace│  │          │  └────────────────────────┘  │ │
│  │  └────────────┘  │          │                              │ │
│  └──────────────────┘          └──────────────────────────────┘ │
│                                                                  │
│  Bound Service Account Tokens:                                  │
│  - Time-bound (expiration)                                      │
│  - Audience-bound (intended recipient)                          │
│  - Object-bound (pod reference)                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3.1: Create Service Account with Limited Permissions

```bash
# Create a service account
kubectl create serviceaccount app-sa -n security-lab

# Create a role for the app
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: app-role
  namespace: security-lab
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["app-config"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-secrets"]
  verbs: ["get"]
EOF

# Bind the role to the service account
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-sa-binding
  namespace: security-lab
subjects:
- kind: ServiceAccount
  name: app-sa
  namespace: security-lab
roleRef:
  kind: Role
  name: app-role
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Step 3.2: Create Pod with Service Account

```bash
# Create resources for the app
kubectl create configmap app-config -n security-lab --from-literal=key=value
kubectl create secret generic app-secrets -n security-lab --from-literal=password=secret

# Create pod using the service account
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: app-pod
  namespace: security-lab
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: true
  containers:
  - name: app
    image: curlimages/curl:latest
    command: ["sleep", "infinity"]
EOF

kubectl wait --for=condition=Ready pod/app-pod -n security-lab --timeout=60s
```

### Step 3.3: Test Service Account Permissions

```bash
# Exec into the pod
kubectl exec -it app-pod -n security-lab -- sh

# Inside the pod, test API access
# Get token
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)
CA_CERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Test getting the allowed configmap
curl -s --cacert $CA_CERT \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/configmaps/app-config

# Test getting a non-allowed configmap (should fail)
curl -s --cacert $CA_CERT \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/configmaps/other-config

# Exit the pod
exit
```

### Step 3.4: Disable Token Auto-Mounting

```bash
# Create a pod without token mounting
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: no-token-pod
  namespace: security-lab
spec:
  serviceAccountName: app-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx:alpine
EOF

kubectl wait --for=condition=Ready pod/no-token-pod -n security-lab --timeout=60s

# Verify no token is mounted
kubectl exec no-token-pod -n security-lab -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null || echo "No secrets mounted - as expected"
```

### Step 3.5: Configure Service Account at Namespace Level

```bash
# Disable auto-mounting for default SA in namespace
kubectl patch serviceaccount default -n security-lab \
  -p '{"automountServiceAccountToken": false}'

# Create a pod using default SA
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: default-sa-pod
  namespace: security-lab
spec:
  containers:
  - name: app
    image: nginx:alpine
EOF

kubectl wait --for=condition=Ready pod/default-sa-pod -n security-lab --timeout=60s

# Verify no token is mounted
kubectl exec default-sa-pod -n security-lab -- ls /var/run/secrets/kubernetes.io/serviceaccount/ 2>/dev/null || echo "No secrets mounted - default SA has automount disabled"
```

### Step 3.6: Create Token with Specific Audience

```bash
# Create a token with specific audience (for Vault, etc.)
kubectl create token app-sa -n security-lab \
  --audience=vault \
  --duration=1h

# Create a token request manifest
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: vault-client
  namespace: security-lab
spec:
  serviceAccountName: app-sa
  containers:
  - name: client
    image: curlimages/curl:latest
    command: ["sleep", "infinity"]
    volumeMounts:
    - mountPath: /var/run/secrets/tokens
      name: vault-token
  volumes:
  - name: vault-token
    projected:
      sources:
      - serviceAccountToken:
          path: vault-token
          audience: vault
          expirationSeconds: 3600
EOF
```

---

## Part 4: Audit Logging

### Audit Policy Levels

```
┌─────────────────────────────────────────────────────────────────┐
│                    AUDIT POLICY LEVELS                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Level: None                                                     │
│  ─────────────                                                   │
│  Don't log events that match this rule                          │
│                                                                  │
│  Level: Metadata                                                 │
│  ───────────────                                                 │
│  Log request metadata (user, timestamp, resource, verb)         │
│  Don't log request or response body                             │
│                                                                  │
│  Level: Request                                                  │
│  ──────────────                                                  │
│  Log metadata and request body                                  │
│  Don't log response body                                        │
│                                                                  │
│  Level: RequestResponse                                          │
│  ──────────────────────                                          │
│  Log metadata, request body, and response body                  │
│  Most verbose, use sparingly                                    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 4.1: Create Audit Policy

```bash
# Create comprehensive audit policy
cat > /tmp/audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
  # Don't log requests to certain non-resource URLs
  - level: None
    nonResourceURLs:
    - /healthz*
    - /version
    - /readyz
    - /livez

  # Don't log watch requests
  - level: None
    verbs: ["watch"]

  # Don't log requests to configmaps called "kube-*"
  - level: None
    resources:
    - group: ""
      resources: ["configmaps"]
    namespaces: ["kube-system"]
    
  # Log Secret access at Metadata level (don't log secret content)
  - level: Metadata
    resources:
    - group: ""
      resources: ["secrets"]
    omitStages:
    - RequestReceived

  # Log authentication at RequestResponse level
  - level: RequestResponse
    resources:
    - group: "authentication.k8s.io"
      resources: ["tokenreviews"]
    - group: "authorization.k8s.io"
      resources: ["subjectaccessreviews"]

  # Log pod exec and attach
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["pods/exec", "pods/attach", "pods/portforward"]

  # Log RBAC changes
  - level: RequestResponse
    resources:
    - group: "rbac.authorization.k8s.io"
      resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
    verbs: ["create", "update", "patch", "delete"]

  # Log node and namespace changes
  - level: RequestResponse
    resources:
    - group: ""
      resources: ["nodes", "namespaces"]
    verbs: ["create", "update", "patch", "delete"]

  # Log everything else at Metadata level
  - level: Metadata
    omitStages:
    - RequestReceived
EOF

cat /tmp/audit-policy.yaml
```

### Step 4.2: Understand Audit Log Format

Example audit log entry:

```json
{
  "kind": "Event",
  "apiVersion": "audit.k8s.io/v1",
  "level": "RequestResponse",
  "auditID": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "stage": "ResponseComplete",
  "requestURI": "/api/v1/namespaces/default/secrets",
  "verb": "create",
  "user": {
    "username": "admin",
    "groups": ["system:masters", "system:authenticated"]
  },
  "sourceIPs": ["10.0.0.1"],
  "userAgent": "kubectl/v1.28.0",
  "objectRef": {
    "resource": "secrets",
    "namespace": "default",
    "name": "my-secret",
    "apiVersion": "v1"
  },
  "responseStatus": {
    "metadata": {},
    "code": 201
  },
  "requestReceivedTimestamp": "2024-01-15T10:30:00.000000Z",
  "stageTimestamp": "2024-01-15T10:30:00.100000Z"
}
```

### Step 4.3: Configure Audit for Kind Cluster (Optional)

If using Kind, you can enable audit logging:

```bash
# Create Kind cluster config with audit logging
cat > /tmp/kind-audit-config.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: ClusterConfiguration
    apiServer:
      extraArgs:
        audit-policy-file: /etc/kubernetes/audit-policy.yaml
        audit-log-path: /var/log/kubernetes/audit.log
        audit-log-maxage: "30"
        audit-log-maxbackup: "10"
        audit-log-maxsize: "100"
      extraVolumes:
      - name: audit
        hostPath: /etc/kubernetes
        mountPath: /etc/kubernetes
        readOnly: true
      - name: audit-log
        hostPath: /var/log/kubernetes
        mountPath: /var/log/kubernetes
        readOnly: false
  extraMounts:
  - hostPath: /tmp/audit-policy.yaml
    containerPath: /etc/kubernetes/audit-policy.yaml
    readOnly: true
EOF
```

### Step 4.4: Simulating Audit Events

Create activities that would be logged:

```bash
# Create various resources to generate audit events
kubectl create namespace audit-test

# Create and access secrets
kubectl create secret generic test-secret -n audit-test --from-literal=key=value
kubectl get secret test-secret -n audit-test -o yaml

# Create RBAC resources
kubectl create role test-role -n audit-test --verb=get --resource=pods

# Pod exec (would be logged at RequestResponse level)
kubectl run test-pod --image=nginx:alpine -n audit-test
kubectl wait --for=condition=Ready pod/test-pod -n audit-test --timeout=60s
kubectl exec test-pod -n audit-test -- whoami

# Clean up
kubectl delete namespace audit-test
```

---

## Part 5: Security Best Practices

### Step 5.1: Create Security-Hardened Namespace

```bash
# Create namespace with security labels
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: hardened-ns
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
EOF
```

### Step 5.2: Implement Least Privilege RBAC

```bash
# Create minimal role for CI/CD pipeline
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cicd-deployer
  namespace: hardened-ns
rules:
# Only allow creating/updating specific resources
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["create", "update", "patch", "get", "list"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["create", "update", "patch", "get", "list"]
- apiGroups: [""]
  resources: ["configmaps"]
  verbs: ["create", "update", "patch", "get", "list"]
# Explicitly deny secrets modification
# (by not including verbs for secrets)
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list"]  # read-only
EOF
```

### Step 5.3: Create a Dedicated Service Account for Workloads

```bash
# Each application should have its own SA
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: frontend-sa
  namespace: hardened-ns
automountServiceAccountToken: false
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backend-sa
  namespace: hardened-ns
automountServiceAccountToken: false
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: worker-sa
  namespace: hardened-ns
automountServiceAccountToken: false
EOF
```

### Step 5.4: RBAC Review Script

Create a script to review RBAC permissions:

```bash
cat > /tmp/rbac-review.sh <<'EOF'
#!/bin/bash

echo "=== RBAC Review Report ==="
echo ""

echo "=== ClusterRoleBindings with cluster-admin ==="
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | select(.roleRef.name == "cluster-admin") | 
    "\(.metadata.name): \(.subjects | map(.name) | join(", "))"'

echo ""
echo "=== ServiceAccounts with ClusterRoleBindings ==="
kubectl get clusterrolebindings -o json | \
  jq -r '.items[] | 
    select(.subjects != null) | 
    select(.subjects[].kind == "ServiceAccount") | 
    "\(.metadata.name) -> \(.roleRef.name): \(.subjects[] | select(.kind=="ServiceAccount") | "\(.namespace)/\(.name)")"'

echo ""
echo "=== Namespaces without Pod Security Labels ==="
kubectl get namespaces -o json | \
  jq -r '.items[] | 
    select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | 
    .metadata.name' | grep -v "^kube-"

echo ""
echo "=== ServiceAccounts with automount enabled ==="
kubectl get serviceaccounts -A -o json | \
  jq -r '.items[] | 
    select(.automountServiceAccountToken != false) | 
    "\(.metadata.namespace)/\(.metadata.name)"'
EOF

chmod +x /tmp/rbac-review.sh
```

### Step 5.5: Security Checklist Implementation

```bash
# Check API server anonymous auth (should be disabled in production)
kubectl get pods -n kube-system -l component=kube-apiserver -o jsonpath='{.items[0].spec.containers[0].command}' 2>/dev/null | tr ',' '\n' | grep anonymous-auth || echo "Check API server config manually"

# List all cluster-admin bindings
echo "=== Subjects with cluster-admin access ==="
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | 
  select(.roleRef.name=="cluster-admin") | 
  .subjects[]? | 
  "\(.kind): \(.name) (namespace: \(.namespace // "cluster-wide"))"
'

# Check for wildcards in ClusterRoles
echo ""
echo "=== ClusterRoles with wildcards ==="
kubectl get clusterroles -o json | jq -r '
  .items[] | 
  select(.rules != null) |
  select(.rules[] | 
    (.verbs[]? == "*") or 
    (.resources[]? == "*") or 
    (.apiGroups[]? == "*")
  ) | 
  .metadata.name
' | sort -u
```

---

## Verification

### Check Authentication

```bash
# Verify developer user setup
kubectl --context=developer-context auth can-i --list -n security-lab
```

### Check RBAC

```bash
# Verify roles and bindings
kubectl get roles,rolebindings -n security-lab
kubectl get clusterroles,clusterrolebindings | grep -E "developer|monitoring|read-only"
```

### Check Service Accounts

```bash
# Verify service account configurations
kubectl get serviceaccounts -n security-lab -o yaml | grep -E "name:|automount"
```

---

## Common Issues and Solutions

### Issue 1: Forbidden Error Despite RBAC

**Symptoms:** User gets "forbidden" even with proper RoleBinding

**Solutions:**
1. Check namespace in RoleBinding
2. Verify subject name matches exactly (case-sensitive)
3. Check if ClusterRoleBinding is needed instead

```bash
# Debug RBAC issues
kubectl auth can-i create pods --as=developer -n security-lab
kubectl get rolebindings -n security-lab -o yaml
```

### Issue 2: Token Not Working

**Symptoms:** API calls fail with token

**Solutions:**
1. Check token expiration
2. Verify audience (for bound tokens)
3. Check service account exists

```bash
# Decode and check token
kubectl get secrets -n security-lab -o jsonpath='{.items[?(@.type=="kubernetes.io/service-account-token")].data.token}' | base64 -d | cut -d. -f2 | base64 -d 2>/dev/null | jq .
```

### Issue 3: Audit Logs Not Generated

**Symptoms:** No audit logs appearing

**Solutions:**
1. Check audit policy syntax
2. Verify API server has audit flags
3. Check log file permissions

---

## Cleanup

```bash
# Remove lab resources
kubectl delete namespace security-lab
kubectl delete namespace hardened-ns
kubectl delete clusterrole read-only-viewer monitoring-base monitoring-metrics monitoring-aggregated
kubectl delete clusterrolebinding developers-viewer
kubectl config delete-context developer-context
kubectl config delete-user developer
kubectl delete csr developer-csr

rm -rf ~/k8s-certs
rm -f /tmp/audit-policy.yaml /tmp/rbac-review.sh
```

---

## Key Takeaways

1. **Authentication** - Use OIDC for users, bound tokens for service accounts
2. **Authorization** - Apply least privilege with scoped Roles
3. **Service Accounts** - Disable automount, use dedicated SAs per workload
4. **Audit Logging** - Log security-relevant events, especially secrets and RBAC changes
5. **Defense in Depth** - Layer security controls at multiple levels

---

## Next Steps

Continue to [Lab 2: Pod Security](../lab-02-pod-security/README.md) to learn about securing workloads with Pod Security Standards and security contexts.

---

## Additional Resources

- [Kubernetes Authentication](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Managing Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)
- [Audit Logging](https://kubernetes.io/docs/tasks/debug/debug-cluster/audit/)
- [CKA Security Checklist](https://kubernetes.io/docs/tasks/administer-cluster/securing-a-cluster/)
