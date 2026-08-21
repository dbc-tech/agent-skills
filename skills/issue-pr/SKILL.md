---
name: issue-pr
description: Raises a pull request for the implementation of a spec, linking it to the corresponding build issue via Resolves. Use when the build is complete and you want to raise a PR that GitHub links to the build issue; triggers on "raise a PR for the implementation", "create a PR linked to this issue", or "submit the build for review".
---

# Issue PR

## Overview

Raise a pull request for the implementation of a spec, linking it to the corresponding `[BUILD]` issue. The PR body references the issue with `Resolves #<n>` so GitHub automatically links the PR to the issue and closes the issue when the PR is merged. The PR carries the `build` label, distinguishing implementation PRs from spec PRs (labelled `spec`) in GitHub's filter view. This skill does not merge the PR or close the issue — merging is a human action.

## When to Use

- The build (implementation) is complete and you want to raise a PR for review
- You have a `[BUILD]` issue number and want the PR to link back to it
- You need GitHub to automatically close the build issue when the PR is merged

**When NOT to use:** Raising a PR for the spec itself (use `spec-pr` instead). Creating a build-tracking issue (use `issue-create` instead). Implementing tasks (use `issue-build` instead).

## Process

### Step 1: Prerequisites check

Verify `gh` is on `PATH`. If not, stop and tell the user — this skill requires the GitHub CLI.

### Step 2: Fetch the issue

Run `gh issue view <n> --json title,body` to fetch the issue's title and body. Extract the issue number from the argument.

If no issue number is provided, stop and ask the user for it.

### Step 3: Determine branches

- **Head branch:** the current git branch (the one with the implementation commits).
- **Base branch:** the repo's default branch. Detect it with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, or accept it from the user.

### Step 4: Compose the PR body

The body should:
- Reference the issue with `Resolves #<n>` so GitHub links the PR to the issue and closes it on merge
- Summarise the work done against the spec/plan/todo
- Reference the spec/plan/todo file paths (if available from the issue body)

Example body:

```markdown
Resolves #42

## Summary

[One-paragraph summary of the work done against the spec]

## Artefacts

- Spec: `/specs/<feature>/SPEC.md`
- Plan: `/specs/<feature>/tasks/plan.md`
- Todo: `/specs/<feature>/tasks/todo.md`
```

The `Resolves #<n>` line must be at the top of the body so GitHub reliably detects it.

### Step 5: Derive the PR title

Derive the PR title from the issue title, keeping the `[BUILD]` prefix so the PR is visually grouped with its build issue in listings and search (spec PRs use the `[SPEC]` prefix via `spec-pr`):

```
Issue title: [BUILD] widget-7-new-feature
PR title:    [BUILD] widget-7-new-feature
```

Alternatively, accept a custom title from the user if they prefer a more descriptive PR title — prefix it with `[BUILD] ` too, so every implementation PR in this workflow is identifiable by its prefix.

### Step 6: Ensure the `build` label exists

Run `gh label create build --force` to create the label if absent or update it if present. The `--force` flag makes this idempotent. This is the same label `issue-create` applies to build-tracking issues, so implementation PRs and their build issues filter together.

### Step 7: Create the PR

```bash
gh pr create \
  --title "<title>" \
  --body-file <body-file> \
  --base <default-branch> \
  --label build
```

Use `--title` and `--body-file` (never `--web` — skills must be scriptable). Write the body to a temporary file and pass it via `--body-file`.

### Step 8: Report

Report the PR URL back to the user. State explicitly that:
- The PR has been opened but not merged — merging is a human action
- The PR is linked to issue `#<n>` via `Resolves #<n>` — GitHub will close the issue when the PR is merged

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just merge directly" | Merging is a human action. The skill opens the PR; it does not merge or close anything. |
| "I don't need Resolves #<n>" | Without `Resolves #<n>`, GitHub won't link the PR to the issue. The issue would need to be closed manually after the PR merges. |
| "I'll close the issue myself" | If `Resolves #<n>` is in the PR body, GitHub auto-closes the issue on merge. Let the convention work — don't close manually. |
| "I'll use --web" | Skills must be scriptable. Use `--title` and `--body-file` so the PR creation is reproducible. |
| "The PR doesn't need a label" | The `build` label distinguishes implementation PRs from spec PRs and other PRs in GitHub's filter view, and groups each PR with its build issue. |

## Red Flags

- Using `--web` instead of `--title`/`--body-file` (skills must be scriptable)
- Merging the PR as part of the skill (merging is a human action)
- Closing the issue manually (the `Resolves #<n>` in the PR body handles this on merge)
- Omitting `Resolves #<n>` from the PR body (GitHub won't link the PR to the issue)
- Putting `Resolves #<n>` anywhere but the top of the body (GitHub may not detect it)
- Proceeding when `gh` is not on `PATH` without telling the user
- Creating the PR without the `build` label
- Stripping the `[BUILD]` prefix from the PR title (the prefix groups the PR with its build issue; spec PRs carry `[SPEC]`)

## Verification

- [ ] The PR body contains `Resolves #<n>` at the top
- [ ] The PR title is derived from the issue title and keeps the `[BUILD]` prefix (or a user-provided custom title, prefixed with `[BUILD] `)
- [ ] The PR is opened against the repo's default branch
- [ ] The skill reports the PR URL back to the user
- [ ] The skill explicitly states it does not merge the PR or close the issue
- [ ] The `build` label exists and is applied to the PR
- [ ] The skill fails with a clear diagnostic when `gh` is not on `PATH`
