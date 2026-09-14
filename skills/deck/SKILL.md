---
name: deck
description: Prepare him for an interview, an exam, or any subject he wants to learn, using HIS OWN card-deck tool at ~/Developer/study-deck — a one-page deck of question cards where he answers first in his own words and only then sees the prepared answer, with a thread under each card and a copy-back button. Use whenever he says «подготовка к собеседованию», «подготовь к собесу», «готовимся к интервью», «изучение новой темы», «хочу разобраться в теме», «колода», «дек», «стопки», «карточки», «прогони со мной вопросы», "prep me for the interview", "deck", "flashcards", "help me learn X" — and ALWAYS before writing any prep or study page of your own. Never build one from scratch: this tool already exists and he spent days on it.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# The deck

`~/Developer/study-deck` — private repo `github.com/alexslkgit/study-deck`. A single-page card
deck: one card per question, the prepared answer locked until he has answered in his own words, a
thread under each card, and a copy button that returns only what he marked and wrote. Built over
many rounds of his own corrections; it is his tool, not a generic idea.

It is not only for interviews. Any material shaped as questions — a new framework, a domain he is
entering, an exam — goes into a deck.

**The failure this skill exists to prevent:** on 2026-08-18 a session wrote a fresh HTML
"interview prep page" for the same company the deck already covers, having never looked for the
deck. He had spent days on the real tool. Whenever the work is "help me prepare" or "help me
learn", the answer is a deck in this repo — never a new page.

## Read before writing anything

**There are two engines in the repo, and only one is current.** `core/` is the engine every new
deck uses. `app/` is the old one, kept only because older decks still load it. Never scaffold on
`app/`: on 2026-09-14 a deck was built on it and he rejected it at first sight as the wrong design.

1. `~/Developer/study-deck/core/README.md` — the contract: `window.DECK`, `round`, `marks`,
   card fields, the four card forms, what the browser stores.
2. `~/Developer/study-deck/STATUS.md` — cold start and live traps. Where it disagrees with
   `core/README.md`, the README wins.
3. A core deck for house style — `decks/system-design-basics/` (his interview deck).

Decks on `core/`: `decks/system-design-basics`, `decks/claude-dev-foundations`, and `decks/_lab`
(the test deck). Everything else in `decks/` is on the old `app/` engine and is not a template.

## New deck

```bash
cd ~/Developer/study-deck && git pull --ff-only && mkdir -p decks/<name> && cp decks/system-design-basics/index.html decks/<name>/index.html
```

Change only the `<title>` in that copy, then write `decks/<name>/data.js` and nothing else. The
`?v=` stamps on the `core/*` links stay exactly as the source deck has them.

Writing a long `data.js` from the main conversation is exactly the spend the kit forbids: hand it
to `page-writer-sonnet` with the source material named by path.

## He answers first, and the first round has NO answers in it

⭐ Standing instruction, 2026-08-19: «Идея того, чтобы я сначала давал ответ, заключается как раз
в том, чтобы не показывать мне лишней информации. Ты написал ответ на сотню строчек — 90 из них я
знаю, а 10 не знаю. Эти 10 и есть полезное. Просто задавай вопрос, я отвечаю, а ты анализируешь
мой ответ и на основании этого пишешь, что мне показать.»

So the deck is built in two moves, and the first one is questions only:

**Round one — `data.js` with `round: 1` and no `a`.** A knowledge card carries `id`, `q`, `tag`
and `reply`, and nothing else the reader can see. A card with no `a` and a reply that is not
`none` is the «про себя» form in `core/README.md`. The engine treats an answerless card as normal:
he answers in his own words, and the card tells him the write-up comes next round. Do NOT write a
prepared answer "just in case" — a hundred lines of which he already knows ninety is the exact
waste this rule exists to end.

**`ref` — the author-only field.** Never rendered, never exported. Put the checklist of points the
full answer must contain there: three to six short lines, enough for the next session to compute
the delta without re-researching the topic. This is where the research goes in round one.

**`q` collapses newlines.** A second language or a second line never goes into `q`: put it in `d`.

**Round two — the delta, and only the delta.** His sent form carries his own wording per card and
the mark he put on each card.

1. Compare his wording against `ref`. What he said correctly is DELETED from the plan, not
   rewritten back at him.
2. `a` becomes the missing piece and nothing else — the few lines he did not have. On a card where
   he pressed «Не знаю», `a` is the whole short answer, because there is no delta to take.
3. `d` holds the trap or the follow-up question he would not survive, if there is one. If there
   isn’t, leave `d` out.
4. Your reply to his answer goes in the card's `from: [{ round: N, t: "…" }]`. His questions are
   never answered in chat prose.
5. Bump `DECK.round` once for the whole deck. His answers of the previous round stay under the
   older key and are shown as «Было · круг N»; nothing of his is copied into `data.js`.
6. A card he answered fully needs no write-up at all. Say so and move on; padding it is how the
   deck stops being read.

A card with `reply: { mode: "none" }` is an instruction, not a question: it carries its content
from round one. `DECK.gate = false`, or `gate` on a single card, turns the gate off where it makes
no sense (a last-minute cram deck, a reference deck).

**Volume is a hard constraint, not a preference.** 2026-08-19, thirty minutes before his interview:
«не нравится объём задач… любой код, если ты мне показываешь и на нём что-то объясняешь — это то,
что я точно не успею разобрать». Ask how much time he has before writing the deck, and size it to
that. Code blocks are for a deck he will read days ahead, never for one he opens the same day.

## Stacks: order and the vacancy flag

- **Blocks are ordered by priority, most urgent stack first.** He reads top-down and stops when
  time runs out, so the order of the stacks IS the plan, and so is card order inside a stack.
- **The stacks he sorts into are `DECK.marks`**, declared per deck as
  `{ id, label, side: "mine" | "done", key }`. The engine hard-codes none.
- **Vacancy-specific material** («под вакансию», recorded 2026-08-19: «есть блок вещей, которые в
  целом нужно знать к любому интервью, а есть то, что именно в этой вакансии») goes in its own
  block, named so. `job` does not exist in `core/`.
- **`prio` and `diff` are his, not the author's.** In `core/` they are flags he sets per card in
  the browser. Never write them into `data.js`.
- Probability that the question actually comes up goes in `tag`, the line above the answer:
  «спросят почти наверняка», «вероятно», «могут спросить».

## Serving it — his address is port 8931 and only 8931

`localStorage` is bound to the port, so a deck opened on any other port looks untouched: every
mark, draft and comment he made is invisible. Never hand him a link on a different port.

```bash
cd ~/Developer/study-deck && (nohup python3 serve.py 8931 >/dev/null 2>&1 &)
```

`serve.py`, not `http.server`: it sends `no-store`, so an edited `data.js` is never served stale.

The link he opens: `http://localhost:8931/decks/<name>/`. A `file://` path is not
clickable for him — always the http form. The server dies between sessions; check it with
`curl -s -o /dev/null -w "%{http_code}" <url>` before sending the link, and restart it silently.

## `key` is written once and never changed again

`DECK.key` is the whole address of his work: the engine reads state from
`localStorage[DECK.key]` and nothing else. Bump it — even to something
that reads more correct, like `-r2` for a second round — and every mark, draft, answer and
comment he made becomes invisible in one reload, while sitting intact under the old name. He
opens the deck, sees "38 не пройдено, 0 повтор, 0 знаю" and empty answer fields, and concludes
the tool lost his evening. This happened on 2026-08-19 to `mayflower-final`.

A new round is a rewrite of the SAME deck: same `key`, same card ids, `round` bumped by one. His
records are keyed by card id plus round number, so the previous round is simply an older key:
nothing is overwritten and no mark is destroyed. There is no `rev`, `nu` or `seed` in `core/`.
A new `key` is only correct for a genuinely new deck with a new name.

## The engine

`core/` (`model.js`, `store.js`, `send.js`, `shell.js`, `shell.css`) is the tool. **Do not touch
it for the sake of a round**: the split between engine and data is what keeps each round cheap,
and a deck is always expressible in `data.js` alone.

It does change when HE asks for a change in how the tool behaves. Then: surgical edits in his
style, backwards compatible with every existing deck, no reset of his `localStorage` shape, the
`?v=` stamp bumped in every core deck's `index.html`, `core/README.md` updated, and
`node core/selftest.js` green. Hand the work to `implementer-opus`, not to the main conversation.

## Verify before handing it over

```bash
cd ~/Developer/study-deck && node --check decks/<name>/data.js && node core/selftest.js
grep -oE 'id: *"[^"]*"' decks/<name>/data.js | sort | uniq -d    # must be empty
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8931/decks/<name>/
```

**Never open a real deck in an automated browser.** Every load writes to the storage his real
answers live in. Anything that has to be looked at goes through `decks/_lab/`, which exists for
exactly that. A malformed `data.js` shows the deck-error screen; the check above catches it
without opening the page.

## Content rules, learned from his corrections

- The short answer in `a` is what he actually reads — it must be the sentence he can say out loud.
  Everything else goes in `d` behind «подробнее».
- Diagrams beat paragraphs. A wall of text copied out of the chat is the thing he refuses to read.
- Never invent his biography. Where a card needs a personal story, say what the story must SHOW
  and leave the story to him.
