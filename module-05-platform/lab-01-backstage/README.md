# Lab 1: Developer Portals with Backstage

## Introduction

Backstage is an open-source platform for building developer portals. Originally developed by Spotify, it provides a unified interface for managing services, documentation, and infrastructure. This lab teaches you to deploy, configure, and extend Backstage for your organization.

## Prerequisites

- Kubernetes cluster with 4GB+ available memory
- kubectl configured
- Helm 3.x installed
- Node.js 18+ (for local development)
- PostgreSQL database (or in-cluster deployment)
- GitHub account for OAuth integration

## Learning Objectives

By the end of this lab, you will be able to:

- Deploy Backstage to Kubernetes
- Configure the software catalog
- Create and register software templates
- Set up TechDocs for documentation
- Integrate with Kubernetes clusters
- Configure authentication providers
- Install and configure plugins

## Backstage Architecture

### Core Components

```
┌─────────────────────────────────────────────────────────────────┐
│                        BACKSTAGE                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Frontend (React)                      │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │    │
│  │  │ Catalog │ │TechDocs │ │Templates│ │ Search  │        │    │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Backend (Node.js)                     │    │
│  │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐        │    │
│  │  │Catalog  │ │Scaffolder│ │TechDocs │ │  Auth   │        │    │
│  │  │ API     │ │  API    │ │  API    │ │  API    │        │    │
│  │  └─────────┘ └─────────┘ └─────────┘ └─────────┘        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                      Database                            │    │
│  │                    (PostgreSQL)                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Plugin Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     PLUGIN ECOSYSTEM                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Core Plugins                    Community Plugins               │
│  ├── @backstage/catalog          ├── @backstage/plugin-kubernetes│
│  ├── @backstage/scaffolder       ├── @backstage/plugin-github    │
│  ├── @backstage/techdocs         ├── @backstage/plugin-jenkins   │
│  ├── @backstage/search           ├── @backstage/plugin-sonarqube │
│  └── @backstage/auth             └── @backstage/plugin-pagerduty │
│                                                                  │
│  Custom Plugins                                                  │
│  ├── @internal/plugin-deployments                                │
│  ├── @internal/plugin-cost-insights                              │
│  └── @internal/plugin-team-dashboard                             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Deploying Backstage

### Option 1: Helm Chart Deployment

```yaml
# backstage-values.yaml
backstage:
  image:
    registry: ghcr.io
    repository: backstage/backstage
    tag: latest
  
  appConfig:
    app:
      title: "Platform Portal"
      baseUrl: https://backstage.example.com
    
    organization:
      name: "My Organization"
    
    backend:
      baseUrl: https://backstage.example.com
      listen:
        port: 7007
      database:
        client: pg
        connection:
          host: ${POSTGRES_HOST}
          port: ${POSTGRES_PORT}
          user: ${POSTGRES_USER}
          password: ${POSTGRES_PASSWORD}
    
    catalog:
      import:
        entityFilename: catalog-info.yaml
        pullRequestBranchName: backstage-integration
      rules:
        - allow: [Component, System, API, Resource, Location, Template]
      locations:
        - type: url
          target: https://github.com/org/backstage-catalog/blob/main/catalog-info.yaml
    
    auth:
      environment: production
      providers:
        github:
          production:
            clientId: ${GITHUB_CLIENT_ID}
            clientSecret: ${GITHUB_CLIENT_SECRET}
    
    kubernetes:
      serviceLocatorMethod:
        type: multiTenant
      clusterLocatorMethods:
        - type: config
          clusters:
            - url: https://kubernetes.default.svc
              name: local
              authProvider: serviceAccount
              skipTLSVerify: true
              serviceAccountToken: ${KUBE_SA_TOKEN}
  
  extraEnvVars:
    - name: POSTGRES_HOST
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: postgres-host
    - name: POSTGRES_USER
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: postgres-user
    - name: POSTGRES_PASSWORD
      valueFrom:
        secretKeyRef:
          name: backstage-secrets
          key: postgres-password

postgresql:
  enabled: true
  auth:
    username: backstage
    password: backstage
    database: backstage

ingress:
  enabled: true
  className: nginx
  hosts:
    - host: backstage.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: backstage-tls
      hosts:
        - backstage.example.com
```

```bash
# Deploy Backstage
helm repo add backstage https://backstage.github.io/charts
helm repo update

kubectl create namespace backstage

# Create secrets
kubectl create secret generic backstage-secrets -n backstage \
  --from-literal=postgres-host=backstage-postgresql \
  --from-literal=postgres-user=backstage \
  --from-literal=postgres-password=backstage \
  --from-literal=github-client-id=${GITHUB_CLIENT_ID} \
  --from-literal=github-client-secret=${GITHUB_CLIENT_SECRET}

# Install
helm install backstage backstage/backstage \
  -n backstage \
  -f backstage-values.yaml

# Verify deployment
kubectl get pods -n backstage
kubectl get ingress -n backstage
```

### Option 2: Custom Docker Image

```dockerfile
# Dockerfile
FROM node:18-bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3 \
    g++ \
    make \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy package files
COPY package.json yarn.lock ./
COPY packages/backend/package.json packages/backend/
COPY packages/app/package.json packages/app/

# Install dependencies
RUN yarn install --frozen-lockfile --network-timeout 600000

# Copy source code
COPY . .

# Build
RUN yarn build:all

# Run
CMD ["node", "packages/backend", "--config", "app-config.yaml", "--config", "app-config.production.yaml"]
```

```yaml
# Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage
  namespace: backstage
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backstage
  template:
    metadata:
      labels:
        app: backstage
    spec:
      serviceAccountName: backstage
      containers:
        - name: backstage
          image: your-registry/backstage:latest
          ports:
            - containerPort: 7007
          env:
            - name: POSTGRES_HOST
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: postgres-host
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: postgres-user
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: backstage-secrets
                  key: postgres-password
          resources:
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 2Gi
          livenessProbe:
            httpGet:
              path: /healthcheck
              port: 7007
            initialDelaySeconds: 60
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /healthcheck
              port: 7007
            initialDelaySeconds: 30
            periodSeconds: 5
          volumeMounts:
            - name: app-config
              mountPath: /app/app-config.production.yaml
              subPath: app-config.production.yaml
      volumes:
        - name: app-config
          configMap:
            name: backstage-config
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: backstage
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-kubernetes-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: view
subjects:
  - kind: ServiceAccount
    name: backstage
    namespace: backstage
```

## Software Catalog

### Catalog Entity Structure

```yaml
# catalog-info.yaml - Component entity
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: payment-service
  description: Handles payment processing and transactions
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: org/payment-service
    backstage.io/kubernetes-id: payment-service
    jenkins.io/job-full-name: payment-service/main
    sonarqube.org/project-key: payment-service
    pagerduty.com/service-id: PXXXXXX
  tags:
    - java
    - spring-boot
    - payments
  links:
    - url: https://dashboard.example.com/payment
      title: Dashboard
      icon: dashboard
    - url: https://runbook.example.com/payment
      title: Runbook
      icon: docs
spec:
  type: service
  lifecycle: production
  owner: team-payments
  system: checkout-system
  dependsOn:
    - resource:default/payments-database
    - component:default/notification-service
  providesApis:
    - payment-api
  consumesApis:
    - fraud-detection-api
---
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: payment-api
  description: Payment processing API
spec:
  type: openapi
  lifecycle: production
  owner: team-payments
  system: checkout-system
  definition:
    $text: https://raw.githubusercontent.com/org/payment-service/main/openapi.yaml
---
apiVersion: backstage.io/v1alpha1
kind: Resource
metadata:
  name: payments-database
  description: PostgreSQL database for payment data
spec:
  type: database
  owner: team-payments
  system: checkout-system
---
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: checkout-system
  description: Complete checkout and payment system
spec:
  owner: group:platform-team
  domain: commerce
---
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: commerce
  description: E-commerce domain
spec:
  owner: group:commerce-leadership
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: team-payments
  description: Payments team
spec:
  type: team
  profile:
    displayName: Payments Team
    email: payments@example.com
  parent: engineering
  children: []
  members:
    - user:john.doe
    - user:jane.smith
---
apiVersion: backstage.io/v1alpha1
kind: User
metadata:
  name: john.doe
spec:
  profile:
    displayName: John Doe
    email: john.doe@example.com
    picture: https://example.com/avatars/john.jpg
  memberOf:
    - team-payments
```

### Catalog Location Registration

```yaml
# all-components.yaml - Location entity
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: org-catalog
  description: Organization-wide catalog
spec:
  type: url
  targets:
    - https://github.com/org/service-a/blob/main/catalog-info.yaml
    - https://github.com/org/service-b/blob/main/catalog-info.yaml
    - https://github.com/org/service-c/blob/main/catalog-info.yaml
---
# Auto-discovery location
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: github-org-discovery
  description: Discover all repos in GitHub org
spec:
  type: github-discovery
  target: https://github.com/org/*/blob/main/catalog-info.yaml
```

### App Config for Catalog

```yaml
# app-config.yaml
catalog:
  import:
    entityFilename: catalog-info.yaml
    pullRequestBranchName: backstage-integration
  
  rules:
    - allow:
        - Component
        - System
        - API
        - Resource
        - Location
        - Template
        - Group
        - User
        - Domain
  
  processors:
    # GitHub discovery
    githubOrg:
      id: production
      orgUrl: https://github.com/my-org
      providers:
        - target: https://github.com/my-org
          schedule:
            frequency: { hours: 1 }
            timeout: { minutes: 3 }
  
  locations:
    # Static locations
    - type: url
      target: https://github.com/org/backstage-catalog/blob/main/all.yaml
      rules:
        - allow: [Location]
    
    # GitHub org discovery
    - type: github-discovery
      target: https://github.com/org/*/blob/-/catalog-info.yaml
    
    # Local file (for development)
    - type: file
      target: ../../examples/entities.yaml
```

## Software Templates

### Template Structure

```yaml
# template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: spring-boot-service
  title: Spring Boot Microservice
  description: Create a new Spring Boot microservice with standard configurations
  tags:
    - java
    - spring-boot
    - microservice
spec:
  owner: platform-team
  type: service
  
  parameters:
    - title: Service Information
      required:
        - name
        - description
        - owner
      properties:
        name:
          title: Service Name
          type: string
          description: Unique name of the service
          pattern: '^[a-z0-9-]+$'
          ui:autofocus: true
        description:
          title: Description
          type: string
          description: Brief description of what this service does
        owner:
          title: Owner
          type: string
          description: Team that owns this service
          ui:field: OwnerPicker
          ui:options:
            catalogFilter:
              kind: Group
    
    - title: Technical Configuration
      required:
        - javaVersion
        - database
      properties:
        javaVersion:
          title: Java Version
          type: string
          default: '17'
          enum:
            - '11'
            - '17'
            - '21'
          enumNames:
            - Java 11 (LTS)
            - Java 17 (LTS)
            - Java 21 (LTS)
        database:
          title: Database
          type: string
          default: postgresql
          enum:
            - postgresql
            - mysql
            - mongodb
            - none
        enableKafka:
          title: Enable Kafka Integration
          type: boolean
          default: false
        enableRedis:
          title: Enable Redis Caching
          type: boolean
          default: false
    
    - title: Repository Configuration
      required:
        - repoUrl
      properties:
        repoUrl:
          title: Repository Location
          type: string
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts:
              - github.com
            allowedOwners:
              - my-org
  
  steps:
    - id: fetch-base
      name: Fetch Base Template
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          javaVersion: ${{ parameters.javaVersion }}
          database: ${{ parameters.database }}
          enableKafka: ${{ parameters.enableKafka }}
          enableRedis: ${{ parameters.enableRedis }}
    
    - id: fetch-kafka
      name: Add Kafka Configuration
      if: ${{ parameters.enableKafka }}
      action: fetch:template
      input:
        url: ./kafka-addon
        targetPath: ./src/main/java/${{ parameters.name | replace('-', '/') }}/kafka
    
    - id: publish
      name: Publish to GitHub
      action: publish:github
      input:
        allowedHosts:
          - github.com
        repoUrl: ${{ parameters.repoUrl }}
        description: ${{ parameters.description }}
        defaultBranch: main
        protectDefaultBranch: true
        requireCodeOwnerReviews: true
    
    - id: create-argocd-app
      name: Create ArgoCD Application
      action: argocd:create-resources
      input:
        appName: ${{ parameters.name }}
        argoInstance: main
        namespace: ${{ parameters.name }}
        repoUrl: ${{ steps.publish.output.remoteUrl }}
        path: kubernetes
    
    - id: register
      name: Register in Catalog
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml
  
  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
      - title: Open in Catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
      - title: ArgoCD Application
        url: https://argocd.example.com/applications/${{ parameters.name }}
```

### Template Skeleton Files

```java
// skeleton/src/main/java/${{values.name | replace('-', '/')}}/Application.java
package ${{ values.name | replace('-', '.') }};

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class Application {
    public static void main(String[] args) {
        SpringApplication.run(Application.class, args);
    }
}
```

```yaml
# skeleton/catalog-info.yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: ${{ values.name }}
  description: ${{ values.description }}
  annotations:
    backstage.io/techdocs-ref: dir:.
    github.com/project-slug: my-org/${{ values.name }}
    backstage.io/kubernetes-id: ${{ values.name }}
  tags:
    - java
    - spring-boot
    {%- if values.database != 'none' %}
    - ${{ values.database }}
    {%- endif %}
    {%- if values.enableKafka %}
    - kafka
    {%- endif %}
spec:
  type: service
  lifecycle: experimental
  owner: ${{ values.owner }}
  {%- if values.database != 'none' %}
  dependsOn:
    - resource:default/${{ values.name }}-database
  {%- endif %}
```

```yaml
# skeleton/kubernetes/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ values.name }}
  labels:
    app: ${{ values.name }}
    backstage.io/kubernetes-id: ${{ values.name }}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${{ values.name }}
  template:
    metadata:
      labels:
        app: ${{ values.name }}
        backstage.io/kubernetes-id: ${{ values.name }}
    spec:
      containers:
        - name: ${{ values.name }}
          image: ghcr.io/my-org/${{ values.name }}:latest
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_PROFILES_ACTIVE
              value: kubernetes
            {%- if values.database == 'postgresql' %}
            - name: SPRING_DATASOURCE_URL
              valueFrom:
                secretKeyRef:
                  name: ${{ values.name }}-db
                  key: url
            {%- endif %}
          resources:
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: 8080
            initialDelaySeconds: 30
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: 8080
            initialDelaySeconds: 10
```

## TechDocs Integration

### TechDocs Configuration

```yaml
# app-config.yaml
techdocs:
  builder: 'external'  # 'local' for development
  generator:
    runIn: 'docker'    # or 'local'
  publisher:
    type: 'awsS3'      # or 'googleGcs', 'azureBlobStorage', 'local'
    awsS3:
      bucketName: 'backstage-techdocs'
      region: 'us-east-1'
      credentials:
        accessKeyId: ${AWS_ACCESS_KEY_ID}
        secretAccessKey: ${AWS_SECRET_ACCESS_KEY}
```

### Documentation Structure

```
docs/
├── mkdocs.yml
├── docs/
│   ├── index.md
│   ├── getting-started.md
│   ├── architecture.md
│   ├── api-reference.md
│   └── runbook.md
└── catalog-info.yaml
```

```yaml
# mkdocs.yml
site_name: Payment Service Documentation
site_description: Documentation for the Payment Service
repo_url: https://github.com/org/payment-service

nav:
  - Home: index.md
  - Getting Started: getting-started.md
  - Architecture: architecture.md
  - API Reference: api-reference.md
  - Runbook: runbook.md

plugins:
  - techdocs-core

markdown_extensions:
  - admonition
  - codehilite
  - pymdownx.superfences
  - pymdownx.tabbed
```

### TechDocs CI/CD Pipeline

```yaml
# .github/workflows/techdocs.yaml
name: Publish TechDocs

on:
  push:
    branches: [main]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Node
        uses: actions/setup-node@v4
        with:
          node-version: '18'
      
      - name: Install techdocs-cli
        run: npm install -g @techdocs/cli
      
      - name: Generate docs
        run: techdocs-cli generate --no-docker
      
      - name: Publish docs
        run: |
          techdocs-cli publish \
            --publisher-type awsS3 \
            --storage-name backstage-techdocs \
            --entity default/component/payment-service \
            --awsS3sse AES256
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AWS_REGION: us-east-1
```

## Kubernetes Integration

### Kubernetes Plugin Configuration

```yaml
# app-config.yaml
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - name: production
          url: https://prod-cluster.example.com
          authProvider: serviceAccount
          serviceAccountToken: ${PROD_CLUSTER_TOKEN}
          skipTLSVerify: false
          caData: ${PROD_CLUSTER_CA}
        - name: staging
          url: https://staging-cluster.example.com
          authProvider: serviceAccount
          serviceAccountToken: ${STAGING_CLUSTER_TOKEN}
    - type: gke
      projectId: my-gcp-project
      region: us-central1
      skipTLSVerify: false
      exposeDashboard: true
```

### Entity Annotations for Kubernetes

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    # Link to Kubernetes resources
    backstage.io/kubernetes-id: my-service
    
    # Multiple clusters
    backstage.io/kubernetes-namespace: production
    backstage.io/kubernetes-label-selector: 'app=my-service'
    
    # Custom resource types to display
    backstage.io/kubernetes-resources: 'deployments,services,ingresses,pods'
spec:
  type: service
  owner: team-platform
```

## Authentication Configuration

### GitHub OAuth

```yaml
# app-config.yaml
auth:
  environment: production
  providers:
    github:
      production:
        clientId: ${GITHUB_CLIENT_ID}
        clientSecret: ${GITHUB_CLIENT_SECRET}
        signIn:
          resolvers:
            - resolver: usernameMatchingUserEntityName
            - resolver: emailMatchingUserEntityProfileEmail
```

### OIDC/OAuth2

```yaml
auth:
  providers:
    oidc:
      production:
        metadataUrl: https://idp.example.com/.well-known/openid-configuration
        clientId: ${OIDC_CLIENT_ID}
        clientSecret: ${OIDC_CLIENT_SECRET}
        prompt: auto
        signIn:
          resolvers:
            - resolver: emailMatchingUserEntityProfileEmail
```

### Guest Access (Development)

```yaml
auth:
  providers:
    guest:
      dangerouslyAllowOutsideDevelopment: false
      userEntityRef: user:development/guest
```

## Exercises

### Exercise 1: Deploy Backstage

Deploy Backstage to your Kubernetes cluster:

```bash
# Create namespace
kubectl create namespace backstage

# Create PostgreSQL secret
kubectl create secret generic backstage-db-secret -n backstage \
  --from-literal=POSTGRES_USER=backstage \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -base64 24)

# Deploy PostgreSQL
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backstage-postgresql
  namespace: backstage
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
        - name: postgresql
          image: postgres:15
          env:
            - name: POSTGRES_USER
              valueFrom:
                secretKeyRef:
                  name: backstage-db-secret
                  key: POSTGRES_USER
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: backstage-db-secret
                  key: POSTGRES_PASSWORD
            - name: POSTGRES_DB
              value: backstage
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: data
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: backstage-postgresql
  namespace: backstage
spec:
  selector:
    app: postgresql
  ports:
    - port: 5432
EOF

# Verify PostgreSQL
kubectl get pods -n backstage -l app=postgresql
```

### Exercise 2: Register Catalog Entities

Create and register catalog entities:

```bash
# Create a sample catalog
mkdir -p backstage-catalog
cat > backstage-catalog/all.yaml <<EOF
apiVersion: backstage.io/v1alpha1
kind: Location
metadata:
  name: sample-services
  description: Sample services catalog
spec:
  targets:
    - ./sample-service.yaml
---
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: sample-service
  description: A sample microservice
  tags:
    - python
    - fastapi
spec:
  type: service
  lifecycle: production
  owner: platform-team
EOF

# Register via API (if Backstage is running)
curl -X POST "http://localhost:7007/api/catalog/locations" \
  -H "Content-Type: application/json" \
  -d '{"type": "url", "target": "https://github.com/org/catalog/blob/main/all.yaml"}'
```

### Exercise 3: Create Software Template

Build a software template:

```bash
# Create template directory
mkdir -p templates/node-service

# Create template.yaml
cat > templates/node-service/template.yaml <<'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: node-service
  title: Node.js Service
  description: Create a Node.js microservice
  tags:
    - nodejs
    - typescript
spec:
  owner: platform-team
  type: service
  parameters:
    - title: Service Details
      required:
        - name
        - owner
      properties:
        name:
          title: Name
          type: string
          pattern: '^[a-z0-9-]+$'
        owner:
          title: Owner
          type: string
          ui:field: OwnerPicker
  steps:
    - id: fetch
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
    - id: publish
      action: publish:github
      input:
        repoUrl: github.com?owner=org&repo=${{ parameters.name }}
    - id: register
      action: catalog:register
      input:
        repoContentsUrl: ${{ steps.publish.output.repoContentsUrl }}
        catalogInfoPath: /catalog-info.yaml
  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
EOF

# Create skeleton
mkdir -p templates/node-service/skeleton
cat > templates/node-service/skeleton/package.json <<'EOF'
{
  "name": "${{ values.name }}",
  "version": "1.0.0",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js"
  }
}
EOF
```

### Exercise 4: Configure TechDocs

Set up TechDocs for a service:

```bash
# Create documentation structure
mkdir -p my-service/docs/docs

cat > my-service/docs/mkdocs.yml <<EOF
site_name: My Service
plugins:
  - techdocs-core
nav:
  - Home: index.md
  - API: api.md
EOF

cat > my-service/docs/docs/index.md <<EOF
# My Service

Welcome to the documentation.

## Quick Start

\`\`\`bash
kubectl apply -f deployment.yaml
\`\`\`
EOF

cat > my-service/docs/docs/api.md <<EOF
# API Reference

## Endpoints

### GET /health
Returns service health status.
EOF

# Update catalog-info.yaml to reference TechDocs
cat > my-service/catalog-info.yaml <<EOF
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    backstage.io/techdocs-ref: dir:docs
spec:
  type: service
  owner: platform-team
  lifecycle: production
EOF
```

### Exercise 5: Kubernetes Plugin Integration

Configure Kubernetes integration:

```bash
# Create service account for Backstage
kubectl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: backstage
  namespace: backstage
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: backstage-kubernetes-reader
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps", "namespaces"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "statefulsets", "daemonsets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["networking.k8s.io"]
    resources: ["ingresses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs", "cronjobs"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: backstage-kubernetes-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: backstage-kubernetes-reader
subjects:
  - kind: ServiceAccount
    name: backstage
    namespace: backstage
EOF

# Get the service account token
kubectl create token backstage -n backstage --duration=8760h
```

## Validation Checklist

Before proceeding to the next lab, verify you can:

- [ ] Deploy Backstage to Kubernetes
- [ ] Configure PostgreSQL database connection
- [ ] Register entities in the software catalog
- [ ] Create and use software templates
- [ ] Set up TechDocs documentation
- [ ] Configure Kubernetes integration
- [ ] Set up authentication providers
- [ ] Navigate the Backstage UI

## Key Takeaways

1. **Backstage is a platform** - It's the foundation for your developer portal
2. **Catalog is central** - All services, APIs, and resources are cataloged
3. **Templates reduce friction** - Scaffold new projects with best practices
4. **TechDocs centralizes documentation** - Single source of truth
5. **Plugins extend functionality** - Rich ecosystem of integrations
6. **Kubernetes integration** - View cluster resources from the portal

## Troubleshooting

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl logs -n backstage -l app=postgresql

# Test connection from Backstage pod
kubectl exec -n backstage deploy/backstage -- \
  pg_isready -h backstage-postgresql -p 5432 -U backstage
```

### Catalog Not Loading

```bash
# Check Backstage logs
kubectl logs -n backstage deploy/backstage | grep -i catalog

# Verify catalog configuration
kubectl get configmap -n backstage backstage-config -o yaml
```

### Template Errors

```bash
# Check scaffolder logs
kubectl logs -n backstage deploy/backstage | grep -i scaffolder

# Validate template YAML
npx @backstage/cli config:check
```

## Next Steps

In Lab 2, we'll explore self-service infrastructure provisioning using Crossplane to enable teams to request and manage cloud resources through Kubernetes.

---

## Quick Reference

### Catalog Entity Kinds

| Kind | Description |
|------|-------------|
| Component | A software component (service, library, website) |
| API | An API definition (OpenAPI, AsyncAPI, GraphQL) |
| Resource | Infrastructure (database, storage, queue) |
| System | Collection of components |
| Domain | Business domain grouping |
| Group | Team or organizational unit |
| User | Individual person |
| Location | Reference to external catalog files |
| Template | Software template for scaffolding |

### Common Annotations

```yaml
annotations:
  backstage.io/techdocs-ref: dir:.
  github.com/project-slug: org/repo
  backstage.io/kubernetes-id: service-name
  jenkins.io/job-full-name: job/name
  sonarqube.org/project-key: project
  pagerduty.com/service-id: PXXXXXX
```

### CLI Commands

```bash
# Create new Backstage app
npx @backstage/create-app@latest

# Start development server
yarn dev

# Build for production
yarn build:all

# Generate TechDocs
npx @techdocs/cli generate

# Publish TechDocs
npx @techdocs/cli publish --publisher-type awsS3
```
