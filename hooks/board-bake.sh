#!/bin/bash
# board-bake.sh — make every board and plan page actually visible, on every Mac, in every session.
#
# Two failures this ends, both measured 2026-08-28 in the Claude Code side panel:
#
#  1. The panel opens a local file as a static data: snapshot with JavaScript DISABLED. A board's
#     <body> is empty until board.js runs, so the panel showed a correct <title> over a blank white
#     page. Every board, every machine. Baking the rendered markup into the file fixes it, and the
#     JSON block stays the source of truth so nothing about how boards are written changes.
#  2. A page-writer invented a "cards" key where the renderer wants "tasks". The board then renders
#     blank in a real browser too, silently. Running the renderer here turns that into a loud error
#     at write time instead of a page he opens and finds empty.
#
# The heavy lifting is in tools/prerender-page.py. This only decides what to hand it.

TOOL="${HOME}/.claude/tools/prerender-page.py"
[ -f "$TOOL" ] || exit 0

INPUT=$(cat)

FILE=$(printf '%s' "$INPUT" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
p = (d.get("tool_input") or {}).get("file_path") or ""
print(p if p.endswith(".html") else "")
' 2>/dev/null)

if [ -n "$FILE" ]; then
    [ -f "$FILE" ] || exit 0
    OUT=$(python3 "$TOOL" "$FILE" 2>&1)
else
    # No single file in hand: sweep the task pages of this project. Unchanged pages are skipped
    # on a hash, so this costs almost nothing on a turn that touched no board.
    DIRS=$(ls -d ./.claude/tasks 2>/dev/null)
    [ -n "$DIRS" ] || exit 0
    OUT=$(python3 "$TOOL" $DIRS/*.html 2>&1)
fi

printf '%s' "$OUT" | grep -q "FAIL\|renderer produced nothing" || exit 0

cat >&2 <<MSG
board-bake: a board or plan page did not render, so it will open BLANK for him.

$OUT

Almost always the JSON does not match the renderer. The board schema is
{ "title", "sub", "stamp", "tasks": [ { "t", "state": "done|live|todo", "open", "items": [...] } ],
  "you": {...}, "now", "decided": [...], "stampNote" }.
There is no "cards" key. Items carry "state": "done|todo|wait|here".
Copy the skeleton from ~/.claude/templates/board.html and re-read ~/.claude/skills/board/SKILL.md.
Fix the JSON and write the page again.
MSG
exit 2
