# Lab 2: Self-Service Infrastructure with Crossplane

## Introduction

Crossplane extends Kubernetes to manage infrastructure resources across any cloud provider. It enables platform teams to define infrastructure abstractions that development teams can consume through standard Kubernetes APIs. This lab teaches you to set up Crossplane and create self-service infrastructure provisioning workflows.

## Prerequisites

- Kubernetes cluster with admin access
- kubectl configured
- Helm 3.x installed
- Cloud provider credentials (AWS, GCP, or Azure)
- Basic understanding of Kubernetes CRDs

## Learning Objectives

By the end of this lab, you will be able to:

- Install and configure Crossplane
- Set up cloud provider configurations
- Create Composite Resource Definitions (XRDs)
- Build Compositions for infrastructure abstraction
- Implement Claims for self-service provisioning
- Integrate with GitOps workflows
- Monitor and troubleshoot Crossplane resources

## Crossplane Architecture

### Core Concepts

```
┌─────────────────────────────────────────────────────────────────┐
│                       CROSSPLANE                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Platform Team Defines                                           │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  XRD (Composite Resource Definition)                     │    │
│  │  ├── Defines the API shape                               │    │
│  │  └── Schema for claims                                   │    │
│  │                                                          │    │
│  │  Composition                                             │    │
│  │  ├── Maps XRD to managed resources                       │    │
│  │  └── Provider-specific implementation                    │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
│  Developers Request                                              │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Claim (XRC)                                             │    │
│  │  └── Request for infrastructure                          │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Composite Resource (XR)                                 │    │
│  │  └── Cluster-scoped realization of claim                 │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Managed Resources                                       │    │
│  │  ├── RDS Instance                                        │    │
│  │  ├── Security Group                                      │    │
│  │  └── Subnet Group                                        │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Provider Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PROVIDERS                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  provider-aws          provider-gcp         provider-azure       │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     │
│  │ EC2          │     │ Compute      │     │ VM           │     │
│  │ RDS          │     │ CloudSQL     │     │ SQL Database │     │
│  │ S3           │     │ GCS          │     │ Blob Storage │     │
│  │ VPC          │     │ VPC          │     │ VNet         │     │
│  │ IAM          │     │ IAM          │     │ AAD          │     │
│  │ ...          │     │ ...          │     │ ...          │     │
│  └──────────────┘     └──────────────┘     └──────────────┘     │
│                                                                  │
│  provider-kubernetes   provider-helm        provider-terraform   │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     │
│  │ Namespace    │     │ Release      │     │ Workspace    │     │
│  │ Deployment   │     │              │     │ Module       │     │
│  │ Service      │     │              │     │              │     │
│  └──────────────┘     └──────────────┘     └──────────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Installing Crossplane

### Helm Installation

```bash
# Create namespace
kubectl create namespace crossplane-system

# Add Crossplane Helm repo
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

# Install Crossplane
helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --set args='{"--enable-environment-configs"}' \
  --set metrics.enabled=true \
  --set resourcesCrossplane.limits.cpu=500m \
  --set resourcesCrossplane.limits.memory=1Gi

# Verify installation
kubectl get pods -n crossplane-system
kubectl get crds | grep crossplane

# Install Crossplane CLI
curl -sL "https://raw.githubusercontent.com/crossplane/crossplane/master/install.sh" | sh
sudo mv crossplane /usr/local/bin/
```

### Provider Installation

```yaml
# provider-aws.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: xpkg.upbound.io/upbound/provider-aws:v0.47.0
  controllerConfigRef:
    name: provider-aws-config
---
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  name: provider-aws-config
spec:
  resources:
    limits:
      cpu: 500m
      memory: 1Gi
    requests:
      cpu: 100m
      memory: 256Mi
---
# provider-kubernetes.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.11.0
---
# provider-helm.yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-helm
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-helm:v0.16.0
```

```bash
# Apply providers
kubectl apply -f provider-aws.yaml
kubectl apply -f provider-kubernetes.yaml
kubectl apply -f provider-helm.yaml

# Wait for providers to be healthy
kubectl get providers -w
```

### Provider Configuration

```yaml
# aws-provider-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: aws-credentials
  namespace: crossplane-system
type: Opaque
stringData:
  credentials: |
    [default]
    aws_access_key_id = ${AWS_ACCESS_KEY_ID}
    aws_secret_access_key = ${AWS_SECRET_ACCESS_KEY}
---
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: aws-credentials
      key: credentials
---
# For IRSA (IAM Roles for Service Accounts)
apiVersion: aws.upbound.io/v1beta1
kind: ProviderConfig
metadata:
  name: irsa
spec:
  credentials:
    source: IRSA
---
# kubernetes-provider-config.yaml
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
---
# helm-provider-config.yaml
apiVersion: helm.crossplane.io/v1beta1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
```

## Creating Composite Resources

### Database XRD and Composition

```yaml
# xrd-database.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdatabases.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XDatabase
    plural: xdatabases
  claimNames:
    kind: Database
    plural: databases
  connectionSecretKeys:
    - endpoint
    - port
    - username
    - password
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
              properties:
                parameters:
                  type: object
                  required:
                    - size
                    - engine
                  properties:
                    size:
                      type: string
                      description: "Size of the database (small, medium, large)"
                      enum:
                        - small
                        - medium
                        - large
                    engine:
                      type: string
                      description: "Database engine"
                      enum:
                        - postgres
                        - mysql
                    version:
                      type: string
                      description: "Engine version"
                      default: "14"
                    storageGB:
                      type: integer
                      description: "Storage size in GB"
                      default: 20
                      minimum: 10
                      maximum: 1000
                    publiclyAccessible:
                      type: boolean
                      default: false
              required:
                - parameters
            status:
              type: object
              properties:
                endpoint:
                  type: string
                port:
                  type: integer
                status:
                  type: string
---
# composition-database-aws.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xdatabases.aws.platform.example.com
  labels:
    provider: aws
    crossplane.io/xrd: xdatabases.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XDatabase
  
  writeConnectionSecretsToNamespace: crossplane-system
  
  patchSets:
    - name: common-parameters
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.size
          toFieldPath: metadata.labels.size
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.labels.database
  
  resources:
    # Subnet Group
    - name: subnet-group
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: SubnetGroup
        spec:
          forProvider:
            region: us-east-1
            description: Managed by Crossplane
            subnetIds:
              - subnet-xxxxxxxxx  # Replace with actual subnet IDs
              - subnet-yyyyyyyyy
      patches:
        - type: PatchSet
          patchSetName: common-parameters
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-subnet-group"
    
    # Security Group
    - name: security-group
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroup
        spec:
          forProvider:
            region: us-east-1
            vpcId: vpc-xxxxxxxxx  # Replace with actual VPC ID
            description: Database security group
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: metadata.name
          transforms:
            - type: string
              string:
                fmt: "%s-sg"
    
    # Security Group Rule (Ingress)
    - name: security-group-rule
      base:
        apiVersion: ec2.aws.upbound.io/v1beta1
        kind: SecurityGroupRule
        spec:
          forProvider:
            region: us-east-1
            type: ingress
            fromPort: 5432
            toPort: 5432
            protocol: tcp
            cidrBlocks:
              - 10.0.0.0/8
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.engine
          toFieldPath: spec.forProvider.fromPort
          transforms:
            - type: map
              map:
                postgres: "5432"
                mysql: "3306"
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.engine
          toFieldPath: spec.forProvider.toPort
          transforms:
            - type: map
              map:
                postgres: "5432"
                mysql: "3306"
    
    # RDS Instance
    - name: rds-instance
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: us-east-1
            dbName: appdb
            instanceClass: db.t3.micro
            allocatedStorage: 20
            skipFinalSnapshot: true
            publiclyAccessible: false
            autoGeneratePassword: true
            passwordSecretRef:
              key: password
              namespace: crossplane-system
            username: admin
          writeConnectionSecretToRef:
            namespace: crossplane-system
      patches:
        - type: PatchSet
          patchSetName: common-parameters
        
        # Instance class based on size
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.size
          toFieldPath: spec.forProvider.instanceClass
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.t3.medium
                large: db.t3.large
        
        # Engine
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.engine
          toFieldPath: spec.forProvider.engine
        
        # Engine version
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.version
          toFieldPath: spec.forProvider.engineVersion
        
        # Storage
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.storageGB
          toFieldPath: spec.forProvider.allocatedStorage
        
        # Public access
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.publiclyAccessible
          toFieldPath: spec.forProvider.publiclyAccessible
        
        # Connection secret name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: spec.writeConnectionSecretToRef.name
          transforms:
            - type: string
              string:
                fmt: "%s-rds"
        
        # Reference subnet group
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.name
          toFieldPath: spec.forProvider.dbSubnetGroupName
          transforms:
            - type: string
              string:
                fmt: "%s-subnet-group"
        
        # Export endpoint to status
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.endpoint
          toFieldPath: status.endpoint
        
        - type: ToCompositeFieldPath
          fromFieldPath: status.atProvider.port
          toFieldPath: status.port
      
      connectionDetails:
        - name: endpoint
          fromFieldPath: status.atProvider.endpoint
        - name: port
          fromFieldPath: status.atProvider.port
        - name: username
          fromFieldPath: spec.forProvider.username
        - name: password
          fromConnectionSecretKey: password
```

### Claim Example

```yaml
# database-claim.yaml
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: my-app-db
  namespace: my-app
spec:
  parameters:
    size: medium
    engine: postgres
    version: "14"
    storageGB: 50
  compositionSelector:
    matchLabels:
      provider: aws
  writeConnectionSecretToRef:
    name: my-app-db-connection
```

## Application Platform XRD

### Complete Application Stack

```yaml
# xrd-application.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xapplications.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XApplication
    plural: xapplications
  claimNames:
    kind: Application
    plural: applications
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
                - parameters
              properties:
                parameters:
                  type: object
                  required:
                    - name
                    - image
                  properties:
                    name:
                      type: string
                      description: Application name
                    image:
                      type: string
                      description: Container image
                    replicas:
                      type: integer
                      default: 2
                      minimum: 1
                      maximum: 10
                    port:
                      type: integer
                      default: 8080
                    resources:
                      type: object
                      properties:
                        cpu:
                          type: string
                          default: "100m"
                        memory:
                          type: string
                          default: "256Mi"
                    database:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: false
                        size:
                          type: string
                          enum: [small, medium, large]
                          default: small
                    ingress:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: true
                        host:
                          type: string
                    monitoring:
                      type: object
                      properties:
                        enabled:
                          type: boolean
                          default: true
---
# composition-application.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xapplications.platform.example.com
  labels:
    crossplane.io/xrd: xapplications.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XApplication
  
  resources:
    # Namespace
    - name: namespace
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Namespace
              metadata:
                name: ""
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.name
    
    # Deployment
    - name: deployment
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: ""
                namespace: ""
              spec:
                replicas: 2
                selector:
                  matchLabels:
                    app: ""
                template:
                  metadata:
                    labels:
                      app: ""
                  spec:
                    containers:
                      - name: app
                        image: ""
                        ports:
                          - containerPort: 8080
                        resources:
                          requests:
                            cpu: 100m
                            memory: 256Mi
                          limits:
                            cpu: 500m
                            memory: 512Mi
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.spec.selector.matchLabels.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.spec.template.metadata.labels.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.image
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].image
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.replicas
          toFieldPath: spec.forProvider.manifest.spec.replicas
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.port
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].ports[0].containerPort
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.resources.cpu
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].resources.requests.cpu
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.resources.memory
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].resources.requests.memory
    
    # Service
    - name: service
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Service
              metadata:
                name: ""
                namespace: ""
              spec:
                selector:
                  app: ""
                ports:
                  - port: 80
                    targetPort: 8080
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.spec.selector.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.port
          toFieldPath: spec.forProvider.manifest.spec.ports[0].targetPort
    
    # Ingress (conditional)
    - name: ingress
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: networking.k8s.io/v1
              kind: Ingress
              metadata:
                name: ""
                namespace: ""
                annotations:
                  kubernetes.io/ingress.class: nginx
              spec:
                rules:
                  - host: ""
                    http:
                      paths:
                        - path: /
                          pathType: Prefix
                          backend:
                            service:
                              name: ""
                              port:
                                number: 80
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.ingress.enabled
          toFieldPath: spec.forProvider.manifest
          transforms:
            - type: convert
              convert:
                toType: string
          policy:
            fromFieldPath: Required
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.ingress.host
          toFieldPath: spec.forProvider.manifest.spec.rules[0].host
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.spec.rules[0].http.paths[0].backend.service.name
    
    # ServiceMonitor (conditional)
    - name: servicemonitor
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: monitoring.coreos.com/v1
              kind: ServiceMonitor
              metadata:
                name: ""
                namespace: ""
              spec:
                selector:
                  matchLabels:
                    app: ""
                endpoints:
                  - port: http
                    interval: 30s
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.monitoring.enabled
          toFieldPath: spec.forProvider.manifest
          policy:
            fromFieldPath: Required
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: spec.parameters.name
          toFieldPath: spec.forProvider.manifest.spec.selector.matchLabels.app
```

## GitOps Integration

### ArgoCD Application for Claims

```yaml
# argocd-claims-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure-claims
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/org/infrastructure-claims.git
    targetRevision: main
    path: claims
  destination:
    server: https://kubernetes.default.svc
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Claims Repository Structure

```
infrastructure-claims/
├── claims/
│   ├── team-a/
│   │   ├── database.yaml
│   │   └── application.yaml
│   ├── team-b/
│   │   ├── database.yaml
│   │   └── cache.yaml
│   └── team-c/
│       └── application.yaml
└── kustomization.yaml
```

```yaml
# claims/team-a/database.yaml
apiVersion: platform.example.com/v1alpha1
kind: Database
metadata:
  name: team-a-prod-db
  namespace: team-a
spec:
  parameters:
    size: large
    engine: postgres
    version: "15"
    storageGB: 100
  compositionSelector:
    matchLabels:
      provider: aws
  writeConnectionSecretToRef:
    name: prod-db-connection
---
# claims/team-a/application.yaml
apiVersion: platform.example.com/v1alpha1
kind: Application
metadata:
  name: team-a-api
  namespace: team-a
spec:
  parameters:
    name: api-service
    image: ghcr.io/team-a/api:v1.2.3
    replicas: 3
    port: 8080
    ingress:
      enabled: true
      host: api.team-a.example.com
    monitoring:
      enabled: true
```

## Exercises

### Exercise 1: Install Crossplane and Providers

Set up Crossplane with the Kubernetes provider:

```bash
# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm repo update

kubectl create namespace crossplane-system

helm install crossplane crossplane-stable/crossplane \
  --namespace crossplane-system \
  --wait

# Verify installation
kubectl get pods -n crossplane-system
kubectl api-resources | grep crossplane

# Install Kubernetes provider
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.11.0
EOF

# Wait for provider
kubectl get providers -w

# Configure provider
kubectl apply -f - <<EOF
apiVersion: kubernetes.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: default
spec:
  credentials:
    source: InjectedIdentity
EOF

# Grant permissions
kubectl apply -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: provider-kubernetes-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: provider-kubernetes-*
    namespace: crossplane-system
EOF
```

### Exercise 2: Create Simple XRD and Composition

Build a namespace provisioning abstraction:

```bash
# Create XRD for namespace with resource quota
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xnamespaces.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XNamespace
    plural: xnamespaces
  claimNames:
    kind: TeamNamespace
    plural: teamnamespaces
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
                - team
              properties:
                team:
                  type: string
                tier:
                  type: string
                  enum: [small, medium, large]
                  default: small
EOF

# Create Composition
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xnamespaces.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XNamespace
  resources:
    - name: namespace
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Namespace
              metadata:
                name: ""
                labels:
                  managed-by: crossplane
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.team
          toFieldPath: spec.forProvider.manifest.metadata.name
          transforms:
            - type: string
              string:
                fmt: "team-%s"
    
    - name: resource-quota
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: ResourceQuota
              metadata:
                name: default
              spec:
                hard:
                  requests.cpu: "2"
                  requests.memory: 4Gi
                  limits.cpu: "4"
                  limits.memory: 8Gi
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.team
          toFieldPath: spec.forProvider.manifest.metadata.namespace
          transforms:
            - type: string
              string:
                fmt: "team-%s"
        - type: FromCompositeFieldPath
          fromFieldPath: spec.tier
          toFieldPath: spec.forProvider.manifest.spec.hard
          transforms:
            - type: map
              map:
                small: |
                  requests.cpu: "2"
                  requests.memory: "4Gi"
                medium: |
                  requests.cpu: "8"
                  requests.memory: "16Gi"
                large: |
                  requests.cpu: "32"
                  requests.memory: "64Gi"
EOF

# Wait for XRD to be established
kubectl get xrd xnamespaces.platform.example.com

# Create a claim
kubectl apply -f - <<EOF
apiVersion: platform.example.com/v1alpha1
kind: TeamNamespace
metadata:
  name: frontend
  namespace: default
spec:
  team: frontend
  tier: medium
EOF

# Verify resources
kubectl get teamnamespace
kubectl get xnamespace
kubectl get namespace team-frontend
kubectl get resourcequota -n team-frontend
```

### Exercise 3: Build Application Deployment XRD

Create a deployment abstraction:

```bash
# Create XRD for simple deployments
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xdeployments.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XDeployment
    plural: xdeployments
  claimNames:
    kind: AppDeployment
    plural: appdeployments
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
                - image
              properties:
                image:
                  type: string
                replicas:
                  type: integer
                  default: 2
                port:
                  type: integer
                  default: 8080
                expose:
                  type: boolean
                  default: true
EOF

# Create Composition with Deployment, Service, and optional Ingress
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xdeployments.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XDeployment
  resources:
    - name: deployment
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: apps/v1
              kind: Deployment
              spec:
                selector:
                  matchLabels:
                    app: ""
                template:
                  metadata:
                    labels:
                      app: ""
                  spec:
                    containers:
                      - name: app
                        resources:
                          requests:
                            cpu: 100m
                            memory: 128Mi
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-name]
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-namespace]
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-name]
          toFieldPath: spec.forProvider.manifest.spec.selector.matchLabels.app
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-name]
          toFieldPath: spec.forProvider.manifest.spec.template.metadata.labels.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.image
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].image
        - type: FromCompositeFieldPath
          fromFieldPath: spec.replicas
          toFieldPath: spec.forProvider.manifest.spec.replicas
        - type: FromCompositeFieldPath
          fromFieldPath: spec.port
          toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].ports[0].containerPort
    
    - name: service
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Service
              spec:
                type: ClusterIP
                ports:
                  - port: 80
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-name]
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-namespace]
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-name]
          toFieldPath: spec.forProvider.manifest.spec.selector.app
        - type: FromCompositeFieldPath
          fromFieldPath: spec.port
          toFieldPath: spec.forProvider.manifest.spec.ports[0].targetPort
EOF

# Create claim
kubectl apply -f - <<EOF
apiVersion: platform.example.com/v1alpha1
kind: AppDeployment
metadata:
  name: nginx-app
  namespace: default
spec:
  image: nginx:1.25
  replicas: 3
  port: 80
  expose: true
EOF

# Verify
kubectl get appdeployment
kubectl get deployment nginx-app
kubectl get service nginx-app
```

### Exercise 4: Composition Functions

Use functions to add dynamic logic:

```bash
# Install function-patch-and-transform
kubectl apply -f - <<EOF
apiVersion: pkg.crossplane.io/v1beta1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.4.0
EOF

# Wait for function
kubectl get functions -w

# Create composition using functions
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xdeployments-with-functions.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XDeployment
  mode: Pipeline
  pipeline:
    - step: patch-and-transform
      functionRef:
        name: function-patch-and-transform
      input:
        apiVersion: pt.fn.crossplane.io/v1beta1
        kind: Resources
        resources:
          - name: deployment
            base:
              apiVersion: kubernetes.crossplane.io/v1alpha1
              kind: Object
              spec:
                forProvider:
                  manifest:
                    apiVersion: apps/v1
                    kind: Deployment
                    spec:
                      replicas: 2
                      template:
                        spec:
                          containers:
                            - name: app
            patches:
              - type: FromCompositeFieldPath
                fromFieldPath: spec.image
                toFieldPath: spec.forProvider.manifest.spec.template.spec.containers[0].image
              - type: FromCompositeFieldPath
                fromFieldPath: spec.replicas
                toFieldPath: spec.forProvider.manifest.spec.replicas
EOF
```

### Exercise 5: Claims with Connection Secrets

Create resources that export connection details:

```bash
# Deploy a simple secret-generating composition
kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xcredentials.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: XCredentials
    plural: xcredentials
  claimNames:
    kind: Credentials
    plural: credentials
  connectionSecretKeys:
    - username
    - password
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
              properties:
                serviceName:
                  type: string
EOF

kubectl apply -f - <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xcredentials.platform.example.com
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: XCredentials
  writeConnectionSecretsToNamespace: crossplane-system
  resources:
    - name: credentials-secret
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha1
        kind: Object
        spec:
          forProvider:
            manifest:
              apiVersion: v1
              kind: Secret
              type: Opaque
              data:
                username: YWRtaW4=  # admin
                password: cGFzc3dvcmQxMjM=  # password123
          writeConnectionSecretToRef:
            namespace: crossplane-system
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.serviceName
          toFieldPath: spec.forProvider.manifest.metadata.name
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.labels[crossplane.io/claim-namespace]
          toFieldPath: spec.forProvider.manifest.metadata.namespace
        - type: FromCompositeFieldPath
          fromFieldPath: metadata.uid
          toFieldPath: spec.writeConnectionSecretToRef.name
      connectionDetails:
        - type: FromFieldPath
          name: username
          fromFieldPath: spec.forProvider.manifest.data.username
        - type: FromFieldPath
          name: password
          fromFieldPath: spec.forProvider.manifest.data.password
EOF

# Create claim with connection secret
kubectl apply -f - <<EOF
apiVersion: platform.example.com/v1alpha1
kind: Credentials
metadata:
  name: myapp-creds
  namespace: default
spec:
  serviceName: myapp-credentials
  writeConnectionSecretToRef:
    name: myapp-connection
EOF

# Verify connection secret was created
kubectl get secret myapp-connection -o yaml
```

## Validation Checklist

Before proceeding to the next lab, verify you can:

- [ ] Install Crossplane and providers
- [ ] Create CompositeResourceDefinitions (XRDs)
- [ ] Build Compositions with patches
- [ ] Create Claims for self-service provisioning
- [ ] Export connection secrets from compositions
- [ ] Integrate with GitOps workflows
- [ ] Debug Crossplane resources

## Key Takeaways

1. **XRDs define the API** - The interface developers interact with
2. **Compositions implement the API** - Map claims to actual resources
3. **Claims are namespaced** - Teams request resources in their namespace
4. **Patches enable customization** - Map claim fields to resource fields
5. **Connection secrets propagate credentials** - Secure credential handling
6. **GitOps works naturally** - Claims are just Kubernetes resources
7. **Providers extend capabilities** - Support for any infrastructure

## Troubleshooting

### Resource Not Creating

```bash
# Check XRD status
kubectl describe xrd xdatabases.platform.example.com

# Check composition
kubectl get composition
kubectl describe composition xdatabases.aws.platform.example.com

# Check claim status
kubectl describe database my-app-db -n my-app

# Check composite resource
kubectl get xdatabase -o yaml

# Check managed resources
kubectl get managed
kubectl describe <managed-resource>

# Check provider logs
kubectl logs -n crossplane-system -l pkg.crossplane.io/provider=provider-aws
```

### Provider Issues

```bash
# Check provider health
kubectl get providers

# Check provider config
kubectl get providerconfigs

# Check provider credentials
kubectl get secret -n crossplane-system aws-credentials -o yaml
```

## Next Steps

In Lab 3, we'll explore golden paths and templates to create standardized development experiences that combine self-service infrastructure with application scaffolding.

---

## Quick Reference

### Resource Hierarchy

```
Claim (namespaced)
  └── Composite Resource (cluster-scoped)
        └── Managed Resources (cloud resources)
```

### Common Patches

```yaml
# Simple field copy
- type: FromCompositeFieldPath
  fromFieldPath: spec.parameters.size
  toFieldPath: spec.forProvider.instanceClass

# With transform
- type: FromCompositeFieldPath
  fromFieldPath: spec.parameters.size
  toFieldPath: spec.forProvider.instanceClass
  transforms:
    - type: map
      map:
        small: db.t3.micro
        large: db.t3.large

# To status
- type: ToCompositeFieldPath
  fromFieldPath: status.atProvider.endpoint
  toFieldPath: status.endpoint
```

### Crossplane CLI

```bash
# Build package
crossplane xpkg build -f package/

# Push package
crossplane xpkg push -f package.xpkg xpkg.upbound.io/org/package:v1.0.0

# Install package
crossplane xpkg install provider xpkg.upbound.io/org/provider:v1.0.0
```
