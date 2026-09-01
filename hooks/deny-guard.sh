#!/usr/bin/env bash
# Names the tools this project pays for and never calls.
#
# Measured 2026-08-31 (TOKEN-ECONOMY.md, DECISIONS.md A-022 and A-024): a built-in tool listed in
# permissions.deny is dropped from the system prompt entirely, not merely blocked. Four of them,
# Artifact + Workflow + ScheduleWakeup + ReportFindings, were 23 333 tokens of session floor, 29%
# of the floor and about 15% of the whole bill in a project where they are never used. Workflow
# alone is 19 309 chars of description; the two small ones together are under 450 tokens and are
# not worth denying on their own.
#
# This is a hook and not a paragraph for the same reason board-guard.sh is: the rule was written
# down once, and a rule that fires at turn zero and then lives on goodwill is not a rule.
#
# Silent unless the project is established (>= 15 sessions on record) AND has called neither
# Artifact nor Workflow in its own transcripts AND does not already deny them. Output is capped at
# a few lines, because this text is paid for in every request of the session that sees it.

set -uo pipefail

payload="$(cat 2>/dev/null || true)"
cwd="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$cwd" ] && [ -n "$payload" ] && command -v python3 >/dev/null 2>&1; then
  cwd="$(printf '%s' "$payload" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("cwd",""))
except Exception: print("")' 2>/dev/null)"
fi
[ -n "$cwd" ] || cwd="$PWD"
[ -d "$cwd" ] || exit 0

proj_dir="${HOME}/.claude/projects/$(printf '%s' "$cwd" | sed 's|/|-|g')"
[ -d "$proj_dir" ] || exit 0

sessions=$(ls "$proj_dir"/*.jsonl 2>/dev/null | wc -l | tr -d ' ')
[ "$sessions" -ge 15 ] 2>/dev/null || exit 0

denied=""
for f in "$cwd/.claude/settings.json" "$cwd/.claude/settings.local.json"; do
  [ -f "$f" ] || continue
  denied="$denied $(python3 - "$f" <<'PY' 2>/dev/null
import json, sys
try:
    d = json.load(open(sys.argv[1]))
    print(" ".join(d.get("permissions", {}).get("deny", [])))
except Exception:
    pass
PY
)"
done

# Only ever suggest denying a tool this project has not called. The check reads at most the 40
# most recent transcripts, so the cost is bounded whatever the project's history looks like.
recent="$(ls -t "$proj_dir"/*.jsonl 2>/dev/null | head -40)"
unused=""
for tool in Artifact Workflow; do
  case " $denied " in *" $tool "*) continue;; esac
  if [ -n "$recent" ] && printf '%s\n' "$recent" | tr '\n' '\0' \
      | xargs -0 grep -l "\"name\":\"$tool\"" 2>/dev/null | head -1 | grep -q .; then
    continue
  fi
  unused="$unused $tool"
done

mcp_denied=""
case "$denied" in *mcp__*) mcp_denied=1;; esac

[ -n "$unused" ] || [ -n "$mcp_denied" ] || exit 0

echo "deny-guard: this project pays for tool schemas it never calls."
if [ -n "$unused" ]; then
  echo "  Never called here in $sessions sessions:${unused}. A denied built-in leaves the prompt"
  echo "  entirely (Workflow ~4.8k tokens, Artifact ~2.2k, plus their input schemas), every request."
  echo "  python3 ~/Developer/claude-kit/tools/deny-tools.py \"$cwd\"${unused}   (takes effect next session)"
fi
if [ -n "$mcp_denied" ]; then
  echo "  An mcp__ entry in permissions.deny saves nothing: an MCP schema stays in the prompt when"
  echo "  denied. Only switching the connector off removes it."
fi
exit 0
