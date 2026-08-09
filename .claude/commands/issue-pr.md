---
description: "Raise a pull request for the implementation, linked to the build issue via Resolves #<n>"
---

Invoke the agent-skills:issue-pr skill.

The argument is the issue number (e.g. `/issue-pr 42`). Fetch the issue with `gh issue view
<n> --json title,body`, compose a PR body with `Resolves #<n>` at the top, derive the PR title
from the issue title, and open a PR with `gh pr create --title <title> --body-file <body>
--base <default-branch>`. Do not merge the PR or close the issue.
