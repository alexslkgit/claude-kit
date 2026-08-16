# Personal orchestrator policy

Local, gitignored. Personal operating policy that must NOT reach collaborators or Cursor.
Neutral, team-facing workflow rules belong in the committed `CLAUDE.md`.

Copy this file to a repo root as `CLAUDE.local.md` and add `CLAUDE.local.md` to that repo's
`.gitignore`. Claude Code loads it automatically alongside `CLAUDE.md`.

## Language

- Talk to the user in **Russian**. Write everything else in **English** — files, logs,
  prompts, config, commit messages, memory, journal. Token cost, not preference.

## Communication protocol

- Three message types only: a **status** (three sentences max), a **blocking question**
  (only when a human is physically required, and never open — it names the decision already
  taken and asks only for a yes/no).
- No walls of text, no italic self-notes in chat. Reasoning goes to `.claude/tasks/<task>.md`.
- The user is in the loop at exactly one step: deciding the unknowns nothing else could
  close. Everything before and after runs without them.

## Model selection — predict, do not escalate

- Pick the **minimum tier that will do the job well**, before the run. Not the cheapest with
  a plan to redo it. Opus or Fable from the start is correct when the task warrants it.
- Cheap-first-then-escalate is rejected: redoing costs more than choosing right once.
- **Verification is a separate mechanism, not a routine step** — re-run on a higher tier when
  a result smells wrong (e.g. "there is nothing of the sort in this project" on a branch
  where it certainly exists).
- Agent roster and routing table: see the `Orchestrator` output style.
- Accumulate tier-fit conclusions in auto-memory and reuse them.

## Off limits

- Never send messages to real colleagues autonomously — put a finished draft where the app keeps
  drafts, the user presses send. Not sending it is the limit; not preparing it is not.
- Do not propose Cowork project memory, the Memory-tool API, or `claude-mem`-style plugins
  as a memory solution — all rejected.
- Do not ask the user to write prompts by hand; that is the delegated work.
- Do not commit to the main branch, touch secrets/keys, or run release scripts without an
  explicit instruction.

## Sources

Where this project's answers actually live. Filled in by the `project-sources` skill on
first use — ask once, record here, never ask again. Record absences explicitly (`none`) so
the question does not come back.

- Tickets: <Jira project key + base URL | Linear team | none>
- Design: <Figma file URL(s), and which one is current | none>
- Chat: <Slack workspace | Teams | none> — relevant channels: <#a, #b>
- Docs: <Confluence space / docs folder / wiki URL | none>
- Environments: <staging / preview URLs | none>
- People: <who owns design, who owns backend — for drafting messages>
- Access: <what needs a browser session, what is reachable over MCP>

## Project-specific additions

<!-- Per-repo overrides: local quirks, exceptions to the rules above. -->
