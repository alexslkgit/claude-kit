---
name: idea
description: Validate a business idea end to end — read the raw idea, interview the user on one page, price the research before running it, then fan out subagents and come back with a verdict. Use when the user says «/идея», «есть идея», «прогони идею», «проанализируй идею», "validate this idea", or hands over a raw business idea in any form. Also use to continue or re-run an idea already in the lab.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, WebSearch, WebFetch, Task, Artifact
---

# Validating a business idea

Three stages, in order, each gated by the user: **understand → price → research.**
Nothing runs until he has seen what it will cost and pressed the last button himself.

Everything here is a decision he made and you cannot infer from the code. Everything that is a
matter of judgement — how many questions, how many subagents, how to split the work, which
models — is deliberately absent. Decide it per idea. Any number written into this file would
outlive the reasoning behind it.

## Where things live

- Runs: `~/Developer/idea-lab` — private, `github.com/alexslkgit/idea-lab`. One folder per idea
  under `ideas/`, committed per stage, plus an index row: date, idea, verdict, what it cost.
- The page: `app/review.html` in that repo is the working reference. Each stage produces a page
  by copying its markup and replacing the data block — see `app/TEMPLATE.md` for the contract.
- Published pages are Artifacts, republished at the same URL each round so his answers survive.

## Stage 1 — understand

He may dictate ten paragraphs or one sentence. Read all of it, then show him **what you
understood** before anything else. Getting this wrong wastes the whole run.

Questions come in two waves, never one wall of them. First the defining ones — the answers that
change what the research even consists of. Only then the follow-ups, and only the ones his
answers left standing. Dumping forty questions on someone who just described an idea is how the
tab gets closed.

Most answers are yours to draft; he corrects rather than composes. What is never yours: money,
time, geography, what he is willing to do with his own hands, partners, horizon. Offer a
position on each, let him confirm it.

When the idea as stated will not fly, say so plainly and propose what to change — but only once
you actually understand it, and at the moment you judge right. Never open with pre-baked
alternatives. Talk the way you would to a colleague outside on a break: no jargon, no term he
did not use first.

If he says he has no time, take the defaults, list them as assumptions, and carry the
assumptions through to the report so the verdict's foundations stay visible.

## Stage 2 — price

Show the plan and its cost on one screen, before anything runs: what each thread investigates,
why it is needed, and the projected spend **as a share of his weekly limit** — that is the unit
he thinks in. Show tokens and comparable past runs alongside it, never instead.

Record estimated versus actual after every run and price the next one off his real numbers, not
off averages.

A ceiling is set before the start. When it is reached, no new subagents launch and the report is
assembled from what arrived, saying plainly which topics went uncovered. Silently truncating and
implying full coverage is the worst thing this tool can do.

Cheap reconnaissance first, then the full run — the full run reuses what reconnaissance found.

## Stage 3 — research

Subagents return structured facts, not prose: claim, number, source, date. No separate
compression pass; there is nothing to compress. Raw output goes to files in the repo — never
into the conversation. What reaches him is the human-language read-out.

Unproven does not mean discarded. Three levels — confirmed, plausible, guess — everything
visible, nothing thrown away, and the verdict states which levels it rests on. Contradictions
between threads are surfaced, not averaged.

A failed thread gets one retry, then an honest line saying that topic is uncovered.

The run ends with the read-out and a page, both in Russian. Verdict is three lines of prose —
goes, does not go, or goes if X — never a score out of ten. No investor search, no legal
validation; those are not this skill.

## Standing constraints

- **Zero budget is the default.** The idea is assumed to launch on his time and his existing
  subscription. If it cannot launch without money, that is itself a verdict — not a reason to
  price advertising. Paid channels enter only after a "goes", capped at 5 €/day for a test.
- **He presses the last button.** The page produces a prompt into his clipboard; he runs it.
  Nothing starts on its own, and no page ever executes anything.
- **The page never talks back to you.** He answers, copies, pastes into chat; you rebuild the
  page. That round trip is the cost of the design and he accepted it.

## Page behaviour he asked for

Answered cards collapse, strike through, and stay in place — he must be able to reopen one and
add a second comment. Enter sends, Shift+Enter breaks the line. Every card carries a reject
button.

Two buttons in the dock, and the difference between them must be unmistakable, because he asked
about it: a quiet one that collects only what changed and is used every round, and a loud one
that means *no objections left, move to the next stage* — enabled only when nothing is waiting
and nothing is rejected. Its label names the next stage, not the action. Both copy into this
chat and nowhere else; the only thing that ever leaves for another session is the final research
prompt, and you hand him that in the conversation rather than through the page.
