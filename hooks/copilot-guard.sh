#!/usr/bin/env bash
# copilot-guard.sh — keeps paid work on the employer's Copilot budget instead of the
# user's personal Claude subscription, on machines that actually have that licence.
#
# Why this exists as a hook and not as prose. The rule "delegate bulk work to
# `copilot -p`" lived only in ~/.claude/CLAUDE.md, read once at turn zero. On 2026-08-11
# a session ran a full ticket — repository reads, greps, two test runs, a rebase — without
# a single Copilot call, and the user noticed from the credit meter, not from the work.
# The one rule that session did follow all day was the status-file rule, and the only
# difference is that status-guard.sh restates it as a system turn while the work happens.
# A rule that fires once and then depends on goodwill for a hundred turns is not a rule.
#
# What it does, in order of bluntness:
#   SessionStart      states the rule once, with the check that proves it applies here.
#   UserPromptSubmit  restates it early (prompt 2 and 5) and then every sixth prompt.
#   PreToolUse:Agent  blocks the research and implementation tiers outright — those are
#                     exactly the briefs the machine rule sends to Copilot — and names
#                     the escape hatch instead of pretending there is never a reason.
#
# The escape hatch is real and deliberate: a brief containing COPILOT-EXEMPT is allowed
# through. Copilot genuinely cannot serve every case — structured output the orchestrator
# will parse, work that needs this conversation's context, a tool Copilot has no access
# to — and a block with no way past it teaches the next session to route around the hook
# rather than to think.
#
# Silent on any machine without the licence: no `copilot` on PATH, or no lhg.ghe.com in
# ~/.copilot/config.json, and this script says nothing at all and blocks nothing.
#
# Output is phrased as factual statements rather than commands: imperative text in hook
# output can trip prompt-injection defences and be surfaced to the user instead of used.
#
# Never fails a session: exits 0 everywhere except the deliberate PreToolUse block.

set -uo pipefail

# ---- Does this machine have the corporate licence at all? -------------------------
# The bridge, not the endpoint string, is what proves this machine is the right one.
# Until 2026-08-17 the check was `grep lhg.ghe.com ~/.copilot/config.json`, and when the
# Copilot CLI re-authenticated the same corporate account against https://github.com that
# string vanished, the hook went silent on every event, and a whole day of repository
# reading was billed to the personal plan with nothing ever saying so. A precondition that
# fails closed and silent is worse than no precondition.
command -v copilot >/dev/null 2>&1 || exit 0
[ -x "$HOME/bin/copilot-ask" ] || exit 0

# Corporate login present? Same account under either host, or the old enterprise endpoint.
CORP_OK=0
/usr/bin/grep -qE "lhg\.ghe\.com|OSlobodianiuk_wsi" "$HOME/.copilot/config.json" 2>/dev/null && CORP_OK=1

MODEL="claude-sonnet-5"
GLOBAL_DIR="$HOME/.claude/copilot-guard"
mkdir -p "$GLOBAL_DIR" 2>/dev/null || true

payload="$(cat 2>/dev/null || true)"
field() { printf '%s' "$payload" | /usr/bin/sed -n "s/.*\"$1\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1; }

event="$(field hook_event_name)"; [ -n "$event" ] || event="${1:-SessionStart}"
cwd="$(field cwd)";              [ -n "$cwd" ]   || cwd="$PWD"

slug="$(printf '%s' "$cwd" | /usr/bin/tr '/' '_' | /usr/bin/tr -cd 'A-Za-z0-9_.-')"
state="$GLOBAL_DIR/$slug.state"

case "$event" in

  PreToolUse)
    # Two things matter here: the Agent tool, and reading the repository by hand.
    # The second was the bigger leak — an Agent block teaches nothing when the session
    # simply greps the repo itself, one cheap-looking call at a time, all on the personal
    # plan. Added 2026-08-17 after a session made fourteen local reads and one Copilot call.
    command -v python3 >/dev/null 2>&1 || exit 0
    verdict="$(printf '%s' "$payload" | python3 -c '
import json, re, sys
try:
    d = json.load(sys.stdin)
except Exception:
    print("allow"); raise SystemExit(0)
tool = d.get("tool_name")
ti = d.get("tool_input") or {}

# ---- hand-reading a work repository -------------------------------------------------
# Only inside the ws-* checkouts: the kit, the home directory and the status files are
# this session own business and stay free.
if tool in ("Bash", "Grep", "Glob"):
    blob = json.dumps(ti)
    if "COPILOT-EXEMPT" in blob:
        print("allow"); raise SystemExit(0)
    cwd = str(d.get("cwd") or "")
    in_repo = "/ws-" in blob or "/ws-" in cwd
    if tool in ("Grep", "Glob"):
        reading = in_repo
    else:
        cmd = str(ti.get("command", ""))
        reading = bool(in_repo and re.search(
            r"\b(grep|rg|ag|find|cat|head|tail|awk|wc|sed -n|git log|git show|git blame)\b", cmd))
    print("read" if reading else "allow"); raise SystemExit(0)

if tool != "Agent":
    print("allow"); raise SystemExit(0)
prompt = str(ti.get("prompt", ""))
if "COPILOT-EXEMPT" in prompt:
    print("allow"); raise SystemExit(0)
sub = str(ti.get("subagent_type", "") or "")
# The tiers whose whole job is fetch / read / search / build / report — the ones the
# machine rule routes to the employer-funded licence. Judgement tiers are left alone:
# planner-opus and verifier-opus decide things the orchestrator acts on directly.
billable = ("researcher-", "implementer-")
if sub.startswith(billable) or sub in ("Explore", "general-purpose", "claude", "Plan", ""):
    print("block:" + (sub or "default"))
else:
    print("allow")
' 2>/dev/null)"
    case "$verdict" in
      read)
        r="$(/usr/bin/sed -n 's/^reads=//p' "$state" 2>/dev/null | head -1)"; : "${r:=0}"
        r=$((r + 1))
        tmp="$state.tmp.$$"
        { [ -f "$state" ] && /usr/bin/grep -v '^reads=' "$state" 2>/dev/null
          printf 'reads=%s\n' "$r"; } > "$tmp" 2>/dev/null && mv "$tmp" "$state" 2>/dev/null
        rm -f "$tmp" 2>/dev/null || true

        # Three free reads a session: checking one fact before answering is not the leak.
        # The leak is the fourth, tenth and fourteenth, which together are a research task
        # that belongs on the employer's budget.
        [ "$r" -le 3 ] 2>/dev/null && exit 0
        cat >&2 <<EOF
copilot-guard: this is hand-read number $r of a work repository in this session.

Three are free because checking a single fact is not research. Past that it is research,
and research on this Mac is paid for by the employer, not by the personal Claude plan:

  ~/bin/copilot-ask -C <repo> "<exact files, exact question>; answer in max N lines"

Brief it the way a subagent gets briefed — name the files, name the question, demand a
bounded answer, take the conclusion and never the raw material. One whole unit of work per
call, because each call carries its own ~28k-token system prompt.

COPILOT-EXEMPT anywhere in the command lets a genuine exception through: reading a file
this conversation must quote verbatim, or a check whose output the next edit depends on
character for character.
EOF
        exit 2
        ;;
      block:*)
        sub="${verdict#block:}"
        cat >&2 <<EOF
copilot-guard blocked an Agent call with subagent_type "$sub".

This Mac carries a corporate GitHub Copilot licence on the GitHub Enterprise account
oleksandr-slobodianiu-sp-lhg at lhg.ghe.com, with a monthly AI-credit budget paid by the
employer. The Agent tool bills the user's personal Claude subscription instead and cannot
be redirected, so research, bulk reading, repository-wide search, first-draft
implementation, test and build runs go through the licence:

  copilot -p "<self-contained brief>" --model $MODEL --allow-all-tools \\
    -C <repo> --add-dir <repo>

The brief the Agent call was about to send is already the brief Copilot needs: name the
exact files and the exact question, ask for the conclusion rather than the material, and
send whole units of work — each invocation carries ~28k tokens of its own system prompt,
so ten small calls cost far more than one large one. The subprocess sees nothing of this
conversation.

Where Copilot genuinely cannot serve — structured output this conversation will parse,
work that needs this conversation's context, or a tool Copilot has no access to — the
string COPILOT-EXEMPT anywhere in the brief lets the Agent call through unmodified.
EOF
        exit 2
        ;;
    esac
    exit 0
    ;;

  UserPromptSubmit)
    n="$(/usr/bin/sed -n 's/^prompts=//p' "$state" 2>/dev/null | head -1)"; : "${n:=0}"
    n=$((n + 1))
    tmp="$state.tmp.$$"
    { [ -f "$state" ] && /usr/bin/grep -v '^prompts=' "$state" 2>/dev/null
      printf 'prompts=%s\n' "$n"; } > "$tmp" 2>/dev/null && mv "$tmp" "$state" 2>/dev/null
    rm -f "$tmp" 2>/dev/null || true

    speak=0
    [ "$n" -eq 2 ] 2>/dev/null && speak=1
    [ "$n" -eq 5 ] 2>/dev/null && speak=1
    [ "$n" -gt 5 ] 2>/dev/null && [ "$((n % 6))" -eq 0 ] 2>/dev/null && speak=1
    [ "$speak" -eq 1 ] || exit 0

    cat <<EOF
copilot-guard: this Mac has the employer-funded Copilot licence, and $n prompts into this
session that budget is the one meant to pay for bulk reading, repository-wide search,
first-draft implementation, and test or build runs — anything token-heavy whose result is a
conclusion rather than a judgement call. The form is
\`copilot -p "<self-contained brief>" --model $MODEL --allow-all-tools -C <repo> --add-dir <repo>\`,
with whole units of work per call rather than steps, because each call carries ~28k tokens of
its own system prompt. Decisions, the final read of a diff, anything needing the user's
approval and the conversation with him stay in this session. Current AI-credit usage is
visible from \`/billing\` inside an interactive \`copilot\` session.
EOF
    exit 0
    ;;

  SessionStart|*)
    if [ -f "$state" ]; then
      tmp="$state.tmp.$$"
      /usr/bin/grep -vE '^(prompts|reads)=' "$state" > "$tmp" 2>/dev/null && mv "$tmp" "$state" 2>/dev/null
      rm -f "$tmp" 2>/dev/null || true
    fi
    if [ "$CORP_OK" -eq 0 ]; then
      cat <<EOF
!!! COPILOT BRIDGE IS NOT AUTHENTICATED — SAY THIS TO THE USER IN THE FIRST REPLY !!!

~/bin/copilot-ask exists, but no corporate login is visible in ~/.copilot/config.json, so
every read this session performs will be billed to the personal Claude plan instead of the
employer's budget. This is a blocker the user has to clear, and it is stated first, in his
first reply, rather than discovered later from the credit meter. The fix is one command in
his terminal:

  script -q /dev/null copilot /login

Until it is cleared, say so plainly and keep local reading to the minimum the task needs.
EOF
      exit 0
    fi
    cat <<EOF
copilot-guard: this Mac carries a corporate GitHub Copilot licence on the account
OSlobodianiuk_wsi, whose monthly AI-credit budget is paid by the employer, and the bridge
~/bin/copilot-ask has just been checked and is authenticated. Work that can be handed
to another agent without losing the thread is meant to go there rather than onto the user's
personal Claude subscription: bulk reading, repository-wide search, first-draft implementation,
migrations, log and diff analysis, test and build runs. Subagents included — a brief written for
a researcher or implementer tier is a brief for
\`copilot -p "<brief>" --model $MODEL --allow-all-tools -C <repo> --add-dir <repo>\`,
because the Agent tool bills the personal subscription and cannot be redirected. The Agent tool
is blocked for those tiers on this machine; COPILOT-EXEMPT in a brief lets a genuine exception
through. Decisions, final review of a diff, anything touching credentials or needing the user's
approval stay here.
EOF
    exit 0
    ;;
esac

exit 0
