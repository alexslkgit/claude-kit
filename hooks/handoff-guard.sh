#!/usr/bin/env bash
# handoff-guard.sh — makes the handoff a file instead of a chat message, and makes the
# clean-up of that file automatic.
#
# The problem it solves, stated by the user 2026-08-13: a handoff was printed into the chat,
# he copied it by hand and pasted it into the new session. Nothing in that flow is guaranteed —
# the copy can be partial, the paste can land in the wrong window, and the prompt is gone the
# moment the old chat closes. Worse, the fix he tried before (a skill saying "also write a
# file") is exactly the kind of rule a session forgets, because a skill is text and text is
# obeyed at the model's discretion.
#
# So the whole mechanism lives here instead. A hook is a shell command the harness runs itself,
# at a fixed moment, whatever the model happens to be doing. It cannot be forgotten, skipped or
# talked out of. What it cannot do is think: it has no agent, it only reads the event payload on
# stdin and answers with text and an exit code. That division is the design —
#
#   the skill writes the handoff (thinking), the hook enforces the path and erases the file
#   afterwards (bookkeeping).
#
# Verified against the hook documentation, 2026-08-03 (see status-guard.sh for the full table):
#   SessionStart      stdout IS injected as a system message
#   UserPromptSubmit  stdout IS added to the context of that turn
#   PostToolUse       stdout IS added to the context; payload carries tool_input.file_path
#
# The four moments:
#   1. UserPromptSubmit, prompt looks like a handoff request
#        -> state the fixed path, so the handoff is written there and not into the chat.
#   2. PostToolUse on Write to that path
#        -> hide it from git via .git/info/exclude, and confirm it exists.
#   3. SessionStart, the file exists
#        -> tell the new session a handoff is waiting and that reading it comes first.
#   4. PostToolUse on Read of that path
#        -> the handoff has been consumed. Move it out of the repo, immediately.
#
# Step 4 is the one the user asked for by name: the file must not survive its own delivery,
# or the next session picks up a stale briefing and the repo slowly fills with dead prompts.
# It is a move, not a delete — into ~/.claude/handoff-archive, last 5 kept. Deleting outright
# saves nothing (the file is outside the repo and outside anyone's context either way) and a
# session that dies mid-read would lose the whole briefing with no way back.
#
# Never fails a session: always exits 0.

set -uo pipefail

ARCHIVE="$HOME/.claude/handoff-archive"

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

event="$(field hook_event_name)"; [ -n "$event" ] || event="${1:-SessionStart}"
cwd="$(field cwd)";              [ -n "$cwd" ]   || cwd="$PWD"

# The repository this session is working in, and the one path a handoff may live at.
repo_root=""; dir="$cwd"
for _ in 1 2 3 4 5 6 7 8; do
  [ -d "$dir/.git" ] && { repo_root="$dir"; break; }
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done
[ -n "$repo_root" ] || exit 0          # no checkout, no file handoff — the skill says so itself
HANDOFF="$repo_root/.claude/HANDOFF.md"

case "$event" in

  UserPromptSubmit)
    # --- context meter -------------------------------------------------------------------
    # The session transcript records the real token count on every assistant message: the sum
    # of input_tokens, cache_read and cache_creation IS the context that was just re-sent. So
    # the size of the conversation does not have to be guessed from its feel — it is a number
    # on disk, and the moment to hand over is a threshold on it rather than a judgement call.
    # Measured 2026-08-13: a session that felt ordinary was already at 169k.
    # Only the tail of the file is read; the whole thing runs to megabytes.
    tp="$(field transcript_path)"
    if [ -n "$tp" ] && [ -f "$tp" ] && command -v python3 >/dev/null 2>&1; then
      ctx="$(/usr/bin/tail -c 400000 "$tp" 2>/dev/null | python3 -c 'import json,sys
n=0
for l in sys.stdin:
    try: u=(json.loads(l).get("message") or {}).get("usage") or {}
    except Exception: continue
    if u: n=sum(u.get(k,0) for k in ("input_tokens","cache_read_input_tokens","cache_creation_input_tokens"))
print(n)' 2>/dev/null)"
      : "${ctx:=0}"
      if [ "$ctx" -ge 200000 ] 2>/dev/null; then
        cat <<EOF
handoff-guard: this conversation is at $(( ctx / 1000 ))k tokens, and every further turn re-sends
all of it. The user's standing rule is to stop at the next natural boundary past 200k — a finished
sub-task, never mid-step — write the handoff to $HANDOFF, and tell him to press /clear. He cannot
be expected to notice this himself; he has said the session should raise it.
EOF
      elif [ "$ctx" -ge 170000 ] 2>/dev/null; then
        printf 'handoff-guard: this conversation is at %sk tokens. Past 200k the standing rule is to wrap up at the next finished sub-task, so it is worth finishing what is open rather than starting something large.\n' "$(( ctx / 1000 ))"
      fi
    fi

    # --- handoff requested ---------------------------------------------------------------
    # Match on the raw payload rather than parsing the prompt out of it: prompts are multi-line
    # and quoted, and a false positive here costs one harmless sentence.
    printf '%s' "$payload" | /usr/bin/grep -qiE \
      'handoff|hand this over|хендоф|хэндоф|хендов|хэндов|архивируйся|заархивируй|перенеси в новый|новый чат|новый диалог' \
      || exit 0
    [ -f "$HANDOFF" ] && exit 0        # already written this turn, nothing to say
    cat <<EOF
handoff-guard: this project's handoff file is $HANDOFF — a handoff is written there with Write,
not printed into the chat. The user has said he no longer copies briefings by hand: he pastes the
path, the next session reads the file, and this hook moves the file out of the repo the moment it
is read. A handoff that exists only as chat text is therefore not delivered.
EOF
    exit 0
    ;;

  PostToolUse)
    # Read the path out of tool_input specifically. A regex over the whole payload would also
    # match a file_path appearing inside the file's own contents, which for the Read branch means
    # archiving a handoff because some unrelated file mentioned it.
    p=""
    if command -v python3 >/dev/null 2>&1; then
      p="$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path","") or "")
except Exception: print("")' 2>/dev/null)"
    fi
    [ -n "$p" ] || p="$(field file_path)"
    [ "$p" = "$HANDOFF" ] || exit 0
    tool="$(field tool_name)"

    case "$tool" in
      Write|Edit|MultiEdit)
        # Keep it out of git without touching .gitignore, which is a tracked, shared file.
        ex="$repo_root/.git/info/exclude"
        if [ -f "$ex" ] && ! /usr/bin/grep -qxF '.claude/HANDOFF.md' "$ex" 2>/dev/null; then
          printf '.claude/HANDOFF.md\n' >> "$ex" 2>/dev/null || true
        fi
        [ -s "$HANDOFF" ] || exit 0
        printf 'handoff-guard: the handoff is on disk at %s (%s lines) and excluded from git. The user pastes that path into the new session; nothing needs to be repeated into the chat.\n' \
          "$HANDOFF" "$(/usr/bin/wc -l < "$HANDOFF" | tr -d ' ')"
        exit 0
        ;;

      Read)
        [ -s "$HANDOFF" ] || exit 0
        mkdir -p "$ARCHIVE" 2>/dev/null || true
        # One file per project, overwritten every time — never a growing pile. A handoff is
        # read once and is worthless the moment it has been; the only reason a copy exists at
        # all is the session that dies mid-read. Timestamped copies were the first design and
        # the user killed it 2026-08-13: "склад из 10 тысяч хендоффов, которые больше никому
        # не нужны". One live file in the project, one dead copy outside it, and that is all.
        dest="$ARCHIVE/$(basename "$repo_root").md"
        if mv -f "$HANDOFF" "$dest" 2>/dev/null; then
          printf 'handoff-guard: that handoff has now been consumed. %s no longer exists — it was moved to %s. Do not write it back, do not re-read it, and do not mention the file to the user: the briefing is in this context now and continuing the work is the next action.\n' \
            "$HANDOFF" "$dest"
        fi
        exit 0
        ;;
    esac
    exit 0
    ;;

  SessionStart|*)
    [ -s "$HANDOFF" ] || exit 0
    when="$(/bin/date -r "$(/usr/bin/stat -f %m "$HANDOFF" 2>/dev/null || echo 0)" '+%Y-%m-%d %H:%M' 2>/dev/null)"
    # Do not merely point at the file — quote its opening. A pointer relies on the session
    # choosing to follow it, and that is the one link in this chain that was still goodwill.
    # With the first lines already in context the briefing has begun whether or not the model
    # decided to open it, and the instruction below is then a continuation rather than a
    # request. Kept short: SessionStart output is capped around 10k characters and the status
    # guard is speaking in the same breath.
    cat <<EOF
handoff-guard: a handoff written ${when:-earlier} is waiting at $HANDOFF.

It is the briefing from the previous session in this project, addressed to you. Reading it in
full with the Read tool is the first action of this session — before answering the user, before
touching the repository, and without telling him you are doing it: from his side he simply
carried on talking, and the mechanics are not his concern. Reading it also consumes it — this
hook moves the file out of the repository the moment you do, so it is read once and never again.

It opens like this, and this is only the opening:

--- $HANDOFF (first lines) ---
$(/usr/bin/head -c 2500 "$HANDOFF")
--- end of excerpt, the rest is in the file ---
EOF
    exit 0
    ;;
esac

exit 0
