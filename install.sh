#!/usr/bin/env bash
# Install / update the orchestrator kit into ~/.claude on this machine.
# Idempotent: safe to re-run after every `git pull`.
#
#   cd ~/Developer/claude-kit && git pull && ./install.sh
#
# Agents and skills installed at user level apply to EVERY project on this machine.
# Nothing here is project-specific; per-repo files (CLAUDE.md, CLAUDE.local.md,
# .claude/tasks/<task>.md) stay in their repos.

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
copy_tree hooks
# The plan renderer the chew skill copies into a repo's .claude/tasks/_shell/. Installed here so
# the skill finds it at a fixed path whatever the machine's clone location is.
copy_tree plan-shell
chmod +x "${CLAUDE_DIR}/hooks/"*.sh 2>/dev/null || true

# Register the status guard. It records context resets and briefs the next session on whether
# the project's status files can be trusted; it never writes them — only the wrap-up skill does.
# Merged into settings.json, never overwriting other hooks; re-running install is idempotent.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/status-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
wanted = {"SessionStart": [None], "UserPromptSubmit": [None],
          "PreCompact": ["manual", "auto"], "SessionEnd": ["clear"]}
added = 0
for event, matchers in wanted.items():
    entries = hooks.setdefault(event, [])
    for matcher in matchers:
        if any(script in json.dumps(e) and e.get("matcher") == matcher for e in entries):
            continue
        entry = {"hooks": [{"type": "command", "command": script, "timeout": 10}]}
        if matcher is not None:
            entry["matcher"] = matcher
        entries.append(entry); added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: status guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the copilot guard. It keeps bulk work on an employer-funded Copilot licence instead
# of the user's personal subscription. The script checks that licence itself and says nothing on
# a machine without it, so registering it everywhere is safe. PreToolUse is matched on the Agent
# tool because that is the one call the rule cannot otherwise reach.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/copilot-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
wanted = {"SessionStart": [None], "UserPromptSubmit": [None], "PreToolUse": ["Agent"]}
added = 0
for event, matchers in wanted.items():
    entries = hooks.setdefault(event, [])
    for matcher in matchers:
        if any(script in json.dumps(e) and e.get("matcher") == matcher for e in entries):
            continue
        entry = {"hooks": [{"type": "command", "command": script, "timeout": 10}]}
        if matcher is not None:
            entry["matcher"] = matcher
        entries.append(entry); added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: copilot guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Merge the machine-conditional rules into ~/.claude/CLAUDE.md between markers. That file also
# holds whatever the user wrote by hand, so this replaces only the marked block, never the file.
# Each rule states its own precondition and is inert on a machine where it does not apply.
if command -v python3 >/dev/null 2>&1 && [ -d "${KIT_DIR}/machine-rules" ]; then
  python3 - "${CLAUDE_DIR}/CLAUDE.md" "${KIT_DIR}/machine-rules" <<'PY'
import os, sys, glob
path, src = sys.argv[1], sys.argv[2]
BEGIN, END = "<!-- kit:machine-rules BEGIN -->", "<!-- kit:machine-rules END -->"
parts = []
for f in sorted(glob.glob(os.path.join(src, "*.md"))):
    with open(f) as fh: parts.append(fh.read().rstrip())
if not parts:
    raise SystemExit(0)
block = (BEGIN + "\n<!-- Generated by claude-kit install.sh. Edit the kit, not this block. -->\n\n"
         + "\n\n---\n\n".join(parts) + "\n" + END)
old = ""
if os.path.exists(path):
    with open(path) as f: old = f.read()
if BEGIN in old and END in old:
    head, rest = old.split(BEGIN, 1)
    _, tail = rest.split(END, 1)
    new = head + block + tail
else:
    new = (old.rstrip() + "\n\n" if old.strip() else "") + block + "\n"
if new != old:
    with open(path, "w") as f: f.write(new)
    print(f"  machine rules: {len(parts)} file(s) merged into {path}")
else:
    print("  machine rules: already current")
PY
fi

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
echo
echo "Integrations are per machine and NOT installed by default — an unauthenticated server"
echo "nags on every session start. Only on a machine that actually has them:"
echo "  ./setup-mcp.sh jira      # Atlassian Cloud"
echo "  ./setup-mcp.sh figma"
echo "  ./setup-mcp.sh jira figma"
