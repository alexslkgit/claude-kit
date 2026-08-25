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

## The board is the front door, the instruction is a room behind it

⭐ **Standing instruction, 2026-08-20.** When a task also has a chewed instruction (the `chew`
skill, `plan.html`), **the board's «Ждёт от тебя» block is how he gets to it.** Its `a.btn` links
straight at the plan and its text names the first step. His words: «по нажатию на ссылку я перехожу
на нашу же инструкцию».

This is not decoration. Every chat message opens with the board URL and nothing else on that line,
so the board is the one address he has. An instruction the board does not point at is an
instruction he will not find tomorrow — and he has already opened the board expecting the
instruction and found neither a link nor a mention.

```html
<div class="you">
  <div class="cap">Ждёт от тебя · 1</div>
  <h2>Четыре экрана из Резерв+</h2>
  <p>Первый шаг: нажать «Сповіщення» справа сверху и снять весь список.</p>
  <a class="btn" href="plan.html">Открыть инструкцию</a>
</div>
```

**The button is not a plan link by default — it is a link to whatever his one action is.** Most
tasks have no chewed instruction at all, and there the `a.btn` goes where it always went: the
pull request to approve, the settings page to open, the App Store Connect form to sign, the draft
to send. A plan is simply the commonest case of "his one action is a sequence of steps", and then
the button opens the plan instead of naming a step in prose. Wiring a board to a plan that does
not exist, or replacing a real destination with a plan link, is the opposite failure.

The two pages share one palette and one pair of typefaces on purpose — `board-shell/board.css`
and `plan-shell/plan.css` hold the same variables. Restyle one, restyle the other in the same
commit; never restyle inside a page.

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

### The board file is DATA ONLY. The shell is never emitted twice.

The look lives in `board-shell/board.css` and the behaviour in `board-shell/board.js`, copied
once into `_shell/` next to the page. **The board file itself carries markup and data and
nothing else: no `<style>`, no `<script>`, ever, not even "just this once".** A board is
rewritten in full at every stage change, decision and blocker, so anything inline is re-emitted
every time — into a context that is re-sent on every later request of the session. Measured
2026-08-21: 9.5 KB of CSS and 2.7 KB of JS per rewrite, none of it ever changing.

Restyling the board, adding a state, fixing a colour: edit the shell file **in the kit**, then
re-copy it. Never patch a page's appearance in the page. `hooks/shell-guard.sh` refuses any page
whose inline `<style>` or `<script>` runs over 500 bytes.

Install the shell once per repo or task folder, before the first board:

```bash
SRC="${HOME}/.claude/board-shell"
[ -d "$SRC" ] || SRC="${HOME}/Developer/claude-kit/board-shell"
mkdir -p .claude/tasks/_shell            # outside a checkout: <task>/_shell
for f in board.css board.js; do
  if [ ! -f ".claude/tasks/_shell/$f" ] || [ "$SRC/$f" -nt ".claude/tasks/_shell/$f" ]; then
    cp "$SRC/$f" ".claude/tasks/_shell/$f"
  fi
done
```

Copied, not linked: a relative path works from a `file://` URL with no server, on all three of
his Macs whatever the username, and the task folder can be moved or zipped whole. A symlink into
`~/.claude` breaks the moment the folder is copied, and an absolute path breaks on the next
machine. **Never point a page at raw.githubusercontent.com.**

If a finished page has to travel on its own — mail, a Cowork artifact, someone without the
folder — fold the shell back in for that copy only:

```bash
python3 ~/.claude/tools/inline-shell.py .claude/tasks/<task>.html
```

### The page is JSON. You never write board markup.

`_shell/board.js` draws the page. The board file is one `<script type="application/json"
id="board">` block inside an eight-line skeleton, and **that block is the only thing you ever
write**. No `<div>`, no `<li>`, no percentages computed by hand: the renderer counts the leaves,
fills the bars and prints the counts, so the header can never disagree with the list below it.

```json
{
  "stamp": "14:32:07",
  "title": "всё, что делает этот чат, одной строкой",
  "sub": "одна строка, если без неё непонятно; поле можно опустить",
  "drift": "было 63%, добавилось 4 подпункта",
  "tasks": [
    { "t": "закрытая задача", "state": "done", "count": [2, 2] },
    { "t": "задача в работе", "state": "live", "items": [
      { "t": "закрытый пункт", "state": "done" },
      { "t": "пункт, который ждёт его", "state": "wait" },
      { "t": "ветка с третьим уровнем", "items": [
        { "t": "пункт, в котором я сейчас", "state": "here" }
      ] }
    ] }
  ],
  "you": { "cap": "Ждёт от тебя · 1", "h": "одно его действие", "p": "что уже готово вокруг",
           "btn": { "href": "plan.html", "label": "Открыть инструкцию" }, "stop": false },
  "now": "одна строка о том, что я делаю в эту секунду",
  "decided": [ { "t": "решение и причина, детали в <a href=\"…\">PR #12</a>" },
               { "t": "тупик и почему больше не пробуем", "dead": true } ],
  "daily": { "since": "вчера 10:15",
             "news": [ { "src": "PR", "t": "строка со <a href=\"…\">ссылкой</a>" } ],
             "say":  [ "что сдвинулось", "чем занят", "что дальше" ] }
}
```

Values print as written, so `<a>`, `<b>` and `<span class="pill">` inside them work. `state` is
`done` / `live` / `todo` on a task, and `done` / `todo` / `wait` / `here` on an item. A task with
no children listed carries `count: [сделано, всего]`; a task with children needs no count at all.
`you`, `now`, `decided`, `daily` are each optional and are simply absent when there is nothing to
say. `open: false` starts a branch folded.

The skeleton around the block is fixed and is copied from `templates/board.html` once:

```html
<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>…</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Commissioner:wght@400;500;600;700&family=Literata:opsz,wght@7..72,400;7..72,600;7..72,700&display=swap">
<link rel="stylesheet" href="_shell/board.css">
<script src="_shell/board.js" defer></script>
</head>
<body>
<script type="application/json" id="board">
{ … }
</script>
</body>
</html>
```

**Always replace the whole file** — never append. Growth is the failure mode, and it is a
different failure from the shell one: the whole-file rule is about the data, the shell rule is
about the styling. Measured 2026-08-21 over 30 days of real sessions: 189 board writes carried
649 KB of CSS and JS and 1 143 KB of markup, all of it re-sent on every later request of those
sessions. The same 189 boards as JSON are about a third of the markup and none of the styling.

**If nothing changed, do not rewrite it.** Compare what you are about to write with what is on
disk; identical means skip the write entirely. A board rewritten for the sake of the timestamp
burns tokens and tells him nothing.

### The structure is fixed. Do not invent another one.

He has watched ten sessions draw ten different boards. The renderer is the answer: it emits these
parts in this order and no others, so the shape is not yours to change. Field names below are the
JSON keys, class names are what the renderer produces — you never type the classes.

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
- A top-level row (number, label, its own progress line, its count) is drawn from the task's `t`,
  its position and its leaves. You write `t`, `state` and `items`, nothing else.
- `state` on a task: `done`, `live`, `todo`. On an item: `done`, `todo`, `wait`, `here`.
- **Exactly one item with `"state": "here"` on the whole board** — it prints «сейчас здесь» — the
  leaf you are inside at this second. Two arrows, and he has to read the whole page to find you.
  The single case with no arrow is a board where everything is closed and only his action is
  left; the block on the right then carries `.you.stop` and says so.
- The item that waits on him carries `"state": "wait"` — it prints «ждёт тебя» — and the same
  thing is spelled out in the block on the right.

### Everything with children folds

Any item with `items` folds, and the renderer gives it a stable id from its position (`t2`,
`t3-2`) so the open/closed state survives in `localStorage` across refreshes. Reordering the tree
loses his folds, so append rather than reshuffle when you can.

- Write finished tasks with `"open": false` and running tasks open (the default). The branch
  holding the «сейчас здесь» item is always open.
- Folding is what keeps the ten-second budget when a task has thirty items: he opens the one
  branch he cares about and the rest stays one line each.

### Every name on the board is a link

⭐ **His standing rule.** A ticket key, a pull request number, a build, a Slack thread, a channel,
a page, a repository: if it has a URL, it is an `<a>`, never bare text. A bare number costs him a
search to remember what it even is. The URL shapes per project live in that project's
`CLAUDE.local.md`; look them up instead of guessing.

### The standup section, when the project has one

Optional, full width, under the two columns: `section.daily`. It exists only where there is
something to read (a tracker, a team chat, pull requests) and is **deleted entirely** where there
is not. Never invent its content to fill the space.

He opens the chat ten minutes before the standup and asks for fresh data. The subagents read
Slack, the tracker and the pull requests, and this section is where the answer lands:

- **«С прошлого дейлика»** — what actually changed, one line each, with the source in `.src`
  (`PR`, `JIRA`, `SLACK`) and every identifier linked. What is drafted but not sent is said
  plainly, because sending is his click.
- **«Что сказать на дейлике»** — exactly three lines: what moved, what he is on now, what is
  next. Тезисы, not a script to read aloud. No causes, no test counts, no build numbers.

### The percent is counted over the LEAVES, by the renderer

Done leaves ÷ all leaves, deepest items only, never the sections. **You never write a percentage
or a count**: the renderer computes both, so the header can no longer disagree with the list. That
disagreement used to happen and he caught it on a shipped board.

- **It is allowed to go backwards, and it must.** Adding four subitems to a 63% board makes it
  42%, and that is the honest number. The only manual part is saying why, in `drift`:
  `было 63%, добавилось 4 подпункта`.
- A task with no children listed is the one place a number is written by hand: `count: [5, 12]`.
  Prefer real items over a count whenever there are real items.

### Three states of the block on the right

| Class | When | What he reads |
|---|---|---|
| `you` present | there is a click of his, and I keep working meanwhile | yellow, one action, and that the work goes on |
| `you` absent | nothing is waiting on him | the column starts with «Сейчас» instead |
| `you.stop: true` | there is no work left at all without him | red, and I have stopped |

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

The refresh is a background `fetch` with a `document.body` swap every 15 seconds, and it lives
in `_shell/board.js` — not in the page. Under `file://` Chrome refuses the fetch and the page
simply stays static, which is why a board served over http updates by itself and one opened from
disk updates when he reloads. These
are **forbidden and blocked by `hooks/page-guard.sh`**: <code>&lt;meta http-equiv="refresh"&gt;</code>,
`location.reload`, `window.focus`, <code>autofocus</code>, `alert`, `Notification`,
`window.open`. Each of them makes Chrome steal focus and drag his macOS Space to the browser
mid-work. This is why the template looks the way it does — do not "simplify" it back.

### It has to survive a `/clear`

**Полка раздаётся постоянно, порт 8899.** LaunchAgent `com.alexslk.tasks-board-server` держит
`python3 -m http.server 8899 --bind 127.0.0.1` с рабочей папкой `~/Tasks`, так что любой борд
открывается как `http://localhost:8899/<task>/board.html` без поднятия сервера руками, и ссылка
не протухает после перезагрузки. Индекс всех бордов и планов — `http://localhost:8899/index.html`.
Ссылку `file://` больше не давать: борды тянут `_shell/board.js`, и часть из них по `file://`
не рендерится. Заведено 2026-08-25, когда задачи переехали в `~/Tasks`.

**Борд внутри гит-репозитория отдаётся тем же сервером, через симлинк.** Он остаётся лежать в
`<repo>/.claude/tasks/`, как и положено, а в полке появляется `~/Tasks/_repos/<repo>` →
`<repo>/.claude/tasks`. Ссылка тогда `http://localhost:8899/_repos/<repo>/<task>.html`, и
относительный `_shell/board.js` резолвится сам, потому что он лежит в той же папке. Симлинк
заводится один раз на репозиторий:

```bash
ln -sfn <repo>/.claude/tasks ~/Tasks/_repos/<repo-name>
```

Сервер, полка и генератор индекса ставятся из кита: `install.sh` создаёт `~/Tasks/_shell`,
кладёт LaunchAgent из `templates/tasks-board-server.plist` и пересобирает `index.html` через
`tools/tasks-index.py`. Руками на новой машине делать нечего.


- It lives at `.claude/tasks/<task>.html`, on disk, always — never the scratchpad, never `/tmp`.
- Its path is named in `STATUS.md`, so a fresh session finds it without asking him.
- **Outside a git checkout, the board is `<task>/board.html` in the task's own folder**, next to
  that task's `plan.html`, `STATUS.md`, `DECISIONS.md` and `journal.md`. A scratch directory like
  `~/Tasks` is a shelf holding many unrelated tasks, and a single shared `.claude/` there makes
  one task's memory masquerade as another's. See the `chew` skill's Files section for the layout.
- Its link opens **every** chat message, the bare URL on its own first line.
- Both themes live in the one file. It follows his system by default, and the three buttons in
  the header (авто / светлая / тёмная) force one; the choice is kept in `localStorage` and
  survives the background refresh. There is never a second file for the dark version.

## Rules

- One board per task, and a board another session created is never rewritten by you.
- Russian on the page, English everywhere else in the kit.
- Rewrite in full or not at all. Never append, never grow.
- The page is data. Styling and behaviour live in `_shell/`, are linked, and are never written
  into the page — fix them in `board-shell/` in the kit instead.
- Never more than one stage behind reality. If you are about to do something the board does not
  mention, write the board first.
- Never narrate an update. The link on the first line is the whole announcement.
