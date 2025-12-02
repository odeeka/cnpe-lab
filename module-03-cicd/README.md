# Module 3: CI/CD Pipelines

## Learning Objectives

By the end of this module, you will be able to:

- Design and implement CI/CD pipelines for cloud-native applications
- Build container images efficiently with multi-stage builds
- Use GitHub Actions for continuous integration workflows
- Deploy Tekton Pipelines on Kubernetes
- Integrate CI systems with GitOps workflows
- Implement security scanning and quality gates
- Create reusable pipeline components

## Topics Covered

1. **CI/CD Fundamentals**
   - Continuous Integration principles
   - Continuous Delivery vs Continuous Deployment
   - Pipeline design patterns
   - Build artifact management
   - Environment promotion strategies

2. **GitHub Actions**
   - Workflow syntax and structure
   - Triggers and events
   - Jobs, steps, and actions
   - Secrets and environment management
   - Self-hosted runners
   - Reusable workflows and composite actions

3. **Container Image Building**
   - Dockerfile best practices
   - Multi-stage builds for optimization
   - BuildKit features and caching
   - Kaniko for in-cluster builds
   - Image signing and attestation
   - Registry management

4. **Tekton Pipelines**
   - Tekton architecture and concepts
   - Tasks, Pipelines, and PipelineRuns
   - Workspaces and parameter passing
   - Triggers for event-driven pipelines
   - Catalog and reusable tasks
   - Integration with ArgoCD

5. **Security and Quality**
   - Static code analysis
   - Container vulnerability scanning
   - SBOM generation
   - Policy enforcement with OPA
   - Secret management in pipelines
   - Compliance and audit trails

6. **GitOps Integration**
   - CI triggering CD through Git
   - Image tag promotion strategies
   - ArgoCD Image Updater integration
   - Environment-specific configurations
   - Rollback strategies

## Prerequisites

- Completed Module 1: Kubernetes Fundamentals
- Completed Module 2: GitOps & Continuous Delivery
- Running kind cluster
- GitHub account with repository access
- Docker or container runtime installed
- Basic shell scripting knowledge

## Lab Structure

Each lab includes:

- **Objective**: Clear learning goals
- **Steps**: Detailed hands-on instructions
- **Validation**: Verification commands
- **Challenges**: Additional practice exercises
- **Troubleshooting**: Common issues and solutions

## Labs

### [Lab 1: GitHub Actions Fundamentals](./lab-01-github-actions/)

**Time**: 2-3 hours

- Create your first GitHub Actions workflow
- Understand workflow syntax and triggers
- Use actions from the marketplace
- Configure secrets and variables
- Implement conditional execution
- Create reusable workflows

### [Lab 2: Container Build Pipelines](./lab-02-container-builds/)

**Time**: 3-4 hours

- Write optimized Dockerfiles
- Implement multi-stage builds
- Use BuildKit caching strategies
- Build with Kaniko in Kubernetes
- Push to container registries
- Implement image tagging strategies

### [Lab 3: Tekton Pipelines](./lab-03-tekton/)

**Time**: 3-4 hours

- Install Tekton on Kubernetes
- Create Tasks and Pipelines
- Configure Workspaces and PipelineResources
- Implement Tekton Triggers
- Use Tekton Catalog tasks
- Build and deploy applications

### [Lab 4: CI/CD Integration with GitOps](./lab-04-gitops-integration/)

**Time**: 2-3 hours

- Connect CI pipelines to GitOps
- Implement image tag updates
- Configure ArgoCD Image Updater
- Create promotion workflows
- Handle multi-environment deployments

### [Lab 5: Testing and Quality Gates](./lab-05-testing/)

**Time**: 2-3 hours

- Implement unit and integration tests
- Configure code coverage reporting
- Set up container vulnerability scanning
- Implement policy checks with OPA
- Create quality gate workflows
- Generate SBOMs

### [Lab 6: Advanced Pipeline Patterns](./lab-06-advanced/)

**Time**: 2-3 hours

- Create matrix builds
- Implement pipeline parallelization
- Design monorepo pipelines
- Configure caching strategies
- Handle secrets securely
- Implement rollback pipelines

## Study Tips

1. **Practice with real projects**: Create repositories with actual applications
2. **Understand the CI/CD flow**: From commit to production
3. **Focus on security**: Scanning and secret management are crucial
4. **Learn to debug**: Pipeline failures are common during development
5. **Optimize for speed**: Fast feedback loops improve developer experience

## Reference Materials

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Tekton Documentation](https://tekton.dev/docs/)
- [Dockerfile Best Practices](https://docs.docker.com/develop/develop-images/dockerfile_best-practices/)
- [CNCF CI/CD Landscape](https://landscape.cncf.io/card-mode?category=continuous-integration-delivery)

## Estimated Time

| Component | Time |
|-----------|------|
| Lab 1: GitHub Actions | 2-3 hours |
| Lab 2: Container Builds | 3-4 hours |
| Lab 3: Tekton Pipelines | 3-4 hours |
| Lab 4: GitOps Integration | 2-3 hours |
| Lab 5: Testing & Quality | 2-3 hours |
| Lab 6: Advanced Patterns | 2-3 hours |
| Assessment | 3-4 hours |
| **Total** | **17-24 hours** |

## Module Completion Checklist

- [ ] Created GitHub Actions workflow
- [ ] Built container images with multi-stage Dockerfile
- [ ] Installed and configured Tekton
- [ ] Created Tekton Pipeline with multiple tasks
- [ ] Integrated CI with ArgoCD
- [ ] Implemented container scanning
- [ ] Set up quality gates
- [ ] Completed matrix builds
- [ ] Configured pipeline caching
- [ ] Passed assessment (70%+)

## Assessment

After completing all labs, take the [Module 3 Assessment](./assessment/) to validate your CI/CD knowledge. The assessment includes:

- Creating GitHub Actions workflows
- Building and scanning container images
- Implementing Tekton Pipelines
- Integrating with GitOps
- Implementing security best practices

**Passing Score**: 70% (14/20 tasks)

---

[**Start Lab 1: GitHub Actions Fundamentals**](./lab-01-github-actions/) | [Back to Main README](../README.md)
