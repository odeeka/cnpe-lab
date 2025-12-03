# Module 6: Security - Quick Reference

## RBAC (Role-Based Access Control)

### Create Role
```bash
# Namespace-scoped Role
kubectl create role developer \
  --verb=get,list,watch,create,update \
  --resource=pods,deployments \
  -n development

# From YAML
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: development
rules:
- apiGroups: [""]
  resources: ["pods", "services", "configmaps"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["apps"]
  resources: ["deployments"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
EOF
```

### Create ClusterRole
```bash
kubectl create clusterrole readonly \
  --verb=get,list,watch \
  --resource=pods,services,deployments

# Aggregated ClusterRole
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: monitoring
aggregationRule:
  clusterRoleSelectors:
  - matchLabels:
      rbac.example.com/aggregate-to-monitoring: "true"
rules: []  # Auto-filled
EOF
```

### Create Bindings
```bash
# RoleBinding
kubectl create rolebinding developer-binding \
  --role=developer \
  --user=john \
  -n development

# ClusterRoleBinding
kubectl create clusterrolebinding readonly-binding \
  --clusterrole=readonly \
  --group=developers

# Bind ClusterRole to namespace (RoleBinding + ClusterRole)
kubectl create rolebinding admin-binding \
  --clusterrole=admin \
  --user=admin \
  -n production
```

### Check Permissions
```bash
# As current user
kubectl auth can-i create pods
kubectl auth can-i create pods -n production
kubectl auth can-i --list

# As another user
kubectl auth can-i create pods --as=john
kubectl auth can-i create pods --as=john -n development

# As service account
kubectl auth can-i create pods --as=system:serviceaccount:default:myapp-sa
```

---

## Service Accounts

### Create Service Account
```bash
kubectl create serviceaccount myapp-sa -n default

# With automount disabled
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: myapp-sa
  namespace: default
automountServiceAccountToken: false
EOF
```

### Create Token
```bash
# Time-limited token
kubectl create token myapp-sa --duration=1h

# With audience
kubectl create token myapp-sa --audience=vault --duration=1h
```

### Use in Pod
```yaml
spec:
  serviceAccountName: myapp-sa
  automountServiceAccountToken: false  # Disable if not needed
```

---

## Pod Security

### Pod Security Admission Labels
```bash
# Label namespace for Pod Security Standards
kubectl label namespace production \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/enforce-version=latest \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

### Security Context (Pod Level)
```yaml
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
```

### Security Context (Container Level)
```yaml
containers:
- name: app
  securityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    capabilities:
      drop:
      - ALL
      add:
      - NET_BIND_SERVICE  # Only if needed
```

### Restricted Pod Template
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-pod
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    runAsGroup: 1000
    fsGroup: 1000
    seccompProfile:
      type: RuntimeDefault
  automountServiceAccountToken: false
  containers:
  - name: app
    image: nginx:alpine
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
```

---

## Network Policies

### Default Deny All
```yaml
# Deny all ingress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress

---
# Deny all egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Egress
```

### Allow DNS
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: production
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
```

### Allow Specific Traffic
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-frontend-to-backend
  namespace: production
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
```

### Cross-Namespace Access
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: production
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - protocol: TCP
      port: 9090
```

---

## Secrets Management

### Native Secrets
```bash
# Create from literals
kubectl create secret generic db-creds \
  --from-literal=username=admin \
  --from-literal=password=secret

# Create from file
kubectl create secret generic tls-cert \
  --from-file=tls.crt=/path/to/tls.crt \
  --from-file=tls.key=/path/to/tls.key

# TLS secret
kubectl create secret tls my-tls \
  --cert=tls.crt \
  --key=tls.key

# Docker registry
kubectl create secret docker-registry regcred \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=user \
  --docker-password=pass
```

### External Secrets
```yaml
# SecretStore
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault
  namespace: production
spec:
  provider:
    vault:
      server: "http://vault:8200"
      path: "secret"
      version: "v2"
      auth:
        kubernetes:
          mountPath: "kubernetes"
          role: "my-role"

---
# ExternalSecret
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: app-secret
  namespace: production
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: vault
  target:
    name: app-secret
  data:
  - secretKey: password
    remoteRef:
      key: myapp/config
      property: password
```

### Sealed Secrets
```bash
# Seal a secret
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml \
  < secret.yaml \
  > sealed-secret.yaml

# Apply sealed secret
kubectl apply -f sealed-secret.yaml
```

---

## Image Security

### Trivy Scanning
```bash
# Scan image
trivy image nginx:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL nginx:latest

# JSON output
trivy image --format json --output results.json nginx:latest

# Scan local filesystem
trivy fs --security-checks vuln,config .
```

### Cosign Signing
```bash
# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key myregistry/myimage:v1

# Verify signature
cosign verify --key cosign.pub myregistry/myimage:v1
```

### Kyverno Policies
```yaml
# Require image from trusted registry
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-trusted-registry
spec:
  validationFailureAction: Enforce
  rules:
  - name: validate-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must be from trusted registry"
      pattern:
        spec:
          containers:
          - image: "myregistry.io/*"

---
# Require image signature
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
spec:
  validationFailureAction: Enforce
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "myregistry.io/*"
      attestors:
      - entries:
        - keys:
            publicKeys: |-
              -----BEGIN PUBLIC KEY-----
              ...
              -----END PUBLIC KEY-----
```

---

## Runtime Security

### Falco Commands
```bash
# Check Falco status
kubectl get pods -n falco

# View Falco logs
kubectl logs -l app=falco -n falco -f

# Check custom rules
kubectl get configmap falco-rules -n falco -o yaml
```

### Falco Rules
```yaml
# Custom Falco rule
- rule: Terminal shell in container
  desc: A shell was used as entrypoint/exec in container
  condition: >
    spawned_process and container and
    shell_procs and proc.tty != 0
  output: >
    Shell spawned in container
    (user=%user.name container=%container.name shell=%proc.name)
  priority: WARNING
  tags: [container, shell]

- rule: Sensitive file access
  desc: Sensitive file accessed
  condition: >
    open_read and container and
    fd.name in (/etc/shadow, /etc/passwd, /etc/kubernetes/*)
  output: >
    Sensitive file accessed (file=%fd.name container=%container.name)
  priority: WARNING
  tags: [filesystem, sensitive]
```

### Kubescape
```bash
# Scan cluster
kubescape scan framework nsa

# Scan with CIS benchmark
kubescape scan framework cis-v1.23-t1.0.1

# Scan specific namespace
kubescape scan framework nsa --include-namespaces production

# Scan YAML files
kubescape scan *.yaml
```

---

## Audit Logging

### Audit Policy
```yaml
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
# Don't log read-only endpoints
- level: None
  nonResourceURLs:
  - /healthz*
  - /version
  - /readyz

# Log secrets at Metadata level only
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]

# Log authentication/authorization
- level: RequestResponse
  resources:
  - group: "authentication.k8s.io"
  - group: "authorization.k8s.io"

# Log RBAC changes
- level: RequestResponse
  resources:
  - group: "rbac.authorization.k8s.io"
  verbs: ["create", "update", "patch", "delete"]

# Log everything else at Metadata
- level: Metadata
```

---

## Quick Checks

### Security Audit Commands
```bash
# Check PSA labels on namespaces
kubectl get ns -l 'pod-security.kubernetes.io/enforce'

# Find privileged pods
kubectl get pods -A -o json | jq -r '
  .items[] | 
  select(.spec.containers[].securityContext.privileged == true) |
  "\(.metadata.namespace)/\(.metadata.name)"'

# Find pods running as root
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.securityContext.runAsNonRoot != true) |
  "\(.metadata.namespace)/\(.metadata.name)"'

# List network policies
kubectl get networkpolicy -A

# Check service accounts with cluster-admin
kubectl get clusterrolebindings -o json | jq -r '
  .items[] |
  select(.roleRef.name == "cluster-admin") |
  .subjects[]? |
  "\(.kind): \(.name)"'

# Find secrets in pods
kubectl get pods -A -o json | jq -r '
  .items[] |
  select(.spec.volumes[]?.secret != null) |
  "\(.metadata.namespace)/\(.metadata.name): \(.spec.volumes[].secret.secretName)"'
```

### Pod Security Check
```bash
# Check pod security context
kubectl get pod <pod> -o jsonpath='{.spec.securityContext}'

# Check container security context
kubectl get pod <pod> -o jsonpath='{.spec.containers[*].securityContext}'

# Test PSA compliance
kubectl --dry-run=server apply -f pod.yaml
```

---

## Common Patterns

### Least Privilege Pod
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: secure-app
spec:
  securityContext:
    runAsNonRoot: true
    runAsUser: 65534
    runAsGroup: 65534
    fsGroup: 65534
    seccompProfile:
      type: RuntimeDefault
  serviceAccountName: app-sa
  automountServiceAccountToken: false
  containers:
  - name: app
    image: myapp:v1
    securityContext:
      allowPrivilegeEscalation: false
      readOnlyRootFilesystem: true
      capabilities:
        drop: ["ALL"]
    resources:
      limits:
        cpu: "500m"
        memory: "128Mi"
      requests:
        cpu: "100m"
        memory: "64Mi"
    volumeMounts:
    - name: tmp
      mountPath: /tmp
    - name: cache
      mountPath: /var/cache
  volumes:
  - name: tmp
    emptyDir:
      sizeLimit: "100Mi"
  - name: cache
    emptyDir:
      sizeLimit: "100Mi"
```

### Zero-Trust Network Policy
```yaml
# Default deny all
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
---
# Allow only required traffic
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-policy
spec:
  podSelector:
    matchLabels:
      app: myapp
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: frontend
    ports:
    - port: 8080
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: database
    ports:
    - port: 5432
  - to:  # DNS
    - namespaceSelector: {}
      podSelector:
        matchLabels:
          k8s-app: kube-dns
    ports:
    - port: 53
      protocol: UDP
```

---

## Troubleshooting

### RBAC Issues
```bash
# Debug permission denied
kubectl auth can-i <verb> <resource> --as=<user> -n <namespace>

# List all permissions
kubectl auth can-i --list --as=<user> -n <namespace>

# Check role bindings for user
kubectl get rolebindings,clusterrolebindings -A -o json | \
  jq -r '.items[] | select(.subjects[]?.name == "<user>") | .metadata.name'
```

### Network Policy Issues
```bash
# Check policies affecting pod
kubectl get networkpolicy -n <namespace>

# Test connectivity
kubectl exec -n <ns> <pod> -- nc -zv <target> <port>

# Check if CNI supports policies
kubectl get pods -n kube-system | grep -E "calico|cilium|weave"
```

### Secret Issues
```bash
# Check ExternalSecret sync
kubectl describe externalsecret <name> -n <namespace>

# Check SecretStore connectivity
kubectl describe secretstore <name> -n <namespace>

# Check Sealed Secrets controller
kubectl logs -l app.kubernetes.io/name=sealed-secrets -n sealed-secrets
```
