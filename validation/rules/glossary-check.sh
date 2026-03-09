#!/bin/bash
# glossary-check.sh — Verify terms match glossary.md
# Args: $1 = artifact path, $2 = repo root

ARTIFACT="$1"
REPO_ROOT="$2"
GLOSSARY_FILE="$REPO_ROOT/docs/context/glossary.md"

if [ ! -f "$GLOSSARY_FILE" ]; then
    echo "ERROR: glossary.md not found"
    exit 1
fi

# Strip ANSI codes
CLEAN=$(sed 's/\x1b\[[0-9;]*m//g' "$ARTIFACT")

ISSUES=0
WARNINGS=""

# Check PAN storage violations
if echo "$CLEAN" | grep -inE 'store.*PAN|save.*PAN|log.*PAN|PAN.*storage|PAN.*log|PAN.*database' | grep -viE 'token|mask|never|NOT|запрещ|нельзя|не ' > /dev/null 2>&1; then
    WARNINGS="$WARNINGS\n  - CRITICAL: PAN appears to be stored/logged (C-002 violation)"
    ISSUES=$((ISSUES + 1))
fi

# Check CVV storage violations
if echo "$CLEAN" | grep -inE 'store.*CVV|save.*CVV|log.*CVV|CVV.*storage|CVV.*response' | grep -viE 'never|NOT|запрещ|нельзя|excluded|не ' > /dev/null 2>&1; then
    WARNINGS="$WARNINGS\n  - CRITICAL: CVV appears to be stored/logged (C-002 violation)"
    ISSUES=$((ISSUES + 1))
fi

# Check for non-standard terms
NON_STANDARD=$(echo "$CLEAN" | grep -oiE '(charge-back|charge back|refundation|pre-auth[^o]|tokenisation)' || true)
if [ -n "$NON_STANDARD" ]; then
    WARNINGS="$WARNINGS\n  - Non-standard terms: $NON_STANDARD"
    ISSUES=$((ISSUES + 1))
fi

if [ "$ISSUES" -gt 0 ]; then
    echo -e "Glossary check issues:$WARNINGS"
    exit 1
fi

echo "Glossary check passed"
exit 0
