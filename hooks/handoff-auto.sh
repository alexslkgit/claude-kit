#!/usr/bin/env bash
# handoff-auto.sh — writes the handoff without him having to ask for it.
#
# The ritual he was doing by hand, roughly three hundred times a day by his own count:
#   1. session says "we are at 250k, I wrote the handoff, press /clear"
#   2. he presses /clear
#   3. he types "pick up the handoff"
#
# Step 2 is the only one a machine cannot do. Verified 2026-08-25: no hook can trigger /clear or
# /compact, and there is no supported way for any process to type into a running interactive
# session. So this hook takes step 1, and handoff-guard.sh takes step 3.
#
# How step 1 is taken: a Stop hook fires when the assistant is about to go idle, which is exactly
# the natural boundary the rule asks to stop at. Over the threshold it answers `decision: block`,
# which hands the turn back to the model with a reason instead of ending it. The model then writes
# the handoff and says one short line. He reads one line and presses one key.
#
# Loop safety, and it matters because a Stop hook that keeps blocking will spin:
#   · exits immediately when `stop_hook_active` is true, so a block can never chain
#   · fires at most once per session, tracked by a marker file per session id
#   · silent whenever it cannot measure the context
#   · always exits 0
#
# Never remove the marker check. Claude Code caps consecutive Stop blocks at 8, but a hook that
# relies on that cap is a hook that wastes eight turns.

set -uo pipefail

HARD=200000  # matches context-guard.sh; the two must never disagree
STATE_DIR="$HOME/.claude/context-guard"

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

# Already inside a block from this same hook: never chain.
printf '%s' "$payload" | grep -q '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

tp="$(field transcript_path)"
sid="$(field session_id)"
[ -n "$tp" ] && [ -f "$tp" ] || exit 0
[ -n "$sid" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null || true
marker="$STATE_DIR/${sid}.autohandoff"
[ -e "$marker" ] && exit 0

# Same measurement as context-guard: input + cache_read + cache_creation of the last assistant
# message is the context that was just re-sent. Only the tail is read; these files are megabytes.
ctx="$(/usr/bin/tail -c 400000 "$tp" 2>/dev/null | python3 -c 'import json,sys
n=0
for l in sys.stdin:
    try: u=(json.loads(l).get("message") or {}).get("usage") or {}
    except Exception: continue
    if u: n=sum(u.get(k,0) for k in ("input_tokens","cache_read_input_tokens","cache_creation_input_tokens"))
print(n)' 2>/dev/null)"
: "${ctx:=0}"
[ "$ctx" -gt 0 ] 2>/dev/null || exit 0
# Under the threshold, this hook has one other job: catch the session telling him to press
# /clear when nothing asked for it. Happened 2026-08-31 at 100k in a session twelve requests old,
# because the previous session's closing line was still in view and got echoed. A clear costs him
# the whole conversation, so the sentence may only appear when the meter actually says so.
if [ "$ctx" -lt "$HARD" ] 2>/dev/null; then
  last="$(/usr/bin/tail -c 200000 "$tp" 2>/dev/null | python3 -c 'import json,sys
t=""
for l in sys.stdin:
    try: d=json.loads(l)
    except Exception: continue
    if d.get("type")!="assistant": continue
    for c in (d.get("message") or {}).get("content") or []:
        if isinstance(c,dict) and c.get("type")=="text": t=c.get("text","")
print(t)' 2>/dev/null)"
  case "$last" in
    */clear*|*"клир"*|*"Клир"*)
      : > "$marker" 2>/dev/null || true
      k=$(( ctx / 1000 ))
      python3 - "$k" <<'PY2'
import json, sys
k = sys.argv[1]
print(json.dumps({"decision":"block","reason":(
 "clear-guard: you just told him to press /clear, and the context is %sk. The rule is 200k. "
 "Under it a clear throws away a working conversation for nothing, and he reads the sentence as "
 "you not knowing where you are.\n\n"
 "Say so plainly in one line: the /clear was wrong, the session is at %sk, carry on. Do not "
 "explain the hook, do not apologise at length, do not restate what you were doing."
) % (k, k)}))
PY2
      exit 0;;
  esac
fi

[ "$ctx" -ge "$HARD" ] 2>/dev/null || exit 0

: > "$marker" 2>/dev/null || true
k=$(( ctx / 1000 ))

python3 - "$k" <<'PY'
import json, sys
k = sys.argv[1]
reason = (
  "handoff-auto: this conversation is at %sk tokens and you are about to go idle, which is the "
  "natural boundary the rule asks for. Do the whole handoff now, without asking him anything and "
  "without offering it as a choice.\n\n"
  "1. Bring the task's files up to date first: STATUS.md rewritten, DECISIONS.md appended, the "
  "board rewritten to its current state. A handoff that only writes a prompt is incomplete.\n"
  "2. Write the continuation briefing to the task's own handoff file, the path handoff-guard "
  "names at session start. One handoff per task, never a shared one.\n"
  "3. Then say exactly one line to him, the board link first as always, and the words: handoff "
  "written, press /clear. Nothing else. Do not explain the ritual, do not list what you wrote, "
  "and do not ask whether he wants it.\n\n"
  "He does not have to type anything after the clear: the next session is handed the briefing "
  "automatically. This fires once per session, so if the handoff is already written and current, "
  "say the one line and stop."
) % k
print(json.dumps({"decision": "block", "reason": reason}))
PY
exit 0
