#!/usr/bin/env node
// signin.mjs — open the automation profile as a normal visible window so the user signs in ONCE.
// The cookies stay in HOME/profile and every later `run.mjs` starts already signed in.
//   node signin.mjs https://portal.example.com
import { createRequire } from 'node:module'
import os0 from 'node:os'
import path0 from 'node:path'
const require0 = createRequire(path0.join(os0.homedir(), '.claude', 'browser-flows', 'noop.cjs'))
const { chromium } = require0('playwright-core')
import path from 'node:path'
import os from 'node:os'
const HOME = path.join(os.homedir(), '.claude', 'browser-flows')
const url = process.argv[2] || 'about:blank'
const context = await chromium.launchPersistentContext(path.join(HOME, 'profile'), {
  executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  headless: false, viewport: null,
  args: ['--no-first-run', '--no-default-browser-check'],
})
const page = context.pages()[0] || await context.newPage()
await page.goto(url)
console.log('signed-in window open. close it when done; cookies persist in', path.join(HOME, 'profile'))
await context.waitForEvent('close', { timeout: 0 })
