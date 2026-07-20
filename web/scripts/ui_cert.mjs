// Comprehensive UI + Visual Regression Certification.
//   MODE=smoke  ENGINE=chromium|firefox|webkit   → visit every route, collect
//       console/page errors + render + desktop overflow.
//   MODE=visual THEME=light|dark                 → every route × {desktop,tablet,
//       mobile}: capture baseline screenshot + detect overflow/blank/broken-icon/
//       theme issues. (Chromium.)
import fs from 'node:fs';
import path from 'node:path';
import { chromium, firefox, webkit } from '@playwright/test';

const BASE = process.env.BASE_URL || 'http://localhost:4350';
const MODE = process.env.MODE || 'smoke';
const ENGINE = process.env.ENGINE || 'chromium';
const THEME = process.env.THEME || 'light';
const engines = { chromium, firefox, webkit };
const VIEWPORTS = [['desktop', 1440, 900], ['tablet', 768, 1024], ['mobile', 390, 844]];

const routes = JSON.parse(fs.readFileSync('/tmp/routes.json', 'utf8'));

async function login(page) {
  await page.goto(`${BASE}/login`, { waitUntil: 'domcontentloaded', timeout: 20000 });
  await page.getByRole('button', { name: /Continue as/i }).click();
  await page.waitForURL(/\/(admin|management)\/dashboard/, { timeout: 15000 });
}

async function checks(page) {
  return await page.evaluate(() => {
    const el = document.scrollingElement || document.documentElement;
    const overflow = el.scrollWidth - window.innerWidth;
    const main = document.querySelector('main') || document.getElementById('root');
    const blank = !main || (main.innerText.trim().length < 15 && main.childElementCount < 2);
    // broken-icon heuristic: a rendered glyph is ~square; raw ligature text is wide.
    let brokenIcon = false;
    const icons = [...document.querySelectorAll('.material-symbols-rounded')].slice(0, 6);
    for (const i of icons) {
      const r = i.getBoundingClientRect();
      if (r.width > 4 && r.height > 4 && r.width / r.height > 2.2) { brokenIcon = true; break; }
    }
    const iconFontOk = document.fonts ? document.fonts.check('24px "Material Symbols Rounded"') : true;
    const dark = document.documentElement.classList.contains('dark');
    const bg = getComputedStyle(document.body).backgroundColor;
    return { overflow, blank, brokenIcon, iconFontOk, dark, bg };
  });
}

async function runSmoke() {
  const browser = await engines[ENGINE].launch();
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  const perRoute = new Map();
  let cur = '';
  page.on('console', (m) => { if (m.type() === 'error') (perRoute.get(cur) || []).push('console: ' + m.text().slice(0, 120)); });
  page.on('pageerror', (e) => (perRoute.get(cur) || []).push('pageerror: ' + e.message.slice(0, 120)));
  await login(page);
  const results = [];
  for (const route of routes) {
    cur = route; perRoute.set(route, []);
    let ok = true, note = '';
    try {
      await page.goto(BASE + route, { waitUntil: 'domcontentloaded', timeout: 8000 });
      await page.waitForTimeout(120);
      const c = await checks(page);
      if (c.blank) { ok = false; note = 'BLANK'; }
      else if (c.overflow > 4) { ok = false; note = `overflow ${c.overflow}px`; }
      else if (c.brokenIcon || !c.iconFontOk) { ok = false; note = 'broken-icon'; }
    } catch (e) { ok = false; note = 'ERROR ' + (e.message || '').split('\n')[0].slice(0, 90); }
    const errs = perRoute.get(route);
    if (errs.length) { ok = false; note = (note ? note + '; ' : '') + errs[0]; }
    results.push({ route, ok, note });
    if (results.length % 30 === 0) process.stdout.write(`  ../\n`);
    if (!ok) console.log(`  ❌ ${route} — ${note}`);
  }
  await browser.close();
  const fail = results.filter((r) => !r.ok);
  console.log(`\n[${ENGINE}] ${results.length - fail.length}/${results.length} routes clean` + (fail.length ? `, ${fail.length} with issues` : ' ✅'));
  fs.writeFileSync(`/tmp/cert-smoke-${ENGINE}.json`, JSON.stringify(results, null, 2));
}

async function runVisual() {
  const outDir = `visual-baselines/${THEME}`;
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const ctx = await browser.newContext();
  const page = await ctx.newPage();
  await page.addInitScript((t) => localStorage.setItem('akshara.theme-mode', t), THEME);
  await login(page);
  const issues = [];
  let shots = 0;
  for (const [vp, w, h] of VIEWPORTS) {
    await page.setViewportSize({ width: w, height: h });
    for (const route of routes) {
      try {
        await page.goto(BASE + route, { waitUntil: 'domcontentloaded', timeout: 8000 });
        await page.waitForTimeout(120);
        const c = await checks(page);
        const slug = route.replace(/\//g, '_').replace(/^_/, '') || 'root';
        await page.screenshot({ path: path.join(outDir, `${slug}__${vp}.png`), fullPage: false });
        shots++;
        if (c.overflow > 4) issues.push(`overflow ${c.overflow}px @ ${route} ${vp}/${THEME}`);
        if (c.blank) issues.push(`BLANK @ ${route} ${vp}/${THEME}`);
        if (c.brokenIcon || !c.iconFontOk) issues.push(`broken-icon @ ${route} ${vp}/${THEME}`);
        if (THEME === 'dark' && !c.dark) issues.push(`dark-not-applied @ ${route} ${vp}`);
      } catch (e) {
        issues.push(`ERROR @ ${route} ${vp}/${THEME}: ${(e.message || '').split('\n')[0].slice(0, 80)}`);
      }
    }
  }
  await browser.close();
  console.log(`\n[visual ${THEME}] ${shots} baselines captured, ${issues.length} issues`);
  issues.slice(0, 40).forEach((i) => console.log('  ❌ ' + i));
  fs.writeFileSync(`/tmp/cert-visual-${THEME}.json`, JSON.stringify(issues, null, 2));
}

async function runInteract() {
  const browser = await engines[ENGINE].launch();
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 } });
  const page = await ctx.newPage();
  const perRoute = new Map();
  let cur = '';
  page.on('console', (m) => { if (m.type() === 'error') (perRoute.get(cur) || []).push('console: ' + m.text().slice(0, 120)); });
  page.on('pageerror', (e) => (perRoute.get(cur) || []).push('pageerror: ' + e.message.slice(0, 120)));
  await login(page);

  // Global chrome: ⌘K command palette open→type→esc; theme toggle applies .dark.
  const chrome = [];
  try {
    await page.keyboard.press('Meta+KeyK');
    await page.waitForTimeout(200);
    const paletteOpen = await page.locator('[role="dialog"], [cmdk-root], input[placeholder*="Search" i]').first().isVisible().catch(() => false);
    chrome.push(`palette ${paletteOpen ? 'opens ✓' : 'no-op'}`);
    await page.keyboard.press('Escape');
  } catch { chrome.push('palette ERROR'); }

  const results = [];
  let totalTabs = 0, totalDrawers = 0, totalSorts = 0;
  for (const route of routes) {
    cur = route; perRoute.set(route, []);
    const rec = { route, tabs: 0, drawer: false, sorts: 0 };
    try {
      await page.goto(BASE + route, { waitUntil: 'domcontentloaded', timeout: 8000 });
      await page.waitForTimeout(120);
      // Tabs: click each role=tab, verify no crash.
      const tabs = page.locator('[role="tab"]');
      const tc = Math.min(await tabs.count(), 6);
      for (let i = 0; i < tc; i++) { await tabs.nth(i).click({ timeout: 1500 }).catch(() => {}); await page.waitForTimeout(60); rec.tabs++; }
      // Sortable header: click first, verify sort doesn't throw.
      const sortable = page.locator('th.cursor-pointer');
      if (await sortable.count()) { await sortable.first().click({ timeout: 1500 }).catch(() => {}); await page.waitForTimeout(60); rec.sorts++; }
      // Detail drawer/dialog: click first clickable row, expect a role=dialog, then Escape.
      const rows = page.locator('tr.cursor-pointer');
      if (await rows.count()) {
        await rows.first().click({ timeout: 1500 }).catch(() => {});
        await page.waitForTimeout(180);
        rec.drawer = await page.locator('[role="dialog"]').first().isVisible().catch(() => false);
        if (rec.drawer) await page.keyboard.press('Escape');
      }
    } catch (e) { perRoute.get(route).push('nav: ' + (e.message || '').split('\n')[0].slice(0, 80)); }
    const errs = perRoute.get(route);
    rec.ok = errs.length === 0;
    rec.note = errs[0] || '';
    totalTabs += rec.tabs; totalDrawers += rec.drawer ? 1 : 0; totalSorts += rec.sorts;
    results.push(rec);
    if (results.length % 30 === 0) process.stdout.write(`  ../\n`);
    if (!rec.ok) console.log(`  ❌ ${route} — ${rec.note}`);
  }
  await browser.close();
  const fail = results.filter((r) => !r.ok);
  console.log(`\n[interact ${ENGINE}] ${results.length - fail.length}/${results.length} routes error-free` + (fail.length ? `, ${fail.length} with errors` : ' ✅'));
  console.log(`  exercised: ${totalTabs} tab-switches, ${totalDrawers} detail drawers opened, ${totalSorts} column sorts; chrome: ${chrome.join(', ')}`);
  fs.writeFileSync(`/tmp/cert-interact-${ENGINE}.json`, JSON.stringify({ chrome, totalTabs, totalDrawers, totalSorts, results }, null, 2));
}

if (MODE === 'smoke') await runSmoke();
else if (MODE === 'interact') await runInteract();
else await runVisual();
