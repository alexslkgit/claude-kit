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

## company-brief: six blocks, and a fit block he decides from — 2026-08-20

Second pass over the same page, from his review of the Obox brief.

1. **In-page anchors are banned in this template.** The nav chips were `<a href="#s1">`. Rendered
   inside the app's sandboxed viewer, that turned into an "open external link" prompt to
   claudeusercontent.com and a blank page. They are `<button>` plus `scrollIntoView` now.
2. **Eleven collapsed sections is a scroll, not a dashboard.** The ten research sections now group
   into six page blocks: подходит-ли-тебе (fit + culture), компания (2+3), проект и приложение
   (4+5), деньги, на звонок (9+8+10), трекер и источники (1 + sources, last).
3. **New first block: "Подходит ли тебе"** — за/против against his standing criteria, with the
   criteria written into the skill so they stop being re-derived. The one he supplied and that was
   missing entirely: **outstaff is usually a plus, because the real employer is the client, and the
   client can be large.** The size of the consultancy is the secondary number.
4. **Theme is switchable by hand**, three states: auto, light, dark. `prefers-color-scheme` alone
   was not enough — he asked to be able to force either.

**Cost of not doing it earlier:** he read the first brief on a phone, tapped the first chip, and
landed on a blank external page.

## Один вид борда на все задачи — 2026-08-20

Борд выглядел по-разному в каждой сессии: «я его сделал уже раз 10, каждый отдельный диалог его
делает по-своему». Из трёх нарисованных направлений он выбрал «Разворот» и дал список правок.

1. **Шаблон и макет собираются из одного файла.** `templates/board.html` — источник; артборды
   канваса генерируются из него скриптом, подменяя только палитру. Разъехаться они не могут,
   поэтому «в макете красиво, в жизни иначе» больше не случится.
2. **Кольцо прогресса заменено на линию** сверху во всю ширину. Его слова: круговая диаграмма не
   настолько комфортна для просмотра, как линия.
3. **Процент считается по листьям дерева** и обязан честно ехать назад при добавлении работы.
   Числа в шапке должны сходиться с суммой по разделам — прошлый макет на этом и погорел.
4. **Один чат — один борд, задач может быть несколько.** Каждая задача это пункт верхнего уровня
   со своей шкалой прямо в строке, общая шкала сверху остаётся.
5. **Ровно одна стрелка «сейчас здесь» на весь борд** — лист, внутри которого я нахожусь в эту
   секунду. Две стрелки или ни одной, и ему приходится читать страницу целиком.
6. **Слова «Оглавление» на борде нет.** Роль заголовка списка играет суть задачи наверху.
7. **Тема переключается вручную, три состояния: авто, светлая, тёмная.** Он просил «обе темы»;
   одного `prefers-color-scheme` ему уже не хватило на странице company-brief (запись выше, п. 4),
   поэтому здесь сразу и авто, и принудительный выбор, сохранённый в `localStorage`.
8. **Правило «нечего менять — не переписывать»** записано в скилл: борд, переписанный ради
   отметки времени, жжёт токены и не говорит ему ничего.
9. **Скилл `board` переписан из советов в жёсткую структуру** — части страницы по порядку,
   что в них можно и чего нельзя. Советы позволяли каждой сессии рисовать своё, это и была
   причина проблемы.

**Тупик:** прочитать опубликованный канвас через `WebFetch` стоит около 30k токенов — голова
страницы это код редактора. Сверять правки нужно по рабочим файлам в
`.claude/design/board/`, а не по опубликованной странице.

## company-brief: his page, not a report — 2026-08-20 (third pass)

From his review of the second version. Every item below is his wording turned into a rule.

1. **Collapsed by default, all of it.** He opens what he wants. The chip row is deleted entirely —
   tapping a chip scrolled the page and he disliked it. One `развернуть всё` control remains.
2. **Lines are strikeable.** Tap a pro, a con, a question or a thesis he disagrees with: it greys
   out, strikes through and moves to the bottom of its own list, and the choice survives a reload
   via localStorage. His edit of the brief has to outlive the brief.
3. **A stage bar, but only when a process is running.** `{{STAGES}}` left as `не нашёл` on a first
   contact removes the block. Note: the block must NOT carry the `.opt` class — the empty-row sweep
   runs before the bar is built and would delete it every time.
4. **Fit score, 0–100.** He asked whether it was worth the tokens; it is one number and one
   sentence, and it is the thing he reads first.
5. **Field priority is his, not the abstraction's.** Where the engineers are, where management is,
   timezone, headcount and registration are first class and live in an always-visible block. Growth
   is second, revenue second-to-third, funding fourth. The App Store link is the first row of the
   project block, not a line inside it. Team size and seniority mix are first class.
6. **Deleted from the page for good:** «чего не говорить», the banned-word list, and any reminder
   about his legend or parallel work. He knows; printing it back is noise. It stays as a constraint
   on how the brief is written.
7. **No scripts to read aloud.** Theses are one line each and the English wording sits in a nested
   collapsed block. Questions must be specific to the company — generic ones are cut, not shortened.
8. **Earlier call transcripts are a research source** (`~/Developer/meeting-listener/live/*.txt`),
   because he already asks about team size and seniority on the first call.
9. `Тир` carries a hover explanation. He asked what it meant, which means the page never said.

## Борд: сворачивание, ссылки, блок дейлика — 2026-08-20, второй заход

1. **Вложенные списки сворачиваются**, нативный `details`/`summary`, у каждого стабильный `id`.
   Состояние открыт-закрыт лежит в `localStorage` и восстанавливается после фонового обновления,
   иначе каждые 15 секунд его сворачивание сбрасывалось бы. Готовые задачи пишутся закрытыми,
   идущие открытыми, ветка со стрелкой «сейчас здесь» всегда открыта.
2. **Любое название на борде — ссылка.** Ключ тикета, номер пулл-реквеста, тред в чате, сборка,
   страница. Голая цифра стоит ему поиска, ссылка стоит клика. Правило записано в скилл.
3. **Необязательный блок `section.daily`** под двумя колонками: «С прошлого дейлика» со списком
   изменений и источником (PR, JIRA, SLACK) у каждой строки, и «Что сказать на дейлике» ровно в
   три строки. Он приходит в чат за десять минут до дейлика и просит свежие данные; подагенты
   читают чат, трекер и пулл-реквесты, ответ ложится сюда. Где трекера и чата нет, блок удаляется
   целиком, выдумывать в него содержимое запрещено.
4. **Соседним живым сессиям отправлена одна строка** про новый шаблон вместо объяснения: они
   работают в том же чекауте и рисуют борды по старому скиллу.

## company-brief: дизайн по системе колоды — 2026-08-20, четвёртый заход

1. **Отдельную дизайн-систему не заказывали.** Утверждённая система уже нарисована в Claude Design
   в проекте «Колода — направления» и принята им в соседнем диалоге: Golos Text для интерфейса,
   Source Serif 4 для длинной прозы, тёплая бумага `#F5F3F0` / `#17181B`, терракотовый акцент
   `#A25A34` в светлой и `#D9A66B` в тёмной, радиусы 22 у карточек и 999 у пилюль. Бриф взял её
   целиком. Просить нарисовать вторую значило бы получить два разных стиля на два продукта, а он
   просил один.
2. **Копию брифа в Claude Design не заводили.** Артборд с тем же содержимым разошёлся бы с
   `brief-template.html` на первой же правке, и он правил бы не ту страницу, которую отдаёт скилл.
   Источник правды один — шаблон в ките.
3. **Зелёный и красный введены как два приглушённых оттенка той же тёплой семьи**
   (`#4C6B3E` / `#9B3E2E` в светлой, `#A9C48E` / `#E09B89` в тёмной). В палитре колоды их нет, но
   «за», «против» и красный флаг без цветовой разницы не читаются.
4. **Три пилюли достоверности перевязаны на словарь колоды:** «подтверждено» — акцентная плашка,
   «правдоподобно» — нейтральная заливка, «догадка» — только волосяной контур. Разница теперь в
   весе, а не в трёх разных цветах.
5. **Вердикт обёрнут в `div.lead`.** Токен `{{VERDICT_10SEC}}` часто приходит голым текстом, а
   текстовый узел шрифтом не покрасить: вердикт набирался интерфейсным шрифтом, а соседний абзац
   сербским. Обёртка чинит это, не трогая ни один из 88 токенов.
6. **Шапка получила тот же градиент, что и страница,** `background-attachment: fixed`. Без этого в
   тёмной теме липкая шапка шла отдельной плашкой поверх градиента.
