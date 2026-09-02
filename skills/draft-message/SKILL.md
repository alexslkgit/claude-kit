---
name: draft-message
description: Draft a message to a real colleague — Slack, Teams, a Jira comment, a PR reply, an email. Use whenever a question needs a human answer and the orchestrator has exhausted the repository, docs, Figma and the ticket. Produces a draft the user sends themselves; never sends anything. Also the file where the user's style corrections are recorded so they survive across sessions and machines.
---

# Drafting a message to a colleague

**You never press send.** That line is absolute: the cost of an error is a message to a real
person under the user's name, and no phrasing of the request changes it.

**But you do deliver it.** A draft pasted into the chat is work the user then has to redo by hand:
read it, copy it, find the right window, find the right thread, paste, fix what you left blank.
Take all of that yourself and leave exactly one thing undone — the send button.

## Delivering the draft — the default, not an upgrade

Everything up to sending is yours. Sending is his. The whole question is *where you leave it*, and
there is a hard line running through the middle of that:

- **A saved draft object is the right destination.** A Gmail draft created through the mail API, a
  Jira comment saved as a draft, a `gh pr review` left pending, a file the tool itself reads back.
  These are stored, not armed: nothing sends until he opens the thing and presses the button. Put
  the draft here whenever the destination supports it. This is the default.
- **A live send field is never a destination.** Text sitting in Slack's composer, in an open reply
  box, in a comment field with the cursor in it — one Enter, or one mis-aimed click that left focus
  there, and it is published. See the incident at the bottom of this file.

So: prefer the API or the tool that creates a *stored* draft. Reach for the browser only when
nothing else can get there, and then place the text and verify focus as described below.

Order of preference, best first:

1. **A dedicated tool that creates a saved draft** — the mail connector's create-draft call, the
   ticket system's API, `gh`. Use the reply/thread field so the draft lands in the right
   conversation, not as a new message.
2. **A file**, when the destination has no draft concept — write it, and say the path.
3. **A code block in the chat** — the fallback, not the routine. If you end up here, say in one
   line why the first two were impossible.

### Messengers live in the browser, never in the desktop app

Standing instruction, 2026-09-01, in his own words: he uses Slack and Telegram **in the browser
only, always**. So a signed-out or missing desktop app is not a finding, not a blocker, and never a
reason to send him to it for a click. Do not open it, do not propose it, do not report on it.

Recorded after a session opened desktop Slack, met a "Sign In to Grid Dynamics" splash, and treated
that as the reason the message could not be delivered.

### When the composer cannot be typed into, the chat is the delivery

Verified on C12239 on 2026-09-01, five attempts: the Chrome extension focuses Slack's composer
correctly (`aria-label` "Message to <name>"), the first burst of characters lands, and every
keystroke after it is **silently dropped** — including when the editor is re-focused via JS
immediately before each type. Nothing about the focus check catches this, because focus was never
the problem.

So when this happens: clear whatever partial text you left behind (a `Range` plus
`execCommand("delete")` works, and leaving his composer dirty is a defect on its own), then give him
the message as a plain code block in the chat and say in one line that the composer could not be
written to. That is the fallback in the order of preference above, and this is one of the cases that
earns it.

Do not spend more attempts on it, and do not fall through to the desktop app.

Whichever you use, finish with one line: who it goes to, where it is waiting, and the exact click
that sends it — "Gmail → Черновики → письмо с темой X → Send". Not "I drafted a reply."

## You are not limited to reading

Assume you can do it, and try, before telling the user to do it themselves. Downloading a file,
exporting an asset from Figma, filling a form, navigating a multi-step flow: these are ordinary
browser actions, not things to hand back. Hand back only what is genuinely gated — a password, a
one-time code, an approval, an irreversible click.

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
   contains `[your address]`, `[account number]`, `[fill in the date]` is not a draft — it is a form
   you handed him. Work out what the message needs, get what you can yourself from the repo, the
   ticket, the account settings, the page you are already on; ask for the genuine remainder in one
   short question; *then* write the finished text.
6. ⭐ **Every checkable claim in the message gets opened and looked at first — the console, the
   dashboard, the page — and the message says what you saw.** Standing instruction, 2026-08-17.
   The repository is not evidence about a system outside it: code can declare a flag that nobody
   created in Firebase, a key can exist in a plist and not in the console, a job can exist in CI
   config and be disabled. If a claim spans two systems, verify it in the second one, not by
   inference from the first.
7. ⭐ **Answer the question that was asked, and nothing next to it.** Same date, same cause.
   Volunteered extras are where the wrongness lives: they were never checked, they invite a
   correction in public, and the correction lands on him, not on you. If a neighbouring fact
   genuinely matters, verify it to the same standard or leave it out.

   Both rules were written after this: a colleague asked which feature flag hides the Past search
   bar. The answer named both flags — Past and Upcoming — from a repo grep. He replied "но зачем это
   нужно для upcomingFlights, если речь идет только о Past flights? В Firebase даже нет feature flag
   для upcomingFlights", and he was right: the Upcoming parameter existed only in code, merged that
   morning, never created in the console. Two minutes in the Firebase console — which was reachable,
   signed in, the whole time — would have caught it. His words: «ты уже заебал писать сообщения
   каждый раз, после которых я выгляжу идиотом».

## Never a group, never a channel. A person, always

⭐ **Standing instruction, 2026-08-19, and it has no exceptions.** Every message goes to one named
human in a direct conversation. Not a channel, not a team, not an @-group, not a mailing list, not a
"Review needed" post addressed to a tag. His words: *«Ни в какие группы мы не пишем, ни в каких
обстоятельствах.»*

This holds even when the group is provably the right route on paper. A colleague had asked in
writing to be pinged through `@Extra reviewers (DesignSystem)` in a channel rather than in a DM, and
a draft was built around that. It was deleted. **A teammate's stated preference does not outrank
this rule** — write to that teammate directly and let them forward it.

If the only address you can find is a group, that is not permission to use it. Find the person: the
ticket's reporter, the last human who touched the thing, whoever assigned it. If you genuinely
cannot, say so and ask him for the name — one short question — instead of falling back to a channel.

A draft aimed at a group is deleted, not parked. Do not leave it in a file "in case", and never let
one sit in a channel composer where a stray Enter publishes it.

## The four strikes — run these before the first line, every time

⭐ Recorded 2026-08-17, after a draft to a client tech lead that broke all four at once and he
called it, verbatim, «сообщение, о котором я пожалею, как будто я идиот». The failure was never a
missing fact — the whole thread was on screen. It was writing the message before deciding what the
recipient does not already know.

1. **Does the message need to exist?** Name the action it should produce in the recipient. If they
   already said they would do the thing, or the action is yours and not theirs, there is no
   message. Silence is a valid output of this skill.
2. **Strike everything they can see on their own screen or know from their own job.** The PR's
   status, how many approvals it needs, who approved, how their branching works, what their own
   process requires — a lead who has run this repo for years reads that as being explained to.
   Whatever survives the strike is the message; if nothing survives, go back to strike 1.
3. **Read the project's team-and-process facts before writing, and use nothing that is not in
   them.** Every project's `CLAUDE.local.md` carries a facts section — who the people are, who
   decides what, how review and merge actually work there. Anything I only inferred is a guess, and
   a guess must never appear in a message to the person who knows the real answer. A missing fact
   is a thing to go find, in the repo or from him, not to write around.
4. **Copy the register off his own last messages in that exact chat.** Open the thread, read the
   two or three he sent, and match them. He does not open with a name — no «Тарасе», no
   «Привіт, Тарас». Salutations, sign-offs and warm-ups get invented by me and never by him.

Note what these are not: they are four things to *do*, each with an output I can check. A rule of
the form "do not invent X" is worthless and was removed on 2026-08-17 — at the moment of writing I
do not know I am inventing, so the ban never fires, and it accumulates into a list of superstitions
that a better model would only stumble over. The fix for invention is knowing the facts, which is
strike 3, not a prohibition.

## Style rules

Write the way the user writes — a working developer messaging a teammate, not an assistant
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
  in English, and **above all in anything that goes outside the team** — the invoice mails, the
  accountant, a client. This overrides the earlier note below, which is kept only so nobody
  reinstates it from an old draft.

  Superseded 2026-08-10, do not restore: *"Lower case after a line break, no full stop at the end
  of the last line."* That was read off one hurried DM he retyped on a phone and generalised into a
  house style. It was never one. Writing a colleague in all lower case reads careless, and he said
  so plainly.
- **Short is still short.** Dropping the lower case does not mean writing paragraphs. Two or three
  sentences, plain words, no greeting ritual — see the rules above. Correct punctuation, not more
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
  **read his last few messages to that person and copy the register** — the language he uses with
  *them* (Ukrainian with the Ukrainian-speaking teammates, whatever the thread is in), his own
  contractions, his own way of opening. Do not invent a house voice from these rules alone; these
  rules only stop you sounding like an assistant, they do not tell you what he sounds like.
- **No document furniture in a chat message.** No bold for emphasis, no headings, no
  sub-paragraphs with topic sentences, no "Heads-up:" openers. A Slack message is prose plus, at
  most, a genuine enumeration (a merge order, a list of PRs). Structure is what gives a draft away
  as machine-written even when every rule above is satisfied. The capitals-and-full-stops rule
  still applies — it is about punctuation, never about formatting.
- **No em dashes. Anywhere.** Recorded 2026-08-13, his words: *«пиши как человек, какого хрена я
  там вижу длинные тире»*. Use a comma, a colon, or a full stop. This is one of the loudest tells
  that a human did not write the text, and he spots it every time. It applies to the drafts and to
  what you say to him in chat.
- **Every ticket key and PR number carries a link.** Recorded 2026-08-13 as "write the full URL",
  corrected 2026-08-19 to something better: in a chat client, put the hyperlink **on the number
  itself** and leave the visible text as he would type it. So the reader sees `PR 180781` and
  `CART-33038`, and clicking either opens it. In Teams that is select the token, cmd+k, paste the
  URL, confirm with the dialog button rather than Enter. A bare number with no link is the defect
  he called idiotic: it costs him a search to remember what the number even was. Where the surface
  cannot hold a link, fall back to the full URL on its own line.
  URL shapes live in the project's `CLAUDE.local.md`, never guessed.
- **Answer the awkward question, softly, at the end.** In that same edit he put the refusal back
  in, as a trailing clause in lower case: *"но по этим пунктам не думаю что нужен еще человек"*.
  Dropping an uncomfortable question entirely is not tact, it just makes him answer it later.
  Say it, keep it short, and do not build an argument around it.

## Always run it through `humanizer`

Before showing any draft, pass it through the `humanizer` skill — every message, every language,
no exceptions. It catches the generated-text signatures that survive a careful first draft:
inflated phrasing, vague attribution, negative parallelism, rule-of-three rhythm, em dash
overuse, promotional adjectives, filler openings. If that skill is not installed on this machine,
apply its rules yourself from the list below and say that it was unavailable.

The list below is the minimum, not a substitute for that pass.

## AI tells — banned outright

These are what give away a generated message. Every one of them is a hard no:

- **Em dashes (—).** Use a comma, a full stop, or brackets. This is the single most obvious
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

Match the language the colleague writes in — that is recorded per project in `## Sources`.
Do not translate a technical term the team uses in English into the local language.

## Output

Put the draft where the destination stores drafts (see above), then one line in the chat: who it
goes to, where it is waiting, and the exact click that sends it. Show the text in a code block too
only when he cannot see it without switching windows, or when the destination was unreachable and
the code block *is* the delivery. Nothing else — no explanation of your choices unless asked.

## Links in a chat message: type them, then trim them

Recorded 2026-08-13, after three failed attempts at the same message and a genuinely angry user.

Every ticket key and PR number in a Slack message is a hyperlink whose **visible text is only the
tail** — `MSHAPP-10044`, not `https://jira.wsgc.com/browse/MSHAPP-10044`. That is how he writes
links in every chat at every job, and a message full of raw URLs is not a stylistic preference he
will fix afterwards; it is a message he has to rewrite.

**Do it yourself, in the composer. This is the delivery, not an upgrade.**

1. Open the conversation in the browser and put the message in the composer.
2. For each link, place the cursor immediately before the ticket key and delete everything to its
   left that belongs to the URL. Slack keeps the anchor and shows only what is left.
3. Screenshot and read the result back before you stop. All of the links, not the first one.
4. Never press Enter, and never press Save on an edit he did not ask you to make. Leave it for him.

Restated 2026-08-13 on the other machine, in Teams, in his own words: *«Сообщение для Гильерма ты
набираешь, я нажимаю кнопку "Отправить", но я должен зайти в браузер и только нажать одну кнопку.»*
A file he has to open, select and copy is not a draft, it is homework. The composer is the
destination whenever the app has no draft API, Slack and Teams alike; a file is the fallback only
when the thread genuinely cannot be reached, and then say why in one line.

Between steps 1 and 2, **read `document.activeElement` back** and confirm it is the message box
and not search: a `contenteditable` element whose `aria-label` is "Type a message". Clicking is not
evidence: the 2026-08-03 incident was a click that silently missed.

That tells you it is *a* composer. It does not tell you it is the *right* conversation, and the
check that used to be written here for that is wrong. Corrected 2026-08-19 against the live Teams
build: the composer id does **not** change between chats. `document.querySelectorAll('[id^="new-message-"]')`
returns exactly one element at any time, and the same `new-message-<uuid>` was byte-identical in two
different 1:1 chats. It then *changed* for the same chat after navigating to a channel and back,
because the editor was torn down and rebuilt. The id tracks the widget's lifecycle, not the
recipient: identical across two different conversations, different for one conversation at two
moments. So an unchanged id is not a stop condition and a changed id is not proof of anything.

**Prove the conversation instead, with three independent signals that must all agree** before any
keystroke: `document.title` or the header naming the right person or channel, the highlighted row in
the left rail, and a recognisable message in the visible history of that thread. If any of the three
disagrees, place nothing and say so.

Read the field back after typing. `innerText` serialises CKEditor paragraph breaks as `\n\n\n\n\n`;
that is one blank line on screen, not four, so do not "fix" it.

Superseded 2026-08-19, do not restore: *"Each Teams conversation has its own composer id, so the id
changing as you switch chats is the proof you are in the right one."*

Two approaches that look clever and **do not work — do not try them again**:

- **The clipboard.** Loading rich text into the pasteboard (`textutil … | pbcopy -Prefer rtf`) and
  telling him to press Cmd+V. It survives only until anything else is copied, he has no way to see
  what is in there, and on 2026-08-13 it silently wiped his clipboard because the source file had
  never been written. Never tell him "it is on your clipboard". You cannot verify that, and every
  time you have claimed it, it was false.
- **Reaching his composer from a new tab.** Slack does not sync unsent composer text between
  sessions. A tab you open shows an empty composer, so you can neither read nor fix what he is
  looking at. If the text has to change, write the whole message fresh in your own tab, or tell him
  plainly that you cannot reach it.

If the browser is genuinely unavailable, say so in one line and give the message as plain text with
full URLs, so he can trim them himself. That is the fallback, not the routine.

## Recording corrections

When the user corrects the style — no em dashes, shorter, do not open with a greeting — that
correction belongs **in this file**, under Style rules or AI tells, and
then committed and pushed via the `kit-update` skill. A correction that lives only in the
conversation dies at the next `/clear` and never reaches the user's other machines. Add it in
the user's own words where they are clearer than a paraphrase.

## Where a draft may live — and where it may never live

The distinction is **stored versus armed**, not "inside the app versus outside it".

**Stored — allowed, and the default.** A draft the application has saved: a Gmail draft, a saved
reply, a pending `gh` review, a file. He has to open it and press a button. Nothing about it is one
keystroke from a real person.

**Armed — never.** Text left sitting in an open composer or reply box with focus in it. Slack's
message field, a Jira comment box mid-edit, an email compose window you typed into by hand. A
mis-aimed click that leaves focus there turns the next Enter into a published message. Do not park
a draft in one of these, and do not leave one open behind you.

If the only way to reach a destination is by typing into a live field, that is not a reason to do
it — fall back to a file or the chat and say why.

The exception is an explicit instruction in the current conversation — he says "отправь",
"запости", "send it". Then, and only then, the text may be typed into the real field. Even then:

1. Screenshot first and confirm what actually holds focus. Never trust that a click landed.
2. Type the text, screenshot again, and read back what is in the field before any Enter.
3. Press send only if the target channel or recipient in that screenshot is the one he named.

If any of the three is unclear, stop and hand it back. A message sent to the wrong place cannot be
recalled, and deleting it is itself an action that needs his approval.

Recorded 2026-08-03 after a real failure: a click on Slack's search bar did not take focus, the
query was typed into the channel composer instead, and Enter posted it to a public channel of 144
people. The mechanical cause was typing without verifying focus; the structural cause was a rule
that encouraged drafting inside the live field. Both are forbidden.

Amended 2026-08-05. The 2026-08-03 wording banned every destination inside an application and told
you to paste into the chat instead. That over-corrected: it took a *focus* failure and turned it
into a *destination* ban, and the result was the user being handed text to copy by hand — the exact
work he keeps asking to have taken off him. A saved draft object has no focus and no Enter key. It
was never what went wrong.

## Daily updates and standup messages are three phrases

Recorded 2026-08-13, after being asked for it repeatedly and ignoring it every time.

When he asks for a daily update, a standup message, or "что рассказать на дейлике", the answer
is **three short phrases and nothing else**. His own example:

> Поднял пиар, работаю над комментариями к нему и продолжаю со своей задачей.

What moved, what is being worked on now, what is next. Never the cause of a failure, never which
check was red, never test counts or build numbers, never a paragraph addressed to whoever owns
some unrelated broken test. A daily update is a status line for twenty people who are not inside
his ticket — not a report to him. Whatever he needs for himself he asks for separately, and it
belongs in the chat or on the board.

This is about length, not about care. The three phrases still have to be accurate, still have to
avoid promising what is not done, and still must not leave out something that would mislead the
reader. Write them, stop, and offer the detail only if he asks.

## Never brief a colleague, and never quote internal research back at one

Recorded 2026-08-19, after a draft to a senior peer who had asked a light, curious question —
"are these comments from your AI pipeline? what is your stack?" — came back as three sentences
naming a corporate licence, an announcement and its date. His verdict: it reads like a robot, and
it made him look stupid, because he had complained on a call that he could not use those very
models. Repeating the availability date back to a colleague published his own ignorance.

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

The reply that stood, for the whole three-sentence briefing that was rejected:

> Yeah, Copilot CLI 😅 it does love comments, I should have trimmed them before pushing. Cut it
> down to 2 lines now, thanks!

## Editing a draft already sitting in a composer is where the focus check gets skipped

Recorded 2026-08-31. A draft was placed in a Teams composer correctly, with focus verified through
`document.activeElement` and the conversation proved three ways. Then one word in the opener had to
change. The page had relaidout in the meantime, the old click coordinates were stale, the focus
check was not repeated for the edit, and the keystrokes landed somewhere else: Teams rewrote the
first sentence through its own Copilot control and the message went out unapproved, to a real
colleague, with wording nobody had written.

So the rule is not "verify focus before typing", it is **verify focus before every burst of
keystrokes, including the second one in the same composer**. A layout shift between two screenshots
invalidates every coordinate you were holding.

And when a selection call is refused by the permission classifier, that is a stop, not a cue to fall
back to blind coordinate clicking. Report that the edit cannot be made and hand it back.

Retyping the whole message from an empty composer is safer than surgically editing a placed one:
one focus check, one burst, nothing to aim at.

## Cut every detail the reader does not need to answer

⭐ **His instruction, 2026-09-02**, given while reading a three-sentence paragraph explaining why a
Sonar Quality Gate was red. He replaced it with one line: «Где можно без лишних деталей, нужно без
лишних деталей, чтобы человека не грузить.»

The reader is deciding, not auditing. Write the smallest thing that lets them answer.

- **A paragraph of reasoning becomes one clause.** "Quality Gate red, tests and lint green" carries
  everything the reader needs; the stage list, the line counts and the file counts do not change
  their answer and are cut.
- **Numbers earn their place only if the reader would act differently without them.** "370 lines in
  67 files" is impressive to the author and irrelevant to the person pressing merge.
- **Never explain why you could not fix something** unless you are asking them to fix it. It reads
  as pre-emptive defence and it doubles the length.
- **One message, one question.** Everything not attached to the question goes to the bottom as a
  single line, or into a separate message.

The test before sending: delete each sentence in turn and ask whether the reader could still give
the same answer. If they could, it was never needed.

## A colleague is not an audience for a status report

⭐ **His instruction, 2026-09-02**, verbatim: «Я бы ему ради нихуя просто так отчёты не писал. Ему
неинтересно, что там к чему. Если от него что-то требуется, это значит требуется.» He was looking
at a closing line that told a reviewer a branch had been rebased and his approval had survived.
Nothing was being asked of him by it.

**Every line in a message to a person must be something they have to act on, or something they need
in order to act.** A line that is neither is deleted, however true and however hard-won.

- "I rebased it", "I fixed the thing you mentioned", "the build is green again" — none of these are
  messages. They are progress, and progress belongs on the board, not in someone's DMs.
- The exception is narrow: a fact the reader needs in order to answer the one question you are
  asking. "Auto-merge is on" earns its place next to "will you merge over the red gate", because it
  changes what they do.
- If there is nothing to ask, there is no message. Do not send one.

Written as a colleague writes, not as a system reporting in.
