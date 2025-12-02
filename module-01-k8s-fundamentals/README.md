# Module 1: Kubernetes Fundamentals & Container Basics

## Learning Objectives

By the end of this module, you will be able to:

- Understand container architecture and lifecycle
- Deploy and manage Kubernetes clusters (kind, minikube)
- Master core Kubernetes resources (Pods, Deployments, Services, ConfigMaps, Secrets)
- Implement resource management and scheduling
- Configure networking basics (ClusterIP, NodePort, LoadBalancer)
- Understand Kubernetes storage (Volumes, PersistentVolumes, PersistentVolumeClaims)
- Debug and troubleshoot running applications

## Topics Covered

1. **Container Basics**
   - Container vs VM architecture
   - Docker/Containerd fundamentals
   - Image layers and optimization
   - Multi-stage builds

2. **Kubernetes Architecture**
   - Control plane components
   - Worker node components
   - etcd and cluster state
   - API server interaction

3. **Core Workload Resources**
   - Pods lifecycle and patterns
   - ReplicaSets and Deployments
   - StatefulSets for stateful apps
   - DaemonSets and Jobs
   - CronJobs for scheduled tasks

4. **Configuration & Secrets**
   - ConfigMaps for configuration
   - Secrets management
   - Environment variables vs volumes
   - Immutable ConfigMaps/Secrets

5. **Networking Fundamentals**
   - Kubernetes networking model
   - Service types and use cases
   - DNS in Kubernetes
   - Network policies basics

6. **Storage Basics**
   - Volume types
   - PersistentVolumes (PV)
   - PersistentVolumeClaims (PVC)
   - StorageClasses

## Prerequisites

- Docker installed
- kind installed (already configured in your repo)
- kubectl installed
- Basic Linux command line knowledge
- Text editor (VS Code recommended)

## Lab Structure

Each lab is self-contained with:

- **Objective**: What you'll learn
- **Steps**: Detailed instructions
- **Validation**: How to verify success
- **Cleanup**: Resource removal
- **Troubleshooting**: Common issues

## Labs

### [Lab 1: Setting Up Your Environment](./lab-01-setup/)

**Time**: 45-60 minutes

Set up kind cluster, explore kubectl, understand cluster architecture, master basic commands

### [Lab 2: Working with Pods](./lab-02-pods/)

**Time**: 90-120 minutes

Create pods, understand lifecycle, multi-container patterns (sidecar, init containers), debugging

### [Lab 3: Deployments & ReplicaSets](./lab-03-deployments/)

**Time**: 90-120 minutes

Create deployments, scale applications, perform rolling updates and rollbacks, deployment strategies

### [Lab 4: Services & Networking](./lab-04-services/)

**Time**: 90-120 minutes

Expose applications using ClusterIP, NodePort, LoadBalancer, headless services, DNS discovery

### [Lab 5: ConfigMaps & Secrets](./lab-05-config-secrets/)

**Time**: 90-120 minutes

Manage application configuration and sensitive data, environment variables vs volumes, TLS secrets

### [Lab 6: Storage & Persistence](./lab-06-storage/)

**Time**: 120-150 minutes

Work with volumes, PVs, PVCs, StorageClasses, StatefulSets, dynamic provisioning

### [Lab 7: Resource Management & Autoscaling](./lab-07-resources/)

**Time**: 120-150 minutes

Configure resource requests/limits, QoS classes, LimitRanges, HPA, ResourceQuotas, Priority

### [Lab 8: Debugging & Troubleshooting](./lab-08-debugging/)

**Time**: 120-150 minutes

Debug failing pods, analyze logs, exec into containers, ephemeral debug containers, health checks

## Study Tips

1. **Hands-on Practice**: Do each lab multiple times until comfortable
2. **Kubectl Mastery**: Practice kubectl commands without looking them up
3. **Read Documentation**: Official Kubernetes docs are your best friend
4. **Understand YAML**: Get comfortable reading and writing Kubernetes manifests
5. **Delete and Recreate**: Practice creating resources from memory

## Reference Materials

- [Kubernetes Official Documentation](https://kubernetes.io/docs/)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [Kubernetes API Reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- [kind Documentation](https://kind.sigs.k8s.io/)

## Estimated Time

- **Labs 1-8**: ~12-16 hours (hands-on practice)
- **Review & Practice**: 4-6 hours
- **Assessment**: 3-4 hours
- **Total: 19-26 hours**

## Module Completion Checklist

- [ ] Completed Lab 1: Setup & kubectl basics
- [ ] Completed Lab 2: Pods & multi-container patterns
- [ ] Completed Lab 3: Deployments & scaling
- [ ] Completed Lab 4: Services & networking
- [ ] Completed Lab 5: ConfigMaps & Secrets
- [ ] Completed Lab 6: Storage & persistence
- [ ] Completed Lab 7: Resource management & autoscaling
- [ ] Completed Lab 8: Debugging & troubleshooting
- [ ] Can create resources without referring to docs
- [ ] Understand when to use each Service type
- [ ] Can troubleshoot common pod failures
- [ ] Understand resource requests vs limits
- [ ] Can configure apps using ConfigMaps/Secrets
- [ ] Understand PV/PVC relationship
- [ ] Passed the [Module Assessment](./assessment/) (70%+)

## Assessment

Test your knowledge with the [Module 1 Assessment](./assessment/) - a comprehensive practical exam with 20 tasks covering all topics.

**Format**: Hands-on challenges
**Duration**: 3-4 hours
**Passing Score**: 70% (14/20 tasks)
**Difficulty**: Intermediate

---

**Next Module**: [Module 2: Advanced Kubernetes Patterns & GitOps](../module-02-gitops/)
