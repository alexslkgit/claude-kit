---
name: chew
description: Write a chewed step-by-step plan for something the user has to do with his own hands — an App Store Connect form, a bank, a government portal, a device setting. Every step is read off the real screen first, never from memory, and a screen that cannot be seen yet is marked unseen instead of guessed. Use whenever he says «разжуй», «разжуй мне», «разжёванный план», «план как для», «чтобы я не ошибся», «пошагово», «по шагам», "chew it up", or "a step-by-step plan I cannot get wrong". Also use unprompted whenever the answer to his question is a sequence of manual actions in a UI you can open.
---

# Chew it up

He reads a plan. On step 3 the menu is called something else than the plan says. They go back and
forth. By step 6 he closes the laptop and goes for coffee, and the task dies — not because it was
hard, but because the instruction stopped matching the screen.

Everything below exists to make that impossible. The output is not a document, it is a **live page
next to him while he works**, and the rules are about where the words in it come from.

## The one unforgivable failure

**Never invent a screen.** A step describing a dialog you did not see is worse than no step: it
teaches him that the whole page is a guess, and then he stops trusting the steps that were real.

When the next screen is behind a gate you cannot pass — it appears only after he signs, pays,
selects a country, receives an SMS — the plan says so and **stops there**:

> **Этого экрана я не видел** — Apple показывает поля счёта только после выбора страны. Дойдёшь —
> скинь скриншот, допишу шаги сюда.

That sentence is what earns the trust that makes him follow the other nine steps.

## Ten rules

1. **No step written from memory.** Before writing a step, open the actual thing and read the real
   labels off the screen: the real page in **his own Chrome** via the `mcp__claude-in-chrome__*`
   tools (his session, his account, his data — that is the point), the real app in the simulator,
   the real CLI. Documentation is a hint about where to look, never the source of a step. If the
   docs and the screen disagree, the screen wins and the docs are wrong.
2. **A gated screen is marked unseen and the plan stops.** See above. Never bridge the gap with
   "дальше, скорее всего, попросят…".
3. **Verbatim labels, plus where the control physically is.** Quote the button exactly as it is
   written, in its own language (`Edit Legal Entity`, not «изменить юрлицо»), and say where it sits:
   «синяя ссылка в конце голубой полосы сверху», «правый край строки, третья сверху». The phrase
   **«найди на странице» must never appear in a rendered plan** — if you are tempted to write it,
   you did not look at the screen.
4. **One action per step**, and every step ends with the visible confirmation: `ok` renders as
   «Получилось, если …». If you cannot name what changes on screen, the step is two steps or you
   did not see it.
5. **A «приготовь заранее» block at the top**, listing every number, document, password and account
   the whole flow will need. Nothing may be discovered mid-flow — a missing IBAN found on step 7 is
   the same failure as a wrong label.
6. **Forks only when real.** A fork is a branch you actually observed or a trap you actually hit.
   Hypothetical «если вдруг появится окно…» is noise that makes the page look unreliable.
7. **Only what physically needs his hands, and you must have proof.** Anything you can do yourself
   is not a step — it goes into the short `mine` block at the end so he can see it exists and
   ignore it. **Before a step is allowed into the plan, run the thing yourself and record the tool
   you invoked and the error it returned**, in a `fork` on that step. No attempt means it is not
   his step, and a plan that fails this test wastes the one thing he cannot get back.
   Three things that are *not* proof of a gate:
   - *«за его логином»* — his Chrome is already signed in, and the `mcp__claude-in-chrome__*` tools
     reach it. Reading a page costs him nothing. Only a password field, a one-time code, a physical
     device or a decision genuinely stops you.
   - *«кончался контекст»* — never a reason to hand him work. Hand off to a fresh session instead.
   - *a CLI refusing non-interactive mode* — give it a pseudo-terminal:
     `script -q /dev/null <command>`. It then prints its URL or prompt and waits, and the browser
     half you can usually finish yourself.
   When a step really is his, **the command goes in the step's own visible block, never folded into
   a `fork` behind «подробнее»**. He should be able to run it without reading anything first.
   Recorded 2026-08-13, after five such steps reached him in one plan.
8. **THE PAGE IS ALIVE — EVERY SINGLE EXCHANGE ENDS WITH THE FILE PATCHED, NO EXCEPTIONS.** Not
   "when it changes materially." Every time, while the plan is open, whatever he said. He asks a
   question, you answer it in chat — that answer also becomes data in the file, at the step it
   concerns, before you consider the turn done. Concretely, every reply maps to a patch:
   - He reports a step done → that step's `status` becomes `done`; the step he is now on stays
     `todo`.
   - He sends a screenshot of a screen you had marked "не видел" → the fork with that line is
     replaced by the real steps read off the screenshot.
   - He asks a question and you answer it → the answer becomes a `fork` on the step it belongs
     to, or a `note` on the stage if it is broader than one step.
   - He says something is ready (a document, a number, a password he now has) → it moves into the
     `prep` block, or off it if it was the last missing item.
   Never announce the patch as a task — no "сейчас обновлю план", no "дай обновлю файл". Just do
   it, silently, as part of answering, and keep the chat reply itself to at most three sentences.
   Only the JSON block is ever edited; the HTML around it was written once and is never rewritten.
   Never create a second file for the same task, never leave the answer only in the chat, never
   send him a corrected copy of the whole plan.
9. **A dated provenance line at the bottom** (`verified`): what you opened with your own eyes, and
   when. It is the reason he believes rule 2.
10. **Screenshots only where words genuinely cannot locate a control** — an unlabelled icon, one
    row among twenty identical ones. Cropped to the control, never a full page. They cost tokens on
    every read.

## The plan and the board are one pair

⭐ **Standing instruction, 2026-08-20.** They are two files with two jobs — the board says where
the *run* stands, the plan says what *he* does next — and he reaches the second one **through the
first**. Never merge them, and never let the plan exist only as a link in a chat message.

His words, after a session handed him a plan link in the body of a message: «если я говорю тебе
про инструкцию, ты на свой основной борт должен дать ссылку на него… по нажатию на ссылку я
перехожу на нашу же инструкцию». The reason is mechanical: every chat message opens with the board
URL and nothing else, so the board is the only address he has memorised. A plan the board does not
point at is a plan he cannot find tomorrow morning.

Three things follow, and none of them is optional:

1. **Writing a plan means patching the board in the same turn.** The board's «Ждёт от тебя» block
   becomes the entrance: its `a.btn` links to the plan, and its text says what the first step is.
   Not a mention somewhere on the page — the call-to-action itself.
2. **They look like one product.** `plan.css` carries the board's palette and typefaces on purpose.
   If you restyle one, restyle the other in the same commit.
3. **The board link still opens every message.** The plan link may appear in the body once, when
   the plan is new. After that, point at `board.html` and let him click through — or point at one
   step, `plan.html#step-6`, when you mean exactly that step.

## Files

Two layouts, and which one applies is decided by a single question: **is this a git checkout?**

**Inside a repository** — many tickets share one project, so the plan sits beside the board:

```
.claude/tasks/<task>.plan.html    # the chewed plan — for him, Russian
.claude/tasks/<task>.html         # the board — for him, Russian
.claude/tasks/<task>.md           # the journal — for you, English
.claude/tasks/<task>.img/         # cropped screenshots, only if rule 10 forced one
.claude/tasks/_shell/             # plan.css + plan.js, copied from the kit
```

**Outside a repository** — the task shelf is `~/Tasks`, not a project directory, and
each task is its own world. The task gets a folder and everything in it is flat and stably named,
so a link never changes and the whole task can be zipped, moved or deleted as one thing:

```
~/Tasks/<task>/plan.html      # the chewed plan
~/Tasks/<task>/board.html     # the board
~/Tasks/<task>/journal.md     # the journal
~/Tasks/<task>/STATUS.md      # current state
~/Tasks/<task>/DECISIONS.md   # append-only
~/Tasks/<task>/_shell/        # plan.css + plan.js
~/Tasks/<task>/.claude/status-dir   # one line: the absolute path to this folder
```

Recorded 2026-08-20: three unrelated tasks had been sharing one `~/Downloads/.claude/`, so the
session-start hook announced a third task's STATUS.md as this task's memory, and the task actually
being worked on had no STATUS.md at all.

`.claude/` must be gitignored before you write into it — verify, and exclude it locally rather than
editing a shared `.gitignore`:

```bash
git check-ignore -q .claude/ || echo ".claude/" >> "$(git rev-parse --git-dir)/info/exclude"
```

### Install the shell first (once per repo)

```bash
SRC="${HOME}/.claude/plan-shell"
[ -d "$SRC" ] || SRC="${HOME}/Developer/claude-kit/plan-shell"
mkdir -p .claude/tasks/_shell
for f in plan.css plan.js; do
  if [ ! -f ".claude/tasks/_shell/$f" ] || [ "$SRC/$f" -nt ".claude/tasks/_shell/$f" ]; then
    cp "$SRC/$f" ".claude/tasks/_shell/$f"
  fi
done
```

Copied, not linked: relative paths work on all three of his Macs whatever the username, offline,
from a `file://` URL, with no MIME surprises. **Never point a plan at raw.githubusercontent.com.**

## The plan file: data, never markup

**The instance file contains only data. Styling and behaviour are never emitted into it — not
once, not "just this bit". The shell is edited in `plan-shell/` in the kit and re-copied.**
`hooks/shell-guard.sh` refuses any page whose inline `<style>` or `<script>` runs over 500 bytes.

The whole file is this — a JSON block plus two relative includes. If you find yourself writing a
`<div>`, stop: the renderer owns the markup, you own the data.

```html
<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<!-- No auto-refresh: a reload yanks his macOS Space to the browser. A plan is static;
     after editing it, tell him to reload the tab. Enforced by hooks/page-guard.sh. -->
<meta name="viewport" content="width=device-width, initial-scale=1">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Commissioner:wght@400;500;600;700&family=Literata:opsz,wght@7..72,400;7..72,600;7..72,700&display=swap">
<link rel="stylesheet" href="_shell/plan.css">
</head>
<body>
<script type="application/json" id="plan">
{ … }
</script>
<script src="_shell/plan.js"></script>
</body>
</html>
```

The `<meta refresh>` is load-bearing: he keeps the tab open, you patch the file, his tab shows the
patch a minute later without being told. The renderer restores his scroll position and remembers
the «скрыть выполненные» toggle across that reload.

### The schema

```jsonc
{
  "title":    "Монетизация: подключить счёт",         // h1
  "subtitle": "<span class=\"pill\">…</span> …",       // one dim line under it, pill optional
  "verified": "Проверено вживую 9 августа: …",         // rule 9, renders at the bottom
  "notes":  [ { "kind": "good|warn|prep", "head": "…", "body": "html" } ],   // prep = rule 5
  "stages": [ { "title": "Этап 1 — …",
                "notes": [ … ],                        // optional, same shape, shown inside the stage
                "steps": [ {
                  "do":     "Нажми <b>Edit Legal Entity</b>",       // one action, rule 4
                  "where":  "Синяя ссылка в конце голубой полосы",  // rule 3
                  "ok":     "открылось окно с восемью полями",      // renders as «Получилось, если …»
                  "forks":  [ "…" ],                                // rule 6; also the "не видел" line
                  "links":  [ { "text": "…", "href": "https://…" } ],
                  "img":    { "src": "<task>.img/step-4.png", "cap": "…" },  // or just a path string
                  "status": "todo|done|blocked"                     // default todo
                } ] } ],
  "mine": [ "…", "…" ]        // rule 7; or { "title": "…", "items": [ … ] }
}
```

Ten things the renderer already does, so never do them by hand:

- **Numbering is computed from position and never stored.** Inserting step 4 renumbers everything
  after it for free — that is why patching is cheap and a second file is never needed.
- `done` renders struck through and dimmed, `blocked` in the amber warning colour.
- A progress line «Сделано 5 из 9» with a bar, and a «скрыть выполненные» toggle.
- A stage whose steps are all `done` collapses itself; a click expands it.
- Every step has a stable anchor `#step-N`, and the number circle is that link — so a chat message
  can point at exactly one step: `…/monetization.plan.html#step-6`. Pointing at a step that is
  hidden or inside a collapsed stage still works: the renderer reveals it and flashes it.
- Links become real clickable `<a>` opening in a new tab. He has complained that they were not.
- Images are capped at `max-width:100%`, path relative to the plan file.
- Dark and light follow the system, and the page is readable on a phone.
- `title` also becomes the browser tab title.
- Strings may carry inline HTML — `<b>` for a label he must find, `<code>` for something he types
  verbatim, `<i>` sparingly. Bold exactly the words that appear on his screen; bolding a whole
  sentence makes the label unfindable.

Everything he reads is in **Russian** — the kit's "English everywhere except chat" rule does not
apply to a surface he reads, exactly as with the board. Keep the labels themselves in their
original language.

`plan-shell/example.plan.html` in the kit is a working plan that uses every field; open it when
unsure what a field does, and copy its shape.

## The run

1. Open the real thing and walk the flow yourself as far as the gate lets you, capturing labels as
   you go. This is the expensive part and it is the whole value — do not shorten it.
2. Write the file: prep block, stages, steps, `mine`, `verified`.
3. Send the link **once**, as a full clickable `file:///Users/…/.claude/tasks/<task>.plan.html`
   URL, with one sentence saying what the first step is and where you stopped seeing screens.
4. He works. Each time he reports back: patch the file (`status` to `done`, new steps inserted,
   the "не видел" fork replaced with the steps you can now see because he sent a screenshot), and
   reply in chat in at most three sentences, linking `#step-N` when you mean a particular step.
   Patching is an `Edit` inside the JSON block; never rewrite the file from scratch and never
   restate the plan in the chat.
5. When the last step is `done`, say so in one line. The file stays on disk as the record.

## Never

- Never put a password, a token, a full card number or a full IBAN into the page. Say which
  document to take it from; he types it.
- Never write a step whose confirmation you cannot name.
- Never describe a menu path you have not walked in this session — labels change between releases,
  locales and A/B buckets, and your memory of them is exactly the thing that ruins his morning.
- Never ask him to re-read the plan from the top. Point at `#step-N`.
- Never let a literal `</script>` sit inside a JSON string — it closes the data block and the page
  renders «План не отрисовался». Write `<\/script>`. Same for an unescaped `"` inside inline HTML:
  the renderer reports the JSON error with the parser's message, so if he says the page is empty,
  ask for that line rather than guessing.
