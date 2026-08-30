#!/usr/bin/env python3
"""prerender-page.py - bake a data-only board or plan page into a real static page.

SHELL-GUARD-EXEMPT. This is the renderer, not a page. It is the one place allowed to emit
a stylesheet and a script into a file, and it does so from the shell on disk, never from
an agent's context, so the token argument behind shell-guard is untouched.

Why this exists
---------------
A board carries only <script type="application/json" id="board"> plus a link to the shared
_shell/ renderer. That is deliberate and cheap. But it means <body> is empty until
JavaScript runs, and the Claude Code side panel renders a local file as a static data:
snapshot with scripts DISABLED. The result is a correct <title> over a blank white page,
on every Mac, in every session. Measured 2026-08-28: a hand written static page renders in
that pane, the same page's JSON+renderer form does not.

The fix is not to abandon the JSON shell. It is to run the SAME renderer here, at write
time, and bake its output into the file. One renderer, no duplicated logic, no drift.

Output shape, and it is idempotent because the baked block is delimited:

  <style> shell css </style>              the snapshot cannot fetch _shell/ either
  <body>
    <!--BAKED--> rendered markup <!--/BAKED-->    what the side panel shows
    <script type="application/json" id="board">   still the source of truth
    <script> shell js </script>                   live refresh when served over http

    python3 ~/.claude/tools/prerender-page.py page.html [more.html ...]
"""
import hashlib, json, os, re, subprocess, sys, tempfile

HOME = os.path.expanduser("~")
KINDS = {
    "board": ("board.css", "board.js", os.path.join(HOME, ".claude", "board-shell")),
    "plan": ("plan.css", "plan.js", os.path.join(HOME, ".claude", "plan-shell")),
}

# A DOM small enough to read in one screen and large enough for the shell renderers, which
# only ever read the JSON block and assign document.body.innerHTML.
STUB = r"""
ObjC.import('Foundation');

/* A DOM just large enough for the two shell renderers, and serialisable, because board.js
   assigns document.body.innerHTML while plan.js builds nodes with appendChild. */
var __VOID = { img: 1, br: 1, hr: 1, input: 1, meta: 1, link: 1, source: 1 };
function __attr(v) { return String(v).replace(/&/g, '&amp;').replace(/"/g, '&quot;'); }
function __esc(v) { return String(v).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;'); }
function __el(tag) {
  var n = { tag: (tag || 'div').toLowerCase(), className: '', id: '', _a: {}, _k: [], _h: null, _t: null,
            style: {}, dataset: {}, checked: false, open: false, value: '', children: [] };
  n.classList = {
    add: function () { for (var i = 0; i < arguments.length; i++) { if ((' ' + n.className + ' ').indexOf(' ' + arguments[i] + ' ') < 0) { n.className = (n.className + ' ' + arguments[i]).trim(); } } },
    remove: function () { for (var i = 0; i < arguments.length; i++) { n.className = (' ' + n.className + ' ').split(' ' + arguments[i] + ' ').join(' ').trim(); } },
    toggle: function (c, f) { if (f === undefined) { f = !n.classList.contains(c); } if (f) { n.classList.add(c); } else { n.classList.remove(c); } return f; },
    contains: function (c) { return (' ' + n.className + ' ').indexOf(' ' + c + ' ') >= 0; }
  };
  n.setAttribute = function (k, v) { if (k === 'class') { n.className = v; } else if (k === 'id') { n.id = v; } else { n._a[k] = v; } };
  n.getAttribute = function (k) { return k === 'class' ? n.className : (k === 'id' ? n.id : (n._a[k] !== undefined ? n._a[k] : null)); };
  n.removeAttribute = function (k) { delete n._a[k]; };
  n.appendChild = function (c) { n._k.push(c); n.children.push(c); return c; };
  n.append = function () { for (var i = 0; i < arguments.length; i++) { n.appendChild(arguments[i]); } };
  n.insertBefore = function (c) { n._k.unshift(c); return c; };
  n.addEventListener = function () {}; n.removeEventListener = function () {};
  n.remove = function () {}; n.focus = function () {}; n.scrollIntoView = function () {};
  n.querySelector = function () { return null; }; n.querySelectorAll = function () { return []; };
  n.closest = function () { return null; }; n.contains = function () { return false; };
  Object.defineProperty(n, 'innerHTML', { get: function () { return n._h != null ? n._h : n._k.map(__ser).join(''); },
                                          set: function (v) { n._h = v; n._t = null; n._k = []; n.children = []; } });
  Object.defineProperty(n, 'textContent', { get: function () { return n._t != null ? n._t : ''; },
                                            set: function (v) { n._t = v; n._h = null; n._k = []; n.children = []; } });
  Object.defineProperty(n, 'tagName', { get: function () { return n.tag.toUpperCase(); } });
  // Real DOM elements carry both childNodes (all nodes) and children (elements only); this
  // stub only ever appends via appendChild into _k, so the two coincide and childNodes can
  // simply mirror _k live. plan.js reads row.childNodes.length; board.js never touches it.
  Object.defineProperty(n, 'childNodes', { get: function () { return n._k; } });
  return n;
}
function __ser(n) {
  if (n == null) { return ''; }
  if (typeof n === 'string') { return n; }
  if (n.tag === '#text') { return __esc(n._t); }
  var a = '';
  if (n.className) { a += ' class="' + __attr(n.className) + '"'; }
  if (n.id) { a += ' id="' + __attr(n.id) + '"'; }
  for (var k in n._a) { a += ' ' + k + '="' + __attr(n._a[k]) + '"'; }
  if (n.open) { a += ' open'; }
  if (__VOID[n.tag]) { return '<' + n.tag + a + '>'; }
  var inner = n._h != null ? n._h : (n._t != null ? __esc(n._t) : n._k.map(__ser).join(''));
  return '<' + n.tag + a + '>' + inner + '</' + n.tag + '>';
}

var body = __el('body');
var document = {
  body: body,
  readyState: 'complete',
  documentElement: __el('html'),
  getElementById: function (id) { return (id === '%KIND%') ? { textContent: __json } : null; },
  querySelectorAll: function () { return []; },
  querySelector: function () { return null; },
  addEventListener: function () {},
  createElement: function (t) { return __el(t); },
  createTextNode: function (t) { var e = __el('#text'); e._t = String(t); return e; },
  createDocumentFragment: function () { return __el('#frag'); }
};
var window = { addEventListener: function () {}, removeEventListener: function () {},
  scrollY: 0, scrollX: 0, scrollTo: function () {}, innerWidth: 1200, innerHeight: 900,
  matchMedia: function () { return { matches: false, addListener: function () {}, addEventListener: function () {} }; },
  getComputedStyle: function () { return { getPropertyValue: function () { return ''; } }; } };
var localStorage = { getItem: function () { return null; }, setItem: function () {}, removeItem: function () {} };
var sessionStorage = { getItem: function () { return null; }, setItem: function () {}, removeItem: function () {} };
function MutationObserver(cb) { this.observe = function () {}; this.disconnect = function () {}; }
function setInterval() { return 0; }
function setTimeout() { return 0; }
function clearTimeout() {}
function clearInterval() {}
function requestAnimationFrame() { return 0; }
var location = { href: '', pathname: '/page.html', search: '', hash: '' };
function fetch() { return { then: function () { return this; }, catch: function () { return this; } }; }
function DOMParser() { this.parseFromString = function () { return { body: null, getElementById: function () { return null; } }; }; }
"""

TAIL = r"""
var __out = body.innerHTML;
$.NSString.alloc.initWithUTF8String(__out)
  .writeToFileAtomicallyEncodingError($('%OUT%'), true, $.NSUTF8StringEncoding, $());
"""


def detect_kind(html):
    for kind in KINDS:
        if re.search(r'type="application/json"[^>]*id="%s"' % kind, html):
            return kind
    return None


def shell_dir(path, kind):
    """Prefer the copy sitting next to the page, fall back to the kit's installed one."""
    css, js, installed = KINDS[kind]
    local = os.path.join(os.path.dirname(os.path.abspath(path)), "_shell")
    if os.path.exists(os.path.join(local, css)) and os.path.exists(os.path.join(local, js)):
        return local
    if os.path.exists(os.path.join(installed, css)):
        return installed
    return None


def render(payload, js_source, kind):
    """Run the real shell renderer under JavaScriptCore, capture document.body.innerHTML."""
    fd, out_path = tempfile.mkstemp(suffix=".html")
    os.close(fd)
    script = ("var __json = " + json.dumps(payload) + ";\n"
              + STUB.replace("%KIND%", kind) + "\n"
              + js_source + "\n"
              + TAIL.replace("%OUT%", out_path))
    try:
        r = subprocess.run(["osascript", "-l", "JavaScript", "-e", script],
                           capture_output=True, text=True, timeout=60)
        with open(out_path, encoding="utf-8") as f:
            markup = f.read()
        if not markup.strip():
            sys.stderr.write("prerender: renderer produced nothing. "
                             + r.stderr.strip()[:500] + "\n")
            return None
        return markup
    finally:
        os.path.exists(out_path) and os.unlink(out_path)


# Removed before the live renderer runs, so the baked snapshot never doubles up.
DROP = ("(function(){var b=document.getElementById('__baked');"
        "if(b&&b.parentNode){b.parentNode.removeChild(b);}})();\n")


def bake(path):
    with open(path, encoding="utf-8") as f:
        html = f.read()
    kind = detect_kind(html)
    if not kind:
        return None, "not a data page"
    m = re.search(r'<script[^>]*id="%s"[^>]*>(.*?)</script>' % kind, html, re.S)
    if not m:
        return False, "no json block"
    sd = shell_dir(path, kind)
    if not sd:
        return False, "no _shell beside the page and none installed"
    css_name, js_name, _ = KINDS[kind]
    css = open(os.path.join(sd, css_name), encoding="utf-8").read().strip()
    js = open(os.path.join(sd, js_name), encoding="utf-8").read().strip()

    stamp = hashlib.sha256((m.group(1) + css + js).encode("utf-8")).hexdigest()[:16]
    if ("<!--BAKED %s-->" % stamp) in html and "--force" not in sys.argv:
        return None, "unchanged"

    markup = render(m.group(1), js, kind)
    if markup is None:
        return False, "renderer failed"

    # Strip what a previous run put in, so this is idempotent.
    html = re.sub(r'<!--BAKED[^>]*-->.*?<!--/BAKED-->\s*', "", html, flags=re.S)
    html = re.sub(r'<style data-shell>.*?</style>\s*', "", html, flags=re.S)
    html = re.sub(r'<script data-shell>.*?</script>\s*', "", html, flags=re.S)
    # Drop the external links; the snapshot cannot follow them anyway.
    html = re.sub(r'<link[^>]*href="_shell/[^"]+"[^>]*>\s*', "", html)
    html = re.sub(r'<script[^>]*src="_shell/[^"]+"[^>]*>\s*</script>\s*', "", html)

    html = html.replace("</head>", "<style data-shell>\n" + css + "\n</style>\n</head>", 1)
    html = re.sub(r'(<body[^>]*>)',
                  lambda mm: mm.group(1) + "\n<!--BAKED " + stamp + "-->\n<div id=\"__baked\">" + markup + "</div>\n<!--/BAKED-->\n",
                  html, count=1)
    html = html.replace("</body>",
                        "<script data-shell>\n" + DROP + js + "\n</script>\n</body>", 1)

    with open(path, "w", encoding="utf-8") as f:
        f.write(html)
    return True, "baked %d chars of %s markup" % (len(markup), kind)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("usage: prerender-page.py <page.html> [more.html ...]")
    bad = 0
    for p in [a for a in sys.argv[1:] if not a.startswith("--")]:
        ok, why = bake(p)
        if ok is None:
            continue
        print(("  ok   " if ok else "  FAIL ") + os.path.basename(p) + ": " + why)
        if not ok:
            bad = 1
    sys.exit(bad)
