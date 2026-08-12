---
description: Review code using Open Code Review (OCR) delegate mode. Use when you want a rules-driven, agent-driven code review with low-priority findings folded.
---

Invoke the agent-skills:code-review-and-quality skill, OCR Delegate Review section.

Run the OCR delegate review flow:
1. Confirm the ocr CLI is installed (command -v ocr; if missing, direct to install: npm install -g @alibaba-group/open-code-review).
2. ocr delegate preview ... to list reviewable files and mode.
3. ocr delegate rule <paths> ... to get the review rule groups.
4. git diff/show per file for the review range/commit/workspace.
5. Review each file against its rule group.
6. Report with one rubric: Critical/High, Medium/Warning, and a folded count for Low/Nit findings.

Read the SKILL.md OCR Delegate Review section and follow it exactly.
