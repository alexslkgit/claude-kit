# claude-kit

Portable orchestrator configuration for Claude Code. One repo, installed once per machine,
shared by every project on that machine.

## Install on a new machine — one command, once ever

```bash
git clone https://github.com/alexslkgit/claude-kit.git ~/Developer/claude-kit && cd ~/Developer/claude-kit && ./install.sh
```

Then `/clear`. That is all — `install.sh` also selects the output style for you by merging
`"outputStyle": "orchestrator"` into `~/.claude/settings.json` (your other settings are kept,
and a `.bak` is written). Styles are read once at session start, hence the `/clear`.

Nothing to pick by hand: `/output-style` was removed in recent versions and `/config` is a
manual step, so the installer writes the same key those wrote.

## Update everywhere — no commands after that

Edit on any machine, commit, push. On the others, just say it in the chat — "обнови кит",
"подтяни настройки", "sync the kit" — and the `kit-update` skill runs the pull and the
install. The command below is only the manual equivalent:

```bash
cd ~/Developer/claude-kit && git pull --ff-only && ./install.sh
```

Zero token cost — it is a file sync, not context. Nothing loads into a conversation until it
is actually used (skills load on demand, agents only when invoked).

**Never edit `~/.claude/agents`, `~/.claude/skills` or `~/.claude/output-styles` directly** —
the next install overwrites them and the change never reaches the other machines.

## Using the skills outside Claude Code (Cowork)

This repo is also a plugin marketplace, because `install.sh` only reaches Claude Code on a Mac.
Where the skills are needed elsewhere — Cowork, for instance — add it as a marketplace and
install the plugin:

```
/plugin marketplace add alexslkgit/claude-kit
/plugin install orchestrator-kit@claude-kit
```

The plugin carries the **agents and skills** only. A plugin cannot ship an output style, so the
orchestrator persona (Russian to the user, three-sentence replies, the model routing table) is
Claude Code only. On the Macs, use `install.sh` and **not** the plugin — running both would
install the same skills twice.

## Integrations

Integrations are **per machine**, so `install.sh` does not touch them — a registered server
that was never authenticated nags at every session start. Run `setup-mcp.sh` only where the
machine actually has the thing, naming what it has (idempotent, `--remove` undoes it):

```bash
./setup-mcp.sh jira figma      # or just `jira`, or just `figma`
```

Registered user-scoped, so all projects on that machine see them:

| Server | Endpoint | Notes |
|---|---|---|
| `atlassian` | `https://mcp.atlassian.com/v1/mcp/authv2` | Streamable HTTP. The `/v1/sse` endpoint is deprecated (cutoff 2026-06-30) — never use `--transport sse`. Requires an Atlassian **Cloud** site. |
| `figma` | `https://mcp.figma.com/mcp` | Remote, no desktop app needed; Figma de-recommends the local `127.0.0.1:3845` server. |

Both use in-browser OAuth, which is the one step a human must do: restart Claude Code, run
`/mcp`, pick the server, Authenticate. `claude mcp login <name>` does the same from a shell.
A non-interactive run (`claude -p`) cannot complete OAuth — sign in from a real session first.

**The browser is deliberately not an MCP server.** Claude Code's built-in Chrome integration
(`claude --chrome`, or `/chrome` → "Enabled by default") is the only option that reuses an
already-logged-in browser session, which is the entire point when the source is a Teams or
Slack web UI with no API. Opening a remote-debugging port for Chrome DevTools MCP or Playwright
MCP instead forces a blank profile — Chrome refuses the flag on your default one — so you would
be logging in again every time. Enabling Chrome by default costs context on every session, so
prefer `claude --chrome` per task.

User-scoped MCP servers are inherited by subagents automatically. An agent's `mcpServers:`
frontmatter **grants** extra servers rather than restricting; to take them away use `tools:`
(allowlist) or `disallowedTools:`. Note that the read-only research agents here list plain
tools, which already means no MCP access — grant it explicitly if a researcher needs Jira.

## Starting a new project

1. Copy `templates/CLAUDE.md` to the repo root and fill it in; commit it.
2. Copy `templates/CLAUDE.local.md` to the repo root; add `CLAUDE.local.md` to `.gitignore`.
3. Make sure `.claude/` is in `.gitignore`. Per-task journals are created from `templates/task-journal.md` as work starts — one file per ticket, never shared between tasks.
4. On the first task, the `project-sources` skill asks once for the tickets/design/chat links
   and records them in `CLAUDE.local.md` — after that it never asks again.

## What is machine-wide vs per-repo

Installed to `~/.claude/` by `install.sh`, applies to **every project on this machine**:

| Path | Contents |
|---|---|
| `agents/` | researcher (haiku/sonnet/opus/fable), planner (opus), implementer (sonnet/opus), verifier (opus) |
| `skills/` | procedures loaded on demand — `ticket-intake`, `bug-fix`, `handoff`, `draft-message`, `pr-review`, `project-sources`, `kit-update` |
| `output-styles/orchestrator.md` | main-conversation persona + the model routing table |

Lives in each repository, not here:

| Path | Contents | Git |
|---|---|---|
| `CLAUDE.md` | stack, build/test/lint commands, conventions, invariants | committed |
| `CLAUDE.local.md` | personal policy — start from `templates/CLAUDE.local.md` | gitignored |
| `.claude/tasks/<task>.md` | per-task journal: STATE header, open questions, log | gitignored |

Project-level files win over user-level ones of the same name, so a repo can override any
agent from this kit by putting its own `.claude/agents/<same-name>.md` in place.

## Model routing

The tier is fixed inside each agent's file — the parent cannot choose it at call time, so
each role exists at several tiers and **choosing the agent is choosing the model**. The
routing table lives in `output-styles/orchestrator.md`.

Policy: predict the minimum tier that will do the job *well*, before the run. Cheap-first-
then-escalate is deliberately rejected. Re-running on a higher tier is a reaction to a
suspicious result, not a routine step.

## Verified mechanics (do not re-derive)

- Output styles apply to the **main conversation only** — subagents keep their own system
  prompt. That is intentional here: terse with the user, verbose inside.
- A plugin **cannot** ship an output style (agents, skills, hooks and MCP servers only) —
  which is why this kit installs by copy rather than as a plugin.
- Subagents **cannot ask the user anything**; a background run silently denies whatever
  needs approval. Keep every decision in the main thread and give agents narrow tool lists.
- Omitting `tools:` in an agent grants **all** tools. Every agent here lists them explicitly.
- Auto-memory (`~/.claude/projects/<repo>/memory/`) is per-repo and machine-local; it is the
  place for accumulated model-tier conclusions.
