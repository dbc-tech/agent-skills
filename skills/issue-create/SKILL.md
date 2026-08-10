---
name: issue-create
description: Opens a GitHub Issue to track the build for a merged specification, using the [BUILD] naming convention. Use when a spec has been merged via PR and you want to track its build as a GitHub Issue; triggers on "create an issue for the build", "raise a build issue for this spec", or "track this spec in GitHub".
---

# Issue Create

## Overview

Open a GitHub Issue that summarises a merged spec and links to its spec/plan/todo files. The issue uses the `[BUILD]` prefix to distinguish it from spec PRs (which use `[SPEC]`). This is the step that creates a durable, trackable record connecting "the merged spec" to "the build that implements it."

## When to Use

- A spec has been merged via a `[SPEC]` PR (raised by `spec-pr`) and is ready for implementation
- You want to track the implementation of a spec as a GitHub Issue
- You need a single issue that `issue-build` and `issue-pr` can reference

**When NOT to use:** Raising a PR for the spec itself (use `spec-pr` instead). Raising a PR for the implementation (use `issue-pr` instead). Listing existing build issues (use `issue-list` instead).

## Process

### Step 1: Prerequisites check

Verify `gh` is on `PATH`. If not, stop and tell the user — this skill requires the GitHub CLI.

### Step 2: Read the spec and derive the name

Read the spec at `specs/<feature>/SPEC.md`. Kebab-case the text after `# Spec:` in the heading to derive `<name>`:

```
# Spec: Widget 7 new feature
                  ↓ kebab-case
widget-7-new-feature
```

Rules: lowercase, trim, collapse internal whitespace to single hyphens, strip characters that are invalid in a GitHub issue title or directory name. The directory name and the issue `<name>` are identical strings.

If no `# Spec:` heading exists, stop and tell the user — do not guess the name.

### Step 3: Ensure the `build` label exists

Run `gh label create build --force` to create the label if absent or update it if present. The `--force` flag makes this idempotent.

### Step 4: Compose the issue body

The body should:
- Link to the spec, plan, and todo files with relative paths
- Include a one-paragraph summary pulled from the spec's `## Objective` section
- State the next steps for the developer

Example body:

```markdown
## Summary

[One-paragraph summary from the spec's ## Objective section]

## Artefacts

- Spec: `specs/<feature>/SPEC.md`
- Plan: `specs/<feature>/tasks/plan.md`
- Todo: `specs/<feature>/tasks/todo.md`

## Next steps

Run `/issue-build <this-issue-number>` to begin implementation.
When the build is complete, run `/issue-pr <this-issue-number>` to raise a PR.
```

### Step 5: Create the issue

```bash
gh issue create \
  --title "[BUILD] <name>" \
  --label build \
  --body-file <body-file>
```

Use `--title` and `--body-file` (never `--web` — skills must be scriptable). Write the body to a temporary file and pass it via `--body-file`.

### Step 6: Report

Report the issue number and URL back to the user. State explicitly that the issue has been opened to track the build — not the spec itself.

## Naming Convention

| Artefact | Prefix | Label | Raised by |
|---|---|---|---|
| **Spec PR** | `[SPEC]` | `spec` | `/spec-pr` |
| **Build Issue** (this skill) | `[BUILD]` | `build` | `/issue-create` |

Both share the same kebab-cased `<name>` derived from `# Spec:` in the spec heading. The prefix is the disambiguation signal.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just start building, no need for an issue" | The issue is the durable link between the merged spec and the build. Without it, there's no trackable record of which spec is being implemented. |
| "I'll use [SPEC] since the issue is about a spec" | The `[BUILD]` prefix distinguishes build-tracking issues from spec PRs. Using `[SPEC]` would collide with the PR that merged the spec. |
| "The issue doesn't need a label" | The `build` label distinguishes build issues from spec PRs and other issues in GitHub's filter view. |
| "I'll create the issue before the spec PR is merged" | The spec should be merged first. The issue body links to the spec/plan/todo files, which need to be on the default branch for the links to resolve. |

## Red Flags

- Using the `[SPEC]` prefix on a build issue (should be `[BUILD]`)
- Using `--web` instead of `--title`/`--body-file` (skills must be scriptable)
- Creating the issue before the spec has been merged (links won't resolve)
- Guessing `<name>` instead of deriving it from the `# Spec:` heading
- Creating the issue without the `build` label
- Proceeding when `gh` is not on `PATH` without telling the user

## Verification

- [ ] The issue title is `[BUILD] <name>` where `<name>` is kebab-cased from `# Spec:`
- [ ] The `build` label exists and is applied to the issue
- [ ] The issue body links to the spec, plan, and todo files
- [ ] The skill fails with a clear diagnostic when no `# Spec:` heading exists
- [ ] The skill fails with a clear diagnostic when `gh` is not on `PATH`
- [ ] The issue number and URL are reported back to the user
