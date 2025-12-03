# Lab 4: Platform Automation - Part 3

## Platform APIs and Developer CLI Tools

This part covers building platform APIs for self-service capabilities and creating CLI tools that enhance developer productivity.

---

## Part 4: Platform APIs

### API Architecture for Internal Platforms

```
┌─────────────────────────────────────────────────────────────────┐
│                    PLATFORM API ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    API Gateway                            │   │
│  │              (Authentication, Rate Limiting)              │   │
│  └──────────────────────────────────────────────────────────┘   │
│                              │                                   │
│         ┌────────────────────┼────────────────────┐             │
│         ▼                    ▼                    ▼             │
│  ┌─────────────┐      ┌─────────────┐      ┌─────────────┐     │
│  │ Environment │      │  Template   │      │   Metrics   │     │
│  │    API      │      │    API      │      │    API      │     │
│  └─────────────┘      └─────────────┘      └─────────────┘     │
│         │                    │                    │             │
│         └────────────────────┼────────────────────┘             │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                 Kubernetes API Server                     │   │
│  │              (Custom Resources, Operators)                │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### Exercise 1: Platform API Server

Create a Go-based platform API:

```go
// cmd/platform-api/main.go
package main

import (
	"context"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"sigs.k8s.io/controller-runtime/pkg/client"

	platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

type PlatformAPI struct {
	k8sClient  client.Client
	kubeClient *kubernetes.Clientset
}

func main() {
	// Initialize Kubernetes client
	config, err := rest.InClusterConfig()
	if err != nil {
		log.Fatalf("Failed to get cluster config: %v", err)
	}

	k8sClient, err := client.New(config, client.Options{})
	if err != nil {
		log.Fatalf("Failed to create client: %v", err)
	}

	kubeClient, err := kubernetes.NewForConfig(config)
	if err != nil {
		log.Fatalf("Failed to create kubernetes client: %v", err)
	}

	api := &PlatformAPI{
		k8sClient:  k8sClient,
		kubeClient: kubeClient,
	}

	// Setup router
	router := gin.Default()

	// Middleware
	router.Use(gin.Recovery())
	router.Use(CORSMiddleware())
	router.Use(AuthMiddleware())
	router.Use(MetricsMiddleware())

	// Health endpoints
	router.GET("/health", api.Health)
	router.GET("/ready", api.Ready)

	// Metrics endpoint
	router.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// API v1 routes
	v1 := router.Group("/api/v1")
	{
		// Environment management
		environments := v1.Group("/environments")
		{
			environments.GET("", api.ListEnvironments)
			environments.POST("", api.CreateEnvironment)
			environments.GET("/:name", api.GetEnvironment)
			environments.DELETE("/:name", api.DeleteEnvironment)
			environments.PUT("/:name/scale", api.ScaleEnvironment)
			environments.PUT("/:name/sleep", api.SleepEnvironment)
			environments.PUT("/:name/wake", api.WakeEnvironment)
		}

		// Templates
		templates := v1.Group("/templates")
		{
			templates.GET("", api.ListTemplates)
			templates.GET("/:name", api.GetTemplate)
			templates.POST("/:name/instantiate", api.InstantiateTemplate)
		}

		// Teams
		teams := v1.Group("/teams")
		{
			teams.GET("", api.ListTeams)
			teams.GET("/:name", api.GetTeam)
			teams.GET("/:name/environments", api.GetTeamEnvironments)
			teams.GET("/:name/quota", api.GetTeamQuota)
		}

		// Costs
		costs := v1.Group("/costs")
		{
			costs.GET("/summary", api.GetCostSummary)
			costs.GET("/team/:name", api.GetTeamCosts)
			costs.GET("/environment/:name", api.GetEnvironmentCosts)
		}
	}

	// Start server
	srv := &http.Server{
		Addr:    ":8080",
		Handler: router,
	}

	go func() {
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Fatalf("Server forced to shutdown: %v", err)
	}
}

// Middleware functions
func CORSMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	}
}

func AuthMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Skip auth for health endpoints
		if c.Request.URL.Path == "/health" || c.Request.URL.Path == "/ready" {
			c.Next()
			return
		}

		token := c.GetHeader("Authorization")
		if token == "" {
			c.JSON(401, gin.H{"error": "Authorization header required"})
			c.Abort()
			return
		}

		// Validate token (implement your auth logic)
		user, err := validateToken(token)
		if err != nil {
			c.JSON(401, gin.H{"error": "Invalid token"})
			c.Abort()
			return
		}

		c.Set("user", user)
		c.Next()
	}
}

func MetricsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		c.Next()
		duration := time.Since(start)

		// Record metrics
		httpRequestsTotal.WithLabelValues(
			c.Request.Method,
			c.Request.URL.Path,
			http.StatusText(c.Writer.Status()),
		).Inc()

		httpRequestDuration.WithLabelValues(
			c.Request.Method,
			c.Request.URL.Path,
		).Observe(duration.Seconds())
	}
}
```

### Exercise 2: Environment API Handlers

Implement environment management endpoints:

```go
// internal/api/environments.go
package api

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/types"
	"sigs.k8s.io/controller-runtime/pkg/client"

	platformv1alpha1 "github.com/example/platform-operator/api/v1alpha1"
)

// Request/Response types
type CreateEnvironmentRequest struct {
	Name       string   `json:"name" binding:"required"`
	Team       string   `json:"team" binding:"required"`
	Template   string   `json:"template" binding:"required"`
	Size       string   `json:"size"`
	TTL        string   `json:"ttl"`
	GitRepo    string   `json:"gitRepository"`
	ExtraTools []string `json:"extraTools"`
}

type EnvironmentResponse struct {
	Name         string            `json:"name"`
	Developer    string            `json:"developer"`
	Team         string            `json:"team"`
	Template     string            `json:"template"`
	Size         string            `json:"size"`
	Phase        string            `json:"phase"`
	Endpoint     string            `json:"endpoint"`
	ExpiresAt    *time.Time        `json:"expiresAt,omitempty"`
	CreatedAt    time.Time         `json:"createdAt"`
	Resources    map[string]string `json:"resources"`
}

type ScaleRequest struct {
	Size string `json:"size" binding:"required,oneof=small medium large"`
}

// ListEnvironments returns all environments for the authenticated user
func (api *PlatformAPI) ListEnvironments(c *gin.Context) {
	ctx := c.Request.Context()
	user := c.MustGet("user").(User)

	var envList platformv1alpha1.DevEnvironmentList
	listOpts := []client.ListOption{}

	// Filter by team if not admin
	if !user.IsAdmin {
		listOpts = append(listOpts, client.MatchingLabels{
			"platform.example.com/team": user.Team,
		})
	}

	if err := api.k8sClient.List(ctx, &envList, listOpts...); err != nil {
		c.JSON(500, gin.H{"error": "Failed to list environments"})
		return
	}

	responses := make([]EnvironmentResponse, 0, len(envList.Items))
	for _, env := range envList.Items {
		responses = append(responses, toEnvironmentResponse(&env))
	}

	c.JSON(200, gin.H{
		"environments": responses,
		"total":        len(responses),
	})
}

// CreateEnvironment creates a new development environment
func (api *PlatformAPI) CreateEnvironment(c *gin.Context) {
	ctx := c.Request.Context()
	user := c.MustGet("user").(User)

	var req CreateEnvironmentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	// Validate team access
	if !user.IsAdmin && req.Team != user.Team {
		c.JSON(403, gin.H{"error": "Cannot create environment for another team"})
		return
	}

	// Check quota
	if err := api.checkTeamQuota(ctx, req.Team); err != nil {
		c.JSON(429, gin.H{"error": err.Error()})
		return
	}

	// Create DevEnvironment resource
	devEnv := &platformv1alpha1.DevEnvironment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      req.Name,
			Namespace: "platform-envs",
			Labels: map[string]string{
				"platform.example.com/team":      req.Team,
				"platform.example.com/developer": user.Username,
			},
		},
		Spec: platformv1alpha1.DevEnvironmentSpec{
			Developer:     user.Username,
			Team:          req.Team,
			Template:      req.Template,
			Size:          req.Size,
			TTL:           req.TTL,
			GitRepository: req.GitRepo,
			ExtraTools:    req.ExtraTools,
		},
	}

	if err := api.k8sClient.Create(ctx, devEnv); err != nil {
		c.JSON(500, gin.H{"error": fmt.Sprintf("Failed to create environment: %v", err)})
		return
	}

	c.JSON(201, gin.H{
		"message":     "Environment created successfully",
		"environment": toEnvironmentResponse(devEnv),
	})
}

// GetEnvironment returns a specific environment
func (api *PlatformAPI) GetEnvironment(c *gin.Context) {
	ctx := c.Request.Context()
	user := c.MustGet("user").(User)
	name := c.Param("name")

	devEnv := &platformv1alpha1.DevEnvironment{}
	key := types.NamespacedName{Name: name, Namespace: "platform-envs"}

	if err := api.k8sClient.Get(ctx, key, devEnv); err != nil {
		c.JSON(404, gin.H{"error": "Environment not found"})
		return
	}

	// Check access
	if !user.IsAdmin && devEnv.Spec.Team != user.Team {
		c.JSON(403, gin.H{"error": "Access denied"})
		return
	}

	c.JSON(200, toEnvironmentResponse(devEnv))
}

// DeleteEnvironment removes an environment
func (api *PlatformAPI) DeleteEnvironment(c *gin.Context) {
	ctx := c.Request.Context()
	user := c.MustGet("user").(User)
	name := c.Param("name")

	devEnv := &platformv1alpha1.DevEnvironment{}
	key := types.NamespacedName{Name: name, Namespace: "platform-envs"}

	if err := api.k8sClient.Get(ctx, key, devEnv); err != nil {
		c.JSON(404, gin.H{"error": "Environment not found"})
		return
	}

	// Check ownership or admin
	if !user.IsAdmin && devEnv.Spec.Developer != user.Username {
		c.JSON(403, gin.H{"error": "Only owner can delete environment"})
		return
	}

	if err := api.k8sClient.Delete(ctx, devEnv); err != nil {
		c.JSON(500, gin.H{"error": "Failed to delete environment"})
		return
	}

	c.JSON(200, gin.H{"message": "Environment deleted"})
}

// ScaleEnvironment changes the size of an environment
func (api *PlatformAPI) ScaleEnvironment(c *gin.Context) {
	ctx := c.Request.Context()
	user := c.MustGet("user").(User)
	name := c.Param("name")

	var req ScaleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(400, gin.H{"error": err.Error()})
		return
	}

	devEnv := &platformv1alpha1.DevEnvironment{}
	key := types.NamespacedName{Name: name, Namespace: "platform-envs"}

	if err := api.k8sClient.Get(ctx, key, devEnv); err != nil {
		c.JSON(404, gin.H{"error": "Environment not found"})
		return
	}

	// Check ownership
	if !user.IsAdmin && devEnv.Spec.Developer != user.Username {
		c.JSON(403, gin.H{"error": "Only owner can scale environment"})
		return
	}

	// Update size
	devEnv.Spec.Size = req.Size
	if err := api.k8sClient.Update(ctx, devEnv); err != nil {
		c.JSON(500, gin.H{"error": "Failed to scale environment"})
		return
	}

	c.JSON(200, gin.H{
		"message":     "Environment scaled",
		"environment": toEnvironmentResponse(devEnv),
	})
}

// SleepEnvironment pauses an environment to save resources
func (api *PlatformAPI) SleepEnvironment(c *gin.Context) {
	ctx := c.Request.Context()
	name := c.Param("name")

	devEnv := &platformv1alpha1.DevEnvironment{}
	key := types.NamespacedName{Name: name, Namespace: "platform-envs"}

	if err := api.k8sClient.Get(ctx, key, devEnv); err != nil {
		c.JSON(404, gin.H{"error": "Environment not found"})
		return
	}

	// Add sleep annotation
	if devEnv.Annotations == nil {
		devEnv.Annotations = make(map[string]string)
	}
	devEnv.Annotations["platform.example.com/sleep"] = "true"

	if err := api.k8sClient.Update(ctx, devEnv); err != nil {
		c.JSON(500, gin.H{"error": "Failed to sleep environment"})
		return
	}

	c.JSON(200, gin.H{"message": "Environment sleeping"})
}

// WakeEnvironment resumes a sleeping environment
func (api *PlatformAPI) WakeEnvironment(c *gin.Context) {
	ctx := c.Request.Context()
	name := c.Param("name")

	devEnv := &platformv1alpha1.DevEnvironment{}
	key := types.NamespacedName{Name: name, Namespace: "platform-envs"}

	if err := api.k8sClient.Get(ctx, key, devEnv); err != nil {
		c.JSON(404, gin.H{"error": "Environment not found"})
		return
	}

	// Remove sleep annotation
	delete(devEnv.Annotations, "platform.example.com/sleep")

	if err := api.k8sClient.Update(ctx, devEnv); err != nil {
		c.JSON(500, gin.H{"error": "Failed to wake environment"})
		return
	}

	c.JSON(200, gin.H{"message": "Environment waking up"})
}

// Helper functions
func toEnvironmentResponse(env *platformv1alpha1.DevEnvironment) EnvironmentResponse {
	resp := EnvironmentResponse{
		Name:      env.Name,
		Developer: env.Spec.Developer,
		Team:      env.Spec.Team,
		Template:  env.Spec.Template,
		Size:      env.Spec.Size,
		Phase:     env.Status.Phase,
		Endpoint:  env.Status.Endpoint,
		CreatedAt: env.CreationTimestamp.Time,
		Resources: make(map[string]string),
	}

	if env.Status.ExpiresAt != nil {
		t := env.Status.ExpiresAt.Time
		resp.ExpiresAt = &t
	}

	for _, ref := range env.Status.Resources {
		resp.Resources[ref.Kind] = ref.Name
	}

	return resp
}

func (api *PlatformAPI) checkTeamQuota(ctx context.Context, team string) error {
	var envList platformv1alpha1.DevEnvironmentList
	if err := api.k8sClient.List(ctx, &envList, client.MatchingLabels{
		"platform.example.com/team": team,
	}); err != nil {
		return err
	}

	// Get team quota (from ConfigMap or custom resource)
	maxEnvs := 10 // Default
	if len(envList.Items) >= maxEnvs {
		return fmt.Errorf("team quota exceeded: %d/%d environments", len(envList.Items), maxEnvs)
	}

	return nil
}
```

### Exercise 3: OpenAPI Specification

Create OpenAPI spec for the platform API:

```yaml
# api/openapi.yaml
openapi: 3.0.3
info:
  title: Platform API
  description: Internal Developer Platform API for self-service capabilities
  version: 1.0.0
  contact:
    name: Platform Team
    email: platform@example.com

servers:
  - url: https://platform-api.example.com/api/v1
    description: Production
  - url: https://platform-api-staging.example.com/api/v1
    description: Staging

security:
  - bearerAuth: []

paths:
  /environments:
    get:
      summary: List environments
      description: List all environments accessible to the authenticated user
      tags:
        - Environments
      parameters:
        - name: team
          in: query
          schema:
            type: string
        - name: status
          in: query
          schema:
            type: string
            enum: [Running, Sleeping, Provisioning, Failed]
      responses:
        '200':
          description: List of environments
          content:
            application/json:
              schema:
                type: object
                properties:
                  environments:
                    type: array
                    items:
                      $ref: '#/components/schemas/Environment'
                  total:
                    type: integer
        '401':
          $ref: '#/components/responses/Unauthorized'

    post:
      summary: Create environment
      description: Create a new development environment
      tags:
        - Environments
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CreateEnvironmentRequest'
      responses:
        '201':
          description: Environment created
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Environment'
        '400':
          $ref: '#/components/responses/BadRequest'
        '429':
          $ref: '#/components/responses/QuotaExceeded'

  /environments/{name}:
    get:
      summary: Get environment
      tags:
        - Environments
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Environment details
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Environment'
        '404':
          $ref: '#/components/responses/NotFound'

    delete:
      summary: Delete environment
      tags:
        - Environments
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Environment deleted
        '404':
          $ref: '#/components/responses/NotFound'

  /environments/{name}/scale:
    put:
      summary: Scale environment
      tags:
        - Environments
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/ScaleRequest'
      responses:
        '200':
          description: Environment scaled
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Environment'

  /environments/{name}/sleep:
    put:
      summary: Sleep environment
      description: Pause the environment to save resources
      tags:
        - Environments
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Environment sleeping

  /environments/{name}/wake:
    put:
      summary: Wake environment
      description: Resume a sleeping environment
      tags:
        - Environments
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: Environment waking up

  /templates:
    get:
      summary: List templates
      tags:
        - Templates
      responses:
        '200':
          description: List of available templates
          content:
            application/json:
              schema:
                type: object
                properties:
                  templates:
                    type: array
                    items:
                      $ref: '#/components/schemas/Template'

  /templates/{name}/instantiate:
    post:
      summary: Instantiate template
      description: Create a new project from a template
      tags:
        - Templates
      parameters:
        - name: name
          in: path
          required: true
          schema:
            type: string
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/InstantiateRequest'
      responses:
        '201':
          description: Project created

  /costs/summary:
    get:
      summary: Get cost summary
      tags:
        - Costs
      parameters:
        - name: period
          in: query
          schema:
            type: string
            enum: [day, week, month]
            default: month
      responses:
        '200':
          description: Cost summary
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CostSummary'

components:
  securitySchemes:
    bearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT

  schemas:
    Environment:
      type: object
      properties:
        name:
          type: string
        developer:
          type: string
        team:
          type: string
        template:
          type: string
        size:
          type: string
          enum: [small, medium, large]
        phase:
          type: string
          enum: [Pending, Provisioning, Running, Sleeping, Terminating, Failed]
        endpoint:
          type: string
          format: uri
        expiresAt:
          type: string
          format: date-time
        createdAt:
          type: string
          format: date-time
        resources:
          type: object
          additionalProperties:
            type: string

    CreateEnvironmentRequest:
      type: object
      required:
        - name
        - team
        - template
      properties:
        name:
          type: string
          pattern: '^[a-z0-9-]+$'
          minLength: 3
          maxLength: 63
        team:
          type: string
        template:
          type: string
          enum: [web-service, backend-api, data-pipeline, ml-workbench]
        size:
          type: string
          enum: [small, medium, large]
          default: small
        ttl:
          type: string
          pattern: '^[0-9]+[hdw]$'
          default: '8h'
        gitRepository:
          type: string
          format: uri
        extraTools:
          type: array
          items:
            type: string

    ScaleRequest:
      type: object
      required:
        - size
      properties:
        size:
          type: string
          enum: [small, medium, large]

    Template:
      type: object
      properties:
        name:
          type: string
        description:
          type: string
        category:
          type: string
        defaultSize:
          type: string
        requiredTools:
          type: array
          items:
            type: string

    InstantiateRequest:
      type: object
      required:
        - projectName
      properties:
        projectName:
          type: string
        parameters:
          type: object
          additionalProperties:
            type: string

    CostSummary:
      type: object
      properties:
        totalCost:
          type: number
          format: float
        currency:
          type: string
        period:
          type: string
        breakdown:
          type: object
          properties:
            compute:
              type: number
            storage:
              type: number
            network:
              type: number

  responses:
    Unauthorized:
      description: Authentication required
      content:
        application/json:
          schema:
            type: object
            properties:
              error:
                type: string

    BadRequest:
      description: Invalid request
      content:
        application/json:
          schema:
            type: object
            properties:
              error:
                type: string
              details:
                type: array
                items:
                  type: string

    NotFound:
      description: Resource not found
      content:
        application/json:
          schema:
            type: object
            properties:
              error:
                type: string

    QuotaExceeded:
      description: Quota exceeded
      content:
        application/json:
          schema:
            type: object
            properties:
              error:
                type: string
              limit:
                type: integer
              current:
                type: integer
```

---

## Part 5: Developer CLI Tools

### Exercise 4: Platform CLI with Cobra

Create a CLI for developers to interact with the platform:

```go
// cmd/platform/main.go
package main

import (
	"os"

	"github.com/spf13/cobra"
)

var (
	apiURL   string
	token    string
	verbose  bool
	output   string
)

func main() {
	rootCmd := &cobra.Command{
		Use:   "platform",
		Short: "Platform CLI - Interact with the Internal Developer Platform",
		Long: `Platform CLI provides commands to manage development environments,
templates, and other platform resources.

Get started:
  platform login
  platform env create my-env --template web-service
  platform env list`,
	}

	// Global flags
	rootCmd.PersistentFlags().StringVar(&apiURL, "api-url", "https://platform-api.example.com", "Platform API URL")
	rootCmd.PersistentFlags().StringVar(&token, "token", "", "API token (or use PLATFORM_TOKEN env)")
	rootCmd.PersistentFlags().BoolVarP(&verbose, "verbose", "v", false, "Verbose output")
	rootCmd.PersistentFlags().StringVarP(&output, "output", "o", "table", "Output format (table, json, yaml)")

	// Add commands
	rootCmd.AddCommand(
		newLoginCmd(),
		newEnvCmd(),
		newTemplateCmd(),
		newCostCmd(),
		newConfigCmd(),
		newVersionCmd(),
	)

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

// cmd/platform/login.go
func newLoginCmd() *cobra.Command {
	var (
		username string
		password string
	)

	cmd := &cobra.Command{
		Use:   "login",
		Short: "Login to the platform",
		RunE: func(cmd *cobra.Command, args []string) error {
			// Interactive login if no credentials provided
			if username == "" {
				fmt.Print("Username: ")
				fmt.Scanln(&username)
			}
			if password == "" {
				fmt.Print("Password: ")
				// Use term.ReadPassword for secure input
				pwBytes, _ := term.ReadPassword(int(os.Stdin.Fd()))
				password = string(pwBytes)
				fmt.Println()
			}

			// Authenticate
			client := NewPlatformClient(apiURL)
			token, err := client.Login(username, password)
			if err != nil {
				return fmt.Errorf("login failed: %w", err)
			}

			// Save token to config
			if err := saveConfig(ConfigData{Token: token, APIUrl: apiURL}); err != nil {
				return fmt.Errorf("failed to save config: %w", err)
			}

			fmt.Println("✓ Login successful")
			return nil
		},
	}

	cmd.Flags().StringVarP(&username, "username", "u", "", "Username")
	cmd.Flags().StringVarP(&password, "password", "p", "", "Password")

	return cmd
}
```

### Exercise 5: Environment Commands

Implement environment management commands:

```go
// cmd/platform/env.go
package main

import (
	"encoding/json"
	"fmt"
	"os"
	"text/tabwriter"
	"time"

	"github.com/spf13/cobra"
	"gopkg.in/yaml.v3"
)

func newEnvCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:     "env",
		Aliases: []string{"environment", "environments"},
		Short:   "Manage development environments",
	}

	cmd.AddCommand(
		newEnvListCmd(),
		newEnvCreateCmd(),
		newEnvGetCmd(),
		newEnvDeleteCmd(),
		newEnvScaleCmd(),
		newEnvSleepCmd(),
		newEnvWakeCmd(),
		newEnvLogsCmd(),
		newEnvExecCmd(),
	)

	return cmd
}

func newEnvListCmd() *cobra.Command {
	var (
		team   string
		status string
	)

	cmd := &cobra.Command{
		Use:   "list",
		Short: "List environments",
		RunE: func(cmd *cobra.Command, args []string) error {
			client := getClient()

			envs, err := client.ListEnvironments(team, status)
			if err != nil {
				return err
			}

			return printOutput(envs, output)
		},
	}

	cmd.Flags().StringVar(&team, "team", "", "Filter by team")
	cmd.Flags().StringVar(&status, "status", "", "Filter by status")

	return cmd
}

func newEnvCreateCmd() *cobra.Command {
	var (
		template   string
		team       string
		size       string
		ttl        string
		gitRepo    string
		extraTools []string
		wait       bool
	)

	cmd := &cobra.Command{
		Use:   "create NAME",
		Short: "Create a new environment",
		Args:  cobra.ExactArgs(1),
		Example: `  # Create a simple environment
  platform env create my-env --template web-service

  # Create with all options
  platform env create my-env \
    --template backend-api \
    --team backend \
    --size medium \
    --ttl 24h \
    --git-repo https://github.com/example/my-service \
    --wait`,
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			client := getClient()

			req := CreateEnvironmentRequest{
				Name:       name,
				Team:       team,
				Template:   template,
				Size:       size,
				TTL:        ttl,
				GitRepo:    gitRepo,
				ExtraTools: extraTools,
			}

			fmt.Printf("Creating environment %s...\n", name)
			env, err := client.CreateEnvironment(req)
			if err != nil {
				return err
			}

			if wait {
				fmt.Println("Waiting for environment to be ready...")
				env, err = client.WaitForEnvironment(name, 5*time.Minute)
				if err != nil {
					return err
				}
			}

			fmt.Printf("✓ Environment created\n")
			fmt.Printf("  Name:     %s\n", env.Name)
			fmt.Printf("  Status:   %s\n", env.Phase)
			if env.Endpoint != "" {
				fmt.Printf("  Endpoint: %s\n", env.Endpoint)
			}

			return nil
		},
	}

	cmd.Flags().StringVarP(&template, "template", "t", "web-service", "Template to use")
	cmd.Flags().StringVar(&team, "team", "", "Team name (defaults to your team)")
	cmd.Flags().StringVar(&size, "size", "small", "Environment size (small, medium, large)")
	cmd.Flags().StringVar(&ttl, "ttl", "8h", "Time to live")
	cmd.Flags().StringVar(&gitRepo, "git-repo", "", "Git repository to clone")
	cmd.Flags().StringSliceVar(&extraTools, "extra-tools", nil, "Additional tools to install")
	cmd.Flags().BoolVarP(&wait, "wait", "w", false, "Wait for environment to be ready")

	return cmd
}

func newEnvGetCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "get NAME",
		Short: "Get environment details",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			client := getClient()
			env, err := client.GetEnvironment(args[0])
			if err != nil {
				return err
			}
			return printOutput(env, output)
		},
	}
}

func newEnvDeleteCmd() *cobra.Command {
	var force bool

	cmd := &cobra.Command{
		Use:   "delete NAME",
		Short: "Delete an environment",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			client := getClient()

			if !force {
				fmt.Printf("Delete environment %s? [y/N]: ", name)
				var confirm string
				fmt.Scanln(&confirm)
				if confirm != "y" && confirm != "Y" {
					fmt.Println("Cancelled")
					return nil
				}
			}

			if err := client.DeleteEnvironment(name); err != nil {
				return err
			}

			fmt.Printf("✓ Environment %s deleted\n", name)
			return nil
		},
	}

	cmd.Flags().BoolVarP(&force, "force", "f", false, "Skip confirmation")

	return cmd
}

func newEnvScaleCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "scale NAME SIZE",
		Short: "Scale an environment",
		Args:  cobra.ExactArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			name, size := args[0], args[1]
			client := getClient()

			if err := client.ScaleEnvironment(name, size); err != nil {
				return err
			}

			fmt.Printf("✓ Environment %s scaled to %s\n", name, size)
			return nil
		},
	}
}

func newEnvSleepCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "sleep NAME",
		Short: "Put environment to sleep",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			client := getClient()
			if err := client.SleepEnvironment(args[0]); err != nil {
				return err
			}
			fmt.Printf("✓ Environment %s is sleeping\n", args[0])
			return nil
		},
	}
}

func newEnvWakeCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "wake NAME",
		Short: "Wake up a sleeping environment",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			client := getClient()
			if err := client.WakeEnvironment(args[0]); err != nil {
				return err
			}
			fmt.Printf("✓ Environment %s is waking up\n", args[0])
			return nil
		},
	}
}

func newEnvLogsCmd() *cobra.Command {
	var (
		follow    bool
		container string
		tail      int
	)

	cmd := &cobra.Command{
		Use:   "logs NAME",
		Short: "View environment logs",
		Args:  cobra.ExactArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			client := getClient()
			return client.StreamLogs(args[0], container, follow, tail)
		},
	}

	cmd.Flags().BoolVarP(&follow, "follow", "f", false, "Follow log output")
	cmd.Flags().StringVarP(&container, "container", "c", "", "Container name")
	cmd.Flags().IntVar(&tail, "tail", 100, "Number of lines to show")

	return cmd
}

func newEnvExecCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "exec NAME -- COMMAND",
		Short: "Execute command in environment",
		Args:  cobra.MinimumNArgs(2),
		RunE: func(cmd *cobra.Command, args []string) error {
			name := args[0]
			command := args[1:]

			client := getClient()
			return client.Exec(name, command)
		},
	}
}

// Output helpers
func printOutput(data interface{}, format string) error {
	switch format {
	case "json":
		enc := json.NewEncoder(os.Stdout)
		enc.SetIndent("", "  ")
		return enc.Encode(data)
	case "yaml":
		enc := yaml.NewEncoder(os.Stdout)
		return enc.Encode(data)
	default:
		return printTable(data)
	}
}

func printTable(data interface{}) error {
	w := tabwriter.NewWriter(os.Stdout, 0, 0, 2, ' ', 0)

	switch v := data.(type) {
	case []EnvironmentResponse:
		fmt.Fprintln(w, "NAME\tTEAM\tTEMPLATE\tSIZE\tSTATUS\tENDPOINT\tAGE")
		for _, env := range v {
			age := time.Since(env.CreatedAt).Round(time.Minute)
			fmt.Fprintf(w, "%s\t%s\t%s\t%s\t%s\t%s\t%s\n",
				env.Name, env.Team, env.Template, env.Size, env.Phase, env.Endpoint, age)
		}
	case EnvironmentResponse:
		fmt.Fprintf(w, "Name:\t%s\n", v.Name)
		fmt.Fprintf(w, "Developer:\t%s\n", v.Developer)
		fmt.Fprintf(w, "Team:\t%s\n", v.Team)
		fmt.Fprintf(w, "Template:\t%s\n", v.Template)
		fmt.Fprintf(w, "Size:\t%s\n", v.Size)
		fmt.Fprintf(w, "Status:\t%s\n", v.Phase)
		fmt.Fprintf(w, "Endpoint:\t%s\n", v.Endpoint)
		fmt.Fprintf(w, "Created:\t%s\n", v.CreatedAt.Format(time.RFC3339))
		if v.ExpiresAt != nil {
			fmt.Fprintf(w, "Expires:\t%s\n", v.ExpiresAt.Format(time.RFC3339))
		}
	}

	return w.Flush()
}
```

### Exercise 6: kubectl Plugin

Create a kubectl plugin for platform operations:

```go
// cmd/kubectl-platform/main.go
package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
	"k8s.io/cli-runtime/pkg/genericclioptions"
)

func main() {
	// Use kubectl's configuration
	configFlags := genericclioptions.NewConfigFlags(true)

	rootCmd := &cobra.Command{
		Use:   "kubectl-platform",
		Short: "Platform operations as kubectl plugin",
		Long: `kubectl platform provides platform operations directly from kubectl.

Install by placing in PATH as 'kubectl-platform'.

Usage:
  kubectl platform env list
  kubectl platform env create my-env --template web-service`,
	}

	configFlags.AddFlags(rootCmd.PersistentFlags())

	rootCmd.AddCommand(
		newEnvPluginCmd(configFlags),
		newQuotaPluginCmd(configFlags),
		newCostPluginCmd(configFlags),
	)

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

func newEnvPluginCmd(configFlags *genericclioptions.ConfigFlags) *cobra.Command {
	cmd := &cobra.Command{
		Use:   "env",
		Short: "Manage development environments",
	}

	cmd.AddCommand(
		&cobra.Command{
			Use:   "list",
			Short: "List environments",
			RunE: func(cmd *cobra.Command, args []string) error {
				config, err := configFlags.ToRESTConfig()
				if err != nil {
					return err
				}

				client, err := NewK8sClient(config)
				if err != nil {
					return err
				}

				return client.ListDevEnvironments()
			},
		},
		&cobra.Command{
			Use:   "describe NAME",
			Short: "Describe environment",
			Args:  cobra.ExactArgs(1),
			RunE: func(cmd *cobra.Command, args []string) error {
				config, err := configFlags.ToRESTConfig()
				if err != nil {
					return err
				}

				client, err := NewK8sClient(config)
				if err != nil {
					return err
				}

				return client.DescribeDevEnvironment(args[0])
			},
		},
	)

	return cmd
}

func newQuotaPluginCmd(configFlags *genericclioptions.ConfigFlags) *cobra.Command {
	return &cobra.Command{
		Use:   "quota",
		Short: "Show team quotas and usage",
		RunE: func(cmd *cobra.Command, args []string) error {
			config, err := configFlags.ToRESTConfig()
			if err != nil {
				return err
			}

			client, err := NewK8sClient(config)
			if err != nil {
				return err
			}

			return client.ShowQuotas()
		},
	}
}

func newCostPluginCmd(configFlags *genericclioptions.ConfigFlags) *cobra.Command {
	return &cobra.Command{
		Use:   "cost [NAMESPACE]",
		Short: "Show cost breakdown",
		RunE: func(cmd *cobra.Command, args []string) error {
			namespace := ""
			if len(args) > 0 {
				namespace = args[0]
			}

			config, err := configFlags.ToRESTConfig()
			if err != nil {
				return err
			}

			client, err := NewK8sClient(config)
			if err != nil {
				return err
			}

			return client.ShowCosts(namespace)
		},
	}
}
```

Install the plugin:

```bash
# Build
go build -o kubectl-platform ./cmd/kubectl-platform

# Install
sudo mv kubectl-platform /usr/local/bin/

# Verify
kubectl plugin list
kubectl platform --help
```

### Exercise 7: Shell Completions

Add shell completions to the CLI:

```go
// cmd/platform/completion.go
package main

import (
	"os"

	"github.com/spf13/cobra"
)

func newCompletionCmd() *cobra.Command {
	cmd := &cobra.Command{
		Use:   "completion [bash|zsh|fish|powershell]",
		Short: "Generate shell completion scripts",
		Long: `Generate shell completion scripts for platform CLI.

To load completions:

Bash:
  $ source <(platform completion bash)

  # To load completions for each session, execute once:
  # Linux:
  $ platform completion bash > /etc/bash_completion.d/platform
  # macOS:
  $ platform completion bash > /usr/local/etc/bash_completion.d/platform

Zsh:
  $ echo "autoload -U compinit; compinit" >> ~/.zshrc
  $ platform completion zsh > "${fpath[1]}/_platform"

Fish:
  $ platform completion fish > ~/.config/fish/completions/platform.fish
`,
		DisableFlagsInUseLine: true,
		ValidArgs:             []string{"bash", "zsh", "fish", "powershell"},
		Args:                  cobra.ExactValidArgs(1),
		RunE: func(cmd *cobra.Command, args []string) error {
			switch args[0] {
			case "bash":
				return cmd.Root().GenBashCompletion(os.Stdout)
			case "zsh":
				return cmd.Root().GenZshCompletion(os.Stdout)
			case "fish":
				return cmd.Root().GenFishCompletion(os.Stdout, true)
			case "powershell":
				return cmd.Root().GenPowerShellCompletionWithDesc(os.Stdout)
			}
			return nil
		},
	}

	return cmd
}

// Add dynamic completions for environment names
func getEnvCompletions(cmd *cobra.Command, args []string, toComplete string) ([]string, cobra.ShellCompDirective) {
	client := getClient()
	envs, err := client.ListEnvironments("", "")
	if err != nil {
		return nil, cobra.ShellCompDirectiveError
	}

	names := make([]string, 0, len(envs))
	for _, env := range envs {
		if strings.HasPrefix(env.Name, toComplete) {
			names = append(names, env.Name)
		}
	}

	return names, cobra.ShellCompDirectiveNoFileComp
}

// Register completions in env commands
func init() {
	// In newEnvGetCmd, newEnvDeleteCmd, etc.
	cmd.ValidArgsFunction = getEnvCompletions
}
```

---

## Validation Checkpoint

Test your platform API and CLI:

```bash
# 1. Test API endpoints
curl -X GET https://platform-api.example.com/api/v1/environments \
  -H "Authorization: Bearer $TOKEN"

# 2. Test CLI login
platform login

# 3. Create environment via CLI
platform env create test-env --template web-service --wait

# 4. List environments
platform env list -o json

# 5. Test kubectl plugin
kubectl platform env list
kubectl platform quota

# 6. Test completions
platform env <TAB>
```

---

## Summary: Part 3

In this part, you learned:

1. **Platform API Design**
   - RESTful API structure for platform resources
   - Authentication and authorization
   - OpenAPI specification

2. **API Implementation**
   - Gin-based HTTP server
   - Kubernetes client integration
   - Request validation and error handling

3. **CLI Development with Cobra**
   - Command structure and flags
   - Multiple output formats (table, JSON, YAML)
   - Interactive prompts

4. **kubectl Plugins**
   - Plugin discovery and installation
   - Kubernetes configuration integration
   - Extending kubectl functionality

5. **Developer Experience**
   - Shell completions
   - Helpful examples and documentation
   - Consistent command patterns

---

## Lab 4 Complete Summary

Across all three parts, you learned:

| Part | Topics Covered |
|------|----------------|
| Part 1 | Kubernetes Operators, Kubebuilder, CRDs, Controllers, Webhooks |
| Part 2 | Advanced reconciliation, Rate limiting, Argo Events, Event-driven automation |
| Part 3 | Platform APIs, OpenAPI, CLI tools, kubectl plugins |

---

**Next Lab: [Lab 5 - Cost Management and FinOps](../lab-05-costs/README.md)**
