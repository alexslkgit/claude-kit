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

1. `~/Developer/study-deck/README.md` — the deck contract: `window.DECK`, blocks, card fields.
2. `~/Developer/study-deck/STATUS.md` — cold start, live traps, the port rule.
3. An existing deck for house style — `decks/mayflower-ios/data.js` (the richest one).

Existing decks: `decks/mayflower-ios`, `decks/mayflower-final`, `decks/justmarkets-ios`,
`decks/claude-code`.

## New deck

```bash
cd ~/Developer/study-deck && mkdir -p decks/<name> && cp app/deck.html decks/<name>/index.html
```

Then write `decks/<name>/data.js` and nothing else.

Writing a long `data.js` from the main conversation is exactly the spend the kit forbids: hand it
to `page-writer-sonnet` with the source material named by path.

## He answers first, and the first round has NO answers in it

⭐ Standing instruction, 2026-08-19: «Идея того, чтобы я сначала давал ответ, заключается как раз
в том, чтобы не показывать мне лишней информации. Ты написал ответ на сотню строчек — 90 из них я
знаю, а 10 не знаю. Эти 10 и есть полезное. Просто задавай вопрос, я отвечаю, а ты анализируешь
мой ответ и на основании этого пишешь, что мне показать.»

So the deck is built in two moves, and the first one is questions only:

**Round one — `data.js` with questions and no `a`.** A knowledge card carries `q`, `prio`, `diff`,
`tag`, `job`, and nothing else the reader can see. The engine treats an answerless card as normal:
he answers in his own words, and the card tells him the write-up comes next round. Do NOT write a
prepared answer "just in case" — a hundred lines of which he already knows ninety is the exact
waste this rule exists to end.

**`ref` — the author-only field.** Never rendered, never exported. Put the checklist of points the
full answer must contain there: three to six short lines, enough for the next session to compute
the delta without re-researching the topic. This is where the research goes in round one.

**Round two — the delta, and only the delta.** His export carries his own wording per card and a
marker for the cards where he pressed «Не знаю».

1. Compare his wording against `ref`. What he said correctly is DELETED from the plan, not
   rewritten back at him.
2. `a` becomes the missing piece and nothing else — the few lines he did not have. On a card where
   he pressed «Не знаю», `a` is the whole short answer, because there is no delta to take.
3. `d` holds the trap or the follow-up question he would not survive, if there is one. If there
   isn’t, leave `d` out.
4. Keep the exchange in that card’s `seed` as the trail. His questions are never answered in chat
   prose.
5. Bump the card’s `rev`. His status resets, his own text survives, and the answer is visible at
   once because the gate has already been passed.
6. A card he answered fully needs no write-up at all. Say so and move on; padding it is how the
   deck stops being read.

`kind:"howto"` cards are instructions, not questions — they carry their content from round one and
are never gated. `DECK.gate = false` turns the gate off for a deck where it makes no sense (a
last-minute cram deck, a reference deck).

**Volume is a hard constraint, not a preference.** 2026-08-19, thirty minutes before his interview:
«не нравится объём задач… любой код, если ты мне показываешь и на нём что-то объясняешь — это то,
что я точно не успею разобрать». Ask how much time he has before writing the deck, and size it to
that. Code blocks are for a deck he will read days ahead, never for one he opens the same day.

## Stacks: order and the vacancy flag

- **Blocks are ordered by priority, most urgent stack first.** He reads top-down and stops when
  time runs out, so the order of the stacks IS the plan. Card order inside a stack is handled by
  the engine from `prio`.
- **`job: true`** on a block (or a single card) marks material specific to THIS company, vacancy
  or subject — as opposed to baseline knowledge any interview on the topic would ask. It renders
  as a «под вакансию» chip. Absence is the default; never flag everything.
  Recorded 2026-08-19: «есть блок вещей, которые в целом нужно знать к любому интервью, а есть то,
  что именно в этой вакансии — я хочу понимать, с чего начать или что оставить на потом».
- Every card carries `prio` 1..3 (3 = нужно прямо сейчас) and `diff` 1..3. Set both deliberately:
  they are the controls he uses to cut the deck down when time is short, and he re-sorts on the
  fly.
- Probability that the question actually comes up goes in `tag`, the line above the answer:
  «спросят почти наверняка», «вероятно», «могут спросить».

## Serving it — his address is port 8931 and only 8931

`localStorage` is bound to the port, so a deck opened on any other port looks untouched: every
mark, draft and comment he made is invisible. Never hand him a link on a different port.

```bash
cd ~/Developer/study-deck && (nohup python3 -m http.server 8931 >/dev/null 2>&1 &)
```

The link he opens: `http://localhost:8931/decks/<name>/index.html`. A `file://` path is not
clickable for him — always the http form. The server dies between sessions; check it with
`curl -s -o /dev/null -w "%{http_code}" <url>` before sending the link, and restart it silently.

## The engine

`app/engine.js` and `app/engine.css` are the tool. **Do not touch them for the sake of a round** —
the split between engine and data is what keeps each round cheap, and a deck is always expressible
in `data.js` alone.

They do change when HE asks for a change in how the tool behaves. Then: surgical edits in his
style, backwards compatible with every existing deck, no reset of his `localStorage` shape, the
`?v=NN` query bumped in `app/deck.html` and in every `decks/*/index.html`, and README updated with
the new fields. Hand the work to `implementer-opus`, not to the main conversation.

## Verify before handing it over

```bash
node --check decks/<name>/data.js && grep -c 'id:"' decks/<name>/data.js
grep -o 'id:"[^"]*"' decks/<name>/data.js | sort | uniq -d    # must be empty
```

A malformed card is dropped silently by the engine, and a script error renders an empty page that
looks exactly like a page with no content — so open it and count the cards before saying it is
ready.

## Content rules, learned from his corrections

- The short answer in `a` is what he actually reads — it must be the sentence he can say out loud.
  Everything else goes in `d` behind «подробнее».
- Diagrams beat paragraphs. A wall of text copied out of the chat is the thing he refuses to read.
- Never invent his biography. Where a card needs a personal story, say what the story must SHOW
  and leave the story to him.
