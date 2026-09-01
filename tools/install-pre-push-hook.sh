#!/usr/bin/env bash
# install-pre-push-hook.sh — chains the test-net into a repo's OWN pre-push hook, never replaces it.
#
# Why chaining and not `core.hooksPath`. `core.hooksPath` is machine-wide: setting it once would
# have been the simpler install, but git then stops looking at `.git/hooks` for EVERY hook type in
# EVERY repo on the machine, not just `pre-push`. The Lufthansa iOS repo already has a real
# `pre-push` (git-lfs, blocks a push missing LFS objects) and a real `pre-commit` (swiftlint,
# swiftformat). Pointing hooksPath at the kit would have silently turned both off. So this script
# edits the repo's existing `.git/hooks/pre-push` in place instead, appending a small forwarding
# block between markers, after whatever was already there — the existing hook still runs, still
# blocks when it decides to, and our test-net only ever adds a background job on top.
#
# Idempotent: running this twice on the same repo changes nothing the second time. It is called
# lazily by hooks/test-net-guard.sh the moment a `git push` is about to run from that repo, which
# is also what makes this reach a repo that already existed before the kit did — nothing here
# depends on when the repo was cloned.
#
# Usage: install-pre-push-hook.sh <repo-root>
# Always exits 0; a repo it cannot touch is left exactly as it was.

set -uo pipefail

repo_root="${1:-}"
[ -n "$repo_root" ] && [ -d "$repo_root/.git" ] || exit 0

hook_dir="$repo_root/.git/hooks"
hook_file="$hook_dir/pre-push"
BEGIN="# >>> claude-kit test-net (managed by install.sh; edit the kit, not this block) >>>"
END="# <<< claude-kit test-net <<<"
target="$HOME/.claude/hooks/pre-push-test-net.sh"

mkdir -p "$hook_dir" 2>/dev/null || exit 0

if [ -f "$hook_file" ] && grep -qF "$BEGIN" "$hook_file" 2>/dev/null; then
  # Already installed. Re-stamp only if the forwarded path changed (e.g. a fresh machine).
  grep -qF "$target" "$hook_file" 2>/dev/null && exit 0
fi

block=$(cat <<EOF
$BEGIN
if [ -x "$target" ]; then
  "$target" "\$@"
fi
$END
EOF
)

if [ ! -f "$hook_file" ]; then
  printf '#!/bin/sh\n\n%s\n' "$block" > "$hook_file" 2>/dev/null || exit 0
  chmod +x "$hook_file" 2>/dev/null || true
  exit 0
fi

if grep -qF "$BEGIN" "$hook_file" 2>/dev/null; then
  # Stale block from an older kit path — replace just that block, keep everything else.
  awk -v b="$BEGIN" -v e="$END" '
    $0==b {skip=1}
    !skip {print}
    $0==e {skip=0}
  ' "$hook_file" > "$hook_file.tmp.$$" 2>/dev/null && mv "$hook_file.tmp.$$" "$hook_file"
fi

printf '\n%s\n' "$block" >> "$hook_file" 2>/dev/null || exit 0
chmod +x "$hook_file" 2>/dev/null || true
exit 0
