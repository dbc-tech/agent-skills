---
description: "Raise a PR for the spec/plan/tasks themselves using [SPEC] naming convention"
---

Invoke the agent-skills:spec-pr skill.

Read the spec at `/specs/<feature>/SPEC.md`, kebab-case the text after `# Spec:` to derive
`<name>`, ensure the `spec` label exists (`gh label create spec --force`), and open a pull
request with `gh pr create --title "[SPEC] <name>" --label spec --body-file <body> --base <default-branch>`
where the body references the spec, plan, and todo files.
