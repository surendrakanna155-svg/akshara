// Pixel-level visual-regression analysis over the captured baselines.
// For every route × viewport it decodes the Light and Dark PNGs and computes:
//   • meanLum / stdLum  → blank/near-uniform detection (a real page has texture)
//   • theme delta        → Dark must render darker than Light (theme actually applied)
//   • change fraction     → Light vs Dark must differ on a real fraction of pixels
//       (identical renders = theme regression / dead toggle)
// Emits a JSON + console summary. Pure JS (pngjs), no native deps.
import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';

const LIGHT = 'visual-baselines/light';
const DARK = 'visual-baselines/dark';
const STEP = 7; // sample every 7th pixel row/col — fast, statistically ample

function load(p) {
  return PNG.sync.read(fs.readFileSync(p));
}
function lumStats(png) {
  let n = 0, sum = 0, sum2 = 0;
  const { width, height, data } = png;
  for (let y = 0; y < height; y += STEP) {
    for (let x = 0; x < width; x += STEP) {
      const i = (y * width + x) * 4;
      const l = 0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2];
      sum += l; sum2 += l * l; n++;
    }
  }
  const mean = sum / n;
  const std = Math.sqrt(Math.max(0, sum2 / n - mean * mean));
  return { mean, std };
}
function changeFraction(a, b) {
  // fraction of co-sampled pixels whose luminance differs by >25 between the two themes
  const w = Math.min(a.width, b.width), h = Math.min(a.height, b.height);
  let n = 0, diff = 0;
  for (let y = 0; y < h; y += STEP) {
    for (let x = 0; x < w; x += STEP) {
      const ia = (y * a.width + x) * 4, ib = (y * b.width + x) * 4;
      const la = 0.299 * a.data[ia] + 0.587 * a.data[ia + 1] + 0.114 * a.data[ia + 2];
      const lb = 0.299 * b.data[ib] + 0.587 * b.data[ib + 1] + 0.114 * b.data[ib + 2];
      if (Math.abs(la - lb) > 25) diff++;
      n++;
    }
  }
  return diff / n;
}

const files = fs.readdirSync(LIGHT).filter((f) => f.endsWith('.png'));
const issues = [];
let analyzed = 0;
for (const f of files) {
  const lp = path.join(LIGHT, f), dp = path.join(DARK, f);
  if (!fs.existsSync(dp)) { issues.push(`missing-dark-baseline: ${f}`); continue; }
  let L, D;
  try { L = load(lp); D = load(dp); } catch (e) { issues.push(`decode-error: ${f} (${e.message})`); continue; }
  const ls = lumStats(L), ds = lumStats(D);
  const chg = changeFraction(L, D);
  analyzed++;
  // 1. blank / near-uniform (no content texture at all)
  if (ls.std < 3.5) issues.push(`blank-light(std=${ls.std.toFixed(1)}): ${f}`);
  if (ds.std < 3.5) issues.push(`blank-dark(std=${ds.std.toFixed(1)}): ${f}`);
  // 2. theme direction: Dark should be darker than Light overall
  if (ds.mean - ls.mean > 12) issues.push(`theme-inverted(L=${ls.mean.toFixed(0)},D=${ds.mean.toFixed(0)}): ${f}`);
  // 3. theme actually toggles: renders must differ on a real fraction of pixels
  if (chg < 0.03) issues.push(`theme-not-applied(chg=${(chg * 100).toFixed(1)}%): ${f}`);
}
console.log(`\n[visual-analyze] ${analyzed} route×viewport pairs analyzed, ${issues.length} anomalies`);
issues.slice(0, 60).forEach((i) => console.log('  ⚠ ' + i));
fs.writeFileSync('/tmp/cert-visual-analyze.json', JSON.stringify({ analyzed, issues }, null, 2));
