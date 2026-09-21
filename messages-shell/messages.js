// messages.js: the shared messages page shell. Copy-to-clipboard (HTML + plain text) and
// a per-card draft/sent toggle persisted in localStorage. No frameworks, no network calls.
(function () {
  function hashCode(str) {
    var h = 0;
    for (var i = 0; i < str.length; i++) {
      h = (Math.imul(31, h) + str.charCodeAt(i)) | 0;
    }
    return String(h);
  }

  function statusKey(card) {
    return 'msg-status-' + hashCode(card.getAttribute('data-key') || '');
  }

  // Old key: hashed the rendered body text, which shifts whenever layout changes. Kept only
  // so restore() can migrate whatever it already saved under it, once, then drop it.
  function legacyStatusKey(card) {
    var body = card.querySelector('.body');
    return 'msg-status-' + hashCode(body.innerText);
  }

  function setStatus(card, status, persist) {
    card.setAttribute('data-status', status);
    var words = { sent: 'отправлено', deleted: 'удалено', superseded: 'переписано', draft: 'черновик' };
    var word = words[status] || 'черновик';
    var statusEl = card.querySelector('.status');
    if (statusEl) {
      statusEl.textContent = word;
    } else {
      var meta = card.querySelector('.meta');
      meta.textContent = meta.textContent.replace(/(черновик|отправлено|удалено|переписано)\s*$/, word);
    }
    if (persist !== false) {
      try { localStorage.setItem(statusKey(card), status); } catch (err) { /* private window */ }
    }
  }

  function restore() {
    document.querySelectorAll('.msg').forEach(function (card) {
      var edited = null;
      try { edited = localStorage.getItem(editKey(card)); } catch (err) { /* private window */ }
      if (edited) {
        setBody(card, edited);
        card.setAttribute('data-edited', '1');
        var m = document.createElement('span');
        m.className = 'edited';
        m.textContent = 'переписано';
        card.querySelector('header .meta').insertAdjacentElement('afterend', m);
      }
      // One-time migration: adopt whatever was saved under the old, layout-dependent key
      // if the new, stable key has nothing yet, then drop the old entry.
      var newKey = statusKey(card);
      var oldKey = legacyStatusKey(card);
      var current = null, legacy = null;
      try {
        current = localStorage.getItem(newKey);
        legacy = localStorage.getItem(oldKey);
        if (!current && legacy) {
          localStorage.setItem(newKey, legacy);
          localStorage.removeItem(oldKey);
          current = legacy;
        }
      } catch (err) { /* private window */ }
      var saved = current;
      if (saved === 'deleted') {
        card.setAttribute('data-status', 'deleted');
      } else if (saved === 'sent' || saved === 'draft') {
        setStatus(card, saved, false);
      }
    });
  }

  function fallbackCopy(body) {
    var range = document.createRange();
    range.selectNodeContents(body);
    var sel = window.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    try {
      document.execCommand('copy');
    } catch (err) {
      /* nothing more to try */
    }
    sel.removeAllRanges();
  }

  function flashCopied(btn) {
    var old = btn.textContent;
    btn.textContent = 'Скопировано';
    btn.classList.add('copied');
    setTimeout(function () {
      btn.textContent = old;
      btn.classList.remove('copied');
    }, 1500);
  }

  function plainText(body) {
    var paragraphs = body.querySelectorAll('p');
    var parts = [];
    (paragraphs.length ? paragraphs : [body]).forEach(function (p) {
      parts.push(p.innerText.trim());
    });
    return parts.join('\n\n');
  }

  function copyCard(card, btn) {
    var body = card.querySelector('.body');
    var paragraphs = body.querySelectorAll('p');
    // Slack and Teams turn <p> into a single line break; a blank line between paragraphs
    // needs an explicit double <br>. He always writes messages with blank lines.
    var html = paragraphs.length
      ? '<div>' + Array.prototype.map.call(paragraphs, function (p) { return p.innerHTML; }).join('<br><br>') + '</div>'
      : body.innerHTML;
    var text = plainText(body);
    if (window.ClipboardItem && navigator.clipboard && navigator.clipboard.write) {
      var item = new ClipboardItem({
        'text/html': new Blob([html], { type: 'text/html' }),
        'text/plain': new Blob([text], { type: 'text/plain' })
      });
      navigator.clipboard.write([item]).then(
        function () { flashCopied(btn); },
        function () { fallbackCopy(body); flashCopied(btn); }
      );
    } else {
      fallbackCopy(body);
      flashCopied(btn);
    }
  }

  // He rewrites nearly every draft before sending it. Until 2026-09-17 those rewrites lived only in
  // the Slack composer, so no session ever saw them and the same defects came back. Editing happens
  // here instead: the edit is POSTed to messages/edit (tasks-server.py appends it to edits.jsonl)
  // and kept in localStorage so the card still shows his wording after a reload.
  function editKey(card) { return 'msg-edit-' + hashCode(card.getAttribute('data-key') || ''); }

  function setBody(card, text) {
    var body = card.querySelector('.body');
    body.innerHTML = '';
    text.split(/\n\s*\n/).forEach(function (para) {
      var p = document.createElement('p');
      p.textContent = para.trim();
      body.appendChild(p);
    });
  }

  function openEditor(card) {
    if (card.querySelector('.editor')) { return; }
    var body = card.querySelector('.body');
    var box = document.createElement('div');
    box.className = 'editor';
    var ta = document.createElement('textarea');
    ta.value = plainText(body);
    ta.rows = Math.max(4, ta.value.split('\n').length + 2);
    box.appendChild(ta);
    var row = document.createElement('div');
    row.className = 'editor-row';
    row.innerHTML = '<button type="button" class="save-edit">Сохранить</button>' +
      '<button type="button" class="cancel-edit">Отмена</button>' +
      '<span class="hint">Правка попадёт в edits.jsonl, по ней будут правила для следующих сообщений</span>';
    box.appendChild(row);
    body.style.display = 'none';
    body.parentNode.insertBefore(box, body.nextSibling);
    ta.focus();
  }

  function closeEditor(card) {
    var box = card.querySelector('.editor');
    if (box) { box.parentNode.removeChild(box); }
    card.querySelector('.body').style.display = '';
  }

  function saveEditor(card) {
    var box = card.querySelector('.editor');
    if (!box) { return; }
    var edited = box.querySelector('textarea').value.trim();
    var original = plainText(card.querySelector('.body'));
    closeEditor(card);
    if (!edited || edited === original) { return; }
    setBody(card, edited);
    card.setAttribute('data-edited', '1');
    try { localStorage.setItem(editKey(card), edited); } catch (err) { /* private window */ }
    var mark = card.querySelector('.edited');
    if (!mark) {
      mark = document.createElement('span');
      mark.className = 'edited';
      card.querySelector('header .meta').insertAdjacentElement('afterend', mark);
    }
    mark.textContent = 'переписано';
    fetch('/messages/edit', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        to: (card.querySelector('.to') || {}).textContent || '',
        project: card.getAttribute('data-project') || '',
        key: card.getAttribute('data-key') || '',
        lang: (card.querySelector('.meta').textContent.match(/·\s*(uk|ru|en)\s*·/) || [])[1] || '',
        original: original,
        edited: edited
      })
    }).then(function (r) { if (!r.ok) { mark.textContent = 'переписано, не сохранено на диск'; } },
            function () { mark.textContent = 'переписано, не сохранено на диск'; });
  }

  document.addEventListener('click', function (e) {
    var copyBtn = e.target.closest('.copy');
    if (copyBtn) {
      copyCard(copyBtn.closest('.msg'), copyBtn);
      return;
    }
    var rwBtn = e.target.closest('.rewrite');
    if (rwBtn) { openEditor(rwBtn.closest('.msg')); return; }
    var saveBtn = e.target.closest('.save-edit');
    if (saveBtn) { saveEditor(saveBtn.closest('.msg')); return; }
    var cancelBtn = e.target.closest('.cancel-edit');
    if (cancelBtn) { closeEditor(cancelBtn.closest('.msg')); return; }
    var delBtn = e.target.closest('.del');
    if (delBtn) {
      var dc = delBtn.closest('.msg');
      setStatus(dc, 'deleted', true);
      placeCards();
      return;
    }
    var sortBtn = e.target.closest('#sortbar button');
    if (sortBtn) {
      localStorage.setItem('msg-sort', sortBtn.getAttribute('data-sort'));
      placeCards();
      return;
    }
    var sentBtn = e.target.closest('.sent');
    if (sentBtn) {
      var c = sentBtn.closest('.msg');
      setStatus(c, c.getAttribute('data-status') === 'draft' ? 'sent' : 'draft', true);
      placeCards();
    }
  });

  // One layout pass. Deleted cards vanish, sent cards go to the collapsed Архив, the rest are
  // drafts shown either as one list by time or grouped by project. Choice lives in localStorage.
  function stamp(card) {
    var ts = card.getAttribute('data-ts');
    if (ts) { return ts; }
    var m = (card.querySelector('.meta').textContent.match(/\d{4}-\d{2}-\d{2}( \d{2}:\d{2})?/) || [''])[0];
    return m;
  }

  function placeCards() {
    var main = document.getElementById('messages');
    var mode = localStorage.getItem('msg-sort') === 'project' ? 'project' : 'time';
    var bar = document.getElementById('sortbar');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'sortbar';
      bar.innerHTML = '<span>Сортировка:</span><button type="button" data-sort="time">по времени</button>' +
        '<button type="button" data-sort="project">по проектам</button>';
      main.parentNode.insertBefore(bar, main);
    }
    bar.querySelectorAll('button').forEach(function (b) {
      b.classList.toggle('on', b.getAttribute('data-sort') === mode);
    });
    var archive = document.getElementById('archive');
    if (!archive) {
      archive = document.createElement('details');
      archive.id = 'archive';
      archive.innerHTML = '<summary></summary><div class="afilter-row"><input id="afilter" type="search" placeholder="Поиск по архиву: имя, проект, слово из текста"></div><div id="archive-body"></div>';
      main.parentNode.insertBefore(archive, main.nextSibling);
    }
    var cards = Array.prototype.slice.call(document.querySelectorAll('.msg'));
    cards.forEach(function (c, i) { if (!c.hasAttribute('data-ord')) { c.setAttribute('data-ord', i); } });
    cards.sort(function (a, b) {
      var x = stamp(a), y = stamp(b);
      if (x !== y) { return x < y ? 1 : -1; }
      return a.getAttribute('data-ord') - b.getAttribute('data-ord');
    });
    main.querySelectorAll('section.project').forEach(function (s) { s.parentNode.removeChild(s); });
    var body = document.getElementById('archive-body') || archive;
    body.querySelectorAll('section.project').forEach(function (s) { s.parentNode.removeChild(s); });
    var sections = {};
    var archived = [];
    cards.forEach(function (card) {
      var st = card.getAttribute('data-status');
      card.hidden = false;
      // Nothing is ever hidden away: sent, discarded and rewritten all land in the archive,
      // because a message he cannot find again is the same as a message that was lost.
      if (st === 'sent' || st === 'deleted' || st === 'superseded') { archived.push(card); return; }
      if (mode === 'time') { main.appendChild(card); return; }
      var name = card.getAttribute('data-project') || 'без проекта';
      if (!sections[name]) {
        var section = document.createElement('section');
        section.className = 'project';
        var h = document.createElement('h2');
        h.textContent = name;
        section.appendChild(h);
        main.appendChild(section);
        sections[name] = section;
      }
      sections[name].appendChild(card);
    });
    var abuckets = {};
    archived.forEach(function (card) {
      var name = card.getAttribute('data-project') || 'без проекта';
      if (!abuckets[name]) {
        var asec = document.createElement('section');
        asec.className = 'project';
        var ah = document.createElement('h2');
        ah.textContent = name;
        asec.appendChild(ah);
        body.appendChild(asec);
        abuckets[name] = asec;
      }
      abuckets[name].appendChild(card);
    });
    Object.keys(abuckets).forEach(function (name) {
      var count = abuckets[name].querySelectorAll('.msg').length;
      abuckets[name].querySelector('h2').textContent = name + ' · ' + count;
    });
    document.querySelectorAll('.msg .sent').forEach(function (b) {
      var st = b.closest('.msg').getAttribute('data-status');
      b.textContent = (st === 'draft' || !st) ? 'Отправил' : 'Вернуть в черновики';
    });
    archive.querySelector('summary').textContent = 'Архив · ' + archived.length;
    archive.hidden = archived.length === 0;
    applyArchiveFilter();
  }

  // The archive is only useful if one message can be found in it. Filters on everything the
  // card shows: recipient, project, date and the text itself.
  function applyArchiveFilter() {
    var input = document.getElementById('afilter');
    if (!input) { return; }
    var q = input.value.trim().toLowerCase();
    var body = document.getElementById('archive-body');
    if (!body) { return; }
    body.querySelectorAll('section.project').forEach(function (sec) {
      var shown = 0;
      sec.querySelectorAll('.msg').forEach(function (card) {
        var hay = (card.getAttribute('data-project') || '') + ' ' + card.textContent;
        var hit = !q || hay.toLowerCase().indexOf(q) !== -1;
        card.hidden = !hit;
        if (hit) { shown += 1; }
      });
      sec.hidden = shown === 0;
    });
  }

  document.addEventListener('input', function (e) {
    if (e.target && e.target.id === 'afilter') { applyArchiveFilter(); }
  });

  document.querySelectorAll('.msg header').forEach(function (h) {
    // Three explicit rows, built from the elements the HTML already has, before any
    // button gets appended so each one lands in the row it belongs to.
    var titleRow = document.createElement('div');
    titleRow.className = 'hrow title';
    var metaRow = document.createElement('div');
    metaRow.className = 'hrow meta-row';
    var actionsRow = document.createElement('div');
    actionsRow.className = 'hrow actions';

    var to = h.querySelector('.to');
    var meta = h.querySelector('.meta');
    var openLink = h.querySelector('.open');
    var copyBtn = h.querySelector('.copy');
    if (to) { titleRow.appendChild(to); }
    if (meta) { metaRow.appendChild(meta); }
    if (openLink) { actionsRow.appendChild(openLink); }
    if (copyBtn) { actionsRow.appendChild(copyBtn); }

    h.appendChild(titleRow);
    h.appendChild(metaRow);
    h.appendChild(actionsRow);

    if (!h.querySelector('.sent')) {
      var b = document.createElement('button');
      b.className = 'sent';
      b.type = 'button';
      b.textContent = 'Отправил';
      actionsRow.appendChild(b);
    }
    if (!h.querySelector('.rewrite')) {
      var rw = document.createElement('button');
      rw.className = 'rewrite';
      rw.type = 'button';
      rw.textContent = 'Переписать';
      actionsRow.appendChild(rw);
    }
    var grow = document.createElement('span');
    grow.className = 'grow';
    actionsRow.appendChild(grow);
    if (!h.querySelector('.del')) {
      var x = document.createElement('button');
      x.className = 'del';
      x.type = 'button';
      x.title = 'Удалить с этой страницы';
      x.setAttribute('aria-label', 'Удалить');
      x.textContent = '\u00d7';
      actionsRow.appendChild(x);
    }
    var proj = h.parentNode.getAttribute('data-project');
    if (proj && !h.querySelector('.proj')) {
      var tag = document.createElement('span');
      tag.className = 'proj';
      tag.textContent = proj;
      titleRow.appendChild(tag);
    }
  });
  restore();
  placeCards();
})();
