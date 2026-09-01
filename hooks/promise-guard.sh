#!/usr/bin/env bash
# promise-guard.sh — a ledger of open commitments, so a second dictated task landing on top of
# the first one cannot bury it.
#
# The failure, in his own words. He dictates a task, work starts. He dictates a second task while
# the first is still running. Later he asks about the first one and is told it was never done. It
# has happened more than once and it is the thing he trusts least about this whole kit. His
# instruction: unless he has explicitly cancelled something, it must never be dropped or forgotten.
#
# Why this cannot be fixed with a sentence in CLAUDE.md, and this kit already learned the lesson
# once — see copilot-guard.sh: "a rule that fires once and then depends on goodwill for a hundred
# turns is not a rule." A commitment that lives only in the model's context is lost exactly when
# the context gets long or is cleared, which is precisely when he notices it is gone. So the
# commitment has to live in a file, and a hook has to read it back on the model's behalf — twice:
# once going in, so a new message adds to the pile instead of overwriting it in view, and once
# coming out, so the model cannot go idle while something on the pile is still open.
#
# Three parts:
#   1. LEDGER   ~/.claude/promises/<session-id>.md, one line per commitment, states open/done/
#      dropped. Lines are appended and edited in place, never deleted — the history of what was
#      promised has to survive a state change, not just the open ones.
#   2. UserPromptSubmit  prints the open lines back at the top of every turn a new message can
#      land on top of them. Only when the open set changed since it last printed — see the cost
#      note below.
#   3. Stop  blocks, the way handoff-auto.sh blocks, when the model is about to go idle with open
#      lines older than a minute. Younger than a minute is exempted or the model could never
#      answer a quick question without the hook fighting it.
#
# THE DISCIPLINE THIS DEPENDS ON, stated plainly because a hook can only enforce what was written
# down: the FIRST action on any message that contains a request is to log its asks to the ledger,
# one line per ask, before doing anything else. A dictated message often carries several asks in
# one breath and each one gets its own line. If it is not written down, this hook has nothing to
# read back and nothing to block on — the writing is the part that must never be skipped.
#
# COST. Everything this hook prints becomes a system turn, and a system turn is re-sent with every
# later request of the session until it ends — so it is paid for again and again, not once. That is
# why UserPromptSubmit below keeps a fingerprint of the open set beside the ledger and only prints
# when that fingerprint changes: the previous print is still sitting in the context, still
# readable, and reprinting an unchanged list buys nothing. Do not "improve" this into printing on
# every turn — that turns a one-line-per-change cost into a one-line-per-request cost for the rest
# of the session, which is exactly the kind of leak the rest of this kit's hooks exist to close.
# The Stop half is free in the normal case for the same reason status-guard and handoff-auto are:
# it only ever speaks when it blocks. There is no "all clear" message, on purpose.
#
# Silent whenever it cannot identify a session, never fails a session: always exits 0 except the
# deliberate Stop block.

set -uo pipefail

DIR="$HOME/.claude/promises"

# ---------------------------------------------------------------------------------------------
# CLI mode — how a session (or another hook) writes to the ledger. Batched on purpose: a tool
# call here costs about the same whatever it does, so one call must be able to log several asks
# or resolve several lines at once instead of paying that price per line.
#
#   promise-guard.sh add  <session-id> "<ask>" ["<ask>" ...]
#   promise-guard.sh set  <session-id> <line#>:<open|waiting|done|dropped>[:<reason>] [... more pairs]
#
# WAITING is the fourth state and it exists because the Stop half would otherwise force a lie.
# A line blocked on something outside this session — a CI run, a build, another person — is
# still owed and must not be marked done, but holding the turn hostage to it is pointless: the
# event will not arrive while the model sits there. So waiting keeps the line visible on the way
# in and stops it blocking on the way out. It always carries a reason naming what is being waited
# on, and it goes back to open the moment that thing lands.
#   promise-guard.sh list <session-id>
# ---------------------------------------------------------------------------------------------
cmd="${1:-}"
case "$cmd" in
add|set|list)
  shift
  sid="${1:-}"; shift || true
  if [ -z "$sid" ]; then
    echo "usage: promise-guard.sh $cmd <session-id> ..." >&2
    exit 1
  fi
  mkdir -p "$DIR" 2>/dev/null || true
  ledger="$DIR/${sid}.md"

  case "$cmd" in
  add)
    if [ "$#" -eq 0 ]; then
      echo "usage: promise-guard.sh add <session-id> \"<ask>\" [...]" >&2
      exit 1
    fi
    now="$(date '+%Y-%m-%d %H:%M')"
    logged=0
    for ask in "$@"; do
      [ -n "$ask" ] || continue
      printf -- '- [open] %s \xc2\xb7 %s\n' "$now" "$ask" >> "$ledger"
      logged=$((logged + 1))
    done
    echo "promise-guard: logged ${logged} ask(s) to ${ledger}"
    ;;
  set)
    if [ ! -f "$ledger" ]; then
      echo "promise-guard: no ledger yet for ${sid}" >&2
      exit 1
    fi
    if [ "$#" -eq 0 ]; then
      echo "usage: promise-guard.sh set <session-id> <line#>:<open|waiting|done|dropped>[:<reason>] [...]" >&2
      exit 1
    fi
    python3 - "$ledger" "$@" <<'PY'
import sys, re
ledger = sys.argv[1]
changes = {}
for spec in sys.argv[2:]:
    parts = spec.split(":", 2)
    if len(parts) < 2:
        continue
    try:
        idx = int(parts[0])
    except ValueError:
        continue
    state = parts[1].strip()
    if state not in ("open", "waiting", "done", "dropped"):
        continue
    reason = parts[2].strip() if len(parts) > 2 else ""
    changes[idx] = (state, reason)

with open(ledger) as f:
    lines = f.readlines()

n = 0
updated = 0
out = []
for line in lines:
    if line.startswith("- ["):
        n += 1
        if n in changes:
            state, reason = changes[n]
            m = re.match(r"- \[[a-z]+\]\s*(.*)", line.rstrip("\n"))
            rest = m.group(1) if m else line.rstrip("\n")
            rest = re.sub(r"\s+\u2014 reason:.*$", "", rest)  # drop any prior dropped-reason suffix
            if state == "dropped":
                rest = f"{rest} \u2014 reason: {reason or 'no reason given'}"
            line = f"- [{state}] {rest}\n"
            updated += 1
    out.append(line)

with open(ledger, "w") as f:
    f.writelines(out)
print(f"promise-guard: updated {updated} line(s) in {ledger}")
PY
    ;;
  list)
    if [ -f "$ledger" ]; then cat "$ledger"; else echo "promise-guard: no ledger for ${sid}"; fi
    ;;
  esac
  exit 0
  ;;
esac

# ---------------------------------------------------------------------------------------------
# Hook mode — invoked by Claude Code with the event payload on stdin, no arguments.
# ---------------------------------------------------------------------------------------------
command -v python3 >/dev/null 2>&1 || exit 0
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

read -r event sid <<<"$(printf '%s' "$payload" | python3 -c '
import json, sys
try: d = json.load(sys.stdin)
except Exception: d = {}
print(d.get("hook_event_name") or "", d.get("session_id") or "")' 2>/dev/null)"
[ -n "${sid:-}" ] || exit 0

mkdir -p "$DIR" 2>/dev/null || true
ledger="$DIR/${sid}.md"
fp_file="$DIR/${sid}.fp"

case "$event" in
UserPromptSubmit)
  if [ ! -f "$ledger" ]; then
    # Nag exactly once per session — the fingerprint file doubles as "already nagged". After
    # this, the discipline comment at the top of this file is the model's only reminder: the
    # hook cannot tell a quiet session apart from one that simply never wrote its asks down.
    [ -f "$fp_file" ] && exit 0
    printf 'MISSING' > "$fp_file" 2>/dev/null || true
    echo "promise-guard: no ledger yet for this session — log this turn's asks before starting work."
    exit 0
  fi

  out="$(python3 - "$ledger" "$fp_file" <<'PY'
import hashlib, os, sys
ledger, fp_file = sys.argv[1], sys.argv[2]
with open(ledger) as f:
    lines = [l.rstrip("\n") for l in f
             if l.startswith("- [open]") or l.startswith("- [waiting]")]
if not lines:
    # Silent: an empty open set costs nothing, whether the ledger is new or fully drained.
    sys.exit(0)

fp = hashlib.sha1("\n".join(lines).encode("utf-8", "replace")).hexdigest()
prev = ""
if os.path.exists(fp_file):
    with open(fp_file) as f:
        prev = f.read().strip()
if fp == prev:
    sys.exit(0)  # open set unchanged since the last print — already in view, say nothing

with open(fp_file, "w") as f:
    f.write(fp)

def label(line):
    # "- [open] 2026-09-01 15:12 \u00b7 <ask>" -> "<ask>", capped short.
    ask = line.split("\u00b7", 1)[-1].strip() if "\u00b7" in line else line
    ask = (ask[:40] + "\u2026") if len(ask) > 40 else ask
    return ("~" + ask) if line.startswith("- [waiting]") else ask

shown = lines[:5]
tail = f" ({len(shown)} oldest)" if len(lines) > 5 else ""
print(f"promise-guard: {len(lines)} open{tail}, adds not replaces \u2014 " + "; ".join(label(l) for l in shown))
PY
)"
  [ -n "$out" ] && echo "$out"
  exit 0
  ;;

Stop)
  [ -f "$ledger" ] || exit 0
  out="$(python3 - "$ledger" <<'PY'
import re, sys, time

ledger = sys.argv[1]
with open(ledger) as f:
    lines = [l.rstrip("\n") for l in f if l.startswith("- [open]")]
if not lines:
    sys.exit(0)

now = time.time()
stale = []
for line in lines:
    m = re.match(r"- \[open\] (\d{4}-\d{2}-\d{2} \d{2}:\d{2})", line)
    age = None
    if m:
        try:
            t = time.strptime(m.group(1), "%Y-%m-%d %H:%M")
            age = now - time.mktime(t)
        except Exception:
            age = None
    # Unparseable timestamp: treat as old rather than silently letting it escape the block.
    if age is None or age >= 60:
        stale.append(line)

if not stale:
    sys.exit(0)  # everything open was logged inside this last minute — let a quick reply through

items = "\n".join(f"  {l}" for l in lines)
reason = (
    "promise-guard: this session is about to go idle with %d open commitment(s) still on the "
    "ledger. Going idle with an open commitment is the exact failure this hook exists to stop — "
    "a second task landing on top of the first is not a cancellation of the first.\n\n"
    "%s\n\n"
    "Each line has to leave this turn resolved: finished, marked done, marked waiting on something "
    "outside this session, or marked dropped with a reason he can read — never silently left open. "
    "Waiting is for a line blocked on a CI run, a build or another person: it stays owed and stays "
    "visible, it just stops holding the turn. Use:\n"
    "  promise-guard.sh set %%SID%% <line#>:done\n"
    "  promise-guard.sh set %%SID%% <line#>:waiting:<what is being waited on>\n"
    "  promise-guard.sh set %%SID%% <line#>:dropped:<reason>\n"
    "This hook can only enforce what was written to the ledger; it has no way to know about a "
    "request that was never logged, so treat any gap you notice here as a bug in this turn, not "
    "in the hook."
) % (len(stale), items)
print(reason)
PY
)"
  if [ -n "$out" ]; then
    sid_esc="$sid"
    out="${out//%SID%/$sid_esc}"
    python3 - "$out" <<'PY'
import json, sys
print(json.dumps({"decision": "block", "reason": sys.argv[1]}))
PY
  fi
  exit 0
  ;;
esac

exit 0
