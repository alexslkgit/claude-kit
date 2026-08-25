#!/usr/bin/env bash
# page-sweep.sh — finds pages already on disk that can pull his macOS Space over to the browser.
#
# page-guard.sh stops a bad page from being WRITTEN. It cannot see the ones that were written
# before it existed, the ones a tool wrote without going through Write/Edit/Bash, or the ones he
# downloaded. On 2026-08-25 he said the disease had been fixed several times and kept coming back,
# and asked for every existing file to be proved clean, not only future ones. This is that proof,
# re-run at the start of every session so a regression is caught the same day it lands.
#
# What counts as an offender here is narrower than in page-guard, on purpose: only a call that
# fires BY ITSELF. A reload or a modal inside a click handler cannot swipe him anywhere, because he
# is already looking at the page when he clicks. Reporting those would make the sweep noise, and a
# noisy check gets ignored, which is how this bug survived in the first place.
#
# SessionStart contract: whatever it prints on stdout is added to the session context. Silence is
# the normal outcome. Every unexpected condition exits 0.

set -uo pipefail
command -v python3 >/dev/null 2>&1 || exit 0

python3 <<'PY' 2>/dev/null
import json, os, re, sys

HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".claude", ".page-sweep-cache.json")
ROOTS = [os.path.join(HOME, d) for d in
         ("Tasks", "Downloads", "Developer", "Documents", "Desktop", ".claude/templates", ".claude/skills")]

# node_modules and friends are somebody else's code. tool-results and versions are frozen records
# of what was already published: rewriting them would corrupt a transcript, and he never opens them.
SKIP = re.compile(r"/(node_modules|\.git|\.venv|venv|dist|build|Pods|DerivedData|site-packages"
                  r"|\.next|coverage|tool-results|versions|\.Trash)/")

RULES = [
    ("a <meta http-equiv=\"refresh\"> reload", r"<meta[^>]+http-equiv\s*=\s*[\"']?refresh"),
    ("a location.reload()",                    r"location\s*\.\s*reload\s*\("),
    ("a location.replace(location…) reload",   r"location\s*\.\s*replace\s*\(\s*location"),
    ("a window.focus()",                       r"\b(window|self)\s*\.\s*focus\s*\("),
    ("a modal that activates the window",      r"(?<![\w.])(alert|confirm)\s*\("),
    ("a desktop Notification",                 r"\bNotification\s*\.\s*requestPermission|new\s+Notification\s*\("),
    ("a window.open()",                        r"\bwindow\s*\.\s*open\s*\("),
]

# A call is his, not the page's, when the code that reaches it hangs off something he did:
# a click, a form submit, a file he picked. None of those can fire while he is in another app.
CLICK = re.compile(r"(addEventListener\s*\(\s*[\"'](?:click|change|submit|input|keydown|keyup|drop)"
                   r"|\bon(?:click|change|submit|input|keydown|keyup|drop)\s*=)", re.I)


def prose_stripped(body):
    body = re.sub(r"<!--.*?-->", "", body, flags=re.S)
    return re.sub(r"<(code|pre|kbd|samp)\b[^>]*>.*?</\1>", "", body, flags=re.S | re.I)


FUNC = re.compile(r"(?:async\s+)?function\s+([A-Za-z_$][\w$]*)\s*\(")
# A page usually reaches its modals through a named handler wired up in markup, one
# onclick="saveDraft(...)" away from the call. Those names count as click-bound too.
HANDLER = re.compile(r"on(?:click|submit)\s*=\s*[\"'][^\"']*?([A-Za-z_$][\w$]*)\s*\(", re.I)


def self_firing(body, pattern, clicked):
    """True when at least one match is not reached through a click handler."""
    for m in re.finditer(pattern, body, re.I):
        before = body[max(0, m.start() - 800):m.start()]
        if CLICK.search(before):
            continue
        names = FUNC.findall(body[:m.start()])
        if names and names[-1] in clicked:
            continue
        return True
    return False


# Cheap literal pre-filter. Almost every page on disk contains none of these, and skipping the
# regex pass for those is what keeps a whole-disk sweep under a second on the second run.
TOKENS = ("reload", "focus", "alert(", "confirm(", "Notification", "window.open", "http-equiv")

try:
    cache = json.load(open(CACHE))
except Exception:
    cache = {}
fresh = {}

hits = []
scanned = 0
for root in ROOTS:
    for dirpath, dirnames, filenames in os.walk(root):
        if SKIP.search(dirpath + "/"):
            dirnames[:] = []
            continue
        for name in filenames:
            if not name.lower().endswith((".html", ".htm")):
                continue
            path = os.path.join(dirpath, name)
            scanned += 1
            try:
                st = os.stat(path)
            except OSError:
                continue
            stamp = "%d:%d" % (st.st_mtime_ns, st.st_size)
            was = cache.get(path)
            if was and was[0] == stamp:                 # unchanged since the last sweep
                fresh[path] = was
                if was[1]:
                    hits.append((path.replace(HOME, "~"), was[1]))
                continue
            try:
                raw = open(path, encoding="utf-8", errors="ignore").read()
            except Exception:
                continue
            if "PAGE-GUARD-EXEMPT" in raw or not any(t in raw for t in TOKENS):
                fresh[path] = [stamp, []]
                continue
            body = prose_stripped(raw)
            clicked = set(HANDLER.findall(body))
            why = [label for label, pat in RULES if self_firing(body, pat, clicked)]
            fresh[path] = [stamp, why]
            if why:
                hits.append((path.replace(HOME, "~"), why))

try:
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump(fresh, open(CACHE, "w"))
except Exception:
    pass

if not hits:
    sys.exit(0)

print("page-sweep: %d of %d pages on disk can raise the browser window by themselves." % (len(hits), scanned))
print("This is the bug he has chased for months: a page in a background tab reloads or focuses")
print("itself, macOS switches Space, and he is thrown into Chrome mid-sentence. Fix them before")
print("anything else, and say in one line what you found.")
print("")
for path, why in hits[:25]:
    print("  %s  ·  %s" % (path, ", ".join(why)))
if len(hits) > 25:
    print("  … and %d more" % (len(hits) - 25))
print("")
print("The fix is never a reload. Re-fetch the file in the background and swap document.body")
print("innerHTML, the way skills/meeting-live/board/render.py and board-shell/board.js do it.")
print("A page that is finished gets no refresh at all. If a call is genuinely his own click and")
print("cannot fire on its own, put PAGE-GUARD-EXEMPT in a comment with the reason and the date.")
PY
exit 0
