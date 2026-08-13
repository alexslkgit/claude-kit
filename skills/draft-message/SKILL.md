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
- **Ticket and PR numbers go in as full URLs**, not as bare keys. Recorded 2026-08-13: he trims the
  tail himself so the chat client renders a tidy hyperlink, and he cannot do that if you wrote
  `MSHAPP-10044`. So `https://jira.wsgc.com/browse/MSHAPP-10044`, and
  `https://github.wsgc.com/<org>/<repo>/pull/7757` for a PR.
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
