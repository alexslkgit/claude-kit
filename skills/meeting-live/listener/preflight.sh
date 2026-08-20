#!/bin/zsh
# preflight.sh — make the meeting listener runnable on THIS Mac, whichever one it is.
#
# Idempotent. Safe to run before every meeting. Prints one PASS/FAIL block at the end and
# never overwrites a listener that is already newer than the kit's copy.
#
#   ~/Developer/claude-kit/skills/meeting-live/listener/preflight.sh
#
# Override the install location with MEETING_HOME=/some/path.

set -u
KIT_DIR=${0:a:h}
HOME_DIR=${MEETING_HOME:-$HOME/Developer/meeting-listener}
MODEL_NAME=${MODEL_NAME:-ggml-large-v3-turbo.bin}
MODEL_URL="https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$MODEL_NAME"

ok=1
say()  { print -r -- "$@" }
fail() { ok=0; say "FAIL  $@" }
pass() { say "ok    $@" }

say "listener home: $HOME_DIR"
mkdir -p "$HOME_DIR/models" "$HOME_DIR/live" || fail "cannot create $HOME_DIR"

# --- sources -----------------------------------------------------------------------------
for f in listen.sh tap-rec.swift; do
  if [[ ! -f "$HOME_DIR/$f" ]] || [[ "$KIT_DIR/$f" -nt "$HOME_DIR/$f" ]]; then
    cp "$KIT_DIR/$f" "$HOME_DIR/$f" && say "      copied $f from the kit"
  fi
done
chmod +x "$HOME_DIR/listen.sh" 2>/dev/null
pass "sources in place"

# --- tools -------------------------------------------------------------------------------
if ! command -v brew >/dev/null; then
  fail "homebrew missing — install it from https://brew.sh, everything below needs it"
fi
for c in ffmpeg whisper-cli; do
  if command -v $c >/dev/null; then
    pass "$c"
  else
    pkg=$c; [[ $c == whisper-cli ]] && pkg=whisper-cpp
    say "      installing $pkg"
    brew install $pkg >/dev/null 2>&1 && pass "$c installed" || fail "brew install $pkg"
  fi
done
command -v swiftc >/dev/null && pass "swiftc" \
  || fail "swiftc missing — install Xcode command line tools: xcode-select --install"

# --- model -------------------------------------------------------------------------------
if [[ -s "$HOME_DIR/models/$MODEL_NAME" ]]; then
  pass "model $MODEL_NAME"
else
  say "      downloading $MODEL_NAME, about 1.6 GB, once per Mac"
  curl -fL --progress-bar -o "$HOME_DIR/models/$MODEL_NAME" "$MODEL_URL" \
    && pass "model downloaded" || fail "model download"
fi

# --- binary ------------------------------------------------------------------------------
if [[ ! -x "$HOME_DIR/tap-rec" ]] || [[ "$HOME_DIR/tap-rec.swift" -nt "$HOME_DIR/tap-rec" ]]; then
  say "      building tap-rec"
  ( cd "$HOME_DIR" && swiftc -O -o tap-rec tap-rec.swift 2>&1 | tail -5 )
fi
[[ -x "$HOME_DIR/tap-rec" ]] && pass "tap-rec built" || fail "tap-rec did not build"

# --- permission --------------------------------------------------------------------------
say ""
say "One toggle cannot be checked from here and cannot be set from here:"
say "  System Settings > Privacy & Security > Screen & System Audio Recording"
say "  must be ON for the app that launches this (Terminal, iTerm, Claude)."
say "If the transcript stays empty while people are talking, that toggle is the reason."

say ""
if (( ok )); then
  say "PASS. Start a meeting with:"
  say "  $HOME_DIR/listen.sh <topic>-\$(date +%F)"
  say "Transcript: $HOME_DIR/live/<name>.txt   Stop: pkill -f tap-rec"
else
  say "NOT READY. Fix the FAIL lines above and run this again."
  exit 1
fi
