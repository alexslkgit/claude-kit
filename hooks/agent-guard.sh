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
    print("allow"); raise SystemExit(0)

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
    print("allow" if "TIER-OK" in brief else "untiered:" + (sub or "no type"))
    raise SystemExit(0)
if tier.startswith("fable") or sub.endswith("-fable"):
    print("allow" if "TIER-FABLE:" in brief else "fable:" + sub)
    raise SystemExit(0)
if tier.startswith("opus") or sub.endswith("-opus"):
    print("allow" if "TIER-OPUS:" in brief else "opus:" + sub)
    raise SystemExit(0)
print("count:" + sub)
' 2>/dev/null)"

case "$verdict" in
  untiered:*)
    sub="${verdict#untiered:}"
    cat >&2 <<EOF
agent-guard refused an Agent call with subagent_type "$sub".

The untiered types — general-purpose, claude, Explore, Plan, and a spawn with no type — carry
no model of their own and inherit whatever the main chat is running, which is Opus. Measured
over the month to 2026-08-25 that is 147 runs and 10.3% of the whole limit, at about \$5 to \$7
a run, against \$0.49 a run for the tiered agents.

The roster exists so the tier is chosen once, in the definition: researcher-haiku for a
mechanical lookup, researcher-sonnet or implementer-sonnet as the default, page-writer-sonnet
for any long file, browser-scout-sonnet for anything in a browser, sim-verifier-sonnet for the
simulator. Picking the one that matches the brief costs nothing and prices the run correctly.

TIER-OK anywhere in the brief lets a genuine catch-all through — a task that truly spans tools
no single roster agent has.
EOF
    exit 2
    ;;
  opus:*)
    sub="${verdict#opus:}"
    cat >&2 <<EOF
agent-guard refused an Agent call with subagent_type "$sub" because the brief does not say why
the Opus tier is the one this task needs.

implementer-opus alone was 15.3% of the whole limit in the month to 2026-08-25: 247 runs,
11 934 requests, \$5.04 a run against \$0.70 for implementer-sonnet. researcher-opus was another
4.8%. The gap is not only the price per request — an Opus run is also twice as long, so it is
compounded twice.

The output style already asks for this prediction from the plan's risk section rather than as a
retry after a cheaper run: an architectural boundary, concurrency, persistence or migration
logic, a state machine, a data invariant, or an ambiguous cross-cutting question where a
plausible-looking answer can be quietly wrong. Where none of that is present, the sonnet tier of
the same role is the default and the brief is already written for it.

A line reading TIER-OPUS: <the reason in one sentence> anywhere in the brief lets it through,
and it is worth writing, because the next session reads it.
EOF
    exit 2
    ;;
  fable:*)
    sub="${verdict#fable:}"
    cat >&2 <<EOF
agent-guard refused an Agent call with subagent_type "$sub".

Fable is \$0.327 a request, five times the average and 6.1% of the month for 2.1% of the
requests. It is the tier for a question already judged too hard for Opus — a subtle correctness
problem across several subsystems, a race that survived an Opus pass — not a first attempt.

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
