# Module 6: Kubernetes Security

## Overview

Security is a critical aspect of running Kubernetes in production. This module covers comprehensive security practices from cluster hardening to runtime threat detection, following the defense-in-depth principle.

## The 4Cs of Cloud Native Security

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLOUD NATIVE SECURITY                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                        CLOUD                               │  │
│  │  Infrastructure security, IAM, network perimeter          │  │
│  │  ┌─────────────────────────────────────────────────────┐  │  │
│  │  │                     CLUSTER                          │  │  │
│  │  │  API security, RBAC, admission control, audit       │  │  │
│  │  │  ┌───────────────────────────────────────────────┐  │  │  │
│  │  │  │                  CONTAINER                     │  │  │  │
│  │  │  │  Image security, runtime, isolation           │  │  │  │
│  │  │  │  ┌─────────────────────────────────────────┐  │  │  │  │
│  │  │  │  │                 CODE                     │  │  │  │  │
│  │  │  │  │  Dependencies, secrets, input           │  │  │  │  │
│  │  │  │  └─────────────────────────────────────────┘  │  │  │  │
│  │  │  └───────────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Learning Objectives

By the end of this module, you will be able to:

- Implement comprehensive RBAC policies
- Configure Pod Security Standards and Admission
- Design and apply Network Policies
- Manage secrets securely with external providers
- Implement supply chain security with image signing
- Deploy runtime security monitoring

## Prerequisites

- Completed Modules 1-5
- Understanding of Kubernetes architecture
- Familiarity with Linux security concepts
- kubectl configured with cluster access

---

## Module Structure

### Lab 1: Cluster Security Fundamentals
Learn the foundations of Kubernetes security including authentication, authorization, and audit logging.

**Topics:**
- Kubernetes security model
- API server authentication methods
- RBAC deep dive
- Service account security
- Audit logging

**Duration:** 90 minutes

---

### Lab 2: Pod Security
Implement workload isolation and security controls at the pod level.

**Topics:**
- Pod Security Standards
- Pod Security Admission
- Security contexts
- Capabilities management
- Seccomp and AppArmor

**Duration:** 75 minutes

---

### Lab 3: Network Security
Design and implement network segmentation and traffic control.

**Topics:**
- Network Policies
- Ingress/Egress rules
- Default deny strategies
- Cilium advanced policies
- Service mesh mTLS

**Duration:** 75 minutes

---

### Lab 4: Secrets Management
Secure sensitive data with external secret management solutions.

**Topics:**
- Kubernetes Secrets limitations
- External Secrets Operator
- HashiCorp Vault integration
- Sealed Secrets for GitOps
- Secret rotation

**Duration:** 90 minutes

---

### Lab 5: Image and Supply Chain Security
Protect your software supply chain from source to deployment.

**Topics:**
- Image vulnerability scanning
- Admission controllers (Kyverno/OPA)
- Image signing with Cosign
- SBOM generation
- Registry security

**Duration:** 90 minutes

---

### Lab 6: Runtime Security
Detect and respond to threats at runtime.

**Topics:**
- Falco deployment
- Runtime threat detection
- CIS benchmarks
- Security scanning
- Incident response

**Duration:** 75 minutes

---

## Security Framework

```
┌─────────────────────────────────────────────────────────────────┐
│                    SECURITY LIFECYCLE                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   BUILD TIME              DEPLOY TIME            RUNTIME         │
│   ──────────              ───────────            ───────         │
│                                                                  │
│   ┌─────────┐            ┌─────────┐           ┌─────────┐      │
│   │ Image   │            │Admission│           │ Runtime │      │
│   │Scanning │────────────│ Control │───────────│ Monitor │      │
│   │ (Trivy) │            │(Kyverno)│           │ (Falco) │      │
│   └─────────┘            └─────────┘           └─────────┘      │
│        │                      │                     │            │
│        ▼                      ▼                     ▼            │
│   ┌─────────┐            ┌─────────┐           ┌─────────┐      │
│   │ Image   │            │   Pod   │           │ Audit   │      │
│   │ Signing │            │Security │           │ Logs    │      │
│   │(Cosign) │            │  (PSA)  │           │         │      │
│   └─────────┘            └─────────┘           └─────────┘      │
│        │                      │                     │            │
│        ▼                      ▼                     ▼            │
│   ┌─────────┐            ┌─────────┐           ┌─────────┐      │
│   │  SBOM   │            │ Network │           │Incident │      │
│   │Generate │            │ Policy  │           │Response │      │
│   │         │            │         │           │         │      │
│   └─────────┘            └─────────┘           └─────────┘      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Tools

| Category | Tools |
|----------|-------|
| Authentication | OIDC, X.509 certificates, Service Accounts |
| Authorization | RBAC, OPA Gatekeeper, Kyverno |
| Pod Security | Pod Security Admission, Seccomp, AppArmor |
| Network | NetworkPolicy, Cilium, Calico |
| Secrets | Vault, External Secrets, Sealed Secrets |
| Scanning | Trivy, Grype, kubescape |
| Signing | Cosign, Sigstore, Notary |
| Runtime | Falco, Sysdig, Tetragon |

---

## Assessment Overview

The module assessment consists of 20 practical tasks across 5 sections:

| Section | Focus Area | Tasks |
|---------|------------|-------|
| 1 | RBAC and Authentication | 4 |
| 2 | Pod Security | 4 |
| 3 | Network Security | 4 |
| 4 | Secrets Management | 4 |
| 5 | Supply Chain Security | 4 |

**Passing Score:** 70% (14/20 tasks)

---

## Additional Resources

- [Kubernetes Security Documentation](https://kubernetes.io/docs/concepts/security/)
- [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [NIST Container Security Guide](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-190.pdf)
- [Falco Documentation](https://falco.org/docs/)
- [Sigstore/Cosign Documentation](https://docs.sigstore.dev/)

---

## Getting Started

Begin with [Lab 1: Cluster Security Fundamentals](lab-01-cluster-security/README.md) to learn the foundations of Kubernetes security.
