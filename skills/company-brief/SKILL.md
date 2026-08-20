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

1. **The HTML brief.** The template is versioned in the kit repository and is fetched fresh on
   every run, so a fix to the layout reaches every surface at once — Claude Code, Cowork, a cloud
   session — without re-uploading the skill:

   ```bash
   curl -fsSL -o /tmp/brief-template.html \
     https://raw.githubusercontent.com/alexslkgit/claude-kit/main/skills/company-brief/assets/brief-template.html
   ```

   If the fetch fails, fall back to `assets/brief-template.html` in this skill's own directory and
   say in the read-out which one was used. Copy it, replace the `{{TOKENS}}`, change nothing else.
   **Never regenerate the markup and never restyle it** — the shape is fixed so he does not
   re-learn the layout every time. Layout complaints are fixed in the repository file, never in
   one brief.

   Three mechanics the template gives you, so the filling stays plain text:

   | You write | The page does |
   |---|---|
   | `+ текст` / `~ текст` / `? текст` at the start of a value | turns the prefix into the pill `подтверждено` / `правдоподобно` / `догадка` |
   | `не нашёл` as the whole value | **deletes the row.** A section whose rows all go away deletes itself, and so does its chip in the top navigation |
   | anything else | prints as written; inner HTML such as `<a>` is allowed |

   So write `не нашёл` freely — it is the instruction to hide, not text he will read. Never delete
   a row from the markup by hand.

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

## What the page shows, and in what order

**Everything below the fold is collapsed on load.** He opens what he wants. The chips row is gone:
one `развернуть всё` control, nothing else.

Always visible, in this order:

| Block | Rule |
|---|---|
| Шапка | company, role, call time, **the range and its floor** |
| Этап | the stage bar. `{{STAGES}}` is a `\|`-separated list and `{{STAGE_NOW}}` the 1-based current one. **On a first contact leave `{{STAGES}}` as `не нашёл` — the whole block disappears.** Only fill it when a process is genuinely under way |
| Насколько подходит | `{{FIT_SCORE}}` 0–100 plus one sentence. Score the fit to his strategy, not the company's quality |
| Вердикт | the one-paragraph read |
| Красный флаг | only when there is one |
| **Где они и сколько их** | where the engineers sit · where management sits · timezone · headcount · where it is registered. **This is what he wants to see first and it never goes into a collapsed block** |

Collapsed, in this order: подходит ли тебе · проект и команда · деньги · вопросы им · тезисы о себе ·
компания-прочее · трекер и источники.

**Field priority, decided by him on 2026-08-20 and not to be re-ordered by feel.** First class:
where the engineers are, where management is, timezone, headcount, the App Store link, the team
(size, seniority mix, project size). Second: growth over the year, revenue. Fourth, and near the
bottom: funding and ownership changes. Turnover and investor history are not what decides whether
he takes the call.

## What never goes in the brief

He named these on 2026-08-20 and they are permanent:

- **Никаких напоминаний про его легенду и параллельные работы.** He knows. The old раздел «чего не
  говорить» is deleted from the page. The legend still governs how the theses are written — it is
  your constraint, never his reminder.
- **Никакого списка запрещённых слов.** Same reason: it constrains your writing, it is not content.
- **Никаких общих вопросов.** «Сколько этапов», «какая команда» he remembers himself. A question
  earns its place only if it is specific to this company: a contradiction you found, an unnamed
  client, a stack mismatch, a number that does not add up.
- **Никаких простыней текста, который он должен зачитывать.** The five theses are one line each.
  The English wording lives inside a nested collapsed block and is never open on load.

## Подходит ли тебе — the block he actually decides from

His criteria are standing, not per-company. Judge every company against these, and never invert
them because they sound unflattering:

- **A large company with heavy process and no overtime is a plus, not a minus.** Boring and
  predictable is the goal of the current strategy.
- **Outstaff is usually a plus, and the reason is specific:** he does not work at the consultancy,
  he works inside the client. A twenty-person shop placing him into a large stable client is a
  better outcome than a twenty-person product company. So **the size and stability of the client
  outweigh the size of the employer** — and when the client is unknown, say that the plus is
  unconfirmed rather than assuming it.
- **A small company on its own is a stability risk**: the role lives or dies with one contract.
- Startups, crypto and CIS product companies are tier 3 — say so and stop.
- Overtime, on-call and night releases are a minus, every time.
- Full remote and a B2B contract under recibos verdes are conditions, not preferences. Their
  absence goes in `{{FIT_CONS}}` at the top.
- Being the only iOS engineer with nobody to review the code is a minus, even when the autonomy
  is a plus.

Three to five items on each side, one line each, concrete to this company. `{{FIT_VERDICT}}` is
one or two sentences: does this fit the strategy, and what is the condition on that answer.

## What the layout does for him

He reads this on a phone and he does not read pages that look like walls.

- **Nothing is expanded on load.** He opens blocks himself. One `развернуть всё` control, no chips.
- **A collapsed block shows only its `{{SUM_…}}` line.** Six words or fewer, the finding and not the
  topic: `18 человек, Rust, iOS нет` beats `информация о компании`.
- **`не нашёл` deletes the row**, then the block if it emptied. Never delete markup by hand.
- **Every list in `за`, `против`, вопросы and тезисы is strikeable.** He taps a line he disagrees
  with, it greys out and moves to the bottom of its own list, and the choice survives a reload. That
  is his edit, not yours: never pre-strike anything.
- **In-page anchors are banned.** A viewer that sandboxes the page turns `href="#id"` into an
  external-link prompt and a blank tab. Scrolling is done with buttons and `scrollIntoView`.
- **The theme button gives auto, light and dark.** Do not remove it and do not rely on
  `prefers-color-scheme` alone.

## Template tokens

Every token in `assets/brief-template.html`. No data → `не нашёл`, never a deleted row.

| Token | What goes in |
|---|---|
| `{{COMPANY}}` `{{ROLE}}` `{{CALL_AT}}` `{{DATE}}` | header: name, vacancy with link, when the call is, when the brief was built |
| `{{RANGE}}` `{{RANGE_FLOOR}}` | shown in the sticky header and again in the money block |
| `{{STAGES}}` `{{STAGE_NOW}}` | `Скрининг\|Техническое\|Финал` and `2`. `не нашёл` on a first contact, and the bar disappears |
| `{{FIT_SCORE}}` `{{FIT_SCORE_WHY}}` | 0–100 against his strategy, and one sentence saying what the number rests on |
| `{{VERDICT_10SEC}}` `{{RED_FLAGS}}` | the paragraph read, and the one thing that could end the process |
| `{{ENGINEERS_LOCATION}}` `{{MANAGEMENT_LOCATION}}` `{{TIMEZONE_IMPACT}}` `{{HEADCOUNT}}` `{{HEADCOUNT_SOURCE}}` `{{REGISTERED}}` | the always-visible «где они и сколько их» block |
| `{{SUM_FIT}}` `{{SUM_PROJECT}}` `{{SUM_MONEY}}` `{{SUM_QUESTIONS}}` `{{SUM_THESES}}` `{{SUM_COMPANY}}` `{{SUM_META}}` | the line shown while a block is collapsed, six words max, the finding and not the topic |
| `{{FIT_VERDICT}}` `{{FIT_PROS}}` `{{FIT_CONS}}` | fit block; pros and cons are `<li>` items, three to five each. He can strike any of them out on the page |
| `{{AXIS_PROCESS}}` `{{AXIS_HOURS}}` `{{AXIS_AUTONOMY}}` `{{AXIS_REMOTE}}` `{{CULTURE_VERDICT}}` `{{CULTURE_SOURCES}}` | how it is to work there, inside the fit block |
| `{{APP_STORE_URL}}` | **first row of проект и команда.** A link, not a name |
| `{{CLIENT}}` `{{TEAM_SHAPE}}` `{{TEAM_SENIORITY}}` `{{PROJECT_SIZE}}` | what the project is, how many people, the seniority mix, how big the codebase or the product is |
| `{{BUSINESS_MODEL}}` `{{PRODUCT_STACK}}` `{{CLIENT_CANDIDATES}}` `{{PROJECT_NOTE}}` | the rest of the project block |
| `{{APP_LAST_UPDATE}}` `{{APP_MIN_IOS}}` `{{APP_RATING}}` `{{APP_OBS_1}}`…`{{APP_OBS_3}}` `{{APP_IMPROVEMENT}}` | the listing, then observations he can point at, then his opening move |
| `{{MONEY_NAMED_WHERE}}` | **first row of the money block.** Whether a figure has already gone to them and through which channel: the profile, the application form, an email, or nowhere |
| `{{WHO_NAMES_FIRST}}` `{{ANCHOR_PROFILE}}` `{{POSTING_RANGE}}` `{{MARKET_DATA}}` `{{CONTRACTOR_RATE}}` `{{RANGE_BASIS}}` `{{UNIT_CONVERSION}}` `{{SHEET_DISAGREEMENT}}` | the four signals in weight order, then the reasoning and the unit maths |
| `{{Q_CRITICAL_1}}`…`{{Q_CRITICAL_3}}` + `{{Q_CRITICAL_1_MEANING}}`…`{{Q_CRITICAL_3_MEANING}}` | the three that must be asked in the first ten minutes, each specific to this company |
| `{{QUESTIONS_REST}}` | `<li>` items, still company-specific. `не нашёл` if there are none, and the block disappears |
| `{{THESIS_1_RU}}`…`{{THESIS_5_RU}}` `{{THESES_EN}}` | one line each; the English version sits in a nested collapsed block |
| `{{OWNERSHIP_VERDICT}}` `{{OWNERSHIP_CHAIN}}` `{{HEADCOUNT_TREND}}` `{{HEADCOUNT_TREND_SOURCE}}` `{{REVENUE}}` `{{REVENUE_SOURCE}}` `{{OWNERSHIP_CHANGE}}` `{{OWNERSHIP_CHANGE_SOURCE}}` `{{SIZE_MEANING}}` | компания-прочее, the low-priority block |
| `{{TRACKER_STATUS}}` `{{TRACKER_NEXT_STEP}}` `{{TRACKER_SALARY_GROSS}}` `{{TRACKER_COMMENT}}` `{{TIER}}` `{{TIER_VERDICT}}` `{{SOURCES}}` | трекер и источники, at the bottom. The word «Тир» carries its own hover explanation in the template |

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
| Transcripts of earlier calls with this company, `~/Developer/meeting-listener/live/*.txt` | **only when a process is already under way.** grep by company name: he asks about team size, seniority mix and project size on the first call, so the answers to `{{TEAM_SHAPE}}`, `{{TEAM_SENIORITY}}` and `{{PROJECT_SIZE}}` are usually already there |

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

Exactly five, **one line each**, what he should be saying about himself at this company. Not skills
— narrative. Broad generalist or narrow specialist. High-load consumer app or enterprise
correctness. Owning a platform long-term or shipping fast.

- **Derive them from this company, never from the last interview's.** Breadth reads as ownership in
  one place and as no focus in the next.
- **Match the aspirational culture, not the observed one.** Nobody is hired for describing how
  little the job demands.
- The English wording goes in `{{THESES_EN}}`, inside the nested collapsed block. It is there if he
  wants it, never in his face — a script he is expected to read out loud is the thing he objected to.

## 9. Critical questions

**Only questions that could not have been asked at any other company.** He remembers the generic
ones himself, and a generic list is what makes him stop reading. Every question has to come out of
something you actually found: a client that is not named, a stack that contradicts the vacancy, a
seniority band that does not match the money, a review that says something the site does not.

Three of them are marked as first-ten-minutes, because a wrong answer ends the process, and each
carries what the answer would mean. `{{QUESTIONS_REST}}` holds anything else specific to this
company — `не нашёл` when there is nothing, and the block disappears rather than filling with
filler.

## 10. What not to say

**Research-only. This never becomes a block on the page** — see «What never goes in the brief».
Use it to constrain how sections 8 and 9 are written: keep the standing legend intact, keep the
current employer out of it, keep the banned vocabulary out of the wording. Do not print any of it
back to him.

## Sources

End with the links actually used. He re-reads them before the call, and a brief whose numbers
cannot be traced is one he cannot trust next time.
