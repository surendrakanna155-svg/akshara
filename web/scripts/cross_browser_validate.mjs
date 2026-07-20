// Cross-browser + responsive validation across Chromium, Firefox, and WebKit
// (Safari's engine) — all run locally headless via Playwright. Drives the built
// app (demo mode): login → shell → a dashboard → a data table, capturing console
// errors, render assertions, and horizontal-overflow at 4 viewports per engine.
//
//   node scripts/cross_browser_validate.mjs
import { chromium, firefox, webkit } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://localhost:4340';
const ENGINES = [['Chromium', chromium], ['Firefox', firefox], ['WebKit (Safari)', webkit]];
const VIEWPORTS = [
  ['desktop', 1440, 900],
  ['laptop', 1280, 800],
  ['tablet', 768, 1024],
  ['mobile', 390, 844],
];

async function checkOverflow(page) {
  return await page.evaluate(() => {
    const el = document.scrollingElement || document.documentElement;
    return { scrollW: el.scrollWidth, innerW: window.innerWidth, overflow: el.scrollWidth - window.innerWidth };
  });
}

async function runEngine(name, type) {
  const res = { name, steps: [], consoleErrors: [], overflow: [], ok: true };
  let browser;
  try {
    browser = await type.launch();
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
    const page = await ctx.newPage();
    page.on('console', (m) => { if (m.type() === 'error') res.consoleErrors.push(m.text().slice(0, 160)); });
    page.on('pageerror', (e) => res.consoleErrors.push('pageerror: ' + e.message.slice(0, 160)));

    // 1. Login page renders
    await page.goto(`${BASE}/login`, { waitUntil: 'networkidle', timeout: 20000 });
    await page.getByText('Welcome back').waitFor({ timeout: 10000 });
    res.steps.push('login renders ✓');

    // 2. Demo login (role picker → Continue) → shell mounts (URL + sidebar nav)
    await page.getByRole('button', { name: /Continue as/i }).click();
    await page.waitForURL(/\/(admin|management)\/dashboard/, { timeout: 15000 });
    await page.getByRole('link', { name: 'Students' }).first().waitFor({ timeout: 10000 }); // sidebar nav
    res.steps.push('demo login → shell + sidebar ✓');

    // 3. A data page renders (SIS registry)
    await page.goto(`${BASE}/sis/registry`, { waitUntil: 'networkidle', timeout: 20000 });
    await page.getByRole('heading', { name: 'Students' }).waitFor({ timeout: 10000 });
    res.steps.push('SIS registry renders ✓');

    // 4. A dashboard (charts lazy-load path)
    await page.goto(`${BASE}/admin/dashboard`, { waitUntil: 'networkidle', timeout: 20000 });
    await page.getByText(/School overview/i).first().waitFor({ timeout: 10000 });
    res.steps.push('dashboard renders ✓');

    // 5. Responsive: no horizontal overflow at each viewport (table page = overflow risk)
    await page.goto(`${BASE}/finance/collections`, { waitUntil: 'networkidle', timeout: 20000 });
    for (const [label, w, h] of VIEWPORTS) {
      await page.setViewportSize({ width: w, height: h });
      await page.waitForTimeout(250);
      const o = await checkOverflow(page);
      const bad = o.overflow > 4;
      res.overflow.push(`${label} ${w}×${h}: ${bad ? `❌ overflow ${o.overflow}px` : 'ok'}`);
      if (bad) res.ok = false;
    }
    await ctx.close();
  } catch (e) {
    res.ok = false;
    res.steps.push('ERROR: ' + (e.message || String(e)).split('\n')[0].slice(0, 160));
  } finally {
    if (browser) await browser.close();
  }
  if (res.consoleErrors.length) res.ok = false;
  return res;
}

const results = [];
for (const [name, type] of ENGINES) {
  process.stdout.write(`\n### ${name}\n`);
  const r = await runEngine(name, type);
  results.push(r);
  r.steps.forEach((s) => console.log('  ' + s));
  r.overflow.forEach((s) => console.log('  responsive ' + s));
  console.log('  console errors:', r.consoleErrors.length ? r.consoleErrors : 'none ✓');
  console.log('  =>', r.ok ? '✅ PASS' : '❌ ISSUES');
}
console.log('\n=== SUMMARY ===');
for (const r of results) console.log(`  ${r.name.padEnd(16)} ${r.ok ? '✅ PASS' : '❌ ' + (r.consoleErrors[0] || r.steps.find((s) => s.startsWith('ERROR')) || 'overflow')}`);
process.exit(results.every((r) => r.ok) ? 0 : 1);
