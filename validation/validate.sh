#!/bin/bash
# validate.sh — Main validation script for artifacts
# Usage: ./validation/validate.sh <path-to-artifact>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RULES_DIR="$SCRIPT_DIR/rules"
REPORTS_DIR="$SCRIPT_DIR/reports"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check args
if [ $# -lt 1 ]; then
    echo -e "${RED}Usage: $0 <path-to-artifact>${NC}"
    exit 1
fi

ARTIFACT="$1"

if [ ! -f "$ARTIFACT" ]; then
    echo -e "${RED}Error: File not found: $ARTIFACT${NC}"
    exit 1
fi

# Create reports directory
mkdir -p "$REPORTS_DIR"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
REPORT_FILE="$REPORTS_DIR/validation-$(date -u +"%Y%m%d-%H%M%S").txt"
TOTAL_CHECKS=4
PASSED_CHECKS=0
ERRORS=""

echo "=== Validation Report ===" | tee "$REPORT_FILE"
echo "Artifact: $ARTIFACT" | tee -a "$REPORT_FILE"
echo "Date: $TIMESTAMP" | tee -a "$REPORT_FILE"
echo "" | tee -a "$REPORT_FILE"

# Run each check
echo "Running constraints check..." | tee -a "$REPORT_FILE"
if bash "$RULES_DIR/constraints-check.sh" "$ARTIFACT" "$REPO_ROOT" >> "$REPORT_FILE" 2>&1; then
    echo -e "${GREEN}[PASS] constraints-check${NC}" | tee -a "$REPORT_FILE"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${RED}[FAIL] constraints-check${NC}" | tee -a "$REPORT_FILE"
    ERRORS="$ERRORS\n- constraints-check failed"
fi

echo "" | tee -a "$REPORT_FILE"
echo "Running completeness check..." | tee -a "$REPORT_FILE"
if bash "$RULES_DIR/completeness-check.sh" "$ARTIFACT" "$REPO_ROOT" >> "$REPORT_FILE" 2>&1; then
    echo -e "${GREEN}[PASS] completeness-check${NC}" | tee -a "$REPORT_FILE"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${RED}[FAIL] completeness-check${NC}" | tee -a "$REPORT_FILE"
    ERRORS="$ERRORS\n- completeness-check failed"
fi

echo "" | tee -a "$REPORT_FILE"
echo "Running glossary check..." | tee -a "$REPORT_FILE"
if bash "$RULES_DIR/glossary-check.sh" "$ARTIFACT" "$REPO_ROOT" >> "$REPORT_FILE" 2>&1; then
    echo -e "${GREEN}[PASS] glossary-check${NC}" | tee -a "$REPORT_FILE"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${RED}[FAIL] glossary-check${NC}" | tee -a "$REPORT_FILE"
    ERRORS="$ERRORS\n- glossary-check failed"
fi

echo "" | tee -a "$REPORT_FILE"
echo "Running consistency check..." | tee -a "$REPORT_FILE"
if bash "$RULES_DIR/consistency-check.sh" "$ARTIFACT" "$REPO_ROOT" >> "$REPORT_FILE" 2>&1; then
    echo -e "${GREEN}[PASS] consistency-check${NC}" | tee -a "$REPORT_FILE"
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
else
    echo -e "${RED}[FAIL] consistency-check${NC}" | tee -a "$REPORT_FILE"
    ERRORS="$ERRORS\n- consistency-check failed"
fi

echo "" | tee -a "$REPORT_FILE"
echo "===========================" | tee -a "$REPORT_FILE"
echo "Result: $PASSED_CHECKS/$TOTAL_CHECKS checks passed" | tee -a "$REPORT_FILE"

if [ "$PASSED_CHECKS" -eq "$TOTAL_CHECKS" ]; then
    echo -e "${GREEN}OVERALL: PASSED${NC}" | tee -a "$REPORT_FILE"
    echo "" | tee -a "$REPORT_FILE"
    echo "Ready for human review." | tee -a "$REPORT_FILE"
    exit 0
else
    echo -e "${RED}OVERALL: FAILED${NC}" | tee -a "$REPORT_FILE"
    echo -e "Errors:${ERRORS}" | tee -a "$REPORT_FILE"
    exit 1
fi
