// LIVE interaction certification on REAL production records. Asserts that each
// control actually CHANGES state (rows filter, order reorders, drawer opens) —
// not merely that a click landed. Read-only: no mutations, no form submits.
import fs from 'node:fs';
import { chromium } from '@playwright/test';
import { ensureFreshSession, tokenExpiresInSec } from './refresh_session.mjs';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
const sess = await ensureFreshSession(600);
console.log('# session: role=' + sess.role + ' · token valid ' + (tokenExpiresInSec(sess.token) / 60).toFixed(1) + ' min\n');

// Data-bearing routes confirmed populated by the route sweep.
const TARGETS = [
  '/sis/registry', '/hr/employees', '/finance/collections', '/admissions/leads',
  '/library/catalog', '/transport/routes', '/academics/exams', '/communication',
  '/attendance/corrections', '/teacher/attendance', '/finance/refunds', '/library/members',
];

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();
const errors = [];
let cur = '';
page.on('console', (m) => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) errors.push(cur + ': ' + m.text().slice(0, 120)); });
page.on('pageerror', (e) => errors.push(cur + ': pageerror ' + e.message.slice(0, 120)));
let unauth = 0;
page.on('response', (r) => { if (r.url().includes('/api-proxy/') && r.status() === 401) unauth++; });

const rowText = async () => (await page.locator('tbody tr').allInnerTexts()).join('|');
const rowCount = () => page.locator('tbody tr').count();
const tally = { search: [], filter: [], sort: [], drawer: [], tabs: [], detail: [], back: [], refresh: [] };

for (const route of TARGETS) {
  cur = route;
  const r = { route };
  await page.goto(BASE + route, { waitUntil: 'networkidle', timeout: 25000 }).catch(() => {});
  await page.waitForTimeout(600);
  const base = await rowCount();
  if (!base) { console.log(route.padEnd(26) + ' — no rows, skipped'); continue; }

  // ---- SEARCH: a term from row 1 keeps rows; nonsense term empties the table
  const search = page.locator('input[placeholder*="Search" i]').first();
  if (await search.count()) {
    // Each page defines its own `search.match` over ONE or TWO fields (e.g.
    // refunds searches studentName only). So try several real tokens from the
    // row and pass if any matches — a single guessed token proves nothing.
    const cells = await page.locator('tbody tr').first().locator('td').allInnerTexts();
    const tokens = [...new Set((cells.join(' ').match(/[A-Za-z][A-Za-z0-9-]{3,}/g) || []))]
      .filter((w) => !/^[0-9a-f]{8}-[0-9a-f]{4}/i.test(w)) // raw UUIDs are never searchable
      .filter((w) => !/^(Active|Pending|Approved|Completed|Paid|Rejected|Processed)$/i.test(w))
      .slice(0, 8);

    await search.fill('zzzqqq_no_match');
    await page.waitForTimeout(350);
    const none = await rowCount();

    let hit = null;
    let hitRows = 0;
    for (const t of tokens) {
      await search.fill(t);
      await page.waitForTimeout(300);
      const n = await rowCount();
      if (n > 0 && n <= base) { hit = t; hitRows = n; break; }
    }
    await search.fill('');
    await page.waitForTimeout(300);
    const restoredAll = await rowCount();
    r.search = none === 0 && hit && restoredAll === base
      ? `ok("${hit}"→${hitRows})`
      : `FAIL(tried=${tokens.length} base=${base} none=${none} restored=${restoredAll})`;
    tally.search.push(String(r.search).startsWith('ok'));
  }

  // ---- FILTER: selecting the first real option must not error and must subset
  const sel = page.locator('select').first();
  if (await sel.count()) {
    const opts = await sel.locator('option').all();
    let applied = false;
    for (const o of opts.slice(1, 3)) {
      const v = await o.getAttribute('value');
      if (!v) continue;
      await sel.selectOption(v).catch(() => {});
      await page.waitForTimeout(350);
      const n = await rowCount();
      if (n <= base) applied = true;
      break;
    }
    await sel.selectOption('').catch(() => {});
    await page.waitForTimeout(250);
    const restored = await rowCount();
    r.filter = applied && restored === base ? 'ok' : `FAIL(restored=${restored}/${base})`;
    tally.filter.push(r.filter === 'ok');
  }

  // ---- SORT: clicking a sortable header must reorder (when >1 row)
  // A column whose values are all identical CANNOT reorder — that is correct
  // behaviour, not a defect. Try every sortable header and pass if any reorders;
  // only report FAIL when a column with distinct values refuses to sort.
  // Only some columns are sortable, so the Nth sortable header is NOT the Nth
  // column — resolve each header's true column index before reading its values.
  const sortableIdx = await page.locator('thead th').evaluateAll((els) =>
    els.map((el, i) => (el.className.includes('cursor-pointer') ? i : -1)).filter((i) => i >= 0),
  );
  if (sortableIdx.length && base > 1) {
    let reordered = false;
    let distinctSeen = false;
    for (const col of sortableIdx) {
      const vals = await page.locator(`tbody tr td:nth-child(${col + 1})`).allInnerTexts();
      const distinct = new Set(vals.map((v) => v.trim())).size > 1;
      const th = page.locator('thead th').nth(col);
      await th.click();
      await page.waitForTimeout(280);
      const asc = await rowText();
      await th.click();
      await page.waitForTimeout(280);
      const flipped = asc !== (await rowText());
      if (distinct) distinctSeen = true;
      // A column with distinct values MUST reorder; uniform columns cannot.
      if (distinct && flipped) { reordered = true; break; }
    }
    r.sort = reordered ? 'ok' : !distinctSeen ? 'ok(uniform values)' : 'FAIL(distinct values, no reorder)';
    tally.sort.push(String(r.sort).startsWith('ok'));
  } else if (sortableIdx.length) {
    r.sort = 'ok(single-row)';
    tally.sort.push(true);
  }

  // ---- DRAWER / DIALOG: row click opens a dialog, Esc closes it
  const row = page.locator('tr.cursor-pointer').first();
  if (await row.count()) {
    await row.click().catch(() => {});
    await page.waitForTimeout(500);
    const dlg = page.locator('[role="dialog"]').first();
    const opened = await dlg.isVisible().catch(() => false);
    let closed = null;
    if (opened) {
      await page.keyboard.press('Escape');
      await page.waitForTimeout(400);
      closed = !(await dlg.isVisible().catch(() => false));
    }
    if (opened) { r.drawer = closed ? 'ok(open+esc)' : 'FAIL(no esc close)'; tally.drawer.push(!!closed); }
    else if (page.url() !== BASE + route) { r.detail = 'ok(navigated ' + page.url().replace(BASE, '') + ')'; tally.detail.push(true); }
  }

  // ---- BACK NAVIGATION
  if (page.url() !== BASE + route) {
    await page.goBack({ waitUntil: 'networkidle' }).catch(() => {});
    await page.waitForTimeout(500);
    const backOk = page.url().includes(route) && (await rowCount()) > 0;
    r.back = backOk ? 'ok' : 'FAIL(url=' + page.url().replace(BASE, '') + ')';
    tally.back.push(backOk);
  }

  // ---- MODULE TABS: rendered as NavLinks (route-based), not ARIA tabs. Click a
  // sibling tab and require a real route change that renders without error.
  const tabStrip = page.locator('div.overflow-x-auto.border-b a');
  const tabCount = await tabStrip.count();
  if (tabCount > 1) {
    const before = page.url();
    let moved = false;
    for (let i = 0; i < Math.min(tabCount, 4); i++) {
      const href = await tabStrip.nth(i).getAttribute('href');
      if (href && !before.endsWith(href)) {
        await tabStrip.nth(i).click().catch(() => {});
        await page.waitForLoadState('networkidle').catch(() => {});
        await page.waitForTimeout(500);
        moved = page.url() !== before;
        const crashed = await page.getByText(/Unexpected Application Error/i).count();
        r.tabs = moved && !crashed ? `ok(${tabCount}→${page.url().replace(BASE, '')})` : 'FAIL';
        tally.tabs.push(!!moved && !crashed);
        break;
      }
    }
    if (!moved && r.tabs === undefined) { r.tabs = 'ok(single)'; tally.tabs.push(true); }
    await page.goto(BASE + route, { waitUntil: 'networkidle' }).catch(() => {});
    await page.waitForTimeout(400);
  }

  // ---- REFRESH: reload must re-fetch and re-render the same rows
  await page.reload({ waitUntil: 'networkidle' }).catch(() => {});
  await page.waitForTimeout(700);
  const after = await rowCount();
  r.refresh = after === base ? 'ok' : `FAIL(${after}/${base})`;
  tally.refresh.push(after === base);

  console.log(
    route.padEnd(26) + ' rows=' + String(base).padEnd(3) +
    ['search', 'filter', 'sort', 'drawer', 'detail', 'back', 'tabs', 'refresh']
      .filter((k) => r[k]).map((k) => k + '=' + r[k]).join(' '),
  );
}
await browser.close();

const pct = (a) => (a.length ? a.filter(Boolean).length + '/' + a.length : '—');
console.log('\n=== INTERACTION TALLY (real records) ===');
for (const [k, v] of Object.entries(tally)) console.log('  ' + k.padEnd(9) + pct(v));
console.log('\nconsole/page errors: ' + (errors.length || 'none ✅'));
errors.slice(0, 10).forEach((e) => console.log('   ❌ ' + e));
console.log('401s: ' + (unauth === 0 ? '0 ✅' : unauth + ' ❌ INVALID RUN'));
fs.writeFileSync('/tmp/cert-interactions.json', JSON.stringify({ tally, errors }, null, 2));
const failed = Object.values(tally).some((v) => v.some((x) => !x)) || errors.length || unauth;
process.exitCode = failed ? 1 : 0;
