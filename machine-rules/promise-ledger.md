# Log every ask before working it

Applies everywhere, on every machine, to every message that contains a request. The
`promise-guard` hook reads this back on his behalf — see the header of
`hooks/promise-guard.sh` for why prose alone lost this fight before.

## The rule

The FIRST action on any message that contains a request is to append its asks to the
ledger, one line per ask, before starting the work:

```bash
promise-guard.sh add "$SESSION_ID" "<ask 1>" "<ask 2>" "<ask 3>"
```

A dictated message often carries several asks in one breath. Each one gets its own line,
in one call — that is what the batch form is for. Do this before the first tool call that
does the actual work, not after.

When an ask is finished, or he explicitly cancels it, close its line in the same batched
way, never by leaving it to be inferred later:

```bash
promise-guard.sh set "$SESSION_ID" 2:done
promise-guard.sh set "$SESSION_ID" 3:dropped:"he said skip it, the vendor cancelled"
```

**A new message adds to what is already owed; it never replaces it.** Only an explicit
cancellation in his own words closes a line early, and it is closed with the reason he gave,
not a guess at one.

This hook can only enforce what was written down. If a line was never logged, the ledger
has nothing to show and nothing to block on — the writing is the part that must never be
skipped, on every machine, on every message.
