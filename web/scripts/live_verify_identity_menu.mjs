// Verify the identity-menu fix in LIVE mode: (1) NO demo persona list, (2) the
// session survives opening the menu, (3) Sign out clears the session and lands
// on /login. Reuses the one session; refreshes without a new OTP.
import { chromium } from '@playwright/test';
import { ensureFreshSession } from './refresh_session.mjs';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
await ensureFreshSession(300);

const browser = await chromium.launch();
const ctx = await browser.newContext({ storageState: '/tmp/ak-web-state.json', viewport: { width: 1440, height: 900 } });
const page = await ctx.newPage();
await page.goto(BASE + '/sis/registry', { waitUntil: 'networkidle' });
await page.waitForTimeout(700);
const rowsBefore = await page.locator('tbody tr').count();

// Open the identity menu.
await page.getByText('Staging School Admin').first().click().catch(() => {});
await page.waitForTimeout(500);
const menuText = await page.locator('.absolute.right-0').innerText().catch(() => '');
const hasPersonaList = /Switch persona/i.test(menuText);
const hasSignOut = /Sign out/i.test(menuText);
// Demo roles that must NOT appear as switch targets in live.
const leaks = ['Principal', 'Finance Admin', 'Teacher', 'Parent', 'Librarian'].filter((r) => menuText.includes(r));

console.log('rows before        : ' + rowsBefore);
console.log('persona list shown : ' + (hasPersonaList ? '❌ YES (should be demo-only)' : 'no ✅'));
console.log('demo-role leaks    : ' + (leaks.length ? '❌ ' + leaks.join(', ') : 'none ✅'));
console.log('Sign out present   : ' + (hasSignOut ? 'yes ✅' : '❌ MISSING'));

// Session must be intact after merely opening the menu.
const sessAfterOpen = await page.evaluate(() => JSON.parse(localStorage.getItem('akshara.session') || '{}'));
console.log('session intact     : ' + (sessAfterOpen.token ? 'yes ✅ (role=' + sessAfterOpen.role + ')' : '❌ token lost'));

// Now actually sign out.
await page.getByText('Sign out', { exact: true }).click().catch(() => {});
await page.waitForTimeout(1200);
const url = page.url();
const sessAfterOut = await page.evaluate(() => localStorage.getItem('akshara.session'));
const onLogin = url.includes('/login');
console.log('after Sign out url : ' + url.replace(BASE, '') + (onLogin ? ' ✅' : ' ❌'));
console.log('session cleared    : ' + (!sessAfterOut ? 'yes ✅' : '❌ still present'));

const ok = !hasPersonaList && !leaks.length && hasSignOut && sessAfterOpen.token && onLogin && !sessAfterOut;
console.log('\nRESULT: ' + (ok ? 'PASS ✅' : 'FAIL ❌'));
await browser.close();
process.exitCode = ok ? 0 : 1;
