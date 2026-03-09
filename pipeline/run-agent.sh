#!/bin/bash
# run-agent.sh — Run BA or SA agent via Claude API with Paperclip integration
# Usage: ./pipeline/run-agent.sh --agent ba|sa --task "task text" [--context file1.md file2.md]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$REPO_ROOT/output"
VALIDATE_SCRIPT="$REPO_ROOT/validation/validate.sh"

# Claude API config
CLAUDE_API_KEY="${CLAUDE_API_KEY:-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}"
CLAUDE_MODEL="${CLAUDE_MODEL:-claude-sonnet-4-20250514}"
CLAUDE_API_URL="https://api.anthropic.com/v1/messages"
MAX_RETRIES=3

# Paperclip config
PAPERCLIP_URL="${PAPERCLIP_URL:-http://localhost:3100}"
PAPERCLIP_COMPANY_ID="ec4aeaec-5652-431a-b36d-bd798710dcad"
BA_AGENT_ID="81ac780f-bd9a-4347-b039-b545470c3767"
SA_AGENT_ID="5060d458-7b64-41f3-913d-c6ca11776f11"
BA_API_KEY="pcp_80e256dc2a5b2b3ed795454aa6f623349e91ed05870842b8"
SA_API_KEY="pcp_f150a8dbf2891dc570e3614bc81c129d7fad99c999e9090b"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Parse arguments
AGENT=""
TASK=""
CONTEXT_FILES=()

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent) AGENT="$2"; shift 2 ;;
        --task) TASK="$2"; shift 2 ;;
        --context)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                CONTEXT_FILES+=("$1")
                shift
            done
            ;;
        *) echo -e "${RED}Unknown option: $1${NC}"; exit 1 ;;
    esac
done

if [ -z "$AGENT" ] || [ -z "$TASK" ]; then
    echo -e "${RED}Error: --agent and --task are required${NC}"; exit 1
fi
if [ "$AGENT" != "ba" ] && [ "$AGENT" != "sa" ]; then
    echo -e "${RED}Error: --agent must be 'ba' or 'sa'${NC}"; exit 1
fi

# Set agent-specific vars
if [ "$AGENT" = "ba" ]; then
    AGENT_ID="$BA_AGENT_ID"; PCP_KEY="$BA_API_KEY"; AGENT_LABEL="BA Agent"
else
    AGENT_ID="$SA_AGENT_ID"; PCP_KEY="$SA_API_KEY"; AGENT_LABEL="SA Agent"
fi

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
OUTPUT_FILE="$OUTPUT_DIR/${AGENT}-${TIMESTAMP}.md"

echo -e "${CYAN}=== Flowlix Agent Pipeline ===${NC}"
echo -e "Agent: ${GREEN}${AGENT_LABEL}${NC}"
echo -e "Task: ${TASK}"
echo -e "Output: ${OUTPUT_FILE}"
echo ""

# Support Paperclip adapter mode (issue already exists)
if [ "${PAPERCLIP_SKIP_ISSUE_CREATE:-}" = "1" ] && [ -n "${PAPERCLIP_ISSUE_ID:-}" ]; then
    ISSUE_ID="$PAPERCLIP_ISSUE_ID"
    echo -e "${CYAN}[0/5] Using existing Paperclip issue: $ISSUE_ID${NC}"
else
# --- Paperclip: Create issue (no assignee to avoid checkout requirements) ---
echo -e "${CYAN}[0/5] Creating issue in Paperclip...${NC}"

ISSUE_TITLE=$(printf '[%s] %s' "$AGENT_LABEL" "$TASK" | head -c 200)
ISSUE_DESC=$(printf 'Задача: %s\nАгент: %s\nМодель: %s' "$TASK" "$AGENT_LABEL" "$CLAUDE_MODEL")
ISSUE_BODY=$(python3 -c "
import json, sys
print(json.dumps({
    'title': sys.argv[1],
    'description': sys.argv[2],
    'status': 'todo',
    'priority': 'medium'
}))
" "$ISSUE_TITLE" "$ISSUE_DESC")

ISSUE_RESPONSE=$(curl -s \
    -H "Authorization: Bearer $PCP_KEY" \
    -H "Content-Type: application/json" \
    -X POST "$PAPERCLIP_URL/api/companies/$PAPERCLIP_COMPANY_ID/issues" \
    -d "$ISSUE_BODY")

ISSUE_ID=$(echo "$ISSUE_RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || true)

if [ -n "$ISSUE_ID" ]; then
    echo -e "  ${GREEN}Issue created: $ISSUE_ID${NC}"
else
    echo -e "  ${YELLOW}Warning: Could not create issue in Paperclip (continuing without)${NC}"
    echo "  Response: $ISSUE_RESPONSE"
fi

fi
# Helper: post comment to Paperclip issue
post_comment() {
    local body="$1"
    [ -z "$ISSUE_ID" ] && return 0
    local json_body
    json_body=$(python3 -c "import json,sys; print(json.dumps({'body': sys.stdin.read()}))" <<< "$body")
    curl -s -o /dev/null \
        -H "Authorization: Bearer $PCP_KEY" \
        -H "Content-Type: application/json" \
        -X POST "$PAPERCLIP_URL/api/issues/$ISSUE_ID/comments" \
        -d "$json_body" || true
}

# Helper: update issue status
update_issue_status() {
    local status="$1"
    [ -z "$ISSUE_ID" ] && return 0
    curl -s -o /dev/null \
        -H "Authorization: Bearer $PCP_KEY" \
        -H "Content-Type: application/json" \
        -X PATCH "$PAPERCLIP_URL/api/issues/$ISSUE_ID" \
        -d "{\"status\":\"$status\"}" || true
}

# Step 1: Collect context
echo -e "${CYAN}[1/5] Collecting context...${NC}"

SYSTEM_PROMPT_FILE="$REPO_ROOT/agents/${AGENT}-agent/system-prompt.md"
SYSTEM_PROMPT=$(cat "$SYSTEM_PROMPT_FILE")

CONTEXT=""
MANDATORY_FILES=(
    "docs/context/glossary.md"
    "docs/context/constraints.md"
    "docs/context/decision-matrix.md"
)
[ "$AGENT" = "sa" ] && MANDATORY_FILES+=("docs/context/tech-stack.md")

LOADED_COUNT=0
for file in "${MANDATORY_FILES[@]}"; do
    FULL_PATH="$REPO_ROOT/$file"
    if [ -f "$FULL_PATH" ]; then
        CONTEXT="${CONTEXT}

--- FILE: $file ---
$(cat "$FULL_PATH")"
        echo "  Loaded: $file"
        LOADED_COUNT=$((LOADED_COUNT + 1))
    fi
done

for file in "${CONTEXT_FILES[@]}"; do
    FULL_PATH="$REPO_ROOT/$file"
    if [ -f "$FULL_PATH" ]; then
        CONTEXT="${CONTEXT}

--- FILE: $file ---
$(cat "$FULL_PATH")"
        echo "  Loaded: $file"
        LOADED_COUNT=$((LOADED_COUNT + 1))
    fi
done

post_comment "Контекст загружен ($LOADED_COUNT файлов). Вызываю Claude API ($CLAUDE_MODEL)..."

# Function to call Claude API
call_claude() {
    local user_message="$1"
    local full_message="КОНТЕКСТ:
${CONTEXT}

ЗАДАЧА:
${user_message}"

    local escaped_system escaped_message
    escaped_system=$(printf '%s' "$SYSTEM_PROMPT" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')
    escaped_message=$(printf '%s' "$full_message" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')

    local response http_code body
    response=$(curl -s -w "\n%{http_code}" \
        --max-time 120 \
        "$CLAUDE_API_URL" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $CLAUDE_API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "{
            \"model\": \"$CLAUDE_MODEL\",
            \"max_tokens\": 8192,
            \"system\": $escaped_system,
            \"messages\": [{
                \"role\": \"user\",
                \"content\": $escaped_message
            }]
        }")

    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" != "200" ]; then
        echo "API_ERROR: HTTP $http_code" >&2
        return 1
    fi

    echo "$body" | python3 -c '
import sys, json
data = json.load(sys.stdin)
for block in data.get("content", []):
    if block.get("type") == "text":
        print(block["text"])
'
}

# Step 2-4: Generate and validate with retries
echo ""
echo -e "${CYAN}[2/5] Calling Claude API...${NC}"

VALIDATION_FEEDBACK=""
for ATTEMPT in $(seq 1 $MAX_RETRIES); do
    if [ "$ATTEMPT" -eq 1 ]; then
        CURRENT_TASK="$TASK"
    else
        echo -e "${YELLOW}  Retry attempt $ATTEMPT/$MAX_RETRIES with validation feedback...${NC}"
        post_comment "Попытка $ATTEMPT/$MAX_RETRIES. Ошибки предыдущей попытки:
$VALIDATION_FEEDBACK"
        CURRENT_TASK="$TASK

ВАЖНО: Предыдущая версия артефакта НЕ прошла валидацию. Ошибки:
${VALIDATION_FEEDBACK}

Исправь эти ошибки и сгенерируй артефакт заново. Убедись что:
1. Есть ссылки на constraints (C-XXX) в тексте
2. Есть секция Acceptance Criteria с Happy Path, Edge Cases и Error Scenarios
3. Есть секция Constraints с перечислением затронутых C-XXX
4. Используются только термины из glossary.md"
    fi

    RESULT=$(call_claude "$CURRENT_TASK" 2>/dev/null) || {
        echo -e "${RED}  API call failed${NC}"
        post_comment "Ошибка вызова Claude API (попытка $ATTEMPT)"
        sleep 2
        continue
    }

    echo "$RESULT" > "$OUTPUT_FILE"
    echo -e "${GREEN}  Saved to: $OUTPUT_FILE${NC}"

    echo ""
    echo -e "${CYAN}[3/5] Validating artifact...${NC}"

    VALIDATION_FEEDBACK=$(bash "$VALIDATE_SCRIPT" "$OUTPUT_FILE" 2>&1) && {
        echo "$VALIDATION_FEEDBACK"
        echo ""
        echo -e "${CYAN}[4/5] Posting result to Paperclip...${NC}"

        # Post artifact as comment
        ARTIFACT_BODY="## Результат (попытка $ATTEMPT/$MAX_RETRIES) — PASS

Валидация: 4/4 проверки пройдены

---

$(cat "$OUTPUT_FILE")"
        post_comment "$ARTIFACT_BODY"
        update_issue_status "done"

        echo -e "${GREEN}  Posted to Paperclip${NC}"
        echo ""
        echo -e "${CYAN}[5/6] Publishing to GitHub Pages...${NC}"
        bash "$REPO_ROOT/pipeline/publish-to-pages.sh" "$OUTPUT_FILE" --agent "$AGENT" 2>&1 || echo -e "${YELLOW}  Warning: publish to Pages failed${NC}"
        echo ""
        echo -e "${CYAN}[6/6] Complete${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  PASSED — Ready for human review${NC}"
        echo -e "${GREEN}  Artifact: $OUTPUT_FILE${NC}"
        [ -n "$ISSUE_ID" ] && echo -e "${GREEN}  Paperclip issue: $ISSUE_ID${NC}"
        echo -e "${GREEN}  GitHub Pages: https://anurgaz.github.io/ba-sa-paperclip-agents/features/${NC}"
        echo -e "${GREEN}========================================${NC}"








        exit 0
    }

    echo "$VALIDATION_FEEDBACK"
    echo -e "${YELLOW}  Validation failed (attempt $ATTEMPT/$MAX_RETRIES)${NC}"
done

echo ""
post_comment "FAILED — Валидация не пройдена после $MAX_RETRIES попыток. Требуется ручное вмешательство."
update_issue_status "backlog"

echo -e "${RED}========================================${NC}"
echo -e "${RED}  FAILED — Validation failed after $MAX_RETRIES attempts${NC}"
echo -e "${RED}  Artifact: $OUTPUT_FILE${NC}"
echo -e "${RED}  Review validation report manually${NC}"
echo -e "${RED}========================================${NC}"
exit 1
