---
name: meeting-live
description: Sit in a live call with him — read the running transcript, tell him in two lines what is being discussed, and interrupt him the moment his own tickets come up with a ready sentence he can say out loud. Use whenever he says «подключись к встрече», «слушай созвон», «я на рефайнменте», «что сейчас обсуждают», «о чём говорят», «инструктируй по ходу», "join the meeting", "listen to the call", "what are they talking about", or asks whether you can follow a meeting in real time. Also use to read a meeting that already happened.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Monitor, TaskStop
---

# Being in the meeting with him

He is in a call, on camera, with people who assume he knows the topic. He cannot read. The whole
job is that **he never looks out of the loop**, and that costs him at most one glance per message.

The mechanism is his own: `~/Developer/meeting-listener` taps system audio through a Core Audio
process tap and transcribes locally with `whisper-cli`. Nothing leaves the machine, no API, no key.
Built 2026-08-18; the dead ends are in the memory `meeting-listener-live-transcript` and must not be
re-derived. ScreenCaptureKit gives frames and silently gives no audio; three attempts, including a
signed bundle, returned zero audio callbacks.

## Start it — the first message, before anything else

**You cannot start it yourself.** The auto-mode classifier blocks the script, both as a plain call
and with `run_in_background`. Verified 2026-08-20. Do not spend two attempts discovering this again:
hand him the Run button in your first reply.

```bash
/Users/U123877/Developer/meeting-listener/listen.sh <topic>-<YYYY-MM-DD>
```

- **Name the session after the meeting, never `current`.** `listen.sh` truncates its output file on
  start, so a shared name destroys an earlier transcript.
- The transcript is `~/Developer/meeting-listener/live/<name>.txt`, appended, about twenty seconds
  behind the room.
- It printing `transcript: …` and returning to the shell prompt does **not** mean it died. Check
  `pgrep -fl "tap-rec|listen.sh"` before reporting a failure.
- Prerequisite, one toggle, already granted on his main Mac: Screen & System Audio Recording for
  `Claude` and `claude.app`.
- Stop with `pkill -f tap-rec`.

## Then arm a watch, do not poll

A persistent `Monitor` on the tail is the whole trick: it costs nothing while the meeting is on his
topic-free stretches, and it wakes you the instant his name or his tickets are spoken.

```
tail -F -n 0 <transcript> | grep -iE --line-buffered "<filter>"
```

`persistent: true`, `timeout_ms` at the meeting's length. Build the filter from three groups:

1. **His ticket numbers**, bare digits — whisper writes numerals, and people say them aloud.
2. **His platform words**: `ios`, `mobile`, `iphone`, `apple`, `swift`, `native app`.
3. **His name in every form** the room uses: `alex`, `oleksandr`, `aleksand`, `sasha`,
   `slobodianiuk`.

Plus whatever his current ticket is actually about, in the words the room will use for it.

**Wrap short words in word boundaries** — `[[:<:]]ios[[:>:]]`, `[[:<:]]alex[[:>:]]` — or `scenarios`
and `studios` fire the watch every other line. This is BSD grep on macOS; `\b` also works, the
bracket form is safer inside a long alternation.

Widen on request without argument. He knows the room; if he says "or iOS, or mobile", stop the
monitor with `TaskStop` and re-arm rather than adding a second one, so he gets one notification per
line and not two.

## What you send him, and what you never send

Two blocks, nothing else:

- **What is happening**, two or three sentences of plain words. Who is arguing about what, and what
  they landed on. Names as the room says them.
- **One sentence in English he can say out loud**, in quotes, that makes him sound like he has been
  following. Only when it is genuinely his area; a wrong line is worse than silence.

Add the estimate guidance when a number is about to be asked for, because that is the one moment he
cannot bluff: what the ticket was already refined at, and what the number becomes if a bigger scope
is folded in.

Never send the transcript. Never send a bullet list of everything said. Never explain the mechanism
while he is in the call.

## While the meeting runs

- Stay silent between hits. Silence is the product.
- Answer «сейчас о чём» with `tail -n 25` of the transcript and the same two blocks. Twenty five
  lines is about eight minutes and is enough to name the topic.
- When a monitor line fires, read a little context around it before writing. One matched line is
  usually mid-sentence and the previous minute is what tells you whether it is really his.
- If the room switches to a language whisper mangles, say so in one line rather than inventing
  content.

## After it ends

- `pkill -f tap-rec`.
- Copy the transcript next to the project's task pages, `<repo>/.claude/tasks/<meeting>-<date>.txt`,
  so the next session can read what was decided.
- Anything that changes the work — a scope call, an estimate, a new owner — goes into the project's
  decisions file with the timestamp from the transcript as its evidence.

## A meeting that already happened

MacWhisper keeps its recordings in `~/Library/Application Support/MacWhisper/Database/main.sqlite`,
tables `session`, `transcriptline`, `recordedmeeting`, `speaker`. Text only lands there once a
recording is stopped, which is exactly why it is useless live and excellent afterwards.
