---
name: board
description: Maintain the board — a live, self-refreshing HTML page for the user, one per task, next to the task journal, rewritten in full at every stage change, decision and blocker, so he opens it at any moment and understands the whole run in ten seconds without asking anything. Use whenever the user says "борд", "обнови борд", "покажи борд", "board" or "update the board". Create it when a task starts and close it on finish.
allowed-tools: Read, Write, Edit, Bash, Glob
---

# The board

The user walks away while the run continues. He comes back in ten minutes or in an hour, opens
one tab, and must see **where the work stands, what is already done, what is still coming, and
whether anything is waiting on him** — without reading the chat and without asking.

That is the whole job of this board. It is a dashboard: not a log and not a report.

## Two files per task, two different readers

The journal and the board sit side by side, same basename, same folder:

```
.claude/tasks/CART-33038.md      # journal — for you and the next session
.claude/tasks/CART-33038.html    # the board — for the user
```

| | `<task>.html` | `<task>.md` |
|---|---|---|
| Reader | the user | you, the next session |
| Content | current state, conclusions only | open questions, findings, dead ends, reasons |
| Shape | rewritten in full, one screen | STATE rewritten, Log appended |
| Language | **Russian** | English |

Reasoning goes to the journal. The board gets the conclusion. Never duplicate the Log onto the
board — a board that grows is a board that stops being read.

The board is a strict view of `## STATE`: if STATE says the task is blocked, so does the board.
When they disagree, both are wrong until you fix them together.

## Language exception

The kit's rule is "everything except chat in English". **The board is the exception and is
written in Russian**, because it is a surface the user reads, exactly like a chat message. It
is never read back into context, so Russian costs nothing here.

## Where it lives, and why it is never committed

`.claude/` is already required to be gitignored before anything is written into it. Do not
assume it — verify at creation, and if it is not ignored, exclude it *locally* rather than
editing a `.gitignore` that other people share:

```bash
git check-ignore -q .claude/ || \
  echo ".claude/" >> "$(git rev-parse --git-dir)/info/exclude"
```

`.git/info/exclude` is per clone and never committed, which is why it is used here.

**The board never goes in `/tmp`, in the scratchpad, or anywhere else session-scoped.** It has to
survive a `/clear` and it has to be somewhere the user can reopen without a fresh link from you.
A task brief that says "create no files except X" does not apply here: `.claude/` is gitignored,
so writing the board there is not creating a file in the project. If the checkout genuinely cannot
hold it, say so in one line and carry on — but do not silently downgrade to a temp path.
Measured 2026-08-06: a board written to the session scratchpad did not open for the user at all,
and the whole run was invisible to him.

One board per task. Starting the next ticket creates its own board; the finished one stays on
disk as the record of that task and is never touched again.

## When to write it

Create it as the **first action of the task**, before any research, while it still says only
"начал" — an empty board that exists beats a perfect board that appears twenty minutes in.

Then rewrite it in full at every one of these:

- a stage starts or finishes
- a subagent is dispatched, and again when it returns
- a decision is taken
- something blocks, or something starts waiting on the user
- **before anything that will run longer than about two minutes** — so the board explains the
  silence instead of looking frozen
- the task ends: status `готово`, no current stage, final decisions in place

The board must never be more than one stage behind reality. If you are about to do something and
the board does not say so, write the board first.

The board link opens **every chat message** — the bare URL on its own first line, nothing else
on that line, even when the board did not change (⭐ standing instruction, 2026-08-16: he refused
to scroll the chat hunting for it). Use the clickable form the project has established (a local
`http://localhost:…` server if one is running, otherwise a full `file://` URL with the absolute
path — a bare or relative path is not clickable). Beyond that line the updates are silent: they
are never narrated, never become a message, and never count against the three-sentence limit.

## How to write it

Copy `templates/board.html` and fill it in. **Always replace the whole file** — never append.
Growth is the failure mode.

**If nothing changed, do not rewrite it.** Compare what you are about to write with what is on
disk; identical means skip the write entirely. A board rewritten for the sake of the timestamp
burns tokens and tells him nothing.

### The structure is fixed. Do not invent another one.

He has watched ten sessions draw ten different boards. The template is the answer, and these are
its parts in page order. Nothing is added, nothing is reordered, nothing is renamed.

1. `.kicker` — `Борд · обновлено ЧЧ:ММ:СС`. **Seconds are mandatory**: without them he cannot
   tell a board that updated ten seconds ago from one that froze half an hour ago.
2. `h1` — the whole chat's work in one line. This is also the list's heading: there is **no
   «Оглавление»**, no «Содержание», no heading over the tree at all.
3. `.sub` — one line, only if the title alone is not enough. Otherwise delete the element.
4. `.total` — the overall progress **line** (never a ring or a donut), the percent, the counts,
   and `.drift` when the percent went backwards.
5. `.cols` — the tree on the left, three blocks on the right.
6. `.stamp` — one line, the last thing on the page.

The right column holds **exactly three blocks, in this order**: «Ждёт от тебя», «Сейчас»,
«Решено по дороге». There is never a fourth. He praised this page for having nothing spare on
it; a block you think would help goes in the journal instead.

### The tree

- **Three levels maximum.** A fourth level means the task was cut too fine — merge it.
- **A top-level item is a TASK.** One chat is one board, but a chat may hold several tasks, and
  then each is its own top-level item with its own bar in its own row. The overall bar at the top
  stays and covers all of them.
- Every top-level row is: `.num`, `.label`, `.grow`, `.mini` (its own progress line), `.count`.
- State classes on the `li`: `done`, `live`, `todo`. Nesting is `ul.lvl2`, then `ul.lvl3`.
- **Exactly one `li.here` on the whole board**, carrying the `here-tag` span «сейчас здесь» — the
  leaf you are inside at this second. Two arrows, and he has to read the whole page to find you.
  The single case with no arrow is a board where everything is closed and only his action is
  left; the block on the right then carries `.you.stop` and says so.
- The item that waits on him carries the `wait-tag` span «ждёт тебя», and the same thing is
  spelled out in the block on the right.

### The percent is counted over the LEAVES

Count the deepest items only, never the sections. Done leaves ÷ all leaves.

- **It is allowed to go backwards, and it must.** Adding four subitems to a 63% board makes it
  42%, and that is the honest number. Say so in `.drift`: `было 63%, добавилось 4 подпункта`.
- **The header must add up to the sections.** `12 из 19` in the total has to equal the sum of the
  `count` cells below it. An earlier board shipped with numbers that disagreed and he caught it
  immediately; check the arithmetic before every write.
- `.f-done` is the closed share, `.f-live` is a thin slice for what is running right now.

### Three states of the block on the right

| Class | When | What he reads |
|---|---|---|
| `.you` | there is a click of his, and I keep working meanwhile | yellow, one action, and that the work goes on |
| `.you.idle` | nothing is waiting on him | a calm frame: what will appear here and roughly when |
| `.you.stop` | there is no work left at all without him | red, and I have stopped |

**Only what he can physically do gets in there**: a click, a sign-in, a one-time code, a
signature, something judged by eye. A question you could answer from the repository, the ticket,
the design or the history is never his — see the output style. One action per line, and the
button carries the exact link, already opened in his browser where that is possible.

### What never goes on the board

- No paragraphs. One line per item; a thought needing a second line is cut or moved to the journal.
- No history. The board is the present tense: what was decided three days ago is not on it.
- No shas, no decision ids, no file paths, no English technical terms in the body.
- No tables of runs, no logs, no token counts, no subagent names.
- No emoji.
- The left tree fits one screen without scrolling. Overflow is deleted, never shrunk.

### Live refresh, and the reload ban

The template refreshes by background `fetch` with a `document.body` swap, every 15 seconds. These
are **forbidden and blocked by `hooks/page-guard.sh`**: <code>&lt;meta http-equiv="refresh"&gt;</code>,
`location.reload`, `window.focus`, <code>autofocus</code>, `alert`, `Notification`,
`window.open`. Each of them makes Chrome steal focus and drag his macOS Space to the browser
mid-work. This is why the template looks the way it does — do not "simplify" it back.

### It has to survive a `/clear`

- It lives at `.claude/tasks/<task>.html`, on disk, always — never the scratchpad, never `/tmp`.
- Its path is named in `STATUS.md`, so a fresh session finds it without asking him.
- Its link opens **every** chat message, the bare URL on its own first line.
- Both themes live in the one file. It follows his system by default, and the three buttons in
  the header (авто / светлая / тёмная) force one; the choice is kept in `localStorage` and
  survives the background refresh. There is never a second file for the dark version.

## Rules

- One board per task, and a board another session created is never rewritten by you.
- Russian on the page, English everywhere else in the kit.
- Rewrite in full or not at all. Never append, never grow.
- Never more than one stage behind reality. If you are about to do something the board does not
  mention, write the board first.
- Never narrate an update. The link on the first line is the whole announcement.
