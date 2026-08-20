---
name: company-brief
description: Research a company before an interview and return a fixed-shape brief — who actually owns it and where its engineers sit, size and money, the product or the outstaff project, the iOS app with a link, a researched pay range, the real culture, five narrative theses for the call, and the critical questions. Use whenever he asks in ANY wording about a company he is talking to or considering: «расскажи о компании», «разбери компанию», «что за компания», «что это за контора», «подготовь меня к собесу», «готовимся к интервью», "tell me about this company", "what do we know about them", or pastes a vacancy, a recruiter email or a calendar invite. Also use before drafting any reply to a recruiter at a company not yet researched.
allowed-tools: WebSearch, WebFetch, Read, Write, Edit, Bash, Task
---

# Researching a company before an interview

The request is never curiosity. An interview is coming, usually within hours, and he needs things
to say and things to ask. A brief that is only facts about the company has failed.

## Non-negotiables

- **Never answer from what you already know.** Every section rests on something fetched in this
  run. Priors about size, geography, pay or culture are the largest source of wrong briefs.
- **Label anything that is not a quoted source: confirmed / plausible / guess.** An unlabelled
  guess is what he catches you on, and it costs the whole brief its credibility.
- **Never invent an observation about their app.** He quotes those out loud in the call.
- Answer in Russian. Tone dry and engineering. Banned words: thrilled, passionate, dynamic, delve,
  excited.
- The section order below is fixed. He reads the same shape every time.
- Time-box to the calendar. Under an hour to the call: cut depth, never sections. A thin sourced
  line beats a missing block.

## Output

Two things, always both:

1. **The HTML brief.** Fill `assets/brief-template.html` from this skill's own directory. Copy it,
   replace the `{{TOKENS}}`, change nothing else — the template is fixed on purpose so every brief
   looks the same and he does not have to re-learn the layout. Never regenerate the markup, never
   restyle it. If a token has no data, write `не нашёл` rather than deleting the row.
2. **A short read-out in the chat** — the row, the verdict, the pay line, and anything that must be
   decided before the call. Five lines, not the whole brief.

Where it goes:

- Claude Code: write to `~/Developer/job-search/briefs/<company>-<YYYY-MM-DD>.html`, create the
  folder if missing, then print the path. Do not put briefs in the kit repo.
- Cowork: deliver the file, and persist it as an artifact so it survives the session.

## Readability rules — as binding as the content

He reads these on a phone, ten minutes before a call. A wall of text is a failed brief.

| Rule | Limit |
|---|---|
| Sentence | one clause where possible, ~15 words |
| Paragraph | 3 lines, then break |
| Prose in a row | 2 paragraphs, then a list or a table |
| Table | when two or more things are compared on the same axes |
| List | when order or count matters (theses, questions) |
| Bold | the noun being decided, not whole sentences |

No preamble, no restating the question, no closing summary. Numbers carry their unit and their
date inline. English wording he will say out loud goes in a monospace block, separate from the
Russian explanation.

## The tracking sheet

He keeps a Google Sheet tracker. **Its ID is deliberately not written here — this repository is
public.** Take the ID from `CLAUDE.local.md` in Claude Code, or from the project instructions in
Cowork. If neither has it, ask him once and do not write the answer into this file.

Read it before writing anything. Read-only — he edits it himself unless he asks otherwise.

First tab is the application tracker. Relevant columns:

| Column | Use |
|---|---|
| `Company`, `Country`, `Company Size` | the row exists at all — check by company name first |
| `Status`, `Next Step`, `Apply date` | where the process already stands |
| `Salary expectations (GROSS)` | **a model estimate, filled in bulk, not evidence.** Quote it, never inherit it |
| `Salary Range` | the range the company actually published, usually `unknown` |
| `Contact person`, `Whose search` | who sourced it — Vika or him |
| `Oleksandr's Comment` | his own notes, outweighs everything else in the row |

Later tabs hold an event log, a target-company list, a promoted-vacancy pipeline, an outstaff
company list and recruiter contacts. Say plainly when there is no row for this company — it means
nothing was promised to them and nothing is on record.

## 1. The row

Open with the standing table, one row:

| Компания | Статус | Следующий шаг | Зарплата B2B Gross | Комментарий |

The comment carries the tier and the one fact that decides whether this is worth his time.

| Tier | What | CV | Range |
|---|---|---|---|
| 1 | banks, retail, outstaff | Default CV | €5–8k |
| 2 | FAANG / Big Tech | Lead CV | €10–15k+, referral only |
| 3 | startups, crypto, CIS product companies | — | blacklist, say so and stop |

## 2. Whose company is this, actually

Not the flag on the website. Three separate answers:

- **Ownership chain to the top.** A US registration with a small US office is a common and
  legitimate arrangement; so is a Cyprus holding staffed from Ukraine. Follow it to whoever
  actually owns the company, parent's parent included.
- **Where the engineers sit** — not the HQ, not where the entity is registered. Use LinkedIn's
  people-by-location breakdown, the locations on their job postings, the office list. For large
  companies name where *development* is concentrated: a company can employ everywhere and still
  build in three sites.
- **Where his managers sit**, and in which timezone. That decides how much of his day the job eats.

Then the verdict in his terms, one sentence: «интернациональная, по факту Индия + Украина,
менеджмент в США, владелец японский». Not «a global technology leader».

## 3. Size and money

| Wanted | Note |
|---|---|
| Headcount | with a date and a source |
| Direction over the last year | hiring, freeze, layoffs |
| Revenue or turnover | only when the number exists; for a private consultancy `не раскрывается` is the honest answer |
| Owner change, funding | only when it explains the current hiring |

Size is a proxy for the two things he cares about: how heavy the process will be, and whether pay
comes off a rate card or is negotiated per person.

## 4. What they sell, and the project

**Service / outstaff.** The client is the real employer of his day.

- Name the client when it is known or inferable from case studies and postings.
- When it is not, say so and list the plausible candidates by industry. The first question in the
  call will be which client this is.
- Cover the engagement types they sell — team extension, managed service, nearshore. It predicts
  whether he joins an existing iOS team or lands solo inside a client.

**Product.** The product, how it makes money, its users, its stage, and the iOS app's place in it.

Written from a developer's angle: stack, platform, release cadence, team shape. Not the marketing
positioning.

## 5. Their app

The highest-value part of the brief. His standing move is to say he clicked through their app and
found specific things. Give him the material.

Deliver the App Store link and two or three concrete observations he can say out loud.

Where observations come from, in order:

1. Recent 1–2★ reviews — they name the actual bugs and the actual friction.
2. Version history and release cadence.
3. The listing itself: screenshots, iPad support, minimum iOS, size, last update.

Two hard rules:

- **Separate what you saw from what you inferred, and never write an observation you cannot point
  at.** A fabricated detail about their own app, in front of the engineer who built it, is the
  worst possible outcome of this skill.
- Service company with an unknown client, or many apps shipped: say so and give the candidate
  links. «Их может быть несколько, вот эти» is a correct answer.

Close with one line on what he could offer to improve. That is the second half of his move.

## 6. Money

Two separate things, both required.

**Did we already name a number.** Check the sheet row first and state it outright: named or not,
and what. An answer in the call that undercuts a figure already sent by email destroys the
negotiation.

**The researched range.** Not a feeling. This is where this skill is most often wrong, so:

- **Anchor on who pays the invoice and where their client is.** A Portuguese consultancy with
  offices only in Portugal and Spain, billing a Portuguese client, is bounded by the Portuguese
  rate card. Local pay in Portugal sits far below the same seniority in Ukraine, let alone the US.
  A number that is normal for a Ukrainian outstaff contract can be absurd here. Never carry a
  range across markets.
- **Sources by descending weight:** a range printed in the posting · local salary data
  (landing.jobs, itjobs.pt for Portugal; dou.ua for Ukraine) · Glassdoor or the local equivalent
  filtered to that country · levels.fyi, Big Tech only. A reasoned estimate comes last, labelled a
  guess, with the reasoning shown.
- **Convert units before comparing anything.** Portuguese pay is quoted gross monthly over 14
  months, sometimes annual, sometimes with the meal allowance folded in; consultancies think in a
  day rate to the client. His unit is a monthly B2B invoice under recibos verdes. Show the
  conversion whenever you cross units.
- **B2B is not employment gross.** No holiday, no subsidies, no employer social charges, so the
  invoice sits above an equivalent salary — while the consultancy's margin caps it from above.
  State both bounds when they differ.
- **Cross-check the sheet, do not inherit it.** Where research and the sheet disagree materially,
  show both, say which you stand behind, and why.
- Give the range **with the walk-away floor**, and say whether to name a number first or bounce the
  question back to the recruiter.

If the research does not support a number, say that. An honest «нет данных, вот как вытянуть вилку
из них в звонке» beats a confident invention.

## 7. The real culture

What the site says about culture is a hiring asset, not evidence. Go after the sourced kind:
Glassdoor and Blind reviews with dates, Reddit and dou.ua threads, tenure patterns on LinkedIn, the
wording of their own postings, any mention of overtime, on-call, release pressure, layoffs,
micromanagement.

Then rate the four axes that matter to the current strategy — replace one job with a calmer,
better-paid one:

| Axis | Question |
|---|---|
| Process weight | bureaucratic and slow, or startup chaos |
| Hours | overtime, on-call, night releases |
| Autonomy | how much of the day is meetings and status |
| Remote reality | fully remote, or an office nearby that quietly becomes hybrid |

Say plainly when a company is boring in a way that suits him. A large bureaucratic corporate with
no overtime is a good outcome under this strategy, not a downside.

## 8. Five theses for the call

A separate block, exactly five, one sentence each: what he should be saying about himself **at this
company**. Not skills — narrative. Broad generalist or narrow specialist. High-load consumer app or
enterprise correctness. Owning a platform long-term or shipping fast. Process discipline or
autonomy.

- **Derive them from this company's culture, never from the last interview's.** The same words get
  him hired at one company and cut at another: breadth reads as ownership in one place and as no
  focus in the next. Re-derive every time.
- **Match the aspirational culture, not the observed one.** Where the honest read is a slow
  bureaucracy, the theses still speak to reliability, ownership and predictable delivery. Nobody is
  hired for describing how little the job demands.
- Stay inside the standing legend for external HR — building his own product on the side, looking
  for one stable enterprise role without overtime. Never surface the parallel jobs.

Give the wording in English, the way he will say it.

## 9. Critical questions

A separate block, his questions to them, disqualifying ones first: which client and which product ·
fully remote or onsite days and where · B2B through recibos verdes or CLT only · contract length and
renewal · existing iOS team or solo · on-call and out-of-hours releases · what the next step is.

Mark the two or three that must be asked in the first ten minutes because a wrong answer ends the
process, and say what each answer would mean.

## 10. What not to say

Short and specific to this company: the parallel jobs, whatever in his history conflicts with the
legend, the current employer as a target, the banned vocabulary.

## Sources

End with the links actually used. He re-reads them before the call, and a brief whose numbers
cannot be traced is one he cannot trust next time.
