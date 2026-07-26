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

# Select the output style non-interactively. `/output-style` was removed in newer versions,
# and `/config` is a manual step — this sets the same `outputStyle` key those wrote.
# Merge, never overwrite: the file also holds permissions, env and hooks.
STYLE="orchestrator"
SETTINGS="${CLAUDE_DIR}/settings.json"
if [ ! -f "$SETTINGS" ]; then
  mkdir -p "$CLAUDE_DIR"
  printf '{\n  "outputStyle": "%s"\n}\n' "$STYLE" > "$SETTINGS"
  echo "  output style: created ${SETTINGS} with outputStyle=${STYLE}"
elif command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS" "$STYLE" <<'PY'
import json, sys, shutil
path, style = sys.argv[1], sys.argv[2]
with open(path) as f:
    raw = f.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError as e:
    sys.exit(f"  output style: {path} is not valid JSON ({e}); set \"outputStyle\": \"{style}\" by hand")
if data.get("outputStyle") == style:
    print(f"  output style: already {style}")
else:
    shutil.copyfile(path, path + ".bak")
    data["outputStyle"] = style
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    print(f"  output style: set to {style} (backup at {path}.bak)")
PY
else
  echo "  output style: python3 missing — add \"outputStyle\": \"${STYLE}\" to ${SETTINGS} by hand"
fi

echo
echo "Done. Run /clear — the output style loads at session start."
echo "For a new repo: copy templates/CLAUDE.local.md to its root and gitignore it."
