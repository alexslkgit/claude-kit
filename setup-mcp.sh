#!/usr/bin/env bash
# Register user-scoped MCP servers — per machine, by explicit name. Idempotent.
#
#   ./setup-mcp.sh jira          # Atlassian Cloud (Jira + Confluence)
#   ./setup-mcp.sh figma
#   ./setup-mcp.sh jira figma
#   ./setup-mcp.sh --remove jira figma
#
# NOT called by install.sh, deliberately: the machines differ, and a registered server that
# was never authenticated prints a "needs sign-in" notice at every session start. Install only
# what this machine actually has.
#
# Uses the `claude` CLI when it is on PATH; otherwise writes the same user-scope entries into
# ~/.claude.json (where `--scope user` stores them), with a backup and JSON validation.
#
# Authentication is not done here — both use in-browser OAuth. Afterwards: restart Claude Code,
# run /mcp, pick the server, Authenticate. Or `claude mcp login <name>`. A non-interactive run
# (`claude -p`) cannot complete OAuth, so sign in from a real session first.
#
# Endpoints verified 2026-07-26:
#  - jira  -> https://mcp.atlassian.com/v1/mcp/authv2 over Streamable HTTP. The old /v1/sse
#    endpoint is deprecated (cutoff 2026-06-30, already passed) — never use `--transport sse`.
#    Requires an Atlassian *Cloud* site; Server and Data Center are not supported.
#  - figma -> https://mcp.figma.com/mcp, remote. Figma now de-recommends its local
#    127.0.0.1:3845 desktop server, so the desktop app does not need to be running.
#
# The browser is deliberately absent. Claude Code's built-in Chrome integration
# (`claude --chrome`, or `/chrome` -> "Enabled by default") is the only option that reuses an
# already-logged-in session, which is the entire point for a Teams or Slack web UI. Chrome
# refuses --remote-debugging-port on the default profile, so Chrome DevTools MCP and Playwright
# MCP both hand you a blank profile and a fresh login prompt.

set -euo pipefail

# No associative arrays: macOS ships bash 3.2, where `declare -A` does not exist.
url_for() {
  case "$1" in
    atlassian) echo "https://mcp.atlassian.com/v1/mcp/authv2" ;;
    figma)     echo "https://mcp.figma.com/mcp" ;;
    *)         return 1 ;;
  esac
}

MODE="add"
NAMES=()
for arg in "$@"; do
  case "$arg" in
    --remove) MODE="remove" ;;
    jira|atlassian) NAMES+=(atlassian) ;;
    figma) NAMES+=(figma) ;;
    *) echo "unknown integration: ${arg} (known: jira, figma)" >&2; exit 2 ;;
  esac
done

if [ ${#NAMES[@]} -eq 0 ]; then
  cat >&2 <<'EOF'
Name the integrations this machine has:
  ./setup-mcp.sh jira
  ./setup-mcp.sh figma
  ./setup-mcp.sh jira figma
  ./setup-mcp.sh --remove jira figma
EOF
  exit 2
fi

if command -v claude >/dev/null 2>&1; then
  for name in "${NAMES[@]}"; do
    if [ "$MODE" = "remove" ]; then
      claude mcp remove --scope user "$name" >/dev/null 2>&1 && echo "  ${name}: removed" \
        || echo "  ${name}: was not registered"
    elif claude mcp list 2>/dev/null | grep -q "^${name}[: ]"; then
      echo "  ${name}: already registered"
    else
      claude mcp add --transport http --scope user "$name" "$(url_for "$name")" >/dev/null
      echo "  ${name}: added"
    fi
  done
elif command -v python3 >/dev/null 2>&1; then
  echo "claude CLI not on PATH — editing ~/.claude.json directly"
  MODE="$MODE" NAMES="${NAMES[*]}" \
  URLS="atlassian=$(url_for atlassian) figma=$(url_for figma)" \
  python3 - "$HOME/.claude.json" <<'PY'
import json, os, shutil, sys
path = sys.argv[1]
mode = os.environ["MODE"]
names = os.environ["NAMES"].split()
urls = dict(kv.split("=", 1) for kv in os.environ["URLS"].split())

data = {}
if os.path.exists(path):
    raw = open(path).read()
    if raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            sys.exit(f"  ~/.claude.json is not valid JSON ({e}); refusing to touch it")

servers = data.get("mcpServers", {})
changed = []
for n in names:
    if mode == "remove":
        if servers.pop(n, None) is not None:
            changed.append(f"-{n}")
    else:
        cfg = {"type": "http", "url": urls[n]}
        if servers.get(n) != cfg:
            servers[n] = cfg
            changed.append(f"+{n}")

if not changed:
    print(f"  {', '.join(names)}: already as requested")
else:
    if servers:
        data["mcpServers"] = servers
    else:
        data.pop("mcpServers", None)
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak")
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    json.load(open(tmp))  # fail before replacing the real file
    os.replace(tmp, path)
    print(f"  {' '.join(changed)} (backup at {path}.bak)")
PY
else
  echo "  neither the claude CLI nor python3 is available — register by hand:" >&2
  for name in "${NAMES[@]}"; do
    echo "    claude mcp add --transport http --scope user ${name} $(url_for "$name")" >&2
  done
  exit 1
fi

if [ "$MODE" = "add" ]; then
  cat <<'EOF'

Next, once on this machine:
  1. Restart Claude Code, run /mcp, and Authenticate each server in the browser.
  2. If this machine reads Teams or Slack in the browser, run /chrome once. Prefer
     `claude --chrome` per session over "Enabled by default" — always-on costs context.
EOF
fi
