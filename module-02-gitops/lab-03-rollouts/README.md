# Lab 3: Progressive Delivery with Argo Rollouts

## Objective

Implement progressive delivery strategies using Argo Rollouts, including Canary deployments with traffic shifting, Blue/Green deployments, and automated analysis for safe production releases.

## What You'll Learn

- Install and configure Argo Rollouts
- Implement Canary deployments with percentage-based traffic shifting
- Configure Blue/Green deployments with instant cutover
- Set up Analysis Templates for automated rollback decisions
- Integrate with metrics providers (Prometheus)
- Manage rollout pauses, promotions, and aborts

## Prerequisites

- Completed Labs 1-2 (ArgoCD installed)
- Running kind cluster
- Basic understanding of deployment strategies

## Lab Steps

### Step 1: Understanding Progressive Delivery

**Traditional Deployment (All-at-Once):**

```
v1 (100%) ─────────────── v2 (100%)
           instant switch
           high risk
```

**Canary Deployment:**

```
v1 (100%) → v1 (90%) + v2 (10%) → v1 (50%) + v2 (50%) → v2 (100%)
            gradual shift, validate at each step
```

**Blue/Green Deployment:**

```
Blue (active) ─── Green (preview) ─── Green (active)
                  test preview       instant switch
```

**Why Progressive Delivery Matters:**

- Reduce blast radius of bad deployments
- Automated rollback on failure
- Real-time traffic analysis
- Zero-downtime releases
- Confidence in production changes

### Step 2: Install Argo Rollouts

1. **Install the Argo Rollouts controller:**

```bash
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

2. **Wait for controller to be ready:**

```bash
kubectl wait --for=condition=Ready pods --all -n argo-rollouts --timeout=120s
```

3. **Verify installation:**

```bash
kubectl get pods -n argo-rollouts
```

Expected output:

```text
NAME                             READY   STATUS    RESTARTS   AGE
argo-rollouts-xxxxxxxxx-xxxxx    1/1     Running   0          1m
```

4. **Install the kubectl plugin (optional but recommended):**

```bash
# Linux
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts

# Verify
kubectl argo rollouts version
```

### Step 3: Create Lab Namespace

```bash
kubectl create namespace rollouts-demo
kubectl config set-context --current --namespace=rollouts-demo
```

### Step 4: Deploy a Basic Canary Rollout

1. **Create a Rollout resource (replaces Deployment):**

Save as `canary-rollout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-demo
  namespace: rollouts-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: canary-demo
  template:
    metadata:
      labels:
        app: canary-demo
    spec:
      containers:
      - name: rollouts-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 30s}
        - setWeight: 40
        - pause: {duration: 30s}
        - setWeight: 60
        - pause: {duration: 30s}
        - setWeight: 80
        - pause: {duration: 30s}
```

2. **Create a Service:**

Save as `canary-service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: canary-demo
  namespace: rollouts-demo
spec:
  selector:
    app: canary-demo
  ports:
  - port: 80
    targetPort: 8080
```

3. **Apply the resources:**

```bash
kubectl apply -f canary-rollout.yaml
kubectl apply -f canary-service.yaml
```

4. **Watch the rollout status:**

```bash
kubectl argo rollouts get rollout canary-demo --watch
```

### Step 5: Trigger a Canary Update

1. **Update the image to trigger a canary release:**

```bash
kubectl argo rollouts set image canary-demo rollouts-demo=argoproj/rollouts-demo:yellow
```

2. **Watch the canary progression:**

```bash
kubectl argo rollouts get rollout canary-demo --watch
```

You'll see output like:

```text
Name:            canary-demo
Namespace:       rollouts-demo
Status:          ॥ Paused
Strategy:        Canary
  Step:          1/8
  SetWeight:     20
  ActualWeight:  20
Images:          argoproj/rollouts-demo:blue (stable)
                 argoproj/rollouts-demo:yellow (canary)
Replicas:
  Desired:       5
  Current:       5
  Updated:       1
  Ready:         5
  Available:     5
```

3. **Manually promote to next step (if using manual pause):**

```bash
kubectl argo rollouts promote canary-demo
```

4. **Or abort if issues found:**

```bash
kubectl argo rollouts abort canary-demo
```

### Step 6: Blue/Green Deployment

1. **Create a Blue/Green Rollout:**

Save as `bluegreen-rollout.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: bluegreen-demo
  namespace: rollouts-demo
spec:
  replicas: 3
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: bluegreen-demo
  template:
    metadata:
      labels:
        app: bluegreen-demo
    spec:
      containers:
      - name: rollouts-demo
        image: argoproj/rollouts-demo:blue
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
  strategy:
    blueGreen:
      activeService: bluegreen-active
      previewService: bluegreen-preview
      autoPromotionEnabled: false
      scaleDownDelaySeconds: 30
      prePromotionAnalysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: bluegreen-preview
```

2. **Create Active and Preview Services:**

Save as `bluegreen-services.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-active
  namespace: rollouts-demo
spec:
  selector:
    app: bluegreen-demo
  ports:
  - port: 80
    targetPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: bluegreen-preview
  namespace: rollouts-demo
spec:
  selector:
    app: bluegreen-demo
  ports:
  - port: 80
    targetPort: 8080
```

3. **Apply:**

```bash
kubectl apply -f bluegreen-services.yaml
kubectl apply -f bluegreen-rollout.yaml
```

4. **Trigger a Blue/Green update:**

```bash
kubectl argo rollouts set image bluegreen-demo rollouts-demo=argoproj/rollouts-demo:green
```

5. **View the status:**

```bash
kubectl argo rollouts get rollout bluegreen-demo --watch
```

6. **Preview the new version:**

```bash
kubectl port-forward svc/bluegreen-preview 8081:80 &
curl http://localhost:8081
```

7. **Promote when ready:**

```bash
kubectl argo rollouts promote bluegreen-demo
```

### Step 7: Analysis Templates

Analysis Templates automate rollback decisions based on metrics.

1. **Create a simple Analysis Template:**

Save as `analysis-template.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: success-rate
  namespace: rollouts-demo
spec:
  args:
    - name: service-name
  metrics:
    - name: success-rate
      interval: 10s
      count: 3
      successCondition: result[0] >= 0.95
      failureLimit: 1
      provider:
        job:
          spec:
            backoffLimit: 0
            template:
              spec:
                containers:
                - name: analysis
                  image: curlimages/curl:latest
                  command: ["/bin/sh", "-c"]
                  args:
                    - |
                      # Simulate success rate check
                      # In real scenario, query Prometheus
                      echo '[0.99]'
                restartPolicy: Never
```

2. **Apply the template:**

```bash
kubectl apply -f analysis-template.yaml
```

3. **Prometheus-based Analysis (for real metrics):**

Save as `prometheus-analysis.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AnalysisTemplate
metadata:
  name: prometheus-success-rate
  namespace: rollouts-demo
spec:
  args:
    - name: service-name
    - name: namespace
      value: rollouts-demo
  metrics:
    - name: success-rate
      interval: 30s
      count: 5
      successCondition: result[0] >= 0.95
      failureCondition: result[0] < 0.90
      failureLimit: 3
      provider:
        prometheus:
          address: http://prometheus.monitoring:9090
          query: |
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              namespace="{{args.namespace}}",
              status=~"2.*"
            }[1m])) /
            sum(rate(http_requests_total{
              service="{{args.service-name}}",
              namespace="{{args.namespace}}"
            }[1m]))
```

### Step 8: Canary with Inline Analysis

Add analysis directly to the Canary strategy:

Save as `canary-with-analysis.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-analysis
  namespace: rollouts-demo
spec:
  replicas: 5
  selector:
    matchLabels:
      app: canary-analysis
  template:
    metadata:
      labels:
        app: canary-analysis
    spec:
      containers:
      - name: app
        image: argoproj/rollouts-demo:blue
        ports:
        - containerPort: 8080
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 10s}
        - analysis:
            templates:
              - templateName: success-rate
            args:
              - name: service-name
                value: canary-analysis
        - setWeight: 40
        - pause: {duration: 10s}
        - setWeight: 60
        - pause: {duration: 10s}
        - setWeight: 80
        - pause: {duration: 10s}
      # Anti-affinity to spread canary and stable pods
      canaryMetadata:
        labels:
          role: canary
      stableMetadata:
        labels:
          role: stable
```

### Step 9: Traffic Management with Service Mesh

For precise traffic control, integrate with a service mesh.

**Canary with Istio:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-istio
spec:
  replicas: 5
  selector:
    matchLabels:
      app: canary-istio
  template:
    metadata:
      labels:
        app: canary-istio
    spec:
      containers:
      - name: app
        image: myapp:v1
        ports:
        - containerPort: 8080
  strategy:
    canary:
      canaryService: canary-istio-canary
      stableService: canary-istio-stable
      trafficRouting:
        istio:
          virtualService:
            name: canary-istio-vsvc
            routes:
              - primary
      steps:
        - setWeight: 10
        - pause: {duration: 1m}
        - setWeight: 30
        - pause: {duration: 1m}
        - setWeight: 50
        - pause: {duration: 1m}
```

**Canary with NGINX Ingress:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: canary-nginx
spec:
  replicas: 5
  selector:
    matchLabels:
      app: canary-nginx
  template:
    # ... template spec
  strategy:
    canary:
      canaryService: canary-nginx-canary
      stableService: canary-nginx-stable
      trafficRouting:
        nginx:
          stableIngress: canary-nginx-ingress
          annotationPrefix: nginx.ingress.kubernetes.io
          additionalIngressAnnotations:
            canary-by-header: X-Canary
      steps:
        - setWeight: 20
        - pause: {}
```

### Step 10: Rollout Dashboard

1. **Access the Argo Rollouts Dashboard:**

```bash
kubectl argo rollouts dashboard &
```

2. **Open http://localhost:3100 in your browser**

The dashboard shows:

- All Rollouts in the cluster
- Current step and progress
- ReplicaSet history
- Analysis results

### Step 11: Rollout Commands Reference

**Status and Monitoring:**

```bash
# Get rollout status
kubectl argo rollouts get rollout <name>

# Watch rollout in real-time
kubectl argo rollouts get rollout <name> --watch

# List all rollouts
kubectl argo rollouts list rollouts

# Get rollout history
kubectl argo rollouts history rollout <name>
```

**Controlling Rollouts:**

```bash
# Promote to next step
kubectl argo rollouts promote <name>

# Skip all remaining steps (full promote)
kubectl argo rollouts promote <name> --full

# Abort rollout (rollback)
kubectl argo rollouts abort <name>

# Retry aborted rollout
kubectl argo rollouts retry rollout <name>

# Restart rollout (recreate pods)
kubectl argo rollouts restart <name>

# Undo to previous version
kubectl argo rollouts undo <name>
kubectl argo rollouts undo <name> --to-revision=2
```

**Updating Rollouts:**

```bash
# Set new image
kubectl argo rollouts set image <name> <container>=<image>

# Pause rollout
kubectl argo rollouts pause <name>

# Resume paused rollout
kubectl argo rollouts resume <name>
```

### Step 12: ArgoCD Integration

Deploy Rollouts through ArgoCD:

Save as `rollout-argocd-app.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rollouts-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/rollouts-repo.git
    targetRevision: HEAD
    path: rollouts
  destination:
    server: https://kubernetes.default.svc
    namespace: production
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
    syncOptions:
      - CreateNamespace=true
      - RespectIgnoreDifferences=true
  ignoreDifferences:
    - group: argoproj.io
      kind: Rollout
      jsonPointers:
        - /spec/replicas
```

**Important:** Use `RespectIgnoreDifferences` to prevent ArgoCD from reverting rollout state during canary.

## Validation

Verify your lab completion:

```bash
# Check Argo Rollouts controller is running
kubectl get pods -n argo-rollouts

# List all rollouts
kubectl argo rollouts list rollouts -n rollouts-demo

# Check canary rollout status
kubectl argo rollouts get rollout canary-demo -n rollouts-demo

# Verify analysis template exists
kubectl get analysistemplate -n rollouts-demo
```

## Practice Challenges

### Challenge 1: Timed Canary Release

Create a Canary rollout that:

- Starts at 5% traffic
- Increases by 15% every 2 minutes
- Has a 5-minute bake time at 50%
- Completes in approximately 15 minutes

### Challenge 2: Blue/Green with Analysis

Create a Blue/Green rollout that:

- Runs pre-promotion analysis for 2 minutes
- Uses a success rate check
- Auto-promotes if analysis passes
- Has scale-down delay of 60 seconds

### Challenge 3: A/B Testing Setup

Create a Canary setup that:

- Routes based on header `X-Canary: true`
- Sends all header traffic to canary
- Regular traffic stays on stable
- Uses NGINX ingress annotations

### Challenge 4: Automated Rollback

Create an analysis that:

- Checks every 30 seconds
- Requires 95% success rate
- Aborts after 3 consecutive failures
- Completes after 5 successful checks

## Cleanup

```bash
# Delete all rollouts in demo namespace
kubectl delete rollouts --all -n rollouts-demo

# Delete analysis templates
kubectl delete analysistemplates --all -n rollouts-demo

# Delete namespace
kubectl delete namespace rollouts-demo

# Uninstall Argo Rollouts (optional - keep for other labs)
# kubectl delete -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml
```

## Troubleshooting

### Rollout stuck in Paused state

Check if it's waiting for manual promotion:

```bash
kubectl argo rollouts get rollout <name>
kubectl argo rollouts promote <name>
```

### Analysis failing

Check analysis run status:

```bash
kubectl get analysisruns -n rollouts-demo
kubectl describe analysisrun <name> -n rollouts-demo
```

View analysis job logs:

```bash
kubectl logs job/<analysis-job-name> -n rollouts-demo
```

### Traffic not shifting (Canary)

Ensure services are correctly configured:

```bash
kubectl get endpoints -n rollouts-demo
kubectl describe svc <service-name> -n rollouts-demo
```

Check pod labels match service selector.

### ReplicaSets not scaling properly

Check rollout events:

```bash
kubectl describe rollout <name> -n rollouts-demo
```

Look for resource quota or scheduling issues.

## Key Takeaways

- Rollouts replace Deployments for progressive delivery
- Canary provides gradual traffic shifting with validation points
- Blue/Green provides instant cutover with preview testing
- Analysis Templates automate go/no-go decisions
- Integration with service meshes enables precise traffic control
- ArgoCD can manage Rollouts like any other resource
- Always have a rollback plan - use `abort` when needed
- Combine with observability for data-driven releases

## Additional Resources

- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [Canary Strategy](https://argo-rollouts.readthedocs.io/en/stable/features/canary/)
- [Blue/Green Strategy](https://argo-rollouts.readthedocs.io/en/stable/features/bluegreen/)
- [Analysis and Progressive Delivery](https://argo-rollouts.readthedocs.io/en/stable/features/analysis/)
- [Traffic Management](https://argo-rollouts.readthedocs.io/en/stable/features/traffic-management/)

## Next Lab

Continue to [Lab 4: GitOps Workflows & Best Practices](../lab-04-workflows/) to learn about repository structures, environment promotion, and secret management.

---

[Back to Module 2 README](../README.md) | [Previous: Lab 2](../lab-02-app-patterns/) | [Next: Lab 4](../lab-04-workflows/)
