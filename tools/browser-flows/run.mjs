#!/usr/bin/env node
// run.mjs — run a saved browser flow against a persistent, already-signed-in Chrome profile.
//
// Why this exists: a multi-step browser flow driven turn-by-turn by the model costs tens of
// thousands of tokens, most of it screenshots that are re-sent on every later request. A flow
// that has been walked once can be replayed by this runner for the price of its printed summary.
//
//   node run.mjs <flow-name> [--headed] [--json '<args>']
//
// A flow is HOME/flows/<name>.mjs exporting: export default async (page, ctx) => ({ ...summary })
// ctx = { args, out, log, chromium, context }. Everything the flow returns is printed as JSON.
// Nothing else goes to stdout, so the model reads a handful of lines instead of a screen.
import { createRequire } from 'node:module'
import os0 from 'node:os'
import path0 from 'node:path'
const require0 = createRequire(path0.join(os0.homedir(), '.claude', 'browser-flows', 'noop.cjs'))
const { chromium } = require0('playwright-core')
import path from 'node:path'
import os from 'node:os'
import fs from 'node:fs'

const HOME = path.join(os.homedir(), '.claude', 'browser-flows')
const CHROME = '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
const argv = process.argv.slice(2)
const name = argv[0]
if (!name) { console.error('usage: run.mjs <flow-name> [--headed] [--json <args>]'); process.exit(2) }
const headed = argv.includes('--headed')
const argsIdx = argv.indexOf('--json')
const args = argsIdx > -1 ? JSON.parse(argv[argsIdx + 1]) : {}

const flowPath = path.join(HOME, 'flows', `${name}.mjs`)
if (!fs.existsSync(flowPath)) { console.error(`no flow at ${flowPath}`); process.exit(2) }
const out = path.join(HOME, 'out', name)
fs.mkdirSync(out, { recursive: true })

const lines = []
const log = (...a) => lines.push(a.join(' '))

const context = await chromium.launchPersistentContext(path.join(HOME, 'profile'), {
  executablePath: CHROME,
  headless: !headed,
  viewport: { width: 1440, height: 900 },
  acceptDownloads: true,
  args: ['--no-first-run', '--no-default-browser-check'],
})
const page = context.pages()[0] || await context.newPage()
page.setDefaultTimeout(30000)

let result, failed = null
try {
  const flow = (await import(flowPath)).default
  result = await flow(page, { args, out, log, chromium, context })
} catch (e) {
  failed = String(e && e.message || e).split('\n').slice(0, 4).join(' | ')
  try { await page.screenshot({ path: path.join(out, 'failure.png') }) } catch {}
} finally {
  await context.close().catch(() => {})
}
console.log(JSON.stringify({ flow: name, ok: !failed, error: failed, log: lines, result, out }, null, 1))
process.exit(failed ? 1 : 0)
