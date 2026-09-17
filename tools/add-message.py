#!/usr/bin/env python3
"""Add a draft card to the shared messages page without re-reading the page.

Usage:
  add-message.py --project <slug> --to "<Name, where>" --lang uk|ru|en \
      --open "<url>" (--body-file <file> | --body "<text>") [--replace]

Body: paragraphs separated by blank lines. Inline: [text](url), **bold**.
A line block of the form "1. ..." / "2. ..." stays in one paragraph joined by <br>.
A new card is a new VERSION: earlier cards with the same project and recipient are always
dropped (pass --keep to keep them). Recipient labels drift between sessions, so also pass
--supersedes "<substring of the old card's recipient line>" (repeatable, case-insensitive) for
every older card this text replaces. The output lists every card left for the project: read it,
and if one of them is an older version of what you just wrote, run again with --supersedes.
Prints the page URL and one line per card on the page for that project.
"""
import argparse, datetime, html, os, re, sys

PAGE = os.path.expanduser('~/Tasks/messages/messages.html')
MARK = '<!-- NEW MESSAGES GO HERE -->'
URL = 'http://localhost:8899/messages/messages.html'


def inline(s):
    s = html.escape(s, quote=False)
    s = re.sub(r'\[([^\]]+)\]\(([^)\s]+)\)', r'<a href="\2">\1</a>', s)
    s = re.sub(r'\*\*([^*]+)\*\*', r'<b>\1</b>', s)
    return s


def body_html(text):
    out = []
    for para in re.split(r'\n\s*\n', text.strip()):
        lines = [l.rstrip() for l in para.strip().split('\n')]
        if all(re.match(r'^\d+\.\s', l) for l in lines):
            out.append('    <p>' + '<br>'.join(inline(l) for l in lines) + '</p>')
        else:
            out.append('    <p>' + inline(' '.join(lines)) + '</p>')
    return '\n'.join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--project', required=True)
    ap.add_argument('--to', required=True)
    ap.add_argument('--lang', required=True)
    ap.add_argument('--open', required=True)
    ap.add_argument('--body-file')
    ap.add_argument('--body')
    ap.add_argument('--replace', action='store_true', help='default, kept for old callers')
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--supersedes', action='append', default=[])
    a = ap.parse_args()
    text = open(a.body_file).read() if a.body_file else a.body
    if not text:
        sys.exit('add-message: empty body')
    page = open(PAGE).read()
    if MARK not in page:
        sys.exit('add-message: marker missing in ' + PAGE)
    key = html.escape(a.project + '|' + a.to, quote=True)
    n = 0
    if not a.keep:
        page, n = re.subn(
            r'<article class="msg" data-status="draft" data-project="%s" data-key="%s"[^>]*>.*?</article>\n\n'
            % (re.escape(html.escape(a.project, quote=True)), re.escape(key)), '', page, flags=re.S)
    proj = re.escape(html.escape(a.project, quote=True))
    for sub in a.supersedes:
        def drop(m, sub=sub):
            to = re.search(r'<span class="to">Кому: ([^<]*)', m.group(0))
            return '' if to and sub.lower() in html.unescape(to.group(1)).lower() else m.group(0)
        before = page.count('<article')
        page = re.sub(r'<article class="msg"[^>]*data-project="%s"[^>]*>.*?</article>\n\n?' % proj, drop, page, flags=re.S)
        n += before - page.count('<article')
    now = datetime.datetime.now().strftime('%Y-%m-%d %H:%M')
    card = (
        '<article class="msg" data-status="draft" data-project="%s" data-key="%s" data-ts="%s">\n'
        '  <header>\n'
        '    <span class="to">Кому: %s</span>\n'
        '    <span class="meta">%s · %s · <span class="status">черновик</span></span>\n'
        '    <a class="open" href="%s" target="_blank" rel="noopener">Открыть</a>\n'
        '    <button class="copy" type="button">Копировать</button>\n'
        '  </header>\n'
        '  <div class="body">\n%s\n  </div>\n'
        '</article>\n\n'
    ) % (html.escape(a.project, quote=True), key, now, html.escape(a.to, quote=False),
         now, a.lang, html.escape(a.open, quote=True), body_html(text))
    page = page.replace(MARK, MARK + '\n' + card, 1)
    open(PAGE, 'w').write(page)
    tos = re.findall(r'data-project="%s"[^>]*>\s*<header>\s*<span class="to">Кому: ([^<]+)' % proj, page)
    print(URL)
    print('replaced %d; cards for %s: %s' % (n, a.project, ' | '.join(tos)))


if __name__ == '__main__':
    main()
