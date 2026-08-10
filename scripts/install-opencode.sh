#!/bin/bash
set -e

TARGET="${1:-.}"
SKILLS_DIR="${TARGET}/.opencode/skills"

echo "Installing agent-skills into ${TARGET}" >&2

command -v git >/dev/null 2>&1 || { echo "ERROR: git not found on PATH" >&2; exit 1; }

# 1. Ensure target .opencode/ exists.
mkdir -p "$(dirname "${SKILLS_DIR}")"

# 2. Symlink .opencode/skills -> this repo's skills/.
#    If the target is a real directory (a copy), back it up before replacing.
REPO_SKILLS="$(cd "$(dirname "$0")/.." && pwd)/skills"
if [ -L "${SKILLS_DIR}" ] && [ "$(readlink -f "${SKILLS_DIR}")" = "${REPO_SKILLS}" ]; then
  echo "  ✓ ${SKILLS_DIR} already linked" >&2
else
  if [ -d "${SKILLS_DIR}" ] && [ ! -L "${SKILLS_DIR}" ]; then
    BACKUP="${SKILLS_DIR}.bak.$(date +%Y%m%d%H%M%S)"
    mv "${SKILLS_DIR}" "${BACKUP}"
    echo "  • backed up existing directory to ${BACKUP}" >&2
  fi
  ln -sfn "${REPO_SKILLS}" "${SKILLS_DIR}"
  echo "  ✓ linked ${SKILLS_DIR} -> ${REPO_SKILLS}" >&2
fi

# 3. Symlink commands into the global OpenCode config directory.
#    Source: .claude/commands/ (shared across Claude Code and OpenCode).
#    Target respects OPENCODE_CONFIG_DIR, then XDG_CONFIG_HOME, then ~/.config.
REPO_COMMANDS="$(cd "$(dirname "$0")/.." && pwd)/.claude/commands"
if [ -n "${OPENCODE_CONFIG_DIR}" ]; then
  OPENCODE_CONFIG="${OPENCODE_CONFIG_DIR}"
elif [ -n "${XDG_CONFIG_HOME}" ]; then
  OPENCODE_CONFIG="${XDG_CONFIG_HOME}/opencode"
else
  OPENCODE_CONFIG="${HOME}/.config/opencode"
fi
COMMANDS_TARGET="${OPENCODE_CONFIG}/commands"

if [ -d "${REPO_COMMANDS}" ]; then
  mkdir -p "${COMMANDS_TARGET}"
  for cmd_file in "${REPO_COMMANDS}"/*.md; do
    [ -f "$cmd_file" ] || continue
    cmd_name="$(basename "$cmd_file")"
    cmd_target="${COMMANDS_TARGET}/${cmd_name}"
    if [ -L "${cmd_target}" ] && [ "$(readlink -f "${cmd_target}")" = "${cmd_file}" ]; then
      echo "  ✓ ${cmd_target} already linked" >&2
    else
      ln -sfn "${cmd_file}" "${cmd_target}"
      echo "  ✓ linked ${cmd_target} -> ${cmd_file}" >&2
    fi
  done
else
  echo "  ⚠ no .claude/commands/ found in repo, skipping command installation" >&2
fi

# 4. Verify.
[ -d "${REPO_SKILLS}" ] || { echo "ERROR: skills/ not found at ${REPO_SKILLS}" >&2; exit 1; }
[ -L "${SKILLS_DIR}" ]  || { echo "ERROR: ${SKILLS_DIR} not a symlink" >&2; exit 1; }

echo "Done. Skills available at ${SKILLS_DIR}, commands at ${COMMANDS_TARGET}"
