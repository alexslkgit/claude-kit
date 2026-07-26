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
   comments and in `.claude/state.md`. Many sources are already written down somewhere.
2. **Ask for the gap in one message, with options**, listing everything missing at once —
   not one question per source. Example:
   "По этому проекту не записано: где переписка (Slack / Teams / ни то ни другое) и файл
   Figma. Скинь ссылки, или скажи «нет такого» — запишу, больше спрашивать не буду."
3. **Write the answer into `CLAUDE.local.md`** under `## Sources`, in English, using the
   template below. If the file or the block does not exist, create it. Ensure
   `CLAUDE.local.md` is in the repo's `.gitignore` — these links are internal.
4. **Record explicit absences too** (`Chat: none`). An absence stops the question from
   coming back, which is the whole point.
5. Note in `.claude/state.md` that sources were established.

## Template

```markdown
## Sources

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
the human. Prefer the structured integration over the browser: an MCP for Jira/Linear or
Figma is stable, a scraped web UI is not. Reach for the browser only where no MCP exists,
Teams being the usual case.

Never send a message into any of these systems autonomously. Draft it, the user sends it.
