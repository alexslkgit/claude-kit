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
  # Marker-free fallback, added 2026-08-25. The walk looked UP for a marker and DOWN one level for
  # a shelf, and was blind to the folder it was standing in — which is the case the whole design
  # aims at: a session that already sits in its own task folder. ~/Downloads/html-autoswipe held
  # HANDOFF.md, STATUS.md and DECISIONS.md and this hook said nothing, because nobody had written
  # the one-line marker by hand. A folder holding STATUS.md is that task's status directory.
  if [ -z "$status_dir" ] && [ -f "$dir/STATUS.md" ]; then
    status_dir="$dir"
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
# Beside the counter, added 2026-08-27: marks that THIS session has already announced a pickup
# once, whichever branch did it, so the deferred UserPromptSubmit check never repeats what
# SessionStart already said and vice versa.
picked_marker="$SESSDIR/$sid.picked"

# --- who this chat is, which the filesystem alone can never say -------------------------------
# A /clear starts a brand new CLI session id in the same directory, so every id this hook is
# handed is fresh and identifies nothing. The desktop app, however, keeps the CHAT, and records
# both halves in ~/Library/Application Support/Claude/claude-code-sessions/**/local_<chat>.json:
#
#   "cliSessionId": "<the id in this payload>"   new after every clear
#   "sessionId":    "local_<uuid>"               the chat itself, stable for its whole life
#   "title":        "<what he sees in the list>" stable, and set by the session-title tool
#
# That local_ id is the missing identity. A handoff stamped with it at write time is claimed by
# exactly one chat, and the chat that wakes up after the clear resolves the same id and takes its
# own briefing with no guess, no timestamp and nothing for him to type. Added 2026-08-25, after a
# session with five waiting handoffs had to ask him which one it was and he answered that he did
# not know either — the identity was on disk the whole time, and nothing was reading it.
CHATROOT="$HOME/Library/Application Support/Claude/claude-code-sessions"
CHAT_ID=""; CHAT_TITLE=""; CHAT_TITLESRC=""
# Bounded wait, added 2026-08-27. The mapping file is written by the desktop app AFTER the CLI
# session already exists — measured on 471eaebd, 2m17s after SessionStart — so a resolve_chat that
# only tries once at SessionStart routinely finds nothing and both identity branches below it are
# gated on CHAT_ID being non-empty. An optional first argument is the number of EXTRA attempts
# beyond the first, 0.4s apart; every call site but SessionStart keeps passing none, so nothing
# outside that one branch waits at all, and even there the ceiling is ~6s and a miss still exits 0.
resolve_chat() {
  local extra="${1:-0}" tries f
  tries=$((extra + 1))
  [ -n "$sid" ] || return 0
  [ -d "$CHATROOT" ] || return 0
  while :; do
    f="$(/usr/bin/grep -rl "\"cliSessionId\":\"$sid\"" "$CHATROOT" --include='local_*.json' 2>/dev/null | head -1)"
    [ -n "$f" ] && break
    tries=$((tries - 1))
    [ "$tries" -gt 0 ] || return 0
    sleep 0.4 2>/dev/null || true
  done
  CHAT_ID="$(basename "$f" .json)"
  if command -v python3 >/dev/null 2>&1; then
    CHAT_TITLE="$(python3 -c 'import json,sys
try: print(json.load(open(sys.argv[1])).get("title","") or "")
except Exception: pass' "$f" 2>/dev/null)"
  fi
  [ -n "$CHAT_TITLE" ] || CHAT_TITLE="$(/usr/bin/sed -n 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1)"
  CHAT_TITLESRC="$(/usr/bin/sed -n 's/.*"titleSource"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$f" | head -1)"
}
[ "$event" = "SessionStart" ] && resolve_chat 15 || resolve_chat

# The stamp a handoff carries, and the two readers of it.
MARK='handoff-chat:'

MATCHPY='
import sys, os, re
title = sys.argv[1]
STOP = set("the a an of and for to in on orchestrator session handoff work task claude helio".split())
def toks(x):
    return set(t for t in re.split(r"[^a-z0-9]+", x.lower()) if t and t not in STOP and len(t) > 1)
want = toks(title)
if want:
    best_score, best_file, second = 0, None, 0
    for line in sys.stdin:
        f = line.strip()
        if not f or not os.path.isfile(f):
            continue
        slug = os.path.splitext(os.path.basename(f))[0]
        score = len(want & toks(slug))
        if score > best_score:
            second, best_score, best_file = best_score, score, f
        elif score > second:
            second = score
    if best_score >= 2 and best_score >= second + 2:
        print(best_file)
'
# --- the second way in, for a briefing written before stamping existed -------------------------
# A stamp is exact and always wins. But a handoff written by an older session carries none, and he
# asked on 2026-08-25 for the problem to be impossible in EXISTING chats too, not only in new ones.
# The chat's title is the other half of its identity, it survives a clear, and this project's
# handoffs are named after their task: "onboarding-ai-chat-page" the chat and
# onboarding-ai-chat-page.md the briefing. So an unstamped file may be claimed by name, and only
# when the name leaves no room for doubt: at least two words in common and a clear winner over the
# runner-up. Anything less falls through to the list and to him.
title_match() {   # stdin: candidate paths. stdout: the single winner, or nothing.
  [ -n "$CHAT_TITLE" ] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  # The program goes in -c, never on stdin: a heredoc would BE stdin and the candidate paths
  # would arrive at an already-exhausted pipe. That cost one silent test run.
  python3 -c "$MATCHPY" "$CHAT_TITLE"
}
owner_of() { /usr/bin/sed -n "s/.*$MARK[[:space:]]*\([A-Za-z0-9_-]*\).*/\1/p" "$1" 2>/dev/null | head -1; }
owner_title_of() { /usr/bin/sed -n "s/.*$MARK[[:space:]]*[A-Za-z0-9_-]*[[:space:]]*|[[:space:]]*\(.*[^[:space:]]\)[[:space:]]*-->.*/\1/p" "$1" 2>/dev/null | head -1; }

# Every handoff waiting for this session, newest first.
#
# shelf_handoffs is defined above the early exit. The walk only looks UP from cwd, which is blind
# in the case that matters most: he clears a session while sitting in a shelf directory such as
# ~/Tasks, where each task keeps its own folder, and the briefing is one level DOWN.
# Added 2026-08-20, the same day the shelf itself was untangled.
waiting() {
  { [ -n "$LEGACY" ] && [ -s "$LEGACY" ] && printf '%s\n' "$LEGACY"; } 2>/dev/null
  [ -n "$DIR" ] && [ -d "$DIR" ] && /usr/bin/find "$DIR" -maxdepth 1 -type f -name '*.md' -size +0 2>/dev/null
  { [ -n "$DURABLE" ] && [ -s "$DURABLE" ] && printf '%s\n' "$DURABLE"; } 2>/dev/null
  shelf_handoffs 2>/dev/null
}
title_of() { /usr/bin/head -1 "$1" 2>/dev/null | /usr/bin/sed 's/^#[[:space:]]*//' | /usr/bin/cut -c1-110; }
stamp_of() { /bin/date -r "$(/usr/bin/stat -f %m "$1" 2>/dev/null || echo 0)" '+%Y-%m-%d %H:%M' 2>/dev/null; }

# Self-healing stamp, added 2026-08-27. The PostToolUse/Write branch below is the only place that
# writes the stamp, and it is registered for Write only until this same date's settings.json fix —
# but even after that fix, a handoff dropped by a Bash heredoc is never seen by ANY PostToolUse
# matcher, because no file_path ever passes through a tool call. So whenever this chat's identity
# is known, claim any unstamped waiting handoff that title_match would resolve for this chat's own
# title, using the exact stamp format and line-2 position the Write branch uses, and stamp it here
# instead. Called from both SessionStart and UserPromptSubmit, after resolve_chat.
heal_stamps() {
  [ -n "$CHAT_ID" ] || return 0
  local list unstamped target tmp
  list="$(waiting)"
  [ -n "$list" ] || return 0
  unstamped="$(printf '%s\n' "$list" | while IFS= read -r f; do
    [ -n "$f" ] || continue
    [ -s "$f" ] || continue
    /usr/bin/grep -q "$MARK" "$f" 2>/dev/null || printf '%s\n' "$f"
  done)"
  [ -n "$unstamped" ] || return 0
  target="$(printf '%s\n' "$unstamped" | title_match)"
  [ -n "$target" ] && [ -s "$target" ] || return 0
  tmp="$target.stamp.$$"
  { /usr/bin/head -1 "$target"
    printf '<!-- %s %s | %s -->\n' "$MARK" "$CHAT_ID" "$CHAT_TITLE"
    /usr/bin/tail -n +2 "$target"
  } > "$tmp" 2>/dev/null && mv -f "$tmp" "$target" 2>/dev/null || rm -f "$tmp" 2>/dev/null
}

# Archive-on-delivery, added 2026-08-27. Consumption was PostToolUse-on-Read only, so a briefing
# read with a bare `cat` in a bypass-permissions session — or one whose full text this hook itself
# just printed, in the SessionStart and UserPromptSubmit pickup blocks below — was never seen by
# that matcher and sat on disk confusing the next session. The moment this hook has put a briefing
# into the model's context in full, it HAS been delivered, so it archives it in that same breath,
# exactly the way the PostToolUse/Read branch already does. $DURABLE is exempt on purpose: it is
# part of the project's own archive, rewritten by the next wrap-up, and is never consumed.
archive_handoff() {   # $1: the path just cat'ed in full into a heredoc above this call.
  local f="$1"
  [ -n "$f" ] && [ -s "$f" ] || return 0
  [ -n "$DURABLE" ] && [ "$f" = "$DURABLE" ] && return 0
  mkdir -p "$ARCHIVE" 2>/dev/null || true
  mv -f "$f" "$ARCHIVE/$(basename "$repo_root")-$(basename "$f")" 2>/dev/null || true
}

case "$event" in

  UserPromptSubmit)
    mkdir -p "$SESSDIR" 2>/dev/null || true
    n="$(cat "$counter" 2>/dev/null || echo 0)"; n=$((n + 1)); printf '%s' "$n" > "$counter" 2>/dev/null || true
    /usr/bin/find "$SESSDIR" -type f -mtime +2 -delete 2>/dev/null || true

    # --- deferred identity pickup, added 2026-08-27 -----------------------------------------
    # SessionStart's bounded wait is capped at ~6s, and the mapping file that resolve_chat greps
    # for was measured arriving 2m17s after the session started — well outside that ceiling. This
    # session did not miss the handoff, it only missed it AT THAT MOMENT. Every prompt after that
    # is another chance to resolve, so identity is checked here on every single one, unconditional
    # on any keyword, until a pickup is announced once (marker: $picked_marker) or there is nothing
    # to claim. This is the fix for the proven race: SessionStart's own branches stay untouched.
    if [ ! -f "$picked_marker" ]; then
      heal_stamps
      pu_f=""
      if [ -n "$CHAT_ID" ]; then
        pu_list="$(waiting)"
        if [ -n "$pu_list" ]; then
          pu_claimed=""
          while IFS= read -r pu_wf; do
            [ -n "$pu_wf" ] || continue
            [ "$(owner_of "$pu_wf")" = "$CHAT_ID" ] && pu_claimed="$pu_claimed$pu_wf
"
          done <<PUCLAIMEOF
$pu_list
PUCLAIMEOF
          pu_cn="$(printf '%s' "$pu_claimed" | /usr/bin/grep -c . )"
          if [ "$pu_cn" = "1" ]; then
            pu_f="$(printf '%s' "$pu_claimed" | head -1)"
          elif [ "$pu_cn" = "0" ]; then
            pu_f="$(printf '%s\n' "$pu_list" | title_match)"
          fi
        fi
      fi
      if [ -n "$pu_f" ] && [ -s "$pu_f" ]; then
        cat <<EOF
handoff-guard: you are already picked up, and nobody had to guess. This chat is "$CHAT_TITLE"
($CHAT_ID). Identity only just resolved — the desktop app had not finished writing the mapping
file at session start — and the briefing below is claimed by this chat, by its stamp or, if it
predates stamping, by its name, so it is yours by identity rather than by recency. It is here in
full ($(stamp_of "$pu_f")).

Read it and carry on from where it stops. Your first message opens with the board link as always
and says in one line which task you picked up, so a wrong pickup is caught in a second. Do not
thank him for the handoff, do not summarise it back at him, do not write a new one, and do not
tell him to clear a context he cleared seconds ago.

--- $pu_f ---
$(cat "$pu_f" 2>/dev/null)
--- end ---
EOF
        archive_handoff "$pu_f"  # 2026-08-27: delivered in full above, consumed now, whatever tool reads next.
        touch "$picked_marker" 2>/dev/null || true
        exit 0
      fi
    fi

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
        if [ -n "$CHAT_ID" ]; then
          echo "You are the chat \"$CHAT_TITLE\" ($CHAT_ID). A briefing stamped with that id is yours"
          echo "by identity; one stamped with another id is not, whatever its date says."
          echo
        fi
        echo "Briefings on disk right now:"
        i=0
        printf '%s\n' "$list" | while read -r f; do
          [ -n "$f" ] || continue
          i=$((i + 1))
          o="$(owner_of "$f")"; ot="$(owner_title_of "$f")"
          if [ -z "$o" ]; then tag="unclaimed — predates stamping"
          elif [ "$o" = "$CHAT_ID" ]; then tag="THIS CHAT — open this one"
          else tag="another chat: ${ot:-$o} — not yours"; fi
          printf '  %s. %s\n     %s  ·  %s\n     %s\n' "$i" "$f" "$(stamp_of "$f")" "$(title_of "$f")" "$tag"
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

FIRST, ASK YOURSELF WHO YOU ARE. If this hook printed your chat id and title above, that is the
answer and a stamped briefing bearing it is yours. If it could not resolve them, fall back to
reading your own title by renaming yourself and reading what comes back:

    mcp__ccd_session_mgmt__set_session_title(session_id: "self", title: "identifying")

The result ends with `(was "<your real title>")`. Rename yourself back to that exact string at
once. `get_session` refuses the current session, so this round trip is the only way to read it.
On 2026-08-25 the title was the ONLY thing that identified a cleared chat correctly, after its
working directory had already pointed it at the wrong project and it had read that project's
briefing.

Open one ONLY when you have positive evidence:
  · exactly one briefing is listed, or
  · his message names the task, the file, the folder or the subject matter, or
  · your own chat title, read as above, names it, or
  · the working directory belongs to ONE task and no other chat is parked in it. A git checkout
    is NOT automatically that. If the parallel guard has just told you several sessions are live
    in this directory, it is a shelf: it is not evidence, however much it looks like a project.

Otherwise ask him, in one line, with the numbered list above, which one this chat is. That is a
legitimate question: he is the only thing in the world that knows which chat he is sitting in.
One digit from him costs seconds. The wrong briefing costs the project.

Whatever you open, your first line names it: "поднял хендофф по <задача>". He caught the failure
of 2026-08-25 only because the session said out loud what it had picked up.

THEN CLOSE THE HOLE FOR THIS CHAT, ONCE: as soon as you know which task it is, move the session
into that task's own folder with mcp__ccd_directory__change_directory. The shelf is what makes
this ambiguous; a chat that sits in ~/Tasks/<task>/ can never be confused again, because the
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
        # Stamp the file with the chat that wrote it, mechanically, so the next session after the
        # clear can claim its own briefing without asking him. Line 2, so `head -1` still yields
        # the title. Never rely on the model remembering to write this line: it is injected here.
        if [ -n "$CHAT_ID" ] && ! /usr/bin/grep -q "$MARK" "$p" 2>/dev/null; then
          tmp="$p.stamp.$$"
          { /usr/bin/head -1 "$p"
            printf '<!-- %s %s | %s -->\n' "$MARK" "$CHAT_ID" "$CHAT_TITLE"
            /usr/bin/tail -n +2 "$p"
          } > "$tmp" 2>/dev/null && mv -f "$tmp" "$p" 2>/dev/null || rm -f "$tmp" 2>/dev/null
        fi
        printf 'handoff-guard: the handoff is on disk at %s (%s lines), stamped with this chat (%s) and excluded from git. Give him that path; nothing needs to be repeated into the chat.\n' \
          "$p" "$(/usr/bin/wc -l < "$p" | tr -d ' ')" "${CHAT_TITLE:-unresolved}"
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
    rm -f "$picked_marker" 2>/dev/null || true
    heal_stamps  # 2026-08-27: claim any unstamped handoff title_match resolves for this chat.
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
    # --- the identity match, and the only one that is allowed ------------------------------
    # The first version of this matched on FRESHNESS and was switched off the same day: the newest
    # briefing on a shelf is simply whichever OTHER chat he cleared last, and picking it put another
    # project into the context. The rule that replaced it was "re-enable only on identity, never on
    # time", and this is that identity: the session is standing INSIDE one task's own folder and
    # that folder holds exactly one briefing. A /clear restarts the session in the same directory,
    # so the directory itself is the answer to "which chat is this" — no guess, no timestamp, and
    # nothing for him to type. Two briefings, or a briefing anywhere but this folder, and it falls
    # through to the listing below.
    # --- the identity match, and it needs no folder and no timestamp ------------------------
    # The briefing was stamped with this chat's id when it was written, so the chat that comes
    # back after the clear simply picks the file bearing its own name. This is the branch that
    # ends the question "which of these is mine".
    if [ -n "$CHAT_ID" ]; then
      claimed=""
      while IFS= read -r f; do
        [ -n "$f" ] || continue
        [ "$(owner_of "$f")" = "$CHAT_ID" ] && claimed="$claimed$f
"
      done <<CLAIMEOF
$list
CLAIMEOF
      cn="$(printf '%s' "$claimed" | /usr/bin/grep -c . )"
      if [ "$cn" = "1" ]; then
        f="$(printf '%s' "$claimed" | head -1)"
        cat <<EOF
handoff-guard: you are already picked up, and nobody had to guess. This chat is "$CHAT_TITLE"
($CHAT_ID), the briefing below was written by this same chat before the clear and carries its id,
so it is yours by identity rather than by recency. It is here in full ($(stamp_of "$f")).

Read it and carry on from where it stops. Your first message opens with the board link as always
and says in one line which task you picked up, so a wrong pickup is caught in a second. Do not
thank him for the handoff, do not summarise it back at him, do not write a new one, and do not
tell him to clear a context he cleared seconds ago.

--- $f ---
$(cat "$f" 2>/dev/null)
--- end ---
EOF
        archive_handoff "$f"  # 2026-08-27: delivered in full above, consumed now, whatever tool reads next.
        touch "$picked_marker" 2>/dev/null || true  # 2026-08-27: so UserPromptSubmit does not repeat this.
        exit 0
      fi

      # No stamp names this chat. Try the name.
      if [ "$cn" = "0" ]; then
        f="$(printf '%s\n' "$list" | title_match)"
        if [ -n "$f" ] && [ -s "$f" ]; then
          cat <<EOF
handoff-guard: you are already picked up, and nobody had to guess. This chat is "$CHAT_TITLE",
and of the $n briefings waiting here exactly one is named after that task and no other comes
close, so it is yours. It carries no chat stamp only because it was written before handoffs were
stamped; everything written from now on is claimed by id instead. It is here in full ($(stamp_of "$f")).

Read it and carry on from where it stops. Your first message opens with the board link as always
and says in one line which task you picked up, so a wrong pickup is caught in a second. Do not
thank him for the handoff, do not summarise it back at him, and do not write a new one.

--- $f ---
$(cat "$f" 2>/dev/null)
--- end ---
EOF
          archive_handoff "$f"  # 2026-08-27: delivered in full above, consumed now, whatever tool reads next.
          touch "$picked_marker" 2>/dev/null || true  # 2026-08-27: so UserPromptSubmit does not repeat this.
          exit 0
        fi
      fi
    fi

    if [ "$n" = "1" ] && [ -s "$cwd/HANDOFF.md" ] && [ "$(printf '%s\n' "$list" | head -1)" = "$cwd/HANDOFF.md" ]; then
      f="$cwd/HANDOFF.md"
      cat <<EOF
handoff-guard: you are already picked up, and he does not have to ask. This session is sitting in
$cwd, that task keeps exactly one briefing, and it is below in full ($(stamp_of "$f")).
He typed "pick up the handoff" after every clear for weeks; that keystroke was removed on
2026-08-25 and asking him for it, or waiting for it, is a defect.

Read it and carry on from where it stops. Your first message opens with the board link as always
and says in one line which task you picked up, so a wrong pickup is caught in a second. Do not
thank him for the handoff, do not summarise what you just read back at him, do not write a new
handoff, and do not tell him to clear a context he cleared seconds ago.

--- $f ---
$(cat "$f" 2>/dev/null)
--- end ---
EOF
      archive_handoff "$f"  # 2026-08-27: delivered in full above, consumed now, whatever tool reads next.
      touch "$picked_marker" 2>/dev/null || true  # 2026-08-27: so UserPromptSubmit does not repeat this.
      exit 0
    fi

    if [ "$n" -gt 1 ]; then
      echo "handoff-guard: $n handoffs are waiting here, one per task, and none of them carries this"
      echo "chat's id. Do not open any of them until you have positive evidence which task this chat"
      echo "is. Recency is not evidence — the newest file is whichever OTHER chat he cleared last."
      echo "Reading the wrong one puts another project into this context, and on 2026-08-25 that"
      echo "destroyed a session that had been running for days."
      echo
      if [ -n "$CHAT_ID" ]; then
        echo "You are the chat \"$CHAT_TITLE\" ($CHAT_ID). That title is real identity and it survives"
        echo "a clear: if it names one of the tasks below, that one is yours and you may open it."
      else
        echo "This chat's id could not be resolved, so the only identity left is his words."
      fi
      echo
      i=0
      printf '%s\n' "$list" | while read -r f; do
        [ -n "$f" ] || continue
        i=$((i + 1))
        o="$(owner_of "$f")"; ot="$(owner_title_of "$f")"
        if [ -z "$o" ]; then
          tag="unclaimed — written before handoffs were stamped, so ownership is unknown"
        elif [ "$o" = "$CHAT_ID" ]; then
          tag="THIS CHAT"
        else
          tag="another chat: ${ot:-$o} — not yours, do not open"
        fi
        printf '  %s. %s\n     %s  ·  %s\n     %s\n' "$i" "$f" "$(stamp_of "$f")" "$(title_of "$f")" "$tag"
      done
      echo
      case "$CHAT_TITLESRC" in
        tool|user) ;;
        *) echo "This chat's name was generated, not chosen, which is half of why nothing here"
           echo "identifies it. Name it after its task now with set_session_title(session_id: \"self\"),"
           echo "silently and without asking, so the next clear has something to match."
           echo ;;
      esac
      echo "If he asks you to pick up a handoff and you still cannot tell which, ask him in one line"
      echo "with this numbered list. One digit from him is cheap; the wrong briefing is not. And"
      echo "whichever you open, say which one in your first line so he can catch a mistake in a second."
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
