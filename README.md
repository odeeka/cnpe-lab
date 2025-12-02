# cnpe-lab

Certified Cloud Native Platform Engineer Lab

[Platforms Whitepapers](https://tag-app-delivery.cncf.io/whitepapers/platforms/)

## Quick Start

Install `kind` -> https://kind.sigs.k8s.io/docs/user/quick-start/

```bash
cd base
kind create cluster --config kind-cluster.yaml
```

## Learning Modules

### [Module 1: Kubernetes Fundamentals & Container Basics](./module-01-k8s-fundamentals/) ⭐ START HERE

Master the foundation of cloud-native engineering with comprehensive hands-on labs:

**What's Covered:**
- 🎯 **Lab 1**: Cluster setup, kubectl mastery, architecture
- 🎯 **Lab 2**: Pods, multi-container patterns, init containers
- 🎯 **Lab 3**: Deployments, scaling, rolling updates, rollbacks
- 🎯 **Lab 4**: Services (ClusterIP, NodePort, LoadBalancer), DNS
- 🎯 **Lab 5**: ConfigMaps, Secrets, configuration management
- 🎯 **Lab 6**: Storage (PV/PVC), StatefulSets, dynamic provisioning
- 🎯 **Lab 7**: Resource management, QoS, HPA, ResourceQuotas
- 🎯 **Lab 8**: Debugging, troubleshooting, health checks

**Status**: ✅ **COMPLETE** - 8 labs + comprehensive assessment
**Time**: 19-26 hours (12-16 hours labs + 3-4 hours assessment + review)
**Prerequisites**: Docker, kubectl, kind installed
**Assessment**: 20 practical tasks (70% to pass)

[**📖 Quick Reference Guide**](./module-01-k8s-fundamentals/QUICK-REFERENCE.md) | [**🎯 Start Lab 1**](./module-01-k8s-fundamentals/lab-01-setup/)

---

### Module 2: GitOps & Continuous Delivery (Coming Soon)

- ArgoCD installation and GitOps workflows
- Progressive delivery (Canary, Blue/Green)
- Argo Rollouts and deployment strategies
- Multi-cluster management

### Module 3: Infrastructure as Code (Planned)

- Terraform for Kubernetes
- Crossplane for cloud-native IaC
- Helm charts and Kustomize

### Module 4: Developer Portals (Planned)

- Backstage.io platform
- Software templates
- Service catalog design

### Module 5: Observability (Planned)

- OpenTelemetry setup
- Prometheus & Grafana
- Distributed tracing

### Module 6: Security & Policy (Planned)

- Kyverno policy engine
- Image signing with Cosign
- Runtime security with Falco

---

## CNPE Subjects

| **Téma**                                                | **Lényeges technológiák / eszközök**                                                                                                            |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| **Web portals for observing and provisioning products** | Backstage, Port, Humanitec, IDPs, Service Catalog, Internal Dashboards, Developer Portals                                                      |
| **APIs & CLIs for provisioning products/capabilities**  | REST API, GraphQL, OpenAPI/Swagger, Terraform Provider development, Crossplane, gRPC, Custom Kubernetes Operators, kubectl/plugins              |
| **“Golden path” templates & documentation**             | Backstage Software Templates, Cookiecutter, Helm Chart skeleton, Kustomize overlays, GitHub Templates, IaC module templates                     |
| **Automation for building & testing**                   | GitHub Actions, Azure DevOps Pipelines, Tekton, Jenkins, BuildKit, Kaniko, Trivy (SAST/SCA), Snyk, CodeQL                                       |
| **Automation for delivery & verification**              | ArgoCD, Argo Rollouts, FluxCD, GitOps, Progressive Delivery (Canary, Blue/Green), CI/CD gating, Cosign verify                                   |
| **Developer environments (hosted IDEs, remote tools)**  | GitHub Codespaces, DevContainers, Telepresence, Okteto, minikube/kind, Remote SSH Dev Envs                                                      |
| **Observability (functionality, performance, cost)**    | OpenTelemetry, Prometheus, Grafana, Loki, Tempo/Jaeger, Azure Monitor, Kiali, Alerts & SLO monitoring                                           |
| **Infrastructure services (compute, network, storage)** | Kubernetes (AKS/EKS/GKE), CSI drivers, Nginx Ingress / AGIC / Gateway API, VNet/Subnet, Load Balancers (L4/L7), Private Link, NAT Gateway, VMSS |
| **Data services (databases, caches, object stores)**    | PostgreSQL/MySQL (managed), Redis, Cosmos DB, MongoDB, MinIO/S3, ETL pipelines, Backup/restore tooling                                          |
| **Messaging & event services**                          | Kafka, RabbitMQ, Azure EventHub, NATS, CloudEvents, MQTT brokers, Event-driven architecture tools                                               |
| **Identity & secret management**                        | Azure AD / Workload Identity, Managed Identities, Cert-Manager, External Secrets Operator, Vault, Key Vault, OIDC federation, PKI tooling       |
| **Security services (static, runtime, policy)**         | Trivy, Snyk, Falco (runtime), Kyverno, OPA/Gatekeeper, Cosign (image signing), SBOM (Syft), CI security scans                                   |
| **Artifact storage (images, packages, binaries)**       | Azure Container Registry (ACR), Harbor, GitHub Packages, OCI Registry for Helm, Language-specific registries (npm, PyPI, Maven), Binary repos   |

## Example tasks

1. Terraform provisioning + modularized IaC
2. Private AKS
3. ArgoCD + GitOps
4. Backstage developer portal
5. ACR + KeyVault + PostgreSQL + Redis
6. OpenTelemetry observability pipeline
7. CI/CD pipeline (build + scan + sign + deploy)
8. Zero Trust access with Cloudflare Tunnel
9. Self-service golden path template
10. Policy enforcement with Kyverno
