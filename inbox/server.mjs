// The owner's queue. One page, every session on this machine, one click each.
//
// Extension over the SDLC playbook, ruled as Y-002: the article disperses approvals
// across stage gates and never gathers them. This gathers them, and the click goes
// back to the waiting session instead of stopping at the screen.
//
//   node ~/Developer/claude-kit/inbox/server.mjs      →  http://localhost:7654

import { createServer } from 'node:http';
import { readdir, readFile, writeFile, unlink } from 'node:fs/promises';
import { join } from 'node:path';
import { homedir } from 'node:os';

const IN = join(homedir(), '.claude', 'inbox');
const PORT = 7654;

const readJSON = async (p) => { try { return JSON.parse(await readFile(p, 'utf8')); } catch { return null; } };

async function pending() {
  let names = [];
  try { names = await readdir(join(IN, 'queue')); } catch { return []; }
  const out = [];
  for (const n of names.filter((n) => n.endsWith('.json'))) {
    const r = await readJSON(join(IN, 'queue', n));
    if (r) out.push(r);
  }
  return out.sort((a, b) => String(a.created).localeCompare(String(b.created)));
}

async function answer(id, value) {
  await writeFile(join(IN, 'answers', `${id}.json`),
    JSON.stringify({ id, answer: value, at: new Date().toISOString() }, null, 1));
  try { await unlink(join(IN, 'queue', `${id}.json`)); } catch {}
}

const PAGE = `<!DOCTYPE html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Что ждёт тебя</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Commissioner:wght@400;500;600;700&family=Literata:opsz,wght@7..72,400;7..72,600&display=swap">
<style>
:root{--bg:#FDFCF9;--fg:#23211E;--muted:#6E675C;--line:#E7E0D0;--card:#FFF;
--accent:#9A6207;--ok:#4B7A57;--btn-bg:#23211E;--btn-fg:#FDFCF9;color-scheme:light}
@media(prefers-color-scheme:dark){:root:not([data-theme="light"]){--bg:#1A1917;--fg:#EDE8DE;
--muted:#9C9486;--line:#332F2A;--card:#232120;--btn-bg:#EDE8DE;--btn-fg:#1A1917}}
*{box-sizing:border-box}
body{margin:0;padding:32px 20px 80px;background:var(--bg);color:var(--fg);
font:400 16px/1.55 Commissioner,system-ui,sans-serif}
.wrap{max-width:760px;margin:0 auto}
h1{font:600 15px/1 Commissioner,sans-serif;letter-spacing:.14em;text-transform:uppercase;
color:var(--muted);margin:0 0 4px}
.count{font:700 44px/1.1 Literata,Georgia,serif;margin:0 0 28px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;
padding:18px 20px;margin:0 0 14px}
.meta{font-size:12.5px;color:var(--muted);letter-spacing:.04em;margin-bottom:6px}
.t{font:600 19px/1.35 Literata,Georgia,serif;margin:0 0 6px}
.why{color:var(--muted);font-size:15px;margin:0 0 14px}
.row{display:flex;gap:8px;flex-wrap:wrap;align-items:center}
button{font:500 14.5px Commissioner,sans-serif;padding:8px 16px;border-radius:9px;
border:1px solid var(--line);background:transparent;color:var(--fg);cursor:pointer}
button.p{background:var(--btn-bg);color:var(--btn-fg);border-color:var(--btn-bg)}
button:hover{opacity:.85}
code{font-size:13px;background:rgba(154,98,7,.09);color:var(--accent);
padding:3px 7px;border-radius:6px;word-break:break-all}
.empty{color:var(--muted);font-size:17px;padding:40px 0;font-family:Literata,Georgia,serif}
.foot{margin-top:34px;font-size:12.5px;color:var(--muted)}
</style></head><body><div class="wrap">
<h1>Ждёт тебя</h1><div class="count" id="n">…</div><div id="list"></div>
<div class="foot">Страница сама обновляется. Любая сессия на этом маке кладёт сюда то, что уперлось в тебя, и твой клик возвращается в неё и снимает блокировку.</div>
</div><script>
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
async function load(){
 const r=await fetch('/api/pending'),items=await r.json();
 document.getElementById('n').textContent=items.length||'ничего';
 document.getElementById('list').innerHTML=items.length?items.map(i=>\`
  <div class="card">
   <div class="meta">\${esc(i.project)}\${i.session?' · '+esc(i.session):''} · \${esc((i.created||'').slice(0,16).replace('T',', '))}</div>
   <div class="t">\${esc(i.title)}</div>
   \${i.why?'<p class="why">'+esc(i.why)+'</p>':''}
   \${i.open?'<p class="why"><code>'+esc(i.open)+'</code></p>':''}
   <div class="row">\${(i.options||['Да','Нет']).map((o,k)=>
     '<button class="'+(k===0?'p':'')+'" onclick="say(\\''+esc(i.id)+'\\',\\''+esc(o)+'\\')">'+esc(o)+'</button>').join('')}
   </div></div>\`).join(''):'<div class="empty">Пусто. Ни одна сессия сейчас тебя не ждёт.</div>';
}
async function say(id,value){
 await fetch('/api/answer',{method:'POST',headers:{'content-type':'application/json'},
  body:JSON.stringify({id,value})});
 load();
}
load();setInterval(load,3000);
</script></body></html>`;

createServer(async (req, res) => {
  if (req.url === '/api/pending') {
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end(JSON.stringify(await pending()));
  }
  if (req.url === '/api/answer' && req.method === 'POST') {
    let body = '';
    for await (const c of req) body += c;
    const { id, value } = JSON.parse(body || '{}');
    // A missing value used to be accepted: it removed the request from the queue and wrote an
    // answer file with no answer in it, which unblocked the waiting session with a crash instead
    // of a decision. Refuse it; the request stays pending and the session keeps waiting.
    if (!id || value === undefined || value === null || value === '') {
      res.writeHead(400, { 'content-type': 'application/json' });
      return res.end('{"ok":false,"error":"id and value are both required"}');
    }
    await answer(id, value);
    res.writeHead(200, { 'content-type': 'application/json' });
    return res.end('{"ok":true}');
  }
  res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
  res.end(PAGE);
}).listen(PORT, () => console.log(`inbox on http://localhost:${PORT}`));
