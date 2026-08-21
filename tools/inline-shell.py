#!/usr/bin/env python3
"""inline-shell.py — fold a page's shell back into one portable file.

The board, the chewed plan and the company brief keep their look and behaviour in a shell
next to them (_shell/*.css, _shell/*.js) and carry data only, so rewriting a page costs the
data and nothing else. That is right for a page he opens from disk, and wrong exactly once:
when the page has to travel on its own — attached to mail, delivered as a Cowork artifact,
handed to someone who will not get the folder around it.

    python3 ~/.claude/tools/inline-shell.py brief.html
    python3 ~/.claude/tools/inline-shell.py board.html -o /tmp/board-standalone.html

Local <link rel="stylesheet"> and <script src> are inlined; remote ones (Google Fonts) are
left alone, because inlining them is not possible and the page degrades to system fonts.
The copy is stamped SHELL-GUARD-EXEMPT: it is a snapshot for sending, never a page to edit.
Edit the original and re-run this.
"""
import argparse, pathlib, re, sys

def inline(path: pathlib.Path) -> str:
    html = path.read_text()
    base = path.parent

    def css(m):
        href = m.group(1)
        if href.startswith(("http://", "https://", "//", "data:")):
            return m.group(0)
        f = (base / href)
        if not f.is_file():
            print(f"  missing, left as a link: {href}", file=sys.stderr)
            return m.group(0)
        return "<style>\n" + f.read_text().strip() + "\n</style>"

    def js(m):
        src = m.group(1)
        if src.startswith(("http://", "https://", "//", "data:")):
            return m.group(0)
        f = (base / src)
        if not f.is_file():
            print(f"  missing, left as a link: {src}", file=sys.stderr)
            return m.group(0)
        return "<script>\n" + f.read_text().strip() + "\n</script>"

    html = re.sub(r'<link\b[^>]*rel=["\']?stylesheet["\']?[^>]*href=["\']([^"\']+)["\'][^>]*>', css, html, flags=re.I)
    html = re.sub(r'<link\b[^>]*href=["\']([^"\']+)["\'][^>]*rel=["\']?stylesheet["\']?[^>]*>', css, html, flags=re.I)
    html = re.sub(r'<script\b[^>]*\bsrc=["\']([^"\']+)["\'][^>]*>\s*</script>', js, html, flags=re.I)

    stamp = ("<!-- SHELL-GUARD-EXEMPT — standalone snapshot made by tools/inline-shell.py.\n"
             "     Do not edit this copy: edit the original page and its shell, then re-run. -->\n")
    return html.replace("<html", stamp + "<html", 1)

if __name__ == "__main__":
    ap = argparse.ArgumentParser(description="Fold _shell/*.css and _shell/*.js into one file.")
    ap.add_argument("page")
    ap.add_argument("-o", "--out", default=None)
    a = ap.parse_args()
    src = pathlib.Path(a.page).expanduser().resolve()
    out = pathlib.Path(a.out).expanduser() if a.out else src.with_name(src.stem + "-standalone.html")
    out.write_text(inline(src))
    print(f"{out}  ({out.stat().st_size} bytes, from {src.stat().st_size})")
