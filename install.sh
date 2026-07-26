#!/usr/bin/env bash
# Install / update the orchestrator kit into ~/.claude on this machine.
# Idempotent: safe to re-run after every `git pull`.
#
#   cd ~/Developer/claude-kit && git pull && ./install.sh
#
# Agents and skills installed at user level apply to EVERY project on this machine.
# Nothing here is project-specific; per-repo files (CLAUDE.md, CLAUDE.local.md,
# .claude/state.md) stay in their repos.

set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="${HOME}/.claude"

copy_tree() {
  local name="$1"
  local src="${KIT_DIR}/${name}"
  local dst="${CLAUDE_DIR}/${name}"
  [ -d "$src" ] || return 0
  mkdir -p "$dst"
  # Copy, do not delete: anything you keep in ~/.claude outside the kit survives.
  cp -R "${src}/." "${dst}/"
  echo "  ${name}: $(find "$src" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ') entries -> ${dst}"
}

echo "Installing orchestrator kit from ${KIT_DIR}"
copy_tree agents
copy_tree skills
copy_tree output-styles

echo
echo "Done. Next:"
echo "  1. /clear, then select the 'Orchestrator' output style (it loads at session start)."
echo "  2. For a new repo: copy templates/CLAUDE.local.md to its root and gitignore it."
