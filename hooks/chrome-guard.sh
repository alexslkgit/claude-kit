#!/usr/bin/env bash
# chrome-guard.sh — tells every new session which connected Chrome is which.
#
# The problem, stated by the user 2026-08-17 after months of it: several of his Macs are signed
# into one Claude account, so `list_connected_browsers` always returns several browsers, and
# every field it returns is useless for telling them apart —
#
#   name       "Browser 1..N", assigned by position in the list, so it changes when another Mac
#              connects or drops
#   isLocal    verified false: three browsers on three OTHER Macs all reported isLocal: true
#   connectedAt a hint at best
#
# The product's own answer — name the browser while confirming it in `switch_browser` — does not
# stick: he has typed a name into that dialog for months and the list still says "Browser N"
# (re-verified 2026-08-17: naming a browser "Luft-Mac" left the list unchanged).
#
# So the names live here instead, in a file the kit syncs between machines, keyed by deviceId,
# and this hook injects them at session start so the model never has to go looking. It is a hook
# and not a skill for the usual reason: a skill is obeyed at the model's discretion, a hook runs.
#
# SessionStart stdout IS injected as a system message (see status-guard.sh for the event table).

set -uo pipefail

REG="$HOME/Developer/claude-kit/chrome-browsers.json"
[ -f "$REG" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

python3 - "$REG" <<'PY'
import json, socket, sys

try:
    with open(sys.argv[1]) as f:
        data = json.load(f)
except Exception:
    raise SystemExit(0)

rows = data.get("browsers") or []
if not rows:
    raise SystemExit(0)

here = socket.gethostname().split(".")[0]
lines = []
for b in rows:
    host = b.get("hostname") or ""
    mine = " ← THIS Mac" if host.split(".")[0] == here else ""
    who = host or "unknown Mac"
    prof = b.get("chromeProfileName") or b.get("chromeProfileDir") or ""
    prof = f" ({prof})" if prof else ""
    seen = b.get("verified", "")
    conf = "" if b.get("method") == "localhost-probe" else "  [unconfirmed]"
    lines.append(f"  {b.get('deviceId','?')}  {who}{prof}{mine}  verified {seen}{conf}")

print("chrome-guard: connected Chromes are not identifiable from the tool output — their names")
print("are positional and isLocal is wrong. Known mapping, from claude-kit/chrome-browsers.json:")
print("\n".join(lines))
print("Use these names in any question you must ask him; never show him \"Browser N\".")
print("An unknown deviceId, or zero browsers matching this Mac: run the `chrome-pick` skill —")
print("it identifies the local one with a localhost probe at no cost to him, and records it here.")
PY
