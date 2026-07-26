# Claude Code rules for <project>

Living document — update it when conventions shift; stale rules are worse than none. When it
conflicts with what you see in the codebase, trust the codebase and report the conflict.
Keep under ~200 lines: longer files measurably reduce adherence.

This file is **committed** — collaborators and other AI tools read it. Personal operating
policy (language, tone, model tiers) goes in the gitignored `CLAUDE.local.md` instead.

## Project at a glance

<stack, platforms, targets, deployment target, backend, notable third-party deps, who works
on this and how>

## Folder layout

<the tree that matters, and what each top-level folder is for>

## Where new files go, by type

<screen / view-model / business logic / service / model / test — one line each>

## Architecture baselines

<the rules that cannot be inferred from reading one file: layering, dependency injection,
what may talk to what>

## Invariants

<contracts that corrupt data or break users if violated: schema, key formats, migration
rules, feature flags that must not be flipped. Be explicit — this is the section that
prevents the expensive mistakes.>

## Working autonomously (orchestrated sessions)

- Close unknowns yourself before asking a human, in this source order: **repository & git
  history → documentation → design files → chat/tickets → the human.** Never ask what you
  can verify yourself.
- When a human decision is genuinely required, present concrete options, not an open question.
- Put reasoning, plans, dead ends and decision rationale in the work journal at
  `.claude/tasks/<task>.md` (gitignored) — not in commit messages or code comments.
- Do not commit to the main branch, touch secrets, or run release scripts without an
  explicit instruction.

## Build, test, lint

<exact commands, copy-pasteable, with the one simulator/target/device that actually exists>

## Code quality guardrails

<the project's non-negotiables: forbidden patterns, formatting, localization, error handling>

## Commit conventions

<who commits, what the hooks enforce, what is never bypassed>

## What Claude cannot do here

<the honest list: no device runs, no runtime logs, no preview canvas — so that assumptions
get stated instead of assumed>

## Anti-patterns to reject on sight

<the short list a reviewer would flag immediately>
