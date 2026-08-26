# Stack Design

Read this reference before `gh stack init` when deciding whether work needs a stack, how many layers to create, and what each branch should own.

## Start with dependencies, not file types

A stack records a dependency chain. Code may depend only on work in its own branch or a branch below it:

```text
(main) <- billing/models <- billing/api <- billing/ui <- billing/integration
             shared types       routes        views          flow tests
```

Here, the API can import the models, and the UI can call the API. Reversing either pair would make a lower branch depend on a change that exists only above it.

Design this order before writing code. Agents cannot reorder branches non-interactively with `gh stack`; repairing a bad order requires removing stack tracking, rewriting Git ancestry, and initializing the stack again.

Use this sequence:

1. List the independently reviewable concerns in the change.
2. Draw a dependency edge from each concern to anything it requires.
3. Put foundations nearest the trunk and dependents above them.
4. Combine two concerns when neither benefits from an independent review or merge boundary.
5. Split a concern whose layer cannot be summarized in one sentence.

The example names are illustrative. Derive the actual topic and concern names from the task and repository.

## Choose recognizable branch names

When repository or user conventions do not dictate another format, use a shared topic prefix:

```text
<topic>/<concern>
billing/schema
billing/api
billing/ui
```

Repository and user naming rules take precedence. `gh stack` uses every name exactly as supplied: `gh stack add refactor/cache` creates a branch literally named `refactor/cache`.

Passing `-m` without a branch name derives a date-and-slug name from the commit message, such as `03-24-add_api_routes`. Prefer an explicit branch name so the stack remains predictable.

## Stage each layer deliberately

Create the stack before implementation, then commit only the files or hunks owned by the current layer. Prefer direct Git staging to the `gh stack add -Am` shortcut:

```bash
git add internal/models/user.go internal/models/session.go
git commit -m "Add user and session models"

gh stack add billing/api
git add internal/api/routes.go internal/api/handlers.go
git commit -m "Add user API routes"
```

Multiple commits on one branch are valid when they all serve the same concern. A change for another concern belongs in another layer.

Without `-Am`, `gh stack add <branch>` leaves the index and working tree untouched. Staged and unstaged changes therefore follow onto the new branch. Commit or stash before adding the layer when it must start clean.

Immediately after `init`, `gh stack add -Am` behaves specially if the current branch has no commits: it commits on that current branch instead of creating another branch. This is intended to populate the first layer, but explicit staging is easier to audit.

## Add a layer only for dependent, distinct work

Add the next layer when both statements are true:

- It depends on work already in the stack.
- It deserves a distinct review boundary.

Useful signals for a new layer include:

- The work moves between concerns, such as schema to API or backend to frontend.
- A different reviewer or owning team should review it.
- The current layer is already a complete, reasonably sized diff.
- The next concern could be reverted or delayed independently after its dependencies merge.

Do not add a layer merely because the work touches another file. Branch boundaries should communicate dependency and review intent.

## Keep one coherent story per stack

A reviewer should be able to read the PRs bottom-to-top as one feature unfolding.

```text
Same outcome and dependent?       -> same stack
Same outcome but not distinct?    -> same branch
Different outcome or independent? -> separate stack or ordinary branch
```

Use one stack across schema, backend, frontend, tests, and documentation when every layer advances the same project. Start another stack for an unrelated refactor, bug fix, or feature even if it was discovered while working on the current stack.

A truly trivial incidental fix may remain in the current layer. Once it needs its own explanation, review audience, or follow-up work, move it to a separate branch or stack.

## Design check

Before `gh stack init`, verify:

- Every dependency is in the same layer or lower.
- Every layer has one sentence that explains its concern.
- Independent work is outside the stack.
- Names follow user or repository conventions and identify the shared topic.
- The initial working tree can be staged into the planned layers without mixing concerns.
