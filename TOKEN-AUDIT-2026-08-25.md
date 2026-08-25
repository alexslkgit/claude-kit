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
