#!/bin/bash
# completeness-check.sh — Verify all required template fields are filled
# Args: $1 = artifact path, $2 = repo root

ARTIFACT="$1"
REPO_ROOT="$2"

# Detect artifact type by content
IS_USER_STORY=false
IS_API_SPEC=false
IS_TEST_CASE=false
IS_SEQUENCE=false

if grep -q "User Story" "$ARTIFACT" 2>/dev/null && grep -q "Acceptance Criteria" "$ARTIFACT" 2>/dev/null; then
    IS_USER_STORY=true
fi
if grep -q "Endpoint" "$ARTIFACT" 2>/dev/null && grep -q "Rate Limits" "$ARTIFACT" 2>/dev/null; then
    IS_API_SPEC=true
fi
if grep -q "Test Steps" "$ARTIFACT" 2>/dev/null || grep -q "Preconditions" "$ARTIFACT" 2>/dev/null; then
    IS_TEST_CASE=true
fi
if grep -q "@startuml" "$ARTIFACT" 2>/dev/null; then
    IS_SEQUENCE=true
fi

MISSING=""

if $IS_USER_STORY; then
    echo "Detected: User Story"
    # Required sections for user story
    for section in "Metadata" "User Story" "Context" "Acceptance Criteria" "Constraints" "Dependencies"; do
        if ! grep -qi "### $section\|## $section" "$ARTIFACT" 2>/dev/null; then
            MISSING="$MISSING\n  - Missing section: $section"
        fi
    done
    # Check acceptance criteria has happy + edge + error
    if ! grep -qi "Happy Path" "$ARTIFACT" 2>/dev/null; then
        MISSING="$MISSING\n  - Missing: Happy Path in Acceptance Criteria"
    fi
    if ! grep -qi "Edge Case\|Edge Cases" "$ARTIFACT" 2>/dev/null; then
        MISSING="$MISSING\n  - Missing: Edge Cases in Acceptance Criteria"
    fi
    if ! grep -qi "Error Scenario\|Error Scenarios" "$ARTIFACT" 2>/dev/null; then
        MISSING="$MISSING\n  - Missing: Error Scenarios in Acceptance Criteria"
    fi
fi

if $IS_API_SPEC; then
    echo "Detected: API Specification"
    for section in "Metadata" "Endpoint" "Authentication" "Rate Limits" "Headers" "Request" "Response" "Error Responses" "Audit Log"; do
        if ! grep -qi "### $section\|## $section" "$ARTIFACT" 2>/dev/null; then
            MISSING="$MISSING\n  - Missing section: $section"
        fi
    done
    # Check required error codes
    for code in "400" "401" "403" "429" "500"; do
        if ! grep -q "$code" "$ARTIFACT" 2>/dev/null; then
            MISSING="$MISSING\n  - Missing HTTP error code: $code"
        fi
    done
    # Check idempotency for mutations
    if grep -qiE '(POST|PUT|PATCH|DELETE)' "$ARTIFACT" 2>/dev/null; then
        if ! grep -qi "Idempotency" "$ARTIFACT" 2>/dev/null; then
            MISSING="$MISSING\n  - Missing: Idempotency-Key for mutating endpoint"
        fi
    fi
fi

if $IS_TEST_CASE; then
    echo "Detected: Test Case"
    for section in "Metadata" "Preconditions" "Test Steps" "Expected Result"; do
        if ! grep -qi "### $section\|## $section" "$ARTIFACT" 2>/dev/null; then
            MISSING="$MISSING\n  - Missing section: $section"
        fi
    done
fi

if $IS_SEQUENCE; then
    echo "Detected: Sequence Diagram"
    STARTUML_COUNT=$(grep -c "@startuml" "$ARTIFACT" 2>/dev/null || echo 0)
    if [ "$STARTUML_COUNT" -lt 3 ]; then
        MISSING="$MISSING\n  - Need at least 3 diagrams (1 happy + 2 error), found: $STARTUML_COUNT"
    fi
    if ! grep -qi "audit" "$ARTIFACT" 2>/dev/null; then
        MISSING="$MISSING\n  - Missing: Audit Log participant in sequence diagram (C-009)"
    fi
fi

if ! $IS_USER_STORY && ! $IS_API_SPEC && ! $IS_TEST_CASE && ! $IS_SEQUENCE; then
    echo "WARNING: Could not detect artifact type. Performing basic checks."
    # Basic check: has headings, has content
    HEADING_COUNT=$(grep -c "^#" "$ARTIFACT" 2>/dev/null || echo 0)
    if [ "$HEADING_COUNT" -lt 2 ]; then
        MISSING="$MISSING\n  - Artifact has fewer than 2 headings"
    fi
    WORD_COUNT=$(wc -w < "$ARTIFACT" 2>/dev/null || echo 0)
    if [ "$WORD_COUNT" -lt 50 ]; then
        MISSING="$MISSING\n  - Artifact has fewer than 50 words (seems incomplete)"
    fi
fi

if [ -n "$MISSING" ]; then
    echo -e "Completeness issues found:$MISSING"
    exit 1
fi

echo "All required sections and fields present"
exit 0
