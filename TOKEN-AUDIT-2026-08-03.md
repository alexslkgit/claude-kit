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
