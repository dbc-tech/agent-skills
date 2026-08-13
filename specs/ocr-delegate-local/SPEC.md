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

## 2a. Scope & applicability

OCR delegate review is a **code/content review** tool: `ocr delegate preview` selects files by a compiled-in reviewable-extension allowlist (e.g. `.ts`, `.tsx`, `.json`, `.toml`, `.yml`, `.yaml`, `.js`, `.sh`) and reports unsupported extensions as `excluded: unsupported_ext`. On this repository the majority of content is Markdown, which the CLI does not select in its default preview allowlist.

Decision: the delegate workflow still applies here, with an explicit contract:
- Files the preview selects are reviewed against their rule groups via the delegate flow.
- Files the preview **excludes** (e.g. Markdown docs) are **reported explicitly** (path + reason), not silently skipped, and are covered by the skill's normal five-axis review path so no change is left unaddressed.
- The review report accounts for **every file the preview returned** (tracked and new/untracked `[added]`), explicitly noting any skipped and why, so partial coverage cannot be reported as complete.

## 3. Design

### 3.1 Extend `skills/code-review-and-quality`

Add an **OCR delegate scaffolding** section (or a `references/` file under that skill) that steps the host agent through the delegate workflow:

1. **Preview** — `ocr delegate preview [--from <ref> --to <ref>] [--commit <hash>] [--exclude <patterns>]` lists reviewable files + mode/ref metadata (workspace / range / commit).
2. **Rules** — `ocr delegate rule <path1> <path2> ...` resolves the review rules for the reviewable files, grouped by content (shared rules not repeated).
3. **Diff** — pull each file's diff via git (`git diff <merge_base>..<to> -- <path>` for range mode, `git show <commit> -- <path>` for commit mode, `git diff HEAD -- <path>` for workspace).
4. **Review** — review each file against its rule group.
5. **Report** — classify findings under **one canonical severity rubric** and **fold nits into a count** rather than silently deleting them (keeps review signal credible).

Prerequisite guard: at the top of the flow, `command -v ocr ||` prompt to install (non-executing echo form). Confirm `ocr delegate --help` resolves so the current install supports delegate mode (see §4).

### 3.2 Add a `delegate-review` slash command across all three command directories

A `delegate-review` command (in the same style as the existing `review.md`/`review.toml`) that points the host agent at the OCR-delegate section of `code-review-and-quality`. Because `scripts/validate-commands.js` requires every command to exist in **all three** directories with an **identical `description`**, this ships as three files:
- `.claude/commands/delegate-review.md`
- `.gemini/commands/delegate-review.toml`
- `commands/delegate-review.toml`

The existing OpenCode/install machinery already distributes every `.claude/commands/*.md` and `.gemini/commands/*.toml` for free.

### 3.3 Add `docs/ocr-delegate-setup.md`

A setup + usage guide mirroring `docs/opencode-setup.md`:

- Prerequisite (non-executing guard): `command -v ocr || echo "Install: npm install -g @alibaba-group/open-code-review"` (current release — see §4).
- What delegate mode does and when to use it, incl. the code/content-extension scope and the Markdown fallback.
- The workflow (preview → rules → diff → review → report).
- Behaviour notes: delegate review does not transmit repo content to an OCR endpoint, but the launcher can perform a background npm-registry update check on startup unless `OCR_NO_UPDATE=1` is set; the install binary download is checksum/sha-verified.
- Verification (incl. no file silently skipped).

### 3.4 No installer/updater changes

Confirmed redundant — existing scripts distribute `skills/` + `.claude/commands/`. The only "wiring" this feature needs is the runtime `command -v ocr` guard inside the skill/command, plus a docs page.

## 4. Version & supply-chain posture

The OCR CLI is installed as the **current release** — `npm install -g @alibaba-group/open-code-review`. Keeping it current is a **developer-hygiene responsibility** that sits in the team's normal review loop: install the latest when you first set up, and update the global install as you go when a newer release lands or behaviour looks off. Setup stays simple, and because the tool is re-verified against the current release whenever it is used, supply-chain exposure stays low and ownership is clear.

Supporting practices:
- **Capability check.** Confirm `ocr delegate --help` resolves before relying on output — a bare version string alone doesn't prove subcommand support.
- **Runtime update control.** The CLI launcher can run a background npm-registry update check on startup; suppress it for review invocations with `OCR_NO_UPDATE=1` so a run is deterministic and updates happen deliberately rather than in a background.
- **Egress.** Delegate review does not transmit repo content to an OCR endpoint. The install-time native-binary download is checksum/sha-verified by the installer; the startup update check is the one ambient registry call, suppressed by `OCR_NO_UPDATE`.
- Vendor the skill/command content as a **human-reviewed snapshot**; keep Apache-2.0 attribution + applicable third-party notice on vendored content.

## 5. Canonical severity rubric

Adopt a single rubric across the skill + command so the host agent's output is consistent. This rubric is **scoped to delegate reports only** and does not replace the skill's existing five-axis severity labels (`Critical` / required-unprefixed / `Nit` / `Optional` / `Consider` / `FYI`); reconcile them explicitly:

- **Critical / High** ↔ the skill's required/Critical tier — security, data loss, broken behaviour, API-contract regression. Always report; blocks merge.
- **Medium / Warning** — likely bugs, edge-case regressions, missing validation, maintainability with real risk. Report with context; not merge-blocking on its own.
- **Low / Nit** ↔ the skill's Nit / Optional / Suggestion tier — style, naming, optional improvements. **Fold into a count** (`Nits (folded): N`), not silently deleted; surface any low finding that is clearly valuable.

(The CI in `dbc.github.review` uses a `[high]/[medium]/[low]` prefix which is a separate surface — not part of this change.)

## 6. Tests / evals

- Extend `evals/cases/code-review-and-quality.json` with OCR-delegate trigger prompts (positive + negative) and a behavioral case, rather than a new case file for a non-existent skill.
- Add a **missing-prereq behavioral case**: a dialogue premise that `ocr` is absent (e.g. "`command -v ocr` returned non-zero") so the guard's install directive is exercised deterministically. Note the Tier-2 runner validates routing/schema only; behavioral dialogue cases are the mechanism for this (see `evals/README.md`).
- Run `node scripts/run-evals.js` (Tier-2 routing + collision check) and validate commands (`node scripts/validate-commands.js`), which enforces the 3-dir `delegate-review` command parity with identical descriptions.

## 7. File change summary (target)

| Path | Change |
|------|--------|
| `skills/code-review-and-quality/SKILL.md` | Add OCR-delegate section (scope + workflow + rubric + egress note) |
| `.claude/commands/delegate-review.md` | New command (identical `description` across dirs) |
| `.gemini/commands/delegate-review.toml` | New command |
| `commands/delegate-review.toml` | New command |
| `docs/ocr-delegate-setup.md` | New setup guide (current-release install + workflow + behaviour notes) |
| `evals/cases/code-review-and-quality.json` | Add OCR-delegate trigger (positive + negative) + behavioral cases |
| `README.md` | Command count 13→14, add `/delegate-review`, link the setup guide |

## 8. Tasks

- [ ] Confirm OCR delegate `preview`/`rule` subcommand output and the reviewable-extension allowlist on the installed CLI (`ocr delegate preview` in throwaway dir)
- [ ] Vendor the OCR delegate workflow content as a reviewed snapshot (Apache-2.0 attribution)
- [ ] Confirm `ocr delegate --help` resolves on a current release; document the hygiene practice to keep the global install up to date
- [ ] Extend `skills/code-review-and-quality` with the OCR-delegate section
- [ ] Add `delegate-review` command to all three dirs (`.claude/commands/delegate-review.md`, `.gemini/commands/delegate-review.toml`, `commands/delegate-review.toml`) with identical `description`
- [ ] Add `docs/ocr-delegate-setup.md` (non-executing guard, scope/fallback, behaviour notes, verification with no-file-silently-skipped)
- [ ] Add CLI-prereq guard (`command -v ocr`, non-executing) + note `OCR_NO_UPDATE=1` to skill/command/docs
- [ ] Fold nits into a count, one canonical rubric scoped to delegate reports (reconciled to the skill's taxonomy)
- [ ] Extend `evals/cases/code-review-and-quality.json` (positive/negative triggers + missing-prereq behavioral case)
- [ ] Update README (command count 13→14, `/delegate-review` table row, setup-guide link)
- [ ] Run `node scripts/run-evals.js`, `node scripts/validate-commands.js`, `node scripts/validate-reference-links.js` green

## 9. Verification

- [ ] `ocr delegate preview` / `ocr delegate rule` run on the installed CLI; excluded/reviewable split matches the scope contract, and excluded files are reported (not silently skipped)
- [ ] `ocr delegate --help` resolves on a current release; the update-as-you-go hygiene practice is documented
- [ ] Eval + validator suite green (incl. 3-dir command parity)
- [ ] README reflects 14 commands and links the setup guide
- [ ] No change to `dbc.github.review`
- [ ] No new install/update scripts added
