---
name: project-sources
description: Establish and remember where this project's information actually lives — Jira/Linear project, Figma files, the team chat (Slack or Teams) and its relevant channels, docs, staging URLs. Use when starting work in a repo whose CLAUDE.local.md has no Sources block, or when research needs a source that is not recorded yet. Records the answer so it is never asked twice.
allowed-tools: Read, Edit, Write, Bash, Grep, Glob
---

# Project sources

Each job has a different stack of places where answers live: one uses Slack, another Teams,
another keeps the specs in Confluence and the design in a single Figma file. That mapping is
per repository and per machine, so it belongs in the repo's gitignored `CLAUDE.local.md`,
not in this kit.

## Rule

**Ask once, record, never ask again.** A missing source is one of the few legitimate reasons
to interrupt the user — but only once per project, and only for what you cannot discover.

## Procedure

1. **Look before asking.** Check `CLAUDE.local.md` for a `## Sources` block, then the repo:
   README, docs folder, CI config, `.env.example`, git remotes, existing links in code
   comments and in `.claude/tasks/<task>.md`. Many sources are already written down somewhere.
2. **Ask for the gap in one message, with options**, listing everything missing at once —
   not one question per source. Example:
   ask it in the user's language, shaped like: "Not recorded for this project: where the team
   chat is (Slack / Teams / neither) and the Figma file. Send the links, or say there is none —
   I will write it down and stop asking."
3. **Write the answer into `CLAUDE.local.md`** under `## Sources`, in English, using the
   template below. If the file or the block does not exist, create it. Ensure
   `CLAUDE.local.md` is in the repo's `.gitignore` — these links are internal.
4. **Record explicit absences too** (`Chat: none`). An absence stops the question from
   coming back, which is the whole point.
5. Note in `.claude/tasks/<task>.md` that sources were established.

## Template

```markdown
## Sources

- Base branch: <develop | main> <+ note if it is recreated every release cycle>
- Tickets: <Jira project key + base URL | Linear team | none>
- Design: <Figma file URL(s), and which one is current | none>
- Chat: <Slack workspace | Teams | none> — relevant channels: <#a, #b>
- Docs: <Confluence space / docs folder / wiki URL | none>
- Environments: <staging / preview URLs | none>
- People: <who owns design, who owns backend — for drafting messages>
- Access: <what needs a browser session and what is reachable over MCP>
```

## Using them afterwards

Follow the source order — repository & git history → documentation → Figma → chat/tickets →
the human.

**Do not assume an MCP is available or worth chasing.** It is preferable where it exists and is
reachable, but two things rule it out often: self-hosted Jira Server/Data Center has no
Atlassian MCP at all (only `*.atlassian.net` Cloud does), and corporate security policy
routinely blocks issuing API tokens or approving OAuth apps. In that case the browser is the
primary path, not a fallback — the built-in Chrome integration reuses the session the user is
already signed into. Record which it is in the `Access` line and stop revisiting it.

When a workspace has several accounts (a client Slack and an employer Slack, say), record both
and which is which, because posting or reading in the wrong one is a real mistake.

Never send a message into any of these systems autonomously. Draft it, the user sends it.
