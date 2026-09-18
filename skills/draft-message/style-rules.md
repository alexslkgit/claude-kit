# Who gets what, and how it must read

Read this file before writing any draft, and read the last entries of `~/Tasks/messages/edits.jsonl`
for the person you are writing to. The JSONL is the record of what he actually sent: every card he
rewrote on the messages page stores the original and his own wording side by side. That is the only
honest feedback loop there is, because before 2026-09-17 he rewrote nearly every draft in the
composer and no session ever saw it.

## Updating this file is part of the job

A rewrite reaches you by itself: `hooks/edits-guard.sh` prints every unacknowledged entry of
`edits.jsonl` at the top of each turn until a session writes the rule and runs
`~/.claude/hooks/edits-guard.sh ack`. When it fires, open the entry, compare `original` with `edited`, and ask what the
difference is *in general*. One rule per repeated defect, written into the person's block below or
into the global list. Never a list of his specific corrections: a rule he has to re-read as a diary
is a rule that gets ignored. If a rewrite shows nothing general, leave the file alone.

## Global, applies to every message and every person

- **No long dash anywhere.** A comma, a colon, or two sentences. He deletes them by hand and has
  asked for this for half a year.
- **No rule-of-three lists, no "not only X but Y", no closing sentence that restates the message,
  no opening that recaps the question.** These are the tells that make a message read as written by
  a machine, and he strips them every time.
- **One thing per message.** A DM is a ping, not a report: only what changes what the reader does
  next, sayable in one breath. If it needs a second paragraph to explain itself, it is too long.
- **No hedging and no throat-clearing.** Not "I wanted to check whether maybe", just the thing.
- **No promises he has not made.** Never write that he will do something, deliver something or
  decide something unless he said so in this conversation. A number, a date or an offer of work
  inside a draft is a commitment he has to honour in front of his team.
- **Never a bare ticket or PR number** where it can be a link.
- **A fact he has not checked himself is not his position.** A message may not turn a session's
  research into his announced decision, and may not tell peers what to do on the strength of it.
  Until he has looked, the honest message is what he actually knows, that he is checking, and the
  one question still open. Written 2026-09-18 from a rewrite: a group-chat draft laid out settled
  dates, chosen flights and "then we all put the same flights in the form"; he replaced it with
  two lines saying he would check the options himself and asking whether other airlines are
  allowed at all.
- **A sentence that does not change what the reader does next is deleted, not softened.** The
  worst form is raising something and then withdrawing it in the same breath: an ask that turns out
  to be already satisfied, a worry the state of the world has answered, a note about what you chose
  not to ask. Check the live state first, and if the ask is dead, it does not appear at all. Naming
  it costs the reader a paragraph to discover there was nothing to do.
- **He sends it, always.** The draft is a card on the page; nothing is ever sent from here.

## Per person

The blocks below are one job's people. A project that keeps a colleague database of its own, a
`team.json` or the facts section of its `CLAUDE.local.md`, is the register for its people and it
wins over anything inferred here. Read that first, and add a block below only for a defect he
actually corrected, never to copy a database into the kit.

### Taras Paliienko, Principal engineer, reviews and merges his PRs
- Ukrainian in DM. Technical, dense, no pleasantries, no thanks-in-advance.
- He is the one who finds the defect; the reply says what was wrong, what was done, what he can
  check now. Never explain the tooling to him.
- A PR announcement in `a_ws_ios_apps_pr` is exactly `Hi team, please review` and the bare URL. No
  ticket key, no description, no @-mentions.

### Ivan Kudriavtsev, PM, runs the AQA daily and the client reporting
- Russian. He asks about scope, dates and people, and he forwards what he is told to the client.
- Give facts and the state of the work, never an estimate that has not been checked, and never a
  recommendation about staffing or budget unless he asked in those words. Decisions about a second
  developer are his to make; the draft supplies the numbers, not the verdict.
- Recorded 2026-09-17: a draft had him volunteering to size somebody else's proof of concept and to
  choose between hiring and doing it himself. He cut both. Offer the fact, ask for the material,
  stop.

### Ihor Rudakov, AQA, writes the E2E tests against his identifiers
- Ukrainian. Peer to peer, concrete about screens and identifiers.
- He argues from what was already built, so a claim about effort must name what it is measured
  against, or it comes back contradicted.

### Andrei Popic, AQA
- Ukrainian or English, short. Same register as Ihor.

### Dmytro Vlasenko
- Russian. He built the earlier proof of concept, so ask for the branch or the pull request rather
  than describing what is needed.

### Oleksii Pelekh, Danevych, Drozd, Rusin, other reviewers
- Russian in DM, English in channels. A review request is one line and a link.

### Tony Sebastian, QA, and Karthik
- English only. Plain, factual, no idiom.

### Vendor Management and finance, the monthly invoice
- English, formal, complete sentences, the attachment named. This is the one place where a full
  polite frame is correct.

## Channels

- English in every channel without exception, whichever workspace.
- Client workspace, Williams-Sonoma: assume the client reads everything. No internal reasoning, no
  effort estimates, no complaints about tooling.
