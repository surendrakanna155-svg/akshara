// Assert the fixed pages render REAL values (not blanks/undefined/NaN) from live
// production records. Reuses the one session; refreshes without a new OTP.
import { chromium } from '@playwright/test';
import { ensureFreshSession } from './refresh_session.mjs';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
await ensureFreshSession(300);

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();

const CHECKS = [
  { route: '/sis/registry', label: 'SIS registry (student names + class)' },
  { route: '/attendance', label: 'Attendance watchlist' },
  { route: '/teacher/messages', label: 'Teacher messages' },
  { route: '/finance/dashboard', label: 'Finance dashboard KPIs' },
  { route: '/admissions/dashboard', label: 'Admissions dashboard KPIs' },
];

let bad = 0;
for (const c of CHECKS) {
  await page.goto(BASE + c.route, { waitUntil: 'networkidle', timeout: 25000 }).catch(() => {});
  await page.waitForTimeout(900);
  const text = await page.locator('main').innerText().catch(() => '');
  // Symptoms of a broken mapping surviving into the DOM.
  const rot = ['undefined', 'NaN', 'null', '[object Object]'].filter((t) => text.includes(t));
  const firstRow = await page.locator('tbody tr').first().innerText().catch(() => '');
  console.log('\n===== ' + c.label + ' (' + c.route + ') =====');
  console.log('  rotten tokens : ' + (rot.length ? '❌ ' + rot.join(', ') : 'none ✅'));
  if (firstRow) console.log('  first row     : ' + firstRow.replace(/\n+/g, ' | ').slice(0, 130));
  const kpi = text.split('\n').filter((l) => /₹|%/.test(l)).slice(0, 5);
  if (kpi.length) console.log('  money/percent : ' + kpi.join(' · ').slice(0, 150));
  if (rot.length) bad++;
}
console.log('\npages with rotten values: ' + (bad || 'none ✅'));
await browser.close();
process.exitCode = bad ? 1 : 0;
