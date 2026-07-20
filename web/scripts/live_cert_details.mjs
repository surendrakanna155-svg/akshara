// Deep-link the parametric detail routes with REAL record ids pulled from the
// live API, and verify each renders the record (not a crash / blank / wrong id).
import { chromium } from '@playwright/test';
import { ensureFreshSession } from './refresh_session.mjs';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
const API = 'https://akshara.veloraunisexsalon.com/functions/v1/api';
const s = await ensureFreshSession(600);

const get = async (p) => {
  const r = await fetch(API + p, { headers: { Authorization: `Bearer ${s.token}`, 'X-School-Id': s.schoolId } });
  return r.json().catch(() => null);
};
const firstId = (j, ...keys) => {
  const items = j?.data?.items ?? j?.data ?? [];
  const it = Array.isArray(items) ? items[0] : items;
  for (const k of keys) if (it?.[k]) return it[k];
  return null;
};

const [students, collections, leads] = await Promise.all([
  get('/sis/students?pageSize=1'),
  get('/finance/collections?pageSize=1'),
  get('/admissions/leads?pageSize=1'),
]);

const CASES = [
  { route: '/sis/students/' + firstId(students, 'studentId', 'id'), label: 'SIS student detail' },
  { route: '/finance/collections/' + firstId(collections, 'id'), label: 'Collection detail' },
  { route: '/admissions/leads/' + firstId(leads, 'id'), label: 'Lead detail' },
].filter((c) => !c.route.endsWith('null'));

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();
const errs = [];
page.on('console', (m) => { if (m.type() === 'error' && !/Failed to load resource/.test(m.text())) errs.push(m.text().slice(0, 120)); });
page.on('pageerror', (e) => errs.push('pageerror ' + e.message.slice(0, 120)));

let bad = 0;
for (const c of CASES) {
  await page.goto(BASE + c.route, { waitUntil: 'networkidle', timeout: 25000 }).catch(() => {});
  await page.waitForTimeout(900);
  const text = await page.locator('main').innerText().catch(() => '');
  const crash = /Unexpected Application Error/i.test(text);
  const blank = text.trim().length < 60;
  const rotten = ['undefined', 'NaN', '[object Object]'].filter((t) => text.includes(t));
  const ok = !crash && !blank && !rotten.length;
  if (!ok) bad++;
  console.log(
    (ok ? '✅ ' : '❌ ') + c.label.padEnd(22) + c.route.slice(0, 52).padEnd(54) +
    (crash ? 'CRASH ' : '') + (blank ? 'BLANK ' : '') + (rotten.length ? 'ROTTEN:' + rotten : '') +
    '| ' + text.replace(/\n+/g, ' · ').slice(0, 90),
  );
}

// 404 semantics: a well-formed but non-existent id must not crash the page.
const ghost = '/sis/students/00000000-0000-4000-8000-000000000999';
await page.goto(BASE + ghost, { waitUntil: 'networkidle', timeout: 20000 }).catch(() => {});
await page.waitForTimeout(900);
const gt = await page.locator('main').innerText().catch(() => '');
const gOk = !/Unexpected Application Error/i.test(gt) && gt.trim().length > 40;
console.log((gOk ? '✅ ' : '❌ ') + 'unknown-id detail'.padEnd(22) + ghost.slice(0, 52).padEnd(54) + '| ' + gt.replace(/\n+/g, ' · ').slice(0, 80));
if (!gOk) bad++;

console.log('\nconsole errors: ' + (errs.length || 'none ✅'));
errs.slice(0, 5).forEach((e) => console.log('   ❌ ' + e));
console.log('detail pages failing: ' + (bad || 'none ✅'));
await browser.close();
process.exitCode = bad || errs.length ? 1 : 0;
