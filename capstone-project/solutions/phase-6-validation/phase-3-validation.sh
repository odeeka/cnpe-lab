#!/bin/bash
# Phase 3: Observability Validation Script

set -e

SCORE=0
MAX_SCORE=20
OBS_NAMESPACE="observability"
APP_NAMESPACE="bookstore-prod"

echo "=============================================="
echo "Phase 3: Observability Validation"
echo "=============================================="

# Check 1: Prometheus running (4 points)
echo -n "Checking Prometheus... "
if kubectl get pods -n $OBS_NAMESPACE -l app.kubernetes.io/name=prometheus 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=4))
else
    echo "✗ FAIL - Prometheus not running"
fi

# Check 2: Grafana running (3 points)
echo -n "Checking Grafana... "
if kubectl get pods -n $OBS_NAMESPACE -l app.kubernetes.io/name=grafana 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - Grafana not running"
fi

# Check 3: ServiceMonitors configured (4 points)
echo -n "Checking ServiceMonitors... "
SM_COUNT=$(kubectl get servicemonitors -n $OBS_NAMESPACE 2>/dev/null | grep -c bookstore || echo 0)
if [ "$SM_COUNT" -ge 4 ]; then
    echo "✓ PASS ($SM_COUNT ServiceMonitors found)"
    ((SCORE+=4))
elif [ "$SM_COUNT" -ge 2 ]; then
    echo "~ PARTIAL ($SM_COUNT ServiceMonitors found)"
    ((SCORE+=2))
else
    echo "✗ FAIL - Only $SM_COUNT ServiceMonitors found"
fi

# Check 4: Loki/Logging solution running (3 points)
echo -n "Checking Loki... "
if kubectl get pods -n $OBS_NAMESPACE -l app=loki 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - Loki not running"
fi

# Check 5: Alerting rules configured (3 points)
echo -n "Checking alerting rules... "
RULES_COUNT=$(kubectl get prometheusrules -n $OBS_NAMESPACE 2>/dev/null | grep -c bookstore || echo 0)
if [ "$RULES_COUNT" -ge 1 ]; then
    echo "✓ PASS ($RULES_COUNT rule sets found)"
    ((SCORE+=3))
else
    echo "✗ FAIL - No alerting rules found"
fi

# Check 6: Tracing configured (3 points)
echo -n "Checking tracing (Jaeger)... "
if kubectl get pods -n $OBS_NAMESPACE -l app=jaeger 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=3))
elif kubectl get pods -n $OBS_NAMESPACE -l app.kubernetes.io/name=jaeger 2>/dev/null | grep -q Running; then
    echo "✓ PASS"
    ((SCORE+=3))
else
    echo "✗ FAIL - Jaeger not running"
fi

echo ""
echo "=============================================="
echo "Phase 3 Score: $SCORE / $MAX_SCORE"
echo "=============================================="

exit 0
