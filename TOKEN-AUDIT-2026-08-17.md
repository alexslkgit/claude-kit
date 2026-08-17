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
