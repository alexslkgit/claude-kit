# Bootstrap prompt — set up the two-file memory for a new project

Paste this into a fresh conversation in any project that does not have the status files yet. It is
written to be handed to an agent, not read by a human.

---

I work on this project across many separate conversations, and I clear the context deliberately
rather than letting it compact — a summary of a summary drifts, and the drift is invisible until it
has already steered the work. So conversation memory is not where project memory lives. Set up the
files that replace it.

Create `~/<short-project-name>-orchestrator/` outside this repository — nothing in it is ever
committed to the project — containing two files with **opposite lifecycles**:

**`STATUS.md` — mutable, rewritten, pruned.** Answers *where are we now*. Structure:

- The three maintenance rules at the very top, so the file teaches its own upkeep:
  1. *Write for a reader with no memory at all.* Every entry stands on its own: what, why, and where
     — absolute path, sha, ticket key, `file:line`, the person's name, the date. Never "as
     discussed", never "the branch", never a pronoun pointing at a conversation that will not exist.
     Relative time becomes absolute dates. A cold reader must be able to act, not merely understand.
  2. *A fact goes in the moment it becomes a fact, with its evidence attached.* Not at session end —
     there may be no end you control. Every number and verdict carries how it was obtained, the
     command or the place in the code, so it can be re-checked without being re-derived. And state
     is verified, not trusted: before acting on a recorded number, re-run the commands the file
     itself lists, because repos, remotes and tickets move while nobody is looking.
  3. *Rewrite, do not accumulate — measured by staleness, not by length.* Current-state sections are
     replaced wholesale; superseded facts are struck through with the correction beside them, never
     silently deleted. The test for each section is whether a wrong line in it would change what
     happens next: if yes it stays however long the file gets, if no it belongs in the append-only
     file or nowhere. **No line limit.** A thousand English lines is on the order of 15–20k tokens,
     under 10% of the window, and reading it beats re-deriving what it contains. Stale content read
     as current is the cost that actually matters.
- A **cold-start section**: who I am, what to read in what order, the exact shell commands that
  re-verify live state, the hard constraints (what must never be done without an explicit
  instruction from me), and a map of paths, repositories and remotes.
- **Part 1, for me, in my language, deliberately plain**: where we are, ready-to-speak text for my
  next standup or status call, what can go wrong, and what only I can physically do. Plus a dated
  changelog.
- **Part 2, the working log, dense**: board, current work with shas and paths, settled facts that
  must not be re-verified, standing constraints, news from chat and meetings, and next steps split
  into *waiting on me*, *running unattended*, and *never started but still owed*.

**`DECISIONS.md` — append-only, never edited, never pruned.** Answers *why is it like this, and what
did we already rule out*. Each entry: **id · date · what was decided · who decided · why · what it
costs us.** Dead ends get ids too (`X-nnn`) — the decision not to go somewhere is a decision, and
each one cost real time once. When a decision stops being true, append a new entry that supersedes
it by number and mark the old one `SUPERSEDED BY D-nn`; never rewrite history. `STATUS.md` cites
ids instead of restating reasoning — that is what lets rule 3 prune safely.

**`status.html` beside them is mandatory, not optional.** It is my own view, and it has one job:
take me from zero to oriented in five minutes — what we are doing, why, where we are, what I say at
my next standup, and at the very top the short list of things only I can physically do. My language,
plain words, self-contained HTML, no external assets, works in light and dark. It is rewritten in the
same wrap-up as the other two, never later: a stale one is worse than none, because I read it right
before a call and repeat what it says out loud.

Then wire the guard, so a context reset is never silent:

- Write `<repo>/.claude/status-dir` — one line, the absolute path of the status directory. This is
  how the hook finds the files from inside the repo. If this is a shared repository, hide it through
  `.git/info/exclude` rather than `.gitignore`: `.gitignore` is committed and belongs to everyone,
  `info/exclude` is per-clone. A single `.claude/` entry covers the main clone and every worktree.
- Touch `<status-dir>/.wrapup-stamp` at the end of every wrap-up.
- Confirm `~/.claude/hooks/status-guard.sh` is installed and registered in `~/.claude/settings.json`
  for `SessionStart`, `PreCompact` (manual and auto) and `SessionEnd` (matcher `clear`). If the kit
  is present, `~/Developer/claude-kit/install.sh` does this and is idempotent. The hook records every
  reset and, on the next session start, names the status files and says whether a wrap-up ran after
  the last reset. It cannot write anything itself — hooks cannot run an agent — so it is a tripwire,
  not a replacement for the wrap-up.
- Add a one-line pointer in auto-memory (`~/.claude/projects/<repo>/memory/`) saying these files are
  the source of truth and are read at the start of every session.

From then on: when I say **"заверни всё в статус"** / "wrap up", run the `wrap-up` skill — it
re-verifies live state, flushes everything that exists only in the conversation into the right one
of the two files, prunes, and hands me back a clean context. Then I clear, and the next session
starts with **"прочитай статус"**.

Populate both files now from whatever you already know about this project, and tell me plainly what
you could not fill in.
