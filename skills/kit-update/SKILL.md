---
name: kit-update
description: Sync the orchestrator kit (subagents, output style, skills, templates) between machines. Use whenever the user asks in ANY wording to update, pull, refresh, sync, save or push the kit / config / settings / agents / skills — including "обнови кит", "подтяни настройки", "сохрани конфиг", "сохрани настройки", "запушь кит", "sync the kit", "save this rule everywhere". Also use proactively after you edit any kit file, and whenever the user gives a durable correction about how you work (message style, model tier choices, a rule they restate) — that correction belongs in a kit file, not in this conversation.
allowed-tools: Bash, Read, Edit, Write
---

# Sync the orchestrator kit

The kit is a git repo at `~/Developer/claude-kit`. `install.sh` copies `agents/`, `skills/`
and `output-styles/` into `~/.claude/`, where they apply to **every project on this machine**.

## Rules

- **Never edit `~/.claude/agents`, `~/.claude/skills` or `~/.claude/output-styles` directly.**
  `install.sh` overwrites them and the edit would be lost and would not reach the other
  machines. Edit the kit, then install.
- **Pulling and installing is safe — do it without asking.** Pushing is not: ask first, and
  never push without an explicit yes.
- If the kit directory does not exist on this machine, say so and give the clone command
  rather than guessing a path.

## Pull direction (the default — "обнови кит")

```bash
cd ~/Developer/claude-kit && git pull --ff-only && ./install.sh
```

Then report in one sentence what changed (`git log --oneline HEAD@{1}..HEAD`) and, if the
output style changed, remind the user that styles load at session start so `/clear` is
needed for it to take effect. Agents and skills take effect immediately, no restart.

## Push direction (after editing a kit file here)

```bash
cd ~/Developer/claude-kit && ./install.sh && git status --short
```

Install locally first so the change is live here, then show the diff and ask whether to
commit and push it to the other machines. Commit message: one line, English, imperative.

Pulling needs no credentials (the repo is public), but **pushing does**. On a machine that
has never pushed, `git push` fails on authentication: install `gh` if missing
(`brew install gh`), then run `gh auth login --web` — it prints a one-time code, so report
that code to the user and let them enter it in the browser. Never ask for, type, or print a
password or token yourself.

## Conflicts

A `git pull --ff-only` that refuses means both machines edited the kit. Do not force
anything: show `git log --oneline origin/main...HEAD` and the conflicting files, and ask
which side wins.
