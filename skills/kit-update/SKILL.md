---
name: kit-update
description: Sync the orchestrator kit (subagents, output style, skills, templates) on this machine. Use whenever the user asks in any wording to pull, refresh, sync or update the kit / agents / skills / config — for example "обнови кит", "подтяни настройки", "sync the kit". Also use after editing any kit file on this machine, to install the edit locally and offer to push it.
allowed-tools: Bash, Read, Edit
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

## Conflicts

A `git pull --ff-only` that refuses means both machines edited the kit. Do not force
anything: show `git log --oneline origin/main...HEAD` and the conflicting files, and ask
which side wins.
