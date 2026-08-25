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

## company-brief: одна копия скилла вместо трёх — 2026-08-20, пятый заход

1. **Копия в аккаунте claude.ai отставала на 189 строк** (251 против 440) и не имела файла шаблона
   вовсе. В чатах приложения скилл собирал бриф по старым инструкциям и рисовал страницу на глаз.
   Найдено при проверке, а не по жалобе, поэтому неизвестно, сколько брифов так и собралось.
2. **Старая копия удалена, новая загружена зипом** через claude.ai → Customize → Skills. Новый id
   `skill_01Sg2MfGmCrPQNLgqdCjVJ4u`, старый `skill_01CMD9tgqSURverwNBteqArE` больше не существует.
   Текст старой копии сохранён в `archive/company-brief-account-SKILL-2026-08-20.md` на случай, если
   в ней окажется что-то, чего нет в ките.
3. **Каждая копия теперь сама тянет свежую версию.** В начале `SKILL.md` стоит раздел «Take the
   current version first»: любой прогон сначала берёт текущий `SKILL.md` по raw с гитхаба и следует
   ему, если тот отличается. Копий будет много всегда — кит, аккаунт, другие маки, — поэтому чинить
   надо не копии, а их поведение.
4. **Файл шаблона в аккаунт может не доехать, и это не важно.** Шаблон и так тянется по raw на
   каждом прогоне, зип с `assets/` загружен на всякий случай.
5. **Дубль имени в Claude Code безвреден.** В сессии видны и `company-brief` из `~/.claude/skills`,
   и `anthropic-skills:company-brief` из аккаунта. Теперь это один и тот же текст, и оба ведут к
   одному источнику правды.

## Оболочка HTML вынесена из шаблонов — 2026-08-21

1. **Оформление лежит рядом со страницей, в `_shell/`, и подключается относительным путём.**
   Рассматривались три варианта: относительный путь до копии, абсолютный путь до `~/.claude`,
   симлинк при установке. Выбран первый, потому что страница обязана открываться как `file://`
   без сервера: абсолютный путь ломается на второй машине (другой юзернейм и другой клон),
   симлинк не переживает копирования или зипа папки задачи и не доезжает в облачные сессии.
   Копия занимает 12 КБ на задачу один раз и не растёт. Тот же довод уже записан в `chew`.
2. **`board-shell/` — отдельное дерево, зеркало `plan-shell/`.** Новый паттерн не выдумывался:
   `plan-shell` был сделан правильно, борд приведён к нему. Оба кладутся в один `_shell/` рядом
   со страницами, имена файлов не конфликтуют.
3. **Бриф о компании разобран тоже, хотя пишется один раз за прогон.** Иначе у хука появляется
   список исключений, а исключение — это дыра, через которую оформление возвращается. Портативность
   брифа (почта, артефакт Cowork) закрыта инструментом `tools/inline-shell.py`: он склеивает
   страницу обратно в один файл по требованию, и склейка помечается `SHELL-GUARD-EXEMPT`.
4. **Рендерер `meeting-live` не тронут.** Его CSS живёт строкой в `board/render.py`: страницу
   пишет скрипт, а не агент, поэтому в контекст эти байты не попадают ни разу. Разбирать нечего.
5. **Из триггеров перезаписи борда убран «сабагент ушёл и вернулся».** При шести фоновых агентах
   это двенадцать перезаписей, из которых пользователь не узнаёт ничего нового. Остальные триггеры
   (смена стадии, решение, блокер, ожидание, длинная пауза, конец) остались.
6. **Хук `hooks/shell-guard.sh` — 500 байт на инлайновый блок.** Пять строк правки инлайном не
   оболочка; 9,5 КБ — оболочка. `<script type="application/json">` и родственные типы не считаются
   вовсе: это данные страницы, ровно то, ради чего всё делалось. Хук работает в двух режимах:
   `--check` проходит по шаблонам кита (годится для CI и pre-commit), как PreToolUse он ловит
   `Write`, `Edit` и запись HTML из `Bash`, то есть срабатывает и внутри сабагентов.
7. **`agents/page-writer-sonnet.md` был прямым источником регресса.** В нём стояло «Self-contained
   HTML: inline the CSS» — агент, который пишет борды, получал инструкцию, противоположную правилу
   из скилла. Та же строчка нашлась в `templates/status-file-bootstrap.md`. Обе переписаны.
8. **Замер после разбора:** `templates/board.html` 19 182 → 6 511 байт (тело 5 881), шаблон брифа
   26 007 → 9 052. Рендер `file://` до и после совпадает попиксельно (одинаковый md5 скриншота
   headless Chrome), без `_shell/` рядом — не совпадает, то есть проверка не вырожденная.

## Борд стал данными, кэш вместо перекачки — 2026-08-21, второй заход

Первый заход в этот же день вынес оформление в `_shell/`. Аудит после него показал, где остались
деньги, и закрыл два места.

1. **Замер по 1 348 транскриптам за 30 дней.** 189 полных записей борда: 649 КБ оформления и
   1 143 КБ разметки с данными, плюс 1 309 правок борда на 862 КБ. Каждый байт после записи
   пересылается на каждом следующем запросе сессии, поэтому запись борда — самая дорогая
   регулярная операция в ките. Скрипты замера: `audit.py` и `audit2.py` в скретчпаде сессии.
2. **Борд переведён на JSON.** `board-shell/board.js` получил рендерер: страница содержит один
   блок `<script type="application/json" id="board">`, разметку рисует он. Шаблон 19 182 → 3 561
   байт, рендер попиксельно совпадает с прежним (md5 `94791dee…` на обоих). Побочный выигрыш:
   проценты и счётчики считает рендерер по листьям дерева, поэтому шапка больше не может
   разойтись со списком — эта ошибка уже случалась на живом борде.
3. **Фоновое обновление переписано под данные.** Свап `document.body.innerHTML` подменил бы
   отрисованный DOM невидимым JSON-блоком; теперь обновление берёт JSON из скачанной копии и
   перерисовывает. Разметочный борд старого вида по-прежнему обновляется свапом, чтобы страницы,
   написанные до сегодня, не сломались.
4. **`tools/kit-sync.sh` вместо «curl на каждом прогоне».** Порядок такой: если на машине есть
   клон кита — берём из него, сети нет вообще; иначе кэш в `~/.claude/cache/kit`, проверяемый не
   чаще раза в три часа (`KIT_SYNC_TTL`), и проверка условная — `If-None-Match`, 304 без тела.
   Скрипт печатает одну строку, содержимое файла в разговор не попадает никогда, читаем только на
   `CHANGED`. Раньше `company-brief` начинал каждый прогон с чтения своего же `SKILL.md` на 28 КБ,
   то есть примерно 8 000 токенов на пустом месте, и они потом пересылались всю сессию.
5. **Колода уже сделана правильно и не тронута.** `study-deck/app/deck.html` — 296 байт,
   `decks/<name>/index.html` — 567, всё содержимое в `data.js`, движок общий на 186 КБ. Это тот же
   паттерн, к которому приведены борд и план.
6. **`idea-lab/app/review.html` остаётся монолитом на 31 КБ** — единственный шаблон, который не
   разобран. За 30 дней им не пользовались ни разу, поэтому чинится отдельной задачей, а не в
   этой. Способ известен: тот же `_shell/` плюс блок данных.
7. **Хук, зарегистрированный посреди работы, действует в уже запущенных сессиях.** Проверено
   экспериментом в этой же сессии: `install.sh` дописал `shell-guard` в `settings.json`, после чего
   `Write` с инлайновым стилем на 734 байта был заблокирован здесь же, без перезапуска. Значит,
   правило доезжает до всех живых диалогов сразу, а не только до новых. Поэтому текст отказа
   переписан так, чтобы он не просто запрещал, а объяснял новый контракт: борд это JSON-блок,
   инструкции устарели, вот где лежит свежий скилл и шаблон. Отказ теперь мигрирует чужую сессию.

## Борд задачи живёт в папке задачи, а не в общем .claude полки — 2026-08-25

1. **`~/Downloads` это полка, а не проект.** Борд `company-brief` лежал в
   `~/Downloads/.claude/tasks/company-brief-skill.html`, то есть в общем каталоге полки, рядом с
   бордами чужих задач. Переехал в `~/Downloads/company-brief-skill/` вместе со своим `_shell/`,
   `STATUS.md` и `HANDOFF.md` — в ту же форму, что у остальных задач полки. Старый файл удалён,
   чтобы не осталось двух бордов одной задачи.
2. **`STATUS.md` в папке задачи это указатель, а не вторая память.** Настоящее состояние кита
   лежит в самом ките; дублировать его на полке значит завести расхождение. В папке задачи только
   холодный старт, таблица «что где» и одна строка текущего состояния.
3. **Дизайн брифа пережил рефакторинг оболочки 21.08 без потерь** — проверено 25.08: палитра и
   шрифты переехали в `assets/brief.css`, все 88 токенов на месте, раздел «Take the current
   version first» в `SKILL.md` на месте.

## Страницы, которые сами выдёргивают его в браузер, закрыты целиком, 2026-08-25

1. **Виновник найден и это был не «двадцать страниц», а один осиротевший шаблон.**
   `templates/meeting-board.html` содержал `setTimeout(() => location.reload(), refresh*1000)` с
   дефолтом 120 секунд и указанием в `skills/meeting-live/SKILL.md` ставить 5 секунд, «когда
   вопрос может прилететь ему». То есть борд созвона перезагружал себя раз в 5 секунд. Шаблон был
   мёртвый: `render.py` самодостаточен, держит свои CSS и палитру и никогда его не открывал, а
   `SKILL.md` всё равно называл шаблон единственным источником дизайна. Шаблон удалён из кита и из
   `~/.claude/templates/`, `SKILL.md` теперь указывает на `render.py`.
2. **Второй виновник вообще не в HTML.** LaunchAgent `com.ios-job-monitor.chrome-launcher`
   выполнял `open -a "Google Chrome"` три раза в сутки, в 01:10, 06:40 и 19:40, и поднимал Chrome
   поверх всего. В логе 12 срабатываний с 21 августа. Агент выгружен, plist убран из
   `~/Library/LaunchAgents` в `~/Downloads/html-autoswipe/disabled-agents/`, чтобы его можно было
   вернуть, если он для чего-то нужен.
3. **Проверены все страницы на диске, а не только те, что попались.** 811 файлов в `Downloads`,
   `Developer`, `Documents`, `Desktop` и `.claude`. 37 совпадений по запрещённым вызовам, из них
   ровно один действительно срабатывал сам: пункт 1. Остальные 36 висят на его собственном
   действии: 22 модалки в обработчиках кнопок, 7 перезагрузок по кнопке «сбросить» в idea-lab,
   3 открытия вкладки по клику, 2 записи в транскриптах сессий, 2 минифицированных бандла
   Claude Design.
4. **Порог для обхода уже: только то, что стреляет само.** Вызов, до которого код доходит из
   `click`, `change`, `submit`, `input`, `keydown` или `drop`, выехать не может: он уже смотрит на
   эту страницу, когда нажимает. Ловить их значит сделать проверку шумной, а шумную проверку
   перестают читать, и именно так баг и выжил.
5. **`hooks/page-sweep.sh`, на `SessionStart`.** `page-guard` видит только страницу, которую
   пишут; он не видит те, что уже лежат, те, что записал другой инструмент, и те, что он скачал.
   Обход проходит весь диск и печатает только самострельные. Первый прогон около 7 секунд, дальше
   около 1 секунды: кэш по `mtime` плюс дешёвый префильтр по литералам. Проверено подкладыванием
   страницы с `meta refresh`: поймана, после удаления обход снова чистый.
6. **`page-guard` расширен на Claude Design.** Он пишет файлы своим MCP-инструментом, мимо `Write`,
   и был единственным генератором, которого хук не видел. Матчер теперь включает
   `mcp__claude-design__write_files` и `mcp__claude-design__create_support_js`.
7. **Экспорты артефактов и записи транскриптов не правим.** `Documents/Claude/Artifacts/**` это
   копии опубликованного, их перезаписывает сам десктоп; `.claude/projects/*/tool-results/**` это
   история сессии, править её значит портить транскрипт. Обе ветки исключены из обхода по пути, с
   причиной в комментарии скрипта.
8. **Тупик: не пытаться отличать клик от таймера регуляркой в `page-guard`.** На записи хук видит
   кусок текста без контекста и ошибётся. Разделение живёт только в обходе, где есть весь файл.

## Ритуал хендоффа автоматизирован до одной клавиши, 2026-08-25

1. **Проверено, чего не может ни один хук.** Хук не может вызвать `/clear` или `/compact`, не
   может подставить пользовательскую реплику и не может перезапустить сессию. Внешний процесс не
   может отправить сообщение в живую интерактивную сессию: `claude -p --resume` завершает её и
   запускает новую в неинтерактивном режиме. Значит, из трёх шагов ритуала машине доступны первый
   и третий, а нажатие клавиши остаётся ему.
2. **Шаг 1 забирает `hooks/handoff-auto.sh`, хук на `Stop`.** Момент, когда ассистент собирается
   уйти в простой, это ровно та «естественная граница», о которой говорит правило. Past 250k хук
   отвечает `decision: block` с инструкцией, и сессия сама доводит `STATUS.md`, `DECISIONS.md`,
   борд и пишет хендофф. Ему остаётся одна строка на экране.
3. **Защита от петли обязательна.** Хук выходит немедленно при `stop_hook_active`, срабатывает не
   больше одного раза на сессию по маркеру с `session_id`, и молчит, если не смог измерить
   контекст. Клод-код обрывает цепочку блоков на восьмом, но полагаться на это значит потратить
   восемь ходов впустую.
4. **Шаг 3 забирает `handoff-guard.sh`.** Сессия, стартовавшая с `source` равным `clear` или
   `compact`, при ровно одном хендоффе свежее часа получает **весь файл целиком** в контекст и
   указание продолжать. Фразу «подхвати хендофф» он больше не печатает.
5. **Порог намеренно узкий.** Два свежих хендоффа или обычный `startup` — падаем в старый список.
   Угадать, какую из задач он имел в виду, дороже, чем дать ему напечатать одну фразу.
6. **`context-guard` теперь требует одну строку, а не абзац.** Всё, что он должен увидеть на эту
   тему: хендофф написан, жми `/clear`.
7. **Тупик: включать авто-компакт вместо клира.** Замер 2026-08-17 уже показал, что `/compact`
   стоит полного запроса и контекст возвращается к тому же объёму примерно за 20 ходов. Клавиша
   дешевле.

## Хендофф выбирался по времени, и это убило чужой проект, 2026-08-25

1. **Что случилось.** Чат «Accountant» (бухгалтерия) после `/clear` подхватил хендофф по делу
   ТЦК / Резерв+ и начал работать с ним. Подтверждено самой сессией `downloads-b9`: она выбрала
   файл **по самому свежему mtime**, потому что его сообщение было только «Подхватываю хендов» и
   не называло задачу.
2. **Причина не в хуке и не в модели, а в отсутствии идентичности.** `/clear` в приложении создаёт
   новую сессию с новым `session_id` и с `source: startup`; в транскрипте нет названия чата;
   рабочая папка у всех этих чатов одна и та же полка `~/Downloads`. Сессия физически не может
   узнать, какой она чат. Инструкция при этом говорила «читай тот, чей заголовок совпадает с тем,
   о чём он спрашивает», и не запрещала догадываться, когда не совпадает ничего.
3. **Догадка запрещена явно.** Выбор по свежести, по «выглядит активнее» и «открою посмотреть,
   подойдёт ли» теперь названы в тексте хука как запрещённые. Открывать можно только при
   положительном признаке: хендофф ровно один, либо его слова называют задачу, либо рабочая папка
   и есть папка задачи.
4. **Иначе задаётся ровно один вопрос, с нумерованным списком.** Это тот редкий случай, когда
   вопрос законный: он единственный в мире знает, в каком чате сидит. Одна цифра от него стоит
   секунд, чужой брифинг стоит проекта.
5. **Автоподхват по свежести, добавленный этим же утром, выключен в тот же день.** Он делал ровно
   ту ошибку, которая уже случилась: один свежий хендофф на полке мог автоматически уехать в
   несвязанный чат целиком. Ветка оставлена в коде выключенной, с причиной.
6. **Настоящее лекарство: один чат, одна папка.** Как только задача известна, сессия переносит
   себя в папку задачи через `mcp__ccd_directory__change_directory`. После этого следующий
   `/clear` стартует внутри задачи, и папка сама отвечает на вопрос. Вопрос задаётся один раз за
   всю жизнь чата.
7. **Хендофф теперь начинается с блока идентичности:** задача, папка, как называется чат, и строка
   «не твой, если». Последняя строка и есть то, что останавливает чужую сессию на первом взгляде.
8. **Проверены все живые сессии.** Восемь опрошены, семь работают со своими файлами, одна была той
   самой пострадавшей. Независимо всплыла вторая форма той же болезни: сессия работает в
   `~/Developer/idea-lab`, а её окно припарковано в `~/Finances/finapp`, и хук предлагает ей чужие
   хендоффы на каждом старте.
