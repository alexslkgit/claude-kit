#!/usr/bin/env python3
"""Build a self-contained copy of a board page for publishing as an Artifact.

The board on disk links `_shell/board.css` and `_shell/board.js`, which an
Artifact cannot fetch: the CSP admits Google Fonts and nothing else. This
inlines both and strips the document skeleton, because the Artifact host wraps
the file in its own doctype, html, head and body.

    python3 _shell/build_artifact.py onboarding.html "Title for the gallery"

Writes <name>.artifact.html beside the source. Re-run it after every board
patch and publish the result to the SAME file path, which keeps the URL stable.
"""
import re
import sys
from pathlib import Path

source = Path(sys.argv[1])
title = sys.argv[2] if len(sys.argv) > 2 else None
shell = source.parent / "_shell"

src = source.read_text(encoding="utf-8")
title = title or re.search(r"<title>(.*?)</title>", src, re.S).group(1)
fonts = re.search(r'<link rel="stylesheet" href="https://fonts\.googleapis\.com[^>]*>', src).group(0)
body = re.search(r"<body>(.*)</body>", src, re.S).group(1)
body = re.sub(r'<script src="_shell/board\.js"[^>]*></script>\s*', "", body)

out = source.with_suffix(".artifact.html")
out.write_text(
    f"<title>{title}</title>\n{fonts}\n"
    f"<style>\n{(shell / 'board.css').read_text(encoding='utf-8')}\n</style>\n"
    f"{body}\n"
    f"<script>\n{(shell / 'board.js').read_text(encoding='utf-8')}\n</script>\n",
    encoding="utf-8",
)
print(f"{out} ({out.stat().st_size} bytes) — title: {title}")
