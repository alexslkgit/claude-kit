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
`PreToolUse Write|Edit` and on `Bash`, because a heredoc writing an html file bypasses `Write`
entirely; it fires in subagents as well as the main session, with `PAGE-GUARD-EXEMPT` as the
deliberate escape; `tools/strip-page-refresh.py` sweeps everything already on disk. First sweep:
4875 html files scanned across the home directory, 5 boards cleaned, 0 left. Minified bundles and
HTML comments are excluded, so a third-party library's own focus handling is not corrupted and the
comment that explains the ban is not deleted by the tool enforcing it.

**Cost of the earlier partial fix.** Four days of new pages, each reintroducing the bug, and a
second round of his time to report it.

**Dead end considered and rejected.** Rewriting `location.reload()` and `alert()` automatically
across all 4875 files. Both are legitimate when a human clicks a button, and 45 pages use them
that way, including his finance dashboards. The tool reports those and touches nothing.

## company-brief: the brief page is a dashboard, not a document — 2026-08-20

The first real brief (Out of the Box Systems) printed `не нашёл` five times in a row in the app
section, on a company that has no app at all, and rendered every value as a full-width table row.
He read it and named the defects: dead rows he has to skip, prose where a line would do, and no way
to get to the part he needs.

**Decided.**

1. **Missing data deletes its own row.** The filler still writes `не нашёл`; the page removes the
   row, then removes any section left empty, then rebuilds the top navigation from what survived.
   Hiding is the template's job, not the filler's, so a brief can never again be padded with
   absences.
2. **Sections collapse.** Only деньги, тезисы and вопросы open on load. A collapsed section shows a
   six-word `{{SUM_n}}` finding, so the whole brief is scannable without opening anything.
3. **The range and the floor live in a sticky header.** The one number he must never hunt for.
4. **Confidence is a one-character prefix** (`+`, `~`, `?`) turned into a pill by the page. The old
   way had the filler writing `<span class="tag ok">` by hand, which is both noisy in the source and
   easy to break.
5. **The template is fetched from GitHub raw on every run**, with the packaged copy as the fallback.
   Otherwise a layout fix has to be re-uploaded to claude.ai before Cowork sees it, and the two
   copies drift.

**Cost of not doing it earlier:** the template did not exist at all until today, so the first live
run drew its own layout minutes before an interview.

## 2 — Борд один и тот же для любой работы, вариант «Разворот» (2026-08-20)

**Решение.** Выбран вариант Б, «Разворот»: список задач слева, колонка справа с тем, что ждёт
его, прогрессом и решениями. Он выбрал его из трёх направлений, макет и требования лежат в
`.claude/handoffs/perfect-board.md` и `.claude/design/board/`.

**Почему это вообще понадобилось.** Борд рисовался заново в каждом диалоге и каждый раз по-своему.
Его слова: «я его сделал уже раз 10, каждый отдельный диалог его делает по-своему, и мне это не
нравится». Значит, вид борда должен быть шаблоном и жёсткой инструкцией, а не рекомендацией.

**Что зафиксировано вместе с видом.** Вложенность максимум три уровня. Процент считается по
листьям дерева и честно едет назад, когда работы добавилось. Красная плашка только при полной
блокировке, пока есть чем заняться, она жёлтая. На борд попадает только то, что физически может
сделать один он. Несколько задач в одном чате живут пунктами верхнего уровня, у каждого своя
шкала. Борд переживает `/clear` и не переписывается, когда менять нечего.

**Урок из этой же сессии, стоил доверия к странице.** Первый макет писал в шапке «7 из 33
закрыто», а сумма по разделам давала 5 из 12. Цифры в шапке обязаны быть посчитаны из дерева, а
не написаны рядом с ним.
