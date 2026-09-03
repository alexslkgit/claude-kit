#!/bin/bash
# Threads API auth for the kit. Secrets live in the login keychain, never in files or chat.
#
#   threads-auth.sh app-id <id>        store the Meta app id
#   threads-auth.sh store-secret       store the app secret from the CLIPBOARD (he copies it on the
#                                      dashboard with one click; it never passes through a chat)
#   threads-auth.sh url [redirect]     print the authorize URL to open in his signed-in browser
#   threads-auth.sh exchange <code|url> [redirect]
#                                      code -> short-lived -> long-lived token, store token + user id
#   threads-auth.sh refresh            refresh the long-lived token (valid 60 days, refresh after 24h)
#   threads-auth.sh whoami             GET /me, proves the stored token works
#
# Docs: https://developers.facebook.com/docs/threads/get-started
set -euo pipefail
SVC=claude-kit-threads
REDIRECT_DEFAULT="https://localhost/threads-callback"
API=https://graph.threads.net
kc_get() { security find-generic-password -s "$SVC" -a "$1" -w 2>/dev/null || true; }
kc_set() { security add-generic-password -U -s "$SVC" -a "$1" -w "$2" >/dev/null; }

case "${1:-}" in
app-id)
  [ -n "${2:-}" ] || { echo "usage: threads-auth.sh app-id <id>" >&2; exit 2; }
  kc_set app-id "$2"; echo "app id stored" ;;
store-secret)
  s="$(pbpaste | tr -d '[:space:]')"
  [ ${#s} -ge 20 ] || { echo "clipboard does not look like an app secret (${#s} chars)" >&2; exit 2; }
  kc_set app-secret "$s"; pbcopy </dev/null; echo "app secret stored (${#s} chars), clipboard cleared" ;;
url)
  id="$(kc_get app-id)"; [ -n "$id" ] || { echo "no app id stored" >&2; exit 2; }
  r="${2:-$REDIRECT_DEFAULT}"
  printf 'https://threads.net/oauth/authorize?client_id=%s&redirect_uri=%s&scope=threads_basic,threads_content_publish&response_type=code&state=kit\n' \
    "$id" "$(python3 -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1],safe=""))' "$r")" ;;
exchange)
  [ -n "${2:-}" ] || { echo "usage: threads-auth.sh exchange <code or redirected url>" >&2; exit 2; }
  code="$(python3 -c '
import sys,urllib.parse
a=sys.argv[1]
if "code=" in a:
    q=urllib.parse.urlparse(a).query or a.split("?",1)[-1]
    a=urllib.parse.parse_qs(q)["code"][0]
print(a.split("#")[0])' "$2")"
  id="$(kc_get app-id)"; sec="$(kc_get app-secret)"; r="${3:-$REDIRECT_DEFAULT}"
  [ -n "$id" ] && [ -n "$sec" ] || { echo "app id or secret missing in keychain" >&2; exit 2; }
  short="$(curl -sS -X POST "$API/oauth/access_token" \
    -d client_id="$id" -d client_secret="$sec" -d grant_type=authorization_code \
    -d redirect_uri="$r" -d code="$code")"
  tok="$(printf '%s' "$short" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token",""))')"
  [ -n "$tok" ] || { echo "short-lived exchange failed: $(printf '%s' "$short" | sed 's/[A-Za-z0-9_-]\{40,\}/<redacted>/g')" >&2; exit 1; }
  uid="$(printf '%s' "$short" | python3 -c 'import sys,json;print(json.load(sys.stdin).get("user_id",""))')"
  long="$(curl -sS "$API/access_token?grant_type=th_exchange_token&client_secret=$sec&access_token=$tok")"
  ltok="$(printf '%s' "$long" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token",""))')"
  [ -n "$ltok" ] || { echo "long-lived exchange failed: $(printf '%s' "$long" | sed 's/[A-Za-z0-9_-]\{40,\}/<redacted>/g')" >&2; exit 1; }
  kc_set token "$ltok"; kc_set user-id "$uid"; kc_set token-date "$(date -u +%F)"
  echo "long-lived token stored for user $uid, expires in ~60 days; refresh with: threads-auth.sh refresh" ;;
refresh)
  tok="$(kc_get token)"; [ -n "$tok" ] || { echo "no token stored" >&2; exit 2; }
  out="$(curl -sS "$API/refresh_access_token?grant_type=th_refresh_token&access_token=$tok")"
  ntok="$(printf '%s' "$out" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("access_token",""))')"
  [ -n "$ntok" ] || { echo "refresh failed: $(printf '%s' "$out" | sed 's/[A-Za-z0-9_-]\{40,\}/<redacted>/g')" >&2; exit 1; }
  kc_set token "$ntok"; kc_set token-date "$(date -u +%F)"; echo "token refreshed $(date -u +%F)" ;;
whoami)
  tok="$(kc_get token)"; [ -n "$tok" ] || { echo "no token stored" >&2; exit 2; }
  curl -sS "$API/v1.0/me?fields=id,username,name&access_token=$tok"; echo ;;
*)
  sed -n 2,12p "$0"; exit 2 ;;
esac
