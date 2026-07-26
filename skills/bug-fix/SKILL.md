---
name: bug-fix
description: The mandatory procedure for fixing any bug — reproduce it first, capture the evidence, fix the root cause, then re-run the exact same flow and prove the symptom is gone by comparing before and after. Use for every ticket, request or report that describes something broken, misbehaving, crashing, or not matching expected behaviour, however small it looks. Not optional and not skippable.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Skill
---

# Fixing a bug

**A bug is not fixed until it has been reproduced, fixed, and re-checked through the same flow
that exposed it.** These three phases are mandatory and ordered. Writing code before a
reproduction is the most expensive mistake available here: you cannot tell whether you fixed
the bug, fixed something else, or fixed nothing, and you may be "fixing" something that was
already fixed or never broken.

## Phase 0 — is this bug real, and still real?

Before touching anything, establish that there is something to fix. Bug tickets go stale.

- Read the ticket's **full comment history**. "Fixed in the last release", "cannot reproduce",
  "actually works as designed" are common and are usually buried below the fold.
- Search git history for a fix that already landed: `git log --oneline -S'<symbol>'`,
  `git log --grep='<ticket key>'`, and `git blame` on the suspect lines. A merged fix that
  never made it into the reporter's build looks exactly like an open bug.
- Note the version, branch and commit the report is against, and how far the current branch has
  moved since. A bug reported against a three-month-old build may already be gone.

If the evidence says it is already fixed, stop and report that with the commit that fixed it.
Do not "fix" it again.

## Phase 1 — reproduce it, before any code change

This phase has one exit condition: you have watched the bug happen, or you have a documented
reason why only a human can watch it happen.

1. **Extract the exact repro conditions** from the ticket: branch, build, environment, account,
   feature flags, config, device or simulator, locale, data state. Missing conditions are the
   usual reason a bug "cannot be reproduced" — find them, do not assume defaults.
2. **Write the steps down as a numbered list** in `.claude/state.md`, ending with the expected
   result and the actual result, stated separately and concretely. "It's broken" is not an
   actual result; "the ring shows 0 instead of 4 after logging the second habit" is.
3. **Reproduce it by the cheapest honest route**, in this order:
   - a failing unit or integration test that exercises the same path,
   - a script or command that drives the code directly,
   - running the app and following the steps.
4. **Capture the "before" evidence**: the failing test output, the log line, the wrong value,
   the screenshot. Quote it verbatim in your report. This is what the "after" gets compared
   against, so a paraphrase is not good enough.

**If you cannot reproduce it, do not fix it.** Report instead, with: every condition you tried,
what you observed instead, and concrete options — ask the reporter for the missing condition
(draft it with `draft-message`), close as stale with the commit that already fixed it, or
request the environment or account that is missing. Guessing at a fix for an unreproduced bug
is forbidden, because a fix that cannot be checked cannot be trusted.

**If reproduction physically requires the user** — a device build, a paid account, a
third-party sandbox, several people coordinating — say so immediately in one sentence, give
them the exact numbered steps and what to look for, and continue with everything that does not
depend on the answer. Do not stall the whole task waiting.

## Phase 2 — diagnose, then fix

- **Find the root cause, not the symptom.** State the mechanism explicitly: what value is wrong,
  where it becomes wrong, and why. If you cannot state it in one sentence, you have not found
  it yet — keep going, or escalate the investigation to a higher research tier.
- **Fix the cause.** Suppressing the symptom (a guard around the crash, a clamp on the bad
  value) is acceptable only as a deliberate, stated decision, never as an accident.
- **Add a regression test that fails against the unfixed code.** A test that passes either way
  is not coverage. Prove it: run it against the pre-fix behaviour — stash the fix, or assert
  the old value — and show that it goes red. State how you proved it.
- Route the change to the implementer tier the risk deserves: mechanical to
  `implementer-sonnet`, anything touching invariants, concurrency, persistence or an
  architectural boundary to `implementer-opus`.

## Phase 3 — prove it is gone, through the same flow

Re-running the tests is not enough. The bug was found through a specific flow, so that exact
flow is what must be re-checked.

1. **Repeat the numbered steps from Phase 1 verbatim** — same branch state, same config, same
   data, same steps, same order. A different route proves a different thing.
2. **Compare before and after side by side**, using the evidence captured in Phase 1:

   ```
   Steps: <the numbered repro>
   Before: <exact observed wrong behaviour, quoted>
   After:  <exact observed behaviour now, quoted>
   ```

3. **Confirm the regression test now passes**, and that the rest of the suite, the build and the
   lint still pass. Report real output; never soften a failure.
4. **Check you did not just move the bug**: the neighbouring cases, the opposite path, and the
   edge the fix touches. A fix that breaks an adjacent case is not a fix.

Only with all of that in hand is the bug closed. If any of it is missing, say plainly what is
missing rather than reporting success — an unverified fix reported as done is worse than an
open bug, because it stops anyone else from looking.

## When the user must do the final check

If the flow can only be exercised by hand — on a device, in a real account, against a live
service — do everything else in full, then hand over one short block: the numbered steps, what
was wrong before, and exactly what to look for now. Mark the bug as **fix implemented,
verification pending**, never as closed, until they confirm.
