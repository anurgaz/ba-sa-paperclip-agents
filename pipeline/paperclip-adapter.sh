#!/bin/bash
# paperclip-adapter.sh — Wrapper for Paperclip process adapter
# Called by Paperclip with env: PAPERCLIP_AGENT_ID, PAPERCLIP_COMPANY_ID, PAPERCLIP_API_URL
# Issue ID passed via PAPERCLIP_ISSUE_ID or parsed from context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

API_URL="${PAPERCLIP_API_URL:-http://localhost:3100}"
AGENT_ID="${PAPERCLIP_AGENT_ID:-}"
COMPANY_ID="${PAPERCLIP_COMPANY_ID:-}"

# Determine agent type from ID
BA_AGENT_ID="81ac780f-bd9a-4347-b039-b545470c3767"
SA_AGENT_ID="5060d458-7b64-41f3-913d-c6ca11776f11"

if [ "$AGENT_ID" = "$BA_AGENT_ID" ]; then
    AGENT_TYPE="ba"
elif [ "$AGENT_ID" = "$SA_AGENT_ID" ]; then
    AGENT_TYPE="sa"
else
    echo "[adapter] Unknown agent ID: $AGENT_ID" >&2
    exit 1
fi

# Get issue ID from env (set by Paperclip heartbeat)
ISSUE_ID="${PAPERCLIP_ISSUE_ID:-${1:-}}"

if [ -z "$ISSUE_ID" ]; then
    echo "[adapter] No issue ID provided. Use: $0 <issue-id>" >&2
    echo "[adapter] Or set PAPERCLIP_ISSUE_ID env var" >&2
    exit 1
fi

echo "[adapter] Agent: $AGENT_TYPE | Issue: $ISSUE_ID"

# Fetch issue details from Paperclip API
API_KEY_BA="pcp_80e256dc2a5b2b3ed795454aa6f623349e91ed05870842b8"
API_KEY_SA="pcp_f150a8dbf2891dc570e3614bc81c129d7fad99c999e9090b"

if [ "$AGENT_TYPE" = "ba" ]; then
    API_KEY="$API_KEY_BA"
else
    API_KEY="$API_KEY_SA"
fi

ISSUE_JSON=$(curl -s \
    -H "Authorization: Bearer $API_KEY" \
    "$API_URL/api/issues/$ISSUE_ID")

TASK_TITLE=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('title',''))" 2>/dev/null || echo "")
TASK_DESC=$(echo "$ISSUE_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('description',''))" 2>/dev/null || echo "")

if [ -z "$TASK_TITLE" ]; then
    echo "[adapter] Could not fetch issue details" >&2
    exit 1
fi

# Build task from issue title + description
TASK="$TASK_TITLE"
[ -n "$TASK_DESC" ] && TASK="$TASK. $TASK_DESC"

# Strip [BA Agent] or [SA Agent] prefix from task
TASK=$(echo "$TASK" | sed 's/^\[BA Agent\] //; s/^\[SA Agent\] //')

echo "[adapter] Task: $TASK"

# Run the pipeline (skip Paperclip issue creation since issue already exists)
export PAPERCLIP_SKIP_ISSUE_CREATE=1
export PAPERCLIP_ISSUE_ID="$ISSUE_ID"

exec bash "$REPO_ROOT/pipeline/run-agent.sh" --agent "$AGENT_TYPE" --task "$TASK"
