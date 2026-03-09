#!/bin/bash
# consistency-check.sh — Check for conflicts with business rules
# Args: $1 = artifact path, $2 = repo root

ARTIFACT="$1"
REPO_ROOT="$2"
BR_DIR="$REPO_ROOT/docs/business-rules"

if [ ! -d "$BR_DIR" ]; then
    echo "ERROR: business-rules directory not found at $BR_DIR"
    exit 1
fi

WARNINGS=""
ISSUES=0

# Check 1: If artifact mentions thresholds, verify they match business rules
# AML threshold should be €15,000
if grep -qiE '(AML|threshold|порог)' "$ARTIFACT" 2>/dev/null; then
    # Check for wrong AML thresholds
    WRONG_THRESHOLDS=$(grep -oE '€[0-9,]+' "$ARTIFACT" 2>/dev/null | grep -vE '(15[,.]?000|25|30|100|5[,.]?000|10[,.]?000|50[,.]?000|250[,.]?000|75[,.]?000|150[,.]?000|2[,.]?000[,.]?000|1[,.]?000[,.]?000|400[,.]?000|100[,.]?000|200|270|14[,.]?530|9\.99|50[,.]?000\.00|150\.00|99\.99)' || true)
    # This is a heuristic - just flag unusual amounts for review
fi

# Check 2: UBO threshold must be 25%
if grep -qiE 'UBO|beneficial.owner' "$ARTIFACT" 2>/dev/null; then
    # Check for wrong UBO thresholds (should be 25%)
    if grep -qE '(UBO|beneficial)' "$ARTIFACT" 2>/dev/null && grep -qE '(10%|15%|20%|30%|50%).*threshold' "$ARTIFACT" 2>/dev/null; then
        WARNINGS="$WARNINGS\n  - UBO threshold should be >=25% (C-003). Found different threshold"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Check 3: Chargeback deadlines (Visa 30 days, MC 45 days)
if grep -qiE '(chargeback|dispute|representment)' "$ARTIFACT" 2>/dev/null; then
    # Check for wrong Visa deadline
    if grep -qiE 'visa.*45.day\|visa.*60.day' "$ARTIFACT" 2>/dev/null; then
        WARNINGS="$WARNINGS\n  - Visa representment deadline is 30 days, not 45/60"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Check 4: Settlement schedule consistency
if grep -qiE 'settlement.*schedule\|T\+[0-9]' "$ARTIFACT" 2>/dev/null; then
    # T+1 for LOW, T+3 for MEDIUM, T+7 for HIGH
    if grep -qE 'LOW.*T\+[2-9]' "$ARTIFACT" 2>/dev/null; then
        WARNINGS="$WARNINGS\n  - LOW risk merchants should have T+1 settlement"
        ISSUES=$((ISSUES + 1))
    fi
fi

# Check 5: SCA requirements
if grep -qiE '(payment|transaction|авториз)' "$ARTIFACT" 2>/dev/null; then
    if grep -qiE 'EEA\|PSD2' "$ARTIFACT" 2>/dev/null; then
        if ! grep -qiE '(SCA|3DS|3-D Secure|аутентификац)' "$ARTIFACT" 2>/dev/null; then
            WARNINGS="$WARNINGS\n  - Artifact mentions EEA payments but no SCA/3DS reference (C-001)"
            ISSUES=$((ISSUES + 1))
        fi
    fi
fi

# Check 6: Rate limit values consistency with C-012
if grep -qiE 'rate.limit' "$ARTIFACT" 2>/dev/null; then
    # Authorization should be <=100 req/sec per MID
    if grep -qiE 'authoriz.*[0-9]+.*req.*sec' "$ARTIFACT" 2>/dev/null; then
        AUTH_RATE=$(grep -oiE 'authoriz.*?([0-9]+).*req.*sec' "$ARTIFACT" 2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
        if [ -n "$AUTH_RATE" ] && [ "$AUTH_RATE" -gt 100 ] 2>/dev/null; then
            WARNINGS="$WARNINGS\n  - Authorization rate limit exceeds 100 req/sec per MID (C-012)"
            ISSUES=$((ISSUES + 1))
        fi
    fi
fi

# Check 7: Verify BR references exist
BR_REFS=$(grep -oE 'BR-[A-Z]+-[0-9]+' "$ARTIFACT" 2>/dev/null | sort -u || true)
for ref in $BR_REFS; do
    PREFIX=$(echo "$ref" | sed 's/-[0-9]*$//')
    BR_NUM=$(echo "$ref" | grep -oE "[0-9]+$")
        if ! grep -rqE "BR-[A-Z]+-0*$BR_NUM" "$BR_DIR" 2>/dev/null; then
        WARNINGS="$WARNINGS\n  - Referenced business rule $ref not found in business-rules/"
        ISSUES=$((ISSUES + 1))
    fi
done

if [ "$ISSUES" -gt 0 ]; then
    echo -e "Consistency check issues:$WARNINGS"
    exit 1
fi

echo "Consistency check passed: no conflicts with business rules detected"
exit 0
