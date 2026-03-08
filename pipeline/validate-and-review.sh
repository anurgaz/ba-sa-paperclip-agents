#!/bin/bash
# validate-and-review.sh — Run validation on an existing artifact
# Usage: ./pipeline/validate-and-review.sh <path-to-artifact>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VALIDATE_SCRIPT="$REPO_ROOT/validation/validate.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-artifact>"
    exit 1
fi

ARTIFACT="$1"

if [ ! -f "$ARTIFACT" ]; then
    echo -e "${RED}Error: File not found: $ARTIFACT${NC}"
    exit 1
fi

echo -e "${CYAN}=== Validate & Review ===${NC}"
echo "Artifact: $ARTIFACT"
echo ""

if bash "$VALIDATE_SCRIPT" "$ARTIFACT"; then
    echo ""
    echo -e "${GREEN}Artifact is valid. Ready for human review.${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Review the artifact content"
    echo "  2. Approve or provide feedback"
    echo "  3. Move to docs/ if approved"
else
    echo ""
    echo -e "${RED}Artifact has validation issues. See report above.${NC}"
fi
