# Lab 4: Platform Automation

## Overview

Platform automation is essential for scaling internal developer platforms. This lab covers building Kubernetes operators, custom controllers, and automation tools that reduce manual toil while providing self-service capabilities to development teams.

## Learning Objectives

By the end of this lab, you will be able to:

- Build Kubernetes operators using Kubebuilder
- Implement custom controllers with reconciliation logic
- Create event-driven automation pipelines
- Design platform APIs for self-service
- Build CLI tools for developer productivity

## Prerequisites

- Completed Labs 1-3 (Backstage, Crossplane, Golden Paths)
- Go programming basics
- Understanding of Kubernetes controllers
- kubectl configured for your cluster

## Part 1: Kubernetes Operators for Platforms

### Understanding Operators

Operators extend Kubernetes to manage complex applications using custom resources:

```
┌─────────────────────────────────────────────────────────────────┐
│                    OPERATOR PATTERN                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    watches     ┌─────────────────────────┐     │
│  │   Custom    │ ◄───────────── │      Controller         │     │
│  │  Resource   │                │   (Reconcile Loop)      │     │
│  └─────────────┘                └─────────────────────────┘     │
│        │                                   │                     │
│        │ defines                           │ manages             │
│        ▼                                   ▼                     │
│  ┌─────────────┐                ┌─────────────────────────┐     │
│  │   Desired   │                │    Actual Resources     │     │
│  │   State     │                │  (Pods, Services, etc)  │     │
│  └─────────────┘                └─────────────────────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Exercise 1: Setting Up Kubebuilder

Install Kubebuilder for operator development:

```bash
# Download kubebuilder
curl -L -o kubebuilder https://go.kubebuilder.io/dl/latest/$(go env GOOS)/$(go env GOARCH)

# Make executable and move to PATH
chmod +x kubebuilder
sudo mv kubebuilder /usr/local/bin/

# Verify installation
kubebuilder version
```

### Exercise 2: Initialize Operator Project

Create a new operator for managing developer environments:

```bash
# Create project directory
mkdir -p ~/platform-operator
cd ~/platform-operator

# Initialize the project
kubebuilder init \
  --domain platform.example.com \
  --repo github.com/example/platform-operator

# Project structure created
tree -L 2
```

Expected structure:

```
platform-operator/
├── Dockerfile
├── Makefile
├── PROJECT
├── README.md
├── cmd/
│   └── main.go
├── config/
│   ├── default/
│   ├── manager/
│   ├── prometheus/
│   └── rbac/
├── go.mod
├── go.sum
├── hack/
│   └── boilerplate.go.txt
└── internal/
    └── controller/
```

### Exercise 3: Create Custom Resource Definition

Create a DevEnvironment CRD for managing developer environments:

```bash
# Create API (CRD + Controller)
kubebuilder create api \
  --group platform \
  --version v1alpha1 \
  --kind DevEnvironment \
  --resource \
  --controller
```

Edit the types file `api/v1alpha1/devenvironment_types.go`:

```go
/*
Copyright 2024.

Licensed under the Apache License, Version 2.0 (the "License");
...
*/

package v1alpha1

import (
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// DevEnvironmentSpec defines the desired state of DevEnvironment
type DevEnvironmentSpec struct {
	// Developer is the owner of this environment
	// +kubebuilder:validation:Required
	Developer string `json:"developer"`

	// Team that the developer belongs to
	// +kubebuilder:validation:Required
	Team string `json:"team"`

	// Template specifies which golden path template to use
	// +kubebuilder:validation:Enum=web-service;backend-api;data-pipeline;ml-workbench
	// +kubebuilder:default=web-service
	Template string `json:"template,omitempty"`

	// Size defines resource allocation
	// +kubebuilder:validation:Enum=small;medium;large
	// +kubebuilder:default=small
	Size string `json:"size,omitempty"`

	// TTL defines time-to-live for the environment (e.g., "24h", "7d")
	// +kubebuilder:validation:Pattern=`^[0-9]+[hdw]$`
	// +optional
	TTL string `json:"ttl,omitempty"`

	// AutoSleep enables automatic sleep during off-hours
	// +kubebuilder:default=true
	AutoSleep bool `json:"autoSleep,omitempty"`

	// GitRepository to clone into the environment
	// +optional
	GitRepository string `json:"gitRepository,omitempty"`

	// ExtraTools lists additional tools to install
	// +optional
	ExtraTools []string `json:"extraTools,omitempty"`
}

// ResourceAllocation defines compute resources for sizes
type ResourceAllocation struct {
	CPU    resource.Quantity `json:"cpu"`
	Memory resource.Quantity `json:"memory"`
}

// DevEnvironmentStatus defines the observed state of DevEnvironment
type DevEnvironmentStatus struct {
	// Phase represents the current lifecycle phase
	// +kubebuilder:validation:Enum=Pending;Provisioning;Running;Sleeping;Terminating;Failed
	Phase string `json:"phase,omitempty"`

	// Conditions represent the latest available observations
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// Endpoint is the URL to access the environment
	Endpoint string `json:"endpoint,omitempty"`

	// ExpiresAt is when the environment will be cleaned up
	ExpiresAt *metav1.Time `json:"expiresAt,omitempty"`

	// LastActiveAt is the last time the environment was accessed
	LastActiveAt *metav1.Time `json:"lastActiveAt,omitempty"`

	// Resources created by this DevEnvironment
	Resources []ResourceReference `json:"resources,omitempty"`

	// Message provides human-readable status information
	Message string `json:"message,omitempty"`
}

// ResourceReference identifies a resource managed by this DevEnvironment
type ResourceReference struct {
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	Namespace string `json:"namespace,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:printcolumn:name="Developer",type=string,JSONPath=`.spec.developer`
// +kubebuilder:printcolumn:name="Team",type=string,JSONPath=`.spec.team`
// +kubebuilder:printcolumn:name="Template",type=string,JSONPath=`.spec.template`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Endpoint",type=string,JSONPath=`.status.endpoint`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// DevEnvironment is the Schema for the devenvironments API
type DevEnvironment struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   DevEnvironmentSpec   `json:"spec,omitempty"`
	Status DevEnvironmentStatus `json:"status,omitempty"`
}

// +kubebuilder:object:root=true

// DevEnvironmentList contains a list of DevEnvironment
type DevEnvironmentList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []DevEnvironment `json:"items"`
}

func init() {
	SchemeBuilder.Register(&DevEnvironment{}, &DevEnvironmentList{})
}

// Helper functions for size-based resource allocation
func (d *DevEnvironment) GetResourceAllocation() corev1.ResourceRequirements {
	sizes := map[string]corev1.ResourceRequirements{
		"small": {
			Requests: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("500m"),
				corev1.ResourceMemory: resource.MustParse("1Gi"),
			},
			Limits: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("1"),
				corev1.ResourceMemory: resource.MustParse("2Gi"),
			},
		},
		"medium": {
			Requests: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("1"),
				corev1.ResourceMemory: resource.MustParse("2Gi"),
			},
			Limits: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("2"),
				corev1.ResourceMemory: resource.MustParse("4Gi"),
			},
		},
		"large": {
			Requests: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("2"),
				corev1.ResourceMemory: resource.MustParse("4Gi"),
			},
			Limits: corev1.ResourceList{
				corev1.ResourceCPU:    resource.MustParse("4"),
				corev1.ResourceMemory: resource.MustParse("8Gi"),
			},
		},
	}

	if alloc, ok := sizes[d.Spec.Size]; ok {
		return alloc
	}
	return sizes["small"]
}
```

### Exercise 4: Generate CRD Manifests

Generate the CRD and RBAC manifests:

```bash
# Generate CRD manifests
make manifests

# View generated CRD
cat config/crd/bases/platform.platform.example.com_devenvironments.yaml
```

Expected CRD output:

```yaml
---
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  annotations:
    controller-gen.kubebuilder.io/version: v0.14.0
  name: devenvironments.platform.platform.example.com
spec:
  group: platform.platform.example.com
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
    - additionalPrinterColumns:
        - jsonPath: .spec.developer
          name: Developer
          type: string
        - jsonPath: .spec.team
          name: Team
          type: string
        - jsonPath: .spec.template
          name: Template
          type: string
        - jsonPath: .status.phase
          name: Phase
          type: string
        - jsonPath: .status.endpoint
          name: Endpoint
          type: string
        - jsonPath: .metadata.creationTimestamp
          name: Age
          type: date
      name: v1alpha1
      schema:
        openAPIV3Schema:
          description: DevEnvironment is the Schema for the devenvironments API
          properties:
            apiVersion:
              type: string
            kind:
              type: string
            metadata:
              type: object
            spec:
              description: DevEnvironmentSpec defines the desired state
              properties:
                developer:
                  type: string
                team:
                  type: string
                template:
                  default: web-service
                  enum:
                    - web-service
                    - backend-api
                    - data-pipeline
                    - ml-workbench
                  type: string
                size:
                  default: small
                  enum:
                    - small
                    - medium
                    - large
                  type: string
                ttl:
                  pattern: ^[0-9]+[hdw]$
                  type: string
                autoSleep:
                  default: true
                  type: boolean
                gitRepository:
                  type: string
                extraTools:
                  items:
                    type: string
                  type: array
              required:
                - developer
                - team
              type: object
            status:
              description: DevEnvironmentStatus defines the observed state
              properties:
                phase:
                  enum:
                    - Pending
                    - Provisioning
                    - Running
                    - Sleeping
                    - Terminating
                    - Failed
                  type: string
                conditions:
                  items:
                    type: object
                    # ... condition properties
                  type: array
                endpoint:
                  type: string
                expiresAt:
                  format: date-time
                  type: string
                lastActiveAt:
                  format: date-time
                  type: string
                resources:
                  items:
                    properties:
                      kind:
                        type: string
                      name:
                        type: string
                      namespace:
                        type: string
                    required:
                      - kind
                      - name
                    type: object
                  type: array
                message:
                  type: string
              type: object
          type: object
      served: true
      storage: true
      subresources:
        status: {}
```

### Exercise 5: Implement the Controller

Edit `internal/controller/devenvironment_controller.go`:

```go
/*
Copyright 2024.
*/

package controller

import (
	"context"
	"fmt"
	"time"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	networkingv1 "k8s.io/api/networking/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/meta"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/types"
	"k8s.io/apimachinery/pkg/util/intstr"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
	"sigs.k8s.io/controller-runtime/pkg/log"

	platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

const (
	devEnvFinalizer = "platform.example.com/finalizer"
)

// DevEnvironmentReconciler reconciles a DevEnvironment object
type DevEnvironmentReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=platform.platform.example.com,resources=devenvironments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=platform.platform.example.com,resources=devenvironments/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=platform.platform.example.com,resources=devenvironments/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=services,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=core,resources=configmaps,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=networking.k8s.io,resources=ingresses,verbs=get;list;watch;create;update;patch;delete

// Reconcile is the main reconciliation loop
func (r *DevEnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Reconciling DevEnvironment", "name", req.Name, "namespace", req.Namespace)

	// Fetch the DevEnvironment instance
	devEnv := &platformv1alpha1.DevEnvironment{}
	if err := r.Get(ctx, req.NamespacedName, devEnv); err != nil {
		if errors.IsNotFound(err) {
			logger.Info("DevEnvironment not found, ignoring")
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
		return ctrl.Result{Requeue: true}, nil
	}

	// Update status to Provisioning if Pending
	if devEnv.Status.Phase == "" || devEnv.Status.Phase == "Pending" {
		return r.setPhase(ctx, devEnv, "Provisioning", "Starting environment provisioning")
	}

	// Create or update resources
	if err := r.reconcileDeployment(ctx, devEnv); err != nil {
		return r.setPhase(ctx, devEnv, "Failed", fmt.Sprintf("Failed to reconcile deployment: %v", err))
	}

	if err := r.reconcileService(ctx, devEnv); err != nil {
		return r.setPhase(ctx, devEnv, "Failed", fmt.Sprintf("Failed to reconcile service: %v", err))
	}

	if err := r.reconcileIngress(ctx, devEnv); err != nil {
		return r.setPhase(ctx, devEnv, "Failed", fmt.Sprintf("Failed to reconcile ingress: %v", err))
	}

	// Check deployment status
	deployment := &appsv1.Deployment{}
	deploymentName := types.NamespacedName{
		Name:      devEnv.Name + "-env",
		Namespace: devEnv.Namespace,
	}
	if err := r.Get(ctx, deploymentName, deployment); err != nil {
		return ctrl.Result{RequeueAfter: 10 * time.Second}, nil
	}

	// Update status based on deployment
	if deployment.Status.ReadyReplicas > 0 {
		endpoint := fmt.Sprintf("https://%s.dev.example.com", devEnv.Name)
		devEnv.Status.Endpoint = endpoint
		return r.setPhase(ctx, devEnv, "Running", "Environment is ready")
	}

	// Check TTL expiration
	if devEnv.Spec.TTL != "" && devEnv.Status.ExpiresAt != nil {
		if time.Now().After(devEnv.Status.ExpiresAt.Time) {
			logger.Info("DevEnvironment TTL expired, deleting", "name", devEnv.Name)
			if err := r.Delete(ctx, devEnv); err != nil {
				return ctrl.Result{}, err
			}
			return ctrl.Result{}, nil
		}
	}

	return ctrl.Result{RequeueAfter: 30 * time.Second}, nil
}

// handleDeletion performs cleanup when DevEnvironment is deleted
func (r *DevEnvironmentReconciler) handleDeletion(ctx context.Context, devEnv *platformv1alpha1.DevEnvironment) (ctrl.Result, error) {
	logger := log.FromContext(ctx)
	logger.Info("Handling deletion", "name", devEnv.Name)

	// Update phase to Terminating
	if devEnv.Status.Phase != "Terminating" {
		devEnv.Status.Phase = "Terminating"
		devEnv.Status.Message = "Cleaning up resources"
		if err := r.Status().Update(ctx, devEnv); err != nil {
			return ctrl.Result{}, err
		}
	}

	// Resources are cleaned up via OwnerReferences (garbage collection)
	// Add any additional cleanup logic here

	// Remove finalizer
	controllerutil.RemoveFinalizer(devEnv, devEnvFinalizer)
	if err := r.Update(ctx, devEnv); err != nil {
		return ctrl.Result{}, err
	}

	logger.Info("Successfully deleted DevEnvironment", "name", devEnv.Name)
	return ctrl.Result{}, nil
}

// setPhase updates the status phase and message
func (r *DevEnvironmentReconciler) setPhase(ctx context.Context, devEnv *platformv1alpha1.DevEnvironment, phase, message string) (ctrl.Result, error) {
	devEnv.Status.Phase = phase
	devEnv.Status.Message = message

	// Set condition
	condition := metav1.Condition{
		Type:               "Ready",
		Status:             metav1.ConditionFalse,
		Reason:             phase,
		Message:            message,
		LastTransitionTime: metav1.Now(),
	}
	if phase == "Running" {
		condition.Status = metav1.ConditionTrue
	}
	meta.SetStatusCondition(&devEnv.Status.Conditions, condition)

	if err := r.Status().Update(ctx, devEnv); err != nil {
		return ctrl.Result{}, err
	}

	if phase == "Failed" {
		return ctrl.Result{RequeueAfter: 1 * time.Minute}, nil
	}
	return ctrl.Result{RequeueAfter: 10 * time.Second}, nil
}

// reconcileDeployment creates or updates the deployment
func (r *DevEnvironmentReconciler) reconcileDeployment(ctx context.Context, devEnv *platformv1alpha1.DevEnvironment) error {
	logger := log.FromContext(ctx)

	deployment := &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      devEnv.Name + "-env",
			Namespace: devEnv.Namespace,
		},
	}

	// CreateOrUpdate pattern
	op, err := controllerutil.CreateOrUpdate(ctx, r.Client, deployment, func() error {
		// Set labels
		labels := map[string]string{
			"app.kubernetes.io/name":       devEnv.Name,
			"app.kubernetes.io/component":  "dev-environment",
			"app.kubernetes.io/managed-by": "platform-operator",
			"platform.example.com/team":    devEnv.Spec.Team,
		}
		deployment.Labels = labels

		// Get image based on template
		image := r.getImageForTemplate(devEnv.Spec.Template)

		// Build container
		replicas := int32(1)
		deployment.Spec = appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{
				MatchLabels: labels,
			},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{
					Labels: labels,
					Annotations: map[string]string{
						"platform.example.com/developer": devEnv.Spec.Developer,
					},
				},
				Spec: corev1.PodSpec{
					Containers: []corev1.Container{
						{
							Name:      "dev-env",
							Image:     image,
							Resources: devEnv.GetResourceAllocation(),
							Ports: []corev1.ContainerPort{
								{
									Name:          "http",
									ContainerPort: 8080,
								},
								{
									Name:          "ide",
									ContainerPort: 8443,
								},
							},
							Env: []corev1.EnvVar{
								{
									Name:  "DEVELOPER",
									Value: devEnv.Spec.Developer,
								},
								{
									Name:  "TEAM",
									Value: devEnv.Spec.Team,
								},
								{
									Name:  "GIT_REPOSITORY",
									Value: devEnv.Spec.GitRepository,
								},
							},
							ReadinessProbe: &corev1.Probe{
								ProbeHandler: corev1.ProbeHandler{
									HTTPGet: &corev1.HTTPGetAction{
										Path: "/healthz",
										Port: intstr.FromInt(8080),
									},
								},
								InitialDelaySeconds: 10,
								PeriodSeconds:       5,
							},
						},
					},
				},
			},
		}

		// Set owner reference for garbage collection
		return controllerutil.SetControllerReference(devEnv, deployment, r.Scheme)
	})

	if err != nil {
		return err
	}

	logger.Info("Deployment reconciled", "name", deployment.Name, "operation", op)

	// Track resource
	r.addResourceReference(devEnv, "Deployment", deployment.Name, deployment.Namespace)
	return nil
}

// reconcileService creates or updates the service
func (r *DevEnvironmentReconciler) reconcileService(ctx context.Context, devEnv *platformv1alpha1.DevEnvironment) error {
	logger := log.FromContext(ctx)

	service := &corev1.Service{
		ObjectMeta: metav1.ObjectMeta{
			Name:      devEnv.Name + "-env",
			Namespace: devEnv.Namespace,
		},
	}

	op, err := controllerutil.CreateOrUpdate(ctx, r.Client, service, func() error {
		labels := map[string]string{
			"app.kubernetes.io/name":       devEnv.Name,
			"app.kubernetes.io/component":  "dev-environment",
			"app.kubernetes.io/managed-by": "platform-operator",
		}
		service.Labels = labels

		service.Spec = corev1.ServiceSpec{
			Selector: labels,
			Ports: []corev1.ServicePort{
				{
					Name:       "http",
					Port:       80,
					TargetPort: intstr.FromInt(8080),
				},
				{
					Name:       "ide",
					Port:       443,
					TargetPort: intstr.FromInt(8443),
				},
			},
		}

		return controllerutil.SetControllerReference(devEnv, service, r.Scheme)
	})

	if err != nil {
		return err
	}

	logger.Info("Service reconciled", "name", service.Name, "operation", op)
	r.addResourceReference(devEnv, "Service", service.Name, service.Namespace)
	return nil
}

// reconcileIngress creates or updates the ingress
func (r *DevEnvironmentReconciler) reconcileIngress(ctx context.Context, devEnv *platformv1alpha1.DevEnvironment) error {
	logger := log.FromContext(ctx)

	ingress := &networkingv1.Ingress{
		ObjectMeta: metav1.ObjectMeta{
			Name:      devEnv.Name + "-env",
			Namespace: devEnv.Namespace,
		},
	}

	pathType := networkingv1.PathTypePrefix

	op, err := controllerutil.CreateOrUpdate(ctx, r.Client, ingress, func() error {
		ingress.Annotations = map[string]string{
			"kubernetes.io/ingress.class":                "nginx",
			"cert-manager.io/cluster-issuer":             "letsencrypt-prod",
			"nginx.ingress.kubernetes.io/proxy-body-size": "100m",
		}

		ingress.Spec = networkingv1.IngressSpec{
			TLS: []networkingv1.IngressTLS{
				{
					Hosts:      []string{fmt.Sprintf("%s.dev.example.com", devEnv.Name)},
					SecretName: fmt.Sprintf("%s-tls", devEnv.Name),
				},
			},
			Rules: []networkingv1.IngressRule{
				{
					Host: fmt.Sprintf("%s.dev.example.com", devEnv.Name),
					IngressRuleValue: networkingv1.IngressRuleValue{
						HTTP: &networkingv1.HTTPIngressRuleValue{
							Paths: []networkingv1.HTTPIngressPath{
								{
									Path:     "/",
									PathType: &pathType,
									Backend: networkingv1.IngressBackend{
										Service: &networkingv1.IngressServiceBackend{
											Name: devEnv.Name + "-env",
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

		return controllerutil.SetControllerReference(devEnv, ingress, r.Scheme)
	})

	if err != nil {
		return err
	}

	logger.Info("Ingress reconciled", "name", ingress.Name, "operation", op)
	r.addResourceReference(devEnv, "Ingress", ingress.Name, ingress.Namespace)
	return nil
}

// getImageForTemplate returns the container image for a template type
func (r *DevEnvironmentReconciler) getImageForTemplate(template string) string {
	images := map[string]string{
		"web-service":   "ghcr.io/example/dev-env-web:latest",
		"backend-api":   "ghcr.io/example/dev-env-api:latest",
		"data-pipeline": "ghcr.io/example/dev-env-data:latest",
		"ml-workbench":  "ghcr.io/example/dev-env-ml:latest",
	}

	if img, ok := images[template]; ok {
		return img
	}
	return images["web-service"]
}

// addResourceReference adds a managed resource to status
func (r *DevEnvironmentReconciler) addResourceReference(devEnv *platformv1alpha1.DevEnvironment, kind, name, namespace string) {
	ref := platformv1alpha1.ResourceReference{
		Kind:      kind,
		Name:      name,
		Namespace: namespace,
	}

	// Check if already exists
	for _, existing := range devEnv.Status.Resources {
		if existing.Kind == kind && existing.Name == name {
			return
		}
	}

	devEnv.Status.Resources = append(devEnv.Status.Resources, ref)
}

// SetupWithManager sets up the controller with the Manager
func (r *DevEnvironmentReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&platformv1alpha1.DevEnvironment{}).
		Owns(&appsv1.Deployment{}).
		Owns(&corev1.Service{}).
		Owns(&networkingv1.Ingress{}).
		Complete(r)
}
```

### Exercise 6: Build and Deploy the Operator

Build and deploy the operator:

```bash
# Build the operator image
make docker-build IMG=platform-operator:v0.1.0

# Load into kind cluster (for local development)
kind load docker-image platform-operator:v0.1.0 --name platform-lab

# Install CRDs
make install

# Deploy operator
make deploy IMG=platform-operator:v0.1.0

# Verify deployment
kubectl get pods -n platform-operator-system
```

### Exercise 7: Test the Operator

Create a DevEnvironment resource:

```yaml
# devenv-sample.yaml
apiVersion: platform.platform.example.com/v1alpha1
kind: DevEnvironment
metadata:
  name: john-dev
  namespace: default
spec:
  developer: john.doe
  team: backend
  template: backend-api
  size: medium
  ttl: "24h"
  autoSleep: true
  gitRepository: https://github.com/example/my-service.git
  extraTools:
    - docker
    - kubectl
    - helm
```

Apply and observe:

```bash
# Create the DevEnvironment
kubectl apply -f devenv-sample.yaml

# Watch the operator logs
kubectl logs -f -n platform-operator-system deployment/platform-operator-controller-manager

# Check DevEnvironment status
kubectl get devenvironment
kubectl describe devenvironment john-dev

# See created resources
kubectl get deployment,service,ingress -l app.kubernetes.io/name=john-dev
```

Expected output:

```
NAME       DEVELOPER   TEAM      TEMPLATE      PHASE     ENDPOINT                         AGE
john-dev   john.doe    backend   backend-api   Running   https://john-dev.dev.example.com  2m
```

### Exercise 8: Implement Webhooks

Add validation webhook for DevEnvironment:

```bash
# Create webhook
kubebuilder create webhook \
  --group platform \
  --version v1alpha1 \
  --kind DevEnvironment \
  --defaulting \
  --programmatic-validation
```

Edit `api/v1alpha1/devenvironment_webhook.go`:

```go
/*
Copyright 2024.
*/

package v1alpha1

import (
	"fmt"
	"time"

	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	logf "sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/webhook"
	"sigs.k8s.io/controller-runtime/pkg/webhook/admission"
)

var devenvironmentlog = logf.Log.WithName("devenvironment-resource")

func (r *DevEnvironment) SetupWebhookWithManager(mgr ctrl.Manager) error {
	return ctrl.NewWebhookManagedBy(mgr).
		For(r).
		Complete()
}

// +kubebuilder:webhook:path=/mutate-platform-platform-example-com-v1alpha1-devenvironment,mutating=true,failurePolicy=fail,sideEffects=None,groups=platform.platform.example.com,resources=devenvironments,verbs=create;update,versions=v1alpha1,name=mdevenvironment.kb.io,admissionReviewVersions=v1

var _ webhook.Defaulter = &DevEnvironment{}

// Default implements webhook.Defaulter
func (r *DevEnvironment) Default() {
	devenvironmentlog.Info("default", "name", r.Name)

	// Set default TTL if not specified
	if r.Spec.TTL == "" {
		r.Spec.TTL = "8h"
	}

	// Set expiration time based on TTL
	if r.Status.ExpiresAt == nil {
		duration, err := parseTTL(r.Spec.TTL)
		if err == nil {
			expiresAt := time.Now().Add(duration)
			r.Status.ExpiresAt = &metav1.Time{Time: expiresAt}
		}
	}

	// Default template
	if r.Spec.Template == "" {
		r.Spec.Template = "web-service"
	}

	// Default size
	if r.Spec.Size == "" {
		r.Spec.Size = "small"
	}
}

// +kubebuilder:webhook:path=/validate-platform-platform-example-com-v1alpha1-devenvironment,mutating=false,failurePolicy=fail,sideEffects=None,groups=platform.platform.example.com,resources=devenvironments,verbs=create;update,versions=v1alpha1,name=vdevenvironment.kb.io,admissionReviewVersions=v1

var _ webhook.Validator = &DevEnvironment{}

// ValidateCreate implements webhook.Validator
func (r *DevEnvironment) ValidateCreate() (admission.Warnings, error) {
	devenvironmentlog.Info("validate create", "name", r.Name)

	return r.validateDevEnvironment()
}

// ValidateUpdate implements webhook.Validator
func (r *DevEnvironment) ValidateUpdate(old runtime.Object) (admission.Warnings, error) {
	devenvironmentlog.Info("validate update", "name", r.Name)

	oldEnv := old.(*DevEnvironment)

	// Prevent changing developer after creation
	if oldEnv.Spec.Developer != r.Spec.Developer {
		return nil, fmt.Errorf("developer cannot be changed after creation")
	}

	// Prevent changing team after creation
	if oldEnv.Spec.Team != r.Spec.Team {
		return nil, fmt.Errorf("team cannot be changed after creation")
	}

	return r.validateDevEnvironment()
}

// ValidateDelete implements webhook.Validator
func (r *DevEnvironment) ValidateDelete() (admission.Warnings, error) {
	devenvironmentlog.Info("validate delete", "name", r.Name)
	return nil, nil
}

func (r *DevEnvironment) validateDevEnvironment() (admission.Warnings, error) {
	var warnings admission.Warnings

	// Validate TTL
	if r.Spec.TTL != "" {
		duration, err := parseTTL(r.Spec.TTL)
		if err != nil {
			return nil, fmt.Errorf("invalid TTL format: %v", err)
		}

		// Warn if TTL is very long
		if duration > 7*24*time.Hour {
			warnings = append(warnings, "TTL is longer than 7 days, consider shorter duration")
		}

		// Reject TTL longer than 30 days
		if duration > 30*24*time.Hour {
			return nil, fmt.Errorf("TTL cannot exceed 30 days")
		}
	}

	// Validate size for team quotas (example policy)
	if r.Spec.Size == "large" && r.Spec.Team == "interns" {
		return nil, fmt.Errorf("team 'interns' is not allowed to use 'large' environments")
	}

	return warnings, nil
}

func parseTTL(ttl string) (time.Duration, error) {
	if len(ttl) < 2 {
		return 0, fmt.Errorf("TTL too short")
	}

	unit := ttl[len(ttl)-1]
	value := ttl[:len(ttl)-1]

	var multiplier time.Duration
	switch unit {
	case 'h':
		multiplier = time.Hour
	case 'd':
		multiplier = 24 * time.Hour
	case 'w':
		multiplier = 7 * 24 * time.Hour
	default:
		return 0, fmt.Errorf("unknown unit: %c", unit)
	}

	var num int
	_, err := fmt.Sscanf(value, "%d", &num)
	if err != nil {
		return 0, err
	}

	return time.Duration(num) * multiplier, nil
}
```

### Exercise 9: Operator Testing

Create unit tests for the controller:

```go
// internal/controller/devenvironment_controller_test.go
package controller

import (
	"context"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"

	platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

var _ = Describe("DevEnvironment Controller", func() {
	const (
		DevEnvName      = "test-dev"
		DevEnvNamespace = "default"
		timeout         = time.Second * 30
		interval        = time.Millisecond * 250
	)

	Context("When creating a DevEnvironment", func() {
		It("Should create Deployment, Service, and Ingress", func() {
			ctx := context.Background()

			// Create DevEnvironment
			devEnv := &platformv1alpha1.DevEnvironment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      DevEnvName,
					Namespace: DevEnvNamespace,
				},
				Spec: platformv1alpha1.DevEnvironmentSpec{
					Developer: "test-user",
					Team:      "platform",
					Template:  "web-service",
					Size:      "small",
				},
			}
			Expect(k8sClient.Create(ctx, devEnv)).Should(Succeed())

			// Verify DevEnvironment was created
			devEnvLookup := types.NamespacedName{Name: DevEnvName, Namespace: DevEnvNamespace}
			createdDevEnv := &platformv1alpha1.DevEnvironment{}
			Eventually(func() bool {
				err := k8sClient.Get(ctx, devEnvLookup, createdDevEnv)
				return err == nil
			}, timeout, interval).Should(BeTrue())

			// Verify Deployment was created
			deploymentLookup := types.NamespacedName{
				Name:      DevEnvName + "-env",
				Namespace: DevEnvNamespace,
			}
			createdDeployment := &appsv1.Deployment{}
			Eventually(func() bool {
				err := k8sClient.Get(ctx, deploymentLookup, createdDeployment)
				return err == nil
			}, timeout, interval).Should(BeTrue())

			// Verify labels
			Expect(createdDeployment.Labels["app.kubernetes.io/name"]).Should(Equal(DevEnvName))
			Expect(createdDeployment.Labels["platform.example.com/team"]).Should(Equal("platform"))

			// Verify Service was created
			serviceLookup := types.NamespacedName{
				Name:      DevEnvName + "-env",
				Namespace: DevEnvNamespace,
			}
			createdService := &corev1.Service{}
			Eventually(func() bool {
				err := k8sClient.Get(ctx, serviceLookup, createdService)
				return err == nil
			}, timeout, interval).Should(BeTrue())

			// Cleanup
			Expect(k8sClient.Delete(ctx, devEnv)).Should(Succeed())
		})
	})

	Context("When updating DevEnvironment size", func() {
		It("Should update resource allocations", func() {
			ctx := context.Background()

			// Create initial DevEnvironment
			devEnv := &platformv1alpha1.DevEnvironment{
				ObjectMeta: metav1.ObjectMeta{
					Name:      "size-test",
					Namespace: DevEnvNamespace,
				},
				Spec: platformv1alpha1.DevEnvironmentSpec{
					Developer: "test-user",
					Team:      "platform",
					Size:      "small",
				},
			}
			Expect(k8sClient.Create(ctx, devEnv)).Should(Succeed())

			// Wait for deployment
			time.Sleep(2 * time.Second)

			// Update size
			devEnvLookup := types.NamespacedName{Name: "size-test", Namespace: DevEnvNamespace}
			Expect(k8sClient.Get(ctx, devEnvLookup, devEnv)).Should(Succeed())
			devEnv.Spec.Size = "medium"
			Expect(k8sClient.Update(ctx, devEnv)).Should(Succeed())

			// Verify resources updated
			deploymentLookup := types.NamespacedName{
				Name:      "size-test-env",
				Namespace: DevEnvNamespace,
			}
			updatedDeployment := &appsv1.Deployment{}
			Eventually(func() string {
				k8sClient.Get(ctx, deploymentLookup, updatedDeployment)
				cpu := updatedDeployment.Spec.Template.Spec.Containers[0].Resources.Requests.Cpu()
				return cpu.String()
			}, timeout, interval).Should(Equal("1"))

			// Cleanup
			Expect(k8sClient.Delete(ctx, devEnv)).Should(Succeed())
		})
	})
})
```

Run tests:

```bash
# Run unit tests
make test

# Run with verbose output
go test ./... -v -ginkgo.v
```

### Validation Checkpoint

Verify your operator knowledge:

```bash
# 1. Check CRD is installed
kubectl get crd devenvironments.platform.platform.example.com

# 2. Check operator is running
kubectl get pods -n platform-operator-system

# 3. Create and verify DevEnvironment
kubectl apply -f devenv-sample.yaml
kubectl get devenvironment -w

# 4. Check created resources
kubectl get all -l app.kubernetes.io/managed-by=platform-operator

# 5. Test deletion cleanup
kubectl delete devenvironment john-dev
kubectl get all -l app.kubernetes.io/name=john-dev
```

### Best Practices for Operator Development

#### 1. Use OwnerReferences for Garbage Collection

```go
// Set owner reference on all child resources
controllerutil.SetControllerReference(parent, child, r.Scheme)
```

#### 2. Implement Idempotent Reconciliation

```go
// Use CreateOrUpdate pattern
op, err := controllerutil.CreateOrUpdate(ctx, r.Client, resource, func() error {
    // Mutation function
    return nil
})
```

#### 3. Handle Status Updates Carefully

```go
// Update status separately from spec
if err := r.Status().Update(ctx, obj); err != nil {
    if errors.IsConflict(err) {
        return ctrl.Result{Requeue: true}, nil
    }
    return ctrl.Result{}, err
}
```

#### 4. Use Finalizers for Cleanup

```go
// Add finalizer
controllerutil.AddFinalizer(obj, finalizerName)

// Check for deletion
if !obj.DeletionTimestamp.IsZero() {
    // Perform cleanup
    controllerutil.RemoveFinalizer(obj, finalizerName)
}
```

#### 5. Implement Proper RBAC

```go
// +kubebuilder:rbac:groups=...,resources=...,verbs=...
```

---

## Summary: Part 1

In this first part of Lab 4, you learned:

1. **Operator Pattern Fundamentals**
   - Controllers watch custom resources
   - Reconciliation loop maintains desired state
   - OwnerReferences enable garbage collection

2. **Kubebuilder Project Setup**
   - Initialize projects with `kubebuilder init`
   - Create APIs with `kubebuilder create api`
   - Generate manifests with `make manifests`

3. **Custom Resource Definitions**
   - Define spec and status structures
   - Use kubebuilder markers for validation
   - Add printer columns for kubectl

4. **Controller Implementation**
   - Reconcile loop structure
   - CreateOrUpdate pattern for idempotency
   - Status management and conditions

5. **Webhooks for Validation**
   - Defaulting webhooks
   - Validating webhooks
   - Admission control

---

**Next: Part 2 will cover Custom Controllers with Advanced Patterns, Event-Driven Automation, and Platform APIs.**

Continue to [Part 2: Advanced Controllers and Event-Driven Automation](./README-part2.md)
