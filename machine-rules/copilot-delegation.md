# Delegate paid work to the corporate Copilot licence

Applies only to a machine that has a corporate GitHub Copilot licence attached to a GitHub
Enterprise account with its own AI-credit budget paid by the employer. The `copilot-guard`
hook checks the precondition on every session and stays silent where it does not hold, so
this text is safe to carry to every machine.

The precondition, checked by the hook, not by hand:

```bash
command -v copilot && grep -q "lhg.ghe.com" ~/.copilot/config.json
```

## The rule

Whenever a unit of work can be handed to another agent without losing the thread, hand it to
Copilot CLI instead of doing it in the main conversation:

```bash
copilot -p "<self-contained brief>" --model claude-sonnet-5 --allow-all-tools
```

`claude-sonnet-5` is the strongest model on this licence — verified 2026-08-05. Also
available: `claude-sonnet-4.6`, `claude-sonnet-4.5`, `claude-haiku-4.5`, `gpt-5.4`,
`gpt-5.3-codex`. Opus is not on the licence. Do not downgrade to save credits; the budget is
far larger than this workload consumes. Current usage is visible from `/billing` inside an
interactive `copilot` session — there is no `copilot billing` subcommand, that name only
works as a slash command in the interactive REPL.

**This applies to every project and every repository on such a machine, without being asked.**

## What goes to Copilot

Bulk reading, repository-wide search, first-draft implementation, test and build runs,
migrations, log and diff analysis — anything token-heavy whose result is a conclusion rather
than a judgement call.

**Subagents go here too.** The orchestrator style delegates research, implementation and
verification to subagents; on such a machine that delegation runs through `copilot -p`, not
through the Agent tool, because the Agent tool bills the personal subscription and cannot be
redirected. A brief written for `researcher-*` or `implementer-*` is a brief for Copilot —
send the same text, with the file paths and the exact question spelled out, and ask for the
conclusion rather than the material.

The `copilot-guard` hook enforces this by blocking the Agent tool for the research and
implementation tiers. Where Copilot genuinely cannot serve — structured output the
orchestrator will parse, work that needs this conversation's context, a tool Copilot has no
access to — the string `COPILOT-EXEMPT` anywhere in the brief lets the call through.

Keep read-only work read-only. For research, scope the subprocess to what it may touch:

```bash
copilot -p "<brief>" --model claude-sonnet-5 --allow-all-tools -C <repo> --add-dir <repo>
```

## What stays in the main conversation

Decisions, final review of a diff, anything needing the user's approval, anything touching
credentials, and the conversation with the user itself.

## Cost shape

Each `copilot -p` call carries roughly 28k tokens of its own system prompt, so ten small
calls cost far more than one large one. Send whole units of work, not steps. Briefs must be
self-contained — the subprocess sees none of the calling conversation.

## Why this is a hook and not only prose

It was prose only, in one machine-local file, until 2026-08-11. That day a session ran a
whole ticket — repository reads, greps, two full test runs, a rebase, a pull request — with
zero Copilot calls, and the user noticed from the credit meter rather than from the work.
The one rule that session followed all day was the status-file rule, and the only difference
is that `status-guard.sh` restates it as a system turn while the work is happening. A rule
that fires once at turn zero and then depends on goodwill is not a rule.
