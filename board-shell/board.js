/* board.js — the whole behaviour of the board. One file, every board on this machine.
   Instance pages link it and contain no script of their own.

   Live refresh is a background fetch with a document.body swap, and NEVER a page reload.
   The reload family (a refresh meta tag, location.reload, window.focus, an auto-focus
   attribute, alert, Notification, window.open) makes Chrome steal focus and yank his
   macOS Space to the browser mid-work. Blocked by hooks/page-guard.sh, so do not
   "simplify" this back.

   Under file:// Chrome refuses the fetch (the scheme is not http or https); the catch
   swallows it and the page simply stays static, which is correct. Served over http it
   refreshes every 15 seconds. */

/* ---------------------------------------------------------------- the renderer
   The board page carries ONE <script type="application/json" id="board"> block and nothing
   else. Everything below turns it into the markup board.css expects. Counts, per-task bars and
   the overall percent are computed from the tree here, so a board can never quote a percentage
   that disagrees with its own list.

   Card of the data, all fields optional except title and tasks:

   { "title": "...", "sub": "...", "stamp": "09:22", "drift": "было 63%, добавилось 4 подпункта",
     "tasks": [ { "t": "Задача", "state": "done|live|todo", "open": true,
                  "count": [2,2],                     // only for a task with no children listed
                  "closed": 6,                        // finished children deleted instead of listed
                  "items": [ { "t": "Пункт", "state": "done|todo|wait|here", "closed": 2,
                               "items": [...] } ] } ],
     "you":  { "cap": "Ждёт от тебя · 1", "h": "...", "p": "...", "stop": false,
               "btn": { "href": "plan.html", "label": "Открыть инструкцию" } },
     "now":  "одна строка о том, что я делаю сейчас",
     "decided": [ { "t": "решение и причина", "dead": false } ],
     "daily": { "since": "вчера 10:15",
                "news": [ { "src": "PR", "t": "строка, <a href=…>ссылка</a>" } ],
                "say":  [ "что сдвинулось", "чем занят", "что дальше" ] },
     "stampNote": "Страница обновляется сама, перезагружать не нужно." }

   Values are printed as written, so <a>, <b> and <span class="pill"> inside them work. */

(function () {
  function tally(items) {
    // leaves only: a node with children contributes its children, never itself.
    // `closed` is how many finished children were deleted rather than listed: they are still work
    // that was done, so they count in both halves of the fraction and the percent does not lie.
    var total = 0, done = 0, live = 0;
    for (var i = 0; i < (items || []).length; i++) {
      var n = items[i];
      if (n.items && n.items.length) {
        var t = tally(n.items), c = n.closed || 0;
        total += t.total + c; done += t.done + c; live += t.live;
      } else {
        total++;
        if (n.state === 'done') done++;
        if (n.state === 'here' || n.state === 'live') live++;
      }
    }
    return { total: total, done: done, live: live };
  }
  function taskTally(task) {
    if (task.items && task.items.length) {
      var t = tally(task.items), c = task.closed || 0;
      return { total: t.total + c, done: t.done + c, live: t.live };
    }
    var c2 = task.count || [task.state === 'done' ? 1 : 0, 1];
    return { total: c2[1], done: c2[0], live: task.state === 'live' ? 1 : 0 };
  }
  function pct(a, b) { return b ? Math.round(a * 100 / b) : 0; }

  function leaf(n, lvl, id) {
    var tag = n.state === 'wait' ? '<span class="wait-tag">ждёт тебя</span>'
            : n.state === 'here' ? '<span class="here-tag">сейчас здесь</span>' : '';
    if (n.items && n.items.length) {
      return '<li class="branch"><details id="' + id + '"' + (n.open === false ? '' : ' open') +
             '><summary>' + n.t + '</summary>' + list(n.items, lvl + 1, id) + '</details></li>';
    }
    return '<li' + (n.state && n.state !== 'wait' ? ' class="' + n.state + '"' : '') + '>' + n.t + tag + '</li>';
  }
  function list(items, lvl, id) {
    var out = '<ul class="lvl' + lvl + '">';
    for (var i = 0; i < items.length; i++) out += leaf(items[i], lvl, id + '-' + (i + 1));
    return out + '</ul>';
  }
  function task(t, i) {
    var n = taskTally(t), id = 't' + (i + 1);
    var row = '<span class="num">' + (i + 1) + '</span><span class="label">' + t.t + '</span>' +
              '<span class="grow"></span><span class="mini"><i style="width:' + pct(n.done, n.total) + '%"></i></span>' +
              '<span class="count">' + n.done + ' из ' + n.total + '</span>';
    var cls = t.state || (n.done === n.total ? 'done' : n.done ? 'live' : 'todo');
    if (!t.items || !t.items.length) return '<li class="' + cls + '"><div class="row">' + row + '</div></li>';
    return '<li class="' + cls + '"><details id="' + id + '"' + (t.open === false ? '' : ' open') +
           '><summary class="row">' + row + '</summary>' + list(t.items, 2, id) + '</details></li>';
  }

  function build(d) {
    var all = { total: 0, done: 0, live: 0 };
    for (var i = 0; i < d.tasks.length; i++) {
      var n = taskTally(d.tasks[i]); all.total += n.total; all.done += n.done; all.live += n.live;
    }
    var h = '<main>\n\n  <div class="head">\n    <div class="kicker">Борд' +
            (d.stamp ? ' · обновлено ' + d.stamp : '') + '</div>\n    <div class="theme">' +
            '\n      <button data-theme-set="auto">авто</button>' +
            '\n      <button data-theme-set="light">светлая</button>' +
            '\n      <button data-theme-set="dark">тёмная</button>\n    </div>\n  </div>' +
            '\n  <h1>' + d.title + '</h1>' + (d.sub ? '\n  <p class="sub">' + d.sub + '</p>' : '');

    h += '\n\n  <div class="total">\n    <div class="total-meta">\n      <span class="pct">' +
         pct(all.done, all.total) + '%</span>\n      <span>' + all.done + ' из ' + all.total +
         ' пунктов закрыто' + (all.live ? ', ' + all.live + ' в работе' : '') + '</span>' +
         (d.drift ? '\n      <span class="drift">' + d.drift + '</span>' : '') +
         '\n    </div>\n    <div class="bar"><i class="f-done" style="width:' + pct(all.done, all.total) +
         '%"></i><i class="f-live" style="width:' + pct(all.live, all.total) + '%"></i></div>\n  </div>';

    h += '\n\n  <div class="cols">\n\n    <ol class="tasks">\n\n';
    for (var j = 0; j < d.tasks.length; j++) h += '      ' + task(d.tasks[j], j) + '\n\n';
    h += '    </ol>\n\n    <aside class="side">\n\n';

    if (d.you) {
      h += '      <div class="you' + (d.you.stop ? ' stop' : '') + '">\n        <div class="cap">' +
           (d.you.cap || 'Ждёт от тебя') + '</div>\n        <h2>' + (d.you.h || '') + '</h2>\n' +
           (d.you.p ? '        <p>' + d.you.p + '</p>\n' : '') +
           (d.you.btn ? '        <a class="btn" href="' + d.you.btn.href + '">' + d.you.btn.label + '</a>\n' : '') +
           '      </div>\n\n';
    }
    if (d.now) h += '      <div class="box">\n        <div class="cap">Сейчас</div>\n        <p>' +
                    d.now + '</p>\n      </div>\n\n';
    if (d.decided && d.decided.length) {
      h += '      <div class="box">\n        <div class="cap">Решено по дороге</div>\n';
      for (var k = 0; k < d.decided.length; k++) {
        var it = d.decided[k];
        h += '        <p' + (it.dead ? ' class="dead"' : '') + '>' + it.t + '</p>\n';
      }
      h += '      </div>\n\n';
    }
    h += '    </aside>\n  </div>';

    if (d.daily) {
      h += '\n\n  <section class="daily">\n    <div class="daily-cols">\n      <div>\n' +
           '        <div class="cap">С прошлого дейлика' + (d.daily.since ? ' · ' + d.daily.since : '') +
           '</div>\n        <ul class="news">\n';
      for (var m = 0; m < (d.daily.news || []).length; m++) {
        h += '          <li><span class="src">' + d.daily.news[m].src + '</span>' + d.daily.news[m].t + '</li>\n';
      }
      h += '        </ul>\n      </div>\n      <div>\n        <div class="cap">Что сказать на дейлике</div>\n' +
           '        <ol class="say">';
      for (var s = 0; s < (d.daily.say || []).length; s++) h += '<li>' + d.daily.say[s] + '</li>';
      h += '</ol>\n      </div>\n    </div>\n  </section>';
    }

    h += '\n\n  <p class="stamp">' + (d.stampNote || 'Страница обновляется сама, перезагружать не нужно.') +
         '</p>\n\n</main>';
    return h;
  }

  function draw(json) {
    var d;
    try { d = JSON.parse(json); } catch (e) {
      document.body.innerHTML = '<main><h1>Борд не разобрался</h1><p class="sub">JSON битый: ' +
        (e && e.message ? e.message : e) + '</p></main>';
      return false;
    }
    document.body.innerHTML = build(d);
    return true;
  }

  window.__boardDraw = draw;
  // Node entry point for board-shell/render-body.js, which the board-inline hook runs after every
  // board write to bake this same markup into the file. `module` is undefined in a browser, so
  // this line costs the page nothing. One renderer, two callers: the pane and the browser can
  // never disagree about what the board says.
  if (typeof module === 'object' && module !== null && module.exports) {
    module.exports = { build: build, draw: draw };
  }
  var src = document.getElementById('board');
  if (src) draw(src.textContent);
})();

let __boardSeen = null;
setInterval(async () => {
  try {
    const r = await fetch(location.href, {cache: 'no-store'});
    const doc = new DOMParser().parseFromString(await r.text(), 'text/html');
    const src = doc.getElementById('board');
    if (src) {
      // Data page: re-render from the fetched JSON. Swapping the body would drop the rendered
      // DOM and put the invisible <script> block in its place.
      const json = src.textContent;
      if (json !== __boardSeen && window.__boardDraw && window.__boardDraw(json)) __boardSeen = json;
    } else if (doc.body && doc.body.innerHTML !== document.body.innerHTML) {
      document.body.innerHTML = doc.body.innerHTML;   // a hand-written markup board still works
    }
  } catch (e) {}
}, 15000);

// Theme switch and fold state. No reloads: an attribute on <html> and localStorage.
(function () {
  var KEY = 'board-theme';
  function apply(v) {
    var r = document.documentElement;
    if (v === 'light' || v === 'dark') { r.setAttribute('data-theme', v); }
    else { r.removeAttribute('data-theme'); }
    var bs = document.querySelectorAll('[data-theme-set]');
    for (var i = 0; i < bs.length; i++) {
      bs[i].classList.toggle('on', bs[i].getAttribute('data-theme-set') === (v || 'auto'));
    }
  }
  function current() { try { return localStorage.getItem(KEY) || 'auto'; } catch (e) { return 'auto'; } }
  var OKEY = 'board-open';
  function readOpen() { try { return JSON.parse(localStorage.getItem(OKEY) || '{}'); } catch (e) { return {}; } }
  function applyOpen() {
    var st = readOpen(), ds = document.querySelectorAll('details[id]');
    for (var i = 0; i < ds.length; i++) { var v = st[ds[i].id]; if (v !== undefined) { ds[i].open = !!v; } }
  }
  document.addEventListener('toggle', function (e) {
    var d = e.target;
    if (!d.id || d.tagName !== 'DETAILS') return;
    var st = readOpen(); st[d.id] = d.open;
    try { localStorage.setItem(OKEY, JSON.stringify(st)); } catch (e2) {}
  }, true);
  apply(current());
  applyOpen();
  document.addEventListener('click', function (e) {
    var b = e.target.closest && e.target.closest('[data-theme-set]');
    if (!b) return;
    var v = b.getAttribute('data-theme-set');
    try { localStorage.setItem(KEY, v); } catch (e2) {}
    apply(v);
  });
  new MutationObserver(function () { apply(current()); applyOpen(); }).observe(document.body, { childList: true });
})();
