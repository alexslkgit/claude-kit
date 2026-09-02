#!/usr/bin/env bash
# compact-steer.sh — a PreCompact hook. Tells the compaction what must survive the summary.
#
# 2026-09-02: the cut moved from a manual /clear at 200k to an automatic compaction at 300k
# (context-guard.sh / handoff-auto.sh HARD=300000, CLAUDE_CODE_AUTO_COMPACT_WINDOW=313000). A
# compaction is now routine rather than something the user asks for, so what the summary keeps
# matters more than it used to: STATUS.md and DECISIONS.md carry the durable record, but the
# summary itself is what the model has in hand the instant it resumes, before it has re-read
# anything from disk.
#
# PreCompact receives {trigger: manual|auto, custom_instructions} and its stdout is appended to
# the compaction instructions, so this prints a short keep/drop list rather than doing anything
# itself — it cannot write files or block the compaction, only steer what the summary preserves.
#
# Never fails a session: always exits 0, and stays silent whenever it cannot read its input.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

trigger="$(field trigger)"; [ -n "$trigger" ] || trigger="unspecified"

cat <<EOF
compact-steer: this compaction is $trigger. Preserve verbatim in the summary:
  - the board URL (or path), if one was opened or written this session
  - the task folder path this session is working in
  - every decision id mentioned (A-xxx or similar), by id and one line of what it decided
  - every file path edited this session, whether or not the edit is finished
  - every number that was measured this session (counts, percentages, costs, thresholds) — the
    exact figure, not a rounded restatement
  - all open questions, worded as questions, not folded into a conclusion
  - which subagent, if any, is still running and what it was asked to do

Drop from the summary: full tool outputs, file bodies, diffs, screenshots, and anything already
written to STATUS.md or DECISIONS.md on disk — those are re-read from disk, not carried in text.
EOF

exit 0
