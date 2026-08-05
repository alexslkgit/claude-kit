---
name: wrap-up
description: Flush everything worth keeping from this conversation into the project's status file, then hand the user a clean context. Use whenever the user says "заверни всё в статус", "сворачиваемся", "обнови статус", "перед клиром", "wrap up", "flush to status", or otherwise signals they are about to clear the conversation. Also offer it unprompted when a session has produced decisions or findings that exist only in the chat.
allowed-tools: Read, Write, Edit, Grep, Glob, Bash
---

# Wrap-up: the status file replaces conversation memory

The user clears context on purpose and often. Compaction was rejected — a summary of a summary
drifts, and drift is invisible until it has already steered the work. So the contract is blunt:
**whatever is not in the status file does not exist.** This skill is the moment that contract is
honoured.

You are not writing a summary of the conversation. You are writing the file that a future instance
of you — with no memory of any of this — will read instead of the conversation, and then act on
without asking the user a single question they have already answered.

## Two files, opposite lifecycles

`~/<project-orchestrator-dir>/`, outside the repository, never committed to a client repo:

- **`STATUS.md` — mutable.** Answers *where are we now*. Rewritten and pruned every wrap-up.
- **`DECISIONS.md` — append-only.** Answers *why is it like this, and what did we already rule out*.
  Never edited, never pruned. A decision that stops being true is superseded by a new numbered entry
  that references the old one; the old one stays, marked `SUPERSEDED BY D-nn`.

They are separate because rule 3 below — prune anything that can no longer change a decision — is
correct for current state and catastrophic for reasoning. Reasoning ages out of "current" while
still being the only thing that stops the same idea being re-proposed six weeks later. `STATUS.md`
cites decision ids (`D-004`, `X-006`) instead of restating them, which is also what keeps it short.

Entry shape in `DECISIONS.md`: **id · date · what was decided · who decided · why · what it costs
us.** A dead end is a decision too — the decision not to go somewhere — and gets an id (`X-nnn`)
like anything else. Every entry names the person and the date, because "we decided" is not a fact a
cold reader can act on.

If this project has neither file yet, create the directory and both files from scratch using the
structure here, and add a one-line pointer to auto-memory (`~/.claude/projects/<repo>/memory/`) so
the next session knows where to look before it knows anything else.

**There is no third file.** The user's own view is the board written by the `board` skill
(`.claude/tasks/<task>.html`) — a wrap-up updates that board, it does not create a second HTML
status beside it. If a project still carries an older `status.html`, fold whatever is current in
it into the board and delete it.

What that board must carry after a wrap-up: what we are doing and why, where we are, what he says at
his next standup, and, at the very top, **the short list of things only he can physically do**
(approve a push, sign in, click submit, decide scope). In his language, plainly, no jargon he did
not use himself. A stale board is worse than none — he trusts it before a call and repeats it aloud.

One project, one set of files. Never let another project's status leak in.

## The three rules that govern every line you write

**1 — Write for a reader with no memory at all.** Every entry stands on its own: what, why, and
where — absolute path, sha, ticket key, `file:line`, the person's name, the date. Never "as
discussed", never "the branch", never a pronoun pointing at a conversation that will not exist.
Convert "yesterday" and "last week" into dates. If a fact came from a person, name them and say
when. A cold reader must be able to act, not merely to understand.

**2 — A fact goes in the moment it becomes a fact, with its evidence attached.** Not at the end of
the session — there may be no end you get to control. Every number and every verdict carries how it
was obtained: the command, or the place in the code. That way it can be re-checked without being
re-derived, which is the whole point. And state is **verified, not trusted**: the repo, the remote,
the tickets and the PRs all move while nobody is looking, so before acting on a recorded number,
re-run the commands the file itself lists.

**3 — Rewrite, do not accumulate — measured by staleness, not by length.** Current-state sections are
replaced wholesale. Superseded facts are struck through (`~~so~~`) with the correction beside them,
never silently deleted — a wrong belief that was held is worth knowing, because it will otherwise be
re-derived. The test for every section is one question: **if this line were wrong, would it change
what happens next?** If yes it stays, however long the file gets; if no, it belongs in the
append-only file or nowhere.

**Do not impose a line limit, and do not quote one you invented.** A status file of a thousand
English lines is on the order of 15–20k tokens — under 10% of the context window — and reading it
replaces re-deriving everything in it, including things that took a whole session to establish. The
cost that actually matters is stale content being read as current, which is a correctness failure
with no ceiling on its price. Growth is a symptom to notice, not a rule to obey: sustained growth
almost always means finished work was never moved out. The append-only file is *expected* to grow
forever.

## What the file contains

- **Maintenance rules** — the three above, at the very top, so the file teaches its own upkeep.
- **Cold start** — who the user is, what to read in what order, the exact commands that re-verify
  live state, the hard constraints (what must never be done without an explicit instruction), and a
  map of paths, worktrees and remotes. This section is what makes `/clear` survivable.
- **Part 1, for the human, in their language, deliberately plain** — where we are, ready-to-speak
  text for their next standup, what can go wrong, and what only they can do. Plus a dated changelog.
- **Part 2, the working log, dense** — board, current work with sha and paths, settled facts that
  must not be re-verified, dead ends that must not be repeated, standing decisions with their
  reasons, news from chat and meetings, and next steps split into *waiting on the user*, *running
  unattended*, and *never started but still owed*.

## Procedure

0. **Run `date` before you write a single dated line.** A session can stay open for days: the user
   comes back to the same chat on Tuesday and again on Thursday, and nothing in the conversation
   tells you which one it is. Recorded 2026-08-06, when a wrap-up dated three days of work as one
   and recorded a merged PR as still open, because the date was carried forward from the first
   message instead of being read from the clock. The repository, the tickets and the remote all
   moved in between, and sibling chats had changed the checked-out branch underneath the session.
   Read the clock, then re-verify state, then write.

1. **Re-verify live state before writing a word of it.** Branch, worktrees, remote position, PR
   state, ticket state — by command, not from memory. Recording a stale number as current is the
   one failure this skill exists to prevent.
2. **Sweep the conversation for anything that exists only here**: decisions and the reasoning behind
   them, numbers you derived, dead ends, things a colleague said, corrections the user made, things
   you got wrong and fixed. Each becomes an entry under rule 1. **Sort as you go** — a decision or a
   dead end is appended to `DECISIONS.md` with a fresh id; everything else belongs in `STATUS.md`.
   When in doubt about which file: ask whether the entry would still matter after this ticket ships.
   If yes, it is a decision.
3. **Write Part 2 first, Part 1 second.** Part 1 is derived from it, not the other way round — that
   is what keeps the human summary honest.
4. **Update the board** if there is one, including the "what only you can do" block. Send it to
   the user with `SendUserFile` so it is one click away.
5. **Prune under rule 3** — by asking of each section whether a wrong line in it would change the
   next action, not by counting lines. Report what you moved out and why, not the file size.
6. **Wire the guard.** Two small files, both cheap to get wrong by forgetting:
   - `<repo>/.claude/status-dir` — one line, the absolute path of the status directory. This is how
     the `status-guard` hook finds the files from inside the repo. Create it if absent. **In a client
     repo, hide it via `.git/info/exclude`, not `.gitignore`** — `.gitignore` is shared with hundreds
     of other people and a personal tooling entry has no business in their diff, whereas
     `info/exclude` is per-clone and never committed. One entry, `.claude/`, covers the main clone
     and every worktree, since they share the common git directory. Verify with
     `git check-ignore -v .claude/status-dir` and confirm `git status` is clean afterwards.
     **Every worktree needs its own copy of the marker file.** Worktrees share the git directory but
     not the working tree, so a session started inside one otherwise reports that the project has no
     status files at all. Walk `git worktree list` and drop the marker into each.
   - `touch <status-dir>/.wrapup-stamp` — **as the last action of the wrap-up.** The hook compares
     this timestamp against the moment of the last context reset; without the touch, every future
     session is told the files are stale, and a warning that is always on is a warning nobody reads.
7. **Check the auto-memory pointer** exists and still describes the files accurately.
8. **Report in three lines or fewer**, then tell the user they can clear now, and give them the exact
   phrase that resumes work (see below).

## Handing over the clear

**You cannot clear the context yourself.** Hooks communicate through stdout, stderr and exit codes
only — they cannot trigger a slash command or a tool call. A `SessionEnd` hook *does* fire on
`/clear`, with `reason: "clear"`, but it runs on a 1.5-second budget (raisable to 60), it cannot
block or defer the clear, and it cannot run an agent — so it can never do this writing. That is why
this skill is invoked *instead of* clearing, not alongside it.

The `status-guard` hook (`~/.claude/hooks/status-guard.sh`, installed by the kit) covers the gap it
can: on `PreCompact` and on `SessionEnd` with reason `clear` it records that a reset happened, and on
`SessionStart` — whose stdout *is* injected into the new session's context — it names the status
files and says whether a wrap-up ran after the last reset. So a clear without a wrap-up is not
silent: the next session is told the files may be missing whatever the last one learned. That is a
tripwire, not a safety net; the writing still only happens here.

Finish the write, touch the stamp, then say plainly that the files are current and the context can go.

Give the user the resume phrase, and keep it short enough to retype: **"прочитай статус"** (or
"read the status file" — match the language they use). The next session starts by reading the file's
cold-start section and nothing else.

## When the wrap-up reveals a gap

If, while sweeping, you find something you never actually verified — a number you carried from a
subagent report, a claim you inherited from an earlier session — do not launder it into the file as
established fact. Either verify it now, or write it with the doubt attached and name what would
settle it. The file's authority comes entirely from the fact that nothing in it is decorative.
