#!/usr/bin/env python3
"""Render the meeting board from a small JSON file.

    render.py <board.json> [-o <out.html>]

Writing the JSON is cheap; writing the HTML by hand is not. Keep the JSON small and rewrite it
whenever the room moves — the page reloads itself and he never touches anything.

JSON shape, every key optional except "entries":

{
  "meeting":  "Refinement",              // shown as the title
  "refresh":  60,                        // seconds; 5 when a question may land on him, 120 when idle
  "state":    "idle" | "watch" | "hot",  // colours the header strip
  "now":      "What the room is doing right now, one or two sentences.",
  "mine":     false,                     // true when the current topic is his
  "say":      "The exact sentence to say out loud.",   // null when he has nothing to say
  "heads_up": "A question is coming about X.",         // null when nothing is coming
  "entries":  [ {"t": "10:12", "text": "...", "mine": false}, ... ],  // newest first
  "open":     ["Anything he owes someone, one line each."],
  "updated":  "10:31"
}
"""
import html
import json
import sys
from pathlib import Path

PALETTE = {
    "idle":  ("#2c2e33", "#a7a7a0", "слушаю"),
    "watch": ("#7fb8ff", "#7fb8ff", "рядом с твоей темой"),
    "hot":   ("#f0d060", "#f0d060", "это твоё"),
}

CSS = """
:root { color-scheme: dark; --bg:#111214; --fg:#f0f0ec; --mut:#8e8e88; --line:#2c2e33;
        --card:#1c1e22; --acc:#7fb8ff; --pin:#f0d060; --mine:#f0d060; }
* { box-sizing:border-box }
html,body { max-width:100%; overflow-x:hidden }
body { margin:0; padding:1.25rem 1rem 4rem; background:var(--bg); color:var(--fg);
       font:19px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
.wrap { max-width:44rem; margin:0 auto }
h1 { font-size:1.5rem; margin:0; font-weight:900 }
.strip { display:flex; align-items:baseline; gap:.6rem; flex-wrap:wrap;
         border-bottom:2px solid var(--st); padding-bottom:.6rem; margin-bottom:1rem }
.state { font-size:.95rem; font-weight:800; color:var(--st); text-transform:uppercase;
         letter-spacing:.05em }
.upd { color:var(--mut); font-size:.9rem; margin-left:auto }
.card { background:var(--card); border:1px solid var(--line); border-radius:12px;
        padding:1rem 1.2rem; margin:.8rem 0 }
.card h2 { margin:0 0 .45rem; font-size:1rem; font-weight:800; color:var(--mut);
           text-transform:uppercase; letter-spacing:.04em }
.card p { margin:.3rem 0; font-size:1.15rem }
.say { border:2px solid var(--pin) }
.say h2 { color:var(--pin) }
.say p { font-size:1.45rem; font-weight:700; line-height:1.35 }
.heads { border:2px solid var(--acc) }
.heads h2 { color:var(--acc) }
.heads p { font-size:1.2rem; font-weight:600 }
.now p { font-size:1.3rem }
ol { list-style:none; margin:0; padding:0 }
li { display:flex; gap:.8rem; padding:.4rem 0; border-bottom:1px solid var(--line);
     font-size:1.05rem }
li:last-child { border-bottom:0 }
li .t { color:var(--mut); font-variant-numeric:tabular-nums; flex:0 0 3.6rem }
li.mine { color:var(--mine); font-weight:700 }
li.mine .t { color:var(--mine) }
.open li { color:var(--fg) }
.quiet { color:var(--mut); font-size:1rem; margin-top:.6rem }
"""


def esc(value):
    return html.escape(str(value), quote=False)


def render(data):
    state = data.get("state", "idle")
    stripe, _text, label = PALETTE.get(state, PALETTE["idle"])
    refresh = int(data.get("refresh", 60))
    out = []
    add = out.append

    add('<!doctype html><html lang="ru"><head><meta charset="utf-8">')
    add(f'<meta http-equiv="refresh" content="{refresh}">')
    add('<meta name="viewport" content="width=device-width,initial-scale=1">')
    add(f'<title>{esc(data.get("meeting", "Meeting"))}</title>')
    add(f"<style>{CSS}</style></head><body><div class=\"wrap\">")

    add(f'<div class="strip" style="--st:{stripe}">')
    add(f'<h1>{esc(data.get("meeting", "Meeting"))}</h1>')
    add(f'<span class="state">{esc(label)}</span>')
    if data.get("updated"):
        add(f'<span class="upd">{esc(data["updated"])}</span>')
    add("</div>")

    if data.get("say"):
        add('<div class="card say"><h2>Скажи это</h2>')
        add(f'<p>{esc(data["say"])}</p></div>')

    if data.get("heads_up"):
        add('<div class="card heads"><h2>Сейчас могут спросить</h2>')
        add(f'<p>{esc(data["heads_up"])}</p></div>')

    if data.get("now"):
        mine = " say" if data.get("mine") else ""
        add(f'<div class="card now{mine}"><h2>Прямо сейчас</h2>')
        add(f'<p>{esc(data["now"])}</p></div>')

    entries = data.get("entries") or []
    add('<div class="card"><h2>Как шёл разговор</h2><ol>')
    for e in entries:
        cls = ' class="mine"' if e.get("mine") else ""
        add(f'<li{cls}><span class="t">{esc(e.get("t", ""))}</span>'
            f'<span>{esc(e.get("text", ""))}</span></li>')
    add("</ol>")
    if not entries:
        add('<p class="quiet">Пока ничего не началось.</p>')
    add("</div>")

    if data.get("open"):
        add('<div class="card open"><h2>За тобой</h2><ol>')
        for item in data["open"]:
            add(f"<li><span>{esc(item)}</span></li>")
        add("</ol></div>")

    add("</div></body></html>")
    return "\n".join(out)


def main():
    args = [a for a in sys.argv[1:]]
    if not args:
        sys.exit("usage: render.py <board.json> [-o <out.html>]")
    src = Path(args[0])
    dst = Path(args[args.index("-o") + 1]) if "-o" in args else src.with_suffix(".html")
    data = json.loads(src.read_text())
    dst.write_text(render(data))
    print(dst)


if __name__ == "__main__":
    main()
