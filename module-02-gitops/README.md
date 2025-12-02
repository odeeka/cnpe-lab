# Module 2: GitOps & Continuous Delivery

## Learning Objectives

By the end of this module, you will be able to:

- Understand GitOps principles and why they matter for platform engineering
- Install and configure ArgoCD in a Kubernetes cluster
- Deploy applications using GitOps workflows
- Implement progressive delivery strategies (Canary, Blue/Green)
- Manage multiple environments and clusters with GitOps
- Troubleshoot sync issues and implement best practices

## Topics Covered

1. **GitOps Fundamentals**
   - What is GitOps and why it matters
   - GitOps vs traditional CI/CD
   - Git as the single source of truth
   - Pull vs Push deployment models
   - Benefits: Auditability, reproducibility, disaster recovery

2. **ArgoCD Architecture**
   - Core components (API Server, Repo Server, Application Controller)
   - Application CRD and sync process
   - Multi-tenancy with Projects
   - RBAC and SSO integration
   - High availability considerations

3. **Application Deployment Patterns**
   - Kustomize overlays for environments
   - Helm charts with ArgoCD
   - Plain YAML manifests
   - Jsonnet and other config tools
   - App of Apps pattern
   - ApplicationSets for scaling

4. **Progressive Delivery with Argo Rollouts**
   - Canary deployments
   - Blue/Green deployments
   - Analysis and metrics-based promotion
   - Automated rollbacks
   - Traffic management integration

5. **GitOps Workflows**
   - Repository structure patterns
   - Environment promotion strategies
   - Secret management approaches
   - Sync policies and waves
   - Hooks and resource ordering

6. **Multi-Cluster GitOps**
   - Cluster registration and management
   - ApplicationSets with generators
   - Hub and spoke architecture
   - Fleet management patterns

## Prerequisites

- Completed Module 1: Kubernetes Fundamentals
- Running kind cluster (from Module 1)
- kubectl configured
- Git basics (clone, commit, push)
- GitHub account (for GitOps repositories)

## Lab Structure

Each lab is self-contained with:

- **Objective**: What you'll learn
- **Steps**: Detailed instructions with commands
- **Validation**: How to verify success
- **Challenges**: Extra practice exercises
- **Troubleshooting**: Common issues and solutions

## Labs

### [Lab 1: ArgoCD Installation & Basics](./lab-01-argocd-setup/)

**Time**: 2-3 hours

- Install ArgoCD in your kind cluster
- Access the ArgoCD UI and CLI
- Understand GitOps principles in practice
- Deploy your first application via Git
- Explore sync status and health checks

### [Lab 2: Application Deployment Patterns](./lab-02-app-patterns/)

**Time**: 3-4 hours

- Deploy applications with Kustomize overlays
- Use Helm charts with ArgoCD
- Implement App of Apps pattern
- Create ApplicationSets for multiple environments
- Manage application dependencies

### [Lab 3: Progressive Delivery with Argo Rollouts](./lab-03-rollouts/)

**Time**: 3-4 hours

- Install Argo Rollouts
- Implement Canary deployments with traffic shifting
- Configure Blue/Green deployments
- Set up analysis templates with metrics
- Implement automated rollbacks

### [Lab 4: GitOps Workflows & Best Practices](./lab-04-workflows/)

**Time**: 2-3 hours

- Design GitOps repository structures
- Implement environment promotion
- Configure sync policies and waves
- Use hooks for resource ordering
- Implement secret management strategies

### [Lab 5: Multi-Cluster GitOps](./lab-05-multi-cluster/)

**Time**: 2-3 hours

- Register multiple clusters with ArgoCD
- Use ApplicationSets with cluster generators
- Implement hub and spoke patterns
- Configure cluster-specific overrides
- Plan disaster recovery strategies

### [Lab 6: Advanced Topics & Operations](./lab-06-advanced/)

**Time**: 2-3 hours

- Configure RBAC and Projects
- Set up notifications (Slack, webhooks)
- Use ArgoCD Image Updater
- Implement drift detection and remediation
- Troubleshoot common sync issues

## Study Tips

1. **Practice daily**: GitOps becomes intuitive with repetition
2. **Use real repositories**: Create GitHub repos for your practice
3. **Break things intentionally**: Learn how ArgoCD handles drift and failures
4. **Read the sync status**: Understanding sync states is crucial
5. **Explore the UI and CLI**: Both are important for the exam

## Reference Materials

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Argo Rollouts Documentation](https://argo-rollouts.readthedocs.io/)
- [GitOps Principles - OpenGitOps](https://opengitops.dev/)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery/tree/main/gitops-wg)

## Estimated Time

| Component | Time |
|-----------|------|
| Lab 1: ArgoCD Setup | 2-3 hours |
| Lab 2: Application Patterns | 3-4 hours |
| Lab 3: Argo Rollouts | 3-4 hours |
| Lab 4: GitOps Workflows | 2-3 hours |
| Lab 5: Multi-Cluster | 2-3 hours |
| Lab 6: Advanced Topics | 2-3 hours |
| Assessment | 3-4 hours |
| **Total** | **17-24 hours** |

## Module Completion Checklist

- [ ] ArgoCD installed and accessible
- [ ] Deployed application via GitOps
- [ ] Implemented Kustomize overlays
- [ ] Created Helm-based ArgoCD Application
- [ ] Set up App of Apps pattern
- [ ] Configured Canary deployment with Rollouts
- [ ] Implemented Blue/Green deployment
- [ ] Set up environment promotion workflow
- [ ] Registered multiple clusters (simulated)
- [ ] Configured RBAC and Projects
- [ ] Completed all practice challenges
- [ ] Passed assessment (70%+)

## Assessment

After completing all labs, take the [Module 2 Assessment](./assessment/) to validate your GitOps and ArgoCD knowledge. The assessment includes:

- Installing and configuring ArgoCD
- Setting up GitOps repositories
- Implementing progressive delivery
- Troubleshooting sync issues
- Multi-environment management

**Passing Score**: 70% (14/20 tasks)

---

[**Start Lab 1: ArgoCD Installation**](./lab-01-argocd-setup/) | [Back to Main README](../README.md)
