#!/usr/bin/env bash
# board-port-guard.sh — keeps port 8899 answering with the board shelf on BOTH localhost addresses.
#
# Why it exists. On 2026-09-06 the owner clicked a board link and got a 404. The LaunchAgent was
# up and serving ~/Tasks on 127.0.0.1:8899, but another session had left a stray
# `python -m http.server 8899` behind, bound to `*` over IPv6, and Chrome resolves `localhost`
# to ::1 first. So every board link on the machine was answered by a finance app's public folder.
# Two fixes: the LaunchAgent now binds `::`, which on macOS holds both address families so a
# stray cannot take either; and this hook, at session start and on every prompt, kills any
# listener on 8899 that is not the agent's and restarts the agent when either address is wrong.
#
# Exits 0 always; speaks only when it did something or when the port is down.

set -uo pipefail
exec 2>/dev/null

PORT=8899
LABEL="com.alexslk.tasks-board-server"
EVENT="$(python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("hook_event_name",""))
except Exception: print("")' 2>/dev/null || true)"

probe() { curl -s -m 1 -o /dev/null -w '%{http_code}' "http://$1:${PORT}/_repos/" 2>/dev/null || echo 000; }
ours() { launchctl print "gui/$(id -u)/${LABEL}" 2>/dev/null | grep -E '^[[:space:]]*pid = ' | awk '{print $3}'; }

acted=""
agent_pid="$(ours)"
for pid in $(lsof -nP -iTCP:${PORT} -sTCP:LISTEN -t 2>/dev/null | sort -u); do
  [ "$pid" = "${agent_pid:-x}" ] && continue
  cmd="$(ps -o command= -p "$pid" 2>/dev/null)"
  # The agent's own server is recognised twice over: by launchd's pid and by the bind it alone uses.
  case "$cmd" in *"--bind ::"*) continue ;; esac
  case "$cmd" in
    *http.server*"${PORT}"*) kill "$pid" 2>/dev/null && acted="${acted} killed stray listener pid ${pid} (${cmd##*/});" ;;
  esac
done

if [ "$(probe 127.0.0.1)" != "200" ] || [ "$(probe '[::1]')" != "200" ]; then
  launchctl kickstart -k "gui/$(id -u)/${LABEL}" 2>/dev/null \
    || launchctl bootstrap "gui/$(id -u)" "${HOME}/Library/LaunchAgents/${LABEL}.plist" 2>/dev/null
  for _ in 1 2 3 4 5 6 7 8; do
    [ "$(probe 127.0.0.1)" = "200" ] && [ "$(probe '[::1]')" = "200" ] && { acted="${acted} restarted the board server;"; break; }
    sleep 0.3
  done
fi

v4="$(probe 127.0.0.1)"; v6="$(probe '[::1]')"
if [ "$v4" != "200" ] || [ "$v6" != "200" ]; then
  echo "board-port-guard: http://localhost:${PORT} is NOT serving the board shelf (v4 ${v4}, v6 ${v6})."
  echo "Fix: cd ~/Developer/claude-kit && ./install.sh   (reinstalls the LaunchAgent bound on ::)."
  echo "Until then every board link you give him 404s; say so instead of pasting one."
  exit 0
fi
[ -n "$acted" ] && echo "board-port-guard:${acted} board links answer on both addresses again."
exit 0
