#!/bin/bash
# spec-pr-test.sh - Tests that the spec-pr skill derives the correct [SPEC] PR title
# from a spec heading by kebab-casing.

set -euo pipefail

# --- Kebab-case function (mirrors the skill's documented rules) ---
kebab_case() {
  local input="$1"
  # lowercase
  input="$(echo "$input" | tr '[:upper:]' '[:lower:]')"
  # trim leading/trailing whitespace
  input="$(echo "$input" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  # collapse internal whitespace to single hyphens
  input="$(echo "$input" | tr -s '[:space:]' '-')"
  # remove characters invalid in a GitHub PR title or directory name
  # (keep lowercase letters, digits, hyphens)
  input="$(echo "$input" | tr -cd 'a-z0-9-')"
  # collapse multiple consecutive hyphens
  input="$(echo "$input" | tr -s '-')"
  # trim leading/trailing hyphens
  input="$(echo "$input" | sed 's/^-//;s/-$//')"
  echo "$input"
}

# --- Test ---
SPEC_HEADING="Widget 7 new feature"
EXPECTED_NAME="widget-7-new-feature"
EXPECTED_PR_TITLE="[SPEC] widget-7-new-feature"

ACTUAL_NAME="$(kebab_case "$SPEC_HEADING")"
ACTUAL_PR_TITLE="[SPEC] $ACTUAL_NAME"

if [ "$ACTUAL_NAME" != "$EXPECTED_NAME" ]; then
  echo "FAIL: kebab_case('$SPEC_HEADING') = '$ACTUAL_NAME', expected '$EXPECTED_NAME'" >&2
  exit 1
fi

if [ "$ACTUAL_PR_TITLE" != "$EXPECTED_PR_TITLE" ]; then
  echo "FAIL: PR title = '$ACTUAL_PR_TITLE', expected '$EXPECTED_PR_TITLE'" >&2
  exit 1
fi

# --- Edge case: extra spaces and mixed case ---
SPEC_HEADING_2="  My   GREAT  Feature  "
EXPECTED_NAME_2="my-great-feature"

ACTUAL_NAME_2="$(kebab_case "$SPEC_HEADING_2")"

if [ "$ACTUAL_NAME_2" != "$EXPECTED_NAME_2" ]; then
  echo "FAIL: kebab_case('$SPEC_HEADING_2') = '$ACTUAL_NAME_2', expected '$EXPECTED_NAME_2'" >&2
  exit 1
fi

echo "spec-pr kebab-case OK"
