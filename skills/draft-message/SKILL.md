---
name: draft-message
description: Draft a message to a real colleague, Slack, Teams, a Jira comment, a PR reply, an email. Use whenever a question needs a human answer and the orchestrator has exhausted the repository, docs, Figma and the ticket. The draft is written as a card on the shared messages page (~/Tasks/messages/messages.html, served at http://localhost:8899/messages/messages.html); nothing is ever sent. Also the file where the user's style corrections are recorded so they survive across sessions and machines.
---

# Drafting a message to a colleague

**You never press send.** That line is absolute: the cost of an error is a message to a real
person under the user's name, and no phrasing of the request changes it.

## ⭐ Delivery: the shared messages page

⭐ **Standing instruction, 2026-09-08, and it is the only rule for chat delivery.** He said it
plainly after watching a session spend twenty tool calls losing a fight with Teams: *«Ты мне
всегда пишешь сообщения в виде HTML, чтобы я мог скопировать с гиперссылками. И отдельно
открываешь вкладки, на которых нужно его вставить.»* The same day, in his own words, he gave the
reason: «единственная проблема что иногда нам нужны гиперссылки, которые в обычный текст не
получается, а в html они встраиваются и нормально копируются… плюс форматирование, жирным
выделить тоже можешь».

Until 2026-09-08 "draft a message" meant opening his real Chrome and typing the text straight into
whatever the destination was, a whole browser flow of tokens every time. Now «напиши драфт»,
«напиши сообщение», "draft a message" and "write a message" mean exactly one thing: write the
message as a card on the one shared page he keeps open and copies from. Every draft to a person is
delivered as two things, together, in one turn:

1. **An HTML page** with the message rendered as it should look, links live on the tokens
   (`PR 190875`, `CART-33186`), and a copy button that puts rich text on the clipboard. One page
   may hold several drafts, each with its own button. Put it beside the task, link it once.
2. **The tab already open on the exact conversation**, so pasting is the only step left. Opening
   a tab is a navigation, and navigation works; typing into a web composer is what does not.

Do not type into a composer, do not click into it, do not spend calls verifying focus. Focus
checks, `document.activeElement` and trimming a typed URL do not apply here: no draft is ever
typed into a composer, in Teams, Slack, or anywhere else.

**Why typing into the composer failed.** A background MCP tab reports `visibilityState: "hidden"`,
and in that state CKEditor ignores synthetic key events and `document.execCommand('insertText')`
alike: focus reads as correct, the selection sits inside the editor, and nothing lands. It fails
silently, so each attempt looks like it might be the one that works, and a session will keep
trying. It will not work. Go to the page instead.

A Teams deep link that does resolve in the web client has this shape, and the `/_#/l/` prefix is
the part that matters (the `/l/` form alone lands on the desktop-app launcher):

```
https://teams.microsoft.com/_#/l/channel/<threadId>/<Channel%20Name>?groupId=<guid>&tenantId=<guid>
https://teams.microsoft.com/v2/?r=1#/conversations/<conversationId>?ctx=chat
```

A channel or chat id that is not in the left rail can be read out of the client's own IndexedDB
(`Teams:conversation-manager:*`, store `conversations`) without clicking anything.

## Delivering the draft, the default, not an upgrade

- File: `~/Tasks/messages/messages.html`, served at `http://localhost:8899/messages/messages.html`.
- **Write the card with the script, never by editing the page.** The page is read once by the
  script, not by the conversation, so a card costs the body and nothing else:
```bash
~/.claude/tools/add-message.py --project <repo-or-task-slug> --to "Taras Paliienko, DM в Slack Grid Dynamics" \
    --lang uk --open "<url>" --body-file /path/to/body.md [--replace]
```
  Body file: paragraphs separated by blank lines, `[text](url)` for links, `**bold**` for bold.
  `--replace` drops the earlier draft card for the same project and recipient first, which is how
  an "updated message" is written. `--project` is the repository or task slug; the page groups
  cards under one heading per project, so with ten drafts he sees at a glance which project each
  belongs to. The script inserts under the `<!-- NEW MESSAGES GO HERE -->` marker inside
  `<main id="messages">`, newest on top. Never remove the marker, never hand-edit the page.
  (Recorded 2026-09-10: cards were being written by hand with python heredocs, which meant
  re-reading the page into the conversation each time. He asked for the script.)
- **Several cards on one page is the normal case, not an exception.** Every message drafted in a
  session lands on the same page as its own card. Each card is fully independent: its own
  recipient, its own language, its own Open link, its own status. Nothing about one card depends
  on another, and nothing is ever merged into a shared header.
- Card markup, exactly:
```html
<article class="msg" data-status="draft">
  <header>
    <span class="to">Кому: Taras Paliienko, DM в Slack Grid Dynamics</span>
    <span class="meta">2026-09-09 · uk · <span class="status">черновик</span></span>
    <a class="open" href="URL" target="_blank" rel="noopener">Открыть</a>
    <button class="copy" type="button">Копировать</button>
  </header>
  <div class="body">
    <p>...</p>
    <p>...</p>
  </div>
</article>
```
- Allowed HTML inside `.body`: `p`, `br`, `a`, `b`, `ol`/`ul` `li`, nothing else. Bold only where a
  human would actually bold something, never for structure.
- **Always in separate paragraphs**, his words. One `<p>` per paragraph of the message, never one
  long `<p>` with `<br>` carrying the whole body. A numbered list he would type by hand (two lines
  like "1. ..." / "2. ...") is the one exception: those two lines share a `<p>` joined by `<br>`,
  because that is how he writes a short list himself. Everything else that is a real paragraph
  break gets its own `<p>`.
- **Every card carries a mandatory `Открыть` link** in the header, next to Копировать: an
  `<a class="open" href="..." target="_blank" rel="noopener">`, pointing at the exact place the
  message is to be pasted, the Slack DM or channel, the Jira ticket's comment box, the mail compose
  URL, the Telegram chat. His flow, in his own words: «нажимаю Копировать, нажимаю Открыть,
  попадаю в браузер и сразу вставляю сообщение». A card with no Open link is a defect. If the exact
  URL is not known, the card still carries the best URL there is, the person's DM or the channel,
  and the `.meta` line says plainly what is uncertain (for example "DM не записан в team.json").
  URL shapes come from two places, never guessed: the project's `CLAUDE.local.md` `## Sources`
  block carries the Slack workspace URLs, the Jira browse URL and the GitHub PR URL shape; the
  per-person Slack handle, email or DM, where recorded, lives in `.claude/team.json`.
- The reply to him in chat is the URL of the page, plus one sentence per card saying who it is for.
  Never also paste the message text into the chat, that defeats the point of the page.
- The browser is never opened to deliver a draft, from the main conversation or from a subagent.
  No subagent is ever handed the page together with a send-capable tool; he copies and sends by hand.
- The "write in his voice" rule below still needs the recipient's recent messages for register.
  That reading goes to `browser-scout-sonnet`, by URL, read-only, only when the register for that
  person is not already in the project's `team.json`.

## Before drafting

1. **Earn the question.** A message to a human is the last resort, after the repository, git
   history, docs, Figma and the ticket itself. If you have not exhausted those, do that first.
2. **Ask one thing, or a short numbered list.** A colleague answers a specific question fast
   and a vague one never. If you need three answers, number them so they can reply inline.
3. **Give them what they need to answer without opening anything.** The screen, the exact
   element, the two options you see. Do not make them go dig.
4. **Name the recipient and the channel** from the repo's `CLAUDE.local.md` `## Sources`
   block. If it is not recorded, use the `project-sources` skill first.
5. **Collect the facts you are missing before you write, not inside what you wrote.** A draft that
   contains `[your address]`, `[account number]`, `[fill in the date]` is not a draft: it is a form
   you handed him. Work out what the message needs, get what you can yourself from the repo, the
   ticket, the account settings, the page you are already on; ask for the genuine remainder in one
   short question; *then* write the finished text.
6. ⭐ **Every checkable claim in the message gets opened and looked at first, the console, the
   dashboard, the page, and the message says what you saw.** Standing instruction, 2026-08-17.
   The repository is not evidence about a system outside it: code can declare a flag that nobody
   created in Firebase, a key can exist in a plist and not in the console, a job can exist in CI
   config and be disabled. If a claim spans two systems, verify it in the second one, not by
   inference from the first.
7. ⭐ **Answer the question that was asked, and nothing next to it.** Same date, same cause.
   Volunteered extras are where the wrongness lives: they were never checked, they invite a
   correction in public, and the correction lands on him, not on you. If a neighbouring fact
   genuinely matters, verify it to the same standard or leave it out.

   Both rules were written after a colleague asked which feature flag hides the Past search bar and
   got both flags back from a repo grep, when only one existed outside code. He was right, and two
   minutes in the Firebase console would have caught it. His words: «ты уже заебал писать сообщения
   каждый раз, после которых я выгляжу идиотом».

## Never a group, never a channel. A person, always

⭐ **Standing instruction, 2026-08-19, and it has no exceptions.** Every message goes to one named
human in a direct conversation. Not a channel, not a team, not an @-group, not a mailing list, not a
"Review needed" post addressed to a tag. His words: *«Ни в какие группы мы не пишем, ни в каких
обстоятельствах.»*

This holds even when the group is provably the right route on paper: a colleague once asked in
writing to be pinged in a channel rather than a DM, and the draft was deleted anyway.
**A teammate's stated preference does not outrank this rule.**

If the only address you can find is a group, that is not permission to use it. Find the person: the
ticket's reporter, the last human who touched the thing, whoever assigned it. If you genuinely
cannot, say so and ask him for the name, one short question, instead of falling back to a channel.

A draft aimed at a group is deleted, not parked. Do not leave it on the messages page "in case".

## The four strikes: run these before the first line, every time

⭐ Recorded 2026-08-17, after a draft to a client tech lead that broke all four at once and he
called it, verbatim, «сообщение, о котором я пожалею, как будто я идиот». The failure was never a
missing fact: the whole thread was on screen. It was writing the message before deciding what the
recipient does not already know.

1. **Does the message need to exist?** Name the action it should produce in the recipient. If they
   already said they would do the thing, or the action is yours and not theirs, there is no
   message. Silence is a valid output of this skill.
2. **Strike everything they can see on their own screen or know from their own job.** The PR's
   status, how many approvals it needs, who approved, how their branching works, what their own
   process requires: a lead who has run this repo for years reads that as being explained to.
   Whatever survives the strike is the message; if nothing survives, go back to strike 1.
3. **Read the project's team-and-process facts before writing, and use nothing that is not in
   them.** Every project's `CLAUDE.local.md` carries a facts section, who the people are, who
   decides what, how review and merge actually work there. Anything I only inferred is a guess, and
   a guess must never appear in a message to the person who knows the real answer. A missing fact
   is a thing to go find, in the repo or from him, not to write around.
4. **Copy the register off his own last messages in that exact chat.** Open the thread, read the
   two or three he sent, and match them. He does not open with a name: no «Тарасе», no
   «Привіт, Тарас». Salutations, sign-offs and warm-ups get invented by me and never by him.

## Style rules

Write the way the user writes: a working developer messaging a teammate, not an assistant
writing a memo.

- **Short.** Two or three sentences. Long messages get read later, meaning never.
- **No greeting rituals.** No "Hope you're doing well", no "Quick question!", no
  "I wanted to reach out". Start with the thing.
- **No apologising for asking.** Not "Sorry to bother you". Just ask.
- **No thanking in advance**, no "Let me know if you have any questions!" at the end.
- **Plain words.** Not "utilize", "leverage", "reach out", "circle back", "align on",
  "ensure", "facilitate", "delve", "robust", "seamless", "comprehensive".
- **Ask, do not summarise your own work.** They do not need to know what you already checked
  unless it changes their answer.
- **Capital letters and full stops. Always, everywhere, no exceptions.** Recorded 2026-08-10 in his
  own words: *«Прекратить писать с маленькой буквы без точек, это ужасно.»* Every sentence starts
  with a capital and ends with a full stop, in a DM as much as in a channel, in Russian as much as
  in English, and **above all in anything that goes outside the team**, the invoice mails, the
  accountant, a client. This overrides the earlier note below, which is kept only so nobody
  reinstates it from an old draft.

  Superseded 2026-08-10, do not restore: *"Lower case after a line break, no full stop at the end
  of the last line."* That was read off one hurried DM he retyped on a phone and generalised into a
  house style. It was never one. Writing a colleague in all lower case reads careless, and he said
  so plainly.
- **Short is still short.** Dropping the lower case does not mean writing paragraphs. Two or three
  sentences, plain words, no greeting ritual, see the rules above. Correct punctuation, not more
  words.
- **A reply that carries no new fact is one line.** Recorded 2026-08-14, after a manager wrote
  "we might have to wait for Monday" and the draft answered with a full paragraph explaining that
  the vote can come from anyone, who was pinged, and that nothing is lost. Everything in it was
  true and none of it changed what he would do. When the other side has already stated the
  outcome, the reply is an acknowledgement plus at most one fact that changes something:
  *"Understood, thanks. Still trying today."* Length is only earned by information the reader does
  not have. Volume as reassurance reads as filler and he says so every time.
- **"Я пока занимаюсь", not "Я на стороне приложения".** Recorded 2026-08-04. He describes what he
  is doing right now; he does not declare which side of a boundary he stands on. Any phrasing that
  reads like a position statement gets rewritten by him into a plain list of what is on his plate.
- **A team channel gets a little more shape than a DM.** Recorded 2026-08-07 from his own rewrite of
  a status message: he opens with "Hello team", puts a short bullet list under a one-line lead,
  closes with a plain courtesy line, and leaves the awkward bit for a trailing `PS:`. A DM has none
  of that scaffolding, but the punctuation rule above applies to both.
- **Write in his voice, not in yours.** Recorded 2026-08-13, his words: *«обрати внимание на то,
  как мы переписываемся, потому что ты пишешь в своем стиле, а не в том, в котором я с ним
  говорю»*. Two drafts had to be thrown out. Before drafting to anyone he already talks to,
  **read his last few messages to that person and copy the register**: the language he uses with
  *them* (Ukrainian with the Ukrainian-speaking teammates, whatever the thread is in), his own
  contractions, his own way of opening. Do not invent a house voice from these rules alone; these
  rules only stop you sounding like an assistant, they do not tell you what he sounds like.
- **No document furniture in a chat message.** No bold for emphasis, no headings, no
  sub-paragraphs with topic sentences, no "Heads-up:" openers. A Slack message is prose plus, at
  most, a genuine enumeration (a merge order, a list of PRs). Structure is what gives a draft away
  as machine-written even when every rule above is satisfied. The capitals-and-full-stops rule
  still applies, it is about punctuation, never about formatting.
- **No em dashes. Anywhere.** Recorded 2026-08-13, his words: *«пиши как человек, какого хрена я
  там вижу длинные тире»*. Use a comma, a colon, or a full stop. This is one of the loudest tells
  that a human did not write the text, and he spots it every time. It applies to the drafts and to
  what you say to him in chat.
- **Every ticket key and PR number carries a link.** Recorded 2026-08-13 as "write the full URL",
  corrected 2026-08-19 to something better: put the hyperlink **on the number itself** and leave
  the visible text as he would type it. So the reader sees `PR 180781` and `CART-33038`, and
  clicking either opens it. On the messages page that is an `<a href="...">` wrapped around the
  number, with the visible text staying the number. A bare number with no link is the defect he
  called idiotic: it costs him a search to remember what the number even was. URL shapes live in
  the project's `CLAUDE.local.md`, never guessed.
- **Answer the awkward question, softly, at the end.** In that same edit he put the refusal back
  in, as a trailing clause in lower case: *"но по этим пунктам не думаю что нужен еще человек"*.
  Dropping an uncomfortable question entirely is not tact, it just makes him answer it later.
  Say it, keep it short, and do not build an argument around it.

## The register: a working engineer typing to a colleague, after the pattern in `social-post`

Recorded 2026-09-08. He named Boris Cherny (Anthropic, Claude Code) as the writer whose texts he
does not have to edit, and the `social-post` skill holds the mechanics observed in eight of
Cherny's posts. A post and a DM are different things, so only the part that survives the move to
a reply is carried here. His words: «не всегда это будет в стиле поста, если я пишу просто кому-то
в личку, то возможно не каждое правило будет срабатывать, если оно не нужно реально».

Always, in every message to a person:

- **The first sentence is a fact about a thing you did or a thing that exists.** "I ran the
  sample-server locally and pointed the demo app at it." Not an explanation of why, not a
  greeting-warmer, not a number, not a headline. The why, if needed, comes second.
- **First person, contractions, present or present perfect.** "I've", "it's", "doesn't". A
  message with no contraction in it was not typed by a human in a chat.
- **Names literal.** The command, the file, the field, the ticket key, the person's name. Never
  "the newer approach", "the engine tool", "a colleague".
- **A number lives inside a sentence and carries its base.** "17 iterations, 3 of them after
  your -5", never a bare stat.
- **Paragraphs of unequal length, blank line between them.** The short one lands after the long
  one. One paragraph is fine for one fact.
- **A contrast is stated once as an observation, never staged.** No "not X but Y" as a device,
  no mirrored verbs, no line that could be quoted on its own.
- **Keep the one caveat that is true.** "I did not run it against a live backend" builds more
  trust than a claim of completeness. One caveat, with its size, not a list of hedges.
- **Nothing about the message itself, nothing about the writer's effort.** No "quick update",
  no "just wanted to", no "hope this helps", no recap of what was just said.

Only when the message is actually a question, a proposal or a status the reader has not asked for:

- **End on one direct question**, the thing you need from them, phrased so a one-word answer
  works. Not two questions, not "thoughts?".

Never carried over from posts, because a reply is not a post:

- A reply to a question does not need a closing question or a link on its own line. When the
  reader asked something, the last line is the answer, and the message stops.
- No length target. A reply that carries one fact is one line.
- A link goes on the token that names the thing (`PR 190875`, `CART-33186`), see "Links in a
  chat message" below, not on its own line.

Check before delivery, same as `social-post`: a number or a colon headline as the first line, a
mirrored verb, a quotable maxim, three bullets of one silhouette, an announced count of points, a
dropped caveat, two closing questions. Any hit is rewritten.

## Always run it through `humanizer`

Before showing any draft, pass it through the `humanizer` skill, every message, every language,
no exceptions. It catches the generated-text signatures that survive a careful first draft:
inflated phrasing, vague attribution, negative parallelism, rule-of-three rhythm, em dash
overuse, promotional adjectives, filler openings. If that skill is not installed on this machine,
apply its rules yourself from the list below and say that it was unavailable.

The list below is the minimum, not a substitute for that pass.

## AI tells: banned outright

These are what give away a generated message. Every one of them is a hard no:

- **Em dashes.** Use a comma, a full stop, or brackets. This is the single most obvious
  tell. Also avoid the en dash (–) in prose.
- **Rule of three.** "It is clean, fast, and maintainable." Real people write two things or
  four, not a rhythmic triplet.
- **Negative parallelism.** "It's not just X, it's Y." "This isn't about A, it's about B."
- **Opening with a compliment.** "Great question", "Good catch", "Makes sense" as an opener.
- **Bold-lead-in bullet lists** in a chat message. Chat messages are prose.
- **Hedging stacks.** "I think it might possibly be worth considering."
- **Emoji as punctuation**, and 🚀 ✨ 🎯 at all unless the user's own style has them.
- **"Let me know if..."** as a closer.
- **Curly quotes and typographic ellipses (…)** where a keyboard would produce " and ...

## Language

Match the language the colleague writes in, that is recorded per project in `## Sources`.
Do not translate a technical term the team uses in English into the local language.

## Recording corrections

When the user corrects the style, no em dashes, shorter, do not open with a greeting, that
correction belongs **in this file**, under Style rules or AI tells, and
then committed and pushed via the `kit-update` skill. A correction that lives only in the
conversation dies at the next `/clear` and never reaches the user's other machines. Add it in
the user's own words where they are clearer than a paraphrase.

## Daily updates and standup messages are three phrases

Recorded 2026-08-13, after being asked for it repeatedly and ignoring it every time.

When he asks for a daily update, a standup message, or "что рассказать на дейлике", the answer
is **three short phrases and nothing else**. His own example:

> Поднял пиар, работаю над комментариями к нему и продолжаю со своей задачей.

What moved, what is being worked on now, what is next. Never the cause of a failure, never which
check was red, never test counts or build numbers, never a paragraph addressed to whoever owns
some unrelated broken test. A daily update is a status line for twenty people who are not inside
his ticket, not a report to him. Whatever he needs for himself he asks for separately, and it
belongs in the chat or on the board.

## Never brief a colleague, and never quote internal research back at one

Recorded 2026-08-19, after a light, curious question from a senior peer got back three sentences
naming a corporate licence, an announcement and its date. His verdict: it reads like a robot.

Two rules follow, and they hold for every message to every person.

1. **Research files are background for him, never material for a message.** Everything collected
   about org policy, tooling positions, who owns what, what was announced and when, exists so that
   *he* is not surprised. None of it is ever pasted at a colleague. Before a fact goes into a
   draft, ask what it is doing there: if it is proving that you know something rather than
   answering what was asked, cut it.
2. **Match the size and register of the thing you are answering.** A one-line curious question gets
   a one-line human answer with an emoji, not a paragraph with dates in it. Read his own last three
   messages in that chat and write the way they are written. The test: if the reply could have been
   written by a press office, it is wrong.

## Cut every detail the reader does not need to answer

⭐ **His instruction, 2026-09-02**, given while reading a three-sentence paragraph explaining why a
Sonar Quality Gate was red. He replaced it with one line: «Где можно без лишних деталей, нужно без
лишних деталей, чтобы человека не грузить.»

The reader is deciding, not auditing. Write the smallest thing that lets them answer.

- **A paragraph of reasoning becomes one clause.** "Quality Gate red, tests and lint green" is
  enough; stage lists, line counts and file counts do not change the answer.
- **Numbers earn their place only if the reader would act differently without them.**
- **Never explain why you could not fix something** unless you are asking them to fix it.
- **One message, one question.** Anything else goes to the bottom as one line, or a separate message.

## A colleague is not an audience for a status report

⭐ **His instruction, 2026-09-02**, verbatim: «Я бы ему ради нихуя просто так отчёты не писал. Ему
неинтересно, что там к чему. Если от него что-то требуется, это значит требуется.» He was looking
at a closing line that told a reviewer a branch had been rebased and his approval had survived.
Nothing was being asked of him by it.

**Every line in a message to a person must be something they have to act on, or something they need
in order to act.** A line that is neither is deleted, however true and however hard-won.

- "I rebased it", "the build is green again": progress, not messages. Progress goes on the board.
- The exception is narrow: a fact the reader needs to answer the one question you are asking.
- If there is nothing to ask, there is no message. Do not send one.

## Never offer an option you already know is wrong

⭐ **His instruction, 2026-09-02.** A draft asked a reviewer whether to merge over a red Sonar gate
"or add these files to the exclusions". The PR was a prefix rename touching 67 files across the
whole app, so the second option meant excluding half the project from analysis forever. He caught
it: asking it at all makes the sender look like they have not thought about their own change.

**Work the alternatives out before you write, and put only the live ones in the message.** An
option you would refuse if the reader said yes is a hole in your own thinking, not a choice.

- Before offering a choice, answer it yourself. If one branch is obviously wrong, delete it.
- Count the blast radius of every option: identical wording can be trivial for one case and
  absurd for another.
- A question with one sensible branch is not a question. State what you are doing and ask them
  to confirm, or ask nothing.
