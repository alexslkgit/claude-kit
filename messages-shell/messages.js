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
      var saved = localStorage.getItem(statusKey(card));
      if (saved === 'sent' || saved === 'draft') {
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

  document.addEventListener('click', function (e) {
    var copyBtn = e.target.closest('.copy');
    if (copyBtn) {
      copyCard(copyBtn.closest('.msg'), copyBtn);
      return;
    }
    var sentBtn = e.target.closest('.sent');
    if (sentBtn) {
      var c = sentBtn.closest('.msg');
      setStatus(c, c.getAttribute('data-status') === 'sent' ? 'draft' : 'sent', true);
      placeCards();
    }
  });

  // Sent cards leave the project sections and collect under a collapsed Архив at the bottom,
  // so the page shows only what is still to be sent. Status lives in localStorage per card.
  function placeCards() {
    var main = document.getElementById('messages');
    var archive = document.getElementById('archive');
    if (!archive) {
      archive = document.createElement('details');
      archive.id = 'archive';
      archive.innerHTML = '<summary></summary>';
      main.parentNode.insertBefore(archive, main.nextSibling);
    }
    document.querySelectorAll('.msg').forEach(function (card) {
      var sent = card.getAttribute('data-status') === 'sent';
      var inArchive = card.parentNode === archive;
      if (sent && !inArchive) {
        archive.appendChild(card);
      } else if (!sent && inArchive) {
        var section = sectionFor(card.getAttribute('data-project') || 'без проекта');
        section.appendChild(card);
      }
    });
    document.querySelectorAll('section.project').forEach(function (sec) {
      sec.hidden = !sec.querySelector('.msg');
    });
    var n = archive.querySelectorAll('.msg').length;
    archive.querySelector('summary').textContent = 'Архив · ' + n;
    archive.hidden = n === 0;
  }

  function sectionFor(name) {
    var main = document.getElementById('messages');
    var found = null;
    main.querySelectorAll('section.project').forEach(function (sec) {
      if (sec.querySelector('h2').textContent === name) { found = sec; }
    });
    if (found) { return found; }
    var section = document.createElement('section');
    section.className = 'project';
    var h = document.createElement('h2');
    h.textContent = name;
    section.appendChild(h);
    main.appendChild(section);
    return section;
  }

  function groupByProject() {
    var main = document.getElementById('messages');
    if (!main) { return; }
    var cards = Array.prototype.slice.call(main.querySelectorAll('.msg'));
    if (!cards.some(function (c) { return c.getAttribute('data-project'); })) { return; }
    var order = [], groups = {};
    cards.forEach(function (card) {
      var name = card.getAttribute('data-project') || 'без проекта';
      if (!groups[name]) { groups[name] = []; order.push(name); }
      groups[name].push(card);
    });
    order.forEach(function (name) {
      var section = document.createElement('section');
      section.className = 'project';
      var h = document.createElement('h2');
      h.textContent = name;
      section.appendChild(h);
      groups[name].forEach(function (card) { section.appendChild(card); });
      main.appendChild(section);
    });
  }

  document.querySelectorAll('.msg header').forEach(function (h) {
    if (!h.querySelector('.sent')) {
      var b = document.createElement('button');
      b.className = 'sent';
      b.type = 'button';
      b.textContent = 'Отправил';
      h.appendChild(b);
    }
  });
  groupByProject();
  restore();
  placeCards();
})();
