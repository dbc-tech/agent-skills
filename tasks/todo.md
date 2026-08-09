# Todo: Issue-Driven Build Workflow + OpenCode Installer

## Phase 1: Foundation — specs/<feature>/ path convention + task-marking

- [x] Task 1: Update `/spec` command to write `specs/<feature>/SPEC.md`
  - Acceptance: `commands/spec.toml`, `.claude/commands/spec.md`, and `.gemini/commands/spec.toml` all instruct the agent to save the spec to `specs/<feature>/SPEC.md` (derived by kebab-casing the text after `# Spec:`), not the repo root.
  - Verify: `node scripts/validate-commands.js` exits 0 (descriptions unchanged, still in parity); manual read of each file confirms the new path.
  - Files: `commands/spec.toml`, `.claude/commands/spec.md`, `.gemini/commands/spec.toml`
  - Dependencies: None

- [x] Task 2: Update `/plan` command to write `specs/<feature>/tasks/plan.md` and `specs/<feature>/tasks/todo.md`
  - Acceptance: `commands/planning.toml`, `.claude/commands/plan.md`, and `.gemini/commands/planning.toml` all instruct the agent to save the plan and todo under `specs/<feature>/tasks/`, not the repo-root `tasks/`.
  - Verify: `node scripts/validate-commands.js` exits 0; manual read of each file confirms the new paths.
  - Files: `commands/planning.toml`, `.claude/commands/plan.md`, `.gemini/commands/planning.toml`
  - Dependencies: None

- [x] Task 3: Update `spec-driven-development`, `planning-and-task-breakdown`, and `incremental-implementation` skills to reference the new paths and enforce task-marking
  - Acceptance:
    - `skills/spec-driven-development/SKILL.md`: Phase 1 ("Specify") and Phase 2 ("Plan") output-path references point to `specs/<feature>/`. The verification checklist references the new path.
    - `skills/planning-and-task-breakdown/SKILL.md`: "Output Files" section points to `specs/<feature>/tasks/plan.md` and `specs/<feature>/tasks/todo.md`.
    - `skills/incremental-implementation/SKILL.md`: Increment Checklist gains an explicit step naming the todo file edit (`- [ ]` → `- [x]`), the plan status update (if the plan tracks status), and the requirement to stage both in the **same commit** as the code — never a separate post-commit step.
  - Verify: `node scripts/validate-skills.js` exits 0; `node scripts/validate-reference-links.js` exits 0 (no broken cross-skill links introduced). Manual read of `incremental-implementation` Increment Checklist confirms the checkbox-edit step is present and concrete.
  - Files: `skills/spec-driven-development/SKILL.md`, `skills/planning-and-task-breakdown/SKILL.md`, `skills/incremental-implementation/SKILL.md`
  - Dependencies: None

- [x] Task 4: Extend `/build` command's spec path-resolution list + rewrite commit/mark steps to fold task-status edits into the same commit
  - Acceptance: `commands/build.toml`, `.claude/commands/build.md`, and `.gemini/commands/build.toml` all list `specs/**/SPEC.md` as a known spec path and `specs/**/tasks/plan.md` as a known planning-artefact path. The repo-root `SPEC.md`, `docs/SPEC.md`, `spec/`, `tasks/plan.md`, `tasks/todo.md` paths are retained but marked as deprecated fallbacks. **Additionally**, the single-task loop's steps 7 ("Commit") and 8 ("Mark the task complete and stop") are rewritten into a single combined step that explicitly says: edit the todo file (change `- [ ]` to `- [x]` for the task just completed; update plan status if tracked), stage the todo file alongside the code files, and commit them together. The auto mode's step 5 ("commit → mark complete") is rewritten so that "mark complete" is spelled out as "the `- [ ]` → `- [x]` edit in the todo file, staged in the same commit as the code" — not an abstract "task-status update." The auto step 5 line "Stage only the files that task touched plus its task-status update" is retained but clarified: "task-status update" means the checkbox edit in the todo file and any status change in the plan file. Remove the separate "mark complete" step entirely; there is no separate step.
  - Verify: `node scripts/validate-commands.js` exits 0; manual read of all three `/build` files confirms: (a) the new `specs/**/` glob is present; (b) deprecated fallbacks are labelled; (c) the single-task loop has a single combined "stage code + checkbox edit, commit together" step (not separate commit and mark steps); (d) the auto loop spells out `- [ ]` → `- [x]` concretely.
  - Files: `commands/build.toml`, `.claude/commands/build.md`, `.gemini/commands/build.toml`
  - Dependencies: Task 1, Task 2 (the `/build` resolution list must match what `/spec` and `/plan` now write), Task 3 (the `incremental-implementation` skill must already carry the same task-marking language, so the command and skill stay consistent)

### Checkpoint: Foundation
- [ ] `node scripts/validate-commands.js` exits 0
- [ ] `node scripts/validate-skills.js` exits 0
- [ ] `node scripts/validate-reference-links.js` exits 0
- [ ] Manual: read `/spec` and `/plan` prompt text — new paths present, repo-root paths gone
- [ ] Manual: `incremental-implementation` Increment Checklist names the todo-file checkbox edit and same-commit requirement
- [ ] Manual: read `/build` prompt in all three dirs — single-task loop has a combined "stage code + checkbox edit, commit together" step; auto loop spells out `- [ ]` → `- [x]` concretely

## Phase 2: spec-pr + issue-create vertical slices

- [x] Task 5: Create `skills/spec-pr/SKILL.md` + 3 command files + `evals/cases/spec-pr.json` + `scripts/spec-pr-test.sh`
  - Acceptance: `skills/spec-pr/SKILL.md` exists with valid YAML frontmatter (`name: spec-pr`, description with "what" + "Use when" triggers, ≤1024 chars). The skill body documents: reading `specs/<feature>/SPEC.md`, kebab-casing the text after `# Spec:` to derive `<name>`, ensuring the `spec` label exists (`gh label create spec --force`), determining current branch and base branch (the repo's default), running `gh pr create --title "[SPEC] <name>" --label spec --body-file <body> --base <default-branch>`, composing a PR body that references the spec, plan, and todo files, and reporting the PR URL back. The skill explicitly states it does not merge the PR. Three command files exist (`.claude/commands/spec-pr.md` with `Invoke the agent-skills:spec-pr skill.` prefix; `commands/spec-pr.toml` and `.gemini/commands/spec-pr.toml` with bare `Invoke the spec-pr skill.`), all with byte-identical `description` fields. `evals/cases/spec-pr.json` exists with ≥3 positive triggers, ≥2 negative triggers (with `owner` where possible — `evals/README.md` says "where you can"), and 1 behavioural eval (`kind: "dialogue"` since the deliverable is the PR-creation conversation). `scripts/spec-pr-test.sh` exists and asserts that `# Spec: Widget 7 new feature` kebab-cases to `widget-7-new-feature` and the resulting PR title is `[SPEC] widget-7-new-feature`.
  - Verify: `node scripts/validate-skills.js` exits 0; `node scripts/validate-commands.js` exits 0; `node scripts/run-evals.js` exits 0; `node scripts/validate-reference-links.js` exits 0; `bash scripts/spec-pr-test.sh` prints `spec-pr kebab-case OK` and exits 0.
  - Files: `skills/spec-pr/SKILL.md`, `.claude/commands/spec-pr.md`, `commands/spec-pr.toml`, `.gemini/commands/spec-pr.toml`, `evals/cases/spec-pr.json`, `scripts/spec-pr-test.sh`
  - Dependencies: Task 1 (the skill reads from `specs/<feature>/SPEC.md`)

- [x] Task 6: Create `skills/issue-create/SKILL.md` + 3 command files + `evals/cases/issue-create.json` + `scripts/issue-create-test.sh`
  - Acceptance: `skills/issue-create/SKILL.md` exists with valid YAML frontmatter (`name: issue-create`, description with "what" + "Use when" triggers, ≤1024 chars). The skill body documents: reading `specs/<feature>/SPEC.md`, kebab-casing the text after `# Spec:` to derive `<name>`, running `gh label create build --force`, running `gh issue create --title "[BUILD] <name>" --label build --body-file <body>`, and failing with a clear diagnostic when no `# Spec:` heading exists or `gh` is not on `PATH`. Three command files exist (`.claude/commands/issue-create.md` with `Invoke the agent-skills:issue-create skill.` prefix; `commands/issue-create.toml` and `.gemini/commands/issue-create.toml` with bare `Invoke the issue-create skill.`), all with byte-identical `description` fields. `evals/cases/issue-create.json` exists with ≥3 positive triggers, ≥2 negative triggers (with `owner` where possible), and 1 behavioural eval (`kind: "dialogue"`). `scripts/issue-create-test.sh` exists and asserts that `# Spec: Widget 7 new feature` kebab-cases to `widget-7-new-feature` and the resulting issue title is `[BUILD] widget-7-new-feature`.
  - Verify: `node scripts/validate-skills.js` exits 0; `node scripts/validate-commands.js` exits 0; `node scripts/run-evals.js` exits 0; `node scripts/validate-reference-links.js` exits 0; `bash scripts/issue-create-test.sh` prints `issue-create kebab-case OK` and exits 0.
  - Files: `skills/issue-create/SKILL.md`, `.claude/commands/issue-create.md`, `commands/issue-create.toml`, `.gemini/commands/issue-create.toml`, `evals/cases/issue-create.json`, `scripts/issue-create-test.sh`
  - Dependencies: Task 1 (the skill reads from `specs/<feature>/SPEC.md`), Task 5 (spec-pr is the "merge the spec" step that issue-create's workflow assumes has happened)

### Checkpoint: spec-pr + issue-create vertical slices
- [ ] `node scripts/validate-skills.js` exits 0 (2 new skills conform to anatomy)
- [ ] `node scripts/validate-commands.js` exits 0 (2 new commands in all three dirs, descriptions byte-identical)
- [ ] `node scripts/run-evals.js` exits 0 (trigger + routing evals pass for `spec-pr` and `issue-create`)
- [ ] `node scripts/validate-reference-links.js` exits 0
- [ ] `bash scripts/spec-pr-test.sh` exits 0
- [ ] `bash scripts/issue-create-test.sh` exits 0
- [ ] Manual: read `skills/spec-pr/SKILL.md` — workflow is actionable, PR body references spec/plan/todo, does not merge
- [ ] Manual: read `skills/issue-create/SKILL.md` — workflow is actionable, uses `[BUILD]` prefix, not `[SPEC]`

## Phase 3: Remaining issue-* commands

- [ ] Task 7: Create `skills/issue-list/SKILL.md` + 3 command files + `evals/cases/issue-list.json` + `scripts/issue-list-test.sh`
  - Acceptance: `skills/issue-list/SKILL.md` exists with valid frontmatter. The skill body documents: running `gh issue list --state open --json number,title,url` (or equivalent), filtering client-side to issues whose `title` starts with literal `[BUILD] `, and presenting number/title/url. Three command files exist with byte-identical `description`. `evals/cases/issue-list.json` exists with ≥3 positive + ≥2 negative (with `owner`) + 1 behavioural (`kind: "dialogue"`). `scripts/issue-list-test.sh` asserts that a mock `gh issue list --json title` output containing `[BUILD] foo`, `[BUILD] bar`, `bug: baz`, `[BUILD]` (no trailing space), and `[SPEC] qux` returns only `[BUILD] foo` and `[BUILD] bar`.
  - Verify: `node scripts/validate-skills.js` exits 0; `node scripts/validate-commands.js` exits 0; `node scripts/run-evals.js` exits 0; `bash scripts/issue-list-test.sh` prints `issue-list filter OK` and exits 0.
  - Files: `skills/issue-list/SKILL.md`, `.claude/commands/issue-list.md`, `commands/issue-list.toml`, `.gemini/commands/issue-list.toml`, `evals/cases/issue-list.json`, `scripts/issue-list-test.sh`
  - Dependencies: Task 6 (the `[BUILD] ` convention is defined by `issue-create`)

- [ ] Task 8: Create 3 `issue-build` command files (NO skill)
  - Acceptance: `.claude/commands/issue-build.md`, `commands/issue-build.toml`, and `.gemini/commands/issue-build.toml` exist with byte-identical `description`. Each command prompt documents: accepting an issue number argument (`$ARGUMENTS` in Claude Code), running `gh issue view <n>` to fetch the issue body and title, parsing the body for markdown links to `specs/<feature>/SPEC.md` / `specs/<feature>/tasks/plan.md` / `specs/<feature>/tasks/todo.md`, falling back to deriving `<feature>` from the `[BUILD] <name>` issue title and looking under `specs/<name>/`, then chaining the existing `/build` flow against the resolved spec/plan/todo. No `skills/issue-build/SKILL.md` is created. The command explicitly states it delegates to `incremental-implementation` and `test-driven-development` skills.
  - Verify: `node scripts/validate-commands.js` exits 0 (new command in all three dirs, descriptions byte-identical); manual read confirms the link-parsing and `[BUILD] <name>` title-fallback logic is documented.
  - Files: `.claude/commands/issue-build.md`, `commands/issue-build.toml`, `.gemini/commands/issue-build.toml`
  - Dependencies: Task 4 (`/build` must recognise `specs/**/SPEC.md`), Task 6 (the `[BUILD] ` convention)

- [ ] Task 9: Create `skills/issue-pr/SKILL.md` + 3 command files + `evals/cases/issue-pr.json`
  - Acceptance: `skills/issue-pr/SKILL.md` exists with valid frontmatter. The skill body documents: accepting an issue number, running `gh issue view <n>` to fetch the issue title and body, composing a PR body that references the issue with `Resolves #<n>` (so GitHub links the PR to the issue) and summarises the work done against the spec/plan/todo, determining the current branch (and base branch as the repo's default), running `gh pr create --title <title> --body-file <body> --base <default-branch>`, and reporting the PR URL back. The skill explicitly states it does not merge the PR or close the issue. Three command files exist with byte-identical `description`. `evals/cases/issue-pr.json` exists with ≥3 positive + ≥2 negative (with `owner`) + 1 behavioural (`kind: "dialogue"`). Behavioural eval includes a scenario where `gh` is absent from `PATH` and the skill reports the missing prerequisite.
  - Verify: `node scripts/validate-skills.js` exits 0; `node scripts/validate-commands.js` exits 0; `node scripts/run-evals.js` exits 0; `node scripts/validate-reference-links.js` exits 0.
  - Files: `skills/issue-pr/SKILL.md`, `.claude/commands/issue-pr.md`, `commands/issue-pr.toml`, `.gemini/commands/issue-pr.toml`, `evals/cases/issue-pr.json`
  - Dependencies: Task 6 (the issue-* convention)

### Checkpoint: All issue-* + spec-pr commands
- [ ] `node scripts/validate-skills.js` exits 0 (4 new skills conform)
- [ ] `node scripts/validate-commands.js` exits 0 (5 new commands in all three dirs)
- [ ] `node scripts/run-evals.js` exits 0 for `spec-pr`, `issue-create`, `issue-list`, `issue-pr`
- [ ] `node scripts/validate-reference-links.js` exits 0
- [ ] `bash scripts/issue-create-test.sh` exits 0
- [ ] `bash scripts/issue-list-test.sh` exits 0
- [ ] `bash scripts/spec-pr-test.sh` exits 0
- [ ] Manual: read `issue-build` command prompt — link-parsing + `[BUILD] <name>` title-fallback logic is clear

## Phase 4: OpenCode install + update (parallel track)

- [ ] Task 10: Create `scripts/install-opencode.sh` + `scripts/install-opencode-test.sh`
  - Acceptance: `scripts/install-opencode.sh` exists, is executable (`chmod +x`), uses `#!/bin/bash` + `set -e`, writes all human-facing messages to stderr and the final success line to stdout. It: checks `git` is on `PATH` (exits non-zero with a diagnostic if absent); creates `<target>/.opencode/` if needed; symlinks `<target>/.opencode/skills` to this repo's `skills/` directory (resolved absolutely via `$(cd "$(dirname "$0")/.." && pwd)/skills`); scaffolds `<target>/AGENTS.md` with the `# Auto-generated by agent-skills install-opencode.sh` marker on line 1 **only if absent** (never overwrites an existing file); verifies the symlink resolves. The script is idempotent — re-running it prints `already linked` / `already present` and exits 0. `scripts/install-opencode-test.sh` exists, uses `set -euo pipefail` + `mktemp` + cleanup trap (mirrors `hooks/session-start-test.sh`), and asserts: (a) running the installer in a fresh `/tmp` dir creates the symlink and a marker-tagged `AGENTS.md`; (b) re-running it is a no-op; (c) running it when `git` is not on `PATH` exits non-zero with an error message; (d) running it against a target with a pre-existing hand-edited `AGENTS.md` leaves that file untouched.
  - Verify: `bash scripts/install-opencode-test.sh` prints `install-opencode OK` and exits 0; manual run in `/tmp/opencode-smoke` confirms symlink resolves and `AGENTS.md` has the marker on line 1.
  - Files: `scripts/install-opencode.sh`, `scripts/install-opencode-test.sh`
  - Dependencies: None (parallel track)

- [ ] Task 11: Create `scripts/update-opencode.sh` + `scripts/update-opencode-test.sh`
  - Acceptance: `scripts/update-opencode.sh` exists, is executable, uses `#!/bin/bash` + `set -e`. It: runs `git -C <repo-root> pull --ff-only` (exits non-zero if the pull fails); re-verifies the `<target>/.opencode/skills` symlink and recreates it if missing or pointing elsewhere; refreshes `<target>/AGENTS.md` **only if** its first line matches the installer marker; if not (hand-edited), leaves the file alone; if `AGENTS.md` is absent, exits non-zero directing the user to run `install-opencode.sh` first. `scripts/update-opencode-test.sh` asserts: (a) marker-tagged `AGENTS.md` is refreshed; (b) hand-edited `AGENTS.md` is left byte-for-byte unchanged; (c) missing `AGENTS.md` exits non-zero; (d) missing symlink is recreated. The test stubs `git pull` so it doesn't need network.
  - Verify: `bash scripts/update-opencode-test.sh` prints `update-opencode OK` and exits 0.
  - Files: `scripts/update-opencode.sh`, `scripts/update-opencode-test.sh`
  - Dependencies: Task 10 (the updater assumes a prior install; reuses the marker convention)

- [ ] Task 12: Update `docs/opencode-setup.md` with install + update script instructions
  - Acceptance: `docs/opencode-setup.md` has a new "Installation" section documenting: prerequisites (`git`); running `scripts/install-opencode.sh [target-dir]`; what it creates (`.opencode/skills` symlink, `AGENTS.md` with marker); running `scripts/update-opencode.sh [target-dir]`; what the updater does (`git pull`, re-symlink, refresh marker-tagged `AGENTS.md`); the marker behaviour (installer-managed `AGENTS.md` is refreshed; hand-edited is never overwritten); and that the updater fails loudly if `AGENTS.md` is absent. Existing "How It Works" and "Usage Examples" sections are preserved.
  - Verify: Manual read — new section is accurate, prerequisites listed, marker behaviour explained.
  - Files: `docs/opencode-setup.md`
  - Dependencies: Task 10, Task 11

### Checkpoint: OpenCode scripts
- [ ] `bash scripts/install-opencode-test.sh` exits 0
- [ ] `bash scripts/update-opencode-test.sh` exits 0
- [ ] `docs/opencode-setup.md` documents both scripts, prerequisites, and the marker behaviour

## Phase 5: CLAUDE.md → AGENTS.md sweep + final validation

- [ ] Task 13: Sweep all `CLAUDE.md`-only references to "AGENTS.md and CLAUDE.md" with "prefer AGENTS.md"
  - Acceptance: The following sites are updated so that whenever the agent-rules file is referenced, both `AGENTS.md` and `CLAUDE.md` are named, with a note to prefer `AGENTS.md` when both exist: (1) `.claude/commands/code-simplify.md:9` — `Read CLAUDE.md` → `Read AGENTS.md and CLAUDE.md (prefer AGENTS.md when both exist)`; (2) `skills/code-simplification/SKILL.md:49` — `Read CLAUDE.md / project conventions` → `Read AGENTS.md and CLAUDE.md (prefer AGENTS.md) / project conventions`; (3) `skills/code-simplification/SKILL.md:328` — `checked against CLAUDE.md or equivalent` → `checked against AGENTS.md and CLAUDE.md (prefer AGENTS.md) or equivalent`; (4) `skills/documentation-and-adrs/SKILL.md:254` — `CLAUDE.md / rules files` → `AGENTS.md and CLAUDE.md (prefer AGENTS.md) / rules files`; (5) `skills/documentation-and-adrs/SKILL.md:288` — `Rules files (CLAUDE.md etc.)` → `Rules files (AGENTS.md and CLAUDE.md; prefer AGENTS.md)`; (6) `skills/context-engineering/SKILL.md:26` — `Rules Files (CLAUDE.md, etc.)` → `Rules Files (AGENTS.md and CLAUDE.md, etc.; prefer AGENTS.md)`; (7) `skills/context-engineering/SKILL.md:42` — the `**CLAUDE.md** (for Claude Code):` heading → `**AGENTS.md and CLAUDE.md** (for OpenCode and Claude Code; prefer AGENTS.md):`. Docs files (`docs/getting-started.md`, `docs/adoption-guide.md`, `docs/developer-onboarding.md`) already reference `CLAUDE.md` in the context of listing example rules files across tools — these are left unchanged. After the sweep, `grep -rn "CLAUDE\.md" skills/ .claude/commands/ commands/ .gemini/commands/` returns zero matches that instruct an agent to read `CLAUDE.md` alone without also naming `AGENTS.md`.
  - Verify: `node scripts/validate-skills.js` exits 0; `node scripts/validate-commands.js` exits 0; `node scripts/validate-reference-links.js` exits 0; `grep -rn "CLAUDE\.md" skills/ .claude/commands/ commands/ .gemini/commands/ | grep -v "AGENTS\.md"` returns zero lines.
  - Files: `.claude/commands/code-simplify.md`, `skills/code-simplification/SKILL.md`, `skills/documentation-and-adrs/SKILL.md`, `skills/context-engineering/SKILL.md`
  - Dependencies: None (parallel track)

### Checkpoint: Complete
- [ ] `node scripts/validate-skills.js` exits 0
- [ ] `node scripts/validate-commands.js` exits 0
- [ ] `node scripts/validate-versions.js` exits 0
- [ ] `node scripts/validate-reference-links.js` exits 0
- [ ] `node scripts/run-evals.js` exits 0
- [ ] `bash hooks/session-start-test.sh` prints `session-start JSON payload OK` and exits 0
- [ ] `bash scripts/install-opencode-test.sh` exits 0
- [ ] `bash scripts/update-opencode-test.sh` exits 0
- [ ] `bash scripts/issue-create-test.sh` exits 0
- [ ] `bash scripts/issue-list-test.sh` exits 0
- [ ] `bash scripts/spec-pr-test.sh` exits 0
- [ ] `grep -rn "CLAUDE\.md" skills/ .claude/commands/ commands/ .gemini/commands/ | grep -v "AGENTS\.md"` returns zero lines
- [ ] All 15 success criteria in `SPEC.md` are met
- [ ] Ready for review

## Notes

- **No `skills/issue-build/SKILL.md`.** `/issue-build` is a command that chains `incremental-implementation` + `test-driven-development`; it has no unique workflow. Task 8 creates only the 3 command files.
- **Dual prefixes.** `[SPEC]` is for spec PRs (raised by `/spec-pr`); `[BUILD]` is for build-tracking issues (raised by `/issue-create`). Both share the same kebab-cased `<name>`. The `issue-list-test.sh` mock includes a `[SPEC] qux` entry to verify it is correctly excluded from the `[BUILD] ` filter.
- **Eval `kind: "dialogue"`.** The four new skills (`spec-pr`, `issue-create`, `issue-list`, `issue-pr`) have conversation-shaped deliverables (creating/listing issues, raising PRs), not file edits. Their behavioural evals use `kind: "dialogue"` to avoid the `evals/fixtures/` requirement (per `evals/README.md` §"Adding a skill").
- **Command-file prefix convention.** `.claude/commands/*.md` invoke skills as `Invoke the agent-skills:<name> skill.` (verified at `.claude/commands/spec.md:5` and `.claude/commands/build.md:5`). `commands/*.toml` and `.gemini/commands/*.toml` use bare `Invoke the <name> skill.` (verified at `commands/spec.toml:4` and `commands/planning.toml:4`). New commands follow the same split.
- **Self-reference.** This plan itself (`tasks/plan.md` / `tasks/todo.md`) lives at the repo root, not under `specs/<feature>/`. That's intentional: this is the framework's own meta-spec for extending itself, and the spec/plan/todo output convention applies to downstream features built with the framework, not to the framework's own development artefacts (which pre-date the convention and are already at the repo root). The `SPEC.md` at the repo root is similarly grandfathered.
