#!/usr/bin/env python3
"""Add built-in tools to a project's permissions.deny.

A denied built-in tool is dropped from the system prompt entirely, not merely blocked
(measured 2026-08-31: -23 333 tokens of session floor for four tools). Denying an MCP
tool does NOT remove its schema, so only built-ins are worth listing here.

usage: deny-tools.py <project-dir> <Tool> [<Tool> ...]
       deny-tools.py --show <project-dir>
"""
import json, os, sys

def path_for(proj):
    return os.path.join(os.path.expanduser(proj), ".claude", "settings.local.json")

def load(p):
    if not os.path.exists(p):
        return {}
    with open(p) as fh:
        return json.load(fh)

def main(argv):
    if len(argv) < 2:
        print(__doc__); return 2
    if argv[0] == "--show":
        p = path_for(argv[1])
        d = load(p)
        print(p, json.dumps(d.get("permissions", {}).get("deny", []), indent=2))
        return 0
    proj, tools = argv[0], argv[1:]
    p = path_for(proj)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    d = load(p)
    perms = d.setdefault("permissions", {})
    deny = perms.setdefault("deny", [])
    added = [t for t in tools if t not in deny]
    deny.extend(added)
    with open(p, "w") as fh:
        json.dump(d, fh, indent=2)
        fh.write("\n")
    print(f"{p}: added {added or 'nothing'}, deny now {deny}")
    return 0

if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
