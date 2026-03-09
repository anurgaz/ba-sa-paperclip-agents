#!/bin/bash
# run-agent.sh — Run BA or SA agent via Claude API
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
        --agent)
            AGENT="$2"
            shift 2
            ;;
        --task)
            TASK="$2"
            shift 2
            ;;
        --context)
            shift
            while [[ $# -gt 0 ]] && [[ ! "$1" =~ ^-- ]]; do
                CONTEXT_FILES+=("$1")
                shift
            done
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

if [ -z "$AGENT" ] || [ -z "$TASK" ]; then
    echo -e "${RED}Error: --agent and --task are required${NC}"
    exit 1
fi

if [ "$AGENT" != "ba" ] && [ "$AGENT" != "sa" ]; then
    echo -e "${RED}Error: --agent must be 'ba' or 'sa'${NC}"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
OUTPUT_FILE="$OUTPUT_DIR/${AGENT}-${TIMESTAMP}.md"

echo -e "${CYAN}=== Flowlix Agent Pipeline ===${NC}"
echo -e "Agent: ${GREEN}${AGENT}${NC}"
echo -e "Task: ${TASK}"
echo -e "Output: ${OUTPUT_FILE}"
echo ""

# Step 1: Collect context
echo -e "${CYAN}[1/4] Collecting context...${NC}"

SYSTEM_PROMPT_FILE="$REPO_ROOT/agents/${AGENT}-agent/system-prompt.md"
SYSTEM_PROMPT=$(cat "$SYSTEM_PROMPT_FILE")

CONTEXT=""
MANDATORY_FILES=(
    "docs/context/glossary.md"
    "docs/context/constraints.md"
    "docs/context/decision-matrix.md"
)
[ "$AGENT" = "sa" ] && MANDATORY_FILES+=("docs/context/tech-stack.md")

for file in "${MANDATORY_FILES[@]}"; do
    FULL_PATH="$REPO_ROOT/$file"
    if [ -f "$FULL_PATH" ]; then
        CONTEXT="${CONTEXT}

--- FILE: $file ---
$(cat "$FULL_PATH")"
        echo "  Loaded: $file"
    fi
done

for file in "${CONTEXT_FILES[@]}"; do
    FULL_PATH="$REPO_ROOT/$file"
    if [ -f "$FULL_PATH" ]; then
        CONTEXT="${CONTEXT}

--- FILE: $file ---
$(cat "$FULL_PATH")"
        echo "  Loaded: $file"
    fi
done

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

# Step 2 & 3: Generate and validate with retries
echo ""
echo -e "${CYAN}[2/4] Calling Claude API...${NC}"

for ATTEMPT in $(seq 1 $MAX_RETRIES); do
    if [ "$ATTEMPT" -eq 1 ]; then
        CURRENT_TASK="$TASK"
    else
        echo -e "${YELLOW}  Retry attempt $ATTEMPT/$MAX_RETRIES with validation feedback...${NC}"
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
        sleep 2
        continue
    }

    # Save clean output (no ANSI)
    echo "$RESULT" > "$OUTPUT_FILE"
    echo -e "${GREEN}  Saved to: $OUTPUT_FILE${NC}"

    echo ""
    echo -e "${CYAN}[3/4] Validating artifact...${NC}"

    VALIDATION_FEEDBACK=$(bash "$VALIDATE_SCRIPT" "$OUTPUT_FILE" 2>&1) && {
        echo "$VALIDATION_FEEDBACK"
        echo ""
        echo -e "${CYAN}[4/4] Complete${NC}"
        echo -e "${GREEN}========================================${NC}"
        echo -e "${GREEN}  PASSED — Ready for human review${NC}"
        echo -e "${GREEN}  Artifact: $OUTPUT_FILE${NC}"
        echo -e "${GREEN}========================================${NC}"
        exit 0
    }

    echo "$VALIDATION_FEEDBACK"
    echo -e "${YELLOW}  Validation failed (attempt $ATTEMPT/$MAX_RETRIES)${NC}"
done

echo ""
echo -e "${RED}========================================${NC}"
echo -e "${RED}  FAILED — Validation failed after $MAX_RETRIES attempts${NC}"
echo -e "${RED}  Artifact: $OUTPUT_FILE${NC}"
echo -e "${RED}  Review validation report manually${NC}"
echo -e "${RED}========================================${NC}"
exit 1
