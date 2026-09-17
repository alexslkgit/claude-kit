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
    var body = card.querySelector('.body');
    return 'msg-status-' + hashCode(body.innerText);
  }

  function setStatus(card, status, persist) {
    card.setAttribute('data-status', status);
    var word = status === 'sent' ? 'отправлено' : 'черновик';
    var statusEl = card.querySelector('.status');
    if (statusEl) {
      statusEl.textContent = word;
    } else {
      var meta = card.querySelector('.meta');
      meta.textContent = meta.textContent.replace(/(черновик|отправлено)\s*$/, word);
    }
    if (persist !== false) {
      localStorage.setItem(statusKey(card), status);
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
      var saved = localStorage.getItem(statusKey(card));
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
      localStorage.setItem(statusKey(dc), 'deleted');
      dc.setAttribute('data-status', 'deleted');
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
      setStatus(c, c.getAttribute('data-status') === 'sent' ? 'draft' : 'sent', true);
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
      archive.innerHTML = '<summary></summary>';
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
    var sections = {};
    cards.forEach(function (card) {
      var st = card.getAttribute('data-status');
      card.hidden = st === 'deleted';
      if (st === 'deleted') { return; }
      if (st === 'sent') { archive.appendChild(card); return; }
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
    var n = archive.querySelectorAll('.msg:not([hidden])').length;
    archive.querySelector('summary').textContent = 'Архив · ' + n;
    archive.hidden = n === 0;
  }

  document.querySelectorAll('.msg header').forEach(function (h) {
    if (!h.querySelector('.sent')) {
      var b = document.createElement('button');
      b.className = 'sent';
      b.type = 'button';
      b.textContent = 'Отправил';
      h.appendChild(b);
    }
    if (!h.querySelector('.rewrite')) {
      var rw = document.createElement('button');
      rw.className = 'rewrite';
      rw.type = 'button';
      rw.textContent = 'Переписать';
      h.appendChild(rw);
    }
    if (!h.querySelector('.del')) {
      var x = document.createElement('button');
      x.className = 'del';
      x.type = 'button';
      x.title = 'Удалить с этой страницы';
      x.setAttribute('aria-label', 'Удалить');
      x.textContent = '\u00d7';
      h.appendChild(x);
    }
    var proj = h.parentNode.getAttribute('data-project');
    if (proj && !h.querySelector('.proj')) {
      var tag = document.createElement('span');
      tag.className = 'proj';
      tag.textContent = proj;
      h.querySelector('.meta').insertAdjacentElement('afterend', tag);
    }
  });
  restore();
  placeCards();
})();
