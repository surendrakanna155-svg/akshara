# NIKSHA — brand system

> **The source of truth is `brand/_reference/niksha-brand-board.png`** — the
> approved brand artwork, held in this repository. See
> `_reference/README.md` for its checksum and the rules that govern it.
>
> Every mark is **vectorised from that board** by `brand/trace_from_reference.js`
> — outlines traced from its pixels, every gradient stop a measured mean of the
> pixels beneath its region. No shape or hex value was chosen by hand, and the
> trace is reproducible: re-running it yields byte-identical masters. No SVG here
> contains raster data or embedded images.
>
> Masters live in `brand/<brand>/svg/`. Everything else — PNGs, icons, banners —
> is **generated** from those masters by `brand/build_assets.js`, and the Android
> and iOS app icons by `brand/build_platform_icons.js`. Never hand-edit a
> generated file, and never hand-edit a master: fix the board and re-trace.
>
> ```bash
> npm i sharp imagetracerjs          # tooling only, not repo dependencies
> node brand/trace_from_reference.js # board  -> masters
> node brand/build_assets.js         # master -> every derivative
> node brand/build_platform_icons.js # master -> Android + iOS app icons
> ```
>
> **History.** An earlier revision of this package was drawn by hand rather than
> traced, and drifted materially from the reference — different letterform
> construction, different palette. It was replaced wholesale. Do not reintroduce
> hand-authored geometry: the reference board is the single source of truth.

---

## 1. The three brands

| Brand | Purpose | Palette | Mark |
|---|---|---|---|
| **NIKSHA Technologies Pvt. Ltd.** | Corporate identity | Blue → violet | N monogram dissolving into data squares |
| **NIKSHA OS** | School ERP platform | Blue → sky, green accent | N rising from an open book, ascending data squares |
| **NIKSY** | Personal AI assistant | Teal → green | N inside an open progress ring |

### What makes them a family

All three carry an **N monogram of the same family** — left stem, descending
diagonal, right stem — so they read as siblings, while each remains unmistakably
its own brand.

They are **not the same letterform**, and this is deliberate. In the reference,
Technologies and NIKSY are drawn as ribbon monograms with rounded stems and
curled terminals, while the OS monogram is angular and interlocks with the book
that frames it. Harmonising them was considered and rejected by the brand owner:
making the three identical would have required redrawing the OS mark, which must
match the reference exactly apart from the removed flag.

The differentiation is carried by **environment, not by redrawing the letter**:

- **Technologies** — the monogram *dissolves*. Engineering, infrastructure, the thing underneath.
- **OS** — the monogram *rises from an open book*, data lifting off the page. Education, achievement.
- **NIKSY** — the monogram is *held inside an open ring*. Personal, in progress, human.

---

## 2. Colour

### NIKSHA Technologies
| Role | Hex |
|---|---|
| Blue stem | `#046AF9` |
| Mid blue | `#044AE7` |
| Deep blue | `#0038C7` |
| Violet stem | `#672BF4` |
| Dissolve violet | `#A78BFA` |
| Canvas (dark) | `#0A0F2C` |

### NIKSHA OS
| Role | Hex |
|---|---|
| Deep | `#022997` |
| Primary | `#0234B8` |
| Mid | `#013AC8` |
| Light | `#0496F3` |
| Growth accent | `#0AA565` |
| **App canvas / icon background** | **`#0B1F4B`** |

### NIKSY
| Role | Hex |
|---|---|
| Deep | `#047956` |
| Mid | `#029777` |
| Primary | `#02A78A` |
| Light | `#02B695` |
| Canvas (light) | `#F5FBF7` |

### Rules
1. **The gradient runs bottom-left → top-right.** Always. A gradient that runs the other way reads as descent.
2. **Green is an accent, never a fill.** In the OS mark it appears only on the book's leading edge.
3. **Never recolour a mark outside these palettes.** Use the monochrome variants instead.
4. Verify contrast on every background: body text and the mark must clear **4.5:1**.

---

## 3. Clear space and minimum size

**Clear space** = the height of the monogram's stem width (`S`) on all four
sides. Nothing — text, rule, image edge, another logo — enters that band.

```
        ← S →
   ┌─────────────────┐
 S │      MARK       │ S
   └─────────────────┘
        ← S →
```

**Minimum sizes** — below these the mark stops being legible and the symbol-only
version must be used:

| Use | Minimum |
|---|---|
| Symbol only | 16 px / 6 mm |
| Horizontal lockup | 120 px / 32 mm |
| Vertical lockup | 96 px / 25 mm |
| Favicon | 16 px (symbol only, monochrome) |
| App icon | 48 px (mdpi) |

**Below 24 px use the monochrome symbol.** Gradients band and the fine detail —
dissolve squares, ring gap, chart bars — collapses into mud.

---

## 4. App icon construction (NIKSHA OS)

- **Background:** solid `#0B1F4B`. Not a gradient — Android's adaptive-icon masks and parallax make gradient backgrounds shift oddly between launchers.
- **Legacy icon:** glyph at **68%** of the canvas, optically centred.
- **Adaptive foreground:** glyph at **62%** of a transparent canvas. The manifest already applies a 16% inset, and the combination keeps the mark inside Android's 66% safe circle on every mask shape (circle, squircle, rounded square, teardrop).
- **Play Store icon:** 512×512, **flattened — no alpha channel.** Play rejects icons with transparency.

---

## 5. Typography

| Role | Typeface | Weight | Notes |
|---|---|---|---|
| Wordmark | **Inter** | 700, tracking +0.14em | The wide tracking is what makes "N I K S H A" read as a mark rather than a word |
| Product sub-label ("OS") | Inter | 600 | Set in the brand primary, never in the wordmark's colour |
| Headings | Inter | 600 | |
| Body | Inter | 400 | |
| Numerals | Inter, **tabular figures** | 400–700 | Mandatory anywhere numbers change or align in a column — money, marks, attendance |

Inter is open-source (SIL OFL), so it is safe for app, web, print and video
without licensing exposure. If Inter is unavailable, fall back to the platform
UI font (SF Pro / Roboto) — never to a display serif.

---

## 6. Applying the brand

**Do**
- Use the symbol alone where the brand is already established (app icon, favicon, avatar).
- Use the horizontal lockup in website headers and email signatures.
- Use monochrome on photography, single-colour print, and any busy background.
- Keep the gradient direction consistent across every asset in a layout.

**Don't**
- Stretch, skew, rotate or re-space the mark.
- Add drop shadows, outlines, bevels or glows.
- Place the gradient mark on a mid-tone background where it loses contrast.
- Recreate the wordmark by typing it — use the vector master, whose tracking is fixed.
- Ship the raster reference board itself. It is the source these masters were
  traced from and the authority for any future revision, but it is not an asset —
  always ship the vector master or a PNG generated from it.

---

## 7. Files

```
brand/
├── _reference/
│   ├── niksha-brand-board.png   ← SOURCE OF TRUTH (approved artwork)
│   └── README.md                ← provenance, checksum, re-trace procedure
├── BRAND_GUIDELINES.md          ← this file
├── trace_from_reference.js      ← board → the three masters
├── build_assets.js              ← masters → every derivative
├── build_platform_icons.js      ← master → Android + iOS app icons
├── niksha-os/
│   ├── svg/  niksha-os-symbol.svg          ← MASTER (generated by the trace)
│   ├── png/  (generated)
│   ├── icons/(generated)
│   └── play/ (feature graphic; re-render per play/README.md after a re-trace)
├── niksha-technologies/
│   └── svg/  niksha-technologies-symbol.svg ← MASTER (generated by the trace)
└── niksy/
    └── svg/  niksy-symbol.svg               ← MASTER (generated by the trace)
```
