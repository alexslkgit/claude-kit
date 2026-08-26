#!/usr/bin/env node
/* render-body.js — bakes a board's rendered body and its stylesheet into the board file itself.
 *
 * Why this exists. The board page is one <script type="application/json" id="board"> block; the
 * whole body is drawn at load time by the sibling _shell/board.js. When he clicks the board link
 * in a chat, the Claude Code desktop app opens the page in its own pane, and that pane renders
 * the HTML but does NOT resolve the page's sibling subresources: board.js never runs, board.css
 * never loads, and he sees a blank white page. Proved 2026-08-26: headless Chrome over file://
 * renders the same file fully (28 423 characters of body, both _shell files 200), and the two
 * boards on this Mac that happen to be written as inline markup with an inline <style> are
 * exactly the two that do render in the pane.
 *
 * So the file gets the rendered body written INTO it, after the tool call, by a hook. The agent
 * writing a board still writes only the JSON block — that is the whole point, and the rendered
 * markup never enters any conversation's context. board.css is inlined in the same pass, because
 * a rendered board with no stylesheet is barely better than a blank one.
 *
 * Both inlined blocks are progressive-enhancement leftovers, not the source of truth:
 *   · the <style> is emitted BEFORE the <link>, so in a real browser the fresh _shell/board.css
 *     wins the cascade and "restyle the shell, restyle every board" still holds;
 *   · <script src="_shell/board.js"> stays in the page, and when it does run it replaces
 *     document.body wholesale, so the baked markup is simply overwritten by the live render and
 *     the 15-second self-refresh keeps working untouched.
 *
 * The markup comes from board.js's own `build`, run under node behind the DOM shim below, so the
 * pane and the browser can never disagree about what the board says.
 *
 *     node render-body.js <board>.html        rewrites the file in place, idempotently
 *     node render-body.js --check <board>.html  renders and reports, writes nothing
 *
 * Exit 0 only when the file was rewritten (or was already up to date). ANY other outcome — not a
 * board, broken JSON, missing _shell, a renderer that threw — exits non-zero with a reason on
 * stderr and leaves the file byte-for-byte as it was. hooks/board-inline.sh swallows that.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const BODY_OPEN = '<!--board-inline-->';
const BODY_CLOSE = '<!--/board-inline-->';
const STYLE_OPEN = '<!--board-inline-style-->';
const STYLE_CLOSE = '<!--/board-inline-style-->';

function die(msg) {
  process.stderr.write('render-body: ' + msg + '\n');
  process.exit(1);
}

/* ------------------------------------------------------------------ the DOM shim
   board.js is a browser file and runs top to bottom on load: it looks for the JSON block, sets a
   theme attribute on <html>, reads localStorage, arms a MutationObserver and a 15-second
   setInterval. None of that may throw here and none of it may keep node alive. Everything below
   is a stub that answers "nothing" — getElementById returns null so board.js does NOT self-draw,
   and we call the exported build() ourselves with the JSON we parsed. */
function loadRenderer(boardJsPath) {
  const stub = {
    innerHTML: '',
    tagName: 'DIV',
    id: '',
    open: false,
    classList: { toggle() {}, add() {}, remove() {}, contains() { return false; } },
    setAttribute() {}, removeAttribute() {}, getAttribute() { return null; },
    addEventListener() {}, removeEventListener() {},
    querySelectorAll() { return []; }, querySelector() { return null; },
    closest() { return null; }, appendChild() {},
  };
  const sandbox = {
    module: { exports: {} },
    console: { log() {}, warn() {}, error() {} },
    setInterval() { return 0; }, clearInterval() {},
    setTimeout() { return 0; }, clearTimeout() {},
    fetch() { return Promise.resolve({ text() { return Promise.resolve(''); } }); },
    location: { href: '' },
    DOMParser: function () { this.parseFromString = function () { return { body: null, getElementById() { return null; } }; }; },
    MutationObserver: function () { return { observe() {}, disconnect() {} }; },
    localStorage: { getItem() { return null; }, setItem() {}, removeItem() {} },
    document: {
      body: stub,
      documentElement: stub,
      getElementById() { return null; },
      querySelectorAll() { return []; },
      querySelector() { return null; },
      createElement() { return stub; },
      addEventListener() {}, removeEventListener() {},
    },
  };
  sandbox.window = sandbox;
  sandbox.self = sandbox;
  sandbox.globalThis = sandbox;
  vm.createContext(sandbox);
  vm.runInContext(fs.readFileSync(boardJsPath, 'utf8'), sandbox, { filename: boardJsPath, timeout: 5000 });
  const build = sandbox.module.exports && sandbox.module.exports.build;
  if (typeof build !== 'function') {
    die(boardJsPath + ' exports no build(); it predates the node entry point — re-copy the shell');
  }
  return build;
}

/* ------------------------------------------------------------------ locating the pieces */
const JSON_BLOCK = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;

function findJsonBlock(src) {
  JSON_BLOCK.lastIndex = 0;
  let m;
  while ((m = JSON_BLOCK.exec(src)) !== null) {
    const attrs = m[1];
    if (!/application\/json/i.test(attrs)) continue;
    if (!/\bid\s*=\s*["']?board["']?/i.test(attrs)) continue;
    return { json: m[2], end: m.index + m[0].length };
  }
  return null;
}

// The href the page itself uses, so the inlined copy is the same file the browser would fetch.
function shellHref(src, dir, tag, attr, file) {
  const re = new RegExp('<' + tag + '\\b[^>]*\\b' + attr + '\\s*=\\s*"([^"]*' + file.replace('.', '\\.') + ')"[^>]*>', 'i');
  const m = src.match(re);
  return {
    resolved: path.resolve(dir, m ? m[1] : '_shell/' + file),
    tagStart: m ? src.indexOf(m[0]) : -1,
  };
}

// Both blocks are written as "\n<open>\n … \n<close>\n", so removing them means taking the
// newline on each side back out too. Get that wrong by one character and every rewrite either
// grows the file by a blank line or eats the newline before <link>.
function stripMarkers(src, open, close) {
  const a = src.indexOf(open);
  if (a === -1) return src;
  const b = src.indexOf(close, a);
  if (b === -1) return src;
  let end = b + close.length;
  if (src[end] === '\n') end += 1;
  let start = a;
  if (start > 0 && src[start - 1] === '\n') start -= 1;
  return src.slice(0, start) + src.slice(end);
}

/* ------------------------------------------------------------------ main */
const args = process.argv.slice(2);
const checkOnly = args[0] === '--check';
const file = checkOnly ? args[1] : args[0];
if (!file) die('usage: render-body.js [--check] <board>.html');

let src;
try { src = fs.readFileSync(file, 'utf8'); } catch (e) { die('cannot read ' + file + ': ' + e.message); }

// Idempotency: everything below is computed against the file WITHOUT any block this tool added
// before, so running it twice produces the same bytes and running it on a rewritten board does
// not stack a second copy.
const bare = stripMarkers(stripMarkers(src, STYLE_OPEN, STYLE_CLOSE), BODY_OPEN, BODY_CLOSE);

const block = findJsonBlock(bare);
if (!block) die(file + ' carries no <script type="application/json" id="board"> block — not a board');

let data;
try { data = JSON.parse(block.json); } catch (e) { die(file + ': the board JSON does not parse (' + e.message + ')'); }
if (!data || typeof data !== 'object' || !Array.isArray(data.tasks)) {
  die(file + ': the board JSON has no tasks array; the renderer would throw');
}

const dir = path.dirname(path.resolve(file));
const css = shellHref(bare, dir, 'link', 'href', 'board.css');
const js = shellHref(bare, dir, 'script', 'src', 'board.js');
if (!fs.existsSync(js.resolved)) die('no renderer at ' + js.resolved + ' — the _shell is missing');
if (!fs.existsSync(css.resolved)) die('no stylesheet at ' + css.resolved + ' — the _shell is missing');
if (css.tagStart === -1) die(file + ' does not link board.css; there is nowhere to put the inline copy');

const build = loadRenderer(js.resolved);
let body;
try { body = build(data); } catch (e) { die(file + ': the renderer threw (' + e.message + ')'); }
if (typeof body !== 'string' || body.indexOf('<main') === -1) {
  die(file + ': the renderer produced no <main>; refusing to write');
}

let sheet;
try { sheet = fs.readFileSync(css.resolved, 'utf8'); } catch (e) { die('cannot read ' + css.resolved + ': ' + e.message); }
// A stylesheet that closes its own tag would break out of the <style> element and eat the page.
if (/<\/style/i.test(sheet)) die(css.resolved + ' contains </style; refusing to inline it');
if (/<\/style/i.test(body) || /<script/i.test(body)) die(file + ': the rendered body carries a tag it must not; refusing to write');

const styleBlock = '\n' + STYLE_OPEN + '\n<style>\n' + sheet.replace(/\s*$/, '') + '\n</style>\n' + STYLE_CLOSE + '\n';
const bodyBlock = '\n' + BODY_OPEN + '\n' + body + '\n' + BODY_CLOSE + '\n';

// The <link> sits in <head>, before the JSON block in <body>, so both offsets are taken from
// `bare` and the head splice is applied first only in the sense that its offset is the smaller
// one. Splice the body first and the link offset would still be valid — but only by luck, so do
// the head first and shift the body offset by what the head splice added.
if (css.tagStart >= block.end) die(file + ': the board.css link sits after the JSON block; refusing to guess');
const withStyle = bare.slice(0, css.tagStart) + styleBlock + bare.slice(css.tagStart);
const bodyEnd = block.end + (withStyle.length - bare.length);
const out = withStyle.slice(0, bodyEnd) + bodyBlock + withStyle.slice(bodyEnd);

if (checkOnly) {
  process.stdout.write(path.basename(file) + ': body ' + body.length + ' chars, css ' + sheet.length + ' chars (nothing written)\n');
  process.exit(0);
}

if (out === src) {
  process.stdout.write(path.basename(file) + ': already inlined, unchanged\n');
  process.exit(0);
}

// Atomic: a crash mid-write must never leave him a truncated board. Same directory, so rename()
// stays inside one filesystem.
const tmp = path.join(dir, '.' + path.basename(file) + '.board-inline.' + process.pid);
try {
  fs.writeFileSync(tmp, out, 'utf8');
  const mode = fs.statSync(file).mode;
  fs.chmodSync(tmp, mode & 0o7777);
  fs.renameSync(tmp, file);
} catch (e) {
  try { fs.unlinkSync(tmp); } catch (e2) { /* nothing to clean up */ }
  die('cannot write ' + file + ': ' + e.message);
}
process.stdout.write(path.basename(file) + ': inlined ' + body.length + ' chars of body and ' + sheet.length + ' chars of css\n');
