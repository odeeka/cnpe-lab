# Lab 4: Secrets Management

## Overview

This lab covers secure secrets management in Kubernetes, including the limitations of native secrets, integration with HashiCorp Vault, External Secrets Operator, Sealed Secrets for GitOps, and secret rotation strategies.

## Objectives

- Understand Kubernetes Secrets limitations
- Deploy and configure HashiCorp Vault
- Implement External Secrets Operator
- Use Sealed Secrets for GitOps workflows
- Configure secret rotation

## Prerequisites

- Completed Lab 3: Network Security
- Running Kubernetes cluster (1.28+)
- Helm 3.x installed
- kubectl configured with cluster access

---

## Kubernetes Secrets Overview

```
┌─────────────────────────────────────────────────────────────────┐
│              KUBERNETES SECRETS - LIMITATIONS                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Native Kubernetes Secrets:                                     │
│  ──────────────────────────                                     │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  apiVersion: v1                                          │    │
│  │  kind: Secret                                            │    │
│  │  metadata:                                               │    │
│  │    name: my-secret                                       │    │
│  │  type: Opaque                                            │    │
│  │  data:                                                   │    │
│  │    password: cGFzc3dvcmQxMjM=  ◄── Base64 encoded       │    │
│  │                                    (NOT encrypted!)      │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Problems:                                                       │
│  ─────────                                                       │
│  ✗ Base64 is encoding, not encryption                           │
│  ✗ Stored in etcd (potentially unencrypted)                     │
│  ✗ Visible to anyone with RBAC access                           │
│  ✗ Cannot store in Git (security risk)                          │
│  ✗ No audit trail of access                                     │
│  ✗ No automatic rotation                                        │
│  ✗ No central management                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Secret Management Solutions

| Solution | GitOps Safe | External Store | Rotation | Complexity |
|----------|-------------|----------------|----------|------------|
| Native Secrets | ❌ | ❌ | ❌ | Low |
| Sealed Secrets | ✅ | ❌ | Manual | Low |
| External Secrets | ✅ | ✅ | ✅ | Medium |
| Vault + ESO | ✅ | ✅ | ✅ | High |
| Vault + CSI | ❌ | ✅ | ✅ | Medium |

---

## Part 1: Kubernetes Secrets Basics

### Step 1.1: Create and Examine Secrets

```bash
# Create namespace
kubectl create namespace secrets-lab

# Create a secret from literal values
kubectl create secret generic db-credentials \
  -n secrets-lab \
  --from-literal=username=admin \
  --from-literal=password=supersecret123

# View the secret (base64 encoded)
kubectl get secret db-credentials -n secrets-lab -o yaml

# Decode the secret (anyone with access can do this!)
kubectl get secret db-credentials -n secrets-lab \
  -o jsonpath='{.data.password}' | base64 -d
echo ""
```

### Step 1.2: Secret Types

```bash
# Different secret types
echo "=== Kubernetes Secret Types ==="

# Opaque (generic) - most common
kubectl create secret generic app-secrets \
  -n secrets-lab \
  --from-literal=api-key=abc123

# Docker registry credentials
kubectl create secret docker-registry regcred \
  -n secrets-lab \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username=myuser \
  --docker-password=mypass \
  --docker-email=user@example.com

# TLS secret
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/tls.key -out /tmp/tls.crt \
  -subj "/CN=example.com"

kubectl create secret tls tls-secret \
  -n secrets-lab \
  --cert=/tmp/tls.crt \
  --key=/tmp/tls.key

# List all secrets
kubectl get secrets -n secrets-lab
```

### Step 1.3: Using Secrets in Pods

```bash
# Secret as environment variables
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-env-pod
  namespace: secrets-lab
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "echo Username: \$DB_USER && echo Password: \$DB_PASS && sleep 3600"]
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
EOF

kubectl wait --for=condition=Ready pod/secret-env-pod -n secrets-lab --timeout=60s
kubectl logs secret-env-pod -n secrets-lab

# Secret as volume mount
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: secret-volume-pod
  namespace: secrets-lab
spec:
  containers:
  - name: app
    image: busybox:latest
    command: ["sh", "-c", "cat /etc/secrets/username && echo '' && cat /etc/secrets/password && sleep 3600"]
    volumeMounts:
    - name: secret-volume
      mountPath: /etc/secrets
      readOnly: true
  volumes:
  - name: secret-volume
    secret:
      secretName: db-credentials
EOF

kubectl wait --for=condition=Ready pod/secret-volume-pod -n secrets-lab --timeout=60s
kubectl logs secret-volume-pod -n secrets-lab
```

### Step 1.4: Enable Encryption at Rest

```bash
# Check if encryption at rest is enabled
# This would be in API server configuration

cat <<EOF
# Example encryption configuration (kube-apiserver)
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: <base64-encoded-32-byte-key>
      - identity: {}  # Fallback to unencrypted
EOF

echo ""
echo "To enable, add to kube-apiserver:"
echo "  --encryption-provider-config=/etc/kubernetes/encryption-config.yaml"
```

---

## Part 2: HashiCorp Vault

### Vault Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    HASHICORP VAULT                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                     VAULT SERVER                         │    │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐    │    │
│  │  │   KV    │  │   PKI   │  │Database │  │  AWS    │    │    │
│  │  │ Engine  │  │ Engine  │  │ Engine  │  │ Engine  │    │    │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘    │    │
│  │                                                          │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │              Authentication Methods                │  │    │
│  │  │  • Kubernetes    • Token     • OIDC               │  │    │
│  │  │  • AppRole       • LDAP      • GitHub             │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  │                                                          │    │
│  │  ┌───────────────────────────────────────────────────┐  │    │
│  │  │                   Policies                         │  │    │
│  │  │  path "secret/data/myapp/*" { capabilities = [] } │  │    │
│  │  └───────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    CLIENTS                               │    │
│  │  • External Secrets Operator                             │    │
│  │  • Vault Agent Injector                                  │    │
│  │  • Vault CSI Provider                                    │    │
│  │  • Direct API                                            │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2.1: Install Vault

```bash
# Add HashiCorp Helm repo
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# Create namespace
kubectl create namespace vault

# Install Vault in dev mode (for lab purposes only!)
helm install vault hashicorp/vault \
  --namespace vault \
  --set "server.dev.enabled=true" \
  --set "server.dev.devRootToken=root" \
  --set "injector.enabled=true" \
  --wait

# Wait for Vault to be ready
kubectl wait --for=condition=Ready pod/vault-0 -n vault --timeout=120s

# Check status
kubectl get pods -n vault
```

### Step 2.2: Configure Vault

```bash
# Set up port-forward (in background)
kubectl port-forward svc/vault -n vault 8200:8200 &
VAULT_PF_PID=$!
sleep 3

# Set Vault address and token
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Verify connection
vault status

# Enable KV secrets engine v2
vault secrets enable -path=secret kv-v2

# Store some secrets
vault kv put secret/myapp/config \
  username="dbadmin" \
  password="supersecret" \
  api-key="abc123xyz"

# Read secrets
vault kv get secret/myapp/config

# Store database credentials
vault kv put secret/myapp/database \
  host="postgres.default.svc" \
  port="5432" \
  username="appuser" \
  password="dbpassword123"
```

### Step 2.3: Configure Kubernetes Authentication

```bash
# Enable Kubernetes auth method
vault auth enable kubernetes

# Configure Kubernetes auth
vault write auth/kubernetes/config \
  kubernetes_host="https://kubernetes.default.svc:443"

# Create policy for application
vault policy write myapp-policy - <<EOF
path "secret/data/myapp/*" {
  capabilities = ["read"]
}
EOF

# Create role for application
vault write auth/kubernetes/role/myapp \
  bound_service_account_names=myapp-sa \
  bound_service_account_namespaces=secrets-lab \
  policies=myapp-policy \
  ttl=1h

# Verify
vault read auth/kubernetes/role/myapp
```

### Step 2.4: Use Vault Agent Injector

```bash
# Create service account for app
kubectl create serviceaccount myapp-sa -n secrets-lab

# Deploy app with Vault Agent injection
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vault-injected-app
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vault-injected-app
  template:
    metadata:
      labels:
        app: vault-injected-app
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "myapp"
        vault.hashicorp.com/agent-inject-secret-config: "secret/data/myapp/config"
        vault.hashicorp.com/agent-inject-template-config: |
          {{- with secret "secret/data/myapp/config" -}}
          export DB_USER="{{ .Data.data.username }}"
          export DB_PASS="{{ .Data.data.password }}"
          export API_KEY="{{ .Data.data.api_key }}"
          {{- end }}
    spec:
      serviceAccountName: myapp-sa
      containers:
      - name: app
        image: busybox:latest
        command: ["sh", "-c", "source /vault/secrets/config && env | grep -E 'DB_|API_' && sleep 3600"]
EOF

# Wait and check logs
kubectl wait --for=condition=Ready pod -l app=vault-injected-app -n secrets-lab --timeout=120s
kubectl logs -l app=vault-injected-app -n secrets-lab -c app

# Check injected secrets file
kubectl exec -n secrets-lab -l app=vault-injected-app -c app -- cat /vault/secrets/config
```

### Step 2.5: Cleanup Vault Port-Forward

```bash
# Kill port-forward
kill $VAULT_PF_PID 2>/dev/null || true
```

---

## Part 3: External Secrets Operator

### ESO Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                EXTERNAL SECRETS OPERATOR                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────┐                    ┌──────────────────────┐   │
│  │ SecretStore  │                    │   External Provider  │   │
│  │ or           │───────────────────▶│   • Vault            │   │
│  │ClusterSecret │                    │   • AWS SM           │   │
│  │   Store      │◀───────────────────│   • GCP SM           │   │
│  └──────────────┘    Connection      │   • Azure KV         │   │
│         │            & Auth          │   • 1Password        │   │
│         │                            └──────────────────────┘   │
│         ▼                                                        │
│  ┌──────────────┐                                               │
│  │ External     │                                               │
│  │ Secret       │────── References ──────┐                      │
│  │              │                        │                      │
│  └──────────────┘                        ▼                      │
│         │                         ┌──────────────┐              │
│         │                         │   Fetch      │              │
│         │                         │   Secret     │              │
│         ▼                         │   Data       │              │
│  ┌──────────────┐                 └──────────────┘              │
│  │  Kubernetes  │◀───────────────────────┘                      │
│  │   Secret     │     Create/Update                             │
│  │  (managed)   │                                               │
│  └──────────────┘                                               │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3.1: Install External Secrets Operator

```bash
# Add ESO Helm repo
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

# Install ESO
helm install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace \
  --wait

# Verify installation
kubectl get pods -n external-secrets
kubectl get crds | grep external-secrets
```

### Step 3.2: Configure SecretStore for Vault

```bash
# Ensure Vault port-forward is running
kubectl port-forward svc/vault -n vault 8200:8200 &
VAULT_PF_PID=$!
sleep 3

# Create a Vault token for ESO
export VAULT_ADDR='http://127.0.0.1:8200'
export VAULT_TOKEN='root'

# Create token policy for ESO
vault policy write eso-policy - <<EOF
path "secret/data/*" {
  capabilities = ["read"]
}
EOF

# Create token for ESO
ESO_TOKEN=$(vault token create -policy=eso-policy -format=json | jq -r '.auth.client_token')

# Store token in Kubernetes secret
kubectl create secret generic vault-token \
  -n secrets-lab \
  --from-literal=token=$ESO_TOKEN

# Create SecretStore
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: vault-backend
  namespace: secrets-lab
spec:
  provider:
    vault:
      server: "http://vault.vault.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
EOF

# Verify SecretStore
kubectl get secretstore -n secrets-lab
kubectl describe secretstore vault-backend -n secrets-lab
```

### Step 3.3: Create ExternalSecret

```bash
# Create ExternalSecret that syncs from Vault
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: myapp-external-secret
  namespace: secrets-lab
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: vault-backend
  target:
    name: myapp-synced-secret
    creationPolicy: Owner
  data:
  - secretKey: username
    remoteRef:
      key: myapp/config
      property: username
  - secretKey: password
    remoteRef:
      key: myapp/config
      property: password
  - secretKey: api-key
    remoteRef:
      key: myapp/config
      property: api-key
EOF

# Wait for sync
sleep 5

# Check ExternalSecret status
kubectl get externalsecret -n secrets-lab
kubectl describe externalsecret myapp-external-secret -n secrets-lab

# Verify synced secret
kubectl get secret myapp-synced-secret -n secrets-lab
kubectl get secret myapp-synced-secret -n secrets-lab -o jsonpath='{.data.username}' | base64 -d && echo ""
```

### Step 3.4: Use ClusterSecretStore

```bash
# ClusterSecretStore for cluster-wide access
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: vault-cluster-store
spec:
  provider:
    vault:
      server: "http://vault.vault.svc:8200"
      path: "secret"
      version: "v2"
      auth:
        tokenSecretRef:
          name: vault-token
          key: token
          namespace: secrets-lab
EOF

# Use ClusterSecretStore from any namespace
kubectl create namespace app-team-a

kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: team-a-secret
  namespace: app-team-a
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: ClusterSecretStore
    name: vault-cluster-store
  target:
    name: team-a-credentials
  data:
  - secretKey: db-password
    remoteRef:
      key: myapp/database
      property: password
EOF

# Verify
kubectl get externalsecret -n app-team-a
kubectl get secret team-a-credentials -n app-team-a
```

### Step 3.5: ExternalSecret with Templates

```bash
# Template secrets for specific formats
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-connection-string
  namespace: secrets-lab
spec:
  refreshInterval: 1h
  secretStoreRef:
    kind: SecretStore
    name: vault-backend
  target:
    name: db-connection
    template:
      type: Opaque
      data:
        connection-string: "postgresql://{{ .username }}:{{ .password }}@{{ .host }}:{{ .port }}/mydb"
  data:
  - secretKey: username
    remoteRef:
      key: myapp/database
      property: username
  - secretKey: password
    remoteRef:
      key: myapp/database
      property: password
  - secretKey: host
    remoteRef:
      key: myapp/database
      property: host
  - secretKey: port
    remoteRef:
      key: myapp/database
      property: port
EOF

# Check templated secret
sleep 5
kubectl get secret db-connection -n secrets-lab -o jsonpath='{.data.connection-string}' | base64 -d && echo ""

# Cleanup port-forward
kill $VAULT_PF_PID 2>/dev/null || true
```

---

## Part 4: Sealed Secrets

### Sealed Secrets Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SEALED SECRETS                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Developer Workstation:                                         │
│  ──────────────────────                                         │
│                                                                  │
│  ┌─────────────────┐      kubeseal       ┌──────────────────┐  │
│  │  Secret YAML    │─────────────────────▶│  SealedSecret   │  │
│  │  (plaintext)    │     (encrypt with    │  YAML           │  │
│  │                 │      public key)     │  (safe for Git) │  │
│  └─────────────────┘                      └────────┬─────────┘  │
│                                                     │            │
│                                                     │ Git Push   │
│                                                     ▼            │
│  Kubernetes Cluster:                        ┌──────────────┐    │
│  ───────────────────                        │ Git Repo     │    │
│                                             └──────┬───────┘    │
│  ┌──────────────────────────────────────┐         │             │
│  │  Sealed Secrets Controller            │◀────────┘ GitOps     │
│  │  (has private key)                    │                      │
│  │                                        │                      │
│  │  Decrypts SealedSecret ──────────────▶│  Creates Kubernetes │
│  │                                        │  Secret             │
│  └──────────────────────────────────────┘                      │
│                                                                  │
│  Key Points:                                                     │
│  • Private key only exists in cluster                           │
│  • SealedSecret is cluster-specific                             │
│  • Safe to store encrypted secrets in Git                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 4.1: Install Sealed Secrets Controller

```bash
# Install Sealed Secrets controller
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm repo update

kubectl create namespace sealed-secrets

helm install sealed-secrets sealed-secrets/sealed-secrets \
  --namespace sealed-secrets \
  --wait

# Verify installation
kubectl get pods -n sealed-secrets
kubectl get svc -n sealed-secrets
```

### Step 4.2: Install kubeseal CLI

```bash
# Install kubeseal (Linux)
KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | jq -r '.tag_name' | cut -c 2-)
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
tar -xzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
rm kubeseal kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz

# Verify
kubeseal --version
```

### Step 4.3: Create Sealed Secret

```bash
# Create a regular secret (don't apply it!)
cat > /tmp/my-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: secrets-lab
type: Opaque
stringData:
  username: admin
  password: supersecretpassword
  api-key: abc123xyz789
EOF

# Seal the secret
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml \
  < /tmp/my-secret.yaml \
  > /tmp/my-sealed-secret.yaml

# View the sealed secret (safe for Git!)
cat /tmp/my-sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f /tmp/my-sealed-secret.yaml

# Verify the controller created the regular secret
kubectl get sealedsecret -n secrets-lab
kubectl get secret mysecret -n secrets-lab

# Verify the secret contents
kubectl get secret mysecret -n secrets-lab -o jsonpath='{.data.password}' | base64 -d && echo ""
```

### Step 4.4: Sealed Secret Scopes

```bash
# Strict scope (default) - tied to name and namespace
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml \
  --scope strict \
  < /tmp/my-secret.yaml \
  > /tmp/sealed-strict.yaml

# Namespace-wide scope - can be renamed within namespace
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml \
  --scope namespace-wide \
  < /tmp/my-secret.yaml \
  > /tmp/sealed-namespace.yaml

# Cluster-wide scope - can be used anywhere
kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml \
  --scope cluster-wide \
  < /tmp/my-secret.yaml \
  > /tmp/sealed-cluster.yaml

echo "Scope comparison:"
echo "- strict: Name + Namespace bound (most secure)"
echo "- namespace-wide: Namespace bound only"
echo "- cluster-wide: No restrictions (least secure)"
```

### Step 4.5: Update Sealed Secret

```bash
# To update a sealed secret, recreate and reapply
cat > /tmp/updated-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: mysecret
  namespace: secrets-lab
type: Opaque
stringData:
  username: admin
  password: newpassword123
  api-key: newkey456
EOF

kubeseal --controller-name=sealed-secrets \
  --controller-namespace=sealed-secrets \
  --format yaml \
  < /tmp/updated-secret.yaml \
  > /tmp/updated-sealed-secret.yaml

kubectl apply -f /tmp/updated-sealed-secret.yaml

# Verify update
kubectl get secret mysecret -n secrets-lab -o jsonpath='{.data.password}' | base64 -d && echo ""
```

### Step 4.6: Backup and Restore Keys

```bash
# Backup the sealing key (important for disaster recovery!)
kubectl get secret -n sealed-secrets -l sealedsecrets.bitnami.com/sealed-secrets-key -o yaml > /tmp/sealed-secrets-key-backup.yaml

echo "Key backup saved to /tmp/sealed-secrets-key-backup.yaml"
echo "Store this securely - it's needed to decrypt secrets!"

# To restore (if reinstalling controller):
# kubectl apply -f /tmp/sealed-secrets-key-backup.yaml
# Then reinstall the controller
```

---

## Part 5: Secret Rotation

### Rotation Strategies

```
┌─────────────────────────────────────────────────────────────────┐
│                   SECRET ROTATION STRATEGIES                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Strategy 1: External Secrets Operator Auto-Refresh             │
│  ─────────────────────────────────────────────────              │
│  • Set refreshInterval in ExternalSecret                        │
│  • ESO polls and updates Kubernetes Secret                      │
│  • App must handle secret changes                               │
│                                                                  │
│  Strategy 2: Vault Dynamic Secrets                              │
│  ─────────────────────────────────                              │
│  • Vault generates short-lived credentials                      │
│  • Automatic expiration and renewal                             │
│  • Database, AWS, etc. backends                                 │
│                                                                  │
│  Strategy 3: Rolling Deployment                                 │
│  ─────────────────────────────                                  │
│  • Update secret in external store                              │
│  • Trigger deployment rollout                                   │
│  • New pods get new secret                                      │
│                                                                  │
│  Strategy 4: Sidecar Rotation                                   │
│  ─────────────────────────                                      │
│  • Vault Agent as sidecar                                       │
│  • Continuously updates secret files                            │
│  • App watches for file changes                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 5.1: ESO Auto-Refresh

```bash
# ExternalSecret with short refresh interval
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: rotating-secret
  namespace: secrets-lab
spec:
  refreshInterval: 5m  # Check every 5 minutes
  secretStoreRef:
    kind: SecretStore
    name: vault-backend
  target:
    name: app-rotating-secret
  data:
  - secretKey: api-key
    remoteRef:
      key: myapp/config
      property: api-key
EOF

# Monitor refreshes
kubectl describe externalsecret rotating-secret -n secrets-lab | grep -A5 "Status:"
```

### Step 5.2: Trigger Pod Restart on Secret Change

```bash
# Use Reloader to restart pods when secrets change
# Install Reloader
helm repo add stakater https://stakater.github.io/stakater-charts
helm repo update

helm install reloader stakater/reloader \
  --namespace secrets-lab \
  --set reloader.watchGlobally=false

# Deploy with auto-reload annotation
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: auto-reload-app
  namespace: secrets-lab
  annotations:
    reloader.stakater.com/auto: "true"  # Reload on any mounted secret change
spec:
  replicas: 1
  selector:
    matchLabels:
      app: auto-reload-app
  template:
    metadata:
      labels:
        app: auto-reload-app
    spec:
      containers:
      - name: app
        image: busybox:latest
        command: ["sh", "-c", "cat /etc/secrets/api-key && sleep 3600"]
        volumeMounts:
        - name: secrets
          mountPath: /etc/secrets
      volumes:
      - name: secrets
        secret:
          secretName: app-rotating-secret
EOF

kubectl wait --for=condition=Ready pod -l app=auto-reload-app -n secrets-lab --timeout=60s
```

### Step 5.3: Secret Rotation with Checksum

```bash
# Manual rotation using checksum annotation
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: checksum-app
  namespace: secrets-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: checksum-app
  template:
    metadata:
      labels:
        app: checksum-app
      annotations:
        # This triggers rollout when secret changes
        checksum/secret: "initial-value"
    spec:
      containers:
      - name: app
        image: busybox:latest
        command: ["sh", "-c", "sleep 3600"]
        envFrom:
        - secretRef:
            name: myapp-synced-secret
EOF

# To rotate, update the checksum annotation
# kubectl patch deployment checksum-app -n secrets-lab \
#   -p '{"spec":{"template":{"metadata":{"annotations":{"checksum/secret":"new-value"}}}}}'
```

---

## Part 6: Best Practices

### Secret Management Checklist

```bash
cat <<EOF
=== Secret Management Best Practices ===

1. Storage
   □ Enable encryption at rest for etcd
   □ Use external secret store (Vault, AWS SM, etc.)
   □ Never store secrets in Git (use Sealed Secrets)

2. Access Control
   □ Limit RBAC access to secrets
   □ Use separate service accounts per app
   □ Audit secret access

3. Rotation
   □ Implement automatic rotation
   □ Use short-lived credentials where possible
   □ Plan for emergency rotation

4. Operations
   □ Backup encryption keys
   □ Monitor secret sync status
   □ Alert on secret access failures

5. Development
   □ Use different secrets per environment
   □ Never log secrets
   □ Mask secrets in CI/CD logs
EOF
```

### Step 6.1: RBAC for Secrets

```bash
# Restrict secret access
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: secret-reader
  namespace: secrets-lab
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["app-rotating-secret", "myapp-synced-secret"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: app-secret-reader
  namespace: secrets-lab
subjects:
- kind: ServiceAccount
  name: myapp-sa
  namespace: secrets-lab
roleRef:
  kind: Role
  name: secret-reader
  apiGroup: rbac.authorization.k8s.io
EOF
```

### Step 6.2: Audit Secret Access

```bash
# Audit policy for secrets (add to API server)
cat <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
  resources:
  - group: ""
    resources: ["secrets"]
  omitStages:
  - RequestReceived
EOF
```

---

## Verification

### Check All Secret Sources

```bash
echo "=== Secret Management Status ==="

echo ""
echo "Native Secrets:"
kubectl get secrets -n secrets-lab

echo ""
echo "External Secrets:"
kubectl get externalsecrets -n secrets-lab

echo ""
echo "Sealed Secrets:"
kubectl get sealedsecrets -n secrets-lab

echo ""
echo "SecretStores:"
kubectl get secretstores -n secrets-lab
kubectl get clustersecretstores
```

---

## Common Issues and Solutions

### Issue 1: ExternalSecret Not Syncing

**Symptoms:** ExternalSecret status shows error

**Solutions:**
1. Check SecretStore connectivity
2. Verify authentication credentials
3. Check secret path exists in provider

```bash
kubectl describe externalsecret <name> -n <namespace>
kubectl describe secretstore <name> -n <namespace>
```

### Issue 2: Sealed Secret Decryption Failed

**Symptoms:** SealedSecret not creating Secret

**Solutions:**
1. Check if correct key is used
2. Verify scope (strict/namespace/cluster)
3. Check controller logs

```bash
kubectl logs -l app.kubernetes.io/name=sealed-secrets -n sealed-secrets
```

### Issue 3: Vault Authentication Failed

**Symptoms:** Vault agent can't authenticate

**Solutions:**
1. Check service account exists
2. Verify Vault role configuration
3. Check Kubernetes auth mount

```bash
vault read auth/kubernetes/role/<role-name>
```

---

## Cleanup

```bash
# Remove lab resources
kubectl delete namespace secrets-lab
kubectl delete namespace app-team-a

# Uninstall components (optional)
helm uninstall sealed-secrets -n sealed-secrets
helm uninstall external-secrets -n external-secrets
helm uninstall vault -n vault
helm uninstall reloader -n secrets-lab

kubectl delete namespace sealed-secrets external-secrets vault

rm -f /tmp/*.yaml /tmp/tls.* /tmp/kubeseal*
```

---

## Key Takeaways

1. **Native Secrets** - Base64 encoded, not encrypted; enable encryption at rest
2. **External Secrets** - Sync secrets from external providers automatically
3. **Sealed Secrets** - Encrypt secrets for safe Git storage
4. **Vault** - Comprehensive secret management with dynamic secrets
5. **Rotation** - Implement automatic rotation with refresh intervals

---

## Next Steps

Continue to [Lab 5: Image and Supply Chain Security](../lab-05-supply-chain/README.md) to learn about securing your software supply chain.

---

## Additional Resources

- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [External Secrets Operator](https://external-secrets.io/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [HashiCorp Vault](https://www.vaultproject.io/docs)
- [Encryption at Rest](https://kubernetes.io/docs/tasks/administer-cluster/encrypt-data/)
