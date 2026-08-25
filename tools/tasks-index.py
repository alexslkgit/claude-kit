#!/usr/bin/env python3
"""Regenerate $HOME/Tasks/index.html — the single index page of every task
board and plan on this Mac, served at http://localhost:8899/index.html.

Scans two kinds of task sources under SHELF = ~/Tasks:

1. Shelf tasks: direct subdirectories of SHELF not starting with '_'.
   Each is expected to hold board.html (and optionally plan.html).
2. Repo tasks: SHELF/_repos/<repo>/ is a symlink into a repository's
   .claude/tasks directory. Every *.html file directly inside it (except
   under _shell/ and except *.plan.html files, which are paired with a
   same-stem board when one exists) is one entry.

stdlib only, no external assets in the generated page.
"""
import html
import os
import re
from datetime import datetime

SHELF = os.path.expanduser('~/Tasks')
OUT = os.path.join(SHELF, 'index.html')

TITLE_RE = re.compile(r'<title[^>]*>(.*?)</title>', re.IGNORECASE | re.DOTALL)
H1_RE = re.compile(r'<h1[^>]*>(.*?)</h1>', re.IGNORECASE | re.DOTALL)
TAG_RE = re.compile(r'<[^>]+>')


def clean_label(raw):
    """Strip tags/entities from an extracted <title>/<h1> so it's plain text."""
    text = TAG_RE.sub('', raw)
    text = html.unescape(text)
    return ' '.join(text.split())


def label_from_html(path, fallback):
    try:
        with open(path, 'r', encoding='utf-8', errors='replace') as f:
            content = f.read(20000)
    except OSError:
        return fallback
    m = TITLE_RE.search(content)
    if m:
        label = clean_label(m.group(1))
        if label:
            return label
    m = H1_RE.search(content)
    if m:
        label = clean_label(m.group(1))
        if label:
            return label
    return fallback


def mtime_of(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0.0


def fmt_date(ts):
    if not ts:
        return ''
    return datetime.fromtimestamp(ts).strftime('%d.%m.%Y')


def collect_shelf_rows():
    rows = []
    if not os.path.isdir(SHELF):
        return rows
    for name in sorted(os.listdir(SHELF)):
        if name.startswith('_'):
            continue
        task_dir = os.path.join(SHELF, name)
        if not os.path.isdir(task_dir):
            continue
        board = os.path.join(task_dir, 'board.html')
        plan = os.path.join(task_dir, 'plan.html')
        has_board = os.path.isfile(board)
        has_plan = os.path.isfile(plan)
        label = label_from_html(board, name) if has_board else name
        mtime = mtime_of(board) if has_board else mtime_of(task_dir)
        rows.append({
            'label': label,
            'href': f'{name}/board.html' if has_board else None,
            'plan_href': f'{name}/plan.html' if has_plan else None,
            'mtime': mtime,
        })
    return rows


def collect_repo_groups():
    groups = []
    repos_dir = os.path.join(SHELF, '_repos')
    if not os.path.isdir(repos_dir):
        return groups
    for repo in sorted(os.listdir(repos_dir)):
        repo_dir = os.path.join(repos_dir, repo)
        if not os.path.isdir(repo_dir):
            continue
        rows = []
        try:
            entries = sorted(os.listdir(repo_dir))
        except OSError:
            continue
        for entry in entries:
            if not entry.endswith('.html'):
                continue
            if entry.endswith('.plan.html'):
                continue
            full = os.path.join(repo_dir, entry)
            if not os.path.isfile(full):
                continue
            stem = entry[:-len('.html')]
            plan_name = f'{stem}.plan.html'
            plan_path = os.path.join(repo_dir, plan_name)
            has_plan = os.path.isfile(plan_path)
            label = label_from_html(full, stem)
            rows.append({
                'label': label,
                'href': f'_repos/{repo}/{entry}',
                'plan_href': f'_repos/{repo}/{plan_name}' if has_plan else None,
                'mtime': mtime_of(full),
            })
        if rows:
            rows.sort(key=lambda r: r['mtime'], reverse=True)
            groups.append((repo, rows))
    return groups


def render_row(row):
    date = fmt_date(row['mtime'])
    if row['href']:
        main = f'<a href="{html.escape(row["href"])}">{html.escape(row["label"])}</a>'
        cls = 'row'
    else:
        main = f'<span class="missing">{html.escape(row["label"])} — <em>страницы нет</em></span>'
        cls = 'row row-missing'
    plan = ''
    if row.get('plan_href'):
        plan = f' <a class="plan" href="{html.escape(row["plan_href"])}">план</a>'
    return (
        f'<li class="{cls}">'
        f'<span class="label">{main}{plan}</span>'
        f'<span class="date">{date}</span>'
        f'</li>'
    )


def render_page(shelf_rows, repo_groups):
    shelf_rows_sorted = sorted(shelf_rows, key=lambda r: r['mtime'], reverse=True)
    shelf_html = '\n'.join(render_row(r) for r in shelf_rows_sorted) or '<li class="empty">пусто</li>'

    repo_sections = []
    for repo, rows in repo_groups:
        items = '\n'.join(render_row(r) for r in rows)
        repo_sections.append(
            f'<h3>{html.escape(repo)}</h3>\n<ul class="rows">\n{items}\n</ul>'
        )
    repos_html = '\n'.join(repo_sections) or '<p class="empty">пусто</p>'

    generated = datetime.now().strftime('%d.%m.%Y %H:%M')

    return f'''<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Задачи</title>
<style>
:root {{
  --bg: #f7f7f5;
  --fg: #1c1c1e;
  --fg-muted: #6b6b6f;
  --border: #e2e2e0;
  --link: #0a5fd6;
  --link-visited: #6a3fb0;
  --accent: #8a8a8e;
  --card-bg: #ffffff;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #121212;
    --fg: #e7e7e5;
    --fg-muted: #9a9a9d;
    --border: #2a2a2c;
    --link: #6ea8ff;
    --link-visited: #c19bff;
    --accent: #8a8a8e;
    --card-bg: #1a1a1a;
  }}
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  padding: 2.5rem 1.5rem 4rem;
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.45;
}}
main {{
  max-width: 900px;
  margin: 0 auto;
}}
h1 {{
  font-size: 1.4rem;
  font-weight: 600;
  margin: 0 0 0.25rem;
}}
.generated {{
  color: var(--fg-muted);
  font-size: 0.85rem;
  margin: 0 0 2rem;
}}
h2 {{
  font-size: 1.05rem;
  font-weight: 600;
  border-bottom: 1px solid var(--border);
  padding-bottom: 0.4rem;
  margin: 2.5rem 0 0.75rem;
}}
h3 {{
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--fg-muted);
  margin: 1.5rem 0 0.4rem;
}}
ul.rows {{
  list-style: none;
  margin: 0;
  padding: 0;
}}
li.row {{
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 1rem;
  padding: 0.45rem 0;
  border-bottom: 1px solid var(--border);
}}
li.empty {{
  color: var(--fg-muted);
  padding: 0.45rem 0;
}}
.label {{
  flex: 1;
  min-width: 0;
  overflow-wrap: break-word;
}}
.date {{
  flex-shrink: 0;
  color: var(--fg-muted);
  font-size: 0.85rem;
  font-variant-numeric: tabular-nums;
}}
a {{
  color: var(--link);
  text-decoration: none;
}}
a:visited {{
  color: var(--link-visited);
}}
a:hover {{
  text-decoration: underline;
}}
a.plan {{
  color: var(--accent);
  font-size: 0.85rem;
  margin-left: 0.4rem;
}}
.row-missing .label {{
  color: var(--fg-muted);
}}
.missing em {{
  font-style: normal;
  color: var(--fg-muted);
}}
</style>
</head>
<body>
<main>
<h1>Задачи</h1>
<p class="generated">обновлено {generated}</p>

<h2>Задачи</h2>
<ul class="rows">
{shelf_html}
</ul>

<h2>Репозитории</h2>
{repos_html}
</main>
</body>
</html>
'''


def main():
    shelf_rows = collect_shelf_rows()
    repo_groups = collect_repo_groups()
    page = render_page(shelf_rows, repo_groups)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(page)
    repo_pages = sum(len(rows) for _, rows in repo_groups)
    print(f'tasks-index: {len(shelf_rows)} shelf tasks, {repo_pages} repo pages -> {OUT}')


if __name__ == '__main__':
    main()
