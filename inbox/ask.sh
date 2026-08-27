#!/bin/bash
# ask.sh — put one request in front of the owner and, optionally, wait for his click.
#
# Any Claude session on this machine calls this instead of asking in its own chat.
# The owner sees every session's pending request in one page and answers without
# reading any of the conversations behind them.
#
#   ask.sh --title "..." --why "..." [--options "Да|Нет"] [--open "<url or command>"]
#          [--project NAME] [--session NAME] [--wait [SECONDS]]
#
# Prints the request id on stdout. With --wait it blocks and prints the answer
# instead, exiting 1 on timeout.

set -euo pipefail
IN="$HOME/.claude/inbox"
title=""; why=""; options="Да|Нет"; open=""; project=""; session=""; wait_for=""
while [ $# -gt 0 ]; do
  case "$1" in
    --title)   title="$2";   shift 2 ;;
    --why)     why="$2";     shift 2 ;;
    --options) options="$2"; shift 2 ;;
    --open)    open="$2";    shift 2 ;;
    --project) project="$2"; shift 2 ;;
    --session) session="$2"; shift 2 ;;
    --wait)    if [[ "${2:-}" =~ ^[0-9]+$ ]]; then wait_for="$2"; shift 2; else wait_for=3600; shift; fi ;;
    *) echo "ask.sh: unknown argument $1" >&2; exit 2 ;;
  esac
done
[ -n "$title" ] || { echo "ask.sh: --title is required" >&2; exit 2; }
[ -n "$project" ] || project="$(basename "$PWD")"

id="$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$IN/queue" "$IN/answers"
python3 - "$IN/queue/$id.json" "$id" "$title" "$why" "$options" "$open" "$project" "$session" <<'PY'
import json, sys, datetime
path, rid, title, why, options, open_, project, session = sys.argv[1:9]
json.dump({
    "id": rid,
    "created": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
    "project": project,
    "session": session,
    "title": title,
    "why": why,
    "options": [o for o in options.split("|") if o],
    "open": open_,
}, open(path, "w"), ensure_ascii=False, indent=1)
PY

if [ -z "$wait_for" ]; then echo "$id"; exit 0; fi

# Block until the owner answers. His click writes the answer file; nothing polls him.
deadline=$(( $(date +%s) + wait_for ))
while [ "$(date +%s)" -lt "$deadline" ]; do
  if [ -f "$IN/answers/$id.json" ]; then
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("answer",""))' "$IN/answers/$id.json"
    exit 0
  fi
  sleep 3
done
echo "ask.sh: no answer within ${wait_for}s (request $id still pending)" >&2
exit 1
