---
name: handoff
description: Write a complete continuation prompt so this conversation can be restarted in a fresh chat without losing anything. Use whenever the user says "архивируйся", "заархивируй контекст", "перенеси в новый чат", "handoff", "hand this over", or otherwise signals that this conversation has grown too expensive and should continue elsewhere. The output is a long self-contained briefing addressed to the next instance of yourself, never a summary for a human.
allowed-tools: Read, Grep, Glob, Bash
---

# Handoff: continuing this conversation in a fresh chat

The user is not asking for a summary. They are asking you to **write the system briefing for
your own successor**, who will wake up with zero memory and must carry on mid-stride without
asking them to repeat anything.

## The two rules that decide whether this works

**1. Completeness beats brevity, by a wide margin.** A handoff prompt of two thousand words is
cheap; one lost decision that gets relitigated in the new chat is not. Do not compress, do not
summarize away the reasoning, do not drop something because it "probably is not needed". The
only thing you may leave out is what is genuinely finished and can no longer influence
anything.

**2. It is addressed to you, not about you.** Write in the second person, as instructions:
"You are continuing…", "You write prompts for Claude Code; you do not run them yourself." The
successor must know what job it is doing before it knows what has been done. A briefing that
reads like a report leaves the next instance unsure of its own role, and it will default to
being a passive summarizer.

## Flush the durable files first — this is not optional

A handoff prompt is one artefact and it dies when that chat closes. The files outlive it, and the
successor reads them before it reads you. **Bring all three up to date before you write a single
line of the prompt**, then write the prompt from them:

1. **`STATUS.md`** — rewrite the state it gets wrong, do not append. Every claim carries its
   evidence: the command, the sha, the `file:line`, the date. If it says "1 commit ahead" and there
   are two, that is the kind of error that makes the successor act on a lie.
2. **`DECISIONS.md`** — append every decision and every dead end this conversation produced, with
   its reason and its cost. If you decided something and did not write it down, the next session
   will re-litigate it from scratch, which is exactly what a handoff is meant to prevent.
3. **The task progress page** — the self-refreshing HTML page the `task-progress` skill maintains,
   at `.claude/tasks/<task>.html`. This one is for the user, not for you: it is what he opens to
   re-orient in five minutes without asking anything. A stale page is worse than none, and a `/clear`
   is exactly the moment he will open it.

Then the prompt itself carries pointers to all three, not copies of them.

Where the files do not exist — a Cowork or Cloud session with no repository checkout, a machine
reached through the file bridge — say so in one line inside the handoff instead of inventing paths,
and put the state that would have gone into them into the prompt itself. Absence of the files is a
fact the successor needs; silence about them is not.

## Build it from evidence, not memory

Before writing, gather the facts rather than recalling them: read the task journal's `STATE`
block and its open questions, check `git log --oneline` and `git status` for what actually
landed, and re-read the user's own corrections in this conversation. Anything you assert in the
handoff should be something you just verified — the successor cannot tell a real fact from a
half-remembered one, and will act on both.

## What the prompt must contain

Every section below, in this order, omitting only what truly does not apply. Sections 1, 2, 10
and 11 are the ones that get forgotten, and each costs a whole confused exchange.

1. **Role and continuity.** Who the successor is and what job it continues. State the working
   arrangement explicitly — for example: "You are the orchestrator. You write prompts that the
   user pastes into Claude Code; you do not execute them yourself, and you keep doing exactly
   that after this handoff." Without this the new chat silently changes its own role.
2. **Language.** Say it plainly: which language to talk to the user in, and which language
   files, prompts, commits and notes are written in. This is the single most common failure —
   a handoff written in English produces a chat that answers the user in English.
3. **Who the user is** and the constraints that shape the work: role, timezone, plan and usage
   limits, which machines and which of them has what, how they want to be talked to (message
   length, no walls of text, options instead of open questions).
4. **The task.** The goal in terms of observable behaviour, the ticket key and URL, and how it
   is judged done.
5. **Current state.** What is finished, what is half-done and where exactly it stopped, what
   comes next. Name real files, branches and commits, not "the changes we made".
6. **Decisions and the reasons for them** — including the alternatives that were rejected and
   why. This is the most valuable and most frequently lost part: without the reasons, the new
   chat re-opens settled questions and the user has to argue them a second time.
7. **Dead ends.** What was tried and did not work, so it is not tried again.
8. **Established facts not to re-derive** — verified findings with their source (file and line,
   commit, doc URL). Mark anything uncertain as uncertain; a guess promoted to a fact by the
   handoff is worse than an open question.
9. **Open questions**, numbered, each with what would close it and who or what can close it.
10. **The trail of people and sources.** Everyone who was asked something and what came of it,
    in order, because a chain of referrals is impossible to reconstruct and expensive to
    repeat. For each: who was asked (by name and channel), what exactly they were asked, what
    they answered, and what that changed — including "they redirected us to someone else",
    which is the most common outcome and the one that vanishes in a summary. Mark each thread
    as answered, redirected, or still waiting. Do the same for non-human sources: which Figma
    frames, documents and tickets were actually opened and what each one settled or failed to
    settle, with links. The successor must be able to see the whole path from the original
    question to where it stands now, so it neither re-asks a colleague who already answered nor
    forgets the one who never did.
11. **Work in flight.** Anything that was set running elsewhere and has not come back yet: a
    prompt the user already pasted into Claude Code, a message awaiting a colleague's reply, a
    build or CI job. For each one state what was asked, what a good answer looks like, that the
    user will paste the result into the new chat, and how to judge it when it arrives. Instruct
    the successor to ask for it by name early rather than proceeding as if nothing is pending.
12. **Standing corrections about style and behaviour** the user made during this conversation —
    banned phrasings, formatting they dislike, tools they rejected and why. These live only in
    the conversation and die with it unless carried over.
13. **The immediate next action**, in one line, plus an explicit instruction not to restart the
    task, not to re-plan what is already planned, and not to ask the user anything the briefing
    already answers.
14. **Pointers**: the task journal path, key files, ticket and design URLs, the repository and
    branch.

## Form

- Output the whole thing inside **one fenced code block**, so it copies in a single gesture.
  Nothing outside it except one short line saying what to do with it.
- Write the briefing in **English** — it is a prompt, and it is two to four times cheaper than
  Cyrillic — while instructing the successor to reply to the user in their language.
- Use headings and lists. The successor reads it as a specification, so structure earns its
  space.
- Date it, and state which conversation it continues.
- Never end with an offer to help or a question. It is a briefing, not a message.

## After writing it

If the project has a task journal, fold the same facts into its `STATE` block and log, so the
handoff and the journal do not diverge. Anything durable that emerged — a rule about how to
work, a tier that was wrong for a class of task — belongs in the kit or in auto-memory, not
only in the handoff, because the handoff is consumed once and then discarded.

Tell the user in one sentence to paste it as the first message of the new chat, and remind them
to send anything still in flight into that chat when it comes back.
