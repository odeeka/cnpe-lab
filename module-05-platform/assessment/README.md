# Module 5 Assessment: Platform Engineering

## Overview

This assessment evaluates your platform engineering skills through practical scenarios. You'll work with developer portals, self-service infrastructure, operators, cost management, and multi-tenancy patterns.

**Duration:** 3-4 hours  
**Passing Score:** 70% (18/25 tasks)  
**Environment:** Kubernetes cluster with required platform tools

---

## Section 1: Developer Portal (Backstage) - 15%

### Task 1.1: Deploy Backstage to Kubernetes

**Scenario:** Your organization needs a centralized developer portal.

**Requirements:**

1. Deploy Backstage using the official Helm chart or manifests
2. Configure PostgreSQL backend database
3. Set up ingress with TLS for external access
4. Configure app-config.yaml with your organization details
5. Enable GitHub authentication integration

**Deliverables:**

- Backstage accessible via HTTPS
- PostgreSQL database persistent and healthy
- GitHub OAuth configured and working
- At least one user can log in

**Validation Commands:**

```bash
# Check Backstage deployment
kubectl get pods -n backstage
kubectl get ingress -n backstage

# Test database connection
kubectl exec -it -n backstage deploy/backstage -- \
  psql -h postgres -U backstage -d backstage -c '\dt'

# Verify configuration
kubectl get configmap backstage-app-config -n backstage -o yaml

# Test access
curl -k https://backstage.yourdomain.com/api/catalog/entities
```

**Scoring Criteria:**

- Backstage deployed and accessible: 2 points
- PostgreSQL configured correctly: 1 point
- TLS/Ingress working: 1 point
- GitHub auth functional: 1 point

**Total: 5 points**

---

### Task 1.2: Register Services in Software Catalog

**Scenario:** Register your platform services in the Backstage catalog.

**Requirements:**

1. Create `catalog-info.yaml` for at least 3 services:
   - An API service (e.g., payment-api)
   - A frontend application (e.g., web-app)
   - A data processing service (e.g., analytics-worker)
2. Each entity must include:
   - Proper metadata (name, description, owner, tags)
   - Lifecycle stage (production, experimental, deprecated)
   - Component type (service, website, library)
   - Dependencies between services
   - Links to repository, documentation, monitoring

**Deliverables:**

- Three valid `catalog-info.yaml` files
- Services visible in Backstage catalog
- Dependencies properly mapped
- All required fields populated

**Example Structure:**

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payment-api
  description: Payment processing REST API
  annotations:
    github.com/project-slug: myorg/payment-api
    backstage.io/techdocs-ref: dir:.
  tags:
    - api
    - payments
    - golang
  links:
    - url: https://grafana.example.com/d/payment-api
      title: Monitoring Dashboard
      icon: dashboard
spec:
  type: service
  lifecycle: production
  owner: team-payments
  dependsOn:
    - component:database-service
    - resource:payment-queue
  providesApis:
    - payment-rest-api
```

**Validation Commands:**

```bash
# Validate catalog files
backstage-cli catalog:validate catalog-info.yaml

# Check entities in catalog
curl http://localhost:7007/api/catalog/entities | jq '.[] | .metadata.name'

# Verify dependencies
curl http://localhost:7007/api/catalog/entities/by-name/component/default/payment-api | \
  jq '.spec.dependsOn'
```

**Scoring Criteria:**

- Three valid catalog-info.yaml files: 3 points
- Dependencies correctly defined: 1 point
- All required metadata present: 1 point

**Total: 5 points**

---

### Task 1.3: Create API Documentation

**Scenario:** Document the payment-api using OpenAPI and register it in Backstage.

**Requirements:**

1. Create an OpenAPI 3.0 specification for payment-api
2. Define at least 3 endpoints:
   - `POST /api/v1/payments` - Create payment
   - `GET /api/v1/payments/{id}` - Get payment status
   - `GET /api/v1/health` - Health check
3. Include request/response schemas with proper types
4. Add authentication scheme (Bearer token)
5. Register API definition in Backstage catalog
6. Link API to the payment-api component

**Deliverables:**

- Valid OpenAPI spec file (`payment-api-spec.yaml`)
- API entity in Backstage catalog
- API linked to component
- Swagger UI accessible in Backstage

**Example OpenAPI Structure:**

```yaml
openapi: 3.0.0
info:
  title: Payment API
  version: 1.0.0
  description: RESTful API for payment processing
servers:
  - url: https://api.example.com
    description: Production server

paths:
  /api/v1/payments:
    post:
      summary: Create a new payment
      operationId: createPayment
      security:
        - bearerAuth: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/PaymentRequest'
      responses:
        '201':
          description: Payment created successfully
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PaymentResponse'
        '400':
          description: Invalid request
        '401':
          description: Unauthorized

  /api/v1/payments/{id}:
    get:
      summary: Get payment status
      operationId: getPayment
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
            format: uuid
      responses:
        '200':
          description: Payment details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/PaymentResponse'

  /api/v1/health:
    get:
      summary: Health check endpoint
      operationId: healthCheck
      responses:
        '200':
          description: Service is healthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthResponse'

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
  
  schemas:
    PaymentRequest:
      type: object
      required:
        - amount
        - currency
        - customer_id
      properties:
        amount:
          type: number
          format: double
          example: 99.99
        currency:
          type: string
          example: USD
        customer_id:
          type: string
          format: uuid
    
    PaymentResponse:
      type: object
      properties:
        id:
          type: string
          format: uuid
        status:
          type: string
          enum: [pending, completed, failed]
        amount:
          type: number
        currency:
          type: string
        created_at:
          type: string
          format: date-time
    
    HealthResponse:
      type: object
      properties:
        status:
          type: string
          example: healthy
        version:
          type: string
          example: 1.0.0
```

**API Entity Registration:**

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: payment-rest-api
  description: Payment processing REST API
spec:
  type: openapi
  lifecycle: production
  owner: team-payments
  definition:
    $text: https://github.com/myorg/payment-api/blob/main/api-spec.yaml
```

**Validation Commands:**

```bash
# Validate OpenAPI spec
swagger-cli validate payment-api-spec.yaml

# Check API entity in Backstage
curl http://localhost:7007/api/catalog/entities/by-name/api/default/payment-rest-api

# Verify spec is loaded
curl http://localhost:7007/api/catalog/entities/by-name/api/default/payment-rest-api | \
  jq '.spec.definition'
```

**Scoring Criteria:**

- Valid OpenAPI 3.0 spec: 2 points
- All required endpoints defined with schemas: 1 point
- Security scheme configured: 1 point
- API registered and linked in Backstage: 1 point

**Total: 5 points**

---

### Task 1.4: Configure TechDocs

**Scenario:** Set up TechDocs for the payment-api component.

**Requirements:**

1. Create `mkdocs.yml` configuration in the repository
2. Add documentation structure with at least:
   - `docs/index.md` - Overview and getting started
   - `docs/api-reference.md` - API usage guide
   - `docs/architecture.md` - System architecture
   - `docs/runbook.md` - Operations guide
3. Configure navigation in mkdocs.yml
4. Add TechDocs annotation to catalog-info.yaml
5. Verify TechDocs builds and displays in Backstage

**Deliverables:**

- Valid mkdocs.yml configuration
- Complete documentation structure (4+ pages)
- TechDocs accessible in Backstage UI
- Documentation includes code examples

**Example mkdocs.yml:**

```yaml
site_name: Payment API Documentation
site_description: Documentation for the Payment Processing API

nav:
  - Home: index.md
  - API Reference: api-reference.md
  - Architecture: architecture.md
  - Runbook: runbook.md
  - Development:
      - Setup: development/setup.md
      - Testing: development/testing.md

theme:
  name: material
  palette:
    primary: indigo

plugins:
  - techdocs-core

markdown_extensions:
  - admonition
  - codehilite
  - toc:
      permalink: true
```

**Example Documentation (docs/index.md):**

```markdown
# Payment API

## Overview

The Payment API provides a RESTful interface for processing payments securely.

## Quick Start

### Authentication

All API requests require a Bearer token:

\`\`\`bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
  https://api.example.com/api/v1/payments
\`\`\`

### Create a Payment

\`\`\`bash
curl -X POST https://api.example.com/api/v1/payments \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 99.99,
    "currency": "USD",
    "customer_id": "cust_12345"
  }'
\`\`\`

## Architecture

See [Architecture](architecture.md) for system design details.

## Operations

See [Runbook](runbook.md) for operational procedures.
```

**Update catalog-info.yaml:**

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payment-api
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: myorg/payment-api
spec:
  type: service
  lifecycle: production
  owner: team-payments
```

**Validation Commands:**

```bash
# Build TechDocs locally
npx @techdocs/cli generate --source-dir . --output-dir ./site

# Verify structure
ls -la docs/
cat mkdocs.yml

# Check TechDocs in Backstage
curl http://localhost:7007/api/techdocs/default/component/payment-api/
```

**Scoring Criteria:**

- Valid mkdocs.yml configuration: 1 point
- Complete documentation structure (4+ pages): 2 points
- TechDocs annotation configured: 1 point
- Documentation builds and displays correctly: 1 point

**Total: 5 points**

---

## Section 1 Summary

| Task | Description | Points |
|------|-------------|--------|
| 1.1 | Deploy Backstage to Kubernetes | 5 |
| 1.2 | Register Services in Software Catalog | 5 |
| 1.3 | Create API Documentation | 5 |
| 1.4 | Configure TechDocs | 5 |
| **Total** | | **20** |

**Minimum Passing Score for Section 1:** 14/20 (70%)

---

## Section 2: Self-Service Infrastructure (Crossplane) - 15%

### Task 2.1: Composite Resource Definition (XRD)

**Scenario:** Create a Crossplane XRD for a database-as-a-service offering.

**Requirements:**

1. Define XRD for `Database` in `platform.example.com` API group
2. Support engine types: postgres, mysql, mongodb
3. Include size specifications (small, medium, large)
4. Add backup configuration options (enabled, retentionDays)
5. Expose connection details in status (endpoint, port, secretName)

**Deliverables:**

- Valid XRD manifest (`database-xrd.yaml`)
- XRD installed in cluster
- CRD auto-generated for Database resource
- Claims enabled for namespace-scoped access

**Example XRD:**

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: databases.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: Database
    plural: databases
  claimNames:
    kind: DatabaseClaim
    plural: databaseclaims
  
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - engine
                - size
              properties:
                engine:
                  type: string
                  enum:
                    - postgres
                    - mysql
                    - mongodb
                  description: Database engine type
                size:
                  type: string
                  enum:
                    - small
                    - medium
                    - large
                  description: Database instance size
                backup:
                  type: object
                  properties:
                    enabled:
                      type: boolean
                      default: true
                    retentionDays:
                      type: integer
                      minimum: 1
                      maximum: 35
                      default: 7
                highAvailability:
                  type: boolean
                  default: false
            status:
              type: object
              properties:
                endpoint:
                  type: string
                port:
                  type: integer
                secretName:
                  type: string
                state:
                  type: string
```

**Validation Commands:**

```bash
# Apply XRD
kubectl apply -f database-xrd.yaml

# Verify XRD is established
kubectl get xrd databases.platform.example.com

# Check generated CRD
kubectl get crd databases.platform.example.com
kubectl get crd databaseclaims.platform.example.com

# Explain the resource
kubectl explain databases.platform.example.com.spec
```

**Scoring Criteria:**

- Valid XRD with correct group/names: 2 points
- All required spec fields defined: 1 point
- Status fields for connection details: 1 point
- Claims enabled: 1 point

**Total: 5 points**

---

### Task 2.2: Crossplane Composition

**Scenario:** Implement the composition for AWS RDS databases.

**Requirements:**

1. Map size to RDS instance classes (db.t3.micro, db.t3.small, db.t3.medium)
2. Configure automated backups based on backup settings
3. Set up VPC security groups for database access
4. Create parameter group for engine type
5. Patch connection details to composite status

**Deliverables:**

- Valid Composition manifest (`database-composition.yaml`)
- Composition linked to Database XRD
- Proper resource mapping with patches
- Connection secret propagation

**Example Composition:**

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws-rds
  labels:
    provider: aws
    crossplane.io/xrd: databases.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: Database
  
  patchSets:
    - name: common-tags
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels
          toFieldPath: spec.forProvider.tags
          policy:
            mergeOptions:
              keepMapValues: true

  resources:
    # Security Group for Database
    - name: security-group
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroup
        spec:
          forProvider:
            region: us-east-1
            vpcId: vpc-12345678
            description: Database security group
            ingress:
              - fromPort: 5432
                toPort: 5432
                protocol: tcp
                cidrBlocks:
                  - 10.0.0.0/16
      patches:
        - type: PatchSet
          patchSetName: common-tags

    # RDS Instance
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: us-east-1
            allocatedStorage: 20
            autoMinorVersionUpgrade: true
            publiclyAccessible: false
            skipFinalSnapshot: true
            storageEncrypted: true
            storageType: gp3
          writeConnectionSecretToRef:
            namespace: crossplane-system
      patches:
        # Map engine type
        - type: FromCompositeFieldPath
          fromFieldPath: spec.engine
          toFieldPath: spec.forProvider.engine
          transforms:
            - type: map
              map:
                postgres: postgres
                mysql: mysql
                mongodb: docdb
        
        # Map size to instance class
        - type: FromCompositeFieldPath
          fromFieldPath: spec.size
          toFieldPath: spec.forProvider.instanceClass
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.t3.small
                large: db.t3.medium
        
        # Backup retention
        - type: FromCompositeFieldPath
          fromFieldPath: spec.backup.retentionDays
          toFieldPath: spec.forProvider.backupRetentionPeriod
        
        # High availability
        - type: FromCompositeFieldPath
          fromFieldPath: spec.highAvailability
          toFieldPath: spec.forProvider.multiAz
        
        # Connection secret name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: spec.writeConnectionSecretToRef.name
          transforms:
            - type: string
              string:
                fmt: "%s-connection"
        
        # Patch status with endpoint
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.endpoint
          toFieldPath: status.endpoint
        
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.port
          toFieldPath: status.port

  writeConnectionSecretsToNamespace: crossplane-system
```

**Validation Commands:**

```bash
# Apply composition
kubectl apply -f database-composition.yaml

# Verify composition is valid
kubectl get composition database-aws-rds

# Check composition details
kubectl describe composition database-aws-rds

# List all compositions for this XRD
kubectl get compositions -l crossplane.io/xrd=databases.platform.example.com
```

**Scoring Criteria:**

- Valid Composition linked to XRD: 2 points
- Size to instance class mapping: 1 point
- Backup configuration patches: 1 point
- Connection secret propagation: 1 point

**Total: 5 points**

---

### Task 2.3: Database Claim

**Scenario:** A developer needs to request a PostgreSQL database for the payments service.

**Requirements:**

1. Create a claim for a medium PostgreSQL database
2. Enable daily backups with 7-day retention
3. Request in the `payments` namespace
4. Add appropriate labels for cost tracking (team, project, environment)
5. Specify high availability requirement

**Deliverables:**

- Valid DatabaseClaim manifest (`database-claim.yaml`)
- Claim successfully provisions resources
- Connection secret available in namespace
- Status shows database endpoint

**Example Claim:**

```yaml
apiVersion: platform.example.com/v1alpha1
kind: DatabaseClaim
metadata:
  name: payment-db
  namespace: payments
  labels:
    team: payments
    project: payment-service
    environment: production
    cost-center: cc-1234
spec:
  engine: postgres
  size: medium
  backup:
    enabled: true
    retentionDays: 7
  highAvailability: true
  
  compositionSelector:
    matchLabels:
      provider: aws
  
  writeConnectionSecretToRef:
    name: payment-db-connection
```

**Verification Steps:**

```bash
# Apply the claim
kubectl apply -f database-claim.yaml

# Check claim status
kubectl get databaseclaim payment-db -n payments -o yaml

# Wait for provisioning
kubectl wait --for=condition=Ready databaseclaim/payment-db -n payments --timeout=600s

# Verify composite resource created
kubectl get database -l crossplane.io/claim-name=payment-db

# Check connection secret
kubectl get secret payment-db-connection -n payments
kubectl get secret payment-db-connection -n payments -o jsonpath='{.data}' | jq

# Verify endpoint in status
kubectl get databaseclaim payment-db -n payments -o jsonpath='{.status.endpoint}'
```

**Validation Commands:**

```bash
# Claim should be synced
kubectl get databaseclaim payment-db -n payments -o jsonpath='{.status.conditions}'

# Underlying resources created
kubectl get rdsinstance -l crossplane.io/claim-name=payment-db

# Labels applied for cost tracking
kubectl get databaseclaim payment-db -n payments -o jsonpath='{.metadata.labels}'
```

**Scoring Criteria:**

- Valid claim with correct spec: 2 points
- Cost tracking labels present: 1 point
- Connection secret reference configured: 1 point
- High availability enabled: 1 point

**Total: 5 points**

---

### Task 2.4: Composition Functions

**Scenario:** Add validation and transformation logic to the database composition using Composition Functions.

**Requirements:**

1. Create a composition function that validates database names
2. Enforce naming conventions (lowercase, max 20 chars, alphanumeric)
3. Validate size against allowed values
4. Add default labels if not provided
5. Return meaningful error messages for validation failures

**Deliverables:**

- Composition function package installed
- Updated composition using the function
- Validation working for invalid inputs
- Default labels applied when missing

**Example Function (Go):**

```go
package main

import (
    "context"
    "regexp"
    "strings"

    "github.com/crossplane/function-sdk-go"
    "github.com/crossplane/function-sdk-go/errors"
    "github.com/crossplane/function-sdk-go/logging"
    "github.com/crossplane/function-sdk-go/request"
    "github.com/crossplane/function-sdk-go/response"
)

func main() {
    function.Serve(&Function{log: logging.NewNopLogger()})
}

type Function struct {
    log logging.Logger
}

func (f *Function) RunFunction(_ context.Context, req *function.Request) (*function.Response, error) {
    rsp := response.To(req, response.DefaultTTL)

    // Get the composite resource
    xr, err := request.GetObservedCompositeResource(req)
    if err != nil {
        response.Fatal(rsp, errors.Wrapf(err, "cannot get observed composite resource"))
        return rsp, nil
    }

    // Validate database name
    name := xr.Resource.GetName()
    
    // Check length
    if len(name) > 20 {
        response.Fatal(rsp, errors.Errorf("database name '%s' exceeds 20 characters", name))
        return rsp, nil
    }

    // Check lowercase and alphanumeric
    validName := regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
    if !validName.MatchString(name) {
        response.Fatal(rsp, errors.Errorf("database name '%s' must be lowercase alphanumeric with hyphens", name))
        return rsp, nil
    }

    // Validate size
    size, _ := xr.Resource.GetString("spec.size")
    validSizes := map[string]bool{"small": true, "medium": true, "large": true}
    if !validSizes[size] {
        response.Fatal(rsp, errors.Errorf("invalid size '%s', must be small, medium, or large", size))
        return rsp, nil
    }

    // Add default labels if not present
    labels := xr.Resource.GetLabels()
    if labels == nil {
        labels = map[string]string{}
    }
    
    if _, ok := labels["managed-by"]; !ok {
        labels["managed-by"] = "crossplane"
    }
    if _, ok := labels["platform"]; !ok {
        labels["platform"] = "database-service"
    }
    
    xr.Resource.SetLabels(labels)

    // Update the desired composite
    if err := response.SetDesiredCompositeResource(rsp, xr); err != nil {
        response.Fatal(rsp, errors.Wrapf(err, "cannot set desired composite resource"))
        return rsp, nil
    }

    f.log.Info("Validation passed", "name", name, "size", size)
    return rsp, nil
}
```

**Function Package Configuration:**

```yaml
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-database-validator
spec:
  package: ghcr.io/myorg/function-database-validator:v1.0.0
```

**Updated Composition with Function:**

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws-rds
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: Database
  
  mode: Pipeline
  pipeline:
    # First: Run validation function
    - step: validate-and-transform
      functionRef:
        name: function-database-validator
    
    # Then: Render resources
    - step: render-resources
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: rds-instance
            base:
              apiVersion: rds.aws.upbound.io/v1beta1
              kind: Instance
              # ... rest of the resource definition
```

**Validation Commands:**

```bash
# Install the function package
kubectl apply -f function-database-validator.yaml

# Wait for function to be healthy
kubectl wait --for=condition=Healthy function/function-database-validator --timeout=120s

# Check function is installed
kubectl get functions.pkg.crossplane.io

# Test validation with invalid name
cat <<EOF | kubectl apply -f -
apiVersion: platform.example.com/v1alpha1
kind: DatabaseClaim
metadata:
  name: INVALID_NAME_TOO_LONG_AND_UPPERCASE
  namespace: test
spec:
  engine: postgres
  size: invalid
EOF

# Should see validation error
kubectl get databaseclaim -n test -o yaml | grep -A5 "conditions"

# Test with valid name
cat <<EOF | kubectl apply -f -
apiVersion: platform.example.com/v1alpha1
kind: DatabaseClaim
metadata:
  name: valid-db
  namespace: test
spec:
  engine: postgres
  size: medium
EOF

# Should succeed
kubectl get databaseclaim valid-db -n test -o jsonpath='{.status.conditions[0].status}'
```

**Scoring Criteria:**

- Function package installed and healthy: 2 points
- Name validation working (length, format): 1 point
- Size validation working: 1 point
- Default labels applied: 1 point

**Total: 5 points**

---

## Section 2 Summary

| Task | Description | Points |
|------|-------------|--------|
| 2.1 | Composite Resource Definition (XRD) | 5 |
| 2.2 | Crossplane Composition | 5 |
| 2.3 | Database Claim | 5 |
| 2.4 | Composition Functions | 5 |
| **Total** | | **20** |

**Minimum Passing Score for Section 2:** 14/20 (70%)

---

## Section 3: Platform Automation - 20%

### Task 3.1: Custom Resource Definition

**Scenario:** Create a CRD for developer environments that allows developers to spin up isolated environments for testing and development.

**Requirements:**

1. Define `DevEnvironment` CRD in `platform.example.com/v1alpha1`
2. Include spec fields: repository, branch, resources (cpu, memory), services (list)
3. Add status fields: phase, url, message, conditions
4. Implement CEL validation rules for field constraints
5. Add printer columns for kubectl output (NAME, PHASE, URL, AGE)

**Deliverables:**

- Valid CRD manifest (`devenvironment-crd.yaml`)
- CRD installed in cluster
- Validation rules enforced
- Printer columns display correctly

**Example CRD:**

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: devenvironments.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: DevEnvironment
    listKind: DevEnvironmentList
    plural: devenvironments
    singular: devenvironment
    shortNames:
      - devenv
      - de
  scope: Namespaced
  
  versions:
    - name: v1alpha1
      served: true
      storage: true
      
      # Printer columns for kubectl get
      additionalPrinterColumns:
        - name: Phase
          type: string
          jsonPath: .status.phase
          description: Current phase of the environment
        - name: URL
          type: string
          jsonPath: .status.url
          description: Access URL for the environment
        - name: Repository
          type: string
          jsonPath: .spec.repository
          priority: 1
        - name: Branch
          type: string
          jsonPath: .spec.branch
          priority: 1
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
      
      subresources:
        status: {}
      
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            spec:
              type: object
              required:
                - repository
                - branch
              properties:
                repository:
                  type: string
                  description: Git repository URL
                  pattern: '^https?://.*\.git$'
                branch:
                  type: string
                  description: Git branch to deploy
                  default: main
                  minLength: 1
                  maxLength: 63
                resources:
                  type: object
                  description: Resource limits for the environment
                  properties:
                    cpu:
                      type: string
                      default: "500m"
                      pattern: '^[0-9]+m?$'
                    memory:
                      type: string
                      default: "512Mi"
                      pattern: '^[0-9]+(Mi|Gi)$'
                services:
                  type: array
                  description: Additional services to deploy
                  items:
                    type: object
                    required:
                      - name
                      - image
                    properties:
                      name:
                        type: string
                        minLength: 1
                      image:
                        type: string
                      port:
                        type: integer
                        minimum: 1
                        maximum: 65535
                        default: 8080
                      replicas:
                        type: integer
                        minimum: 1
                        maximum: 10
                        default: 1
                ttlSeconds:
                  type: integer
                  description: Time-to-live in seconds (auto-cleanup)
                  minimum: 3600
                  maximum: 604800
                  default: 86400
            status:
              type: object
              properties:
                phase:
                  type: string
                  enum:
                    - Pending
                    - Creating
                    - Ready
                    - Failed
                    - Terminating
                url:
                  type: string
                message:
                  type: string
                conditions:
                  type: array
                  items:
                    type: object
                    required:
                      - type
                      - status
                    properties:
                      type:
                        type: string
                      status:
                        type: string
                        enum: ["True", "False", "Unknown"]
                      reason:
                        type: string
                      message:
                        type: string
                      lastTransitionTime:
                        type: string
                        format: date-time
                deployedServices:
                  type: array
                  items:
                    type: object
                    properties:
                      name:
                        type: string
                      ready:
                        type: boolean
                      endpoint:
                        type: string
      
      # CEL Validation Rules
      x-kubernetes-validations:
        - rule: "self.spec.resources.cpu.matches('^[0-9]+m?$')"
          message: "CPU must be in format like '500m' or '1'"
        - rule: "size(self.spec.services) <= 5"
          message: "Maximum 5 services allowed per environment"
```

**Validation Commands:**

```bash
# Apply CRD
kubectl apply -f devenvironment-crd.yaml

# Verify CRD is established
kubectl get crd devenvironments.platform.example.com
kubectl describe crd devenvironments.platform.example.com

# Check short names work
kubectl get devenv
kubectl get de

# Test printer columns with sample resource
cat <<EOF | kubectl apply -f -
apiVersion: platform.example.com/v1alpha1
kind: DevEnvironment
metadata:
  name: test-env
  namespace: default
spec:
  repository: https://github.com/example/app.git
  branch: feature-123
  resources:
    cpu: "500m"
    memory: "1Gi"
EOF

kubectl get devenv
# Should show: NAME       PHASE   URL   AGE

# Test validation - should fail
cat <<EOF | kubectl apply -f - 2>&1
apiVersion: platform.example.com/v1alpha1
kind: DevEnvironment
metadata:
  name: invalid-env
spec:
  repository: "not-a-valid-url"
  branch: ""
EOF
# Should show validation error
```

**Scoring Criteria:**

- Valid CRD with correct group/names: 2 points
- All required spec/status fields: 1 point
- CEL or pattern validation rules: 1 point
- Printer columns configured: 1 point

**Total: 5 points**

---

### Task 3.2: Kubernetes Operator Controller

**Scenario:** Implement the controller logic for DevEnvironment using Kubebuilder.

**Requirements:**

1. Watch DevEnvironment resources for changes
2. Create Deployment, Service, and Ingress for each environment
3. Update status with environment URL and phase
4. Handle deletion with finalizers for cleanup
5. Implement proper error handling and requeue logic

**Deliverables:**

- Working controller deployed to cluster
- Reconciliation creates child resources
- Status updates reflect actual state
- Finalizers clean up resources on deletion

**Example Controller (Go):**

```go
package controllers

import (
    "context"
    "fmt"

    appsv1 "k8s.io/api/apps/v1"
    corev1 "k8s.io/api/core/v1"
    networkingv1 "k8s.io/api/networking/v1"
    "k8s.io/apimachinery/pkg/api/errors"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
    "sigs.k8s.io/controller-runtime/pkg/log"

    platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

const (
    devEnvFinalizer = "platform.example.com/finalizer"
)

type DevEnvironmentReconciler struct {
    client.Client
    Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=platform.example.com,resources=devenvironments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.example.com,resources=devenvironments/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete

func (r *DevEnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    logger := log.FromContext(ctx)

    // Fetch the DevEnvironment
    devEnv := &platformv1alpha1.DevEnvironment{}
    if err := r.Get(ctx, req.NamespacedName, devEnv); err != nil {
        if errors.IsNotFound(err) {
            return ctrl.Result{}, nil
        }
        return ctrl.Result{}, err
    }

    // Handle deletion
    if !devEnv.ObjectMeta.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, devEnv)
    }

    // Add finalizer if not present
    if !controllerutil.ContainsFinalizer(devEnv, devEnvFinalizer) {
        controllerutil.AddFinalizer(devEnv, devEnvFinalizer)
        if err := r.Update(ctx, devEnv); err != nil {
            return ctrl.Result{}, err
        }
    }

    // Update phase to Creating
    if devEnv.Status.Phase == "" {
        devEnv.Status.Phase = "Creating"
        if err := r.Status().Update(ctx, devEnv); err != nil {
            return ctrl.Result{}, err
        }
    }

    // Create Deployment
    deployment := r.buildDeployment(devEnv)
    if err := controllerutil.SetControllerReference(devEnv, deployment, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }
    if err := r.createOrUpdate(ctx, deployment); err != nil {
        return r.setFailedStatus(ctx, devEnv, err)
    }

    // Create Service
    service := r.buildService(devEnv)
    if err := controllerutil.SetControllerReference(devEnv, service, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }
    if err := r.createOrUpdate(ctx, service); err != nil {
        return r.setFailedStatus(ctx, devEnv, err)
    }

    // Create Ingress
    ingress := r.buildIngress(devEnv)
    if err := controllerutil.SetControllerReference(devEnv, ingress, r.Scheme); err != nil {
        return ctrl.Result{}, err
    }
    if err := r.createOrUpdate(ctx, ingress); err != nil {
        return r.setFailedStatus(ctx, devEnv, err)
    }

    // Update status to Ready
    devEnv.Status.Phase = "Ready"
    devEnv.Status.URL = fmt.Sprintf("https://%s.dev.example.com", devEnv.Name)
    devEnv.Status.Message = "Environment ready"
    
    if err := r.Status().Update(ctx, devEnv); err != nil {
        return ctrl.Result{}, err
    }

    logger.Info("Successfully reconciled DevEnvironment", "name", devEnv.Name)
    return ctrl.Result{}, nil
}

func (r *DevEnvironmentReconciler) handleDeletion(ctx context.Context, devEnv *platformv1alpha1.DevEnvironment) (ctrl.Result, error) {
    if controllerutil.ContainsFinalizer(devEnv, devEnvFinalizer) {
        // Perform cleanup - child resources are deleted by ownerReference
        
        // Remove finalizer
        controllerutil.RemoveFinalizer(devEnv, devEnvFinalizer)
        if err := r.Update(ctx, devEnv); err != nil {
            return ctrl.Result{}, err
        }
    }
    return ctrl.Result{}, nil
}

func (r *DevEnvironmentReconciler) buildDeployment(devEnv *platformv1alpha1.DevEnvironment) *appsv1.Deployment {
    replicas := int32(1)
    return &appsv1.Deployment{
        ObjectMeta: metav1.ObjectMeta{
            Name:      devEnv.Name,
            Namespace: devEnv.Namespace,
            Labels: map[string]string{
                "app":         devEnv.Name,
                "environment": "dev",
            },
        },
        Spec: appsv1.DeploymentSpec{
            Replicas: &replicas,
            Selector: &metav1.LabelSelector{
                MatchLabels: map[string]string{"app": devEnv.Name},
            },
            Template: corev1.PodTemplateSpec{
                ObjectMeta: metav1.ObjectMeta{
                    Labels: map[string]string{"app": devEnv.Name},
                },
                Spec: corev1.PodSpec{
                    Containers: []corev1.Container{{
                        Name:  "app",
                        Image: "nginx:latest", // Would clone repo in real impl
                        Ports: []corev1.ContainerPort{{ContainerPort: 8080}},
                    }},
                },
            },
        },
    }
}

func (r *DevEnvironmentReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&platformv1alpha1.DevEnvironment{}).
        Owns(&appsv1.Deployment{}).
        Owns(&corev1.Service{}).
        Owns(&networkingv1.Ingress{}).
        Complete(r)
}
```

**Validation Commands:**

```bash
# Deploy the controller
make deploy IMG=myregistry/devenvironment-controller:v1

# Verify controller is running
kubectl get pods -n platform-system -l control-plane=controller-manager

# Check controller logs
kubectl logs -n platform-system deploy/platform-controller-manager -f

# Create a test environment
cat <<EOF | kubectl apply -f -
apiVersion: platform.example.com/v1alpha1
kind: DevEnvironment
metadata:
  name: test-env
  namespace: default
spec:
  repository: https://github.com/example/app.git
  branch: main
  resources:
    cpu: "500m"
    memory: "512Mi"
EOF

# Watch status
kubectl get devenv test-env -w

# Verify child resources created
kubectl get deploy,svc,ingress -l app=test-env

# Check status is Ready
kubectl get devenv test-env -o jsonpath='{.status.phase}'

# Test deletion cleanup
kubectl delete devenv test-env
kubectl get deploy,svc,ingress -l app=test-env
# Should be empty
```

**Scoring Criteria:**

- Controller deployed and running: 1 point
- Creates Deployment, Service, Ingress: 2 points
- Status updates correctly: 1 point
- Finalizer cleanup works: 1 point

**Total: 5 points**

---

### Task 3.3: Event-Driven Automation

**Scenario:** Set up automated deployment on Git push events using Argo Events.

**Requirements:**

1. Create Argo Events EventSource for GitHub webhooks
2. Configure Sensor to trigger on push to main branch
3. Create trigger that runs Argo Workflow for deployment
4. Filter events for specific repository
5. Pass commit SHA to workflow parameters

**Deliverables:**

- EventSource for GitHub webhooks deployed
- Sensor with proper filtering and trigger
- Argo Workflow template for deployment
- Webhook secret configured

**Example EventSource:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    platform-repo:
      repositories:
        - owner: myorg
          names:
            - platform-app
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
        url: https://webhooks.example.com
      events:
        - push
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
      insecure: false
      active: true
      contentType: json
```

**Example Sensor:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: github-deploy-sensor
  namespace: argo-events
spec:
  dependencies:
    - name: github-push
      eventSourceName: github-webhook
      eventName: platform-repo
      filters:
        data:
          # Only trigger on push to main branch
          - path: body.ref
            type: string
            value:
              - "refs/heads/main"
          # Filter by repository
          - path: body.repository.full_name
            type: string
            value:
              - "myorg/platform-app"
  
  triggers:
    - template:
        name: deploy-workflow
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: deploy-app-
              spec:
                entrypoint: deploy
                arguments:
                  parameters:
                    - name: commit-sha
                    - name: repo-url
                    - name: branch
                templates:
                  - name: deploy
                    inputs:
                      parameters:
                        - name: commit-sha
                        - name: repo-url
                        - name: branch
                    steps:
                      - - name: build-image
                          template: build
                          arguments:
                            parameters:
                              - name: commit-sha
                                value: "{{inputs.parameters.commit-sha}}"
                      - - name: deploy-app
                          template: deploy-k8s
                          arguments:
                            parameters:
                              - name: commit-sha
                                value: "{{inputs.parameters.commit-sha}}"
                  
                  - name: build
                    inputs:
                      parameters:
                        - name: commit-sha
                    container:
                      image: gcr.io/kaniko-project/executor:latest
                      args:
                        - "--dockerfile=Dockerfile"
                        - "--destination=myregistry/app:{{inputs.parameters.commit-sha}}"
                  
                  - name: deploy-k8s
                    inputs:
                      parameters:
                        - name: commit-sha
                    container:
                      image: bitnami/kubectl:latest
                      command: ["/bin/sh", "-c"]
                      args:
                        - |
                          kubectl set image deployment/app \
                            app=myregistry/app:{{inputs.parameters.commit-sha}}
          
          # Pass event data as workflow parameters
          parameters:
            - src:
                dependencyName: github-push
                dataKey: body.after
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: github-push
                dataKey: body.repository.clone_url
              dest: spec.arguments.parameters.1.value
            - src:
                dependencyName: github-push
                dataKey: body.ref
              dest: spec.arguments.parameters.2.value
      
      retryStrategy:
        steps: 3
        duration: 10s
```

**Validation Commands:**

```bash
# Deploy Argo Events
kubectl create namespace argo-events
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml

# Create GitHub secret
kubectl create secret generic github-access -n argo-events \
  --from-literal=token=$GITHUB_TOKEN \
  --from-literal=secret=$WEBHOOK_SECRET

# Apply EventSource and Sensor
kubectl apply -f eventsource.yaml
kubectl apply -f sensor.yaml

# Verify EventSource is ready
kubectl get eventsource github-webhook -n argo-events
kubectl get pods -n argo-events -l eventsource-name=github-webhook

# Verify Sensor is ready
kubectl get sensor github-deploy-sensor -n argo-events
kubectl get pods -n argo-events -l sensor-name=github-deploy-sensor

# Test with a simulated event
curl -X POST http://eventsource-svc:12000/push \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{"ref":"refs/heads/main","after":"abc123","repository":{"full_name":"myorg/platform-app","clone_url":"https://github.com/myorg/platform-app.git"}}'

# Check workflow was triggered
kubectl get workflows -n argo-events
```

**Scoring Criteria:**

- EventSource deployed and receiving events: 2 points
- Sensor filtering on branch and repo: 1 point
- Workflow triggered with correct parameters: 1 point
- Event data properly passed to workflow: 1 point

**Total: 5 points**

---

### Task 3.4: Platform CLI Plugin

**Scenario:** Create a kubectl plugin for platform operations.

**Requirements:**

1. Create `kubectl-platform` plugin in Go using Cobra
2. Implement `env create <name>` command with flags
3. Implement `env list` command with output formatting
4. Implement `env delete <name>` command with confirmation
5. Add shell completion support for bash/zsh

**Deliverables:**

- Working kubectl plugin binary
- All commands implemented and functional
- Shell completion scripts
- Help text for all commands

**Example Plugin (Go with Cobra):**

```go
package main

import (
    "context"
    "fmt"
    "os"
    "text/tabwriter"

    "github.com/spf13/cobra"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
    "k8s.io/apimachinery/pkg/runtime/schema"
    "k8s.io/client-go/dynamic"
    "k8s.io/client-go/tools/clientcmd"
)

var (
    namespace  string
    repository string
    branch     string
)

var devEnvGVR = schema.GroupVersionResource{
    Group:    "platform.example.com",
    Version:  "v1alpha1",
    Resource: "devenvironments",
}

func main() {
    rootCmd := &cobra.Command{
        Use:   "kubectl-platform",
        Short: "Platform engineering CLI tools",
        Long:  "A kubectl plugin for managing platform resources like DevEnvironments",
    }

    // Add completion command
    rootCmd.AddCommand(&cobra.Command{
        Use:   "completion [bash|zsh|fish]",
        Short: "Generate shell completion scripts",
        Args:  cobra.ExactArgs(1),
        RunE: func(cmd *cobra.Command, args []string) error {
            switch args[0] {
            case "bash":
                return rootCmd.GenBashCompletion(os.Stdout)
            case "zsh":
                return rootCmd.GenZshCompletion(os.Stdout)
            case "fish":
                return rootCmd.GenFishCompletion(os.Stdout, true)
            default:
                return fmt.Errorf("unsupported shell: %s", args[0])
            }
        },
    })

    // env command group
    envCmd := &cobra.Command{
        Use:   "env",
        Short: "Manage developer environments",
    }

    // env create
    createCmd := &cobra.Command{
        Use:   "create <name>",
        Short: "Create a new developer environment",
        Args:  cobra.ExactArgs(1),
        RunE:  createEnv,
    }
    createCmd.Flags().StringVarP(&namespace, "namespace", "n", "default", "Namespace")
    createCmd.Flags().StringVarP(&repository, "repo", "r", "", "Git repository URL (required)")
    createCmd.Flags().StringVarP(&branch, "branch", "b", "main", "Git branch")
    createCmd.MarkFlagRequired("repo")

    // env list
    listCmd := &cobra.Command{
        Use:   "list",
        Short: "List all developer environments",
        RunE:  listEnvs,
    }
    listCmd.Flags().StringVarP(&namespace, "namespace", "n", "", "Namespace (empty for all)")

    // env delete
    deleteCmd := &cobra.Command{
        Use:   "delete <name>",
        Short: "Delete a developer environment",
        Args:  cobra.ExactArgs(1),
        RunE:  deleteEnv,
    }
    deleteCmd.Flags().StringVarP(&namespace, "namespace", "n", "default", "Namespace")

    // env status
    statusCmd := &cobra.Command{
        Use:   "status <name>",
        Short: "Show status of a developer environment",
        Args:  cobra.ExactArgs(1),
        RunE:  statusEnv,
    }
    statusCmd.Flags().StringVarP(&namespace, "namespace", "n", "default", "Namespace")

    envCmd.AddCommand(createCmd, listCmd, deleteCmd, statusCmd)
    rootCmd.AddCommand(envCmd)

    if err := rootCmd.Execute(); err != nil {
        os.Exit(1)
    }
}

func getClient() (dynamic.Interface, error) {
    loadingRules := clientcmd.NewDefaultClientConfigLoadingRules()
    configOverrides := &clientcmd.ConfigOverrides{}
    kubeConfig := clientcmd.NewNonInteractiveDeferredLoadingClientConfig(loadingRules, configOverrides)
    
    config, err := kubeConfig.ClientConfig()
    if err != nil {
        return nil, err
    }
    
    return dynamic.NewForConfig(config)
}

func createEnv(cmd *cobra.Command, args []string) error {
    name := args[0]
    client, err := getClient()
    if err != nil {
        return err
    }

    devEnv := &unstructured.Unstructured{
        Object: map[string]interface{}{
            "apiVersion": "platform.example.com/v1alpha1",
            "kind":       "DevEnvironment",
            "metadata": map[string]interface{}{
                "name":      name,
                "namespace": namespace,
            },
            "spec": map[string]interface{}{
                "repository": repository,
                "branch":     branch,
                "resources": map[string]interface{}{
                    "cpu":    "500m",
                    "memory": "512Mi",
                },
            },
        },
    }

    _, err = client.Resource(devEnvGVR).Namespace(namespace).Create(
        context.TODO(), devEnv, metav1.CreateOptions{})
    if err != nil {
        return fmt.Errorf("failed to create environment: %w", err)
    }

    fmt.Printf("✓ DevEnvironment '%s' created in namespace '%s'\n", name, namespace)
    fmt.Printf("  Repository: %s\n", repository)
    fmt.Printf("  Branch: %s\n", branch)
    return nil
}

func listEnvs(cmd *cobra.Command, args []string) error {
    client, err := getClient()
    if err != nil {
        return err
    }

    var list *unstructured.UnstructuredList
    if namespace == "" {
        list, err = client.Resource(devEnvGVR).List(context.TODO(), metav1.ListOptions{})
    } else {
        list, err = client.Resource(devEnvGVR).Namespace(namespace).List(context.TODO(), metav1.ListOptions{})
    }
    if err != nil {
        return err
    }

    w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)
    fmt.Fprintln(w, "NAMESPACE\tNAME\tPHASE\tURL\tAGE")
    
    for _, item := range list.Items {
        ns := item.GetNamespace()
        name := item.GetName()
        phase, _, _ := unstructured.NestedString(item.Object, "status", "phase")
        url, _, _ := unstructured.NestedString(item.Object, "status", "url")
        age := item.GetCreationTimestamp().Time
        
        fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\n", ns, name, phase, url, formatAge(age))
    }
    w.Flush()
    return nil
}

func deleteEnv(cmd *cobra.Command, args []string) error {
    name := args[0]
    client, err := getClient()
    if err != nil {
        return err
    }

    fmt.Printf("Delete DevEnvironment '%s' in namespace '%s'? [y/N]: ", name, namespace)
    var confirm string
    fmt.Scanln(&confirm)
    if confirm != "y" && confirm != "Y" {
        fmt.Println("Cancelled")
        return nil
    }

    err = client.Resource(devEnvGVR).Namespace(namespace).Delete(
        context.TODO(), name, metav1.DeleteOptions{})
    if err != nil {
        return fmt.Errorf("failed to delete environment: %w", err)
    }

    fmt.Printf("✓ DevEnvironment '%s' deleted\n", name)
    return nil
}

func statusEnv(cmd *cobra.Command, args []string) error {
    name := args[0]
    client, err := getClient()
    if err != nil {
        return err
    }

    devEnv, err := client.Resource(devEnvGVR).Namespace(namespace).Get(
        context.TODO(), name, metav1.GetOptions{})
    if err != nil {
        return err
    }

    phase, _, _ := unstructured.NestedString(devEnv.Object, "status", "phase")
    url, _, _ := unstructured.NestedString(devEnv.Object, "status", "url")
    message, _, _ := unstructured.NestedString(devEnv.Object, "status", "message")
    repo, _, _ := unstructured.NestedString(devEnv.Object, "spec", "repository")
    branch, _, _ := unstructured.NestedString(devEnv.Object, "spec", "branch")

    fmt.Printf("Name:       %s\n", name)
    fmt.Printf("Namespace:  %s\n", namespace)
    fmt.Printf("Phase:      %s\n", phase)
    fmt.Printf("URL:        %s\n", url)
    fmt.Printf("Message:    %s\n", message)
    fmt.Printf("Repository: %s\n", repo)
    fmt.Printf("Branch:     %s\n", branch)
    return nil
}
```

**Build and Install:**

```bash
# Build the plugin
go build -o kubectl-platform ./cmd/kubectl-platform

# Install to PATH
sudo mv kubectl-platform /usr/local/bin/

# Or install to kubectl plugins directory
mkdir -p ~/.kube/plugins
mv kubectl-platform ~/.kube/plugins/

# Generate completions
kubectl platform completion bash > /etc/bash_completion.d/kubectl-platform
kubectl platform completion zsh > ~/.zsh/completions/_kubectl-platform
```

**Validation Commands:**

```bash
# Verify plugin is discoverable
kubectl plugin list | grep platform

# Test create command
kubectl platform env create test-env --repo https://github.com/org/app.git --branch main

# Test list command
kubectl platform env list
kubectl platform env list -n default

# Test status command
kubectl platform env status test-env

# Test delete command
kubectl platform env delete test-env

# Test help
kubectl platform --help
kubectl platform env --help
kubectl platform env create --help

# Test completions
source <(kubectl platform completion bash)
kubectl platform env <TAB>
```

**Scoring Criteria:**

- Plugin discoverable by kubectl: 1 point
- Create command works with flags: 1 point
- List command with proper formatting: 1 point
- Delete command with confirmation: 1 point
- Shell completion working: 1 point

**Total: 5 points**

---

## Section 3 Summary

| Task | Description | Points |
|------|-------------|--------|
| 3.1 | Custom Resource Definition | 5 |
| 3.2 | Kubernetes Operator Controller | 5 |
| 3.3 | Event-Driven Automation | 5 |
| 3.4 | Platform CLI Plugin | 5 |
| **Total** | | **20** |

**Minimum Passing Score for Section 3:** 14/20 (70%)

---

## Section 4: Cost Management - 15%

### Task 4.1: Kubecost Configuration

**Scenario:** Deploy and configure Kubecost for comprehensive cost visibility.

**Requirements:**

1. Deploy Kubecost via Helm with persistent storage
2. Configure cloud provider billing integration (AWS CUR)
3. Set up team allocation based on namespace labels
4. Configure Prometheus integration for metrics
5. Set data retention to 30 days

**Deliverables:**

- Kubecost deployed and accessible
- Cloud billing integration configured
- Team allocation labels working
- Cost data visible in dashboard

**Helm Installation:**

```bash
# Add Kubecost Helm repo
helm repo add kubecost https://kubecost.github.io/cost-analyzer/
helm repo update

# Create namespace
kubectl create namespace kubecost

# Create values file
cat <<EOF > kubecost-values.yaml
global:
  prometheus:
    enabled: true
    fqdn: http://prometheus-server.monitoring.svc:80

kubecostProductConfigs:
  clusterName: "production-cluster"
  # Cloud provider integration
  cloudIntegrationJSON: |
    {
      "aws": [
        {
          "athenaBucketName": "s3://kubecost-athena-results",
          "athenaRegion": "us-east-1",
          "athenaDatabase": "athenacurcfn_kubecost",
          "athenaTable": "kubecost",
          "projectID": "123456789012"
        }
      ]
    }

persistentVolume:
  enabled: true
  size: 32Gi
  storageClass: gp3

# Data retention
kubecostModel:
  etlDailyStoreDurationDays: 30

# Allocation settings
kubecostMetrics:
  exporter:
    enabled: true

# Team allocation labels
kubecostDeployment:
  labels:
    team: platform
EOF

# Install Kubecost
helm install kubecost kubecost/cost-analyzer \
  --namespace kubecost \
  -f kubecost-values.yaml
```

**Configure Team Allocation Labels:**

```yaml
# Namespace with cost allocation labels
apiVersion: v1
kind: Namespace
metadata:
  name: team-payments
  labels:
    team: payments
    department: engineering
    cost-center: cc-1234
    environment: production
```

**Validation Commands:**

```bash
# Check Kubecost pods are running
kubectl get pods -n kubecost

# Wait for ready
kubectl wait --for=condition=Ready pod -l app=cost-analyzer -n kubecost --timeout=300s

# Port forward to access UI
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090

# Test allocation API
curl -s http://localhost:9090/model/allocation \
  -d window=1d \
  -d aggregate=namespace | jq '.data[0] | keys'

# Check cloud integration
curl -s http://localhost:9090/model/cloudCost?window=7d | jq '.data'

# Verify Prometheus integration
kubectl get servicemonitor -n kubecost

# Check data retention setting
kubectl get cm kubecost-cost-analyzer -n kubecost -o yaml | grep etlDailyStoreDurationDays
```

**Scoring Criteria:**

- Kubecost deployed with persistent storage: 2 points
- Cloud billing integration configured: 1 point
- Team allocation labels working: 1 point
- Prometheus integration active: 1 point

**Total: 5 points**

---

### Task 4.2: Resource Quotas and LimitRanges

**Scenario:** Implement cost governance with resource quotas.

**Requirements:**

1. Create ResourceQuota for `development` namespace
2. Limit: 10 CPU, 20Gi memory, 50 pods
3. Limit PVC storage to 100Gi
4. Create LimitRange with default requests/limits
5. Add quota for LoadBalancer services (max 2)

**Deliverables:**

- ResourceQuota applied and enforced
- LimitRange with sensible defaults
- Quota prevents over-provisioning
- Clear error messages on quota breach

**Example ResourceQuota:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: development-quota
  namespace: development
spec:
  hard:
    # Compute resources
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "10"
    limits.memory: 20Gi
    
    # Object counts
    pods: "50"
    services: "20"
    services.loadbalancers: "2"
    services.nodeports: "5"
    secrets: "50"
    configmaps: "50"
    persistentvolumeclaims: "20"
    
    # Storage
    requests.storage: 100Gi
    
    # Ephemeral storage
    requests.ephemeral-storage: 50Gi
    limits.ephemeral-storage: 100Gi
```

**Example LimitRange:**

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: development-limits
  namespace: development
spec:
  limits:
    # Default limits for containers
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      min:
        cpu: "50m"
        memory: "64Mi"
      max:
        cpu: "2"
        memory: "4Gi"
    
    # Pod-level limits
    - type: Pod
      max:
        cpu: "4"
        memory: "8Gi"
    
    # PVC limits
    - type: PersistentVolumeClaim
      min:
        storage: 1Gi
      max:
        storage: 50Gi
```

**Validation Commands:**

```bash
# Apply quota and limits
kubectl apply -f resourcequota.yaml
kubectl apply -f limitrange.yaml

# Check quota status
kubectl describe resourcequota development-quota -n development

# Check limit range
kubectl describe limitrange development-limits -n development

# Test quota enforcement - this should work
kubectl run test-pod --image=nginx -n development

# Check quota used
kubectl get resourcequota -n development

# Test quota breach - this should fail
for i in $(seq 1 60); do
  kubectl run test-$i --image=nginx -n development 2>&1
done
# Should see: Error from server (Forbidden): pods "test-51" is forbidden: exceeded quota

# Test LimitRange defaults
kubectl run no-limits --image=nginx -n development
kubectl get pod no-limits -n development -o yaml | grep -A 10 resources:
# Should show default limits applied

# Test LoadBalancer quota
kubectl expose deployment test --type=LoadBalancer --port=80 -n development
kubectl expose deployment test2 --type=LoadBalancer --port=80 -n development
kubectl expose deployment test3 --type=LoadBalancer --port=80 -n development
# Third one should fail
```

**Scoring Criteria:**

- ResourceQuota with correct limits: 2 points
- LimitRange with defaults: 1 point
- Storage quota configured: 1 point
- Service quota (LoadBalancer limit): 1 point

**Total: 5 points**

---

### Task 4.3: Cost Budget Alerts

**Scenario:** Set up automated cost budget monitoring with alerts.

**Requirements:**

1. Create CostBudget CRD for budget definitions
2. Define budget: $5000/month for production namespace
3. Set alert thresholds at 50%, 80%, 100%
4. Configure Slack notification on threshold breach
5. Implement budget controller that checks costs

**Deliverables:**

- CostBudget CRD installed
- Budget resource created for production
- Alerts configured with thresholds
- Slack notifications working

**CostBudget CRD:**

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: costbudgets.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: CostBudget
    listKind: CostBudgetList
    plural: costbudgets
    singular: costbudget
    shortNames:
      - cb
  scope: Namespaced
  versions:
    - name: v1alpha1
      served: true
      storage: true
      subresources:
        status: {}
      additionalPrinterColumns:
        - name: Budget
          type: string
          jsonPath: .spec.budget.amount
        - name: Current
          type: string
          jsonPath: .status.currentSpend
        - name: Percentage
          type: string
          jsonPath: .status.percentUsed
        - name: Status
          type: string
          jsonPath: .status.phase
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required:
                - budget
                - namespace
              properties:
                namespace:
                  type: string
                  description: Target namespace to monitor
                budget:
                  type: object
                  properties:
                    amount:
                      type: number
                      description: Budget amount in dollars
                    period:
                      type: string
                      enum: [daily, weekly, monthly]
                      default: monthly
                    currency:
                      type: string
                      default: USD
                alerts:
                  type: array
                  items:
                    type: object
                    properties:
                      threshold:
                        type: integer
                        minimum: 1
                        maximum: 100
                      channel:
                        type: string
                        enum: [slack, email, pagerduty]
                      target:
                        type: string
                notification:
                  type: object
                  properties:
                    slack:
                      type: object
                      properties:
                        webhookSecretRef:
                          type: object
                          properties:
                            name:
                              type: string
                            key:
                              type: string
                        channel:
                          type: string
            status:
              type: object
              properties:
                currentSpend:
                  type: string
                percentUsed:
                  type: string
                phase:
                  type: string
                  enum: [OK, Warning, Critical, Exceeded]
                lastChecked:
                  type: string
                  format: date-time
                alertsTriggered:
                  type: array
                  items:
                    type: object
                    properties:
                      threshold:
                        type: integer
                      triggeredAt:
                        type: string
                        format: date-time
                      notified:
                        type: boolean
```

**Example CostBudget:**

```yaml
apiVersion: platform.example.com/v1alpha1
kind: CostBudget
metadata:
  name: production-budget
  namespace: platform-system
spec:
  namespace: production
  budget:
    amount: 5000
    period: monthly
    currency: USD
  
  alerts:
    - threshold: 50
      channel: slack
      target: "#platform-costs"
    - threshold: 80
      channel: slack
      target: "#platform-costs"
    - threshold: 100
      channel: pagerduty
      target: platform-oncall
  
  notification:
    slack:
      webhookSecretRef:
        name: slack-webhook
        key: url
      channel: "#platform-costs"
```

**Budget Controller Snippet:**

```go
func (r *CostBudgetReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    budget := &platformv1alpha1.CostBudget{}
    if err := r.Get(ctx, req.NamespacedName, budget); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Query Kubecost for current spend
    currentSpend, err := r.queryKubecost(budget.Spec.Namespace)
    if err != nil {
        return ctrl.Result{}, err
    }

    // Calculate percentage
    percentUsed := (currentSpend / budget.Spec.Budget.Amount) * 100

    // Update status
    budget.Status.CurrentSpend = fmt.Sprintf("$%.2f", currentSpend)
    budget.Status.PercentUsed = fmt.Sprintf("%.1f%%", percentUsed)
    budget.Status.LastChecked = metav1.Now()

    // Determine phase and check alerts
    switch {
    case percentUsed >= 100:
        budget.Status.Phase = "Exceeded"
    case percentUsed >= 80:
        budget.Status.Phase = "Critical"
    case percentUsed >= 50:
        budget.Status.Phase = "Warning"
    default:
        budget.Status.Phase = "OK"
    }

    // Send alerts for crossed thresholds
    for _, alert := range budget.Spec.Alerts {
        if percentUsed >= float64(alert.Threshold) {
            if !r.alertAlreadySent(budget, alert.Threshold) {
                r.sendAlert(ctx, budget, alert, currentSpend, percentUsed)
            }
        }
    }

    r.Status().Update(ctx, budget)
    
    // Requeue to check again in 1 hour
    return ctrl.Result{RequeueAfter: time.Hour}, nil
}
```

**Validation Commands:**

```bash
# Apply CRD
kubectl apply -f costbudget-crd.yaml

# Create Slack webhook secret
kubectl create secret generic slack-webhook -n platform-system \
  --from-literal=url=https://hooks.slack.com/services/xxx/yyy/zzz

# Create budget
kubectl apply -f production-budget.yaml

# Check budget status
kubectl get costbudget -n platform-system
kubectl describe costbudget production-budget -n platform-system

# Verify alerts configuration
kubectl get costbudget production-budget -n platform-system -o jsonpath='{.spec.alerts}'

# Check controller logs
kubectl logs -n platform-system deploy/budget-controller | grep -i "checking budget"

# Simulate alert (if testing)
kubectl patch costbudget production-budget -n platform-system \
  --type=merge -p '{"status":{"percentUsed":"85%","phase":"Critical"}}'
```

**Scoring Criteria:**

- CostBudget CRD installed: 1 point
- Budget resource with correct spec: 1 point
- Alert thresholds configured: 1 point
- Slack notification integration: 1 point
- Status updates working: 1 point

**Total: 5 points**

---

### Task 4.4: Right-Sizing Recommendations

**Scenario:** Generate and apply resource right-sizing recommendations.

**Requirements:**

1. Query Kubecost for right-sizing recommendations
2. Create report of over-provisioned workloads
3. Generate patch manifests for top 5 wasteful deployments
4. Calculate potential monthly savings
5. Apply recommendations to staging namespace

**Deliverables:**

- Script to fetch and process recommendations
- JSON report with over-provisioned workloads
- Patch files for deployments
- Savings calculation summary

**Right-Sizing Script:**

```bash
#!/bin/bash
# rightsizing.sh - Fetch and apply right-sizing recommendations

KUBECOST_URL="${KUBECOST_URL:-http://localhost:9090}"
OUTPUT_DIR="${OUTPUT_DIR:-./rightsizing-output}"
APPLY_TO_NAMESPACE="${1:-staging}"

mkdir -p "$OUTPUT_DIR"

echo "=== Fetching Right-Sizing Recommendations ==="

# Get recommendations from Kubecost
curl -s "${KUBECOST_URL}/model/savings/requestSizing" \
  -G -d window=7d -d targetUtilization=0.8 \
  | jq '.' > "$OUTPUT_DIR/recommendations.json"

# Parse and create report
cat "$OUTPUT_DIR/recommendations.json" | jq -r '
  .data // [] | 
  sort_by(.monthlySavings) | 
  reverse | 
  .[:10] | 
  .[] | 
  {
    namespace: .namespace,
    controller: .controllerName,
    container: .containerName,
    currentCPU: .currentRequest.cpu,
    recommendedCPU: .recommendedRequest.cpu,
    currentMemory: .currentRequest.memory,
    recommendedMemory: .recommendedRequest.memory,
    monthlySavings: .monthlySavings
  }
' > "$OUTPUT_DIR/report.json"

echo "=== Top Over-Provisioned Workloads ==="
cat "$OUTPUT_DIR/report.json" | jq -s '.' | jq -r '
  ["NAMESPACE", "CONTROLLER", "CURRENT_CPU", "REC_CPU", "CURRENT_MEM", "REC_MEM", "SAVINGS"],
  (.[] | [.namespace, .controller, .currentCPU, .recommendedCPU, .currentMemory, .recommendedMemory, "$\(.monthlySavings)"]) 
  | @tsv
' | column -t

# Calculate total savings
TOTAL_SAVINGS=$(cat "$OUTPUT_DIR/report.json" | jq -s '[.[].monthlySavings] | add')
echo ""
echo "=== Total Potential Monthly Savings: \$${TOTAL_SAVINGS} ==="

# Generate patch files for top 5
echo ""
echo "=== Generating Patch Files ==="

cat "$OUTPUT_DIR/recommendations.json" | jq -r '
  .data // [] | 
  sort_by(.monthlySavings) | 
  reverse | 
  .[:5] | 
  .[] | 
  @base64
' | while read -r rec; do
  DATA=$(echo "$rec" | base64 -d)
  NS=$(echo "$DATA" | jq -r '.namespace')
  CONTROLLER=$(echo "$DATA" | jq -r '.controllerName')
  CONTAINER=$(echo "$DATA" | jq -r '.containerName')
  REC_CPU=$(echo "$DATA" | jq -r '.recommendedRequest.cpu')
  REC_MEM=$(echo "$DATA" | jq -r '.recommendedRequest.memory')
  
  PATCH_FILE="$OUTPUT_DIR/patch-${NS}-${CONTROLLER}.yaml"
  
  cat > "$PATCH_FILE" <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${CONTROLLER}
  namespace: ${NS}
spec:
  template:
    spec:
      containers:
        - name: ${CONTAINER}
          resources:
            requests:
              cpu: "${REC_CPU}"
              memory: "${REC_MEM}"
            limits:
              cpu: "${REC_CPU}"
              memory: "${REC_MEM}"
EOF
  
  echo "Created: $PATCH_FILE"
done

# Apply patches to specified namespace
if [ "$APPLY_TO_NAMESPACE" != "none" ]; then
  echo ""
  echo "=== Applying Patches to $APPLY_TO_NAMESPACE ==="
  
  for patch in "$OUTPUT_DIR"/patch-${APPLY_TO_NAMESPACE}-*.yaml; do
    if [ -f "$patch" ]; then
      echo "Applying: $patch"
      kubectl apply -f "$patch" --dry-run=client
      # Uncomment to actually apply:
      # kubectl apply -f "$patch"
    fi
  done
fi

echo ""
echo "=== Summary ==="
echo "Report: $OUTPUT_DIR/report.json"
echo "Recommendations: $OUTPUT_DIR/recommendations.json"
echo "Patch files: $OUTPUT_DIR/patch-*.yaml"
echo "Total potential savings: \$${TOTAL_SAVINGS}/month"
```

**Validation Commands:**

```bash
# Port forward Kubecost
kubectl port-forward -n kubecost svc/kubecost-cost-analyzer 9090:9090 &

# Run right-sizing script
chmod +x rightsizing.sh
./rightsizing.sh staging

# Check generated files
ls -la rightsizing-output/
cat rightsizing-output/report.json | jq '.'

# View recommendations count
cat rightsizing-output/recommendations.json | jq '.data | length'

# Check patch files
cat rightsizing-output/patch-*.yaml

# Dry-run apply patches
for patch in rightsizing-output/patch-staging-*.yaml; do
  kubectl apply -f "$patch" --dry-run=server
done

# Apply to staging (if approved)
kubectl apply -f rightsizing-output/patch-staging-*.yaml

# Verify changes
kubectl get deploy -n staging -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.template.spec.containers[0].resources}{"\n"}{end}'
```

**Scoring Criteria:**

- Fetch recommendations from Kubecost: 1 point
- Generate readable report: 1 point
- Create patch manifests: 1 point
- Calculate savings: 1 point
- Apply to staging namespace: 1 point

**Total: 5 points**

---

## Section 4 Summary

| Task | Description | Points |
|------|-------------|--------|
| 4.1 | Kubecost Configuration | 5 |
| 4.2 | Resource Quotas and LimitRanges | 5 |
| 4.3 | Cost Budget Alerts | 5 |
| 4.4 | Right-Sizing Recommendations | 5 |
| **Total** | | **20** |

**Minimum Passing Score for Section 4:** 14/20 (70%)

---

## Section 5: Multi-Tenancy - 15%

### Task 5.1: Namespace Isolation

**Scenario:** Set up complete tenant isolation for a new team called `analytics`.

**Requirements:**

1. Create namespace for team `analytics` with proper labels
2. Apply ResourceQuota (8 CPU, 16Gi memory, 30 pods)
3. Configure LimitRange with sensible defaults
4. Create RBAC for team members (admin, developer, viewer roles)
5. Apply NetworkPolicy for namespace isolation

**Deliverables:**

- Namespace with tenant labels
- ResourceQuota and LimitRange applied
- RBAC roles and bindings configured
- NetworkPolicy blocking cross-namespace traffic

**Example Namespace with Labels:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: analytics
  labels:
    tenant: analytics
    team: analytics
    cost-center: cc-analytics
    environment: production
```

**ResourceQuota:**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: analytics-quota
  namespace: analytics
spec:
  hard:
    requests.cpu: "6"
    requests.memory: 12Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "30"
    services: "10"
    persistentvolumeclaims: "10"
    requests.storage: 50Gi
```

**LimitRange:**

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: analytics-limits
  namespace: analytics
spec:
  limits:
    - type: Container
      default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      min:
        cpu: "50m"
        memory: "64Mi"
      max:
        cpu: "2"
        memory: "4Gi"
```

**RBAC Configuration:**

```yaml
# Admin Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: analytics-admin
  namespace: analytics
rules:
  - apiGroups: ["", "apps", "batch", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list", "create", "update", "delete"]
---
# Developer Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: analytics-developer
  namespace: analytics
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "services", "configmaps", "jobs"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
  - apiGroups: [""]
    resources: ["pods/log", "pods/exec"]
    verbs: ["get", "create"]
---
# Viewer Role
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: analytics-viewer
  namespace: analytics
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["*"]
    verbs: ["get", "list", "watch"]
---
# RoleBindings
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: analytics-admins
  namespace: analytics
subjects:
  - kind: Group
    name: analytics-admins
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: analytics-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: analytics-developers
  namespace: analytics
subjects:
  - kind: Group
    name: analytics-developers
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: analytics-developer
  apiGroup: rbac.authorization.k8s.io
```

**NetworkPolicy for Isolation:**

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: analytics
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow traffic within same namespace
    - from:
        - podSelector: {}
    # Allow traffic from ingress controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
    # Allow traffic from monitoring
    - from:
        - namespaceSelector:
            matchLabels:
              name: monitoring
  egress:
    # Allow traffic within same namespace
    - to:
        - podSelector: {}
    # Allow DNS
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
    # Allow external traffic
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
```

**Validation Commands:**

```bash
# Create all resources
kubectl apply -f namespace.yaml
kubectl apply -f resourcequota.yaml
kubectl apply -f limitrange.yaml
kubectl apply -f rbac.yaml
kubectl apply -f networkpolicy.yaml

# Verify namespace
kubectl describe ns analytics

# Check quota
kubectl get resourcequota -n analytics

# Check limit range
kubectl describe limitrange -n analytics

# Test RBAC
kubectl auth can-i --list --as=system:serviceaccount:analytics:default -n analytics
kubectl auth can-i create deployments --as=developer@example.com -n analytics
kubectl auth can-i delete secrets --as=viewer@example.com -n analytics  # Should be no

# Test network isolation
kubectl run test-pod --image=nginx -n analytics
kubectl exec -n analytics test-pod -- curl -s http://some-service.other-namespace.svc  # Should fail
kubectl exec -n analytics test-pod -- curl -s http://some-service.analytics.svc  # Should work

# Verify network policy
kubectl get networkpolicy -n analytics
kubectl describe networkpolicy tenant-isolation -n analytics
```

**Scoring Criteria:**

- Namespace with labels created: 1 point
- ResourceQuota configured correctly: 1 point
- LimitRange with defaults: 1 point
- RBAC roles and bindings: 1 point
- NetworkPolicy for isolation: 1 point

**Total: 5 points**

---

### Task 5.2: Hierarchical Namespaces

**Scenario:** Implement hierarchical namespace structure for the platform team.

**Requirements:**

1. Install Hierarchical Namespace Controller (HNC)
2. Create parent namespace `platform-team`
3. Create child namespaces: dev, staging, prod
4. Propagate ResourceQuota to children
5. Propagate RBAC roles to children

**Deliverables:**

- HNC installed and operational
- Parent-child namespace hierarchy
- Resource propagation working
- RBAC inheritance functioning

**Install HNC:**

```bash
# Install HNC
kubectl apply -f https://github.com/kubernetes-sigs/hierarchical-namespaces/releases/download/v1.1.0/default.yaml

# Wait for HNC to be ready
kubectl wait --for=condition=Available deployment/hnc-controller-manager -n hnc-system --timeout=120s

# Verify installation
kubectl get pods -n hnc-system
```

**Create Hierarchy:**

```yaml
# Parent namespace
apiVersion: v1
kind: Namespace
metadata:
  name: platform-team
  labels:
    team: platform
---
# Create subnamespaces
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: dev
  namespace: platform-team
---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: staging
  namespace: platform-team
---
apiVersion: hnc.x-k8s.io/v1alpha2
kind: SubnamespaceAnchor
metadata:
  name: prod
  namespace: platform-team
```

**Configure Propagation:**

```yaml
# HNC Configuration to propagate resources
apiVersion: hnc.x-k8s.io/v1alpha2
kind: HNCConfiguration
metadata:
  name: config
spec:
  resources:
    # Propagate ResourceQuotas
    - resource: resourcequotas
      mode: Propagate
    # Propagate LimitRanges
    - resource: limitranges
      mode: Propagate
    # Propagate Roles
    - resource: roles
      mode: Propagate
    # Propagate RoleBindings
    - resource: rolebindings
      mode: Propagate
    # Propagate NetworkPolicies
    - resource: networkpolicies
      mode: Propagate
    # Propagate Secrets (selectively)
    - resource: secrets
      mode: Propagate
```

**Parent ResourceQuota (will propagate):**

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: platform-team
  labels:
    hnc.x-k8s.io/inherited-from: platform-team
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
```

**Parent Role (will propagate):**

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: platform-developer
  namespace: platform-team
rules:
  - apiGroups: ["", "apps", "batch"]
    resources: ["pods", "deployments", "services", "configmaps"]
    verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: platform-developers
  namespace: platform-team
subjects:
  - kind: Group
    name: platform-team
    apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: platform-developer
  apiGroup: rbac.authorization.k8s.io
```

**Validation Commands:**

```bash
# Create parent namespace
kubectl create ns platform-team

# Create subnamespaces
kubectl apply -f subnamespaces.yaml

# View hierarchy
kubectl hns tree platform-team

# Expected output:
# platform-team
# ├── dev
# ├── staging
# └── prod

# Check subnamespace status
kubectl get subnamespaceanchors -n platform-team

# Create quota in parent
kubectl apply -f resourcequota.yaml

# Verify propagation to children
kubectl get resourcequota -n platform-team-dev
kubectl get resourcequota -n platform-team-staging
kubectl get resourcequota -n platform-team-prod

# Create role in parent
kubectl apply -f rbac.yaml

# Verify RBAC propagation
kubectl get roles -n platform-team-dev
kubectl get rolebindings -n platform-team-dev

# Test RBAC works in child
kubectl auth can-i create pods --as=developer@platform-team -n platform-team-dev

# Describe hierarchy config
kubectl get hierarchyconfigurations.hnc.x-k8s.io -n platform-team -o yaml
```

**Scoring Criteria:**

- HNC installed and running: 1 point
- Parent-child hierarchy created: 1 point
- ResourceQuota propagation: 1 point
- RBAC propagation: 1 point
- All child namespaces functional: 1 point

**Total: 5 points**

---

### Task 5.3: Virtual Clusters

**Scenario:** Provision a vCluster for isolated testing environment.

**Requirements:**

1. Deploy vCluster named `test-cluster` in `vcluster-test` namespace
2. Configure resource limits for the vCluster (2 CPU, 4Gi memory)
3. Enable sync for specific resources (deployments, services, ingresses)
4. Set up ingress for vCluster API access
5. Generate kubeconfig for vCluster access

**Deliverables:**

- vCluster running in host cluster
- Resource limits enforced
- Resource syncing configured
- External API access via ingress
- Working kubeconfig

**Install vCluster CLI:**

```bash
# Install vCluster CLI
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"
chmod +x vcluster
sudo mv vcluster /usr/local/bin/
```

**Create vCluster with Helm:**

```yaml
# vcluster-values.yaml
vcluster:
  image: rancher/k3s:v1.28.2-k3s1

syncer:
  extraArgs:
    - --sync=ingresses
    - --sync=persistentvolumes
    - --sync=storageclasses

sync:
  services:
    enabled: true
  configmaps:
    enabled: true
  secrets:
    enabled: true
  endpoints:
    enabled: true
  pods:
    enabled: true
  events:
    enabled: true
  persistentvolumeclaims:
    enabled: true
  ingresses:
    enabled: true

# Resource limits for vCluster pods
resources:
  limits:
    cpu: "2"
    memory: 4Gi
  requests:
    cpu: "500m"
    memory: 1Gi

# Ingress for API access
ingress:
  enabled: true
  host: test-cluster.example.com
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/backend-protocol: HTTPS
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"

# Isolation settings
isolation:
  enabled: true
  resourceQuota:
    enabled: true
    quota:
      requests.cpu: "4"
      requests.memory: 8Gi
      limits.cpu: "8"
      limits.memory: 16Gi
      pods: "50"
  limitRange:
    enabled: true
    default:
      cpu: "500m"
      memory: "512Mi"
    defaultRequest:
      cpu: "100m"
      memory: "128Mi"
```

**Deploy vCluster:**

```bash
# Create namespace
kubectl create namespace vcluster-test

# Install vCluster via Helm
helm repo add loft https://charts.loft.sh
helm repo update

helm install test-cluster loft/vcluster \
  --namespace vcluster-test \
  --values vcluster-values.yaml

# Or use vCluster CLI
vcluster create test-cluster \
  --namespace vcluster-test \
  --values vcluster-values.yaml
```

**Generate Kubeconfig:**

```bash
# Using vCluster CLI
vcluster connect test-cluster \
  --namespace vcluster-test \
  --kube-config ./vcluster-kubeconfig.yaml

# Or manually extract
kubectl get secret vc-test-cluster -n vcluster-test -o jsonpath='{.data.config}' | base64 -d > vcluster-kubeconfig.yaml
```

**Validation Commands:**

```bash
# Check vCluster pods are running
kubectl get pods -n vcluster-test
kubectl wait --for=condition=Ready pod -l app=vcluster -n vcluster-test --timeout=300s

# View vCluster status
vcluster list

# Connect to vCluster
vcluster connect test-cluster -n vcluster-test

# Or use kubeconfig directly
export KUBECONFIG=./vcluster-kubeconfig.yaml

# Verify vCluster is working
kubectl get nodes
kubectl get namespaces

# Create resources in vCluster
kubectl create namespace test-app
kubectl create deployment nginx --image=nginx -n test-app
kubectl expose deployment nginx --port=80 -n test-app

# Verify resources are synced to host cluster
KUBECONFIG=~/.kube/config kubectl get pods -n vcluster-test
# Should see the nginx pod from vCluster

# Check resource limits
kubectl get resourcequota -n vcluster-test

# Test ingress access (if configured)
curl -k https://test-cluster.example.com/api/v1/namespaces

# Disconnect
vcluster disconnect
```

**Scoring Criteria:**

- vCluster deployed and running: 2 points
- Resource limits configured: 1 point
- Resource syncing working: 1 point
- Kubeconfig generated and working: 1 point

**Total: 5 points**

---

### Task 5.4: Tenant Onboarding Automation

**Scenario:** Automate complete tenant onboarding with a custom controller.

**Requirements:**

1. Create Tenant CRD with all required fields
2. Implement controller that provisions:
   - Namespace with tenant labels
   - ResourceQuota and LimitRange
   - NetworkPolicy for isolation
   - RBAC for tenant admins and developers
3. Update status with provisioned resources
4. Handle tenant deletion with cleanup
5. Send Slack notification on completion

**Deliverables:**

- Tenant CRD installed
- Controller deployed and functioning
- All resources created on Tenant creation
- Cleanup on Tenant deletion
- Notifications working

**Tenant CRD:**

```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: tenants.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: Tenant
    listKind: TenantList
    plural: tenants
    singular: tenant
    shortNames:
      - tn
  scope: Cluster
  versions:
    - name: v1alpha1
      served: true
      storage: true
      subresources:
        status: {}
      additionalPrinterColumns:
        - name: Phase
          type: string
          jsonPath: .status.phase
        - name: Namespace
          type: string
          jsonPath: .status.namespace
        - name: Age
          type: date
          jsonPath: .metadata.creationTimestamp
      schema:
        openAPIV3Schema:
          type: object
          required:
            - spec
          properties:
            spec:
              type: object
              required:
                - name
                - adminEmail
              properties:
                name:
                  type: string
                  description: Tenant name (used for namespace)
                  pattern: '^[a-z][a-z0-9-]*$'
                  maxLength: 20
                adminEmail:
                  type: string
                  format: email
                adminGroups:
                  type: array
                  items:
                    type: string
                developerGroups:
                  type: array
                  items:
                    type: string
                resources:
                  type: object
                  properties:
                    cpuLimit:
                      type: string
                      default: "8"
                    memoryLimit:
                      type: string
                      default: "16Gi"
                    storageLimit:
                      type: string
                      default: "100Gi"
                    podLimit:
                      type: integer
                      default: 50
                networkIsolation:
                  type: boolean
                  default: true
                costCenter:
                  type: string
                notification:
                  type: object
                  properties:
                    slack:
                      type: object
                      properties:
                        channel:
                          type: string
                        webhookSecretRef:
                          type: string
            status:
              type: object
              properties:
                phase:
                  type: string
                  enum:
                    - Pending
                    - Provisioning
                    - Ready
                    - Failed
                    - Terminating
                namespace:
                  type: string
                message:
                  type: string
                conditions:
                  type: array
                  items:
                    type: object
                    properties:
                      type:
                        type: string
                      status:
                        type: string
                      reason:
                        type: string
                      message:
                        type: string
                      lastTransitionTime:
                        type: string
                        format: date-time
                provisionedResources:
                  type: object
                  properties:
                    namespace:
                      type: boolean
                    resourceQuota:
                      type: boolean
                    limitRange:
                      type: boolean
                    networkPolicy:
                      type: boolean
                    rbac:
                      type: boolean
```

**Example Tenant:**

```yaml
apiVersion: platform.example.com/v1alpha1
kind: Tenant
metadata:
  name: analytics-team
spec:
  name: analytics
  adminEmail: analytics-admin@example.com
  adminGroups:
    - analytics-admins
  developerGroups:
    - analytics-developers
  resources:
    cpuLimit: "16"
    memoryLimit: "32Gi"
    storageLimit: "200Gi"
    podLimit: 100
  networkIsolation: true
  costCenter: cc-analytics-2024
  notification:
    slack:
      channel: "#platform-notifications"
      webhookSecretRef: slack-webhook
```

**Controller Logic (Simplified):**

```go
func (r *TenantReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch Tenant
    tenant := &platformv1alpha1.Tenant{}
    if err := r.Get(ctx, req.NamespacedName, tenant); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Handle deletion
    if !tenant.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, tenant)
    }

    // Add finalizer
    if !controllerutil.ContainsFinalizer(tenant, tenantFinalizer) {
        controllerutil.AddFinalizer(tenant, tenantFinalizer)
        return ctrl.Result{}, r.Update(ctx, tenant)
    }

    // Update phase
    tenant.Status.Phase = "Provisioning"
    r.Status().Update(ctx, tenant)

    // 1. Create Namespace
    ns := r.buildNamespace(tenant)
    if err := r.createIfNotExists(ctx, ns); err != nil {
        return r.setFailed(ctx, tenant, "Namespace", err)
    }
    tenant.Status.ProvisionedResources.Namespace = true

    // 2. Create ResourceQuota
    quota := r.buildResourceQuota(tenant)
    if err := r.createIfNotExists(ctx, quota); err != nil {
        return r.setFailed(ctx, tenant, "ResourceQuota", err)
    }
    tenant.Status.ProvisionedResources.ResourceQuota = true

    // 3. Create LimitRange
    limits := r.buildLimitRange(tenant)
    if err := r.createIfNotExists(ctx, limits); err != nil {
        return r.setFailed(ctx, tenant, "LimitRange", err)
    }
    tenant.Status.ProvisionedResources.LimitRange = true

    // 4. Create NetworkPolicy
    if tenant.Spec.NetworkIsolation {
        netpol := r.buildNetworkPolicy(tenant)
        if err := r.createIfNotExists(ctx, netpol); err != nil {
            return r.setFailed(ctx, tenant, "NetworkPolicy", err)
        }
    }
    tenant.Status.ProvisionedResources.NetworkPolicy = true

    // 5. Create RBAC
    if err := r.createRBAC(ctx, tenant); err != nil {
        return r.setFailed(ctx, tenant, "RBAC", err)
    }
    tenant.Status.ProvisionedResources.RBAC = true

    // Update status to Ready
    tenant.Status.Phase = "Ready"
    tenant.Status.Namespace = tenant.Spec.Name
    tenant.Status.Message = "Tenant provisioned successfully"
    r.Status().Update(ctx, tenant)

    // Send notification
    if tenant.Spec.Notification.Slack.Channel != "" {
        r.sendSlackNotification(ctx, tenant, "Tenant provisioned successfully")
    }

    log.Info("Tenant provisioned", "name", tenant.Name)
    return ctrl.Result{}, nil
}

func (r *TenantReconciler) handleDeletion(ctx context.Context, tenant *platformv1alpha1.Tenant) (ctrl.Result, error) {
    // Delete namespace (cascades to all resources)
    ns := &corev1.Namespace{}
    ns.Name = tenant.Spec.Name
    if err := r.Delete(ctx, ns); err != nil && !errors.IsNotFound(err) {
        return ctrl.Result{}, err
    }

    // Remove finalizer
    controllerutil.RemoveFinalizer(tenant, tenantFinalizer)
    return ctrl.Result{}, r.Update(ctx, tenant)
}
```

**Validation Commands:**

```bash
# Apply CRD
kubectl apply -f tenant-crd.yaml

# Deploy controller
kubectl apply -f tenant-controller.yaml

# Verify controller is running
kubectl get pods -n platform-system -l app=tenant-controller

# Create a tenant
kubectl apply -f analytics-tenant.yaml

# Watch tenant status
kubectl get tenant analytics-team -w

# Check phase is Ready
kubectl get tenant analytics-team -o jsonpath='{.status.phase}'

# Verify all resources created
kubectl get ns analytics
kubectl get resourcequota -n analytics
kubectl get limitrange -n analytics
kubectl get networkpolicy -n analytics
kubectl get rolebindings -n analytics

# Test RBAC
kubectl auth can-i create pods --as=user@analytics-admins -n analytics

# Check provisioned resources in status
kubectl get tenant analytics-team -o jsonpath='{.status.provisionedResources}'

# Delete tenant
kubectl delete tenant analytics-team

# Verify cleanup
kubectl get ns analytics  # Should be gone
```

**Scoring Criteria:**

- Tenant CRD installed: 1 point
- Controller creates all resources: 2 points
- Status updates correctly: 1 point
- Deletion cleanup works: 1 point

**Total: 5 points**

---

## Section 5 Summary

| Task | Description | Points |
|------|-------------|--------|
| 5.1 | Namespace Isolation | 5 |
| 5.2 | Hierarchical Namespaces | 5 |
| 5.3 | Virtual Clusters | 5 |
| 5.4 | Tenant Onboarding Automation | 5 |
| **Total** | | **20** |

**Minimum Passing Score for Section 5:** 14/20 (70%)

---

## Assessment Summary

| Section | Description | Points | Weight |
|---------|-------------|--------|--------|
| 1 | Developer Portal (Backstage) | 20 | 20% |
| 2 | Self-Service Infrastructure (Crossplane) | 20 | 20% |
| 3 | Platform Automation | 20 | 20% |
| 4 | Cost Management | 20 | 20% |
| 5 | Multi-Tenancy | 20 | 20% |
| **Total** | | **100** | **100%** |

### Passing Requirements

- **Overall Score:** Minimum 70 points (70%)
- **Per Section:** Minimum 10 points per section (50%)
- **Critical Tasks:** Tasks 2.1 (XRD), 3.1 (CRD), 3.2 (Controller), 5.1 (Isolation) must pass

### Time Management

| Section | Recommended Time |
|---------|------------------|
| Section 1: Developer Portal | 45 minutes |
| Section 2: Self-Service Infrastructure | 45 minutes |
| Section 3: Platform Automation | 50 minutes |
| Section 4: Cost Management | 40 minutes |
| Section 5: Multi-Tenancy | 40 minutes |
| **Total** | **3.5-4 hours** |

---

## Solutions

Solutions are provided in a separate file: [SOLUTIONS.md](SOLUTIONS.md)

---

## Additional Resources

- [Backstage Documentation](https://backstage.io/docs)
- [Crossplane Documentation](https://crossplane.io/docs)
- [Kubebuilder Book](https://book.kubebuilder.io)
- [Argo Events Documentation](https://argoproj.github.io/argo-events/)
- [Kubecost Documentation](https://docs.kubecost.com)
- [vCluster Documentation](https://www.vcluster.com/docs)
- [Hierarchical Namespaces](https://github.com/kubernetes-sigs/hierarchical-namespaces)
