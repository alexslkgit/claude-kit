# STATUS — claude-kit

## Холодный старт
Репозиторий конфигурации оркестратора: субагенты, output style, скиллы, шаблоны, хуки.
Публичный, `github.com/alexslkgit/claude-kit`, ветка `main`. Устанавливается на машину через
`install.sh`, который копирует деревья в `~/.claude/`. **Секретов и идентификаторов в него не
кладём** — ID таблиц и прочее живёт в `CLAUDE.local.md` на машине.

Решения — в `DECISIONS.md`, append-only, отменять номером и датой, не переписывать.

## Текущее состояние — 2026-08-25

Борд задачи `company-brief` переехал с общей полки в собственную папку
`~/Downloads/company-brief-skill/` (борд, `_shell/`, `STATUS.md`, `HANDOFF.md`). Проверено, что
рефакторинг оболочки 21.08 ничего не сломал в брифе: палитра и шрифты в `assets/brief.css`,
88 токенов и раздел «Take the current version first» на месте.

Закрыт баг «страница сама выдёргивает его в браузер», целиком, а не по двадцать файлов за раз.
Проверены все 811 страниц на диске: самострельная была ровно одна,
`templates/meeting-board.html`, осиротевший шаблон борда созвона с перезагрузкой раз в 5 секунд,
он удалён, `skills/meeting-live/SKILL.md` теперь указывает на `render.py`. Отдельно выгружен
LaunchAgent `com.ios-job-monitor.chrome-launcher`, который поднимал Chrome три раза в сутки.
Добавлен `hooks/page-sweep.sh` на `SessionStart`: обходит весь диск, печатает только то, что
стреляет само, около 1 секунды на кэше. `page-guard` расширен на записи через Claude Design.
Подробности и тупики: `DECISIONS.md`, раздел от 2026-08-25.

## Текущее состояние — 2026-08-21

### Оболочка страниц вынесена из шаблонов
Борд и бриф больше не носят своё оформление в себе. Вид и поведение борда — `board-shell/board.css`
и `board-shell/board.js`, вид брифа — `skills/company-brief/assets/brief.css` и `brief.js`. Страница
копирует их один раз в `_shell/` рядом с собой и подключает относительным путём; сама страница
содержит только разметку с данными. `plan-shell/` был таким с самого начала и служил образцом.

| Файл | Было | Стало |
|---|---|---|
| `templates/board.html` | 19 182 | 3 561 (JSON-блок, разметку рисует рендерер) |
| `skills/company-brief/assets/brief-template.html` | 26 007 | 9 052 |

Борд пишется как данные: один блок `<script type="application/json" id="board">`, рендерер в
`board-shell/board.js` строит разметку и сам считает проценты по листьям. Проверено рендером
headless Chrome: старый разметочный борд и новый JSON-борд дают одинаковый PNG.

`tools/kit-sync.sh` — единая точка получения файлов кита: клон, если он есть, иначе кэш с
проверкой не чаще раза в три часа и условным запросом. `company-brief` переведён на него.

Защита от возврата: `hooks/shell-guard.sh` — падает на инлайновом `<style>` или исполняемом
`<script>` больше 500 байт, и как `--check` по шаблонам кита, и как PreToolUse на `Write`/`Edit`/
`Bash`. Зарегистрирован в `install.sh` рядом с остальными guard-скриптами. Портативная копия
страницы (почта, артефакт) собирается `tools/inline-shell.py`.

Не коммичено на 2026-08-21 09:20 — коммит делает он сам.

## Текущее состояние — 2026-08-20

### skills/company-brief
Скилл собирает бриф о компании перед собеседованием. За 20.08 сделано три прохода, все запушены:

| Коммит | Что |
|---|---|
| `72b30d5` | создан `assets/brief-template.html`, которого не было вовсе; переписан раздел «Деньги» |
| `428c352` | пустые значения удаляют свою строку; разделы сворачиваются; вилка в липкой шапке |
| `8ab23ed` | всё свёрнуто по умолчанию; зачёркивание пунктов; шкала этапов; оценка 0–100 |
| `e37fc50` | шаблон перерисован по дизайн-системе колоды: Golos Text + Source Serif 4, тёплая бумага, терракота, карточки 22px |

Шаблон тянется на каждом прогоне по raw с GitHub, локальная копия в директории скилла — запасная.
Проверено после каждого пуша: raw отдаётся без токена и совпадает с локальным файлом.

Дизайн закрыт. Система взята целиком из проекта Claude Design «Колода — направления», того же,
что у деки: `#F5F3F0`/`#17181B` бумага, акцент `#A25A34`/`#D9A66B`, Golos Text для интерфейса и
Source Serif 4 для длинной прозы. Проверено на 375 и 1280, обе темы, горизонтального скролла нет,
все 88 токенов и весь скрипт целы. Образец — `~/Developer/job-search/briefs/obox-systems-2026-08-20.html`,
пересобирается скриптом `_rebuild-obox.py` рядом с ним.

Копий скилла три и они больше не расходятся: кит, `~/.claude/skills` и аккаунт claude.ai сверены
по md5 20.08. Старая копия в аккаунте отставала на 189 строк и была без шаблона, её удалили и
загрузили заново зипом; её текст лежит в `archive/company-brief-account-SKILL-2026-08-20.md`.
В начале `SKILL.md` теперь раздел «Take the current version first»: любой прогон, где бы он ни
шёл, сначала берёт свежий `SKILL.md` по raw и следует ему.

**Открыто:** ничего по этому скиллу.

## Уроки по этому репозиторию

- Скиллы из `anthropic-skills:` приезжают из аккаунта claude.ai и на маке лежат в сессионной
  директории `~/Library/Application Support/Claude/local-agent-mode-sessions/…`. Правки там не
  переживают сессию. Источник правды — этот репозиторий; в аккаунт заливается zip вручную.
- `hooks/page-guard.sh` проверяет не только записываемый файл, но и текст bash-команды. Скрипт,
  который просто перечисляет запрещённые строки для самопроверки, будет отклонён — проверку делает
  сам хук, дублировать её не нужно.

## 2026-08-20 — the board and the chewed plan are one pair; artefacts belong to a task
He opened the board expecting the instruction he had just asked for and found neither a link to it
nor a mention. Root cause: nothing in the kit connected the two skills. `skills/board/SKILL.md`
never mentioned `plan.html`, `skills/chew/SKILL.md` mentioned the board only to say they were
different files, `templates/board.html` had an unused `.you a.btn`, and `plan-shell/plan.css` was
a cold blue design against the board's warm paper. Fixed in all four, plus the output style.

Second failure found while checking the first: `~/Downloads` held three unrelated tasks
(tck-reserve, justmarkets, raads-r) sharing one `.claude/`, with `status-dir` pointing at the third
one. So `status-guard.sh` announced raads-r's STATUS.md as the memory of whatever task the session
was on, and the task actually being worked had no STATUS.md at all. The hook now recognises a shelf
— a directory that is not a project but holds task folders — and lists them instead of picking one.
Outside a git checkout, a task gets its own folder with STATUS.md, DECISIONS.md, journal.md,
board.html, plan.html, _shell/ and its own .claude/status-dir.
