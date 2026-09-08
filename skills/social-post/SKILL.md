---
name: social-post
description: Use whenever he asks for a post, a LinkedIn post, a thread, a tweet, an X post, a Threads post or a short announcement of an article. Holds the one register he accepts: a person telling colleagues what they did, with no literary devices. Recorded 2026-09-08 after two rejected drafts.
---

# A post is a person talking, not an announcement

Recorded 2026-09-08. Two LinkedIn drafts in a row were rejected as "AI-written" and "yellow
press" although both had passed a critic. The second one was built from the critic's own
replacement lines and still read as journalism. His diagnosis, verbatim: «Ты анонсируешь
статью как журналист. ... в пизду эти все литературные приемы, тут нет человеческого нихуя».
The reference he named is Boris Cherny (Anthropic, Claude Code). Eight of Cherny's own LinkedIn
posts were read in full the same day; the mechanics below are what was observed, not taste.

## The rule in one line

Write it the way a working engineer would type it into a team channel to tell colleagues what
he did and what he saw. If a sentence would look odd in Slack, it does not go in the post.

## What the reference does, observed in 8 of 8 posts

- **Opens with a plain fact about a thing he did or a thing that exists.** "A weird experiment
  I've been trying the last few weeks is having Claude take over day-to-day maintenance of our
  apps." Subject, verb, done. Zero posts open with a number, a question, a colon headline or a
  one-line hook.
- **First person, present or present perfect, contractions.** "I've been trying", "hasn't
  caught up", "It's".
- **Numbers sit inside a sentence and always carry their base.** "opened 388 PRs across our
  repos, 180 of which we merged". Never a standalone stat line, never a bare pair like
  "5.14 against 11.42" with no unit and no side named.
- **Products, commands, channel names are literal.** "proj-claude-maintains-apps", "/loop,
  /batch", "Opus 5", "Sonnet". Never "a newer model", never "the cheap tier".
- **Paragraphs of unequal length, separated by blank lines.** A 25-character sentence next to a
  180-character one. The short one lands the point after the long one, not before it.
- **Lists are rare and ragged.** One list in eight posts, hyphen bullets, plain shorthand, and it
  ends with "- a bunch more.." instead of a complete taxonomy.
- **Ending is one direct question or a bare link on its own line.** "Curious where you are --
  what step is your team on?" Never two questions, never "Thoughts?", never a call to follow.
- **Contrast is stated, not staged.** "it measures activity, not return" appears once as a plain
  observation. Self-irony instead of jokes: "It is a bit buried in the system card."
- **Never, in the sample:** emoji, hashtags, bold or unicode styling, "Excited to share", a
  sentence about the post itself, a bullet recap of his own text, third-person self-reference.

## The tells that got the drafts rejected, so they are checked before delivery

Each of these appeared in a rejected draft. Presence of any one is a defect.

1. A number as the first line, used as a hook. It is the yellow-press move inverted.
2. A colon headline ("Claude Code: 5,14 ...") or a title-shaped first line.
3. A mirrored verb ("wanted to confirm and did not confirm") or a "not X but Y" more than once.
4. Any sentence that would be quotable on its own: a maxim, a moral at the end of a paragraph,
   an aphorism ("Both sounded convincing precisely because I counted them wrong").
5. Three bullets with the same silhouette.
6. Announcing the count of your own points ("Three more things:").
7. A caveat from the source dropped to sound confident. His credibility is built on caveats;
   keep at least one, with its sample size.
8. Two closing questions, or a closing question copied from the article's last line.
9. Assembling the post from the article's summary sentences. Nothing in the post was written
   for the feed, and the reader can tell.
10. Vague nouns where the source names things: "a newer model" for Fable.

## Length and language

900 to 1600 characters for LinkedIn. His language of the day: he said on 2026-09-08 that
English posts are not read by his audience, so Ukrainian unless he asks otherwise. No em-dash
or en-dash in any language; a hyphen is fine.

## Delivery

Per the `draft-message` rule of 2026-09-08: an HTML page beside the task with the text in a
`<textarea>` and a copy button that copies `.value`, so paragraph breaks survive the paste
(copying `innerText` from a div lost every blank line on the first delivery), plus the tab
already open on the composer. Do not type into the composer. Styles go in a linked `.css`
file, not inline, or `shell-guard` refuses the write.

A link to an article goes on its own line near the end, full URL. If the platform's link card
comes up empty (Medium behind Cloudflare has done this), attach the article's first chart as
an image and keep the URL in the text.

## Procedure

1. Read the source material and pick the two or three things he actually did or saw, with
   their numbers and their bases.
2. Write the first sentence as "for the last N weeks I did X". No hook.
3. Write the rest as he would tell it, paragraphs of unequal length, numbers inside sentences,
   names literal, one caveat kept.
4. Run the tells list above against the text. Fix every hit.
5. Have `marketer-opus` read it once against this file and the reference mechanics, and apply
   what it finds. Then deliver.
