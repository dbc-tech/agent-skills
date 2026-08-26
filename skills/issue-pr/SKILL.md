---
name: issue-pr
description: Submits pull requests for completed implementation stacks and links them to the build issue. Use when a build or planned checkpoint is ready for review, when implementation PRs must link to a build issue, or when submitting a spec-governed PR stack. Uses GitHub Stacked PRs for spec-governed work and a standard PR only for small unspecced changes.
---

# Issue PR

## Overview

Submit implementation pull requests linked to the corresponding `[BUILD]` issue. Work governed by a `SPEC.md` and companion implementation plan is submitted as GitHub Stacked PRs, with one focused layer per planned task by default. Small changes without a spec keep the standard single-PR path.

This skill opens PRs for review. It does not merge them or close the build issue directly.

## When to Use

- One or more implementation stacks have reached a planned review or merge checkpoint
- You have a `[BUILD]` issue number that should be linked from the implementation PRs
- A spec-driven build produced one or more planned stacks

**When NOT to use:** Raising a PR for the spec itself (use `spec-pr`). Creating a build-tracking issue (use `issue-create`). Implementing tasks (use `issue-build`).

## Process

### Step 1: Check prerequisites and fetch the issue

Verify `gh` is on `PATH` and authenticated. If not, stop with the specific prerequisite error.

Require an issue number, then run:

```bash
gh issue view <n> --json title,body
```

### Step 2: Select the delivery mode

Resolve the spec, plan, and task-list paths from the issue body. If the issue body has no paths, derive the feature name from its `[BUILD] <name>` title and check `/specs/<name>/SPEC.md`, `/specs/<name>/tasks/plan.md`, and `/specs/<name>/tasks/todo.md`, followed by the legacy root paths.

- **Stacked mode:** both a governing spec and companion implementation plan exist. Read them and treat the plan's task grouping, exact branch names, trunks, start conditions, stack order, dependencies, phases, checkpoints, and designated closing layer as authoritative.
- **Standalone mode:** neither a governing spec nor companion plan exists. Use one normal PR; do not manufacture a one-layer stack for a small unspecced change.
- **Inconsistent mode:** exactly one of the governing spec or plan exists. Stop and repair the missing artefact; never silently downgrade partially spec-governed work to a standalone PR.

A README or arbitrary design note is not a governing spec.

For stacked mode, run `gh stack --version`. If `gh` exists but the extension is missing, stop, tell the user, and offer the official installation command:

```bash
gh extension install github/gh-stack
```

Install it only with user approval, then rerun `gh stack --version`. If authentication fails, stop with the diagnostic.

Before changing any PR state, detect the repository and probe Stack API support:

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
gh api repos/<owner>/<repo>/stacks --silent
```

If the probe reports unsupported or `404`, preserve the completed branches and stop before moving any PR to draft. Ask the user to either enable/use a supported repository or explicitly approve a delivery-policy exception. With that explicit approval only, submit the same linear branch chain as regular PRs, setting each PR's base to the preceding planned branch and the bottom PR's base to the declared trunk. Record the exception in every PR body. Never fall back silently.

### Step 3: Validate completed work

Require a clean working tree before submission. Determine the **ready stack set** from completed task statuses and reached checkpoints; later stacks whose start conditions are still blocked are not part of this submission. For each ready stack:

1. Confirm each completed task is on the branch assigned by the Delivery Plan.
2. Run `gh stack view --json` and require the active local stack to equal the ready checkpoint prefix exactly. If branches above the checkpoint already exist, stop and restructure or separate them before submission; `gh stack submit --auto` operates on the whole active stack.
3. Confirm each layer satisfies its task acceptance criteria and verification.
4. Use `Resolves #<n>` on the designated closing layer only when every task and final checkpoint in the full Delivery Plan is complete. At an intermediate checkpoint, every submitted layer uses `Part of #<n>`.
5. Run `gh stack rebase` for each stack before submission. Stop on conflicts instead of bypassing them.

One task per layer is the default. Accept combined tasks only when the approved plan explicitly groups them because they must land together or cannot verify independently.

### Step 4: Ensure the build label exists

Run `gh label create build --force`. The same label groups implementation PRs with their build issue.

### Step 5: Compose stacked PR metadata

Name each branch and PR for its spec task. Keep the `[BUILD]` prefix while making the layer independently identifiable:

```text
[BUILD] <feature>: Task <n> - <task title>
```

Every stacked PR body must include:

- `Part of #<n>` at the top for non-closing layers
- `Resolves #<n>` at the top only for the single designated closing layer
- Governing spec, plan, and task-list paths
- Task number and title
- Phase, stack name, and layer position
- Dependencies and required merge/checkpoint order
- Acceptance criteria addressed by the layer
- Verification commands and results

Example non-closing layer:

```markdown
Part of #42

## Task

- Task: 2 - Add API endpoints
- Phase: Core
- Stack: notifications, layer 2 of 3
- Depends on: Task 1

## Artefacts

- Spec: `/specs/notifications/SPEC.md`
- Plan: `/specs/notifications/tasks/plan.md`
- Todo: `/specs/notifications/tasks/todo.md`

## Acceptance Criteria

- [Completed criteria from the task]

## Verification

- `npm test`
- `npm run build`
```

The designated final layer uses `Resolves #42` instead of `Part of #42`. Never put `Resolves` on every layer; merging a lower or parallel layer would close the build issue before the full implementation lands.

### Step 6: Submit the ready stack set

Prepare every title and body file before publishing. Before resubmitting a branch with an existing ready PR, inspect it and move it back to draft; if that fails, stop before editing metadata:

```bash
gh pr view <branch> --json isDraft
gh pr ready --undo <branch> # only when the existing PR is ready
```

For each ready stack, check out a branch in that stack and submit without `--open` so new PRs remain drafts while metadata is applied:

```bash
gh stack submit --auto
```

After submission, apply the planned title, body, and label to each branch:

```bash
gh pr edit <branch> \
  --title "[BUILD] <feature>: Task <n> - <task title>" \
  --body-file <body-file> \
  --add-label build
```

Verify each PR's metadata while it is still a draft:

```bash
gh pr view <branch> --json title,body,labels,isDraft
```

For stacks with two or more layers, verify remote GitHub Stack membership through the REST API for every PR:

```bash
gh api repos/<owner>/<repo>/pulls/<pr-number> --jq '.stack'
```

Require a non-null stack object with the planned base, size, and position. If remote linking or metadata verification fails, leave the PRs as drafts, report the affected branches, and stop. GitHub's Stack API requires at least two PRs, so a spec-governed one-layer submission uses the stack CLI and conventions but produces one ordinary remote PR; report that explicitly.

Only after metadata and remote membership checks pass, mark each draft ready:

```bash
gh pr ready <branch>
```

Use a temporary body file per layer. Do not use `gh pr create` for stack members in a supported repository; `gh stack submit` creates the PRs with the correct parent branches and links multi-layer submissions as a stack.

### Step 7: Standalone fallback

For a small unspecced change, retain the standard PR flow:

1. Derive the title from the issue and keep the `[BUILD]` prefix.
2. Put `Resolves #<n>` at the top of the body.
3. Summarize the change and verification.
4. Detect the default branch with `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`.
5. Open the PR with `gh pr create --title <title> --body-file <body-file> --base <default-branch> --label build`.

Use `--title` and `--body-file`, never `--web`; skills must remain scriptable. Do not use this fallback merely because a spec-driven build has only one task. A spec-governed one-layer implementation is still initialized and submitted through `gh stack` when the repository supports it.

### Step 8: Report

Report every submitted PR URL grouped by ready stack and ordered from bottom to top. State explicitly that:

- The PRs are open but not merged
- Non-closing layers use `Part of #<n>`
- Only the designated final layer uses `Resolves #<n>`
- At intermediate checkpoints no layer resolves the issue, and later blocked stacks remain unsubmitted
- The stack must remain current with `gh stack rebase` or `gh stack sync`
- A full stack may be merged with `gh stack merge --yes` only after all stack checkpoints pass
- A partial phase must name its top PR: `gh stack merge <phase-top-pr-number> --yes`; never use bare `--yes` for a partial merge

Merging remains a human action; do not run the merge command as part of this skill.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "One PR is simpler" | For spec-governed work, the approved task graph defines independently reviewable layers. A single large PR discards that structure. |
| "We can link separate PRs later" | `gh stack submit` creates correct parent branches and stack metadata. Use it instead of `gh pr create` for members. |
| "Every PR should resolve the issue" | The first merged layer would close the issue early. Only the designated final layer resolves it. |
| "Parallel tasks can go in one stack" | A stack declares dependency. Parallel-safe tasks use separate stacks unless the plan records a real dependency. |
| "A one-task spec does not need gh stack" | The rule is based on governance, not layer count. A spec plus plan uses the stack workflow consistently. |
| "I'll merge it now" | This skill submits for review. Checkpoints, checks, and reviews must pass before a human merges with `gh stack merge`. |
| "The repository does not support stacks, so I'll silently use normal PRs" | Delivery mode is an approved policy. Preserve the branches and get an explicit exception before creating a regular PR chain. |
| "Later stacks are in the plan, so issue-pr must submit them now" | Submit only completed stacks at reached checkpoints. Future stacks may not exist until their prerequisites merge. |

## Red Flags

- Using `gh pr create` for a spec-governed stack member without an explicit unsupported-repository exception
- Submitting a spec-governed build as one PR despite multiple planned tasks
- Putting `Resolves #<n>` on multiple layers
- Omitting task, phase, dependency, acceptance, or verification details from a layer
- Stack branch order differs from the approved plan
- Attempting to validate or submit a future stack whose start condition is still blocked
- Parallel-safe tasks are stacked without a real dependency
- Submitting with unresolved rebase conflicts or a dirty working tree
- Running `gh pr merge` for a stack member
- Merging as part of this skill
- Using `--web` instead of scriptable title/body-file commands
- Using bare `gh stack merge --yes` when only a partial phase should merge

## Verification

- [ ] Delivery mode was selected from the presence of a governing spec and companion plan
- [ ] `gh stack view --json` matches the approved Delivery Plan for every ready stack
- [ ] Existing ready PRs were moved to draft before metadata edits
- [ ] `gh stack submit --auto` created new spec-governed PRs as drafts before metadata edits
- [ ] Every layer has the `build` label and task-specific title and body
- [ ] Every PR was verified before `gh pr ready <branch>` marked it ready for review
- [ ] Every multi-layer PR has a non-null remote `.stack` object with the planned base, size, and position
- [ ] Non-closing layers use `Part of #<n>`
- [ ] Exactly one designated final layer uses `Resolves #<n>` only when the full Delivery Plan is complete; intermediate submissions use only `Part of #<n>`
- [ ] Standalone or chained `gh pr create` was used only for a small unspecced change or an explicitly approved unsupported-repository exception
- [ ] All PR URLs were reported in stack order
- [ ] No PR or issue was merged or closed directly
