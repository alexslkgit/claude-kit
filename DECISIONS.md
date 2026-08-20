# Decisions — claude-kit

Append-only. Supersede by number, never rewrite an entry.

## 1 — A page this kit generates may never reload or focus itself (2026-08-20)

**Decision.** No page written for him carries `<meta http-equiv="refresh">`, `location.reload()`,
`window.focus()`, `autofocus`, `alert()`/`confirm()`, a `Notification` or a `window.open()`.
A page that must stay live re-fetches its own file in the background and swaps `document.body`.

**Why.** Any of those activates the Chrome window, and macOS answers by dragging his Space over
to the browser while he is working in another app. Measured 2026-08-16 on three boards: every
10 to 60 seconds, endlessly, until the tab was closed.

**Why it came back, which is the real lesson.** The 2026-08-16 fix was written into
`skills/board/SKILL.md` and `templates/board.html` and applied to roughly twenty existing pages.
It never reached the generators: `agents/page-writer-sonnet.md` instructed a meta refresh on
every board, `skills/chew/SKILL.md` carried one in its template, `skills/meeting-live/board/render.py`
printed one, and `README.md` documented it as the correct way. A skill file is read only when that
skill is invoked, so most pages were written by something that had never seen the rule. On
2026-08-20 he hit it again and asked for it to end for good: «надо было не 20 затронуть,
абсолютно все».

**What was done.** Those four sources fixed; `hooks/page-guard.sh` refuses the `Write` itself on
`PreToolUse Write|Edit`, in subagents as well as the main session, with `PAGE-GUARD-EXEMPT` as the
deliberate escape; `tools/strip-page-refresh.py` sweeps everything already on disk. First sweep:
4875 html files scanned across the home directory, 5 boards cleaned, 0 left. Minified bundles and
HTML comments are excluded, so a third-party library's own focus handling is not corrupted and the
comment that explains the ban is not deleted by the tool enforcing it.

**Cost of the earlier partial fix.** Four days of new pages, each reintroducing the bug, and a
second round of his time to report it.

**Dead end considered and rejected.** Rewriting `location.reload()` and `alert()` automatically
across all 4875 files. Both are legitimate when a human clicks a button, and 45 pages use them
that way, including his finance dashboards. The tool reports those and touches nothing.
