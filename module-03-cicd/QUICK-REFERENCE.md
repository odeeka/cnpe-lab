# Module 3: CI/CD Pipelines - Quick Reference

## GitHub Actions

### Workflow Syntax

```yaml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
    paths: ['src/**', '*.json']
    paths-ignore: ['**.md', 'docs/**']
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 2 * * *'
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [dev, staging, prod]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
    permissions:
      contents: read
      packages: write
      id-token: write
    
    outputs:
      image-tag: ${{ steps.meta.outputs.tags }}
    
    steps:
      - uses: actions/checkout@v4
      - run: echo "Building..."
```

### Common Actions

```yaml
# Checkout code
- uses: actions/checkout@v4
  with:
    fetch-depth: 0  # Full history

# Setup Node.js
- uses: actions/setup-node@v4
  with:
    node-version: '20'
    cache: 'npm'

# Setup Python
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: 'pip'

# Setup Go
- uses: actions/setup-go@v5
  with:
    go-version: '1.22'
    cache: true

# Cache dependencies
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-

# Upload artifacts
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/
    retention-days: 7

# Download artifacts
- uses: actions/download-artifact@v4
  with:
    name: build-output
    path: dist/
```

### Matrix Builds

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        os: [ubuntu-latest, macos-latest]
        node: [18, 20, 22]
        include:
          - os: ubuntu-latest
            node: 20
            coverage: true
        exclude:
          - os: macos-latest
            node: 18
    steps:
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
```

### Reusable Workflows

```yaml
# .github/workflows/reusable.yaml
on:
  workflow_call:
    inputs:
      environment:
        type: string
        required: true
    secrets:
      deploy-token:
        required: true
    outputs:
      url:
        value: ${{ jobs.deploy.outputs.url }}

jobs:
  deploy:
    runs-on: ubuntu-latest
    outputs:
      url: ${{ steps.deploy.outputs.url }}
    steps:
      - run: echo "Deploying to ${{ inputs.environment }}"
```

```yaml
# Calling workflow
jobs:
  deploy:
    uses: ./.github/workflows/reusable.yaml
    with:
      environment: production
    secrets:
      deploy-token: ${{ secrets.DEPLOY_TOKEN }}
```

### Conditional Execution

```yaml
jobs:
  deploy:
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to prod
        if: ${{ success() && github.event_name == 'push' }}
        run: deploy.sh

      - name: Notify on failure
        if: ${{ failure() }}
        run: notify.sh

      - name: Always cleanup
        if: ${{ always() }}
        run: cleanup.sh
```

---

## Docker & Container Builds

### Dockerfile Best Practices

```dockerfile
# Multi-stage build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY src/ ./src/
RUN npm run build

# Production image
FROM node:20-alpine
LABEL org.opencontainers.image.source="https://github.com/org/repo"

RUN addgroup -S app && adduser -S app -G app
WORKDIR /app
COPY --from=builder --chown=app:app /app/dist ./dist
COPY --from=builder --chown=app:app /app/node_modules ./node_modules

USER app
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

### Docker Build Action

```yaml
- name: Set up Buildx
  uses: docker/setup-buildx-action@v3

- name: Login to GHCR
  uses: docker/login-action@v3
  with:
    registry: ghcr.io
    username: ${{ github.actor }}
    password: ${{ secrets.GITHUB_TOKEN }}

- name: Build and push
  uses: docker/build-push-action@v5
  with:
    context: .
    push: true
    tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
    cache-from: type=gha
    cache-to: type=gha,mode=max
    platforms: linux/amd64,linux/arm64
```

### Buildah Commands

```bash
# Build image
buildah bud -t myapp:latest .

# Build from Dockerfile
buildah bud -f Dockerfile.prod -t myapp:prod .

# Push image
buildah push myapp:latest docker://registry.example.com/myapp:latest

# Login to registry
buildah login -u user -p pass registry.example.com

# List images
buildah images

# Remove image
buildah rmi myapp:latest
```

### Trivy Scanning

```yaml
# Scan filesystem
- uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    scan-ref: '.'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'

# Scan container image
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: 'ghcr.io/org/app:latest'
    format: 'sarif'
    output: 'trivy-results.sarif'
```

### Cosign Image Signing

```bash
# Generate key pair
cosign generate-key-pair

# Sign image
cosign sign --key cosign.key ghcr.io/org/app@sha256:digest

# Verify signature
cosign verify --key cosign.pub ghcr.io/org/app:latest

# Keyless signing (CI)
cosign sign --yes ghcr.io/org/app@sha256:digest
```

---

## Tekton Pipelines

### Task Definition

```yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-task
spec:
  params:
    - name: image
      type: string
  workspaces:
    - name: source
  results:
    - name: digest
      description: Image digest
  steps:
    - name: build
      image: gcr.io/kaniko-project/executor:latest
      args:
        - "--dockerfile=$(workspaces.source.path)/Dockerfile"
        - "--destination=$(params.image)"
        - "--digest-file=$(results.digest.path)"
```

### Pipeline Definition

```yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ci-pipeline
spec:
  params:
    - name: git-url
    - name: image-name
  workspaces:
    - name: shared-workspace
  tasks:
    - name: clone
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.git-url)
      workspaces:
        - name: output
          workspace: shared-workspace

    - name: build
      runAfter: [clone]
      taskRef:
        name: build-task
      params:
        - name: image
          value: $(params.image-name)
      workspaces:
        - name: source
          workspace: shared-workspace
```

### PipelineRun

```yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ci-pipeline-run-
spec:
  pipelineRef:
    name: ci-pipeline
  params:
    - name: git-url
      value: https://github.com/org/repo.git
    - name: image-name
      value: ghcr.io/org/app:latest
  workspaces:
    - name: shared-workspace
      volumeClaimTemplate:
        spec:
          accessModes: [ReadWriteOnce]
          resources:
            requests:
              storage: 1Gi
```

### Tekton CLI Commands

```bash
# List resources
tkn task list
tkn pipeline list
tkn pipelinerun list
tkn taskrun list

# Start pipeline
tkn pipeline start ci-pipeline \
  -p git-url=https://github.com/org/repo.git \
  -w name=shared-workspace,claimName=workspace-pvc

# View logs
tkn pipelinerun logs ci-pipeline-run-abc -f

# Describe run
tkn pipelinerun describe ci-pipeline-run-abc

# Delete old runs
tkn pipelinerun delete --keep 5
```

### Triggers

```yaml
# EventListener
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
spec:
  triggers:
    - triggerRef: github-push-trigger
  resources:
    kubernetesResource:
      serviceType: LoadBalancer

# Trigger
apiVersion: triggers.tekton.dev/v1beta1
kind: Trigger
metadata:
  name: github-push-trigger
spec:
  interceptors:
    - ref:
        name: github
      params:
        - name: eventTypes
          value: [push]
  bindings:
    - ref: github-binding
  template:
    ref: pipeline-template

# TriggerBinding
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-binding
spec:
  params:
    - name: git-url
      value: $(body.repository.clone_url)
    - name: git-revision
      value: $(body.after)

# TriggerTemplate
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: pipeline-template
spec:
  params:
    - name: git-url
    - name: git-revision
  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: triggered-run-
      spec:
        pipelineRef:
          name: ci-pipeline
        params:
          - name: git-url
            value: $(tt.params.git-url)
```

---

## GitOps Integration

### ArgoCD Image Updater Annotations

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    # Image list
    argocd-image-updater.argoproj.io/image-list: app=ghcr.io/org/app

    # Update strategy: semver, latest, digest, name
    argocd-image-updater.argoproj.io/app.update-strategy: semver

    # Allow/ignore tags
    argocd-image-updater.argoproj.io/app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
    argocd-image-updater.argoproj.io/app.ignore-tags: latest,dev-*

    # Write-back method: git, argocd
    argocd-image-updater.argoproj.io/write-back-method: git
    argocd-image-updater.argoproj.io/git-branch: main
    argocd-image-updater.argoproj.io/write-back-target: kustomization
```

### Kustomize Image Update

```yaml
# kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

images:
  - name: myapp
    newName: ghcr.io/org/myapp
    newTag: v1.2.3
```

```bash
# Update image
kustomize edit set image myapp=ghcr.io/org/myapp:v1.2.4
```

### ArgoCD CLI Commands

```bash
# Login
argocd login argocd.example.com

# List apps
argocd app list

# Sync app
argocd app sync myapp

# Get app status
argocd app get myapp

# Rollback
argocd app rollback myapp <revision>

# History
argocd app history myapp

# Diff
argocd app diff myapp

# Set parameters
argocd app set myapp -p image.tag=v1.2.4
```

---

## Testing & Quality

### Test Workflow Pattern

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Unit tests
        run: npm test -- --coverage

      - name: Check coverage
        run: |
          COVERAGE=$(jq '.total.lines.pct' coverage/coverage-summary.json)
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            exit 1
          fi

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
```

### Security Scanning

```yaml
# Trivy filesystem scan
- uses: aquasecurity/trivy-action@master
  with:
    scan-type: 'fs'
    severity: 'CRITICAL,HIGH'
    exit-code: '1'

# Gitleaks secret scan
- uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

# OWASP ZAP scan
- uses: zaproxy/action-baseline@v0.10.0
  with:
    target: 'https://app.example.com'
```

### SonarQube Integration

```yaml
- uses: SonarSource/sonarqube-scan-action@master
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
    SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL }}

- uses: SonarSource/sonarqube-quality-gate-action@master
  timeout-minutes: 5
  env:
    SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
```

---

## Performance Optimization

### Caching Strategies

```yaml
# Node.js
- uses: actions/setup-node@v4
  with:
    cache: 'npm'

# Python
- uses: actions/setup-python@v5
  with:
    cache: 'pip'

# Go
- uses: actions/setup-go@v5
  with:
    cache: true

# Custom cache
- uses: actions/cache@v4
  with:
    path: |
      ~/.cache
      node_modules
    key: ${{ runner.os }}-${{ hashFiles('**/lockfiles') }}
    restore-keys: |
      ${{ runner.os }}-

# Docker layer cache
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max
```

### Parallel Execution

```yaml
jobs:
  # Independent jobs run in parallel
  lint:
    runs-on: ubuntu-latest
    steps: [...]

  test:
    runs-on: ubuntu-latest
    steps: [...]

  security:
    runs-on: ubuntu-latest
    steps: [...]

  # Dependent job waits
  build:
    needs: [lint, test, security]
    runs-on: ubuntu-latest
    steps: [...]
```

### Path Filtering

```yaml
on:
  push:
    paths:
      - 'src/**'
      - 'package*.json'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

### Concurrency Control

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
```

---

## Common Patterns

### Semantic Versioning

```yaml
- name: Bump version
  id: version
  uses: mathieudutour/github-tag-action@v6.1
  with:
    github_token: ${{ secrets.GITHUB_TOKEN }}
    default_bump: patch
    release_branches: main

- name: Create release
  uses: actions/create-release@v1
  with:
    tag_name: ${{ steps.version.outputs.new_tag }}
    release_name: Release ${{ steps.version.outputs.new_tag }}
```

### Environment Deployments

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com
    steps:
      - name: Deploy
        run: deploy.sh
```

### Notifications

```yaml
- name: Slack notification
  uses: slackapi/slack-github-action@v1.24.0
  with:
    channel-id: 'deployments'
    payload: |
      {
        "text": "Deployed ${{ github.sha }} to production"
      }
  env:
    SLACK_BOT_TOKEN: ${{ secrets.SLACK_BOT_TOKEN }}
```

---

## Troubleshooting

### GitHub Actions

```bash
# Enable debug logging
# Set repository secret: ACTIONS_STEP_DEBUG = true

# Check runner logs
# Settings → Actions → Runners → View logs

# Validate workflow syntax
# Use actionlint or GitHub workflow editor
```

### Tekton

```bash
# Check pipeline status
tkn pipelinerun describe <run-name>

# View step logs
tkn pipelinerun logs <run-name> -f

# Debug pod
kubectl describe pod <task-pod>
kubectl logs <task-pod> -c step-<step-name>

# Check events
kubectl get events --field-selector involvedObject.name=<pod>
```

### Container Builds

```bash
# Debug build
docker build --progress=plain -t myapp .

# Check image layers
docker history myapp:latest

# Inspect image
docker inspect myapp:latest

# Scan for vulnerabilities
trivy image myapp:latest
```

---

## Quick Commands Cheat Sheet

| Task | Command |
|------|---------|
| Validate workflow | `actionlint .github/workflows/*.yaml` |
| Run locally | `act -j build` |
| Build image | `docker build -t app:tag .` |
| Push image | `docker push registry/app:tag` |
| Scan image | `trivy image app:tag` |
| Sign image | `cosign sign app@sha256:digest` |
| Start pipeline | `tkn pipeline start ci-pipeline` |
| View logs | `tkn pipelinerun logs run-name -f` |
| Sync ArgoCD | `argocd app sync myapp` |
| Rollback | `argocd app rollback myapp` |
