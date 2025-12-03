# Module 5: Platform Engineering

## Overview

Platform Engineering is the discipline of building and maintaining internal developer platforms (IDPs) that enable self-service capabilities for development teams. This module covers the tools, patterns, and practices for creating platforms that improve developer experience while maintaining governance and security.

## Learning Objectives

By the end of this module, you will be able to:

- Design and implement internal developer platforms
- Deploy and configure Backstage developer portals
- Create self-service infrastructure provisioning
- Build golden paths and software templates
- Implement platform automation with Crossplane
- Manage costs and resources across teams
- Design multi-tenant Kubernetes environments

## Prerequisites

- Completed Modules 1-4 (Kubernetes, GitOps, CI/CD, Observability)
- Understanding of Kubernetes operators
- Familiarity with Helm and Kustomize
- Basic knowledge of infrastructure as code

## Module Structure

### Lab 1: Developer Portals with Backstage

Build a developer portal for service catalog and documentation:

- Backstage architecture and components
- Service catalog configuration
- Software templates (scaffolding)
- TechDocs integration
- Plugin ecosystem
- Authentication and authorization

### Lab 2: Self-Service Infrastructure

Enable teams to provision infrastructure on demand:

- Crossplane fundamentals
- Composite Resource Definitions (XRDs)
- Compositions and claims
- Provider configuration
- Resource provisioning workflows
- GitOps integration

### Lab 3: Golden Paths and Templates

Create standardized paths for common development scenarios:

- Template design principles
- Scaffolding new services
- Repository templates
- CI/CD pipeline templates
- Infrastructure templates
- Compliance-as-code in templates

### Lab 4: Platform Automation

Automate platform operations and maintenance:

- Kubernetes operators for platforms
- Custom controllers
- Reconciliation patterns
- Event-driven automation
- Platform APIs
- CLI tools for developers

### Lab 5: Cost Management and FinOps

Implement cost visibility and optimization:

- Resource quota management
- Cost allocation and showback
- Kubecost deployment
- Budget alerts and policies
- Right-sizing recommendations
- Spot instance strategies

### Lab 6: Multi-Tenancy Patterns

Design secure multi-tenant platforms:

- Namespace-based isolation
- Virtual clusters (vCluster)
- Hierarchical namespaces
- Network policies for tenants
- Resource quotas per tenant
- RBAC for multi-tenancy

## The Platform Engineering Mindset

```
┌─────────────────────────────────────────────────────────────────┐
│                    INTERNAL DEVELOPER PLATFORM                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Developer Experience Layer                                      │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │  Developer   │ │   Golden     │ │    Self-     │             │
│  │   Portal     │ │   Paths      │ │   Service    │             │
│  └──────────────┘ └──────────────┘ └──────────────┘             │
│                                                                  │
│  Platform Services Layer                                         │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │   Service    │ │  Secrets     │ │ Observability│             │
│  │   Mesh       │ │  Management  │ │   Stack      │             │
│  └──────────────┘ └──────────────┘ └──────────────┘             │
│                                                                  │
│  Infrastructure Layer                                            │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐             │
│  │  Kubernetes  │ │   Cloud      │ │   GitOps     │             │
│  │  Clusters    │ │  Resources   │ │   Engine     │             │
│  └──────────────┘ └──────────────┘ └──────────────┘             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### Platform as a Product

- Treat the platform as a product with internal customers
- Focus on developer experience (DevEx)
- Gather feedback and iterate
- Measure platform adoption and satisfaction

### Self-Service with Guardrails

- Enable autonomy for development teams
- Implement sensible defaults
- Enforce policies automatically
- Reduce cognitive load

### Golden Paths

- Paved roads for common scenarios
- Best practices built-in
- Optional but compelling
- Reduce decision fatigue

## Tools Covered

| Tool | Purpose |
|------|---------|
| Backstage | Developer portal and service catalog |
| Crossplane | Infrastructure provisioning |
| vCluster | Virtual Kubernetes clusters |
| Kubecost | Cost management and allocation |
| Hierarchical Namespaces | Multi-tenancy isolation |
| Argo CD | GitOps deployment |
| External Secrets | Secrets management |

## Time Estimate

| Component | Duration |
|-----------|----------|
| Lab 1: Developer Portals | 90 minutes |
| Lab 2: Self-Service Infrastructure | 90 minutes |
| Lab 3: Golden Paths | 75 minutes |
| Lab 4: Platform Automation | 90 minutes |
| Lab 5: Cost Management | 60 minutes |
| Lab 6: Multi-Tenancy | 75 minutes |
| Assessment | 180 minutes |
| **Total** | **~11 hours** |

## Success Criteria

After completing this module, you should be able to:

- [ ] Deploy and configure Backstage
- [ ] Create software templates for new services
- [ ] Set up Crossplane for infrastructure provisioning
- [ ] Design and implement golden paths
- [ ] Build custom platform automation
- [ ] Implement cost visibility and allocation
- [ ] Configure multi-tenant Kubernetes clusters

## Additional Resources

- [Backstage Documentation](https://backstage.io/docs)
- [Crossplane Documentation](https://crossplane.io/docs)
- [Platform Engineering Guide](https://platformengineering.org)
- [CNCF Platforms White Paper](https://tag-app-delivery.cncf.io/whitepapers/platforms/)
- [Team Topologies](https://teamtopologies.com)

---

Continue to [Lab 1: Developer Portals](./lab-01-backstage/README.md) to begin building your internal developer platform.
