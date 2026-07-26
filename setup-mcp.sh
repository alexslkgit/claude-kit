#!/usr/bin/env bash
# Register the user-scoped MCP servers this workflow needs. Idempotent.
#
#   ./setup-mcp.sh
#
# Uses the `claude` CLI when it is on PATH, and otherwise writes the same user-scope entries
# straight into ~/.claude.json (that is where `--scope user` stores them). A backup is made
# before any edit.
#
# Authentication is NOT done here: both servers use in-browser OAuth. After running this,
# start a session and run `/mcp`, pick the server, Authenticate. Or `claude mcp login <name>`
# if the CLI is installed. A non-interactive run (`claude -p`) cannot do the OAuth flow.
#
# Endpoints verified 2026-07-26:
#  - Atlassian: https://mcp.atlassian.com/v1/mcp/authv2 over Streamable HTTP. The old
#    /v1/sse endpoint is deprecated (cutoff 2026-06-30) — do not use `--transport sse`.
#    Requires an Atlassian *Cloud* site; Server/Data Center is not supported.
#  - Figma: https://mcp.figma.com/mcp, remote and recommended over the desktop
#    127.0.0.1:3845 server, which Figma now de-recommends.
#
# The browser is deliberately NOT an MCP server here. Claude Code's built-in Chrome
# integration (`claude --chrome`, or `/chrome` -> "Enabled by default") is the only option
# that reuses your already-logged-in browser session, which is the whole point for reading a
# Teams or Slack web UI. Opening a remote-debugging port instead forces a blank profile.

set -euo pipefail

add_via_cli() {
  local name="$1" url="$2"
  if claude mcp list 2>/dev/null | grep -q "^${name}[: ]"; then
    echo "  ${name}: already registered"
  else
    claude mcp add --transport http --scope user "$name" "$url" >/dev/null
    echo "  ${name}: added (${url})"
  fi
}

if command -v claude >/dev/null 2>&1; then
  echo "Registering MCP servers via the claude CLI"
  add_via_cli atlassian https://mcp.atlassian.com/v1/mcp/authv2
  add_via_cli figma https://mcp.figma.com/mcp
elif command -v python3 >/dev/null 2>&1; then
  echo "claude CLI not on PATH — writing user-scope entries to ~/.claude.json"
  python3 - "$HOME/.claude.json" <<'PY'
import json, os, shutil, sys
path = sys.argv[1]
wanted = {
    "atlassian": {"type": "http", "url": "https://mcp.atlassian.com/v1/mcp/authv2"},
    "figma":     {"type": "http", "url": "https://mcp.figma.com/mcp"},
}
data = {}
if os.path.exists(path):
    with open(path) as f:
        raw = f.read()
    if raw.strip():
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            sys.exit(f"  ~/.claude.json is not valid JSON ({e}); refusing to touch it")
servers = data.setdefault("mcpServers", {})
changed = [n for n, cfg in wanted.items() if servers.get(n) != cfg]
if not changed:
    print("  atlassian, figma: already registered")
else:
    if os.path.exists(path):
        shutil.copyfile(path, path + ".bak")
    for n in changed:
        servers[n] = wanted[n]
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    json.load(open(tmp))  # fail before replacing the real file
    os.replace(tmp, path)
    print(f"  registered: {', '.join(changed)} (backup at {path}.bak)")
PY
else
  echo "  neither the claude CLI nor python3 is available — register the servers by hand:"
  echo "    claude mcp add --transport http --scope user atlassian https://mcp.atlassian.com/v1/mcp/authv2"
  echo "    claude mcp add --transport http --scope user figma https://mcp.figma.com/mcp"
  exit 1
fi

cat <<'EOF'

Next, once per machine:
  1. Restart Claude Code, then run /mcp and Authenticate atlassian and figma in the browser.
  2. Run /chrome and pick "Enabled by default" if you want browser access always on;
     otherwise start sessions with `claude --chrome` when a task needs a web UI.
EOF
