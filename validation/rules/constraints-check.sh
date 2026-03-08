#!/bin/bash
# constraints-check.sh — Verify artifact references relevant constraints
# Args: $1 = artifact path, $2 = repo root

ARTIFACT="$1"
REPO_ROOT="$2"
CONSTRAINTS_FILE="$REPO_ROOT/docs/context/constraints.md"

if [ ! -f "$CONSTRAINTS_FILE" ]; then
    echo "ERROR: constraints.md not found at $CONSTRAINTS_FILE"
    exit 1
fi

# Extract all constraint IDs from constraints.md
CONSTRAINT_IDS=$(grep -oE 'C-[0-9]+' "$CONSTRAINTS_FILE" | sort -u)

# Check if artifact has a Constraints section or references any C-XXX
ARTIFACT_CONSTRAINTS=$(grep -oE 'C-[0-9]+' "$ARTIFACT" 2>/dev/null | sort -u)

if [ -z "$ARTIFACT_CONSTRAINTS" ]; then
    echo "WARNING: No constraint references (C-XXX) found in artifact"
    echo "Every artifact should reference at least one constraint"
    exit 1
fi

# Verify referenced constraints exist in constraints.md
INVALID_REFS=""
for ref in $ARTIFACT_CONSTRAINTS; do
    if ! echo "$CONSTRAINT_IDS" | grep -q "^${ref}$"; then
        INVALID_REFS="$INVALID_REFS $ref"
    fi
done

if [ -n "$INVALID_REFS" ]; then
    echo "ERROR: Invalid constraint references:$INVALID_REFS"
    echo "These constraints do not exist in constraints.md"
    exit 1
fi

COUNT=$(echo "$ARTIFACT_CONSTRAINTS" | wc -l | tr -d ' ')
echo "Found $COUNT valid constraint references: $(echo $ARTIFACT_CONSTRAINTS | tr '\n' ' ')"

# Check for PAN/CVV related content without C-002 reference
if grep -qiE '(PAN|card.?number|CVV|CVC)' "$ARTIFACT" 2>/dev/null; then
    if ! echo "$ARTIFACT_CONSTRAINTS" | grep -q "C-002"; then
        echo "WARNING: Artifact mentions PAN/CVV but does not reference C-002"
        exit 1
    fi
fi

# Check for AML content without C-006 reference
if grep -qiE '(AML|anti.?money|suspicious|SAR|MLRO)' "$ARTIFACT" 2>/dev/null; then
    if ! echo "$ARTIFACT_CONSTRAINTS" | grep -q "C-006"; then
        echo "WARNING: Artifact mentions AML but does not reference C-006"
        exit 1
    fi
fi

# Check for audit/log content without C-009 reference
if grep -qiE '(audit.?log|audit.?trail)' "$ARTIFACT" 2>/dev/null; then
    if ! echo "$ARTIFACT_CONSTRAINTS" | grep -q "C-009"; then
        echo "WARNING: Artifact mentions audit log but does not reference C-009"
        exit 1
    fi
fi

exit 0
