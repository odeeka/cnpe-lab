# Module 6: Security - Completion Checklist

## Overview

Use this checklist to track your progress through the Security module. Each lab builds upon previous concepts, so complete them in order.

---

## Pre-Module Requirements

- [ ] Completed Modules 1-5
- [ ] Kubernetes cluster running (1.28+)
- [ ] kubectl configured with admin access
- [ ] Helm 3.x installed
- [ ] Basic Linux security knowledge

---

## Lab 1: Cluster Security Fundamentals

### Concepts
- [ ] Understand Kubernetes authentication methods
- [ ] Understand X.509 certificate-based auth
- [ ] Understand RBAC components (Role, ClusterRole, Binding)

### Hands-On
- [ ] Create user certificate and CSR
- [ ] Create custom Role with specific permissions
- [ ] Create RoleBinding to bind role to user
- [ ] Create ClusterRole for cluster-wide access
- [ ] Use `kubectl auth can-i` for permission checking
- [ ] Implement RBAC aggregation
- [ ] Create ServiceAccount with limited permissions
- [ ] Disable token auto-mounting
- [ ] Create audience-bound tokens
- [ ] Understand audit policy levels
- [ ] Create comprehensive audit policy

### Key Commands Mastered
- [ ] `kubectl create role`
- [ ] `kubectl create rolebinding`
- [ ] `kubectl create clusterrole`
- [ ] `kubectl create clusterrolebinding`
- [ ] `kubectl auth can-i`
- [ ] `kubectl create serviceaccount`
- [ ] `kubectl create token`

---

## Lab 2: Pod Security

### Concepts
- [ ] Understand Pod Security Standards (Privileged, Baseline, Restricted)
- [ ] Understand Pod Security Admission modes (Enforce, Audit, Warn)
- [ ] Understand security context hierarchy

### Hands-On
- [ ] Label namespace with PSA labels
- [ ] Create pods compliant with each PSS level
- [ ] Configure pod-level security context
- [ ] Configure container-level security context
- [ ] Enable read-only root filesystem
- [ ] Prevent privilege escalation
- [ ] Drop all capabilities
- [ ] Add specific required capabilities
- [ ] Apply RuntimeDefault seccomp profile
- [ ] Understand AppArmor profiles
- [ ] Create production-ready secure pod

### Key Commands Mastered
- [ ] `kubectl label namespace` (PSA labels)
- [ ] Dry-run pod creation to test PSA
- [ ] Query pod security context

---

## Lab 3: Network Security

### Concepts
- [ ] Understand Kubernetes network model
- [ ] Understand NetworkPolicy selectors
- [ ] Understand ingress vs egress policies

### Hands-On
- [ ] Create test environment (frontend, backend, database)
- [ ] Create simple ingress NetworkPolicy
- [ ] Create simple egress NetworkPolicy
- [ ] Implement default deny all ingress
- [ ] Implement default deny all egress
- [ ] Allow DNS egress
- [ ] Create cross-namespace policies
- [ ] Use namespaceSelector AND podSelector
- [ ] Use namespaceSelector OR podSelector
- [ ] Create IP block policies
- [ ] Block cloud metadata service
- [ ] Understand Cilium L7 policies
- [ ] Understand service mesh mTLS

### Key Commands Mastered
- [ ] `kubectl get networkpolicy`
- [ ] Network connectivity testing
- [ ] Debug network policy issues

---

## Lab 4: Secrets Management

### Concepts
- [ ] Understand Kubernetes Secrets limitations
- [ ] Understand encryption at rest
- [ ] Understand external secret management

### Hands-On
- [ ] Create native Kubernetes secrets
- [ ] Use secrets as environment variables
- [ ] Mount secrets as volumes
- [ ] Install HashiCorp Vault
- [ ] Configure Vault KV engine
- [ ] Configure Kubernetes auth in Vault
- [ ] Use Vault Agent Injector
- [ ] Install External Secrets Operator
- [ ] Create SecretStore
- [ ] Create ExternalSecret
- [ ] Use ClusterSecretStore
- [ ] Create templated ExternalSecret
- [ ] Install Sealed Secrets
- [ ] Seal secrets with kubeseal
- [ ] Understand sealed secret scopes
- [ ] Implement secret rotation strategies

### Key Commands Mastered
- [ ] `kubectl create secret`
- [ ] `vault` CLI commands
- [ ] `kubeseal` CLI
- [ ] ExternalSecret configuration

---

## Lab 5: Image and Supply Chain Security

> Note: To be completed when lab is created

### Concepts
- [ ] Understand supply chain security
- [ ] Understand image scanning
- [ ] Understand image signing

### Hands-On
- [ ] Scan images with Trivy
- [ ] Sign images with Cosign
- [ ] Verify image signatures
- [ ] Create Kyverno policies
- [ ] Generate SBOM

---

## Lab 6: Runtime Security

> Note: To be completed when lab is created

### Concepts
- [ ] Understand runtime threat detection
- [ ] Understand CIS benchmarks
- [ ] Understand security scanning

### Hands-On
- [ ] Deploy Falco
- [ ] Create custom Falco rules
- [ ] Run kubescape scans
- [ ] Implement incident response

---

## Assessment

- [ ] Section 1: RBAC and Authentication (20 points)
  - [ ] Task 1.1: Create Developer Role
  - [ ] Task 1.2: Create Service Account and Binding
  - [ ] Task 1.3: Create Read-Only ClusterRole
  - [ ] Task 1.4: Restrict Secret Access
  - [ ] Task 1.5: Aggregated ClusterRole

- [ ] Section 2: Pod Security (20 points)
  - [ ] Task 2.1: Configure Namespace Security
  - [ ] Task 2.2: Create Hardened Pod
  - [ ] Task 2.3: Create Secure Deployment
  - [ ] Task 2.4: Configure Restricted Namespace
  - [ ] Task 2.5: Fix Insecure Pod

- [ ] Section 3: Network Security (20 points)
  - [ ] Task 3.1: Default Deny Policy
  - [ ] Task 3.2: Allow DNS
  - [ ] Task 3.3: Application Network Policy
  - [ ] Task 3.4: Monitoring Access
  - [ ] Task 3.5: Block Metadata Service

- [ ] Section 4: Secrets Management (20 points)
  - [ ] Task 4.1: Create Application Secrets
  - [ ] Task 4.2: Use Secrets in Pod
  - [ ] Task 4.3: External Secrets Configuration
  - [ ] Task 4.4: Sealed Secret
  - [ ] Task 4.5: RBAC for Secrets

- [ ] Section 5: Security Monitoring (20 points)
  - [ ] Task 5.1: Audit Policy
  - [ ] Task 5.2: Security Compliance Check Script
  - [ ] Task 5.3: Falco Rule
  - [ ] Task 5.4: Security Remediation
  - [ ] Task 5.5: Security Report

---

## Skills Validation

After completing this module, you should be able to:

### RBAC & Authentication
- [ ] Design and implement least-privilege RBAC policies
- [ ] Create and manage service accounts securely
- [ ] Configure Kubernetes authentication methods
- [ ] Audit and review RBAC permissions

### Pod Security
- [ ] Implement Pod Security Standards across namespaces
- [ ] Configure comprehensive security contexts
- [ ] Manage Linux capabilities appropriately
- [ ] Apply Seccomp and AppArmor profiles

### Network Security
- [ ] Design zero-trust network architecture
- [ ] Implement default deny policies
- [ ] Create granular network policies
- [ ] Debug network connectivity issues

### Secrets Management
- [ ] Integrate external secret providers
- [ ] Implement GitOps-safe secret management
- [ ] Configure secret rotation
- [ ] Secure secrets with RBAC

### Security Monitoring
- [ ] Create audit policies for compliance
- [ ] Deploy runtime security monitoring
- [ ] Write security compliance scripts
- [ ] Respond to security incidents

---

## Common Exam Topics

Based on CNPE exam objectives, focus on:

1. **RBAC**
   - Creating roles and bindings
   - Service account management
   - Permission checking and debugging

2. **Pod Security**
   - Pod Security Standards/Admission
   - Security contexts
   - Capability management

3. **Network Policies**
   - Default deny strategies
   - Cross-namespace policies
   - Ingress/egress rules

4. **Secrets**
   - Native secrets usage
   - External secrets integration
   - RBAC for secrets

5. **Compliance**
   - CIS benchmarks
   - Security scanning
   - Audit logging

---

## Module Completion

- [ ] All labs completed
- [ ] Assessment passed (≥70%)
- [ ] Key commands practiced
- [ ] Concepts understood

**Date Completed:** _____________

**Assessment Score:** _____ / 100

**Notes:**
```




```

---

## Next Steps

After completing this module:
1. Review any weak areas identified in assessment
2. Practice scenarios under time pressure
3. Continue to Module 7: Disaster Recovery (when available)
