#!/usr/bin/env bash
# browser-guard.sh — makes the browser round trip, not the pixel, the thing that gets counted.
#
# The measurement this exists for (2026-08-25, 1802 transcripts since 4 August, 138 sessions
# that touched a browser): 8 700 browser tool calls, of which exactly 420 — five percent — went
# through browser_batch. The other 95% were one call per request, and a request re-sends the
# whole context. A twelve-step sign-in at a 150k context costs 1.8M re-sent tokens step by step
# and 150k as one batch.
#
# bulk-guard already caps the pictures. This one caps the round trips, and it only counts the
# calls that are genuinely predictable two steps ahead:
#
#   click, type, key, navigate, form_input, scroll   — batchable, counted
#   read_page, get_page_text, javascript_tool, find  — you have to look before the next move,
#                                                      never counted, and named as the cheap way
#                                                      to look (260 tokens against a screenshot's
#                                                      1 600)
#
# It nudges once per run of four and then resets, so a flow that genuinely cannot be predicted
# loses one call and continues. It can never deadlock a session.
#
# Escape hatch, same shape as bulk-guard:
#   touch ~/.claude/browser-guard/$CLAUDE_SESSION_ID.bypass
#
# PreToolUse contract: exit 2 blocks and feeds stderr to the model; anything else lets it through.
# Every unexpected condition exits 0 — this must never be the reason a session cannot work.

set -uo pipefail

RUN_LIMIT=4                       # single predictable calls in a row before one nudge
STATE_DIR="$HOME/.claude/browser-guard"

payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

IFS=$'\t' read -r tool sid action <<<"$(printf '%s' "$payload" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("x\tx\tx"); raise SystemExit
ti=d.get("tool_input") or {}
print("\t".join([str(d.get("tool_name") or "x"), str(d.get("session_id") or "x"), str(ti.get("action") or "x")]))
' 2>/dev/null)"

[ "$sid" = "x" ] && exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
[ -f "$STATE_DIR/$sid.bypass" ] && exit 0
counter="$STATE_DIR/$sid.run"

case "$tool" in
  *browser_batch|*computer_batch)
    # a batch is the behaviour being asked for — the run starts over
    : > "$counter" 2>/dev/null; exit 0 ;;
  *__computer|*__navigate|*__form_input|*__file_upload)
    case "$action" in
      screenshot|zoom|read*) exit 0 ;;   # looking, not acting — bulk-guard owns the pictures
    esac ;;
  *) exit 0 ;;
esac

n=$(( $(cat "$counter" 2>/dev/null || echo 0) + 1 ))
printf '%s' "$n" > "$counter" 2>/dev/null
[ "$n" -lt "$RUN_LIMIT" ] && exit 0
: > "$counter" 2>/dev/null    # nudge once, then let the flow continue

cat >&2 <<'MSG'
browser-guard: that is the fourth single browser action in a row. Send them as one browser_batch.

Each separate call is its own request, and a request re-sends the whole context. Four steps at a
150k context is 600k re-sent tokens; the same four inside one browser_batch is 150k. Measured
2026-08-25: 8 700 browser calls in three weeks, 420 of them batched.

  browser_batch: [ {name:"navigate", input:{url}}, {name:"computer", input:{action:"left_click", ref}},
                   {name:"computer", input:{action:"type", text}}, {name:"computer", input:{action:"key", text:"Return"}} ]

If you cannot predict the next step because you have to see the page first, look with
javascript_tool — a one-line expression that returns exactly the field you need costs about 260
tokens, against 1 600 for a screenshot that then rides along in the context for the rest of the
session:

  javascript_tool: ({ url: location.pathname, rows: document.querySelectorAll('tbody tr').length,
                      files: [...document.querySelectorAll('a[href$=".pdf"]')].map(a => a.href) })

And if this whole flow is many steps long, it does not belong in the main conversation at all —
hand it to browser-scout-sonnet with the goal, and let it come back with five lines.

This is one nudge per run of four; the same call will pass if you send it again.
MSG
exit 2
