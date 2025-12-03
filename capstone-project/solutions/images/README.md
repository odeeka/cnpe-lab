# Pre-Built Application Images for BookStore Capstone

This directory contains configuration for using pre-built demo images so students can focus on Kubernetes concepts rather than building applications.

## Available Images

All images are available from GitHub Container Registry (ghcr.io):

| Service | Image | Description |
|---------|-------|-------------|
| Frontend | `ghcr.io/cnpe-lab/bookstore-frontend:v1.0.0` | React-based frontend |
| API Gateway | `ghcr.io/cnpe-lab/bookstore-api-gateway:v1.0.0` | Node.js API gateway |
| Catalog Service | `ghcr.io/cnpe-lab/bookstore-catalog:v1.0.0` | Product catalog API |
| Order Service | `ghcr.io/cnpe-lab/bookstore-order:v1.0.0` | Order management API |
| User Service | `ghcr.io/cnpe-lab/bookstore-user:v1.0.0` | User authentication API |
| Payment Service | `ghcr.io/cnpe-lab/bookstore-payment:v1.0.0` | Payment processing API |

## Alternative: Using Public Demo Images

If the custom images are not available, use these public alternatives:

| Service | Alternative Image |
|---------|-------------------|
| Frontend | `nginx:1.25-alpine` |
| API Gateway | `nginx:1.25-alpine` |
| Catalog Service | `hashicorp/http-echo:alpine` |
| Order Service | `hashicorp/http-echo:alpine` |
| User Service | `hashicorp/http-echo:alpine` |
| Payment Service | `hashicorp/http-echo:alpine` |

## Usage

Apply the Kustomize overlay to use pre-built images:

```bash
kubectl apply -k images/overlays/prebuilt
```

Or use with ArgoCD:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  source:
    path: capstone-project/solutions/images/overlays/prebuilt
```
