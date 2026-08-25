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

# Two markers, two different artefacts, and the walk looks for both:
#   .git                → $DIR / $LEGACY, transient handoffs, consumed the moment they are read.
#   .claude/status-dir  → $DURABLE, <status-dir>/HANDOFF.md: part of the project archive,
#                         rewritten by the wrap-up, read as often as needed, never moved.
# The status-dir branch is what makes this hook work outside a git checkout. It exited here
# 2026-08-20 with the user in ~/Downloads (not a repo), which is exactly the session that then
# answered "handoff" by writing a second briefing over the first.
repo_root=""; status_dir=""; dir="$cwd"
for _ in 1 2 3 4 5 6 7 8; do
  [ -z "$repo_root" ] && [ -d "$dir/.git" ] && repo_root="$dir"
  if [ -z "$status_dir" ] && [ -f "$dir/.claude/status-dir" ]; then
    status_dir="$(head -1 "$dir/.claude/status-dir" | /usr/bin/sed 's/[[:space:]]*$//')"
    case "$status_dir" in "~"*) status_dir="$HOME${status_dir#\~}" ;; esac
  fi
  [ -n "$repo_root" ] && [ -n "$status_dir" ] && break
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done
# A shelf directory has neither marker — no .git, no status-dir — and that is exactly the cwd he
# lands in after a /clear. Bailing out here is what made the briefing invisible, so the third way
# to stay alive is: at least one <cwd>/<task>/HANDOFF.md exists one level down.
shelf_handoffs() {
  for d in "$cwd"/*/; do
    [ -d "$d" ] || continue
    case "$(basename "$d")" in .*|node_modules|_*) continue ;; esac
    [ -s "${d%/}/HANDOFF.md" ] && printf '%s\n' "${d%/}/HANDOFF.md"
  done
}
[ -n "$repo_root" ] || [ -n "$status_dir" ] || [ -n "$(shelf_handoffs 2>/dev/null)" ] || exit 0

DIR=""; LEGACY=""
[ -n "$repo_root" ] && { DIR="$repo_root/.claude/handoffs"; LEGACY="$repo_root/.claude/HANDOFF.md"; }
DURABLE=""; [ -n "$status_dir" ] && DURABLE="$status_dir/HANDOFF.md"

# Per-session prompt counter. The pickup branch turns on the FIRST prompt of a session and
# nothing else, so the count is the whole mechanism.
SESSDIR="$HOME/.claude/.handoff-guard"
sid="$(field session_id)"; [ -n "$sid" ] || sid="$(printf '%s' "$cwd" | /usr/bin/tr -cd 'A-Za-z0-9')"
counter="$SESSDIR/$sid.n"

# Every handoff waiting for this session, newest first.
#
# shelf_handoffs is defined above the early exit. The walk only looks UP from cwd, which is blind
# in the case that matters most: he clears a session while sitting in a shelf directory such as
# ~/Downloads, where each task keeps its own folder, and the briefing is one level DOWN.
# Added 2026-08-20, the same day the shelf itself was untangled.
waiting() {
  { [ -n "$LEGACY" ] && [ -s "$LEGACY" ] && printf '%s\n' "$LEGACY"; } 2>/dev/null
  [ -n "$DIR" ] && [ -d "$DIR" ] && /usr/bin/find "$DIR" -maxdepth 1 -type f -name '*.md' -size +0 2>/dev/null
  { [ -n "$DURABLE" ] && [ -s "$DURABLE" ] && printf '%s\n' "$DURABLE"; } 2>/dev/null
  shelf_handoffs 2>/dev/null
}
title_of() { /usr/bin/head -1 "$1" 2>/dev/null | /usr/bin/sed 's/^#[[:space:]]*//' | /usr/bin/cut -c1-110; }
stamp_of() { /bin/date -r "$(/usr/bin/stat -f %m "$1" 2>/dev/null || echo 0)" '+%Y-%m-%d %H:%M' 2>/dev/null; }

case "$event" in

  UserPromptSubmit)
    mkdir -p "$SESSDIR" 2>/dev/null || true
    n="$(cat "$counter" 2>/dev/null || echo 0)"; n=$((n + 1)); printf '%s' "$n" > "$counter" 2>/dev/null || true
    /usr/bin/find "$SESSDIR" -type f -mtime +2 -delete 2>/dev/null || true

    printf '%s' "$payload" | /usr/bin/grep -qiE \
      'handoff|hand ?off|hand this over|хендоф|хэндоф|хендов|хэндов|архивируйся|заархивируй|перенеси в новый|новый чат|новый диалог' \
      || exit 0

    # --- the word arrived on the FIRST prompt of the session ------------------------------
    # Then it cannot be a request to write one: no conversation exists yet to hand over. It is
    # the other end of the same ritual — he has pressed /clear and is handing the briefing back.
    # Recorded 2026-08-20, after a session answered "handoff" by writing a second one over the
    # top of the first and telling him to clear a context he had cleared thirty seconds earlier.
    if [ "$n" -le 1 ]; then
      list="$(waiting)"
      echo "handoff-guard: this is the FIRST prompt of this session and it says handoff. Nothing has"
      echo "happened here yet, so there is nothing to hand over — this is a PICKUP. He has just pressed"
      echo "/clear and is handing you the briefing the previous session left. Read it, then carry on from"
      echo "where it stops. Do NOT write a handoff, do NOT run wrap-up, do NOT tell him to clear a context"
      echo "he has already cleared, and do NOT ask him what the task was — that button is what spared him"
      echo "from saying it twice."
      echo
      if [ -n "$list" ]; then
        cnt="$(printf '%s\n' "$list" | /usr/bin/grep -c . )"
        echo "Briefings on disk right now:"
        i=0
        printf '%s\n' "$list" | while read -r f; do
          [ -n "$f" ] || continue
          i=$((i + 1))
          printf '  %s. %s\n     %s  ·  %s\n' "$i" "$f" "$(stamp_of "$f")" "$(title_of "$f")"
        done
        echo
        if [ "$cnt" -gt 1 ]; then
          cat <<'PICK'
THE ONE RULE THAT MATTERS HERE, and it cost him a whole project on 2026-08-25: you do not know
which of these is yours, and NOTHING on disk can tell you. A /clear starts a brand new session
with a new id and no memory of which chat it belongs to; the folder is a shelf shared by every
task; and the newest file is simply whichever OTHER chat he cleared most recently.

So: picking by recency is FORBIDDEN. Picking "the one that looks most active" is forbidden.
Opening one to see whether it fits is forbidden, because reading it puts somebody else's project
into this context and the damage is already done.

Open one ONLY when you have positive evidence:
  · exactly one briefing is listed, or
  · his message names the task, the file, the folder or the subject matter, or
  · the working directory IS that task's own folder.

Otherwise ask him, in one line, with the numbered list above, which one this chat is. That is a
legitimate question: he is the only thing in the world that knows which chat he is sitting in.
One digit from him costs seconds. The wrong briefing costs the project.

Whatever you open, your first line names it: "поднял хендофф по <задача>". He caught the failure
of 2026-08-25 only because the session said out loud what it had picked up.

THEN CLOSE THE HOLE FOR THIS CHAT, ONCE: as soon as you know which task it is, move the session
into that task's own folder with mcp__ccd_directory__change_directory. The shelf is what makes
this ambiguous; a chat that sits in ~/Downloads/<task>/ can never be confused again, because the
next /clear starts there and the folder itself is the answer. Do it silently, do not explain the
mechanics to him, and do not ask permission for it.
PICK
        else
          echo "Exactly one, so it is unambiguous: read it, then STATUS.md beside it."
        fi
      else
        echo "None found here. Read STATUS.md in the project status directory, start from its cold-start"
        echo "section, and open with one line saying where you are picking up."
      fi
      echo
      echo "If you genuinely do have this conversation's history in front of you, ignore this: the"
      echo "transcript is the authority and this hook only counts prompts."
      exit 0
    fi

    [ -n "$DIR" ] || exit 0            # no checkout: the skill governs where it goes, and outside
                                       # a repo the handoff is <task-folder>/HANDOFF.md
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
    [ -n "$p" ] || exit 0
    [ -n "$DIR" ] || exit 0            # nothing transient to police in a non-repo cwd
    case "$p" in
      "$LEGACY"|"$DIR"/*.md) ;;        # $DURABLE is deliberately absent: it is never consumed
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
    rm -f "$counter" 2>/dev/null || true
    list="$(waiting)"
    [ -n "$list" ] || exit 0
    n="$(printf '%s\n' "$list" | /usr/bin/grep -c . )"

    # --- the automatic pickup ---------------------------------------------------------------
    # He was typing "pick up the handoff" after every /clear, by his own count around three
    # hundred times a day, and on 2026-08-25 he asked for that keystroke to disappear. It can:
    # a session started BY a clear or a compact, with exactly one briefing written in the last
    # hour, can only be the far end of the ritual that just happened. So the whole file goes in
    # here as context and the session is already picked up before he says anything at all.
    #
    # Deliberately narrow. Two fresh handoffs, or a plain startup, and it falls through to the
    # listing below: guessing which task he meant is the one failure that costs more than typing.
    src="$(field source)"
    # DISABLED 2026-08-25, same day it was written. See below: a fresh handoff is not proof that it
    # belongs to THIS chat. Re-enabled only once the match is by identity, never by time.
    case "DISABLED-$src" in
      clear|compact)
        fresh="$(printf '%s\n' "$list" | while read -r f; do
          [ -n "$f" ] && [ -n "$(/usr/bin/find "$f" -mmin -60 2>/dev/null)" ] && printf '%s\n' "$f"
        done)"
        if [ "$(printf '%s\n' "$fresh" | /usr/bin/grep -c . )" = "1" ]; then
          f="$(printf '%s\n' "$fresh" | head -1)"
          cat <<EOF
handoff-guard: he pressed /clear and you are already picked up. The briefing the previous session
left, $(stamp_of "$f"), is below in full. He does not have to type "pick up the handoff" and he is
not going to: that keystroke was removed on 2026-08-25 and asking him for it is a defect.

Carry on from where it stops. Your first message opens with the board link as always and says in
one line where you are picking up. Do not thank him for the handoff, do not summarise what you
just read, do not write a new handoff, and do not tell him to clear a context he cleared seconds
ago.

--- $f ---
$(cat "$f" 2>/dev/null)
--- end ---
EOF
          exit 0
        fi
        ;;
    esac

    if [ "$n" -gt 1 ]; then
      echo "handoff-guard: $n handoffs are waiting here, one per task, and NONE of them is known to be"
      echo "yours. Do not open any of them until you have positive evidence which task this chat is:"
      echo "his words naming it, or a working directory that is one task's own folder. Recency is not"
      echo "evidence — the newest file is whichever OTHER chat he cleared last. Reading the wrong one"
      echo "puts another project into this context, and on 2026-08-25 that destroyed a session that had"
      echo "been running for days."
      echo
      i=0
      printf '%s\n' "$list" | while read -r f; do
        [ -n "$f" ] || continue
        i=$((i + 1))
        printf '  %s. %s\n     %s  ·  %s\n' "$i" "$f" "$(stamp_of "$f")" "$(title_of "$f")"
      done
      echo
      echo "If he asks you to pick up a handoff and you cannot tell which, ask him in one line with"
      echo "this numbered list. One digit from him is cheap; the wrong briefing is not. And whichever"
      echo "you open, say which one in your first line so he can catch a mistake in a second."
      exit 0
    fi

    f="$(printf '%s\n' "$list" | head -1)"
    cat <<EOF
handoff-guard: a handoff written $(stamp_of "$f") is waiting at $f.

It is the briefing from the previous session in this project, addressed to you. Reading it in
full with the Read tool is the first action of this session — before answering the user, before
touching the repository, and without telling him you are doing it: from his side he simply
carried on talking, and the mechanics are not his concern.

$(if [ "$f" = "$DURABLE" ] || [ "$(basename "$f")" = "HANDOFF.md" ]; then
    printf '%s' "This one is part of the task's own archive and stays where it is: it is rewritten by the next wrap-up, not deleted by being read."
  else
    printf '%s' "Reading it also consumes it — this hook moves the file out of the repository the moment you do, so it is read once and never again."
  fi)

It opens like this, and this is only the opening:

--- $f (first lines) ---
$(/usr/bin/head -40 "$f" 2>/dev/null)
--- end of excerpt, the rest is in the file ---
EOF
    exit 0
    ;;
esac
exit 0
