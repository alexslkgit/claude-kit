---
name: record-demo
description: Record a screen demo of an app — iOS/watchOS simulator, Android emulator, or a browser — cut it to a short clip and leave the finished file in ~/Downloads. Use whenever the user asks to record, film, capture or show a video of anything running ("запиши видео", "сними как работает", "покажи видео", "record a demo", "make a clip"), including when the clip is for someone else — a partner, a store listing, a bug report.
---

# Record a demo

The deliverable is a **file in `~/Downloads`**, not a path in the chat and not a file in a
scratchpad. He shares it from there. A recording that ends anywhere else has not been delivered.

## The two things he never has to ask for

1. **`~/Downloads/<something>.mp4`.** Copy it there as the last step, every time, even when he
   named another path — put it in both. Name it after the thing shown (`helio-ai-demo.mp4`),
   not after the task.
2. **About 720p.** For a portrait phone capture that means `scale=720:-2` (720×1560-ish). Not
   the raw 1206-px simulator capture — the file triples in size for nothing. `-crf 23` keeps a
   40-second clip near 1.5 MB.

Silent is fine and is the default; simulator captures have no audio track anyway.

## Length

Short means **20–40 seconds**. Under 20 s nothing is readable; over about 60 s nobody watches
to the end. The raw take will be three to five times that — the cutting is not optional.

## Do the rehearsal before you roll

Every failed take costs the whole take plus every server call inside it. Before recording:

- Walk the exact flow once, by hand, and screenshot each step. This is where you find the
  stale state — a chat that still has yesterday's messages, a cached result that skips the
  loading state, an onboarding screen that has already been dismissed.
- **Reset the state you want on camera.** An empty list, a first-run screen, an uncached
  result. Verify the reset worked with a screenshot — do not assume it did.
- Decide the beats and write them down: what is tapped, in what order, where it pauses.
- Warm up anything with a cold start. A serverless backend answers in ~35 s cold and ~15 s
  warm, and the first call after a deploy is the one that misbehaves.

## Recording

```bash
xcrun simctl io <udid> recordVideo --codec h264 --force raw.mov   # SIGINT to finalise
```

Start it with `nohup … &`, keep the pid, and stop it with `kill -INT` — anything else leaves
an unplayable file. Android: `adb shell screenrecord`. Browser: the Chrome MCP's gif tool for
short loops, otherwise capture the window.

Drive the UI with the simulator control tools between start and stop, and **screenshot after
every step that can fail** — a tap that missed is invisible until you watch the take back.

## Cutting: one flat speed is always wrong

The take is a mix of things that must be read and things that are dead air. A single rate
either makes the text unreadable or leaves a 30-second wait in. Segment it and give each part
its own rate:

| What is on screen | Rate |
|---|---|
| Text he must actually read | 2.5–3.5x |
| Navigation, taps, typing | 8–9x |
| Waiting on a spinner, dead air between steps | 10–13x |

```bash
ffmpeg -i raw.mov -filter_complex "\
[0:v]trim=0:6,setpts=(PTS-STARTPTS)/3[a];\
[0:v]trim=16:38,setpts=(PTS-STARTPTS)/9[b];\
[0:v]trim=38:68,setpts=(PTS-STARTPTS)/3.4[c];\
[a][b][c]concat=n=3:v=1:a=0[cat];\
[cat]scale=720:-2,fps=30[out]" -map "[out]" \
  -c:v libx264 -pix_fmt yuv420p -crf 23 -preset slow -movflags +faststart out.mp4
```

Find the boundaries instead of guessing them: pull one frame every few seconds, stitch them
into a contact sheet, and read the timestamps off it. Guessed boundaries cut mid-gesture.

Trimming a whole passage out — a consent screen he decided he does not want — is a segment
you drop from the filter, not a reason to record again. **Always check the raw take for what
he asked for before re-shooting anything.**

## Verify before you hand it over

Pull frames from the *finished* file, not the raw one, and look at them. Confirm every beat he
asked for is present and nothing is half-scrolled or mid-animation. Then copy to `~/Downloads`
and send the file itself, with the duration and what it shows in one line.

## Typing on camera

Injected keystrokes follow the **Mac's** current input source, so on a non-Latin layout
`text` lands as gibberish — and it is not fixable from inside the simulator (`AppleKeyboards`
is the list, not the active layout). Do not touch the Mac's input source. Use the pasteboard:

```bash
printf '%s' "the sentence" | xcrun simctl pbcopy <udid>
```

then long-press the field (`touch_path`, ~900 ms, same point twice) and tap **Paste**. It reads
as an ordinary iOS gesture on camera. Screenshot after the paste to confirm the text landed
before sending.

## Simulator state that resists being reset

App preferences are cached by `cfprefsd`, which rewrites your edit the moment the app relaunches.
Editing the plist on a booted device does nothing, and killing `cfprefsd` first does not help
either. The one reliable order is **shut the device down, edit, boot**:

```bash
xcrun simctl shutdown <udid>
plutil -replace <key> -bool NO "<app data container>/Library/Preferences/<bundle>.plist"
xcrun simctl boot <udid>
```

A reboot can change the active keyboard, so re-check typing afterwards. Server-side state
(cached results, transcripts) is reset at the source, not in the app.

Never uninstall the app to reset it — that destroys the anonymous account and every bit of
history the demo is meant to show.
