# Phase 4: Security Solutions

This directory contains the security configuration for the BookStore application.

## Directory Structure

```
phase-4-security/
├── network-policies/
│   ├── default-deny.yaml       # Default deny all traffic
│   ├── frontend-policy.yaml    # Frontend network rules
│   ├── backend-policy.yaml     # Backend services network rules
│   └── database-policy.yaml    # Database network rules
├── pod-security/
│   ├── pod-security-standards.yaml  # Pod Security Standards
│   └── security-contexts.yaml       # Security context examples
├── rbac/
│   ├── service-accounts.yaml   # Service accounts
│   ├── roles.yaml              # Roles and ClusterRoles
│   └── bindings.yaml           # RoleBindings
└── secrets/
    └── sealed-secrets.yaml     # SealedSecrets configuration
```

## Quick Deploy

```bash
# Apply default deny policies first
kubectl apply -f network-policies/default-deny.yaml

# Apply service-specific network policies
kubectl apply -f network-policies/

# Apply Pod Security Standards
kubectl apply -f pod-security/

# Apply RBAC
kubectl apply -f rbac/
```

## Network Policy Strategy

1. **Default Deny**: All namespaces start with deny-all ingress/egress
2. **Allow Specific**: Only explicitly allowed traffic is permitted
3. **Least Privilege**: Services only communicate with required dependencies
