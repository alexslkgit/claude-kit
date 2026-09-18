#!/usr/bin/env bash
# edits-guard.sh — a draft he rewrote on the messages page reaches the next session by itself.
#
# Why it exists. The messages page stores his rewrite of a card in ~/Tasks/messages/edits.jsonl
# (tasks-server.py, POST /messages/edit), and the draft-message skill says to read that file
# before the next draft. Until 2026-09-18 nothing else read it: the session that wrote the draft
# never learned it had been rewritten, and the rule was only derived if a later session happened
# to load the skill and happened to look. He asked, in his own words, whether he has to tell us
# each time, and the honest answer was yes. Same diagnosis as draft-guard and promise-guard: a
# feedback file nobody is made to open is not feedback.
#
# So this runs on UserPromptSubmit and prints every rewrite that has not been acknowledged yet,
# with the instruction that closes it: derive ONE general rule into the kit's style-rules.md,
# push the kit, then acknowledge. The acknowledgement is a line count in a state file, written
# only by the CLI half below, so a rewrite keeps coming back on every turn of every session until
# a session actually turns it into a rule.
#
# CLI:  edits-guard.sh ack            acknowledge every rewrite printed so far
#       edits-guard.sh status         print how many wait
# Hook: no arguments, JSON on stdin, prints to stdout (a system turn) and always exits 0.
set -uo pipefail
EDITS="${HOME}/Tasks/messages/edits.jsonl"
STATE="${HOME}/.claude/state/edits-guard"; mkdir -p "$STATE" 2>/dev/null || exit 0
ACK="${STATE}/acked-lines"
RULES="${HOME}/Developer/claude-kit/skills/draft-message/style-rules.md"

total() { [ -f "$EDITS" ] && grep -c . "$EDITS" 2>/dev/null || echo 0; }
acked() { [ -f "$ACK" ] && cat "$ACK" 2>/dev/null || echo 0; }

case "${1:-}" in
  ack)    total > "$ACK"; echo "edits-guard: acknowledged, $(acked) rewrites on record"; exit 0 ;;
  status) echo "edits-guard: $(( $(total) - $(acked) )) rewrite(s) waiting for a rule"; exit 0 ;;
esac

cat >/dev/null 2>&1 || true   # drain the hook payload, nothing in it is needed
T=$(total); A=$(acked)
[ "$T" -gt "$A" ] || exit 0

python3 - "$EDITS" "$A" "$RULES" <<'PY' 2>/dev/null
import json, sys
path, acked, rules = sys.argv[1], int(sys.argv[2]), sys.argv[3]
rows = [l for l in open(path, encoding="utf-8") if l.strip()][acked:]
print(f"edits-guard: he rewrote {len(rows)} draft(s) on the messages page and no rule was derived yet.")
print("Compare original with edited, and BEFORE any other work write ONE general rule (never his")
print(f"specific correction) into {rules}, in the person's block or the global list, push the kit")
print("with the kit-update skill, then run: ~/.claude/hooks/edits-guard.sh ack")
print("This message repeats on every turn of every session until that ack.")
for l in rows:
    try: d = json.loads(l)
    except Exception: continue
    cut = lambda s: (s or "").replace("\n", " ").strip()[:600]
    print(f"\n- to: {d.get('to','?')}  ({d.get('at','?')}, {d.get('project','?')})")
    print(f"  original: {cut(d.get('original'))}")
    print(f"  edited:   {cut(d.get('edited'))}")
PY
exit 0
