#!/bin/bash
# issue-list-test.sh - Tests that the issue-list skill correctly filters issues by [BUILD] prefix.
# Uses mock gh issue list JSON output instead of calling the real GitHub API.

set -euo pipefail

# --- Mock gh issue list output ---
# Contains a mix of matching and non-matching titles:
# - [BUILD] foo          → should match
# - [BUILD] bar          → should match
# - bug: baz             → should NOT match (no prefix)
# - [BUILD]              → should NOT match (no trailing space)
# - [SPEC] qux           → should NOT match (wrong prefix)
# - [BUILD] payment-gw   → should match
MOCK_ISSUES='[
  {"number": 42, "title": "[BUILD] foo", "url": "https://github.com/owner/repo/issues/42"},
  {"number": 57, "title": "[BUILD] bar", "url": "https://github.com/owner/repo/issues/57"},
  {"number": 12, "title": "bug: baz", "url": "https://github.com/owner/repo/issues/12"},
  {"number": 99, "title": "[BUILD]", "url": "https://github.com/owner/repo/issues/99"},
  {"number": 33, "title": "[SPEC] qux", "url": "https://github.com/owner/repo/issues/33"},
  {"number": 71, "title": "[BUILD] payment-gw", "url": "https://github.com/owner/repo/issues/71"}
]'

# --- Filtering function (mirrors the skill's documented logic) ---
filter_build_issues() {
  local json="$1"
  # Use node to parse JSON and filter by [BUILD] prefix (with trailing space)
  echo "$json" | node -e '
    const issues = JSON.parse(require("fs").readFileSync(0, "utf8"));
    const filtered = issues
      .filter(i => i.title.startsWith("[BUILD] "))
      .map(i => `${i.number}\t${i.title}\t${i.url}`)
      .join("\n");
    if (filtered) console.log(filtered);
  '
}

# --- Test ---
FILTERED="$(filter_build_issues "$MOCK_ISSUES")"

# Expected: 42, 57, 71 (the three [BUILD] issues with trailing space)
EXPECTED_COUNT=3
ACTUAL_COUNT="$(echo "$FILTERED" | grep -c . || true)"

if [ "$ACTUAL_COUNT" != "$EXPECTED_COUNT" ]; then
  echo "FAIL: expected $EXPECTED_COUNT issues, got $ACTUAL_COUNT" >&2
  echo "$FILTERED" >&2
  exit 1
fi

# Verify each expected issue is present
TAB=$'\t'
for expected in "^42${TAB}\[BUILD\] foo" "^57${TAB}\[BUILD\] bar" "^71${TAB}\[BUILD\] payment-gw"; do
  if ! echo "$FILTERED" | grep -q "$expected"; then
    echo "FAIL: expected issue not found in filtered output: $expected" >&2
    exit 1
  fi
done

# Verify excluded issues are NOT present
for excluded in "bug: baz" "\[BUILD\]$" "\[SPEC\] qux"; do
  if echo "$FILTERED" | grep -q "$excluded"; then
    echo "FAIL: excluded issue found in filtered output: $excluded" >&2
    exit 1
  fi
done

echo "issue-list filter OK"
