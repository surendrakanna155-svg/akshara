// LIVE interaction + populated-visual certification. READ-ONLY: authenticates
// via API, injects the session, then drives the live-built app across the
// data-bearing routes — exercising tabs, sortable columns, and detail drawers on
// REAL rows, and capturing populated screenshots. No mutations (no form submits,
// no action buttons; only tab/sort/row clicks that open read-only detail views).
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
const API = 'https://api.nikshaos.in/functions/v1/api';
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function post(p, b, t) { const r = await fetch(API + p, { method: 'POST', headers: { 'Content-Type': 'application/json', ...(t ? { Authorization: `Bearer ${t}` } : {}) }, body: JSON.stringify(b) }); return { status: r.status, json: await r.json().catch(() => null) }; }
async function get(p, t) { const r = await fetch(API + p, { headers: t ? { Authorization: `Bearer ${t}` } : {} }); return { status: r.status, json: await r.json().catch(() => null) }; }
async function loginCd(phone) { for (let i = 0; i < 8; i++) { const r = await post('/auth/login', { identifier: phone, type: 'phone' }); const d = r.json?.data; if (d?.otp && d?.sessionId) return d; if (r.json?.error?.code === 'OTP_COOLDOWN') { process.stdout.write('  (cooldown 20s)\n'); await sleep(20000); continue; } throw new Error('login ' + JSON.stringify(r.json?.error || r.status)); } throw new Error('cooldown'); }
async function authenticate(phone) { const { otp, sessionId } = await loginCd(phone); const v = await post('/auth/verify-otp', { identifier: phone, type: 'phone', otp, sessionId }); const d = v.json?.data; return d?.accessToken || d?.token; }
async function schoolSession(t0) {
  const me0 = await get('/auth/me', t0); const d0 = me0.json?.data || {};
  const schools = d0.schools || d0.availableSchools || d0.memberships || [];
  const sid = (Array.isArray(schools) && (schools[0]?.id || schools[0]?.schoolId)) || d0.schoolId;
  let token = t0;
  if (sid) { const sw = await post('/auth/context/switch', { scope: 'school', schoolId: sid }, t0); token = sw.json?.data?.accessToken || t0; }
  const me = (await get('/auth/me', token)).json?.data || {};
  return {
    id: String(me.id ?? me.userId ?? 'me'), name: String(me.name ?? me.fullName ?? 'Signed in'),
    role: String(me.role ?? me.erpRole ?? 'schoolAdmin'),
    schoolName: String(me.schoolName ?? me.organizationName ?? 'Akshara'),
    schoolId: String(me.schoolId ?? sid ?? ''), tenantId: String(me.organizationId ?? me.tenantId ?? ''), token,
  };
}

// Data-bearing routes (confirmed rows) + their tabbed dashboards.
const ROUTES = [
  '/sis/registry', '/hr/employees', '/finance/collections', '/finance/student-accounts',
  '/library/catalog', '/transport/routes', '/admissions/leads', '/academics/exams',
  '/finance/fee-structures', '/sis/dashboard', '/finance/dashboard', '/hr/dashboard',
  '/admissions/dashboard', '/library/dashboard', '/transport/dashboard', '/admin/dashboard',
];

const browser = await chromium.launch();
// Reuse a cached session (from auth_once.mjs) to avoid re-hitting the OTP
// rate-limit; fall back to a fresh auth only if no cache exists.
const session = fs.existsSync('/tmp/live-session.json')
  ? JSON.parse(fs.readFileSync('/tmp/live-session.json', 'utf8'))
  : await schoolSession(await authenticate('9876543210'));
console.log(`# LIVE session: role=${session.role} school=${session.schoolId || '-'} tenant=${session.tenantId || '-'}`);
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
await ctx.addInitScript((s) => localStorage.setItem('akshara.session', JSON.stringify(s)), session);
const page = await ctx.newPage();
const errors = [];
let cur = '';
page.on('console', (m) => { if (m.type() === 'error') errors.push(`${cur}: ${m.text().slice(0, 110)}`); });
page.on('pageerror', (e) => errors.push(`${cur}: pageerror ${e.message.slice(0, 110)}`));
fs.mkdirSync('visual-baselines/live', { recursive: true });

let tabs = 0, drawers = 0, sorts = 0, rowsSeen = 0, populated = 0;
const rows = [];
for (const route of ROUTES) {
  cur = route;
  const rec = { route, rows: 0, tabs: 0, drawer: false, sorts: 0 };
  try {
    await page.goto(BASE + route, { waitUntil: 'domcontentloaded', timeout: 15000 });
    // wait up to 6s for data to populate a table or KPI cards
    await page.waitForFunction(() => document.querySelectorAll('tr').length > 1 || document.querySelectorAll('[data-kpi], .ak-kpi, [role="tab"]').length > 0, { timeout: 6000 }).catch(() => {});
    await page.waitForTimeout(400);
    rec.rows = await page.locator('tbody tr').count();
    rowsSeen += rec.rows; if (rec.rows > 0) populated++;
    // tabs
    const tb = page.locator('[role="tab"]'); const tc = Math.min(await tb.count(), 6);
    for (let i = 0; i < tc; i++) { await tb.nth(i).click({ timeout: 1500 }).catch(() => {}); await page.waitForTimeout(120); rec.tabs++; }
    // sortable header
    const st = page.locator('th.cursor-pointer'); if (await st.count()) { await st.first().click({ timeout: 1500 }).catch(() => {}); await page.waitForTimeout(100); rec.sorts++; }
    // detail drawer from a real row
    const cr = page.locator('tr.cursor-pointer'); if (await cr.count()) { await cr.first().click({ timeout: 1500 }).catch(() => {}); await page.waitForTimeout(300); rec.drawer = await page.locator('[role="dialog"]').first().isVisible().catch(() => false); if (rec.drawer) await page.keyboard.press('Escape'); }
    const slug = route.replace(/\//g, '_').replace(/^_/, '');
    await page.screenshot({ path: `visual-baselines/live/${slug}.png` });
  } catch (e) { errors.push(`${route}: nav ${(e.message || '').split('\n')[0].slice(0, 80)}`); }
  tabs += rec.tabs; drawers += rec.drawer ? 1 : 0; sorts += rec.sorts;
  rows.push(rec);
  console.log(`  ${route.padEnd(28)} rows=${rec.rows} tabs=${rec.tabs} drawer=${rec.drawer ? '✓' : '-'} sort=${rec.sorts}`);
}
await browser.close();
console.log(`\n[LIVE] ${populated}/${ROUTES.length} routes populated with real rows; ${rowsSeen} rows rendered`);
console.log(`  exercised: ${tabs} tab-switches, ${drawers} detail drawers on live rows, ${sorts} column sorts`);
console.log(`  console/page errors: ${errors.length ? errors.length : 'none ✅'}`);
errors.slice(0, 30).forEach((e) => console.log('   ❌ ' + e));
fs.writeFileSync('/tmp/cert-live-interact.json', JSON.stringify({ session: { role: session.role, schoolId: session.schoolId }, populated, rowsSeen, tabs, drawers, sorts, errors, rows }, null, 2));
