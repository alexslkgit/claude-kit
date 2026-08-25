#!/usr/bin/env bash
# context-guard.sh — makes the clear-at-200k rule fire by itself.
#
# Why this exists as a hook and not as a line in the output style: the line was there, and
# measured 2026-08-17 across 173 real transcripts it was ignored for a month. 101 sessions ran
# to 200–400k, 14 past 400k, and in the week of 2026-07-13 a single 4 302-request session was
# 61% of that whole week's spend. A threshold that only lives in prose loses to whatever is
# happening at the moment it is crossed. Same conclusion as status-guard.sh reached before it.
#
# What was already there and why it never fired for him: handoff-guard.sh carried a context
# meter, but the whole script exits early when the cwd is not inside a git checkout, so in
# ~/Downloads and any other non-repo directory the meter was dead. That meter now lives here
# instead, with no repo requirement, and handoff-guard keeps only the file mechanics.
#
# The numbers, from TOKEN-AUDIT-2026-08-17.md:
#   RE-MEASURED 2026-08-25 over a full month priced from usage, subagents included for the first
#   time (every earlier number in this file was computed on 58% of the spend):
#     a request costs $0.105 whatever tool it runs — Bash .105, Edit .106, Read .101, simulator .105
#     a fresh session already starts at a 72 641 token floor
#     simulating the month at each threshold: 100k saves 22.0%, 150k saves 22.4%, 200k 17.3%,
#     250k 12.0%, 300k 7.9% — so the old 250k rule left about $500 a month on the table, and
#     below 100k it collapses because the floor makes it thrash
#   150k is the arithmetic optimum but 656 cuts a month is ~21 a day, which he refused as unlivable
#   on 2026-08-25. 200k takes 10.1 of the 13.1 available points at 380 cuts, ~12 a day. That is the
#   rule. The honest comparison is not 250k against 200k: the month ran with 250k nominally in force
#   and came out exactly as the "never" case, so the rule was not being followed at all.
#   a handoff costs ~200k units and breaks even after 11 requests — the median user message
#   is now 9.9 requests at $2.74, so a cut at 150k pays for itself well inside one message
#
# Two bands, and the difference between them matters:
#   220k  soft — do not start anything large, finish what is open. Said once.
#   200k  hard — wrap up at the next boundary and tell him to press /clear. Repeats.
#
# Two events, because one is not enough. UserPromptSubmit catches the start of a turn, but a
# turn is a median of 25 requests and can be 71, so a session can enter at 150k and leave at
# 260k without ever passing through a prompt boundary. PostToolUse therefore checks as well —
# but only announces a band once per session, or ten thousand Bash calls become ten thousand
# reminders. UserPromptSubmit repeats the hard band deliberately: that one is meant to nag.
#
# Never fails a session: always exits 0, and stays silent whenever it cannot measure.

set -uo pipefail

SOFT=180000
HARD=200000
STATE_DIR="$HOME/.claude/context-guard"

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

event="$(field hook_event_name)"; [ -n "$event" ] || event="${1:-UserPromptSubmit}"
tp="$(field transcript_path)"
sid="$(field session_id)"

[ -n "$tp" ] && [ -f "$tp" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

# The transcript records the real token count on every assistant message, so the size of this
# conversation is a number on disk rather than a feeling. input + cache_read + cache_creation of
# the most recent assistant message IS the context that was just re-sent. Only the tail is read;
# these files run to megabytes and this hook is on the hot path of every tool call.
ctx="$(/usr/bin/tail -c 400000 "$tp" 2>/dev/null | python3 -c 'import json,sys
n=0
for l in sys.stdin:
    try: u=(json.loads(l).get("message") or {}).get("usage") or {}
    except Exception: continue
    if u: n=sum(u.get(k,0) for k in ("input_tokens","cache_read_input_tokens","cache_creation_input_tokens"))
print(n)' 2>/dev/null)"
: "${ctx:=0}"
[ "$ctx" -gt 0 ] 2>/dev/null || exit 0

k=$(( ctx / 1000 ))
band=""
[ "$ctx" -ge "$SOFT" ] 2>/dev/null && band="soft"
[ "$ctx" -ge "$HARD" ] 2>/dev/null && band="hard"
[ -n "$band" ] || exit 0

# Cost of carrying on, in the same unit the audit uses, so the number in the message is the
# actual price of the next request rather than an adjective.
per_req=$(( 8 + (13 * k) / 100 ))

# One announcement per band per session on the tool path. The prompt path is allowed to repeat
# the hard band; that is the whole point of it.
if [ "$event" = "PostToolUse" ]; then
  [ -n "$sid" ] || exit 0
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  marker="$STATE_DIR/${sid}.${band}"
  [ -e "$marker" ] && exit 0
  : > "$marker" 2>/dev/null || true
  # Housekeeping: markers are worthless once their session is gone.
  /usr/bin/find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null || true
fi

if [ "$band" = "hard" ]; then
  cat <<EOF
context-guard: this conversation is at ${k}k tokens. Every further request re-sends all of it —
about ${per_req}k units each, against 21k at 150k and 24k in a fresh session. The user's standing
rule, re-measured 2026-08-25, is to stop past 200k at the next natural boundary — a finished
sub-task, never mid-step — run the wrap-up skill so STATUS.md, DECISIONS.md and the board are
current, write the handoff, and then tell him in plain words to press /clear. You cannot clear it
yourself and /compact is the wrong tool: it costs a full-context request and the context regrows
to here within ~20 turns.

The handoff costs about 200k units and breaks even after 11 requests, while his median message is
25, so it pays for itself inside one message of work. The single exception he agreed to: fewer than
~10 requests of work left in the entire task — then finish instead, and say that is why.

He has asked to be told this rather than discover it from the meter. Do not go silent on it, and do
not simply carry on: a session that keeps working past this point is the failure this hook exists
to stop.

Since 2026-08-25 he does not work this ritual by hand any more, so keep your part of it to one
line. handoff-auto.sh writes the handoff by itself when the turn ends, handoff-guard.sh hands the
whole briefing to the next session the moment he clears, and the only thing left that a machine
cannot do is the keystroke. So the entire message he should ever see about this is: handoff
written, press /clear. Never a paragraph, never a list of what you wrote, never a question about
whether he wants it.
EOF
else
  cat <<EOF
context-guard: this conversation is at ${k}k tokens, ~${per_req}k units per request. Past 200k the
standing rule is to wrap up at the next finished sub-task, so finish what is open and do not start
anything large. If something big is genuinely next, hand it over now instead of half-doing it.
Heavy reads, test runs and screenshot loops belong to a subagent from here on — measured, tool
traffic held in the main context is 46% of all spend, and screenshots alone are 13%.
EOF
fi

exit 0
