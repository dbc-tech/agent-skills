---
name: issue-pr
description: Submits pull requests for a completed build and links them to the build issue. Use when a build is ready for review, when implementation PRs must link to a build issue, or when submitting a spec-governed PR stack. Uses GitHub Stacked PRs for spec-governed work and a standard PR only for small unspecced changes.
---

# Issue PR

## Overview

Submit implementation pull requests linked to the corresponding `[BUILD]` issue. Work governed by a `SPEC.md` and companion implementation plan is submitted as GitHub Stacked PRs, with one focused layer per planned task by default. Small changes without a spec keep the standard single-PR path.

This skill opens PRs for review. It does not merge them or close the build issue directly.

## When to Use

- The implementation is complete and ready for review
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

- **Stacked mode:** both a governing spec and companion implementation plan or task list exist. Read them and treat their task grouping, exact branch names, stack order, dependencies, phases, checkpoints, and designated closing layer as authoritative.
- **Standalone mode:** no governing spec and companion plan exist. Use one normal PR; do not manufacture a one-layer stack for a small unspecced change.

A README or arbitrary design note is not a governing spec.

For stacked mode, run `gh stack --version`. If `gh` exists but the extension is missing, install the official extension and check again:

```bash
gh extension install github/gh-stack
gh stack --version
```

Stop if GitHub Stacked PRs are unsupported for the repository or authentication fails.

### Step 3: Validate completed work

Require a clean working tree before submission. For stacked mode:

1. Confirm each completed task is on the branch assigned by the Delivery Plan.
2. Run `gh stack view` for every planned stack and compare the branch order with the task dependency graph.
3. Confirm each layer satisfies its task acceptance criteria and verification.
4. Confirm exactly one layer is designated to close the build issue. Its merge must be ordered after every other required stack and final checkpoint.
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

### Step 6: Submit every planned stack

For each stack, check out a branch in that stack and run:

```bash
gh stack submit --auto --open
```

`--auto` keeps submission scriptable and `--open` makes new PRs ready for review instead of drafts. After submission, apply the planned title, body, and label to each branch:

```bash
gh pr edit <branch> \
  --title "[BUILD] <feature>: Task <n> - <task title>" \
  --body-file <body-file> \
  --add-label build
```

Use a temporary body file per layer. Do not use `gh pr create` for stack members; `gh stack submit` creates the PRs with the correct parent branches and links them as a stack.

### Step 7: Standalone fallback

For a small unspecced change, retain the standard PR flow:

1. Derive the title from the issue and keep the `[BUILD]` prefix.
2. Put `Resolves #<n>` at the top of the body.
3. Summarize the change and verification.
4. Open the PR against the default branch with `gh pr create --title <title> --body-file <body-file> --base <default-branch> --label build`.

Do not use this fallback merely because a spec-driven build has only one task. A spec-governed one-layer implementation is still initialized and submitted through `gh stack`.

### Step 8: Report

Report every PR URL grouped by stack and ordered from bottom to top. State explicitly that:

- The PRs are open but not merged
- Non-closing layers use `Part of #<n>`
- Only the designated final layer uses `Resolves #<n>`
- The stack must remain current with `gh stack rebase` or `gh stack sync`
- A stack or partial phase may be merged with `gh stack merge --yes` only after the relevant checkpoint, acceptance criteria, checks, and reviews pass

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

## Red Flags

- Using `gh pr create` for a spec-governed stack member
- Submitting a spec-governed build as one PR despite multiple planned tasks
- Putting `Resolves #<n>` on multiple layers
- Omitting task, phase, dependency, acceptance, or verification details from a layer
- Stack branch order differs from the approved plan
- Parallel-safe tasks are stacked without a real dependency
- Submitting with unresolved rebase conflicts or a dirty working tree
- Running `gh pr merge` for a stack member
- Merging as part of this skill

## Verification

- [ ] Delivery mode was selected from the presence of a governing spec and companion plan
- [ ] `gh stack view` matches the approved Delivery Plan for every stack
- [ ] `gh stack submit --auto --open` created or updated every spec-governed PR
- [ ] Every layer has the `build` label and task-specific title and body
- [ ] Non-closing layers use `Part of #<n>`
- [ ] Exactly one designated final layer uses `Resolves #<n>`
- [ ] Standalone `gh pr create` was used only for a small unspecced change
- [ ] All PR URLs were reported in stack order
- [ ] No PR or issue was merged or closed directly
