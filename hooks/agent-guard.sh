#!/usr/bin/env bash
# agent-guard.sh — makes the tier of a subagent a decision instead of a reflex.
#
# Measured 26 July – 25 August 2026 over 1 848 transcripts, priced per request from `usage`,
# with sidechain rows counted for the first time. Subagents are $3 138 of the $8 145 month,
# 39% of the whole limit, across 1 251 runs. Where that money actually sits:
#
#   implementer-opus     247 runs  11 934 req  $1 246   15.3% of the month   $5.04 a run
#   researcher-opus      156 runs   4 500 req  $  393    4.8%                $2.52 a run
#   general-purpose       93 runs   3 964 req  $  470    5.8%                $5.05 a run
#   claude (catch-all)    54 runs   2 992 req  $  369    4.5%                $6.83 a run
#   every sonnet tier    484 runs   9 377 req  $  235    2.9%                $0.49 a run
#
# Two facts follow. First, the untiered types — general-purpose, claude, Explore, Plan, and a
# spawn with no type at all — are 10.3% of the limit on their own, because none of them carries
# a `model:` and every one of them inherits whatever the main chat is running. On 2026-08-25
# every agent in ~/Developer/claude-kit/agents/ was checked and all fourteen do carry an explicit
# `model:`; the earlier theory that the kit was leaking Opus through missing fields was wrong.
# The leak is which type gets spawned, not how it is defined.
#
# Second, implementer-opus is the single largest line in the audit after Bash, and it is not
# expensive per request — it is expensive because an Opus implementation run is twice as long as
# a Sonnet one and each request under it costs four times as much. The output style already says
# to predict that tier from the plan's risk section rather than reaching for it. This hook turns
# that sentence into a stop.
#
# Nothing here is a dead end: every refusal names a marker that lets a genuine case through, for
# the same reason copilot-guard has COPILOT-EXEMPT. A block with no way past it teaches the next
# session to route around the hook instead of to think.
#
# Output is phrased as statements, never imperatives: imperative text from a hook can trip
# prompt-injection defences and be shown to the user instead of used.

# 2026-09-06, remeasured on usage fields over 4.14 weeks (research/audit-2026-09-05 in the
# html-autoswipe task): his rule is that Sonnet and Haiku run only where a wrong result is caught
# mechanically, so every cheap-tier brief needs a CHECK: line; researcher-opus and
# browser-scout-opus are the defaults for their roles and need no TIER-OPUS; the untiered types
# are refused outright (226 runs, 25% of subagent spend, 33 of 53 nested spawns). Nesting is real:
# a subagent whose tools include Agent spawns its own, and this hook fires inside subagents too.

set -uo pipefail

command -v python3 >/dev/null 2>&1 || exit 0

STATE_DIR="$HOME/.claude/agent-guard"
mkdir -p "$STATE_DIR" 2>/dev/null || true

payload="$(cat 2>/dev/null || true)"
sid="$(printf '%s' "$payload" | /usr/bin/sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
: "${sid:=nosession}"
state="$STATE_DIR/$(printf '%s' "$sid" | /usr/bin/tr -cd 'A-Za-z0-9_.-').state"

verdict="$(printf '%s' "$payload" | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("allow"); raise SystemExit(0)
if d.get("tool_name") != "Agent":
    print("allow"); raise SystemExit(0)
ti = d.get("tool_input") or {}
brief = str(ti.get("prompt", "")) + " " + str(ti.get("description", ""))
sub = str(ti.get("subagent_type", "") or "")
model = str(ti.get("model", "") or "")

# An explicit cheap model on the call overrides the type: what is being paid for is the model.
if model in ("sonnet", "haiku"):
    print("allow" if "CHECK:" in brief else "check:" + (sub or model)); raise SystemExit(0)

# Resolve the tier from the definition on disk, not from the name. Keying on a "-opus"
# suffix let every project-local agent straight through: scan-reader, a repo agent defined
# with model: opus and named nothing in particular, was 1.3% of the limit over 65 runs and
# this hook waved all 65 past. The name is a label; the file is the fact.
import os, re
def declared_model(name):
    if not name: return None
    for base in (os.path.join(str(d.get("cwd") or ""), ".claude", "agents"),
                 os.path.expanduser("~/.claude/agents"),
                 os.path.expanduser("~/Developer/claude-kit/agents")):
        f = os.path.join(base, name + ".md")
        if os.path.isfile(f):
            try: head = open(f, errors="ignore").read(4000)
            except Exception: continue
            m = re.search(r"^model:\s*([A-Za-z0-9._-]+)", head, re.M)
            return (m.group(1).lower() if m else "")   # "" = defined but declares no model
    return None                                        # no definition found at all

untiered = ("general-purpose", "claude", "Explore", "Plan", "")
decl = declared_model(sub)
tier = model or decl or ""

if sub in untiered or decl == "" or decl is None:
    # No definition, or a definition that names no model: the run inherits the main chat.
    print("untiered:" + (sub or "no type"))
    raise SystemExit(0)
if tier.startswith("fable") or sub.endswith("-fable"):
    print("allow" if "TIER-FABLE:" in brief else "fable:" + sub)
    raise SystemExit(0)
# Roles with no cheaper sibling, and the two roles where Opus is the default since 2026-09-06,
# need no justification; only implementer-opus still names the design risk.
opus_default = ("researcher-opus", "browser-scout-opus", "planner-opus", "verifier-opus",
                "marketer-opus", "sense-check-opus")
if tier.startswith("opus") or sub.endswith("-opus"):
    print("allow" if (sub in opus_default or "TIER-OPUS:" in brief) else "opus:" + sub)
    raise SystemExit(0)
if tier in ("sonnet", "haiku") or sub.endswith(("-sonnet", "-haiku")):
    print("allow" if "CHECK:" in brief else "check:" + sub)
    raise SystemExit(0)
print("count:" + sub)
' 2>/dev/null)"

case "$verdict" in
  untiered:*)
    sub="${verdict#untiered:}"
    cat >&2 <<EOF
agent-guard refused an Agent call with subagent_type "$sub".

The untiered types, general-purpose, claude, Explore, Plan and a spawn with no type, carry no
model, no turn cap and no tools list of their own: they inherit Opus and every tool, including
Agent, so they nest without limit. Measured over the 4.14 weeks to 2026-09-05 they were 226 runs
and 25% of all subagent spend, and 33 of the 53 nested spawns that month came from them. Since
2026-09-06 nothing lets them through.

Every task has a roster type: researcher-opus for anything to find out, browser-scout-opus for
anything in a browser, implementer-opus or implementer-sonnet for edits, page-writer-sonnet for a
long file, sim-verifier-sonnet for the simulator. A task that spans two of those is two spawns,
or one Opus parent that delegates through its own Agent allowlist.
EOF
    exit 2
    ;;
  check:*)
    sub="${verdict#check:}"
    cat >&2 <<EOF
agent-guard refused a cheap-tier Agent call ("$sub") because the brief has no CHECK: line.

His rule, written down 2026-09-06: Sonnet and Haiku only where a wrong result is caught by a
mechanical check, never where the report would be consumed as a fact. Measured over the month to
2026-09-05, at most 6% of Sonnet runs were redone on Opus, against 16% of Opus runs redone on
Opus, so the cheap tier is not the expensive one in tokens; what it cannot buy is trust in an
unchecked answer.

A line reading CHECK: <what catches a wrong result> anywhere in the brief lets it through. Real
checks: the build and the tests, a grep of the same pattern, the PNG path the report must name,
the quoted page text, a page he reads himself. Where no such check exists the task belongs to the
Opus sibling of the role, which for research and browsing needs no justification at all.
EOF
    exit 2
    ;;
  opus:*)
    sub="${verdict#opus:}"
    cat >&2 <<EOF
agent-guard refused an Agent call with subagent_type "$sub" because the brief does not say why
the Opus tier is the one this step needs.

implementer-opus was 275 meter-% a week over the 4.14 weeks to 2026-09-05, 307 runs at 3.7 a
run against 0.68 for implementer-sonnet, and 39% of all subagent spend. Implementation is the one
role where the cheap tier has a real check, the build and the tests, so a decided step runs on
implementer-sonnet and only design risk sends it here: an architectural boundary, concurrency,
persistence or migration logic, a state machine, a data invariant, an edit where a
plausible-looking version can be quietly wrong.

A line reading TIER-OPUS: <the reason in one sentence> anywhere in the brief lets it through.
EOF
    exit 2
    ;;
  fable:*)
    sub="${verdict#fable:}"
    cat >&2 <<EOF
agent-guard refused an Agent call with subagent_type "$sub".

Fable is the tier for a question already judged too hard for Opus, a subtle correctness problem
across several subsystems, a race that survived an Opus pass, not a first attempt.

A line reading TIER-FABLE: <what Opus is expected to miss here> anywhere in the brief lets it
through.
EOF
    exit 2
    ;;
esac

# Allowed. Count the cheap runs only so the note below reports something true.
n="$(/usr/bin/sed -n 's/^runs=//p' "$state" 2>/dev/null | head -1)"; : "${n:=0}"
n=$((n + 1))
printf 'runs=%s\n' "$n" > "$state" 2>/dev/null || true
exit 0
