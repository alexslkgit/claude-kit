/* brief.js — the whole behaviour of a company brief: the `не нашёл` row and section
   removal, the pills, the top navigation. Brief pages link it and carry no script. */

(function () {
var TAGS = { '+': ['ok', 'подтверждено'], '~': ['maybe', 'правдоподобно'], '?': ['guess', 'догадка'] };

function missing(txt) {
  return !txt.replace(/не нашёл|не нашел|нет данных/gi, '')
             .replace(/подтверждено|правдоподобно|догадка/g, '')
             .replace(/[—–\-·:,.\s]/g, '');
}

// "+ ", "~ " or "? " at the start of a value becomes the confidence pill.
document.querySelectorAll('.row > span, .body > p, .body li, .box').forEach(function (el) {
  var lbl = el.querySelector(':scope > .lbl');
  var node = lbl ? lbl.nextSibling : el.firstChild;
  while (node && node.nodeType === 3 && !node.nodeValue.trim()) node = node.nextSibling;
  if (!node || node.nodeType !== 3) return;
  var m = node.nodeValue.match(/^\s*([+~?])\s+/);
  if (!m) return;
  node.nodeValue = node.nodeValue.slice(m[0].length);
  var t = TAGS[m[1]], pill = document.createElement('span');
  pill.className = 'tag ' + t[0];
  pill.textContent = t[1];
  el.insertBefore(pill, el.firstChild);
});

// Anything optional with no data removes itself rather than printing "не нашёл".
document.querySelectorAll('.opt').forEach(function (el) {
  var lbl = el.querySelector(':scope > .lbl');
  var src = el.querySelector(':scope > span:last-child') || el;
  var txt = src.textContent;
  if (src === el && lbl) txt = txt.replace(lbl.textContent, '');
  if (missing(txt)) el.remove();
});
document.querySelectorAll('.body ul, .body ol').forEach(function (u) {
  if (!u.children.length) u.remove();
});
document.querySelectorAll('details.sec').forEach(function (d) {
  if (!d.querySelector('.body').textContent.replace(/\s+/g, '')) d.remove();
});

// The stage bar exists only while a process is actually running.
var sb = document.querySelector('.stages');
if (sb) {
  var names = (sb.dataset.stages || '').split('|').map(function (s) { return s.trim(); })
    .filter(function (s) { return s && !missing(s); });
  var now = parseInt(sb.dataset.now, 10);
  if (names.length < 2 || !now) {
    var box = document.getElementById('stagebox');
    if (box) box.remove();
  } else {
    names.forEach(function (n, i) {
      var d = document.createElement('div');
      d.className = i + 1 < now ? 'past' : (i + 1 === now ? 'now' : '');
      d.innerHTML = '<i></i>';
      d.appendChild(document.createTextNode(n));
      sb.appendChild(d);
    });
  }
}

// Fit score paints its own bar.
var sc = document.querySelector('.score b');
if (sc) {
  var n = parseInt(sc.dataset.score, 10);
  if (isNaN(n)) { sc.closest('.box').remove(); }
  else { document.querySelector('.score .bar i').style.width = n + '%'; }
}

// Striking a line out: grey, struck through, moved to the end of its own list.
// Kept in localStorage so his edits survive a reload of the same brief.
var KEY = 'brief:' + location.pathname;
var off = {};
try { off = JSON.parse(localStorage.getItem(KEY) || '{}'); } catch (e) {}
function save() {
  try { localStorage.setItem(KEY, JSON.stringify(off)); } catch (e) {}
}
document.querySelectorAll('ul.x, ol.x').forEach(function (list) {
  Array.prototype.slice.call(list.children).forEach(function (li) {
    var id = li.textContent.trim().slice(0, 60);
    if (off[id]) { li.classList.add('off'); list.appendChild(li); }
    li.addEventListener('click', function () {
      if (li.classList.contains('off')) {
        li.classList.remove('off');
        delete off[id];
      } else {
        li.classList.add('off');
        list.appendChild(li);
        off[id] = 1;
      }
      save();
    });
  });
});

// One control, not a row of chips: he asked for the chips to go.
var all = document.getElementById('all');
all.addEventListener('click', function () {
  var open = all.textContent === 'развернуть всё';
  document.querySelectorAll('details.sec').forEach(function (d) { d.open = open; });
  all.textContent = open ? 'свернуть всё' : 'развернуть всё';
});

// Theme: auto, then forced light, then forced dark.
var root = document.documentElement, modes = ['', 'light', 'dark'], icons = ['◐', '☀', '☾'], i = 0;
document.getElementById('theme').addEventListener('click', function () {
  i = (i + 1) % 3;
  if (modes[i]) root.setAttribute('data-theme', modes[i]); else root.removeAttribute('data-theme');
  this.textContent = icons[i];
});

document.querySelectorAll('.say button').forEach(function (b) {
  b.addEventListener('click', function () {
    navigator.clipboard.writeText(b.nextElementSibling.textContent).then(function () {
      b.textContent = 'скопировано';
      setTimeout(function () { b.textContent = 'копировать'; }, 1500);
    });
  });
});
})();
