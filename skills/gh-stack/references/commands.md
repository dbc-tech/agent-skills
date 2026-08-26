# Command Semantics

Use this reference when a command fails unexpectedly or when its preconditions, remote effects, ordering, or atomicity affect the plan. For accepted flags and arguments, run `gh stack <command> --help`; `gh stack help <command>` does not show command-specific help.

## `init`

```bash
gh stack init [--base <trunk>] <bottom-branch>...<top-branch>
```

`init` records the chain locally and checks out the last branch named. It processes arguments bottom-to-top:

- An existing branch is adopted.
- A missing first branch is created from the trunk.
- Each later missing branch is created from the preceding branch.
- `--base` selects a trunk other than the repository default.

There is no separate adopt command; whether the named branch already exists controls the behavior. `init` also enables Git `rerere`. Configure `git config rerere.enabled true` first to avoid the initial TTY confirmation.

## `add`

```bash
gh stack add <branch>
```

Run `add` only from the current stack's top branch, or from the trunk while building an empty stack. Elsewhere it exits 5 with `can only add branches on top of the stack`; use `gh stack top` before retrying.

The ordinary form creates the next branch without changing the index or working tree, so all uncommitted changes follow to it. Commit or stash first when the new branch should be clean.

Shortcut behavior needs extra care:

- `-A` stages all changes; `-u` stages tracked changes. They are mutually exclusive.
- Both `-A` and `-u` require `-m`.
- If the current branch has no commits, `add -Am` commits there instead of creating another branch. This commonly populates the first branch immediately after `init`.

Prefer explicit `git add` and `git commit` when several concerns coexist in the working tree.

## `push`

`push` updates every active branch—that is, every branch that is neither merged nor queued—in one multi-ref push. Each ref uses force-with-lease protection.

The operation is **not atomic**. One branch can update while another is rejected because its remote ref moved. Inspect the rejected branch, reconcile it, and rerun; repeated `push` calls safely skip refs that already landed.

`push` never creates or updates PRs. Use `submit --auto` for PR state.

## `submit`

```bash
gh stack submit --auto [--open]
```

`submit` performs these operations:

1. Push each active branch.
2. Create a PR for every branch without one.
3. Base each PR on its first unmerged ancestor.
4. Link the PRs into a GitHub Stack.

Submission is **not atomic**. Branches are pushed sequentially with force-with-lease; earlier pushes and PR updates remain if a later push is rejected. Repair the rejected branch and rerun the identical command.

`--auto` generates PR metadata:

- One commit on a branch: the commit subject becomes the title and the commit body becomes the PR body.
- Multiple commits: the branch name is humanized by replacing hyphens and underscores with spaces.

No submit flag accepts a custom title or body. Apply custom metadata later with `gh pr edit`.

New PRs are drafts unless `--open` is present. `--open` also marks existing PRs in the submitted stack ready for review.

If every PR in the existing stack is merged, it cannot be extended. `submit` places any remaining unmerged local branches in a new GitHub stack rooted at the trunk and leaves the completed stack unchanged.

The repository must have stacked PRs enabled. In non-interactive mode, an unsupported repository exits 9 rather than offering the TTY-only fallback to ordinary PRs.

## `link`

`link` creates or extends a GitHub stack without writing local tracking state. Use it for branches owned by another VCS tool, process, or worktree.

List arguments bottom-to-top. Each may be a branch name or PR number. A numeric argument is attempted as a PR number before falling back to a branch name, except for the first argument: if it matches an existing stack number, later arguments are appended to that stack and its current PRs must not be listed again.

```bash
gh stack link branch-a branch-b branch-c
gh stack link 7 feature-d
```

For an existing stack, already-linked arguments are skipped and branches belonging to another stack are rejected.

Branch arguments are pushed automatically with a non-force, atomic push. Missing PRs receive generated titles and chained bases; existing PRs with incorrect bases are corrected. Stack membership changes are additive—`link` never removes a PR.

Because no local tracking file is created, navigation commands will not recognize this stack. Run `gh stack checkout <stack-or-pr-number>` later if local tracking is needed.

## `sync`

`sync` is the routine full-stack reconciliation command. Its order is significant:

1. Fetch from the selected remote.
2. Reconcile local tracking with the GitHub stack, appending PRs added on GitHub. Non-interactive divergence aborts without changes.
3. Fast-forward the trunk when possible; warn instead when it has diverged.
4. Cascade-rebase when the trunk moved, a branch was fast-forwarded from remote, or a branch no longer contains its expected parent. Merged PRs are accounted for automatically.
5. Push active branches atomically.
6. Refresh PR state from GitHub.
7. Additively synchronize the GitHub stack object when at least two PRs exist, linking its open PRs.
8. Delete local branches for merged PRs only when `--prune` is explicitly supplied in non-interactive use.

`sync` never opens PRs. Use `submit --auto` for that.

The cascade rebase is all-or-nothing. A conflict restores every branch to its pre-sync state and exits 3. Run `gh stack rebase` afterward to reproduce a conflict that can be resolved and continued.

If local and GitHub stack shapes both changed, non-interactive `sync` prints both chains and `Sync aborted`, changes nothing, and exits 0. Verify the postcondition with `gh stack view --json`; do not equate exit 0 with reconciliation in this case.

## `rebase`

`rebase` pulls from the remote and replays a cascade through the selected portion of the stack:

- `--upstack` starts with the current branch and proceeds to the top. Use it after changing a lower layer.
- `--downstack` starts at the trunk and ends at the current branch.
- `--no-trunk` skips fetching and replaying on the trunk, aligning only stack branches with one another.
- `--continue` resumes after conflict resolutions have been staged.
- `--abort` restores every branch in the stack, not only the current branch.

Merged PRs are detected. After a squash merge, `rebase` uses the correct `--onto` target so commits from the merged parent are not replayed a second time.

A conflict exits 3 and leaves the cascade stopped for resolution. Starting another rebase while one is active exits 7.

## `view`

Always use `gh stack view --json` for automation. It writes the machine-readable payload to stdout and status messages to stderr. Bare `view` opens a full-screen TUI when stdout is a TTY and prints static text when piped.

`--short` is reliably non-interactive but produces human-oriented text. Do not parse it when JSON is available.

As a best-effort side effect, `view` refreshes PR state from GitHub. An unreachable API does not make the local view fail.

## `checkout`

```bash
gh stack checkout <stack-number|pr-number|pr-url|local-branch>
```

Resolution rules differ by target:

- A bare number is tried as a stack number, then a PR number, then a branch name.
- Stack numbers, PR numbers, and PR URLs contact GitHub, fetch the branches, establish local tracking, and check out the stack.
- A branch name is resolved only against locally tracked stacks; it never fetches an unknown stack. Use a stack or PR number to bring remote-only tracking down.

If a differently composed local stack already covers those branches, `checkout` cannot override it. Run `gh stack unstack --local`, which preserves GitHub state, then retry.

`checkout` accepts no remote flag. In repositories with multiple remotes, it depends on `remote.pushDefault`.

## `unstack`

`unstack` removes grouping and tracking, never PRs or Git branches.

- No argument: remove the active stack from both GitHub and local tracking.
- Stack number: remove that GitHub stack from anywhere in the repository and also remove local tracking when present.
- `--local`: remove only local tracking without contacting GitHub.

Combining `--local` with a stack number that is not tracked locally is an error. An unknown stack number exits 2.

Remote unstacking may leave PRs stacked while they have auto-merge enabled or are queued. Clear that state before retrying when necessary.

## `merge`

Always scope and confirm the operation:

```bash
gh stack merge <pr-or-stack-number> --yes [--squash|--merge|--rebase]
```

A PR number selects that PR and every unmerged PR below it. A stack number selects every unmerged PR in the stack. The resulting set is **all-or-nothing**: one unmergeable PR prevents every merge in the set.

The extension performs a basic precheck that each PR is open and not a draft; it does not bypass branch protection or merge requirements. Stack merges do not support bypassing those requirements.

Choose a method with `--squash`, `--rebase`, `--merge`, or `--merge-method <method>`. Without one, the last-used method is reused.

When the base branch uses a merge queue, the command queues the selected PRs rather than merging immediately. The queue chooses the method and ignores a supplied method flag with a warning. PRs enter the queue together but can land in different groups as it processes them.

Never substitute `gh pr merge`; it has no stack-aware merge semantics.

## Navigation

`up`, `down`, `top`, `bottom`, and `trunk` are non-interactive. `up` and `down` accept counts, such as `gh stack up 3`, and stop at the stack boundary. From an active branch, navigation skips merged branches, so `bottom` selects the lowest unmerged layer.

`gh stack switch` always uses a selection menu and has no agent-safe form.
