#!/usr/bin/env bash
# kit-sync.sh — get a file from the kit without paying for it twice.
#
# The problem it solves. company-brief (and any skill that exists in more than one copy: the kit
# on disk, the claude.ai account, another Mac, a cloud session) used to start every run with
# "curl the current SKILL.md and follow it if it differs". Two costs, both invisible:
#   1. the network round trip, repeated for every run in a session;
#   2. the 28 KB file read into the conversation to compare it, which is then re-sent on every
#      later request of that session. That one is the expensive half by an order of magnitude.
#
# What this does instead:
#   · a local clone of the kit, if there is one, is the source: no network at all;
#   · otherwise a cached copy under ~/.claude/cache/kit/, refreshed at most once every TTL
#     (default 3 hours, override with KIT_SYNC_TTL seconds);
#   · the refresh is a conditional request (If-None-Match / If-Modified-Since), so an unchanged
#     file costs one 304 and no body;
#   · it prints ONE line: the path, and whether the content changed since last time. Nothing is
#     ever dumped into the conversation. Read the file only when the line says CHANGED.
#
# Usage:
#   tools/kit-sync.sh skills/company-brief/SKILL.md
#   tools/kit-sync.sh skills/company-brief/assets/brief.css ~/Developer/job-search/briefs/_shell/brief.css
#   KIT_SYNC_TTL=0 tools/kit-sync.sh <path>      # force a check now
#
# Output line:
#   FRESH   <abs-path>   cached copy is current (checked <n> min ago), content unchanged
#   CHANGED <abs-path>   content differs from the copy you had; read it
#   LOCAL   <abs-path>   served from the clone at ~/Developer/claude-kit, always current
#   STALE   <abs-path>   network failed; this is the last good copy, age <n> h

set -uo pipefail
REL="${1:-}"; DEST="${2:-}"
[ -n "$REL" ] || { echo "usage: kit-sync.sh <path-in-kit> [destination]" >&2; exit 2; }

TTL="${KIT_SYNC_TTL:-10800}"                      # 3 hours
CLONE="${HOME}/Developer/claude-kit"
CACHE="${HOME}/.claude/cache/kit"
RAW="https://raw.githubusercontent.com/alexslkgit/claude-kit/main"
mkdir -p "${CACHE}/$(dirname "$REL")" 2>/dev/null || true
copy="${CACHE}/${REL}"
stamp="${copy}.stamp"
etag="${copy}.etag"

hash_of() { [ -f "$1" ] && shasum -a 1 "$1" 2>/dev/null | cut -c1-12 || echo none; }
deliver() {                                        # $1 = verdict, $2 = source file, $3 = note
  local src="$2"
  if [ -n "$DEST" ] && [ "$src" != "$DEST" ]; then mkdir -p "$(dirname "$DEST")"; cp "$src" "$DEST"; src="$DEST"; fi
  printf '%s %s   %s\n' "$1" "$src" "${3:-}"
}

# 1. A clone on this machine wins outright: it is the working copy, and install.sh comes from it.
if [ -f "${CLONE}/${REL}" ]; then
  deliver LOCAL "${CLONE}/${REL}" "from the clone, no network"
  exit 0
fi

before="$(hash_of "$copy")"
age=999999
[ -f "$stamp" ] && age=$(( $(date +%s) - $(cat "$stamp" 2>/dev/null || echo 0) ))

# 2. Inside the TTL a cached copy is used as is. This is the whole point: a session that runs the
#    same skill ten times checks the network once.
if [ -f "$copy" ] && [ "$age" -lt "$TTL" ]; then
  deliver FRESH "$copy" "checked $((age/60)) min ago, TTL $((TTL/60)) min"
  exit 0
fi

# 3. Past the TTL, one conditional request. 304 means nothing came down the wire.
tmp="${copy}.new"
args=(-sSL -o "$tmp" -w '%{http_code}' --etag-save "$etag")
[ -f "$etag" ] && args+=(--etag-compare "$etag")
[ -f "$copy" ] && args+=(-z "$copy")
code="$(curl "${args[@]}" "${RAW}/${REL}" 2>/dev/null)"
code="${code:-000}"
if [ "$code" = "200" ] && [ -s "$tmp" ]; then
  mv "$tmp" "$copy"; date +%s > "$stamp"
  after="$(hash_of "$copy")"
  if [ "$before" = "$after" ]; then deliver FRESH "$copy" "re-checked, content unchanged"
  else deliver CHANGED "$copy" "content differs from the copy you had, read it"; fi
  exit 0
fi
rm -f "$tmp"
if [ "$code" = "304" ]; then date +%s > "$stamp"; deliver FRESH "$copy" "304, unchanged upstream"; exit 0; fi
if [ -f "$copy" ]; then deliver STALE "$copy" "network failed (${code}), copy is $((age/3600)) h old"; exit 0; fi
echo "MISSING ${REL}   no clone, no cache, network failed (${code})" >&2
exit 1
