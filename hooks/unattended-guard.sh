#!/usr/bin/env bash
# unattended-guard.sh — refuse an unattended delegated call that nobody is watching.
#
# WHY THIS IS A HOOK AND NOT ONLY PROSE. The rule it enforces is written in
# machine-rules/copilot-delegation.md, and the reason it is also written here is the same reason
# copilot-guard.sh exists: a rule that fires once at turn zero and then depends on goodwill is not a
# rule. On the night of 2026-09-01 a session that had just written the supervisor itself went on to
# dispatch the next call with a bare `nohup copilot -p ... &` anyway, because the supervisor was one
# more thing to remember at the moment of dispatch.
#
# It blocks exactly two shapes and nothing else, so a foreground call, an interactive session, or a
# call already going through the supervisor all pass untouched.
#
#   1. a backgrounded `copilot -p` that does not go through agent-supervise.sh
#   2. a backgrounded xcodebuild/xcrun/simctl run with no marker file to poll
#
# PreToolUse on Bash. Exit 2 blocks the call and returns stderr to the model.

payload="$(cat)"
command -v python3 >/dev/null 2>&1 || exit 0

verdict="$(printf '%s' "$payload" | python3 -c '
import json, re, sys

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

if d.get("tool_name") != "Bash":
    sys.exit(0)
cmd = (d.get("tool_input") or {}).get("command") or ""

# Only unattended dispatches are in scope: something put into the background.
backgrounded = bool(re.search(r"&\s*$", cmd, re.M)) or "nohup" in cmd
if not backgrounded:
    sys.exit(0)

if "agent-supervise.sh" in cmd or "SUPERVISE-OK" in cmd:
    sys.exit(0)

if re.search(r"\bcopilot\b[^\n]*\s-p\b", cmd):
    print("COPILOT")
    sys.exit(0)

if re.search(r"\b(xcodebuild|xcrun|simctl)\b", cmd) and not re.search(r"\.done\b|marker|MARKER", cmd):
    print("LONGJOB")
' 2>/dev/null)"

case "$verdict" in
  COPILOT)
    cat >&2 <<'MSG'
unattended-guard: this backgrounds a `copilot -p` call with nothing watching it.

A `copilot -p` call exits 0 when the API drops mid-flight, so a dead call and a finished call are
the same event from outside. And a call that hits its own permission classifier stays alive
retrying forever while its report file never moves. Both happened on 2026-09-01; the second one
burned thirteen hours.

Dispatch it through the supervisor instead:

  nohup ~/.claude/tools/agent-supervise.sh <brief> <log> <report> 8 25 > <sup.log> 2>&1 &

It restarts the call when it dies AND when its report file stops moving. For that to work the brief
must tell the call to write its report within the first two minutes, and must end by requiring the
last line of the report to be DONE on its own line.

If this really is a call that must not be supervised, put SUPERVISE-OK in the command and say in one
line why.
MSG
    exit 2
    ;;
  LONGJOB)
    cat >&2 <<'MSG'
unattended-guard: this backgrounds a build or simulator run with no marker file to poll.

The harness caps a Bash call at ten minutes and run_in_background does not lift that cap, so a
backgrounded long job is killed at its timeout with no signal that it died. A counted test run was
lost to exactly this on 2026-09-02.

Put the job in a small script that ends by writing its exit code to a marker file, launch that with
nohup, and poll for the marker. The marker is the only thing that separates finished from hung.

If the command genuinely cannot outlast ten minutes, put SUPERVISE-OK in it.
MSG
    exit 2
    ;;
esac

exit 0
