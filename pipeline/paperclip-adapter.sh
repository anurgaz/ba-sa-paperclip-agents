#!/bin/bash
# paperclip-adapter.sh — Wrapper for Paperclip process adapter
# Env from Paperclip: PAPERCLIP_AGENT_ID, PAPERCLIP_COMPANY_ID, PAPERCLIP_API_URL,
#                     PAPERCLIP_ISSUE_ID, PAPERCLIP_RUN_ID (patched)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

API_URL="${PAPERCLIP_API_URL:-http://localhost:3100}"
AGENT_ID="${PAPERCLIP_AGENT_ID:-}"
ISSUE_ID="${PAPERCLIP_ISSUE_ID:-}"

# Determine agent type from ID
BA_AGENT_ID="81ac780f-bd9a-4347-b039-b545470c3767"
SA_AGENT_ID="5060d458-7b64-41f3-913d-c6ca11776f11"
BA_API_KEY="pcp_80e256dc2a5b2b3ed795454aa6f623349e91ed05870842b8"
SA_API_KEY="pcp_f150a8dbf2891dc570e3614bc81c129d7fad99c999e9090b"

if [ "$AGENT_ID" = "$BA_AGENT_ID" ]; then
    AGENT_TYPE="ba"
    API_KEY="$BA_API_KEY"
elif [ "$AGENT_ID" = "$SA_AGENT_ID" ]; then
    AGENT_TYPE="sa"
    API_KEY="$SA_API_KEY"
else
    echo "[adapter] Unknown agent ID: $AGENT_ID" >&2
    exit 1
fi

echo "[adapter] Agent: $AGENT_TYPE | Issue: ${ISSUE_ID:-none}"

if [ -z "$ISSUE_ID" ]; then
    echo "[adapter] No PAPERCLIP_ISSUE_ID — cannot determine task" >&2
    exit 1
fi

# Fetch issue title/description from Paperclip API
ISSUE_JSON=$(curl -s \
    -H "Authorization: Bearer $API_KEY" \
    "$API_URL/api/issues/$ISSUE_ID")

TASK_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null || echo "")
TASK_DESC=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))" 2>/dev/null || echo "")

if [ -z "$TASK_TITLE" ]; then
    echo "[adapter] Could not fetch issue details from $API_URL/api/issues/$ISSUE_ID" >&2
    exit 1
fi

# Build task from title + description
TASK="$TASK_TITLE"
[ -n "$TASK_DESC" ] && TASK="$TASK_DESC"

echo "[adapter] Task: $TASK"

# Run pipeline with existing issue (skip creation)
export PAPERCLIP_SKIP_ISSUE_CREATE=1
export PAPERCLIP_ISSUE_ID="$ISSUE_ID"

exec bash "$REPO_ROOT/pipeline/run-agent.sh" --agent "$AGENT_TYPE" --task "$TASK"
