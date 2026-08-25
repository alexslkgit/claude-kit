#!/usr/bin/env bash
# bulk-guard.sh — keeps bulk out of the main conversation by refusing it at the call site.
#
# The measurement this exists for (TOKEN-AUDIT-2026-08-17.md, 173 sessions, 37k requests):
# tool traffic held in main contexts — what was sent plus what came back — is 46% of all token
# spend, because every one of those tokens is re-sent on every later request of the session.
# Ranked by that carried cost:
#
#   screenshots  13%   1 600 images at ~1 600 tokens each
#   Bash         13%   9 819 calls, nothing big, purely count
#   Agent         5%   briefs out and reports back — the cost of delegating, and worth it
#   Read          5%   median 1 431 tokens per call, worst 13 925
#   Write         4%   median 2 590 tokens of file body, a board 8–10k
#
# The output style already asked for all of this in prose. Measured over a month, the prose lost:
# 1 600 screenshots and 986 Write calls happened anyway. So the three biggest items become a
# refusal at the moment of the call, with the alternative named in the refusal — the same shape
# that finally made the status files and the handoff path stick.
#
# What it does NOT do: block anything the user is watching for. Two images per session pass
# freely, because "show me what that screen looks like" is a real request and it is usually one
# picture. Past that, the screenshot loop belongs to a subagent whose context is thrown away.
#
# Escape hatch, for when the orchestrator has a reason the hook cannot see — the user asked to be
# shown a series, or a page is genuinely mid-flow and a subagent cannot pick it up:
#
#   touch ~/.claude/bulk-guard/$CLAUDE_SESSION_ID.bypass
#
# One line of Bash, deliberately cheap, deliberately visible in the transcript so a session that
# bypasses this has to have said why.
#
# PreToolUse contract: exit 2 blocks the call and feeds stderr back to the model. Any other exit
# code lets the call through. This script therefore exits 0 on every unexpected condition — it must
# never be the reason a session cannot work.

set -uo pipefail

IMAGE_BUDGET=2          # free screenshots per session in the main conversation
READ_LINES=1200         # a Read with no offset/limit above this is a whole-file dump
WRITE_CHARS=12000       # ~3k tokens of file body; a board or a plan page, not a config edit
STATE_DIR="$HOME/.claude/bulk-guard"

payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

# Tab-separated, and the path is read with IFS set: a file path with a space in it must not shift
# every field after it. Any parse failure yields values that make every branch fall through.
IFS=$'\t' read -r tool sid action clen offlim fpath <<<"$(printf '%s' "$payload" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("x\tx\tx\t0\t1\tx"); raise SystemExit
ti=d.get("tool_input") or {}
print("\t".join([
    str(d.get("tool_name") or "x"),
    str(d.get("session_id") or "x"),
    str(ti.get("action") or "x"),
    str(len(str(ti.get("content") or ""))),
    "1" if (ti.get("offset") or ti.get("limit") or ti.get("pages")) else "0",
    str(ti.get("file_path") or "x"),
]))' 2>/dev/null)"
[ -n "${tool:-}" ] && [ "$tool" != "x" ] || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null || true
[ -e "$STATE_DIR/$sid.bypass" ] && exit 0
/usr/bin/find "$STATE_DIR" -type f -mtime +7 -delete 2>/dev/null || true

case "$tool" in

  # --- screenshots: 13% of everything ---------------------------------------------------------
  mcp__claude-in-chrome__computer|mcp__Claude_Browser__computer|mcp__computer-use__screenshot|\
  mcp__computer-use__zoom|mcp__Claude_Code_iOS_Simulator__control|\
  mcp__claude-in-chrome__browser_batch|mcp__computer-use__computer_batch)
    # Only the calls that actually return an image. A tap, a scroll or a keypress costs ~20 tokens
    # and is none of this hook's business.
    # action=x means the payload has no action field at all — mcp__computer-use__screenshot and the
    # two batch tools, all of which do return images. Everything else with an action that is not a
    # screenshot is a tap, a scroll or a keypress: ~20 tokens, not this hook's business.
    case "$action" in
      screenshot|zoom|x) ;;
      *) exit 0 ;;
    esac

    counter="$STATE_DIR/$sid.images"
    n=0; [ -f "$counter" ] && n="$(/bin/cat "$counter" 2>/dev/null || echo 0)"
    n=$(( n + 1 )); printf '%s' "$n" > "$counter" 2>/dev/null || true
    [ "$n" -le "$IMAGE_BUDGET" ] 2>/dev/null && exit 0

    case "$tool" in
      mcp__Claude_Code_iOS_Simulator__*) agent="sim-verifier-sonnet" ;;
      *) agent="browser-scout-sonnet (browser-scout-opus when the answer has to be worked out)" ;;
    esac
    cat >&2 <<EOF
bulk-guard: that is screenshot #$n in this conversation, and the free budget is $IMAGE_BUDGET.
Blocked, because an image is ~1 600 tokens and is re-sent on every later request of this session —
measured over 173 sessions, screenshots in main contexts were 13% of all token spend, the single
largest identifiable leak.

Do it in a subagent instead: $agent. Launch it with the goal, not the clicks
("check the paywall renders correctly in light and dark and report what is on each screen"), and let
it take as many screenshots as it needs — they die with its context. Ask it for words back.

If the user needs to SEE something:
  · a simulator screen — the agent writes a PNG with
    'xcrun simctl io booted screenshot <path>' and returns the path; send that with SendUserFile,
    and the image never enters any conversation
  · a web page — open the tab in his browser and let him look. That costs nothing.

If you genuinely need eyes in this conversation — he asked to be shown a series, or a page is
mid-flow and a subagent cannot pick it up — say so to him in one line, then:
  touch $STATE_DIR/$sid.bypass
EOF
    exit 2
    ;;

  # --- Bash: 42% of the limit, and the teeth are on the run, not on the call ------------------
  # Re-measured 2026-08-25 over the full month with subagents included: 37 286 calls at a median
  # of 325 characters, $3 425, the largest single line in the audit. No individual call is worth
  # blocking and none is large; the cost is that there are thirty-seven thousand of them, each
  # one a request, each request re-sending the whole context underneath it.
  #
  # The only lever is batching, and until 2026-08-25 this hook only mentioned it three times a
  # session and blocked nothing, which measurably changed nothing. What it refuses now is exactly
  # the pattern that is provably wasteful and never load-bearing: a fourth read-only one-liner in
  # an unbroken run of them — ls, then cat, then grep, then wc — where every one of those could
  # have travelled in a single call. It is the same shape browser-guard already uses on unbatched
  # clicks, and it resets on the refusal, so a flow that genuinely has to look between steps can
  # never deadlock: the next call always goes through.
  Bash)
    counter="$STATE_DIR/$sid.bash"
    n=0; [ -f "$counter" ] && n="$(/bin/cat "$counter" 2>/dev/null || echo 0)"
    n=$(( n + 1 )); printf '%s' "$n" > "$counter" 2>/dev/null || true

    simple="$(printf '%s' "$payload" | python3 -c '
import json, re, sys
try: d = json.load(sys.stdin)
except Exception: print("0"); raise SystemExit
c = str((d.get("tool_input") or {}).get("command") or "")
# Anything already carrying more than one command is the behaviour being asked for.
if re.search(r"&&|\|\||;|\n|\|", c) or len(c) > 400: print("0"); raise SystemExit
# Read-only verbs only. A single mutating command is never refused.
print("1" if re.match(r"\s*(ls|cat|head|tail|wc|pwd|echo|file|stat|du|which|type|"
                      r"grep|rg|find|glob|sed -n|awk|jq|"
                      r"git (status|log|show|diff|branch|remote))\b", c) else "0")
' 2>/dev/null)"

    runf="$STATE_DIR/$sid.bashrun"
    if [ "$simple" = "1" ]; then
      r=0; [ -f "$runf" ] && r="$(/bin/cat "$runf" 2>/dev/null || echo 0)"
      r=$(( r + 1 )); printf '%s' "$r" > "$runf" 2>/dev/null || true
    else
      printf '0' > "$runf" 2>/dev/null || true; r=0
    fi

    if [ "$r" -ge 4 ] 2>/dev/null; then
      printf '0' > "$runf" 2>/dev/null || true
      cat >&2 <<EOF
bulk-guard refused this Bash call: it is the fourth read-only one-liner in a row.

Four calls are four requests, and a request costs the whole context sitting under it — 10.5 cents
flat, whatever the command was. Measured over the month to 2026-08-25, Bash is 37 286 calls and
42% of the limit at a median of 325 characters a call. Nothing in that number is size; all of it
is count.

The same four commands in one call cost one request. Independent lookups go in one heredoc or one
short script, output is trimmed at the source with head, wc or grep rather than printed in full
and read back here, and a long series of greps, builds or test runs belongs to a subagent whose
context is discarded when it finishes.

The run counter is already reset, so the next call goes through whatever it is. This refusal
cannot repeat until another four read-only one-liners have gone by.
EOF
      exit 2
    fi

    case "$n" in
      60|180|360) ;;
      *) exit 0 ;;
    esac
    cat <<EOF
bulk-guard: that is Bash call #$n in this conversation. Measured over the month to 2026-08-25,
Bash was 37 286 calls and 42% of the whole limit, and not one call was large — the median is 325
characters. Each is a request, and each request re-sends the entire context underneath it. The
only fix is fewer, bigger calls: independent commands in one call, related ones in one script,
output trimmed at the source. If what is coming is a long series of greps, builds or test runs,
that whole series belongs to a subagent whose context is thrown away.
EOF
    exit 0
    ;;

  # --- Read: 5% -------------------------------------------------------------------------------
  Read)
    [ "$offlim" = "1" ] && exit 0
    [ -f "$fpath" ] || exit 0
    lines="$(/usr/bin/wc -l < "$fpath" 2>/dev/null | tr -d ' ')"
    [ -n "$lines" ] || exit 0
    [ "$lines" -gt "$READ_LINES" ] 2>/dev/null || exit 0
    cat >&2 <<EOF
bulk-guard: $fpath is $lines lines — roughly $(( lines / 100 ))k tokens — and this Read has no
offset/limit, so all of it would land in the main context and be re-sent on every later request.
Blocked.

Either read the part you actually need (offset/limit), or if the question is "what does this file
do / where is X in it", send a subagent — researcher-sonnet for a question, researcher-haiku for a
mechanical lookup — and ask for the conclusion rather than the material. Grep with a narrow pattern
also answers most of these for a few hundred tokens.

Genuinely need the whole thing here:
  touch $STATE_DIR/$sid.bypass
EOF
    exit 2
    ;;

  # --- Write: 4% ------------------------------------------------------------------------------
  Write)
    [ "$clen" -gt "$WRITE_CHARS" ] 2>/dev/null || exit 0
    cat >&2 <<EOF
bulk-guard: that Write carries $clen characters (~$(( clen / 4000 ))k tokens) of file body, and the
whole body travels in the tool call and is then re-sent on every later request of this session.
Blocked. Measured: Write from the main thread was 4% of all spend, largely boards rewritten several
times per session.

Hand it to page-writer-sonnet: give it the facts, the path, and the shape — it writes the file and
returns three lines. The body never enters this context. That is strictly better for a board, a
plan page, a status document or a long draft, because you are paying here for prose only the user
reads in a browser.

Edit is not blocked: changing part of an existing page costs the hunk, not the file. If this is a
small file that merely happens to be dense, or the content is already in this context for another
reason:
  touch $STATE_DIR/$sid.bypass
EOF
    exit 2
    ;;
esac

exit 0
