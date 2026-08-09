# Spec: Issue-Driven Build Workflow + OpenCode Installer

## Objective

Extend the **agent-skills** framework itself (the `addyosmani/agent-skills` repo) so that spec → plan → build → PR can be driven from a **GitHub Issue**, and so that the framework can be installed into OpenCode with a single script and a tested setup guide.

### Why

Today the lifecycle is:

```
DEFINE (/spec) → PLAN (/plan) → BUILD (/build) → VERIFY → REVIEW → SHIP
```

Specs/plans/todos live at the repo root. There is no link from a merged spec to the work
that implements it — build starts from a local file the agent has to locate. This means:

- No durable record connects "the merged spec" to "the build that implements it."
- The team cannot see, in GitHub, which specs are waiting to be built.
- Working from a fresh clone requires manually re-pointing the agent at the right files.

This spec closes that loop:

1. A spec/plan/todo is authored via `/spec` and `/plan`, then merged via a **spec PR**
   raised by `/spec-pr` — titled `[SPEC] <name>`.
2. `issue-create` reads the merged spec, derives `<name>` (kebab-cased) from the
   `# Spec:` heading, and opens a GitHub Issue titled `[BUILD] <name>` whose body links to
   `specs/<name>/SPEC.md`, `specs/<name>/tasks/plan.md`, `specs/<name>/tasks/todo.md`.
   The issue is labelled `build`.
3. `issue-list` lists all open issues whose title starts with `[BUILD] `.
4. `issue-build <issue-number>` resolves the spec/plan/todo from the issue (links first,
   `[BUILD] <name>` fallback), then chains the existing `/build` command sequence.
5. `issue-pr <issue-number>` is invoked at the end of development to raise a pull request
   based on the linked issue; the PR body references the issue so GitHub links them.

### Target users

- **Developers** using agent-skills with the GitHub CLI installed who want a traceable,
  reviewable, issue-driven path from spec to implementation to pull request.
- **Teams** reviewing specs in PRs who want a single GitHub Issue to track the build that
  realises each merged spec, and a single PR that links back to it.

### Naming convention (binding)

Two distinct prefixes disambiguate **PRs for the spec itself** from **Issues for the build
that implements it**:

| Artefact | Prefix | Raised by | Example |
|---|---|---|---|
| **Spec PR** (the spec/plan/tasks themselves) | `[SPEC]` | `/spec-pr` | `[SPEC] widget-7-new-feature` |
| **Build Issue** (tracks the implementation) | `[BUILD]` | `/issue-create` | `[BUILD] widget-7-new-feature` |

Both use the same kebab-cased `<name>` derived from the `# Spec:` heading, so a spec and
its corresponding build issue are linked by shared `<name>`. The prefix is the only
difference.

### Success criteria

1. `issue-create` reads the merged `specs/<feature>/SPEC.md`, derives `<name>` as the
   **kebab-cased** form of the text after `# Spec:` in the heading, and opens a GitHub
   Issue with:
   - Title: `[BUILD] <name>` (e.g. `# Spec: Widget 7 new feature` → `[BUILD] widget-7-new-feature`)
   - Body: markdown links to `specs/<feature>/SPEC.md`, `specs/<feature>/tasks/plan.md`,
     `specs/<feature>/tasks/todo.md`, plus a one-paragraph summary pulled from the spec's
     `## Objective` section.
   - Label: `build` (created if it does not yet exist on the repo).
   - Fails with a clear message if no `# Spec:` heading exists.
2. `issue-list` lists every open issue whose title begins with `[BUILD] `, with issue number,
   title, and URL — and no closed and no non-`[BUILD] ` issues.
3. `issue-build <n>` chains the existing `/build` flow onto the spec/plan/todo referenced by
   issue `#<n>`. Link resolution: parse the issue body for markdown links to
   `specs/<feature>/SPEC.md` etc.; if missing, derive `<feature>` from the `[BUILD] <name>`
   issue title and look under `specs/<name>/`.
4. `issue-pr <n>` raises a pull request whose body references issue `#<n>` (so GitHub links
   the PR to the issue) and summarises the work done against the spec/plan/todo. The PR is
   opened against the repo's default branch from the current branch (or a branch the user
   has prepared). It does not auto-close the issue — merging is a human action.
5. `spec-pr` raises a pull request for the **spec/plan/tasks themselves** (not the
   implementation). The PR title is `[SPEC] <name>` where `<name>` is the kebab-cased
   text after `# Spec:`. The PR body references the spec, plan, and todo files.
6. The `/spec` and `/plan` commands write to `specs/<feature>/SPEC.md`,
   `specs/<feature>/tasks/plan.md`, `specs/<feature>/tasks/todo.md` (NOT the repo root).
7. `validate-commands.js` passes after new commands are added in all three command dirs
   (`.claude/commands/`, `commands/`, `.gemini/commands/`).
8. `validate-skills.js` passes after new skills are added under `skills/`.
9. `scripts/install-opencode.sh` installs the framework into a target project's
   `.opencode/skills` (symlink to this repo's `skills/`) and ensures an `AGENTS.md` exists
   in the target; exits non-zero on any failure with a diagnostic.
10. `scripts/update-opencode.sh` performs ongoing updates: pulls the latest skills from this
    repo (via `git pull`), re-verifies the symlink, and refreshes the scaffolded `AGENTS.md`
    note if and only if it was originally written by the installer (detected by a marker
    comment). Never overwrites a hand-edited `AGENTS.md`.
11. `docs/opencode-setup.md` documents both scripts and their prerequisites.
12. Every skill and command that previously said "see CLAUDE.md" now names **both** files
    ("AGENTS.md and CLAUDE.md") and instructs preferring `AGENTS.md` when both exist.
13. Repo-root `SPEC.md` and `tasks/` paths are no longer written to by `/spec` or `/plan`;
    the `/build` auto path-resolution list is extended to include `specs/*/SPEC.md` and a
    deprecation note is added to the repo-root path.
14. `/build` (both single-task and auto modes) **marks completed tasks in the plan and todo
    files as part of the same commit as the code change** — the model edits the `- [ ]`
    checkbox to `- [x]` in the todo file (and updates the plan's task status if the plan
    tracks status), stages that file edit alongside the code, and commits them together.
    This is not a separate "mark complete" step that happens after the commit; it is part
    of the commit. The goal: every commit is self-describing — you can see which task it
    closed by looking at the diff.

---

## Tech Stack

| Layer | Choice |
|---|---|
| Skill / command format | Markdown with YAML frontmatter (TOML body for `commands/*.toml` and `.gemini/commands/*.toml`) |
| Installer / updater | POSIX `sh` + coreutils (no Node dependency for the scripts themselves) |
| GitHub integration | `gh` CLI (v2.45.0 verified on this machine) — `gh issue create`, `gh issue list`, `gh issue view`, `gh label create`, `gh pr create` |
| Validation | Existing Node.js scripts in `scripts/` (`validate-skills.js`, `validate-commands.js`) + `scripts/lib/skill-lint.js` |

No new runtime dependencies. `gh` is a prerequisite for `issue-create` / `issue-list` /
`issue-build` / `issue-pr` / `spec-pr`; the installer, updater, and other skills remain
`gh`-free.

---

## Commands

Slash commands live in three sibling directories and MUST stay in parity (enforced by
`scripts/validate-commands.js`):

| Dir | Format | Tool |
|---|---|---|
| `.claude/commands/*.md` | YAML frontmatter + markdown body | Claude Code |
| `commands/*.toml` | TOML (Antigravity) | Antigravity CLI |
| `.gemini/commands/*.toml` | TOML | Gemini CLI |

Existing commands (do not change behaviour, only the `specs/<feature>/` output paths for
`/spec` and `/plan`, and add `issue-build` to the path-resolution list in `/build`):

```
/spec, /plan, /build, /test, /review, /webperf, /code-simplify, /ship
```

New commands (added in all three dirs with identical `description` field):

```
/spec-pr                            # raise a [SPEC] <name> PR for the spec/plan/tasks themselves
/issue-create                       # read merged spec, open [BUILD] <name> issue with body links + build label
/issue-list                         # list open issues whose title starts with "[BUILD] "
/issue-build <n>                    # chain /build onto spec linked from issue #<n>
/issue-pr <n>                       # raise a pull request linked to issue #<n>, summarising the work
```

Validation commands (run before every PR):

```bash
node scripts/validate-skills.js     # every skills/<name>/SKILL.md passes skill-anatomy rules
node scripts/validate-commands.js  # command parity across .claude/commands, commands/, .gemini/commands
node scripts/validate-versions.js   # plugin.json / marketplace.json versions consistent
node scripts/validate-reference-links.js   # no broken skill→skill or skill→references links
node scripts/run-evals.js           # trigger/routing evals for every skill (CI)
bash hooks/session-start-test.sh    # hook JSON payload still well-formed
```

Installer and updater commands (new):

```bash
scripts/install-opencode.sh [target-dir]   # default target: . (current directory)
scripts/update-opencode.sh   [target-dir]   # default target: . (current directory)
```

---

## Project Structure

### Existing layout (unchanged)

```
skills/<kebab-case-name>/SKILL.md   # skills
agents/<role>.md                     # personas
.claude/commands/*.md                # Claude Code slash commands (.md)
commands/*.toml                      # Antigravity slash commands (.toml)
.gemini/commands/*.toml              # Gemini CLI slash commands (.toml)
references/*.md                      # cross-skill shared checklists
scripts/*.js                         # validators + evals
scripts/lib/skill-lint.js            # skill linter (single source of truth for rules)
hooks/session-start.sh               # session-start hook
evals/                               # eval cases + framework
docs/                                # setup guides + anatomy docs
```

### New layout

```
specs/<feature>/                     # NEW — per-feature planning artefacts
  SPEC.md                            #   the merged spec (was: repo-root SPEC.md)
  tasks/plan.md                      #   the implementation plan (was: tasks/plan.md)
  tasks/todo.md                      #   the task checklist (was: tasks/todo.md)
skills/spec-pr/SKILL.md             # NEW skill
skills/issue-create/SKILL.md         # NEW skill
skills/issue-list/SKILL.md           # NEW skill
skills/issue-pr/SKILL.md             # NEW skill
commands/spec-pr.toml              # NEW (Antigravity)
commands/issue-create.toml           # NEW (Antigravity)
commands/issue-list.toml             # NEW (Antigravity)
commands/issue-build.toml            # NEW (Antigravity)
commands/issue-pr.toml              # NEW (Antigravity)
.claude/commands/spec-pr.md         # NEW (Claude Code)
.claude/commands/issue-create.md     # NEW (Claude Code)
.claude/commands/issue-list.md       # NEW (Claude Code)
.claude/commands/issue-build.md      # NEW (Claude Code)
.claude/commands/issue-pr.md         # NEW (Claude Code)
.gemini/commands/spec-pr.toml      # NEW (Gemini CLI)
.gemini/commands/issue-create.toml   # NEW (Gemini CLI)
.gemini/commands/issue-list.toml     # NEW (Gemini CLI)
.gemini/commands/issue-build.toml    # NEW (Gemini CLI)
.gemini/commands/issue-pr.toml      # NEW (Gemini CLI)
scripts/install-opencode.sh          # NEW installer
scripts/update-opencode.sh           # NEW updater
evals/cases/spec-pr.json            # NEW eval cases (3+ positive, 2+ negative, 1 behavioural — per CONTRIBUTING.md)
evals/cases/issue-create.json
evals/cases/issue-list.json
evals/cases/issue-pr.json
```

Note: there is **no** `skills/issue-build/SKILL.md` — `/issue-build` is a command that chains
the existing `incremental-implementation` and `test-driven-development` skills; no new skill
is required for it. `/issue-pr` and `/spec-pr` both get skills because they define their own
workflows (branch/commit hygiene, PR body composition, issue/PR linkage conventions).

### What changes in existing files

| File | Change |
|---|---|
| `commands/spec.toml` (and `.claude/commands/spec.md`, `.gemini/commands/spec.toml`) | Update the Save-the-spec instruction: `specs/<feature>/SPEC.md` instead of `SPEC.md`. Derive `<feature>` from the `# Spec: <feature>` heading, kebab-cased. |
| `commands/planning.toml` (and siblings) | Update the Save instructions: `specs/<feature>/tasks/plan.md` and `specs/<feature>/tasks/todo.md` instead of `tasks/plan.md` / `tasks/todo.md`. |
| `commands/build.toml` (and siblings) | Extend the "known spec paths" list with `specs/**/SPEC.md`. Keep repo-root `SPEC.md`, `docs/SPEC.md`, `spec/` as deprecated fallbacks. Planning-artefact glob extends to `specs/**/tasks/plan.md`. **Also:** rewrite step 8 ("Mark the task complete and stop") and auto step 5 ("commit → mark complete") so that marking is an explicit file edit (change `- [ ]` to `- [x]` in the todo file) staged in the **same** commit as the code, not a mental note or a separate post-commit step. Single-task step 7 ("Commit") and step 8 ("Mark complete") become a single combined step: "Stage code + todo-file checkbox edit, commit together." |
| `skills/spec-driven-development/SKILL.md` | Update Phase 1 ("Specify") and Phase 2 ("Plan") output-path references to `specs/<feature>/`. Update the verification checklist. |
| `skills/planning-and-task-breakdown/SKILL.md` | Update "Output Files" section: `specs/<feature>/tasks/plan.md` and `specs/<feature>/tasks/todo.md`. |
| `skills/incremental-implementation/SKILL.md` | Add an explicit "Mark the task complete" step to the Increment Checklist that names the file (`specs/<feature>/tasks/todo.md` or `tasks/todo.md`), the edit (`- [ ]` → `- [x]`), and the requirement to stage it in the same commit. The `/build` command carries the path-resolution update. |
| Anywhere "CLAUDE.md" is referenced alone | Replace with "AGENTS.md and CLAUDE.md" and add: "prefer `AGENTS.md` when both exist." Sites include `AGENTS.md`, `CLAUDE.md`, skills, commands, and `docs/`. |

---

## Code Style

This repo's "code" is markdown skills and TOML/sh commands. The conventions below are
binding for the new artefacts.

### Skill frontmatter (required, machine-validated)

```yaml
---
name: issue-create
description: Opens a GitHub Issue summarising a merged spec and linking to its spec/plan/todo files. Use when a spec has been merged via PR and you want to track its implementation as a GitHub Issue; triggers on "create an issue for this spec", "raise an issue for the build", or "track this spec in GitHub".
---
```

- `name`: lowercase, hyphen-separated, MUST match the directory name.
- `description`: third-person "what" first; then one or more `Use when` triggers in the same
  paragraph. ≤1024 chars. No workflow steps in the description (agents follow the summary
  instead of reading the skill).

### Name derivation (binding convention)

The `<name>` used in issue/PR titles and the `<feature>` directory are linked by
kebab-casing, not by free text. The **prefix** distinguishes a spec PR from a build issue:

```
# Spec: Widget 7 new feature      ← heading in SPEC.md
                  ↓ kebab-case
[SPEC] widget-7-new-feature       ← spec PR title (raised by /spec-pr)
[BUILD] widget-7-new-feature      ← build issue title (raised by /issue-create)
                  ↓ identical <name>
specs/widget-7-new-feature/       ← directory name
```

Kebab-casing rules: lowercase, trim, collapse internal whitespace to single hyphens,
strip characters that are invalid in a GitHub issue/PR title or a directory name. The
directory name, the spec PR `<name>`, and the build issue `<name>` are identical strings;
only the prefix differs.

### Command file (Claude Code) — `.claude/commands/spec-pr.md`

```markdown
---
description: "Raise a PR for the spec/plan/tasks themselves using [SPEC] naming convention"
---

Invoke the agent-skills:spec-pr skill.

Read the spec at `specs/<feature>/SPEC.md`, kebab-case the text after `# Spec:` to derive
`<name>`, and open a pull request with `gh pr create --title "[SPEC] <name>" --body-file <body>`
where the body references the spec, plan, and todo files.
```

### Command file (Claude Code) — `.claude/commands/issue-create.md`

```markdown
---
description: "Open a GitHub Issue that summarises the merged spec and links to its spec/plan/todo"
---

Invoke the agent-skills:issue-create skill.

Read the merged spec at `specs/<feature>/SPEC.md`, kebab-case the text after `# Spec:` to
derive `<name>`, ensure the `build` label exists (`gh label create build --force`), and open a
GitHub Issue with `gh issue create --title "[BUILD] <name>" --label build --body-file <body>`
where the body links to the spec, plan, and todo.
```

### Command file (Antigravity / Gemini) — `commands/issue-create.toml`

```toml
description = "Open a GitHub Issue that summarises the merged spec and links to its spec/plan/todo"

prompt = """
Invoke the issue-create skill.

Read the merged spec at `specs/<feature>/SPEC.md`, kebab-case the text after `# Spec:` to
derive `<name>`, ensure the `build` label exists (`gh label create build --force`), and open a
GitHub Issue with `gh issue create --title "[BUILD] <name>" --label build --body-file <body>`
where the body links to the spec, plan, and todo.
"""
```

The `description` field MUST be byte-identical across the three command directories (enforced by
`scripts/validate-commands.js`). Prompt bodies differ only in tool-specific syntax
(`$ARGUMENTS`, agent-skills: prefixes, GEMINI.md vs CLAUDE.md mentions).

### Installer script — `scripts/install-opencode.sh`

```sh
#!/bin/bash
set -e

TARGET="${1:-.}"
SKILLS_DIR="${TARGET}/.opencode/skills"
AGENTS_FILE="${TARGET}/AGENTS.md"
INSTALLER_MARKER="# Auto-generated by agent-skills install-opencode.sh"

echo "Installing agent-skills into ${TARGET}" >&2

command -v git >/dev/null 2>&1 || { echo "ERROR: git not found on PATH" >&2; exit 1; }

# 1. Ensure target .opencode/ exists.
mkdir -p "$(dirname "${SKILLS_DIR}")"

# 2. Symlink .opencode/skills -> this repo's skills/.
REPO_SKILLS="$(cd "$(dirname "$0")/.." && pwd)/skills"
if [ -L "${SKILLS_DIR}" ] && [ "$(readlink -f "${SKILLS_DIR}")" = "${REPO_SKILLS}" ]; then
  echo "  ✓ ${SKILLS_DIR} already linked" >&2
else
  ln -sfn "${REPO_SKILLS}" "${SKILLS_DIR}"
  echo "  ✓ linked ${SKILLS_DIR} -> ${REPO_SKILLS}" >&2
fi

# 3. Scaffold AGENTS.md if absent. Never overwrite an existing file.
if [ ! -f "${AGENTS_FILE}" ]; then
  {
    echo "${INSTALLER_MARKER}"
    echo "# AGENTS.md"
    echo ""
    echo "This project uses agent-skills. Skills live in \`.opencode/skills/\` (symlinked)."
    echo ""
    echo "## OpenCode Integration"
    echo ""
    echo "- If a task matches a skill, invoke it via the \`skill\` tool."
    echo "- Prefer \`AGENTS.md\` over \`CLAUDE.md\` when both exist."
    echo ""
    echo "See https://github.com/addyosmani/agent-skills for the full catalog."
  } >"${AGENTS_FILE}"
  echo "  ✓ wrote ${AGENTS_FILE}" >&2
else
  echo "  ✓ ${AGENTS_FILE} already present (left untouched)" >&2
fi

# 4. Verify.
[ -d "${REPO_SKILLS}" ] || { echo "ERROR: skills/ not found at ${REPO_SKILLS}" >&2; exit 1; }
[ -L "${SKILLS_DIR}" ]  || { echo "ERROR: ${SKILLS_DIR} not a symlink" >&2; exit 1; }

echo "Done. Skills available at ${SKILLS_DIR}" >&2
```

The `INSTALLER_MARKER` comment on line 1 of the scaffolded `AGENTS.md` is how
`update-opencode.sh` detects that the file was written by the installer (and is therefore
safe to refresh) versus hand-edited (and must be left alone).

### Updater script — `scripts/update-opencode.sh`

```sh
#!/bin/bash
set -e

TARGET="${1:-.}"
SKILLS_DIR="${TARGET}/.opencode/skills"
AGENTS_FILE="${TARGET}/AGENTS.md"
INSTALLER_MARKER="# Auto-generated by agent-skills install-opencode.sh"

echo "Updating agent-skills in ${TARGET}" >&2

# 1. Pull latest skills from the repo this script lives in.
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "  • pulling latest in ${REPO_ROOT}" >&2
git -C "${REPO_ROOT}" pull --ff-only

# 2. Re-verify the symlink. Recreate if missing.
REPO_SKILLS="${REPO_ROOT}/skills"
if [ ! -L "${SKILLS_DIR}" ] || [ "$(readlink -f "${SKILLS_DIR}")" != "${REPO_SKILLS}" ]; then
  mkdir -p "$(dirname "${SKILLS_DIR}")"
  ln -sfn "${REPO_SKILLS}" "${SKILLS_DIR}"
  echo "  ✓ re-linked ${SKILLS_DIR} -> ${REPO_SKILLS}" >&2
else
  echo "  ✓ ${SKILLS_DIR} already linked" >&2
fi

# 3. Refresh AGENTS.md only if it carries the installer marker.
if [ -f "${AGENTS_FILE}" ] && head -n1 "${AGENTS_FILE}" | grep -qF "${INSTALLER_MARKER}"; then
  # Re-scaffold with the latest template (marker preserved).
  {
    echo "${INSTALLER_MARKER}"
    echo "# AGENTS.md"
    echo ""
    echo "This project uses agent-skills. Skills live in \`.opencode/skills/\` (symlinked)."
    echo ""
    echo "## OpenCode Integration"
    echo ""
    echo "- If a task matches a skill, invoke it via the \`skill\` tool."
    echo "- Prefer \`AGENTS.md\` over \`CLAUDE.md\` when both exist."
    echo ""
    echo "See https://github.com/addyosmani/agent-skills for the full catalog."
  } >"${AGENTS_FILE}"
  echo "  ✓ refreshed ${AGENTS_FILE} (installer-managed)" >&2
elif [ -f "${AGENTS_FILE}" ]; then
  echo "  ✓ ${AGENTS_FILE} is hand-edited (left untouched)" >&2
else
  echo "  • ${AGENTS_FILE} absent; run install-opencode.sh first" >&2
  exit 1
fi

# 4. Verify.
[ -L "${SKILLS_DIR}" ] || { echo "ERROR: ${SKILLS_DIR} not a symlink after update" >&2; exit 1; }

echo "Done. Skills at ${SKILLS_DIR}" >&2
```

Design choice — two separate scripts rather than one `--update` flag: `install-opencode.sh`
must be runnable against a project that has never had agent-skills (no marker, no symlink,
no `AGENTS.md`); `update-opencode.sh` assumes a prior install and is allowed to fail loudly
when that assumption is broken. Combining them would force every update call to re-derive
whether it is in install-mode or update-mode, which is the exact ambiguity separating them.
Two scripts, two contracts, no mode flag.

Conventions for both scripts (from `docs/skill-anatomy.md` "Script Requirements"):
- `#!/bin/bash` shebang.
- `set -e` for fail-fast.
- All human-facing messages to **stderr**; the final success line goes to stdout.
- No secrets; no destructive ops; idempotent (re-runnable).

---

## Testing Strategy

The repo has no `npm test` (it's a documentation project). Verification is by the existing
Node-based validators plus shell tests for any new script.

### What to test

| Concern | Test | Location |
|---|---|---|
| New skills conform to skill-anatomy | `node scripts/validate-skills.js` exits 0 | Existing script |
| New commands exist in all three dirs with identical `description` | `node scripts/validate-commands.js` exits 0 | Existing script |
| `plugin.json` / marketplace.json versions consistent | `node scripts/validate-versions.js` exits 0 | Existing script |
| No broken skill→skill or skill→references links | `node scripts/validate-reference-links.js` exits 0 | Existing script |
| Trigger/routing evals pass for new skills | `node scripts/run-evals.js` exits 0; add `evals/cases/spec-pr.json`, `evals/cases/issue-create.json`, `evals/cases/issue-list.json`, `evals/cases/issue-pr.json` with ≥3 positive + ≥2 negative + 1 behavioural eval (per CONTRIBUTING.md §"Creating the skill") | Existing script + new fixture files |
| `issue-create` derives the right kebab-cased title from a spec heading | New shell test: feed a fixture `# Spec: Widget 7 new feature` and assert the derived issue title is `[BUILD] widget-7-new-feature` | `scripts/issue-create-test.sh` |
| `spec-pr` derives the right kebab-cased PR title from a spec heading | New shell test: feed a fixture `# Spec: Widget 7 new feature` and assert the derived PR title is `[SPEC] widget-7-new-feature` | `scripts/spec-pr-test.sh` |
| `issue-list` filter only matches `[BUILD] ` prefix | New shell test against `gh issue list --json title` mock output | `scripts/issue-list-test.sh` |
| `install-opencode.sh` is idempotent and fails cleanly when prerequisites are missing | New `scripts/install-opencode-test.sh` (mirrors `hooks/session-start-test.sh` pattern) | new file |
| `update-opencode.sh` refreshes a marker-tagged `AGENTS.md` and leaves a hand-edited one untouched | New `scripts/update-opencode-test.sh` | new file |
| `docs/opencode-setup.md` accurately describes running both scripts | Manual: run installer in /tmp/opencode smoke dir, confirm `AGENTS.md` written (with marker) and `.opencode/skills` symlink resolves; run updater, confirm marker-tagged file is refreshed and a hand-edited file is left untouched | manual |

### Test locations

- Shell tests for new scripts go alongside existing shell tests (the repo's convention is
  `scripts/*-test.js` for Node scripts and `hooks/*-test.sh` for shell; the OpenCode
  installer and updater tests go in `scripts/install-opencode-test.sh` and
  `scripts/update-opencode-test.sh` to match the `*-test.sh` pattern).
- Eval cases go in `evals/cases/<skill-name>.json` per `CONTRIBUTING.md`.

### Behavioural coverage

Each new skill's behavioural eval must include at least one scenario where `gh` is absent
from `PATH` and the skill correctly reports the missing prerequisite instead of failing
silently.

### Coverage bar

No percentage threshold — the repo's bar is "every validator script exits 0 and every new
skill has its required eval case file." That bar is non-negotiable for merge.

---

## Boundaries

### Always do

- Run **all** of `validate-skills.js`, `validate-commands.js`, `validate-versions.js`,
  `validate-reference-links.js`, and `run-evals.js` before committing changes to skills or
  commands.
- Add a new command to **all three** command directories (`.claude/commands/`,
  `commands/`, `.gemini/commands/`) with byte-identical `description` fields.
- Add an eval case file (`evals/cases/<skill>.json`) for every new skill, meeting the
  CONTRIBUTING.md minimum (≥3 positive, ≥2 negative, 1 behavioural trigger).
- Derive the `<name>` in issue/PR titles by **kebab-casing** the text after `# Spec:` in
  the merged spec's heading — not from a directory name, not from a free-text prompt.
- Use the **`[BUILD]`** prefix for build-tracking issues (`issue-create`) and the
  **`[SPEC]`** prefix for spec PRs (`spec-pr`). Never mix the two.
- Ensure the `build` label exists on the repo before the labelled issue is created
  (`gh label create build --force` — `--force` makes it idempotent).
- Raise an implementation PR via `issue-pr` whose body references the build issue
  (`Resolves #<n>` or `Implements #<n>`) so GitHub links the PR to the issue.
- List **both** `AGENTS.md` and `CLAUDE.md` whenever referencing the agent-rules file;
  instruct preferring `AGENTS.md` when both exist.
- Use `set -e`, `#!/bin/bash`, stderr-for-humans / stdout-for-machines in any new
  `scripts/*.sh`, matching the `docs/skill-anatomy.md` "Script Requirements" section.
- Run `gh issue create` and `gh pr create` with `--title` and `--body-file` (never `--web`
  from a skill — skills must be scriptable).
- **Mark completed tasks in the todo file (and plan, if it tracks status) as part of the
  same commit as the code change** — edit `- [ ]` to `- [x]`, stage that file alongside the
  code, commit together. Never leave task-status updates for a separate "later" commit;
  the team reviews iteratively and every commit must be self-describing.
- Treat the spec as a living document: when path conventions change in this spec, update
  the spec first, then the code.

### Ask first

- Changing the `[BUILD] ` / `[SPEC] ` title prefixes, the `build` label name, or the
  `specs/<feature>/` directory layout (downstream consumers will have open issues/PRs using
  the current convention).
- Adding a new dependency (none expected; `gh` is the only new prerequisite, and only for
  the five issue-*/spec-pr commands).
- Editing `plugin.json` version or `marketplace.json` (also covered by
  `validate-versions.js`).
- Changing the install script's behaviour to overwrite an existing `AGENTS.md` (currently
  it scaffolds only when absent; do not change this without sign-off).
- Changing the updater to refresh a hand-edited `AGENTS.md` (currently refreshes only
  files carrying the installer marker; do not change without sign-off).
- Removing the repo-root `SPEC.md` / `tasks/` path fallbacks from `/build` — keep them as
  deprecated fallbacks to avoid breaking existing consumer repos.

### Never do

- Never auto-push commits, auto-merge PRs, or auto-close issues from a skill or command —
  humans review and merge. `issue-pr` and `spec-pr` open PRs but do not merge or close.
- Never write the GitHub auth token or any secret into a skill body, command prompt, or
  script. `gh` reads its own config; do not handle credentials.
- Never edit vendor directories or files under `node_modules/`.
- Never remove a failing validator; fix the underlying issue or mark a documented
  exception in the validator.
- Never create a new skill that duplicates an existing one's workflow — extend or
  reference instead (per CONTRIBUTING.md §"Before proposing a new skill").
- Never run `gh issue create` or `gh pr create` inside a CI run unattended; both are
  interactive developer commands.
- Never omit the eval case file for a new skill; CI will fail.
- Never overwrite a hand-edited `AGENTS.md`. The updater detects the installer marker and
  refuses to touch anything without it.
- Never use the `[SPEC]` prefix on a build-tracking issue or the `[BUILD]` prefix on a spec
  PR. The prefix is the single disambiguation signal.

---

## Success Criteria (restated, testable)

- [ ] `issue-create` reads `specs/<feature>/SPEC.md`, kebab-cases the text after `# Spec:`
  to derive `<name>`, and opens `[BUILD] <name>` with body links to spec/plan/todo and the
  `build` label (creating the label if absent).
- [ ] `issue-create` fails with a clear diagnostic when no `# Spec:` heading exists or
  `gh` is not on `PATH`.
- [ ] `issue-list` lists only open issues whose title starts with `[BUILD] `; closed and
  unrelated issues are excluded.
- [ ] `issue-build <n>` resolves the spec/plan/todo from issue `#<n>` (body links first,
  `[BUILD] <name>` fallback to `specs/<name>/`) and chains the `/build` flow.
- [ ] `issue-pr <n>` raises a pull request whose body references issue `#<n>`; GitHub
  links the PR to the issue. The issue is not auto-closed by this command.
- [ ] `spec-pr` reads `specs/<feature>/SPEC.md`, kebab-cases the text after `# Spec:` to
  derive `<name>`, and opens a PR titled `[SPEC] <name>` whose body references the
  spec/plan/todo files. The PR is not auto-merged.
- [ ] `/spec` writes to `specs/<feature>/SPEC.md`; `/plan` writes to
  `specs/<feature>/tasks/plan.md` and `specs/<feature>/tasks/todo.md`. Repo-root paths are
  deprecated.
- [ ] `/build` auto path-resolution list includes `specs/*/SPEC.md` and
  `specs/*/tasks/plan.md` while keeping legacy paths as deprecated fallbacks.
- [ ] `/build` (single-task and auto modes) edits the todo file's `- [ ]` checkbox to `- [x]`
  for each completed task and stages that edit in the **same commit** as the code change.
  Every commit's diff includes the checkbox flip alongside the code.
- [ ] `scripts/install-opencode.sh` installs into a target project (symlinks
  `.opencode/skills`, scaffolds `AGENTS.md` with installer marker if absent), is
  idempotent, and exits non-zero with a diagnostic on missing prerequisites.
- [ ] `scripts/update-opencode.sh` pulls the latest skills, re-verifies the symlink, and
  refreshes a marker-tagged `AGENTS.md` while leaving hand-edited files untouched.
- [ ] `docs/opencode-setup.md` documents both scripts and their prerequisites.
- [ ] All skills/commands that referenced `CLAUDE.md` alone now reference "AGENTS.md and
  CLAUDE.md" with a "prefer AGENTS.md" note.
- [ ] `node scripts/validate-skills.js`, `node scripts/validate-commands.js`,
  `node scripts/validate-versions.js`, `node scripts/validate-reference-links.js`, and
  `node scripts/run-evals.js` all exit 0.
- [ ] `evals/cases/spec-pr.json`, `evals/cases/issue-create.json`,
  `evals/cases/issue-list.json`, and `evals/cases/issue-pr.json` exist and pass the
  CONTRIBUTING.md minimum (≥3 positive, ≥2 negative, 1 behavioural).

---

## Resolved Open Questions

1. **Label on `[BUILD] ` issues?** — **Resolved:** attach a `build` label. `issue-create`
   calls `gh label create build --force` (idempotent — creates the label if absent, updates
   description/color if already present) before opening the labelled issue. The `[BUILD] `
   title prefix is retained as a secondary signal so `issue-list` can filter on title.

2. **Auto-close the issue when `/build` finishes?** — **Resolved:** No auto-close on build.
   Instead, add `/issue-pr <n>` which raises a pull request whose body references the
   issue (`Resolves #<n>` or `Implements #<n>`) so GitHub links the PR to the issue. The PR
   body summarises the work done against the spec/plan/todo. Merging the PR is the human
   action that closes the issue (if `Resolves`/`Closes` syntax is used).

3. **Cross-repo `gh --repo` support?** — **Resolved:** v1 targets the current repo only.
   No `--repo` flag on `spec-pr`, `issue-create`, `issue-list`, `issue-build`, or
   `issue-pr`. Add later if a cross-repo workflow emerges.

4. **Heading-with-spaces handling?** — **Resolved:** always kebab-case the text after
   `# Spec:` to produce `<name>`, and use the same kebab-cased string as the directory
   name. Example: `# Spec: Widget 7 new feature` → `[BUILD] widget-7-new-feature` (issue)
   and `[SPEC] widget-7-new-feature` (spec PR) and `specs/widget-7-new-feature/` (dir).
   The `<name>` is identical across all three; only the prefix differs.

5. **Prefix collision between spec PRs and build issues?** — **Resolved:** use `[SPEC]`
   for spec PRs (raised by `/spec-pr`) and `[BUILD]` for build issues (raised by
   `/issue-create`). Both share the same kebab-cased `<name>`, so a spec and its
   corresponding build issue are linked by `<name>` and disambiguated by prefix.
