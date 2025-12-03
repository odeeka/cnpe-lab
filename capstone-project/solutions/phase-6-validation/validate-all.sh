#!/bin/bash
# BookStore Capstone Project - Full Validation Script

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOTAL_SCORE=0
PASSING_SCORE=70

echo "=============================================="
echo "  BookStore Capstone Project Validation"
echo "=============================================="
echo ""
echo "Starting validation at $(date)"
echo ""

# Make validation scripts executable
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Run Phase 1 Validation
echo ""
PHASE1_OUTPUT=$("$SCRIPT_DIR/phase-1-validation.sh" 2>&1 || true)
echo "$PHASE1_OUTPUT"
PHASE1_SCORE=$(echo "$PHASE1_OUTPUT" | grep "Phase 1 Score:" | awk '{print $4}')
PHASE1_SCORE=${PHASE1_SCORE:-0}

# Run Phase 2 Validation
echo ""
PHASE2_OUTPUT=$("$SCRIPT_DIR/phase-2-validation.sh" 2>&1 || true)
echo "$PHASE2_OUTPUT"
PHASE2_SCORE=$(echo "$PHASE2_OUTPUT" | grep "Phase 2 Score:" | awk '{print $4}')
PHASE2_SCORE=${PHASE2_SCORE:-0}

# Run Phase 3 Validation
echo ""
PHASE3_OUTPUT=$("$SCRIPT_DIR/phase-3-validation.sh" 2>&1 || true)
echo "$PHASE3_OUTPUT"
PHASE3_SCORE=$(echo "$PHASE3_OUTPUT" | grep "Phase 3 Score:" | awk '{print $4}')
PHASE3_SCORE=${PHASE3_SCORE:-0}

# Run Phase 4 Validation
echo ""
PHASE4_OUTPUT=$("$SCRIPT_DIR/phase-4-validation.sh" 2>&1 || true)
echo "$PHASE4_OUTPUT"
PHASE4_SCORE=$(echo "$PHASE4_OUTPUT" | grep "Phase 4 Score:" | awk '{print $4}')
PHASE4_SCORE=${PHASE4_SCORE:-0}

# Run Phase 5 Validation
echo ""
PHASE5_OUTPUT=$("$SCRIPT_DIR/phase-5-validation.sh" 2>&1 || true)
echo "$PHASE5_OUTPUT"
PHASE5_SCORE=$(echo "$PHASE5_OUTPUT" | grep "Phase 5 Score:" | awk '{print $4}')
PHASE5_SCORE=${PHASE5_SCORE:-0}

# Calculate Total Score
TOTAL_SCORE=$((PHASE1_SCORE + PHASE2_SCORE + PHASE3_SCORE + PHASE4_SCORE + PHASE5_SCORE))

echo ""
echo "=============================================="
echo "           FINAL RESULTS"
echo "=============================================="
echo ""
echo "Phase 1 (Foundation):    $PHASE1_SCORE / 20"
echo "Phase 2 (Application):   $PHASE2_SCORE / 20"
echo "Phase 3 (Observability): $PHASE3_SCORE / 20"
echo "Phase 4 (Security):      $PHASE4_SCORE / 20"
echo "Phase 5 (Reliability):   $PHASE5_SCORE / 20"
echo "----------------------------------------------"
echo "TOTAL SCORE:             $TOTAL_SCORE / 100"
echo ""

if [ "$TOTAL_SCORE" -ge "$PASSING_SCORE" ]; then
    echo "🎉 CONGRATULATIONS! You PASSED the Capstone Project! 🎉"
    echo ""
    echo "You have successfully demonstrated proficiency in:"
    echo "  ✓ Kubernetes fundamentals and cluster management"
    echo "  ✓ GitOps practices with ArgoCD"
    echo "  ✓ Microservices deployment patterns"
    echo "  ✓ Observability and monitoring"
    echo "  ✓ Security best practices"
    echo "  ✓ Reliability and disaster recovery"
    echo ""
    EXIT_CODE=0
else
    echo "❌ You did not pass the Capstone Project."
    echo ""
    echo "Required score: $PASSING_SCORE / 100"
    echo "Your score:     $TOTAL_SCORE / 100"
    echo ""
    echo "Review the failed checks above and try again."
    echo ""
    EXIT_CODE=1
fi

echo "Validation completed at $(date)"
echo ""

exit $EXIT_CODE
