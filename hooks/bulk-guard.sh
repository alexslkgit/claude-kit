#!/usr/bin/env bash
# bulk-guard.sh — keeps bulk out of the main conversation by refusing it at the call site.
#
# The measurement this exists for (TOKEN-ECONOMY.md, archived section 2026-08-17, 173 sessions, 37k requests):
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
#
# The hole, found 2026-08-26 in a real session: the Read rule above guards the Read tool only, and
# the same file read out through Bash walked straight past it. That session pulled an ASR transcript
# into the main conversation with sed -n '2,60p' and cat over five successive calls — about 58 000
# characters, roughly 18 000 tokens — which then rode along in every later request of the session.
# Read would have refused it. Bash was never asked. So Bash now also refuses a read-out utility
# (cat, head, tail, sed -n A,Bp, less, more, bat, column, jq .) pointed at a file over
# BASH_DUMP_BYTES. 30 KB is about 8–10k tokens: past that, a subagent that returns a conclusion is
# cheaper than carrying the file for the rest of the session.
#
# What that rule deliberately does NOT refuse, because a false block costs more here than a false
# pass: a narrow window (head -n N, tail -n N, sed -n 'A,Bp' under 200 lines), any grep — grep is a
# filter, not a dump, whatever the file size — any pipeline, since a pipe is the session already
# shrinking the output at the source, any redirection to a file, since that output never reaches the
# conversation, and any path that cannot be stat'ed. Unknown means allow, everywhere. The scratchpad
# round-trip exemption was considered and dropped: this hook cannot see the session's temp dir
# without guessing at it, and that guess is fragile in the direction that blocks work.

set -uo pipefail

IMAGE_BUDGET=2          # free screenshots per session in the main conversation
READ_LINES=1200         # a Read with no offset/limit above this is a whole-file dump
WRITE_CHARS=24000       # measured break-even against a page-writer-sonnet run, A-048
BASH_DUMP_BYTES=30000   # a file read out through Bash above this is a dump, not a look
BASH_DUMP_LINES=200     # a window this narrow is a look, whatever the file behind it weighs
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
    # --- a file read out in full through Bash, the hole closed 2026-08-26 -----------------------
    # Runs before every counter in this branch and touches none of them: this rule is about the size
    # of one call, the batching rule below is about the number of calls, and a refusal here must not
    # move the state the other rule measures.
    #
    # The parser prints one tab-separated "path<TAB>bytes" line and only ever on a confident,
    # positive detection. Every other outcome — an exception, an unreadable quoting, a missing
    # python, a path that cannot be stat'ed — prints nothing, and nothing means allow.
    dump="$(printf '%s' "$payload" | BASH_DUMP_BYTES="$BASH_DUMP_BYTES" \
                                     BASH_DUMP_LINES="$BASH_DUMP_LINES" python3 -c '
import json, os, re, shlex, stat, sys

LIMIT = 30000
WINDOW = 200
try:
    LIMIT = int(os.environ.get("BASH_DUMP_BYTES") or LIMIT)
    WINDOW = int(os.environ.get("BASH_DUMP_LINES") or WINDOW)
except Exception:
    pass

try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit
c = str((d.get("tool_input") or {}).get("command") or "")
base = str(d.get("cwd") or "")
if not os.path.isdir(base):
    base = "."

# A pipe shrinks the output at the source, a redirect sends it somewhere that is not this
# conversation, and pbcopy is the clipboard. All three are already the right behaviour. A pipeline
# whose tail happens not to shrink is a false negative this accepts on purpose.
if not c or "|" in c or ">" in c or "pbcopy" in c:
    raise SystemExit

def size_of(tok):
    if not tok or tok.startswith("-"):
        return 0
    p = os.path.expanduser(tok)
    if not os.path.isabs(p):
        p = os.path.join(base, p)
    try:
        st = os.stat(p)
    except Exception:
        return 0
    if not stat.S_ISREG(st.st_mode):
        return 0
    return st.st_size

def head_tail(rest):
    # (is it already a narrow window, the file arguments). Anything unreadable answers "narrow".
    n = None
    unit = "lines"
    files = []
    follow = False
    i = 0
    while i < len(rest):
        a = rest[i]
        if a in ("-f", "-F", "--follow"):
            follow = True
        elif a in ("-n", "-c", "--lines", "--bytes"):
            unit = "bytes" if a in ("-c", "--bytes") else "lines"
            i += 1
            n = rest[i] if i < len(rest) else None
        elif a.startswith("--lines=") or a.startswith("--bytes="):
            unit = "bytes" if a.startswith("--bytes=") else "lines"
            n = a.split("=", 1)[1]
        elif a.startswith("-"):
            m = re.match(r"^-([nc]?)([0-9]+)$", a)
            if m:
                unit = "bytes" if m.group(1) == "c" else "lines"
                n = m.group(2)
        else:
            files.append(a)
        i += 1
    if follow or n is None:
        return True, files
    if n.startswith("+"):
        return False, files
    m = re.match(r"^([0-9]+)([bkKmMgG]?)$", n)
    if not m:
        return True, files
    mult = {"": 1, "b": 512, "k": 1024, "K": 1000,
            "m": 1048576, "M": 1000000, "g": 1073741824, "G": 1000000000}
    v = int(m.group(1)) * mult.get(m.group(2), 1)
    if unit == "bytes":
        return v <= LIMIT, files
    return v <= WINDOW, files

def sed_lines(rest):
    # Only sed -n "A,Bp" FILE is understood. A substitution, an -e, an -f, a regex address: all of
    # them are filters or unreadable from here, and both answer None, which allows.
    if "-n" not in rest:
        return None, []
    if any(a.startswith("-") and a != "-n" for a in rest):
        return None, []
    plain = [a for a in rest if not a.startswith("-")]
    if not plain:
        return None, []
    script, files = plain[0], plain[1:]
    m = re.match(r"^\s*([0-9]+)\s*,\s*([0-9]+)\s*p\s*;?\s*$", script)
    if m:
        return int(m.group(2)) - int(m.group(1)) + 1, files
    if re.match(r"^\s*[0-9]+\s*,\s*\$\s*p\s*;?\s*$", script) or re.match(r"^\s*p\s*$", script):
        return WINDOW + 1, files
    return None, files

def jq_dump(rest):
    ok = ("-r", "-j", "-C", "-M", "-S", "-a", "-e", "--raw-output", "--sort-keys", "--color-output")
    if any(a.startswith("-") and a not in ok for a in rest):
        return False, []
    plain = [a for a in rest if not a.startswith("-")]
    if not plain:
        return False, []
    return plain[0].strip() in (".", ".[]"), plain[1:]

for seg in re.split(r"&&|;|\n|&", c):
    try:
        args = shlex.split(seg)
    except Exception:
        continue
    while args and re.match(r"^[A-Za-z_][A-Za-z_0-9]*=", args[0]):
        args.pop(0)
    if not args:
        continue
    cmd = os.path.basename(args[0])
    rest = args[1:]
    files = [a for a in rest if not a.startswith("-")]
    if cmd in ("cat", "less", "more"):
        pass
    elif cmd in ("head", "tail"):
        narrow, files = head_tail(rest)
        if narrow:
            continue
    elif cmd == "sed":
        span, files = sed_lines(rest)
        if span is None or span <= WINDOW:
            continue
    elif cmd == "jq":
        whole, files = jq_dump(rest)
        if not whole:
            continue
    elif cmd == "bat":
        if any(a.startswith("-r") or a.startswith("--line-range") for a in rest):
            continue
    elif cmd == "column":
        pass
    else:
        continue
    for f in files:
        n = size_of(f)
        if n > LIMIT:
            sys.stdout.write(f + "\t" + str(n))
            raise SystemExit
' 2>/dev/null)"

    if [ -n "${dump:-}" ]; then
      IFS=$'\t' read -r dpath dsize <<<"$dump"
      if [ -n "${dpath:-}" ] && [ "${dsize:-0}" -gt "$BASH_DUMP_BYTES" ] 2>/dev/null; then
        cat >&2 <<EOF
bulk-guard: $dpath is $dsize characters (~$(( dsize / 4000 ))k tokens) and this command reads it out
in full, so all of it lands in the main context and is re-sent on every later request of this
session. Blocked. Read refuses exactly this; until 2026-08-26 the same file read through Bash was
the way around it, measured once at 58 000 characters carried for a whole session.

Take a narrow window instead — head -n 40, sed -n '120,180p', or a grep with a real pattern, which
is never blocked whatever the file weighs. If the question is "what is in this file" or "what does
it say about X", that is a subagent: researcher-sonnet for a question, researcher-haiku for a
mechanical lookup, and ask it for the conclusion rather than the material. A pipeline that shrinks
the output at the source, and a redirect into a file, both go through untouched.

Genuinely need the whole thing here:
  touch $STATE_DIR/$sid.bypass
EOF
        exit 2
      fi
    fi

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

    # --- the batching hypothesis, off by default --------------------------------------------
    # Set BULK_GUARD_BATCH=1 and the run counter stops caring whether a call is a read-only
    # one-liner: ANY Bash call extends the run, and the third one in a row is refused. This is
    # the variant the baseline set measures against the shipped rule, one variable apart. It is
    # deliberately env-gated rather than switched on: measured 2026-08-26, 38.8% of the month's
    # Bash calls sit in unbroken runs of three or more, so this fires often, and every refusal
    # costs a request of its own. Whether it pays is a question for the run, not for the logs.
    if [ "${BULK_GUARD_BATCH:-0}" = "1" ]; then
      r=0; [ -f "$runf" ] && r="$(/bin/cat "$runf" 2>/dev/null || echo 0)"
      r=$(( r + 1 )); printf '%s' "$r" > "$runf" 2>/dev/null || true
      if [ "$r" -ge 3 ] 2>/dev/null; then
        printf '0' > "$runf" 2>/dev/null || true
        cat >&2 <<EOF
bulk-guard refused this Bash call: it is the third command in a row with no other tool between
them, and the two before it have already been paid for.

A request costs the whole context sitting under it, whatever the command was. Measured over the
month to 2026-08-25, Bash is 37 286 calls and 42% of the limit at a median of 325 characters:
none of that number is size, all of it is count.

Put everything you can predict into ONE call — a heredoc, a short script, several commands joined
with && or ; — and keep looking only where you genuinely cannot know the next command until you
have seen this output.

The run counter is already reset, so the next call goes through whatever it is.
EOF
        exit 2
      fi
      case "$n" in
        60|180|360) ;;
        *) exit 0 ;;
      esac
      exit 0
    fi

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

  # --- Write: prose pages only, above the measured break-even -----------------------------------
  Write)
    [ "$clen" -gt "$WRITE_CHARS" ] 2>/dev/null || exit 0
    # Source code is never handed to the page writer: it is the wrong role, and by A-048 the
    # delegation is the more expensive path anyway. Only pages the user reads in a browser.
    case "$fpath" in
      *.html|*.htm|*.md|*.markdown|*.txt) ;;
      *) exit 0 ;;
    esac
    cat >&2 <<EOF
bulk-guard: that Write carries $clen characters (~$(( clen / 4000 ))k tokens) of page body. You pay
for it twice here: once to compose it as output, and again on every later request of this session
as it is re-read from cache.

Measured break-even, A-048: composing plus carrying a page costs about the same as one
page-writer-sonnet run at roughly 24 000 characters, and above that the run is cheaper. This one is
over the line, so hand it over: give page-writer-sonnet the facts, the path and the shape, and it
returns three lines while the body never enters this context.

Below that size doing it yourself is cheaper by about 1,55x, which is why this now fires only on
long prose pages. Edit is never blocked: changing part of an existing page costs the hunk, not the
file. If the content is already in this context for another reason:
  touch $STATE_DIR/$sid.bypass
EOF
    exit 2
    ;;
esac

exit 0
