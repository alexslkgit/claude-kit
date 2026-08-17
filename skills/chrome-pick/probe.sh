#!/usr/bin/env bash
# Identify which connected Chrome runs on THIS Mac.
#
# Only a browser on this machine can reach this machine's loopback, so we serve a URL on
# 127.0.0.1 and see whose fetch arrives.
#
#   probe.sh start   -> starts the server, prints PROBE_URL=http://127.0.0.1:<port>/probe-
#   probe.sh check   -> prints the probe tags that reached this Mac (one line each)
#   probe.sh stop    -> stops the server and removes the state
#
# Between start and check, drive each candidate browser to <PROBE_URL><tag>.

set -euo pipefail

DIR="${TMPDIR:-/tmp}/claude-chrome-probe"
LOG="$DIR/probe.log"
PID="$DIR/probe.pid"
PORT_FILE="$DIR/port"

case "${1:-}" in
  start)
    mkdir -p "$DIR"
    [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null || true
    rm -f "$LOG" "$PID" "$PORT_FILE"
    PORT=$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')
    ( cd "$DIR" && nohup python3 -m http.server "$PORT" --bind 127.0.0.1 >"$LOG" 2>&1 & echo $! >"$PID" )
    echo "$PORT" >"$PORT_FILE"
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      curl -s -o /dev/null --max-time 1 "http://127.0.0.1:$PORT/selftest" && break
      sleep 0.2
    done
    if ! grep -q selftest "$LOG" 2>/dev/null; then
      echo "FAILED: local server did not answer its own request on port $PORT" >&2
      exit 1
    fi
    echo "PROBE_URL=http://127.0.0.1:$PORT/probe-"
    ;;
  check)
    [ -f "$LOG" ] || { echo "not started" >&2; exit 1; }
    if grep -o 'probe-[A-Za-z0-9_-]*' "$LOG" | sort -u | grep .; then
      :
    else
      echo "NO HITS: no connected browser is on this Mac (local extension is probably signed out)"
    fi
    ;;
  stop)
    [ -f "$PID" ] && kill "$(cat "$PID")" 2>/dev/null || true
    pkill -f "http.server $(cat "$PORT_FILE" 2>/dev/null || echo __none__)" 2>/dev/null || true
    rm -rf "$DIR"
    echo "stopped"
    ;;
  *)
    echo "usage: probe.sh start|check|stop" >&2
    exit 2
    ;;
esac
