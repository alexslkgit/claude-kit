#!/usr/bin/env bash
# headless-chrome-guard.sh — headless Playwright/Puppeteer runs must not launch the real Chrome.app.
#
# Why this exists. See DECISIONS.md, 2026-09-23: two headless test suites launched with
# `channel: 'chrome'` — the real /Applications/Google Chrome.app — and macOS registered every
# headless launch as a GUI app, so the Dock filled with transient Chrome icons that did nothing on
# click. Not a leak, just noise, but it happened twice the same day because nothing stopped a
# third config from doing the same thing. The fix Playwright already ships is
# `chromium-headless-shell` (`npx playwright install chromium-headless-shell`) — omit `channel`
# entirely and it is used automatically. The real Chrome.app is still correct for headed flows
# that need his logged-in sessions (~/.claude/browser-flows, signin.mjs), so this only blocks the
# combination of a named installed-Chrome channel/executable WITHOUT `headless: false` nearby.
#
# PreToolUse contract: exit 2 blocks and feeds stderr to the model as the reason; every other exit
# lets the tool call through. Never errors out on unexpected input — a hook that breaks the tool
# it is supposed to guard would be worse than the Dock icons.

set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

verdict="$(printf '%s' "$payload" | python3 -c "
import json, re, sys

CHANNEL = re.compile(r\"channel\s*:\s*['\\\"](chrome|chrome-beta|chrome-dev|chrome-canary|msedge)['\\\"]\", re.I)
EXEC_PATH = re.compile(r\"executablePath[^\n]*Google Chrome\.app\", re.I)
HEADLESS_FALSE = re.compile(r\"headless\s*:\s*false\", re.I)

def flags_headless_chrome(text):
    if not text:
        return False
    if not (CHANNEL.search(text) or EXEC_PATH.search(text)):
        return False
    return not HEADLESS_FALSE.search(text)

def bash_headless_chrome(cmd):
    if not cmd:
        return False
    if not re.search(r'playwright', cmd, re.I):
        return False
    return bool(re.search(r'--(browser|channel)[= ]chrome\b', cmd, re.I))

try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit

tool = str(d.get('tool_name') or '')
ti = d.get('tool_input') or {}

if tool == 'Bash':
    if bash_headless_chrome(str(ti.get('command') or '')):
        print('bash')
    raise SystemExit

if tool == 'Write':
    if flags_headless_chrome(str(ti.get('content') or '')):
        print('write')
    raise SystemExit

if tool == 'Edit':
    if flags_headless_chrome(str(ti.get('new_string') or '')):
        print('edit')
    raise SystemExit

if tool == 'MultiEdit':
    edits = ti.get('edits') or []
    if any(flags_headless_chrome(str(e.get('new_string') or '')) for e in edits if isinstance(e, dict)):
        print('multiedit')
    raise SystemExit
" 2>/dev/null)"

[ -n "${verdict:-}" ] || exit 0

cat >&2 <<'EOF'
headless-chrome-guard: this launches the real installed Chrome (channel/executablePath) without
`headless: false` nearby.

Headless automation must omit `channel` and use Playwright's chromium-headless-shell instead
(`npx playwright install chromium-headless-shell`) — every headless launch of the real
/Applications/Google Chrome.app puts a transient Dock icon on his machine, once per launch.

The real Chrome.app stays reserved for headed flows that need his logged-in sessions
(~/.claude/browser-flows, signin.mjs) — those must keep `headless: false`.

See claude-kit DECISIONS.md, 2026-09-23.
EOF
exit 2
