---
description: "Submit implementation PRs linked to a build issue, using stacked PRs for spec-governed work"
---

Invoke the agent-skills:issue-pr skill.

The argument is the issue number (e.g. `/issue-pr 42`). Fetch the issue with `gh issue view
<n> --json title,body` and resolve its spec, plan, and task list. For spec-governed work,
validate the plan's stack topology, ensure the official `gh stack` extension is available,
submit every stack with `gh stack submit --auto --open`, then apply task-specific titles,
bodies, and the `build` label. Non-closing layers use `Part of #<n>`; only the plan's final
layer uses `Resolves #<n>`. Use `gh pr create` only for a small unspecced standalone change.
Do not merge PRs or close the issue directly.
