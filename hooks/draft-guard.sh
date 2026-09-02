#!/usr/bin/env bash
# draft-guard.sh — a message to a colleague is not written until the session has loaded what it
# already knows about that colleague.
#
# Why it exists. On 2026-09-02 a session wrote one Slack message to a reviewer and needed three
# corrections from the owner before it was sendable: a paragraph where a line would do, a status
# line that asked nothing of the reader, and an option that would have excluded 67 files of
# production code from analysis. Every one of those rules was already written, 496 lines of them
# in skills/draft-message/SKILL.md, and the reviewer's own entry with a how_to_approach field sat
# in the repo's .claude/team.json. The session opened neither. It composed the draft inline, at
# 205k tokens of context, straight from its own working state.
#
# Same diagnosis as dash-guard and board-guard: a rule in a file that does not get loaded is not
# a rule. So this refuses to let a colleague-facing draft leave the session until, in this
# session, the draft-message skill has been invoked and team.json has been read.
#
# PreToolUse contract: exit 0 in silence for anything unexpected; exit 2 with the reason on stderr
# only for a real refusal. Escape hatch: DRAFT-GUARD-EXEMPT anywhere in the tool input.
set -uo pipefail
exec 3>&2 2>/dev/null
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
state="${HOME}/.claude/state/draft-guard"; mkdir -p "$state" 2>/dev/null || exit 0
verdict="$(printf '%s' "$payload" | python3 -c '
import json, os, re, sys
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
sid = d.get("session_id") or ""
tool = d.get("tool_name") or ""
ti = d.get("tool_input") or {}
blob = json.dumps(ti, ensure_ascii=False)
state = sys.argv[1]
if not sid: sys.exit(0)
loaded = os.path.join(state, sid + ".skill"); team = os.path.join(state, sid + ".team")
if "DRAFT-GUARD-EXEMPT" in blob: sys.exit(0)
# 1. remember that the skill was loaded / the team file was read in this session
if tool == "Skill" and (ti.get("skill") or "").endswith("draft-message"):
    open(loaded, "w").close(); sys.exit(0)
if "team.json" in blob:
    open(team, "w").close(); sys.exit(0)
# 2. does this call produce a colleague-facing draft?
draft = bool(re.search(r"paste\.html|/tasks/draft-[^\s\"]*\.(md|html)", blob)) or \
        (re.search(r"Cmd\+V|Ctrl\+V", blob) and re.search(r"Slack|Teams|композер|composer", blob))
if not draft: sys.exit(0)
missing = []
if not os.path.exists(loaded): missing.append("the draft-message skill was never invoked in this session")
if not os.path.exists(team):   missing.append("<repo>/.claude/team.json was never read in this session")
if missing: print("\n".join(missing))
' "$state")"
[ -n "$verdict" ] || exit 0
{
cat <<MSG
draft-guard: this looks like a message to a real colleague, and it is being written blind.
$verdict

Before the draft: invoke the draft-message skill (496 lines of his corrections, three of them
from the last time this exact thing happened), and read the recipient's entry in
<repo>/.claude/team.json, including its how_to_approach field. Then write it as that file
says: one thing asked, nothing reported, no option you would refuse yourself.

Escape hatch, only for a file that is genuinely not a message to a person: DRAFT-GUARD-EXEMPT.
MSG
} >&3
exit 2
