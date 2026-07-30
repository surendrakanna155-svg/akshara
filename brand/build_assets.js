#!/usr/bin/env node
/**
 * Generates every derivative brand asset from the three SVG masters.
 *
 *   node brand/build_assets.js
 *
 * Requires `sharp` (npm i sharp). Everything it writes is disposable — the
 * masters in each brand's svg/ folder are the only source of truth. If an asset
 * looks wrong, fix the master and re-run; never hand-edit an output.
 *
 * Deliberately NOT generated here:
 *   - Play Store feature graphic (needs marketing copy, not just the mark)
 *   - Brand guidelines PDF (BRAND_GUIDELINES.md is the source; export to PDF
 *     from any Markdown renderer)
 */
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;

const BRANDS = {
  'niksha-os': {
    master: 'niksha-os/svg/niksha-os-symbol.svg',
    canvas: '#0B1F4B',
    light: '#FFFFFF',
    primary: '#2563EB',
    wordmark: 'NIKSHA',
    suffix: 'OS',
    tagline: 'The AI Operating System for Schools',
  },
  'niksha-technologies': {
    master: 'niksha-technologies/svg/niksha-technologies-symbol.svg',
    canvas: '#0A0F2C',
    light: '#FFFFFF',
    primary: '#4F46E5',
    wordmark: 'NIKSHA',
    suffix: 'TECHNOLOGIES',
    tagline: 'Where Knowledge Meets Intelligence',
  },
  niksy: {
    master: 'niksy/svg/niksy-symbol.svg',
    canvas: '#04231A',
    light: '#F5FBF7',
    primary: '#10B981',
    wordmark: 'NIKS',
    suffix: 'Y',
    tagline: 'Your Personal AI for Life',
  },
};

/** Strips every fill/stroke to one flat colour — for mono/black/white variants. */
function monochrome(svg, colour) {
  return svg
    // Drop gradient defs entirely; a flat mark must not reference them.
    .replace(/<defs>[\s\S]*?<\/defs>/g, '')
    .replace(/fill="url\(#[^)]*\)"/g, `fill="${colour}"`)
    .replace(/stroke="url\(#[^)]*\)"/g, `stroke="${colour}"`)
    .replace(/fill="#[0-9A-Fa-f]{3,8}"/g, `fill="${colour}"`)
    .replace(/stroke="#[0-9A-Fa-f]{3,8}"/g, `stroke="${colour}"`)
    // Opacity steps carry meaning in the dissolve/ring; keep them.
    ;
}

/**
 * Lifts the mark's dark end so it holds contrast on the brand's own dark canvas.
 *
 * Why this exists: the masters are tuned for light backgrounds, where the deep
 * tones give the mark weight. Composited onto the navy icon canvas (#0B1F4B)
 * those same tones are nearly the background colour, so the dissolve squares and
 * ring gap disappeared at icon sizes — exactly where legibility matters most.
 * Icons and dark social surfaces therefore use this lifted variant.
 *
 * This used to be a lookup table of six hand-picked hexes. That worked only while
 * the masters were hand-authored from a fixed palette. The masters are now traced
 * from the reference artwork and carry several hundred sampled colours, none of
 * which are in that table — so the table silently did nothing. It is replaced
 * with a curve that lifts luminance while preserving hue and saturation, which
 * works for any palette:
 *
 *     L' = 1 - (1 - L)^EXP
 *
 * Monotonic, fixes both endpoints (black stays darkest, white stays white), and
 * brightens the low end hardest — which is precisely where the contrast was lost.
 */
const DARK_LIFT_EXP = 1.45;

function liftHex(hexStr) {
  const r = parseInt(hexStr.slice(1, 3), 16) / 255;
  const g = parseInt(hexStr.slice(3, 5), 16) / 255;
  const b = parseInt(hexStr.slice(5, 7), 16) / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const l = (max + min) / 2;
  const lNew = 1 - Math.pow(1 - l, DARK_LIFT_EXP);
  if (l <= 0 || l >= 1 || lNew <= l) return hexStr;

  // Scale the channels about the midpoint so hue and saturation are untouched.
  let k = l < 0.5 ? lNew / l : (1 - lNew) / (1 - l);

  // Cap the scale so no channel clips at 255. A clipped channel is not a
  // brighter colour — it is a different hue, which is how the NIKSY teal turned
  // mint on its first pass.
  if (l < 0.5 && max > 0) k = Math.min(k, 1 / max);
  else if (l >= 0.5 && min < 1) k = Math.min(k, 1 / (1 - min));

  const map = (c) => {
    const v = l < 0.5 ? c * k : 1 - (1 - c) * k;
    return Math.max(0, Math.min(255, Math.round(v * 255)))
      .toString(16).padStart(2, '0');
  };
  return `#${map(r)}${map(g)}${map(b)}`;
}

function onDark(svg) {
  return svg.replace(/#[0-9A-Fa-f]{6}\b/g, (m) => liftHex(m.toLowerCase()));
}

const ensure = (d) => fs.mkdirSync(d, { recursive: true });

async function render(svgBuf, out, w, h, bg) {
  const glyph = await sharp(svgBuf, { density: 1200 })
    .resize(Math.round(w * 0.72), Math.round(h * 0.72), {
      fit: 'contain',
      background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png()
    .toBuffer();
  const base =
    bg === 'transparent'
      ? { create: { width: w, height: h, channels: 4, background: { r: 0, g: 0, b: 0, alpha: 0 } } }
      : { create: { width: w, height: h, channels: 4, background: bg } };
  let pipe = sharp(base).composite([{ input: glyph, gravity: 'center' }]);
  // flatten() makes the pixels opaque but keeps the alpha channel. Play and the
  // App Store both reject icons that still carry one, so drop it outright.
  if (bg !== 'transparent') pipe = pipe.flatten({ background: bg }).removeAlpha();
  await pipe.png().toFile(out);
}

async function build(key, cfg) {
  const svg = fs.readFileSync(path.join(ROOT, cfg.master), 'utf8');
  const dir = path.join(ROOT, key);
  const png = path.join(dir, 'png');
  const icons = path.join(dir, 'icons');
  const svgDir = path.join(dir, 'svg');
  [png, icons, svgDir].forEach(ensure);

  // ── Colour variants as SVG (still vector) ────────────────────────────────
  const variants = {
    black: monochrome(svg, '#000000'),
    white: monochrome(svg, '#FFFFFF'),
    mono: monochrome(svg, cfg.primary),
  };
  variants['on-dark'] = onDark(svg);
  for (const [name, body] of Object.entries(variants)) {
    fs.writeFileSync(path.join(svgDir, `${key}-symbol-${name}.svg`), body);
  }

  const gradient = Buffer.from(svg);
  // Icons and dark surfaces use the lifted gradient — see onDark().
  const gradientOnDark = Buffer.from(onDark(svg));
  const whiteSvg = Buffer.from(variants.white);
  const blackSvg = Buffer.from(variants.black);

  // ── High-resolution PNGs, transparent + on-brand backgrounds ─────────────
  for (const size of [128, 256, 512, 1024, 2048]) {
    await render(gradient, path.join(png, `symbol-${size}-transparent.png`), size, size, 'transparent');
    await render(gradient, path.join(png, `symbol-${size}-light.png`), size, size, cfg.light);
      await render(gradientOnDark, path.join(png, `symbol-${size}-dark.png`), size, size, cfg.canvas);
  }
  await render(blackSvg, path.join(png, 'symbol-1024-black.png'), 1024, 1024, 'transparent');
  await render(whiteSvg, path.join(png, 'symbol-1024-white.png'), 1024, 1024, 'transparent');

  // ── Favicons ─────────────────────────────────────────────────────────────
  for (const size of [16, 32, 48, 64, 180, 192, 512]) {
    await render(gradient, path.join(icons, `favicon-${size}.png`), size, size, 'transparent');
  }

  // ── Platform app icons ───────────────────────────────────────────────────
  // Play & App Store both reject alpha, so these are flattened.
  await render(gradientOnDark, path.join(icons, 'play-store-512.png'), 512, 512, cfg.canvas);
  await render(gradientOnDark, path.join(icons, 'app-store-1024.png'), 1024, 1024, cfg.canvas);
  await render(gradientOnDark, path.join(icons, 'macos-1024.png'), 1024, 1024, cfg.canvas);
  await render(gradientOnDark, path.join(icons, 'windows-256.png'), 256, 256, cfg.canvas);
  // Android adaptive foreground stays transparent — the launcher supplies the bg.
  for (const [d, s] of Object.entries({ mdpi: 108, hdpi: 162, xhdpi: 216, xxhdpi: 324, xxxhdpi: 432 })) {
    await render(gradientOnDark, path.join(icons, `android-adaptive-fg-${d}-${s}.png`), s, s, 'transparent');
  }

  // ── Social / marketing surfaces ──────────────────────────────────────────
  const social = [
    ['linkedin-banner-1584x396.png', 1584, 396],
    ['youtube-banner-2560x1440.png', 2560, 1440],
    ['twitter-header-1500x500.png', 1500, 500],
    ['og-image-1200x630.png', 1200, 630],
    ['website-header-800x200.png', 800, 200],
    ['presentation-1920x1080.png', 1920, 1080],
    ['wallpaper-2560x1440.png', 2560, 1440],
    ['social-square-1080.png', 1080, 1080],
  ];
  for (const [name, w, h] of social) {
    const glyph = await sharp(whiteSvg, { density: 1200 })
      .resize(Math.round(Math.min(w, h) * 0.42), Math.round(Math.min(w, h) * 0.42), {
        fit: 'contain',
        background: { r: 0, g: 0, b: 0, alpha: 0 },
      })
      .png()
      .toBuffer();
    await sharp({ create: { width: w, height: h, channels: 4, background: cfg.canvas } })
      .composite([{ input: glyph, gravity: 'center' }])
      .flatten({ background: cfg.canvas })
      .png()
      .toFile(path.join(png, name));
  }

  // ── Print / business-card / letterhead: vector, not raster ───────────────
  // These must stay SVG — a business card printed from a PNG is an amateur tell.
  fs.writeFileSync(path.join(svgDir, `${key}-print-cmyk-safe.svg`), variants.black);

  console.log(`${key}: assets written`);
}

(async () => {
  for (const [key, cfg] of Object.entries(BRANDS)) await build(key, cfg);
  console.log('\nAll brand assets generated from the SVG masters.');
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
