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
# So the briefing goes out on SessionStart, and the other two only record.
#
# Output is phrased as factual statements rather than commands: imperative text in hook
# output can trip prompt-injection defences and be surfaced to the user instead of used.
#
# Per-project wiring: `.claude/status-dir` inside the repo — one line, an absolute path to
# the directory holding STATUS.md / DECISIONS.md / status.html. The `wrap-up` skill writes it.
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
status_dir=""; dir="$cwd"
for _ in 1 2 3 4 5 6 7 8; do
  if [ -f "$dir/.claude/status-dir" ]; then
    status_dir="$(head -1 "$dir/.claude/status-dir" | /usr/bin/sed 's/[[:space:]]*$//')"
    case "$status_dir" in "~"*) status_dir="$HOME${status_dir#\~}" ;; esac
    break
  fi
  [ "$dir" = "/" ] && break
  dir="$(dirname "$dir")"
done

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

  SessionStart|*)
    if [ -z "$status_dir" ]; then
      cat <<EOF
status-guard: this project has no persistent status files.

No \`.claude/status-dir\` marker exists at or above $cwd, so there is no STATUS.md, no
DECISIONS.md and no status.html for this project, and nothing here survives a context reset.
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
STATUS.md, DECISIONS.md and status.html.
EOF
      exit 0
    fi

    printf 'status-guard: this project keeps its memory in %s.\n' "$status_dir"
    printf 'STATUS.md holds current state and opens with a cold-start section; DECISIONS.md is append-only and holds every decision and dead end with its reason.\n'
    [ -f "$status_dir/status.html" ] && \
      printf 'status.html is the user'\''s own five-minute view of the same thing, and is kept in step with the other two.\n'
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
