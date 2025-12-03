#!/bin/bash
# Phase 1: Foundation Validation Script

set -e

SCORE=0
MAX_SCORE=20
NAMESPACE_PROD="bookstore-prod"
NAMESPACE_STAGING="bookstore-staging"

echo "=============================================="
echo "Phase 1: Foundation Validation"
echo "=============================================="

# Check 1: Cluster is running (2 points)
echo -n "Checking cluster connectivity... "
if kubectl cluster-info &>/dev/null; then
    echo "✓ PASS"
    ((SCORE+=2))
else
    echo "✗ FAIL - Cannot connect to cluster"
fi

# Check 2: Required namespaces exist (3 points)
echo -n "Checking required namespaces... "
MISSING_NS=""
for ns in $NAMESPACE_PROD $NAMESPACE_STAGING bookstore-dev observability; do
    if ! kubectl get namespace $ns &>/dev/null; then
        MISSING_NS="$MISSING_NS $ns"
    fi
done
if [ -z "$MISSING_NS" ]; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - Missing namespaces:$MISSING_NS"
fi

# Check 3: ResourceQuotas configured (3 points)
echo -n "Checking ResourceQuotas... "
if kubectl get resourcequota -n $NAMESPACE_PROD &>/dev/null; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - No ResourceQuota found in $NAMESPACE_PROD"
fi

# Check 4: ArgoCD is running (4 points)
echo -n "Checking ArgoCD installation... "
if kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=4))
else
    echo "✗ FAIL - ArgoCD server not running"
fi

# Check 5: ArgoCD Applications configured (4 points)
echo -n "Checking ArgoCD Applications... "
APP_COUNT=$(kubectl get applications -n argocd 2>/dev/null | grep -c bookstore || echo 0)
if [ "$APP_COUNT" -ge 1 ]; then
    echo "✓ PASS ($APP_COUNT applications found)"
    ((SCORE+=4))
else
    echo "✗ FAIL - No BookStore applications found in ArgoCD"
fi

# Check 6: Ingress controller running (4 points)
echo -n "Checking Ingress Controller... "
if kubectl get pods -n ingress-nginx -l app.kubernetes.io/component=controller 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=4))
else
    echo "✗ FAIL - Ingress controller not running"
fi

echo ""
echo "=============================================="
echo "Phase 1 Score: $SCORE / $MAX_SCORE"
echo "=============================================="

exit 0
