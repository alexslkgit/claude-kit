#!/usr/bin/env bash
# headless-chrome-guard.test.sh, plain bash test harness for hooks/headless-chrome-guard.sh.
#
# Same convention as send-guard.test.sh: feed a JSON payload on stdin, check the exit code,
# print PASS/FAIL.

set -uo pipefail
HOOK="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/headless-chrome-guard.sh"

pass=0
fail=0

run_case() {
  local desc="$1" expected="$2" payload="$3"
  local actual
  printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>/tmp/headless-chrome-guard-test-stderr.$$
  actual=$?
  if [ "$actual" -eq "$expected" ]; then
    echo "PASS: $desc (exit=$actual)"
    pass=$((pass + 1))
  else
    echo "FAIL: $desc (expected=$expected actual=$actual)"
    cat /tmp/headless-chrome-guard-test-stderr.$$
    fail=$((fail + 1))
  fi
  rm -f /tmp/headless-chrome-guard-test-stderr.$$
}

# ---- must block --------------------------------------------------------------------------------

# 1. Write with channel:'chrome' and headless:true
run_case "Write channel chrome headless:true blocked" 2 \
  '{"session_id":"t1","tool_name":"Write","tool_input":{"file_path":"/tmp/a.ts","content":"await chromium.launch({ channel: '"'"'chrome'"'"', headless: true });"}}'

# 2. Edit with channel: "chrome" and no headless line at all
run_case "Edit channel chrome no headless line blocked" 2 \
  '{"session_id":"t2","tool_name":"Edit","tool_input":{"file_path":"/tmp/b.ts","old_string":"x","new_string":"await chromium.launch({ channel: \"chrome\" });"}}'

# 3. Bash: npx playwright test --browser=chrome
run_case "Bash playwright --browser=chrome blocked" 2 \
  '{"session_id":"t3","tool_name":"Bash","tool_input":{"command":"npx playwright test --browser=chrome"}}'

# 4. Bash: --channel chrome (space form)
run_case "Bash playwright --channel chrome blocked" 2 \
  '{"session_id":"t4","tool_name":"Bash","tool_input":{"command":"npx playwright test --channel chrome"}}'

# 5. MultiEdit with a channel:'chrome' new_string and no headless:false
run_case "MultiEdit channel chrome blocked" 2 \
  '{"session_id":"t5","tool_name":"MultiEdit","tool_input":{"file_path":"/tmp/c.ts","edits":[{"old_string":"x","new_string":"launch({ channel: '"'"'chrome'"'"' })"}]}}'

# 6. executablePath pointing at the real Chrome.app, no headless:false
run_case "executablePath Chrome.app blocked" 2 \
  '{"session_id":"t6","tool_name":"Write","tool_input":{"file_path":"/tmp/d.ts","content":"chromium.launch({ executablePath: \"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome\" })"}}'

# ---- must pass ----------------------------------------------------------------------------------

# 7. channel:'chrome' with headless:false is a legitimate headed flow
run_case "channel chrome with headless:false allowed" 0 \
  '{"session_id":"t7","tool_name":"Write","tool_input":{"file_path":"/tmp/e.ts","content":"await chromium.launch({ channel: '"'"'chrome'"'"', headless: false });"}}'

# 8. plain chromium.launch() with no channel at all
run_case "plain chromium.launch() allowed" 0 \
  '{"session_id":"t8","tool_name":"Write","tool_input":{"file_path":"/tmp/f.ts","content":"await chromium.launch({ headless: true });"}}'

# 9. unrelated file / content
run_case "unrelated file allowed" 0 \
  '{"session_id":"t9","tool_name":"Write","tool_input":{"file_path":"/tmp/g.md","content":"# notes\nnothing here about chrome"}}'

# 10. Bash playwright command without --browser=chrome
run_case "Bash playwright default browser allowed" 0 \
  '{"session_id":"t10","tool_name":"Bash","tool_input":{"command":"npx playwright test"}}'

# 11. empty stdin
run_case "empty stdin exits 0" 0 ""

echo "-----"
echo "pass=$pass fail=$fail"
[ "$fail" -eq 0 ]
