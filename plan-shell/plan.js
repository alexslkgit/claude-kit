/* plan.js — renders a chewed plan from its JSON data block.
   The plan file carries data only: a <script type="application/json" id="plan"> block plus
   relative <link>/<script src> to this shell. Everything below is markup so that writing a
   plan never means writing HTML.

   Contract with the data (see the chew skill for the authoring rules):
     { title, subtitle, verified,
       notes:  [ { kind:"good"|"warn"|"prep", head, body } ],
       stages: [ { title, notes:[...], steps:[ step ] } ],
       mine:   [ "…" ]        // or { title, items:[ "…" ] }
     }
     step = { do, where, ok, forks:[…], links:[{text,href}], img:"…"|{src,cap},
              status:"todo"|"done"|"blocked" }

   Step numbers are NEVER stored in the data — they are computed here from position, so
   inserting a step mid-flow costs nothing. Strings may carry inline HTML (<b>, <code>, <a>);
   the file is local and authored by the assistant, so it is trusted markup.

   State that must survive the page's own <meta refresh>: the "скрыть выполненные" toggle and
   any stage the user expanded by hand live in localStorage, the scroll position in
   sessionStorage, both keyed by the plan's own path. */

(function () {
  'use strict';

  var KEY = 'chew-plan:' + location.pathname;
  var SCROLL_KEY = 'chew-scroll:' + location.pathname;

  // ---- tiny DOM helpers --------------------------------------------------
  function el(tag, cls, html) {
    var n = document.createElement(tag);
    if (cls) { n.className = cls; }
    if (html != null) { n.innerHTML = html; }
    return n;
  }
  function text(v) { return v == null ? '' : String(v); }

  function loadState() {
    try {
      var raw = localStorage.getItem(KEY);
      var s = raw ? JSON.parse(raw) : {};
      return { hideDone: !!s.hideDone, stages: s.stages || {} };
    } catch (e) {
      return { hideDone: false, stages: {} };
    }
  }
  function saveState(state) {
    try { localStorage.setItem(KEY, JSON.stringify(state)); } catch (e) { /* private mode */ }
  }

  // ---- pieces ------------------------------------------------------------
  function noteBlock(note) {
    var kind = note.kind === 'good' || note.kind === 'warn' ? note.kind : 'prep';
    var box = el('div', 'note ' + kind);
    if (note.head) { box.appendChild(el('div', 'hd', text(note.head))); }
    box.appendChild(el('div', null, text(note.body)));
    return box;
  }

  function linkRow(links) {
    var row = el('div', 'links');
    links.forEach(function (l) {
      var href = typeof l === 'string' ? l : l.href;
      if (!href) { return; }
      var a = el('a', null, text(typeof l === 'string' ? l : (l.text || l.href)));
      a.href = href;
      a.target = '_blank';
      a.rel = 'noopener';
      row.appendChild(a);
    });
    return row.childNodes.length ? row : null;
  }

  function shot(img) {
    var src = typeof img === 'string' ? img : img.src;
    if (!src) { return null; }
    var box = el('div', 'shot');
    var im = document.createElement('img');
    im.src = src;
    im.alt = (typeof img === 'object' && img.cap) ? String(img.cap) : '';
    im.loading = 'lazy';
    box.appendChild(im);
    if (typeof img === 'object' && img.cap) { box.appendChild(el('div', 'cap', text(img.cap))); }
    return box;
  }

  function stepCard(step, number) {
    var status = step.status === 'done' || step.status === 'blocked' ? step.status : 'todo';
    var card = el('section', 'step' + (status === 'todo' ? '' : ' ' + status));
    card.id = 'step-' + number;

    // The number itself is the anchor, so a chat message can point at exactly one step.
    var num = el('a', 'num', String(number));
    num.href = '#step-' + number;
    num.title = 'Ссылка на этот шаг';
    card.appendChild(num);

    var body = el('div', 'body');
    body.appendChild(el('div', 'do', text(step['do'])));
    if (step.where) { body.appendChild(el('p', 'where', text(step.where))); }
    if (step.img) { var s = shot(step.img); if (s) { body.appendChild(s); } }
    if (step.links && step.links.length) {
      var lr = linkRow(step.links);
      if (lr) { body.appendChild(lr); }
    }
    (step.forks || []).forEach(function (f) { body.appendChild(el('p', 'fork', text(f))); });
    if (step.ok) { body.appendChild(el('p', 'ok', 'Получилось, если ' + text(step.ok))); }
    card.appendChild(body);
    return card;
  }

  // ---- render ------------------------------------------------------------
  function render(data) {
    var state = loadState();
    var wrap = el('div', 'wrap');

    if (data.title) {
      wrap.appendChild(el('h1', null, text(data.title)));
      document.title = String(data.title).replace(/<[^>]*>/g, '');
    }
    if (data.subtitle) { wrap.appendChild(el('div', 'sub', text(data.subtitle))); }

    var total = 0, done = 0;
    (data.stages || []).forEach(function (st) {
      (st.steps || []).forEach(function (sp) {
        total++;
        if (sp.status === 'done') { done++; }
      });
    });

    var meter = el('div', 'meter');
    meter.appendChild(el('span', 'count', 'Сделано ' + done + ' из ' + total));
    var bar = el('div', 'bar');
    var fill = el('i');
    fill.style.width = (total ? Math.round((done / total) * 100) : 0) + '%';
    bar.appendChild(fill);
    meter.appendChild(bar);

    var label = el('label', 'toggle');
    var box = document.createElement('input');
    box.type = 'checkbox';
    box.checked = state.hideDone;
    label.appendChild(box);
    label.appendChild(document.createTextNode('скрыть выполненные'));
    meter.appendChild(label);
    wrap.appendChild(meter);

    (data.notes || []).forEach(function (n) { wrap.appendChild(noteBlock(n)); });

    var counter = 0;
    (data.stages || []).forEach(function (st, i) {
      var steps = st.steps || [];
      var stDone = steps.filter(function (s) { return s.status === 'done'; }).length;
      var allDone = steps.length > 0 && stDone === steps.length;

      var stage = el('section', 'stage' + (allDone ? ' all-done' : ''));
      var collapsed = Object.prototype.hasOwnProperty.call(state.stages, i)
        ? !!state.stages[i]
        : allDone;                         // a finished stage folds itself away
      if (collapsed) { stage.classList.add('collapsed'); }

      var head = el('div', 'stage-head');
      head.appendChild(el('span', 'caret', '&#9660;'));
      head.appendChild(el('span', 'name', text(st.title)));
      if (steps.length) { head.appendChild(el('span', 'tally', stDone + ' из ' + steps.length)); }
      head.addEventListener('click', function () {
        stage.classList.toggle('collapsed');
        state.stages[i] = stage.classList.contains('collapsed');
        saveState(state);
      });
      stage.appendChild(head);

      var sbody = el('div', 'stage-body');
      (st.notes || []).forEach(function (n) { sbody.appendChild(noteBlock(n)); });
      steps.forEach(function (sp) { counter++; sbody.appendChild(stepCard(sp, counter)); });
      stage.appendChild(sbody);
      wrap.appendChild(stage);
    });

    var mine = data.mine;
    if (mine && (mine.length || (mine.items && mine.items.length))) {
      var items = mine.items || mine;
      var mbox = el('div', 'mine');
      mbox.appendChild(el('div', 'hd', text(mine.title || 'Моя часть — тебя не касается')));
      var ul = el('ul', 'plain');
      items.forEach(function (it) { ul.appendChild(el('li', null, text(it))); });
      mbox.appendChild(ul);
      wrap.appendChild(mbox);
    }

    if (data.verified) { wrap.appendChild(el('div', 'foot', text(data.verified))); }

    document.body.appendChild(wrap);
    if (state.hideDone) { document.body.classList.add('hide-done'); }

    box.addEventListener('change', function () {
      state.hideDone = box.checked;
      document.body.classList.toggle('hide-done', state.hideDone);
      saveState(state);
    });

    return wrap;
  }

  // ---- anchors, scroll ---------------------------------------------------
  function focusHash() {
    var m = /^#step-(\d+)$/.exec(location.hash || '');
    if (!m) { return false; }
    var node = document.getElementById('step-' + m[1]);
    if (!node) { return false; }
    var stage = node.closest ? node.closest('.stage') : null;
    if (stage) { stage.classList.remove('collapsed'); }   // never point at a hidden step
    node.classList.add('pinned');                          // survives "скрыть выполненные"
    node.scrollIntoView({ block: 'center' });
    node.classList.remove('flash');
    void node.offsetWidth;
    node.classList.add('flash');
    return true;
  }

  function keepScroll() {
    var t = 0;
    window.addEventListener('scroll', function () {
      clearTimeout(t);
      t = setTimeout(function () {
        try { sessionStorage.setItem(SCROLL_KEY, String(window.scrollY)); } catch (e) { /* noop */ }
      }, 120);
    }, { passive: true });
  }

  function restoreScroll() {
    try {
      var y = parseInt(sessionStorage.getItem(SCROLL_KEY) || '0', 10);
      if (y > 0) { window.scrollTo(0, y); }
    } catch (e) { /* noop */ }
  }

  function boot() {
    var node = document.getElementById('plan');
    var data;
    try {
      data = JSON.parse(node.textContent);
    } catch (e) {
      document.body.appendChild(el('div', 'wrap',
        '<div class="note warn"><div class="hd">План не отрисовался</div>' +
        'Блок данных в этом файле — не валидный JSON: <code>' +
        String(e.message).replace(/</g, '&lt;') + '</code>. Скинь мне эту строчку, починю.</div>'));
      return;
    }
    render(data);
    if (!focusHash()) { restoreScroll(); }
    keepScroll();
    window.addEventListener('hashchange', focusHash);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
