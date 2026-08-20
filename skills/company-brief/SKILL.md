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
   restyle it. If a token has no data, write `не нашёл` rather than deleting the row. The complete
   token list is the table in **Template tokens** below; template and table are edited together or
   not at all.

   The confidence label is markup, not a word in the sentence. Open the claim with one of
   `<span class="tag ok">подтверждено</span>`, `<span class="tag maybe">правдоподобно</span>`,
   `<span class="tag guess">догадка</span>`. The template also carries `.warn` for red flags and
   `.note` for an explanation, and a `<pre>` for every English line he says out loud.
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

## Template tokens

Every token in `assets/brief-template.html`. No data → `не нашёл`, never a deleted row.

| Token | What goes in |
|---|---|
| `{{COMPANY}}` `{{ROLE}}` `{{CALL_AT}}` `{{DATE}}` | header: name, vacancy with link, when the call is, when the brief was built |
| `{{TRACKER_STATUS}}` `{{TRACKER_NEXT_STEP}}` `{{TRACKER_SALARY_GROSS}}` `{{TRACKER_COMMENT}}` | the sheet row, copied |
| `{{TIER}}` `{{TIER_VERDICT}}` | 1/2/3 and the one fact that decides whether this is worth his time |
| `{{OWNERSHIP_CHAIN}}` `{{ENGINEERS_LOCATION}}` `{{MANAGEMENT_LOCATION}}` `{{TIMEZONE_IMPACT}}` `{{OWNERSHIP_VERDICT}}` | section 2, verdict in his terms, one sentence |
| `{{HEADCOUNT}}` `{{HEADCOUNT_SOURCE}}` `{{HEADCOUNT_TREND}}` `{{HEADCOUNT_TREND_SOURCE}}` | with a date every time |
| `{{REVENUE}}` `{{REVENUE_SOURCE}}` `{{OWNERSHIP_CHANGE}}` `{{OWNERSHIP_CHANGE_SOURCE}}` `{{SIZE_MEANING}}` | `не раскрывается` is the honest answer for a private consultancy |
| `{{BUSINESS_MODEL}}` | `аутстафф` or `продукт`, one word, then the rest of section 4 follows from it |
| `{{CLIENT}}` `{{CLIENT_CANDIDATES}}` `{{ENGAGEMENT_TYPES}}` `{{PRODUCT_STACK}}` `{{TEAM_SHAPE}}` `{{PROJECT_NOTE}}` | section 4 |
| `{{APP_NAME}}` `{{APP_STORE_URL}}` `{{APP_LAST_UPDATE}}` `{{APP_MIN_IOS}}` `{{APP_RATING}}` | straight off the listing |
| `{{APP_OBS_1}}` `{{APP_OBS_2}}` `{{APP_OBS_3}}` | one observation each, every one labelled and pointable-at |
| `{{APP_IMPROVEMENT}}` `{{APP_CANDIDATES}}` | what he would improve; the candidate apps when the client is unknown |
| `{{NUMBER_ALREADY_NAMED}}` `{{NUMBER_SOURCE}}` `{{EMPLOYER_KNEW}}` | the figure they have already seen, where from, and whether they saw it before writing to him |
| `{{ANCHOR_PROFILE}}` `{{POSTING_RANGE}}` `{{MARKET_DATA}}` `{{CONTRACTOR_RATE}}` | the four money signals, in the order of section 6 |
| `{{RANGE}}` `{{RANGE_FLOOR}}` `{{RANGE_BASIS}}` `{{UNIT_CONVERSION}}` `{{WHO_NAMES_FIRST}}` `{{SHEET_DISAGREEMENT}}` | the range, the walk-away floor, how it was derived, the unit maths, who names a number first |
| `{{AXIS_PROCESS}}` `{{AXIS_HOURS}}` `{{AXIS_AUTONOMY}}` `{{AXIS_REMOTE}}` `{{CULTURE_VERDICT}}` `{{CULTURE_SOURCES}}` | section 7 |
| `{{RED_FLAGS}}` | goes into the `.warn` block; `нет` when there are none |
| `{{THESIS_1_RU}}`…`{{THESIS_5_RU}}` | exactly five, one sentence each |
| `{{THESES_EN}}` | the same five in English, inside `<pre>`, the way he will say them |
| `{{Q_CRITICAL_1}}`…`{{Q_CRITICAL_3}}` + `{{Q_CRITICAL_1_MEANING}}`…`{{Q_CRITICAL_3_MEANING}}` | the three that must be asked in the first ten minutes, and what each answer would mean |
| `{{QUESTIONS_REST}}` `{{QUESTIONS_EN}}` `{{DONT_SAY}}` `{{SOURCES}}` | `<li>` items; `{{QUESTIONS_EN}}` is plain text inside `<pre>` |

## The tracking sheet

He keeps a Google Sheet tracker. **Its ID is deliberately not written here — this repository is
public.** Take the ID from `CLAUDE.local.md` in Claude Code, or from the project instructions in
Cowork. If neither has it, ask him once and do not write the answer into this file.

Read it before writing anything. Read-only — he edits it himself unless he asks otherwise.

**The sheet is too large to read into context, and always will be.** A direct read fails with
`result exceeds maximum allowed tokens` and dumps the output to a file. That is the normal path,
not an error: take the dump and grep it by company name, never pull the sheet itself into the
conversation.

```bash
grep -i -n -m5 "<company>" <dumped-file>
```

If the grep is empty, try the domain and the legal suffix (`obox`, `out of the box`) before
concluding there is no row.

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

## The research checklist

Run all of it, every time, before writing a line. It is a fixed list on purpose: derived on the fly
it comes out different each run and half of it gets found by accident.

| Source | What to take from it, and only this |
|---|---|
| The vacancy on the job board | title, stack, location wording, published range, date |
| The company page on the same board | their own headcount claim, founding year, office list |
| His own profile on that board | **his published expectation, and whether they saw it before writing** |
| Clutch or the local equivalent | hourly rate to clients, size band, founding year, client reviews with dates |
| LinkedIn `/company/<slug>/people/` | headcount now, and the **engineer split by country** |
| The GitHub organisation | whether the profile stack exists there at all, and how recently |
| Their own site: `/about` and `/vacancies` | leadership and entities; the open-roles list shows where they are actually growing |
| Local job boards (happymonday.ua, dou.ua) | often a different headcount and founding year than the English site |
| App Store | whether the app exists at all, then version history and 1–2★ reviews |
| A recent salary report for that market | the range for this seniority, with its publication date |

Two failure modes, both seen:

- A number that appears on only one of these is `правдоподобно`, not `подтверждено`. Headcount and
  founding year routinely differ between the English site and the local board.
- «Nothing found» on a source that must have data is a failed search, not a finding. Re-run it by
  domain, by legal name, and by the founders' names before writing `не нашёл`.

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

### Did we already name a number

Check, in this order: **the job-board profile · the sheet row · the correspondence**. State it
outright — named or not, what, and whether the employer could see it before they made contact.

**This is the first anchor of the range, and it outranks every calculation.** He keeps a public
expectation on his Djinni profile. When a recruiter writes to him first, having seen that figure,
and the conversation continues, the figure is accepted as the base. Do not undercut it, do not
"sanity-check" it downwards, do not present a range whose top is below it.

> Verified 2026-08-20 on Out of the Box Systems. His profile said **$5000 NET/month after tax**,
> Obox wrote first and kept writing. This skill nonetheless produced €2.5–4k by working backwards
> from a Clutch rate, and the whole money section was wrong.

### The researched range

Sources by descending weight. Take the first one that has data, and use the later ones only to
bound it.

1. **The expectation on his job-board profile, plus whether the employer knew it at first
   contact.** Recruiter approached first, figure visible → the figure is the floor of the range,
   not its middle.
2. **A range printed in the posting itself.**
3. **Local market data for the client's country** — dou.ua for Ukraine, landing.jobs and itjobs.pt
   for Portugal, Glassdoor or the local equivalent filtered to that country, levels.fyi for Big
   Tech only.
4. **The contractor's own rate to its client** (Clutch and similar) — **the ceiling of the
   company's economics, never a way to derive an offer.** It says what they can afford, not what
   they will pay a candidate whose number they have already seen.
5. **A reasoned estimate**, last, labelled `догадка`, with the arithmetic shown.

**Hard rule: when a figure is already known to the employer, the back-calculation from the
contractor's margin is not applied at all.** It may appear in the brief as a ceiling, with that
word next to it, and nowhere else.

Then, still required:

- **Convert units before comparing anything.** Portuguese pay is quoted gross monthly over 14
  months, sometimes annual, sometimes with the meal allowance folded in; consultancies think in a
  day rate to the client; his own unit is a monthly B2B invoice under recibos verdes, and his
  profile figure is NET after tax. Show every conversion.
- **B2B is not employment gross.** No holiday, no subsidies, no employer social charges, so the
  invoice sits above an equivalent salary.
- **Never carry a range across markets.** A number that is normal for a Ukrainian outstaff
  contract can be absurd for a Portuguese client, and the reverse.
- **Cross-check the sheet, do not inherit it.** `Salary expectations (GROSS)` there is a model
  estimate filled in bulk. Where it disagrees with the research materially, show both, say which
  you stand behind, and why.
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
