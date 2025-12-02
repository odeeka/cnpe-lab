# Lab 4: CI/CD Integration with GitOps

## Overview

This lab covers integrating CI pipelines with GitOps workflows. You will learn to connect CI systems (GitHub Actions, Tekton) with ArgoCD, implement image tag promotion strategies, configure ArgoCD Image Updater, and create end-to-end continuous deployment pipelines.

## Time to Complete

Estimated time: 2-3 hours

## Prerequisites

Before starting this lab, ensure you have:

- Completed Labs 1-3 of this module
- Completed Module 2: GitOps & Continuous Delivery
- Running kind cluster with ArgoCD installed
- GitHub repository with container registry access

## Learning Objectives

By the end of this lab, you will be able to:

1. Understand CI/CD integration patterns with GitOps
2. Connect CI pipelines to GitOps workflows
3. Implement image tag update strategies
4. Configure ArgoCD Image Updater
5. Create promotion workflows across environments
6. Handle rollbacks in a GitOps context

## CI/CD + GitOps Architecture

```text
CI/CD + GitOps Integration:

┌─────────────────────────────────────────────────────────────────┐
│                     Application Repository                       │
│  ├── src/                                                       │
│  ├── Dockerfile                                                 │
│  └── .github/workflows/ci.yaml                                  │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Push
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        CI Pipeline                               │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────────────────┐ │
│  │  Test   │──▶│  Build  │──▶│  Scan   │──▶│  Push to Registry │ │
│  └─────────┘  └─────────┘  └─────────┘  └──────────┬──────────┘ │
└────────────────────────────────────────────────────┼────────────┘
                                                     │
                    ┌────────────────────────────────┼────────────┐
                    │                                ▼            │
                    │  ┌─────────────────────────────────────┐    │
                    │  │        Container Registry           │    │
                    │  │  ghcr.io/org/app:v1.2.3             │    │
                    │  └─────────────────────────────────────┘    │
                    │                    │                        │
                    │    Option A        │        Option B        │
                    │    (CI Updates)    │        (Image Updater) │
                    │         │          │             │          │
                    │         ▼          │             ▼          │
┌───────────────────┼─────────────────┐  │  ┌─────────────────────┤
│  GitOps Repository│                 │  │  │  ArgoCD Image      ││
│  ├── base/        │                 │  │  │  Updater           ││
│  │   ├── deploy.yaml                │  │  │  (watches registry)││
│  │   └── kustomization.yaml         │  │  └─────────┬──────────┤│
│  └── overlays/    │                 │  │            │          ││
│      ├── dev/     │◀─ CI updates ───┘  │            │          ││
│      ├── staging/ │   image tag        │            │          ││
│      └── prod/    │                    │            ▼          ││
└───────────────────┼────────────────────┼────────────────────────┘│
                    │                    │                         │
                    └────────────────────┼─────────────────────────┘
                                         │
                                         ▼
                    ┌─────────────────────────────────────────────┐
                    │                  ArgoCD                      │
                    │  Syncs desired state to Kubernetes          │
                    └─────────────────────────────────────────────┘
```

## Lab Exercises

### Exercise 1: CI Pipeline Updates GitOps Repository

#### Step 1: Application Repository Structure

```text
app-repo/
├── src/
│   └── main.go
├── Dockerfile
├── go.mod
└── .github/
    └── workflows/
        └── ci.yaml
```

#### Step 2: GitOps Repository Structure

```text
gitops-repo/
├── apps/
│   └── my-app/
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   └── kustomization.yaml
│           ├── staging/
│           │   └── kustomization.yaml
│           └── prod/
│               └── kustomization.yaml
└── README.md
```

#### Step 3: CI Workflow with GitOps Update

```yaml
# .github/workflows/ci.yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  GITOPS_REPO: your-org/gitops-repo

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
      image-digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Container Registry
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
            type=sha,prefix=sha-
            type=semver,pattern={{version}}
            type=ref,event=branch

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  update-gitops:
    needs: build
    runs-on: ubuntu-latest

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.GITOPS_REPO }}
          token: ${{ secrets.GITOPS_PAT }}
          path: gitops

      - name: Setup Kustomize
        uses: imranismail/setup-kustomize@v2

      - name: Update image tag
        run: |
          cd gitops/apps/my-app/overlays/dev
          kustomize edit set image app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.image-tag }}

      - name: Commit and push
        run: |
          cd gitops
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git diff --staged --quiet || git commit -m "Update my-app to ${{ needs.build.outputs.image-tag }}"
          git push
```

### Exercise 2: Tekton Pipeline with GitOps Update

#### Step 1: Create Update GitOps Task

```yaml
# update-gitops-task.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: update-gitops
spec:
  description: Update image tag in GitOps repository
  params:
    - name: gitops-repo-url
      type: string
      description: GitOps repository URL
    - name: gitops-repo-branch
      type: string
      default: main
    - name: app-name
      type: string
      description: Application name
    - name: environment
      type: string
      default: dev
    - name: image
      type: string
      description: Full image reference with tag

  workspaces:
    - name: ssh-credentials
      description: SSH key for GitOps repo access

  steps:
    - name: clone-gitops
      image: alpine/git:2.40.1
      script: |
        #!/bin/sh
        mkdir -p ~/.ssh
        cp $(workspaces.ssh-credentials.path)/id_rsa ~/.ssh/
        chmod 600 ~/.ssh/id_rsa
        ssh-keyscan github.com >> ~/.ssh/known_hosts

        git clone $(params.gitops-repo-url) /workspace/gitops
        cd /workspace/gitops
        git checkout $(params.gitops-repo-branch)

    - name: update-image
      image: registry.k8s.io/kustomize/kustomize:v5.0.3
      workingDir: /workspace/gitops
      script: |
        #!/bin/sh
        cd apps/$(params.app-name)/overlays/$(params.environment)
        kustomize edit set image app=$(params.image)

        echo "Updated kustomization.yaml:"
        cat kustomization.yaml

    - name: commit-push
      image: alpine/git:2.40.1
      workingDir: /workspace/gitops
      script: |
        #!/bin/sh
        git config user.name "Tekton Pipeline"
        git config user.email "tekton@example.com"

        git add .
        if git diff --staged --quiet; then
          echo "No changes to commit"
        else
          git commit -m "Update $(params.app-name) to $(params.image) in $(params.environment)"
          git push origin $(params.gitops-repo-branch)
        fi
```

#### Step 2: Complete Tekton Pipeline

```yaml
# ci-cd-pipeline.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ci-cd-pipeline
spec:
  params:
    - name: app-repo-url
      type: string
    - name: app-repo-revision
      type: string
      default: main
    - name: gitops-repo-url
      type: string
    - name: image-registry
      type: string
    - name: image-name
      type: string
    - name: environment
      type: string
      default: dev

  workspaces:
    - name: source
    - name: docker-credentials
    - name: ssh-credentials

  tasks:
    - name: fetch-source
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.app-repo-url)
        - name: revision
          value: $(params.app-repo-revision)
      workspaces:
        - name: output
          workspace: source

    - name: build-push
      taskRef:
        name: kaniko
      runAfter:
        - fetch-source
      params:
        - name: IMAGE
          value: $(params.image-registry)/$(params.image-name):$(tasks.fetch-source.results.commit)
      workspaces:
        - name: source
          workspace: source
        - name: dockerconfig
          workspace: docker-credentials

    - name: update-gitops
      taskRef:
        name: update-gitops
      runAfter:
        - build-push
      params:
        - name: gitops-repo-url
          value: $(params.gitops-repo-url)
        - name: app-name
          value: $(params.image-name)
        - name: environment
          value: $(params.environment)
        - name: image
          value: $(params.image-registry)/$(params.image-name):$(tasks.fetch-source.results.commit)
      workspaces:
        - name: ssh-credentials
          workspace: ssh-credentials
```

### Exercise 3: ArgoCD Image Updater

ArgoCD Image Updater automatically updates image tags based on registry changes.

#### Step 1: Install ArgoCD Image Updater

```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml

# Verify installation
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-image-updater
```

#### Step 2: Configure Registry Access

```yaml
# argocd-image-updater-config.yaml
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
        credentials: secret:argocd/ghcr-credentials#token
        default: true

      - name: Docker Hub
        prefix: docker.io
        api_url: https://registry-1.docker.io
        credentials: pullsecret:argocd/dockerhub-credentials

  log.level: debug
```

#### Step 3: Create Registry Credentials

```yaml
# ghcr-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ghcr-credentials
  namespace: argocd
type: Opaque
stringData:
  token: ghp_your_github_token
```

#### Step 4: Configure Application for Image Updater

```yaml
# app-with-image-updater.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
  annotations:
    # Image list to track
    argocd-image-updater.argoproj.io/image-list: app=ghcr.io/your-org/my-app

    # Update strategy
    argocd-image-updater.argoproj.io/app.update-strategy: semver

    # Allowed tags (regex)
    argocd-image-updater.argoproj.io/app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$

    # Write back method
    argocd-image-updater.argoproj.io/write-back-method: git

    # Git branch
    argocd-image-updater.argoproj.io/git-branch: main

    # Kustomize image parameter
    argocd-image-updater.argoproj.io/app.kustomize.image-name: app
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-repo
    path: apps/my-app/overlays/dev
    targetRevision: HEAD
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

#### Step 5: Update Strategies

```yaml
# Semver - follow semantic versioning
argocd-image-updater.argoproj.io/app.update-strategy: semver
argocd-image-updater.argoproj.io/app.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$

# Latest - newest build
argocd-image-updater.argoproj.io/app.update-strategy: latest
argocd-image-updater.argoproj.io/app.allow-tags: regexp:^main-[a-f0-9]+$

# Digest - track specific digest
argocd-image-updater.argoproj.io/app.update-strategy: digest

# Name - alphabetically latest
argocd-image-updater.argoproj.io/app.update-strategy: name
argocd-image-updater.argoproj.io/app.allow-tags: regexp:^build-[0-9]+$
```

### Exercise 4: Environment Promotion Workflow

#### Step 1: Promotion Pipeline with GitHub Actions

```yaml
# .github/workflows/promote.yaml
name: Promote to Environment

on:
  workflow_dispatch:
    inputs:
      source-env:
        description: 'Source environment'
        required: true
        type: choice
        options:
          - dev
          - staging
      target-env:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - staging
          - prod
      app-name:
        description: 'Application name'
        required: true
        type: string

jobs:
  promote:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4

      - name: Setup Kustomize
        uses: imranismail/setup-kustomize@v2

      - name: Get current image from source
        id: source-image
        run: |
          cd apps/${{ inputs.app-name }}/overlays/${{ inputs.source-env }}
          IMAGE=$(kustomize build . | grep 'image:' | head -1 | awk '{print $2}')
          echo "image=$IMAGE" >> $GITHUB_OUTPUT
          echo "Source image: $IMAGE"

      - name: Update target environment
        run: |
          cd apps/${{ inputs.app-name }}/overlays/${{ inputs.target-env }}
          kustomize edit set image app=${{ steps.source-image.outputs.image }}

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Promote ${{ inputs.app-name }} from ${{ inputs.source-env }} to ${{ inputs.target-env }}"
          body: |
            ## Promotion Request

            - **Application**: ${{ inputs.app-name }}
            - **Source**: ${{ inputs.source-env }}
            - **Target**: ${{ inputs.target-env }}
            - **Image**: ${{ steps.source-image.outputs.image }}

            Triggered by: @${{ github.actor }}
          branch: promote-${{ inputs.app-name }}-${{ inputs.target-env }}
          labels: |
            promotion
            ${{ inputs.target-env }}
```

#### Step 2: Automated Promotion with Tekton

```yaml
# promotion-pipeline.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: environment-promotion
spec:
  params:
    - name: gitops-repo-url
      type: string
    - name: app-name
      type: string
    - name: source-env
      type: string
    - name: target-env
      type: string

  workspaces:
    - name: ssh-credentials

  tasks:
    - name: clone-gitops
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.gitops-repo-url)
      workspaces:
        - name: output
          workspace: source

    - name: get-source-image
      runAfter:
        - clone-gitops
      taskSpec:
        params:
          - name: app-name
            type: string
          - name: source-env
            type: string
        workspaces:
          - name: source
        results:
          - name: image
        steps:
          - name: extract-image
            image: registry.k8s.io/kustomize/kustomize:v5.0.3
            script: |
              #!/bin/sh
              cd $(workspaces.source.path)/apps/$(params.app-name)/overlays/$(params.source-env)
              IMAGE=$(kustomize build . | grep 'image:' | head -1 | awk '{print $2}')
              echo -n "$IMAGE" > $(results.image.path)
      params:
        - name: app-name
          value: $(params.app-name)
        - name: source-env
          value: $(params.source-env)
      workspaces:
        - name: source
          workspace: source

    - name: update-target
      runAfter:
        - get-source-image
      taskRef:
        name: update-gitops
      params:
        - name: gitops-repo-url
          value: $(params.gitops-repo-url)
        - name: app-name
          value: $(params.app-name)
        - name: environment
          value: $(params.target-env)
        - name: image
          value: $(tasks.get-source-image.results.image)
      workspaces:
        - name: ssh-credentials
          workspace: ssh-credentials
```

### Exercise 5: Rollback Strategies

#### Step 1: Git-Based Rollback

```yaml
# .github/workflows/rollback.yaml
name: Rollback Deployment

on:
  workflow_dispatch:
    inputs:
      app-name:
        description: 'Application name'
        required: true
        type: string
      environment:
        description: 'Environment'
        required: true
        type: choice
        options:
          - dev
          - staging
          - prod
      commits-back:
        description: 'Number of commits to roll back'
        required: true
        type: number
        default: 1

jobs:
  rollback:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Get previous image
        id: previous
        run: |
          cd apps/${{ inputs.app-name }}/overlays/${{ inputs.environment }}
          PREVIOUS=$(git log --oneline -n ${{ inputs.commits-back }} -- . | tail -1 | awk '{print $1}')
          git checkout $PREVIOUS -- kustomization.yaml
          IMAGE=$(grep 'newTag:' kustomization.yaml | awk '{print $2}')
          echo "image=$IMAGE" >> $GITHUB_OUTPUT
          echo "Rolling back to: $IMAGE"

      - name: Commit rollback
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Rollback ${{ inputs.app-name }} in ${{ inputs.environment }} to ${{ steps.previous.outputs.image }}"
          git push
```

#### Step 2: ArgoCD Rollback

```bash
# List application history
argocd app history my-app

# Rollback to previous version
argocd app rollback my-app <history-id>

# Rollback with CLI
argocd app set my-app --revision <previous-commit-sha>
argocd app sync my-app
```

### Exercise 6: Complete CI/CD Pipeline Example

#### Step 1: Full GitHub Actions Pipeline

```yaml
# .github/workflows/complete-cicd.yaml
name: Complete CI/CD Pipeline

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'Dockerfile'
  pull_request:
    branches: [main]
  release:
    types: [published]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}
  GITOPS_REPO: your-org/gitops-repo

jobs:
  # ===================
  # CI Jobs
  # ===================
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run tests
        run: make test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run linter
        run: make lint

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run security scan
        uses: securego/gosec@master

  # ===================
  # Build Job
  # ===================
  build:
    needs: [test, lint, security-scan]
    runs-on: ubuntu-latest
    outputs:
      image-tag: ${{ steps.meta.outputs.version }}
      image-digest: ${{ steps.build.outputs.digest }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
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
            type=sha,prefix=sha-
            type=semver,pattern={{version}},enable=${{ github.event_name == 'release' }}
            type=raw,value=latest,enable=${{ github.ref == 'refs/heads/main' }}

      - name: Build and push
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  # ===================
  # Image Scanning
  # ===================
  scan:
    needs: build
    if: github.event_name != 'pull_request'
    runs-on: ubuntu-latest

    steps:
      - name: Run Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.image-tag }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'

  # ===================
  # Deploy to Dev
  # ===================
  deploy-dev:
    needs: [build, scan]
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: development

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.GITOPS_REPO }}
          token: ${{ secrets.GITOPS_PAT }}

      - name: Update dev image
        run: |
          cd apps/my-app/overlays/dev
          kustomize edit set image app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.image-tag }}

      - name: Commit and push
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Deploy to dev: ${{ needs.build.outputs.image-tag }}"
          git push

  # ===================
  # Deploy to Staging (Release)
  # ===================
  deploy-staging:
    needs: build
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
    environment: staging

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.GITOPS_REPO }}
          token: ${{ secrets.GITOPS_PAT }}

      - name: Update staging image
        run: |
          cd apps/my-app/overlays/staging
          kustomize edit set image app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.image-tag }}

      - name: Commit and push
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Deploy to staging: ${{ github.event.release.tag_name }}"
          git push

  # ===================
  # Deploy to Production (Manual)
  # ===================
  deploy-prod:
    needs: deploy-staging
    if: github.event_name == 'release'
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://app.example.com

    steps:
      - name: Checkout GitOps repo
        uses: actions/checkout@v4
        with:
          repository: ${{ env.GITOPS_REPO }}
          token: ${{ secrets.GITOPS_PAT }}

      - name: Update prod image
        run: |
          cd apps/my-app/overlays/prod
          kustomize edit set image app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.image-tag }}

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Production deploy: ${{ github.event.release.tag_name }}"
          body: |
            ## Production Deployment

            - Version: ${{ github.event.release.tag_name }}
            - Image: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.image-tag }}

            Approve to deploy to production.
          branch: deploy-prod-${{ github.event.release.tag_name }}
          labels: production
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Set up CI pipeline that updates GitOps repository
- [ ] Configure Tekton pipeline with GitOps integration
- [ ] Install and configure ArgoCD Image Updater
- [ ] Implement different update strategies
- [ ] Create environment promotion workflows
- [ ] Implement rollback procedures
- [ ] Understand the complete CI/CD + GitOps flow

## Troubleshooting

### GitOps Update Failures

```bash
# Check CI job logs
# Look for git push errors

# Common issues:
# - Missing write permissions (PAT scope)
# - Branch protection rules
# - Merge conflicts
```

### ArgoCD Image Updater

```bash
# Check Image Updater logs
kubectl logs -n argocd deployment/argocd-image-updater

# Check application annotations
kubectl get application my-app -n argocd -o yaml | grep argocd-image-updater

# Test registry access
kubectl exec -n argocd deployment/argocd-image-updater -- argocd-image-updater test ghcr.io/org/app
```

### ArgoCD Sync Issues

```bash
# Check sync status
argocd app get my-app

# Force refresh
argocd app get my-app --refresh

# Check for drift
argocd app diff my-app
```

## Key Takeaways

1. **CI/CD Separation**: CI builds and tests, CD handles deployment via GitOps
2. **Git as Source of Truth**: All deployment changes flow through Git
3. **Image Updater**: Automates image tag updates based on registry
4. **Promotion**: Move images between environments via Git commits
5. **Rollback**: Simple with Git history and ArgoCD
6. **Environments**: Use GitHub Environments for approvals and protection

## Next Steps

In Lab 5, you will learn:

- Implementing comprehensive testing strategies
- Code coverage and quality gates
- Container vulnerability scanning
- Policy enforcement with OPA
