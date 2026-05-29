#!/usr/bin/env bash
set -euo pipefail

# detect-changes.sh
# Compares baseline.json against current upstream state via GitHub API.
# Outputs a JSON report of changed files for nuonco/nuon.
#
# Usage: bash .maintainer/scripts/detect-changes.sh
# Output: JSON to stdout (human-readable summary to stderr)
# Requirements: gh CLI authenticated
#
# Note: only nuonco/nuon (the public, customer-facing repo) is tracked.
# nuonco/mono is intentionally NOT tracked — it is internal tooling/infra
# and has no bearing on how a customer authors a config or uses the CLI.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAINTAINER_DIR="$(dirname "$SCRIPT_DIR")"
BASELINE_FILE="$MAINTAINER_DIR/baseline.json"

# --- Validate prerequisites ---

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found." >&2
  exit 1
fi

if [ ! -f "$BASELINE_FILE" ]; then
  echo "ERROR: baseline.json not found. Run seed-baseline.sh first." >&2
  exit 1
fi

# --- Read baseline ---

NUON_BASELINE_COMMIT=$(jq -r '.repos["nuonco/nuon"].commit' "$BASELINE_FILE")
LAST_SYNC=$(jq -r '.last_sync' "$BASELINE_FILE")

echo "Baseline from: $LAST_SYNC" >&2
echo "  nuonco/nuon: ${NUON_BASELINE_COMMIT:0:12}" >&2
echo "" >&2

# --- Get current HEAD commit ---

NUON_CURRENT=$(gh api repos/nuonco/nuon/commits/main --jq '.sha')

echo "Current HEAD:" >&2
echo "  nuonco/nuon: ${NUON_CURRENT:0:12}" >&2
echo "" >&2

# --- Detect changes in nuonco/nuon ---

NUON_CHANGES="[]"
NUON_CHANGED=false

if [ "$NUON_BASELINE_COMMIT" = "$NUON_CURRENT" ]; then
  echo "nuonco/nuon: no new commits" >&2
else
  echo "nuonco/nuon: detecting changes..." >&2

  # Get all changed files between baseline and current (omit patch to keep output small)
  NUON_ALL_CHANGES=$(gh api "repos/nuonco/nuon/compare/${NUON_BASELINE_COMMIT}...${NUON_CURRENT}" \
    --jq '[.files[] | {filename, status, sha}]' 2>/dev/null || echo "[]")

  # Filter to tracked path prefixes and relevant file extensions
  NUON_CHANGES=$(echo "$NUON_ALL_CHANGES" | jq '
    [.[] | select(
      .filename | test("^(pkg/config/|bins/cli/cmd/|bins/cli/internal/services/|bins/lsp/handlers/|bins/lsp/mappers/|bins/lsp/models/|sdks/nuon-go/models/)")
    ) | select(
      .filename | test("\\.(go|toml|yaml|yml)$")
    )]
  ')

  NUON_CHANGE_COUNT=$(echo "$NUON_CHANGES" | jq 'length')

  if [ "$NUON_CHANGE_COUNT" -gt 0 ]; then
    NUON_CHANGED=true
    echo "  $NUON_CHANGE_COUNT tracked files changed" >&2
    echo "$NUON_CHANGES" | jq -r '.[].filename' | while read -r f; do
      echo "    - $f" >&2
    done
  else
    echo "  no tracked files changed (only untracked paths)" >&2
  fi
fi

# --- Build output ---

TOTAL_CHANGES=$(echo "$NUON_CHANGES" | jq 'length')

echo "" >&2
echo "Total tracked changes: $TOTAL_CHANGES" >&2

# Build summary for CI issue body
SUMMARY=""
if [ "$NUON_CHANGED" = true ]; then
  NUON_FILELIST=$(echo "$NUON_CHANGES" | jq -r '.[].filename' | sed 's/^/- /')
  SUMMARY+="### nuonco/nuon (${NUON_BASELINE_COMMIT:0:12} → ${NUON_CURRENT:0:12})\n\n${NUON_FILELIST}\n\n"
fi

# Output JSON to stdout
jq -n \
  --argjson total_changes "$TOTAL_CHANGES" \
  --arg last_sync "$LAST_SYNC" \
  --arg nuon_baseline "$NUON_BASELINE_COMMIT" \
  --arg nuon_current "$NUON_CURRENT" \
  --argjson nuon_changes "$NUON_CHANGES" \
  --arg summary "$(echo -e "$SUMMARY")" \
  '{
    total_changes: $total_changes,
    last_sync: $last_sync,
    report: $summary,
    repos: {
      "nuonco/nuon": {
        baseline_commit: $nuon_baseline,
        current_commit: $nuon_current,
        changes: $nuon_changes
      }
    }
  }'
