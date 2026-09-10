#!/usr/bin/env python3
"""Add a draft card to the shared messages page without re-reading the page.

Usage:
  add-message.py --project <slug> --to "<Name, where>" --lang uk|ru|en \
      --open "<url>" (--body-file <file> | --body "<text>") [--replace]

Body: paragraphs separated by blank lines. Inline: [text](url), **bold**.
A line block of the form "1. ..." / "2. ..." stays in one paragraph joined by <br>.
--replace drops earlier draft cards with the same project and recipient first.
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
    ap.add_argument('--replace', action='store_true')
    a = ap.parse_args()
    text = open(a.body_file).read() if a.body_file else a.body
    if not text:
        sys.exit('add-message: empty body')
    page = open(PAGE).read()
    if MARK not in page:
        sys.exit('add-message: marker missing in ' + PAGE)
    key = html.escape(a.project + '|' + a.to, quote=True)
    if a.replace:
        page, n = re.subn(
            r'<article class="msg" data-status="draft" data-project="%s" data-key="%s">.*?</article>\n\n'
            % (re.escape(html.escape(a.project, quote=True)), re.escape(key)), '', page, flags=re.S)
    else:
        n = 0
    card = (
        '<article class="msg" data-status="draft" data-project="%s" data-key="%s">\n'
        '  <header>\n'
        '    <span class="to">Кому: %s</span>\n'
        '    <span class="meta">%s · %s · <span class="status">черновик</span></span>\n'
        '    <a class="open" href="%s" target="_blank" rel="noopener">Открыть</a>\n'
        '    <button class="copy" type="button">Копировать</button>\n'
        '  </header>\n'
        '  <div class="body">\n%s\n  </div>\n'
        '</article>\n\n'
    ) % (html.escape(a.project, quote=True), key, html.escape(a.to, quote=False),
         datetime.date.today().isoformat(), a.lang, html.escape(a.open, quote=True), body_html(text))
    page = page.replace(MARK, MARK + '\n' + card, 1)
    open(PAGE, 'w').write(page)
    tos = re.findall(r'data-project="%s"[^>]*>\s*<header>\s*<span class="to">Кому: ([^<]+)'
                     % re.escape(html.escape(a.project, quote=True)), page)
    print(URL)
    print('replaced %d; cards for %s: %s' % (n, a.project, ' | '.join(tos)))


if __name__ == '__main__':
    main()
