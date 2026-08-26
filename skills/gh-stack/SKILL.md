---
name: gh-stack
description: Manages linear stacks of dependent branches and pull requests with GitHub's gh-stack CLI extension. Use when creating, editing, submitting, syncing, rebasing, inspecting, checking out, or merging stacked pull requests; when work should be split into dependent review layers; or when a repository already uses `gh stack`.
---

# gh-stack

## Overview

Use `gh stack` to turn dependent work into a linear chain of small pull requests, each based on the layer below it. This keeps every review focused while preserving the dependency order needed to build and merge the complete change safely.

## When to Use

- A feature or refactor has dependent parts that should be reviewed separately.
- The user asks for stacked PRs, dependent branches, branch layers, or a review stack.
- A checked-out repository already has an active `gh stack` stack.
- Work requires creating, viewing, editing, pushing, submitting, syncing, rebasing, checking out, or merging a stack.
- A change belongs in a lower layer of an existing stack and the branches above it must be replayed.

**NOT for:** unrelated branches that can merge independently, repositories where stacked PRs are unavailable, non-GitHub hosting, or ordinary single-PR work that gains no review or dependency benefit from multiple layers. Use separate stacks for parallel work; a `gh stack` stack cannot branch.

## Core Process

### 1. Confirm authorization and configure the repository

Installing an extension and changing Git config are local mutations. Pushing branches, creating or editing PRs, changing a GitHub stack, and merging are remote mutations. Confirm the user's request authorizes each class of mutation before running it.

Install the extension and make conflict recovery deterministic:

```bash
gh extension install github/gh-stack
git config rerere.enabled true
git config remote.pushDefault origin
```

`rerere` remembers conflict resolutions. `remote.pushDefault` is required for `checkout` and `trunk` when a repository has multiple remotes, because those commands do not accept `--remote`. For `push`, `submit`, `sync`, `rebase`, and `link`, either configure `remote.pushDefault` or pass `--remote <name>` explicitly.

Read [references/commands.md](references/commands.md) when exact preconditions, side effects, ordering, or atomicity matter. Treat `gh stack <command> --help` as authoritative for flags; `gh stack help <command>` only prints top-level help.

### 2. Design a linear stack before editing

`gh stack` prints the trunk first, then branches from bottom to top:

```text
(main) <- auth <- api <- frontend
           bottom          top
         merges first   merges last
```

Foundational work belongs at the bottom; anything that depends on it belongs above it. `up` moves away from the trunk, while `down` moves toward it.

```text
Does the next concern depend on the current work?
├── No  -> independent branch or separate stack
└── Yes -> Would its diff or reviewer audience be meaningfully distinct?
          ├── No  -> keep it in the current layer
          └── Yes -> add it as the next layer above
```

Stacks are strictly linear: each branch has one parent and at most one child. Plan every layer before writing files because agents have no non-interactive way to reorder or remove a layer in place. Read [references/stack-design.md](references/stack-design.md) before creating a stack or deciding branch boundaries.

### 3. Force non-interactive command forms

Some commands inspect whether stdout is a TTY. Under a PTY, a bare command can open a prompt or full-screen interface and block an agent indefinitely. Always use an explicit target or non-interactive flag:

| Always run | Never run bare | Reason |
|---|---|---|
| `gh stack view --json` | `gh stack view` | Bare `view` opens a TUI under a PTY. |
| `gh stack submit --auto` | `gh stack submit` | Bare `submit` prompts for every new PR title. |
| `gh stack merge <target> --yes` | `gh stack merge` or `gh pr merge` | A target and confirmation are required; `gh pr merge` cannot merge a stack. |
| `gh stack init <branch>...` | `gh stack init` | Bare `init` prompts for branch names. |
| `gh stack add <branch>` | `gh stack add` | Bare `add` prompts for a name and fails when piped. |
| `gh stack checkout <target>` | `gh stack checkout` | Bare `checkout` opens a selection menu. |
| `gh stack up`, `down`, `top`, or `bottom` | `gh stack switch` | `switch` is menu-only. |
| No agent-safe form | `gh stack modify` | `modify` is TUI-only. |

`gh stack view --short` is non-interactive but formatted for humans; use `--json` for automation. If `checkout <pr>` conflicts with a differently composed local stack over the same branches, run `gh stack unstack --local` to retain the GitHub stack but remove local tracking, then retry.

### 4. Create and populate the stack bottom-up

Create the stack before implementing the concerns. Name each branch explicitly; names are used verbatim, including slashes.

```bash
gh stack init auth
git add internal/auth/
git commit -m "Add auth middleware"

gh stack add api
git add internal/api/
git commit -m "Add API routes"

gh stack submit --auto
gh stack view --json
```

`init` creates or adopts branches in the given bottom-to-top order and checks out the final branch. `add` must run from the stack top. Prefer deliberate `git add` and `git commit` operations over `gh stack add -Am` so unrelated working-tree changes do not land in the wrong layer.

`submit --auto` pushes active branches, creates missing PRs, assigns each PR the first unmerged ancestor as its base, and links the PRs on GitHub. New PRs are drafts unless `--open` is supplied; `--open` also marks existing PRs ready for review. Submission is not atomic, so on a partial failure fix the rejected branch and rerun the same command.

### 5. Edit the branch that owns the concern

Inspect the stack before editing. If file ownership is unclear, inspect its history:

```bash
gh stack view --json
git log --all -- path/to/file
```

Move to the owning layer, commit there, then cascade the change through every dependent branch:

```bash
gh stack checkout api          # or navigate with: gh stack down
git add internal/api/routes.go
git commit -m "Add get-user endpoint"
gh stack rebase --upstack
gh stack top
gh stack push
```

Never commit a lower layer's concern only on the current top branch. If the rebase stops, use the exit-3 recovery in [references/troubleshooting.md](references/troubleshooting.md).

### 6. Synchronize and verify state

Use `sync` for routine reconciliation:

```bash
gh stack sync
gh stack view --json
```

`sync` fetches; reconciles local tracking with the GitHub stack; fast-forwards the trunk; cascade-rebases when needed; atomically pushes active branches; refreshes PR state; and additively updates the GitHub stack. It never creates PRs. Add `--prune` only when local branches for merged PRs should be deleted:

```bash
gh stack sync --prune
```

The rebase phase is all-or-nothing: a conflict restores every branch to its pre-sync state and exits 3. Local/remote stack-shape divergence also makes no changes, but non-interactive `sync` exits 0 while writing `Sync aborted`; verify the resulting stack with `view --json` rather than treating exit 0 alone as proof. See [references/troubleshooting.md](references/troubleshooting.md) for both recovery paths.

`gh stack view --json` writes state only to **stdout** and status messages to **stderr**. Parse stdout and normally branch on exit codes; use stderr for diagnostics, including the exceptional exit-0 divergence message. The JSON schema is:

```text
trunk           string
currentBranch   string
branches[]      name, head, base, isCurrent, isMerged, isQueued, needsRebase
branches[].pr   number, url, state ("OPEN" | "MERGED" | "QUEUED"); absent without a PR
```

`base` is the saved parent SHA the branch was last known to contain, not necessarily the parent's current tip. `needsRebase` is true when the current parent tip is no longer an ancestor of the branch.

### 7. Merge an explicit target

```bash
gh stack merge 42 --yes
gh stack merge 7 --yes --squash
```

A PR number selects that PR plus every unmerged PR below it. A stack number selects every unmerged PR in that stack. The selected merge set is all-or-nothing: if any member cannot merge, none merge.

Choose `--squash`, `--merge`, `--rebase`, or `--merge-method <method>` when the method must be explicit; otherwise the last-used method is reused. If the base uses a merge queue, the stack is queued instead, the queue chooses the method, and any supplied method flag is ignored with a warning. Queued PRs may land in separate groups.

### 8. Recover from explicit exit codes

| Code | Meaning | Evidence-based recovery |
|---:|---|---|
| 0 | Command completed | Verify the postcondition; `sync` divergence can still report `Sync aborted`. |
| 1 | Generic error | Read stderr and address the reported failure. |
| 2 | Not in a stack | Run `gh stack init <branch>...` or `gh stack checkout <target>`. |
| 3 | Rebase conflict | Follow the rebase or sync-specific recovery below. |
| 4 | GitHub API failure | Run `gh auth status`, correct authentication/connectivity, then retry. |
| 5 | Invalid arguments or invalid placement | Correct the invocation using `gh stack <command> --help`; for `add`, move to the top. |
| 6 | Disambiguation required | Check out a branch unique to the intended stack or use a command with an explicit stack number. |
| 7 | Rebase already in progress | Run `gh stack rebase --continue` after staging resolutions, or `--abort`. |
| 8 | Stack file locked | Wait roughly five seconds; if persistent, identify the other `gh stack` process before retrying. |
| 9 | Stacked PRs unavailable | Stop and tell the user the repository does not have stacked PRs enabled. |
| 10 | Modify recovery required | Run `gh stack modify --abort`; do not enter the TUI. |

After `gh stack rebase` exits 3, resolve files, stage them with `git add`, and run `gh stack rebase --continue`; repeat for later layers or use `--abort` to restore the entire stack. After `gh stack sync` exits 3, the stack is already restored: run `gh stack rebase` to recreate a stoppable conflict, then resolve and continue.

There is no non-interactive reorder, rename, or removal workflow. Do not invoke `gh stack modify`; use `unstack`, fix branch names and ancestry, then `init` and `submit --auto`. PR titles and bodies are generated automatically, so edit them afterward with `gh pr edit`. Read [references/troubleshooting.md](references/troubleshooting.md) before restructuring or recovering from an unusual state.

## Common Rationalizations

| Agent excuse | Reality |
|---|---|
| "The harness probably is not a TTY." | PTY behavior varies. Explicit flags and targets are the only reliable way to prevent prompts and TUIs. |
| "I can build everything on one branch and split it later." | There is no agent-safe in-place reorder or removal; design and create the layers before implementation. |
| "This fix is needed everywhere, so I can commit it at the top." | A lower-layer concern committed at the top produces misleading diffs and broken dependency ownership. Edit the owning layer and rebase upstack. |
| "Exit 0 means sync succeeded." | Local/remote divergence exits 0 with `Sync aborted` and makes no changes. Verify the JSON state. |
| "`gh pr merge` is close enough." | It does not understand the dependent merge set. Only `gh stack merge <target> --yes` applies stack semantics. |
| "I can use `modify` once to repair the order." | `modify` is TUI-only. Agents must unstack, rewrite ancestry, and initialize the corrected order. |
| "A failed submit or push changed nothing." | Both can partially update remote branches. Inspect state, fix the rejected branch, and rerun safely. |
| "Two independent branches can share one stack." | A stack is one linear story. Independent work belongs in separate stacks. |

## Red Flags

- Running `view`, `submit`, `init`, `add`, `checkout`, or `merge` without the required non-interactive argument or flag.
- Invoking `gh stack switch`, `gh stack modify`, or `gh pr merge` for a stack.
- Editing before deciding which branch owns the concern.
- Adding a layer from anywhere other than the stack top.
- Treating stderr status text as JSON or ignoring the stdout/stderr split.
- Treating exit 0 from `sync` as sufficient evidence without checking for divergence.
- Assuming `push` or `submit` is atomic after a partial remote failure.
- Reordering only stack metadata without first correcting Git ancestry.
- Pruning merged branches without an explicit `--prune` decision.
- Trying to model parallel or unrelated work inside one linear stack.

## Verification

Before declaring stacked-PR work complete, confirm with evidence:

- [ ] `gh stack view --json` exits 0 and its stdout parses as JSON with `trunk`, `currentBranch`, and ordered `branches`.
- [ ] The branches form one bottom-to-top dependency chain, and each layer has a single reviewable concern.
- [ ] Every edit is committed on the branch that owns it; `needsRebase` is false for all active branches after synchronization.
- [ ] Every intended PR has a `branches[].pr` object with the expected base relationship and state.
- [ ] No command depended on a prompt, selection menu, or TUI.
- [ ] The configured remote is unambiguous through `remote.pushDefault` or explicit `--remote` flags.
- [ ] Any `sync` run completed its intended postcondition and did not merely exit 0 with `Sync aborted`.
- [ ] Any merge used an explicit PR or stack target plus `--yes`, and the selected all-or-nothing set matched the user's authorization.
- [ ] Recovery completed without a pending rebase, modify session, or `.git/gh-stack.lock` conflict.
