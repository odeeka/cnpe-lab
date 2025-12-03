# Lab 3: Golden Paths and Software Templates

## Introduction

Golden paths are opinionated, well-supported pathways for building applications that reduce cognitive load and accelerate development. They combine infrastructure templates, CI/CD pipelines, security best practices, and observability into standardized starting points. This lab teaches you to design and implement golden paths that balance developer autonomy with organizational standards.

## Prerequisites

- Completed Lab 1 (Backstage) and Lab 2 (Crossplane)
- Understanding of GitOps principles
- Familiarity with Helm and Kustomize
- Access to a Git repository hosting service

## Learning Objectives

By the end of this lab, you will be able to:

- Design golden paths for common application types
- Create Backstage software templates
- Build reusable Helm chart libraries
- Implement compliance-as-code in templates
- Integrate templates with CI/CD and GitOps
- Create multi-environment configurations
- Measure golden path adoption

## Golden Path Philosophy

### What Makes a Good Golden Path

```
┌─────────────────────────────────────────────────────────────────┐
│                     GOLDEN PATH PRINCIPLES                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  1. OPTIONAL BUT COMPELLING                                      │
│     ├── Not mandatory, but clearly advantageous                  │
│     ├── Reduces time-to-production significantly                 │
│     └── Developers choose it because it works                    │
│                                                                  │
│  2. OPINIONATED BUT FLEXIBLE                                     │
│     ├── Strong defaults for common cases                         │
│     ├── Escape hatches for special needs                         │
│     └── Extensible, not restrictive                              │
│                                                                  │
│  3. COMPLETE END-TO-END                                          │
│     ├── From code to production                                  │
│     ├── Includes observability and security                      │
│     └── Covers all environments                                  │
│                                                                  │
│  4. MAINTAINED AND EVOLVED                                       │
│     ├── Regular updates with improvements                        │
│     ├── Clear upgrade paths                                      │
│     └── Deprecation notices for changes                          │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Golden Path Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    GOLDEN PATH ANATOMY                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Repository Template                                             │
│  ├── Application scaffold (source code)                         │
│  ├── Dockerfile and container configuration                     │
│  ├── Kubernetes manifests or Helm chart                         │
│  ├── CI/CD pipeline definitions                                 │
│  ├── Testing setup (unit, integration, e2e)                     │
│  └── Documentation templates                                    │
│                                                                  │
│  Infrastructure Template                                         │
│  ├── Database provisioning (Crossplane claims)                  │
│  ├── Cache layer (Redis, Memcached)                             │
│  ├── Message queue (Kafka, RabbitMQ)                            │
│  └── Storage buckets                                            │
│                                                                  │
│  Platform Integration                                            │
│  ├── Service mesh enrollment                                    │
│  ├── Secret management integration                              │
│  ├── Observability stack (metrics, logs, traces)                │
│  └── Security scanning and policies                             │
│                                                                  │
│  GitOps Configuration                                            │
│  ├── ArgoCD Application                                         │
│  ├── Environment promotion workflow                             │
│  └── Rollback procedures                                        │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Backstage Software Templates

### Complete Microservice Template

```yaml
# template.yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: microservice-golden-path
  title: Production-Ready Microservice
  description: |
    Creates a complete microservice with CI/CD, observability, and GitOps deployment.
    Includes database, caching, and message queue options.
  tags:
    - recommended
    - microservice
    - production-ready
spec:
  owner: platform-team
  type: service
  
  parameters:
    # Step 1: Basic Information
    - title: Service Information
      required:
        - name
        - description
        - owner
      properties:
        name:
          title: Service Name
          type: string
          description: Unique identifier for the service (lowercase, hyphens only)
          pattern: '^[a-z][a-z0-9-]*$'
          maxLength: 53
          ui:autofocus: true
          ui:help: "Used for repository name, kubernetes resources, and service discovery"
        
        description:
          title: Description
          type: string
          description: Brief description of what this service does
          maxLength: 200
        
        owner:
          title: Owning Team
          type: string
          description: Team responsible for this service
          ui:field: OwnerPicker
          ui:options:
            catalogFilter:
              kind: Group
    
    # Step 2: Technology Stack
    - title: Technology Stack
      required:
        - language
        - framework
      properties:
        language:
          title: Programming Language
          type: string
          enum:
            - java
            - go
            - python
            - typescript
          enumNames:
            - Java 17
            - Go 1.21
            - Python 3.11
            - TypeScript/Node.js 20
        
        framework:
          title: Framework
          type: string
          enum: []
          ui:field: FrameworkPicker
          ui:options:
            dependsOn: language
            mappings:
              java:
                - spring-boot
                - quarkus
                - micronaut
              go:
                - gin
                - echo
                - fiber
              python:
                - fastapi
                - flask
                - django
              typescript:
                - express
                - nestjs
                - fastify
    
    # Step 3: Dependencies
    - title: Dependencies
      properties:
        database:
          title: Database
          type: object
          properties:
            enabled:
              title: Enable Database
              type: boolean
              default: true
            type:
              title: Database Type
              type: string
              enum:
                - postgresql
                - mysql
                - mongodb
              default: postgresql
            size:
              title: Size
              type: string
              enum:
                - small
                - medium
                - large
              default: small
              description: "small: 10GB/2vCPU, medium: 50GB/4vCPU, large: 200GB/8vCPU"
        
        cache:
          title: Caching Layer
          type: object
          properties:
            enabled:
              title: Enable Redis Cache
              type: boolean
              default: false
            size:
              title: Cache Size (MB)
              type: integer
              default: 256
              enum: [128, 256, 512, 1024]
        
        messaging:
          title: Message Queue
          type: object
          properties:
            enabled:
              title: Enable Message Queue
              type: boolean
              default: false
            type:
              title: Queue Type
              type: string
              enum:
                - kafka
                - rabbitmq
              default: kafka
    
    # Step 4: Deployment Configuration
    - title: Deployment Configuration
      properties:
        environments:
          title: Deployment Environments
          type: array
          items:
            type: string
            enum:
              - development
              - staging
              - production
          default:
            - development
            - staging
            - production
          uniqueItems: true
        
        replicas:
          title: Production Replicas
          type: integer
          default: 3
          minimum: 2
          maximum: 10
        
        resources:
          title: Resource Sizing
          type: string
          enum:
            - small
            - medium
            - large
          default: small
          description: "small: 256Mi/100m, medium: 512Mi/250m, large: 1Gi/500m"
        
        ingress:
          title: External Access
          type: object
          properties:
            enabled:
              title: Enable Public Ingress
              type: boolean
              default: false
            path:
              title: Path Prefix
              type: string
              default: /
    
    # Step 5: Repository
    - title: Repository Location
      required:
        - repoUrl
      properties:
        repoUrl:
          title: Repository URL
          type: string
          ui:field: RepoUrlPicker
          ui:options:
            allowedHosts:
              - github.com
            allowedOwners:
              - my-org

  steps:
    # Step 1: Fetch and template the base skeleton
    - id: fetch-skeleton
      name: Fetch Application Skeleton
      action: fetch:template
      input:
        url: ./skeletons/${{ parameters.language }}/${{ parameters.framework }}
        targetPath: ./
        values:
          name: ${{ parameters.name }}
          description: ${{ parameters.description }}
          owner: ${{ parameters.owner }}
          language: ${{ parameters.language }}
          framework: ${{ parameters.framework }}
    
    # Step 2: Add Kubernetes manifests
    - id: fetch-kubernetes
      name: Add Kubernetes Manifests
      action: fetch:template
      input:
        url: ./kubernetes-templates/base
        targetPath: ./kubernetes
        values:
          name: ${{ parameters.name }}
          replicas: ${{ parameters.replicas }}
          resources: ${{ parameters.resources }}
          environments: ${{ parameters.environments }}
    
    # Step 3: Add database configuration
    - id: fetch-database
      name: Add Database Configuration
      if: ${{ parameters.database.enabled }}
      action: fetch:template
      input:
        url: ./infrastructure-templates/database
        targetPath: ./infrastructure
        values:
          name: ${{ parameters.name }}
          type: ${{ parameters.database.type }}
          size: ${{ parameters.database.size }}
    
    # Step 4: Add cache configuration
    - id: fetch-cache
      name: Add Cache Configuration
      if: ${{ parameters.cache.enabled }}
      action: fetch:template
      input:
        url: ./infrastructure-templates/cache
        targetPath: ./infrastructure
        values:
          name: ${{ parameters.name }}
          size: ${{ parameters.cache.size }}
    
    # Step 5: Add messaging configuration
    - id: fetch-messaging
      name: Add Messaging Configuration
      if: ${{ parameters.messaging.enabled }}
      action: fetch:template
      input:
        url: ./infrastructure-templates/messaging
        targetPath: ./infrastructure
        values:
          name: ${{ parameters.name }}
          type: ${{ parameters.messaging.type }}
    
    # Step 6: Add CI/CD pipeline
    - id: fetch-cicd
      name: Add CI/CD Pipeline
      action: fetch:template
      input:
        url: ./cicd-templates/${{ parameters.language }}
        targetPath: ./
        values:
          name: ${{ parameters.name }}
          language: ${{ parameters.language }}
          framework: ${{ parameters.framework }}
          environments: ${{ parameters.environments }}
    
    # Step 7: Add observability configuration
    - id: fetch-observability
      name: Add Observability Configuration
      action: fetch:template
      input:
        url: ./observability-templates
        targetPath: ./
        values:
          name: ${{ parameters.name }}
          language: ${{ parameters.language }}
    
    # Step 8: Publish to GitHub
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
        dismissStaleReviews: true
        requiredStatusCheckContexts:
          - build
          - test
          - security-scan
        topics:
          - ${{ parameters.language }}
          - ${{ parameters.framework }}
          - golden-path
    
    # Step 9: Create ArgoCD Applications
    - id: argocd-apps
      name: Create ArgoCD Applications
      action: argocd:create-resources
      input:
        appName: ${{ parameters.name }}
        argoInstance: main
        namespace: argocd
        repoUrl: ${{ steps.publish.output.remoteUrl }}
        path: kubernetes/overlays
        environments: ${{ parameters.environments }}
    
    # Step 10: Create infrastructure claims
    - id: infrastructure-claims
      name: Provision Infrastructure
      if: ${{ parameters.database.enabled or parameters.cache.enabled or parameters.messaging.enabled }}
      action: kubernetes:apply
      input:
        manifestPath: ./infrastructure
        namespaced: true
        namespace: ${{ parameters.name }}-infrastructure
    
    # Step 11: Register in catalog
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
        icon: github
      - title: Open in Catalog
        icon: catalog
        entityRef: ${{ steps.register.output.entityRef }}
      - title: ArgoCD Dashboard
        icon: dashboard
        url: https://argocd.example.com/applications/${{ parameters.name }}
      - title: Documentation
        icon: docs
        url: ${{ steps.publish.output.remoteUrl }}/blob/main/docs/README.md
    text:
      - title: Getting Started
        content: |
          ## Your service is ready!
          
          1. Clone your repository:
             ```
             git clone ${{ steps.publish.output.remoteUrl }}
             ```
          
          2. Development:
             ```
             cd ${{ parameters.name }}
             make dev
             ```
          
          3. Deploy to development:
             ```
             git push origin main
             ```
             ArgoCD will automatically sync to development environment.
```

### Template Skeleton Structure

```
skeletons/
├── java/
│   ├── spring-boot/
│   │   ├── skeleton/
│   │   │   ├── src/
│   │   │   │   ├── main/
│   │   │   │   │   ├── java/
│   │   │   │   │   │   └── ${{values.name | replace('-', '/')}}/
│   │   │   │   │   │       ├── Application.java
│   │   │   │   │   │       ├── controller/
│   │   │   │   │   │       │   └── HealthController.java
│   │   │   │   │   │       └── config/
│   │   │   │   │   │           └── AppConfig.java
│   │   │   │   │   └── resources/
│   │   │   │   │       ├── application.yaml
│   │   │   │   │       └── application-kubernetes.yaml
│   │   │   │   └── test/
│   │   │   │       └── java/
│   │   │   ├── pom.xml
│   │   │   ├── Dockerfile
│   │   │   ├── Makefile
│   │   │   └── catalog-info.yaml
│   │   └── template.yaml
│   └── quarkus/
│       └── ...
├── go/
│   ├── gin/
│   │   ├── skeleton/
│   │   │   ├── cmd/
│   │   │   │   └── server/
│   │   │   │       └── main.go
│   │   │   ├── internal/
│   │   │   │   ├── handlers/
│   │   │   │   └── config/
│   │   │   ├── go.mod
│   │   │   ├── Dockerfile
│   │   │   └── Makefile
│   │   └── template.yaml
│   └── ...
├── python/
│   └── fastapi/
│       ├── skeleton/
│       │   ├── app/
│       │   │   ├── __init__.py
│       │   │   ├── main.py
│       │   │   ├── routers/
│       │   │   └── config.py
│       │   ├── tests/
│       │   ├── requirements.txt
│       │   ├── Dockerfile
│       │   └── Makefile
│       └── template.yaml
└── typescript/
    └── nestjs/
        └── ...
```

### Spring Boot Skeleton Example

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

```java
// skeleton/src/main/java/${{values.name | replace('-', '/')}}/controller/HealthController.java
package ${{ values.name | replace('-', '.') }}.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import io.micrometer.core.annotation.Timed;

@RestController
public class HealthController {

    @GetMapping("/health")
    @Timed(value = "health.check", description = "Health check endpoint")
    public HealthResponse health() {
        return new HealthResponse("UP", "${{ values.name }}");
    }

    public record HealthResponse(String status, String service) {}
}
```

```yaml
# skeleton/src/main/resources/application.yaml
spring:
  application:
    name: ${{ values.name }}
  
  datasource:
    url: ${DATABASE_URL:jdbc:postgresql://localhost:5432/${{ values.name | replace('-', '_') }}}
    username: ${DATABASE_USER:postgres}
    password: ${DATABASE_PASSWORD:postgres}

server:
  port: ${PORT:8080}

management:
  endpoints:
    web:
      exposure:
        include: health,info,prometheus,metrics
  endpoint:
    health:
      show-details: always
      probes:
        enabled: true
  metrics:
    tags:
      application: ${{ values.name }}
```

```xml
<!-- skeleton/pom.xml -->
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
         https://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>
    
    <parent>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-parent</artifactId>
        <version>3.2.0</version>
    </parent>
    
    <groupId>com.example</groupId>
    <artifactId>${{ values.name }}</artifactId>
    <version>0.0.1-SNAPSHOT</version>
    <name>${{ values.name }}</name>
    <description>${{ values.description }}</description>
    
    <properties>
        <java.version>17</java.version>
    </properties>
    
    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
        </dependency>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-actuator</artifactId>
        </dependency>
        <dependency>
            <groupId>io.micrometer</groupId>
            <artifactId>micrometer-registry-prometheus</artifactId>
        </dependency>
        {%- if values.database.enabled %}
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-jpa</artifactId>
        </dependency>
        <dependency>
            <groupId>org.postgresql</groupId>
            <artifactId>postgresql</artifactId>
        </dependency>
        {%- endif %}
        {%- if values.cache.enabled %}
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-data-redis</artifactId>
        </dependency>
        {%- endif %}
        {%- if values.messaging.enabled and values.messaging.type == 'kafka' %}
        <dependency>
            <groupId>org.springframework.kafka</groupId>
            <artifactId>spring-kafka</artifactId>
        </dependency>
        {%- endif %}
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
    </dependencies>
    
    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
    </build>
</project>
```

```dockerfile
# skeleton/Dockerfile
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Security: Run as non-root
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

# Copy application
COPY --chown=appuser:appgroup target/*.jar app.jar

# Actuator health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=30s \
  CMD wget -q --spider http://localhost:8080/actuator/health || exit 1

# JVM settings
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

EXPOSE 8080

ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
```

## Kubernetes Templates

### Base Kustomize Structure

```yaml
# kubernetes-templates/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml
  - servicemonitor.yaml
  - poddisruptionbudget.yaml

configMapGenerator:
  - name: ${{ values.name }}-config
    literals:
      - APP_NAME=${{ values.name }}
```

```yaml
# kubernetes-templates/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${{ values.name }}
  labels:
    app.kubernetes.io/name: ${{ values.name }}
    app.kubernetes.io/component: service
    app.kubernetes.io/managed-by: backstage
spec:
  replicas: ${{ values.replicas }}
  selector:
    matchLabels:
      app.kubernetes.io/name: ${{ values.name }}
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ${{ values.name }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/actuator/prometheus"
    spec:
      serviceAccountName: ${{ values.name }}
      securityContext:
        runAsNonRoot: true
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: ${{ values.name }}
          image: ghcr.io/my-org/${{ values.name }}:latest
          imagePullPolicy: Always
          ports:
            - name: http
              containerPort: 8080
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          envFrom:
            - configMapRef:
                name: ${{ values.name }}-config
            - secretRef:
                name: ${{ values.name }}-secrets
                optional: true
          resources:
            {%- if values.resources == 'small' %}
            requests:
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
            {%- elif values.resources == 'medium' %}
            requests:
              cpu: 250m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
            {%- else %}
            requests:
              cpu: 500m
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 2Gi
            {%- endif %}
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            capabilities:
              drop:
                - ALL
          livenessProbe:
            httpGet:
              path: /actuator/health/liveness
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /actuator/health/readiness
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

```yaml
# kubernetes-templates/base/poddisruptionbudget.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: ${{ values.name }}
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ${{ values.name }}
```

```yaml
# kubernetes-templates/base/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ${{ values.name }}
  labels:
    app.kubernetes.io/name: ${{ values.name }}
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: ${{ values.name }}
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 30s
```

### Environment Overlays

```yaml
# kubernetes-templates/overlays/development/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${{ values.name }}-dev

resources:
  - ../../base

replicas:
  - name: ${{ values.name }}
    count: 1

patches:
  - patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: 50m
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 128Mi
    target:
      kind: Deployment
      name: ${{ values.name }}

images:
  - name: ghcr.io/my-org/${{ values.name }}
    newTag: dev
```

```yaml
# kubernetes-templates/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: ${{ values.name }}-prod

resources:
  - ../../base
  - hpa.yaml
  - networkpolicy.yaml

patches:
  - patch: |-
      - op: add
        path: /metadata/annotations/iam.amazonaws.com~1role
        value: arn:aws:iam::123456789:role/${{ values.name }}-prod
    target:
      kind: ServiceAccount
      name: ${{ values.name }}
```

```yaml
# kubernetes-templates/overlays/production/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${{ values.name }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${{ values.name }}
  minReplicas: ${{ values.replicas }}
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Percent
          value: 100
          periodSeconds: 15
```

## CI/CD Templates

### GitHub Actions Workflow

```yaml
# cicd-templates/java/.github/workflows/ci.yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.version.outputs.version }}
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven
      
      - name: Build and Test
        run: |
          mvn -B verify
      
      - name: Generate Version
        id: version
        run: |
          if [[ "${{ github.ref }}" == "refs/heads/main" ]]; then
            echo "version=${{ github.sha }}" >> $GITHUB_OUTPUT
          else
            echo "version=dev-${{ github.sha }}" >> $GITHUB_OUTPUT
          fi
      
      - name: Upload Test Results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-results
          path: target/surefire-reports/
  
  security-scan:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          format: 'sarif'
          output: 'trivy-results.sarif'
      
      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
  
  build-image:
    runs-on: ubuntu-latest
    needs: [build, security-scan]
    permissions:
      contents: read
      packages: write
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven
      
      - name: Build JAR
        run: mvn -B package -DskipTests
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Login to Container Registry
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
          tags: |
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build.outputs.version }}
            ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
  
  deploy-dev:
    runs-on: ubuntu-latest
    needs: build-image
    if: github.ref == 'refs/heads/develop'
    environment: development
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Update image tag
        run: |
          cd kubernetes/overlays/development
          kustomize edit set image ghcr.io/my-org/${{ values.name }}:${{ needs.build.outputs.version }}
      
      - name: Commit and push
        run: |
          git config user.name "GitHub Actions"
          git config user.email "actions@github.com"
          git add .
          git commit -m "Deploy ${{ needs.build.outputs.version }} to development"
          git push
  
  deploy-prod:
    runs-on: ubuntu-latest
    needs: build-image
    if: github.ref == 'refs/heads/main'
    environment: production
    
    steps:
      - uses: actions/checkout@v4
      
      - name: Update image tag
        run: |
          cd kubernetes/overlays/production
          kustomize edit set image ghcr.io/my-org/${{ values.name }}:${{ needs.build.outputs.version }}
      
      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          title: "Deploy ${{ needs.build.outputs.version }} to production"
          body: |
            Automated deployment PR for version ${{ needs.build.outputs.version }}
            
            Changes:
            - Image: ghcr.io/my-org/${{ values.name }}:${{ needs.build.outputs.version }}
          branch: deploy/${{ needs.build.outputs.version }}
          base: main
```

## Compliance as Code

### Security Policies in Templates

```yaml
# compliance-templates/security-policies.yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-golden-path-labels
  annotations:
    policies.kyverno.io/title: Require Golden Path Labels
    policies.kyverno.io/description: >-
      Ensures all deployments created from golden paths have required labels
spec:
  validationFailureAction: enforce
  background: true
  rules:
    - name: require-managed-by-label
      match:
        resources:
          kinds:
            - Deployment
      validate:
        message: "Deployment must have 'app.kubernetes.io/managed-by' label"
        pattern:
          metadata:
            labels:
              app.kubernetes.io/managed-by: "backstage|argocd"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: enforce-security-context
spec:
  validationFailureAction: enforce
  rules:
    - name: require-run-as-non-root
      match:
        resources:
          kinds:
            - Pod
      validate:
        message: "Pods must run as non-root"
        pattern:
          spec:
            securityContext:
              runAsNonRoot: true
            containers:
              - securityContext:
                  allowPrivilegeEscalation: false
                  capabilities:
                    drop:
                      - ALL
```

### Network Policies

```yaml
# compliance-templates/network-policy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ${{ values.name }}-network-policy
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: ${{ values.name }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
        - namespaceSelector:
            matchLabels:
              name: monitoring
          podSelector:
            matchLabels:
              app.kubernetes.io/name: prometheus
      ports:
        - protocol: TCP
          port: 8080
  egress:
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ${{ values.name }}-database
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - namespaceSelector:
            matchLabels:
              name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

## Exercises

### Exercise 1: Create Basic Template

Build a simple template for a static website:

```bash
# Create template structure
mkdir -p templates/static-website/skeleton

# Create template.yaml
cat > templates/static-website/template.yaml <<'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: static-website
  title: Static Website
  description: Create a static website with Nginx
spec:
  owner: platform-team
  type: website
  parameters:
    - title: Website Details
      required: [name]
      properties:
        name:
          title: Name
          type: string
        domain:
          title: Domain
          type: string
  steps:
    - id: fetch
      action: fetch:template
      input:
        url: ./skeleton
        values:
          name: ${{ parameters.name }}
          domain: ${{ parameters.domain }}
    - id: publish
      action: publish:github
      input:
        repoUrl: github.com?owner=my-org&repo=${{ parameters.name }}
  output:
    links:
      - title: Repository
        url: ${{ steps.publish.output.remoteUrl }}
EOF

# Create skeleton files
cat > templates/static-website/skeleton/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>${{ values.name }}</title>
</head>
<body>
    <h1>Welcome to ${{ values.name }}</h1>
</body>
</html>
EOF

cat > templates/static-website/skeleton/Dockerfile <<'EOF'
FROM nginx:alpine
COPY . /usr/share/nginx/html
EXPOSE 80
EOF
```

### Exercise 2: Multi-Language Template

Create a template that supports multiple languages:

```bash
# Create language-specific skeletons
mkdir -p templates/api-service/{go,python,typescript}/skeleton

# Create shared template with language selection
cat > templates/api-service/template.yaml <<'EOF'
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: api-service
  title: API Service
spec:
  owner: platform-team
  type: service
  parameters:
    - title: Service Details
      properties:
        name:
          title: Name
          type: string
        language:
          title: Language
          type: string
          enum: [go, python, typescript]
  steps:
    - id: fetch
      action: fetch:template
      input:
        url: ./${{ parameters.language }}/skeleton
        values:
          name: ${{ parameters.name }}
EOF

# Create Go skeleton
cat > templates/api-service/go/skeleton/main.go <<'EOF'
package main

import (
    "net/http"
    "github.com/gin-gonic/gin"
)

func main() {
    r := gin.Default()
    r.GET("/health", func(c *gin.Context) {
        c.JSON(http.StatusOK, gin.H{"status": "UP"})
    })
    r.Run(":8080")
}
EOF

# Create Python skeleton
cat > templates/api-service/python/skeleton/main.py <<'EOF'
from fastapi import FastAPI

app = FastAPI(title="${{ values.name }}")

@app.get("/health")
def health():
    return {"status": "UP"}
EOF
```

### Exercise 3: Infrastructure Integration

Add Crossplane claims to templates:

```bash
# Create infrastructure template
mkdir -p templates/infra-templates/database

cat > templates/infra-templates/database/database-claim.yaml <<'EOF'
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: ${{ values.name }}-db
  namespace: ${{ values.name }}
spec:
  parameters:
    size: ${{ values.size }}
    engine: ${{ values.engine }}
  writeConnectionSecretToRef:
    name: ${{ values.name }}-db-credentials
EOF

# Update main template to include infrastructure
cat >> templates/api-service/template.yaml <<'EOF'
    - id: fetch-infra
      action: fetch:template
      if: ${{ parameters.database.enabled }}
      input:
        url: ../infra-templates/database
        targetPath: ./infrastructure
        values:
          name: ${{ parameters.name }}
          size: ${{ parameters.database.size }}
          engine: ${{ parameters.database.engine }}
EOF
```

### Exercise 4: Environment Overlays

Create multi-environment configurations:

```bash
# Create overlay structure
mkdir -p templates/k8s-templates/{base,overlays/{dev,staging,prod}}

# Create base kustomization
cat > templates/k8s-templates/base/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
EOF

# Create dev overlay
cat > templates/k8s-templates/overlays/dev/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${{ values.name }}-dev
resources:
  - ../../base
replicas:
  - name: ${{ values.name }}
    count: 1
EOF

# Create prod overlay
cat > templates/k8s-templates/overlays/prod/kustomization.yaml <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ${{ values.name }}-prod
resources:
  - ../../base
  - hpa.yaml
replicas:
  - name: ${{ values.name }}
    count: 3
EOF
```

### Exercise 5: Measure Adoption

Create metrics for template usage:

```bash
# Create Prometheus metrics for template adoption
cat > observability/template-metrics.yaml <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: golden-path-metrics
  namespace: monitoring
spec:
  groups:
    - name: golden-path.rules
      rules:
        - record: golden_path:services:total
          expr: |
            count(kube_deployment_labels{label_app_kubernetes_io_managed_by="backstage"})
        
        - record: golden_path:adoption:ratio
          expr: |
            count(kube_deployment_labels{label_app_kubernetes_io_managed_by="backstage"})
            /
            count(kube_deployment_labels)
        
        - record: golden_path:services_by_template:count
          expr: |
            count by (label_backstage_io_template) (
              kube_deployment_labels{label_app_kubernetes_io_managed_by="backstage"}
            )
EOF

# Create Grafana dashboard
cat > observability/template-dashboard.json <<'EOF'
{
  "title": "Golden Path Adoption",
  "panels": [
    {
      "title": "Total Golden Path Services",
      "type": "stat",
      "targets": [{"expr": "golden_path:services:total"}]
    },
    {
      "title": "Adoption Rate",
      "type": "gauge",
      "targets": [{"expr": "golden_path:adoption:ratio * 100"}]
    },
    {
      "title": "Services by Template",
      "type": "piechart",
      "targets": [{"expr": "golden_path:services_by_template:count"}]
    }
  ]
}
EOF
```

## Validation Checklist

Before proceeding to the next lab, verify you can:

- [ ] Design golden paths for common use cases
- [ ] Create Backstage software templates
- [ ] Build language-specific skeletons
- [ ] Implement multi-environment configurations
- [ ] Add infrastructure provisioning to templates
- [ ] Include CI/CD pipelines in templates
- [ ] Implement compliance policies
- [ ] Measure template adoption

## Key Takeaways

1. **Golden paths are products** - Invest in making them excellent
2. **Templates should be complete** - Include everything needed
3. **Support multiple languages** - Teams have different preferences
4. **Environments matter** - Dev, staging, and prod need different configs
5. **Compliance built-in** - Security and policies from day one
6. **Measure adoption** - Data drives improvements
7. **Iterate based on feedback** - Listen to developers

## Troubleshooting

### Template Rendering Issues

```bash
# Validate template syntax
npx @backstage/cli template:render ./template.yaml --values '{"name": "test"}'

# Check Backstage logs
kubectl logs -n backstage deploy/backstage | grep scaffolder

# Test template action
curl -X POST http://backstage:7007/api/scaffolder/v2/dry-run \
  -H "Content-Type: application/json" \
  -d '{"templateRef": "template:default/my-template", "values": {"name": "test"}}'
```

### Skeleton Generation Problems

```bash
# Verify Jinja2 syntax
python3 -c "from jinja2 import Template; Template(open('template.yaml').read())"

# Check for unescaped characters
grep -r '{{' skeleton/ | grep -v '${{' 
```

## Next Steps

In Lab 4, we'll explore platform automation including building custom operators, controllers, and CLIs to streamline platform operations.

---

## Quick Reference

### Template Actions

| Action | Description |
|--------|-------------|
| `fetch:template` | Render and copy template files |
| `publish:github` | Create GitHub repository |
| `catalog:register` | Register entity in catalog |
| `argocd:create-resources` | Create ArgoCD application |
| `kubernetes:apply` | Apply Kubernetes manifests |

### Template Variables

```yaml
# Access parameter values
${{ parameters.name }}

# Transform values
${{ parameters.name | replace('-', '_') }}
${{ parameters.name | lower }}

# Conditional logic
{%- if values.enabled %}
...
{%- endif %}

# Loops
{%- for env in values.environments %}
...
{%- endfor %}
```

### Common Patterns

```yaml
# Owner picker
owner:
  ui:field: OwnerPicker
  ui:options:
    catalogFilter:
      kind: Group

# Repo URL picker  
repoUrl:
  ui:field: RepoUrlPicker
  ui:options:
    allowedHosts: [github.com]

# Entity picker
dependency:
  ui:field: EntityPicker
  ui:options:
    catalogFilter:
      kind: Component
```
