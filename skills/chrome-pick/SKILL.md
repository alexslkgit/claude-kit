---
name: chrome-pick
description: Identify which connected Chrome is the one on THIS Mac, without making the user click anything, and remember it by name for every future session. Use whenever a browser task starts and `list_connected_browsers` returns more than one browser, whenever `switch_browser` times out, or whenever the user says "не тот браузер", "какой хром", "подключись к браузеру", "wrong browser", "pick the browser".
allowed-tools: Read, Write, Edit, Bash, Glob, mcp__claude-in-chrome__list_connected_browsers, mcp__claude-in-chrome__select_browser, mcp__claude-in-chrome__switch_browser, mcp__claude-in-chrome__navigate, mcp__claude-in-chrome__tabs_context_mcp, mcp__claude-in-chrome__tabs_close_mcp, AskUserQuestion
---

# Which Chrome is this Mac's Chrome

The user has several Macs signed into one Claude account. Every one of them shows up in
`list_connected_browsers`, and the tool tells you almost nothing useful:

- **`isLocal: true` is meaningless.** Verified 2026-08-17 on `C12239`: all three connected
  browsers reported `isLocal: true` and not one of them was on that Mac.
- **`name` is `Browser 1..N`** — assigned by position in the list, so it *changes* when another
  Mac connects or drops. Never store a `Browser N` name; store the `deviceId`.
- **`connectedAt`** is a hint at best: the most recently connected one is often the Mac the user
  just touched, but it is evidence, not proof.

Guessing costs the user a wrong tab opening on a machine he is not sitting at, and costs you the
whole task. Prove it instead.

## The probe — zero clicks, a few seconds

Only a browser running on **this** Mac can reach **this** Mac's loopback. So make each candidate
fetch a URL on a local server and see which fetch arrives.

```bash
~/.claude/skills/chrome-pick/probe.sh start
```

It prints `PROBE_URL=http://127.0.0.1:<port>/probe-`. Then, for each deviceId in the list:

1. `select_browser` with that deviceId
2. `navigate` to `<PROBE_URL><first 8 chars of the deviceId>` — no tabId, it uses the group's tab

Then:

```bash
~/.claude/skills/chrome-pick/probe.sh check
```

It prints the deviceId prefixes that actually reached this Mac. Exactly one hit is the answer.
Finish with `probe.sh stop`, and close the tab you opened with `tabs_close_mcp`.

**Zero hits means something specific:** no connected browser is on this Mac. The local extension
is installed but not signed in — see the diagnosis section below. Do not keep retrying
`switch_browser`; it will keep timing out.

## Remember the answer

The registry is a kit file, so every Mac learns every other Mac's browser:

```
~/Developer/claude-kit/chrome-browsers.json
```

Write the confirmed deviceId there with `hostname`, the Chrome profile directory and its display
name, the date and the method. Always edit the path above — never the installed copy under
`~/.claude` — then run the `kit-update` skill so it reaches the other machines.

On the next session, read the registry first: if the local machine's deviceId (match by
`hostname`) is in `list_connected_browsers`, that is your recommendation, and a single probe
round confirms it in one call instead of N.

## Naming: the product's own feature does not work — do not spend his click on it

`switch_browser` lets the user type a name while confirming, and that name **does not persist**.
He has been typing it for months. Re-verified 2026-08-17: he named a browser `Luft-Mac`, the call
returned `Connected to browser "Luft-Mac"`, and the very next `list_connected_browsers` still said
`Browser 1..N`. Never propose naming as the fix, and never ask him to redo it.

The names live in `chrome-browsers.json` instead, and the `chrome-guard` SessionStart hook injects
them into every session. **Use those names in anything he reads** — a question, a status line, a
plan step. He never sees `Browser N` from you.

One more thing that dialog does badly: it pops in **every** connected Chrome at once, so he can
easily confirm on the wrong Mac — that is exactly how `Luft-Mac` got named while he was sitting at
`C12239`. Another reason the probe, not the dialog, is the identification mechanism.

## The one thing the harness still forces

When more than one browser is connected, the tool result carries a standing instruction to ask
the user before any browser action. Obey it — but make it a formality, not a question:

- put the probe-confirmed browser **first**, labelled `(рекомендую)`,
- put the evidence in its description (`подтверждён ловушкой на localhost`, `это C12239`),
- keep the mandatory last option verbatim.

One click on an answer you already proved is acceptable. Asking him which of four unnamed
browsers is his is not.

## When the local extension is signed out

Symptoms, all three seen together on 2026-08-17: `switch_browser` times out with no window
appearing, the local Chrome never shows in the list, and the probe gets zero hits.

Diagnose from the shell before saying anything — the profile and extension state are readable:

```bash
python3 - <<'PY'
import json, os, time
base = os.path.expanduser("~/Library/Application Support/Google/Chrome")
ID = "fcoeoabgfenejglbffodgkkbkcdhcgfn"          # Claude in Chrome
ls = json.load(open(os.path.join(base, "Local State")))
print("last used profile:", ls["profile"]["last_used"])
for d, info in ls["profile"]["info_cache"].items():
    ext = os.path.isdir(os.path.join(base, d, "Extensions", ID))
    pref = os.path.join(base, d, "Preferences")
    mt = time.strftime("%m-%d %H:%M", time.localtime(os.path.getmtime(pref))) if os.path.exists(pref) else "-"
    print(f"{d:<12} {info.get('name','?'):<20} extension={ext} last_active={mt}")
PY
```

Then look at the extension's own storage — repeated `cic_ext_silent_reauth` keys mean it is
alive and failing to re-authenticate, which is the signed-out case:

```bash
strings ~/Library/"Application Support"/Google/Chrome/Default/"Local Extension Settings"/fcoeoabgfenejglbffodgkkbkcdhcgfn/*.log \
  | grep -c cic_ext_silent_reauth
```

Only then go to him, with the evidence and one action: open the Claude side panel from the
toolbar icon and sign in with the same Claude account as the CLI session. If the panel claims it
is connected and the browser still never appears, the next step is toggling the extension off and
on in `chrome://extensions`.
