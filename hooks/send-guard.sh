#!/usr/bin/env bash
# send-guard.sh, refuses the keystroke that sends a message to a real person, because the prose
# rule keeps failing.
#
# The rule "you never press send, only he does, and only after he wrote «отправь»" is already
# written out in skills/draft-message/SKILL.md, in the output style, and in a project
# CLAUDE.local.md. It has failed three times anyway: on 2026-08-03 a search query was posted to a
# Slack channel of 144 people; on 2026-08-31 a Teams composer edit sent an unapproved message; on
# 2026-09-03 a browser subagent (browser-scout-sonnet), asked only to SEARCH Slack for a word,
# typed into what it believed was the search box, pressed Enter, and posted two messages into a
# real team channel (a_ws_native_aqa) under the owner's name. He deleted them by hand, again.
#
# Three incidents, three different tools (Slack search box, Teams composer, Slack channel), one
# diagnosis: a rule in a prose file that is not loaded at the moment of the keystroke is not a
# rule. So this moves the check to the keystroke itself, the last gate before a browser action or
# an MCP call reaches a real person, and it fires the same way inside a subagent as it does here.
#
# What it refuses:
#   1. A browser input tool (computer / browser_batch / javascript_tool / form_input, on either
#      claude-in-chrome or Claude_Browser) whose action would submit something: a Return/Enter key
#      press, a typed newline, a JS call that submits a form or dispatches a synthetic Enter or
#      posts/sends over the network, or a form value containing a newline.
#   2. Any MCP tool whose name is a send/reply/post/publish/calendar-mutation call, on any server.
#
# 2026-09-07, a second gate, because Enter was only the second half of every incident. The first
# half was text going into a field nobody had verified, and a composer that already holds text can
# still be sent by one mouse click on Send. So putting text into a page is now itself a
# main-conversation action: a `type` action, a form_input with a non-empty string value, either of
# those inside a browser_batch, and javascript that assigns .value / .textContent / .innerHTML /
# .innerText or calls insertText. A subagent that needs to read something navigates to a URL
# instead. The escape is the same shape as `allow` and just as shell-only:
# `send-guard.sh allow-typing <session_id> "<reason>"`, valid 10 minutes.
#
# The only escape hatch is a marker file, and it cannot be created from inside a subagent's own
# input, only by running `send-guard.sh allow <session_id> "<his exact words>"` from the MAIN
# conversation, after he wrote «отправь» / "send it" for that specific message, right here. There
# is deliberately no in-input token: a subagent could type SEND-GUARD-EXEMPT into a text field just
# as easily as it typed Return, so unlike draft-guard and dash-guard this hook has no such bypass.
#
# PreToolUse contract: exit 0 in silence for anything unexpected or unrelated; exit 2 with the
# reason on stderr for a real refusal. State under ~/.claude/state/send-guard/.

set -uo pipefail

STATE="${HOME}/.claude/state/send-guard"
mkdir -p "$STATE" 2>/dev/null || exit 0

# ---- subcommand form: allow / allow-typing / status ------------------------------------------
case "${1:-}" in
  allow)
    sid="${2:-}"; words="${3:-}"
    if [ -z "$sid" ] || [ -z "$words" ]; then
      echo "usage: send-guard.sh allow <session_id> \"<his exact words>\"" >&2
      exit 1
    fi
    : > "${STATE}/${sid}.ok"
    printf '%s %s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$sid" "$words" >> "${STATE}/log"
    echo "send-guard: allow marker set for session $sid, valid 10 minutes"
    exit 0
    ;;
  allow-typing)
    sid="${2:-}"; words="${3:-}"
    if [ -z "$sid" ] || [ -z "$words" ]; then
      echo "usage: send-guard.sh allow-typing <session_id> \"<reason>\"" >&2
      exit 1
    fi
    : > "${STATE}/typing-${sid}"
    printf '%s %s typing: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$sid" "$words" >> "${STATE}/log"
    echo "send-guard: typing marker set for session $sid, valid 10 minutes"
    exit 0
    ;;
  status)
    sid="${2:-}"
    if [ -z "$sid" ]; then
      echo "usage: send-guard.sh status <session_id>" >&2
      exit 1
    fi
    marker="${STATE}/${sid}.ok"
    if [ -f "$marker" ]; then
      now=$(date +%s)
      mt=$(stat -f %m "$marker" 2>/dev/null || stat -c %Y "$marker" 2>/dev/null || echo 0)
      age=$(( now - mt ))
      if [ "$age" -lt 600 ]; then
        echo "send-guard: marker live for session $sid, age ${age}s (expires at 600s)"
      else
        echo "send-guard: marker for session $sid expired, age ${age}s"
      fi
    else
      echo "send-guard: no marker for session $sid"
    fi
    exit 0
    ;;
esac

# ---- PreToolUse hook form -------------------------------------------------------------------
payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

verdict="$(printf '%s' "$payload" | python3 -c '
import json, sys, re

try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)

tool = str(d.get("tool_name") or "")
ti = d.get("tool_input") or {}

BROWSER_TOOLS = {
    "mcp__claude-in-chrome__computer", "mcp__claude-in-chrome__browser_batch",
    "mcp__claude-in-chrome__javascript_tool", "mcp__claude-in-chrome__form_input",
    "mcp__Claude_Browser__computer", "mcp__Claude_Browser__browser_batch",
    "mcp__Claude_Browser__javascript_tool", "mcp__Claude_Browser__form_input",
}

SEND_EXEMPT = {"mcp__ccd_session_mgmt__send_message"}

KEY_SEND_RE = re.compile(r"return|enter", re.I)
JS_SEND_RE = re.compile(
    r"\.submit\(|\.click\(|requestSubmit|KeyboardEvent|keyCode\s*:\s*13"
    r"|key\s*:\s*[\x22\x27]?Enter|dispatchEvent|sendMessage"
    r"|execCommand\(\s*[\x22\x27]insertParagraph",
    re.I,
)
JS_NETWORK_RE = re.compile(r"fetch\(|XMLHttpRequest|sendBeacon", re.I)
JS_METHOD_RE = re.compile(r"POST|PUT|PATCH|DELETE")
JS_TYPE_RE = re.compile(
    r"\.(value|textContent|innerHTML|innerText)\s*\+?=(?!=)"
    r"|execCommand\(\s*[\x22\x27]insertText"
    r"|insertText\s*\(",
    re.I,
)


def action_hit(action):
    """Return a reason string if this single browser action would submit something."""
    if not isinstance(action, dict):
        return None
    inp = action.get("input") if isinstance(action.get("input"), dict) else action
    name = str(inp.get("action") or action.get("action") or action.get("name") or "")

    # computer-style key press
    text = inp.get("text")
    if name == "key" and text and KEY_SEND_RE.search(str(text)):
        return "a key press of Return/Enter (with or without modifiers)"

    # computer-style type with a newline
    if name == "type":
        t = inp.get("text")
        if t and ("\n" in str(t) or "\r" in str(t)):
            return "a typed newline/carriage return"

    # form_input value with a newline
    if "value" in inp:
        v = inp.get("value")
        if v and ("\n" in str(v) or "\r" in str(v)):
            return "a form value containing a newline"

    # javascript_tool text
    for key in ("code", "text", "script", "expression"):
        js = inp.get(key)
        if js:
            js = str(js)
            if JS_SEND_RE.search(js):
                return "javascript that submits a form, clicks, dispatches Enter, or calls sendMessage"
            if JS_NETWORK_RE.search(js) and JS_METHOD_RE.search(js):
                return "javascript that sends a network request (fetch/XHR/sendBeacon with a write method)"
    return None


def typing_hit(action):
    """Return a reason string if this single browser action would put text into the page."""
    if not isinstance(action, dict):
        return None
    inp = action.get("input") if isinstance(action.get("input"), dict) else action
    name = str(inp.get("action") or action.get("action") or action.get("name") or "")

    # computer-style typing
    if name == "type":
        return "a type action that puts text into the page"

    # form_input with a text value (a boolean checkbox value is not typing)
    if "value" in inp:
        v = inp.get("value")
        if isinstance(v, str) and v != "":
            return "a form_input value that puts text into the page"

    # javascript that writes into the DOM
    for key in ("code", "text", "script", "expression"):
        js = inp.get(key)
        if js and JS_TYPE_RE.search(str(js)):
            return "javascript that writes text into the page"
    return None


def scan(fn):
    """Run one detector over the tool input and over every item of a browser_batch."""
    reason = fn(ti)
    if reason:
        return reason
    if isinstance(ti.get("actions"), list):
        for item in ti["actions"]:
            reason = fn(item)
            if reason:
                return reason
    return None


if tool in BROWSER_TOOLS:
    # the send gate is checked over the whole input first, so that a batch holding both a typed
    # word and an Enter is judged by the Enter and never let through by a typing marker
    reason = scan(action_hit)
    if reason:
        print("SEND|" + reason)
        sys.exit(0)
    reason = scan(typing_hit)
    if reason:
        print("TYPE|" + reason)
        sys.exit(0)
    sys.exit(0)

if tool not in SEND_EXEMPT:
    SEND_SUFFIXES = ("__send_message", "__send_email", "__send", "__reply",
                      "__reply_to_thread", "__forward", "__post_message",
                      "__post_comment", "__add_comment", "__create_comment",
                      "__respond_to_event", "__create_event", "__update_event",
                      "__delete_event")
    SEND_MID_RE = re.compile(r"__(send|post|publish)_")
    if tool.endswith(SEND_SUFFIXES) or SEND_MID_RE.search(tool):
        print("SEND|an MCP call that sends, posts, replies to, or publishes something to another person: " + tool)
        sys.exit(0)
' 2>/dev/null)"

[ -n "$verdict" ] || exit 0

# SEND|<reason> is gated by the allow marker, TYPE|<reason> by the typing marker. Anything without
# a kind prefix falls back to the stricter send gate.
kind="${verdict%%|*}"
reason="${verdict#*|}"

sid="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    print(d.get("session_id") or "")
except Exception:
    print("")
' 2>/dev/null)"

# ---- escape hatch: a fresh marker of the matching kind for this session ---------------------
if [ "$kind" = "TYPE" ]; then
  marker="${STATE}/typing-${sid}"
else
  marker="${STATE}/${sid}.ok"
fi

if [ -n "$sid" ] && [ -f "$marker" ]; then
  now=$(date +%s)
  mt=$(stat -f %m "$marker" 2>/dev/null || stat -c %Y "$marker" 2>/dev/null || echo 0)
  age=$(( now - mt ))
  if [ "$age" -lt 600 ]; then
    exit 0
  fi
fi

if [ "$kind" = "TYPE" ]; then
  cat >&2 <<MSG
send-guard: refused $reason. Putting text into a page is a MAIN-conversation action, because
typing into the wrong field was the first half of all three incidents; a subagent reads by
navigating to a URL instead (Jira via its REST URLs, Slack via /client/<team>/<channel>, GitHub
via URLs), never by typing into a search box. Only the main conversation lifts this, with
\`send-guard.sh allow-typing <session_id> "<reason>"\`, valid 10 minutes.
MSG
  exit 2
fi

cat >&2 <<MSG
send-guard: refused $reason. Same pattern that put two unapproved messages into a_ws_native_aqa
on 2026-09-03 after a search-only task pressed Enter in what it thought was a search box.
Only the MAIN conversation may run \`send-guard.sh allow <session_id> "<his exact words>"\`, and
only after he wrote «отправь» / "send it" for this specific message, right here, right now,
quoting his words. A subagent never runs this. For a search box that needs Enter: navigate to a
URL that carries the query, or click the suggestion/result in the dropdown, never press Enter.
MSG
exit 2
