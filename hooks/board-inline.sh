#!/usr/bin/env bash
# board-inline.sh — bakes a board's rendered body and stylesheet into the file, after it is written.
#
# Why this exists as a hook and not as prose. The board is one <script type="application/json"
# id="board"> block and nothing else; the body is drawn at load time by the sibling
# _shell/board.js. When he clicks the board link in a chat, the Claude Code desktop app opens the
# page in its OWN pane, and that pane renders the HTML but does not resolve the page's sibling
# subresources — board.js never runs, board.css never loads, and he gets a blank white page. He
# has been told for months that the board is live and has been looking at nothing.
#
# Established 2026-08-26, with evidence: headless Chrome over file:// renders the same file in
# full (28 423 characters of body, both _shell files 200), so the page is not broken; and the two
# boards on this Mac that happen to be written as inline markup with an inline <style> are exactly
# the two that DO render in the pane. That is also why "recreate the board" appeared to fix it —
# recreation happened to produce a markup board.
#
# The fix cannot be "write markup boards": a board is rewritten in full at every stage change, and
# markup in the file means the rendered body and 9 KB of CSS go through the model's context on
# every rewrite, which is the exact cost board-shell/ was built to remove (see shell-guard.sh).
# So the agent keeps writing ONLY the JSON block, and this hook renders the rest AFTERWARDS, out
# of band. The rendered markup never enters any conversation's context.
#
# board-shell/board.js stays linked in the page as progressive enhancement: where it does run it
# replaces document.body wholesale, so the baked markup is overwritten by the live render and the
# 15-second self-refresh is untouched.
#
# WHAT TRIGGERS IT, and why it is not just Write. Almost no board on this machine is written with
# the Write tool. The established way to update one is a python heredoc through Bash — parse the
# JSON block out of the HTML, mutate the dict, write it back, re-parse to validate — and that is
# what ai-company/CLAUDE.md prescribes and what the desks actually do. A hook matching Write and
# Edit alone would pass its own tests and never fire on a real board update. So the decision is
# made on the FILE, not on the tool: any .html path the tool call names is checked for the board
# JSON block, and only a real board is rendered.
#
# The prefilter is deliberately a regex over the tool input, never a disk walk: a PostToolUse hook
# on Bash runs after EVERY shell command in every project, so a command that mentions no .html and
# no tasks folder must cost a few microseconds and nothing more.
#
# PostToolUse contract: the tool has already run. Nothing here may block, and nothing here may be
# the reason a session cannot work. It fires on every Write, Edit and Bash call in every project on
# this machine, including chats nobody is watching, so EVERY unexpected condition — no node, JSON
# that does not parse, a file that is not a board, a missing _shell, a renderer that throws —
# leaves the file exactly as the tool wrote it and exits 0. A hook that mangles a board is worse
# than the bug it fixes.
#
# Escape hatch: BOARD-INLINE-EXEMPT anywhere in the file leaves it alone.

set -uo pipefail

# This hook has nothing to say. Everything it could print is either "I did nothing" or a job
# control notice from backgrounding the renderer, and a PostToolUse hook that exits 0 must not put
# either in front of anyone.
exec 2>/dev/null

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# The cheapest possible gate, and the one that runs after every Bash call on this machine: a shell
# pattern match on the raw payload, before any interpreter is started. Measured 2026-08-26 —
# spawning python3 to decide costs ~33 ms per call, and this brings the common case to nothing.
case "$payload" in
  *.html*|*.htm\"*|*/tasks*) : ;;
  *) exit 0 ;;
esac

command -v python3 >/dev/null 2>&1 || exit 0
command -v node    >/dev/null 2>&1 || exit 0

# Every .html path this tool call named, one per line, absolute. For Write and Edit that is the
# file_path; for Bash it is whatever the command string mentions — which is how the python-heredoc
# board patch names its file. A folder mentioned without a file name (…/.claude/tasks) contributes
# the boards in it that changed in the last two minutes, so a path assembled at runtime is still
# caught. Bounded at 12 paths; nothing here touches the disk except to check that a name exists.
targets="$(printf '%s' "$payload" | python3 -c '
import json, os, re, sys, time
try: d = json.load(sys.stdin)
except Exception: raise SystemExit
tool = str(d.get("tool_name") or "")
ti   = d.get("tool_input") or {}
cwd  = str(d.get("cwd") or os.getcwd())

if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
    blob = str(ti.get("file_path") or "")
elif tool == "Bash":
    blob = str(ti.get("command") or "")
else:
    raise SystemExit

# The whole cost of this hook on an unrelated Bash call is this one test.
low = blob.lower()
if ".html" not in low and ".htm\"" not in low and "/tasks" not in low: raise SystemExit

def absolute(p):
    return p if os.path.isabs(p) else os.path.normpath(os.path.join(cwd, p))

files, dirs = [], []
for m in re.finditer(r"[^\s\x27\"()<>|;&$`,\[\]]+\.html?\b", blob):
    files.append(absolute(m.group(0)))
for m in re.finditer(r"[^\s\x27\"()<>|;&$`,\[\]]*(?:\.claude/tasks|/Tasks/[^\s\x27\"()<>|;&$`,\[\]/]+)", blob):
    if not m.group(0).lower().endswith((".html", ".htm")): dirs.append(absolute(m.group(0)))

now, out = time.time(), []
for f in files:
    if f not in out: out.append(f)
for dirname in dirs[:4]:
    try: names = sorted(os.listdir(dirname))
    except Exception: continue
    for n in names:
        if not n.lower().endswith((".html", ".htm")): continue
        f = os.path.join(dirname, n)
        try: fresh = now - os.path.getmtime(f) < 120
        except Exception: continue
        if fresh and f not in out: out.append(f)

for f in out[:12]:
    print(f)
' 2>/dev/null)" || exit 0

[ -n "${targets:-}" ] || exit 0

# The kit copy first: it is the one install.sh keeps current. A board's own _shell may be older
# than the machine, and render-body.js reads the page's own board.js anyway.
RENDER=""
for c in "${HOME}/.claude/board-shell/render-body.js" \
         "${HOME}/Developer/claude-kit/board-shell/render-body.js"; do
  [ -f "$c" ] && { RENDER="$c"; break; }
done
[ -n "$RENDER" ] || exit 0

inline_one() {
  target="$1"
  [ -f "$target" ] || return 0
  # The shell's own files and this hook's own documentation mention the block; they are not pages.
  case "$target" in */_shell/*|*/hooks/*|*/.git/*) return 0 ;; esac
  # Only a board. Two cheap greps, and the second one is what keeps an ordinary page out.
  grep -q 'application/json' "$target" 2>/dev/null || return 0
  grep -q 'id="board"'       "$target" 2>/dev/null || return 0
  grep -q 'BOARD-INLINE-EXEMPT' "$target" 2>/dev/null && return 0
  # A board that is already inlined and was not touched in the last two minutes was only read, not
  # written — do not pay for a node process to tell us nothing changed.
  if grep -q '<!--board-inline-->' "$target" 2>/dev/null \
     && [ -z "$(find "$target" -mmin -2 2>/dev/null)" ]; then
    return 0
  fi

  # A watchdog, because `timeout` is not on a stock macOS and a pathological board must not hang a
  # session. render-body.js writes through a temp file and rename(), so killing it cannot truncate
  # the board — the worst case is a stale temp file beside it, which this then removes.
  ( node "$RENDER" "$target" >/dev/null 2>&1 ) &
  pid=$!
  n=0
  while kill -0 "$pid" 2>/dev/null && [ "$n" -lt 20 ]; do
    sleep 0.5
    n=$((n + 1))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    rm -f "$(dirname "$target")/.$(basename "$target").board-inline."* 2>/dev/null
  fi
  wait "$pid" 2>/dev/null
  return 0
}

printf '%s\n' "$targets" | while IFS= read -r t; do
  [ -n "$t" ] && inline_one "$t"
done

exit 0
