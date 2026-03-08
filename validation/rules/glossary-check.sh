#!/bin/bash
# glossary-check.sh — Verify terms match glossary.md
# Args: $1 = artifact path, $2 = repo root

ARTIFACT="$1"
REPO_ROOT="$2"
GLOSSARY_FILE="$REPO_ROOT/docs/context/glossary.md"

if [ ! -f "$GLOSSARY_FILE" ]; then
    echo "ERROR: glossary.md not found at $GLOSSARY_FILE"
    exit 1
fi

# Extract known terms from glossary (both RU and EN columns)
KNOWN_TERMS=$(grep -oE '\| [A-Za-zА-Яа-яёЁ][A-Za-zА-Яа-яёЁ /()-]+\|' "$GLOSSARY_FILE" | sed 's/|//g' | sed 's/^ *//;s/ *$//' | sort -u)

WARNINGS=""
ISSUES=0

# Check for common domain terms that SHOULD be from glossary
# These are terms that indicate domain concepts
DOMAIN_PATTERNS=(
    "chargeback:Чарджбэк/Chargeback"
    "representment:Репрезентмент/Representment"
    "settlement:Расчёт/Settlement"
    "clearing:Клиринг/Clearing"
    "authorization:Авторизация/Authorization"
    "acquiring:Эквайринг/Acquiring"
    "issuing:Эмиссия/Issuing"
    "tokenization:Токенизация/Tokenization"
)

# Check that PAN is never referenced as a stored/logged value
if grep -inE 'store.*PAN|save.*PAN|log.*PAN|PAN.*storage|PAN.*log|PAN.*database|PAN.*DB' "$ARTIFACT" 2>/dev/null | grep -viE 'token|mask|never|NOT|запрещ|нельзя'; then
    WARNINGS="$WARNINGS\n  - CRITICAL: PAN appears to be stored/logged (C-002 violation)"
    ISSUES=$((ISSUES + 1))
fi

# Check CVV is never stored
if grep -inE 'store.*CVV|save.*CVV|log.*CVV|CVV.*storage|CVV.*response' "$ARTIFACT" 2>/dev/null | grep -viE 'never|NOT|запрещ|нельзя|excluded'; then
    WARNINGS="$WARNINGS\n  - CRITICAL: CVV appears to be stored/logged (C-002 violation)"
    ISSUES=$((ISSUES + 1))
fi

# Check for potential non-glossary terms (heuristic)
# Look for payment domain terms that might be misspelled or non-standard
NON_STANDARD=$(grep -oiE '(charge-back|charge back|refundation|pre-auth|pre auth|tokenisation)' "$ARTIFACT" 2>/dev/null || true)
if [ -n "$NON_STANDARD" ]; then
    WARNINGS="$WARNINGS\n  - Non-standard terms found (use glossary terms instead): $NON_STANDARD"
    ISSUES=$((ISSUES + 1))
fi

if [ "$ISSUES" -gt 0 ]; then
    echo -e "Glossary check issues:$WARNINGS"
    exit 1
fi

echo "Glossary check passed: no non-standard terms or PAN/CVV violations detected"
exit 0
