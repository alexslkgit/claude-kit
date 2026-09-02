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

---

# Unattended calls are supervised, and long jobs stay in the seat

Added 2026-09-02, after a night of unattended work produced nothing twice over. Both failures are
worth naming, because they look identical from outside and neither one raises an error.

## The two ways a delegated call dies quietly

**It exits successfully after failing.** On 2026-09-01 the corporate API stopped answering for a few
minutes and killed three `copilot -p` calls at once with `ETIMEDOUT`. Each exited zero. An hour of
work was lost and nothing noticed for two more hours, because a dead call and a finished call are
the same event.

**It stays alive and does nothing.** The replacement call lived thirteen hours. Its log grew the
whole time; its report file was never touched after the first minute. It was retrying variations of
a command that `copilot`'s own permission classifier kept denying, forever, because in a
non-interactive call there is nobody to approve anything.

## The rule

Every unattended `copilot -p` call goes through `~/.claude/tools/agent-supervise.sh`, never a bare
`nohup copilot -p ... &`. It supervises on two signals: the report file must end with a line
containing exactly `DONE`, and the report file's mtime must keep moving. A live call whose report
has been static for twenty-five minutes is killed and restarted with a notice explaining what
happened and telling it to finish rather than start over.

Every brief must therefore carry two lines, or the supervisor cannot work:

- write the report file within the first two minutes and keep improving it as the work proceeds
- the last line of the report is `DONE`, on its own, written only when the work is genuinely finished

The `DONE` sentinel is something the model has to write, not something the runner can infer. That is
deliberate: the third way these calls lose work is deciding on their own that they are finished.

## What `--allow-all-tools` does not allow

Measured on this machine, not assumed. `copilot -p --allow-all-tools` still refuses commands its own
classifier dislikes, and returns `Permission denied and could not request permission from user`:

- writing anywhere outside the directories passed to `-C` / `--add-dir`, including `/tmp`
- backgrounding a command, whether with `&` or `( ... &)`
- some piped invocations of `xcodebuild`

So every brief must say: write scratch files inside the repository, never `/tmp`; never background a
command. And a call that hits a permission refusal must record it in its report and move on, never
retry variations of it, which is exactly what burned the thirteen hours.

## What does not get delegated at all

**Builds, test runs, simulator control and anything else whose output goes to a file.** Delegation
exists to keep bulk material out of the orchestrator's context. A build does not put bulk in the
context: its output goes to a log and only a `grep` of the summary comes back. Handing it to Copilot
buys nothing and adds a permission classifier between the seat and the machine.

So the split is: Copilot reads source, writes code and tests, and diagnoses. The orchestrator builds,
runs, erases simulators, registers files in project files, and reads the summaries.

## A long job is detached with a marker file, never held by a tool timeout

The harness caps a Bash call at ten minutes, and `run_in_background` does not lift that cap: a
backgrounded call is still killed at its timeout. A counted test run was lost to exactly this.

Anything that can outlast ten minutes gets written as a small script, launched with `nohup ... &`,
and ends by writing its exit code to a marker file. Poll for the marker. The marker is what
separates finished from hung, and without one there is no way to tell them apart from outside,
which is the same lesson as the `DONE` sentinel one level down.
