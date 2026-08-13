---
name: pr-review
description: Work a pull request's review comments — read them, judge which are correct, fix what should be fixed, and draft the replies. Use when the user points at a PR, says review comments came in, or asks to answer a reviewer. Reads via the gh CLI; never posts or merges without being asked.
allowed-tools: Read, Grep, Glob, Bash, Edit, Write, Skill
---

# Working a PR's review comments

## 1. Read the whole review

```bash
gh pr view <n> --json title,body,state,reviewDecision,files
gh pr view <n> --comments
gh api repos/{owner}/{repo}/pulls/<n>/comments --paginate
gh pr checks <n>
```

Inline comments live on a file and line, so fetch them from the API — `gh pr view` shows only
the conversation. Read the diff the comment refers to before forming an opinion about it.

## 2. Sort the comments before touching anything

- **Correct and worth fixing** — a real defect or a convention violation. Fix it.
- **Correct but out of scope** — real, but a separate change. Acknowledge, do not sneak it in.
- **Based on a misreading** — the reviewer missed a guard, a call site, or a repo convention.
  Explain, do not silently comply. Complying with a wrong review makes the code worse.
- **Preference** — their taste against yours, with nothing in the repo's rules deciding it.
  Default to their preference; it is cheaper than the argument.

State which bucket each comment is in, in the work journal. Never dismiss a comment silently.

## 3. Fix

Route the fixes through an implementer subagent, tier predicted from the risk: mechanical
corrections to `implementer-sonnet`, anything touching invariants, concurrency, persistence or
an architectural boundary to `implementer-opus`. Run the repo's build, tests and lint, and
report the real result.

## 4. Draft the replies

Use the `draft-message` skill's style rules — same bans, same brevity, same no em dashes. A
reply is one or two sentences:

- Fixed: what you changed, in a few words. No "Great catch!", no "Thanks for the review!".
- Disagreeing: the fact that decides it, with a file and line. Not an argument, a citation.
- Out of scope: say it is real, say where it will be handled.

## 5. Reply, but never resolve. The reviewer resolves their own comment.

⭐ Recorded 2026-08-13 from a reviewer on Azure DevOps PR 184254, in his own words: *"In the future
lets please leave the job of resolving the comment to the person who added it as this is the most
common practice."* Five threads had been answered and closed in one pass, four as `fixed` and one
as `byDesign`, which took the reviewer's own confirmation step away from him.

So: **post the reply and stop.** Leave the thread active. The person who raised it decides whether
the answer settles it, and closing it on their behalf ends a conversation they had not finished.
This holds even when the fix is obvious, even when every check is green, and even when the merge
policy says "Comments must be resolved". That policy is satisfied by the reviewer, not by the
author, and it is the thing that makes closing threads feel like the author's job.

The one exception is an explicit instruction in the current conversation to close them, and even
then say in one line that it cuts across the reviewer's stated preference.

## 6. Never do these unasked

- Post a comment or a review, resolve a thread, or approve.
- Push, force-push, rebase, or merge.
- Change the PR title, description, labels, or reviewers.

Show the drafts, the user posts them. When they explicitly ask you to post, post exactly what
was shown and nothing more.
