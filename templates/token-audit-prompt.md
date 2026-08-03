# Token audit — portable prompt

Paste the block below into a fresh Claude Code session opened in the project you want audited.
It is project-agnostic: it discovers everything it needs. Derived from a measured audit of the
energy-tracker project on 2026-08-03 (20 sessions, 327 MB of transcripts); the priors it carries
are stated as priors and must be re-verified against the local data.

---

You are auditing this project's token consumption and then fixing what you find. Work
autonomously: everything below is discoverable from this machine, so do not ask me anything you
can check yourself. Report in Russian, in short messages; write every file, prompt and commit
message in English.

**Rule for the whole task: keep bulky material out of this conversation.** Delegate every large
read or log parse to a subagent and ask it for conclusions, never for the material. If you catch
yourself about to read a file over ~500 lines into this context, delegate it instead.

## Phase A — measure, before changing anything

Find this project's transcripts: `~/.claude/projects/<cwd-path-with-slashes-as-dashes>/*.jsonl`
(glob for it rather than constructing the name). Hand the analysis to ONE subagent on a strong
tier and have it write python under a scratchpad dir, returning only aggregated tables.

Four schema traps make a naive count wrong by multiples. Pass them to the subagent verbatim:

1. One API response is written as **several JSONL lines, one per content block, each repeating the
   full `usage` object.** Dedup by `message.id` or every total is inflated ~2x.
2. Subagent transcripts additionally contain **streaming partials** with the same `message.id` and
   a growing `output_tokens`. Take `max` per field, not the first value, or subagent output is
   understated ~5x.
3. Session **forks/resumes copy messages under a rewritten `sessionId`**. Dedup by `message.id`
   across files; attribute to the earliest-starting session.
4. Substring matching on command names collides with the repo name and with filenames — use word
   boundaries. (`rg` matched inside "ene**rg**y-tracker"; `strings` inside `Localizable.xcstrings`.)

Have it report, for the last ~20 sessions:

- **Billing split**: summed `input_tokens`, `cache_creation_input_tokens`, `cache_read_input_tokens`,
  `output_tokens`, then weighted to base-input-equivalents at 1.0 / 1.25 (5m TTL) or 2.0 (1h TTL) /
  0.1 / 5.0. Report the share of each. Check the actual TTL in
  `usage.cache_creation.ephemeral_5m_input_tokens` vs `ephemeral_1h_input_tokens`.
- **Per-session cost**, ranked, with turns, request count, average cache-read per request, peak
  context, and how many `compact_boundary` events each has plus their `compactMetadata.trigger`.
- **API calls per user turn** (total assistant requests ÷ user turns). This is the multiplier on
  context size and usually the second-biggest lever.
- **Tool-result volume**: total text chars by tool; for Bash by first word of the command; for Read
  by file path. Count image blocks separately — base64 chars are not context chars; price them at
  ~1.5k tokens each. Report the top 25 offenders and what share the top 10 hold.
- **Output composition**: share of output chars in `thinking` vs visible text vs tool-call
  arguments, stated as the approximation it is.
- **Delegation**: how many Task/Agent calls, in how many sessions, chars consumed inside subagents
  vs chars returned (the compression ratio), and what share of weighted spend the subagents are.
- **Repeat reads within one context window** — not within one session file; two subagents reading
  the same file are not a repeat.

Priors from the audited project, to be confirmed or refuted locally, not assumed:

- Input side was 85% of weighted cost, cache read alone 64%. Output 15%, of which thinking ~24% —
  so **effort level is a ~4% lever, not a major one**.
- Unique tool payload was ~5.8M tokens re-sent an average of 261 times. The payload is not the
  cost; the number of re-sends is.
- One 342-hour session was 48% of all spend, carrying ~275k cache-read tokens per request.
- Build and lint output was already well filtered (401 `xcodebuild` calls = 434k chars total) and
  repeat reads were 0.1% of spend. **Do not spend effort there unless your numbers say otherwise.**
- Delegation was already heavy and effective (81% of tool bytes absorbed by subagents, returned at
  1.7% of volume). More delegation was not the lever; narrower subagent briefs were.

## Phase B — cut the static overhead

This part is safe, permanent and independent of the numbers, so do it regardless.

Measure, in characters, and convert at ~3.6 chars/token: the project `CLAUDE.md`, any
`CLAUDE.local.md`, `~/.claude/CLAUDE.md`, the active output style in `~/.claude/output-styles/`,
the auto-memory index at `~/.claude/projects/<project>/memory/MEMORY.md`, and the combined
`description:` lines of every installed skill and agent. All of these are re-sent on **every**
request, including every tool call, even when the task has nothing to do with them.

Then:

1. **Split `CLAUDE.md` so only what applies to *every* task stays.** Per-subsystem contracts move
   verbatim into project skills at `.claude/skills/<name>/SKILL.md` with a `description:` that
   names the exact paths and symbols that should trigger it. Leave a routing table at the top of
   `CLAUDE.md`: "touching X → load skill Y", and keep any "anti-patterns" summary list, which is
   the safety net that survives a skill not loading.
2. **Verify nothing was lost**: for every non-empty line of the original file, assert it appears in
   the new `CLAUDE.md` or in one of the skills. Print the exceptions and confirm each is one you
   rewrote deliberately.
3. **Gitignore trap**: if `.claude/` is ignored, the skills will not be committed. Re-including
   them needs three lines in that order — `!.claude/`, `.claude/*`, `!.claude/skills/` — because a
   global `~/.gitignore_global` entry for `.claude/` excludes the directory itself and git will not
   descend into an excluded directory to see an exception. Verify with `git check-ignore -v` that
   the skills are visible **and** that secrets, settings and task journals are still ignored.
4. **Trim the output style** if one is active: keep every rule that changes behaviour, drop the
   restatements and the justifications, and move machine-specific or system-specific material into
   the skill that already covers it.
5. **Disable what this project never uses**: MCP servers whose tools are not deferred, plugins and
   skills irrelevant to this codebase. Check whether MCP tool schemas are deferred behind a tool
   search in this harness — if they are, the server list is nearly free and only the descriptions
   cost.

## Phase C — the ranked plan

Write `.claude/tasks/token-optimization.md` (create `.claude/tasks/` if needed and confirm it is
gitignored) containing: the sample description, the billing split, the three most expensive
concrete behaviours **with their measured cost**, an explicit list of what is already fine and must
not be "fixed", and a table of actions ranked by estimated share of total spend saved.

Then give me that table in chat, in Russian, at most one screen. Lead with the single most
expensive behaviour you measured.

## Constraints

- **This repository is shared with other people.** `CLAUDE.md` is a file colleagues read, so the
  split must be reviewable: content moves verbatim, no rewording in passing, no reformatting, no
  opportunistic edits. Show me the diff summary and get my approval before committing anything.
  Do not push.
- Do not lower model tiers as a primary saving — delegation's value is context isolation, and the
  measured thinking cost is small. Tier changes only where a task is mechanical.
- Do not touch source code, tests, CI or dependencies. This task is configuration only.
- If a number you get contradicts a prior above, trust your number and say so explicitly.
