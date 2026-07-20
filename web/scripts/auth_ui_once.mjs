// Authenticate ONCE through the REAL login UI (no session injection), then persist
// Playwright storageState for reuse by every later sweep. Exactly ONE OTP request.
import fs from 'node:fs';
import { chromium } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
const PHONE = process.env.PILOT_PHONE || '9876543210';
const STATE = '/tmp/ak-web-state.json';

const browser = await chromium.launch();
const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();

const console_errors = [];
const net = [];
let refreshToken = null;
page.on('console', (m) => { if (m.type() === 'error') console_errors.push(m.text().slice(0, 200)); });
page.on('pageerror', (e) => console_errors.push('pageerror: ' + e.message.slice(0, 200)));
page.on('response', async (r) => {
  const u = r.url();
  if (!u.includes('/api-proxy/')) return;
  net.push({ status: r.status(), path: u.split('/api-proxy')[1] });
  // The access token lives only 15 min and the web drops the refreshToken it is
  // handed. Capture it here so the sweep can mint fresh tokens via /auth/refresh
  // instead of burning another OTP.
  if (u.includes('/auth/verify-otp')) {
    const j = await r.json().catch(() => null);
    refreshToken = j?.data?.refreshToken ?? null;
  }
});

await page.goto(BASE + '/login', { waitUntil: 'networkidle' });

// The live build should default to the credentials tab (IS_DEMO=false).
const tab = page.getByRole('button', { name: 'Sign in', exact: true });
if (await tab.count()) await tab.first().click().catch(() => {});
await page.waitForTimeout(200);

const modeDemo = await page.getByText('Demo mode is on').count();
console.log('mode: ' + (modeDemo ? 'DEMO (!! build not live)' : 'LIVE credentials'));

await page.getByLabel('Mobile number or email').fill(PHONE);
await page.getByRole('button', { name: /Send verification code/i }).click();

// Wait for either the OTP page or an inline error.
await page.waitForTimeout(2500);
const url1 = page.url();
console.log('after send-code url: ' + url1);
if (!url1.includes('/otp')) {
  const err = await page.locator('.text-error, [class*="error"]').allInnerTexts().catch(() => []);
  console.log('LOGIN ERROR: ' + JSON.stringify(err.slice(0, 3)));
  console.log('net: ' + JSON.stringify(net));
  await browser.close();
  process.exit(1);
}

// OTP should be prefilled by devOtp on the pilot backend.
await page.waitForTimeout(500);
const filled = await page.locator('input[inputmode="numeric"]').evaluateAll((els) => els.map((e) => e.value).join(''));
console.log('otp prefilled: ' + (filled.length === 6 ? 'yes (' + filled.length + ' digits)' : 'NO -> "' + filled + '"'));

await page.getByRole('button', { name: /Verify & continue/i }).click();
await page.waitForTimeout(4000);

const url2 = page.url();
const session = await page.evaluate(() => localStorage.getItem('akshara.session'));
const s = session ? JSON.parse(session) : null;

console.log('after verify url: ' + url2);
console.log('session: ' + (s ? JSON.stringify({ id: s.id, name: s.name, role: s.role, schoolName: s.schoolName, schoolId: s.schoolId, tenantId: s.tenantId, tokenLen: (s.token || '').length }) : 'NONE'));
console.log('console errors: ' + (console_errors.length || 'none'));
console_errors.slice(0, 5).forEach((e) => console.log('  ❌ ' + e));
console.log('network: ' + JSON.stringify(net));

console.log('refreshToken captured: ' + (refreshToken ? 'yes' : 'NO'));
if (s && s.token) {
  await ctx.storageState({ path: STATE });
  fs.writeFileSync('/tmp/ak-web-session.json', JSON.stringify({ ...s, refreshToken }));
  console.log('\n✅ AUTH OK — storageState saved to ' + STATE);
} else {
  console.log('\n❌ AUTH FAILED — no token in session');
}
await browser.close();
