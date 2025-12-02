# Module 3 Assessment: CI/CD Pipelines

## Assessment Overview

This assessment tests your practical knowledge of CI/CD concepts covered in Module 3. You will complete 20 tasks that simulate real-world scenarios.

### Assessment Details

- **Total Tasks**: 20
- **Time Limit**: 3 hours (recommended)
- **Passing Score**: 70% (14/20 tasks)
- **Resources**: All labs and quick reference allowed

---

## Part 1: GitHub Actions (Tasks 1-5)

### Task 1: Create a Basic CI Workflow

**Scenario**: Your team needs a CI workflow for a Node.js application.

**Requirements**:

1. Create a workflow that triggers on push to `main` and pull requests
2. Run on `ubuntu-latest`
3. Use Node.js 20
4. Install dependencies and run tests
5. Only run if JavaScript/TypeScript files change

Create the workflow file:

```text
File: .github/workflows/ci.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: CI Pipeline

on:
  push:
    branches: [main]
    paths:
      - '**.js'
      - '**.ts'
      - 'package*.json'
  pull_request:
    branches: [main]
    paths:
      - '**.js'
      - '**.ts'
      - 'package*.json'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: npm test
```

</details>

**Validation**:

```bash
# Verify workflow syntax
cat .github/workflows/ci.yaml | yq e '.'

# Test locally with act (optional)
act -j test --dryrun
```

---

### Task 2: Implement Matrix Builds

**Scenario**: Test the application across multiple Node.js versions and operating systems.

**Requirements**:

1. Test on Node.js versions 18, 20, and 22
2. Test on Ubuntu and macOS
3. Exclude Node.js 18 on macOS
4. Continue on error for other matrix combinations
5. Add coverage upload for Node.js 20 on Ubuntu

Create or modify the workflow:

```text
File: .github/workflows/matrix-ci.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Matrix CI

on:
  push:
    branches: [main]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    continue-on-error: ${{ matrix.experimental || false }}
    
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        node-version: [18, 20, 22]
        include:
          - os: ubuntu-latest
            node-version: 20
            coverage: true
          - os: ubuntu-latest
            node-version: 22
            experimental: true
        exclude:
          - os: macos-latest
            node-version: 18

    steps:
      - uses: actions/checkout@v4

      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - run: npm ci
      
      - name: Run tests
        run: npm test -- --coverage

      - name: Upload coverage
        if: ${{ matrix.coverage }}
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
```

</details>

---

### Task 3: Create a Reusable Workflow

**Scenario**: Create a reusable build workflow that other repositories can use.

**Requirements**:

1. Accept inputs for: `node-version`, `build-command`, `artifact-path`
2. Accept secret for: `npm-token`
3. Output the artifact name
4. Cache npm dependencies
5. Upload build artifacts

Create the reusable workflow:

```text
File: .github/workflows/reusable-build.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Reusable Build

on:
  workflow_call:
    inputs:
      node-version:
        type: string
        default: '20'
        required: false
      build-command:
        type: string
        default: 'npm run build'
        required: false
      artifact-path:
        type: string
        default: 'dist'
        required: false
    outputs:
      artifact-name:
        description: Name of uploaded artifact
        value: ${{ jobs.build.outputs.artifact-name }}
    secrets:
      npm-token:
        required: false

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact-name: build-${{ github.sha }}
    
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Configure NPM
        if: ${{ secrets.npm-token != '' }}
        run: echo "//registry.npmjs.org/:_authToken=${{ secrets.npm-token }}" >> ~/.npmrc

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: ${{ inputs.build-command }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: ${{ inputs.artifact-path }}
          retention-days: 7
```

</details>

---

### Task 4: Implement Workflow Concurrency

**Scenario**: Prevent duplicate workflow runs and cancel outdated runs.

**Requirements**:

1. Create a concurrency group based on PR number or branch
2. Cancel in-progress runs when new commits are pushed
3. Add a skip check for duplicate content
4. Only run on relevant file changes

Modify the workflow:

```text
File: .github/workflows/optimized-ci.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Optimized CI

on:
  push:
    branches: [main, develop]
    paths:
      - 'src/**'
      - 'tests/**'
      - 'package*.json'
  pull_request:
    paths:
      - 'src/**'
      - 'tests/**'
      - 'package*.json'

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  check:
    runs-on: ubuntu-latest
    outputs:
      should-skip: ${{ steps.skip-check.outputs.should_skip }}
    steps:
      - id: skip-check
        uses: fkirc/skip-duplicate-actions@v5
        with:
          concurrent_skipping: same_content_newer
          skip_after_successful_duplicate: 'true'

  build:
    needs: check
    if: needs.check.outputs.should-skip != 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
      - run: npm ci
      - run: npm test
      - run: npm run build
```

</details>

---

### Task 5: Implement Secret Scanning

**Scenario**: Add security scanning to detect secrets in code.

**Requirements**:

1. Trigger on push and pull requests
2. Use Gitleaks for secret scanning
3. Fail the workflow if secrets are found
4. Upload SARIF results to GitHub Security
5. Allow manual runs for full repository scans

Create the workflow:

```text
File: .github/workflows/security-scan.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
  workflow_dispatch:
    inputs:
      full-scan:
        description: 'Run full repository scan'
        type: boolean
        default: false

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: ${{ github.event.inputs.full-scan == 'true' && 0 || 1 }}

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

      - name: Upload SARIF
        if: always()
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: results.sarif
          category: gitleaks
```

</details>

---

## Part 2: Container Builds (Tasks 6-10)

### Task 6: Optimize a Dockerfile

**Scenario**: Optimize the following Dockerfile for smaller size and faster builds.

**Original Dockerfile**:

```dockerfile
FROM node:20
WORKDIR /app
COPY . .
RUN npm install
RUN npm run build
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

**Requirements**:

1. Use multi-stage build
2. Use Alpine base image for runtime
3. Only copy necessary files
4. Set non-root user
5. Add proper labels

<details>
<summary>Show Solution</summary>

```dockerfile
# Build stage
FROM node:20-alpine AS builder
WORKDIR /app

# Copy dependency files first
COPY package*.json ./
RUN npm ci --only=production

# Copy source and build
COPY src/ ./src/
COPY tsconfig.json ./
RUN npm run build

# Production stage
FROM node:20-alpine AS production

LABEL org.opencontainers.image.source="https://github.com/org/repo"
LABEL org.opencontainers.image.description="Application server"
LABEL org.opencontainers.image.version="1.0.0"

WORKDIR /app

# Create non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy only production dependencies and built files
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package.json ./

# Set ownership and switch user
RUN chown -R appuser:appgroup /app
USER appuser

EXPOSE 3000
CMD ["node", "dist/server.js"]
```

</details>

---

### Task 7: Build with Buildah

**Scenario**: Create a GitHub Actions workflow that builds containers using Buildah without Docker.

**Requirements**:

1. Use Buildah for building
2. Push to GitHub Container Registry
3. Tag with SHA and latest
4. Add vulnerability scanning with Trivy
5. Sign the image with cosign

Create the workflow:

```text
File: .github/workflows/buildah-build.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Buildah Build

on:
  push:
    branches: [main]

env:
  IMAGE_REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write  # For cosign

    steps:
      - uses: actions/checkout@v4

      - name: Install cosign
        uses: sigstore/cosign-installer@v3

      - name: Build image with Buildah
        id: build
        uses: redhat-actions/buildah-build@v2
        with:
          image: ${{ env.IMAGE_NAME }}
          tags: |
            ${{ github.sha }}
            latest
          containerfiles: ./Dockerfile

      - name: Scan image
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ steps.build.outputs.image }}:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Login to GHCR
        uses: redhat-actions/podman-login@v1
        with:
          registry: ${{ env.IMAGE_REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Push image
        id: push
        uses: redhat-actions/push-to-registry@v2
        with:
          image: ${{ steps.build.outputs.image }}
          tags: ${{ steps.build.outputs.tags }}
          registry: ${{ env.IMAGE_REGISTRY }}

      - name: Sign image
        run: |
          cosign sign --yes \
            ${{ env.IMAGE_REGISTRY }}/${{ env.IMAGE_NAME }}@${{ steps.push.outputs.digest }}
```

</details>

---

### Task 8: Implement Image Versioning

**Scenario**: Create semantic versioning for container images based on git tags.

**Requirements**:

1. Trigger on push to main and version tags
2. Generate version from git tag or use SHA for non-tag builds
3. Add multiple tags: version, major.minor, latest
4. Include build metadata as labels
5. Generate SBOM

Create the workflow:

```text
File: .github/workflows/versioned-build.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Versioned Build

on:
  push:
    branches: [main]
    tags: ['v*.*.*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Docker meta
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=semver,pattern={{major}}
            type=sha

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          sbom: true
          provenance: true
```

</details>

---

### Task 9: Create Kaniko Build in Kubernetes

**Scenario**: Set up a Kubernetes Job to build containers in-cluster using Kaniko.

**Requirements**:

1. Create a Kubernetes Job for Kaniko
2. Mount Docker config for registry auth
3. Use a PVC for build context
4. Set resource limits
5. Push to a private registry

Create the Kubernetes manifests:

```text
File: kubernetes/kaniko-build-job.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: docker-config
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: <base64-encoded-docker-config>
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: build-context
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: batch/v1
kind: Job
metadata:
  name: kaniko-build
spec:
  backoffLimit: 2
  ttlSecondsAfterFinished: 300
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: kaniko
          image: gcr.io/kaniko-project/executor:latest
          args:
            - "--dockerfile=Dockerfile"
            - "--context=dir:///workspace"
            - "--destination=registry.example.com/myapp:latest"
            - "--cache=true"
            - "--cache-repo=registry.example.com/myapp/cache"
            - "--snapshot-mode=redo"
            - "--use-new-run"
          resources:
            requests:
              memory: "2Gi"
              cpu: "1"
            limits:
              memory: "4Gi"
              cpu: "2"
          volumeMounts:
            - name: docker-config
              mountPath: /kaniko/.docker
            - name: build-context
              mountPath: /workspace
      volumes:
        - name: docker-config
          secret:
            secretName: docker-config
            items:
              - key: .dockerconfigjson
                path: config.json
        - name: build-context
          persistentVolumeClaim:
            claimName: build-context
```

</details>

---

### Task 10: Implement Multi-Architecture Builds

**Scenario**: Build container images for both AMD64 and ARM64 architectures.

**Requirements**:

1. Use Docker Buildx for multi-arch builds
2. Build for linux/amd64 and linux/arm64
3. Push as a multi-platform manifest
4. Cache layers per architecture
5. Add attestations

Create the workflow:

```text
File: .github/workflows/multi-arch-build.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Multi-Arch Build

on:
  push:
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to GHCR
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          platforms: linux/amd64,linux/arm64
          push: true
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: |
            type=gha,scope=amd64
            type=gha,scope=arm64
          cache-to: |
            type=gha,mode=max,scope=${{ github.ref_name }}
          provenance: true
          sbom: true

      - name: Inspect manifest
        run: |
          docker buildx imagetools inspect \
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ github.ref_name }}
```

</details>

---

## Part 3: Tekton Pipelines (Tasks 11-14)

### Task 11: Create a Tekton Task

**Scenario**: Create a Tekton Task that runs unit tests for a Go application.

**Requirements**:

1. Accept parameters for Go version and test flags
2. Use a workspace for source code
3. Cache Go modules
4. Generate test results in JUnit format
5. Export test results as a result

Create the Task:

```text
File: tekton/tasks/go-test-task.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: go-test
spec:
  description: Run Go unit tests
  
  params:
    - name: go-version
      type: string
      default: "1.22"
    - name: test-flags
      type: string
      default: "-v -race -coverprofile=coverage.out"
    - name: packages
      type: string
      default: "./..."

  workspaces:
    - name: source
      description: Source code
    - name: go-cache
      description: Go module cache
      optional: true

  results:
    - name: coverage
      description: Test coverage percentage
    - name: test-count
      description: Number of tests run

  steps:
    - name: run-tests
      image: golang:$(params.go-version)
      workingDir: $(workspaces.source.path)
      env:
        - name: GOMODCACHE
          value: $(workspaces.go-cache.path)/mod
        - name: GOCACHE
          value: $(workspaces.go-cache.path)/build
      script: |
        #!/usr/bin/env bash
        set -ex
        
        # Download dependencies
        go mod download
        
        # Run tests with JUnit output
        go install github.com/jstemmer/go-junit-report@latest
        go test $(params.test-flags) $(params.packages) 2>&1 | \
          go-junit-report > $(workspaces.source.path)/test-results.xml
        
        # Extract coverage
        if [ -f coverage.out ]; then
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}')
          echo -n "$COVERAGE" | tee $(results.coverage.path)
        fi
        
        # Count tests
        TESTS=$(grep -c "<testcase" test-results.xml || echo "0")
        echo -n "$TESTS" | tee $(results.test-count.path)
```

</details>

---

### Task 12: Create a Tekton Pipeline

**Scenario**: Create a complete CI Pipeline that clones, tests, builds, and pushes an image.

**Requirements**:

1. Clone repository from git
2. Run unit tests using the Task from Task 11
3. Build container image with Kaniko
4. Push to registry
5. Use workspaces for sharing data

Create the Pipeline:

```text
File: tekton/pipelines/ci-pipeline.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ci-pipeline
spec:
  description: Complete CI pipeline
  
  params:
    - name: git-url
      type: string
    - name: git-revision
      type: string
      default: main
    - name: image-name
      type: string
    - name: image-tag
      type: string
      default: latest

  workspaces:
    - name: shared-workspace
    - name: docker-credentials
    - name: go-cache

  tasks:
    - name: clone
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.git-url)
        - name: revision
          value: $(params.git-revision)
      workspaces:
        - name: output
          workspace: shared-workspace

    - name: test
      runAfter: [clone]
      taskRef:
        name: go-test
      params:
        - name: go-version
          value: "1.22"
        - name: test-flags
          value: "-v -race -coverprofile=coverage.out"
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: go-cache
          workspace: go-cache

    - name: build
      runAfter: [test]
      taskRef:
        name: kaniko
      params:
        - name: IMAGE
          value: $(params.image-name):$(params.image-tag)
        - name: DOCKERFILE
          value: ./Dockerfile
        - name: CONTEXT
          value: ./
        - name: EXTRA_ARGS
          value:
            - "--cache=true"
            - "--cache-repo=$(params.image-name)/cache"
      workspaces:
        - name: source
          workspace: shared-workspace
        - name: dockerconfig
          workspace: docker-credentials

  results:
    - name: image-digest
      description: Digest of built image
      value: $(tasks.build.results.IMAGE_DIGEST)
    - name: test-coverage
      description: Test coverage
      value: $(tasks.test.results.coverage)
```

</details>

---

### Task 13: Create Tekton Triggers

**Scenario**: Set up Tekton Triggers to automatically run the Pipeline on git push events.

**Requirements**:

1. Create an EventListener for GitHub webhooks
2. Create a TriggerTemplate that creates PipelineRuns
3. Create a TriggerBinding for push events
4. Handle different branches appropriately
5. Add authentication for webhooks

Create the Trigger resources:

```text
File: tekton/triggers/github-triggers.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-webhook-secret
type: Opaque
stringData:
  secretToken: "your-webhook-secret"
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-push-binding
spec:
  params:
    - name: git-url
      value: $(body.repository.clone_url)
    - name: git-revision
      value: $(body.after)
    - name: git-branch
      value: $(extensions.branch_name)
    - name: image-tag
      value: $(extensions.truncated_sha)
---
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: ci-pipeline-template
spec:
  params:
    - name: git-url
    - name: git-revision
    - name: git-branch
    - name: image-tag
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: ci-pipeline-run-
      spec:
        pipelineRef:
          name: ci-pipeline
        params:
          - name: git-url
            value: $(tt.params.git-url)
          - name: git-revision
            value: $(tt.params.git-revision)
          - name: image-name
            value: ghcr.io/myorg/myapp
          - name: image-tag
            value: $(tt.params.image-tag)
        workspaces:
          - name: shared-workspace
            volumeClaimTemplate:
              spec:
                accessModes: [ReadWriteOnce]
                resources:
                  requests:
                    storage: 1Gi
          - name: docker-credentials
            secret:
              secretName: docker-credentials
          - name: go-cache
            persistentVolumeClaim:
              claimName: go-cache-pvc
---
apiVersion: triggers.tekton.dev/v1beta1
kind: Trigger
metadata:
  name: github-push-trigger
spec:
  interceptors:
    - ref:
        name: github
      params:
        - name: secretRef
          value:
            secretName: github-webhook-secret
            secretKey: secretToken
        - name: eventTypes
          value: [push]
    - ref:
        name: cel
      params:
        - name: filter
          value: body.ref.startsWith('refs/heads/')
        - name: overlays
          value:
            - key: branch_name
              expression: body.ref.split('/')[2]
            - key: truncated_sha
              expression: body.after.truncate(7)
  bindings:
    - ref: github-push-binding
  template:
    ref: ci-pipeline-template
---
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
    - triggerRef: github-push-trigger
  resources:
    kubernetesResource:
      spec:
        template:
          spec:
            containers:
              - resources:
                  requests:
                    memory: "64Mi"
                    cpu: "50m"
                  limits:
                    memory: "128Mi"
                    cpu: "100m"
```

</details>

---

### Task 14: Debug a Failed PipelineRun

**Scenario**: A PipelineRun has failed. Diagnose and fix the issue.

**Failed PipelineRun output**:

```text
Name:   ci-pipeline-run-abc123
Status: Failed

Tasks:
  clone:  Succeeded
  test:   Failed
  build:  Not Run

Pod Logs (test):
  go: github.com/some/package@v1.2.3: Get "https://proxy.golang.org/...": 
  dial tcp: lookup proxy.golang.org: no such host
```

**Requirements**:

1. Identify the root cause
2. Explain the fix
3. Modify the Task or Pipeline to resolve the issue

<details>
<summary>Show Solution</summary>

**Root Cause**: The pod cannot resolve DNS for external hosts, indicating a network policy issue or DNS misconfiguration.

**Diagnosis Steps**:

```bash
# Check pod DNS configuration
kubectl get pod <test-pod> -o yaml | grep -A5 dnsConfig

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Test DNS from pod
kubectl exec -it <pod> -- nslookup proxy.golang.org
```

**Fix Options**:

1. **Use Go proxy environment variable**:

```yaml
# Add to Task
env:
  - name: GOPROXY
    value: "https://proxy.golang.org,direct"
  - name: GOPRIVATE
    value: "github.com/yourorg/*"
```

2. **Configure DNS in Task**:

```yaml
steps:
  - name: run-tests
    image: golang:1.22
    # Add DNS configuration
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
```

3. **Use vendor directory**:

```yaml
steps:
  - name: vendor-deps
    image: golang:1.22
    script: |
      # Use vendored dependencies
      go mod vendor
      go test -mod=vendor ./...
```

4. **Check NetworkPolicy**:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-tekton-egress
spec:
  podSelector:
    matchLabels:
      tekton.dev/taskRun: ""
  policyTypes:
    - Egress
  egress:
    - to: []  # Allow all egress
```

</details>

---

## Part 4: GitOps Integration (Tasks 15-17)

### Task 15: Configure ArgoCD Image Updater

**Scenario**: Set up ArgoCD Image Updater to automatically update deployments when new images are pushed.

**Requirements**:

1. Install and configure ArgoCD Image Updater
2. Configure an Application to track image updates
3. Use semver versioning strategy
4. Write updates back to a git repository
5. Limit updates to specific image patterns

Create the configuration:

```text
File: argocd/image-updater-config.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
# ArgoCD Application with Image Updater annotations
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: app=ghcr.io/myorg/myapp
    argocd-image-updater.argoproj.io/app.update-strategy: semver
    argocd-image-updater.argoproj.io/app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
    argocd-image-updater.argoproj.io/app.ignore-tags: "latest,dev-*"
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
    argocd-image-updater.argoproj.io/write-back-target: kustomization
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-config.git
    path: environments/production
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
---
# Image Updater ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-image-updater-config
  namespace: argocd
data:
  registries.conf: |
    registries:
      - name: GitHub Container Registry
        prefix: ghcr.io
        api_url: https://ghcr.io
        credentials: pullsecret:argocd/ghcr-credentials
        default: true
  log.level: info
---
# Registry credentials
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-credentials
  namespace: argocd
type: kubernetes.io/dockerconfigjson
stringData:
  .dockerconfigjson: |
    {
      "auths": {
        "ghcr.io": {
          "auth": "<base64-encoded-credentials>"
        }
      }
    }
```

</details>

---

### Task 16: Create Multi-Environment Promotion Pipeline

**Scenario**: Create a GitOps promotion workflow that promotes images through dev → staging → production.

**Requirements**:

1. Update dev environment automatically on main branch push
2. Require manual approval for staging promotion
3. Create a PR for production promotion
4. Include validation gates between stages
5. Roll back on failure

Create the workflow:

```text
File: .github/workflows/gitops-promotion.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: GitOps Promotion

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: choice
        options: [staging, production]
      version:
        description: 'Version to promote'
        required: true

env:
  CONFIG_REPO: myorg/myapp-config

jobs:
  build:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.build.outputs.digest }}
    steps:
      - uses: actions/checkout@v4
      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}

  deploy-dev:
    needs: build
    runs-on: ubuntu-latest
    environment: dev
    steps:
      - name: Checkout config repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.CONFIG_REPO }}
          token: ${{ secrets.CONFIG_REPO_TOKEN }}
          path: config

      - name: Update dev environment
        run: |
          cd config/environments/dev
          kustomize edit set image myapp=ghcr.io/${{ github.repository }}:${{ github.sha }}
          git config user.name "github-actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Deploy ${{ github.sha }} to dev"
          git push

      - name: Wait for sync
        run: |
          argocd app wait myapp-dev --health --timeout 300

  promote-staging:
    needs: deploy-dev
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Checkout config repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.CONFIG_REPO }}
          token: ${{ secrets.CONFIG_REPO_TOKEN }}
          path: config

      - name: Promote to staging
        run: |
          cd config
          # Copy image from dev to staging
          DEV_IMAGE=$(cd environments/dev && kustomize build | grep "image:" | awk '{print $2}')
          cd environments/staging
          kustomize edit set image myapp=${DEV_IMAGE}
          git add .
          git commit -m "Promote ${DEV_IMAGE} to staging"
          git push

  promote-production:
    if: github.event.inputs.environment == 'production'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout config repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.CONFIG_REPO }}
          token: ${{ secrets.CONFIG_REPO_TOKEN }}
          path: config

      - name: Create production PR
        run: |
          cd config
          git checkout -b promote-prod-${{ github.run_id }}
          
          cd environments/production
          kustomize edit set image myapp=ghcr.io/${{ github.repository }}:${{ github.event.inputs.version }}
          
          git add .
          git commit -m "Promote ${{ github.event.inputs.version }} to production"
          git push origin promote-prod-${{ github.run_id }}
          
          gh pr create \
            --title "Promote ${{ github.event.inputs.version }} to production" \
            --body "This PR promotes version ${{ github.event.inputs.version }} to production." \
            --reviewer platform-team
        env:
          GH_TOKEN: ${{ secrets.CONFIG_REPO_TOKEN }}
```

</details>

---

### Task 17: Implement Rollback Strategy

**Scenario**: Create an automated rollback mechanism when deployments fail health checks.

**Requirements**:

1. Monitor ArgoCD application health
2. Automatically rollback on failure
3. Send notifications on rollback
4. Keep rollback history
5. Prevent rollback loops

Create the implementation:

```text
File: argocd/rollback-controller.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
# ArgoCD Application with auto-rollback
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
  namespace: argocd
  annotations:
    notifications.argoproj.io/subscribe.on-health-degraded.slack: alerts
spec:
  project: default
  source:
    repoURL: https://github.com/myorg/myapp-config.git
    path: environments/production
    targetRevision: main
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
---
# Rollback script as ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: rollback-script
  namespace: argocd
data:
  rollback.sh: |
    #!/bin/bash
    set -e
    
    APP_NAME=$1
    MAX_ROLLBACKS=3
    ROLLBACK_WINDOW=3600  # 1 hour
    
    # Check rollback history to prevent loops
    RECENT_ROLLBACKS=$(argocd app history $APP_NAME --output json | \
      jq "[.[] | select(.deployedAt | fromdateiso8601 > (now - $ROLLBACK_WINDOW))] | length")
    
    if [ "$RECENT_ROLLBACKS" -ge "$MAX_ROLLBACKS" ]; then
      echo "Too many rollbacks in the last hour. Manual intervention required."
      # Send critical alert
      curl -X POST "$SLACK_WEBHOOK" -d "{
        \"text\": \"CRITICAL: Multiple rollbacks detected for $APP_NAME. Manual intervention required.\"
      }"
      exit 1
    fi
    
    # Get previous healthy revision
    PREVIOUS_REVISION=$(argocd app history $APP_NAME --output json | \
      jq -r '[.[] | select(.health.status == "Healthy")] | .[1].revision')
    
    if [ -z "$PREVIOUS_REVISION" ] || [ "$PREVIOUS_REVISION" == "null" ]; then
      echo "No healthy previous revision found"
      exit 1
    fi
    
    # Perform rollback
    argocd app rollback $APP_NAME $PREVIOUS_REVISION
    
    # Notify
    curl -X POST "$SLACK_WEBHOOK" -d "{
      \"text\": \"Rolled back $APP_NAME to revision $PREVIOUS_REVISION\"
    }"
---
# CronJob to check health and trigger rollback
apiVersion: batch/v1
kind: CronJob
metadata:
  name: health-checker
  namespace: argocd
spec:
  schedule: "*/2 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: argocd-server
          containers:
            - name: checker
              image: argoproj/argocd:v2.10.0
              command: ["/bin/bash"]
              args:
                - -c
                - |
                  APPS=$(argocd app list -o json | jq -r '.[] | select(.status.health.status == "Degraded") | .metadata.name')
                  for app in $APPS; do
                    /scripts/rollback.sh $app
                  done
              volumeMounts:
                - name: scripts
                  mountPath: /scripts
              env:
                - name: SLACK_WEBHOOK
                  valueFrom:
                    secretKeyRef:
                      name: slack-webhook
                      key: url
          volumes:
            - name: scripts
              configMap:
                name: rollback-script
                defaultMode: 0755
          restartPolicy: OnFailure
```

</details>

---

## Part 5: Testing & Quality (Tasks 18-20)

### Task 18: Create a Quality Gate Workflow

**Scenario**: Implement a comprehensive quality gate that must pass before merging.

**Requirements**:

1. Run unit tests with coverage threshold (80%)
2. Run security scanning (Trivy, Gitleaks)
3. Run code quality analysis (ESLint, SonarQube)
4. Block merge if any gate fails
5. Post results to PR

Create the workflow:

```text
File: .github/workflows/quality-gate.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Quality Gate

on:
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: Run tests with coverage
        run: npm test -- --coverage --coverageReporters=json-summary

      - name: Check coverage threshold
        id: coverage
        run: |
          COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
          echo "coverage=$COVERAGE" >> $GITHUB_OUTPUT
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "Coverage $COVERAGE% is below 80% threshold"
            exit 1
          fi

      - name: Post coverage comment
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `## Test Coverage: ${{ steps.coverage.outputs.coverage }}%`
            })

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: trivy-results.sarif

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - run: npm ci

      - name: ESLint
        run: npm run lint -- --format @microsoft/eslint-formatter-sarif --output-file eslint-results.sarif
        continue-on-error: true

      - name: Upload ESLint results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: eslint-results.sarif

  sonarqube:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: SonarQube Scan
        uses: SonarSource/sonarqube-scan-action@master
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
          SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}

      - name: Quality Gate Check
        uses: SonarSource/sonarqube-quality-gate-action@master
        timeout-minutes: 5
        env:
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  gate:
    needs: [test, security, lint, sonarqube]
    runs-on: ubuntu-latest
    steps:
      - name: All gates passed
        run: echo "All quality gates passed!"
```

</details>

---

### Task 19: Implement Load Testing in Pipeline

**Scenario**: Add load testing as part of the CI/CD pipeline using k6.

**Requirements**:

1. Deploy application to test environment
2. Run k6 load tests
3. Define pass/fail thresholds
4. Generate HTML report
5. Store results for trending

Create the workflow:

```text
File: .github/workflows/load-testing.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Load Testing

on:
  workflow_dispatch:
  schedule:
    - cron: '0 2 * * *'  # Nightly

jobs:
  deploy-test:
    runs-on: ubuntu-latest
    outputs:
      test-url: ${{ steps.deploy.outputs.url }}
    steps:
      - uses: actions/checkout@v4

      - name: Deploy to test environment
        id: deploy
        run: |
          # Deploy to test environment
          kubectl apply -f kubernetes/test/
          kubectl wait --for=condition=ready pod -l app=myapp -n test --timeout=120s
          URL=$(kubectl get svc myapp -n test -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
          echo "url=http://$URL" >> $GITHUB_OUTPUT

  load-test:
    needs: deploy-test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create k6 test script
        run: |
          cat > load-test.js << 'EOF'
          import http from 'k6/http';
          import { check, sleep } from 'k6';
          import { htmlReport } from 'https://raw.githubusercontent.com/benc-uk/k6-reporter/main/dist/bundle.js';
          
          export const options = {
            stages: [
              { duration: '1m', target: 50 },   // Ramp up
              { duration: '3m', target: 50 },   // Steady state
              { duration: '1m', target: 100 },  // Spike
              { duration: '2m', target: 100 },  // Steady high
              { duration: '1m', target: 0 },    // Ramp down
            ],
            thresholds: {
              http_req_duration: ['p(95)<500', 'p(99)<1000'],
              http_req_failed: ['rate<0.01'],
              http_reqs: ['rate>100'],
            },
          };
          
          export default function() {
            const res = http.get('${{ needs.deploy-test.outputs.test-url }}/api/health');
            check(res, {
              'status is 200': (r) => r.status === 200,
              'response time < 500ms': (r) => r.timings.duration < 500,
            });
            sleep(1);
          }
          
          export function handleSummary(data) {
            return {
              'report.html': htmlReport(data),
              'summary.json': JSON.stringify(data),
            };
          }
          EOF

      - name: Run k6 load test
        uses: grafana/k6-action@v0.3.1
        with:
          filename: load-test.js

      - name: Upload report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: load-test-report
          path: |
            report.html
            summary.json

      - name: Store results for trending
        run: |
          # Extract key metrics
          DURATION_P95=$(jq '.metrics.http_req_duration.values["p(95)"]' summary.json)
          REQUESTS=$(jq '.metrics.http_reqs.values.count' summary.json)
          FAILURES=$(jq '.metrics.http_req_failed.values.rate' summary.json)
          
          # Send to metrics storage
          curl -X POST "${{ secrets.METRICS_URL }}/load-tests" \
            -H "Content-Type: application/json" \
            -d "{
              \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
              \"duration_p95\": $DURATION_P95,
              \"total_requests\": $REQUESTS,
              \"failure_rate\": $FAILURES
            }"

  cleanup:
    needs: load-test
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Cleanup test environment
        run: |
          kubectl delete -f kubernetes/test/ --ignore-not-found
```

</details>

---

### Task 20: Create End-to-End Pipeline Integration Test

**Scenario**: Validate the entire CI/CD pipeline works correctly by creating an integration test.

**Requirements**:

1. Create a test repository with sample application
2. Push changes to trigger CI pipeline
3. Verify container image is built and pushed
4. Verify GitOps update is applied
5. Verify application is deployed and healthy

Create the integration test:

```text
File: .github/workflows/pipeline-integration-test.yaml
```

<details>
<summary>Show Solution</summary>

```yaml
name: Pipeline Integration Test

on:
  schedule:
    - cron: '0 3 * * 1'  # Weekly on Monday
  workflow_dispatch:

jobs:
  integration-test:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
    steps:
      - uses: actions/checkout@v4

      - name: Setup test environment
        run: |
          # Create kind cluster
          kind create cluster --name pipeline-test
          
          # Install ArgoCD
          kubectl create namespace argocd
          kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
          kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

      - name: Create test application
        run: |
          # Create test app directory
          mkdir -p test-app
          
          # Create simple Go app
          cat > test-app/main.go << 'EOF'
          package main
          import "net/http"
          func main() {
            http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
              w.Write([]byte("OK"))
            })
            http.ListenAndServe(":8080", nil)
          }
          EOF
          
          cat > test-app/Dockerfile << 'EOF'
          FROM golang:1.22-alpine AS builder
          WORKDIR /app
          COPY main.go .
          RUN go build -o server main.go
          
          FROM alpine:3.19
          COPY --from=builder /app/server /server
          CMD ["/server"]
          EOF
          
          # Create Kubernetes manifests
          mkdir -p test-app/k8s
          cat > test-app/k8s/deployment.yaml << 'EOF'
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: test-app
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: test-app
            template:
              metadata:
                labels:
                  app: test-app
              spec:
                containers:
                  - name: app
                    image: test-app:latest
                    ports:
                      - containerPort: 8080
          EOF

      - name: Build container image
        run: |
          cd test-app
          docker build -t test-app:${{ github.sha }} .
          
          # Load into kind
          kind load docker-image test-app:${{ github.sha }} --name pipeline-test

      - name: Update deployment image
        run: |
          # Update image reference
          sed -i "s|image: test-app:latest|image: test-app:${{ github.sha }}|" test-app/k8s/deployment.yaml

      - name: Create ArgoCD Application
        run: |
          kubectl apply -f - << EOF
          apiVersion: argoproj.io/v1alpha1
          kind: Application
          metadata:
            name: test-app
            namespace: argocd
          spec:
            project: default
            source:
              repoURL: https://github.com/${{ github.repository }}.git
              path: test-app/k8s
              targetRevision: ${{ github.sha }}
            destination:
              server: https://kubernetes.default.svc
              namespace: default
            syncPolicy:
              automated:
                prune: true
                selfHeal: true
          EOF

      - name: Wait for deployment
        run: |
          # Wait for ArgoCD sync
          kubectl wait --for=condition=ready pod -l app=test-app --timeout=120s
          
          # Verify deployment
          kubectl get pods -l app=test-app
          kubectl get deployment test-app

      - name: Test application health
        run: |
          # Port forward
          kubectl port-forward svc/test-app 8080:8080 &
          sleep 5
          
          # Health check
          RESPONSE=$(curl -s http://localhost:8080)
          if [ "$RESPONSE" != "OK" ]; then
            echo "Health check failed: $RESPONSE"
            exit 1
          fi
          echo "Health check passed!"

      - name: Verify image update workflow
        run: |
          # Simulate image update
          NEW_TAG="v2.0.0"
          sed -i "s|image: test-app:${{ github.sha }}|image: test-app:${NEW_TAG}|" test-app/k8s/deployment.yaml
          
          # Build new image
          docker build -t test-app:${NEW_TAG} test-app/
          kind load docker-image test-app:${NEW_TAG} --name pipeline-test
          
          # Apply update
          kubectl apply -f test-app/k8s/deployment.yaml
          
          # Wait for rollout
          kubectl rollout status deployment/test-app --timeout=60s
          
          # Verify new image
          CURRENT_IMAGE=$(kubectl get deployment test-app -o jsonpath='{.spec.template.spec.containers[0].image}')
          if [ "$CURRENT_IMAGE" != "test-app:${NEW_TAG}" ]; then
            echo "Image update failed"
            exit 1
          fi
          echo "Image update verified!"

      - name: Generate test report
        if: always()
        run: |
          echo "## Pipeline Integration Test Report" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Step | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Cluster Setup | ✅ |" >> $GITHUB_STEP_SUMMARY
          echo "| Image Build | ✅ |" >> $GITHUB_STEP_SUMMARY
          echo "| ArgoCD Sync | ✅ |" >> $GITHUB_STEP_SUMMARY
          echo "| Health Check | ✅ |" >> $GITHUB_STEP_SUMMARY
          echo "| Image Update | ✅ |" >> $GITHUB_STEP_SUMMARY

      - name: Cleanup
        if: always()
        run: |
          kind delete cluster --name pipeline-test
```

</details>

---

## Scoring Guide

| Part | Tasks | Points |
|------|-------|--------|
| GitHub Actions | 1-5 | 25 |
| Container Builds | 6-10 | 25 |
| Tekton Pipelines | 11-14 | 20 |
| GitOps Integration | 15-17 | 15 |
| Testing & Quality | 18-20 | 15 |
| **Total** | **20** | **100** |

---

## Passing Criteria

- **70% (14 tasks)**: Pass
- **85% (17 tasks)**: Pass with Distinction
- **100% (20 tasks)**: Expert Level

---

## Next Steps

After completing this assessment:

1. Review any tasks you found challenging
2. Practice implementing these patterns in your own projects
3. Continue to Module 4: Observability & Monitoring
4. Explore advanced topics like multi-cluster deployments

---

## Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Tekton Documentation](https://tekton.dev/docs/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Docker Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
