#!/bin/bash
# publish-to-pages.sh — Publish validated artifact to docs/artifacts/ and push to GitHub Pages
# Usage: ./pipeline/publish-to-pages.sh <artifact.md> --agent ba|sa [--feature "slug"] [--title "Feature Title"]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ARTIFACTS_DIR="$REPO_ROOT/docs/artifacts"

ARTIFACT=""
AGENT=""
FEATURE_SLUG=""
FEATURE_TITLE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --agent) AGENT="$2"; shift 2 ;;
        --feature) FEATURE_SLUG="$2"; shift 2 ;;
        --title) FEATURE_TITLE="$2"; shift 2 ;;
        *) [ -z "$ARTIFACT" ] && ARTIFACT="$1"; shift ;;
    esac
done

if [ -z "$ARTIFACT" ] || [ -z "$AGENT" ]; then
    echo "Usage: $0 <artifact.md> --agent ba|sa [--feature slug] [--title title]"; exit 1
fi
[ ! -f "$ARTIFACT" ] && echo "Error: not found: $ARTIFACT" && exit 1

# Detect artifact type using python for reliable unicode handling
read TYPE TYPE_LABEL <<< $(python3 -c "
import sys, re
content = open(sys.argv[1], encoding='utf-8').read().replace('**','')
# Priority order matters
if re.search(r'As a.*I want|As an.*I want|User Story', content, re.I) or \
   ('\u041a\u0430\u043a' in content and '\u0445\u043e\u0447\u0443' in content):
    print('user-story User_Story')
elif '@startuml' in content:
    print('sequence-diagram Sequence_Diagram')
elif re.search(r'Rate Limit', content, re.I) and re.search(r'POST |GET |PUT |DELETE ', content, re.I):
    print('api-spec API_Specification')
elif re.search(r'Test Steps|Preconditions', content, re.I):
    print('test-case Test_Case')
else:
    print('document Document')
" "$ARTIFACT")
TYPE_LABEL=$(echo "$TYPE_LABEL" | tr '_' ' ')

# Transliterate function
transliterate() {
    python3 -c "
import re, sys
t = sys.argv[1].lower()
tr = {
    '\u0430':'a','\u0431':'b','\u0432':'v','\u0433':'g','\u0434':'d','\u0435':'e','\u0451':'e',
    '\u0436':'zh','\u0437':'z','\u0438':'i','\u0439':'i','\u043a':'k','\u043b':'l','\u043c':'m',
    '\u043d':'n','\u043e':'o','\u043f':'p','\u0440':'r','\u0441':'s','\u0442':'t','\u0443':'u',
    '\u0444':'f','\u0445':'kh','\u0446':'ts','\u0447':'ch','\u0448':'sh','\u0449':'shch',
    '\u044a':'','\u044b':'y','\u044c':'','\u044d':'e','\u044e':'yu','\u044f':'ya'
}
r = ''.join(tr.get(c, c) for c in t)
r = re.sub(r'[^a-z0-9]+', '-', r).strip('-')[:60]
print(r)
" "$1"
}

# Extract title from first heading
if [ -z "$FEATURE_TITLE" ]; then
    FEATURE_TITLE=$(python3 -c "
import re, sys
for line in open(sys.argv[1], encoding='utf-8'):
    line = line.strip()
    if line.startswith('#'):
        title = re.sub(r'^#+\s*', '', line)
        title = re.sub(r'\[DRAFT\]\s*', '', title)
        print(title)
        break
" "$ARTIFACT")
fi

# Generate slug
if [ -z "$FEATURE_SLUG" ]; then
    FEATURE_SLUG=$(transliterate "$FEATURE_TITLE")
    [ -z "$FEATURE_SLUG" ] && FEATURE_SLUG="artifact-$(date -u +%Y%m%d-%H%M%S)"
fi

# Agent label for nav
case "$AGENT" in
    ba) AGENT_LABEL="BA Agent" ;;
    sa) AGENT_LABEL="SA Agent" ;;
    *) AGENT_LABEL="$AGENT" ;;
esac

# Create directory and save artifact
FEATURE_DIR="$ARTIFACTS_DIR/$FEATURE_SLUG"
mkdir -p "$FEATURE_DIR"
FILENAME="${AGENT}-${TYPE}.md"
TARGET="$FEATURE_DIR/$FILENAME"

TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M UTC")

# Write artifact with frontmatter using python for reliable encoding
python3 -c "
import sys, re

artifact_path = sys.argv[1]
target_path = sys.argv[2]
type_label = sys.argv[3]
feature_title = sys.argv[4]
agent_label = sys.argv[5]
artifact_type = sys.argv[6]
timestamp = sys.argv[7]

with open(artifact_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Find first heading
lines = content.split('\n')
start = 0
for i, line in enumerate(lines):
    if line.startswith('#'):
        start = i
        break

body = '\n'.join(lines[start:])

with open(target_path, 'w', encoding='utf-8') as f:
    f.write('---\n')
    f.write(f'title: \"{type_label}\"\n')
    f.write(f'feature: \"{feature_title}\"\n')
    f.write(f'agent: {agent_label}\n')
    f.write(f'type: {artifact_type}\n')
    f.write(f'date: {timestamp}\n')
    f.write('validation: 4/4 PASS\n')
    f.write('---\n\n')
    f.write(body)
    f.write('\n')
" "$ARTIFACT" "$TARGET" "$TYPE_LABEL" "$FEATURE_TITLE" "$AGENT_LABEL" "$TYPE" "$TIMESTAMP"

echo "Published: $TARGET"
echo "  Type: $TYPE_LABEL"
echo "  Feature: $FEATURE_SLUG"
echo "  Agent: $AGENT_LABEL"

# --- Update mkdocs.yml nav and artifacts index ---
MKDOCS="$REPO_ROOT/mkdocs.yml"
NAV_PATH="artifacts/$FEATURE_SLUG/$FILENAME"

export MKDOCS_PATH="$MKDOCS"
export ARTIFACTS_DIR_PATH="$ARTIFACTS_DIR"
export FEATURE_TITLE_VAR="$FEATURE_TITLE"
export NAV_PATH_VAR="$NAV_PATH"
export TYPE_LABEL_VAR="$TYPE_LABEL"
export AGENT_LABEL_VAR="$AGENT_LABEL"
export FEATURE_SLUG_VAR="$FEATURE_SLUG"
export FILENAME_VAR="$FILENAME"
export TIMESTAMP_VAR="$TIMESTAMP"

python3 << 'PYEOF'
import os, sys, yaml

mkdocs_path = os.environ['MKDOCS_PATH']
artifacts_dir = os.environ['ARTIFACTS_DIR_PATH']
feature_title = os.environ['FEATURE_TITLE_VAR']
nav_path = os.environ['NAV_PATH_VAR']
type_label = os.environ['TYPE_LABEL_VAR']
agent_label = os.environ['AGENT_LABEL_VAR']
feature_slug = os.environ['FEATURE_SLUG_VAR']
filename = os.environ['FILENAME_VAR']
timestamp = os.environ['TIMESTAMP_VAR']

# Ensure artifacts index exists
index_path = os.path.join(artifacts_dir, 'index.md')
if not os.path.exists(index_path):
    os.makedirs(artifacts_dir, exist_ok=True)
    with open(index_path, 'w', encoding='utf-8') as f:
        f.write('# \u0410\u0440\u0442\u0435\u0444\u0430\u043a\u0442\u044b\n\n')
        f.write('\u0410\u0440\u0442\u0435\u0444\u0430\u043a\u0442\u044b, \u0441\u0433\u0435\u043d\u0435\u0440\u0438\u0440\u043e\u0432\u0430\u043d\u043d\u044b\u0435 BA/SA \u0430\u0433\u0435\u043d\u0442\u0430\u043c\u0438 \u0438 \u043f\u0440\u043e\u0448\u0435\u0434\u0448\u0438\u0435 \u0430\u0432\u0442\u043e\u0432\u0430\u043b\u0438\u0434\u0430\u0446\u0438\u044e (4/4).\n\n')
        f.write('| \u0424\u0438\u0447\u0430 | \u0410\u0433\u0435\u043d\u0442 | \u0422\u0438\u043f | \u0414\u0430\u0442\u0430 |\n')
        f.write('|------|-------|-----|------|\n')

# Add entry to index table
with open(index_path, 'a', encoding='utf-8') as f:
    f.write(f'| [{feature_title}]({feature_slug}/{filename}) | {agent_label} | {type_label} | {timestamp} |\n')

# Update mkdocs.yml nav
with open(mkdocs_path, 'r', encoding='utf-8') as f:
    doc = yaml.safe_load(f)

nav = doc.get('nav', [])
section_name = '\u0410\u0440\u0442\u0435\u0444\u0430\u043a\u0442\u044b'

# Remove old "\u0424\u0438\u0447\u0438" section
nav = [item for item in nav if not (isinstance(item, dict) and '\u0424\u0438\u0447\u0438' in item)]

# Find or create "\u0410\u0440\u0442\u0435\u0444\u0430\u043a\u0442\u044b" section
artifacts_section = None
for item in nav:
    if isinstance(item, dict) and section_name in item:
        artifacts_section = item[section_name]
        break

if artifacts_section is None:
    insert_at = len(nav)
    for i, item in enumerate(nav):
        if isinstance(item, dict):
            key = list(item.keys())[0]
            if '\u0420\u0438\u0441\u043a' in key:
                insert_at = i
                break
    artifacts_section = [{'\u041e\u0431\u0437\u043e\u0440': 'artifacts/index.md'}]
    nav.insert(insert_at, {section_name: artifacts_section})

# Find or create feature subsection
feature_subsection = None
for item in artifacts_section:
    if isinstance(item, dict) and feature_title in item:
        feature_subsection = item[feature_title]
        break

if feature_subsection is None:
    feature_subsection = []
    artifacts_section.append({feature_title: feature_subsection})

# Add entry if not already present
existing_paths = []
for item in feature_subsection:
    if isinstance(item, dict):
        existing_paths.extend(item.values())
    elif isinstance(item, str):
        existing_paths.append(item)

if nav_path not in existing_paths:
    entry_label = f'{type_label} ({agent_label})'
    feature_subsection.append({entry_label: nav_path})

doc['nav'] = nav

with open(mkdocs_path, 'w', encoding='utf-8') as f:
    yaml.dump(doc, f, allow_unicode=True, default_flow_style=False, sort_keys=False)

print(f'Nav updated: {feature_title} / {type_label} ({agent_label})')
PYEOF

# Git commit and push
cd "$REPO_ROOT"
git add docs/artifacts/ "$MKDOCS"
git commit -m "docs: publish $TYPE_LABEL — $FEATURE_SLUG [$AGENT agent]" 2>/dev/null || true
git push origin main 2>/dev/null && echo "Pushed to GitHub — Pages will rebuild" || echo "Warning: git push failed"
