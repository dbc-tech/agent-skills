---
description: "List open GitHub Issues tracking builds for merged specs ([BUILD] prefix)"
---

Invoke the agent-skills:issue-list skill.

Run `gh issue list --state open --json number,title,url --limit 100`, filter client-side to
issues whose title starts with `[BUILD] ` (including the trailing space), and present the
number, title, and URL in a table.
