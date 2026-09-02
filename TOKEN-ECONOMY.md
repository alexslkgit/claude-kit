# TOKEN-ECONOMY

Everything measured about what this setup costs, newest first. Replaces the three separate
`TOKEN-AUDIT-*.md` files, which were three snapshots of one investigation and were being re-read
as if they were three independent findings.

## What is still true, 2026-09-02

The unit changed: everything below is measured in **percent of the Max 5-hour meter per 1M
tokens** (integer percents, read from `api.anthropic.com/api/oauth/usage` with up to about 2
minutes of lag), fitted from controlled `claude -p` sessions, not in API dollars.

Fitted weights, percent of the 5-hour meter per 1M tokens:

| model | cache_read | cache_write (1h) | input | output |
|---|---|---|---|---|
| Opus 5 | 0.07 (range 0.05-0.10) | 1.6 (range 1.1-2.2) | 1.3 (assumed) | 60 (range 50-70) |
| Fable 5.1 | unmeasured | 5.0 | not measured | about 60 at effort medium |
| Sonnet 5 | unmeasured | unmeasured | not measured | 20 (one run, range 0-40; a third of Opus, in line with the price ratio) |

The weekly meter moves at about 1/5.5 of the 5-hour meter this week; the weekly limit itself is
boosted 50 percent until 2026-09-13, so this week's weekly percentages read low against a normal
week.

Runs table, from `research/meter/FACTS-2026-09-02.md`:

| run | model | requests | cache_read | cache_write(1h) | output | 5h meter | weekly |
|---|---|---|---|---|---|---|---|
| C output-heavy | opus-5 | 13 | 0.80M | 0.09M | 88 663 | 23 to 31 (+8) | 5 to 6 |
| C2 output-heavy, fresh 5h window | opus-5 | 21 | 3.08M | 0.21M | 205 829 | 0 to 12 (+12) | 16 to 19 |
| C-fable output-heavy, effort medium | fable-5-1 | 11 | 0.51M | 0.06M | 45 773 | 15 to 18 (+3) | 19 to 20, Fable 23 to 24 |
| Q quiet 3 min | none | 0 | (foreign ~0.8M) | | | 32 to 33 | 7 to 7 |
| A1 read-heavy | opus-5 | 61 | 12.1M | 0.18M | 244 | 33 to 36 (+3) | 7 to 7 |
| B1 4 fresh loads | opus-5 | 4 | 0.09M | 0.68M | 16 | 36 to 37 (+1) | 7 to 8 |
| A2 read-heavy | opus-5 | 31 | 6.3M | 0.19M | 124 | 37 to 38 (+1) | 8 to 8 |
| A-fable effort medium | fable-5-1 | 31 | 0.83M | 5.66M | 124 | 38 to 66 (+28) | 8 to 13, Fable 6 to 17 |
| A3 read-heavy | opus-5 | 101 | 21.0M | 0.19M | 404 | 68 to 69 (+1) | 14 to 14 |
| B2 8 fresh loads | opus-5 | 8 | 0.18M | 1.85M | 32 | 69 to 72 (+3) | 14 to 15 |
| A-fable no effort flag | fable-5-1 | 6 | 0.16M | 1.10M | 24 | 72 to 78 (+6) | 15 to 16, Fable 18 to 20 |

### What it means

On the meter, not on the price sheet, output tokens are 75 percent of the combined spend (SIM
class shares): cache reads are 15 percent, cache writes 10, input near zero. The 2026-08-25 dollar
audit priced cache reads at 57 percent of the bill; on the meter they are a seventh of that share.
Subagents are 56 percent of the combined meter, and 78 percent of their own spend is output, higher
than the main thread's 71 percent.

### The threshold table

Headline table from `SIM-2026-09.md`, floor re-write charged on every cut:

| threshold | delta vs never (meter-%/day) |
|---|---|
| 200k | +2.0 |
| 300k | -0.2 |
| 400k | -0.2 |
| before-break | +3.0 |

Compaction costs 0.47 meter-percent per cut against a plain handoff's 0.45. Idle expiry past the
1h cache TTL produced 234 gaps over 31 days and 45M tokens re-written, under 0.4 points a day, so
it barely moves the total either way.

### The one rule

Never cut by hand. Auto-compact fires at 300k (window set to 313k), and STATUS is re-injected
after it the same way it already is after a manual clear. The lever worth pulling is output, not
context: shorter replies, fewer and larger Bash scripts, the page-writer subagent for long files,
effort medium, and subagents that return conclusions instead of raw material.

State the uncertainty honestly: the output weight alone carries about plus or minus 15 percent on
every total here, larger than the spread between any two of the policies above.

### Pitfalls

- Refusals do not move the meter: a run of random dictionary-word prompts got refused and left the
  meter untouched even though the run reported real cache_write tokens.
- Fable 5.1 under `claude -p --resume` with a 150k single-message context never hit the cache
  (5.7M tokens rewritten every turn); a normal prompt on the same model cached fine. Do not
  benchmark Fable through `-p --resume`.
- The Fable weekly scoped meter has its own 50 percent cap, separate from the all-models weekly
  meter, and the experiment moved it from 3 to 24.
- Measuring needs an idle account: one run was contaminated by another of his chats active in the
  same window.

### Where the material lives

`~/Tasks/browser-token-economy/research/meter/`: `meter-run.sh`, `usage.sh`, `meter.log`,
`results.csv`, `FACTS-2026-09-02.md`, `sim2.py`, `breakdown.py`, `compaction.py`,
`SIM-2026-09.md`. `gaps.py` is in `research/scripts`.

## What is still true, 2026-08-31

- A request costs about $0.105 whatever tool it runs. The price is the context re-sent underneath
  it, not the payload. Shrinking what is inside a call is close to worthless next to making fewer
  calls.
- **The session-start floor is now the larger half of the bill: 58% on 2026-08-31, against 36% on
  08-13.** The floor grew 65k to 86k in twenty days. See `DECISIONS.md`, entry of 2026-08-31.
- **A denied built-in tool is dropped from the prompt, not merely blocked.** Four of them,
  `Artifact`, `Workflow`, `ScheduleWakeup`, `ReportFindings`, are 23 333 tokens of floor,
  measured 2026-08-31 against a control session four minutes apart on the same config. That is
  29% of the floor and about 15% of the whole bill in a project where those tools are unused.
  Confirmed in a second project on 2026-09-01: `ai-company` fell 81 276 to 61 764, minus 19 512.
  **Only built-ins leave.** Denying an **MCP** tool does nothing for cost: its schema stays in the
  prompt, only switching the connector off removes it. Denying a **skill** does nothing either,
  measured 2026-09-01: ten `Skill(...)` entries moved the floor by five tokens and every denied
  skill was still described in full, because the listing is built before permissions apply. Roll out with `tools/deny-tools.py <project-dir> <Tool>...`,
  per project and by measured use, never globally: `Artifact` is genuinely used in
  `energy-tracker`, `Rodovid_business` and `Downloads`.
- The cutting threshold is 200k, about twelve cuts a day. 150k is the arithmetic optimum; he
  refused twenty-one cuts a day as unlivable on 2026-08-25 and that veto stands.
- Tool traffic held in main contexts is 46% of the conversation half. Ranked: screenshots 13%,
  Bash 13% from call count alone, Read 5%, Write 4%.
- Subagents are 39% of the bill. Delegation moves cost, it does not remove it. Fanning out small
  tasks measured 2.6 to 5.9 times a sequential run and was never faster on wall clock.
- The tail dominates: the top 5% of sessions are 27% of the dollars. A hard cap beats average
  discipline.
- Every rule derived from these numbers now lives in a hook, not in prose. A threshold that only
  lives in text loses to whatever is happening at the moment it is crossed; measured over 173
  transcripts, the 250k rule was ignored for a month and the month came out identical to never
  cutting at all.

## Which numbers a hook cites

`hooks/context-guard.sh` and `hooks/bulk-guard.sh` cite the 2026-08-17 audit by name. Its section
is kept below verbatim for that reason.


---

# Archived: TOKEN-AUDIT-2026-08-25.md

# Token audit 2026-07-26 → 2026-08-25 — the money answer

Third in the series after `TOKEN-AUDIT-2026-08-03.md` (three machines, established that uncut sessions
dominate) and `TOKEN-AUDIT-2026-08-17.md` (established *where* to cut). Those two priced everything in
"fresh-input-equivalent units". This one is in **dollars at API list price**, over a fresh 31-day window,
and it re-tests the 250k handoff rule against the data instead of against a model.

## The headline

**$8,145.72** at Claude API list prices over 31 days — **$262.77/day**.
71,281 API requests, 9.78B tokens, 270 sessions.

| | tokens | share of tokens | dollars | share of dollars |
|---|---:|---:|---:|---:|
| fresh input | 886,058 | 0.01% | $3.76 | 0.05% |
| cache read | 9,433,776,238 | 96.50% | $4,632.13 | 56.87% |
| cache write | 280,404,538 | 2.87% | $2,069.25 | 25.40% |
| output | 60,847,294 | 0.62% | $1,440.58 | 17.69% |
| **total** | **9,775,914,128** | 100% | **$8,145.72** | 100% |

Cache writes split 166.9M at the 5-minute TTL (1.25x) and 113.5M at the 1-hour TTL (2x).
Thinking is 12.1M tokens, 20% of all output but only **3.5% of the bill** — the third audit in a row to
find reasoning effort is a marginal lever.

## "95% goes on re-reading" — half right, and the half that is wrong is the half that matters

He remembers 95%. The honest answer is that **both numbers are true of different things**:

- **96.5% of raw tokens** moved through the API were `cache_read` — context that already existed and was
  re-sent. His 95% is a good memory of the *token* figure.
- **56.9% of dollars** were cache reads. Cache reads bill at one tenth of input, so the token share
  overstates the money by nearly a factor of two.

Put the other way: content that is **new in the request** — fresh input + cache write + output — is
**3.5% of tokens but 43.1% of the dollars**. The 0.1x cache-read discount is doing enormous work.
Anyone optimising against the 96% figure will over-invest in shrinking context and under-invest in the
**43.1% of the bill that is cache writes plus output** — material entering and leaving, not being re-read.

The input side as a whole (input + cache read + cache write) is **82.3%** of dollars; generation is 17.7%.

## Trend by week

| week starting | days | requests | dollars | $/day | $/request | cache read, share of $ |
|---|---:|---:|---:|---:|---:|---:|
| 2026-07-26 | 7 | 4,386 | $611.59 | $87.37 | $0.1394 | 58.3% |
| 2026-08-02 | 7 | 10,904 | $1,370.31 | $195.76 | $0.1257 | 60.0% |
| 2026-08-09 | 7 | 24,243 | $2,907.13 | $415.30 | $0.1199 | 59.8% |
| 2026-08-16 | 7 | 18,668 | $2,031.45 | $290.21 | $0.1088 | 52.9% |
| 2026-08-23 | 3 | 13,080 | $1,225.25 | $408.42 | $0.0937 | 52.2% |

Spend more than quadrupled from week 1 to week 3 and the last partial week is running at $408.42/day.
The one genuinely good trend is the right-hand column: cache read fell from 58% to 52% of dollars,
and cost per request fell 33% from the peak week — contexts are getting shorter even as volume grows.

Most expensive days: 2026-08-10 $721.49, 2026-08-13 $634.42, 2026-08-25 $617.64, 2026-08-24 $607.60, 2026-08-19 $523.25.

## By model

| model | requests | dollars | share | $/request |
|---|---:|---:|---:|---:|
| `claude-opus-5` | 56,876 | $7,307.10 | 89.70% | $0.1285 |
| `claude-fable-5` | 1,522 | $498.09 | 6.11% | $0.3273 |
| `claude-sonnet-5` | 12,136 | $333.25 | 4.09% | $0.0275 |
| `claude-haiku-4-5-20251001` | 562 | $5.99 | 0.07% | $0.0107 |
| `claude-opus-4-8` | 10 | $1.29 | 0.02% | $0.1293 |
| `<synthetic>` | 175 | $0.00 | 0.00% | $0.0000 |

`<synthetic>` is not an API call (harness-generated error/interrupt messages) and is priced at zero.
Every model id in the transcripts is in the published price table, so nothing needed a substituted price.

**Fable is the surprise here.** 1,522 requests — 2.1% of them — cost $498.09, **6.1% of the bill**, because
Fable 5 is priced at 2x Opus 5 ($10/$50 vs $5/$25). At $0.327 per request it is **2.5x the cost of an
average Opus 5 request** ($0.128) and **12x a Sonnet 5 one** ($0.027).

## By project — top 15

| # | project | requests | sessions | dollars | share |
|---:|---|---:|---:|---:|---:|
| 1 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 27,642 | 68 | $3,293.57 | 40.4% |
| 2 | `-Users-slobodianiukoleksandr-Finances-finapp` | 9,211 | 37 | $1,074.73 | 13.2% |
| 3 | `-Users-slobodianiukoleksandr-Test-task` | 7,834 | 26 | $977.70 | 12.0% |
| 4 | `-Users-slobodianiukoleksandr-Developer-expence-tracker` | 8,071 | 25 | $942.49 | 11.6% |
| 5 | `-Users-slobodianiukoleksandr-Downloads` | 6,968 | 40 | $700.75 | 8.6% |
| 6 | `-Users-slobodianiukoleksandr-Documents-Tree-storage` | 5,189 | 39 | $481.24 | 5.9% |
| 7 | `-Users-slobodianiukoleksandr-Documents-Rodovid-business` | 4,200 | 18 | $428.94 | 5.3% |
| 8 | `-Users-slobodianiukoleksandr-Developer-ai-company` | 866 | 5 | $102.47 | 1.3% |
| 9 | `-Users-slobodianiukoleksandr-oportunity-radar` | 540 | 3 | $58.75 | 0.7% |
| 10 | `-Users-slobodianiukoleksandr-Downloads-obox-form` | 190 | 1 | $19.33 | 0.2% |
| 11 | `-Users-slobodianiukoleksandr-Downloads-html-autoswipe` | 153 | 2 | $18.18 | 0.2% |
| 12 | `-Users-slobodianiukoleksandr-Developer-ai-company-desks-6-launch` | 94 | 1 | $15.01 | 0.2% |
| 13 | `-Users-slobodianiukoleksandr-Tasks-obox-form` | 103 | 2 | $11.21 | 0.1% |
| 14 | `-Users-slobodianiukoleksandr-Tasks-portugal-taxes` | 108 | 1 | $10.18 | 0.1% |
| 15 | `-Users-slobodianiukoleksandr-Developer-energy-tracker-snapshot-fix` | 53 | 1 | $5.44 | 0.1% |

`energy-tracker` alone is **40%** of the bill. The top four projects are 77%.

## By session

270 sessions. Median **$21.10**, p75 $35.78, p90 **$54.49**, p95 $73.85, max **$639.40**.

**The top 5% of sessions (14 of them) hold 27.3% of all dollars**; the top 10% hold 37.4%; the single
worst session is 7.8% on its own. That is far less concentrated than the 48–65%-on-one-session found in
August 2026's first audit — the handoff discipline has flattened the tail, as that audit predicted it would.

| # | project | requests (main / sub) | peak context | hours | dollars |
|---:|---|---:|---:|---:|---:|
| 1 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 4,171 (2,139 / 2,032) | 526,798 | 80.0 | $639.40 |
| 2 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 1,207 (515 / 692) | 458,104 | 47.9 | $258.65 |
| 3 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 1,539 (56 / 1,483) | 561,237 | 605.5 | $178.74 |
| 4 | `-Users-slobodianiukoleksandr-Test-task` | 906 (88 / 818) | 238,043 | 22.2 | $136.70 |
| 5 | `-Users-slobodianiukoleksandr-Developer-expence-tracker` | 845 (83 / 762) | 232,262 | 119.4 | $135.50 |
| 6 | `-Users-slobodianiukoleksandr-Finances-finapp` | 596 (77 / 519) | 241,582 | 20.0 | $130.29 |
| 7 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 989 (170 / 819) | 325,562 | 5.7 | $119.46 |
| 8 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 1,114 (192 / 922) | 366,465 | 17.2 | $107.69 |
| 9 | `-Users-slobodianiukoleksandr-Developer-energy-tracker` | 773 (293 / 480) | 478,713 | 18.0 | $96.62 |
| 10 | `-Users-slobodianiukoleksandr-Test-task` | 716 (174 / 542) | 362,705 | 2.9 | $92.20 |

The worst session ($639.40, 4,171 requests, 527k peak, starting 2026-07-31) is the same monster the
2026-08-17 audit identified as 15% of that sample. It sits in the first week of this window and is the
main reason week 1 looks as it does.

Concentration by context rather than by session:

| | dollars | share of bill |
|---|---:|---:|
| in sessions whose peak passed 200k (197 sessions) | $7,515.05 | 92.3% |
| in sessions whose peak passed 250k (114 sessions) | $5,227.63 | 64.2% |
| in sessions whose peak passed 300k (66 sessions) | $3,896.35 | 47.8% |
| in sessions whose peak passed 400k (12 sessions) | $1,523.62 | 18.7% |
| in individual requests already above 200k of context | $3,078.00 | 37.8% |
| in individual requests already above 250k of context | $1,845.93 | 22.7% |
| in individual requests already above 300k of context | $1,141.29 | 14.0% |

The distinction matters. **64% of dollars sit in sessions that eventually passed 250k**, but only
**23% of dollars are spent while actually above 250k**. Most of an expensive session's bill is racked
up on the way there, which is exactly why a threshold that only fires at the top cannot recover much.

## By tool

Each request's full cost is attributed to the `tool_use` blocks of the immediately preceding assistant
message in the same stream, split evenly. Requests with no preceding tool call — the first request of a
user turn — are bucketed separately: **3,970 requests, $1,212.88, 14.9% of the bill**.

| # | tool | calls | dollars | share | $/following request | images returned |
|---:|---|---:|---:|---:|---:|---:|
| 1 | `Bash` | 37,286 | $3,424.72 | 42.0% | $0.1051 |  |
| 2 | `Edit` | 6,687 | $637.52 | 7.8% | $0.1058 |  |
| 3 | `Read` | 8,834 | $618.35 | 7.6% | $0.1012 | 2118 |
| 4 | `mcp__Claude_Code_iOS_Simulator__control` | 3,816 | $385.01 | 4.7% | $0.1047 | 1129 |
| 5 | `Write` | 1,795 | $260.17 | 3.2% | $0.1486 |  |
| 6 | `Agent` | 1,258 | $175.57 | 2.2% | $0.1737 |  |
| 7 | `mcp__Claude_Browser__javascript_tool` | 1,507 | $153.64 | 1.9% | $0.1051 |  |
| 8 | `mcp__claude-in-chrome__computer` | 1,858 | $130.51 | 1.6% | $0.0736 | 738 |
| 9 | `mcp__claude-in-chrome__javascript_tool` | 1,432 | $100.47 | 1.2% | $0.0712 |  |
| 10 | `ToolSearch` | 988 | $95.37 | 1.2% | $0.1136 |  |
| 11 | `WebFetch` | 3,515 | $70.15 | 0.9% | $0.0443 |  |
| 12 | `mcp__claude-design__write_files` | 218 | $70.13 | 0.9% | $0.3217 |  |
| 13 | `mcp__claude-design__read_file` | 415 | $65.42 | 0.8% | $0.2115 |  |
| 14 | `mcp__Claude_Browser__computer` | 1,171 | $60.27 | 0.7% | $0.0624 | 659 |
| 15 | `SendMessage` | 454 | $56.97 | 0.7% | $0.1439 |  |
| 16 | `mcp__claude-in-chrome__navigate` | 830 | $50.28 | 0.6% | $0.0630 |  |
| 17 | `WebSearch` | 1,757 | $48.38 | 0.6% | $0.0648 |  |
| 18 | `mcp__claude-in-chrome__browser_batch` | 443 | $48.00 | 0.6% | $0.1088 | 210 |
| 19 | `mcp__Claude_Browser__navigate` | 665 | $46.42 | 0.6% | $0.0737 |  |
| 20 | `Skill` | 269 | $37.38 | 0.5% | $0.1626 |  |

**Bash is 42% of the entire bill.** 37,286 calls in 31 days — 47% of all 80,116 tool calls — and its median
input is 325 characters. It is not expensive per call; it is expensive because every call buys another
full-context request. This confirms the 2026-08-17 finding ("Bash — entirely from call count") and
promotes it: in dollars, batching Bash is worth more than every context rule combined.

**4,882 images** were returned in tool results across the corpus:

| source | images |
|---|---:|
| `Read` | 2,118 |
| `mcp__Claude_Code_iOS_Simulator__control` | 1,129 |
| `mcp__claude-in-chrome__computer` | 738 |
| `mcp__Claude_Browser__computer` | 659 |
| `mcp__claude-in-chrome__browser_batch` | 210 |
| `mcp__computer-use__screenshot` | 17 |
| `mcp__computer-use__computer_batch` | 10 |
| `mcp__computer-use__zoom` | 1 |

`Read` is the largest single source of images at 2,118 — reading image files off disk into the main
context. That is a category the previous audits did not have on their screenshot list at all: they
counted simulator and browser captures and missed the biggest one.

## The cost curve against context size

Every request bucketed by its own context (`input + cache_read + cache_creation`) in 50k bands.

| context band | requests | avg $/request | total dollars | share of bill |
|---|---:|---:|---:|---:|
| 0k-50k | 10,527 | $0.0402 | $423.28 | 5.2% |
| 50k-100k | 19,005 | $0.0762 | $1,447.62 | 17.8% |
| 100k-150k | 16,287 | $0.1048 | $1,707.40 | 21.0% |
| 150k-200k | 10,889 | $0.1368 | $1,489.41 | 18.3% |
| 200k-250k | 7,105 | $0.1734 | $1,232.07 | 15.1% |
| 250k-300k | 3,410 | $0.2066 | $704.48 | 8.6% |
| 300k-350k | 1,952 | $0.2466 | $481.44 | 5.9% |
| 350k-400k | 844 | $0.2746 | $231.73 | 2.8% |
| 400k-450k | 628 | $0.3152 | $197.92 | 2.4% |
| 450k-500k | 425 | $0.3289 | $139.79 | 1.7% |
| 500k-550k | 124 | $0.4799 | $59.50 | 0.7% |
| 550k-600k | 33 | $0.4246 | $14.01 | 0.2% |
| 600k-650k | 52 | $0.3280 | $17.05 | 0.2% |

The curve is close to linear above 50k: **about +$0.035 per request for every +50k of context**, on a
50–100k baseline of $0.076. A request at 400k costs **4.1x** one at 75k. But note where the dollars
actually are: the 50–200k bands hold **57%** of the bill, because that is where the requests are.
Fat sessions are expensive per request; ordinary sessions are expensive in aggregate.

## The handoff threshold — the current rule is wrong, and it costs about $570 a month

### How the simulation works

Each main-thread session is replayed request by request. The real per-request growth in context is
preserved; only the *base* changes. When the simulated context would exceed the threshold, the session is
cut: a handoff is charged, and the context restarts at the measured fresh floor plus the measured size of
a handoff document. `input`, `cache_creation` and `output` are held at their measured values — the same
work gets done — and the `cache_read` of each request is recomputed as `simulated_context − input −
cache_creation`. Subagent spend ($3,394.33) is held constant, since subagent contexts die on their own.

**The simulation reproduces the measured main-thread bill exactly at threshold = never** ($4,751.39 vs $4,751.39 measured,
delta -0.0000%), which is the check that the counterfactual machinery is not inventing money.

### Measured constants, not assumed ones

| constant | value | how measured |
|---|---:|---|
| fresh-session floor | **72,641 tokens** (median) | first-request context of 261 main sessions with ≥3 requests; p25 64,796, p75 78,462, p90 82,009 |
| handoff document | **3,000 tokens** | 136 real `Write` calls to STATUS/HANDOFF/DECISIONS files; 108 distinct handoff events, median 9,637 chars across the file set ≈ 2,409 tokens, rounded up |
| handoff output | **4,072 tokens** | median output tokens of a handoff event |
| requests to compose a wrap-up | 3 at the cut context | assumed; measured median is 1.2 `Write` requests, 3 is deliberately pessimistic |

### The answer

| threshold | cuts over 31 days | main-thread dollars | whole bill | vs never |
|---|---:|---:|---:|---:|
| **100k** | 2,121 | $3,706.46 | $7,100.79 | -22.0% |
| **150k** | 656 | $3,685.12 | $7,079.45 | -22.4% |
| **200k** | 380 | $3,928.22 | $7,322.55 | -17.3% |
| **250k** | 197 | $4,180.31 | $7,574.64 | -12.0% |
| **300k** | 114 | $4,375.14 | $7,769.47 | -7.9% |
| **never** | 0 | $4,751.39 | $8,145.72 | +0.0% |

Finer sweep, main-thread dollars only:

| threshold | 80k | 100k | 120k | 140k | 160k | 180k | 200k | 240k | 300k | 400k |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| vs never | +21.5% | -22.0% | -24.1% | -23.1% | -21.3% | -19.6% | -17.3% | -12.9% | -7.9% | -3.4% |

**The optimum is 120k, not 250k.** Cutting at 120k would have cost $3,608.25 on the main thread against
$4,180.31 at 250k and $4,751.39 uncut — **-24.1% vs never, where the current 250k rule buys only -12.0%**.
The gap between the rule in force and the optimum is **$572.07 over 31 days**, about 7% of the whole bill.

The curve is flat-bottomed from **100k to 160k** (−21% to −24%), then degrades steadily. Below 100k it
collapses: at 80k the rule is **+21.5% worse than never**, because the floor is 72,641 tokens and cutting at
80k means restarting after a handful of requests — 11,790 cuts, pure thrashing. So the floor sets a hard
lower bound: **never put the threshold within ~30k of the fresh floor.**

Sensitivity, because the handoff cost is the softest input:

| scenario | best threshold | its saving | 250k's saving |
|---|---|---:|---:|
| baseline | 120k | -24.1% | -12.0% |
| handoff cost doubled (6 requests, 8,144 output, 6k doc) | 150k | -16.5% | -9.6% |
| floor 90k instead of 72,641 | 150k | -19.4% | -11.0% |

Under every scenario the optimum is **120–150k and 250k is 7–12 points worse than it**. The 2026-08-17
audit's own token-optimum arithmetic landed on "T ≈ 145–170k" and was then overridden to 250k on
ergonomic grounds — how many user messages of work fit before a clear. **The dollars say the override was
expensive.** The ergonomic argument is still real and this audit cannot price it; what it can say is that
the price of the override is 12% of the main-thread bill, and that a 150k threshold captures
almost all of the available saving (−23.1% at 140k) while being far less disruptive than 120k.

**Recommendation: move the threshold to 150k.** It is inside the flat bottom of the curve under all three
sensitivity scenarios, it is 1.9x the measured floor so it does not thrash, and it costs 782 cuts a month
rather than 1,129 at 120k.

## What else the data shows

### 1. Subagents are 42% of the bill and nobody has been looking at them

1,447 subagent runs, 41,960 requests, **$3,394.33**. The 2026-08-17 audit said flatly: "subagent spend is not in the
1 142M... zero sidechain records, so the child side lives elsewhere." It is not elsewhere. It is in
`isSidechain: true` records inside the root session files, and in `<session>/subagents/agent-*.jsonl`
files one level down. **Every previous number in this series was computed on 58% of the spend.**

Median run $1.15, mean $2.35, p90 $5.64, worst $116.53. Median subagent floor is **23,413 tokens** — less than half the
42,755 measured once in the 08-17 audit and less than a third of the 72,641 main-thread floor. Delegation is
cheap to start; it is expensive because it happens 1,447 times.

### 2. The 1-hour cache TTL costs $442.81 a month

40% of cache-write tokens are written at the 1-hour TTL, billed at 2x input instead of 1.25x. Had they
all been 5-minute writes the bill would have been **$442.81 lower (5.4% of everything)**. This is an upper
bound: a 5-minute TTL expires more often, and each expiry converts cheap cache reads back into full-price
writes. The break-even is two reads per write. It is still the largest single unexamined line in the
audit, and the 2026-08-03 audit's open question — "is the 1-hour TTL chosen by the harness or
configurable?" — is still open and is now worth $442.81.

### 3. Requests per user message is down to 9.9

2,973 user messages produced 29,321 main-thread requests — **9.9 per message**, against a median of 25 in the
2026-08-17 audit. Counting subagent requests too it is 24.0. **A user message costs $2.74 on average.**
This is the metric that improved most, and it is the one the previous audit called the biggest leak.

### 4. Fable 5 is a 2x-price model being used at scale

See the model table: 2.1% of requests, 6.1% of dollars. Whatever routes work to Fable should be
checked, because at $10/$50 per MTok it is the most expensive model on the price list, tied with Mythos.

### 5. The transcripts carry no cost field

There is **no `costUSD` anywhere in the corpus** — checked at record level and inside `message`, across
all 320,506 records. So there is no independent cross-check on the dollar figure; it is computed from
`message.usage` and the published price table. What *is* available and was used: `usage.cache_creation`
carries the exact `ephemeral_5m_input_tokens` / `ephemeral_1h_input_tokens` split on every single request
(0 mismatches against `cache_creation_input_tokens`), so the two write prices are applied exactly rather
than assumed. `service_tier` is `standard` and `speed` is `standard` on every request (no fast-mode
premium), `inference_geo` is `not_available` on every request (no 1.1x data-residency premium), and
`server_tool_use` records zero billable server-tool events (no $10/1,000 web searches).

## Method and assumptions

**Corpus.** All 1,848 `*.jsonl` under `~/.claude/projects` (2.5 GB, 23 project directories), 320,506
records, zero unparseable lines. Period `2026-07-26T00:00:00Z` → `2026-08-25T23:59:59Z` inclusive — 31
calendar days, filtered on the UTC `timestamp`. 71,281 of 74,053 all-time requests fall inside it.

**Three deduplication traps, all of which change the answer:**

1. *One API request is written as several JSONL rows.* 145,356 assistant rows collapse to **75,086 unique
   requests** keyed on `requestId` (falling back to `message.id`). Counting rows would have inflated
   requests and every token total by **94%**. The repeated rows carry the *same* usage, except for a
   handful that carry all-zero usage — so the rule is max-per-request, not first-per-request.
2. *Content blocks are spread across those rows.* Deduplicating rows before reading content loses tool
   calls (the 2026-08-03 audit measured 66% lost). Usage is deduplicated; `tool_use` blocks are collected
   from every row and deduplicated on their own block `id`.
3. *One session was written into two project directories.* Session `95613fdb` appears in full under both
   `Developer-ai-company` and `Finances-finapp` — 1,119 requests, 1.7% of all tokens, counted twice by any
   per-file sum. Deduplicated globally on `requestId`; the copy in the directory holding more of the
   session's requests is the one kept.

**Subagents.** Included. They live in two places: `isSidechain: true` records interleaved in the root
session file, and `<session-uuid>/subagents/agent-*.jsonl` (plus `subagents/workflows/wf_*/agent-*.jsonl`)
one and three levels down. Verified non-overlapping — no request id appears in both. Main-thread assistant
records never carry `agentId`, which is what makes the stream split reliable.

**Pricing.** `https://platform.claude.com/docs/en/about-claude/pricing`, fetched 2026-08-25. Opus 5 / 4.8 /
4.7 $5 / $6.25 / $10 / $0.50 / $25 per MTok (input / 5m write / 1h write / read / output); Sonnet 5
$2 / $2.50 / $4 / $0.20 / $10; Fable 5 $10 / $12.50 / $20 / $1 / $50; Haiku 4.5 $1 / $1.25 / $2 / $0.10 /
$5. **No model id in the transcripts needed a substituted price** — every one is in the published table.
`<synthetic>` is a harness artefact, not an API call, and is priced at zero (175 requests).

**The `claude-api` skill does not exist on this machine.** `~/.claude/skills/` holds 16 skills and none is
`claude-api`; there is no plugin or marketplace copy either. Prices were taken from the live documentation
instead. If that skill would have supplied different figures, every dollar here scales with it.

**Assumptions, stated plainly:**

- Cost is **API list price**. This is a Max subscription; the real marginal cost to the user is zero until
  a limit binds. Read this as "what this work is worth" and as a proportional measure of plan consumption,
  not as an invoice. The 2026-08-03 audit's caveat still stands: it is unknown whether Max meters cache
  reads at full weight.
- Tool attribution charges a request to the *previous* message's tool calls. A request that issues five
  tool calls and then costs money on the next turn splits that next cost five ways. This measures "what
  did calling this tool cost me", not "how big was this tool's output".
- Image counts are over the whole corpus, not period-filtered; the period is 96% of the corpus.
- The threshold simulation assumes the same work happens in the same number of requests with the same
  output after a cut. Real re-orientation cost after a clear is not measured and would shift the optimum
  upward — the `handoff cost doubled` row is the proxy for it, and it moves the optimum only to 150k.
- Peak context per session is the peak of its **main thread**.

**Scripts.** Copied to `/Users/slobodianiukoleksandr/Tasks/browser-token-economy/research/scripts/`. Run in
order: `schema.py` (schema discovery) → `load.py` (parse and stream-split) → `analyze2.py` (dedup, price,
period filter) → `report.py` (sections 1–7) → `handoff.py` (handoff constants) → `sim.py` (threshold
simulation) → `extras.py` (section 9) → `emit.py` (writes `spend-data.json`). Every number in this file
also exists machine-readable in `spend-data.json` next to it.

---

# Archived: TOKEN-AUDIT-2026-08-17.md

# Token audit 2026-08-17 — where the handoff threshold should actually sit

Follow-up to `TOKEN-AUDIT-2026-08-03.md`. That audit established *that* uncut sessions dominate
spend. This one measures *where* to cut, because he asked whether 200k is right or whether the
threshold should be 500k.

## Method

Every `~/.claude/projects/*/*.jsonl` (1.7 GB, 13 projects) parsed for per-request `message.usage`.
173 sessions with ≥3 requests. Context at a request = `input + cache_read + cache_creation`.
Everything normalised to one unit — "what this volume would cost as a fresh input token" — so the
four token classes are addable:

```
cost = input×1.0 + cache_read×0.1 + cache_creation×1.25 + output×5.0
```

`0.1` and `1.25` are the Anthropic cache read / 5-minute-write multipliers; `5.0` is Opus output at
5× its input price. Total measured: **1 142 M units**.

Script: `.claude/tasks/context-economics-measure.py`.

## Findings

| where the money goes | share |
|---|---|
| cache read — re-sending context already sent | **64%** |
| cache write — new material entering the context | 20% |
| output — actual generated text | 16% |

**Cost of one request, by context at the moment of that request** (pooled over all 37 000 requests):

| context | requests | cost/request | of which re-send |
|---|---|---|---|
| 50–100k | 5 119 | 20 200 | 7 600 |
| 100–150k | 8 219 | 21 200 | 12 200 |
| 150–200k | 7 848 | 26 200 | 17 000 |
| 200–250k | 5 810 | 32 700 | 21 800 |
| 250–300k | 3 813 | 38 000 | 26 900 |
| 300–400k | 4 572 | 46 300 | 33 400 |
| 400–500k | 1 536 | 64 500 | 43 000 |
| 500k+ | 140 | 93 700 | 47 700 |

Flat to ~130k, then roughly linear: **+7 000 per request for every +50k of context.**

Other measured constants:

- **Floor of a fresh session: 65k** (median first-request context; p25 62k, p75 70k, min 38k) —
  system prompt, CLAUDE.md chain, tool schemas. With status files read in, an effective start of
  ~90k. Over a 186-request session that floor alone is ~1.2 M units.
- **Requests per user message: median 25**, mean 36, p75 41, p90 71.
- **Requests per session: median 186**, p75 263, p90 349, max 4 302.
- **92% of all spend sits in sessions that passed 200k** — 101 sessions at 200–400k, 14 past 400k.
  Median context inside the most expensive sessions is 220–340k. The 200k rule was not being
  followed; the single worst session was 4 302 requests, 527k peak, 168 M units — 15% of everything.
- Sessions capped under 150k: **20 700** per request. Sessions past 400k: **39 300** for the same
  kind of work. 1.9×.

## Break-even and the optimum

Handoff cost ≈ 200k units: STATUS + DECISIONS + board (output at 5×), the 65k floor re-written
fresh in the new session, and the status files read back.

Clearing at 250k for a ~90k restart saves ≈18 000 per subsequent request → **break-even at 11
requests**, i.e. under half of one median user message.

Minimising `8k + 0.13×(F+T)/2 + H×g/(T−F)` (F = 90k floor, H = 200k handoff, g ≈ 1k context growth
per request) gives `T − F ≈ 55k`, so **T ≈ 145–170k**. Doubling the handoff-cost estimate to 400k
only moves it to 170k. 500k would cost ~1.7× per unit of work.

That is the *token* optimum, and it is not the answer, because it ignores how fast his context
actually fills. Measured: **floor 65k, +26k per user message** (p75 50k, p90 84k). So:

| threshold | avg context | cost/request | user messages of work before the clear |
|---|---|---|---|
| 160k | 125k | 27.1k | 3.7 |
| 200k | 145k | 28.7k | 5.2 |
| **250k** | 170k | **31.4k** | **7.1** |
| 300k | 195k | 34.3k | 9.0 |
| 350k | 220k | 37.4k | 11.0 |
| 400k | 245k | 40.5k | 12.9 |

160k buys 16% over 250k and costs a full wrap-up ritual every 3.7 messages. Past 250k it does start
to hurt: 350k is +19% per request, 400k is +29%.

**Decision: threshold 250k.** Exception: fewer than ~10 requests of work left in the whole task —
the handoff cannot pay for itself, finish instead. Message count is never the signal; requests are.
Below 250k the threshold is not the lever — the 26k per message is.

## Where the 26k per message comes from

"Carried cost" below = the token's size × 0.1 × the number of requests still to come in that
session. It is what a token actually costs, not what it looked like when it arrived.
Scripts: `.claude/tasks/m6.py` (results), `m7.py` (inputs and images).

| entering the main context | calls | size each | carried | share of all spend |
|---|---|---|---|---|
| **screenshots** (simulator, browser, computer-use) | 1 600 images | ~1 600 | 147M | **13%** |
| **Bash** — entirely from call count | 9 819 | 236 in / 81 out | 149M | **13%** |
| **Agent** — briefs out, reports back | 754 | 1 317 / 272 | 59M | 5% |
| **Read** — whole files | 1 288 | median 1 431, worst 13 925 | 54M | 5% |
| **Write** — the file body rides along | 986 | median 2 590; a board is 8–10k | 48M | 4% |
| **Edit** | 3 043 | 601 / 47 | 40M | 3% |
| **total tool traffic held in main contexts** | | | **530M** | **46%** |

That is the p90 message: ten screenshots (16k) + two whole files (5k) + one board written from the
main thread (10k) = 31k in a single turn, then re-sent on every request after it.

Rules written into `orchestrator.md` from this: screenshots never in the main thread (the verify
loop is a subagent that returns words; the finished image goes to him via `SendUserFile` by path);
Bash batched; long files authored by a subagent; `Read` with `offset`/`limit` or delegated.

## Bigger leaks than the threshold

1. **25 requests per user message.** It multiplies the 64%. Moving heavy reads and test runs into
   subagents whose context dies with them is worth more than any threshold change.
2. **The 65k floor**, paid at 6.5k on every single request forever. Trimming unused MCP tool schemas
   is a separate, unstarted task.
3. **The rule was ignored for two weeks.** Same failure mode as the status files before
   `status-guard.sh`: a threshold that fires only in prose loses to whatever is happening at 160k.
   A context-pressure hook is the fix, and it does not exist yet.

## Did two weeks of handoff discipline actually pay?

Unit of work = one `Edit`/`Write`. Median **across sessions**, not the weekly sum — otherwise one
monster session decides the answer.

| week | sessions | median cost per edit | median session peak |
|---|---|---|---|
| Jul 13 — before the discipline | 12 | 245k | 324k |
| Aug 3 | 50 | 256k | 286k |
| Aug 10 | 73 | 234k | 255k |
| Aug 17 | 5 | 220k | 218k |

**Correction, same day.** The median across sessions was the wrong statistic for the question
"did this pay?", because it deliberately discards the expensive sessions and those *were* most of
the bill. Measured on the aggregate — which is what the weekly limit sees:

| week | cost per edit, whole bill | same, worst session removed | requests per edit | median context per request | cost per request |
|---|---|---|---|---|---|
| Jul 13 — nothing in place | 456k | 281k | 11.9 | 238k | 38 437 |
| Aug 3 — the /compact era | 275k | 277k | 9.3 | 173k | 29 564 |
| Aug 10 — the handoff era | 252k | 253k | 8.9 | 170k | 28 222 |
| Aug 17 | 186k | 167k | 7.5 | 138k | 24 823 |

**2.4× cheaper per unit of work**, and 1.7× even with each week's worst session removed — so it is
not only that the monsters are gone, ordinary work got cheaper too. Requests per edit improved
independently, 11.9 → 7.5.

The three eras, dated from 38 compaction records in the transcripts: nothing until Jul 31 (this is
where the 4 302-request, 527k session lives) · `/compact` from Jul 31 to Aug 4, 37 calls in five
days, 16 of them on Jul 31 alone · handoffs and status files from Aug 4, with `/compact` never
called again. The switch is dated exactly to when "compact is the wrong tool" entered the kit.
`/compact` was much better than nothing (456k → 275k); handoffs are better than `/compact`
(275k → 252k → 186k). The order is right and nothing here should be reverted.

**On the per-session median: ~10%.** Session peaks fell by a third, but the saving was eaten by the
floor growing 60k → 74k over the same month and by the 46% tool traffic being untouched. Commits
cross-check: week 29 was 100 commits for 273M, week 33 was 187 for 450M — −12% per commit.

The payoff is in the tail, where an average cannot see it. Worst single session as a share of its
whole week:

| week | worst session | its requests | its peak | share of the week |
|---|---|---|---|---|
| Jul 13 | 168.0M | 4 302 | 527k | **61%** |
| Jul 27 | 45.7M | 1 282 | 458k | **92%** |
| Aug 3 | 16.8M | 416 | 456k | 5% |
| Aug 10 | 15.9M | 449 | 485k | 4% |

Before the discipline one session ate two thirds to nine tenths of a week. After it the worst is
four percent. The handoff ritual is insurance against the catastrophic session, not an efficiency
win — and it is worth keeping on exactly that basis.

## Screenshots cannot be dropped from a context

Asked 2026-08-17 whether an image could be summarised to text and then deleted. It cannot: a
context is append-only, and rewriting the prefix invalidates the cache, so everything after the
deletion point would be re-sent at full price — more than leaving the image in place.

The instinct is right about the *place*, though: a subagent takes the screenshots, looks, clicks,
looks again, and returns words. The images die with its context. Break-even:

| case | cheaper | why |
|---|---|---|
| one image, session nearly over | inline | 1 600 × 0.1 × 20 = 3k, under a subagent's own floor |
| one image, early in a session | about even | 1 600 × 0.1 × 150 = 24k vs that floor |
| a loop of three or more | subagent, by several times | ten images with 100 requests left = 160k |

Writing the description costs ~100 output tokens = 500 units, i.e. nothing, so the worry that
narrating the image would cost more than keeping it does not hold.

Caveat on every delegation number here: **subagent spend is not in the 1 142M.** 754 `Agent` calls
appear in these transcripts and zero sidechain records, so the child side lives elsewhere. What is
measured is the saving to the main context; the subagent's own bill is real and unquantified.

## The threshold now fires by itself

`hooks/context-guard.sh`, registered by `install.sh` on `UserPromptSubmit` and `PostToolUse`.
220k soft band (said once), 250k hard band (repeats). PostToolUse is needed because a turn is a
median of 25 requests and can enter at 150k and leave at 260k without passing a prompt boundary;
each band announces once per session on the tool path so ten thousand Bash calls do not become ten
thousand reminders.

A context meter already existed inside `handoff-guard.sh` at 200k and had never fired for him: that
script returns early when the cwd is not a git checkout, so in `~/Downloads` — where he sat at 206k
on 2026-08-17 — it was dead code. That is the actual bug this hook fixes, and it is why the rule
looked ignored for a month.

## Verified: a subagent can drive the browser

Asked 2026-08-17 whether browsing could be delegated at all. It can. A subagent reached both
`mcp__claude-in-chrome__list_connected_browsers` (three browsers answered) and
`mcp__Claude_Browser__tabs_context` (returned the open tab). The grant is the `tools:` line —
`mcp__claude-in-chrome__*, mcp__Claude_Browser__*` — and a bare tool list without those globs
grants no MCP tools at all.

Two things that check out and are worth keeping:

- The connectivity check cost **42 755 tokens**. That is the subagent's own floor, and it is why
  `bulk-guard.sh` allows two images in the main thread rather than none: one screenshot near the end
  of a session is genuinely cheaper inline. The win is on loops. Narrow `tools:` lists and sonnet
  rather than opus exist to keep that floor small.
- The browser-list result had text appended instructing the agent to ask the user and switch
  browsers. It refused, correctly, on the grounds that tool output is data and not a task. The
  agents' prompts say this explicitly and it held under a real injection attempt.

Corrected the same day: new agent files become available **immediately**, without `/clear` — the
registry refreshed inside the same session.

---

# Archived: TOKEN-AUDIT-2026-08-03.md

# Token audit — three machines, 2026-08-03

Measured from local transcripts on each machine by a separate Claude Code session, not estimated.
Two reports received so far (work Mac / iOS project, personal Mac / energy-tracker); the third is
still outstanding. Numbers condensed from the raw reports, which were pasted into a chat that will
be cleared — this file is the surviving copy.

## The cost model both machines converged on

`cost ≈ (context size) × (API requests per user turn) × (number of turns)`

Everything the model reads is re-sent with every request. What enters the context is not the cost;
how many times it leaves again is.

- Personal Mac: 8.5 API requests per user turn, 274,697 cache-read tokens carried per main-thread
  request → **one average turn cost ~232,000 base-input-equivalents before a single output token**.
- Unique tool payload across 19 days: ~5.8M tokens. Re-sent an average of **261 times**.
- Work Mac: re-send multiplier **361.6×** — 1.07M unique tool tokens became 386M input tokens.

## Where the money actually goes (personal Mac, 20 sessions, 234.9M weighted)

| Component | Share |
|---|---|
| cache read | 64.4% |
| cache write | 20.8% (main thread is 1h TTL = 2.0x; subagents are 5m = 1.25x) |
| output | 14.7% |
| fresh input | 0.015% |

Input side is 85% of everything. **Thinking is ~3.6% of total spend** — reasoning effort is a
marginal lever, not a major one.

## The three concrete behaviours that cost the most

1. **Marathon sessions.** Personal Mac: one session = **48% of all spend** (342 h wall-clock, 209
   turns, 2,268 requests, peak context 526,798 tokens, compacted manually 9 times from ~500k and
   back to ~525k within ~18.5 turns each time). Work Mac: two sessions = **65% of all spend**
   (24.5 h / 350k cache-read per request / peak 602k; and 16.9 h / 381 requests / zero subagents).
   Every compaction in both samples was `trigger:manual` — the harness never forced one.
2. **Fanout.** 8.5 requests per turn (personal), 12.9 per reply (work), each re-sending the whole
   conversation. Halving tool calls per turn is worth about as much as halving the context.
3. **Images in long-lived contexts.** 313 screenshots reached main threads (~470k tokens). A
   screenshot taken at turn 20 of a 200-turn session is re-sent on every request after it. The iOS
   Simulator tool was the worst density measured: 545 calls, 230 images, 68 characters of text each.

## What is already efficient — do not "optimize" it

- **Subagents compress 35.7× (work Mac) / to 1.7% of input bytes (personal Mac).** They absorbed
  81% of all tool bytes and returned 278k chars. But they are 40% of weighted spend and 51.7% of
  requests, because each subagent request itself averages 116.5k cache-read tokens. On the personal
  Mac the lever is **narrower briefs**, not more delegation; on the work Mac 16 of 20 sessions used
  **no subagents at all**, so there the lever is delegating in the first place.
- Build and lint output is already filtered: 401 `xcodebuild` calls = 434k chars total (~1.1k each);
  no Bash result anywhere exceeded 50k chars.
- Repeat reads inside one context window: 0.1% of spend.
- **Static config — `CLAUDE.md`, output style, memory — is ~1–2% of total spend.** Both machines
  measured this independently. Real and permanent, but small next to session discipline.

## Ranked levers

| # | Action | Saving | Whose |
|---|---|---|---|
| 1 | Cap context at ~150k and end the session with a handoff file + `/clear`, never `/compact` from 500k | 15–30% | rule |
| 2 | Fewer API calls per turn: batch independent tool calls, one script instead of five commands | 10–15% | habit |
| 3 | Screenshots and visual verification only inside a subagent, returning a text verdict | 5–10% | rule |
| 4 | Narrower subagent briefs — exact file lists, no re-reading the same spec | ~5% | rule |
| 5 | Turn off unused connectors and plugins (~9k tokens of prefix on every request) | 5–7% | **user, in app settings** |
| 6 | Static overhead: output style and `CLAUDE.md` slimming | ~1–2% | done / in progress |
| 7 | Lower reasoning effort on mechanical turns | 1–2% | habit |

Levers 1–3 hit the same 65%, so they do not add up.

Why 1 is first: the habit of compacting at "50% of context" is calibrated against a 1M window, so
50% means ~500k carried on each of 8.5 requests per turn. `/compact` also costs a full-context
request to produce its summary, and the context then regrows to the same place within ~18 turns.

## The honest caveat

All of this measures **tokens weighted by published API price ratios**. That is a proxy for
plan-limit consumption, not a measurement of it: transcripts carry no limit, quota or cost field,
and `~/.claude/telemetry/` held only failed-upload records. It is unknown whether a Max
subscription meters cache reads at full weight, at a discount, or at all — if at full weight,
re-sent context dominates even harder than 64% suggests.

At the last snapshot the limits were **not binding**: 5-hour window 19%, weekly all-models 5%,
weekly Fable 0%, on Max 20x. An earlier "weekly 96%" screenshot was taken at the very end of a
weekly window and is not representative. So this is about headroom and speed, not a wall.

## Open questions worth settling

- How does Max meter the 5-hour and weekly windows — raw tokens, price-weighted tokens, or
  requests? The answer re-ranks everything above.
- Is the 1-hour cache TTL on main threads chosen by the harness or configurable? At 2.0x it is 25%
  of weighted cost; a 5-minute TTL would halve that for fast-turnaround sessions and cost more for
  sessions with long pauses.
- Does a subagent inherit any part of the parent context, or only its prompt? The measured 116.5k
  cache-read per subagent request suggests they grow their own contexts rather than inherit, but
  that was inferred, not confirmed.

## Third machine (this one, iOS project) — disputes four of the priors

Sample: 3,155 requests, 61 user turns, 76.7M weighted. It found two schema traps the other two
missed, so its method is the most trustworthy of the three:

- Subagent transcripts live at `<sessionId>/subagents/**/agent-*.jsonl`; globbing only the root
  loses **51% of requests and 33.7% of spend**.
- Rows sharing one `message.id` carry *different* content blocks — "dedup by id, keep the first"
  loses **66% of tool calls**.

Its numbers: input 80.7% / cache read 56.7% (not 85 / 64) · output 19.3% (not 15) · thinking 31.4%
of output, but the largest single output category is **tool-call arguments at 55.6%** · unique
payload 2.76M tokens re-sent **35.7×, not 261×** — it states 261× is arithmetically impossible on
its data. Treat 261× as unreliable.

Its headline differs too: **the driver is requests per turn, not context size — 51.7 API calls per
user turn**, and three sessions = 53.5% of spend from 12 turns (one made 176 requests over 2 turns,
never compacted, peak 412k).

Its ranked levers: compact at ~150k instead of running to 412k (10–16%) · fewer, wider subagent
briefs — 83 launches cost 2.3M tokens of prefix alone (5–7%) · static: style 26.6→17.1 KB, disable
2 plugins with `usageCount: 0` and 7 unused connectors (3.3%) · trim `git`/`grep`/`cat` output at
the call site (1.5–2%) · `AGENTS.md` routing table instead of 4 unconditional "You must read" over
26 KB of docs (~1%) · `Read` with `offset`/`limit` instead of `cat`/`sed` dumps (0.5–1%).

It explicitly leaves alone: build and lint, **screenshots (0.1% despite 21 MB of base64)**, repeat
reads, the amount of delegation (34.4× compression), cache TTL, visible answer length, model tiers.

### What survives all three reports

1. Long sessions that are never cut are the top lever. 48% / 65% / 53.5% of spend on one to three
   sessions each.
2. Static config — style, `CLAUDE.md`, memory — is **1–3%**. Real, permanent, small.
3. Requests per user turn matter as much as context size (8.5 / 12.9 / 51.7 measured).
4. Delegation compresses 34–36×; the argument is over brief width, not over whether to delegate.
5. Thinking is a minor lever (3.6% of total on one machine).

Screenshots are disputed: machine 2 ranked them 5–10%, machine 3 measured 0.1%. **Not a rule.**

## Context window

Peaks of 526,798 and 412,000 tokens were measured, so the window on those sessions was far above
200k. The "150k cap" is therefore a **cost** rule, not a capacity rule.

## Collision to resolve before anything is committed

The work Mac's session slimmed **the same file** we are slimming here — it reports
`output-styles/orchestrator.md` going 30,267 → 22,144 characters. The file at kit HEAD
(`5735aac`) is **19,423 characters**, so that machine started from a stale copy and has not pulled
`b34a9c6` / `09fd021`. Its diff must not be committed as-is. Resolution: pull there first, then
compare against `DRAFT-orchestrator-v3.md` (2,361 tokens vs the current 5,403) and keep one version.
