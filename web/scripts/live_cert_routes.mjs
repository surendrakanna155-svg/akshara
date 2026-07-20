// LIVE route sweep — every built route, under ONE reused authenticated session.
// Read-only: navigates and observes. Classifies each route's honest state and
// records console/page/network errors. No OTP requests (storageState reuse).
import fs from 'node:fs';
import { chromium } from '@playwright/test';
import { ensureFreshSession, tokenExpiresInSec } from './refresh_session.mjs';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
const ROUTES = fs.readFileSync('/tmp/all_routes.txt', 'utf8').split('\n').map((s) => s.trim()).filter(Boolean);
const CONC = Number(process.env.CONC || 4);

// The access token lives 15 min. An expired token turns every page into an
// error state and would read as a FALSE PASS ("no crash" because no data), so
// refresh before the sweep and assert the token outlives it.
const sess = await ensureFreshSession(600);
console.log('# session: role=' + sess.role + ' · token valid ' + (tokenExpiresInSec(sess.token) / 60).toFixed(1) + ' min');

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });

const results = [];
const queue = [...ROUTES];

async function worker(id) {
  const page = await ctx.newPage();
  const bucket = { errors: [], api: [] };
  page.on('console', (m) => { if (m.type() === 'error') bucket.errors.push(m.text().slice(0, 160)); });
  page.on('pageerror', (e) => bucket.errors.push('pageerror: ' + e.message.slice(0, 160)));
  page.on('response', (r) => {
    const u = r.url();
    if (u.includes('/api-proxy/')) bucket.api.push({ status: r.status(), path: u.split('/api-proxy')[1].split('?')[0] });
  });

  while (queue.length) {
    const route = queue.shift();
    bucket.errors = []; bucket.api = [];
    const rec = { route, ok: true };
    try {
      const resp = await page.goto(BASE + route, { waitUntil: 'domcontentloaded', timeout: 20000 });
      rec.http = resp?.status();
      // let react-query settle
      await page.waitForLoadState('networkidle', { timeout: 8000 }).catch(() => {});
      await page.waitForTimeout(250);

      const body = await page.locator('body').innerText().catch(() => '');
      rec.textLen = body.length;
      rec.shell = await page.locator('aside, nav').count() > 0;
      rec.rows = await page.locator('tbody tr').count().catch(() => 0);

      // Honest-state classification (mutually exclusive markers from AsyncBoundary)
      const has = (re) => re.test(body);
      rec.state = rec.rows > 0 ? 'data'
        : has(/Module not enabled/) ? 'entitlement-403'
        : has(/Choose filters to load/) ? 'needs-params-422'
        : has(/Something went wrong/) ? 'error'
        : has(/Awaiting live data/) ? 'awaiting'
        : has(/Nothing to show yet|No .* yet/) ? 'empty'
        : has(/part of the parity build/) ? 'scaffold'
        : rec.textLen > 400 ? 'content' : 'thin';

      // Blank-screen + crash detection
      rec.blank = rec.textLen < 60;
      rec.crash = has(/Unexpected Application Error|is not a function|Cannot read propert/);
      rec.api = bucket.api;
      rec.errors = [...bucket.errors];
      rec.ok = !rec.blank && !rec.crash && bucket.errors.filter((e) => !/Failed to load resource/.test(e)).length === 0;
    } catch (e) {
      rec.ok = false;
      rec.state = 'nav-fail';
      rec.errors = [String(e.message).split('\n')[0].slice(0, 120)];
    }
    results.push(rec);
    process.stdout.write(rec.ok ? '.' : 'X');
  }
  await page.close();
}

await Promise.all(Array.from({ length: CONC }, (_, i) => worker(i)));
await browser.close();

// ---- report ----
const by = (s) => results.filter((r) => r.state === s).length;
console.log('\n\n=== LIVE ROUTE SWEEP: ' + results.length + ' routes ===');
for (const s of ['data', 'content', 'empty', 'awaiting', 'entitlement-403', 'needs-params-422', 'error', 'scaffold', 'thin', 'nav-fail'])
  if (by(s)) console.log(`  ${s.padEnd(18)} ${by(s)}`);

const crashes = results.filter((r) => r.crash);
const blanks = results.filter((r) => r.blank);
const jsErrs = results.filter((r) => (r.errors || []).some((e) => !/Failed to load resource/.test(e)));
console.log('\ncrashes      : ' + (crashes.length || 'none ✅'));
crashes.forEach((r) => console.log('   ❌ ' + r.route));
console.log('blank screens: ' + (blanks.length || 'none ✅'));
blanks.forEach((r) => console.log('   ❌ ' + r.route));
console.log('JS errors    : ' + (jsErrs.length || 'none ✅'));
jsErrs.slice(0, 12).forEach((r) => console.log('   ❌ ' + r.route + ' :: ' + r.errors.filter((e) => !/Failed to load resource/.test(e))[0]));

// backend status rollup
const codes = {};
results.flatMap((r) => r.api || []).forEach((a) => { codes[a.status] = (codes[a.status] || 0) + 1; });
console.log('\nAPI status rollup: ' + JSON.stringify(codes));
const failing = {};
results.flatMap((r) => r.api || []).filter((a) => a.status >= 500).forEach((a) => { failing[a.path] = (failing[a.path] || 0) + 1; });
console.log('5xx endpoints: ' + JSON.stringify(failing, null, 1));

fs.writeFileSync('/tmp/cert-routes.json', JSON.stringify(results, null, 2));
console.log('\nrows rendered across sweep: ' + results.reduce((n, r) => n + (r.rows || 0), 0));

// Validity gate: a 401 anywhere means the token died mid-sweep and every later
// "no crash" is meaningless. Fail loudly rather than certify a dead session.
const unauth = results.flatMap((r) => r.api || []).filter((a) => a.status === 401).length;
console.log('401s (session validity): ' + (unauth === 0 ? '0 ✅' : unauth + ' ❌ SWEEP INVALID — token expired, re-run'));
if (unauth > 0) process.exitCode = 2;
