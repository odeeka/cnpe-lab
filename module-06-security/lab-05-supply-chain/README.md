# Lab 5: Image and Supply Chain Security

## Overview

This lab covers securing the software supply chain from source code to deployment. You'll learn image vulnerability scanning, image signing and verification, admission control with policy engines, and SBOM (Software Bill of Materials) generation.

## Objectives

- Scan container images for vulnerabilities
- Sign and verify container images
- Implement admission control policies
- Generate and analyze SBOMs
- Secure container registries

## Prerequisites

- Completed Lab 4: Secrets Management
- Running Kubernetes cluster (1.28+)
- Docker or container runtime access
- kubectl configured with cluster access

---

## Supply Chain Security Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                 SOFTWARE SUPPLY CHAIN                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  SOURCE          BUILD           REGISTRY        DEPLOY         │
│  ──────          ─────           ────────        ──────         │
│                                                                  │
│  ┌─────┐       ┌─────────┐      ┌─────────┐    ┌─────────┐     │
│  │Code │──────▶│  Build  │─────▶│ Registry│───▶│Kubernetes│    │
│  │Repo │       │ Pipeline│      │         │    │ Cluster  │    │
│  └─────┘       └─────────┘      └─────────┘    └─────────┘     │
│     │               │                │              │            │
│     ▼               ▼                ▼              ▼            │
│  ┌─────┐       ┌─────────┐      ┌─────────┐    ┌─────────┐     │
│  │Code │       │ Image   │      │ Image   │    │Admission│     │
│  │Scan │       │ Scan    │      │ Sign    │    │ Control │     │
│  │     │       │ (Trivy) │      │(Cosign) │    │(Kyverno)│     │
│  └─────┘       └─────────┘      └─────────┘    └─────────┘     │
│     │               │                │              │            │
│     ▼               ▼                ▼              ▼            │
│  ┌─────┐       ┌─────────┐      ┌─────────┐    ┌─────────┐     │
│  │SBOM │       │ SBOM    │      │Signature│    │ Policy  │     │
│  │     │       │Generate │      │ Store   │    │Enforce  │     │
│  └─────┘       └─────────┘      └─────────┘    └─────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Purpose | Tools |
|-----------|---------|-------|
| Image Scanning | Find vulnerabilities | Trivy, Grype, Clair |
| Image Signing | Verify image integrity | Cosign, Notary |
| SBOM | Track dependencies | Syft, Trivy |
| Admission Control | Enforce policies | Kyverno, OPA Gatekeeper |
| Registry Security | Secure image storage | Harbor, ECR, GCR |

---

## Part 1: Image Vulnerability Scanning with Trivy

### Trivy Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                       TRIVY SCANNER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Scan Types:                                                     │
│  ───────────                                                     │
│  • Container Images     - Vulnerabilities in image layers       │
│  • Filesystem           - Vulnerabilities in files/deps         │
│  • Git Repositories     - Secrets, misconfigs in code           │
│  • Kubernetes           - Cluster misconfigurations             │
│  • IaC (Terraform, etc) - Infrastructure misconfigurations      │
│                                                                  │
│  Vulnerability Sources:                                         │
│  ─────────────────────                                          │
│  • NVD (National Vulnerability Database)                        │
│  • OS-specific databases (Alpine, Debian, RHEL, etc.)          │
│  • Language-specific (npm, pip, go, etc.)                       │
│                                                                  │
│  Severity Levels:                                               │
│  ────────────────                                               │
│  CRITICAL > HIGH > MEDIUM > LOW > UNKNOWN                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 1.1: Install Trivy

```bash
# Install Trivy (Linux)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Or using package manager
# Ubuntu/Debian
# sudo apt-get install wget apt-transport-https gnupg lsb-release
# wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
# echo deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list.d/trivy.list
# sudo apt-get update && sudo apt-get install trivy

# Verify installation
trivy --version
```

### Step 1.2: Scan Container Images

```bash
# Create namespace for lab
kubectl create namespace supply-chain-lab

# Basic image scan
trivy image nginx:latest

# Scan with severity filter
trivy image --severity HIGH,CRITICAL nginx:latest

# Scan with exit code (for CI/CD)
trivy image --exit-code 1 --severity CRITICAL nginx:latest

# JSON output for processing
trivy image --format json --output nginx-scan.json nginx:latest

# Table format with specific columns
trivy image --format table nginx:latest
```

### Step 1.3: Scan Specific Image Layers

```bash
# Show vulnerabilities by layer
trivy image --scanners vuln nginx:latest

# Include secret scanning
trivy image --scanners vuln,secret nginx:latest

# Scan for misconfigurations
trivy image --scanners vuln,misconfig nginx:latest

# Comprehensive scan
trivy image --scanners vuln,secret,misconfig nginx:latest
```

### Step 1.4: Filter and Ignore Vulnerabilities

```bash
# Create ignore file for false positives
cat > .trivyignore <<EOF
# Ignore specific CVEs
CVE-2023-12345
CVE-2023-67890

# Ignore by package
pkg:deb/debian/libssl@1.1.1
EOF

# Scan with ignore file
trivy image --ignorefile .trivyignore nginx:latest

# Ignore unfixed vulnerabilities
trivy image --ignore-unfixed nginx:latest

# Only show fixable vulnerabilities
trivy image --ignore-unfixed --severity HIGH,CRITICAL nginx:latest
```

### Step 1.5: Scan in CI/CD Pipeline

```bash
# Create script for CI/CD
cat > /tmp/scan-image.sh <<'EOF'
#!/bin/bash

IMAGE=$1
SEVERITY=${2:-"HIGH,CRITICAL"}
EXIT_CODE=${3:-1}

echo "Scanning image: $IMAGE"
echo "Severity threshold: $SEVERITY"

trivy image \
  --severity $SEVERITY \
  --exit-code $EXIT_CODE \
  --ignore-unfixed \
  --format table \
  $IMAGE

RESULT=$?

if [ $RESULT -eq 0 ]; then
  echo "✅ Image passed security scan"
else
  echo "❌ Image failed security scan"
fi

exit $RESULT
EOF

chmod +x /tmp/scan-image.sh

# Test the script
/tmp/scan-image.sh nginx:alpine HIGH,CRITICAL
```

### Step 1.6: Scan Kubernetes Cluster

```bash
# Scan entire cluster for misconfigurations
trivy k8s --report summary cluster

# Scan specific namespace
trivy k8s --report summary --namespace default

# Detailed report
trivy k8s --report all --namespace kube-system

# Generate HTML report
trivy k8s --report all --format html --output cluster-report.html cluster
```

---

## Part 2: Image Signing with Cosign

### Cosign Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        COSIGN                                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Signing Methods:                                               │
│  ────────────────                                               │
│  • Key-based      - Traditional public/private key pairs        │
│  • Keyless        - OIDC-based signing (Fulcio + Rekor)        │
│  • Hardware keys  - YubiKey, HSM support                        │
│                                                                  │
│  Signature Storage:                                             │
│  ─────────────────                                              │
│  • OCI Registry   - Stored alongside image                      │
│  • Transparency   - Logged in Rekor                             │
│    Log                                                          │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Signing Flow                          │   │
│  │                                                          │   │
│  │  [Build] ──▶ [Sign] ──▶ [Push Sig] ──▶ [Verify]         │   │
│  │              │          │              │                  │   │
│  │              ▼          ▼              ▼                  │   │
│  │          Private    Registry      Public                 │   │
│  │            Key                      Key                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 2.1: Install Cosign

```bash
# Install Cosign
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign
sudo chmod +x /usr/local/bin/cosign

# Verify installation
cosign version
```

### Step 2.2: Generate Key Pair

```bash
# Generate key pair (will prompt for password)
cosign generate-key-pair

# This creates:
# - cosign.key (private key - keep secret!)
# - cosign.pub (public key - distribute for verification)

# View public key
cat cosign.pub
```

### Step 2.3: Sign Container Image

```bash
# For this demo, we'll use a local registry
# In production, use your actual registry

# Start local registry (if needed)
docker run -d -p 5000:5000 --name registry registry:2

# Tag and push an image
docker pull nginx:alpine
docker tag nginx:alpine localhost:5000/nginx:signed
docker push localhost:5000/nginx:signed

# Sign the image
cosign sign --key cosign.key localhost:5000/nginx:signed

# For keyless signing (uses OIDC)
# COSIGN_EXPERIMENTAL=1 cosign sign localhost:5000/nginx:signed
```

### Step 2.4: Verify Image Signature

```bash
# Verify with public key
cosign verify --key cosign.pub localhost:5000/nginx:signed

# Verify and show signature details
cosign verify --key cosign.pub localhost:5000/nginx:signed | jq .

# Verify with output format
cosign verify --key cosign.pub --output text localhost:5000/nginx:signed
```

### Step 2.5: Add Attestations

```bash
# Create a simple attestation
cat > attestation.json <<EOF
{
  "builder": "github-actions",
  "buildType": "https://example.com/build/v1",
  "invocation": {
    "configSource": {
      "uri": "git+https://github.com/example/repo"
    }
  },
  "metadata": {
    "buildInvocationId": "1234567890",
    "buildStartedOn": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF

# Attach attestation to image
cosign attest --key cosign.key --predicate attestation.json --type custom localhost:5000/nginx:signed

# Verify attestation
cosign verify-attestation --key cosign.pub --type custom localhost:5000/nginx:signed
```

### Step 2.6: Sign with Annotations

```bash
# Sign with custom annotations
cosign sign --key cosign.key \
  -a "git.sha=$(git rev-parse HEAD 2>/dev/null || echo 'none')" \
  -a "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  -a "build.by=ci-pipeline" \
  localhost:5000/nginx:signed

# Verify and view annotations
cosign verify --key cosign.pub localhost:5000/nginx:signed | jq '.[].optional'
```

---

## Part 3: Admission Control with Kyverno

### Kyverno Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        KYVERNO                                  │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Policy Types:                                                   │
│  ─────────────                                                   │
│  • Validate   - Check resources against rules                   │
│  • Mutate     - Modify resources automatically                  │
│  • Generate   - Create additional resources                     │
│  • VerifyImages - Validate image signatures                     │
│                                                                  │
│  Policy Scope:                                                   │
│  ─────────────                                                   │
│  • ClusterPolicy    - Applies cluster-wide                      │
│  • Policy           - Namespace-scoped                          │
│                                                                  │
│  Enforcement Modes:                                             │
│  ─────────────────                                              │
│  • Enforce  - Block non-compliant resources                     │
│  • Audit    - Log but allow non-compliant resources             │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │                 Request Flow                            │    │
│  │                                                         │    │
│  │  [API Request] ──▶ [Kyverno] ──▶ [Validate/Mutate]     │    │
│  │                        │              │                 │    │
│  │                        ▼              ▼                 │    │
│  │                    [Policy]      [Allowed/Denied]       │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 3.1: Install Kyverno

```bash
# Install Kyverno with Helm
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --set replicaCount=1 \
  --wait

# Verify installation
kubectl get pods -n kyverno
kubectl get crds | grep kyverno
```

### Step 3.2: Require Image from Trusted Registry

```bash
# Policy to only allow images from trusted registries
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-trusted-registry
  annotations:
    policies.kyverno.io/title: Require Trusted Registry
    policies.kyverno.io/description: >-
      Only allow images from approved registries.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: validate-registry
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must be from trusted registries (docker.io, gcr.io, or localhost:5000)"
      pattern:
        spec:
          containers:
          - image: "docker.io/* | gcr.io/* | localhost:5000/* | nginx:* | busybox:*"
EOF

# Test - should succeed
kubectl run trusted --image=nginx:alpine -n supply-chain-lab --dry-run=server

# Test - should fail (if registry not in list)
kubectl run untrusted --image=untrusted.io/malicious:latest -n supply-chain-lab --dry-run=server 2>&1 | head -5
```

### Step 3.3: Require Image Digest

```bash
# Policy to require image digest (no mutable tags)
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-image-digest
  annotations:
    policies.kyverno.io/title: Require Image Digest
    policies.kyverno.io/description: >-
      Require images to use digest instead of tags.
spec:
  validationFailureAction: Audit  # Start with Audit
  background: true
  rules:
  - name: require-digest
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "Images must use digest (@sha256:...) not tags"
      pattern:
        spec:
          containers:
          - image: "*@sha256:*"
EOF

# Check policy reports
kubectl get policyreport -A
```

### Step 3.4: Disallow Latest Tag

```bash
# Policy to disallow :latest tag
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-latest-tag
  annotations:
    policies.kyverno.io/title: Disallow Latest Tag
    policies.kyverno.io/description: >-
      Disallow the use of the :latest tag.
spec:
  validationFailureAction: Enforce
  background: true
  rules:
  - name: disallow-latest
    match:
      any:
      - resources:
          kinds:
          - Pod
    validate:
      message: "The :latest tag is not allowed. Use a specific version tag."
      pattern:
        spec:
          containers:
          - image: "!*:latest"
EOF

# Test - should fail
kubectl run latest --image=nginx:latest -n supply-chain-lab --dry-run=server 2>&1 | head -5

# Test - should succeed
kubectl run versioned --image=nginx:1.25-alpine -n supply-chain-lab --dry-run=server
```

### Step 3.5: Verify Image Signatures

```bash
# Store public key in a secret
kubectl create secret generic cosign-pub-key \
  -n kyverno \
  --from-file=cosign.pub=cosign.pub

# Policy to verify image signatures
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: verify-image-signature
  annotations:
    policies.kyverno.io/title: Verify Image Signature
    policies.kyverno.io/description: >-
      Verify that images are signed with our key.
spec:
  validationFailureAction: Enforce
  background: false
  webhookTimeoutSeconds: 30
  rules:
  - name: verify-signature
    match:
      any:
      - resources:
          kinds:
          - Pod
    verifyImages:
    - imageReferences:
      - "localhost:5000/*"
      attestors:
      - count: 1
        entries:
        - keys:
            publicKeys: |-
$(sed 's/^/              /' cosign.pub)
EOF

# Test with signed image
kubectl run signed --image=localhost:5000/nginx:signed -n supply-chain-lab --dry-run=server

# Test with unsigned image (should fail)
docker tag nginx:alpine localhost:5000/nginx:unsigned
docker push localhost:5000/nginx:unsigned
kubectl run unsigned --image=localhost:5000/nginx:unsigned -n supply-chain-lab --dry-run=server 2>&1 | head -10
```

### Step 3.6: Mutating Policies

```bash
# Auto-add security context if missing
kubectl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: add-default-security-context
  annotations:
    policies.kyverno.io/title: Add Default Security Context
spec:
  rules:
  - name: add-security-context
    match:
      any:
      - resources:
          kinds:
          - Pod
    mutate:
      patchStrategicMerge:
        spec:
          securityContext:
            runAsNonRoot: true
            seccompProfile:
              type: RuntimeDefault
          containers:
          - (name): "*"
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                - ALL
EOF

# Test mutation
kubectl run test-mutate --image=nginx:alpine -n supply-chain-lab --dry-run=server -o yaml | grep -A20 securityContext
```

---

## Part 4: SBOM (Software Bill of Materials)

### SBOM Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SOFTWARE BILL OF MATERIALS                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  What is an SBOM?                                               │
│  ────────────────                                               │
│  A formal, structured list of components, libraries, and       │
│  dependencies that make up a software package.                  │
│                                                                  │
│  SBOM Formats:                                                   │
│  ─────────────                                                   │
│  • SPDX        - Linux Foundation standard                      │
│  • CycloneDX   - OWASP standard, good for security              │
│  • SWID        - ISO standard                                   │
│                                                                  │
│  Use Cases:                                                      │
│  ──────────                                                      │
│  • Vulnerability tracking (CVE matching)                        │
│  • License compliance                                           │
│  • Dependency auditing                                          │
│  • Incident response                                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              SBOM Contents                              │    │
│  │                                                         │    │
│  │  • Package name and version                             │    │
│  │  • Package supplier                                     │    │
│  │  • Unique identifiers (purl)                            │    │
│  │  • Dependency relationships                             │    │
│  │  • Checksums/hashes                                     │    │
│  │  • License information                                  │    │
│  └────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Step 4.1: Install Syft

```bash
# Install Syft (SBOM generator)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin

# Verify installation
syft version
```

### Step 4.2: Generate SBOM

```bash
# Generate SBOM for an image (SPDX format)
syft nginx:alpine -o spdx-json > nginx-sbom-spdx.json

# Generate SBOM (CycloneDX format)
syft nginx:alpine -o cyclonedx-json > nginx-sbom-cyclonedx.json

# Generate SBOM (Syft native format)
syft nginx:alpine -o json > nginx-sbom-syft.json

# View summary
syft nginx:alpine -o table | head -30
```

### Step 4.3: Generate SBOM with Trivy

```bash
# Trivy can also generate SBOMs
trivy image --format spdx-json --output nginx-trivy-sbom.json nginx:alpine

# CycloneDX format
trivy image --format cyclonedx --output nginx-trivy-cyclonedx.json nginx:alpine

# View SBOM summary
cat nginx-trivy-sbom.json | jq '.packages | length'
echo "packages found in SBOM"
```

### Step 4.4: Attach SBOM to Image

```bash
# Attach SBOM as attestation using Cosign
cosign attach sbom --sbom nginx-sbom-cyclonedx.json localhost:5000/nginx:signed

# Verify SBOM attachment
cosign verify-attestation --key cosign.pub --type cyclonedx localhost:5000/nginx:signed

# Download attached SBOM
cosign download sbom localhost:5000/nginx:signed > downloaded-sbom.json
```

### Step 4.5: Scan SBOM for Vulnerabilities

```bash
# Scan SBOM with Trivy
trivy sbom nginx-sbom-cyclonedx.json

# With severity filter
trivy sbom --severity HIGH,CRITICAL nginx-sbom-cyclonedx.json

# Using Grype (alternative scanner)
# Install Grype
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Scan SBOM
grype sbom:nginx-sbom-cyclonedx.json
```

### Step 4.6: SBOM Analysis Script

```bash
cat > /tmp/analyze-sbom.sh <<'EOF'
#!/bin/bash

SBOM_FILE=$1

if [ -z "$SBOM_FILE" ]; then
  echo "Usage: $0 <sbom-file.json>"
  exit 1
fi

echo "=== SBOM Analysis Report ==="
echo ""

# Check format
FORMAT=$(jq -r 'if .bomFormat then "CycloneDX" elif .spdxVersion then "SPDX" else "Unknown" end' $SBOM_FILE)
echo "Format: $FORMAT"
echo ""

if [ "$FORMAT" == "CycloneDX" ]; then
  echo "Total Components: $(jq '.components | length' $SBOM_FILE)"
  echo ""
  echo "Components by Type:"
  jq -r '.components | group_by(.type) | .[] | "\(.[0].type): \(length)"' $SBOM_FILE
  echo ""
  echo "Top 10 Components:"
  jq -r '.components[:10] | .[] | "  - \(.name)@\(.version)"' $SBOM_FILE
elif [ "$FORMAT" == "SPDX" ]; then
  echo "Total Packages: $(jq '.packages | length' $SBOM_FILE)"
  echo ""
  echo "Top 10 Packages:"
  jq -r '.packages[:10] | .[] | "  - \(.name)@\(.versionInfo)"' $SBOM_FILE
fi

echo ""
echo "=== Vulnerability Scan ==="
trivy sbom --severity HIGH,CRITICAL $SBOM_FILE 2>/dev/null | tail -20 || echo "Run: trivy sbom $SBOM_FILE"
EOF

chmod +x /tmp/analyze-sbom.sh
/tmp/analyze-sbom.sh nginx-sbom-cyclonedx.json
```

---

## Part 5: Registry Security

### Step 5.1: Private Registry with Authentication

```bash
# Create htpasswd file
mkdir -p /tmp/registry/auth
docker run --entrypoint htpasswd httpd:2 -Bbn admin secretpassword > /tmp/registry/auth/htpasswd

# Run registry with authentication
docker stop registry 2>/dev/null || true
docker rm registry 2>/dev/null || true

docker run -d \
  -p 5000:5000 \
  --name registry \
  -v /tmp/registry/auth:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e "REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd" \
  registry:2

# Login to registry
docker login localhost:5000 -u admin -p secretpassword

# Push image
docker tag nginx:alpine localhost:5000/nginx:secure
docker push localhost:5000/nginx:secure
```

### Step 5.2: Create Image Pull Secret

```bash
# Create secret for Kubernetes
kubectl create secret docker-registry regcred \
  -n supply-chain-lab \
  --docker-server=localhost:5000 \
  --docker-username=admin \
  --docker-password=secretpassword

# Use in pod
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: private-registry-pod
  namespace: supply-chain-lab
spec:
  containers:
  - name: app
    image: localhost:5000/nginx:secure
  imagePullSecrets:
  - name: regcred
EOF
```

### Step 5.3: Scan Registry Images

```bash
# Scan all images in a registry (example script)
cat > /tmp/scan-registry.sh <<'EOF'
#!/bin/bash

REGISTRY=${1:-"localhost:5000"}

echo "=== Scanning Registry: $REGISTRY ==="

# Get catalog (for registries that support it)
IMAGES=$(curl -s http://$REGISTRY/v2/_catalog | jq -r '.repositories[]' 2>/dev/null)

for IMAGE in $IMAGES; do
  echo ""
  echo "--- Scanning: $IMAGE ---"
  
  # Get tags
  TAGS=$(curl -s http://$REGISTRY/v2/$IMAGE/tags/list | jq -r '.tags[]' 2>/dev/null | head -5)
  
  for TAG in $TAGS; do
    echo "  Tag: $TAG"
    trivy image --severity HIGH,CRITICAL --quiet $REGISTRY/$IMAGE:$TAG 2>/dev/null | grep -E "Total:|HIGH|CRITICAL" || echo "    No high/critical vulnerabilities"
  done
done
EOF

chmod +x /tmp/scan-registry.sh
```

---

## Part 6: Complete Pipeline Example

### Step 6.1: Build and Scan Script

```bash
cat > /tmp/secure-build.sh <<'EOF'
#!/bin/bash
set -e

IMAGE_NAME=$1
IMAGE_TAG=${2:-latest}
REGISTRY=${3:-localhost:5000}

FULL_IMAGE="$REGISTRY/$IMAGE_NAME:$IMAGE_TAG"

echo "=== Secure Build Pipeline ==="
echo "Image: $FULL_IMAGE"
echo ""

# Step 1: Build (assuming Dockerfile exists)
echo "Step 1: Building image..."
# docker build -t $FULL_IMAGE .

# For demo, just tag existing image
docker tag nginx:alpine $FULL_IMAGE

# Step 2: Scan for vulnerabilities
echo ""
echo "Step 2: Scanning for vulnerabilities..."
trivy image --severity HIGH,CRITICAL --exit-code 0 $FULL_IMAGE

VULN_COUNT=$(trivy image --severity CRITICAL -q -f json $FULL_IMAGE | jq '.Results[].Vulnerabilities | length' 2>/dev/null | paste -sd+ | bc 2>/dev/null || echo "0")
if [ "$VULN_COUNT" -gt 0 ]; then
  echo "⚠️  Found $VULN_COUNT critical vulnerabilities"
  # exit 1  # Uncomment to fail on critical vulns
fi

# Step 3: Generate SBOM
echo ""
echo "Step 3: Generating SBOM..."
syft $FULL_IMAGE -o cyclonedx-json > /tmp/${IMAGE_NAME}-sbom.json
echo "SBOM saved to /tmp/${IMAGE_NAME}-sbom.json"

# Step 4: Push image
echo ""
echo "Step 4: Pushing image..."
docker push $FULL_IMAGE

# Step 5: Sign image
echo ""
echo "Step 5: Signing image..."
cosign sign --key cosign.key $FULL_IMAGE

# Step 6: Attach SBOM
echo ""
echo "Step 6: Attaching SBOM..."
cosign attach sbom --sbom /tmp/${IMAGE_NAME}-sbom.json $FULL_IMAGE

echo ""
echo "=== Build Complete ==="
echo "Image: $FULL_IMAGE"
echo "Signed: ✅"
echo "SBOM Attached: ✅"
EOF

chmod +x /tmp/secure-build.sh
```

### Step 6.2: Verification Script

```bash
cat > /tmp/verify-image.sh <<'EOF'
#!/bin/bash

IMAGE=$1
PUBLIC_KEY=${2:-cosign.pub}

echo "=== Image Verification ==="
echo "Image: $IMAGE"
echo ""

# Step 1: Verify signature
echo "Step 1: Verifying signature..."
if cosign verify --key $PUBLIC_KEY $IMAGE > /dev/null 2>&1; then
  echo "✅ Signature verified"
else
  echo "❌ Signature verification failed"
  exit 1
fi

# Step 2: Check for SBOM
echo ""
echo "Step 2: Checking SBOM..."
if cosign download sbom $IMAGE > /dev/null 2>&1; then
  echo "✅ SBOM found"
  SBOM=$(cosign download sbom $IMAGE)
  COMPONENTS=$(echo "$SBOM" | jq '.components | length' 2>/dev/null || echo "unknown")
  echo "   Components: $COMPONENTS"
else
  echo "⚠️  No SBOM attached"
fi

# Step 3: Scan for vulnerabilities
echo ""
echo "Step 3: Scanning for vulnerabilities..."
trivy image --severity HIGH,CRITICAL --quiet $IMAGE

echo ""
echo "=== Verification Complete ==="
EOF

chmod +x /tmp/verify-image.sh
```

---

## Verification

### Check Policies

```bash
# List Kyverno policies
kubectl get clusterpolicy

# Check policy reports
kubectl get policyreport -A

# Describe specific policy
kubectl describe clusterpolicy require-trusted-registry
```

### Verify Image Chain

```bash
# Full verification
echo "=== Supply Chain Verification ==="

IMAGE="localhost:5000/nginx:signed"

echo "1. Signature:"
cosign verify --key cosign.pub $IMAGE 2>/dev/null && echo "   ✅ Valid" || echo "   ❌ Invalid"

echo "2. SBOM:"
cosign download sbom $IMAGE > /dev/null 2>&1 && echo "   ✅ Attached" || echo "   ⚠️ Missing"

echo "3. Vulnerabilities:"
VULNS=$(trivy image --severity CRITICAL -q -f json $IMAGE 2>/dev/null | jq '[.Results[].Vulnerabilities // [] | length] | add' 2>/dev/null || echo "0")
echo "   Critical: ${VULNS:-0}"
```

---

## Common Issues and Solutions

### Issue 1: Cosign Signature Verification Failed

**Symptoms:** Signature verification fails

**Solutions:**
1. Ensure correct public key is used
2. Check image reference matches exactly
3. Verify registry is accessible

```bash
# Debug signature
cosign triangulate $IMAGE
cosign verify --key cosign.pub $IMAGE 2>&1
```

### Issue 2: Kyverno Policy Not Enforcing

**Symptoms:** Policy exists but not blocking resources

**Solutions:**
1. Check policy status
2. Verify validationFailureAction is "Enforce"
3. Check Kyverno webhook

```bash
kubectl get clusterpolicy -o yaml | grep validationFailureAction
kubectl get validatingwebhookconfiguration | grep kyverno
```

### Issue 3: SBOM Generation Fails

**Symptoms:** Syft or Trivy can't generate SBOM

**Solutions:**
1. Check image is accessible
2. Verify authentication for private registries
3. Check disk space for scan cache

---

## Cleanup

```bash
# Remove lab resources
kubectl delete namespace supply-chain-lab

# Remove Kyverno policies
kubectl delete clusterpolicy --all

# Remove Kyverno
helm uninstall kyverno -n kyverno
kubectl delete namespace kyverno

# Stop local registry
docker stop registry
docker rm registry

# Clean up files
rm -f cosign.key cosign.pub
rm -f *.json
rm -f /tmp/*.sh /tmp/*.json
```

---

## Key Takeaways

1. **Image Scanning** - Scan all images for vulnerabilities before deployment
2. **Image Signing** - Sign images to ensure integrity and provenance
3. **Admission Control** - Enforce security policies at deploy time
4. **SBOM** - Generate and track software components
5. **Registry Security** - Secure your image storage and access

---

## Next Steps

Continue to [Lab 6: Runtime Security](../lab-06-runtime/README.md) to learn about detecting and responding to runtime threats.

---

## Additional Resources

- [Trivy Documentation](https://aquasecurity.github.io/trivy/)
- [Cosign Documentation](https://docs.sigstore.dev/cosign/overview/)
- [Kyverno Documentation](https://kyverno.io/docs/)
- [SLSA Framework](https://slsa.dev/)
- [SBOM Formats (SPDX, CycloneDX)](https://www.cisa.gov/sbom)
