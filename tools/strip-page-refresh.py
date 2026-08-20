#!/usr/bin/env python3
"""strip-page-refresh.py — remove everything that lets a generated page steal his macOS Space.

Why. A page that reloads itself, focuses its own window, or pops a modal drags his Space over to
Chrome while he is working in another app. A partial sweep on 2026-08-16 fixed about twenty pages
and left every generator emitting the same markup, so the bug came straight back. This is the
sweep that covers everything already on disk; hooks/page-guard.sh stops new ones being written.

Surgery is deliberately conservative. Only edits that cannot break a page are applied:
  · <meta http-equiv="refresh" ...>   deleted outright
  · window.focus() / self.focus();    deleted
  · autofocus attribute              deleted
Anything else that can raise a window (location.reload, alert, Notification, window.open) is
reported, not touched, because removing it can change what the page does.

Usage:
  strip-page-refresh.py --list           report only
  strip-page-refresh.py --apply          rewrite the files
  strip-page-refresh.py --apply ~/Sites  restrict to given roots
"""
import os, re, sys

SKIP_DIRS = {"node_modules", ".git", "Library", ".Trash", "Applications", "Parallels",
             "venv", ".venv", "dist", "build", "DerivedData", ".next", "Pods",
             "site-packages", ".tox", "vendor", ".cache", "Caches"}
EXTS = (".html", ".htm")
MAX_BYTES = 4_000_000

# Applied to every page. A meta refresh has exactly one meaning and removing it cannot break
# anything else on the page.
FIX_ALWAYS = [
    (re.compile(r"[ \t]*<meta[^>]+http-equiv\s*=\s*[\"']?refresh[\"']?[^>]*>[ \t]*\r?\n?", re.I), "meta-refresh"),
]
# Applied only to hand-written pages. In a minified bundle these belong to somebody else's library,
# they fire on a real click rather than on their own, and rewriting one line of a bundle breaks it.
FIX_HANDWRITTEN = [
    (re.compile(r"\b(?:window|self)\s*\.\s*focus\s*\(\s*\)\s*;?", re.I), "window.focus"),
    (re.compile(r"\s+autofocus(?=[\s>/])|\s+autofocus\s*=\s*[\"'][^\"']*[\"']", re.I), "autofocus"),
]
COMMENT = re.compile(r"<!--.*?-->", re.S)
MINIFIED_LINE = 2000


def is_handwritten(src):
    return max((len(l) for l in src.splitlines()), default=0) < MINIFIED_LINE


def edit(src, rules):
    """Apply rules outside HTML comments, so a comment explaining the ban survives it."""
    holes = []

    def stash(m):
        holes.append(m.group(0))
        return f"\x00{len(holes)-1}\x00"

    body = COMMENT.sub(stash, src)
    removed = []
    for pat, label in rules:
        body, n = pat.subn("", body)
        if n:
            removed.append(f"{label}x{n}")
    body = re.sub(r"\x00(\d+)\x00", lambda m: holes[int(m.group(1))], body)
    return body, removed
REPORT = [
    (re.compile(r"location\s*\.\s*reload\s*\(", re.I), "location.reload"),
    (re.compile(r"(?<![\w.])(?:alert|confirm)\s*\(", re.I), "alert/confirm"),
    (re.compile(r"new\s+Notification\s*\(|Notification\s*\.\s*requestPermission", re.I), "Notification"),
    (re.compile(r"\bwindow\s*\.\s*open\s*\(", re.I), "window.open"),
]


def walk(roots):
    for root in roots:
        for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
            dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS and not d.endswith(".xcodeproj")]
            for name in filenames:
                if name.lower().endswith(EXTS):
                    yield os.path.join(dirpath, name)


def main():
    args = [a for a in sys.argv[1:]]
    apply = "--apply" in args
    roots = [a for a in args if not a.startswith("--")] or [os.path.expanduser("~")]
    changed, flagged, scanned, errors = [], [], 0, 0
    for path in walk(roots):
        try:
            if os.path.getsize(path) > MAX_BYTES:
                continue
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                src = f.read()
        except Exception:
            errors += 1
            continue
        scanned += 1
        if "PAGE-GUARD-EXEMPT" in src:
            continue
        rules = list(FIX_ALWAYS)
        if is_handwritten(src):
            rules += FIX_HANDWRITTEN
        out, removed = edit(src, rules)
        notes = [label for pat, label in REPORT if pat.search(COMMENT.sub("", out))]
        if removed:
            changed.append((path, removed))
            if apply:
                try:
                    with open(path, "w", encoding="utf-8") as f:
                        f.write(out)
                except Exception:
                    errors += 1
        if notes:
            flagged.append((path, notes))

    for path, removed in changed:
        print(("FIXED  " if apply else "WOULD  ") + f"{path}  [{', '.join(removed)}]")
    for path, notes in flagged:
        print(f"REVIEW {path}  [{', '.join(notes)}]")
    print(f"\nscanned {scanned} html files · "
          f"{'fixed' if apply else 'fixable'} {len(changed)} · to review {len(flagged)} · unreadable {errors}")


if __name__ == "__main__":
    main()
