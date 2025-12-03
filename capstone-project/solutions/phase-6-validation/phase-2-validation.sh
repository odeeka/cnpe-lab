#!/bin/bash
# Phase 2: Application Validation Script

set -e

SCORE=0
MAX_SCORE=20
NAMESPACE="bookstore-prod"

echo "=============================================="
echo "Phase 2: Application Validation"
echo "=============================================="

# Check 1: Frontend deployment running (3 points)
echo -n "Checking Frontend deployment... "
FRONTEND_READY=$(kubectl get deployment frontend -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "$FRONTEND_READY" -ge 1 ]; then
    echo "✓ PASS ($FRONTEND_READY replicas ready)"
    ((SCORE+=3))
else
    echo "✗ FAIL - Frontend not running"
fi

# Check 2: API Gateway deployment running (3 points)
echo -n "Checking API Gateway deployment... "
APIGW_READY=$(kubectl get deployment api-gateway -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "$APIGW_READY" -ge 1 ]; then
    echo "✓ PASS ($APIGW_READY replicas ready)"
    ((SCORE+=3))
else
    echo "✗ FAIL - API Gateway not running"
fi

# Check 3: Backend services running (4 points)
echo -n "Checking backend services... "
BACKEND_SERVICES="catalog-service order-service user-service payment-service"
RUNNING_COUNT=0
for svc in $BACKEND_SERVICES; do
    READY=$(kubectl get deployment $svc -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
    if [ "$READY" -ge 1 ]; then
        ((RUNNING_COUNT+=1))
    fi
done
if [ "$RUNNING_COUNT" -eq 4 ]; then
    echo "✓ PASS (all 4 services running)"
    ((SCORE+=4))
elif [ "$RUNNING_COUNT" -ge 2 ]; then
    echo "~ PARTIAL ($RUNNING_COUNT/4 services running)"
    ((SCORE+=2))
else
    echo "✗ FAIL - Only $RUNNING_COUNT/4 services running"
fi

# Check 4: PostgreSQL StatefulSet running (3 points)
echo -n "Checking PostgreSQL... "
PG_READY=$(kubectl get statefulset postgres -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "$PG_READY" -ge 1 ]; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - PostgreSQL not running"
fi

# Check 5: Redis deployment running (2 points)
echo -n "Checking Redis... "
REDIS_READY=$(kubectl get deployment redis -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo 0)
if [ "$REDIS_READY" -ge 1 ]; then
    echo "✓ PASS"
    ((SCORE+=2))
else
    echo "✗ FAIL - Redis not running"
fi

# Check 6: All services have endpoints (3 points)
echo -n "Checking service endpoints... "
SERVICES_WITH_ENDPOINTS=0
for svc in frontend api-gateway catalog-service order-service; do
    ENDPOINTS=$(kubectl get endpoints $svc -n $NAMESPACE -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
    if [ -n "$ENDPOINTS" ]; then
        ((SERVICES_WITH_ENDPOINTS+=1))
    fi
done
if [ "$SERVICES_WITH_ENDPOINTS" -ge 4 ]; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - Only $SERVICES_WITH_ENDPOINTS/4 services have endpoints"
fi

# Check 7: Ingress configured (2 points)
echo -n "Checking Ingress... "
if kubectl get ingress -n $NAMESPACE 2>/dev/null | grep -q bookstore; then
    echo "✓ PASS"
    ((SCORE+=2))
else
    echo "✗ FAIL - Ingress not configured"
fi

echo ""
echo "=============================================="
echo "Phase 2 Score: $SCORE / $MAX_SCORE"
echo "=============================================="

exit 0
