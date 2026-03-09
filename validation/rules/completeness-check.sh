#!/bin/bash
# completeness-check.sh — Verify all required template fields are filled
ARTIFACT="$1"
REPO_ROOT="$2"

CLEAN=$(sed 's/\x1b\[[0-9;]*m//g' "$ARTIFACT" | sed 's/\*\*//g')
MISSING=""
DETECTED=""

# Detect type with strict priority
HAS_USERSTORY=$(echo "$CLEAN" | grep -ciE 'As a.*I want|As an.*I want|Как.*хочу|User Story' || true)
HAS_STARTUML=$(echo "$CLEAN" | grep -c '@startuml' || true)
HAS_RATE=$(echo "$CLEAN" | grep -ciE 'Rate Limit' || true)
HAS_HTTP=$(echo "$CLEAN" | grep -ciE 'POST |GET |PUT |DELETE |Endpoint' || true)

if [ "$HAS_USERSTORY" -gt 0 ]; then
    DETECTED="User Story"
elif [ "$HAS_STARTUML" -gt 0 ]; then
    DETECTED="Sequence Diagram"
elif [ "$HAS_RATE" -gt 0 ] && [ "$HAS_HTTP" -gt 0 ]; then
    DETECTED="API Specification"
elif echo "$CLEAN" | grep -qiE 'Test Steps|Preconditions'; then
    DETECTED="Test Case"
else
    DETECTED="Generic"
fi

echo "Detected: $DETECTED"

case "$DETECTED" in
    "User Story")
        echo "$CLEAN" | grep -qiE 'As a|As an|Как' || MISSING="$MISSING\n  - Missing: User Story role statement"
        echo "$CLEAN" | grep -qiE 'Acceptance|Criteria|AC-|Happy Path|Given.*When' || MISSING="$MISSING\n  - Missing: Acceptance Criteria"
        echo "$CLEAN" | grep -qiE 'Edge Case|edge|граничн' || MISSING="$MISSING\n  - Missing: Edge Cases"
        echo "$CLEAN" | grep -qiE 'Error|ошибк|400|declined|failed' || MISSING="$MISSING\n  - Missing: Error Scenarios"
        echo "$CLEAN" | grep -qE 'C-[0-9][0-9][0-9]' || MISSING="$MISSING\n  - Missing: Constraint references"
        ;;
    "API Specification")
        echo "$CLEAN" | grep -qiE 'Auth|Bearer|OAuth|token' || MISSING="$MISSING\n  - Missing: Authentication"
        echo "$CLEAN" | grep -qiE 'Rate' || MISSING="$MISSING\n  - Missing: Rate Limits"
        echo "$CLEAN" | grep -qiE 'Request|request' || MISSING="$MISSING\n  - Missing: Request section"
        echo "$CLEAN" | grep -qiE 'Response|response' || MISSING="$MISSING\n  - Missing: Response section"
        echo "$CLEAN" | grep -qiE 'error|Error|HTTP|status' || MISSING="$MISSING\n  - Missing: Error handling"
        echo "$CLEAN" | grep -qiE 'audit|Audit|log|Log' || MISSING="$MISSING\n  - Missing: Audit section"
        echo "$CLEAN" | grep -q '400' || MISSING="$MISSING\n  - Missing: HTTP 400"
        echo "$CLEAN" | grep -q '429' || MISSING="$MISSING\n  - Missing: HTTP 429"
        echo "$CLEAN" | grep -q '500' || MISSING="$MISSING\n  - Missing: HTTP 500"
        echo "$CLEAN" | grep -qE 'C-[0-9][0-9][0-9]' || MISSING="$MISSING\n  - Missing: Constraint references"
        ;;
    "Sequence Diagram")
        [ "$HAS_STARTUML" -lt 3 ] && MISSING="$MISSING\n  - Need >=3 diagrams, found: $HAS_STARTUML"
        ;;
    "Test Case")
        echo "$CLEAN" | grep -qiE 'Preconditions|preconditions' || MISSING="$MISSING\n  - Missing: Preconditions"
        echo "$CLEAN" | grep -qiE 'Steps|steps' || MISSING="$MISSING\n  - Missing: Test Steps"
        echo "$CLEAN" | grep -qiE 'Expected|expected' || MISSING="$MISSING\n  - Missing: Expected Result"
        ;;
    "Generic")
        WORD_COUNT=$(echo "$CLEAN" | wc -w | tr -d ' ')
        [ "$WORD_COUNT" -lt 50 ] && MISSING="$MISSING\n  - Too short ($WORD_COUNT words)"
        ;;
esac

if [ -n "$MISSING" ]; then
    echo -e "Completeness issues found:$MISSING"
    exit 1
fi

echo "All required sections present"
exit 0
