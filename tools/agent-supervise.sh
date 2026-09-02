#!/usr/bin/env bash
# agent-supervise.sh — run an unattended delegated call and restart it when it dies or stalls.
#
# WHY THIS EXISTS, in one night's numbers. On 2026-09-01 three `copilot -p` calls were dispatched
# against one checkout to work through the night. At 17:47 the corporate API stopped answering for
# a few minutes and killed all three with ETIMEDOUT. Nothing noticed, because a `copilot -p` call
# exits 0 on an API failure exactly as it does on success. A fourth call, restarted with a
# supervisor that only checked the exit, then stayed ALIVE for thirteen hours retrying variations of
# a command its own permission classifier kept denying, writing to its log the whole time and never
# touching its report file once. Both failures look identical from outside: a process in the list.
#
# So liveness is not progress, and an exit code is not a verdict. This supervises on two signals:
#
#   DONE     the call's report file must end with a line containing exactly DONE, which the brief
#            requires it to write as its last action. Nothing else counts as finished.
#   PROGRESS the report file's modification time must move. A call whose report has not changed in
#            STALL_MINUTES while the process is alive is stuck, and is killed and restarted.
#
# The sentinel is deliberately something the model must write rather than something the runner can
# infer, because the other way these calls lose work is deciding on their own that they are finished.
#
# usage: agent-supervise.sh <brief> <log> <report> [max-attempts] [stall-minutes]
#
# The brief must (a) tell the call to write its report file within the first two minutes and keep
# improving it, and (b) end with the instruction to write DONE on its own line, last. Without (a)
# the stall watchdog fires on a call that is working fine; without (b) nothing ever finishes.

set -u

if [ "$#" -lt 3 ]; then
  echo "usage: agent-supervise.sh <brief> <log> <report> [max-attempts] [stall-minutes]" >&2
  exit 2
fi

BRIEF="$1"; LOG="$2"; REPORT="$3"; MAX="${4:-6}"; STALL="${5:-25}"
PREAMBLE="${SUPERVISE_PREAMBLE:-}"
MODEL="${SUPERVISE_MODEL:-claude-sonnet-5}"
REPO="${SUPERVISE_REPO:-$PWD}"

[ -f "$BRIEF" ] || { echo "SUPERVISOR: brief not found: $BRIEF" >&2; exit 2; }

finished() { [ -f "$REPORT" ] && grep -qx "DONE" "$REPORT"; }

report_age_minutes() {
  [ -f "$REPORT" ] || { echo 999; return; }
  local now mtime
  now=$(date +%s)
  mtime=$(stat -f %m "$REPORT" 2>/dev/null || stat -c %Y "$REPORT" 2>/dev/null || echo 0)
  echo $(( (now - mtime) / 60 ))
}

say() { echo "SUPERVISOR $(date '+%H:%M'): $*"; }

for attempt in $(seq 1 "$MAX"); do
  if finished; then say "already finished before attempt $attempt"; exit 0; fi

  EXTRA=""
  if [ "$attempt" -gt 1 ]; then
    EXTRA="

RESTART NOTICE, ATTEMPT $attempt. A previous attempt at this exact brief did not finish. It was
either killed part-way by a network failure talking to the model API, or it stalled: alive but with
its report file untouched for $STALL minutes, which on this machine means it was retrying a command
its own permission classifier keeps denying. Neither is a mistake you need to fix, and neither is a
reason to change the plan.

Some of the work may already be on disk. Do NOT start over and do NOT revert anything. Read your own
report file $REPORT and the working tree first, establish what is already done, and finish the rest.
Re-check any file you find half-written.

If a command is refused with a permission error, do not retry variations of it. Write down in your
report what was refused, and do the job another way or leave that one step for the caller."
  fi

  say "attempt $attempt/$MAX"
  copilot -p "$( [ -n "$PREAMBLE" ] && [ -f "$PREAMBLE" ] && { cat "$PREAMBLE"; echo; }; cat "$BRIEF"; echo "$EXTRA")" \
    --model "$MODEL" --allow-all-tools -C "$REPO" --add-dir "$REPO" >> "$LOG" 2>&1 &
  child=$!

  # Watch the report file, not the process. A live process saying nothing is the failure mode that
  # cost thirteen hours; only the report moving proves the call is actually doing anything.
  while kill -0 "$child" 2>/dev/null; do
    sleep 60
    if finished; then break; fi
    age=$(report_age_minutes)
    if [ "$age" -ge "$STALL" ]; then
      say "report untouched for ${age}m, killing stalled attempt $attempt"
      kill "$child" 2>/dev/null; sleep 3; kill -9 "$child" 2>/dev/null
      break
    fi
  done
  wait "$child" 2>/dev/null
  code=$?

  if finished; then say "DONE on attempt $attempt"; exit 0; fi
  say "attempt $attempt ended (exit $code) without DONE, waiting 60s"
  sleep 60
done

say "gave up after $MAX attempts, $REPORT never reached DONE"
exit 1
