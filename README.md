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

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CNPE Lab Curriculum                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Module 1          Module 2          Module 3          Module 4              │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐         │
│  │Kubernetes│─────►│  GitOps  │─────►│  CI/CD   │─────►│Observ-   │         │
│  │Fundament.│      │ ArgoCD   │      │ Pipelines│      │ability   │         │
│  └──────────┘      └──────────┘      └──────────┘      └──────────┘         │
│       │                                                      │               │
│       │                                                      ▼               │
│       │            Module 5          Module 6          Module 7              │
│       │            ┌──────────┐      ┌──────────┐      ┌──────────┐         │
│       └───────────►│Platform  │─────►│Security  │─────►│Disaster  │         │
│                    │Engineer. │      │Hardening │      │Recovery  │         │
│                    └──────────┘      └──────────┘      └──────────┘         │
│                                                              │               │
│                         Module 8                             │               │
│                         ┌──────────┐                         │               │
│                         │Production│◄────────────────────────┘               │
│                         │Operations│                                         │
│                         └────┬─────┘                                         │
│                              │                                               │
│                              ▼                                               │
│                    ┌─────────────────┐                                       │
│                    │    CAPSTONE     │                                       │
│                    │    PROJECT      │                                       │
│                    └─────────────────┘                                       │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

### [Module 1: Kubernetes Fundamentals](./module-01-k8s-fundamentals/) ⭐ START HERE

Master the foundation of cloud-native engineering with comprehensive hands-on labs.

| Labs | Topics |
|------|--------|
| Lab 1-2 | Cluster setup, Pods, multi-container patterns |
| Lab 3-4 | Deployments, Services, DNS |
| Lab 5-6 | ConfigMaps, Secrets, Storage, StatefulSets |
| Lab 7-8 | Resources, HPA, Debugging |

**Status**: ✅ Complete | **Time**: 19-26 hours | [**📖 Quick Reference**](./module-01-k8s-fundamentals/QUICK-REFERENCE.md)

---

### [Module 2: GitOps & Continuous Delivery](./module-02-gitops/)

GitOps workflows with ArgoCD and progressive delivery patterns.

| Labs | Topics |
|------|--------|
| Lab 1-2 | ArgoCD setup, Application patterns |
| Lab 3-4 | Argo Rollouts, Workflows |
| Lab 5-6 | Multi-cluster, Advanced patterns |

**Status**: ✅ Complete | **Time**: 8-10 hours | [**📖 Quick Reference**](./module-02-gitops/QUICK-REFERENCE.md)

---

### [Module 3: CI/CD Pipelines](./module-03-cicd/)

Build comprehensive CI/CD pipelines with GitHub Actions and Tekton.

| Labs | Topics |
|------|--------|
| Lab 1-2 | GitHub Actions, Container builds |
| Lab 3-4 | Tekton, GitOps integration |
| Lab 5-6 | Testing, Advanced patterns |

**Status**: ✅ Complete | **Time**: 8-10 hours | [**📖 Quick Reference**](./module-03-cicd/QUICK-REFERENCE.md)

---

### [Module 4: Observability](./module-04-observability/)

Set up comprehensive monitoring, logging, and tracing with Prometheus, Grafana, and Loki.

| Labs | Topics |
|------|--------|
| Lab 1-2 | Prometheus, Grafana dashboards |
| Lab 3-4 | Loki logging, Distributed tracing |
| Lab 5-6 | Alerting, Advanced observability |

**Status**: ✅ Complete | **Time**: 8-10 hours | [**📖 Quick Reference**](./module-04-observability/QUICK-REFERENCE.md)

---

### [Module 5: Platform Engineering](./module-05-platform/)

Build internal developer platforms with Backstage and Crossplane.

| Labs | Topics |
|------|--------|
| Lab 1-2 | Backstage, Crossplane |
| Lab 3-4 | Golden paths, Automation |
| Lab 5-6 | Cost management, Multi-tenancy |

**Status**: ✅ Complete | **Time**: 8-10 hours | [**📖 Quick Reference**](./module-05-platform/QUICK-REFERENCE.md)

---

### [Module 6: Security](./module-06-security/)

Implement comprehensive security hardening for Kubernetes clusters.

| Labs | Topics |
|------|--------|
| Lab 1-2 | Cluster security, Pod security |
| Lab 3-4 | Network policies, Secrets management |
| Lab 5-6 | Supply chain, Runtime security |

**Status**: ✅ Complete | **Time**: 8-10 hours | [**📖 Quick Reference**](./module-06-security/QUICK-REFERENCE.md)

---

### [Module 7: Disaster Recovery](./module-07-disaster-recovery/)

Implement backup strategies and disaster recovery procedures.

| Labs | Topics |
|------|--------|
| Lab 1-2 | Backup strategies, Velero |
| Lab 3-4 | DR planning, Chaos engineering |

**Status**: ✅ Complete | **Time**: 6-8 hours | [**📖 Quick Reference**](./module-07-disaster-recovery/QUICK-REFERENCE.md)

---

### [Module 8: Production Operations](./module-08-production-operations/)

Master day-2 operations, upgrades, troubleshooting, and capacity planning.

| Labs | Topics |
|------|--------|
| Lab 1-2 | Day 2 operations, Cluster upgrades |
| Lab 3-4 | Troubleshooting, Cost optimization |
| Lab 5 | Capacity planning |

**Status**: ✅ Complete | **Time**: 8-10 hours | [**📖 Quick Reference**](./module-08-production-operations/QUICK-REFERENCE.md)

---

### [🏆 Capstone Project](./capstone-project/)

**Build a Production-Ready Cloud Native Platform**

Integrate all skills from Modules 1-8 to build and operate a complete platform:

| Phase | Focus |
|-------|-------|
| Phase 1 | Foundation - Cluster & GitOps |
| Phase 2 | Application - Microservices & CI/CD |
| Phase 3 | Observability - Monitoring & Logging |
| Phase 4 | Security - Hardening & Policies |
| Phase 5 | Reliability - DR & Operations |
| Phase 6 | Final Validation |

**Status**: ✅ Complete | **Time**: 8-12 hours | **Difficulty**: Advanced

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
