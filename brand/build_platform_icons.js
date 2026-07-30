#!/usr/bin/env node
/**
 * Writes the platform app icons for NIKSHA OS straight into the app trees.
 *
 *   node brand/build_platform_icons.js
 *
 * Everything derives from brand/niksha-os/svg/niksha-os-symbol.svg. Geometry
 * follows BRAND_GUIDELINES §4:
 *   - background   solid #0B1F4B, never a gradient (adaptive masks and launcher
 *                  parallax shift a gradient background oddly between launchers)
 *   - legacy icon  glyph at 68% of the canvas, optically centred
 *   - adaptive fg  glyph at 62% of a transparent canvas; the manifest already
 *                  applies a 16% inset, and the pair keeps the mark inside
 *                  Android's 66% safe circle on every mask shape
 *   - store icons  flattened, no alpha — both Play and the App Store reject it
 *
 * This exists because flutter_launcher_icons is configured `ios: false`, so the
 * iOS set was never generated and still held the stock Flutter template icon.
 */
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const MASTER = path.join(__dirname, 'niksha-os/svg/niksha-os-symbol.svg');
const CANVAS = '#0B1F4B';

// Same luminance lift the derivative build uses, so the mark holds contrast on
// the navy canvas. Kept in sync with brand/build_assets.js.
const DARK_LIFT_EXP = 1.45;
function liftHex(hexStr) {
  const r = parseInt(hexStr.slice(1, 3), 16) / 255;
  const g = parseInt(hexStr.slice(3, 5), 16) / 255;
  const b = parseInt(hexStr.slice(5, 7), 16) / 255;
  const max = Math.max(r, g, b), min = Math.min(r, g, b);
  const l = (max + min) / 2;
  const lNew = 1 - Math.pow(1 - l, DARK_LIFT_EXP);
  if (l <= 0 || l >= 1 || lNew <= l) return hexStr;
  let k = l < 0.5 ? lNew / l : (1 - lNew) / (1 - l);
  if (l < 0.5 && max > 0) k = Math.min(k, 1 / max);
  else if (l >= 0.5 && min < 1) k = Math.min(k, 1 / (1 - min));
  const map = (c) => {
    const v = l < 0.5 ? c * k : 1 - (1 - c) * k;
    return Math.max(0, Math.min(255, Math.round(v * 255))).toString(16).padStart(2, '0');
  };
  return `#${map(r)}${map(g)}${map(b)}`;
}

const ensure = (d) => fs.mkdirSync(d, { recursive: true });

/** Renders the glyph at `scale` of `size`, over `bg` ('transparent' or a hex). */
async function icon(svg, out, size, scale, bg) {
  const g = await sharp(Buffer.from(svg), { density: 1400 })
    .resize(Math.round(size * scale), Math.round(size * scale), {
      fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 },
    })
    .png().toBuffer();
  let pipe = sharp({
    create: {
      width: size, height: size, channels: 4,
      background: bg === 'transparent' ? { r: 0, g: 0, b: 0, alpha: 0 } : bg,
    },
  }).composite([{ input: g, gravity: 'center' }]);
  // flatten() composites onto the background but LEAVES the alpha channel in
  // place. App Store Connect rejects any icon that still carries one, so the
  // channel has to be dropped, not just made opaque.
  if (bg !== 'transparent') pipe = pipe.flatten({ background: bg }).removeAlpha();
  ensure(path.dirname(out));
  await pipe.png().toFile(out);
}

const ANDROID_LEGACY = { mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 };
const ANDROID_FG = { mdpi: 108, hdpi: 162, xhdpi: 216, xxhdpi: 324, xxxhdpi: 432 };
const IOS = {
  'Icon-App-20x20@1x.png': 20, 'Icon-App-20x20@2x.png': 40, 'Icon-App-20x20@3x.png': 60,
  'Icon-App-29x29@1x.png': 29, 'Icon-App-29x29@2x.png': 58, 'Icon-App-29x29@3x.png': 87,
  'Icon-App-40x40@1x.png': 40, 'Icon-App-40x40@2x.png': 80, 'Icon-App-40x40@3x.png': 120,
  'Icon-App-60x60@2x.png': 120, 'Icon-App-60x60@3x.png': 180,
  'Icon-App-76x76@1x.png': 76, 'Icon-App-76x76@2x.png': 152,
  'Icon-App-83.5x83.5@2x.png': 167,
  'Icon-App-1024x1024@1x.png': 1024,
};

(async () => {
  const master = fs.readFileSync(MASTER, 'utf8');
  const lifted = master.replace(/#[0-9A-Fa-f]{6}\b/g, (m) => liftHex(m.toLowerCase()));

  let n = 0;
  for (const [d, s] of Object.entries(ANDROID_LEGACY)) {
    await icon(lifted, path.join(ROOT, `android/app/src/main/res/mipmap-${d}/ic_launcher.png`), s, 0.68, CANVAS);
    n++;
  }
  for (const [d, s] of Object.entries(ANDROID_FG)) {
    await icon(lifted, path.join(ROOT, `android/app/src/main/res/drawable-${d}/ic_launcher_foreground.png`), s, 0.62, 'transparent');
    n++;
  }
  console.log(`android: ${n} icons written (legacy 68% on ${CANVAS}, adaptive fg 62% transparent)`);

  let m = 0;
  for (const [name, s] of Object.entries(IOS)) {
    await icon(lifted, path.join(ROOT, `ios/Runner/Assets.xcassets/AppIcon.appiconset/${name}`), s, 0.68, CANVAS);
    m++;
  }
  console.log(`ios: ${m} icons written, flattened on ${CANVAS} (no alpha)`);

  // Sources flutter_launcher_icons reads, so regenerating from pubspec produces
  // this same mark rather than reverting to the old Akshara artwork.
  await icon(lifted, path.join(ROOT, 'assets/branding/app_icon.png'), 1024, 0.68, CANVAS);
  await icon(lifted, path.join(ROOT, 'assets/branding/app_icon_foreground.png'), 1024, 0.62, 'transparent');
  console.log('assets/branding: app_icon.png + app_icon_foreground.png regenerated from the NIKSHA OS master');
})().catch((e) => { console.error(e); process.exit(1); });
