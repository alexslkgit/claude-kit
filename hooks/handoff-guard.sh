#!/usr/bin/env bash
# handoff-guard.sh — makes the handoff a file instead of a chat message, makes the next session
# read it, and makes it disappear once read.
#
# The problem it solves, stated by the user 2026-08-13: a handoff was printed into the chat, he
# had to copy it by hand, and half of it was lost. So the skill writes a file, this hook enforces
# where, tells a fresh session it is waiting, and erases it the moment it has been read.
#
# 2026-08-20, the second problem: he runs several sessions on one repository, and forks one into
# two whenever a task splits. With a single fixed HANDOFF.md the second session to be cleared
# overwrites the first one's briefing, and a fresh session picks up whichever file happens to be
# there — someone else's task. So a handoff is now one file per task under .claude/handoffs/,
# and a session start lists every waiting handoff rather than assuming there is one.
#
# Layout:
#   .claude/handoffs/<task-slug>.md   one per task, named by the session's own task
#   .claude/HANDOFF.md                the old single slot, still honoured if something writes it
#
# Never fails a session: always exits 0.

set -uo pipefail
ARCHIVE="$HOME/.claude/handoff-archive"

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

event="$(field hook_event_name)"; [ -n "$event" ] || event="${1:-SessionStart}"
cwd="$(field cwd)";              [ -n "$cwd" ]   || cwd="$PWD"

repo_root=""; dir="$cwd"
for _ in 1 2 3 4 5 6 7 8; do
  [ -d "$dir/.git" ] && { repo_root="$dir"; break; }
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done
[ -n "$repo_root" ] || exit 0          # no checkout, no file handoff — the skill says so itself

DIR="$repo_root/.claude/handoffs"
LEGACY="$repo_root/.claude/HANDOFF.md"

# Every handoff waiting in this repository, newest first.
waiting() {
  { [ -s "$LEGACY" ] && printf '%s\n' "$LEGACY"; } 2>/dev/null
  [ -d "$DIR" ] && /usr/bin/find "$DIR" -maxdepth 1 -type f -name '*.md' -size +0 2>/dev/null
}
title_of() { /usr/bin/head -1 "$1" 2>/dev/null | /usr/bin/sed 's/^#[[:space:]]*//' | /usr/bin/cut -c1-110; }
stamp_of() { /bin/date -r "$(/usr/bin/stat -f %m "$1" 2>/dev/null || echo 0)" '+%Y-%m-%d %H:%M' 2>/dev/null; }

case "$event" in

  UserPromptSubmit)
    printf '%s' "$payload" | /usr/bin/grep -qiE \
      'handoff|hand this over|хендоф|хэндоф|хендов|хэндов|архивируйся|заархивируй|перенеси в новый|новый чат|новый диалог' \
      || exit 0
    others="$(waiting)"
    cat <<EOF
handoff-guard: a handoff is written to a file, not printed into the chat. He no longer copies
briefings by hand: he pastes a path, the next session reads that file, and this hook moves it out
of the repository the moment it is read.

Write it to $DIR/<slug>.md, where the slug names whatever THIS session has been doing, in a few
kebab-case words. The directory is created by the Write itself. One file per topic is the whole
point: he runs several sessions on one repository, and a shared filename means the second one to
finish silently destroys the first one's briefing.
EOF
    if [ -n "$others" ]; then
      echo
      echo "Handoffs already waiting here, from other sessions. Do not overwrite them:"
      printf '%s\n' "$others" | while read -r f; do
        [ -n "$f" ] && printf '  %s  ·  %s  ·  %s\n' "$(basename "$f")" "$(stamp_of "$f")" "$(title_of "$f")"
      done
    fi
    exit 0
    ;;

  PostToolUse)
    p=""
    if command -v python3 >/dev/null 2>&1; then
      p="$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("tool_input",{}).get("file_path","") or "")
except Exception: print("")' 2>/dev/null)"
    fi
    [ -n "$p" ] || p="$(field file_path)"
    case "$p" in
      "$LEGACY"|"$DIR"/*.md) ;;
      *) exit 0 ;;
    esac
    tool="$(field tool_name)"

    case "$tool" in
      Write|Edit|MultiEdit)
        # Keep handoffs out of git without touching .gitignore, which is tracked and shared.
        ex="$repo_root/.git/info/exclude"
        if [ -f "$ex" ]; then
          for line in '.claude/HANDOFF.md' '.claude/handoffs/'; do
            /usr/bin/grep -qxF "$line" "$ex" 2>/dev/null || printf '%s\n' "$line" >> "$ex" 2>/dev/null || true
          done
        fi
        [ -s "$p" ] || exit 0
        printf 'handoff-guard: the handoff is on disk at %s (%s lines) and excluded from git. Give him that path; nothing needs to be repeated into the chat.\n' \
          "$p" "$(/usr/bin/wc -l < "$p" | tr -d ' ')"
        exit 0
        ;;

      Read)
        [ -s "$p" ] || exit 0
        mkdir -p "$ARCHIVE" 2>/dev/null || true
        # One dead copy per handoff, outside the repository. Timestamped piles were the first
        # design and he killed it 2026-08-13: "склад из 10 тысяч хендоффов, которые больше
        # никому не нужны". The copy exists only for the session that dies mid-read.
        dest="$ARCHIVE/$(basename "$repo_root")-$(basename "$p")"
        if mv -f "$p" "$dest" 2>/dev/null; then
          printf 'handoff-guard: that handoff has now been consumed. %s no longer exists, it was moved to %s. Do not write it back, do not re-read it, and do not mention the file to him: the briefing is in this context now and continuing the work is the next action.\n' \
            "$p" "$dest"
        fi
        exit 0
        ;;
    esac
    exit 0
    ;;

  SessionStart|*)
    list="$(waiting)"
    [ -n "$list" ] || exit 0
    n="$(printf '%s\n' "$list" | /usr/bin/grep -c . )"

    if [ "$n" -gt 1 ]; then
      echo "handoff-guard: $n handoffs are waiting in this repository, one per task."
      echo "Read the one whose title matches the task you have just been asked about, with the Read"
      echo "tool, before anything else. Leave the others alone: they belong to other live sessions,"
      echo "and reading one consumes it."
      echo
      printf '%s\n' "$list" | while read -r f; do
        [ -n "$f" ] && printf '  %s\n     %s  ·  %s\n' "$f" "$(stamp_of "$f")" "$(title_of "$f")"
      done
      echo
      echo "If none of them matches, say so in one line and carry on; do not read one at random."
      exit 0
    fi

    f="$(printf '%s\n' "$list" | head -1)"
    cat <<EOF
handoff-guard: a handoff written $(stamp_of "$f") is waiting at $f.

It is the briefing from the previous session in this project, addressed to you. Reading it in
full with the Read tool is the first action of this session — before answering the user, before
touching the repository, and without telling him you are doing it: from his side he simply
carried on talking, and the mechanics are not his concern. Reading it also consumes it — this
hook moves the file out of the repository the moment you do, so it is read once and never again.

It opens like this, and this is only the opening:

--- $f (first lines) ---
$(/usr/bin/head -40 "$f" 2>/dev/null)
--- end of excerpt, the rest is in the file ---
EOF
    exit 0
    ;;
esac
exit 0
