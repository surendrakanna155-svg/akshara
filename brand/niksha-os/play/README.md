# Play Store graphic assets — NIKSHA OS

## feature-graphic-1024x500.png

Google Play's required feature graphic. Exactly 1024×500, no alpha.

**Regenerate** (the PNG is a build output — edit the HTML, never the PNG):

```bash
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless=new --disable-gpu --hide-scrollbars \
  --force-device-scale-factor=1 --window-size=1024,500 \
  --screenshot=brand/niksha-os/play/feature-graphic-1024x500.png \
  "file://$PWD/brand/niksha-os/play/feature-graphic.src.html"
```

The source inlines `brand/niksha-os/svg/niksha-os-symbol-white.svg` as a base64
data URI, so the PNG contains no raster tracing of the mark — it is rendered from
the vector each time.

**Design decisions, and the brand rules behind them**
(`brand/BRAND_GUIDELINES.md` §2):

- The gradient runs **bottom-left → top-right**. Rule 1, and non-negotiable: a
  gradient running the other way reads as descent.
- Palette is NIKSHA OS only — `#0B1F4B` canvas through `#1E3A8A` / `#2563EB` to
  `#38BDF8`. No colour from the Technologies or NIKSY palettes appears.
- Green (`#10B981`) is the **accent rule under the wordmark only**, never a fill.
  Rule 2.
- The lockup is **horizontally centred**. Play crops this asset in several
  placements, and centred content survives the crop; a left-weighted lockup does
  not.
- White wordmark on the deep canvas measures well above the 4.5:1 the brand
  guidelines require (rule 4).

## App icon

`../icons/play-store-512.png` — 512×512, verified. Upload as-is.
