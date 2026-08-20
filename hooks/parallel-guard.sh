#!/usr/bin/env bash
# parallel-guard.sh — tells a session that it is not alone in this checkout, and hands it its own
# id series, so two live sessions cannot overwrite each other's records.
#
# The hole this closes, found 2026-08-20. He forks a session whenever a task splits, and will do it
# hundreds of times. A fork inherits the parent's whole context, including "my decisions are X-nnn
# and my board is STATE.html", and it does NOT get a SessionStart hook, because a fork is not a
# session start. So the fork happily writes the parent's files, the parent rewrites the fork's
# board, and the first handoff written destroys the second. Every rule agreed in chat that day was
# a convention: correct while remembered, gone in a month.
#
# So the split is assigned by machinery instead. Each session touches a registry file on every
# prompt; a session that sees a live neighbour is told, in its own context, which id series is its
# own and which files it must not write. UserPromptSubmit is the event that matters here, because
# it is the only one a forked session actually receives.
#
# Registry: ~/.claude/parallel-sessions/<repo>/<session-id>, content is the assigned letter,
# mtime is last activity. Live means touched within LIVE_MIN minutes. Stale entries are pruned.
#
# Silent when there is exactly one live session, which is almost always. Never fails a session.

set -uo pipefail
LIVE_MIN=90
ROOT="$HOME/.claude/parallel-sessions"

payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

read -r sid cwd <<<"$(printf '%s' "$payload" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print((d.get("session_id") or "x"), (d.get("cwd") or ""))' 2>/dev/null)"
[ -n "${sid:-}" ] && [ "$sid" != "x" ] || exit 0
[ -n "${cwd:-}" ] || cwd="$PWD"

repo=""; dir="$cwd"
for _ in 1 2 3 4 5 6 7 8; do
  [ -d "$dir/.git" ] && { repo="$dir"; break; }
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done
[ -n "$repo" ] || exit 0

reg="$ROOT/$(basename "$repo")"
mkdir -p "$reg" 2>/dev/null || exit 0
/usr/bin/find "$reg" -type f -mmin +$((LIVE_MIN * 4)) -delete 2>/dev/null || true

mine="$reg/$sid"
if [ ! -f "$mine" ]; then
  taken=""
  for f in "$reg"/*; do [ -f "$f" ] && taken="$taken$(/bin/cat "$f" 2>/dev/null)"; done
  letter=""
  for c in X Y Z W V U T S; do
    case "$taken" in *"$c"*) ;; *) letter="$c"; break ;; esac
  done
  [ -n "$letter" ] || letter="R"
  printf '%s' "$letter" > "$mine" 2>/dev/null || exit 0
fi
/usr/bin/touch "$mine" 2>/dev/null || true

live="$(/usr/bin/find "$reg" -type f -mmin -$LIVE_MIN 2>/dev/null)"
n="$(printf '%s\n' "$live" | /usr/bin/grep -c . )"
[ "$n" -gt 1 ] 2>/dev/null || exit 0

letter="$(/bin/cat "$mine" 2>/dev/null)"
others=""
for f in $live; do
  [ "$f" = "$mine" ] && continue
  others="$others $(/bin/cat "$f" 2>/dev/null)"
done

# Announce once per change in the neighbour count, not on every prompt.
mark="$mine.seen$n"
[ -f "$mark" ] && exit 0
rm -f "$mine".seen* 2>/dev/null || true
: > "$mark" 2>/dev/null || true

cat <<EOF
parallel-guard: $n sessions are live in $repo right now, yours and$others. A fork inherits the
parent's context, so without this you would both believe you own the same files.

**Your decision id series is \`$letter-nnn\`.** Use it for every new entry in DECISIONS.md, append
with \`cat >>\`, never rewrite that file. The other series belong to the other sessions.

The rest of the division, so nothing is lost:
  · STATUS.md stays one file. Edit only the section for your task, surgically. Never a whole-file
    rewrite, that is what destroys the other session's work.
  · One board per task at .claude/tasks/<task>.html. Never write a board you did not create.
  · One handoff per task at .claude/handoffs/<task-slug>.md, never a shared name.
  · Write the ownership split into .claude/tasks/COORDINATION.md and send the peer a pointer to
    that file, not a briefing. Read it first if it already exists.

A peer claiming a piece of work is accepted, not escalated to him. Honouring a claim costs nothing;
two sessions clicking the same button is the expensive outcome.
EOF
exit 0
