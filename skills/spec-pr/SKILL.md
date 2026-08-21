---
name: spec-pr
description: Raises a pull request to merge the written specification, plan, and task checklist into the default branch. Use when the specification document is complete and you want to submit it as a PR for team review before implementation begins; triggers on "raise a PR for the spec", "submit the spec for review", or "create a spec PR".
---

# Spec PR

## Overview

Raise a pull request for the spec, plan, and todo files themselves — not the implementation. The PR uses the `[SPEC]` prefix to distinguish it from build-tracking issues (which use `[BUILD]`). This is the "merge the spec" step that `issue-create` assumes has already happened.

## When to Use

- A spec/plan/todo has been written under `/specs/<feature>/` and is ready for team review
- You want to merge the specification via a PR before creating a build issue
- You need a durable, reviewable record of the spec's acceptance

**When NOT to use:** Raising a PR for implemented code (use `issue-pr` instead). Raising a build-tracking issue (use `issue-create` instead).

## Process

### Step 1: Read the spec and derive the name

Read the spec at `/specs/<feature>/SPEC.md`. Kebab-case the text after `# Spec:` in the heading to derive `<name>`:

```
# Spec: Widget 7 new feature
                  ↓ kebab-case
widget-7-new-feature
```

Rules: lowercase, trim, collapse internal whitespace to single hyphens, strip characters that are invalid in a GitHub PR title or directory name. The directory name and the PR `<name>` are identical strings.

If no `# Spec:` heading exists, stop and tell the user — do not guess the name.

### Step 2: Ensure the `spec` label exists

Run `gh label create spec --force` to create the label if absent or update it if present. The `--force` flag makes this idempotent.

### Step 3: Determine branches

- **Head branch:** the current git branch (the one with the spec/plan/todo commits).
- **Base branch:** the repo's default branch. Detect it with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`, or accept it from the user.

### Step 4: Compose the PR body

The body should:
- Reference the spec, plan, and todo files with relative paths
- Include a one-paragraph summary pulled from the spec's `## Objective` section
- State that this PR is for the spec/plan/tasks, not the implementation

Example body:

```markdown
## Summary

[One-paragraph summary from the spec's ## Objective section]

## Artifacts

- Spec: `/specs/<feature>/SPEC.md`
- Plan: `/specs/<feature>/tasks/plan.md`
- Todo: `/specs/<feature>/tasks/todo.md`

## Next steps

Once this PR is reviewed and merged, run `/issue-create` to open a `[BUILD] <name>` issue for the implementation.
```

### Step 5: Create the PR

```bash
gh pr create \
  --title "[SPEC] <name>" \
  --label spec \
  --body-file <body-file> \
  --base <default-branch>
```

Use `--title` and `--body-file` (never `--web` — skills must be scriptable). Write the body to a temporary file and pass it via `--body-file`.

### Step 6: Report

Report the PR URL back to the user. State explicitly that the PR has been opened but not merged — merging is a human action.

## Naming Convention

| Artefact | Prefix | Label | Raised by |
|---|---|---|---|
| **Spec PR** (this skill) | `[SPEC]` | `spec` | `/spec-pr` |
| **Build Issue** | `[BUILD]` | `build` | `/issue-create` |

Both share the same kebab-cased `<name>` derived from `# Spec:` in the spec heading. The prefix is the disambiguation signal.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I can just push to main" | The spec is the shared source of truth — it deserves a reviewable PR, not a direct push. |
| "The spec doesn't need a label" | The `spec` label distinguishes spec PRs from implementation PRs and build issues in GitHub's filter view. |
| "I'll merge it myself" | Merging is a human action. This skill opens the PR; it does not merge or close anything. |
| "I'll use [BUILD] since it's all the same" | The prefixes are disambiguation signals. `[SPEC]` is for spec PRs; `[BUILD]` is for build issues. Never mix them. |

## Red Flags

- Using the `[BUILD]` prefix on a spec PR (should be `[SPEC]`)
- Using `--web` instead of `--title`/`--body-file` (skills must be scriptable)
- Merging the PR as part of the skill (merging is a human action)
- Guessing `<name>` instead of deriving it from the `# Spec:` heading
- Creating the PR without the `spec` label

## Verification

- [ ] The PR title is `[SPEC] <name>` where `<name>` is kebab-cased from `# Spec:`
- [ ] The `spec` label exists and is applied to the PR
- [ ] The PR body references the spec, plan, and todo files
- [ ] The PR is opened against the repo's default branch
- [ ] The PR URL is reported back to the user
- [ ] The skill does not merge the PR
