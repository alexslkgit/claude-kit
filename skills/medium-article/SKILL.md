---
name: medium-article
description: Use whenever he asks to write, draft or publish a Medium article or blog post. Holds his per-account style profiles so no session re-investigates his writing.
---

# Writing a Medium article

## 1. Accounts

| Account | Language | Style file | Status |
|---|---|---|---|
| https://medium.com/@alexslkmain | Ukrainian | styles/alexslkmain-uk.md | profiled |
| https://medium.com/@oleksandrslobodianiuk | English | styles/oleksandrslobodianiuk-en.md | profiled 2026-09-03, 3 articles, all translations of the Ukrainian ones; the English piece is written after the Ukrainian one and links back to it; published 2026-09-06: https://medium.com/@oleksandrslobodianiuk/step-width-and-the-price-of-a-redo-a-second-round-of-meter-measurements-e79e4abb4749 (EN first this time, UA pending) |

He is signed in to one Medium account at a time. When the second account is needed, tell him in
one line to re-login and carry on with other work while he does it.

## 2. Procedure

a. **Load the style file** for the account. If it is missing, run the investigation once with
`browser-scout-sonnet` in his real Chrome, with this exact brief: list all articles with title,
date, read time, claps; read fully the 3 newest plus the most clapped; write down structure, tone,
sentence and paragraph length, endings, tags, titles verbatim, 8 to 10 quotes under 15 words,
recurring intro and outro blocks, and a 10-line checklist. Cap it at 40 tool calls and tell it to
write the file with whatever it has gathered once it hits the cap. Save the result under `styles/`.

b. **Collect the material** into one `MATERIAL.md` in the task folder, via `page-writer-sonnet`.
Every number in it must be sourced, and anything missing gets a GAP marker rather than a guess.

c. **Images first**, as PNG 1600x900, via `implementer-sonnet`. Build them as SVG or HTML and
render with headless Chrome:

```
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --hide-scrollbars --screenshot=out.png --window-size=1600,900 file.html
```

Do not use `qlmanage` for this, it pads SVG to a square and crops it. matplotlib is not
installed.

d. **The draft**, via `implementer-opus` with a `TIER-OPUS` line, since this is voice work.
1000 to 1300 words for a 5 to 6 minute read. File layout: 5 title options, 5 tags, body with
`![caption](img/...)` and italic captions. **No community outro.** He stopped teaching, so the
students, Discord and Udemy block is retired (his words 2026-09-06: "я уже не занимаюсь этим, эта
часть про комьюнити со студентами никому не надо"). An article ends with the conclusion, the
translation note linking the other language, and the question to readers.

e. **Review**, done in the main conversation, never delegated: check every number against
`MATERIAL.md`, run the checklist from the style file, confirm the read time, confirm no
em-dashes.

f. **Placing into Medium**, via `medium-placer-sonnet` in his real Chrome, with a `CHECK:` line (his read-back of the draft is the check): open
https://medium.com/new-story, paste the body as rich text from the clipboard, put HTML on the
clipboard with `osascript` using the `«class HTML»` class, not `pbcopy`, upload each image with
the editor's plus button and the `file_upload` tool, add captions, set title and subtitle, add
the tags in the publish dialog, and **stop at the Publish button**.

g. **Publishing** is his explicit word in that conversation, never inferred, never done by a
subagent. After he publishes, record the URL in `STATUS.md` and in the account table above.

h. **For the second account**: tell him to re-login, then repeat step (f) with the draft
translated and re-written into that account's own style.

## 3. Rules

- Nothing is published or posted without his explicit word in that conversation.
- Never enter credentials on his behalf.
- A translation to the second account is a re-write in that account's style, not a literal
  translation.
- Keep the numbers identical across languages.
- The article's caveats stay in, do not smooth them out for readability.
- No em-dashes, in any language.
- No community, Discord or Udemy block in any new article, in either language.
- A long article needs a chart every 2 or 3 screens, not only at the top: he rejected a text
  heavy draft in 2026-09-06 with "никто не будет читать такое количество текста в 2026 году".

## 4. Lessons

- 2026-09-03, first run: the style scout hit its 60-turn cap while collecting tags across all 12
  articles. Cap it at 40 turns and have it read only 3 articles in full.
</content>
- 2026-09-03, placement: the whole editor flow took one browser-scout-sonnet about 140 tool calls
  across three 60-turn resumes. Brief it to batch, and expect to resume it twice. The `type`
  action drops the first character or word in a freshly focused Medium field (title, subtitle,
  captions): have the scout diff every typed field against the source and retype. Medium has no
  subtitle toggle in the toolbar; the second line stays a paragraph. Rich HTML on the clipboard
  via `«data HTML<hex>»` pastes with headings, lists and code intact.
- 2026-09-03, second placement: `browser-scout-sonnet` refused the editor job as read-only (the
  first instance happened to comply). The `claude` catch-all was used with `TIER-OK:` until
  2026-09-06, when agent-guard stopped admitting untiered types; the placement agent is now
  `medium-placer-sonnet`, a defined type with the browser tools, the editor lessons in its
  prompt and a 120-turn cap. Step (f) above means that agent, not a scout.
- 2026-09-03, third placement: editing the editor DOM with javascript (execCommand, innerHTML)
  makes Medium show "Something is wrong and we cannot save your story" and the work is lost; the
  agent then blamed a Grammarly extension, which was not the cause. Only real input saves:
  clicks, keys, cmd+v of rich HTML, file_upload. And exactly one tab per draft: a second tab on
  the same draft autosaves its stale copy over the edits, and cannot be closed by automation
  because of the "Leave site?" dialog. Replacing a whole body is dearer than a fresh draft plus
  one delete click from him.
- 2026-09-03, after publishing: "Save and publish" on a published story applies at once, no
  panel. The ⋯ menu on medium.com/me/stories does not open under automation; deleting a draft
  goes through its editor's ⋯ menu, and an automated navigation to an editor URL can hit a
  Cloudflare human check, which is his click. Register-wise he rejected the first draft as
  yellow press: the opening must explain the situation to a newcomer before any number.
- 2026-09-06, fourth placement: a tab in his real Chrome freezes within minutes when the Claude window covers it (CDP "Runtime.evaluate timed out"); `navigate` to the same draft URL thaws it, so brief the placer to re-navigate on every timeout and give up only after three in a row. Restructuring a placed draft (move two images, edit two sentences, add five tags) took one placer 90 tool calls. Medium turns digit ranges ("50-70") and dates into en-dashes on paste: write ranges in words in the source. The opening image must carry a visible surprise; a stacked weekly bar chart was rated 4/10 by him, the tier price chart with the redo reversal won.
