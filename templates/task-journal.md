# <TASK-ID> — <one-line title>

<!--
One task, one file, one chat. Lives at .claude/tasks/<task>.md, gitignored.
Never shared with another task: a new ticket gets a new chat and a new file.
English only. The user does not read this; it exists so the chat can stay short and so a long
session can recover what it already decided without re-deriving it.
-->

## STATE

<!-- The only block that is REWRITTEN rather than appended, and the only one normally read
     back. Keep it under ~15 lines so re-reading it is cheap. Update it whenever an answer
     changes, not at the end. -->

- **Status:** research | blocked | implementing | verifying | done
- **Goal:** <observable behaviour the ticket asks for, one sentence>
- **Next step:** <the single next action>
- **Blocked on:** <what, and who or what would unblock it — or NONE>
- **Decided:** <standing decisions a later step must respect, one line each>

---

## Open questions

<!-- Numbered, written down before going looking for answers. Each carries what would close it,
     and gets its answer plus the source appended once closed. -->

1. <question> — closed by: <source> — **answer:** <…, from path/file.swift:42>

## Log

<!-- Append-only, newest at the bottom. Findings, dead ends, and above all the reasons behind
     decisions — those are what cannot be recovered from the diff later. -->

### <YYYY-MM-DD HH:MM> — <what happened>

- <finding, with its evidence>
- <dead end: what was tried, why it failed, so it is not tried twice>
- <decision, and why it was taken over the alternative>
