# OCR Delegate Setup

This guide explains how to run a local, rules-driven review with Open Code Review (OCR) delegate mode.

## Overview

Delegate mode produces deterministic review scaffolding: the reviewable file list, mode and ref metadata, exclusions, and per-file rule groups. The host reviewer then reads each diff, applies the matching rules, and reports the findings. Use it for a local review when project rules should guide the review without an OCR-side endpoint.

Delegate review runs against the local repository and does not transmit repository content to an OCR endpoint. The launcher may perform a background npm-registry update check on startup; set `OCR_NO_UPDATE=1` in the environment for review invocations to suppress it. When the installer downloads the native binary, it verifies the download against its published SHA-256 checksum.

OCR preview reviews code/content extensions, but its reviewable-extension allowlist may exclude documentation formats such as markdown as `unsupported_ext`. Report excluded files explicitly and review them through the skill's normal five-axis path so no file is silently dropped.

The workflow is defined in the `code-review-and-quality` skill under **OCR Delegate Review (Local)** and is available through the `/delegate-review` command.

## Prerequisites

Install the OCR CLI if it is not already available, taking the current release:

```bash
command -v ocr || echo "Install: npm install -g @alibaba-group/open-code-review"
```

The delegate contract in this guide is verified against the current OCR release at the time you set up. Before relying on output, confirm the current install supports delegate mode with `ocr delegate --help`. Keeping the CLI current is a hygiene step in the normal review loop: install the latest when you first set up and update the global install as you go when a newer release lands or behaviour looks off.

## Running the Workflow

### 1. Preview

List reviewable files and capture the workspace, range, or commit metadata. Add exclusions when needed and respect them throughout the review.

```bash
ocr delegate preview [--from <ref> --to <ref>] [--commit <hash>] [--exclude <patterns>]
```

### 2. Resolve Rules

Pass the reviewable paths from the preview. Group the output by rule content so shared rules are applied once to every matching file.

```bash
ocr delegate rule <path1> <path2> ...
```

### 3. Read Each Diff

Use the command that matches the preview mode:

```bash
# Range mode
git diff <merge_base>..<to> -- <path>

# Commit mode
git show <commit> -- <path>

# Workspace mode
git diff HEAD -- <path>

# New untracked file in workspace mode
cat <path>
```

### 4. Review

Review every file against its matching rule group. Use the rule group as the checklist and the `code-review-and-quality` skill's five axes for coverage.

### 5. Report

Report findings with the rubric below, including file and line references and enough context to act on each reported issue.

## Severity Rubric and Folded Nits

- **Critical / High** — Security, data loss, broken behavior, or an API-contract regression. Always report.
- **Medium / Warning** — Likely bugs, edge-case regressions, missing validation, or maintainability problems with real future risk. Report with context.
- **Low / Nit** — Style, naming, or optional improvements. Include `Nits (folded): N` in the report rather than dropping them, and surface a low finding when it is clearly valuable.

This delegate report format is a compact presentation of the review skill's existing severity guidance, not a replacement for it.

## Verification

1. Run `command -v ocr` and confirm it resolves to the installed CLI.
2. Run `ocr delegate preview` and confirm the reported files, exclusions, mode, and refs match the intended review scope.
3. Run `ocr delegate rule <paths>` and confirm every reviewable file maps to a rule group.
4. Confirm every file the preview returned is either reviewed or explicitly reported as skipped, with a reason.
5. Confirm every reviewable file was reviewed and the report includes `Nits (folded): N`, even when the count is zero.
