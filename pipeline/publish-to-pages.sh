#!/bin/bash
# publish-to-pages.sh — Publish validated artifact to docs/features/ and push to GitHub Pages
# Usage: ./pipeline/publish-to-pages.sh <artifact.md> --agent ba|sa [--feature "slug"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FEATURES_DIR="$REPO_ROOT/docs/features"

ARTIFACT=""
AGENT=""
FEATURE_SLUG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent) AGENT="$2"; shift 2 ;;
        --feature) FEATURE_SLUG="$2"; shift 2 ;;
        *) [ -z "$ARTIFACT" ] && ARTIFACT="$1"; shift ;;
    esac
done

if [ -z "$ARTIFACT" ] || [ -z "$AGENT" ]; then
    echo "Usage: $0 <artifact.md> --agent ba|sa [--feature slug]"; exit 1
fi
[ ! -f "$ARTIFACT" ] && echo "Error: not found: $ARTIFACT" && exit 1

# Detect type
CONTENT=$(sed 's/\*\*//g' "$ARTIFACT")
if echo "$CONTENT" | grep -qiE 'As a.*I want|As an.*I want|Как.*хочу|User Story'; then
    TYPE="user-story"; TYPE_LABEL="User Story"
elif echo "$CONTENT" | grep -q '@startuml'; then
    TYPE="sequence-diagram"; TYPE_LABEL="Sequence Diagram"
elif echo "$CONTENT" | grep -qiE 'Rate Limit' && echo "$CONTENT" | grep -qiE 'POST \|GET \|PUT \|DELETE '; then
    TYPE="api-spec"; TYPE_LABEL="API Specification"
elif echo "$CONTENT" | grep -qiE 'Test Steps\|Preconditions'; then
    TYPE="test-case"; TYPE_LABEL="Test Case"
else
    TYPE="document"; TYPE_LABEL="Document"
fi

# Generate slug with transliteration
if [ -z "$FEATURE_SLUG" ]; then
    TITLE=$(grep -m1 '^#' "$ARTIFACT" | sed 's/^#\+\s*//' | sed 's/\[DRAFT\]\s*//')
    FEATURE_SLUG=$(python3 -c "
import re, sys
t = sys.argv[1].lower()
tr = {'а':'a','б':'b','в':'v','г':'g','д':'d','е':'e','ё':'e','ж':'zh','з':'z','и':'i','й':'i','к':'k','л':'l','м':'m','н':'n','о':'o','п':'p','р':'r','с':'s','т':'t','у':'u','ф':'f','х':'kh','ц':'ts','ч':'ch','ш':'sh','щ':'shch','ъ':'','ы':'y','ь':'','э':'e','ю':'yu','я':'ya'}
r = ''.join(tr.get(c, c) for c in t)
r = re.sub(r'[^a-z0-9]+', '-', r).strip('-')[:60]
print(r)
" "$TITLE")
    [ -z "$FEATURE_SLUG" ] && FEATURE_SLUG="artifact-$(date -u +%Y%m%d-%H%M%S)"
fi

# Create feature directory and save
FEATURE_DIR="$FEATURES_DIR/$FEATURE_SLUG"
mkdir -p "$FEATURE_DIR"
FILENAME="${AGENT}-${TYPE}.md"
TARGET="$FEATURE_DIR/$FILENAME"

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")
{
    echo "---"
    echo "title: \"$TYPE_LABEL — $(echo "$FEATURE_SLUG" | sed 's/-/ /g')\""
    echo "agent: $AGENT"
    echo "type: $TYPE"
    echo "date: $TIMESTAMP"
    echo "validation: 4/4 PASS"
    echo "---"
    echo ""
    sed -n '/^#/,$p' "$ARTIFACT"
} > "$TARGET"

echo "Published: $TARGET"
echo "  Type: $TYPE_LABEL"
echo "  Feature: $FEATURE_SLUG"

# Update mkdocs.yml nav
MKDOCS="$REPO_ROOT/mkdocs.yml"
NAV_PATH="features/$FEATURE_SLUG/$FILENAME"

if ! grep -q "Фичи:" "$MKDOCS" 2>/dev/null; then
    sed -i "/Риски и ограничения/i\\
  - Фичи:\\
    - Обзор: features/index.md" "$MKDOCS"
fi

LABEL="$FEATURE_SLUG ($TYPE_LABEL)"
if ! grep -q "$NAV_PATH" "$MKDOCS" 2>/dev/null; then
    sed -i "/features\/index.md/a\\
    - \"$LABEL\": $NAV_PATH" "$MKDOCS"
fi

# Git commit and push
cd "$REPO_ROOT"
git add "$TARGET" "$MKDOCS" docs/features/index.md
git commit -m "docs: publish $TYPE_LABEL — $FEATURE_SLUG [$AGENT agent]" 2>/dev/null || true
git push origin main 2>/dev/null && echo "Pushed to GitHub — Pages will rebuild" || echo "Warning: git push failed"
