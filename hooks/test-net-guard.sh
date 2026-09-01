#!/usr/bin/env bash
# test-net-guard.sh — fires before a `git push` Bash call, cheap half of the same rule.
#
# The incident: 2026-09-01, a Lufthansa iOS pull request with both approvals, minutes from
# merging, a last "cosmetic" commit rewriting a whole Quick/Nimble spec (499 lines in, 566 out),
# pushed without ever being compiled. CI went red on a PR that was about to be merged blind.
#
# hooks/pre-push-test-net.sh is the expensive half: it fires on every push, in the background,
# and answers "did the full suite pass" by the time the PR is ready to merge — never blocking,
# never asked to be fast. This hook is the cheap half, the one that would have actually caught
# THIS incident in minutes instead of an hour: run only the tests you touched, scoped, before you
# ever push. For Xcode that is `xcodebuild test -only-testing:<Target>/<Class>/<test>` against the
# file(s) the commit changed, not the whole scheme. It cannot know what changed, so it reminds
# rather than checks — a reminder is honest about what this hook can and cannot verify.
#
# Also lazily installs the git-level pre-push hook into whatever repo the push targets, chaining
# after any hook already there (see tools/install-pre-push-hook.sh) — this is what makes an
# existing repo, cloned long before the kit, pick up the safety net the first time it is pushed
# to from a Claude Code session, on any Mac.
#
# Said once per session, not on every push: the point is a nudge before the habit forms, not a
# lecture repeated on every one of however many pushes a session makes.
#
# PreToolUse contract: this NEVER blocks. Exit 0 with stdout adds a note to context; nothing here
# ever returns exit 2. Every unexpected condition falls through silently.

set -uo pipefail

STATE_DIR="$HOME/.claude/test-net-guard"
payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

IFS=$'\t' read -r tool sid cmd cwd <<<"$(printf '%s' "$payload" | python3 -c '
import json,sys
try: d=json.load(sys.stdin)
except Exception: print("x\tx\tx\tx"); raise SystemExit
ti=d.get("tool_input") or {}
print("\t".join([str(d.get("tool_name") or "x"), str(d.get("session_id") or "x"),
                 str(ti.get("command") or "").replace("\t"," ")[:2000],
                 str(d.get("cwd") or "")]))
' 2>/dev/null)"

[ "$tool" = "Bash" ] || exit 0
[ -n "${sid:-}" ] && [ "$sid" != "x" ] || exit 0
[ -n "${cmd:-}" ] || exit 0

printf '%s' "$cmd" | grep -qE '(^|[;&|]|&&)[[:space:]]*git[[:space:]]+push([[:space:]]|$)' || exit 0

mkdir -p "$STATE_DIR" 2>/dev/null || exit 0

# Lazy-install the git-level hook into whichever repo this push targets, chained and idempotent.
[ -n "${cwd:-}" ] || cwd="$PWD"
repo_root="$(cd "$cwd" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "$repo_root" ] && [ -f "$HOME/.claude/tools/install-pre-push-hook.sh" ]; then
  "$HOME/.claude/tools/install-pre-push-hook.sh" "$repo_root" >/dev/null 2>&1 || true
fi

marker="$STATE_DIR/${sid}.said"
[ -e "$marker" ] && exit 0
: > "$marker" 2>/dev/null || true

cat <<'EOF'
test-net-guard: the full suite is already running in the background for this push and will land
in ~/.claude/test-runs before the PR is ready to merge — that part needs nothing from you.

The cheaper half is on you, and it is the one that would have caught the 2026-09-01 incident
(a rewritten spec file pushed unbuilt, approved, minutes from merge, CI red): before pushing a
change that touched tests or the code under them, run ONLY the tests you touched, scoped — for
Xcode that is `xcodebuild test -only-testing:<Target>/<Class>/<test>`, not the whole scheme.
Minutes instead of an hour, and it would have compiled the file that broke.
EOF
exit 0
