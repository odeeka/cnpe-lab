# Module 5: Platform Engineering - Quick Reference

## Backstage Commands

### CLI Operations

```bash
# Create new Backstage app
npx @backstage/create-app@latest

# Start Backstage locally
yarn dev

# Build for production
yarn build

# Validate catalog entities
backstage-cli catalog:validate catalog-info.yaml

# Generate TechDocs
npx @techdocs/cli generate --source-dir . --output-dir ./site

# Publish TechDocs
npx @techdocs/cli publish --publisher-type awsS3 --storage-name techdocs-bucket
```

### Catalog Entity Types

```yaml
# Component (service, website, library)
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: my-service
  annotations:
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: team-name
  dependsOn:
    - component:other-service
  providesApis:
    - my-api

# API definition
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: my-api
spec:
  type: openapi
  lifecycle: production
  owner: team-name
  definition:
    $text: ./api-spec.yaml

# System grouping
apiVersion: backstage.io/v1alpha1
kind: System
metadata:
  name: payment-system
spec:
  owner: team-payments

# Domain
apiVersion: backstage.io/v1alpha1
kind: Domain
metadata:
  name: payments
spec:
  owner: team-payments
```

### Software Templates

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: nodejs-service
  title: Node.js Service
spec:
  owner: platform-team
  type: service
  parameters:
    - title: Service Details
      properties:
        name:
          type: string
        owner:
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
```

---

## Crossplane Commands

### CLI Operations

```bash
# Install Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable
helm install crossplane crossplane-stable/crossplane -n crossplane-system --create-namespace

# Install provider
kubectl crossplane install provider xpkg.upbound.io/upbound/provider-aws:v0.40.0

# Create provider config
kubectl apply -f provider-config.yaml

# Check XRDs
kubectl get xrd

# Check compositions
kubectl get compositions

# Check claims
kubectl get claim -A

# Describe composite resource
kubectl describe database.platform.example.com my-database

# Check provider health
kubectl get providers
kubectl get providerconfigs
```

### XRD Template

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
              properties:
                engine:
                  type: string
                  enum: [postgres, mysql]
                size:
                  type: string
                  enum: [small, medium, large]
            status:
              type: object
              properties:
                endpoint:
                  type: string
```

### Composition Template

```yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: database-aws
spec:
  compositeTypeRef:
    apiVersion: platform.example.com/v1alpha1
    kind: Database
  resources:
    - name: rds
      base:
        apiVersion: rds.aws.upbound.io/v1beta1
        kind: Instance
        spec:
          forProvider:
            region: us-east-1
            instanceClass: db.t3.micro
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.size
          toFieldPath: spec.forProvider.instanceClass
          transforms:
            - type: map
              map:
                small: db.t3.micro
                medium: db.t3.small
                large: db.t3.medium
```

### Claim Template

```yaml
apiVersion: platform.example.com/v1alpha1
kind: DatabaseClaim
metadata:
  name: my-db
  namespace: my-app
spec:
  engine: postgres
  size: medium
  compositionSelector:
    matchLabels:
      provider: aws
  writeConnectionSecretToRef:
    name: my-db-connection
```

---

## Kubebuilder Commands

### Project Setup

```bash
# Initialize project
kubebuilder init --domain example.com --repo github.com/org/operator

# Create API
kubebuilder create api --group platform --version v1alpha1 --kind DevEnvironment

# Create webhook
kubebuilder create webhook --group platform --version v1alpha1 --kind DevEnvironment \
  --defaulting --programmatic-validation

# Generate manifests
make manifests

# Generate code
make generate

# Build and push image
make docker-build docker-push IMG=registry/operator:tag

# Deploy to cluster
make deploy IMG=registry/operator:tag

# Run locally
make run

# Uninstall
make uninstall
```

### CRD Markers

```go
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=devenv;de
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// Validation markers
// +kubebuilder:validation:Required
// +kubebuilder:validation:Minimum=1
// +kubebuilder:validation:Maximum=100
// +kubebuilder:validation:Pattern=`^[a-z]+$`
// +kubebuilder:validation:Enum=small;medium;large
// +kubebuilder:default=medium
```

### Controller Template

```go
func (r *DevEnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    log := log.FromContext(ctx)

    // Fetch resource
    devEnv := &platformv1alpha1.DevEnvironment{}
    if err := r.Get(ctx, req.NamespacedName, devEnv); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    // Handle deletion
    if !devEnv.DeletionTimestamp.IsZero() {
        return r.handleDeletion(ctx, devEnv)
    }

    // Add finalizer
    if !controllerutil.ContainsFinalizer(devEnv, finalizerName) {
        controllerutil.AddFinalizer(devEnv, finalizerName)
        return ctrl.Result{}, r.Update(ctx, devEnv)
    }

    // Reconcile logic
    if err := r.reconcileDeployment(ctx, devEnv); err != nil {
        return ctrl.Result{}, err
    }

    // Update status
    devEnv.Status.Phase = "Ready"
    return ctrl.Result{}, r.Status().Update(ctx, devEnv)
}

func (r *DevEnvironmentReconciler) SetupWithManager(mgr ctrl.Manager) error {
    return ctrl.NewControllerManagedBy(mgr).
        For(&platformv1alpha1.DevEnvironment{}).
        Owns(&appsv1.Deployment{}).
        Complete(r)
}
```

---

## Argo Events

### EventSource Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github-webhook
spec:
  github:
    my-repo:
      repositories:
        - owner: myorg
          names: [my-app]
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
      events:
        - push
        - pull_request
      apiToken:
        name: github-token
        key: token
```

### Sensor Template

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: deploy-sensor
spec:
  dependencies:
    - name: github-push
      eventSourceName: github-webhook
      eventName: my-repo
      filters:
        data:
          - path: body.ref
            type: string
            value: ["refs/heads/main"]
  triggers:
    - template:
        name: deploy
        argoWorkflow:
          operation: submit
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: deploy-
              spec:
                entrypoint: deploy
                templates:
                  - name: deploy
                    container:
                      image: alpine
                      command: [echo, "deploying"]
          parameters:
            - src:
                dependencyName: github-push
                dataKey: body.after
              dest: spec.arguments.parameters.0.value
```

---

## Kubecost

### API Endpoints

```bash
# Get allocation by namespace
curl "http://kubecost:9090/model/allocation?window=1d&aggregate=namespace"

# Get allocation by label
curl "http://kubecost:9090/model/allocation?window=7d&aggregate=label:team"

# Get savings recommendations
curl "http://kubecost:9090/model/savings/requestSizing?window=7d"

# Get cluster costs
curl "http://kubecost:9090/model/clusterCostsOverTime?window=30d"

# Get namespace costs
curl "http://kubecost:9090/model/allocation?window=30d&aggregate=namespace&accumulate=true"
```

### Helm Values

```yaml
global:
  prometheus:
    enabled: true
    fqdn: http://prometheus:9090

kubecostProductConfigs:
  clusterName: production

persistentVolume:
  enabled: true
  size: 32Gi

kubecostModel:
  etlDailyStoreDurationDays: 30
```

---

## ResourceQuota & LimitRange

### ResourceQuota Template

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: team-quota
  namespace: team-ns
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "50"
    services: "20"
    services.loadbalancers: "2"
    persistentvolumeclaims: "20"
    requests.storage: 100Gi
```

### LimitRange Template

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: team-limits
  namespace: team-ns
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
    - type: PersistentVolumeClaim
      min:
        storage: 1Gi
      max:
        storage: 50Gi
```

---

## Multi-Tenancy

### NetworkPolicy for Isolation

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: tenant-isolation
  namespace: tenant-ns
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - podSelector: {}
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
  egress:
    - to:
        - podSelector: {}
    - to:
        - namespaceSelector: {}
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
```

### HNC Commands

```bash
# Install HNC
kubectl apply -f https://github.com/kubernetes-sigs/hierarchical-namespaces/releases/latest/download/default.yaml

# Create subnamespace
kubectl hns create child -n parent

# View hierarchy
kubectl hns tree parent

# Set parent
kubectl hns set child --parent parent

# Describe hierarchy
kubectl hns describe parent

# Check propagated resources
kubectl get resourcequota -n child
```

### vCluster Commands

```bash
# Install vCluster CLI
curl -L -o vcluster "https://github.com/loft-sh/vcluster/releases/latest/download/vcluster-linux-amd64"

# Create vCluster
vcluster create my-vcluster -n vcluster-ns

# Connect to vCluster
vcluster connect my-vcluster -n vcluster-ns

# List vClusters
vcluster list

# Delete vCluster
vcluster delete my-vcluster -n vcluster-ns

# Disconnect
vcluster disconnect
```

---

## Kubectl Plugin Development

### Plugin Structure

```bash
# Plugin must be named kubectl-<name>
kubectl-platform

# Install by placing in PATH
sudo mv kubectl-platform /usr/local/bin/

# Verify
kubectl plugin list
```

### Cobra CLI Template

```go
package main

import (
    "github.com/spf13/cobra"
    "k8s.io/client-go/tools/clientcmd"
)

func main() {
    rootCmd := &cobra.Command{
        Use:   "kubectl-platform",
        Short: "Platform engineering tools",
    }

    rootCmd.AddCommand(
        newEnvCmd(),
        newCompletionCmd(rootCmd),
    )

    rootCmd.Execute()
}

func newEnvCmd() *cobra.Command {
    cmd := &cobra.Command{
        Use:   "env",
        Short: "Manage environments",
    }
    cmd.AddCommand(
        &cobra.Command{Use: "create", RunE: createEnv},
        &cobra.Command{Use: "list", RunE: listEnvs},
        &cobra.Command{Use: "delete", RunE: deleteEnv},
    )
    return cmd
}
```

---

## Common Patterns

### Owner References

```go
// Set owner reference for garbage collection
controllerutil.SetControllerReference(parent, child, r.Scheme)
```

### Finalizers

```go
// Add finalizer
if !controllerutil.ContainsFinalizer(obj, finalizerName) {
    controllerutil.AddFinalizer(obj, finalizerName)
    return ctrl.Result{}, r.Update(ctx, obj)
}

// Remove finalizer
controllerutil.RemoveFinalizer(obj, finalizerName)
return ctrl.Result{}, r.Update(ctx, obj)
```

### Status Conditions

```go
meta.SetStatusCondition(&obj.Status.Conditions, metav1.Condition{
    Type:               "Ready",
    Status:             metav1.ConditionTrue,
    Reason:             "Provisioned",
    Message:            "All resources created",
    LastTransitionTime: metav1.Now(),
})
```

### Requeue

```go
// Requeue after duration
return ctrl.Result{RequeueAfter: time.Minute * 5}, nil

// Requeue immediately
return ctrl.Result{Requeue: true}, nil
```

---

## Useful Labels

```yaml
# Standard labels
labels:
  app.kubernetes.io/name: my-app
  app.kubernetes.io/instance: my-app-prod
  app.kubernetes.io/version: "1.0.0"
  app.kubernetes.io/component: frontend
  app.kubernetes.io/part-of: my-system
  app.kubernetes.io/managed-by: platform-operator

# Cost allocation labels
labels:
  team: payments
  cost-center: cc-1234
  environment: production
  project: checkout

# Tenant labels
labels:
  tenant: analytics
  tenant-tier: premium
```
