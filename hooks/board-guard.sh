#!/usr/bin/env bash
# board-guard.sh — keeps a board readable in ten seconds, by refusing the shapes that make it
# unreadable. It does not touch the file; it tells the session what to fix.
#
# Why it exists. On 2026-08-31 the owner opened his board and found points carrying twenty
# subitems each: «такого вообще не может быть ни при каких обстоятельствах». The rules against it
# were already written in skills/board/SKILL.md — delete a done child and carry `closed`, at most
# a handful of open children, one line per item — and a sweep of 58 boards on disk that day found
# them applied on three. The worst board carried 22 top-level tasks, 54 children under one of
# them, 159 items and 115 items over 120 characters.
#
# The diagnosis is the same one the kit has reached twice before: a rule that is read once at
# invoke time and then depends on goodwill across forty mutations is not a rule. Boards are
# mutated by a python heredoc through Bash, dozens of times per task, often by a session that read
# the skill an hour and 150k tokens ago. So the limits are checked here, after the write, on the
# file itself, whatever tool produced it.
#
# PostToolUse contract: the tool has already run. This never edits the board and never fails a
# session for any reason other than a real violation — no python, no JSON block, a file that is
# not a board, anything unexpected at all, and it exits 0 in silence.
#
# Escape hatch: BOARD-GUARD-EXEMPT anywhere in the file.

set -uo pipefail
exec 3>&2 2>/dev/null

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

# Cheapest possible gate, and it runs after every Bash call on this machine.
case "$payload" in
  *.html*|*/tasks*) : ;;
  *) exit 0 ;;
esac
command -v python3 >/dev/null 2>&1 || exit 0

report="$(printf '%s' "$payload" | python3 -c '
import json, os, re, sys

MAX_KIDS  = 5     # open children under one point
MAX_LEN   = 120   # characters in one item
MAX_DEPTH = 3
MAX_TOP   = 8     # top-level tasks on one board

try:
    d = json.load(sys.stdin)
except Exception:
    raise SystemExit

ti  = d.get("tool_input") or {}
cwd = str(d.get("cwd") or os.getcwd())

cand = []
fp = ti.get("file_path")
if isinstance(fp, str) and fp.endswith(".html"):
    cand.append(fp)
blob = ti.get("command") or ""
if isinstance(blob, str):
    cand += re.findall(r"[\w./~-]+\.html", blob)

seen, paths = set(), []
for c in cand[:12]:
    p = os.path.abspath(os.path.join(cwd, os.path.expanduser(c)))
    if p not in seen and os.path.isfile(p):
        seen.add(p); paths.append(p)

def walk(node, depth, path, out):
    kids = node.get("items") or []
    open_kids = [k for k in kids if k.get("state") != "done"]
    done_kids = [k for k in kids if k.get("state") == "done"]
    if done_kids:
        out.append("%s: %d закрытых подпункта не удалены. Удали их и прибавь к \"closed\"."
                   % (path, len(done_kids)))
    if len(open_kids) > MAX_KIDS:
        out.append("%s: %d открытых подпунктов, потолок %d. Опиши на уровень выше, детали в journal.md."
                   % (path, len(open_kids), MAX_KIDS))
    if len(open_kids) == 1:
        out.append("%s: один подпункт. Группа из одного не нужна, факт идёт в строку родителя."
                   % path)
    if depth > MAX_DEPTH:
        out.append("%s: %d-й уровень вложенности, потолок %d." % (path, depth, MAX_DEPTH))
    for i, k in enumerate(kids, 1):
        t = re.sub(r"<[^>]+>", "", str(k.get("t") or ""))
        if len(t) > MAX_LEN:
            out.append("%s.%d: пункт на %d символов, потолок %d. Один факт, остальное выбрасывается."
                       % (path, i, len(t), MAX_LEN))
        walk(k, depth + 1, "%s.%d" % (path, i), out)

msgs = []
for p in paths:
    try:
        s = open(p, encoding="utf-8").read()
    except Exception:
        continue
    if "BOARD-GUARD-EXEMPT" in s:
        continue
    m = re.search(r"id=\"board\">\s*(\{.*?\})\s*</script>", s, re.S)
    if not m:
        continue
    try:
        b = json.loads(m.group(1))
    except Exception:
        continue
    tasks = b.get("tasks")
    if not isinstance(tasks, list):
        continue
    out = []
    if len(tasks) > MAX_TOP:
        out.append("верхний уровень: %d задач, потолок %d. Борд на один чат, не на весь проект."
                   % (len(tasks), MAX_TOP))
    heres = 0
    def count_here(n):
        global heres
        if n.get("state") == "here":
            heres += 1
        for k in (n.get("items") or []):
            count_here(k)
    for i, t in enumerate(tasks, 1):
        count_here(t)
        walk(t, 2, str(i), out)
    if heres > 1:
        out.append("на борде %d пунктов со state \"here\", должен быть ровно один." % heres)
    if out:
        msgs.append((p, out))

for p, out in msgs:
    print("FILE\t" + p)
    for line in out[:12]:
        print("  " + line)
    if len(out) > 12:
        print("  ... и ещё %d нарушений" % (len(out) - 12))
' 2>/dev/null)"

[ -n "$report" ] || exit 0

{
cat <<'MSG'
board-guard: этот борд он не прочитает за десять секунд. Почини JSON и запиши снова.
MSG
printf '%s\n' "$report"
cat <<'MSG'

Правила и почему они такие — skills/board/SKILL.md, раздел «Size, and why boards rot».
Коротко: закрытый подпункт УДАЛЯЕТСЯ, а не зачёркивается, и его считает поле "closed" на
родителе. Открытых подпунктов под одним пунктом не больше пяти. Один факт в строке, до 120
символов. Мелкие шаги работы — запущенный субагент, прочитанный файл, перезапущенный тест —
на борд не попадают вообще: борд это то, что ты рассказал бы о работе, а не то, что делал.

Механическую часть выведи скриптом, не руками:

    for t in d["tasks"]:
        kids = t.get("items") or []
        done = [k for k in kids if k.get("state") == "done"]
        if done:
            t["closed"] = t.get("closed", 0) + len(done)
            kids = [k for k in kids if k.get("state") != "done"]
            t["items"] = kids
        if not kids:
            t.pop("items", None); t["state"], t["open"] = "done", False
MSG
} >&3
exit 2
