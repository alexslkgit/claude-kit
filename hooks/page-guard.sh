#!/usr/bin/env bash
# page-guard.sh — refuses to write a page that can pull his macOS Space over to the browser.
#
# Why this exists as a hook and not as prose. The ban on <meta http-equiv="refresh"> was written
# down on 2026-08-16, in skills/board/SKILL.md, after three self-reloading pages auto-swiped him
# to Chrome every 10-60 s while he worked in another app. That fix reached the board template and
# roughly twenty pages that already existed. It did not reach the generators: page-writer-sonnet
# was still told to emit a meta refresh on every board, the chew plan template carried one, the
# meeting-live renderer printed one, and README documented it as the correct way. So every new
# page reintroduced the bug, and on 2026-08-20 he said he never wants to meet it again.
#
# A rule that lives in one skill file is only read when that skill is invoked. This runs on the
# keystroke instead, in subagents as well as here.
#
# What it blocks, in anything being written as a page or as a generator of one:
#   · <meta http-equiv="refresh">            a real reload; the original offender
#   · location.reload() / location.replace(location.href)
#   · window.focus() / self.focus()          raises the window directly
#   · autofocus                              can raise the window when the tab is restored
#   · alert( / confirm(                      a modal in a background tab activates the window
#   · Notification / requestPermission       ditto, plus a permission prompt
#   · window.open(                           a new tab is a Space switch
#
# The way to keep a page live is the background fetch in templates/board.html: re-fetch the file
# and swap document.body.innerHTML. No reload, no focus, no Space switch.
#
# Escape hatch: put PAGE-GUARD-EXEMPT in the file (in a comment) when a page genuinely needs one
# of these and he has agreed to it.
#
# PreToolUse contract: exit 2 blocks and feeds stderr to the model; anything else lets it through.
# Every unexpected condition exits 0 — this must never be the reason a session cannot work.

set -uo pipefail
payload="$(cat 2>/dev/null || true)"
command -v python3 >/dev/null 2>&1 || exit 0

verdict="$(printf '%s' "$payload" | python3 -c '
import json,sys,re
try: d=json.load(sys.stdin)
except Exception: raise SystemExit
tool=str(d.get("tool_name") or "")
if tool not in ("Write","Edit"): raise SystemExit
ti=d.get("tool_input") or {}
path=str(ti.get("file_path") or "")
body=str(ti.get("content") or ti.get("new_string") or "")
if not body: raise SystemExit

# the guard, its own documentation, and anything explicitly exempted
if "page-guard" in path or "PAGE-GUARD-EXEMPT" in body: raise SystemExit
if re.search(r"/(hooks|\.git)/", path): raise SystemExit

is_page = path.lower().endswith((".html",".htm")) or re.search(r"<html|<head\b|http-equiv", body, re.I)
if not is_page: raise SystemExit

RULES=[
 (r"<meta[^>]+http-equiv\s*=\s*[\"\x27]?refresh", "a <meta http-equiv=\"refresh\"> reload"),
 (r"location\s*\.\s*reload\s*\(", "a location.reload() call"),
 (r"location\s*\.\s*replace\s*\(\s*location", "a location.replace(location…) reload"),
 (r"\b(window|self)\s*\.\s*focus\s*\(", "a window.focus() call"),
 (r"\bautofocus\b", "an autofocus attribute"),
 (r"(?<![\w.])(alert|confirm)\s*\(", "a modal alert()/confirm(), which activates the window"),
 (r"\bNotification\s*\.\s*requestPermission|new\s+Notification\s*\(", "a desktop Notification"),
 (r"\bwindow\s*\.\s*open\s*\(", "a window.open(), which opens a tab and switches Space"),
]
hits=[why for pat,why in RULES if re.search(pat,body,re.I)]
if hits: print(" · ".join(hits))
' 2>/dev/null)"

[ -n "${verdict:-}" ] || exit 0

cat >&2 <<EOF
page-guard: this page carries $verdict.

Every one of those can drag his macOS Space over to Chrome while he is working somewhere else.
He has chased this across dozens of generated pages and asked, on 2026-08-20, never to see it
again: «надо было не 20 затронуть, абсолютно все».

If the page must stay live, use the background fetch from templates/board.html instead — it
re-fetches its own file and swaps the DOM, with no reload and no focus change:

  <script>
  setInterval(async () => {
    try {
      const r = await fetch(location.href, {cache: 'no-store'});
      const doc = new DOMParser().parseFromString(await r.text(), 'text/html');
      if (doc.body && doc.body.innerHTML !== document.body.innerHTML) {
        document.body.innerHTML = doc.body.innerHTML;
      }
    } catch (e) {}
  }, 15000);
  </script>

If the page is finished and will not change again, give it no refresh at all.
Remove the offending markup and call again. If he has agreed to an exception, put
PAGE-GUARD-EXEMPT in a comment in the file.
EOF
exit 2
