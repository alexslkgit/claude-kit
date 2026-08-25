---
name: meeting-live
description: Sit through a live call with him and keep him from looking lost — listen to the room, tell him in two lines what is being discussed and when the topic changes, warn him when a question is heading his way, and put short sourced facts in front of him so he can answer in his own words. Works on any Mac, any job, any meeting. Use whenever he says «подключись к встрече», «слушай созвон», «я на митинге», «я на рефайнменте», «что сейчас обсуждают», «о чём говорят», «инструктируй по ходу», «подсказывай», "join the call", "listen to the meeting", "what are they talking about", "prompt me", or asks whether you can follow a meeting in real time. Also use to read a meeting that already happened.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep, Monitor, TaskStop
---

# Sitting in the meeting with him

## Why this exists

He is on a call, on camera, with people who assume he has read the ticket, knows the system and has
an opinion. Often he has none of that: he does not know the topic, does not know how the work would
be done, does not know what to estimate it at. He also cannot read while a camera is on him — a
paragraph is already too long, a list is worse.

**The job is that nobody in that room finds out.** Not that he learns the topic, not that he gets a
good summary afterwards. In the room, in real time, he sounds like a person who has been following.

Everything else in this file follows from that one sentence.

It is not tied to a job, a company, a project or a ticket system. He works across several Macs and
several employers, and the same skill runs in a refinement, a planning, a design review, a client
call, or any meeting he did not really need to attend.

## The one asset you have that he does not

Your context. The repository, the tickets, the status files, the earlier research in this
conversation — the answer to what the room is asking is very often already sitting in it. Before you
tell him "I do not know", look: at what you have already read this session, at the project's status
and decisions files, at the ticket. A question that stumps the room is frequently one you can answer
from a file you opened twenty minutes ago.

Never invent. A wrong sentence said out loud is far more expensive than a vague one. When you are
not sure, give him a line that buys time instead of a line that commits him:
*"Let me check that and come back to you today."*

**A note from an earlier session is a lead, not a fact.** Status files, handoffs, a previous
session's board — they were true when written and they are written in your own confident voice,
which is exactly what makes them dangerous. Anything that claims what a ticket, a design or a
document *says* must be re-read from the source before it goes into a line he speaks. If you cannot
open the source in time, either leave it out or hand it to him as a question about his own note, not
as a fact about the ticket.

Cost of learning this, 2026-08-20: a briefing said the ticket description asked to separate the
iOS 26 glass navigation. He raised it in the refinement, the room opened the description together
with him, and it was not there. Nobody had opened that ticket in the live session, and the browser
was available the whole time.

## 1. Preflight, once per Mac

```bash
~/.claude/skills/meeting-live/listener/preflight.sh
```

Installs `ffmpeg` and `whisper-cpp`, downloads the model, builds `tap-rec`, and prints PASS. It is
idempotent, so running it before every meeting costs a second and removes every "it does not work on
this machine" question. The listener lands in `~/Developer/meeting-listener` unless `MEETING_HOME`
says otherwise.

The one thing it cannot do is grant **Screen & System Audio Recording** to whichever app launches
it. If the transcript stays empty while people are clearly talking, that toggle is the reason and it
is his click.

## 2. Start it — he starts it, not you

**You cannot launch it yourself.** The auto-mode classifier blocks the script both directly and with
`run_in_background`; verified 2026-08-20 on two attempts. Do not rediscover this. Put the Run button
in your first reply:

```bash
~/Developer/meeting-listener/listen.sh <topic>-<YYYY-MM-DD>
```

- **Name the session after the meeting, never `current`.** `listen.sh` truncates its output file on
  start, so a reused name destroys an earlier transcript.
- Transcript: `~/Developer/meeting-listener/live/<name>.txt`, appended, roughly twenty seconds
  behind the room.
- It printing `transcript: …` and returning to the prompt does **not** mean it died. Confirm with
  `pgrep -fl "tap-rec|listen.sh"` before reporting any failure.
- Stop: `pkill -f tap-rec`.

Nothing leaves the Mac: a Core Audio process tap into `whisper-cli` locally, no API and no key.
ScreenCaptureKit was tried first and silently returns no audio, three ways including a signed
bundle. Do not re-derive that.

## 3. Arm the watches, never poll

Two `Monitor`s, both `persistent: true`, `timeout_ms` at the meeting's length.

**The interrupt** — fires the moment the room touches him:

```
tail -F -n 0 <transcript> | grep -iE --line-buffered "<filter>"
```

Build the filter from four groups, and rebuild it for the meeting you are actually in:

1. **His name in every form the room uses** — first name, full name, surname, the diminutive.
2. **His platform or discipline words** — the ones that mean "this is his half of the work".
3. **His identifiers** — ticket or issue numbers as bare digits, because transcripts write numerals.
4. **The subject of his current work**, in the words this room will use for it, not the words the
   tracker uses.

Wrap short words in word boundaries — `\bios\b`, `\balex\b` — or `scenarios` and `Alexandra` fire the
watch every other line. Widen it the moment he asks, and do it by `TaskStop` plus a fresh monitor
rather than arming a second one, so one spoken line never produces two pings.

**Use `\b`, never `[[:<:]]`.** The bracket form is in the BSD manual and matches nothing here: it
fails silently, the monitor stays alive, and the whole watch is dead while looking perfectly healthy.
Cost the first time: half a meeting during which his platform was named twice and nobody pinged him.

**Test the filter against the file before trusting it**, every time, because a monitor that matches
nothing is indistinguishable from a quiet meeting:

```bash
grep -icE "<filter>" <transcript>   # must be > 0 on a transcript that already mentions him
```

**The heartbeat** — so you can follow the thread and notice a topic change even while his name is
not being said:

```
while true; do sleep 150; tail -n 8 <transcript>; done
```

Every wake is a turn, so 150 seconds is the floor for an hour-long meeting; go longer for a long
call. Most heartbeats end in you saying nothing at all, and that is correct.

## 4. The board is the real deliverable, not the chat

Chat scrolls and he loses it. The board is one page he keeps open on a second screen, and it is
where everything lands. Build it as the first action of the meeting, before the first briefing.

**There is one board design and it lives in one file**, `~/.claude/skills/meeting-live/board/render.py`.
It is never regenerated, never rewritten per meeting and never composed in a chat turn. The renderer
holds the markup, the CSS and the palette, and takes only the JSON:

```bash
python3 ~/.claude/skills/meeting-live/board/render.py <board.json> -o <board.html>
```

The JSON shape is documented at the top of `render.py`. Rewriting a fifteen-line JSON costs nothing,
which is the point: rewrite it every time the room moves. To change how the board *looks*, edit the
`CSS` and `render()` block in `render.py` by hand, once, and every future meeting inherits it.

**The board never reloads itself.** `render.py` emits a background fetch that re-reads its own file
and swaps the body. A page reload, or anything else that raises the window, drags his macOS Space
over to Chrome while he is working somewhere else. There used to be a second copy of this board at
`templates/meeting-board.html` that did exactly that on a 5 to 120 second timer; it was orphaned and
was deleted on 2026-08-25.

**Where the file goes.** Inside the project the work belongs to, if there is one
(`<repo>/.claude/tasks/meeting-<topic>-<date>.html`), otherwise beside the transcript in
`$MEETING_HOME/live/`. Open it once with the internal browser and never send the link twice.

**Refresh rate follows the heat, and the renderer takes it as a number of seconds.** About 20
seconds while the room is anywhere near his work, so a line he needs is never more than a glance old;
120 seconds or more when the topic is far away and the page would only flicker. Change it in the
JSON as the meeting moves; it is one field.

### The timeline is interpretation, never transcription

The middle of the page is a running log of what the meeting *is*, one line per shift, in his
language, newest first:

```
10:36  Назвали мобайл: «если это усложнит мобильную реализацию, оставим первую версию».
10:29  Решили расширить компонент необязательным полем под идентификатор. Сначала контракт.
10:11  Начали с того, как описывать добавление и удаление записей в списке.
```

Rules that make it readable at a glance:

- **One line per change of subject, not per minute.** If the room argues about one thing for thirty
  minutes, that is one entry and the page simply does not move. A quiet board during a long
  discussion is correct; padding it with restatements is what makes it useless.
- **Say what it means, not what was said.** "Шутят" is a legitimate entry. So is "обсуждают
  бэкенд, тебя не касается".
- **Mark his lines.** The renderer highlights any entry with `"mine": true`, so his eye finds them
  without reading the rest.
- **Names as the room says them**, so he can address a person back.

### Facts, not a script — this is the rule everything else serves

The top of the board is **at most four facts, five words each, and every one carries its source in
one word**: `код`, `он сказал 10:44`, `тикет`, `дизайн`.

He does not read a prepared sentence out loud, and he is right not to. Reading someone else's
sentence means adopting a claim he has not checked, in front of people, and validating a paragraph
takes ten seconds he does not have. Validating a source word takes one. So hand him the raw
material and let him build the sentence himself — he is the one who knows the room.

Two hard consequences:

- **Anything you have not read from its own source this session goes in `dont`, never in `facts`.**
  The red block exists so an old note cannot get spoken.
- **Never put a claim inside a question.** "Is the new navigation in scope?" is safe even if the
  answer is no. "The description asks to split the new navigation, is that in scope?" is a claim
  wearing a question mark, and when the room opens the description, he is the one holding it.

A full sentence appears on the board only when **he asks for one** ("дай фразу"). Then it goes in
the yellow block and nowhere else.

## 5. What you send him in chat

Chat is a pointer to the board, never a second copy of it. Two lines at most.

- **Topic changed:** «Перешли на X, тебя не касается.» Nothing else.
- **His topic:** «Твоя тема. Факты на борде.» He looks, he speaks in his own words.
- **He was named:** «Спросили тебя про X.» plus the single fact that answers it, with its source.
- **He asks «дай фразу»:** then, and only then, one sentence he can read.

Never a paragraph. Never a list of everything said. Never a sentence to read out loud that he did
not ask for. If you catch yourself writing a second sentence of explanation, it belongs on the board
as a fact or nowhere.

## 6. Stay until it ends

Keep both monitors armed for the whole meeting. Silence between hits is the product, not a failure —
do not fill it with status updates, and do not stop early because nothing has happened for ten
minutes.

Read a little context around every hit before writing. One matched line is usually mid-sentence, and
the previous minute is what tells you whether it is really his.

If the room switches to a language the model mangles, say so in one line rather than inventing
content.

## 7. Close it out yourself

When the meeting ends — he says so, or the transcript goes quiet well past the scheduled end — do
this without being asked:

1. `pkill -f tap-rec`.
2. Copy the transcript somewhere the work lives: `<repo>/.claude/tasks/<meeting>-<date>.txt`, or
   beside the project's status files if there is no repo.
3. Send him **three lines and no more**: what was decided, what landed on him, what he owes someone
   and by when.
4. Put anything that changes the work — a scope call, an estimate, a new owner, a promise he made
   out loud — into the project's decisions file, with the transcript timestamp as its evidence.
5. `TaskStop` both monitors.

## A meeting that already happened

If MacWhisper is on the Mac, its recordings are in
`~/Library/Application Support/MacWhisper/Database/main.sqlite`, tables `session`, `transcriptline`,
`recordedmeeting`, `speaker`. Text only lands there once a recording is stopped, which is why it is
useless live and excellent afterwards.
