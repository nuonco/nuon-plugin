#!/usr/bin/env bash
set -euo pipefail

# seed-baseline.sh
# Discovers tracked files and populates initial baseline.json for nuonco/nuon.
# Run this once to establish the starting point for change detection.
#
# Usage: bash .maintainer/scripts/seed-baseline.sh
# Requirements: gh CLI authenticated
#
# Note: only nuonco/nuon (the public, customer-facing repo) is tracked.
# nuonco/mono is intentionally NOT tracked — it is internal tooling/infra.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MAINTAINER_DIR="$(dirname "$SCRIPT_DIR")"
BASELINE_FILE="$MAINTAINER_DIR/baseline.json"

# --- Validate prerequisites ---

if ! command -v gh &>/dev/null; then
  echo "ERROR: gh CLI not found. Install with: brew install gh" >&2
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "ERROR: gh CLI not authenticated. Run: gh auth login" >&2
  exit 1
fi

echo "Prerequisites OK. Seeding baseline..."

# --- Define tracked paths ---

# nuonco/nuon: tracked path prefixes (public repo)
NUON_PREFIXES=(
  "pkg/config/"
  "bins/cli/cmd/"
  "bins/cli/internal/services/"
  "bins/lsp/handlers/"
  "bins/lsp/mappers/"
  "bins/lsp/models/"
  "sdks/nuon-go/models/"
)

# --- Helper: get file tree and filter to tracked Go/TOML/YAML files ---

get_tracked_files() {
  local repo="$1"
  shift
  local prefixes=("$@")

  # Build jq filter for prefixes
  local jq_filter='.tree[] | select(.type == "blob") | select('
  local first=true
  for prefix in "${prefixes[@]}"; do
    if [ "$first" = true ]; then
      jq_filter+="(.path | startswith(\"$prefix\"))"
      first=false
    else
      jq_filter+=" or (.path | startswith(\"$prefix\"))"
    fi
  done
  jq_filter+=') | select(.path | test("\\.(go|toml|yaml|yml)$")) | {path: .path, sha: .sha}'

  gh api "repos/$repo/git/trees/main?recursive=1" --jq "$jq_filter"
}

# --- Get current HEAD commit ---

echo "Fetching HEAD commit..."

NUON_HEAD=$(gh api repos/nuonco/nuon/commits/main --jq '.sha')

echo "  nuonco/nuon HEAD: ${NUON_HEAD:0:12}"

# --- Get tracked files with SHAs ---

echo "Discovering tracked files in nuonco/nuon..."
NUON_FILES=$(get_tracked_files "nuonco/nuon" "${NUON_PREFIXES[@]}")
NUON_COUNT=$(echo "$NUON_FILES" | grep -c '"path"' || true)
echo "  Found $NUON_COUNT tracked files"

# --- Build baseline JSON ---

echo "Building baseline.json..."

# Convert file listings to JSON objects
NUON_TRACKED=$(echo "$NUON_FILES" | jq -s 'map({(.path): .sha}) | add // {}')

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -n \
  --arg version "1" \
  --arg timestamp "$TIMESTAMP" \
  --arg nuon_commit "$NUON_HEAD" \
  --argjson nuon_files "$NUON_TRACKED" \
  '{
    version: $version,
    last_sync: $timestamp,
    repos: {
      "nuonco/nuon": {
        commit: $nuon_commit,
        branch: "main",
        tracked_files: $nuon_files
      }
    }
  }' > "$BASELINE_FILE"

echo ""
echo "Baseline written to $BASELINE_FILE"
echo "  nuonco/nuon: $NUON_COUNT files tracked at ${NUON_HEAD:0:12}"
echo ""
echo "Done. The upgrade agent can now detect changes from this baseline."
