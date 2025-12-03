# Module 6: Security - Assessment

## Overview

This assessment evaluates your ability to implement comprehensive Kubernetes security controls. You will configure RBAC, pod security, network policies, secrets management, and security monitoring.

**Duration:** 120 minutes  
**Total Points:** 100  
**Passing Score:** 70%

---

## Environment Setup

```bash
# Create assessment namespaces
kubectl create namespace security-assessment
kubectl create namespace team-alpha
kubectl create namespace team-beta
kubectl create namespace monitoring
kubectl create namespace database

# Label namespaces
kubectl label namespace monitoring purpose=monitoring
kubectl label namespace database purpose=data tier=backend
```

---

## Section 1: RBAC and Authentication (20 points)

### Task 1.1: Create Developer Role (4 points)

Create a Role named `developer` in the `team-alpha` namespace with the following permissions:

**Requirements:**
- Read access to pods, services, configmaps, and deployments
- Create and update deployments
- View pod logs
- Execute into pods

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: team-alpha
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
EOF

# Verify
kubectl describe role developer -n team-alpha
```

</details>

---

### Task 1.2: Create Service Account and Binding (4 points)

Create:
1. A ServiceAccount named `app-deployer` in `team-alpha`
2. Bind the `developer` role to this service account
3. Disable automount of service account token

<details>
<summary>Show Solution</summary>

```bash
# Create ServiceAccount
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: app-deployer
  namespace: team-alpha
automountServiceAccountToken: false
EOF

# Create RoleBinding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-deployer-binding
  namespace: team-alpha
subjects:
- kind: ServiceAccount
  name: app-deployer
  namespace: team-alpha
roleRef:
  kind: Role
  name: developer
  apiGroup: rbac.authorization.k8s.io
EOF

# Verify
kubectl auth can-i create deployments --as=system:serviceaccount:team-alpha:app-deployer -n team-alpha
kubectl auth can-i delete pods --as=system:serviceaccount:team-alpha:app-deployer -n team-alpha
```

</details>

---

### Task 1.3: Create Read-Only ClusterRole (4 points)

Create a ClusterRole named `cluster-viewer` that provides:
- Read-only access to all resources in core API group
- Read-only access to deployments, statefulsets, daemonsets
- Read-only access to ingresses

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cluster-viewer
rules:
- apiGroups: [""]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "daemonsets", "replicasets"]
  verbs: ["get", "list", "watch"]
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses"]
  verbs: ["get", "list", "watch"]
EOF

# Verify
kubectl describe clusterrole cluster-viewer
```

</details>

---

### Task 1.4: Restrict Secret Access (4 points)

Create RBAC rules that allow the `app-deployer` service account to:
- Only read secrets named `app-config` and `db-credentials` in `team-alpha`
- Cannot list or access any other secrets

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: team-alpha
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-config", "db-credentials"]
  verbs: ["get"]
EOF

kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-deployer-secrets
  namespace: team-alpha
subjects:
- kind: ServiceAccount
  name: app-deployer
  namespace: team-alpha
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Create test secrets
kubectl create secret generic app-config -n team-alpha --from-literal=key=value
kubectl create secret generic db-credentials -n team-alpha --from-literal=password=secret
kubectl create secret generic other-secret -n team-alpha --from-literal=data=test

# Verify
kubectl auth can-i get secrets/app-config --as=system:serviceaccount:team-alpha:app-deployer -n team-alpha
kubectl auth can-i get secrets/other-secret --as=system:serviceaccount:team-alpha:app-deployer -n team-alpha
kubectl auth can-i list secrets --as=system:serviceaccount:team-alpha:app-deployer -n team-alpha
```

</details>

---

### Task 1.5: Aggregated ClusterRole (4 points)

Create an aggregated ClusterRole named `platform-admin` that:
1. Aggregates all ClusterRoles labeled with `platform.example.com/aggregate-to-admin: "true"`
2. Create a ClusterRole `platform-monitoring` with that label that allows reading metrics
3. Create a ClusterRole `platform-logs` with that label that allows reading pod logs

<details>
<summary>Show Solution</summary>

```bash
# Aggregated ClusterRole
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-admin
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      platform.example.com/aggregate-to-admin: "true"
rules: []
EOF

# Monitoring role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-monitoring
  labels:
    platform.example.com/aggregate-to-admin: "true"
rules:
- apiGroups: ["metrics.k8s.io"]
  resources: ["pods", "nodes"]
  verbs: ["get", "list", "watch"]
EOF

# Logs role
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: platform-logs
  labels:
    platform.example.com/aggregate-to-admin: "true"
rules:
- apiGroups: [""]
  resources: ["pods/log"]
  verbs: ["get", "list", "watch"]
EOF

# Verify aggregation
kubectl describe clusterrole platform-admin
```

</details>

---

## Section 2: Pod Security (20 points)

### Task 2.1: Configure Namespace Security (4 points)

Configure the `team-alpha` namespace with:
- Enforce `baseline` Pod Security Standard
- Audit and warn on `restricted` standard
- Use latest version

<details>
<summary>Show Solution</summary>

```bash
kubectl label namespace team-alpha \
  pod-security.kubernetes.io/enforce=baseline \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/audit-version=latest \
  pod-security.kubernetes.io/warn=restricted \
  pod-security.kubernetes.io/warn-version=latest

# Verify
kubectl get namespace team-alpha --show-labels
```

</details>

---

### Task 2.2: Create Hardened Pod (5 points)

Create a Pod named `secure-web` in `security-assessment` namespace with:
- Image: `nginx:alpine`
- Run as non-root user (UID 1000)
- Read-only root filesystem
- Drop all capabilities
- Seccomp profile: RuntimeDefault
- Resource limits: 128Mi memory, 200m CPU
- No privilege escalation allowed

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secure-web
  namespace: security-assessment
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: nginx
    image: nginx:alpine
    resources:
      limits:
        memory: "128Mi"
        cpu: "200m"
      requests:
        memory: "64Mi"
        cpu: "100m"
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF

# Verify
kubectl get pod secure-web -n security-assessment -o jsonpath='{.spec.securityContext}'
kubectl get pod secure-web -n security-assessment -o jsonpath='{.spec.containers[0].securityContext}'
```

</details>

---

### Task 2.3: Create Secure Deployment (5 points)

Create a Deployment named `secure-api` in `security-assessment` with:
- 2 replicas
- Image: `hashicorp/http-echo:latest`
- Args: `-text="secure api"`
- All security controls from Task 2.2
- Use the `app-deployer` service account
- Disable service account token mounting

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-api
  namespace: security-assessment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: secure-api
  template:
    metadata:
      labels:
        app: secure-api
    spec:
      serviceAccountName: default
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: api
        image: hashicorp/http-echo:latest
        args:
        - "-text=secure api"
        - "-listen=:8080"
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "128Mi"
            cpu: "200m"
          requests:
            memory: "64Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
EOF

# Verify
kubectl get deployment secure-api -n security-assessment
kubectl get pods -l app=secure-api -n security-assessment
```

</details>

---

### Task 2.4: Configure Restricted Namespace (3 points)

Configure the `database` namespace to:
- Enforce `restricted` Pod Security Standard
- Only allow workloads that meet all security requirements

<details>
<summary>Show Solution</summary>

```bash
kubectl label namespace database \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest

# Verify by trying to create non-compliant pod
kubectl run test --image=nginx -n database --dry-run=server 2>&1 | grep -i "forbidden\|error"
```

</details>

---

### Task 2.5: Fix Insecure Pod (3 points)

The following pod spec is insecure. Fix all security issues:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: insecure-pod
  namespace: security-assessment
spec:
  containers:
  - name: app
    image: nginx
    securityContext:
      privileged: true
```

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: fixed-pod
  namespace: security-assessment
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  containers:
  - name: app
    image: nginx:alpine
    securityContext:
      privileged: false
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop:
        - ALL
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache/nginx
    - name: run
      mountPath: /var/run
  volumes:
  - name: tmp
    emptyDir: {}
  - name: cache
    emptyDir: {}
  - name: run
    emptyDir: {}
EOF
```

</details>

---

## Section 3: Network Security (20 points)

### Task 3.1: Default Deny Policy (4 points)

Create Network Policies in `security-assessment` that:
1. Deny all ingress traffic by default
2. Deny all egress traffic by default

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: security-assessment
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: security-assessment
spec:
  podSelector: {}
  policyTypes:
  - Egress
EOF

# Verify
kubectl get networkpolicy -n security-assessment
```

</details>

---

### Task 3.2: Allow DNS (3 points)

Create a Network Policy that allows all pods in `security-assessment` to access DNS.

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: security-assessment
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
```

</details>

---

### Task 3.3: Application Network Policy (5 points)

Create Network Policies for a three-tier application:
1. `frontend` can receive traffic from anywhere on port 80
2. `backend` can only receive traffic from `frontend` on port 8080
3. `database` (in `database` namespace) can only receive traffic from `backend` on port 5432

First, create test pods:
```bash
kubectl run frontend --image=nginx -n security-assessment -l app=frontend,tier=frontend
kubectl run backend --image=nginx -n security-assessment -l app=backend,tier=backend
kubectl run database --image=postgres:15 -n database -l app=database,tier=database --env=POSTGRES_PASSWORD=test
```

<details>
<summary>Show Solution</summary>

```bash
# Frontend ingress (allow from anywhere)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: frontend-ingress
  namespace: security-assessment
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

# Backend ingress (only from frontend)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-ingress
  namespace: security-assessment
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
      port: 8080
EOF

# Backend egress (to database)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress-db
  namespace: security-assessment
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          purpose: data
      podSelector:
        matchLabels:
          app: database
    ports:
    - protocol: TCP
      port: 5432
EOF

# Database ingress (only from backend in security-assessment)
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: database-ingress
  namespace: database
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
          kubernetes.io/metadata.name: security-assessment
      podSelector:
        matchLabels:
          app: backend
    ports:
    - protocol: TCP
      port: 5432
EOF
```

</details>

---

### Task 3.4: Monitoring Access (4 points)

Create a Network Policy that allows the `monitoring` namespace to scrape metrics from all pods in `security-assessment` on port 9090.

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: security-assessment
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          purpose: monitoring
    ports:
    - protocol: TCP
      port: 9090
EOF

# Verify
kubectl describe networkpolicy allow-monitoring -n security-assessment
```

</details>

---

### Task 3.5: Block Metadata Service (4 points)

Create a Network Policy that blocks pods from accessing the cloud metadata service (169.254.169.254) while allowing other external traffic.

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: block-metadata
  namespace: security-assessment
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - to:
    - ipBlock:
        cidr: 0.0.0.0/0
        except:
        - 169.254.169.254/32
EOF
```

</details>

---

## Section 4: Secrets Management (20 points)

### Task 4.1: Create Application Secrets (4 points)

Create the following secrets in `security-assessment`:
1. `db-credentials` with `username=appuser` and `password=S3cur3P@ss!`
2. `api-keys` with `primary=abc123` and `secondary=xyz789`

<details>
<summary>Show Solution</summary>

```bash
kubectl create secret generic db-credentials \
  -n security-assessment \
  --from-literal=username=appuser \
  --from-literal=password='S3cur3P@ss!'

kubectl create secret generic api-keys \
  -n security-assessment \
  --from-literal=primary=abc123 \
  --from-literal=secondary=xyz789

# Verify
kubectl get secrets -n security-assessment
```

</details>

---

### Task 4.2: Use Secrets in Pod (4 points)

Create a Pod named `secret-consumer` in `security-assessment` that:
- Uses `db-credentials` as environment variables (`DB_USER`, `DB_PASS`)
- Mounts `api-keys` as files in `/etc/api-keys`
- Image: `busybox:latest`
- Command: `sleep 3600`

<details>
<summary>Show Solution</summary>

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-consumer
  namespace: security-assessment
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sleep", "3600"]
    env:
    - name: DB_USER
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: username
    - name: DB_PASS
      valueFrom:
        secretKeyRef:
          name: db-credentials
          key: password
    volumeMounts:
    - name: api-keys
      mountPath: /etc/api-keys
      readOnly: true
  volumes:
  - name: api-keys
    secret:
      secretName: api-keys
EOF

# Verify
kubectl exec secret-consumer -n security-assessment -- env | grep DB_
kubectl exec secret-consumer -n security-assessment -- cat /etc/api-keys/primary
```

</details>

---

### Task 4.3: External Secrets Configuration (4 points)

Create an ExternalSecret configuration (without actually deploying ESO) that would:
1. Sync from a Vault SecretStore named `vault-backend`
2. Create a secret named `synced-credentials`
3. Refresh every 30 minutes
4. Include `database/username` and `database/password` from Vault path `apps/myapp`

<details>
<summary>Show Solution</summary>

```bash
# SecretStore (reference only - requires ESO)
cat <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: security-assessment
spec:
  provider:
    vault:
      server: "http://vault.vault.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "myapp"
          serviceAccountRef:
            name: vault-auth
EOF

# ExternalSecret
cat > /tmp/external-secret.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: synced-credentials
  namespace: security-assessment
spec:
  refreshInterval: 30m
  secretStoreRef:
    kind: SecretStore
    name: vault-backend
  target:
    name: synced-credentials
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: apps/myapp
      property: database/username
  - secretKey: password
    remoteRef:
      key: apps/myapp
      property: database/password
EOF

cat /tmp/external-secret.yaml
```

</details>

---

### Task 4.4: Sealed Secret (4 points)

Create a manifest for a SealedSecret (without kubeseal) that would encrypt:
- Secret name: `sealed-db-creds`
- Namespace: `security-assessment`
- Keys: `host`, `port`, `database`, `user`, `password`

Write the structure showing where encrypted values would go.

<details>
<summary>Show Solution</summary>

```bash
# Source secret (NOT to be committed to Git)
cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: sealed-db-creds
  namespace: security-assessment
type: Opaque
stringData:
  host: "db.example.com"
  port: "5432"
  database: "myapp"
  user: "admin"
  password: "supersecret"
EOF

# Sealed Secret structure (after kubeseal encryption)
cat > /tmp/sealed-secret.yaml <<EOF
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: sealed-db-creds
  namespace: security-assessment
spec:
  encryptedData:
    host: AgBz7...encrypted...base64...
    port: AgCxy...encrypted...base64...
    database: AgDef...encrypted...base64...
    user: AgEgh...encrypted...base64...
    password: AgFij...encrypted...base64...
  template:
    metadata:
      name: sealed-db-creds
      namespace: security-assessment
    type: Opaque
EOF

echo "To create real sealed secret:"
echo "kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets --format yaml < secret.yaml > sealed-secret.yaml"
```

</details>

---

### Task 4.5: RBAC for Secrets (4 points)

Create RBAC rules that:
1. Allow service account `app-reader` to only read specific secrets (`app-config`, `api-keys`)
2. Deny listing all secrets
3. Create the service account

<details>
<summary>Show Solution</summary>

```bash
# Create service account
kubectl create serviceaccount app-reader -n security-assessment

# Create role with specific secret access
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: specific-secret-reader
  namespace: security-assessment
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-config", "api-keys"]
  verbs: ["get"]
EOF

# Create role binding
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-reader-secrets
  namespace: security-assessment
subjects:
- kind: ServiceAccount
  name: app-reader
  namespace: security-assessment
roleRef:
  kind: Role
  name: specific-secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF

# Verify
kubectl auth can-i get secrets/api-keys --as=system:serviceaccount:security-assessment:app-reader -n security-assessment
kubectl auth can-i list secrets --as=system:serviceaccount:security-assessment:app-reader -n security-assessment
kubectl auth can-i get secrets/db-credentials --as=system:serviceaccount:security-assessment:app-reader -n security-assessment
```

</details>

---

## Section 5: Security Monitoring and Compliance (20 points)

### Task 5.1: Audit Policy (5 points)

Create an audit policy that:
1. Logs secret access at Metadata level (no secret content)
2. Logs all RBAC changes at RequestResponse level
3. Logs pod exec/attach at RequestResponse level
4. Ignores health check endpoints
5. Logs everything else at Metadata level

<details>
<summary>Show Solution</summary>

```bash
cat > /tmp/audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Don't log health checks
- level: None
  nonResourceURLs:
  - /healthz*
  - /readyz*
  - /livez*
  - /version

# Log secrets at Metadata (no content)
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
  omitStages:
  - RequestReceived

# Log RBAC changes at RequestResponse
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
    resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["create", "update", "patch", "delete"]
  omitStages:
  - RequestReceived

# Log pod exec/attach at RequestResponse
- level: RequestResponse
  resources:
  - group: ""
    resources: ["pods/exec", "pods/attach", "pods/portforward"]
  omitStages:
  - RequestReceived

# Log everything else at Metadata
- level: Metadata
  omitStages:
  - RequestReceived
EOF

cat /tmp/audit-policy.yaml
```

</details>

---

### Task 5.2: Security Compliance Check Script (5 points)

Create a script that checks for:
1. Namespaces without Pod Security labels
2. Pods running as root
3. Pods with privileged containers
4. Pods without resource limits
5. Service accounts with automount enabled

<details>
<summary>Show Solution</summary>

```bash
cat > /tmp/security-check.sh <<'EOF'
#!/bin/bash

echo "=== Kubernetes Security Compliance Check ==="
echo ""

echo "1. Namespaces without Pod Security labels:"
kubectl get namespaces -o json | jq -r '
  .items[] | 
  select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null) | 
  .metadata.name' | grep -v "^kube-"
echo ""

echo "2. Pods that may run as root:"
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.securityContext.runAsNonRoot != true) |
  select(.spec.containers[].securityContext.runAsNonRoot != true) |
  "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null | head -20
echo ""

echo "3. Privileged containers:"
kubectl get pods -A -o json | jq -r '
  .items[] | 
  . as $pod |
  .spec.containers[] | 
  select(.securityContext.privileged == true) |
  "\($pod.metadata.namespace)/\($pod.metadata.name) - \(.name)"' 2>/dev/null
echo ""

echo "4. Pods without resource limits:"
kubectl get pods -A -o json | jq -r '
  .items[] |
  . as $pod |
  .spec.containers[] |
  select(.resources.limits == null) |
  "\($pod.metadata.namespace)/\($pod.metadata.name) - \(.name)"' 2>/dev/null | head -20
echo ""

echo "5. Service accounts with automount enabled:"
kubectl get serviceaccounts -A -o json | jq -r '
  .items[] |
  select(.automountServiceAccountToken != false) |
  "\(.metadata.namespace)/\(.metadata.name)"' | grep -v "^kube-" | head -20
echo ""

echo "=== Check Complete ==="
EOF

chmod +x /tmp/security-check.sh
/tmp/security-check.sh
```

</details>

---

### Task 5.3: Falco Rule (4 points)

Write a Falco rule that detects:
1. Shell execution in containers
2. Sensitive file access (/etc/shadow, /etc/passwd)
3. Network connections to suspicious ports (4444, 5555)

<details>
<summary>Show Solution</summary>

```bash
cat > /tmp/custom-falco-rules.yaml <<EOF
# Shell execution in container
- rule: Shell Spawned in Container
  desc: Detect shell spawned in a container
  condition: >
    spawned_process and container and
    (proc.name in (bash, sh, zsh, ksh, csh, fish)) and
    proc.tty != 0
  output: >
    Shell spawned in container
    (user=%user.name user_uid=%user.uid container=%container.name 
     container_id=%container.id shell=%proc.name parent=%proc.pname
     cmdline=%proc.cmdline)
  priority: WARNING
  tags: [container, shell, mitre_execution]

# Sensitive file access
- rule: Sensitive File Read in Container
  desc: Detect read access to sensitive files in containers
  condition: >
    open_read and container and
    (fd.name startswith /etc/shadow or
     fd.name startswith /etc/passwd or
     fd.name startswith /etc/sudoers)
  output: >
    Sensitive file accessed in container
    (user=%user.name file=%fd.name container=%container.name
     image=%container.image.repository)
  priority: WARNING
  tags: [container, filesystem, sensitive]

# Suspicious network connections
- rule: Suspicious Outbound Connection
  desc: Detect connections to commonly used attack ports
  condition: >
    outbound and container and
    (fd.sport in (4444, 5555, 6666, 1337))
  output: >
    Suspicious outbound connection
    (user=%user.name command=%proc.cmdline connection=%fd.name
     container=%container.name image=%container.image.repository)
  priority: CRITICAL
  tags: [container, network, mitre_command_and_control]
EOF

cat /tmp/custom-falco-rules.yaml
```

</details>

---

### Task 5.4: Security Remediation (3 points)

Given the following insecure deployment, list all security issues and fix them:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vulnerable-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vulnerable
  template:
    metadata:
      labels:
        app: vulnerable
    spec:
      containers:
      - name: app
        image: myapp:latest
        ports:
        - containerPort: 8080
```

<details>
<summary>Show Solution</summary>

```bash
echo "Issues identified:"
echo "1. No runAsNonRoot - may run as root"
echo "2. No readOnlyRootFilesystem"
echo "3. No capability dropping"
echo "4. No allowPrivilegeEscalation: false"
echo "5. No seccompProfile"
echo "6. Using :latest tag (not pinned)"
echo "7. No resource limits"
echo "8. No service account configured"
echo "9. automountServiceAccountToken not disabled"
echo ""

# Fixed deployment
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: secure-app
  namespace: security-assessment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: secure
  template:
    metadata:
      labels:
        app: secure
    spec:
      serviceAccountName: default
      automountServiceAccountToken: false
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 1000
        seccompProfile:
          type: RuntimeDefault
      containers:
      - name: app
        image: myapp:v1.0.0  # Pinned version
        ports:
        - containerPort: 8080
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "100m"
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          capabilities:
            drop:
            - ALL
        volumeMounts:
        - name: tmp
          mountPath: /tmp
      volumes:
      - name: tmp
        emptyDir: {}
EOF
```

</details>

---

### Task 5.5: Security Report (3 points)

Create a script that generates a security report including:
1. Count of namespaces by PSA enforcement level
2. Count of network policies per namespace
3. Count of secrets per namespace
4. List of ClusterRoleBindings with cluster-admin

<details>
<summary>Show Solution</summary>

```bash
cat > /tmp/security-report.sh <<'EOF'
#!/bin/bash

echo "========================================"
echo "      KUBERNETES SECURITY REPORT       "
echo "      Generated: $(date)               "
echo "========================================"
echo ""

echo "1. Namespaces by Pod Security Level:"
echo "------------------------------------"
for level in privileged baseline restricted; do
  count=$(kubectl get ns -l "pod-security.kubernetes.io/enforce=$level" --no-headers 2>/dev/null | wc -l)
  echo "  $level: $count"
done
no_psa=$(kubectl get ns -o json | jq '[.items[] | select(.metadata.labels["pod-security.kubernetes.io/enforce"] == null)] | length')
echo "  No PSA: $no_psa"
echo ""

echo "2. Network Policies per Namespace:"
echo "-----------------------------------"
kubectl get networkpolicy -A --no-headers 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
echo ""

echo "3. Secrets per Namespace:"
echo "-------------------------"
kubectl get secrets -A --no-headers 2>/dev/null | awk '{print $1}' | sort | uniq -c | sort -rn | head -10
echo ""

echo "4. ClusterRoleBindings with cluster-admin:"
echo "------------------------------------------"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | 
  select(.roleRef.name == "cluster-admin") | 
  "\(.metadata.name): \(.subjects | map("\(.kind)/\(.name)") | join(", "))"'
echo ""

echo "5. Service Accounts with Cluster-Wide Permissions:"
echo "---------------------------------------------------"
kubectl get clusterrolebindings -o json | jq -r '
  .items[] | 
  select(.subjects != null) |
  .subjects[] | 
  select(.kind == "ServiceAccount") | 
  "\(.namespace)/\(.name)"' | sort -u | head -10
echo ""

echo "========================================"
echo "            END OF REPORT              "
echo "========================================"
EOF

chmod +x /tmp/security-report.sh
/tmp/security-report.sh
```

</details>

---

## Cleanup

```bash
# Remove all assessment resources
kubectl delete namespace security-assessment team-alpha team-beta monitoring database

# Remove cluster-scoped resources
kubectl delete clusterrole cluster-viewer platform-admin platform-monitoring platform-logs
kubectl delete clusterrolebinding readonly-binding

rm -f /tmp/*.yaml /tmp/*.sh
```

---

## Scoring Guide

| Section | Points | Your Score |
|---------|--------|------------|
| Section 1: RBAC and Authentication | 20 | |
| Section 2: Pod Security | 20 | |
| Section 3: Network Security | 20 | |
| Section 4: Secrets Management | 20 | |
| Section 5: Security Monitoring | 20 | |
| **Total** | **100** | |

**Passing Score: 70 points**

---

## Key Competencies Tested

1. **RBAC Configuration** - Creating roles, bindings, and managing permissions
2. **Pod Security** - Implementing PSA, security contexts, and capabilities
3. **Network Policies** - Designing zero-trust network architecture
4. **Secrets Management** - Securing sensitive data with various methods
5. **Security Monitoring** - Audit logging, compliance checks, and threat detection
