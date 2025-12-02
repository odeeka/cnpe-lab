# Lab 3: Tekton Pipelines

## Overview

This lab covers Tekton, a Kubernetes-native CI/CD framework. You will learn to install Tekton, create Tasks and Pipelines, configure Workspaces, implement Triggers for event-driven pipelines, and integrate with the Tekton Catalog for reusable components.

## Time to Complete

Estimated time: 3-4 hours

## Prerequisites

Before starting this lab, ensure you have:

- Completed Labs 1-2 of this module
- Running kind cluster
- `kubectl` configured
- Container registry access

## Learning Objectives

By the end of this lab, you will be able to:

1. Install Tekton Pipelines on Kubernetes
2. Create and run Tekton Tasks
3. Build Pipelines from multiple Tasks
4. Configure Workspaces for data sharing
5. Use Parameters for flexibility
6. Implement Triggers for event-driven execution
7. Use Tekton Catalog tasks

## Tekton Architecture

```text
Tekton Components:

┌─────────────────────────────────────────────────────────────────┐
│                      Kubernetes Cluster                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Tekton Pipelines│  │ Tekton Triggers │  │ Tekton Dashboard│ │
│  │   Controller    │  │   Controller    │  │                 │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│                                                                 │
│  Custom Resources:                                              │
│  ┌─────────┐ ┌──────────┐ ┌─────────────┐ ┌──────────────────┐ │
│  │  Task   │ │ Pipeline │ │ TaskRun     │ │ PipelineRun      │ │
│  └─────────┘ └──────────┘ └─────────────┘ └──────────────────┘ │
│                                                                 │
│  Trigger Resources:                                             │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │EventListener│ │TriggerBinding│ │ TriggerTemplate          │ │
│  └─────────────┘ └──────────────┘ └──────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Pipeline Flow:

  ┌─────────────────────────────────────────────────────────────┐
  │                      PipelineRun                             │
  ├─────────────────────────────────────────────────────────────┤
  │  ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐  │
  │  │ TaskRun │───▶│ TaskRun │───▶│ TaskRun │───▶│ TaskRun │  │
  │  │  (git)  │    │ (build) │    │ (test)  │    │(deploy) │  │
  │  └─────────┘    └─────────┘    └─────────┘    └─────────┘  │
  │       │              │              │              │        │
  │       └──────────────┴──────────────┴──────────────┘        │
  │                    Shared Workspace                          │
  └─────────────────────────────────────────────────────────────┘
```

## Lab Exercises

### Exercise 1: Installing Tekton

#### Step 1: Install Tekton Pipelines

```bash
# Install Tekton Pipelines
kubectl apply -f https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml

# Wait for Tekton to be ready
kubectl wait --for=condition=available deployment/tekton-pipelines-controller -n tekton-pipelines --timeout=300s

# Verify installation
kubectl get pods -n tekton-pipelines
```

#### Step 2: Install Tekton Triggers

```bash
# Install Tekton Triggers
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/release.yaml

# Install Tekton Interceptors
kubectl apply -f https://storage.googleapis.com/tekton-releases/triggers/latest/interceptors.yaml

# Wait for Triggers to be ready
kubectl wait --for=condition=available deployment/tekton-triggers-controller -n tekton-pipelines --timeout=300s
```

#### Step 3: Install Tekton Dashboard (Optional)

```bash
# Install Dashboard
kubectl apply -f https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml

# Access Dashboard
kubectl port-forward svc/tekton-dashboard -n tekton-pipelines 9097:9097

# Open browser at http://localhost:9097
```

#### Step 4: Install Tekton CLI (tkn)

```bash
# Linux
curl -LO https://github.com/tektoncd/cli/releases/latest/download/tkn_Linux_x86_64.tar.gz
tar xvzf tkn_Linux_x86_64.tar.gz
sudo mv tkn /usr/local/bin/

# macOS
brew install tektoncd-cli

# Verify
tkn version
```

### Exercise 2: Creating Your First Task

#### Step 1: Simple Task

```yaml
# hello-task.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: hello
spec:
  description: Simple hello world task
  params:
    - name: name
      type: string
      description: Name to greet
      default: "World"
  steps:
    - name: greet
      image: alpine:3.18
      script: |
        #!/bin/sh
        echo "Hello, $(params.name)!"
        echo "Running in Tekton at $(date)"
```

Apply and run:

```bash
kubectl apply -f hello-task.yaml

# Run the task
tkn task start hello --param name=Tekton --showlog

# Or create a TaskRun
kubectl apply -f - <<EOF
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: hello-run-
spec:
  taskRef:
    name: hello
  params:
    - name: name
      value: "Platform Engineer"
EOF
```

#### Step 2: Task with Results

```yaml
# task-with-results.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: generate-build-id
spec:
  description: Generate a unique build ID
  results:
    - name: build-id
      description: The generated build ID
    - name: timestamp
      description: Build timestamp
  steps:
    - name: generate
      image: alpine:3.18
      script: |
        #!/bin/sh
        BUILD_ID="build-$(date +%Y%m%d-%H%M%S)-$(head /dev/urandom | tr -dc a-z0-9 | head -c 6)"
        TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

        echo -n "$BUILD_ID" > $(results.build-id.path)
        echo -n "$TIMESTAMP" > $(results.timestamp.path)

        echo "Generated Build ID: $BUILD_ID"
        echo "Timestamp: $TIMESTAMP"
```

### Exercise 3: Working with Workspaces

#### Step 1: Task with Workspace

```yaml
# git-clone-task.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: git-clone
spec:
  description: Clone a git repository
  params:
    - name: url
      type: string
      description: Git repository URL
    - name: revision
      type: string
      default: main
      description: Git revision to checkout
  workspaces:
    - name: output
      description: Workspace to clone the repo into
  results:
    - name: commit
      description: The commit SHA
  steps:
    - name: clone
      image: alpine/git:2.40.1
      script: |
        #!/bin/sh
        cd $(workspaces.output.path)
        git clone --depth 1 --branch $(params.revision) $(params.url) .
        COMMIT=$(git rev-parse HEAD)
        echo -n "$COMMIT" > $(results.commit.path)
        echo "Cloned $(params.url) at $COMMIT"
        ls -la
```

#### Step 2: Create PersistentVolumeClaim

```yaml
# workspace-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pipeline-workspace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

#### Step 3: Run Task with Workspace

```yaml
# git-clone-taskrun.yaml
apiVersion: tekton.dev/v1
kind: TaskRun
metadata:
  generateName: git-clone-run-
spec:
  taskRef:
    name: git-clone
  params:
    - name: url
      value: https://github.com/argoproj/argocd-example-apps
    - name: revision
      value: main
  workspaces:
    - name: output
      persistentVolumeClaim:
        claimName: pipeline-workspace
```

### Exercise 4: Building Pipelines

#### Step 1: Create Build Task

```yaml
# build-task.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: build-app
spec:
  description: Build the application
  params:
    - name: image
      type: string
      description: Image to build
  workspaces:
    - name: source
      description: Source code workspace
  results:
    - name: image-digest
      description: Digest of the built image
  steps:
    - name: build
      image: gcr.io/kaniko-project/executor:latest
      args:
        - --dockerfile=$(workspaces.source.path)/Dockerfile
        - --context=$(workspaces.source.path)
        - --destination=$(params.image)
        - --digest-file=$(results.image-digest.path)
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
  volumes:
    - name: docker-config
      secret:
        secretName: docker-registry-secret
        items:
          - key: .dockerconfigjson
            path: config.json
```

#### Step 2: Create Test Task

```yaml
# test-task.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: run-tests
spec:
  description: Run application tests
  workspaces:
    - name: source
      description: Source code workspace
  results:
    - name: test-result
      description: Test result (pass/fail)
  steps:
    - name: test
      image: golang:1.21
      workingDir: $(workspaces.source.path)
      script: |
        #!/bin/bash
        echo "Running tests..."
        # Run tests if go project
        if [ -f "go.mod" ]; then
          go test -v ./... && echo -n "pass" > $(results.test-result.path) || echo -n "fail" > $(results.test-result.path)
        else
          echo "No go.mod found, skipping tests"
          echo -n "skip" > $(results.test-result.path)
        fi
```

#### Step 3: Create Pipeline

```yaml
# ci-pipeline.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: ci-pipeline
spec:
  description: Complete CI pipeline
  params:
    - name: repo-url
      type: string
      description: Git repository URL
    - name: revision
      type: string
      default: main
    - name: image
      type: string
      description: Container image to build

  workspaces:
    - name: shared-workspace
      description: Shared workspace for pipeline

  tasks:
    - name: fetch-source
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.repo-url)
        - name: revision
          value: $(params.revision)
      workspaces:
        - name: output
          workspace: shared-workspace

    - name: run-tests
      taskRef:
        name: run-tests
      runAfter:
        - fetch-source
      workspaces:
        - name: source
          workspace: shared-workspace

    - name: build-image
      taskRef:
        name: build-app
      runAfter:
        - run-tests
      params:
        - name: image
          value: $(params.image)
      workspaces:
        - name: source
          workspace: shared-workspace

  results:
    - name: commit-sha
      description: The commit SHA of the built code
      value: $(tasks.fetch-source.results.commit)
    - name: image-digest
      description: The image digest
      value: $(tasks.build-image.results.image-digest)
```

#### Step 4: Run Pipeline

```yaml
# ci-pipelinerun.yaml
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: ci-pipeline-run-
spec:
  pipelineRef:
    name: ci-pipeline
  params:
    - name: repo-url
      value: https://github.com/your-org/your-app
    - name: revision
      value: main
    - name: image
      value: ghcr.io/your-org/your-app:latest
  workspaces:
    - name: shared-workspace
      persistentVolumeClaim:
        claimName: pipeline-workspace
```

Run with CLI:

```bash
tkn pipeline start ci-pipeline \
  --param repo-url=https://github.com/your-org/your-app \
  --param revision=main \
  --param image=ghcr.io/your-org/your-app:latest \
  --workspace name=shared-workspace,claimName=pipeline-workspace \
  --showlog
```

### Exercise 5: Tekton Triggers

#### Step 1: Create TriggerTemplate

```yaml
# trigger-template.yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerTemplate
metadata:
  name: ci-trigger-template
spec:
  params:
    - name: git-repo-url
      description: Git repository URL
    - name: git-revision
      description: Git revision
      default: main
    - name: git-commit-sha
      description: Git commit SHA

  resourcetemplates:
    - apiVersion: tekton.dev/v1
      kind: PipelineRun
      metadata:
        generateName: ci-pipeline-triggered-
        labels:
          tekton.dev/trigger: "true"
      spec:
        pipelineRef:
          name: ci-pipeline
        params:
          - name: repo-url
            value: $(tt.params.git-repo-url)
          - name: revision
            value: $(tt.params.git-revision)
          - name: image
            value: ghcr.io/your-org/app:$(tt.params.git-commit-sha)
        workspaces:
          - name: shared-workspace
            volumeClaimTemplate:
              spec:
                accessModes:
                  - ReadWriteOnce
                resources:
                  requests:
                    storage: 1Gi
```

#### Step 2: Create TriggerBinding

```yaml
# trigger-binding.yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: TriggerBinding
metadata:
  name: github-push-binding
spec:
  params:
    - name: git-repo-url
      value: $(body.repository.clone_url)
    - name: git-revision
      value: $(body.ref)
    - name: git-commit-sha
      value: $(body.after)
```

#### Step 3: Create EventListener

```yaml
# event-listener.yaml
apiVersion: triggers.tekton.dev/v1beta1
kind: EventListener
metadata:
  name: github-listener
spec:
  serviceAccountName: tekton-triggers-sa
  triggers:
    - name: github-push
      interceptors:
        - ref:
            name: github
          params:
            - name: secretRef
              value:
                secretName: github-webhook-secret
                secretKey: token
            - name: eventTypes
              value:
                - push
        - ref:
            name: cel
          params:
            - name: filter
              value: "body.ref == 'refs/heads/main'"
      bindings:
        - ref: github-push-binding
      template:
        ref: ci-trigger-template
```

#### Step 4: Create Service Account and RBAC

```yaml
# triggers-rbac.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tekton-triggers-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tekton-triggers-role
rules:
  - apiGroups: ["triggers.tekton.dev"]
    resources: ["eventlisteners", "triggerbindings", "triggertemplates", "triggers"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["tekton.dev"]
    resources: ["pipelineruns", "taskruns"]
    verbs: ["create", "delete", "get", "list", "watch"]
  - apiGroups: [""]
    resources: ["configmaps", "secrets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["create", "delete", "get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tekton-triggers-rolebinding
subjects:
  - kind: ServiceAccount
    name: tekton-triggers-sa
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: tekton-triggers-role
---
apiVersion: v1
kind: Secret
metadata:
  name: github-webhook-secret
type: Opaque
stringData:
  token: your-webhook-secret
```

#### Step 5: Expose EventListener

```bash
# Get the EventListener service
kubectl get svc el-github-listener

# For local testing, port-forward
kubectl port-forward svc/el-github-listener 8080:8080

# Test with curl
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{
    "ref": "refs/heads/main",
    "after": "abc123",
    "repository": {
      "clone_url": "https://github.com/your-org/your-app.git"
    }
  }'
```

### Exercise 6: Using Tekton Catalog

#### Step 1: Install Tekton Hub CLI

```bash
# Install tkn hub
tkn hub install task git-clone
tkn hub install task kaniko
tkn hub install task kubernetes-actions
```

#### Step 2: Use Catalog Tasks

```yaml
# pipeline-with-catalog.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: build-deploy-pipeline
spec:
  params:
    - name: repo-url
      type: string
    - name: image
      type: string
    - name: namespace
      type: string
      default: default

  workspaces:
    - name: shared-data
    - name: docker-credentials

  tasks:
    - name: clone
      taskRef:
        name: git-clone
        kind: Task
      params:
        - name: url
          value: $(params.repo-url)
      workspaces:
        - name: output
          workspace: shared-data

    - name: build-push
      taskRef:
        name: kaniko
        kind: Task
      runAfter:
        - clone
      params:
        - name: IMAGE
          value: $(params.image)
      workspaces:
        - name: source
          workspace: shared-data
        - name: dockerconfig
          workspace: docker-credentials

    - name: deploy
      taskRef:
        name: kubernetes-actions
        kind: Task
      runAfter:
        - build-push
      params:
        - name: script
          value: |
            kubectl set image deployment/app app=$(params.image) -n $(params.namespace)
            kubectl rollout status deployment/app -n $(params.namespace)
```

### Exercise 7: Pipeline Best Practices

#### Step 1: Parallel Tasks

```yaml
# parallel-pipeline.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: parallel-pipeline
spec:
  params:
    - name: repo-url
      type: string

  workspaces:
    - name: source

  tasks:
    - name: fetch
      taskRef:
        name: git-clone
      params:
        - name: url
          value: $(params.repo-url)
      workspaces:
        - name: output
          workspace: source

    # These run in parallel after fetch
    - name: lint
      taskRef:
        name: lint
      runAfter:
        - fetch
      workspaces:
        - name: source
          workspace: source

    - name: unit-test
      taskRef:
        name: unit-test
      runAfter:
        - fetch
      workspaces:
        - name: source
          workspace: source

    - name: security-scan
      taskRef:
        name: security-scan
      runAfter:
        - fetch
      workspaces:
        - name: source
          workspace: source

    # This waits for all parallel tasks
    - name: build
      taskRef:
        name: build
      runAfter:
        - lint
        - unit-test
        - security-scan
      workspaces:
        - name: source
          workspace: source
```

#### Step 2: Conditional Tasks with When

```yaml
# conditional-pipeline.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: conditional-pipeline
spec:
  params:
    - name: run-integration-tests
      type: string
      default: "true"
    - name: deploy-env
      type: string
      default: "dev"

  tasks:
    - name: build
      taskRef:
        name: build

    # Only run integration tests if param is true
    - name: integration-tests
      when:
        - input: $(params.run-integration-tests)
          operator: in
          values: ["true", "yes"]
      taskRef:
        name: integration-tests
      runAfter:
        - build

    # Only deploy to prod if deploy-env is prod
    - name: deploy-prod
      when:
        - input: $(params.deploy-env)
          operator: in
          values: ["prod", "production"]
      taskRef:
        name: deploy
      params:
        - name: environment
          value: production
      runAfter:
        - integration-tests

    # Deploy to dev otherwise
    - name: deploy-dev
      when:
        - input: $(params.deploy-env)
          operator: notin
          values: ["prod", "production"]
      taskRef:
        name: deploy
      params:
        - name: environment
          value: development
      runAfter:
        - build
```

#### Step 3: Finally Tasks

```yaml
# pipeline-with-finally.yaml
apiVersion: tekton.dev/v1
kind: Pipeline
metadata:
  name: pipeline-with-cleanup
spec:
  tasks:
    - name: build
      taskRef:
        name: build
    - name: test
      taskRef:
        name: test
      runAfter:
        - build

  finally:
    - name: cleanup
      taskRef:
        name: cleanup
      params:
        - name: status
          value: $(tasks.status)

    - name: notify
      taskRef:
        name: send-notification
      params:
        - name: pipeline-status
          value: $(tasks.status)
        - name: build-result
          value: $(tasks.build.status)
```

### Exercise 8: Debugging Tekton Pipelines

#### Step 1: View Pipeline Status

```bash
# List PipelineRuns
tkn pipelinerun list

# Get PipelineRun details
tkn pipelinerun describe <pipelinerun-name>

# Get logs
tkn pipelinerun logs <pipelinerun-name>

# Stream logs
tkn pipelinerun logs -f <pipelinerun-name>
```

#### Step 2: Debug Failed Tasks

```bash
# List TaskRuns
tkn taskrun list

# Get TaskRun details
tkn taskrun describe <taskrun-name>

# Get logs for specific step
tkn taskrun logs <taskrun-name> --step <step-name>

# Get all TaskRun logs
kubectl logs <pod-name> --all-containers
```

#### Step 3: Debug Task

```yaml
# debug-task.yaml
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: debug-task
spec:
  steps:
    - name: debug
      image: alpine:3.18
      script: |
        #!/bin/sh
        echo "=== Environment Variables ==="
        env | sort

        echo "=== Workspace Contents ==="
        ls -la $(workspaces.source.path) || echo "No workspace"

        echo "=== Current User ==="
        id

        echo "=== Available Tools ==="
        which git curl wget || echo "Tools check complete"

        # Keep container running for debugging
        # sleep 3600
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Install Tekton Pipelines and Triggers
- [ ] Create and run Tasks
- [ ] Build Pipelines with multiple Tasks
- [ ] Configure Workspaces for data sharing
- [ ] Use Results to pass data between Tasks
- [ ] Set up Triggers for event-driven execution
- [ ] Use tasks from Tekton Catalog
- [ ] Implement parallel and conditional execution
- [ ] Debug failed PipelineRuns

## Troubleshooting

### Task Fails to Start

```bash
# Check pod status
kubectl get pods

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check Tekton controller logs
kubectl logs -n tekton-pipelines deployment/tekton-pipelines-controller
```

### Workspace Issues

```bash
# Check PVC status
kubectl get pvc

# Check if workspace is mounted
kubectl describe pod <taskrun-pod>
```

### Trigger Not Firing

```bash
# Check EventListener logs
kubectl logs deployment/el-<eventlistener-name>

# Check EventListener service
kubectl get svc el-<eventlistener-name>

# Test with curl
curl -v http://<eventlistener-svc>:8080
```

## Key Takeaways

1. **Tasks**: Reusable units of work with steps
2. **Pipelines**: Orchestrate Tasks with dependencies
3. **Workspaces**: Share data between Tasks
4. **Results**: Pass values between Tasks
5. **Triggers**: Enable event-driven pipelines
6. **Catalog**: Leverage community-maintained Tasks
7. **When Expressions**: Conditional task execution
8. **Finally**: Cleanup and notification tasks

## Next Steps

In Lab 4, you will learn:

- Integrating CI pipelines with ArgoCD
- Implementing GitOps-style deployments
- Connecting Tekton with ArgoCD
- Image tag promotion strategies
