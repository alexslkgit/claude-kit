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
.chunk{display:inline-flex;align-items:center;gap:6px;margin:2px 4px 2px 0;vertical-align:middle}
.chunk a{text-decoration:none}
.cp{font:500 12px Commissioner,sans-serif;padding:3px 9px;border-radius:7px;
border:1px solid var(--line);background:transparent;color:var(--muted);cursor:pointer}
.openrow{display:flex;align-items:center;gap:10px;flex-wrap:wrap;margin:0 0 12px}
.openbtn{font:600 14px Commissioner,sans-serif;padding:8px 18px;border-radius:9px;
background:var(--btn-bg);color:var(--btn-fg);text-decoration:none;border:1px solid var(--btn-bg)}
.steps{margin:0 0 14px;padding-left:22px}
.steps li{margin:6px 0}
.steps label{display:flex;align-items:flex-start;gap:8px;cursor:pointer}
.steps input{margin-top:4px}
.empty{color:var(--muted);font-size:17px;padding:40px 0;font-family:Literata,Georgia,serif}
.grp{display:flex;align-items:baseline;gap:10px;margin:30px 0 12px;
padding-bottom:7px;border-bottom:1px solid var(--line)}
.grp:first-child{margin-top:0}
.grp .nm{font:600 17px/1.2 Literata,Georgia,serif}
.grp .k{font-size:13px;color:var(--muted)}
.sub{font-size:12.5px;color:var(--muted);letter-spacing:.04em;margin:14px 0 8px}
.age{font-weight:600}
.age.old{color:var(--accent)}
.foot{margin-top:34px;font-size:12.5px;color:var(--muted)}
</style></head><body><div class="wrap">
<h1>Ждёт тебя</h1><div class="count" id="n">…</div><div id="list"></div>
<div class="foot">Страница сама обновляется. Любая сессия на этом маке кладёт сюда то, что уперлось в тебя, и твой клик возвращается в неё и снимает блокировку.</div>
</div><script>
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const plural=(n,one,few,many)=>n%10===1&&n%100!==11?one:(n%10>=2&&n%10<=4&&(n%100<10||n%100>=20)?few:many);
const isUrl=s=>/^https?:\\/\\//.test(s);
// One copyable thing, one chunk: a code span with its own «копировать» button, and a real
// link when the value is a URL, so a click never has to select text by hand first.
function chunk(val){
 const code=isUrl(val)?'<a href="'+esc(val)+'" target="_blank" rel="noopener"><code>'+esc(val)+'</code></a>':'<code>'+esc(val)+'</code>';
 return '<span class="chunk">'+code+'<button class="cp" type="button" data-v="'+esc(val)+'" onclick="copyChunk(this)">копировать</button></span>';
}
// Finds backtick spans, http(s) URLs and absolute paths (/… or ~/…) inside free text and turns
// each into its own chunk, leaving the rest of the sentence as plain text around them.
function chunkify(text){
 if(text==null||text==='') return '';
 const re=/\`([^\`]+)\`|(https?:\\/\\/[^\\s)]+)|((?:~\\/|\\/)[^\\s\`,;:()]+)/g;
 let out='',last=0,m;
 while((m=re.exec(text))){
  out+=esc(text.slice(last,m.index));
  out+=chunk(m[1]||m[2]||m[3]);
  last=re.lastIndex;
 }
 out+=esc(text.slice(last));
 return out;
}
function copyChunk(btn){
 const v=btn.getAttribute('data-v');
 const done=()=>{btn.textContent='скопировано';setTimeout(()=>{btn.textContent='копировать'},2000)};
 if(navigator.clipboard&&navigator.clipboard.writeText){
  navigator.clipboard.writeText(v).then(done).catch(()=>fallbackCopy(v,done));
 } else fallbackCopy(v,done);
}
function fallbackCopy(v,done){
 const ta=document.createElement('textarea');
 ta.value=v; ta.style.position='fixed'; ta.style.opacity='0';
 document.body.appendChild(ta); ta.select();
 try{document.execCommand('copy')}catch(e){}
 document.body.removeChild(ta); done();
}
// One checkbox per step, remembered per item so ticking one off while working survives a reload.
function stepsState(id){
 try{return JSON.parse(localStorage.getItem('inbox-steps:'+id)||'{}')}catch(e){return {}}
}
function toggleStep(id,idx,val){
 const st=stepsState(id); st[idx]=val;
 localStorage.setItem('inbox-steps:'+id,JSON.stringify(st));
}
function stepsHtml(i){
 if(!i.steps||!i.steps.length) return '';
 const st=stepsState(i.id);
 return '<ol class="steps">'+i.steps.map((s,idx)=>
   '<li><label><input type="checkbox" '+(st[idx]?'checked':'')+
   ' onchange="toggleStep(\\''+esc(i.id)+'\\','+idx+',this.checked)"> '+chunkify(s)+'</label></li>'
 ).join('')+'</ol>';
}
// How long it has been waiting. The whole reason it is on the card: a request that has sat for
// days is usually answered by deleting it, and nothing on this page used to say that out loud.
function age(iso){
 const ms=Date.now()-new Date(iso).getTime();
 if(!isFinite(ms)||ms<0) return '';
 const m=Math.round(ms/6e4); if(m<60) return Math.max(1,m)+' мин';
 const h=Math.round(ms/3.6e6); if(h<24) return h+' '+plural(h,'час','часа','часов');
 const d=Math.round(ms/8.64e7); return d+' '+plural(d,'день','дня','дней');
}
function card(i){
 const a=age(i.created), old=(Date.now()-new Date(i.created).getTime())>1.728e8; // two days
 return \`<div class="card">
   <div class="meta">\${i.session?esc(i.session)+' · ':''}\${esc((i.created||'').slice(0,16).replace('T',', '))}\${a?' · <span class="age'+(old?' old':'')+'">'+a+'</span>':''}</div>
   <div class="t">\${esc(i.title)}</div>
   \${i.open?'<div class="openrow">'+chunk(i.open)+(isUrl(i.open)?'<a class="p openbtn" href="'+esc(i.open)+'" target="_blank" rel="noopener">Открыть</a>':'')+'</div>':''}
   \${i.why?'<p class="why">'+chunkify(i.why)+'</p>':''}
   \${stepsHtml(i)}
   <div class="row">\${(i.options||['Да','Нет']).map((o,k)=>
     '<button class="'+(k===0?'p':'')+'" onclick="say(\\''+esc(i.id)+'\\',\\''+esc(o)+'\\')">'+esc(o)+'</button>').join('')}
   </div></div>\`;
}
async function load(){
 const r=await fetch('/api/pending'),items=await r.json();
 document.getElementById('n').textContent=items.length||'ничего';
 if(!items.length){
  document.getElementById('list').innerHTML='<div class="empty">Пусто. Ни одна сессия сейчас тебя не ждёт.</div>';
  return;
 }
 // The server hands them over sorted by created, ascending, and that order is kept inside a group
 // on purpose: what has waited longest sits at the top of its project, where it is hardest to skip.
 const g={};
 for(const i of items){ const k=i.project||'без проекта'; (g[k]=g[k]||[]).push(i); }
 // Projects are ordered by their freshest request, newest first, so a project that just asked for
 // something is at the top rather than buried under one that has been waiting since Monday.
 const order=Object.keys(g).sort((a,b)=>
   String(g[b][g[b].length-1].created).localeCompare(String(g[a][g[a].length-1].created)));
 document.getElementById('list').innerHTML=order.map(name=>{
  const list=g[name], n=list.length;
  // A second level only when it earns its place: one session in a project needs no subheading,
  // and it is already on every card.
  const sessions=[...new Set(list.map(i=>i.session||''))].filter(Boolean);
  const body=(sessions.length>1)
   ? sessions.map(s=>'<div class="sub">'+esc(s)+'</div>'+list.filter(i=>i.session===s).map(card).join('')).join('')
     + list.filter(i=>!i.session).map(card).join('')
   : list.map(card).join('');
  return '<div class="grp"><span class="nm">'+esc(name)+'</span><span class="k">'+n+' '+plural(n,'вопрос','вопроса','вопросов')+'</span></div>'+body;
 }).join('');
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
