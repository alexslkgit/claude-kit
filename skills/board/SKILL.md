---
name: board
description: The board — one live HTML page per task that shows the user where the work stands. Written ON REQUEST ONLY, when he says «борд», «покажи борд», «обнови борд», "board", "update the board". Create it at the start of a task and close it at the end; between those, only when he asks.
allowed-tools: Read, Write, Edit, Bash, Glob
---

# The board

He opens one tab and sees where the work stands, what is done, what is coming, and whether
anything waits on him, without reading the chat. A dashboard, not a log and not a report.

## On request only

⭐ **Standing instruction, 2026-08-31.** Write the board when he asks for it, at the start of a
task, and at the end. **Not at every stage change, not at every decision, not before a long
operation.** Measured across 45 days of transcripts: 5 961 board calls in 328 sessions, a median
of **14 board calls per session**, and a request costs ~$0.105 whatever it carries. That is about
$1.50 of upkeep per session, and he was not reading thirteen of those fourteen.

The link still opens **every** chat message, bare URL on its own first line (⭐ 2026-08-16). The
page is therefore a snapshot, not a live feed: `stamp` says when it was last written, and that is
honest. Never narrate an update; the link is the whole announcement.

## Where it lives

| | |
|---|---|
| on the shelf, the common case | `~/Tasks/<task>/board.html`, beside that task's `STATUS.md`, `DECISIONS.md`, `journal.md`, `plan.html` |
| inside a checkout | `<repo>/.claude/tasks/<task>.html`, beside the journal of the same basename |
| the link, always | `http://localhost:8899/<task>/board.html` · in a repo `…/_repos/<repo>/<task>.html` · index `…/index.html` |

A LaunchAgent (`com.alexslk.tasks-board-server`) serves `~/Tasks` permanently, so the link
survives a reboot and a `/clear`. Over http the page refreshes itself in a tab he already has
open; from disk it cannot. Never the scratchpad, never `/tmp`.

**Boards stay local and stay out of git.** `claude-kit` is a public repository: the skill and the
shell belong there, a board holding his task state does not. In a checkout, verify `.claude/` is
ignored and exclude it locally rather than editing a shared `.gitignore`:

```bash
git check-ignore -q .claude/ || echo ".claude/" >> "$(git rev-parse --git-dir)/info/exclude"
```

One board per task. A board another session created is never rewritten by you.

## The file is JSON. You never write markup.

The page is an eight-line skeleton from `templates/board.html` around one block, and that block is
the only thing you ever write:

```json
{
  "stamp": "14:32:07",
  "title": "весь смысл работы одной строкой",
  "sub": "одна строка, если заголовка мало; поле можно опустить",
  "tasks": [
    { "t": "закрытая задача", "state": "done", "open": false, "closed": 6 },
    { "t": "задача в работе", "state": "live", "closed": 4, "items": [
      { "t": "пункт, в котором я сейчас", "state": "here" },
      { "t": "пункт, который ждёт его", "state": "wait" },
      { "t": "ещё не начатый пункт", "state": "todo" }
    ] }
  ],
  "you": { "cap": "Ждёт от тебя · 1", "h": "одно его действие", "p": "что готово вокруг",
           "btn": { "href": "plan.html", "label": "Открыть инструкцию" }, "stop": false },
  "now": "одна строка о том, что я делаю сейчас",
  "decided": [ { "t": "решение и причина, детали в <a href=\"…\">PR #12</a>" },
               { "t": "тупик и почему больше не пробуем", "dead": true } ]
}
```

`state` is `done`/`live`/`todo` on a task, `done`/`todo`/`wait`/`here` on an item. `you`, `now`,
`decided` are optional and absent when there is nothing to say. Values print as written, so `<a>`,
`<b>` and `<span class="pill">` work inside them. There is an optional `daily` block for standup
data in team projects; it is used on one board in thirty-four, so do not add it unprompted.

**Never a `<style>`, never a `<script>`, not even once.** The look is `_shell/board.css`, the
behaviour `_shell/board.js`, copied from the kit's `board-shell/` beside the page. Inline markup
was 12 KB re-emitted into context on every rewrite; `hooks/shell-guard.sh` refuses over 500 bytes
of it. Restyling means editing `board-shell/` in the kit and re-copying, never patching a page.
Copied and not linked, so the folder can be moved or zipped whole. Never point a page at
`raw.githubusercontent.com`: it must render with no network.

```bash
SRC="${HOME}/.claude/board-shell"; [ -d "$SRC" ] || SRC="${HOME}/Developer/claude-kit/board-shell"
mkdir -p _shell && for f in board.css board.js render-body.js; do
  [ "$SRC/$f" -nt "_shell/$f" ] && cp "$SRC/$f" "_shell/$f"; done
```

**You will find rendered markup and a style block in a board on disk anyway. Leave them.**
`hooks/board-inline.sh` and `hooks/board-bake.sh` put them there after the tool call, out of
context, because the app's own pane does not load sibling `_shell/*`. `board-inline.sh` also
matches `Bash`, so on a normal update it is the one that runs and there is no `__baked` block to
look for. `board-bake.sh` runs the real renderer and fails loudly on a key the renderer does not
know, which is the schema check. Neither is yours to invoke or to hand-edit.

## Mutate in place. Never a whole-file `Write`, never a read-back.

```python
d = json.load(open(p))
d["tasks"][0]["items"].append({"t": "новый пункт", "state": "todo"})
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2)
```

Both halves are still being broken, measured over the same 45 days: 474 whole-file `Write` calls at
a median of 7 688 characters, against 598 for a mutate, and 394 `Read` calls that pulled a median
of 8 904 characters of board back into context for nothing. If you need to know what one entry
says, have the script print that entry. If nothing changed, do not run the script at all.

Re-parse the file afterwards to confirm it is still valid JSON.

## Size, and why boards rot

⭐ **His instruction, 2026-08-31**, given while looking at a board with twenty subitems under a
single point. Measured the same day across 58 boards on disk: the worst carried 22 top-level
tasks, 54 children under one of them, 159 items, and 115 of those items over 120 characters.
The rules below existed and were applied on 3 boards of 58, because nothing enforced them.
`hooks/board-guard.sh` now does.

- **A `done` child is deleted, not kept and not struck through.** The parent carries
  `"closed": <n>` so the percentage does not move, and the parent's own line says in one clause
  what the closed work achieved, if it is worth saying.
- **A finished group therefore has no `items` at all**: one folded line, `"state": "done"`,
  `"open": false`.
- **At most 5 open children under any one point.** More than five means the work was cut too fine
  for his eyes: raise the description a level and let the detail live in `journal.md`.
- **Fewer than three genuinely open facts is not a group.** The fact goes on the parent's line and
  the group carries no `items`. A group of one costs him a fold and says nothing.
- **One line per item. Hard ceiling 120 characters, aim for 80. One fact per item.** An item
  carrying three facts keeps the one that matters; the rest is dropped, not split into three.
- **Three levels maximum**, and exactly one item on the whole board with `"state": "here"`.
- **Do not write the small steps you take.** A subagent launched, a file read, a grep run, a test
  re-run are not board items. The board is what he would tell someone about the work, not what
  you did to get there. This is the single reason boards grow to twenty children.
- The left tree fits one screen. Overflow is deleted, never shrunk.

Derive the mechanical part at the end of every write, never by hand:

```python
for t in d["tasks"]:
    kids = t.get("items") or []
    done = [k for k in kids if k.get("state") == "done"]
    if done:                                     # delete them, keep the count honest
        t["closed"] = t.get("closed", 0) + len(done)
        kids = [k for k in kids if k.get("state") != "done"]
        t["items"] = kids
    if not kids:
        t.pop("items", None); t["state"], t["open"] = "done", False
```

## The shape is fixed

`.kicker` (`Борд · обновлено ЧЧ:ММ:СС`, **seconds mandatory**) · `h1`, the whole work in one line
and the tree's only heading · `.sub` · `.total`, the progress line, never a ring · `.cols`, tree
left, three blocks right · `.stamp`. The right column holds **exactly three blocks in this order**:
«Ждёт от тебя», «Сейчас», «Решено по дороге». There is never a fourth.

The renderer counts leaves and computes every percentage and count, so you never write one and the
header can never disagree with the list. The percent is allowed to go backwards when work is added;
say why in `drift`.

«Ждёт от тебя» holds **only what he can physically do**: a click, a sign-in, a one-time code, a
signature, something judged by eye. Its `btn` points at that one action, which is a `plan.html`
only when the action really is a sequence of steps. Absent when nothing waits on him;
`"stop": true` when there is no work left at all without him.

## Never on the board

No paragraphs, no history, no shas, no decision ids, no file paths, no English technical terms in
the body, no emoji, no tables of runs, no logs, no token counts, no subagent names. Every ticket,
PR, build or channel that has a URL is an `<a>`, never bare text; the URL shapes live in the
project's `CLAUDE.local.md`.

Russian on the page, English everywhere else in the kit. The board is a surface he reads, like a
chat message, and is never read back into context.

## The page may never grab his screen

<code>&lt;meta http-equiv="refresh"&gt;</code>, `location.reload`, `window.focus`,
<code>autofocus</code>, `alert`, `Notification` and `window.open` are forbidden and blocked by
`hooks/page-guard.sh`. Each one drags macOS to the browser mid-work. The refresh is a background
`fetch` with a body swap every 15 seconds and it lives in `_shell/board.js`, never in the page.
