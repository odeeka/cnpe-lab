# Lab 4: Platform Automation - Part 2

## Advanced Controllers and Event-Driven Automation

This part covers advanced controller patterns, event-driven automation with Argo Events, and building platform APIs for self-service capabilities.

---

## Part 2: Advanced Controller Patterns

### Understanding Reconciliation Patterns

```
┌─────────────────────────────────────────────────────────────────┐
│                 RECONCILIATION STRATEGIES                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Level-Triggered (Recommended)                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  • Compare desired vs actual state                        │   │
│  │  • Reconcile on any difference                            │   │
│  │  • Idempotent operations                                  │   │
│  │  • Handles missed events                                  │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  Edge-Triggered (Avoid)                                          │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  • React to specific events                               │   │
│  │  • Can miss events during downtime                        │   │
│  │  • Non-idempotent risk                                    │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Exercise 1: Multi-Resource Controller

Create a controller that manages multiple dependent resources:

```go
// internal/controller/platformstack_controller.go
package controller

import (
	"context"
	"fmt"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"

	platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

// PlatformStackReconciler manages complete application stacks
type PlatformStackReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=platform.example.com,resources=platformstacks,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.example.com,resources=platformstacks/status,verbs=get;update;patch

func (r *PlatformStackReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// Fetch the PlatformStack
	stack := &platformv1alpha1.PlatformStack{}
	if err := r.Get(ctx, req.NamespacedName, stack); err != nil {
		if errors.IsNotFound(err) {
			return ctrl.Result{}, nil
		}
		return ctrl.Result{}, err
	}

	// Initialize status
	if stack.Status.Components == nil {
		stack.Status.Components = make(map[string]platformv1alpha1.ComponentStatus)
	}

	// Reconcile each component in order
	components := []struct {
		name      string
		reconcile func(context.Context, *platformv1alpha1.PlatformStack) error
	}{
		{"namespace", r.reconcileNamespace},
		{"configmap", r.reconcileConfigMap},
		{"secrets", r.reconcileSecrets},
		{"database", r.reconcileDatabase},
		{"cache", r.reconcileCache},
		{"application", r.reconcileApplication},
		{"service", r.reconcileService},
		{"ingress", r.reconcileIngress},
	}

	var lastError error
	for _, comp := range components {
		logger.Info("Reconciling component", "component", comp.name)
		
		if err := comp.reconcile(ctx, stack); err != nil {
			lastError = err
			stack.Status.Components[comp.name] = platformv1alpha1.ComponentStatus{
				Ready:   false,
				Message: err.Error(),
			}
		} else {
			stack.Status.Components[comp.name] = platformv1alpha1.ComponentStatus{
				Ready:   true,
				Message: "Component ready",
			}
		}
	}

	// Update overall status
	allReady := true
	for _, status := range stack.Status.Components {
		if !status.Ready {
			allReady = false
			break
		}
	}

	if allReady {
		stack.Status.Phase = "Ready"
		stack.Status.Message = "All components are ready"
	} else {
		stack.Status.Phase = "Degraded"
		stack.Status.Message = "Some components are not ready"
	}

	if err := r.Status().Update(ctx, stack); err != nil {
		return ctrl.Result{}, err
	}

	if lastError != nil {
		return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
	}

	return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}

func (r *PlatformStackReconciler) reconcileNamespace(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	ns := &corev1.Namespace{
		ObjectMeta: metav1.ObjectMeta{
			Name: stack.Spec.Namespace,
			Labels: map[string]string{
				"platform.example.com/stack":       stack.Name,
				"platform.example.com/team":        stack.Spec.Team,
				"platform.example.com/environment": stack.Spec.Environment,
			},
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, ns, func() error {
		// Namespaces can't have owner references to namespaced resources
		return nil
	})
	return err
}

func (r *PlatformStackReconciler) reconcileConfigMap(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	cm := &corev1.ConfigMap{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name + "-config",
			Namespace: stack.Spec.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, cm, func() error {
		cm.Data = map[string]string{
			"ENVIRONMENT": stack.Spec.Environment,
			"TEAM":        stack.Spec.Team,
			"LOG_LEVEL":   stack.Spec.LogLevel,
		}
		return controllerutil.SetControllerReference(stack, cm, r.Scheme)
	})
	return err
}

func (r *PlatformStackReconciler) reconcileSecrets(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	// Reference external secrets or create placeholder
	secret := &corev1.Secret{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name + "-secrets",
			Namespace: stack.Spec.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, secret, func() error {
		if secret.Data == nil {
			secret.Data = make(map[string][]byte)
		}
		// In production, integrate with external secrets operator
		secret.Data["DATABASE_URL"] = []byte(fmt.Sprintf(
			"postgres://%s:%s@%s-db:5432/%s",
			stack.Spec.Database.User,
			"${DB_PASSWORD}",
			stack.Name,
			stack.Spec.Database.Name,
		))
		return controllerutil.SetControllerReference(stack, secret, r.Scheme)
	})
	return err
}

func (r *PlatformStackReconciler) reconcileDatabase(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	if !stack.Spec.Database.Enabled {
		return nil
	}

	// Create StatefulSet for database
	sts := &appsv1.StatefulSet{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name + "-db",
			Namespace: stack.Spec.Namespace,
		},
	}

	replicas := int32(1)
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, sts, func() error {
		sts.Spec = appsv1.StatefulSetSpec{
			Replicas:    &replicas,
			ServiceName: stack.Name + "-db",
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app":       stack.Name + "-db",
					"component": "database",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":       stack.Name + "-db",
						"component": "database",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "postgres",
							Image: "postgres:15",
							Ports: []corev1.ContainerPort{
								{ContainerPort: 5432},
							},
							EnvFrom: []corev1.EnvFromSource{
								{
									SecretRef: &corev1.SecretEnvSource{
										LocalObjectReference: corev1.LocalObjectReference{
											Name: stack.Name + "-secrets",
										},
									},
								},
							},
						},
					},
				},
			},
		}
		return controllerutil.SetControllerReference(stack, sts, r.Scheme)
	})
	return err
}

func (r *PlatformStackReconciler) reconcileCache(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	if !stack.Spec.Cache.Enabled {
		return nil
	}

	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name + "-cache",
			Namespace: stack.Spec.Namespace,
		},
	}

	replicas := int32(1)
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, deployment, func() error {
		deployment.Spec = appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app":       stack.Name + "-cache",
					"component": "cache",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":       stack.Name + "-cache",
						"component": "cache",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:  "redis",
							Image: "redis:7-alpine",
							Ports: []corev1.ContainerPort{
								{ContainerPort: 6379},
							},
						},
					},
				},
			},
		}
		return controllerutil.SetControllerReference(stack, deployment, r.Scheme)
	})
	return err
}

func (r *PlatformStackReconciler) reconcileApplication(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name + "-app",
			Namespace: stack.Spec.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, deployment, func() error {
		deployment.Spec = appsv1.DeploymentSpec{
			Replicas: &stack.Spec.Replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: map[string]string{
					"app":       stack.Name,
					"component": "application",
				},
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: map[string]string{
						"app":       stack.Name,
						"component": "application",
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:      "app",
							Image:     stack.Spec.Image,
							Resources: stack.GetResourceRequirements(),
							EnvFrom: []corev1.EnvFromSource{
								{
									ConfigMapRef: &corev1.ConfigMapEnvSource{
										LocalObjectReference: corev1.LocalObjectReference{
											Name: stack.Name + "-config",
										},
									},
								},
								{
									SecretRef: &corev1.SecretEnvSource{
										LocalObjectReference: corev1.LocalObjectReference{
											Name: stack.Name + "-secrets",
										},
									},
								},
							},
						},
					},
				},
			},
		}
		return controllerutil.SetControllerReference(stack, deployment, r.Scheme)
	})
	return err
}

func (r *PlatformStackReconciler) reconcileService(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name,
			Namespace: stack.Spec.Namespace,
		},
	}

	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, service, func() error {
		service.Spec = corev1.ServiceSpec{
			Selector: map[string]string{
				"app":       stack.Name,
				"component": "application",
			},
			Ports: []corev1.ServicePort{
				{
					Name: "http",
					Port: 80,
				},
			},
		}
		return controllerutil.SetControllerReference(stack, service, r.Scheme)
	})
	return err
}

func (r *PlatformStackReconciler) reconcileIngress(ctx context.Context, stack *platformv1alpha1.PlatformStack) error {
	if !stack.Spec.Ingress.Enabled {
		return nil
	}

	ingress := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:      stack.Name,
			Namespace: stack.Spec.Namespace,
		},
	}

	pathType := networkingv1.PathTypePrefix
	_, err := controllerutil.CreateOrUpdate(ctx, r.Client, ingress, func() error {
		ingress.Spec = networkingv1.IngressSpec{
			Rules: []networkingv1.IngressRule{
				{
					Host: stack.Spec.Ingress.Host,
					IngressRuleValue: networkingv1.IngressRuleValue{
						HTTP: &networkingv1.HTTPIngressRuleValue{
							Paths: []networkingv1.HTTPIngressPath{
								{
									Path:     "/",
									PathType: &pathType,
									Backend: networkingv1.IngressBackend{
										Service: &networkingv1.IngressServiceBackend{
											Name: stack.Name,
											Port: networkingv1.ServiceBackendPort{
												Number: 80,
											},
										},
									},
								},
							},
						},
					},
				},
			},
		}
		return controllerutil.SetControllerReference(stack, ingress, r.Scheme)
	})
	return err
}

// SetupWithManager configures watches for owned resources
func (r *PlatformStackReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.PlatformStack{}).
		Owns(&appsv1.Deployment{}).
		Owns(&appsv1.StatefulSet{}).
		Owns(&corev1.Service{}).
		Owns(&corev1.ConfigMap{}).
		Owns(&corev1.Secret{}).
		Owns(&networkingv1.Ingress{}).
		// Watch for changes to Secrets that reference this stack
		Watches(
			&corev1.Secret{},
			handler.EnqueueRequestsFromMapFunc(r.findStacksForSecret),
		).
		Complete(r)
}

// findStacksForSecret returns reconcile requests for stacks referencing a secret
func (r *PlatformStackReconciler) findStacksForSecret(ctx context.Context, obj client.Object) []reconcile.Request {
	secret := obj.(*corev1.Secret)
	
	// Check if this secret is referenced by any stack
	var stacks platformv1alpha1.PlatformStackList
	if err := r.List(ctx, &stacks); err != nil {
		return nil
	}

	var requests []reconcile.Request
	for _, stack := range stacks.Items {
		for _, ref := range stack.Spec.SecretRefs {
			if ref.Name == secret.Name && ref.Namespace == secret.Namespace {
				requests = append(requests, reconcile.Request{
					NamespacedName: types.NamespacedName{
						Name:      stack.Name,
						Namespace: stack.Namespace,
					},
				})
			}
		}
	}
	return requests
}
```

### Exercise 2: Rate Limiting and Backoff

Implement rate limiting for reconciliation:

```go
// internal/controller/ratelimited_controller.go
package controller

import (
	"context"
	"time"

	"golang.org/x/time/rate"
	"k8s.io/client-go/util/workqueue"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/ratelimiter"
)

// CustomRateLimiter implements a rate limiter with exponential backoff
func CustomRateLimiter() ratelimiter.RateLimiter {
	return workqueue.NewMaxOfRateLimiter(
		// Exponential backoff: 5ms -> 1000s max, doubling
		workqueue.NewItemExponentialFailureRateLimiter(5*time.Millisecond, 1000*time.Second),
		// Overall rate limit: 10 items/second with burst of 100
		&workqueue.BucketRateLimiter{Limiter: rate.NewLimiter(rate.Limit(10), 100)},
	)
}

// SetupWithManager with custom rate limiting
func (r *PlatformStackReconciler) SetupWithManagerRateLimited(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.PlatformStack{}).
		WithOptions(controller.Options{
			RateLimiter:             CustomRateLimiter(),
			MaxConcurrentReconciles: 5,
		}).
		Complete(r)
}

// Implement backoff in reconciliation
func (r *PlatformStackReconciler) ReconcileWithBackoff(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	// Track attempt count using annotations
	stack := &platformv1alpha1.PlatformStack{}
	if err := r.Get(ctx, req.NamespacedName, stack); err != nil {
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	attempts := getAttemptCount(stack)

	// Perform reconciliation
	err := r.doReconcile(ctx, stack)
	if err != nil {
		// Calculate backoff duration
		backoff := calculateBackoff(attempts)
		
		// Update attempt count
		setAttemptCount(stack, attempts+1)
		r.Update(ctx, stack)
		
		return ctrl.Result{RequeueAfter: backoff}, nil
	}

	// Reset attempts on success
	if attempts > 0 {
		setAttemptCount(stack, 0)
		r.Update(ctx, stack)
	}

	return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil
}

func calculateBackoff(attempts int) time.Duration {
	// Exponential backoff with jitter
	base := time.Second
	max := 5 * time.Minute
	
	backoff := base * time.Duration(1<<attempts)
	if backoff > max {
		backoff = max
	}
	
	// Add 10% jitter
	jitter := time.Duration(float64(backoff) * 0.1)
	return backoff + jitter
}

func getAttemptCount(stack *platformv1alpha1.PlatformStack) int {
	if stack.Annotations == nil {
		return 0
	}
	count, _ := strconv.Atoi(stack.Annotations["platform.example.com/attempts"])
	return count
}

func setAttemptCount(stack *platformv1alpha1.PlatformStack, count int) {
	if stack.Annotations == nil {
		stack.Annotations = make(map[string]string)
	}
	stack.Annotations["platform.example.com/attempts"] = strconv.Itoa(count)
}
```

---

## Part 3: Event-Driven Automation

### Understanding Argo Events

```
┌─────────────────────────────────────────────────────────────────┐
│                    ARGO EVENTS ARCHITECTURE                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │   Event     │───►│   Event     │───►│      Sensor         │  │
│  │   Source    │    │    Bus      │    │   (Trigger Logic)   │  │
│  └─────────────┘    └─────────────┘    └─────────────────────┘  │
│        │                                         │               │
│        │                                         ▼               │
│  ┌─────────────┐                       ┌─────────────────────┐  │
│  │  Webhook    │                       │      Trigger        │  │
│  │  GitHub     │                       │  - Kubernetes Job   │  │
│  │  S3         │                       │  - Argo Workflow    │  │
│  │  Kafka      │                       │  - HTTP Request     │  │
│  │  SNS/SQS    │                       │  - Slack/Email      │  │
│  └─────────────┘                       └─────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Exercise 3: Install Argo Events

Deploy Argo Events in your cluster:

```bash
# Create namespace
kubectl create namespace argo-events

# Install Argo Events
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml

# Install EventBus (NATS)
kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml

# Verify installation
kubectl get pods -n argo-events
```

Create EventBus:

```yaml
# eventbus.yaml
apiVersion: argoproj.io/v1alpha1
kind: EventBus
metadata:
  name: default
  namespace: argo-events
spec:
  nats:
    native:
      replicas: 3
      auth: token
```

Apply:

```bash
kubectl apply -f eventbus.yaml
kubectl get eventbus -n argo-events
```

### Exercise 4: GitHub Event Source

Create an event source for GitHub webhooks:

```yaml
# github-eventsource.yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: github
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  github:
    # Pull Request events
    pull-request:
      repositories:
        - owner: example-org
          names:
            - platform-repo
            - service-repo
      webhook:
        endpoint: /pull-request
        port: "12000"
        method: POST
        url: https://webhook.example.com
      events:
        - pull_request
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
      insecure: false
      active: true
      contentType: json

    # Push events
    push:
      repositories:
        - owner: example-org
          names:
            - platform-repo
      webhook:
        endpoint: /push
        port: "12000"
        method: POST
        url: https://webhook.example.com
      events:
        - push
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
      active: true
      contentType: json

    # Release events
    release:
      repositories:
        - owner: example-org
          names:
            - platform-repo
      webhook:
        endpoint: /release
        port: "12000"
        method: POST
        url: https://webhook.example.com
      events:
        - release
      apiToken:
        name: github-access
        key: token
      webhookSecret:
        name: github-access
        key: secret
      active: true
      contentType: json
```

Create the secret:

```bash
# Create GitHub access secret
kubectl create secret generic github-access -n argo-events \
  --from-literal=token=$GITHUB_TOKEN \
  --from-literal=secret=$WEBHOOK_SECRET

# Apply event source
kubectl apply -f github-eventsource.yaml

# Check status
kubectl get eventsource -n argo-events
```

### Exercise 5: Sensor for Platform Automation

Create a sensor that triggers actions based on events:

```yaml
# platform-sensor.yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: platform-automation
  namespace: argo-events
spec:
  template:
    serviceAccountName: argo-events-sa
  dependencies:
    - name: github-pr
      eventSourceName: github
      eventName: pull-request
      filters:
        data:
          - path: body.action
            type: string
            value:
              - opened
              - synchronize
        
    - name: github-push-main
      eventSourceName: github
      eventName: push
      filters:
        data:
          - path: body.ref
            type: string
            value:
              - refs/heads/main
              
    - name: github-release
      eventSourceName: github
      eventName: release
      filters:
        data:
          - path: body.action
            type: string
            value:
              - published

  triggers:
    # Trigger CI on PR
    - template:
        name: trigger-pr-ci
        conditions: github-pr
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: pr-ci-
              spec:
                entrypoint: ci-pipeline
                arguments:
                  parameters:
                    - name: pr-number
                    - name: repo
                    - name: sha
                templates:
                  - name: ci-pipeline
                    steps:
                      - - name: checkout
                          template: checkout
                      - - name: test
                          template: test
                      - - name: build
                          template: build
                  - name: checkout
                    container:
                      image: alpine/git
                      command: [git, clone]
                  - name: test
                    container:
                      image: golang:1.21
                      command: [go, test, ./...]
                  - name: build
                    container:
                      image: docker:dind
                      command: [docker, build, .]
          parameters:
            - src:
                dependencyName: github-pr
                dataKey: body.number
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: github-pr
                dataKey: body.repository.full_name
              dest: spec.arguments.parameters.1.value
            - src:
                dependencyName: github-pr
                dataKey: body.pull_request.head.sha
              dest: spec.arguments.parameters.2.value

    # Trigger deployment on main push
    - template:
        name: trigger-staging-deploy
        conditions: github-push-main
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: staging-deploy-
              spec:
                entrypoint: deploy
                arguments:
                  parameters:
                    - name: sha
                    - name: repo
                templates:
                  - name: deploy
                    steps:
                      - - name: update-image
                          template: update-manifests
                      - - name: sync-argocd
                          template: argocd-sync
                  - name: update-manifests
                    container:
                      image: bitnami/git
                      command: [sh, -c]
                      args:
                        - |
                          git clone https://github.com/example/gitops-repo
                          cd gitops-repo
                          kustomize edit set image app={{workflow.parameters.sha}}
                          git commit -am "Update staging to {{workflow.parameters.sha}}"
                          git push
                  - name: argocd-sync
                    container:
                      image: argoproj/argocd
                      command: [argocd]
                      args:
                        - app
                        - sync
                        - staging-app
          parameters:
            - src:
                dependencyName: github-push-main
                dataKey: body.after
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: github-push-main
                dataKey: body.repository.full_name
              dest: spec.arguments.parameters.1.value

    # Trigger production deployment on release
    - template:
        name: trigger-prod-deploy
        conditions: github-release
        k8s:
          operation: create
          source:
            resource:
              apiVersion: argoproj.io/v1alpha1
              kind: Workflow
              metadata:
                generateName: prod-deploy-
              spec:
                entrypoint: production-deploy
                arguments:
                  parameters:
                    - name: version
                    - name: repo
                templates:
                  - name: production-deploy
                    steps:
                      - - name: approval
                          template: manual-approval
                      - - name: deploy
                          template: deploy-production
                      - - name: notify
                          template: send-notification
                  - name: manual-approval
                    suspend: {}
                  - name: deploy-production
                    container:
                      image: bitnami/kubectl
                      command: [kubectl]
                      args:
                        - apply
                        - -f
                        - production/
                  - name: send-notification
                    container:
                      image: curlimages/curl
                      command: [curl]
                      args:
                        - -X
                        - POST
                        - https://slack.com/webhook
                        - -d
                        - '{"text": "Deployed {{workflow.parameters.version}}"}'
          parameters:
            - src:
                dependencyName: github-release
                dataKey: body.release.tag_name
              dest: spec.arguments.parameters.0.value
            - src:
                dependencyName: github-release
                dataKey: body.repository.full_name
              dest: spec.arguments.parameters.1.value

    # Send Slack notification
    - template:
        name: slack-notification
        conditions: github-pr || github-push-main
        http:
          url: https://hooks.slack.com/services/xxx/yyy/zzz
          payload:
            - src:
                dependencyName: github-pr
                dataKey: body.pull_request.title
              dest: text
          method: POST
```

Apply:

```bash
kubectl apply -f platform-sensor.yaml
kubectl get sensor -n argo-events
```

### Exercise 6: Kubernetes Resource Event Source

Monitor Kubernetes resources and trigger automation:

```yaml
# k8s-resource-eventsource.yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: kubernetes
  namespace: argo-events
spec:
  resource:
    # Watch for new namespaces
    namespace-created:
      namespace: ""
      group: ""
      version: v1
      resource: namespaces
      eventTypes:
        - ADD
      filter:
        labels:
          - key: platform.example.com/managed
            operation: "=="
            value: "true"

    # Watch for pod failures
    pod-failed:
      namespace: ""
      group: ""
      version: v1
      resource: pods
      eventTypes:
        - UPDATE
      filter:
        fields:
          - key: status.phase
            operation: "=="
            value: Failed

    # Watch for PVC creation
    pvc-created:
      namespace: ""
      group: ""
      version: v1
      resource: persistentvolumeclaims
      eventTypes:
        - ADD

    # Watch for DevEnvironment creation
    devenv-created:
      namespace: ""
      group: platform.platform.example.com
      version: v1alpha1
      resource: devenvironments
      eventTypes:
        - ADD
        - UPDATE
```

Create sensor for Kubernetes events:

```yaml
# k8s-sensor.yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: kubernetes-automation
  namespace: argo-events
spec:
  template:
    serviceAccountName: argo-events-sa
  dependencies:
    - name: namespace-created
      eventSourceName: kubernetes
      eventName: namespace-created
      
    - name: pod-failed
      eventSourceName: kubernetes
      eventName: pod-failed
      
    - name: devenv-created
      eventSourceName: kubernetes
      eventName: devenv-created

  triggers:
    # Setup new namespace with default resources
    - template:
        name: setup-namespace
        conditions: namespace-created
        k8s:
          operation: create
          source:
            resource:
              apiVersion: v1
              kind: ConfigMap
              metadata:
                name: platform-defaults
              data:
                team: ""
                environment: ""
          parameters:
            - src:
                dependencyName: namespace-created
                dataKey: body.metadata.name
              dest: metadata.namespace
            - src:
                dependencyName: namespace-created
                dataKey: body.metadata.labels.team
              dest: data.team

    # Create ResourceQuota for new namespace
    - template:
        name: create-quota
        conditions: namespace-created
        k8s:
          operation: create
          source:
            resource:
              apiVersion: v1
              kind: ResourceQuota
              metadata:
                name: default-quota
              spec:
                hard:
                  requests.cpu: "10"
                  requests.memory: 20Gi
                  limits.cpu: "20"
                  limits.memory: 40Gi
                  persistentvolumeclaims: "10"
          parameters:
            - src:
                dependencyName: namespace-created
                dataKey: body.metadata.name
              dest: metadata.namespace

    # Create NetworkPolicy for namespace isolation
    - template:
        name: create-network-policy
        conditions: namespace-created
        k8s:
          operation: create
          source:
            resource:
              apiVersion: networking.k8s.io/v1
              kind: NetworkPolicy
              metadata:
                name: default-deny-ingress
              spec:
                podSelector: {}
                policyTypes:
                  - Ingress
          parameters:
            - src:
                dependencyName: namespace-created
                dataKey: body.metadata.name
              dest: metadata.namespace

    # Alert on pod failure
    - template:
        name: pod-failure-alert
        conditions: pod-failed
        http:
          url: https://hooks.slack.com/services/xxx/yyy/zzz
          method: POST
          payload:
            - src:
                dependencyName: pod-failed
                dataTemplate: |
                  {
                    "text": ":warning: Pod Failed",
                    "attachments": [{
                      "color": "danger",
                      "fields": [
                        {"title": "Pod", "value": "{{ .Input.body.metadata.name }}", "short": true},
                        {"title": "Namespace", "value": "{{ .Input.body.metadata.namespace }}", "short": true},
                        {"title": "Reason", "value": "{{ .Input.body.status.reason }}", "short": false}
                      ]
                    }]
                  }
              dest: body

    # Welcome notification for DevEnvironment
    - template:
        name: devenv-welcome
        conditions: devenv-created
        http:
          url: https://api.example.com/notifications
          method: POST
          payload:
            - src:
                dependencyName: devenv-created
                dataTemplate: |
                  {
                    "type": "devenv_created",
                    "developer": "{{ .Input.body.spec.developer }}",
                    "team": "{{ .Input.body.spec.team }}",
                    "environment": "{{ .Input.body.metadata.name }}",
                    "endpoint": "{{ .Input.body.status.endpoint }}"
                  }
              dest: body
```

Apply:

```bash
kubectl apply -f k8s-resource-eventsource.yaml
kubectl apply -f k8s-sensor.yaml
```

### Exercise 7: Webhook Event Source

Create a generic webhook for external integrations:

```yaml
# webhook-eventsource.yaml
apiVersion: argoproj.io/v1alpha1
kind: EventSource
metadata:
  name: webhook
  namespace: argo-events
spec:
  service:
    ports:
      - port: 12000
        targetPort: 12000
  webhook:
    # Platform API endpoint
    platform-request:
      port: "12000"
      endpoint: /platform/request
      method: POST

    # Environment provisioning
    provision-env:
      port: "12000"
      endpoint: /provision/environment
      method: POST

    # Cleanup request
    cleanup:
      port: "12000"
      endpoint: /cleanup
      method: POST

    # Scale request
    scale:
      port: "12000"
      endpoint: /scale
      method: POST
---
# Expose webhook externally
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argo-events-webhook
  namespace: argo-events
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
    - hosts:
        - events.platform.example.com
      secretName: events-tls
  rules:
    - host: events.platform.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: github-eventsource-svc
                port:
                  number: 12000
```

Sensor for webhook events:

```yaml
# webhook-sensor.yaml
apiVersion: argoproj.io/v1alpha1
kind: Sensor
metadata:
  name: webhook-automation
  namespace: argo-events
spec:
  template:
    serviceAccountName: argo-events-sa
  dependencies:
    - name: provision-request
      eventSourceName: webhook
      eventName: provision-env
      
    - name: cleanup-request
      eventSourceName: webhook
      eventName: cleanup
      
    - name: scale-request
      eventSourceName: webhook
      eventName: scale

  triggers:
    # Create DevEnvironment from webhook
    - template:
        name: create-devenv
        conditions: provision-request
        k8s:
          operation: create
          source:
            resource:
              apiVersion: platform.platform.example.com/v1alpha1
              kind: DevEnvironment
              metadata:
                name: ""
              spec:
                developer: ""
                team: ""
                template: web-service
                size: small
                ttl: "8h"
          parameters:
            - src:
                dependencyName: provision-request
                dataKey: body.name
              dest: metadata.name
            - src:
                dependencyName: provision-request
                dataKey: body.namespace
              dest: metadata.namespace
            - src:
                dependencyName: provision-request
                dataKey: body.developer
              dest: spec.developer
            - src:
                dependencyName: provision-request
                dataKey: body.team
              dest: spec.team
            - src:
                dependencyName: provision-request
                dataKey: body.template
              dest: spec.template
            - src:
                dependencyName: provision-request
                dataKey: body.size
              dest: spec.size

    # Delete resources on cleanup
    - template:
        name: cleanup-devenv
        conditions: cleanup-request
        k8s:
          operation: delete
          source:
            resource:
              apiVersion: platform.platform.example.com/v1alpha1
              kind: DevEnvironment
              metadata:
                name: ""
                namespace: ""
          parameters:
            - src:
                dependencyName: cleanup-request
                dataKey: body.name
              dest: metadata.name
            - src:
                dependencyName: cleanup-request
                dataKey: body.namespace
              dest: metadata.namespace

    # Scale deployment
    - template:
        name: scale-deployment
        conditions: scale-request
        k8s:
          operation: patch
          patchStrategy: merge
          source:
            resource:
              apiVersion: apps/v1
              kind: Deployment
              metadata:
                name: ""
                namespace: ""
              spec:
                replicas: 1
          parameters:
            - src:
                dependencyName: scale-request
                dataKey: body.deployment
              dest: metadata.name
            - src:
                dependencyName: scale-request
                dataKey: body.namespace
              dest: metadata.namespace
            - src:
                dependencyName: scale-request
                dataKey: body.replicas
              dest: spec.replicas
```

Test webhook:

```bash
# Trigger environment provisioning
curl -X POST https://events.platform.example.com/provision/environment \
  -H "Content-Type: application/json" \
  -d '{
    "name": "alice-dev",
    "namespace": "default",
    "developer": "alice",
    "team": "backend",
    "template": "backend-api",
    "size": "medium"
  }'

# Check DevEnvironment was created
kubectl get devenvironment alice-dev
```

---

## Summary: Part 2

In this part of Lab 4, you learned:

1. **Advanced Controller Patterns**
   - Multi-resource reconciliation
   - Rate limiting and backoff strategies
   - Watching related resources

2. **Event-Driven Automation with Argo Events**
   - EventSource configuration (GitHub, Kubernetes, Webhook)
   - Sensor triggers and conditions
   - Event filtering and transformation

3. **Automation Workflows**
   - CI/CD triggers from GitHub events
   - Kubernetes resource automation
   - Self-service via webhooks

4. **Integration Patterns**
   - Connecting external systems
   - Notification workflows
   - Resource provisioning

---

**Next: Part 3 will cover Platform APIs and CLI Tools for Developers.**

Continue to [Part 3: Platform APIs and Developer CLI](./README-part3.md)
