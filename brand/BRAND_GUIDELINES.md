# NIKSHA — brand system

> Master vector artwork for the three brands. Every mark here was **drawn as
> vector geometry**, not traced or upscaled from the reference image. No SVG in
> this package contains raster data, embedded images or stray anchor points.
>
> Masters live in `brand/<brand>/svg/`. Everything else — PNGs, icons, banners —
> is **generated** from those masters by `brand/build_assets.js`. Never hand-edit
> a generated file; fix the master and re-run the build.

---

## 1. The three brands

| Brand | Purpose | Palette | Mark |
|---|---|---|---|
| **NIKSHA Technologies Pvt. Ltd.** | Corporate identity | Blue → violet | N monogram dissolving into data squares |
| **NIKSHA OS** | School ERP platform | Blue → sky, green accent | N rising from an open book, summit flag |
| **NIKSY** | Personal AI assistant | Teal → green | N inside an open progress ring |

### What makes them a family

All three share **one skeleton**: the N monogram is built from the same three
straight prisms — left stem, descending diagonal, right stem — on a shared
baseline and cap height. Identical construction, different treatment. Put them
side by side and they are obviously siblings; see any one alone and it is
unambiguous which brand it is.

The differentiation is carried by **environment, not by redrawing the letter**:

- **Technologies** — the monogram *dissolves*. Engineering, infrastructure, the thing underneath.
- **OS** — the monogram *stands on a book* and plants a flag. Education, achievement.
- **NIKSY** — the monogram is *held inside an open ring*. Personal, in progress, human.

---

## 2. Colour

### NIKSHA Technologies
| Role | Hex |
|---|---|
| Primary | `#2563EB` |
| Mid | `#4F46E5` |
| Accent | `#8B5CF6` |
| Dissolve | `#A78BFA` |
| Canvas (dark) | `#0A0F2C` |

### NIKSHA OS
| Role | Hex |
|---|---|
| Deep | `#1E3A8A` |
| Primary | `#2563EB` |
| Light | `#38BDF8` |
| Growth accent | `#10B981` |
| **App canvas / icon background** | **`#0B1F4B`** |

### NIKSY
| Role | Hex |
|---|---|
| Deep | `#047857` |
| Primary | `#10B981` |
| Light | `#34D399` |
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
flag, dissolve squares, ring gap — collapses into mud.

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
- Use the raster reference image for anything. It is superseded by these masters.

---

## 7. Files

```
brand/
├── BRAND_GUIDELINES.md          ← this file
├── build_assets.js              ← generates every derivative from the masters
├── niksha-os/
│   ├── svg/  niksha-os-symbol.svg          ← MASTER
│   ├── png/  (generated)
│   └── icons/(generated)
├── niksha-technologies/
│   └── svg/  niksha-technologies-symbol.svg ← MASTER
└── niksy/
    └── svg/  niksy-symbol.svg               ← MASTER
```
