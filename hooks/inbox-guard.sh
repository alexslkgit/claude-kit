#!/usr/bin/env bash
# inbox-guard.sh — keeps the owner's one queue alive and tells every session it exists.
#
# The rule it serves lives in the output style ("What reaches him goes in the queue, not into the
# chat"): the two things that may reach him, a click he alone can make and approval for an
# outward action, are written to ~/.claude/inbox instead of into a conversation. Every session on
# this machine writes to the same queue, he answers all of them on one page, and with --wait the
# click comes back to the waiting session instead of stopping at the screen.
#
# It is a hook and not prose for the reason already written down for copilot-guard: a rule that
# fires once at turn zero and then depends on goodwill is not a rule. It has two jobs.
#
#   1. The page has to be up, or the rule is inert. The LaunchAgent starts it at login; this is
#      the belt for the machine where install.sh has not run yet, or where the agent was booted
#      out by hand. Starting it costs nothing and needs no click from him.
#   2. State the command, and state what is already waiting, so a session does not queue a second
#      copy of a question that is sitting on the page unanswered.
#
# SessionStart prints the rule. UserPromptSubmit is silent unless the server has died mid-session
# or something is pending, because a line repeated every turn is a line nobody reads.

set -uo pipefail

IN="$HOME/.claude/inbox"
PORT=7654
SRV="$IN/server.mjs"
EVENT="${CLAUDE_HOOK_EVENT:-}"
[ -n "$EVENT" ] || EVENT="$(printf '%s' "${1:-}" | tr -d '[:space:]')"

# The hook payload arrives on stdin; hook_event_name is the only field needed here. No `timeout`
# here: it is GNU coreutils and absent on stock macOS, which silently emptied this variable and
# made every event look like SessionStart.
if [ -z "$EVENT" ] && command -v python3 >/dev/null 2>&1; then
  EVENT="$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hook_event_name",""))
except Exception: print("")' 2>/dev/null)"
fi

up() { curl -s -m 1 -o /dev/null "http://127.0.0.1:${PORT}/" 2>/dev/null; }

started=""
if ! up; then
  if [ -f "$SRV" ] && command -v node >/dev/null 2>&1; then
    # Detached, so it outlives this hook and this session. KeepAlive belongs to launchd; this is
    # only the fallback for a machine where the agent is not loaded.
    nohup node "$SRV" >>"$IN/server.log" 2>&1 &
    disown 2>/dev/null || true
    for _ in 1 2 3 4 5 6; do up && { started="yes"; break; }; sleep 0.3; done
  fi
fi

pending=0
[ -d "$IN/queue" ] && pending=$(find "$IN/queue" -maxdepth 1 -name '*.json' 2>/dev/null | wc -l | tr -d ' ')

if [ "$EVENT" = "UserPromptSubmit" ]; then
  # Silent in the normal case. Only speak when the state changed under the session's feet.
  if ! up; then
    echo "inbox-guard: the owner's queue at http://localhost:${PORT} is DOWN and could not be started."
    echo "Anything that needs his click has nowhere to go: say so in the message instead of queueing it."
  fi
  exit 0
fi

if ! up; then
  echo "inbox-guard: the owner's queue (http://localhost:${PORT}) is down and would not start."
  echo "Fix it with: cd ~/Developer/claude-kit && ./install.sh   (it installs the LaunchAgent)"
  echo "Until then, anything needing his click has to be said in the message."
  exit 0
fi

echo "inbox-guard: the owner answers every session's requests on ONE page, http://localhost:${PORT}."
[ -n "$started" ] && echo "It was not running; this hook started it."
echo "Do not put a click, a sign-in or an approval into your own chat and wait there. Queue it:"
echo "  ~/.claude/inbox/ask.sh --title \"...\" --why \"one line\" --options \"Да|Нет\" [--open \"<url>\"]"
echo "Add --wait and the call BLOCKS until he clicks, then prints his answer on stdout, so the"
echo "session continues by itself. That is the point: the click returns to the waiting session."
echo "This does not widen what may reach him. It is delivery for the two categories the output"
echo "style already allows, and nothing else."
if [ "$pending" -gt 0 ]; then
  echo "Waiting on him right now: ${pending}. Read them before you queue another, they may be yours:"
  ls -1 "$IN/queue"/*.json 2>/dev/null | head -8 | while IFS= read -r f; do
    python3 -c 'import json,sys
r=json.load(open(sys.argv[1]))
print("  ["+r.get("project","?")+"] "+r.get("title","?"))' "$f" 2>/dev/null
  done
fi
