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
# The board's shell: board.css + board.js. The board skill copies these next to the page it
# writes, so an instance board is markup and data only and never re-emits 12 KB of styling.
copy_tree board-shell
# Small helpers the skills call by absolute path, e.g. tools/inline-shell.py, which folds a
# page's shell back in when the page has to travel on its own.
copy_tree tools
copy_tree templates
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

# Register the handoff guard. It fixes the path a handoff is written to, hides that file from
# git, tells a new session the file is waiting, and moves it out of the repository the moment it
# is read. PostToolUse is matched on Write and Read because those are the two moments the flow
# must not depend on the model remembering anything.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/handoff-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
wanted = {"SessionStart": [None], "UserPromptSubmit": [None], "PostToolUse": ["Write", "Read"]}
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
print(f"  hooks: handoff guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the context guard. It reads the real token count out of the transcript and raises the
# clear-at-250k rule itself, because measured over 173 sessions the rule-as-prose was ignored for a
# month. UserPromptSubmit catches the start of a turn; PostToolUse is unmatched — it must see every
# tool call, since a turn is a median of 25 requests and can cross the threshold without ever
# passing a prompt boundary. The script announces each band once per session on the tool path.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/context-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
added = 0
for event in ("UserPromptSubmit", "PostToolUse"):
    entries = hooks.setdefault(event, [])
    if any(script in json.dumps(e) and e.get("matcher") is None for e in entries):
        continue
    entries.append({"hooks": [{"type": "command", "command": script, "timeout": 10}]}); added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: context guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the bulk guard. It refuses, at the call site, the three things measured to be the largest
# leaks into the main context: screenshots past a budget of two per session, a whole-file Read, and a
# Write carrying a page-sized body. Each refusal names the subagent to use instead. Two PreToolUse
# entries so the script is not run on every unrelated tool call.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/bulk-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
matchers = [
    "Read|Write",
    "Bash",
    "mcp__claude-in-chrome__computer|mcp__claude-in-chrome__browser_batch"
    "|mcp__Claude_Browser__computer|mcp__Claude_Code_iOS_Simulator__control"
    "|mcp__computer-use__screenshot|mcp__computer-use__zoom|mcp__computer-use__computer_batch",
]
entries = hooks.setdefault("PreToolUse", [])
added = 0
for m in matchers:
    if any(script in json.dumps(e) and e.get("matcher") == m for e in entries):
        continue
    entries.append({"matcher": m, "hooks": [{"type": "command", "command": script, "timeout": 10}]})
    added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: bulk guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the browser guard. bulk-guard caps the pictures; this one caps the round trips. Measured
# 2026-08-25 over 1802 transcripts: 8 700 browser tool calls in three weeks, 420 of them batched —
# five percent. Every unbatched call is its own request, and a request re-sends the whole context.
# It counts only the predictable actions (click, type, navigate, form fill) and nudges once per run
# of four, then resets, so it can never deadlock a flow that genuinely has to look between steps.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/browser-guard.sh" <<'BG'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
matcher = (
    "mcp__claude-in-chrome__computer|mcp__claude-in-chrome__navigate|mcp__claude-in-chrome__form_input"
    "|mcp__claude-in-chrome__file_upload|mcp__claude-in-chrome__browser_batch"
    "|mcp__Claude_Browser__computer|mcp__Claude_Browser__navigate|mcp__Claude_Browser__form_input"
    "|mcp__computer-use__computer_batch"
)
entries = data.setdefault("hooks", {}).setdefault("PreToolUse", [])
if any(script in json.dumps(e) for e in entries):
    print("  hooks: browser guard already registered")
else:
    entries.append({"matcher": matcher, "hooks": [{"type": "command", "command": script, "timeout": 10}]})
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
    print("  hooks: browser guard registered")
BG
fi

# Register the dash guard. The long-dash ban was written down on 2026-08-13 and kept failing,
# because it lived only in skills/draft-message/SKILL.md and most drafts never load that skill.
# So the check sits at the keystroke instead: browser typing and form fills always, plus briefs
# and draft files that carry text meant for a person. Status files, boards and code are untouched.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/dash-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON, skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
matchers = [
    "Write|Edit",
    "Agent|SendMessage",
    "mcp__claude-in-chrome__computer|mcp__claude-in-chrome__form_input"
    "|mcp__Claude_Browser__computer|mcp__Claude_Browser__form_input",
]
entries = hooks.setdefault("PreToolUse", [])
added = 0
for m in matchers:
    if any(script in json.dumps(e) and e.get("matcher") == m for e in entries):
        continue
    entries.append({"matcher": m, "hooks": [{"type": "command", "command": script, "timeout": 10}]})
    added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: dash guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the page guard. A generated page that reloads itself, or focuses its own window,
# drags his macOS Space over to Chrome while he is working somewhere else. The ban was written
# into skills/board/SKILL.md on 2026-08-16 and kept coming back, because page-writer-sonnet, the
# chew template, the meeting-live renderer and README still taught the old way. So the check sits
# at the Write instead, and it fires inside subagents too.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/page-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON, skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("PreToolUse", [])
added = 0
# Claude Design writes files through its own MCP tool, never through Write, so it was the one
# generator the guard could not see until 2026-08-25.
for matcher in ("Write|Edit|mcp__claude-design__write_files|mcp__claude-design__create_support_js", "Bash"):
    if any(script in json.dumps(e) and e.get("matcher") == matcher for e in entries):
        continue
    entries.append({"matcher": matcher, "hooks": [{"type": "command", "command": script, "timeout": 10}]})
    added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: page guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the automatic handoff. He was writing the same three-step ritual by hand around three
# hundred times a day: session says "press /clear", he presses it, he types "pick up the handoff".
# A Stop hook takes the first step and handoff-guard takes the third; the keystroke in the middle
# is the only part no hook can do, verified 2026-08-25.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/handoff-auto.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON, skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("Stop", [])
added = 0
if not any(script in json.dumps(e) for e in entries):
    entries.append({"hooks": [{"type": "command", "command": script, "timeout": 15}]}); added = 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: automatic handoff registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the page sweep. The page guard only sees a page being written; it cannot see the ones
# that were already on disk, the ones another tool wrote, or the ones he downloaded. On 2026-08-25
# he asked for every existing file to be proved clean, not only future ones, so the sweep walks the
# whole disk at session start and reports only pages that can raise the window BY THEMSELVES.
# A first run costs about 7 s; after that an mtime cache makes it about 1 s.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/page-sweep.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON, skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("SessionStart", [])
added = 0
if not any(script in json.dumps(e) for e in entries):
    entries.append({"hooks": [{"type": "command", "command": script, "timeout": 20}]}); added = 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: page sweep registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the shell guard. Until 2026-08-21 every board rewrite re-emitted 9.5 KB of CSS and
# 2.7 KB of JS that had not changed since the file was created, into a context that is re-sent on
# every later request. The shells (board-shell/, plan-shell/, company-brief assets) fixed the
# templates; this keeps styling from creeping back into a page one convenient inline block at a
# time, in subagents as well as here. It also runs standalone: hooks/shell-guard.sh --check
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/shell-guard.sh" <<'SHELLGUARDPY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON, skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("PreToolUse", [])
added = 0
for matcher in ("Write|Edit", "Bash"):
    if any(script in json.dumps(e) and e.get("matcher") == matcher for e in entries):
        continue
    entries.append({"matcher": matcher, "hooks": [{"type": "command", "command": script, "timeout": 10}]})
    added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: shell guard registered ({added} new entr{'y' if added==1 else 'ies'})")
SHELLGUARDPY
fi

# Register the parallel guard. A fork inherits the parent's context and receives no SessionStart
# hook, so it believes it owns the parent's id series, board and handoff. This assigns each live
# session its own series and states the division, on UserPromptSubmit because that is the only
# event a forked session actually gets. Silent while there is one session, which is almost always.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/parallel-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON, skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
added = 0
for event in ("UserPromptSubmit", "SessionStart"):
    entries = hooks.setdefault(event, [])
    if any(script in json.dumps(e) for e in entries):
        continue
    entries.append({"hooks": [{"type": "command", "command": script, "timeout": 10}]}); added += 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: parallel guard registered ({added} new entr{'y' if added==1 else 'ies'})")
PY
fi

# Register the chrome guard. It injects the deviceId → machine mapping at session start, because
# the browser list itself cannot be told apart: names are positional and isLocal is wrong.
if command -v python3 >/dev/null 2>&1; then
  python3 - "${CLAUDE_DIR}/settings.json" "${CLAUDE_DIR}/hooks/chrome-guard.sh" <<'PY'
import json, os, sys
path, script = sys.argv[1], sys.argv[2]
data = {}
if os.path.exists(path):
    try:
        with open(path) as f: data = json.load(f)
    except Exception:
        print("  hooks: settings.json is not valid JSON — skipped, fix it and re-run"); raise SystemExit(0)
hooks = data.setdefault("hooks", {})
entries = hooks.setdefault("SessionStart", [])
added = 0
if not any(script in json.dumps(e) for e in entries):
    entries.append({"hooks": [{"type": "command", "command": script, "timeout": 10}]}); added = 1
if added:
    with open(path, "w") as f: json.dump(data, f, indent=2); f.write("\n")
print(f"  hooks: chrome guard registered ({added} new entr{'y' if added==1 else 'ies'})")
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

# The shelf is served permanently on 8899, because boards are handed over as
# http://localhost:8899/... links and never as file:// — they pull _shell/board.js,
# which does not load over file://. A LaunchAgent survives a reboot; a per-session
# http.server on a random port does not.
if [ "$(uname)" = "Darwin" ]; then
  TASKS_DIR="${HOME}/Tasks"
  mkdir -p "${TASKS_DIR}/_shell" "${TASKS_DIR}/_repos"
  cp -f board-shell/board.css board-shell/board.js "${TASKS_DIR}/_shell/" 2>/dev/null || true
  cp -f plan-shell/plan.css plan-shell/plan.js "${TASKS_DIR}/_shell/" 2>/dev/null || true

  AGENT_LABEL="com.alexslk.tasks-board-server"
  AGENT_PLIST="${HOME}/Library/LaunchAgents/${AGENT_LABEL}.plist"
  if [ -f templates/tasks-board-server.plist ]; then
    mkdir -p "${HOME}/Library/LaunchAgents"
    sed "s|TASKS_DIR|${TASKS_DIR}|g" templates/tasks-board-server.plist > "${AGENT_PLIST}.new"
    if [ ! -f "$AGENT_PLIST" ] || ! cmp -s "${AGENT_PLIST}.new" "$AGENT_PLIST"; then
      mv "${AGENT_PLIST}.new" "$AGENT_PLIST"
      launchctl bootout "gui/$(id -u)/${AGENT_LABEL}" 2>/dev/null || true
      launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST" 2>/dev/null || true
      echo "  board server: installed, serving ${TASKS_DIR} on http://localhost:8899"
    else
      rm -f "${AGENT_PLIST}.new"
      launchctl print "gui/$(id -u)/${AGENT_LABEL}" >/dev/null 2>&1 \
        || launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST" 2>/dev/null || true
      echo "  board server: already serving http://localhost:8899"
    fi
  fi

  if [ -f tools/tasks-index.py ] && command -v python3 >/dev/null 2>&1; then
    python3 tools/tasks-index.py >/dev/null 2>&1 \
      && echo "  board index: ${TASKS_DIR}/index.html rebuilt"
  fi
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
