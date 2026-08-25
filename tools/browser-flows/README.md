# browser-flows — a browser flow walked once, replayed for nothing

A multi-step browser flow driven turn by turn by the model costs tens of thousands of tokens,
most of it screenshots that are re-sent on every later request of the session. A flow that has
already been walked can be replayed by this runner for the price of its printed summary:
measured 1.9 seconds and ~180 tokens for navigate + extract + download.

## Install

`install.sh` copies this folder to `~/.claude/tools/browser-flows/`. The machine-local half —
the Chrome profile, the flow files, the downloads — lives in `~/.claude/browser-flows/`:

    mkdir -p ~/.claude/browser-flows/flows
    cd ~/.claude/browser-flows && npm init -y && npm i playwright-core

`playwright-core` drives the Chrome already installed on the Mac. No browser is downloaded.

## Sign in once per site

    node ~/.claude/tools/browser-flows/signin.mjs https://portal.example.com

A normal visible window opens on the automation profile. He signs in, closes it, and the cookies
stay. This is his only action in the whole arrangement and it happens once per site.

Copying his real Chrome profile instead does not work: the cookies do not decrypt outside the
profile they were written in. Verified 2026-08-25, zero cookies came back.

## Write a flow

`~/.claude/browser-flows/flows/<name>.mjs`:

```js
export default async (page, { args, out, log }) => {
  await page.goto('https://portal.example.com/documents')
  await page.getByRole('link', { name: 'Invoice' }).first().click()
  const dl = await page.waitForEvent('download')
  const file = `${out}/invoice.pdf`
  await dl.saveAs(file)
  log('saved', file)
  return { file }
}
```

`ctx` is `{ args, out, log, chromium, context }`. `out` is `~/.claude/browser-flows/out/<name>/`.
Whatever the flow returns is printed as JSON, and nothing else reaches stdout — the model reads a
handful of lines instead of a screen.

## Run

    node ~/.claude/tools/browser-flows/run.mjs <name>
    node ~/.claude/tools/browser-flows/run.mjs <name> --json '{"month":"08"}'
    node ~/.claude/tools/browser-flows/run.mjs <name> --headed     # watch it, or debug

On failure it writes `out/<name>/failure.png` and exits 1 with the error on one line. Look at the
PNG from a subagent, never from the main conversation.
