# Lab 5: Testing and Quality Gates

## Overview

This lab covers implementing comprehensive testing strategies and quality gates in CI/CD pipelines. You will learn to set up unit and integration tests, configure code coverage, implement container vulnerability scanning, enforce policies with OPA/Gatekeeper, and create quality gate workflows.

## Time to Complete

Estimated time: 2-3 hours

## Prerequisites

Before starting this lab, ensure you have:

- Completed Labs 1-4 of this module
- Running kind cluster
- GitHub repository with CI workflows
- Basic understanding of testing concepts

## Learning Objectives

By the end of this lab, you will be able to:

1. Implement unit and integration tests in CI pipelines
2. Configure code coverage reporting
3. Set up container vulnerability scanning
4. Implement policy enforcement with OPA
5. Create quality gate workflows
6. Generate and analyze SBOMs
7. Implement security scanning best practices

## Quality Gates Architecture

```text
Quality Gates Pipeline:

┌─────────────────────────────────────────────────────────────────┐
│                         Source Code                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Static Analysis                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Linting   │  │   SAST      │  │  Secrets    │             │
│  │ (ESLint,    │  │ (CodeQL,    │  │  Detection  │             │
│  │  golangci)  │  │  Semgrep)   │  │  (Gitleaks) │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Pass
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Testing                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    Unit     │  │ Integration │  │     E2E     │             │
│  │    Tests    │  │    Tests    │  │    Tests    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                            │                                     │
│                    Coverage >= 80%                               │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Pass
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Build & Scan                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   Build     │  │   Trivy     │  │    SBOM     │             │
│  │   Image     │  │   Scan      │  │ Generation  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                            │                                     │
│              No Critical/High Vulnerabilities                    │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Pass
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Policy Checks                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │    OPA      │  │   License   │  │  Compliance │             │
│  │   Policies  │  │   Check     │  │   Check     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└───────────────────────────┬─────────────────────────────────────┘
                            │ Pass
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                        Deploy                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Lab Exercises

### Exercise 1: Unit Testing in CI

#### Step 1: Go Application Tests

```go
// main_test.go
package main

import (
    "net/http"
    "net/http/httptest"
    "testing"
)

func TestHealthEndpoint(t *testing.T) {
    req, err := http.NewRequest("GET", "/health", nil)
    if err != nil {
        t.Fatal(err)
    }

    rr := httptest.NewRecorder()
    handler := http.HandlerFunc(healthHandler)
    handler.ServeHTTP(rr, req)

    if status := rr.Code; status != http.StatusOK {
        t.Errorf("handler returned wrong status: got %v want %v",
            status, http.StatusOK)
    }
}

func TestGreetEndpoint(t *testing.T) {
    tests := []struct {
        name     string
        path     string
        expected int
    }{
        {"root path", "/", http.StatusOK},
        {"greet with name", "/greet?name=Test", http.StatusOK},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            req, _ := http.NewRequest("GET", tt.path, nil)
            rr := httptest.NewRecorder()
            handler := http.HandlerFunc(greetHandler)
            handler.ServeHTTP(rr, req)

            if status := rr.Code; status != tt.expected {
                t.Errorf("got %v, want %v", status, tt.expected)
            }
        })
    }
}
```

#### Step 2: GitHub Actions Test Workflow

```yaml
# .github/workflows/test.yaml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'
          cache: true

      - name: Run unit tests
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage.out

  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: testpass
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

      redis:
        image: redis:7
        ports:
          - 6379:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Run integration tests
        env:
          DATABASE_URL: postgres://postgres:testpass@localhost:5432/testdb?sslmode=disable
          REDIS_URL: redis://localhost:6379
        run: go test -v -tags=integration ./...
```

#### Step 3: Python Tests with pytest

```yaml
# .github/workflows/python-tests.yaml
name: Python Tests

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        python-version: ['3.9', '3.10', '3.11']

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: 'pip'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt

      - name: Run tests with coverage
        run: |
          pytest --cov=src --cov-report=xml --cov-report=html -v

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
          fail_ci_if_error: true
```

### Exercise 2: Code Coverage Gates

#### Step 1: Coverage Threshold Check

```yaml
# .github/workflows/coverage-gate.yaml
name: Coverage Gate

on:
  pull_request:
    branches: [main]

jobs:
  coverage:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Run tests with coverage
        run: go test -coverprofile=coverage.out ./...

      - name: Check coverage threshold
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
          echo "Coverage: ${COVERAGE}%"

          THRESHOLD=80
          if (( $(echo "$COVERAGE < $THRESHOLD" | bc -l) )); then
            echo "::error::Coverage ${COVERAGE}% is below threshold ${THRESHOLD}%"
            exit 1
          fi
          echo "Coverage meets threshold"

      - name: Generate coverage report
        run: go tool cover -html=coverage.out -o coverage.html

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage.html
```

#### Step 2: Coverage Diff Check

```yaml
- name: Coverage diff
  uses: codecov/codecov-action@v3
  with:
    files: ./coverage.xml
    fail_ci_if_error: true
    flags: unittests
    name: codecov-umbrella

- name: Check coverage diff
  run: |
    # Compare with base branch coverage
    BASE_COVERAGE=$(curl -s "https://codecov.io/api/gh/${{ github.repository }}/branch/main" | jq '.commit.totals.c')
    CURRENT_COVERAGE=$(cat coverage.xml | grep -oP 'line-rate="\K[^"]+' | head -1)
    CURRENT_PCT=$(echo "$CURRENT_COVERAGE * 100" | bc)

    echo "Base coverage: ${BASE_COVERAGE}%"
    echo "Current coverage: ${CURRENT_PCT}%"

    # Fail if coverage decreased
    if (( $(echo "$CURRENT_PCT < $BASE_COVERAGE" | bc -l) )); then
      echo "::warning::Coverage decreased from ${BASE_COVERAGE}% to ${CURRENT_PCT}%"
    fi
```

### Exercise 3: Static Analysis and Linting

#### Step 1: Go Linting

```yaml
# .github/workflows/lint.yaml
name: Lint

on:
  push:
    branches: [main]
  pull_request:

jobs:
  golangci-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: golangci-lint
        uses: golangci/golangci-lint-action@v3
        with:
          version: latest
          args: --timeout=5m
```

Create `.golangci.yml`:

```yaml
# .golangci.yml
run:
  timeout: 5m

linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - typecheck
    - unused
    - gofmt
    - goimports
    - misspell
    - unconvert
    - gosec
    - bodyclose

linters-settings:
  gosec:
    excludes:
      - G104  # Audit errors not checked

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck
```

#### Step 2: SAST with CodeQL

```yaml
# .github/workflows/codeql.yaml
name: CodeQL Analysis

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 6 * * 1'

jobs:
  analyze:
    runs-on: ubuntu-latest

    permissions:
      security-events: write
      actions: read
      contents: read

    strategy:
      fail-fast: false
      matrix:
        language: ['go', 'javascript']

    steps:
      - uses: actions/checkout@v4

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v2
        with:
          languages: ${{ matrix.language }}
          queries: +security-extended

      - name: Autobuild
        uses: github/codeql-action/autobuild@v2

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v2
        with:
          category: "/language:${{ matrix.language }}"
```

#### Step 3: Secret Scanning

```yaml
# .github/workflows/secrets-scan.yaml
name: Secret Scanning

on:
  push:
    branches: [main]
  pull_request:

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Gitleaks scan
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Create `.gitleaks.toml`:

```toml
# .gitleaks.toml
title = "Gitleaks Config"

[allowlist]
  description = "Allowlist"
  paths = [
    '''go\.sum''',
    '''package-lock\.json''',
  ]

[[rules]]
  id = "aws-access-key"
  description = "AWS Access Key"
  regex = '''AKIA[0-9A-Z]{16}'''
  tags = ["aws", "credentials"]

[[rules]]
  id = "github-token"
  description = "GitHub Token"
  regex = '''ghp_[0-9a-zA-Z]{36}'''
  tags = ["github", "token"]
```

### Exercise 4: Container Vulnerability Scanning

#### Step 1: Trivy Scanning

```yaml
# .github/workflows/container-scan.yaml
name: Container Security Scan

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build-scan:
    runs-on: ubuntu-latest

    permissions:
      security-events: write

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:scan .

      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'app:scan'
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
          exit-code: '1'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v2
        if: always()
        with:
          sarif_file: 'trivy-results.sarif'

  scan-config:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Scan Dockerfile
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: '.'
          format: 'table'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'
```

#### Step 2: Grype Scanning

```yaml
- name: Scan with Grype
  uses: anchore/scan-action@v3
  with:
    image: "app:scan"
    fail-build: true
    severity-cutoff: high
    output-format: sarif

- name: Upload Grype results
  uses: github/codeql-action/upload-sarif@v2
  with:
    sarif_file: results.sarif
```

#### Step 3: Custom Vulnerability Policy

```yaml
# .github/workflows/vuln-policy.yaml
name: Vulnerability Policy

on:
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:scan .

      - name: Scan for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'app:scan'
          format: 'json'
          output: 'trivy-results.json'

      - name: Check vulnerability policy
        run: |
          CRITICAL=$(cat trivy-results.json | jq '[.Results[].Vulnerabilities[] | select(.Severity=="CRITICAL")] | length')
          HIGH=$(cat trivy-results.json | jq '[.Results[].Vulnerabilities[] | select(.Severity=="HIGH")] | length')

          echo "Critical: $CRITICAL, High: $HIGH"

          # Policy: No critical, max 5 high
          if [ "$CRITICAL" -gt 0 ]; then
            echo "::error::Found $CRITICAL critical vulnerabilities"
            exit 1
          fi

          if [ "$HIGH" -gt 5 ]; then
            echo "::error::Found $HIGH high vulnerabilities (max: 5)"
            exit 1
          fi

          echo "Vulnerability policy passed"
```

### Exercise 5: SBOM Generation

#### Step 1: Generate SBOM with Syft

```yaml
# .github/workflows/sbom.yaml
name: SBOM Generation

on:
  push:
    branches: [main]
  release:
    types: [published]

jobs:
  sbom:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:latest .

      - name: Generate SBOM (SPDX)
        uses: anchore/sbom-action@v0
        with:
          image: app:latest
          format: spdx-json
          output-file: sbom.spdx.json

      - name: Generate SBOM (CycloneDX)
        uses: anchore/sbom-action@v0
        with:
          image: app:latest
          format: cyclonedx-json
          output-file: sbom.cyclonedx.json

      - name: Upload SBOMs
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: |
            sbom.spdx.json
            sbom.cyclonedx.json

      - name: Attach SBOM to release
        if: github.event_name == 'release'
        uses: softprops/action-gh-release@v1
        with:
          files: |
            sbom.spdx.json
            sbom.cyclonedx.json
```

#### Step 2: Analyze SBOM for Licenses

```yaml
- name: Check licenses
  run: |
    # Extract licenses from SBOM
    cat sbom.spdx.json | jq -r '.packages[].licenseConcluded' | sort | uniq -c | sort -rn

    # Check for problematic licenses
    COPYLEFT=$(cat sbom.spdx.json | jq '[.packages[] | select(.licenseConcluded | test("GPL|AGPL"; "i"))] | length')

    if [ "$COPYLEFT" -gt 0 ]; then
      echo "::warning::Found $COPYLEFT packages with copyleft licenses"
      cat sbom.spdx.json | jq -r '.packages[] | select(.licenseConcluded | test("GPL|AGPL"; "i")) | "\(.name): \(.licenseConcluded)"'
    fi
```

### Exercise 6: Policy Enforcement with OPA

#### Step 1: Create OPA Policies

```rego
# policies/dockerfile.rego
package dockerfile

deny[msg] {
    input.cmd == "from"
    not startswith(input.value, "gcr.io/distroless/")
    not startswith(input.value, "alpine:")
    msg := sprintf("Base image must be distroless or alpine, got: %s", [input.value])
}

deny[msg] {
    input.cmd == "user"
    input.value == "root"
    msg := "Container must not run as root"
}

deny[msg] {
    input.cmd == "expose"
    to_number(input.value) < 1024
    msg := sprintf("Cannot expose privileged port: %s", [input.value])
}
```

```rego
# policies/kubernetes.rego
package kubernetes

deny[msg] {
    input.kind == "Deployment"
    not input.spec.template.spec.securityContext.runAsNonRoot
    msg := "Deployment must set runAsNonRoot: true"
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container %s must have resource limits", [container.name])
}

deny[msg] {
    input.kind == "Deployment"
    container := input.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Container %s must not be privileged", [container.name])
}
```

#### Step 2: OPA Policy Check in CI

```yaml
# .github/workflows/policy-check.yaml
name: Policy Check

on:
  pull_request:

jobs:
  opa-check:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup OPA
        uses: open-policy-agent/setup-opa@v2
        with:
          version: latest

      - name: Check Dockerfile policy
        run: |
          # Convert Dockerfile to JSON
          docker run --rm -i hadolint/dockerfile-json < Dockerfile > dockerfile.json

          # Run OPA check
          opa eval --data policies/dockerfile.rego --input dockerfile.json "data.dockerfile.deny"

      - name: Check Kubernetes manifests
        run: |
          for file in deploy/*.yaml; do
            echo "Checking $file..."
            result=$(opa eval --data policies/kubernetes.rego --input "$file" "data.kubernetes.deny" --format json)
            violations=$(echo "$result" | jq '.result[0].expressions[0].value | length')

            if [ "$violations" -gt 0 ]; then
              echo "::error::Policy violations in $file:"
              echo "$result" | jq -r '.result[0].expressions[0].value[]'
              exit 1
            fi
          done
```

#### Step 3: Conftest for Policy Testing

```yaml
- name: Install Conftest
  run: |
    wget https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
    tar xzf conftest_Linux_x86_64.tar.gz
    sudo mv conftest /usr/local/bin/

- name: Run Conftest
  run: |
    conftest test Dockerfile --policy policies/
    conftest test deploy/ --policy policies/
```

### Exercise 7: Complete Quality Gate Pipeline

```yaml
# .github/workflows/quality-gates.yaml
name: Quality Gates

on:
  pull_request:
    branches: [main]

jobs:
  # Gate 1: Static Analysis
  static-analysis:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Lint
        uses: golangci/golangci-lint-action@v3

      - name: Security scan (SAST)
        uses: securego/gosec@master

      - name: Secret scan
        uses: gitleaks/gitleaks-action@v2

  # Gate 2: Tests
  tests:
    runs-on: ubuntu-latest
    needs: static-analysis
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.21'

      - name: Run tests
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Check coverage
        run: |
          COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
          if (( $(echo "$COVERAGE < 80" | bc -l) )); then
            echo "::error::Coverage ${COVERAGE}% below 80%"
            exit 1
          fi

  # Gate 3: Build and Scan
  build-scan:
    runs-on: ubuntu-latest
    needs: tests
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t app:pr-${{ github.event.pull_request.number }} .

      - name: Scan for vulnerabilities
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'app:pr-${{ github.event.pull_request.number }}'
          exit-code: '1'
          severity: 'CRITICAL,HIGH'

      - name: Generate SBOM
        uses: anchore/sbom-action@v0
        with:
          image: app:pr-${{ github.event.pull_request.number }}
          format: spdx-json
          output-file: sbom.json

  # Gate 4: Policy Check
  policy-check:
    runs-on: ubuntu-latest
    needs: build-scan
    steps:
      - uses: actions/checkout@v4

      - name: Setup Conftest
        run: |
          wget -q https://github.com/open-policy-agent/conftest/releases/latest/download/conftest_Linux_x86_64.tar.gz
          tar xzf conftest_Linux_x86_64.tar.gz
          sudo mv conftest /usr/local/bin/

      - name: Check policies
        run: |
          conftest test Dockerfile --policy policies/
          conftest test deploy/ --policy policies/

  # Final: Report
  report:
    runs-on: ubuntu-latest
    needs: [static-analysis, tests, build-scan, policy-check]
    if: always()
    steps:
      - name: Quality Gate Status
        run: |
          echo "## Quality Gate Results" >> $GITHUB_STEP_SUMMARY
          echo "" >> $GITHUB_STEP_SUMMARY
          echo "| Gate | Status |" >> $GITHUB_STEP_SUMMARY
          echo "|------|--------|" >> $GITHUB_STEP_SUMMARY
          echo "| Static Analysis | ${{ needs.static-analysis.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Tests | ${{ needs.tests.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Build & Scan | ${{ needs.build-scan.result }} |" >> $GITHUB_STEP_SUMMARY
          echo "| Policy Check | ${{ needs.policy-check.result }} |" >> $GITHUB_STEP_SUMMARY

      - name: Check all gates passed
        if: contains(needs.*.result, 'failure')
        run: |
          echo "::error::One or more quality gates failed"
          exit 1
```

## Verification Checklist

Before completing this lab, verify you can:

- [ ] Set up unit and integration tests in CI
- [ ] Configure code coverage with thresholds
- [ ] Implement static analysis and linting
- [ ] Set up secret scanning
- [ ] Configure container vulnerability scanning
- [ ] Generate and analyze SBOMs
- [ ] Create OPA policies for enforcement
- [ ] Build complete quality gate pipelines

## Troubleshooting

### Test Failures

```bash
# Run tests locally with verbose output
go test -v ./...

# Check for race conditions
go test -race ./...
```

### Coverage Issues

```bash
# Generate coverage report
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Vulnerability Scan Failures

```bash
# Run Trivy locally
trivy image app:local

# Ignore specific vulnerabilities
trivy image --ignore-unfixed app:local
```

## Key Takeaways

1. **Shift Left**: Run security checks early in the pipeline
2. **Coverage Gates**: Enforce minimum coverage thresholds
3. **Vulnerability Scanning**: Block critical/high vulnerabilities
4. **SBOM**: Document software components for compliance
5. **Policy as Code**: Use OPA for consistent policy enforcement
6. **Quality Gates**: Multiple checkpoints before deployment

## Next Steps

In Lab 6, you will learn:

- Matrix builds for multi-platform support
- Pipeline parallelization strategies
- Monorepo pipeline patterns
- Advanced caching techniques
