#!/bin/bash
# Phase 5: Reliability Validation Script

set -e

SCORE=0
MAX_SCORE=20
NAMESPACE="bookstore-prod"

echo "=============================================="
echo "Phase 5: Reliability Validation"
echo "=============================================="

# Check 1: Velero installed (4 points)
echo -n "Checking Velero... "
if kubectl get pods -n velero -l app.kubernetes.io/name=velero 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=4))
else
    echo "✗ FAIL - Velero not running"
fi

# Check 2: Backup schedule configured (3 points)
echo -n "Checking backup schedules... "
SCHEDULE_COUNT=$(kubectl get schedules -n velero 2>/dev/null | grep -c bookstore || echo 0)
if [ "$SCHEDULE_COUNT" -ge 1 ]; then
    echo "✓ PASS ($SCHEDULE_COUNT schedules found)"
    ((SCORE+=3))
else
    echo "✗ FAIL - No backup schedules configured"
fi

# Check 3: PodDisruptionBudgets configured (4 points)
echo -n "Checking PodDisruptionBudgets... "
PDB_COUNT=$(kubectl get pdb -n $NAMESPACE 2>/dev/null | wc -l)
PDB_COUNT=$((PDB_COUNT - 1))  # Subtract header
if [ "$PDB_COUNT" -ge 4 ]; then
    echo "✓ PASS ($PDB_COUNT PDBs found)"
    ((SCORE+=4))
elif [ "$PDB_COUNT" -ge 2 ]; then
    echo "~ PARTIAL ($PDB_COUNT PDBs found)"
    ((SCORE+=2))
else
    echo "✗ FAIL - Only $PDB_COUNT PDBs found"
fi

# Check 4: HorizontalPodAutoscalers configured (3 points)
echo -n "Checking HorizontalPodAutoscalers... "
HPA_COUNT=$(kubectl get hpa -n $NAMESPACE 2>/dev/null | wc -l)
HPA_COUNT=$((HPA_COUNT - 1))  # Subtract header
if [ "$HPA_COUNT" -ge 3 ]; then
    echo "✓ PASS ($HPA_COUNT HPAs found)"
    ((SCORE+=3))
elif [ "$HPA_COUNT" -ge 1 ]; then
    echo "~ PARTIAL ($HPA_COUNT HPAs found)"
    ((SCORE+=2))
else
    echo "✗ FAIL - No HPAs configured"
fi

# Check 5: Pod topology spread constraints (3 points)
echo -n "Checking topology spread constraints... "
TOPOLOGY_CONFIGURED=0
for deploy in frontend api-gateway; do
    CONSTRAINTS=$(kubectl get deployment $deploy -n $NAMESPACE -o jsonpath='{.spec.template.spec.topologySpreadConstraints}' 2>/dev/null || echo "")
    if [ -n "$CONSTRAINTS" ] && [ "$CONSTRAINTS" != "null" ]; then
        ((TOPOLOGY_CONFIGURED+=1))
    fi
done
if [ "$TOPOLOGY_CONFIGURED" -ge 2 ]; then
    echo "✓ PASS"
    ((SCORE+=3))
elif [ "$TOPOLOGY_CONFIGURED" -ge 1 ]; then
    echo "~ PARTIAL"
    ((SCORE+=2))
else
    echo "✗ FAIL - No topology spread constraints"
fi

# Check 6: Chaos engineering configured (3 points)
echo -n "Checking chaos engineering... "
if kubectl get chaosengines -n $NAMESPACE &>/dev/null 2>&1; then
    CE_COUNT=$(kubectl get chaosengines -n $NAMESPACE 2>/dev/null | wc -l)
    if [ "$CE_COUNT" -ge 2 ]; then
        echo "✓ PASS (LitmusChaos configured)"
        ((SCORE+=3))
    else
        echo "~ PARTIAL (LitmusChaos installed but no experiments)"
        ((SCORE+=1))
    fi
elif kubectl get namespace litmus &>/dev/null; then
    echo "~ PARTIAL (LitmusChaos namespace exists)"
    ((SCORE+=1))
else
    echo "✗ FAIL - No chaos engineering configured"
fi

echo ""
echo "=============================================="
echo "Phase 5 Score: $SCORE / $MAX_SCORE"
echo "=============================================="

exit 0
