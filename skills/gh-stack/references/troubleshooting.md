# Troubleshooting and Recovery

Use this reference for rebase conflicts, squash-merge cleanup, local/remote divergence, structural changes, ambiguous stack membership, external worktree integration, locks, and interrupted TUI state.

## Rebase conflict: exit 3

Both `rebase` and `sync` return exit 3 for a cascade conflict, but they leave different states:

```text
gh stack rebase -> stops at the conflict; resolve and continue or abort
gh stack sync   -> restores every branch first; run rebase to reproduce the conflict
```

After a direct rebase failure:

```bash
# Resolve every path listed on stderr.
git add <resolved-paths>
gh stack rebase --continue
```

Repeat the resolution and `--continue` cycle if a later layer conflicts. To abandon the operation, `gh stack rebase --abort` restores every branch in the stack, not just the branch currently checked out.

After a sync failure:

```bash
gh stack rebase
# Resolve the now-stopped conflict.
git add <resolved-paths>
gh stack rebase --continue
```

The setup command `git config rerere.enabled true` allows Git to reuse a recorded resolution when the same conflict appears in later layers. Without `rerere`, the same logical conflict may need to be resolved repeatedly as the cascade proceeds upward.

## State after a squash merge

A squash merge creates a new trunk commit instead of retaining the merged branch's original commits. A naive rebase could therefore replay those commits again.

`gh stack sync` detects the merged layer and rebases its dependents onto the correct target:

```bash
gh stack sync
gh stack view --json
```

The merged branch should report `"isMerged": true` and a PR state of `"MERGED"`. No manual rewrite is normally required.

If the cascade conflicts, `sync` restores every branch and exits 3. Run `gh stack rebase`, resolve the stopped conflict, and continue. Use `gh stack sync --prune` only when the merged local branch should also be deleted.

## Local and GitHub stack shapes diverged

Divergence means both local tracking and the GitHub stack changed structurally—for example, a branch was added locally while a PR was appended on GitHub.

In non-interactive use, `sync` displays both chains, writes `Sync aborted`, makes no changes, and exits 0. Because the exit status is intentionally successful, confirm the postcondition with `gh stack view --json`.

Choose which shape is authoritative before mutating either side.

Keep the GitHub version:

```bash
gh stack unstack --local
gh stack checkout <stack-number>
```

The first command drops only local tracking. `checkout` may also target a PR number and then reconstructs local tracking from GitHub.

Keep the local version:

```bash
gh stack unstack
gh stack submit --auto
```

The first command removes the local and GitHub grouping while preserving all branches and PRs. Submission then rebuilds the GitHub stack from local ancestry.

Neither recovery path deletes branches or pull requests. GitHub may retain stacked membership for PRs that are queued or have auto-merge enabled; clear that state first if unstacking cannot complete.

## Restructure, rename, reorder, or remove a layer

There is no non-interactive command for these operations. `gh stack modify` is a TUI and must not be driven by an agent. Restructuring has two distinct phases:

1. Rewrite branch names or Git ancestry so the branches have the desired dependency order.
2. Replace the old stack grouping with one initialized from that corrected ancestry.

```bash
gh stack unstack
# Rename/drop branches and rewrite ancestry as explicitly authorized.
gh stack init --base main branch-1 branch-2 branch-3
gh stack submit --auto
```

`init` adopts existing branches, and existing PRs survive the unstack operation. Once the ancestry is correct, `submit --auto` updates PR bases and re-links the GitHub stack.

Changing stack metadata alone never changes Git ancestry. Before a history rewrite, require an explicit target order, a clean working tree, and authorization to rewrite the named branches. Record every old boundary SHA before moving anything.

For example, to transform:

```text
main <- models <- migration <- ui
```

into:

```text
main <- migration <- models <- ui
```

record the boundaries and replay each layer's exclusive commits bottom-to-top:

```bash
old_models=$(git rev-parse models)
old_migration=$(git rev-parse migration)

git rebase --onto main "$old_models" migration
git rebase --onto migration main models
git rebase --onto models "$old_migration" ui

gh stack unstack
gh stack init --base main migration models ui
```

The first rebase moves migration-only commits onto `main`; the second places model-only commits above migration; the third moves UI-only commits above models. For another order, inspect each original range with `git log <old-parent>..<branch>` and preserve those ranges while rebuilding from the bottom upward.

## Branch belongs to multiple stacks: exit 6

A branch shared by several stacks—often a trunk—cannot identify one active stack. There is no disambiguation flag for commands that infer the stack from the current branch.

```bash
gh stack checkout <branch-unique-to-the-intended-stack>
```

Rerun the command from that branch. Commands accepting an explicit stack number, such as `gh stack merge 7 --yes` or `gh stack unstack 7`, avoid inference entirely.

## Use stacks from another tool or worktree

`gh stack link` manages only the GitHub-side stack and creates no `.git/gh-stack` tracking. Use it when jj, Sapling, git-town, another worktree, or another process owns the branches:

```bash
gh stack link branch-a branch-b branch-c
gh stack link --base develop --open branch-a branch-b branch-c
gh stack link 10 20 30
gh stack link 7 feature-d
```

Arguments are bottom-to-top. The final example appends `feature-d` to GitHub stack 7 without re-listing its current PRs.

Local navigation commands cannot see a link-only stack. To manage it locally later, run `gh stack checkout <stack-number>` and let the extension establish tracking.

## Stack file locked: exit 8

Only one process may write stack state. Another `gh stack` process holding `.git/gh-stack.lock` causes exit 8 after roughly five seconds.

Retry once the other operation finishes. If the error persists, identify the process holding the lock and stop or wait for that process; do not delete the lock blindly.

## Interrupted modify session: exit 10

An agent must never start `gh stack modify`, but a human or interrupted process may leave its recovery state behind. Restore the repository without reopening the TUI:

```bash
gh stack modify --abort
```

`submit` also notices pending modify state. Under a TTY it may ask whether to overwrite the GitHub stack with local state, which is another reason agents must use explicit non-interactive commands and clear exit 10 first.
