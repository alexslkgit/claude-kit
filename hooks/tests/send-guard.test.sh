#!/usr/bin/env bash
# send-guard.test.sh, plain bash test harness for hooks/send-guard.sh.
#
# No test convention existed under hooks/ before this, so this is a simple bash script: feed a
# JSON payload on stdin, check the exit code, print PASS/FAIL. Uses throwaway session ids under
# ~/.claude/state/send-guard/ and cleans them up on exit.

set -uo pipefail
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/send-guard.sh"
STATE="${HOME}/.claude/state/send-guard"
mkdir -p "$STATE"

pass=0
fail=0

run_case() {
  local desc="$1" expected="$2" payload="$3"
  local actual
  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>/tmp/send-guard-test-stderr.$$
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $desc (exit=$actual)"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected=$expected actual=$actual)"
    cat /tmp/send-guard-test-stderr.$$
    fail=$((fail + 1))
  fi
  rm -f /tmp/send-guard-test-stderr.$$
}

cleanup() {
  rm -f "${STATE}"/send-guard-test-*.ok "${STATE}"/typing-send-guard-test-*
}
trap cleanup EXIT

# 1. key Return refused
run_case "key Return refused" 2 \
  '{"session_id":"send-guard-test-1","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"key","text":"Return"}}'

# 2. key Return allowed with a fresh marker
: > "${STATE}/send-guard-test-2.ok"
run_case "key Return allowed with fresh marker" 0 \
  '{"session_id":"send-guard-test-2","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"key","text":"Return"}}'

# 3. key Return refused with a marker older than 10 minutes
: > "${STATE}/send-guard-test-3.ok"
touch -t "$(date -v-11M '+%Y%m%d%H%M' 2>/dev/null || date -d '-11 minutes' '+%Y%m%d%H%M')" "${STATE}/send-guard-test-3.ok" 2>/dev/null
run_case "key Return refused with stale marker" 2 \
  '{"session_id":"send-guard-test-3","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"key","text":"Return"}}'

# 4. type with newline refused
run_case "type with newline refused" 2 \
  '{"session_id":"send-guard-test-4","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"type","text":"hello\nworld"}}'

# 5. type without newline refused by the typing gate added 2026-09-07 (was allowed before it)
run_case "type without newline refused" 2 \
  '{"session_id":"send-guard-test-5","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"type","text":"hello world"}}'

# 6. left_click allowed
run_case "left_click allowed" 0 \
  '{"session_id":"send-guard-test-6","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"left_click","ref":"123"}}'

# 7. browser_batch with a nested key Return refused
run_case "browser_batch nested key Return refused" 2 \
  '{"session_id":"send-guard-test-7","tool_name":"mcp__claude-in-chrome__browser_batch","tool_input":{"actions":[{"name":"computer","input":{"action":"left_click","ref":"1"}},{"name":"computer","input":{"action":"key","text":"Enter"}}]}}'

# 8. javascript_tool with form.submit() refused
run_case "javascript_tool form.submit() refused" 2 \
  '{"session_id":"send-guard-test-8","tool_name":"mcp__claude-in-chrome__javascript_tool","tool_input":{"code":"document.querySelector(\"form\").submit()"}}'

# 9. javascript_tool reading document.title allowed
run_case "javascript_tool reading document.title allowed" 0 \
  '{"session_id":"send-guard-test-9","tool_name":"mcp__claude-in-chrome__javascript_tool","tool_input":{"code":"document.title"}}'

# 10. Gmail-style send tool refused
run_case "gmail-style send_message refused" 2 \
  '{"session_id":"send-guard-test-10","tool_name":"mcp__x__send_message","tool_input":{"to":"a@b.com","body":"hi"}}'

# 11. ccd_session_mgmt send_message allowed (exempt: session-to-session, not a person)
run_case "ccd_session_mgmt send_message allowed" 0 \
  '{"session_id":"send-guard-test-11","tool_name":"mcp__ccd_session_mgmt__send_message","tool_input":{"to":"session-x","body":"hi"}}'

# 12. unrelated tool (Bash) allowed silently
run_case "unrelated Bash tool allowed" 0 \
  '{"session_id":"send-guard-test-12","tool_name":"Bash","tool_input":{"command":"ls"}}'

# 13. empty stdin exits 0
run_case "empty stdin exits 0" 0 ""

# ---- typing gate, 2026-09-07 -----------------------------------------------------------------

# 14. type allowed with a fresh typing marker
: > "${STATE}/typing-send-guard-test-14"
run_case "type allowed with fresh typing marker" 0 \
  '{"session_id":"send-guard-test-14","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"type","text":"hello world"}}'

# 15. a typing marker never lifts a send-class refusal
: > "${STATE}/typing-send-guard-test-15"
run_case "key Return still refused with typing marker" 2 \
  '{"session_id":"send-guard-test-15","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"key","text":"Return"}}'

# 16. an allow marker never lifts the typing gate
: > "${STATE}/send-guard-test-16.ok"
run_case "type still refused with allow marker only" 2 \
  '{"session_id":"send-guard-test-16","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"type","text":"hello world"}}'

# 17. a batch holding a typed word and an Enter is judged by the Enter, not by the typing marker
: > "${STATE}/typing-send-guard-test-17"
run_case "batch type plus Enter refused with typing marker" 2 \
  '{"session_id":"send-guard-test-17","tool_name":"mcp__claude-in-chrome__browser_batch","tool_input":{"actions":[{"name":"computer","input":{"action":"type","text":"hi"}},{"name":"computer","input":{"action":"key","text":"Enter"}}]}}'

# 18. form_input with text refused, empty and boolean values allowed
run_case "form_input with a text value refused" 2 \
  '{"session_id":"send-guard-test-18","tool_name":"mcp__claude-in-chrome__form_input","tool_input":{"ref":"1","value":"abc"}}'
run_case "form_input with an empty value allowed" 0 \
  '{"session_id":"send-guard-test-18","tool_name":"mcp__claude-in-chrome__form_input","tool_input":{"ref":"1","value":""}}'
run_case "form_input with a checkbox value allowed" 0 \
  '{"session_id":"send-guard-test-18","tool_name":"mcp__claude-in-chrome__form_input","tool_input":{"ref":"1","value":true}}'

# 19. javascript writing into the DOM refused, reading allowed
run_case "javascript assigning .value refused" 2 \
  '{"session_id":"send-guard-test-19","tool_name":"mcp__claude-in-chrome__javascript_tool","tool_input":{"code":"document.querySelector(\"input\").value = \"hi\""}}'
run_case "javascript execCommand insertText refused" 2 \
  '{"session_id":"send-guard-test-19","tool_name":"mcp__claude-in-chrome__javascript_tool","tool_input":{"code":"document.execCommand(\"insertText\", false, \"hi\")"}}'
run_case "javascript comparing .value allowed" 0 \
  '{"session_id":"send-guard-test-19","tool_name":"mcp__claude-in-chrome__javascript_tool","tool_input":{"code":"document.activeElement.value === \"hi\""}}'
run_case "javascript reading innerText allowed" 0 \
  '{"session_id":"send-guard-test-19","tool_name":"mcp__claude-in-chrome__javascript_tool","tool_input":{"code":"document.body.innerText.slice(0, 100)"}}'

# 20. browser_batch carrying a type action refused
run_case "browser_batch nested type refused" 2 \
  '{"session_id":"send-guard-test-20","tool_name":"mcp__claude-in-chrome__browser_batch","tool_input":{"actions":[{"name":"computer","input":{"action":"screenshot"}},{"name":"computer","input":{"action":"type","text":"hi"}}]}}'

# 21. a typing marker older than 10 minutes does not lift the gate
: > "${STATE}/typing-send-guard-test-21"
touch -t "$(date -v-11M '+%Y%m%d%H%M' 2>/dev/null || date -d '-11 minutes' '+%Y%m%d%H%M')" "${STATE}/typing-send-guard-test-21" 2>/dev/null
run_case "type refused with stale typing marker" 2 \
  '{"session_id":"send-guard-test-21","tool_name":"mcp__claude-in-chrome__computer","tool_input":{"action":"type","text":"hello world"}}'

echo "-----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
