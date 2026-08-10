---
name: issue-list
description: Lists open GitHub Issues that track builds for merged specs, filtering by the [BUILD] title prefix. Use when you want to see which specs have open build issues; triggers on "list build issues", "show spec build issues", or "what specs are waiting to be built".
---

# Issue List

## Overview

List all open GitHub Issues whose title starts with `[BUILD] `, presenting their issue number, title, and URL. This skill filters client-side on the title prefix rather than relying on the `build` label, so it works even on repos where the label hasn't been applied yet.

## When to Use

- You want to see which specs have open build issues
- You need to find an issue number to pass to `/issue-build` or `/issue-pr`
- You're checking the status of the issue-driven build pipeline

**When NOT to use:** Creating a new build issue (use `issue-create` instead). Raising a PR (use `issue-pr` instead). Listing all issues regardless of prefix (use `gh issue list` directly).

## Process

### Step 1: Prerequisites check

Verify `gh` is on `PATH`. If not, stop and tell the user — this skill requires the GitHub CLI.

### Step 2: Fetch open issues

Run the following command to fetch all open issues with their number, title, and URL:

```bash
gh issue list --state open --json number,title,url --limit 100
```

This returns a JSON array of issue objects. The `--limit 100` prevents unbounded output on repos with many issues.

### Step 3: Filter by [BUILD] prefix

Filter the JSON output client-side to only issues whose `title` starts with the literal string `[BUILD] ` (including the trailing space). This is a string prefix match, not a regex or label lookup.

Issues with titles like `[BUILD] widget-7` match. Issues with `[SPEC] widget-7`, `bug: fix crash`, or `[BUILD]` (no trailing space) do not match.

### Step 4: Present the results

Present the filtered issues in a table format:

```
 #   Title                        URL
─── ───────────────────────────── ─────────────────────────────────
 42  [BUILD] widget-7             https://github.com/owner/repo/issues/42
 57  [BUILD] payment-gateway-v2   https://github.com/owner/repo/issues/57
```

If no issues match, report "No open [BUILD] issues found."

## Naming Convention

| Artefact | Prefix | Label | Raised by |
|---|---|---|---|
| **Spec PR** | `[SPEC]` | `spec` | `/spec-pr` |
| **Build Issue** | `[BUILD]` | `build` | `/issue-create` |

This skill filters on the `[BUILD] ` prefix, not the `build` label. The title prefix is the primary disambiguation signal; the label is secondary.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just list all issues" | Without filtering, the list is noise — unrelated issues, bug reports, and feature requests drown out the build-tracking issues. The `[BUILD] ` prefix filters to only what matters. |
| "I'll filter by label instead of prefix" | The `build` label might not exist yet (e.g. on a repo where `issue-create` hasn't been run). The title prefix always works because it's part of the issue title, not a separate metadata field. |
| "I don't need a limit" | Repos with hundreds of issues will produce huge JSON output. The `--limit 100` keeps the command fast and the output manageable. |

## Red Flags

- Filtering on `[BUILD]` without the trailing space (would match `[BUILD]` and `[BUILD]foo`)
- Using label-based filtering instead of prefix-based (label may not exist)
- Fetching without `--limit` (unbounded output on large repos)
- Proceeding when `gh` is not on `PATH` without telling the user

## Verification

- [ ] Only open issues whose title starts with `[BUILD] ` (including trailing space) are listed
- [ ] Closed issues are excluded
- [ ] Issues with `[SPEC]` prefix are excluded
- [ ] Issues with `[BUILD]` (no trailing space) are excluded
- [ ] The skill fails with a clear diagnostic when `gh` is not on `PATH`
