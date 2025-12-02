# Lab 1: GitHub Actions Fundamentals

## Overview

This lab introduces GitHub Actions, GitHub's built-in CI/CD platform. You will learn to create workflows, understand the syntax, use marketplace actions, configure secrets, and implement reusable workflow patterns essential for platform engineering.

## Time to Complete

Estimated time: 2-3 hours

## Prerequisites

Before starting this lab, ensure you have:

- GitHub account
- A GitHub repository (you'll create one if needed)
- Basic understanding of YAML syntax
- Git installed locally
- Completed Modules 1 and 2

## Learning Objectives

By the end of this lab, you will be able to:

1. Create and structure GitHub Actions workflows
2. Understand triggers, jobs, and steps
3. Use actions from the GitHub Marketplace
4. Configure secrets and environment variables
5. Implement conditional execution
6. Create reusable workflows and composite actions
7. Use self-hosted runners

## GitHub Actions Architecture

```text
GitHub Actions Architecture:

┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
├─────────────────────────────────────────────────────────────────┤
│  .github/workflows/                                              │
│  ├── ci.yaml          ─────────┐                                │
│  ├── cd.yaml                   │ Workflow Files                 │
│  └── release.yaml     ─────────┘                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼ Triggers (push, PR, schedule, etc.)
┌─────────────────────────────────────────────────────────────────┐
│                      GitHub Actions Runner                       │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │    Job 1     │  │    Job 2     │  │    Job 3     │          │
│  │  (build)     │──▶│   (test)     │──▶│  (deploy)    │          │
│  │              │  │              │  │              │          │
│  │ ┌─────────┐  │  │ ┌─────────┐  │  │ ┌─────────┐  │          │
│  │ │ Step 1  │  │  │ │ Step 1  │  │  │ │ Step 1  │  │          │
│  │ │ Step 2  │  │  │ │ Step 2  │  │  │ │ Step 2  │  │          │
│  │ │ Step 3  │  │  │ │ Step 3  │  │  │ │ Step 3  │  │          │
│  │ └─────────┘  │  │ └─────────┘  │  │ └─────────┘  │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Lab Exercises

### Exercise 1: Creating Your First Workflow

#### Step 1: Create a Repository

If you don't have a repository, create one:

```bash
# Create a new directory
mkdir github-actions-lab
cd github-actions-lab

# Initialize git
git init

# Create a simple application
cat > app.py << 'EOF'
def greet(name):
    return f"Hello, {name}!"

def add(a, b):
    return a + b

if __name__ == "__main__":
    print(greet("World"))
    print(f"2 + 3 = {add(2, 3)}")
EOF

# Create requirements.txt
cat > requirements.txt << 'EOF'
pytest==7.4.0
pytest-cov==4.1.0
EOF

# Create test file
cat > test_app.py << 'EOF'
from app import greet, add

def test_greet():
    assert greet("Alice") == "Hello, Alice!"

def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0
EOF

# Initial commit
git add .
git commit -m "Initial commit"
```

Create the repository on GitHub and push:

```bash
gh repo create github-actions-lab --public --source=. --push
```

Or manually create on GitHub and push:

```bash
git remote add origin https://github.com/YOUR_USERNAME/github-actions-lab.git
git branch -M main
git push -u origin main
```

#### Step 2: Create Your First Workflow

Create the workflow directory and file:

```bash
mkdir -p .github/workflows
```

Create the workflow file:

```yaml
# .github/workflows/ci.yaml
name: CI Pipeline

on:
  push:
    branches:
      - main
      - 'feature/**'
  pull_request:
    branches:
      - main

jobs:
  build:
    name: Build and Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run tests
        run: |
          pytest --verbose

      - name: Display success message
        run: echo "All tests passed!"
```

#### Step 3: Push and View Workflow

```bash
git add .github/workflows/ci.yaml
git commit -m "Add CI workflow"
git push origin main
```

View the workflow:

1. Go to your GitHub repository
2. Click on the "Actions" tab
3. Watch your workflow run

### Exercise 2: Understanding Workflow Syntax

#### Step 1: Workflow Triggers

Update your workflow with multiple triggers:

```yaml
# .github/workflows/ci.yaml
name: CI Pipeline

on:
  # Trigger on push to specific branches
  push:
    branches:
      - main
      - 'release/**'
    paths:
      - 'src/**'
      - 'tests/**'
      - '*.py'
    paths-ignore:
      - '**.md'
      - 'docs/**'

  # Trigger on pull requests
  pull_request:
    branches:
      - main
    types:
      - opened
      - synchronize
      - reopened

  # Manual trigger
  workflow_dispatch:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        default: 'dev'
        type: choice
        options:
          - dev
          - staging
          - prod
      debug:
        description: 'Enable debug mode'
        required: false
        type: boolean
        default: false

  # Scheduled trigger
  schedule:
    - cron: '0 6 * * 1-5'  # Every weekday at 6 AM UTC

# Environment variables available to all jobs
env:
  PYTHON_VERSION: '3.11'
  REGISTRY: ghcr.io

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Show trigger info
        run: |
          echo "Event: ${{ github.event_name }}"
          echo "Ref: ${{ github.ref }}"
          echo "SHA: ${{ github.sha }}"
```

#### Step 2: Job Configuration Options

```yaml
jobs:
  build:
    name: Build Application
    runs-on: ubuntu-latest

    # Job-level permissions
    permissions:
      contents: read
      packages: write

    # Job timeout
    timeout-minutes: 30

    # Continue workflow even if this job fails
    continue-on-error: false

    # Environment for deployments
    environment:
      name: development
      url: https://dev.example.com

    # Concurrency control
    concurrency:
      group: ${{ github.workflow }}-${{ github.ref }}
      cancel-in-progress: true

    # Job outputs
    outputs:
      version: ${{ steps.version.outputs.value }}

    steps:
      - uses: actions/checkout@v4

      - name: Set version
        id: version
        run: echo "value=1.0.${{ github.run_number }}" >> $GITHUB_OUTPUT
```

#### Step 3: Step Configuration

```yaml
steps:
  # Using an action
  - name: Checkout code
    uses: actions/checkout@v4
    with:
      fetch-depth: 0
      token: ${{ secrets.GITHUB_TOKEN }}

  # Running a command
  - name: Run build
    run: |
      echo "Building..."
      npm run build
    working-directory: ./frontend
    shell: bash
    env:
      NODE_ENV: production

  # Conditional execution
  - name: Deploy to production
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    run: ./deploy.sh

  # Continue on error
  - name: Run optional check
    continue-on-error: true
    run: ./optional-check.sh

  # Timeout for step
  - name: Long running task
    timeout-minutes: 10
    run: ./long-task.sh
```

### Exercise 3: Using Marketplace Actions

#### Step 1: Common Actions

```yaml
# .github/workflows/ci-complete.yaml
name: Complete CI Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      # Checkout with full history
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      # Setup Node.js
      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      # Setup Python
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          cache: 'pip'

      # Setup Go
      - name: Setup Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'
          cache: true

      # Cache dependencies
      - name: Cache dependencies
        uses: actions/cache@v4
        with:
          path: |
            ~/.cache/pip
            node_modules
          key: ${{ runner.os }}-deps-${{ hashFiles('**/requirements.txt', '**/package-lock.json') }}
          restore-keys: |
            ${{ runner.os }}-deps-

      # Upload artifacts
      - name: Build
        run: |
          mkdir -p dist
          echo "Built artifact" > dist/app.txt

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: build-artifact
          path: dist/
          retention-days: 5

  test:
    needs: build
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # Download artifacts from previous job
      - name: Download artifact
        uses: actions/download-artifact@v4
        with:
          name: build-artifact
          path: dist/

      - name: Verify artifact
        run: cat dist/app.txt
```

#### Step 2: Docker and Container Actions

```yaml
jobs:
  docker:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      # Login to container registry
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Setup Docker Buildx
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      # Build and push
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: |
            ghcr.io/${{ github.repository }}:${{ github.sha }}
            ghcr.io/${{ github.repository }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Exercise 4: Secrets and Variables

#### Step 1: Using Secrets

Configure secrets in GitHub:

1. Go to repository Settings > Secrets and variables > Actions
2. Add repository secrets

Using secrets in workflows:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to server
        env:
          API_KEY: ${{ secrets.API_KEY }}
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
        run: |
          echo "Deploying with API key..."
          # Never echo secrets directly!
          ./deploy.sh

      - name: Use in action
        uses: some-action@v1
        with:
          token: ${{ secrets.CUSTOM_TOKEN }}
```

#### Step 2: Environment Variables

```yaml
# Global environment variables
env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest

    # Job-level environment variables
    env:
      NODE_ENV: production

    steps:
      - name: Use variables
        env:
          # Step-level environment variable
          STEP_VAR: "step-value"
        run: |
          echo "Registry: $REGISTRY"
          echo "Node env: $NODE_ENV"
          echo "Step var: $STEP_VAR"

      # Dynamic environment variables
      - name: Set dynamic variable
        run: echo "BUILD_DATE=$(date +%Y%m%d)" >> $GITHUB_ENV

      - name: Use dynamic variable
        run: echo "Build date: $BUILD_DATE"
```

#### Step 3: GitHub Context Variables

```yaml
jobs:
  info:
    runs-on: ubuntu-latest
    steps:
      - name: Display context
        run: |
          echo "Repository: ${{ github.repository }}"
          echo "Owner: ${{ github.repository_owner }}"
          echo "Actor: ${{ github.actor }}"
          echo "Ref: ${{ github.ref }}"
          echo "Ref name: ${{ github.ref_name }}"
          echo "SHA: ${{ github.sha }}"
          echo "Short SHA: ${{ github.sha | substring(0, 7) }}"
          echo "Run ID: ${{ github.run_id }}"
          echo "Run number: ${{ github.run_number }}"
          echo "Event: ${{ github.event_name }}"
          echo "Workflow: ${{ github.workflow }}"
          echo "Job: ${{ github.job }}"
```

### Exercise 5: Conditional Execution

#### Step 1: If Conditions

```yaml
jobs:
  conditional:
    runs-on: ubuntu-latest

    steps:
      # Always run
      - name: Always run
        run: echo "This always runs"

      # Run on push only
      - name: Push only
        if: github.event_name == 'push'
        run: echo "Triggered by push"

      # Run on main branch
      - name: Main branch only
        if: github.ref == 'refs/heads/main'
        run: echo "On main branch"

      # Run on pull request
      - name: PR only
        if: github.event_name == 'pull_request'
        run: echo "This is a PR"

      # Run on specific PR action
      - name: PR opened
        if: github.event_name == 'pull_request' && github.event.action == 'opened'
        run: echo "PR was just opened"

      # Run based on changed files
      - name: Check changed files
        id: changed
        uses: dorny/paths-filter@v2
        with:
          filters: |
            docs:
              - 'docs/**'
            src:
              - 'src/**'

      - name: Docs changed
        if: steps.changed.outputs.docs == 'true'
        run: echo "Documentation changed"

      # Run on failure of previous step
      - name: On failure
        if: failure()
        run: echo "Previous step failed"

      # Always run (even on failure)
      - name: Cleanup
        if: always()
        run: echo "Cleanup tasks"

      # Run on success only
      - name: On success
        if: success()
        run: echo "All previous steps succeeded"
```

#### Step 2: Complex Conditions

```yaml
jobs:
  complex:
    runs-on: ubuntu-latest

    steps:
      # Multiple conditions with AND
      - name: Main push only
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: echo "Push to main"

      # Multiple conditions with OR
      - name: Main or develop
        if: github.ref == 'refs/heads/main' || github.ref == 'refs/heads/develop'
        run: echo "On main or develop"

      # Using contains
      - name: Feature branch
        if: contains(github.ref, 'feature/')
        run: echo "On a feature branch"

      # Using startsWith
      - name: Release branch
        if: startsWith(github.ref, 'refs/heads/release/')
        run: echo "On a release branch"

      # Check actor
      - name: Specific user
        if: github.actor == 'admin-user'
        run: echo "Triggered by admin"

      # Using environment variable
      - name: Debug mode
        if: env.DEBUG == 'true'
        run: echo "Debug mode enabled"

      # Check job status
      - name: Job cancelled
        if: cancelled()
        run: echo "Job was cancelled"
```

### Exercise 6: Job Dependencies and Matrix

#### Step 1: Job Dependencies

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.value }}
    steps:
      - uses: actions/checkout@v4
      - name: Set version
        id: version
        run: echo "value=1.0.${{ github.run_number }}" >> $GITHUB_OUTPUT
      - name: Build
        run: echo "Building..."

  test:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Get version from build
        run: echo "Version: ${{ needs.build.outputs.version }}"
      - name: Test
        run: echo "Testing..."

  deploy-staging:
    needs: test
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - name: Deploy to staging
        run: echo "Deploying ${{ needs.build.outputs.version }} to staging"

  deploy-production:
    needs: [test, deploy-staging]
    runs-on: ubuntu-latest
    environment: production
    if: github.ref == 'refs/heads/main'
    steps:
      - name: Deploy to production
        run: echo "Deploying ${{ needs.build.outputs.version }} to production"
```

#### Step 2: Matrix Strategy

```yaml
jobs:
  test:
    runs-on: ${{ matrix.os }}

    strategy:
      fail-fast: false
      max-parallel: 4
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
        python-version: ['3.9', '3.10', '3.11']
        include:
          - os: ubuntu-latest
            python-version: '3.12'
            experimental: true
        exclude:
          - os: windows-latest
            python-version: '3.9'

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python ${{ matrix.python-version }}
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}

      - name: Run tests
        run: |
          echo "Testing on ${{ matrix.os }} with Python ${{ matrix.python-version }}"
          python --version
```

#### Step 3: Dynamic Matrix

```yaml
jobs:
  prepare:
    runs-on: ubuntu-latest
    outputs:
      matrix: ${{ steps.set-matrix.outputs.matrix }}
    steps:
      - uses: actions/checkout@v4
      - name: Set matrix
        id: set-matrix
        run: |
          # Generate matrix from directory structure
          DIRS=$(ls -d */ | tr -d '/' | jq -R -s -c 'split("\n")[:-1]')
          echo "matrix={\"directory\":$DIRS}" >> $GITHUB_OUTPUT

  build:
    needs: prepare
    runs-on: ubuntu-latest
    strategy:
      matrix: ${{ fromJson(needs.prepare.outputs.matrix) }}
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: echo "Building ${{ matrix.directory }}"
```

### Exercise 7: Reusable Workflows

#### Step 1: Create Reusable Workflow

```yaml
# .github/workflows/reusable-build.yaml
name: Reusable Build Workflow

on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      python-version:
        description: 'Python version'
        required: false
        type: string
        default: '3.11'
    secrets:
      deploy-key:
        description: 'Deployment key'
        required: true
    outputs:
      artifact-name:
        description: 'Name of the built artifact'
        value: ${{ jobs.build.outputs.artifact }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      artifact: ${{ steps.build.outputs.name }}

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ inputs.python-version }}

      - name: Build
        id: build
        run: |
          echo "Building for ${{ inputs.environment }}"
          ARTIFACT_NAME="app-${{ inputs.environment }}-${{ github.run_number }}"
          echo "name=$ARTIFACT_NAME" >> $GITHUB_OUTPUT
          mkdir -p dist
          echo "Built for ${{ inputs.environment }}" > dist/$ARTIFACT_NAME.txt

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: ${{ steps.build.outputs.name }}
          path: dist/
```

#### Step 2: Call Reusable Workflow

```yaml
# .github/workflows/ci.yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-dev:
    uses: ./.github/workflows/reusable-build.yaml
    with:
      environment: dev
      python-version: '3.11'
    secrets:
      deploy-key: ${{ secrets.DEV_DEPLOY_KEY }}

  build-staging:
    needs: build-dev
    uses: ./.github/workflows/reusable-build.yaml
    with:
      environment: staging
    secrets:
      deploy-key: ${{ secrets.STAGING_DEPLOY_KEY }}

  deploy:
    needs: [build-dev, build-staging]
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        run: |
          echo "Dev artifact: ${{ needs.build-dev.outputs.artifact-name }}"
          echo "Staging artifact: ${{ needs.build-staging.outputs.artifact-name }}"
```

#### Step 3: Composite Actions

Create a composite action:

```yaml
# .github/actions/setup-project/action.yaml
name: 'Setup Project'
description: 'Setup project dependencies and environment'

inputs:
  python-version:
    description: 'Python version to use'
    required: false
    default: '3.11'
  install-dev:
    description: 'Install dev dependencies'
    required: false
    default: 'true'

outputs:
  cache-hit:
    description: 'Whether cache was hit'
    value: ${{ steps.cache.outputs.cache-hit }}

runs:
  using: 'composite'
  steps:
    - name: Setup Python
      uses: actions/setup-python@v5
      with:
        python-version: ${{ inputs.python-version }}

    - name: Cache pip
      id: cache
      uses: actions/cache@v4
      with:
        path: ~/.cache/pip
        key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements*.txt') }}

    - name: Install dependencies
      shell: bash
      run: |
        python -m pip install --upgrade pip
        pip install -r requirements.txt
        if [ "${{ inputs.install-dev }}" == "true" ]; then
          pip install -r requirements-dev.txt
        fi
```

Use the composite action:

```yaml
# .github/workflows/ci.yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup project
        uses: ./.github/actions/setup-project
        with:
          python-version: '3.11'
          install-dev: 'true'

      - name: Run tests
        run: pytest
```

### Exercise 8: Self-Hosted Runners

#### Step 1: Understanding Self-Hosted Runners

Self-hosted runners run on your own infrastructure:

```yaml
jobs:
  build:
    # Use self-hosted runner
    runs-on: self-hosted

    # Or with labels
    runs-on: [self-hosted, linux, x64]

    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: ./build.sh
```

#### Step 2: Runner Configuration in Kubernetes

```yaml
# actions-runner-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: github-runner
  namespace: actions-runner
spec:
  replicas: 2
  selector:
    matchLabels:
      app: github-runner
  template:
    metadata:
      labels:
        app: github-runner
    spec:
      containers:
        - name: runner
          image: myoung34/github-runner:latest
          env:
            - name: REPO_URL
              value: "https://github.com/your-org/your-repo"
            - name: RUNNER_NAME_PREFIX
              value: "k8s-runner"
            - name: RUNNER_TOKEN
              valueFrom:
                secretKeyRef:
                  name: github-runner-secret
                  key: token
            - name: LABELS
              value: "self-hosted,linux,x64,kubernetes"
          volumeMounts:
            - name: docker-sock
              mountPath: /var/run/docker.sock
      volumes:
        - name: docker-sock
          hostPath:
            path: /var/run/docker.sock
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Create a GitHub Actions workflow
- [ ] Configure multiple triggers (push, PR, schedule, manual)
- [ ] Use actions from the marketplace
- [ ] Configure and use secrets
- [ ] Implement conditional execution
- [ ] Create job dependencies
- [ ] Use matrix builds
- [ ] Create reusable workflows
- [ ] Create composite actions

## Troubleshooting

### Workflow Not Triggering

```text
Common causes:
1. Workflow file in wrong location (.github/workflows/)
2. YAML syntax error
3. Branch/path filters not matching
4. Required permissions not granted
```

### Action Not Found

```yaml
# Check action reference format
uses: owner/repo@version    # Correct
uses: owner/repo@v1         # Correct (tag)
uses: owner/repo@main       # Correct (branch)
uses: owner/repo            # Wrong (missing version)
```

### Secret Not Available

```text
Check:
1. Secret name matches (case-sensitive)
2. Secret is set at correct level (repo/org/env)
3. Workflow has permission to access secrets
4. For PRs from forks, secrets are not available
```

## Key Takeaways

1. **Workflow Structure**: Events trigger workflows, which contain jobs with steps
2. **Actions**: Reusable units of code from marketplace or custom
3. **Secrets**: Secure way to handle sensitive data
4. **Conditions**: Control when jobs and steps execute
5. **Matrix**: Test across multiple configurations efficiently
6. **Reusability**: DRY principle with reusable workflows and composite actions
7. **Context**: Access to rich metadata about the workflow run

## Next Steps

In Lab 2, you will learn:

- Dockerfile best practices
- Multi-stage builds
- Container image building with GitHub Actions
- Image scanning and signing
