#!/bin/bash
# publish-to-pages.sh — Publish validated artifact to docs/features/ and push to GitHub Pages
# Usage: ./pipeline/publish-to-pages.sh <artifact.md> --agent ba|sa --feature "feature-slug"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FEATURES_DIR="$REPO_ROOT/docs/features"

# Parse arguments
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
    echo "Usage: $0 <artifact.md> --agent ba|sa [--feature slug]"
    exit 1
fi

if [ ! -f "$ARTIFACT" ]; then
    echo "Error: Artifact not found: $ARTIFACT"
    exit 1
fi

# Determine artifact type from content
CONTENT=$(cat "$ARTIFACT")
if echo "$CONTENT" | grep -qiE 'As a.*I want|As an.*I want|Как.*хочу|User Story'; then
    TYPE="user-story"
    TYPE_LABEL="User Story"
elif echo "$CONTENT" | grep -q '@startuml'; then
    TYPE="sequence-diagram"
    TYPE_LABEL="Sequence Diagram"
elif echo "$CONTENT" | grep -qiE 'Rate Limit' && echo "$CONTENT" | grep -qiE 'POST \|GET \|PUT \|DELETE '; then
    TYPE="api-spec"
    TYPE_LABEL="API Specification"
elif echo "$CONTENT" | grep -qiE 'Test Steps\|Preconditions'; then
    TYPE="test-case"
    TYPE_LABEL="Test Case"
else
    TYPE="document"
    TYPE_LABEL="Document"
fi

# Generate feature slug from task if not provided
if [ -z "$FEATURE_SLUG" ]; then
    # Extract from artifact title (first # heading)
    TITLE=$(grep -m1 '^#' "$ARTIFACT" | sed 's/^#\+\s*//' | sed 's/\[DRAFT\]\s*//')
    FEATURE_SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9а-яё]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | head -c 60)
    [ -z "$FEATURE_SLUG" ] && FEATURE_SLUG="artifact-$(date -u +%Y%m%d-%H%M%S)"
fi

# Create feature directory
FEATURE_DIR="$FEATURES_DIR/$FEATURE_SLUG"
mkdir -p "$FEATURE_DIR"

# Determine filename
FILENAME="${AGENT}-${TYPE}.md"
TARGET="$FEATURE_DIR/$FILENAME"

# Add metadata header and clean content
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
    # Strip preamble lines (agent thinking/loading messages before first heading)
    sed -n '/^#/,$p' "$ARTIFACT"
} > "$TARGET"

echo "Published: $TARGET"
echo "  Type: $TYPE_LABEL"
echo "  Feature: $FEATURE_SLUG"

# Update mkdocs.yml nav — add feature entry if not present
MKDOCS="$REPO_ROOT/mkdocs.yml"
NAV_PATH="features/$FEATURE_SLUG/$FILENAME"

# Check if features section exists in nav
if ! grep -q "Фичи:" "$MKDOCS" 2>/dev/null; then
    # Add Features section before Риски
    sed -i "/Риски и ограничения/i\\
  - Фичи:\\
    - Обзор: features/index.md" "$MKDOCS"
fi

# Add artifact to nav if not already there
LABEL="$FEATURE_SLUG ($TYPE_LABEL)"
if ! grep -q "$NAV_PATH" "$MKDOCS" 2>/dev/null; then
    # Add under Фичи section
    sed -i "/features\/index.md/a\\
    - \"$LABEL\": $NAV_PATH" "$MKDOCS"
fi

# Git commit and push
cd "$REPO_ROOT"
git add "$TARGET" "$MKDOCS" docs/features/index.md
git commit -m "docs: publish $TYPE_LABEL — $FEATURE_SLUG [$AGENT agent]" 2>/dev/null || true
git push origin main 2>/dev/null && echo "Pushed to GitHub — Pages will rebuild" || echo "Warning: git push failed"
