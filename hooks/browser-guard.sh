#!/usr/bin/env bash
# browser-guard.sh — makes the browser ROUND TRIP the thing that gets counted, not the pixel.
#
# Measured 2026-08-25 over 1802 transcripts, three weeks, 121 612 requests:
#
#   browser work caused 10 772 requests — 9% of all — costing 6.7% of everything
#   the average context re-sent under ONE browser click was 131k
#   a session that touched a browser: median 103 requests, 108k context, 1.87M weighted units
#   a session that did not:            median  47 requests,  62k context, 0.63M
#
# Three rules, in rising order of what they are worth:
#
#   1. The whole flow belongs in a subagent (~4% of all spend). Under a browser click in a
#      subagent there is 20–30k of context instead of 131k. Non-blocking note at 6, 18 and 40
#      browser calls, because by then the shape of the session is established.
#   2. Batch the predictable actions (~2%). Only 420 of 8 700 calls were batched. One refusal per
#      run of four single actions, then the counter resets, so a flow that genuinely must look
#      between steps loses one call and continues.
#   3. Where a connector exists, do not open a tab at all. One note per service per session.
#
# Screenshots are NOT this hook's business — bulk-guard owns the image budget. Measured, browser
# images are only 19M of the 169M: it is cheap to look and expensive to step.
#
# Escape hatch:  touch ~/.claude/browser-guard/$CLAUDE_SESSION_ID.bypass
#
# PreToolUse contract: exit 2 blocks and feeds stderr back to the model; exit 0 with stdout adds a
# note to the context without blocking anything. Every unexpected condition exits 0 — this must
# never be the reason a session cannot work.

set -uo pipefail

RUN_LIMIT=4                       # single predictable actions in a row before one refusal
STATE_DIR="$HOME/.claude/browser-guard"

payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

IFS=$'\t' read -r tool sid action url <<<"$(printf '%s' "$payload" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("x\tx\tx\tx"); raise SystemExit
ti=d.get("tool_input") or {}
u=ti.get("url") or ""
if not u:
    # browser_batch carries its urls one level down
    try: u=" ".join(str((a.get("input") or {}).get("url") or "") for a in (ti.get("actions") or []))
    except Exception: u=""
print("\t".join([str(d.get("tool_name") or "x"), str(d.get("session_id") or "x"),
                 str(ti.get("action") or "x"), u.replace("\t"," ")[:400]]))
' 2>/dev/null)"

[ -z "${sid:-}" ] || [ "$sid" = "x" ] && exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || exit 0
[ -e "$STATE_DIR/$sid.bypass" ] && exit 0
/usr/bin/find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null || true

bump() { # bump <file> -> echoes the new count
  local f="$STATE_DIR/$1" n=0
  [ -f "$f" ] && n="$(/bin/cat "$f" 2>/dev/null || echo 0)"
  n=$(( n + 1 )); printf '%s' "$n" > "$f" 2>/dev/null || true
  printf '%s' "$n"
}

# --- rule 3: a connector exists for this domain, so the tab should not be opening ---------------
if [ -n "${url:-}" ] && [ "$url" != "x" ]; then
  svc=""; tools=""
  case "$url" in
    *mail.google.com*|*://gmail.com*|*.gmail.com*)
      svc=gmail;    tools="search_threads, get_thread, create_draft, send_message, forward" ;;
    *drive.google.com*|*docs.google.com*|*sheets.google.com*)
      svc=drive;    tools="search_files, read_file_content, download_file_content, create_file, update_file" ;;
    *calendar.google.com*)
      svc=calendar; tools="list_events, search_events, create_event, update_event, suggest_time" ;;
    *www.figma.com/design*|*www.figma.com/file*)
      svc=figma;    tools="get_design_context, get_screenshot, get_metadata, get_variable_defs" ;;
  esac
  if [ -n "$svc" ] && [ ! -e "$STATE_DIR/$sid.said-$svc" ]; then
    : > "$STATE_DIR/$sid.said-$svc" 2>/dev/null || true
    cat <<EOF
browser-guard: that URL is $svc, and $svc is connected here as an MCP server — find it with
ToolSearch and call it directly ($tools). The API path costs a few hundred tokens and no
sign-in; the same job through the browser is a sign-in, a wait, several clicks and usually a
screenshot, each one its own request re-sending the whole context. Measured: the average context
re-sent under a single browser call in this corpus is 131k.

Open the tab only for something the connector genuinely cannot do, and say in one line what that is.
EOF
  fi
fi

# --- rule 1 + rule 2 counters -------------------------------------------------------------------
kind=other
case "$tool" in
  *browser_batch|*computer_batch)
    : > "$STATE_DIR/$sid.run" 2>/dev/null || true ;;    # a batch is the behaviour asked for
  *__computer|*__navigate|*__form_input|*__file_upload)
    case "$action" in
      screenshot|zoom) ;;                                # looking: bulk-guard owns the pictures
      *) kind=act ;;
    esac ;;
esac

total="$(bump "$sid.total")"

# --- rule 1: the whole flow belongs in a subagent ------------------------------------------------
case "$total" in
  6|18|40)
    cat <<EOF
browser-guard: that is browser call #$total in this conversation, so this is a flow and not a
glance. A flow belongs to browser-scout-sonnet — browser-scout-opus when the answer has to be
worked out rather than looked up.

Why this is the biggest single lever, measured 2026-08-25 over 121 612 requests: browser work
caused 9% of all requests and 6.7% of all spend, and it costs that much because the average
context re-sent under one browser click here is 131k. In a subagent the same click sits on 20–30k,
because its context holds this task and nothing else. That difference is about 4% of everything.

Hand over the GOAL, end to end, not the clicks: "sign in, download the three invoices for August,
rename them <date>-<vendor>.pdf into ~/Downloads, report one line each". Let it look as much as it
needs; its screenshots die with it. Ask for words back.

Keep it here only if the flow needs something a subagent cannot have — a decision that is the
user's, or an approval — and then keep only that part here.
EOF
    ;;
esac

[ "$kind" = act ] || exit 0
n="$(bump "$sid.run")"
[ "$n" -lt "$RUN_LIMIT" ] 2>/dev/null && exit 0
: > "$STATE_DIR/$sid.run" 2>/dev/null || true    # one refusal per run, then let the flow continue

cat >&2 <<'MSG'
browser-guard: that is the fourth single browser action in a row. Send them as one browser_batch.

Each separate call is its own request, and a request re-sends the whole context. Four steps at a
150k context is 600k re-sent tokens; the same four inside one browser_batch is 150k. Measured
2026-08-25: 8 700 browser calls in three weeks, 420 of them batched — five percent.

  browser_batch: [ {name:"navigate", input:{url}}, {name:"computer", input:{action:"left_click", ref}},
                   {name:"computer", input:{action:"type", text}}, {name:"computer", input:{action:"key", text:"Return"}} ]

If you cannot predict the next step because you have to see the page first, look with
javascript_tool — a one-line expression returning exactly the field you need is ~260 tokens against
1 600 for a screenshot that then rides along for the rest of the session:

  javascript_tool: ({ url: location.pathname, rows: document.querySelectorAll('tbody tr').length,
                      files: [...document.querySelectorAll('a[href$=".pdf"]')].map(a => a.href) })

And if this flow is many steps long it does not belong in this conversation at all — hand it to
browser-scout-sonnet with the goal and let it come back with five lines.

This is one refusal per run of four; the same call passes if you send it again.
MSG
exit 2
