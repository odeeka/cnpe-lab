#!/bin/bash
# Phase 4: Security Validation Script

set -e

SCORE=0
MAX_SCORE=20
NAMESPACE="bookstore-prod"

echo "=============================================="
echo "Phase 4: Security Validation"
echo "=============================================="

# Check 1: Network Policies configured (4 points)
echo -n "Checking Network Policies... "
NP_COUNT=$(kubectl get networkpolicies -n $NAMESPACE 2>/dev/null | wc -l)
NP_COUNT=$((NP_COUNT - 1))  # Subtract header line
if [ "$NP_COUNT" -ge 5 ]; then
    echo "✓ PASS ($NP_COUNT policies found)"
    ((SCORE+=4))
elif [ "$NP_COUNT" -ge 2 ]; then
    echo "~ PARTIAL ($NP_COUNT policies found)"
    ((SCORE+=2))
else
    echo "✗ FAIL - Only $NP_COUNT policies found"
fi

# Check 2: Default deny policy exists (3 points)
echo -n "Checking default deny policy... "
if kubectl get networkpolicy default-deny-ingress -n $NAMESPACE &>/dev/null; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - No default deny policy"
fi

# Check 3: Pod Security Standards applied (4 points)
echo -n "Checking Pod Security Standards... "
PSS_LABEL=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null || echo "")
if [ "$PSS_LABEL" = "restricted" ] || [ "$PSS_LABEL" = "baseline" ]; then
    echo "✓ PASS (enforce: $PSS_LABEL)"
    ((SCORE+=4))
else
    echo "✗ FAIL - Pod Security Standards not configured"
fi

# Check 4: Service Accounts configured (3 points)
echo -n "Checking Service Accounts... "
SA_COUNT=$(kubectl get serviceaccounts -n $NAMESPACE -l app -o name 2>/dev/null | wc -l)
if [ "$SA_COUNT" -ge 4 ]; then
    echo "✓ PASS ($SA_COUNT service accounts found)"
    ((SCORE+=3))
elif [ "$SA_COUNT" -ge 2 ]; then
    echo "~ PARTIAL ($SA_COUNT service accounts found)"
    ((SCORE+=2))
else
    echo "✗ FAIL - Only $SA_COUNT service accounts found"
fi

# Check 5: RBAC configured (3 points)
echo -n "Checking RBAC Roles... "
ROLE_COUNT=$(kubectl get roles,rolebindings -n $NAMESPACE 2>/dev/null | wc -l)
if [ "$ROLE_COUNT" -ge 4 ]; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - Insufficient RBAC configuration"
fi

# Check 6: Secrets management (3 points)
echo -n "Checking secrets management... "
# Check for sealed secrets or external secrets
if kubectl get sealedsecrets -n $NAMESPACE &>/dev/null || kubectl get externalsecrets -n $NAMESPACE &>/dev/null; then
    echo "✓ PASS (encrypted secrets configured)"
    ((SCORE+=3))
elif kubectl get secrets -n $NAMESPACE 2>/dev/null | grep -q -v "default-token\|service-account"; then
    echo "~ PARTIAL (secrets exist but not encrypted)"
    ((SCORE+=1))
else
    echo "✗ FAIL - No secrets configured"
fi

echo ""
echo "=============================================="
echo "Phase 4 Score: $SCORE / $MAX_SCORE"
echo "=============================================="

exit 0
