import re, pathlib

kit = pathlib.Path.home() / "Developer/claude-kit"
# The board's look lives in the shell, not in the template: templates/board.html is data only.
css = (kit / "board-shell/board.css").read_text()

# drop every theme-switching block; each artboard is one fixed snapshot
def cut_blocks(text, starts):
    for marker in starts:
        while True:
            i = text.find(marker)
            if i < 0:
                break
            depth, j = 0, text.index("{", i)
            k = j
            while True:
                if text[k] == "{":
                    depth += 1
                elif text[k] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            text = text[:i] + text[k + 1:]
    return text

css = cut_blocks(css, ["@media (prefers-color-scheme: dark)", ':root[data-theme="dark"]'])

LIGHT = """  --bg:#FDFCF9; --fg:#23211E; --muted:#6E675C; --faint:#7F776C;
  --line:#E7E0D0; --line-soft:#EFEADC; --track:#EDE6D6;
  --done:#7F776C; --ok:#4B7A57; --accent:#9A6207; --dead:#8C6A6A;
  --warn-bg:#FBF1DC; --warn-fg:#8A5A0B; --warn-text:#7A6A4C;
  --btn-bg:#23211E; --btn-fg:#FDFCF9;"""
DARK = """  --bg:#1A1815; --fg:#EDE9E0; --muted:#A39B8D; --faint:#8A8276;
  --line:#332F28; --line-soft:#2A2721; --track:#2E2A23;
  --done:#8A8276; --ok:#7FBF92; --accent:#D9A441; --dead:#C99A9A;
  --warn-bg:#2E2415; --warn-fg:#E8B45C; --warn-text:#C4B08A;
  --btn-bg:#EDE9E0; --btn-fg:#1A1815;"""

def scoped(palette, stop_bg, stop_fg):
    c = css.replace(LIGHT, palette)
    if palette is DARK:
        c = c.replace("color-scheme: light;", "color-scheme: dark;")
    c = c.replace(":root {", ".brd {").replace("body {", ".brd {")
    c = c.replace("main { max-width:1040px; margin:0 auto; }",
                  "main { max-width:none; margin:0; }")
    c = c.replace(".you.stop { background:#F3D9D3; }",
                  ".you.stop { background:%s; }" % stop_bg)
    c = c.replace(".you.stop .cap { color:#8C3A26; }",
                  ".you.stop .cap { color:%s; }" % stop_fg)
    return c + "\n  .brd { width:1040px; }\n"

BODY = """
  <div class="head">
    <div class="kicker">Борд · обновлено 14:32:07</div>
    <div class="theme">
      <button data-theme-set="auto" class="on">авто</button>
      <button data-theme-set="light">светлая</button>
      <button data-theme-set="dark">тёмная</button>
    </div>
  </div>
  <h1>Релиз 2.4 в App Store</h1>
  <p class="sub">Собрать, подписать, отправить на ревью</p>

  <div class="total">
    <div class="total-meta">
      <span class="pct">42%</span>
      <span>5 из 12 пунктов закрыто, 1 в работе</span>
      <span class="drift">было 63%, добавилось 4 подпункта</span>
    </div>
    <div class="bar"><i class="f-done" style="width:42%"></i><i class="f-live" style="width:8%"></i></div>
  </div>

  <div class="cols">

    <ol class="tasks">

      <li class="done">
        <div class="row">
          <span class="num">1</span><span class="label">Подготовка</span>
          <span class="grow"></span>
          <span class="mini"><i style="width:100%"></i></span>
          <span class="count">2 из 2</span>
        </div>
      </li>

      <li class="live"><details id="t2" open>
        <summary class="row">
          <span class="num">2</span><span class="label">Сертификаты и профили</span>
          <span class="grow"></span>
          <span class="mini"><i style="width:33%"></i></span>
          <span class="count">1 из 3</span>
        </summary>
        <ul class="lvl2">
          <li class="done">Вход в App Store Connect</li>
          <li>Выпустить сертификат<span class="wait-tag">ждёт тебя</span></li>
          <li class="todo">Профиль подписи</li>
        </ul>
      </details></li>

      <li class="live"><details id="t3" open>
        <summary class="row">
          <span class="num">3</span><span class="label">Сборка</span>
          <span class="grow"></span>
          <span class="mini"><i style="width:50%"></i></span>
          <span class="count">2 из 4</span>
        </summary>
        <ul class="lvl2">
          <li class="done">Архив собран</li>
          <li class="branch"><details id="t3-2" open><summary>Тесты</summary>
            <ul class="lvl3">
              <li class="done">Unit, 214 из 214</li>
              <li class="here">UI, 28 из 40<span class="here-tag">сейчас здесь</span></li>
            </ul>
          </details></li>
          <li class="todo">Загрузка в TestFlight</li>
        </ul>
      </details></li>

      <li class="todo">
        <div class="row">
          <span class="num">4</span><span class="label">Метаданные и скриншоты</span>
          <span class="grow"></span>
          <span class="mini"><i style="width:0%"></i></span>
          <span class="count">0 из 2</span>
        </div>
      </li>

      <li class="todo">
        <div class="row">
          <span class="num">5</span><span class="label">Отправка на ревью</span>
          <span class="grow"></span>
          <span class="mini"><i style="width:0%"></i></span>
          <span class="count">0 из 1</span>
        </div>
      </li>

    </ol>

    <aside class="side">

      <div class="you">
        <div class="cap">Ждёт от тебя · 1</div>
        <h2>Нажать «Create Certificate» в Apple Developer</h2>
        <p>Вкладка открыта, форма заполнена, остался один клик. Дальше я снова работаю сам.</p>
        <a class="btn" href="#">Открыть вкладку</a>
      </div>

      <div class="box">
        <div class="cap">Сейчас</div>
        <p>Гоняю UI-тесты на билде 2.4.1, осталось 12 из 40.</p>
      </div>

      <div class="box">
        <div class="cap">Решено по дороге</div>
        <p>Собираем на Xcode 16.4, не на 17: семнадцатый ломает виджет на iOS 18, см. <a href="#">тикет #58</a>.</p>
        <p>Скриншоты снимаем только 6,9 дюйма, остальные размеры Apple растянет сама.</p>
        <p class="dead">Тупик: автоподпись через fastlane match не завелась, ключ вне репозитория, разбирали в <a href="#">треде Slack</a>.</p>
      </div>

    </aside>
  </div>

  <section class="daily">
    <div class="daily-cols">
      <div>
        <div class="cap">С прошлого дейлика · вчера 10:15</div>
        <ul class="news">
          <li><span class="src">PR</span>Два пулл-реквеста не мержились из-за тестов, тесты позеленели, оба готовы к мержу: <a href="#">#31</a> и <a href="#">#32</a>.</li>
          <li><span class="src">Тикет</span>Задача переехала в Ready for QA: <a href="#">TASK-15</a>.</li>
          <li><span class="src">Слак</span>Коллега спросил про сертификат в <a href="#">треде Slack</a>, ответ написан, но ещё не отправлен.</li>
        </ul>
      </div>
      <div>
        <div class="cap">Что сказать на дейлике</div>
        <ol class="say"><li>Два пулл-реквеста готовы к мержу, тесты зелёные.</li><li>Сегодня беру задачу 15.</li><li>Дальше метаданные к релизу.</li></ol>
      </div>
    </div>
  </section>

  <p class="stamp">Страница обновляется сама, перезагружать не нужно.</p>
"""

ART = """<!doctype html>
<html>
<head>
  <meta charset="utf-8">
  <script src="./support.js"></script>
</head>
<body>
<x-dc>
<helmet>
  <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Commissioner:wght@400;500;600;700&family=Literata:opsz,wght@7..72,400;7..72,600;7..72,700&display=swap">
  <style>
%s  </style>
</helmet>

<div class="brd">
<main>
%s</main>
</div>
</x-dc>
<script data-dc-script data-props='{}'>
class Component extends DCLogic {
  renderVals() { return {}; }
}
</script>
</body>
</html>
"""

out = kit / ".claude/design/board"
(out / "Main.dc.html").write_text(ART % (scoped(LIGHT, "#F3D9D3", "#8C3A26"), BODY))
(out / "VariantBDark.dc.html").write_text(ART % (scoped(DARK, "#3A211A", "#E9A28C"), BODY))
print("ok", (out/"Main.dc.html").stat().st_size, (out/"VariantBDark.dc.html").stat().st_size)
