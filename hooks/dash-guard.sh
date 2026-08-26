#!/usr/bin/env bash
# dash-guard.sh — refuses an em dash in anything headed for a human being.
#
# Why this exists as a hook and not as prose. The ban was already written down, in his own words,
# on 2026-08-13: «пиши как человек, какого хрена я там вижу длинные тире». It lives in
# skills/draft-message/SKILL.md, and that file only enters a session when the draft-message skill
# is actually invoked. Every draft written without invoking it — which is most of them, because
# "reply to her" does not feel like a skill — never saw the rule. On 2026-08-19 he deleted the
# dashes out of a Teams composer by hand and said he had asked about five hundred times in half a
# year. That is the signature of a rule living in a file nobody loads.
#
# So the check moves to the keystroke. The last gate before text reaches a person is the typing
# call itself, and it fires the same way inside a subagent as it does here.
#
# What it blocks:
#   · typing or form-filling in a browser, always — a composer, a Jira comment, a PR reply
#   · an Agent brief or a cross-session message that carries text to be typed for a person
#   · writing a draft file under .claude/tasks (names containing draft, dm, reply, comment, message)
#
# What it ignores: status files, decisions, boards, plans, code, and this session's own prose to
# him. Those are not messages to colleagues and the dash is not a tell there.
#
# PreToolUse contract: exit 2 blocks and feeds stderr to the model; anything else lets the call
# through. Every unexpected condition exits 0 — this must never be the reason a session cannot work.

set -uo pipefail
payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

verdict="$(printf '%s' "$payload" | python3 -c '
import json,sys,re
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
tool=str(d.get("tool_name") or "")
ti=d.get("tool_input") or {}
DASH=re.compile("[—–―]")

def hit(where,text):
    if text and DASH.search(str(text)):
        print(where); raise SystemExit

# 1. keystrokes into a page: the last gate before a person reads it
if tool.endswith("__computer") and str(ti.get("action") or "")=="type":
    hit("keystrokes into the page",ti.get("text"))
if tool.endswith("__form_input"):
    hit("a form field",ti.get("value"))

# 2. a brief or a peer message carrying text meant for a person.
# The trigger has to mean "compose something a person will read", not merely mention one of those
# words. A bare "draft" or "Teams" anywhere in a long analytical brief matched everything: measured
# 2026-08-26, 26 of the 30 blocks this hook has ever issued were Agent briefs with no message in
# them at all, and the remaining 4 were session-to-session notes. It has never once caught a
# message to a human, because chat prose is not a tool call.
if tool in ("Agent","SendMessage"):
    body=str(ti.get("prompt") or ti.get("message") or "")
    compose=r"(draft|write|compose|send)\s+(a|an|the|this|it)?\s*(message|reply|email|comment|note|dm|answer)\b"
    place=r"reply box|Teams composer|type exactly|send (it|this) to|post (it|this) (to|in)|jira comment|pr reply|slack message"
    if re.search(compose,body,re.I) or re.search(place,body,re.I):
        hit("the message text inside this brief",body)

# 3. a draft file
if tool in ("Write","Edit"):
    p=str(ti.get("file_path") or "")
    if re.search(r"draft|-dm-|reply|comment|message",p,re.I) and "/.claude/tasks/" in p:
        hit("this draft file",ti.get("content") or ti.get("new_string"))
' 2>/dev/null)"

[ -n "${verdict:-}" ] || exit 0

cat >&2 <<EOF
dash-guard: there is a long dash in $verdict.

He has asked for this more times than anyone should have to. His words, 2026-08-13:
«пиши как человек, какого хрена я там вижу длинные тире». On 2026-08-19 he deleted them out of a
Teams composer by hand and asked why the rule keeps failing. It keeps failing because it was
written only in skills/draft-message/SKILL.md, which most drafts never load.

Replace every — – ― with a comma, a colon, a full stop, or two sentences. Then call again.

While you are rewriting, the rest of the same tell: no rule-of-three lists, no "not only X but Y",
no "it's worth noting", no summary sentence that repeats what was just said, no greeting-plus-recap
opening. Short sentences, his register, one emoji if it fits.
EOF
exit 2
