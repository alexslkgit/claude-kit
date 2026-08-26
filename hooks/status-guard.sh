#!/usr/bin/env bash
# status-guard.sh — keeps a project's status files honest across context resets.
#
# What a hook can and cannot do, stated plainly because it is easy to expect too much:
# it talks through stdout, stderr and its exit code, and it cannot run an agent. So this
# script can NEVER write the status files itself — only the `wrap-up` skill does that.
# What it does is remember that a context reset happened, and tell the next session
# whether the status files can be trusted.
#
# Verified against the hook documentation, 2026-08-03:
#   SessionStart  stdout IS injected as a system message (limit 10k chars);
#                 matchers: startup | resume | clear | compact | fork
#   PreCompact    stdout is DISCARDED, stderr is shown; matchers: manual | auto
#   SessionEnd    stdout is DISCARDED, cannot block, 1.5s shared budget;
#                 the field is `session_end_reason` (clear | resume | logout | ...)
#   UserPromptSubmit  stdout IS added to the context of that turn
# So the briefing goes out on SessionStart, the reminder on UserPromptSubmit, and the other
# two only record.
#
# Why there is a reminder at all: SessionStart speaks once, at turn zero, and is never heard
# from again. On 2026-08-09 a session was told at startup that the project had no status files,
# acknowledged nothing, and ran three hours of design work — 36 decisions — with no STATUS.md,
# no DECISIONS.md and no board, until the user asked. A rule that fires once and depends on
# goodwill for the next hundred turns is not a rule. So the absence is restated as the session
# turns into real work: silent for the first two prompts, then once, then every fifth.
#
# Output is phrased as factual statements rather than commands: imperative text in hook
# output can trip prompt-injection defences and be surfaced to the user instead of used.
#
# Per-project wiring: `.claude/status-dir` inside the repo — one line, an absolute path to
# the directory holding STATUS.md / DECISIONS.md. The third artefact, the board, lives beside
# the task journal instead, at `<repo>/.claude/tasks/<task>.html`. The `wrap-up` skill writes it.
#
# Never fails a session: always exits 0.

set -uo pipefail

GLOBAL_DIR="$HOME/.claude/status-guard"
mkdir -p "$GLOBAL_DIR" 2>/dev/null || true

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

event="$(field hook_event_name)"; [ -n "$event" ] || event="${1:-SessionStart}"
cwd="$(field cwd)";              [ -n "$cwd" ]   || cwd="$PWD"
end_reason="$(field session_end_reason)"
source_kind="$(field source)"
trigger="$(field trigger)"

slug="$(printf '%s' "$cwd" | /usr/bin/tr '/' '_' | /usr/bin/tr -cd 'A-Za-z0-9_.-')"
state="$GLOBAL_DIR/$slug.state"
now_h="$(date '+%Y-%m-%d %H:%M')"
now_e="$(date '+%s')"

# Resolve the project's status directory by walking up from cwd.
status_dir=""; repo_root=""; dir="$cwd"
for _ in 1 2 3 4 5 6 7 8; do
  if [ -f "$dir/.claude/status-dir" ]; then
    status_dir="$(head -1 "$dir/.claude/status-dir" | /usr/bin/sed 's/[[:space:]]*$//')"
    case "$status_dir" in "~"*) status_dir="$HOME${status_dir#\~}" ;; esac
    repo_root="$dir"
    break
  fi
  # A folder that already holds STATUS.md IS the status directory, marker or no marker. Requiring
  # a separate marker file meant one hand-written line stood between a task and its own memory,
  # and on 2026-08-25 ~/Downloads/html-autoswipe had STATUS.md, DECISIONS.md, board.html and
  # HANDOFF.md all sitting in it while this hook announced the project had no status files at all.
  # A shelf never trips this: a shelf holds task folders, it has no STATUS.md of its own.
  if [ -f "$dir/STATUS.md" ]; then
    status_dir="$dir"; repo_root="$dir"
    break
  fi
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done

# A "shelf" is a working directory that is not a project but holds several unrelated tasks,
# each in its own folder with its own STATUS.md — ~/Tasks is the live example. Resolving one
# status_dir there is worse than resolving none: on 2026-08-20 the marker at the shelf level
# pointed at a third task's folder, so a session working on a completely different task was told
# that task's STATUS.md was its memory. List them instead of picking one.
shelf_tasks() {
  found=""
  for d in "$cwd"/*/; do
    [ -d "$d" ] || continue
    name="$(basename "$d")"
    case "$name" in .*|node_modules|_*) continue ;; esac
    if [ -f "$d/STATUS.md" ] || [ -f "$d/.claude/status-dir" ]; then
      board=""
      [ -f "$d/board.html" ] && board=" · board.html"
      [ -f "$d/plan.html" ] && board="$board + plan.html"
      found="$found  $name$board
"
    fi
  done
  printf '%s' "$found"
}

record_break() {
  detail="${end_reason:-${trigger:-${source_kind:-unspecified}}}"
  # Capture how fresh the wrap-up was AT THE MOMENT OF THE BREAK. A wrap-up always
  # finishes before the /clear it hands over to, so its stamp is always older than the
  # break it covers; comparing the two directly reports the correct flow as a failure.
  stamp_at_break=0
  [ -n "$status_dir" ] && [ -f "$status_dir/.wrapup-stamp" ] && \
    stamp_at_break="$(/usr/bin/stat -f %m "$status_dir/.wrapup-stamp" 2>/dev/null || echo 0)"
  {
    printf 'stamp_at_break=%s\n' "$stamp_at_break"
    printf 'last_break_human=%s\n' "$now_h"
    printf 'last_break_epoch=%s\n' "$now_e"
    printf 'last_break_event=%s\n' "$event"
    printf 'last_break_detail=%s\n' "$detail"
    printf 'cwd=%s\n' "$cwd"
  } > "$state" 2>/dev/null || true
  printf '%s\t%s\t%s\t%s\n' "$now_h" "$event" "$detail" "$cwd" >> "$GLOBAL_DIR/breaks.log" 2>/dev/null || true
}

# --- kit drift ------------------------------------------------------------------------------
# A commit to the kit is not a release. The hooks that actually run are the copies under
# ~/.claude/hooks, and something has to install them. On 2026-08-26 a narrowed rule sat in the kit
# from 13:22 while every live session kept running the old broad one until 15:08, and a whole
# measured run was blamed on a rule that was already fixed. Silent when the two agree, one line
# when they do not, so the cost is zero on a clean machine.
if [ "$event" = "SessionStart" ] && [ -d "$HOME/Developer/claude-kit/hooks" ]; then
  drift=""
  for kf in "$HOME/Developer/claude-kit/hooks/"*.sh; do
    [ -f "$kf" ] || continue
    inst="$HOME/.claude/hooks/$(basename "$kf")"
    if [ ! -f "$inst" ]; then
      drift="$drift $(basename "$kf" .sh)(missing)"
    elif ! /usr/bin/cmp -s "$kf" "$inst"; then
      drift="$drift $(basename "$kf" .sh)"
    fi
  done
  if [ -n "$drift" ]; then
    printf 'kit-drift: the hooks running right now differ from the kit:%s.\n' "$drift"
    printf 'A kit commit is not a release. Until `bash ~/Developer/claude-kit/install.sh` runs, the\n'
    printf 'old rule is still in force, so do not report one of these as fixed and do not blame one\n'
    printf 'for a block until you have compared the installed file, not the kit git log.\n'
  fi
fi

case "$event" in

  PreCompact)
    record_break
    printf 'status-guard: the context is about to be compacted. Anything that exists only in this conversation belongs in the project status files first — the wrap-up skill writes them.\n' >&2
    exit 0
    ;;

  SessionEnd)
    case "$end_reason" in
      clear|compact|resume|"") record_break ;;
      *) record_break ;;
    esac
    exit 0
    ;;

  UserPromptSubmit)
    # Count this turn. The counter lives beside the break record and is reset on SessionStart.
    n="$(/usr/bin/sed -n 's/^prompts=//p' "$state" 2>/dev/null | head -1)"; : "${n:=0}"
    n=$((n + 1))
    tmp="$state.tmp.$$"
    { [ -f "$state" ] && /usr/bin/grep -v '^prompts=' "$state" 2>/dev/null
      printf 'prompts=%s\n' "$n"; } > "$tmp" 2>/dev/null && mv "$tmp" "$state" 2>/dev/null
    rm -f "$tmp" 2>/dev/null || true

    speak=0
    [ "$n" -eq 3 ] 2>/dev/null && speak=1
    [ "$n" -gt 3 ] 2>/dev/null && [ "$((n % 5))" -eq 0 ] 2>/dev/null && speak=1
    [ "$speak" -eq 1 ] || exit 0

    if [ -z "$status_dir" ] || [ ! -f "$status_dir/STATUS.md" ]; then
      tasks="$(shelf_tasks)"
      if [ -n "$tasks" ]; then
        cat <<EOF
status-guard: $n prompts in. $cwd is a shelf, not a project: it holds several unrelated tasks,
each keeping its own STATUS.md, DECISIONS.md, board.html and plan.html in its own folder.

$tasks
If the work of this session is one of those, its files are the ones to read and to keep current,
and this session should already be sitting in that folder: call mcp__ccd_directory__change_directory
with its absolute path now, so the next /clear inherits the answer instead of a guess.
If it is a new task, it gets its own folder in the same shape rather than writing into the shelf.
EOF
        exit 0
      fi
      cat <<EOF
status-guard: $n prompts into this session, and this project still has no STATUS.md, no
DECISIONS.md and no board, so nothing decided here survives a context reset. The wrap-up skill
creates all three and writes the marker; it is meant to run when the work starts producing
decisions, not only when the context is about to be cleared. The user has said he wants this
raised while it is still cheap to fix rather than discovered at the end of a session.
EOF
      exit 0
    fi

    # Files exist. Say nothing until enough has happened that they are plausibly behind.
    if [ "$((n % 30))" -eq 0 ] 2>/dev/null; then
      stamp_e=0
      [ -f "$status_dir/.wrapup-stamp" ] && stamp_e="$(/usr/bin/stat -f %m "$status_dir/.wrapup-stamp" 2>/dev/null || echo 0)"
      age=$(( now_e - stamp_e ))
      if [ "$stamp_e" -eq 0 ] 2>/dev/null || [ "$age" -gt 3600 ] 2>/dev/null; then
        printf 'status-guard: %s prompts in and the last wrap-up in %s is over an hour old, so anything settled since then exists only in this conversation.\n' "$n" "$status_dir"
      fi
    fi
    exit 0
    ;;

  SessionStart|*)
    # New session, new turn count.
    if [ -f "$state" ]; then
      tmp="$state.tmp.$$"
      /usr/bin/grep -v '^prompts=' "$state" > "$tmp" 2>/dev/null && mv "$tmp" "$state" 2>/dev/null
      rm -f "$tmp" 2>/dev/null || true
    fi

    if [ -z "$status_dir" ]; then
      tasks="$(shelf_tasks)"
      if [ -n "$tasks" ]; then
        cat <<EOF
status-guard: $cwd is a shelf, not a project. It has no status files of its own, and it should
not have any: it holds several unrelated tasks, and each one keeps its own STATUS.md,
DECISIONS.md, journal.md, board.html and plan.html inside its own folder.

Tasks found here:
$tasks
Whichever of these this session is about, that folder is its memory — read its STATUS.md before
answering. A task that is not on the list is new and gets a folder of its own in the same shape;
the wrap-up skill creates it. Nothing is written into the shelf's own .claude directory.

THEN PIN THIS SESSION TO IT. The moment you know which task this chat is, call
mcp__ccd_directory__change_directory with that folder's absolute path. A shelf cannot identify a
chat: a /clear starts a session with a new id and no memory of which chat it belongs to, so the
next one is left guessing between all of the above. Once the session sits in the task's own
folder, the folder IS the answer and the guess never happens again. He does not care which
directory a session sits in and never will — pinning is your job, not a question for him.
Never infer the task from file recency: the newest files belong to whichever OTHER chat he
cleared last, which points away from this one. Positive evidence only — his words, or the folder.
A one-off with no task (a download, a look at a file) stays here and writes nothing.
EOF
        exit 0
      fi
      cat <<EOF
status-guard: this project has no persistent status files.

No \`.claude/status-dir\` marker exists at or above $cwd, so there is no STATUS.md, no
DECISIONS.md and no board for this project, and nothing here survives a context reset.
The wrap-up skill creates all of them, writes the marker, and adds the auto-memory pointer.
The user has asked to be told about this in one line rather than have work proceed silently
without project memory.
EOF
      exit 0
    fi

    if [ ! -f "$status_dir/STATUS.md" ]; then
      cat <<EOF
status-guard: $status_dir is registered as this project's status directory, but STATUS.md is
not there. This project currently has no memory of previous sessions. The wrap-up skill creates
STATUS.md, DECISIONS.md and the board.
EOF
      exit 0
    fi

    printf 'status-guard: this project keeps its memory in %s.\n' "$status_dir"
    printf 'STATUS.md holds current state and opens with a cold-start section; DECISIONS.md is append-only and holds every decision and dead end with its reason.\n'
    if [ -f "$status_dir/board.html" ]; then
      printf 'This task owns its whole folder: board.html is the page he keeps open, plan.html the chewed instruction beside it, journal.md the evidence trail. Keep all of them in step with STATUS.md.\n'
    else
      printf 'The board is the third artefact: a self-refreshing HTML page per task, at %s/.claude/tasks/<task>.html, kept in step with the other two.\n' "${repo_root:-$cwd}"
    fi
    case "$source_kind" in
      clear)   printf 'This session started immediately after a /clear.\n' ;;
      compact) printf 'This session started immediately after a compaction.\n' ;;
    esac

    if [ -f "$state" ]; then
      brk_h="$(/usr/bin/sed -n 's/^last_break_human=//p' "$state" | head -1)"
      brk_e="$(/usr/bin/sed -n 's/^last_break_epoch=//p' "$state" | head -1)"
      brk_d="$(/usr/bin/sed -n 's/^last_break_detail=//p' "$state" | head -1)"
      stamp_e=0
      [ -f "$status_dir/.wrapup-stamp" ] && stamp_e="$(/usr/bin/stat -f %m "$status_dir/.wrapup-stamp" 2>/dev/null || echo 0)"
      brk_stamp="$(/usr/bin/sed -n 's/^stamp_at_break=//p' "$state" | head -1)"
      : "${brk_stamp:=0}"
      # Covered if a wrap-up ran after the break, or shortly before it — a wrap-up that
      # hands over to a /clear stamps minutes before that clear is recorded.
      covered=0
      [ "$stamp_e" -ge "$brk_e" ] 2>/dev/null && covered=1
      [ "$brk_stamp" -gt 0 ] 2>/dev/null && [ "$((brk_e - brk_stamp))" -le 1800 ] 2>/dev/null && covered=1
      if [ -n "${brk_e:-}" ] && [ "$brk_e" -gt 0 ] 2>/dev/null; then
        if [ "$covered" -eq 1 ] 2>/dev/null; then
          printf 'The last context reset was %s (%s), and a wrap-up ran after it, so these files are current.\n' "$brk_h" "$brk_d"
        else
          cat <<EOF
The last context reset was $brk_h ($brk_d) and no wrap-up ran after it. Whatever the previous
session learned may therefore be missing from these files. Live state — branch, remote position,
PR and ticket status — is worth re-checking with the commands in the cold-start section before
being relied on, and the user has asked to be told in one line when this gap exists.
EOF
        fi
      fi
    fi
    exit 0
    ;;
esac

exit 0
