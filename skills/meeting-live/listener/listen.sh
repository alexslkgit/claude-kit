#!/bin/zsh
# listen.sh [session-name] — capture system audio and keep a live transcript on disk.
#
#   Transcript : ~/Developer/meeting-listener/live/<session>.txt   (append-only plain text)
#   Stop with  : pkill -f tap-rec
#
# Everything runs locally: Core Audio process tap -> WAV chunks -> whisper.cpp -> text.
setopt NULL_GLOB
DIR=$HOME/Developer/meeting-listener
NAME=${1:-meeting-$(date +%Y%m%d-%H%M)}
CHUNKS=$DIR/live/$NAME.chunks
OUT=$DIR/live/$NAME.txt
MODEL=${MODEL:-$DIR/models/ggml-large-v3-turbo.bin}
CHUNK_SECONDS=${CHUNK_SECONDS:-20}

mkdir -p "$CHUNKS" "$DIR/live"
: > "$OUT"
echo "transcript: $OUT"

"$DIR/tap-rec" "$CHUNKS" "$CHUNK_SECONDS" 2>>"$DIR/live/$NAME.rec.log" &
REC=$!
trap 'kill $REC 2>/dev/null' EXIT INT TERM

while kill -0 $REC 2>/dev/null; do
  for f in "$CHUNKS"/chunk-*.wav; do
    sz1=$(stat -f%z "$f" 2>/dev/null)
    sleep 0.3
    sz2=$(stat -f%z "$f" 2>/dev/null)
    [[ "$sz1" != "$sz2" ]] && continue

    ts=$(basename "$f" .wav); ts=${ts#chunk-}
    wav16=${f%.wav}-16k.wav
    ffmpeg -loglevel error -y -i "$f" -ar 16000 -ac 1 "$wav16" 2>/dev/null
    txt=$(whisper-cli -m "$MODEL" -f "$wav16" -nt -np -l auto 2>/dev/null \
          | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')
    rm -f "$f" "$wav16"

    # whisper hallucinates stock phrases on silence; drop the usual suspects
    case "$txt" in
      ""|"[BLANK_AUDIO]"|"Thank you."|"Thanks for watching!"|"you"|".") continue ;;
    esac
    printf '[%s] %s\n' "$(date -r ${ts%.*} +%H:%M:%S)" "$txt" >> "$OUT"
  done
  sleep 2
done
