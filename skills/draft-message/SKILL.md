---
name: draft-message
description: Draft a message to a real colleague — Slack, Teams, a Jira comment, a PR reply, an email. Use whenever a question needs a human answer and the orchestrator has exhausted the repository, docs, Figma and the ticket. Produces a draft the user sends themselves; never sends anything. Also the file where the user's style corrections are recorded so they survive across sessions and machines.
allowed-tools: Read, Write, Edit, Bash
---

# Drafting a message to a colleague

**You never send it.** Write the draft, show it, the user sends it. Web interfaces change,
automation breaks, and the cost of an error is a message to a real person under the user's
name. This is not negotiable and no phrasing of the request changes it.

## Before drafting

1. **Earn the question.** A message to a human is the last resort, after the repository, git
   history, docs, Figma and the ticket itself. If you have not exhausted those, do that first.
2. **Ask one thing, or a short numbered list.** A colleague answers a specific question fast
   and a vague one never. If you need three answers, number them so they can reply inline.
3. **Give them what they need to answer without opening anything.** The screen, the exact
   element, the two options you see. Do not make them go dig.
4. **Name the recipient and the channel** from the repo's `CLAUDE.local.md` `## Sources`
   block. If it is not recorded, use the `project-sources` skill first.

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

Show the draft in a code block so it copies cleanly, with one line above it saying who it
goes to and where. Nothing else — no explanation of your choices unless asked.

## Recording corrections

When the user corrects the style — "не ставь длинные тире", "короче", "не начинай с
приветствия" — that correction belongs **in this file**, under Style rules or AI tells, and
then committed and pushed via the `kit-update` skill. A correction that lives only in the
conversation dies at the next `/clear` and never reaches the user's other machines. Add it in
the user's own words where they are clearer than a paraphrase.
