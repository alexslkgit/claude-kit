#!/usr/bin/env bash
# shell-guard.sh — refuses a page that carries its own styling instead of linking the shell.
#
# Why this exists as a hook and not as prose. Until 2026-08-21 the board template was 19 KB, of
# which 9.5 KB was one inline <style> and 2.7 KB two inline <script>s. The board is rewritten in
# full at every stage change, decision and blocker, so every rewrite re-emitted the same 12 KB of
# CSS and JS that had not changed since the file was created — into the agent's context, where it
# is then re-sent on every later request of the session. The same shape sat in the company brief
# (12 KB of CSS in a 26 KB template).
#
# plan-shell/ had already solved it: plan.css and plan.js live once, the page links them and
# carries data only. board-shell/ now does the same for the board, and the brief keeps its shell
# in skills/company-brief/assets/. This guard is what keeps the styling from creeping back one
# convenient inline block at a time.
#
# The rule: no inline <style> or executable <script> over 500 bytes, in any kit template or in
# any page an agent writes. Small blocks are fine — a five-line tweak is not a shell.
#
# DATA is not styling: <script type="application/json">, ld+json and text/template blocks are the
# page's content and are never counted. That is the whole point — instances carry data.
#
# Two ways to run it:
#   ./hooks/shell-guard.sh --check [dir]   scan the kit's templates; exit 1 on a violation
#   (as a PreToolUse hook)                 check the page being written; exit 2 blocks it
#
# Escape hatch: SHELL-GUARD-EXEMPT in the file, for a page that genuinely must be one portable
# file. tools/inline-shell.py is the better answer — it folds the shell back in on demand.
#
# PreToolUse contract: exit 2 blocks and feeds stderr to the model; anything else lets it through.
# Every unexpected condition exits 0 — this must never be the reason a session cannot work.

set -uo pipefail
LIMIT=500

command -v python3 >/dev/null 2>&1 || exit 0

SCAN='
import re,sys
LIMIT=int(sys.argv[1])
DATA=re.compile(r"type\s*=\s*[\"\x27]?(application/json|application/ld\+json|text/template|text/x-template)",re.I)
def blocks(body):
    out=[]
    for m in re.finditer(r"<style\b([^>]*)>(.*?)</style>",body,re.S|re.I):
        out.append(("<style>",len(m.group(2).encode("utf-8","ignore"))))
    for m in re.finditer(r"<script\b([^>]*)>(.*?)</script>",body,re.S|re.I):
        attrs,code=m.group(1),m.group(2)
        if "src" in attrs.lower() or DATA.search(attrs): continue
        out.append(("<script>",len(code.encode("utf-8","ignore"))))
    return [(k,n) for k,n in out if n>LIMIT]
'

# ---------------------------------------------------------------- standalone scan
if [ "${1:-}" = "--check" ]; then
  root="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
  python3 - "$LIMIT" "$root" <<PY
$SCAN
root=sys.argv[2]
import pathlib
bad=[]
for p in sorted(pathlib.Path(root).rglob("*.html")):
    s=str(p)
    if "/.git/" in s or "/hooks/" in s or "/.claude/" in s or "/archive/" in s: continue
    try: body=p.read_text(errors="ignore")
    except Exception: continue
    if "SHELL-GUARD-EXEMPT" in body: continue
    for kind,n in blocks(body):
        bad.append((s.replace(root+"/",""),kind,n))
for f,kind,n in bad:
    print(f"  {f}: inline {kind} of {n} bytes (limit {LIMIT})")
if bad:
    print("")
    print("shell-guard: a kit template is carrying its own styling again.")
    print("Move it into the shell the page links (board-shell/, plan-shell/,")
    print("skills/company-brief/assets/) and leave the page with data only.")
    raise SystemExit(1)
print(f"shell-guard: clean, no inline block over {LIMIT} bytes.")
PY
  exit $?
fi

# ---------------------------------------------------------------- PreToolUse hook
payload="$(cat 2>/dev/null || true)"
verdict="$(printf '%s' "$payload" | python3 -c "
$SCAN
import json
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
tool=str(d.get('tool_name') or '')
ti=d.get('tool_input') or {}
if tool=='Bash':
    cmd=str(ti.get('command') or '')
    if not re.search(r'(>>?|\btee\b)\s*[\"\x27]?[^\s|;\"\x27]*\.html?\b',cmd,re.I): raise SystemExit
    path,body='',cmd
elif tool in ('Write','Edit'):
    path=str(ti.get('file_path') or '')
    body=str(ti.get('content') or ti.get('new_string') or '')
    if not path.lower().endswith(('.html','.htm')): raise SystemExit
else: raise SystemExit
if not body or 'SHELL-GUARD-EXEMPT' in body: raise SystemExit
if 'shell-guard' in path or 'inline-shell' in path or '/hooks/' in path: raise SystemExit
hits=blocks(body)
if hits: print(' · '.join(f'an inline {k} of {n} bytes' for k,n in hits))
" "$LIMIT" 2>/dev/null)"

[ -n "${verdict:-}" ] || exit 0

cat >&2 <<EOF
shell-guard: this page carries $verdict, over the ${LIMIT}-byte limit.

A page an agent rewrites carries DATA ONLY. The look and the behaviour live once, in a shell
the page links, and are never emitted again:

  board   ->  _shell/board.css + _shell/board.js   (kit: board-shell/)
  plan    ->  _shell/plan.css  + _shell/plan.js    (kit: plan-shell/)
  brief   ->  _shell/brief.css + _shell/brief.js   (kit: skills/company-brief/assets/)

Copy the shell next to the page once, link it with a relative path, and write only the markup
that changed. Every board rewrite used to re-emit 12 KB of unchanged CSS and JS into the
context, and that context is re-sent on every later request of the session.

Restyling? Edit the shell file in the kit, not the page.
Need one portable file to send someone? tools/inline-shell.py folds the shell back in.
Genuinely need an exception he has agreed to? Put SHELL-GUARD-EXEMPT in a comment.
EOF
exit 2
