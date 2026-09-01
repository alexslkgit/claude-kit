#!/usr/bin/env bash
# pre-push-test-net.sh — the safety net behind a `git push` that was never compiled locally.
#
# The incident this exists for, 2026-09-01. A pull request on the Lufthansa iOS repo had both
# approvals and was minutes from merging. A last "cosmetic" commit rewrote a whole Quick/Nimble
# spec file — 499 lines in, 566 out — and was pushed without ever being built locally. CI went
# red. His words: he does not want to wait an hour before pushing, but he does want to know, by
# the time the pull request is ready to merge, whether the tests passed, so he never presses
# merge blind. So the test run moves off the critical path of the push entirely: it starts the
# moment the push happens and finishes on its own time, and the answer is sitting on disk,
# ready before he ever looks for it.
#
# This script is the payload a repo's own `.git/hooks/pre-push` forwards to — see
# tools/install-pre-push-hook.sh for how that forwarding line gets into a repo, chained after
# whatever hook (git-lfs, custom lint) already lived there. This file never runs directly as a
# git hook itself; it is invoked BY one, synchronously, with the push's stdin still attached, so
# it can read which refs are being pushed before that pipe closes.
#
# Contract with the push: parse stdin fast, decide, background the actual test run fully
# detached (closed stdin/stdout/stderr, `disown`ed), print one line, exit 0. Nothing in this
# script may block the push or slow it down, and nothing here may ever fail the push — every
# unexpected condition falls through to "exit 0" with at most one explanatory line on stderr.
#
# git-lfs's own pre-push hook already blocks a push when it must (missing LFS objects); this
# script does not touch that behaviour, it only rides in ADDITION to whatever was already there.

set -uo pipefail

RUN_DIR="$HOME/.claude/test-runs"
mkdir -p "$RUN_DIR" 2>/dev/null || exit 0

remote_name="${1:-origin}"
repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"
[ -n "$repo_root" ] || exit 0
cd "$repo_root" 2>/dev/null || exit 0

repo_slug="$(printf '%s' "$(basename "$repo_root")" | tr -c 'A-Za-z0-9_.-' '_')"
[ -n "$repo_slug" ] || repo_slug="repo"

# --- default branch, so a push to it is never treated as a work branch --------------------------
default_branch="$(git symbolic-ref --quiet --short "refs/remotes/${remote_name}/HEAD" 2>/dev/null | sed "s#^${remote_name}/##")"
if [ -z "$default_branch" ]; then
  for b in main master develop trunk; do
    if git show-ref --verify --quiet "refs/remotes/${remote_name}/${b}"; then
      default_branch="$b"; break
    fi
  done
fi
: "${default_branch:=main}"

# --- read what is actually being pushed, one line per ref: local_ref local_sha remote_ref remote_sha
work_shas=""
while read -r local_ref local_sha remote_ref remote_sha; do
  [ -n "${local_ref:-}" ] || continue
  # deleting a branch: local side is all zeros — nothing to test
  case "$local_sha" in ""|0000000000000000000000000000000000000000) continue ;; esac
  # a tag push, either as the local or the remote ref — not a work branch
  case "$local_ref" in refs/tags/*) continue ;; esac
  case "$remote_ref" in refs/tags/*) continue ;; esac
  branch="${remote_ref#refs/heads/}"
  [ "$branch" != "$default_branch" ] || continue
  work_shas="$work_shas $local_sha"
done

work_shas="$(printf '%s' "$work_shas" | xargs -n1 2>/dev/null | sort -u | tr '\n' ' ')"
[ -n "${work_shas// /}" ] || exit 0   # nothing qualifying: tags only, a delete, or the default branch

# --- work out how this project runs its tests, cheapest and most explicit override first --------
decide_command() {
  if [ -f ".claude/test-command" ]; then
    cmd="$(head -1 ".claude/test-command" | sed 's/[[:space:]]*$//')"
    [ -n "$cmd" ] && { printf '%s' "$cmd"; return 0; }
  fi

  if [ -f "fastlane/Fastfile" ]; then
    lane="$(grep -rhoE '^[[:space:]]*lane[[:space:]]*:[A-Za-z0-9_]+' fastlane/ 2>/dev/null \
      | sed -E 's/^[[:space:]]*lane[[:space:]]*:([A-Za-z0-9_]+)/\1/' | sort -u)"
    chosen=""
    for pref in test tests unit_test unit_tests ci ci_test ci_tests; do
      if printf '%s\n' "$lane" | grep -qx "$pref"; then chosen="$pref"; break; fi
    done
    if [ -n "$chosen" ]; then
      if [ -f "Gemfile" ]; then printf 'bundle exec fastlane %s' "$chosen"; else printf 'fastlane %s' "$chosen"; fi
      return 0
    fi
  fi

  workspace="$(find . -maxdepth 1 -iname '*.xcworkspace' -print -quit 2>/dev/null)"
  project="$(find . -maxdepth 1 -iname '*.xcodeproj' -print -quit 2>/dev/null)"
  if [ -n "$workspace" ] || [ -n "$project" ]; then
    container="${workspace:-$project}"
    scheme_dir="$container/xcshareddata/xcschemes"
    scheme=""
    if [ -d "$scheme_dir" ]; then
      count="$(find "$scheme_dir" -maxdepth 1 -iname '*.xcscheme' 2>/dev/null | wc -l | tr -d ' ')"
      if [ "$count" = "1" ]; then
        scheme="$(basename "$(find "$scheme_dir" -maxdepth 1 -iname '*.xcscheme' 2>/dev/null)" .xcscheme)"
      fi
    fi
    if [ -n "$scheme" ]; then
      # Deliberately no -configuration flag. On the Lufthansa iOS repo the scheme is LH, whose
      # own configuration is DebugLH — `-configuration Debug` there does not select an existing
      # configuration, it breaks the build. A generic fallback that adds one breaks every repo
      # shaped like that, so the flag is never added here; a project that needs one names it in
      # its own .claude/test-command instead.
      if [ -n "$workspace" ]; then
        printf "xcodebuild test -workspace %q -scheme %q -destination 'platform=iOS Simulator,name=iPhone 15'" "$workspace" "$scheme"
      else
        printf "xcodebuild test -project %q -scheme %q -destination 'platform=iOS Simulator,name=iPhone 15'" "$project" "$scheme"
      fi
      return 0
    fi
    return 1   # an Xcode project exists but the scheme is ambiguous; do not guess
  fi

  if [ -f "package.json" ] && command -v python3 >/dev/null 2>&1; then
    has_test="$(python3 -c 'import json
try:
    d=json.load(open("package.json"))
    print("y" if (d.get("scripts") or {}).get("test") else "")
except Exception:
    print("")' 2>/dev/null)"
    if [ -n "$has_test" ]; then
      if [ -f "yarn.lock" ]; then printf 'yarn test'; else printf 'npm test'; fi
      return 0
    fi
  fi

  [ -f "Package.swift" ] && { printf 'swift test'; return 0; }
  [ -f "Cargo.toml" ] && { printf 'cargo test'; return 0; }
  if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] || [ -f "requirements.txt" ]; then
    printf 'pytest'; return 0
  fi

  return 1
}

cmd="$(decide_command)"
rc=$?
sha="$(printf '%s' "$work_shas" | awk '{print $1}' | cut -c1-12)"
log="$RUN_DIR/${repo_slug}-${sha}.log"
status="$RUN_DIR/${repo_slug}-${sha}.status"

if [ "$rc" -ne 0 ] || [ -z "$cmd" ]; then
  echo "test-net: could not work out how to run this project's tests (no .claude/test-command, no recognisable fastlane/xcodebuild/npm/swift/cargo/pytest setup) — skipping, push continues." >&2
  exit 0
fi

if [ -f "$status" ]; then
  echo "test-net: $sha already has a result — $(cat "$status" 2>/dev/null)"
  exit 0
fi

echo "test-net: started in background (\`$cmd\`) — result lands at $log and $status"

# Fully detached: closed stdio so the push's own pipes can close, `disown` so the shell exiting
# does not signal it. The subshell writes the status file itself once the run actually finishes.
(
  start_e="$(date '+%s')"
  { eval "$cmd"; } > "$log" 2>&1
  code=$?
  end_h="$(date '+%Y-%m-%d %H:%M:%S')"
  if [ "$code" -eq 0 ]; then
    printf 'PASS %s\n' "$end_h" > "$status"
  else
    printf 'FAIL %s\n' "$end_h" > "$status"
  fi
) </dev/null >/dev/null 2>&1 &
disown 2>/dev/null || true

exit 0
