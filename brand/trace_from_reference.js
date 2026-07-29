/**
 * Traces the three NIKSHA symbol masters out of the approved reference board.
 *
 *   npm i sharp imagetracerjs      # tooling only, not repo dependencies
 *   node brand/trace_from_reference.js
 *
 * Reads  brand/_reference/niksha-brand-board.png
 * Writes brand/<brand>/svg/<brand>-symbol.svg
 *
 * Geometry comes from the board's pixels and every gradient stop is a measured
 * mean of the pixels beneath its region — nothing here picks a colour or a
 * coordinate. Re-run brand/build_assets.js and brand/build_platform_icons.js
 * afterwards to propagate.
 *
 * Three changes over stage 2, each aimed at a specific residual defect:
 *
 *   1. Banding.  A two-stop gradient can only describe a linear ramp, so any
 *      curved ramp got sliced into visible bands. Every region now gets a
 *      MULTI-STOP gradient: pixels are projected onto the region's colour axis,
 *      binned along it, and each bin's mean becomes a stop. Adjacent regions
 *      sample the same underlying image, so they now agree at their shared
 *      edge and the banding closes up.
 *
 *   2. Lost detail.  pathomit was culling the specular highlights and the
 *      smallest dissolve squares. Raised trace resolution and dropped the cull
 *      threshold so they survive.
 *
 *   3. Outline precision.  4x -> 6x upscale before tracing.
 *
 * Nothing here chooses a colour or a coordinate. Geometry comes from the source
 * pixels; every stop is a measured mean of the pixels beneath that region.
 */
const sharp = require('sharp');
const ImageTracer = require('imagetracerjs');
const fs = require('fs');

const path = require('path');
const ROOT = __dirname;
const F = path.join(ROOT, '_reference/niksha-brand-board.png');

const PANELS = [
  { key: 'nt', left: 20,   top: 60, width: 500, height: 400, bg: [10, 15, 44] },
  { key: 'os', left: 560,  top: 40, width: 440, height: 400, bg: [250, 250, 250] },
  { key: 'ny', left: 1040, top: 40, width: 470, height: 400, bg: [240, 248, 242] },
];

const UPSCALE = 6;
const BG_TOL = 78;
const GAP_ROWS = 6;
const SAMPLE_SCALE = 0.34;
const MIN_PTS_GRAD = 40;
const MAX_STOPS = 18;
const FLAT_SPREAD = 7;
const OUT_MASTER = {
  nt: 'niksha-technologies/svg/niksha-technologies-symbol.svg',
  os: 'niksha-os/svg/niksha-os-symbol.svg',
  ny: 'niksy/svg/niksy-symbol.svg',
};
const OUT_BOX = 512;
const MARGIN = 0.96;
const SEAM = 1.6;   // hairline-seam closer, in traced-canvas units

/**
 * NIKSHA OS only: the summit flag. The single sanctioned removal.
 * Expressed as a fraction of the traced canvas — the pole, its finial and the
 * pennant all sit in the top-right corner, clear of the nearest data square,
 * which is why a zone test is safe here. Verified by rendering with the zone
 * filled before it was used to delete anything.
 */
const FLAG_ZONE = { x0: 0.735, y0: 0.0, x1: 1.0, y1: 0.345 };

const dist = (d, i, bg) =>
  Math.abs(d[i] - bg[0]) + Math.abs(d[i + 1] - bg[1]) + Math.abs(d[i + 2] - bg[2]);

const hex = (v) => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0');
const rgbHex = (r, g, b) => `#${hex(r)}${hex(g)}${hex(b)}`;

function markBox(data, w, h, ch, bg) {
  const rowHas = [];
  for (let y = 0; y < h; y++) {
    let n = 0;
    for (let x = 0; x < w; x++) if (dist(data, (y * w + x) * ch, bg) > 60) n++;
    rowHas.push(n > 0);
  }
  const y0 = rowHas.indexOf(true);
  let y1 = y0, gap = 0;
  for (let y = y0; y < h; y++) {
    if (rowHas[y]) { y1 = y; gap = 0; } else if (++gap >= GAP_ROWS) break;
  }
  let x0 = w, x1 = -1;
  for (let y = y0; y <= y1; y++)
    for (let x = 0; x < w; x++)
      if (dist(data, (y * w + x) * ch, bg) > 60) { if (x < x0) x0 = x; if (x > x1) x1 = x; }
  return { x0, y0, x1, y1 };
}

function clearBackground(data, w, h, bg) {
  const seen = new Uint8Array(w * h), stack = [];
  const isBg = (p) => dist(data, p * 4, bg) < BG_TOL;
  for (let x = 0; x < w; x++) stack.push(x, (h - 1) * w + x);
  for (let y = 0; y < h; y++) stack.push(y * w, y * w + w - 1);
  while (stack.length) {
    const p = stack.pop();
    if (p < 0 || p >= w * h || seen[p] || !isBg(p)) continue;
    seen[p] = 1; data[p * 4 + 3] = 0;
    const x = p % w, y = (p - x) / w;
    if (x > 0) stack.push(p - 1);
    if (x < w - 1) stack.push(p + 1);
    if (y > 0) stack.push(p - w);
    if (y < h - 1) stack.push(p + w);
  }
}

function parsePaths(svg) {
  const out = [];
  const re = /<path\s+fill="rgb\((\d+),(\d+),(\d+)\)"[^>]*?\sd="([^"]+)"/g;
  let m;
  while ((m = re.exec(svg))) out.push({ r: +m[1], g: +m[2], b: +m[3], d: m[4] });
  return out;
}

/** Principal axis of colour variation, via a per-channel least-squares plane. */
function colourAxis(pts) {
  const n = pts.length;
  let sx = 0, sy = 0; for (const p of pts) { sx += p.x; sy += p.y; }
  const mx = sx / n, my = sy / n;
  let cxx = 0, cyy = 0, cxy = 0;
  const cm = { r: 0, g: 0, b: 0 };
  for (const p of pts) { cm.r += p.r; cm.g += p.g; cm.b += p.b; }
  cm.r /= n; cm.g /= n; cm.b /= n;
  const cc = { r: [0, 0], g: [0, 0], b: [0, 0] };
  for (const p of pts) {
    const dx = p.x - mx, dy = p.y - my;
    cxx += dx * dx; cyy += dy * dy; cxy += dx * dy;
    for (const ch of ['r', 'g', 'b']) {
      const dc = p[ch] - cm[ch];
      cc[ch][0] += dx * dc; cc[ch][1] += dy * dc;
    }
  }
  const det = cxx * cyy - cxy * cxy;
  if (Math.abs(det) < 1e-9) return null;
  let vx = 0, vy = 0;
  for (const ch of ['r', 'g', 'b']) {
    vx += (cc[ch][0] * cyy - cc[ch][1] * cxy) / det;
    vy += (cc[ch][1] * cxx - cc[ch][0] * cxy) / det;
  }
  const len = Math.hypot(vx, vy);
  if (len < 1e-9) return null;
  return { vx: vx / len, vy: vy / len, mx, my };
}

(async () => {
  const summary = {};
  for (const p of PANELS) {
    const probe = await sharp(F).extract({ left: p.left, top: p.top, width: p.width, height: p.height })
      .raw().toBuffer({ resolveWithObject: true });
    const box = markBox(probe.data, probe.info.width, probe.info.height, probe.info.channels, p.bg);
    const M = 3;
    const crop = {
      left: p.left + Math.max(0, box.x0 - M),
      top: p.top + Math.max(0, box.y0 - M),
      width: (box.x1 - box.x0 + 1) + M * 2,
      height: (box.y1 - box.y0 + 1) + M * 2,
    };
    const W = crop.width * UPSCALE, H = crop.height * UPSCALE;

    const buf = await sharp(F).extract(crop)
      .resize(W, H, { kernel: 'lanczos3' }).ensureAlpha().raw().toBuffer();
    clearBackground(buf, W, H, p.bg);
    // prepped source kept for pixel-overlay verification
    fs.mkdirSync(path.join(ROOT, '_reference/prepped'), { recursive: true });
    await sharp(buf, { raw: { width: W, height: H, channels: 4 } })
      .png().toFile(path.join(ROOT, `_reference/prepped/${p.key}.png`));

    const traced = ImageTracer.imagedataToSVG(
      { width: W, height: H, data: new Uint8ClampedArray(buf) },
      { ltres: 0.6, qtres: 0.6, pathomit: 5, rightangleenhance: false,
        colorsampling: 2, numberofcolors: 32, mincolorratio: 0, colorquantcycles: 10,
        blurradius: 1, blurdelta: 16, strokewidth: 0, linefilter: true,
        roundcoords: 2, viewbox: true, desc: false });

    const paths = parsePaths(traced);
    const sw = Math.max(1, Math.round(W * SAMPLE_SCALE)), sh = Math.max(1, Math.round(H * SAMPLE_SCALE));
    const defs = [], body = [];
    let grad = 0, flat = 0, dropped = 0, flagRemoved = 0;

    for (let i = 0; i < paths.length; i++) {
      const pa = paths[i];
      const one = `<svg xmlns="http://www.w3.org/2000/svg" width="${sw}" height="${sh}" viewBox="0 0 ${W} ${H}"><path fill="#fff" d="${pa.d}"/></svg>`;
      const mask = await sharp(Buffer.from(one)).extractChannel(0).raw().toBuffer();

      const pts = [];
      let covered = 0, total = 0;
      let bx0 = Infinity, by0 = Infinity, bx1 = -Infinity, by1 = -Infinity;
      for (let y = 0; y < sh; y++) {
        for (let x = 0; x < sw; x++) {
          if (mask[y * sw + x] < 128) continue;
          total++;
          if (x < bx0) bx0 = x; if (x > bx1) bx1 = x;
          if (y < by0) by0 = y; if (y > by1) by1 = y;
          const fx = Math.min(W - 1, Math.round(x / SAMPLE_SCALE));
          const fy = Math.min(H - 1, Math.round(y / SAMPLE_SCALE));
          const si = (fy * W + fx) * 4;
          if (buf[si + 3] < 128) continue;
          covered++;
          pts.push({ x: fx, y: fy, r: buf[si], g: buf[si + 1], b: buf[si + 2] });
        }
      }
      if (total === 0 || covered / total < 0.6 || pts.length < 6) { dropped++; continue; }

      // The one sanctioned edit: drop the NIKSHA OS summit flag.
      if (p.key === 'os') {
        const fx0 = bx0 / sw, fx1 = bx1 / sw, fy0 = by0 / sh, fy1 = by1 / sh;
        if (fx0 >= FLAG_ZONE.x0 && fx1 <= FLAG_ZONE.x1 && fy0 >= FLAG_ZONE.y0 && fy1 <= FLAG_ZONE.y1) {
          flagRemoved++; continue;
        }
      }

      const ax = pts.length >= MIN_PTS_GRAD ? colourAxis(pts) : null;
      if (ax) {
        let tmin = Infinity, tmax = -Infinity;
        for (const q of pts) {
          const t = q.x * ax.vx + q.y * ax.vy;
          if (t < tmin) tmin = t; if (t > tmax) tmax = t;
        }
        const span = tmax - tmin;
        if (span > 1e-6) {
          const nb = Math.max(3, Math.min(MAX_STOPS, Math.floor(pts.length / 25)));
          const acc = Array.from({ length: nb }, () => ({ r: 0, g: 0, b: 0, n: 0 }));
          for (const q of pts) {
            const t = (q.x * ax.vx + q.y * ax.vy - tmin) / span;
            const bi = Math.min(nb - 1, Math.max(0, Math.floor(t * nb)));
            acc[bi].r += q.r; acc[bi].g += q.g; acc[bi].b += q.b; acc[bi].n++;
          }
          const stops = [];
          for (let b = 0; b < nb; b++) {
            if (!acc[b].n) continue;
            stops.push({ o: (b + 0.5) / nb, r: acc[b].r / acc[b].n, g: acc[b].g / acc[b].n, b: acc[b].b / acc[b].n });
          }
          let spread = 0;
          for (const s of stops) for (const t2 of stops) {
            spread = Math.max(spread, Math.abs(s.r - t2.r), Math.abs(s.g - t2.g), Math.abs(s.b - t2.b));
          }
          if (stops.length >= 2 && spread > FLAT_SPREAD) {
            stops[0].o = 0; stops[stops.length - 1].o = 1;
            const id = `g${p.key}${i}`;
            const x1v = ax.mx + ax.vx * (tmin - (ax.mx * ax.vx + ax.my * ax.vy));
            const y1v = ax.my + ax.vy * (tmin - (ax.mx * ax.vx + ax.my * ax.vy));
            const x2v = ax.mx + ax.vx * (tmax - (ax.mx * ax.vx + ax.my * ax.vy));
            const y2v = ax.my + ax.vy * (tmax - (ax.mx * ax.vx + ax.my * ax.vy));
            defs.push(
              `<linearGradient id="${id}" gradientUnits="userSpaceOnUse" x1="${x1v.toFixed(1)}" y1="${y1v.toFixed(1)}" x2="${x2v.toFixed(1)}" y2="${y2v.toFixed(1)}">` +
              stops.map((s) => `<stop offset="${s.o.toFixed(3)}" stop-color="${rgbHex(s.r, s.g, s.b)}"/>`).join('') +
              `</linearGradient>`);
            // Stroke in the region's own paint. Adjacent traced regions share an
            // edge but antialias independently, which leaves a hairline of
            // background showing through as a crack across the ribbon. A
            // half-unit stroke closes the seam without altering the silhouette.
            body.push(`<path fill="url(#${id})" stroke="url(#${id})" stroke-width="${SEAM}" d="${pa.d}"/>`);
            grad++; continue;
          }
        }
      }
      let ar = 0, ag = 0, ab = 0;
      for (const q of pts) { ar += q.r; ag += q.g; ab += q.b; }
      {
        const c = rgbHex(ar / pts.length, ag / pts.length, ab / pts.length);
        body.push(`<path fill="${c}" stroke="${c}" stroke-width="${SEAM}" d="${pa.d}"/>`);
      }
      flat++;
    }

    // Normalise onto the 512 canvas the rest of the brand system uses.
    const s = (OUT_BOX * MARGIN) / Math.max(W, H);
    const tx = (OUT_BOX - W * s) / 2, ty = (OUT_BOX - H * s) / 2;
    const svg =
      `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${OUT_BOX} ${OUT_BOX}" width="${OUT_BOX}" height="${OUT_BOX}" role="img">\n` +
      `<defs>\n${defs.join('\n')}\n</defs>\n` +
      `<g transform="translate(${tx.toFixed(2)} ${ty.toFixed(2)}) scale(${s.toFixed(5)})">\n${body.join('\n')}\n</g>\n</svg>\n`;
    fs.writeFileSync(path.join(ROOT, OUT_MASTER[p.key]), svg);

    summary[p.key] = { src: `${crop.width}x${crop.height}`, traced: `${W}x${H}`, grad, flat, dropped, flagRemoved, kb: Math.round(svg.length / 1024) };
    console.log(`${p.key}: src ${crop.width}x${crop.height} @${UPSCALE}x -> ${grad} gradient + ${flat} flat paths, ${dropped} bg dropped, flag paths removed: ${flagRemoved}, ${Math.round(svg.length / 1024)} KB`);
  }
  fs.writeFileSync(path.join(ROOT, '_reference/trace-summary.json'), JSON.stringify(summary, null, 2));
})().catch((e) => { console.error(e); process.exit(1); });
