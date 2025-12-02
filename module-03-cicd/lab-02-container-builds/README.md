# Lab 2: Container Build Pipelines

## Overview

This lab covers building optimized container images for cloud-native applications. You will learn Dockerfile best practices, multi-stage builds, BuildKit features, in-cluster builds with Kaniko, image signing, and integration with CI pipelines.

## Time to Complete

Estimated time: 3-4 hours

## Prerequisites

Before starting this lab, ensure you have:

- Completed Lab 1: GitHub Actions Fundamentals
- Docker installed locally
- GitHub account with a repository
- Container registry access (GitHub Container Registry)
- Running kind cluster

## Learning Objectives

By the end of this lab, you will be able to:

1. Write optimized Dockerfiles following best practices
2. Implement multi-stage builds for smaller images
3. Use BuildKit features for faster builds
4. Build images in Kubernetes with Kaniko
5. Configure container registry authentication
6. Implement image tagging strategies
7. Sign and verify container images

## Container Build Architecture

```text
Container Build Pipeline:

┌─────────────────────────────────────────────────────────────────┐
│                      Source Repository                          │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │   src/   │  │Dockerfile│  │.dockerig-│  │  tests/  │       │
│  │          │  │          │  │   nore   │  │          │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Build Stage                                 │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │  BuildKit / Kaniko                                         │ │
│  │  ┌─────────┐    ┌─────────┐    ┌─────────┐                │ │
│  │  │ Stage 1 │───▶│ Stage 2 │───▶│ Stage 3 │                │ │
│  │  │ (deps)  │    │ (build) │    │ (final) │                │ │
│  │  └─────────┘    └─────────┘    └─────────┘                │ │
│  └────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Scan & Sign                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │  Trivy Scan  │  │  SBOM Gen    │  │  Cosign Sign │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Container Registry                             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  ghcr.io/org/app:v1.0.0                                     ││
│  │  ghcr.io/org/app:sha-abc123                                 ││
│  │  ghcr.io/org/app:latest                                     ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Lab Exercises

### Exercise 1: Dockerfile Best Practices

#### Step 1: Create Sample Application

```bash
mkdir container-build-lab
cd container-build-lab

# Create a Go application
cat > main.go << 'EOF'
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "os"
    "time"
)

type Response struct {
    Message   string `json:"message"`
    Hostname  string `json:"hostname"`
    Timestamp string `json:"timestamp"`
    Version   string `json:"version"`
}

func main() {
    version := os.Getenv("APP_VERSION")
    if version == "" {
        version = "unknown"
    }

    http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
        hostname, _ := os.Hostname()
        resp := Response{
            Message:   "Hello from the container!",
            Hostname:  hostname,
            Timestamp: time.Now().Format(time.RFC3339),
            Version:   version,
        }
        w.Header().Set("Content-Type", "application/json")
        json.NewEncoder(w).Encode(resp)
    })

    http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    })

    log.Println("Starting server on :8080")
    log.Fatal(http.ListenAndServe(":8080", nil))
}
EOF

# Create go.mod
cat > go.mod << 'EOF'
module github.com/example/app

go 1.21
EOF
```

#### Step 2: Basic Dockerfile (Before Optimization)

```dockerfile
# Dockerfile.basic - NOT optimized
FROM golang:1.21

WORKDIR /app

COPY . .

RUN go build -o app .

EXPOSE 8080

CMD ["./app"]
```

Build and check size:

```bash
docker build -f Dockerfile.basic -t app:basic .
docker images app:basic
# Size will be ~800MB+
```

#### Step 3: Optimized Dockerfile

```dockerfile
# Dockerfile
# Build stage
FROM golang:1.21-alpine AS builder

# Install CA certificates for HTTPS
RUN apk add --no-cache ca-certificates

WORKDIR /app

# Copy go mod files first (better caching)
COPY go.mod go.sum* ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
    -ldflags="-w -s -X main.version=${VERSION}" \
    -o /app/server .

# Final stage
FROM scratch

# Copy CA certificates
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Copy binary
COPY --from=builder /app/server /server

# Use non-root user
USER 1000:1000

EXPOSE 8080

ENTRYPOINT ["/server"]
```

Build and compare:

```bash
docker build -t app:optimized .
docker images | grep app
# optimized version should be ~10MB
```

### Exercise 2: Multi-Stage Builds

#### Step 1: Complex Multi-Stage Dockerfile

```dockerfile
# Dockerfile.multistage

# ============================================
# Stage 1: Dependencies
# ============================================
FROM golang:1.21-alpine AS deps

WORKDIR /app

# Install git for private dependencies
RUN apk add --no-cache git

# Copy dependency files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# ============================================
# Stage 2: Build
# ============================================
FROM deps AS builder

# Copy source code
COPY . .

# Build arguments for version info
ARG VERSION=dev
ARG COMMIT_SHA=unknown
ARG BUILD_TIME

# Build with ldflags
RUN CGO_ENABLED=0 GOOS=linux go build \
    -ldflags="-w -s \
    -X main.Version=${VERSION} \
    -X main.CommitSHA=${COMMIT_SHA} \
    -X main.BuildTime=${BUILD_TIME}" \
    -o /server .

# ============================================
# Stage 3: Test
# ============================================
FROM builder AS tester

RUN go test -v ./...

# ============================================
# Stage 4: Production
# ============================================
FROM gcr.io/distroless/static:nonroot AS production

WORKDIR /

# Copy binary from builder
COPY --from=builder /server /server

USER nonroot:nonroot

EXPOSE 8080

ENTRYPOINT ["/server"]

# ============================================
# Stage 5: Debug (optional)
# ============================================
FROM alpine:3.18 AS debug

RUN apk add --no-cache \
    curl \
    wget \
    busybox-extras \
    bind-tools

COPY --from=builder /server /server

EXPOSE 8080

ENTRYPOINT ["/server"]
```

#### Step 2: Build Specific Stages

```bash
# Build only the test stage
docker build --target tester -t app:test .

# Build production image
docker build --target production -t app:prod \
  --build-arg VERSION=1.0.0 \
  --build-arg COMMIT_SHA=$(git rev-parse HEAD) \
  --build-arg BUILD_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  .

# Build debug image
docker build --target debug -t app:debug .
```

### Exercise 3: BuildKit Features

#### Step 1: Enable BuildKit

```bash
# Enable BuildKit
export DOCKER_BUILDKIT=1

# Or use buildx
docker buildx build .
```

#### Step 2: BuildKit Cache Mounts

```dockerfile
# Dockerfile.buildkit
# syntax=docker/dockerfile:1.5

FROM golang:1.21-alpine AS builder

WORKDIR /app

# Use cache mount for Go modules
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    --mount=type=bind,source=go.mod,target=go.mod \
    --mount=type=bind,source=go.sum,target=go.sum \
    go mod download

COPY . .

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 go build -o /server .

FROM gcr.io/distroless/static:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
ENTRYPOINT ["/server"]
```

#### Step 3: Secret Mounts

```dockerfile
# Dockerfile.secrets
# syntax=docker/dockerfile:1.5

FROM alpine AS builder

# Use secret mount for private repo access
RUN --mount=type=secret,id=github_token \
    GITHUB_TOKEN=$(cat /run/secrets/github_token) && \
    git clone https://${GITHUB_TOKEN}@github.com/org/private-repo.git

# Or for npm
RUN --mount=type=secret,id=npmrc,target=/root/.npmrc \
    npm install
```

Build with secrets:

```bash
docker build --secret id=github_token,src=.github_token -t app:secret .
```

#### Step 4: SSH Mounts

```dockerfile
# Dockerfile.ssh
# syntax=docker/dockerfile:1.5

FROM alpine AS builder

RUN apk add --no-cache git openssh-client

# Clone using SSH
RUN --mount=type=ssh \
    git clone git@github.com:org/private-repo.git
```

Build with SSH:

```bash
docker build --ssh default -t app:ssh .
```

### Exercise 4: Building with Kaniko in Kubernetes

#### Step 1: Create Kaniko Job

```yaml
# kaniko-build.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: kaniko-cache
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-secret
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-build
spec:
  template:
    spec:
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - "--dockerfile=Dockerfile"
            - "--context=git://github.com/your-org/your-repo.git#refs/heads/main"
            - "--destination=ghcr.io/your-org/app:latest"
            - "--cache=true"
            - "--cache-repo=ghcr.io/your-org/cache"
          volumeMounts:
            - name: docker-config
              mountPath: /kaniko/.docker
            - name: cache
              mountPath: /cache
          env:
            - name: DOCKER_CONFIG
              value: /kaniko/.docker
      restartPolicy: Never
      volumes:
        - name: docker-config
          secret:
            secretName: docker-registry-secret
            items:
              - key: .dockerconfigjson
                path: config.json
        - name: cache
          persistentVolumeClaim:
            claimName: kaniko-cache
  backoffLimit: 0
```

#### Step 2: Kaniko with Build Context from Git

```yaml
# kaniko-git-build.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-git-build
spec:
  template:
    spec:
      initContainers:
        - name: git-clone
          image: alpine/git
          args:
            - clone
            - --single-branch
            - --depth=1
            - https://github.com/your-org/your-repo.git
            - /workspace
          volumeMounts:
            - name: workspace
              mountPath: /workspace
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - "--dockerfile=/workspace/Dockerfile"
            - "--context=/workspace"
            - "--destination=ghcr.io/your-org/app:$(GIT_COMMIT)"
            - "--cache=true"
          env:
            - name: GIT_COMMIT
              value: "abc123"
          volumeMounts:
            - name: workspace
              mountPath: /workspace
            - name: docker-config
              mountPath: /kaniko/.docker
      restartPolicy: Never
      volumes:
        - name: workspace
          emptyDir: {}
        - name: docker-config
          secret:
            secretName: docker-registry-secret
            items:
              - key: .dockerconfigjson
                path: config.json
```

### Exercise 5: GitHub Actions Container Workflow

#### Step 1: Complete Build Workflow

```yaml
# .github/workflows/container-build.yaml
name: Container Build

on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write
      security-events: write

    outputs:
      image: ${{ steps.meta.outputs.tags }}
      digest: ${{ steps.build.outputs.digest }}

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=sha-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          build-args: |
            VERSION=${{ github.ref_name }}
            COMMIT_SHA=${{ github.sha }}
            BUILD_TIME=${{ github.event.head_commit.timestamp }}
          platforms: linux/amd64,linux/arm64

  scan:
    needs: build
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'

    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.image }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  sign:
    needs: [build, scan]
    runs-on: ubuntu-latest
    if: github.event_name != 'pull_request'

    permissions:
      packages: write
      id-token: write

    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Sign container image
        env:
          DIGEST: ${{ needs.build.outputs.digest }}
          TAGS: ${{ needs.build.outputs.image }}
        run: |
          echo "${TAGS}" | xargs -I {} cosign sign --yes {}@${DIGEST}
```

### Exercise 6: Image Tagging Strategies

#### Step 1: Semantic Versioning

```yaml
# .github/workflows/release.yaml
name: Release

on:
  push:
    tags:
      - 'v*.*.*'

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Parse version
        id: version
        run: |
          VERSION=${GITHUB_REF#refs/tags/v}
          MAJOR=$(echo $VERSION | cut -d. -f1)
          MINOR=$(echo $VERSION | cut -d. -f2)
          PATCH=$(echo $VERSION | cut -d. -f3)
          echo "version=$VERSION" >> $GITHUB_OUTPUT
          echo "major=$MAJOR" >> $GITHUB_OUTPUT
          echo "minor=$MINOR" >> $GITHUB_OUTPUT

      - name: Build and push with semantic tags
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ steps.version.outputs.version }}
            ghcr.io/${{ github.repository }}:${{ steps.version.outputs.major }}.${{ steps.version.outputs.minor }}
            ghcr.io/${{ github.repository }}:${{ steps.version.outputs.major }}
            ghcr.io/${{ github.repository }}:latest
```

#### Step 2: Git SHA-Based Tagging

```yaml
- name: Extract metadata
  id: meta
  uses: docker/metadata-action@v5
  with:
    images: ghcr.io/${{ github.repository }}
    tags: |
      # SHA-based tags
      type=sha,prefix=sha-,format=short
      type=sha,prefix=sha-,format=long

      # Branch-based tags
      type=ref,event=branch

      # PR-based tags
      type=ref,event=pr,prefix=pr-

      # Timestamp-based
      type=raw,value={{date 'YYYYMMDD-HHmmss'}}
```

#### Step 3: Environment-Based Tagging

```yaml
jobs:
  build-dev:
    if: github.ref == 'refs/heads/develop'
    steps:
      - uses: docker/build-push-action@v5
        with:
          tags: |
            ghcr.io/${{ github.repository }}:dev
            ghcr.io/${{ github.repository }}:dev-${{ github.sha }}

  build-staging:
    if: github.ref == 'refs/heads/staging'
    steps:
      - uses: docker/build-push-action@v5
        with:
          tags: |
            ghcr.io/${{ github.repository }}:staging
            ghcr.io/${{ github.repository }}:staging-${{ github.sha }}

  build-prod:
    if: startsWith(github.ref, 'refs/tags/v')
    steps:
      - uses: docker/build-push-action@v5
        with:
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.ref_name }}
            ghcr.io/${{ github.repository }}:latest
```

### Exercise 7: Container Image Signing

#### Step 1: Sign with Cosign (Keyless)

```yaml
# .github/workflows/sign.yaml
name: Sign Container

on:
  workflow_run:
    workflows: ["Container Build"]
    types: [completed]

jobs:
  sign:
    runs-on: ubuntu-latest
    permissions:
      packages: write
      id-token: write  # Required for keyless signing

    steps:
      - name: Install Cosign
        uses: sigstore/cosign-installer@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Sign image (keyless)
        run: |
          cosign sign --yes \
            ghcr.io/${{ github.repository }}@${{ github.event.workflow_run.head_sha }}
```

#### Step 2: Sign with Private Key

```yaml
- name: Sign image (with key)
  env:
    COSIGN_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
    COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
  run: |
    echo "$COSIGN_KEY" > cosign.key
    cosign sign --key cosign.key \
      ghcr.io/${{ github.repository }}:${{ github.sha }}
    rm cosign.key
```

#### Step 3: Verify Signatures

```bash
# Verify keyless signature
cosign verify \
  --certificate-identity-regexp="https://github.com/.*" \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  ghcr.io/org/app:latest

# Verify with public key
cosign verify --key cosign.pub ghcr.io/org/app:latest
```

### Exercise 8: SBOM Generation

#### Step 1: Generate SBOM with Syft

```yaml
# .github/workflows/sbom.yaml
name: Generate SBOM

on:
  push:
    branches: [main]

jobs:
  sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:local .

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: app:local
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: sbom.spdx.json

      - name: Attach SBOM to image
        env:
          COSIGN_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
        run: |
          cosign attach sbom --sbom sbom.spdx.json \
            ghcr.io/${{ github.repository }}:${{ github.sha }}
```

#### Step 2: Generate SBOM with Trivy

```yaml
- name: Generate SBOM with Trivy
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'app:local'
    format: 'cyclonedx'
    output: 'sbom.cyclonedx.json'
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Write optimized multi-stage Dockerfiles
- [ ] Use BuildKit features (cache mounts, secrets)
- [ ] Build images in Kubernetes with Kaniko
- [ ] Configure GitHub Actions for container builds
- [ ] Implement proper tagging strategies
- [ ] Sign container images with Cosign
- [ ] Generate and attach SBOMs
- [ ] Scan images for vulnerabilities

## Troubleshooting

### Build Failures

```bash
# Check Docker build with verbose output
docker build --progress=plain -t app:test .

# Check BuildKit logs
BUILDKIT_PROGRESS=plain docker build .
```

### Registry Authentication

```bash
# Test registry login
docker login ghcr.io -u $GITHUB_USER

# Check Docker config
cat ~/.docker/config.json
```

### Kaniko Issues

```bash
# Check Kaniko pod logs
kubectl logs -f job/kaniko-build

# Verify registry secret
kubectl get secret docker-registry-secret -o yaml
```

## Key Takeaways

1. **Multi-Stage Builds**: Reduce image size by separating build and runtime
2. **BuildKit**: Use cache mounts and secrets for faster, secure builds
3. **Distroless Images**: Minimal attack surface for production
4. **Kaniko**: Build images in Kubernetes without Docker daemon
5. **Tagging Strategies**: Use semantic versioning and SHA for traceability
6. **Image Signing**: Verify image integrity and provenance
7. **SBOM**: Document image contents for security compliance

## Next Steps

In Lab 3, you will learn:

- Tekton Pipelines on Kubernetes
- Creating Tasks and Pipelines
- Event-driven builds with Triggers
- Integration with container registries
