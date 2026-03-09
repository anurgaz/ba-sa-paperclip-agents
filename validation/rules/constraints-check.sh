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

# Strip ANSI codes for analysis
CLEAN_ARTIFACT=$(sed 's/\x1b\[[0-9;]*m//g' "$ARTIFACT")

# Extract all constraint IDs from constraints.md
CONSTRAINT_IDS=$(grep -oE 'C-[0-9]{3}' "$CONSTRAINTS_FILE" | sort -u)

# Check if artifact references any C-XXX
ARTIFACT_CONSTRAINTS=$(echo "$CLEAN_ARTIFACT" | grep -oE 'C-[0-9]{3}' | sort -u)

if [ -z "$ARTIFACT_CONSTRAINTS" ]; then
    echo "WARNING: No constraint references (C-XXX) found in artifact"
    exit 1
fi

# Verify referenced constraints exist
INVALID_REFS=""
for ref in $ARTIFACT_CONSTRAINTS; do
    if ! echo "$CONSTRAINT_IDS" | grep -q "^${ref}$"; then
        INVALID_REFS="$INVALID_REFS $ref"
    fi
done

if [ -n "$INVALID_REFS" ]; then
    echo "ERROR: Invalid constraint references:$INVALID_REFS"
    exit 1
fi

COUNT=$(echo "$ARTIFACT_CONSTRAINTS" | wc -l | tr -d ' ')
echo "Found $COUNT valid constraint references: $(echo $ARTIFACT_CONSTRAINTS | tr '\n' ' ')"

# Check for PAN/CVV related content without C-002 reference
if echo "$CLEAN_ARTIFACT" | grep -qiE 'store.*PAN|save.*PAN|log.*PAN' | grep -viE 'token|mask|never|NOT|запрещ|нельзя'; then
    if ! echo "$ARTIFACT_CONSTRAINTS" | grep -q "C-002"; then
        echo "WARNING: Artifact mentions PAN storage but does not reference C-002"
        exit 1
    fi
fi

exit 0
