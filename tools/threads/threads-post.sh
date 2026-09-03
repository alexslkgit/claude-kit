#!/bin/bash
# Publish a text post on his Threads account through the official API.
#
#   threads-post.sh "text of the post"            text only (a URL inside the text becomes a link)
#   threads-post.sh "text" https://example.com    text plus a link attachment card
#   threads-post.sh --file post.txt [url]         text from a file
#   threads-post.sh --dry "text"                  print what would be sent, send nothing
#
# Token and user id come from the keychain (threads-auth.sh). Limit: 500 characters, 250 posts a day.
# Publishing is outward-facing: run only after he said to post THIS text.
set -euo pipefail
SVC=claude-kit-threads; API=https://graph.threads.net/v1.0
kc_get() { security find-generic-password -s "$SVC" -a "$1" -w 2>/dev/null || true; }
dry=0; [ "${1:-}" = "--dry" ] && { dry=1; shift; }
if [ "${1:-}" = "--file" ]; then text="$(cat "$2")"; link="${3:-}"; else text="${1:-}"; link="${2:-}"; fi
[ -n "$text" ] || { sed -n 2,9p "$0"; exit 2; }
n="$(printf '%s' "$text" | python3 -c 'import sys;print(len(sys.stdin.read()))')"
[ "$n" -le 500 ] || { echo "post is $n characters, the limit is 500" >&2; exit 2; }
if [ "$dry" = 1 ]; then printf 'DRY RUN, %s chars, link=%s\n---\n%s\n' "$n" "${link:-none}" "$text"; exit 0; fi
tok="$(kc_get token)"; uid="$(kc_get user-id)"
[ -n "$tok" ] && [ -n "$uid" ] || { echo "no token or user id in keychain, run threads-auth.sh first" >&2; exit 2; }
args=(-d media_type=TEXT --data-urlencode "text=$text" -d "access_token=$tok")
[ -n "$link" ] && args+=(--data-urlencode "link_attachment=$link")
c="$(curl -sS -X POST "$API/$uid/threads" "${args[@]}")"
cid="$(printf '%s' "$c" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')"
[ -n "$cid" ] || { echo "container failed: $(printf '%s' "$c" | sed 's/[A-Za-z0-9_-]\{40,\}/<redacted>/g')" >&2; exit 1; }
sleep 3
p="$(curl -sS -X POST "$API/$uid/threads_publish" -d "creation_id=$cid" -d "access_token=$tok")"
pid="$(printf '%s' "$p" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("id",""))')"
[ -n "$pid" ] || { echo "publish failed: $(printf '%s' "$p" | sed 's/[A-Za-z0-9_-]\{40,\}/<redacted>/g')" >&2; exit 1; }
link_out="$(curl -sS "$API/$pid?fields=permalink&access_token=$tok" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("permalink",""))')"
echo "published: ${link_out:-id $pid}"
