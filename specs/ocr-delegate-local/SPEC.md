# OCR Delegate Review — Local Embed (agent-skills)

Status: **DRAFT — awaiting review**
Owner: agent-skills
Base: `main`
Scope: this repository only (`dbc-tech/agent-skills`). **`dbc-tech/dbc.github.review` is OUT of scope and will not be touched.**

## 1. Problem

Open Code Review (OCR) in **delegate mode** lets a host coding agent run its own review against a deterministic, rule-driven scaffold produced by OCR — so the review reuses the developer's existing agent subscription, needs no OCR-side LLM endpoint, and the host classifies findings (turning off the noise that full-mode posts produce).

The team wants this available as a **local / pre-PR dev workflow**. This work embeds OCR delegate review into `agent-skills` the same way OpenCode support was embedded: the reusable assets (a review workflow, a slash command, a setup guide) live in this repo and are distributed to consumers by the existing installer/updater machinery.

## 2. Non-goals

- **No change to `dbc.github.review`.** The CI job is explicitly out of scope (separate decision; its post-review already filters `[low]` comments and caps volume).
- **No new install/update scripts.** `install-opencode.sh` / `update-opencode.sh` already symlink the whole `skills/` tree and every `.claude/commands/*.md` into consumer agent configs. Anything added under `skills/` or `.claude/commands/` is distributed automatically. A second script pair would be redundant.
- **No new top-level skill directory.** This repo's CONTRIBUTING gates reject a near-duplicate skill (eval case requirements + a routing-collision check). The generic review route already exists as `code-review-and-quality`; OCR delegate is an enhancement to that skill, not a parallel skill.
- **`everything in OCR delegate mode is agent-driven`** — OCR provides the scaffold (`preview` + `rule`); the host agent performs the review.

## 3. Design

### 3.1 Extend `skills/code-review-and-quality`

Add an **OCR delegate scaffolding** section (or a `references/` file under that skill) that steps the host agent through the delegate workflow:

1. **Preview** — `ocr delegate preview [--from <ref> --to <ref>] [--commit <hash>] [--exclude <patterns>]` lists reviewable files + mode/ref metadata (workspace / range / commit).
2. **Rules** — `ocr delegate rule <path1> <path2> ...` resolves the review rules for the reviewable files, grouped by content (shared rules not repeated).
3. **Diff** — pull each file's diff via git (`git diff <merge_base>..<to> -- <path>` for range mode, `git show <commit> -- <path>` for commit mode, `git diff HEAD -- <path>` for workspace).
4. **Review** — review each file against its rule group.
5. **Report** — classify findings under **one canonical severity rubric** and **fold nits into a count** rather than silently deleting them (keeps review signal credible).

Prerequisite guard: at the top of the flow, `command -v ocr ||` prompt to install. Record the **pinned compatible CLI version** in the skill so a vendored guide doesn't drift against a newer global install.

### 3.2 Add a slash command `.claude/commands/delegate-review.md`

A `delegate-review` command (in the same style as the existing `review.md`) that points the host agent at the OCR-delegate section of `code-review-and-quality`. Placed under `.claude/commands/` so the existing OpenCode/install machinery distributes it for free.

### 3.3 Add `docs/ocr-delegate-setup.md`

A setup + usage guide mirroring `docs/opencode-setup.md`:

- Prerequisite: `which ocr || npm install -g @alibaba-group/open-code-review@<pinned>` (pinned version).
- What delegate mode does and when to use it.
- The workflow (preview → rules → diff → review → report).
- Verification.

### 3.4 No installer/updater changes

Confirmed redundant — existing scripts distribute `skills/` + `.claude/commands/`. The only "wiring" this feature needs is the runtime `command -v ocr` guard inside the skill/command, plus a docs page.

## 4. Version pinning & supply-chain posture

- Reference OCR at a **pinned release/commit** (`@alibaba-group/open-code-review@<pinned>`), not `latest`, `curl .../main`, or unpinned `npx skills add`.
- Vendor the skill/command content as a **human-reviewed snapshot**; record the upstream tag/commit, tested CLI version, content hash, and any local modifications.
- OCR is Apache-2.0 — preserve attribution + applicable third-party notice on vendored content.
- Before rollout, verify the installed OCR binary makes **no unexpected network egress in delegate mode** on a throwaway repo (this repo holds high-sensitivity content).

## 5. Canonical severity rubric

Adopt a single rubric across the skill + command so the host agent's output is consistent:

- **Critical / High** — security, data loss, broken behaviour, API-contract regression. Always report.
- **Medium / Warning** — likely bugs, edge-case regressions, missing validation, maintainability with real risk. Report with context.
- **Low / Nit** — style, naming, optional improvements. **Fold into a count** (not silently deleted).

(The CI in `dbc.github.review` uses a `[high]/[medium]/[low]` prefix which is a separate surface — not part of this change.)

## 6. Tests / evals

- Extend `evals/cases/code-review-and-quality.json` with OCR-delegate trigger prompts (positive + negative + a behavioral case), rather than a new case file for a non-existent skill.
- Add a **CLI-prereq failure case** (missing `ocr` → the skill/command surfaces the guard).
- Run `node scripts/run-evals.js` (Tier-2 routing + collision check) and validate commands (`node scripts/validate-commands.js`).
- Keep any command-parity checks aligned with the added `delegate-review.md`.

## 7. File change summary (target)

| Path | Change |
|------|--------|
| `skills/code-review-and-quality/SKILL.md` | Add OCR-delegate section (or `references/` file) |
| `.claude/commands/delegate-review.md` | New command |
| `docs/ocr-delegate-setup.md` | New setup guide |
| `evals/cases/code-review-and-quality.json` | Add OCR-delegate trigger + behavioral cases |

## 8. Tasks

- [ ] Confirm OCR delegate `preview`/`rule` subcommand output against the pinned CLI version
- [ ] Vendor the OCR delegate workflow content as a reviewed snapshot (tag/commit/hash recorded, Apache-2.0 attribution)
- [ ] Extend `skills/code-review-and-quality` with the OCR-delegate section
- [ ] Add `.claude/commands/delegate-review.md`
- [ ] Add `docs/ocr-delegate-setup.md` (pinned prereq + workflow)
- [ ] Add CLI-prereq guard (`command -v ocr`, pinned-version check) to the skill/command
- [ ] Fold nits into a count, one canonical rubric
- [ ] Extend `evals/cases/code-review-and-quality.json` (positive/negative/behavioral + prereq-failure case)
- [ ] Run `node scripts/run-evals.js` and `node scripts/validate-commands.js` green
- [ ] Verify OCR binary makes no unexpected network egress in delegate mode (throwaway repo)

## 9. Verification

- [ ] `ocr delegate preview` / `ocr delegate rule` run against the pinned CLI on a sample repo
- [ ] Eval + validator suite green
- [ ] `delegate-review.md` command passes command-parity validation
- [ ] No change to `dbc.github.review`
- [ ] No new install/update scripts added
