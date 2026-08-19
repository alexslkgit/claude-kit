---
name: deck
description: Prepare the user for an interview, an exam or any Q&A-shaped material using HIS OWN card-deck tool at ~/Developer/study-deck — a one-page deck of question cards with hidden answers, per-card threads and a copy-back button. Use whenever he says «колода», «дек», «стопки», «карточки», «подготовь к собесу», «подготовка к интервью», «прогони со мной вопросы», "deck", "flashcards", "prep me for the interview" — and ALWAYS before writing any interview-prep page of your own. Never build a prep page from scratch: this tool already exists and he spent days on it.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# The deck

`~/Developer/study-deck` — private repo `github.com/alexslkgit/study-deck`. A single-page card
deck: one card per question, an answer hidden until he asks for it, a thread under each card, and
a copy button that returns only what he marked and wrote. Built over many rounds of his own
corrections; it is his tool, not a generic idea.

**The failure this skill exists to prevent:** on 2026-08-18 a session wrote a fresh HTML
"interview prep page" for the same company the deck already covers, having never looked for the
deck. He had spent days on the real tool. Whenever the work is "help me prepare for questions",
the answer is a deck in this repo — never a new page.

## Read before writing anything

1. `~/Developer/study-deck/README.md` — the deck contract: `window.DECK`, blocks, card fields.
2. `~/Developer/study-deck/STATUS.md` — cold start, live traps, the port rule.
3. An existing deck for house style — `decks/mayflower-ios/data.js` (the richest one).

Existing decks: `decks/mayflower-ios` (Mayflower technical round), `decks/mayflower-final`
(Mayflower final round with TL+PM), `decks/justmarkets-ios`, `decks/claude-code`.

## New deck

```bash
cd ~/Developer/study-deck && mkdir -p decks/<name> && cp app/deck.html decks/<name>/index.html
```

Then write `decks/<name>/data.js` and nothing else. **Never touch `app/engine.js` or
`app/engine.css`** — the split between engine and data is what keeps each round cheap.

Writing a long `data.js` from the main conversation is exactly the spend the kit forbids: hand it
to `page-writer-sonnet` with the source material named by path.

## Serving it — his address is port 8931 and only 8931

`localStorage` is bound to the port, so a deck opened on any other port looks untouched: every
mark, draft and comment he made is invisible. Never hand him a link on a different port.

```bash
cd ~/Developer/study-deck && (nohup python3 -m http.server 8931 >/dev/null 2>&1 &)
```

The link he opens: `http://localhost:8931/decks/<name>/index.html`. A `file://` path is not
clickable for him — always the http form. The server dies between sessions; check it with
`curl -s -o /dev/null -w "%{http_code}" <url>` before sending the link, and restart it silently.

Engine cache is defeated by the version query in `index.html` (`?v=NN`) — bump it whenever the
engine changes, and never by moving to a new port.

## The round

1. You write or rewrite `data.js`.
2. He works the cards and marks each **Знаю** / **Повторить** / **Обсудить**.
3. He presses «Отправить блок» and pastes the result into the chat — only his marks, comments
   and questions come back, never the page.
4. You answer INSIDE the cards and rewrite `data.js`. His questions do not get answered in chat
   prose: the answer belongs in the card he asked it on, in `a`/`d`, with the exchange kept in
   that card's `seed` as the trail.
5. Bump the card's `rev` so his stale status clears while his own text survives. Bump `DECK.key`
   only when the data changes SHAPE — bumping wipes all his marks and drafts.

## Verify before handing it over

```bash
node --check decks/<name>/data.js && grep -c 'id:"' decks/<name>/data.js
grep -o 'id:"[^"]*"' decks/<name>/data.js | sort | uniq -d    # must be empty
```

A malformed card is dropped silently by the engine, and a script error renders an empty page that
looks exactly like a page with no content — so open it and count the cards before saying it is
ready.

## Content rules, learned from his corrections

- He has 10+ years in iOS. Never explain what he uses daily; a card that teaches him optionals is
  a wasted card and he says so.
- The short answer in `a` is what he actually reads — it must be the sentence he can say out loud.
  Everything else goes in `d` behind «подробнее».
- Diagrams beat paragraphs. A wall of text copied out of the chat is the thing he refuses to read.
- Never invent his biography. Where a card needs a personal story, say what the story must SHOW
  and leave the story to him.
