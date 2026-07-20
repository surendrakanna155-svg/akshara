// NETWORK BEHAVIOUR certification. Drives a real authenticated page while the
// data endpoint is forced to each failure mode, and asserts the app degrades
// honestly: no crash, no blank screen, no unhandled error — a real state shown.
import fs from 'node:fs';
import { chromium } from '@playwright/test';
import { ensureFreshSession } from './refresh_session.mjs';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
await ensureFreshSession(600);

// The registry's data call — intercepted per-case. Auth calls are left alone so
// the shell stays signed in and we isolate the data path.
const ROUTE = '/sis/registry';
const DATA_EP = '**/api-proxy/sis/students**';

const envelope = (code, message) => JSON.stringify({ data: null, error: { code, message } });

const CASES = [
  { name: '401 unauthorized', status: 401, body: envelope('UNAUTHORIZED', 'Invalid access token'), expect: /Something went wrong|Invalid access token|sign in/i },
  { name: '403 module disabled', status: 403, body: envelope('MODULE_DISABLED', 'Module is disabled for this school'), expect: /Module not enabled/i },
  { name: '403 forbidden (RBAC)', status: 403, body: envelope('FORBIDDEN', 'You do not have permission'), expect: /Something went wrong|permission/i },
  { name: '404 not found', status: 404, body: envelope('NOT_FOUND', 'Resource not found'), expect: /Something went wrong|not found/i },
  { name: '409 conflict', status: 409, body: envelope('CONFLICT', 'Version conflict'), expect: /Something went wrong|conflict/i },
  { name: '422 needs params', status: 422, body: envelope('VALIDATION_ERROR', 'class is required'), expect: /Choose filters to load/i },
  { name: '429 rate limited', status: 429, body: envelope('RATE_LIMITED', 'Too many requests'), expect: /Something went wrong|Too many/i },
  { name: '500 server error', status: 500, body: envelope('INTERNAL', 'Internal server error'), expect: /Something went wrong|Internal/i },
  { name: 'malformed body', status: 200, body: '<<not json>>', expect: /Something went wrong|Nothing|No students|inbox/i },
];

const browser = await chromium.launch();
const results = [];

async function run(name, setup, expect, { offline = false } = {}) {
  const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  const hard = [];
  // Only UNHANDLED errors count; a logged failed request is expected here.
  page.on('pageerror', (e) => hard.push('pageerror: ' + e.message.slice(0, 100)));
  page.on('console', (m) => {
    const t = m.text();
    if (m.type() === 'error' && !/Failed to load resource|net::ERR|status of 4|status of 5/.test(t)) hard.push(t.slice(0, 100));
  });
  await setup(page, ctx);
  await page.goto(BASE + ROUTE, { waitUntil: 'domcontentloaded', timeout: 30000 }).catch(() => {});
  if (offline) await ctx.setOffline(true);
  await page.waitForLoadState('networkidle', { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(1200);

  const text = await page.locator('main').innerText().catch(() => '');
  const shell = (await page.locator('aside, nav').count()) > 0;
  const crash = /Unexpected Application Error/i.test(text) || hard.some((h) => /TypeError|is not a function|Cannot read/.test(h));
  const blank = text.trim().length < 40;
  const matched = expect ? expect.test(text) : true;
  const ok = !crash && !blank && shell && matched && hard.length === 0;
  results.push({ name, ok, crash, blank, shell, matched, hard: hard.slice(0, 2) });
  console.log(
    (ok ? '✅ ' : '❌ ') + name.padEnd(22) +
    (crash ? 'CRASH ' : '') + (blank ? 'BLANK ' : '') + (!shell ? 'NO-SHELL ' : '') +
    (!matched ? 'UNEXPECTED-STATE ' : '') + (hard.length ? 'JSERR ' : '') +
    '| ' + text.replace(/\n+/g, ' · ').slice(0, 78),
  );
  await ctx.close();
}

for (const c of CASES) {
  await run(c.name, async (page) => {
    await page.route(DATA_EP, (r) => r.fulfill({ status: c.status, contentType: 'application/json', body: c.body }));
  }, c.expect);
}

// Network timeout / connection failure on the data call.
await run('network timeout', async (page) => {
  await page.route(DATA_EP, (r) => r.abort('timedout'));
}, /Something went wrong|Network|error/i);

// OFFLINE: load the app online first, THEN drop the network and force a live
// fetch via client-side navigation. (Going offline before the first load only
// proves the browser can't download the bundle — nothing about the app.)
{
  const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  const hard = [];
  page.on('pageerror', (e) => hard.push('pageerror: ' + e.message.slice(0, 100)));
  await page.goto(BASE + ROUTE, { waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(700);
  await ctx.setOffline(true);
  // SPA-navigate to another data-backed page: its fetch happens while offline.
  await page.locator('aside a[href="/hr/employees"], nav a[href="/hr/employees"]').first().click().catch(() => {});
  await page.waitForTimeout(2500);

  const text = await page.locator('main').innerText().catch(() => '');
  const shell = (await page.locator('aside, nav').count()) > 0;
  const banner = await page.getByText(/offline|no connection|reconnect/i).count();
  const crash = /Unexpected Application Error/i.test(text) || hard.some((h) => /TypeError|Cannot read/.test(h));
  const blank = text.trim().length < 40;
  const ok = !crash && !blank && shell;
  results.push({ name: 'offline', ok, crash, blank, shell, banner });
  console.log(
    (ok ? '✅ ' : '❌ ') + 'offline'.padEnd(22) + (crash ? 'CRASH ' : '') + (blank ? 'BLANK ' : '') +
    (!shell ? 'NO-SHELL ' : '') + '| banner=' + banner + ' · ' + text.replace(/\n+/g, ' · ').slice(0, 66),
  );
  await ctx.setOffline(false);
  await ctx.close();
}

// Slow response must show a loading state, then resolve to real data.
{
  const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  await page.route(DATA_EP, async (r) => { await new Promise((res) => setTimeout(res, 3000)); await r.continue(); });
  await page.goto(BASE + ROUTE, { waitUntil: 'domcontentloaded' }).catch(() => {});
  await page.waitForTimeout(900);
  const skeleton = await page.locator('.animate-pulse').count();
  await page.waitForTimeout(4000);
  const rows = await page.locator('tbody tr').count();
  const ok = skeleton > 0 && rows > 0;
  results.push({ name: 'slow response', ok });
  console.log((ok ? '✅ ' : '❌ ') + 'slow response'.padEnd(22) + `| skeleton=${skeleton} then rows=${rows}`);
  await ctx.close();
}

await browser.close();
const bad = results.filter((r) => !r.ok);
console.log('\n=== NETWORK BEHAVIOUR: ' + (results.length - bad.length) + '/' + results.length + ' handled gracefully ===');
bad.forEach((b) => console.log('  ❌ ' + b.name + ' ' + JSON.stringify(b)));
fs.writeFileSync('/tmp/cert-network.json', JSON.stringify(results, null, 2));
process.exitCode = bad.length ? 1 : 0;
