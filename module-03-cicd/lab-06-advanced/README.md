# Lab 6: Advanced Pipeline Patterns

## Introduction

In this lab, you'll learn advanced CI/CD patterns including pipeline optimization, caching strategies, parallelization, self-hosted runners, and cost optimization techniques for enterprise-scale pipelines.

## Learning Objectives

After completing this lab, you will be able to:

- Implement effective caching strategies for faster builds
- Configure parallel job execution and matrix builds
- Set up and manage self-hosted runners
- Monitor and optimize pipeline performance
- Implement cost-effective pipeline strategies
- Create reusable pipeline components

## Prerequisites

- Completed Labs 1-5 of this module
- Running Kubernetes cluster
- GitHub repository with Actions enabled
- Understanding of CI/CD concepts

## Duration

Estimated time: 90-120 minutes

---

## Exercise 1: Dependency Caching Strategies

### Step 1: Understanding Cache Benefits

Caching dependencies significantly reduces build times:

```text
Without Cache:
┌──────────────────────────────────────────────────────────┐
│ Checkout → Install Dependencies → Build → Test → Deploy │
│    5s           120s               60s    30s     30s   │
│                                                         │
│ Total: ~4 minutes per build                             │
└──────────────────────────────────────────────────────────┘

With Cache:
┌──────────────────────────────────────────────────────────┐
│ Checkout → Restore Cache → Build → Test → Deploy        │
│    5s          5s           60s    30s     30s          │
│                                                         │
│ Total: ~2 minutes per build (50% faster!)               │
└──────────────────────────────────────────────────────────┘
```

### Step 2: Node.js Dependency Caching

Create an optimized workflow with npm caching:

```yaml
# .github/workflows/optimized-node.yaml
name: Optimized Node.js CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js with cache
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: package-lock.json

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: npm run build

      - name: Test
        run: npm test
```

### Step 3: Advanced Custom Caching

For more control, use the cache action directly:

```yaml
# .github/workflows/advanced-caching.yaml
name: Advanced Caching

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      # Cache node_modules with fallback
      - name: Cache node modules
        id: cache-npm
        uses: actions/cache@v4
        with:
          path: |
            ~/.npm
            node_modules
          key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-node-

      # Cache build outputs
      - name: Cache build output
        uses: actions/cache@v4
        with:
          path: |
            .next/cache
            dist
          key: ${{ runner.os }}-build-${{ hashFiles('src/**') }}
          restore-keys: |
            ${{ runner.os }}-build-

      - name: Install dependencies
        if: steps.cache-npm.outputs.cache-hit != 'true'
        run: npm ci

      - name: Build
        run: npm run build
```

### Step 4: Go Module Caching

```yaml
# .github/workflows/go-cached.yaml
name: Go CI with Caching

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
          cache: true
          cache-dependency-path: go.sum

      # Additional build cache
      - name: Cache Go build
        uses: actions/cache@v4
        with:
          path: ~/.cache/go-build
          key: ${{ runner.os }}-go-build-${{ hashFiles('**/*.go') }}
          restore-keys: |
            ${{ runner.os }}-go-build-

      - name: Build
        run: go build -v ./...

      - name: Test
        run: go test -v ./...
```

### Step 5: Python Dependency Caching

```yaml
# .github/workflows/python-cached.yaml
name: Python CI with Caching

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'
          cache-dependency-path: |
            requirements.txt
            requirements-dev.txt

      # Cache virtual environment
      - name: Cache virtualenv
        uses: actions/cache@v4
        with:
          path: .venv
          key: ${{ runner.os }}-venv-${{ hashFiles('**/requirements*.txt') }}

      - name: Install dependencies
        run: |
          python -m venv .venv
          source .venv/bin/activate
          pip install -r requirements.txt -r requirements-dev.txt

      - name: Test
        run: |
          source .venv/bin/activate
          pytest
```

### Step 6: Docker Layer Caching

Optimize Docker builds with layer caching:

```yaml
# .github/workflows/docker-cached.yaml
name: Docker Build with Caching

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Login to Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Build with cache
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      # Alternative: Registry-based cache
      - name: Build with registry cache
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ghcr.io/${{ github.repository }}:latest
          cache-from: type=registry,ref=ghcr.io/${{ github.repository }}:cache
          cache-to: type=registry,ref=ghcr.io/${{ github.repository }}:cache,mode=max
```

### Validation 1

Verify caching is working:

```bash
# Check cache hits in workflow logs
# Look for "Cache restored successfully" messages

# Compare build times
# Run 1 (no cache): ~4 minutes
# Run 2 (with cache): ~2 minutes

# Verify cache in GitHub UI
# Actions → Caches → View cache entries
```

---

## Exercise 2: Parallel Execution and Matrix Builds

### Step 1: Understanding Parallelization

```text
Sequential Execution:
┌─────────┐   ┌─────────┐   ┌─────────┐
│  Test   │──▶│  Build  │──▶│  Deploy │
│  3 min  │   │  2 min  │   │  1 min  │
└─────────┘   └─────────┘   └─────────┘
Total: 6 minutes

Parallel Execution:
┌─────────┐
│ Test A  │───┐
│  1 min  │   │
└─────────┘   │   ┌─────────┐   ┌─────────┐
┌─────────┐   │──▶│  Build  │──▶│  Deploy │
│ Test B  │───┤   │  2 min  │   │  1 min  │
│  1 min  │   │   └─────────┘   └─────────┘
└─────────┘   │
┌─────────┐   │
│ Test C  │───┘
│  1 min  │
└─────────┘
Total: 4 minutes
```

### Step 2: Matrix Strategy for Multi-Version Testing

```yaml
# .github/workflows/matrix-testing.yaml
name: Matrix Testing

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    
    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        node-version: [18, 20, 22]
        os: [ubuntu-latest, macos-latest]
        include:
          - node-version: 20
            os: ubuntu-latest
            coverage: true
        exclude:
          - node-version: 18
            os: macos-latest

    steps:
      - uses: actions/checkout@v4

      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - run: npm ci
      - run: npm test

      - name: Upload coverage
        if: matrix.coverage
        uses: codecov/codecov-action@v4
```

### Step 3: Parallel Jobs with Dependencies

```yaml
# .github/workflows/parallel-pipeline.yaml
name: Parallel Pipeline

on:
  push:
    branches: [main]

jobs:
  # First stage: Run in parallel
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run lint

  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run security scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm test -- --coverage

  # Second stage: Depends on first stage
  build:
    needs: [lint, security-scan, unit-tests]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build
      - uses: actions/upload-artifact@v4
        with:
          name: build-output
          path: dist/

  # Third stage: Integration tests
  integration-tests:
    needs: build
    runs-on: ubuntu-latest
    strategy:
      matrix:
        test-suite: [api, ui, e2e]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: build-output
          path: dist/
      - run: npm ci
      - run: npm run test:${{ matrix.test-suite }}

  # Final stage: Deploy
  deploy:
    needs: integration-tests
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: build-output
          path: dist/
      - run: echo "Deploying..."
```

### Step 4: Dynamic Matrix Generation

```yaml
# .github/workflows/dynamic-matrix.yaml
name: Dynamic Matrix

on:
  push:
    branches: [main]

jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Detect changed services
        id: set-matrix
        run: |
          # Find services with changes
          CHANGED=$(git diff --name-only HEAD~1 HEAD | grep "^services/" | cut -d'/' -f2 | sort -u)
          
          if [ -z "$CHANGED" ]; then
            echo "matrix={\"service\":[]}" >> $GITHUB_OUTPUT
          else
            JSON=$(echo "$CHANGED" | jq -R -s -c 'split("\n") | map(select(length > 0))')
            echo "matrix={\"service\":$JSON}" >> $GITHUB_OUTPUT
          fi

  build:
    needs: prepare
    if: ${{ fromJson(needs.prepare.outputs.matrix).service[0] != null }}
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.prepare.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4
      
      - name: Build ${{ matrix.service }}
        run: |
          cd services/${{ matrix.service }}
          docker build -t ${{ matrix.service }}:${{ github.sha }} .
```

### Validation 2

Verify parallel execution:

```bash
# View workflow run timeline in GitHub Actions
# Jobs should execute in parallel where dependencies allow

# Check total workflow time vs individual job times
# Parallel execution should reduce total time

# Verify matrix combinations
# All specified combinations should have run
```

---

## Exercise 3: Self-Hosted Runners

### Step 1: Understanding Self-Hosted Runners

```text
GitHub-Hosted vs Self-Hosted:

┌────────────────────────┬──────────────────────┐
│   GitHub-Hosted        │   Self-Hosted        │
├────────────────────────┼──────────────────────┤
│ No infrastructure      │ Full control         │
│ Limited resources      │ Custom hardware      │
│ Clean environment      │ Persistent cache     │
│ Pay per minute         │ Fixed cost           │
│ Standard images        │ Custom images        │
│ Network restrictions   │ Private network      │
└────────────────────────┴──────────────────────┘
```

### Step 2: Deploy Runner on Kubernetes

Create a runner deployment using Actions Runner Controller (ARC):

```yaml
# runner/runner-controller.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: actions-runner-system
---
# Install ARC using Helm
# helm repo add actions-runner-controller https://actions-runner-controller.github.io/actions-runner-controller
# helm install arc actions-runner-controller/actions-runner-controller \
#   -n actions-runner-system \
#   --set authSecret.create=true \
#   --set authSecret.github_token="${GITHUB_TOKEN}"
```

### Step 3: Create Runner Deployment

```yaml
# runner/runner-deployment.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: RunnerDeployment
metadata:
  name: k8s-runners
  namespace: actions-runner-system
spec:
  replicas: 3
  template:
    spec:
      repository: your-org/your-repo
      labels:
        - self-hosted
        - kubernetes
        - linux
      resources:
        limits:
          cpu: "2"
          memory: "4Gi"
        requests:
          cpu: "1"
          memory: "2Gi"
      env:
        - name: DOCKER_HOST
          value: tcp://localhost:2375
      dockerdContainerResources:
        limits:
          cpu: "1"
          memory: "2Gi"
```

### Step 4: Autoscaling Runners

```yaml
# runner/runner-autoscaler.yaml
apiVersion: actions.summerwind.dev/v1alpha1
kind: HorizontalRunnerAutoscaler
metadata:
  name: k8s-runners-autoscaler
  namespace: actions-runner-system
spec:
  scaleTargetRef:
    kind: RunnerDeployment
    name: k8s-runners
  scaleUpTriggers:
    - githubEvent:
        workflowJob: {}
      amount: 1
      duration: "5m"
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: TotalNumberOfQueuedAndInProgressWorkflowRuns
      repositoryNames:
        - your-org/your-repo
```

### Step 5: Use Self-Hosted Runners

```yaml
# .github/workflows/self-hosted.yaml
name: Self-Hosted Pipeline

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: [self-hosted, kubernetes, linux]
    
    steps:
      - uses: actions/checkout@v4

      - name: Build application
        run: |
          echo "Building on self-hosted runner"
          docker build -t myapp:${{ github.sha }} .

      - name: Access internal resources
        run: |
          # Can access private network resources
          curl http://internal-service.company.local/api/health
```

### Step 6: Runner Groups and Labels

Configure runner groups for different workloads:

```yaml
# .github/workflows/runner-selection.yaml
name: Runner Selection

on:
  push:
    branches: [main]

jobs:
  # Use GPU runners for ML
  ml-training:
    runs-on: [self-hosted, gpu, linux]
    steps:
      - run: nvidia-smi
      - run: python train_model.py

  # Use high-memory runners for builds
  build:
    runs-on: [self-hosted, high-memory]
    steps:
      - run: npm run build

  # Use standard runners for tests
  test:
    runs-on: [self-hosted, standard]
    steps:
      - run: npm test

  # Fallback to GitHub-hosted
  lint:
    runs-on: ubuntu-latest
    steps:
      - run: npm run lint
```

### Validation 3

Verify runner setup:

```bash
# Check runner status in GitHub
# Settings → Actions → Runners

# Verify runner pods
kubectl get pods -n actions-runner-system

# Check autoscaler status
kubectl get hra -n actions-runner-system

# Test runner connectivity
# Trigger a workflow and verify it runs on self-hosted
```

---

## Exercise 4: Pipeline Performance Monitoring

### Step 1: Workflow Telemetry

Add timing and metrics to workflows:

```yaml
# .github/workflows/monitored-pipeline.yaml
name: Monitored Pipeline

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Start timing
        id: timer
        run: echo "start=$(date +%s)" >> $GITHUB_OUTPUT

      - name: Build
        id: build
        run: |
          START=$(date +%s)
          npm ci && npm run build
          END=$(date +%s)
          echo "duration=$((END-START))" >> $GITHUB_OUTPUT

      - name: Test
        id: test
        run: |
          START=$(date +%s)
          npm test
          END=$(date +%s)
          echo "duration=$((END-START))" >> $GITHUB_OUTPUT

      - name: Calculate metrics
        run: |
          TOTAL=$(($(date +%s) - ${{ steps.timer.outputs.start }}))
          echo "### Pipeline Metrics" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Stage | Duration |" >> $GITHUB_STEP_SUMMARY
          echo "|-------|----------|" >> $GITHUB_STEP_SUMMARY
          echo "| Build | ${{ steps.build.outputs.duration }}s |" >> $GITHUB_STEP_SUMMARY
          echo "| Test | ${{ steps.test.outputs.duration }}s |" >> $GITHUB_STEP_SUMMARY
          echo "| **Total** | ${TOTAL}s |" >> $GITHUB_STEP_SUMMARY

      - name: Send to monitoring
        if: always()
        run: |
          curl -X POST "${{ secrets.METRICS_URL }}" \
            -H "Content-Type: application/json" \
            -d '{
              "workflow": "${{ github.workflow }}",
              "run_id": "${{ github.run_id }}",
              "status": "${{ job.status }}",
              "build_time": "${{ steps.build.outputs.duration }}",
              "test_time": "${{ steps.test.outputs.duration }}",
              "branch": "${{ github.ref_name }}",
              "commit": "${{ github.sha }}"
            }'
```

### Step 2: Prometheus Metrics Collection

Create a metrics exporter for pipeline data:

```yaml
# monitoring/pipeline-metrics.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-metrics-config
data:
  config.yaml: |
    github:
      token: ${GITHUB_TOKEN}
      repos:
        - owner/repo1
        - owner/repo2
    metrics:
      - name: workflow_duration_seconds
        type: histogram
        help: Duration of workflow runs
      - name: workflow_runs_total
        type: counter
        help: Total number of workflow runs
      - name: workflow_failures_total
        type: counter
        help: Total number of failed workflows
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-actions-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: github-actions-exporter
  template:
    metadata:
      labels:
        app: github-actions-exporter
    spec:
      containers:
        - name: exporter
          image: ghcr.io/cpanato/github_actions_exporter:v1
          ports:
            - containerPort: 9999
          env:
            - name: GITHUB_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-token
                  key: token
            - name: GITHUB_REPOS
              value: "owner/repo1,owner/repo2"
---
apiVersion: v1
kind: Service
metadata:
  name: github-actions-exporter
  labels:
    app: github-actions-exporter
spec:
  ports:
    - port: 9999
      targetPort: 9999
  selector:
    app: github-actions-exporter
```

### Step 3: Grafana Dashboard for Pipelines

```json
{
  "dashboard": {
    "title": "CI/CD Pipeline Metrics",
    "panels": [
      {
        "title": "Workflow Duration Trend",
        "type": "timeseries",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(workflow_duration_seconds_bucket[5m]))",
            "legendFormat": "p95 duration"
          }
        ]
      },
      {
        "title": "Success Rate",
        "type": "stat",
        "targets": [
          {
            "expr": "1 - (rate(workflow_failures_total[24h]) / rate(workflow_runs_total[24h]))",
            "legendFormat": "Success Rate"
          }
        ]
      },
      {
        "title": "Builds per Hour",
        "type": "timeseries",
        "targets": [
          {
            "expr": "rate(workflow_runs_total[1h]) * 3600",
            "legendFormat": "Builds/hour"
          }
        ]
      }
    ]
  }
}
```

### Step 4: Build Time Analysis

```yaml
# .github/workflows/analyze-build.yaml
name: Build Analysis

on:
  workflow_run:
    workflows: ["CI Pipeline"]
    types: [completed]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - name: Get workflow data
        uses: actions/github-script@v7
        with:
          script: |
            const run = await github.rest.actions.getWorkflowRun({
              owner: context.repo.owner,
              repo: context.repo.repo,
              run_id: context.payload.workflow_run.id
            });
            
            const jobs = await github.rest.actions.listJobsForWorkflowRun({
              owner: context.repo.owner,
              repo: context.repo.repo,
              run_id: context.payload.workflow_run.id
            });
            
            // Calculate metrics
            const duration = new Date(run.data.updated_at) - new Date(run.data.created_at);
            const jobTimes = jobs.data.jobs.map(job => ({
              name: job.name,
              duration: new Date(job.completed_at) - new Date(job.started_at),
              status: job.conclusion
            }));
            
            console.log('Total Duration:', duration / 1000, 'seconds');
            console.log('Job Times:', JSON.stringify(jobTimes, null, 2));
            
            // Identify bottlenecks
            const slowestJob = jobTimes.reduce((a, b) => a.duration > b.duration ? a : b);
            console.log('Slowest Job:', slowestJob.name, slowestJob.duration / 1000, 'seconds');
```

### Validation 4

Verify monitoring setup:

```bash
# Check metrics endpoint
curl http://localhost:9999/metrics | grep workflow

# Verify Grafana dashboard
# Open Grafana → CI/CD Pipeline Metrics dashboard

# Check step summaries in GitHub
# View workflow run → Summary tab
```

---

## Exercise 5: Cost Optimization

### Step 1: Analyze Current Usage

```yaml
# .github/workflows/usage-report.yaml
name: Usage Report

on:
  schedule:
    - cron: '0 0 1 * *'  # Monthly
  workflow_dispatch:

jobs:
  report:
    runs-on: ubuntu-latest
    steps:
      - name: Generate usage report
        uses: actions/github-script@v7
        with:
          script: |
            // Get workflow runs for the past month
            const thirtyDaysAgo = new Date();
            thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
            
            const workflows = await github.rest.actions.listRepoWorkflows({
              owner: context.repo.owner,
              repo: context.repo.repo
            });
            
            let totalMinutes = 0;
            let report = [];
            
            for (const workflow of workflows.data.workflows) {
              const runs = await github.rest.actions.listWorkflowRuns({
                owner: context.repo.owner,
                repo: context.repo.repo,
                workflow_id: workflow.id,
                created: `>=${thirtyDaysAgo.toISOString().split('T')[0]}`
              });
              
              let workflowMinutes = 0;
              for (const run of runs.data.workflow_runs) {
                if (run.conclusion) {
                  const duration = new Date(run.updated_at) - new Date(run.run_started_at);
                  workflowMinutes += duration / 60000;
                }
              }
              
              report.push({
                name: workflow.name,
                runs: runs.data.total_count,
                minutes: Math.round(workflowMinutes)
              });
              totalMinutes += workflowMinutes;
            }
            
            // Output report
            console.log('## Monthly Usage Report');
            console.log(`Total Minutes: ${Math.round(totalMinutes)}`);
            console.log(`Estimated Cost: $${(totalMinutes * 0.008).toFixed(2)}`);
            report.forEach(w => console.log(`- ${w.name}: ${w.runs} runs, ${w.minutes} minutes`));
```

### Step 2: Implement Path Filters

Only run workflows when relevant files change:

```yaml
# .github/workflows/optimized-triggers.yaml
name: Optimized CI

on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'package*.json'
      - 'Dockerfile'
      - '.github/workflows/optimized-triggers.yaml'
    paths-ignore:
      - '**.md'
      - 'docs/**'
      - '.gitignore'

  pull_request:
    paths:
      - 'src/**'
      - 'tests/**'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm run build
```

### Step 3: Conditional Job Execution

```yaml
# .github/workflows/smart-pipeline.yaml
name: Smart Pipeline

on:
  push:
    branches: [main, develop]

jobs:
  changes:
    runs-on: ubuntu-latest
    outputs:
      frontend: ${{ steps.filter.outputs.frontend }}
      backend: ${{ steps.filter.outputs.backend }}
      infrastructure: ${{ steps.filter.outputs.infrastructure }}
    steps:
      - uses: actions/checkout@v4
      - uses: dorny/paths-filter@v3
        id: filter
        with:
          filters: |
            frontend:
              - 'frontend/**'
            backend:
              - 'backend/**'
            infrastructure:
              - 'terraform/**'
              - 'kubernetes/**'

  frontend:
    needs: changes
    if: ${{ needs.changes.outputs.frontend == 'true' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd frontend && npm ci && npm test && npm run build

  backend:
    needs: changes
    if: ${{ needs.changes.outputs.backend == 'true' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd backend && go test ./... && go build

  infrastructure:
    needs: changes
    if: ${{ needs.changes.outputs.infrastructure == 'true' }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: terraform validate
```

### Step 4: Skip Duplicate Runs

```yaml
# .github/workflows/skip-duplicates.yaml
name: Skip Duplicates

on:
  push:
    branches: [main]
  pull_request:

concurrency:
  group: ${{ github.workflow }}-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Skip check
        uses: fkirc/skip-duplicate-actions@v5
        id: skip_check
        with:
          concurrent_skipping: 'same_content_newer'
          skip_after_successful_duplicate: 'true'

      - uses: actions/checkout@v4
        if: steps.skip_check.outputs.should_skip != 'true'

      - name: Build
        if: steps.skip_check.outputs.should_skip != 'true'
        run: npm ci && npm run build
```

### Step 5: Optimize Runner Selection

```yaml
# .github/workflows/runner-optimization.yaml
name: Runner Optimization

on:
  push:
    branches: [main]

jobs:
  # Use smaller runners for quick tasks
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npm run lint

  # Use larger runners for resource-intensive tasks
  build:
    runs-on: ubuntu-latest-16-core  # Larger runner
    steps:
      - uses: actions/checkout@v4
      - run: npm ci
      - run: npm run build

  # Use ARM runners (cheaper)
  test:
    runs-on: ubuntu-24.04-arm64
    steps:
      - uses: actions/checkout@v4
      - run: npm test
```

### Step 6: Timeout Configuration

```yaml
# .github/workflows/with-timeouts.yaml
name: Pipeline with Timeouts

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30  # Job timeout
    
    steps:
      - uses: actions/checkout@v4

      - name: Install dependencies
        timeout-minutes: 5
        run: npm ci

      - name: Build
        timeout-minutes: 10
        run: npm run build

      - name: Test
        timeout-minutes: 15
        run: npm test
```

### Validation 5

Verify cost optimizations:

```bash
# Check path filtering
# Modify only README.md, workflow should not trigger

# Verify concurrency cancellation
# Push multiple times rapidly, old runs should be cancelled

# Check skip duplicates
# Push same content twice, second run should skip

# Monitor usage in GitHub
# Settings → Billing → Actions usage
```

---

## Exercise 6: Reusable Components

### Step 1: Create Reusable Workflows

```yaml
# .github/workflows/reusable-build.yaml
name: Reusable Build Workflow

on:
  workflow_call:
    inputs:
      node-version:
        required: false
        type: string
        default: '20'
      working-directory:
        required: false
        type: string
        default: '.'
      build-command:
        required: false
        type: string
        default: 'npm run build'
    outputs:
      artifact-name:
        description: 'Name of the build artifact'
        value: ${{ jobs.build.outputs.artifact-name }}
    secrets:
      npm-token:
        required: false

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact-name: build-${{ github.sha }}
    
    defaults:
      run:
        working-directory: ${{ inputs.working-directory }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'
          cache-dependency-path: ${{ inputs.working-directory }}/package-lock.json

      - name: Configure npm
        if: ${{ secrets.npm-token }}
        run: echo "//registry.npmjs.org/:_authToken=${{ secrets.npm-token }}" >> ~/.npmrc

      - name: Install dependencies
        run: npm ci

      - name: Build
        run: ${{ inputs.build-command }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-${{ github.sha }}
          path: ${{ inputs.working-directory }}/dist
```

### Step 2: Reusable Testing Workflow

```yaml
# .github/workflows/reusable-test.yaml
name: Reusable Test Workflow

on:
  workflow_call:
    inputs:
      test-command:
        required: false
        type: string
        default: 'npm test'
      coverage:
        required: false
        type: boolean
        default: false
      node-version:
        required: false
        type: string
        default: '20'
    secrets:
      codecov-token:
        required: false

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: ${{ inputs.node-version }}
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run tests
        run: ${{ inputs.test-command }}

      - name: Upload coverage
        if: ${{ inputs.coverage && secrets.codecov-token }}
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.codecov-token }}
```

### Step 3: Reusable Deploy Workflow

```yaml
# .github/workflows/reusable-deploy.yaml
name: Reusable Deploy Workflow

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      artifact-name:
        required: true
        type: string
      deploy-url:
        required: true
        type: string
    secrets:
      deploy-token:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: ${{ inputs.environment }}
      url: ${{ inputs.deploy-url }}
    
    steps:
      - uses: actions/download-artifact@v4
        with:
          name: ${{ inputs.artifact-name }}
          path: dist

      - name: Deploy
        env:
          DEPLOY_TOKEN: ${{ secrets.deploy-token }}
        run: |
          echo "Deploying to ${{ inputs.environment }}..."
          # Add deployment commands here
```

### Step 4: Use Reusable Workflows

```yaml
# .github/workflows/main-pipeline.yaml
name: Main Pipeline

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    uses: ./.github/workflows/reusable-build.yaml
    with:
      node-version: '20'
      build-command: 'npm run build:prod'
    secrets:
      npm-token: ${{ secrets.NPM_TOKEN }}

  test:
    uses: ./.github/workflows/reusable-test.yaml
    with:
      coverage: true
    secrets:
      codecov-token: ${{ secrets.CODECOV_TOKEN }}

  deploy-staging:
    needs: [build, test]
    if: github.ref == 'refs/heads/main'
    uses: ./.github/workflows/reusable-deploy.yaml
    with:
      environment: staging
      artifact-name: ${{ needs.build.outputs.artifact-name }}
      deploy-url: https://staging.example.com
    secrets:
      deploy-token: ${{ secrets.STAGING_TOKEN }}

  deploy-production:
    needs: [deploy-staging]
    uses: ./.github/workflows/reusable-deploy.yaml
    with:
      environment: production
      artifact-name: ${{ needs.build.outputs.artifact-name }}
      deploy-url: https://example.com
    secrets:
      deploy-token: ${{ secrets.PRODUCTION_TOKEN }}
```

### Step 5: Create Composite Actions

```yaml
# .github/actions/setup-environment/action.yaml
name: Setup Environment
description: Sets up the development environment

inputs:
  node-version:
    description: Node.js version
    required: false
    default: '20'
  install-deps:
    description: Whether to install dependencies
    required: false
    default: 'true'

outputs:
  cache-hit:
    description: Whether cache was hit
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: composite
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: ${{ inputs.node-version }}

    - name: Get npm cache directory
      id: npm-cache-dir
      shell: bash
      run: echo "dir=$(npm config get cache)" >> $GITHUB_OUTPUT

    - name: Cache dependencies
      id: cache
      uses: actions/cache@v4
      with:
        path: |
          ${{ steps.npm-cache-dir.outputs.dir }}
          node_modules
        key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
        restore-keys: |
          ${{ runner.os }}-node-

    - name: Install dependencies
      if: inputs.install-deps == 'true' && steps.cache.outputs.cache-hit != 'true'
      shell: bash
      run: npm ci
```

### Step 6: Use Composite Actions

```yaml
# .github/workflows/with-composite.yaml
name: Pipeline with Composite Actions

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        uses: ./.github/actions/setup-environment
        with:
          node-version: '20'

      - name: Build
        run: npm run build
```

### Validation 6

Verify reusable components:

```bash
# Check reusable workflow execution
# View workflow run to see nested workflow calls

# Verify composite action
# Check if setup steps are properly grouped

# Test workflow outputs
# Verify artifact name is correctly passed between jobs
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Cache Not Restoring

```text
Problem: Cache action shows "cache miss"

Solution:
1. Verify cache key matches exactly
2. Check hash of dependency files
3. Ensure cache path is correct

Debug steps:
- Add debug logging: ACTIONS_STEP_DEBUG=true
- Check cache size (max 10GB per repo)
- Verify no cache expiration (7 days for unused)
```

#### Issue 2: Matrix Jobs Failing

```text
Problem: Some matrix combinations fail

Solution:
1. Check matrix exclusions
2. Verify all combinations are valid
3. Use continue-on-error for flaky tests

Example:
  strategy:
    fail-fast: false
    matrix:
      os: [ubuntu-latest, macos-latest]
      node: [18, 20]
    exclude:
      - os: macos-latest
        node: 18
```

#### Issue 3: Self-Hosted Runner Offline

```text
Problem: Self-hosted runner shows offline

Solution:
1. Check runner pod status
   kubectl get pods -n actions-runner-system
   
2. Verify runner registration
   kubectl logs -n actions-runner-system <runner-pod>
   
3. Check GitHub token validity
   kubectl get secret -n actions-runner-system
   
4. Restart runner
   kubectl rollout restart deployment -n actions-runner-system
```

#### Issue 4: Workflow Timeout

```text
Problem: Workflow exceeds timeout

Solution:
1. Increase timeout-minutes
2. Optimize slow steps
3. Use caching effectively
4. Run steps in parallel
5. Use larger runners
```

---

## Summary

In this lab, you learned:

1. **Caching Strategies**: Implementing dependency and Docker layer caching to speed up builds
2. **Parallel Execution**: Using matrix builds and parallel jobs to reduce total pipeline time
3. **Self-Hosted Runners**: Deploying and managing custom runners on Kubernetes
4. **Performance Monitoring**: Collecting and analyzing pipeline metrics
5. **Cost Optimization**: Reducing CI/CD costs through smart triggers and resource usage
6. **Reusable Components**: Creating maintainable workflows with reusable workflows and composite actions

These advanced patterns enable you to build efficient, scalable, and cost-effective CI/CD pipelines for enterprise workloads.

---

## What's Next?

You've completed all labs in the CI/CD module. Continue to:

1. **Assessment**: Test your knowledge with practical scenarios
2. **Module 4**: Observability & Monitoring
3. **Practice**: Apply these patterns to your own projects

---

## Key Takeaways

```text
Pipeline Optimization Checklist:

□ Caching
  - Dependency caching enabled
  - Docker layer caching configured
  - Build output caching implemented

□ Parallelization
  - Independent jobs run in parallel
  - Matrix builds for multi-environment testing
  - Dependencies properly defined

□ Smart Triggers
  - Path filters configured
  - Duplicate runs prevented
  - Concurrency groups set

□ Monitoring
  - Build metrics collected
  - Dashboard configured
  - Alerts for failures

□ Cost Control
  - Right-sized runners
  - Timeouts configured
  - Usage monitored regularly
```
