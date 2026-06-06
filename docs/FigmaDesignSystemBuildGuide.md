# Akshara ERP — Figma Design System Build Guide

**Document ID:** `AKS-FIGMA-BUILD-v1.0`  
**Purpose:** Step-by-step instructions to build the Akshara master Figma library  
**Sources:** `DesignSystem.md` · `MobileScreenInventory.md` · all module specifications  
**Target file:** `📁 Akshara — Master Design System` (publish as Figma library)

---

## Table of Contents

1. [Before You Start](#1-before-you-start)
2. [Build Order Overview](#2-build-order-overview)
3. [Step 1 — Color Variables](#3-step-1--color-variables)
4. [Step 2 — Typography Styles](#4-step-2--typography-styles)
5. [Step 3 — Effect Styles](#5-step-3--effect-styles)
6. [Step 4 — Grid System](#6-step-4--grid-system)
7. [Step 5 — Spacing Tokens](#7-step-5--spacing-tokens)
8. [Step 6 — Icons](#8-step-6--icons)
9. [Step 7 — Buttons](#9-step-7--buttons)
10. [Step 8 — Inputs](#10-step-8--inputs)
11. [Step 9 — Dropdowns](#11-step-9--dropdowns)
12. [Step 10 — Tables](#12-step-10--tables)
13. [Step 11 — KPI Cards](#13-step-11--kpi-cards)
14. [Step 12 — Chart Cards](#14-step-12--chart-cards)
15. [Step 13 — Navigation Rail](#15-step-13--navigation-rail)
16. [Step 14 — App Bar](#16-step-14--app-bar)
17. [Step 15 — Dialogs](#17-step-15--dialogs)
18. [Step 16 — Bottom Sheets](#18-step-16--bottom-sheets)
19. [Step 17 — Mobile Navigation](#19-step-17--mobile-navigation)
20. [Step 18 — Empty States](#20-step-18--empty-states)
21. [Step 19 — Error States](#21-step-19--error-states)
22. [Step 20 — Loading States](#22-step-20--loading-states)
23. [Step 21 — Publish & Link Modules](#23-step-21--publish--link-modules)
24. [QA Checklist](#24-qa-checklist)

---

## 1. Before You Start

### Figma file setup

| Setting | Value |
|---------|-------|
| File name | `Akshara — Master Design System` |
| Layout grid base | **8pt** |
| Nudge | 8px (Shift = 1px fine) |
| Constraints default | Top-left for fixed; Left+Right for fill |

### Naming convention

```
Category/Component/Variant/State
```

Examples: `Actions/Button/Filled/Default` · `Data/KPI/Standard/Success`

### Component property types

| Figma property | Use |
|----------------|-----|
| **Variant** | Type, Size, State, Accent |
| **Boolean** | FullWidth, HasIcon, Dismissible, Selectable |
| **Text** | Label, Value, Placeholder |
| **Instance swap** | Leading icon, Trailing icon, Avatar |

---

## 2. Build Order Overview

```
Foundations (Steps 1–5)
    ↓
Icons (Step 6)
    ↓
Actions + Inputs (Steps 7–9)
    ↓
Data display (Steps 10–12)
    ↓
Navigation + Shells (Steps 13–14, 17)
    ↓
Overlays (Steps 15–16)
    ↓
Feedback (Steps 18–20)
    ↓
Publish (Step 21)
```

**Estimated build time:** 3–5 days for foundations + core components · 2 days for states + responsive variants.

---

## 3. Step 1 — Color Variables

### 3.1 Create variable collections

Create **two modes** in collection `Theme`:

| Mode | Purpose |
|------|---------|
| `Light` | Default (ship first) |
| `Dark` | Placeholder aliases (P2) |

Create collection `Primitive` (no modes) for raw hex values.

### 3.2 Primitive variables (collection: Primitive)

| Variable name | Type | Value |
|---------------|------|-------|
| `primitive/blue/800` | Color | `#1565C0` |
| `primitive/blue/50` | Color | `#E3F2FD` |
| `primitive/blue/900` | Color | `#0D47A1` |
| `primitive/neutral/0` | Color | `#FFFFFF` |
| `primitive/neutral/50` | Color | `#F8FAFC` |
| `primitive/neutral/200` | Color | `#E2E8F0` |
| `primitive/neutral/500` | Color | `#64748B` |
| `primitive/neutral/900` | Color | `#1E293B` |
| `primitive/red/500` | Color | `#D32F2F` |
| `primitive/red/50` | Color | `#FFEBEE` |
| `primitive/green/600` | Color | `#2E7D32` |
| `primitive/green/50` | Color | `#E8F5E9` |
| `primitive/amber/600` | Color | `#F57C00` |
| `primitive/amber/50` | Color | `#FFF3E0` |
| `primitive/chart/1` | Color | `#1565C0` |
| `primitive/chart/2` | Color | `#42A5F5` |
| `primitive/chart/3` | Color | `#7E57C2` |
| `primitive/chart/4` | Color | `#26A69A` |
| `primitive/chart/grid` | Color | `#E2E8F0` |

### 3.3 Semantic variables (collection: Theme → Light mode)

| Variable | Alias to |
|----------|----------|
| `color/primary` | `primitive/blue/800` |
| `color/on-primary` | `primitive/neutral/0` |
| `color/primary-container` | `primitive/blue/50` |
| `color/on-primary-container` | `primitive/blue/900` |
| `color/surface` | `primitive/neutral/0` |
| `color/surface-container-low` | `primitive/neutral/50` |
| `color/surface-container-highest` | `#E8EDF3` (add primitive) |
| `color/on-surface` | `primitive/neutral/900` |
| `color/on-surface-variant` | `primitive/neutral/500` |
| `color/outline-variant` | `primitive/neutral/200` |
| `color/error` | `primitive/red/500` |
| `color/error-container` | `primitive/red/50` |
| `color/success` | `primitive/green/600` |
| `color/success-container` | `primitive/green/50` |
| `color/warning` | `primitive/amber/600` |
| `color/warning-container` | `primitive/amber/50` |
| `color/scrim` | `#1E293B` @ 40% opacity |

### 3.4 White-label override (per school)

Create variable mode `School/Custom` on `color/primary` and `color/primary-container` only — document in module frames, not in library defaults.

### 3.5 Figma action

1. Local variables → Create collections  
2. Bind all component fills to **semantic** tokens, never raw hex  
3. Enable **extended collections** for module files to consume library variables

---

## 4. Step 2 — Typography Styles

### 4.1 Install fonts

Roboto · Roboto Mono · Noto Sans Telugu · Noto Sans Devanagari · Noto Sans Tamil · Noto Sans Kannada · Noto Sans Malayalam · Noto Nastaliq Urdu

### 4.2 Create text styles (prefix: `type/`)

| Style name | Font | Size | Line | Weight | Letter |
|------------|------|------|------|--------|--------|
| `type/headline/medium` | Roboto | 28 | 36 | Regular 400 | 0 |
| `type/headline/small` | Roboto | 24 | 32 | Regular 400 | 0 |
| `type/title/large` | Roboto | 22 | 28 | Medium 500 | 0 |
| `type/title/medium` | Roboto | 16 | 24 | Medium 500 | 0 |
| `type/title/small` | Roboto | 14 | 20 | Medium 500 | 0 |
| `type/body/large` | Roboto | 16 | 24 | Regular 400 | 0 |
| `type/body/medium` | Roboto | 14 | 20 | Regular 400 | 0 |
| `type/body/small` | Roboto | 12 | 16 | Regular 400 | 0.1 |
| `type/label/large` | Roboto | 14 | 20 | Medium 500 | 0.1 |
| `type/label/medium` | Roboto | 12 | 16 | Medium 500 | 0.2 |
| `type/label/small` | Roboto | 11 | 16 | Medium 500 | 0.3 |
| `type/mono/body` | Roboto Mono | 14 | 20 | Regular 400 | 0 |

**Default text color:** bind to `color/on-surface` · secondary bind to `color/on-surface-variant`

### 4.3 Regional sample frame

Create frame `Foundations/Typography/Regional` with one line per script using matching Noto family — for QA only.

### 4.4 Figma action

Text styles panel → create all styles → never use detached font sizes in components.

---

## 5. Step 3 — Effect Styles

### 5.1 Shadow effect styles

| Style name | X | Y | Blur | Spread | Color |
|------------|---|---|------|--------|-------|
| `elevation/0` | — | — | — | — | none |
| `elevation/1` | 0 | 1 | 3 | 0 | `#1E293B` 8% |
| `elevation/2` | 0 | 2 | 6 | 0 | `#1E293B` 10% |
| `elevation/3` | 0 | 4 | 12 | 0 | `#1E293B` 12% |
| `elevation/4` | 0 | 8 | 24 | 0 | `#1E293B` 14% |

### 5.2 Focus ring (component-level, not style)

2px stroke `color/primary` · offset 2px · use on Focused variants only.

### 5.3 Figma action

Effects panel → save as styles → apply `elevation/1` to KPI/Chart cards · `elevation/3` to Dialogs · `elevation/4` to Bottom sheets.

---

## 6. Step 4 — Grid System

### 6.1 Layout grid presets (save as styles)

| Grid name | Frame | Columns | Type | Margin | Gutter | Width |
|-----------|-------|---------|------|--------|--------|-------|
| `grid/mobile-4` | 390 | 4 | Stretch | 16 | 16 | 78.5 |
| `grid/tablet-8` | 834 | 8 | Stretch | 24 | 24 | 84.75 |
| `grid/desktop-12` | 1440 | 12 | Stretch | 24 | 24 | 104 |
| `grid/content-1136` | 1136 | 12 | Stretch | 0 | 24 | 81.33 |

### 6.2 Column span reference (desktop 1136)

| Spans | Width |
|-------|-------|
| 3 col | 272 |
| 4 col | 368 |
| 6 col | 560 |
| 8 col | 752 |
| 12 col | 1136 |

### 6.3 Safe area guides (mobile)

Create fixed overlay component `Guides/SafeArea/Mobile`:

| Guide | Inset |
|-------|-------|
| Top | 59px |
| Bottom | 34px |
| Side | 16px |

### 6.4 Figma action

1. Create page `Foundations/Grid`  
2. Place frames at each breakpoint with grid style applied  
3. Document span examples as locked reference components

---

## 7. Step 5 — Spacing Tokens

### 7.1 Number variables (collection: Spacing)

| Token | Value |
|-------|-------|
| `space/1` | 4 |
| `space/2` | 8 |
| `space/3` | 12 |
| `space/4` | 16 |
| `space/5` | 20 |
| `space/6` | 24 |
| `space/8` | 32 |
| `space/12` | 48 |

### 7.2 Usage rules (apply via auto-layout gap/padding)

| Context | Token |
|---------|-------|
| Section padding | `space/6` (24) |
| Card internal padding | `space/5` (20) desktop · `space/4` (16) mobile |
| Card grid gap | `space/4` (16) |
| Form field vertical gap | `space/6` (24) |
| Table cell pad | `space/3` H · `space/4` V |
| Icon-text gap | `space/2` (8) |
| Nav item gap | `space/1` (4) |

### 7.3 Spacing swatch frame

Visual row of 4–48px blocks — for designer reference on `Foundations/Spacing`.

---

## 8. Step 6 — Icons

### 6.1 Icon component

**Component:** `Foundation/Icon`

#### Layer structure

```
Icon [component]
└── Vector/Glyph [24×24]
```

#### Variants

| Property | Values |
|----------|--------|
| `Size` | 16 · 20 · 24 · 28 · 40 · 80 |
| `Style` | Outlined · Filled |

#### Properties

| Property | Type | Default |
|----------|------|---------|
| `Glyph` | Instance swap | `dashboard` |
| `Color` | Variable bind | `color/on-surface-variant` |

#### Constraints

Glyph: Center · Center · Fixed size per variant

#### Build steps

1. Install [Material Symbols Rounded](https://fonts.google.com/icons) as SVG or plugin  
2. Create master components at 24px  
3. Scale wrapper for each Size variant  
4. **Filled** style only for active nav items

### 6.2 Status icon colors (never color-only — pair with text)

| Status | Icon color variable |
|--------|-------------------|
| Success | `color/success` |
| Error | `color/error` |
| Warning | `color/warning` |
| Info | `color/primary` |

---

## 9. Step 7 — Buttons

### 9.1 Component: `Actions/Button`

#### Layer structure

```
Button [autolayout H, center, gap 8]
├── Leading/Icon [optional, 20×20]
├── Label [type/label/large]
└── Trailing/Icon [optional, 20×20]
```

#### Auto-layout settings

| Property | Filled/Tonal | Outlined/Text |
|----------|--------------|---------------|
| Direction | Horizontal | Horizontal |
| Alignment | Center | Center |
| Padding | 16 H · 14 V (48h) | 12 H · 10 V (40h) |
| Gap | 8 | 8 |
| Hug contents | Yes (unless FullWidth) | Yes |

#### Variants

| Property | Values |
|----------|--------|
| `Type` | Filled · Tonal · Outlined · Text |
| `Size` | Large (48) · Medium (40) |
| `State` | Default · Hovered · Pressed · Focused · Disabled · Loading |
| `FullWidth` | True · False |

#### Fill & stroke by Type

| Type | Fill | Text | Border |
|------|------|------|--------|
| Filled | `color/primary` | `color/on-primary` | — |
| Tonal | `color/primary-container` | `color/on-primary-container` | — |
| Outlined | `color/surface` | `color/primary` | 1px `color/outline-variant` |
| Text | transparent | `color/primary` | — |
| Disabled | 38% opacity on fill | `color/on-surface` 38% | — |

#### Loading state layer

Replace Label with `Progress/Circular` 20×20 centered · disable Leading/Trailing

#### Constraints

- FullWidth=False: Hug contents  
- FullWidth=True: Fill container width · max 400 desktop

#### Responsive behavior

| Breakpoint | Rule |
|------------|------|
| Mobile | Primary CTAs use FullWidth=True in forms |
| Desktop | FullWidth=False in dialogs/toolbars |

### 9.2 Component: `Actions/IconButton`

```
IconButton [48×48 hit area, 40×40 visual]
└── Icon [24, centered]
```

Variants: `State` × `Emphasis` (Default · Filled tonal)

### 9.3 Component: `Actions/FAB`

```
FAB [56×56, radius 16, elevation/3]
└── Icon [24, on-primary]
```

Position: bottom-right mobile · 24px from safe area

---

## 10. Step 8 — Inputs

### 10.1 Component: `Inputs/TextField`

#### Layer structure

```
TextField [V, gap 4, fill width]
├── Label [type/body/small, on-surface-variant]
├── FieldContainer [H, 56h, pad 16, radius 4 top — M3 outlined]
│   ├── Leading/Icon [optional]
│   ├── InputText [type/body/large, fill]
│   └── Trailing/Icon [optional]
├── HelperText [type/body/small]
└── ErrorText [type/body/small, error — visible on Error state]
```

#### Auto-layout

| Node | Settings |
|------|----------|
| TextField root | Vertical · Gap 4 · Fill width |
| FieldContainer | Horizontal · Align center · Pad 0 16 · Min H 56 · Fill width |
| InputText | Fill width · Hug height |

#### Variants

| Property | Values |
|----------|--------|
| `Size` | Standard (56) · Compact (40) |
| `State` | Default · Focused · Error · Disabled · ReadOnly |
| `HasLabel` | True · False |
| `HasHelper` | True · False |

#### Stroke by state

| State | Border |
|-------|--------|
| Default | 1px `color/outline-variant` |
| Focused | 2px `color/primary` |
| Error | 2px `color/error` |
| Disabled | 1px outline @ 38% |

#### Constraints

FieldContainer: Left + Right · Fill width  
Label/Helper: Left · Fill width

#### Responsive

Mobile: always Fill width · Compact size in filter bars only

### 10.2 Component: `Inputs/TextArea`

Min height 96 · character count row `type/body/small` right-aligned · same states as TextField

### 10.3 Component: `Inputs/Checkbox`

```
CheckboxRow [H, gap 12, min H 48]
├── Box [18×18, radius 2]
└── Label [type/body/large]
```

Variants: `Checked` · `Indeterminate` · `Disabled`

---

## 11. Step 9 — Dropdowns

### 11.1 Component: `Inputs/Dropdown`

#### Layer structure (closed)

```
Dropdown [V, gap 4]
├── Label
├── Trigger [H, 56h, same as TextField]
│   ├── Value [type/body/large]
│   ├── Spacer
│   └── Icon/expand_more [24]
└── HelperText
```

#### Layer structure (menu — separate component)

```
DropdownMenu [V, pad 8, max H 304, elevation/2, radius 8]
└── MenuItem [×n, H, 48h, pad 12 16]
    ├── Icon [optional]
    ├── Label [type/body/large]
    └── Check [if selected]
```

#### Variants

| Property | Values |
|----------|--------|
| `State` | Default · Open · Disabled · Error |
| `Size` | Standard · Compact |

#### Properties

| Property | Type |
|----------|------|
| `Value` | Text |
| `Placeholder` | Text |

#### Constraints

Trigger: Fill width · Menu: min width = trigger width · max 304px height scroll

#### Responsive

Mobile: use `Overlays/BottomSheet/Select` instead of popover menu (see Step 16)

### 11.2 Component: `Inputs/DatePickerTrigger`

Same as Dropdown trigger · trailing `calendar_today` · popover frame 328×360 (calendar grid placeholder)

---

## 12. Step 10 — Tables

### 12.1 Component: `Data/Table`

#### Layer structure

```
Table [V, gap 0, clip content, radius 12, stroke 1 outline-variant]
├── HeaderRow [H, 48h, fill surface-container-highest]
│   └── HeaderCell [×n, pad 12 16, type/label/small]
├── Body [V]
│   └── DataRow [×n, H, 52 or 64h, stroke bottom outline-variant]
│       ├── CheckboxCell [48w, optional]
│       └── DataCell [×n, pad 12 16, type/body/large]
└── Pagination [H, 56h, space-between, pad 8 16]
    ├── Range label
    └── Page controls
```

#### Auto-layout

| Node | Settings |
|------|----------|
| Table | Vertical · Gap 0 |
| HeaderRow / DataRow | Horizontal · Align center · Fill width |
| HeaderCell / DataCell | Hug width per column spec OR Fill for flex columns |

#### Variants

| Property | Values |
|----------|--------|
| `Density` | Compact (52) · Comfortable (64) |
| `Selectable` | True · False |
| `RowState` | Default · Hover · Selected · Disabled |

#### Properties

| Property | Type |
|----------|------|
| `Columns` | Number (use slot components) |
| `ShowPagination` | Boolean |

#### Constraints

Table: Fill width of parent (1136 desktop)  
Fixed-width columns: use min-width on cells (e.g. Actions 96, Checkbox 48)  
Flex columns: Title/Name columns Fill

#### Responsive behavior

| Breakpoint | Behavior |
|------------|----------|
| Desktop | Full table |
| Tablet | Hide low-priority columns (variant `Columns=Reduced`) |
| Mobile | Swap to `Data/Table/MobileCard` component |

### 12.2 Component: `Data/Table/MobileCard`

```
MobileCard [V, pad 16, gap 12, radius 12, stroke]
├── HeaderRow [title + status chip]
├── MetaGrid [2 col key-value]
└── Actions [H, gap 8]
```

One card per table row · used in Parent, Transport, Hostel mobile companions

---

## 13. Step 11 — KPI Cards

### 13.1 Component: `Data/KPI/Standard`

#### Layer structure

```
KPI/Standard [176×120, V, pad 20, gap 12, radius 12, elevation/1]
├── TopRow [H, space-between]
│   ├── IconContainer [40×40, radius 8, primary-container]
│   │   └── Icon [24]
│   └── DeltaChip [optional]
├── Label [type/body/small, on-surface-variant]
└── Value [type/headline/small, on-surface]
```

#### Auto-layout

Root: Vertical · Gap 12 · Padding 20 · Fixed W 176 H 120 (or Fill in grid)

#### Variants

| Property | Values |
|----------|--------|
| `Accent` | Primary · Success · Warning · Error · Neutral |
| `Trend` | None · Up · Down · Flat |
| `Size` | Standard (176×120) · Wide (272×120) |

#### Accent icon container fills

| Accent | Container | Icon color |
|--------|-----------|------------|
| Primary | `primary-container` | `primary` |
| Success | `success-container` | `success` |
| Warning | `warning-container` | `warning` |
| Error | `error-container` | `error` |

#### Delta chip

`type/label/small` · pill radius full · green/red background per trend

#### Constraints

Fixed size in 6-up grid · In mobile 2×2: Width Fill (Hug height)

#### Responsive

| Desktop | 6 × Standard in row (1136) |
| Tablet | 3×2 grid |
| Mobile | 2×2 · use `Data/KPI/Compact` |

### 13.2 Component: `Data/KPI/Compact`

`272×88` or `Fill×88` · Icon 32 · Value `type/title/small` · single row layout option

---

## 14. Step 12 — Chart Cards

### 14.1 Component: `Data/ChartCard`

#### Layer structure

```
ChartCard [V, min 400×320, radius 12, elevation/1, pad 0]
├── Header [H, 48h, pad 16 20, space-between]
│   ├── Title [type/title/medium]
│   └── Actions [IconButton more_vert]
├── Legend [H, 40h, pad 0 20, gap 16] (optional)
├── PlotArea [Fill, min 220h, pad 16 20]
│   └── Chart/Placeholder [use chart tokens]
└── Footer [optional, 32h, pad 8 20]
```

#### Auto-layout

Root: Vertical · Gap 0 · Fill width  
PlotArea: Fill both · Min height 220

#### Variants

| Property | Values |
|----------|--------|
| `ChartType` | Line · Area · Bar · StackedBar · Donut · Funnel · Heatmap |
| `HasLegend` | True · False |
| `Size` | Large (560×320) · Medium (400×280) · Mobile (Fill×280) |

#### Chart color binds

Series 1–4 → `primitive/chart/1-4` · Grid lines → `primitive/chart/grid`

#### Constraints

Desktop: fixed width per grid span (560 = half row)  
Mobile: Fill width · Plot min height 200

#### Responsive

| Desktop | Side-by-side 624+496 or 560+560 |
| Tablet | Stacked full width |
| Mobile | Stacked · legend wraps |

---

## 15. Step 13 — Navigation Rail

### 15.1 Component: `Nav/Rail`

#### Layer structure

```
Nav/Rail [V, Fill height, fill surface, stroke right outline-variant]
├── Brand [H, 64h, pad 12, center]
│   └── Logo [32×32] + SchoolName [collapsed: hide]
├── Items [V, gap 4, pad 8 12, fill]
│   └── NavItem [×n instance]
└── Footer [pad 12]
    └── CollapseToggle [optional tablet]
```

#### NavItem layer

```
NavItem [H, 48h, gap 12, pad 12 16, radius 8]
├── Icon [24]
├── Label [type/label/medium, fill] (hidden when collapsed)
└── Badge [optional]
```

#### Auto-layout

| Node | Settings |
|------|----------|
| Rail | Vertical · Gap 0 · W 256 or 72 |
| NavItem | Horizontal · Center vertical · Fill width |

#### Variants

| Property | Values |
|----------|--------|
| `Expanded` | True (256) · False (72) |
| `Module` | Finance · Management · Admissions · Principal · … |
| `ActiveItem` | Dashboard · Fees · … (per module) |

#### Active state

Fill `color/primary-container` · Icon **Filled** · Label `color/on-primary-container` weight 500

#### Constraints

Rail: Fixed width · Top + Bottom + Left  
NavItem: Fill width of rail

#### Responsive

| Desktop ≥1200 | Expanded 256 |
| Tablet 768–1199 | Collapsed 72 · labels hidden |
| Mobile | **Not visible** — use `Nav/Drawer` overlay |

### 15.2 Component: `Nav/Drawer` (mobile web)

Width 280 · slides over scrim · same NavItem components

---

## 16. Step 14 — App Bar

### 16.1 Web: `Nav/AppBar`

#### Layer structure

```
AppBar [H, 64h, pad 0 24, fill surface, stroke bottom outline-variant]
├── LeftCluster [V, gap 2]
│   ├── Breadcrumb [type/body/small, on-surface-variant]
│   └── PageTitle [type/headline/medium]
├── CenterCluster [optional, search — Principal PR-12]
│   └── SearchTrigger [360w compact field]
└── RightCluster [H, gap 8, center]
    ├── AI/AssistChip [instance]
    ├── NotificationButton [badge]
    └── Avatar [40, radius full]
```

#### Auto-layout

Horizontal · Space between · Align center · Fill width · Fixed H 64

#### Variants

| Property | Values |
|----------|--------|
| `Platform` | Web · Mobile |
| `HasSearch` | True · False |
| `HasBack` | True · False (mobile) |

#### Constraints

LeftCluster: Hug · RightCluster: Hug · Center: Fill (search)

### 16.2 Mobile: `Nav/AppBar/Mobile`

Height **56** · single line title `type/title/large` · back arrow optional · actions max 2 icons

---

## 17. Step 15 — Dialogs

### 17.1 Component: `Overlays/Dialog`

#### Layer structure

```
Dialog/Scrim [Fill screen, scrim color]
└── DialogPanel [V, centered]
    ├── Title [type/title/large, pad 24 24 16 24]
    ├── Content [pad 24 16 24 16, fill width]
    └── Actions [H, end, gap 8, pad 16 24 24 24]
        ├── Button/Text/Cancel
        └── Button/Filled/Confirm
```

#### Auto-layout

Panel: Vertical · Gap 0 · Hug height · Fixed width per size

#### Variants

| Property | Values |
|----------|--------|
| `Size` | Small (400) · Medium (560) · Large (720) |
| `Type` | Confirm · Form · WizardStep · Destructive |
| `Actions` | Single · Dual · Triple |

#### Properties

| Property | Type |
|----------|------|
| `Title` | Text |
| `ShowClose` | Boolean |

#### Constraints

Panel: Center horizontally + vertically on scrim  
Content: Fill panel width · Hug height · Max height 70vh scroll

#### Responsive

| Desktop/Tablet | Fixed width centered |
| Mobile | `Size=Fullscreen` — panel Fill screen, radius 0 |

### 17.2 Wizard pattern

Use `Large (720)` · add `Stepper` row 56h below title · `Step 1 of 4` label

---

## 18. Step 16 — Bottom Sheets

### 18.1 Component: `Overlays/BottomSheet`

#### Layer structure

```
BottomSheet/Scrim [Fill, scrim]
└── SheetPanel [V, bottom align, radius 16 16 0 0, elevation/4]
    ├── Handle [36×4, radius full, centered, pad 12 top]
    ├── Header [H, 56h, pad 16, space-between]
    │   ├── Title [type/title/medium]
    │   └── IconButton/close
    ├── Content [V, pad 16, gap 16, scroll]
    └── Actions [optional sticky, pad 16, border top]
```

#### Auto-layout

SheetPanel: Vertical · Width Fill · Hug height up to 90% viewport  
Content: Fill width · Hug or Fill height

#### Variants

| Property | Values |
|----------|--------|
| `Size` | Half (50%) · Full (90%) · Auto |
| `HasActions` | True · False |

#### Constraints

SheetPanel: Left + Right + Bottom · Width Fill  
Handle: Center horizontal

#### Responsive

**Mobile primary** for: filters, dropdowns, approval detail, child selector (P-D-01)

Tablet: optional instead of dialog for `Approval/DetailDialog`

---

## 19. Step 17 — Mobile Navigation

### 19.1 Component: `Nav/BottomBar`

#### Layer structure

```
BottomBar [H, 80h + safe 34, fill surface, stroke top outline-variant]
└── Items [H, space-around, fill]
    └── BottomNavItem [×4-5, V, center, gap 4, min W 64]
        ├── Icon [24]
        ├── Label [type/label/medium, 10px optional]
        └── Badge [optional dot]
```

#### Auto-layout

Root: Horizontal · Space between · Align center · Fill width · Pad bottom safe area

#### Variants

| Property | Values |
|----------|--------|
| `App` | Parent · Student · Teacher · Alumni |
| `ActiveTab` | Home · Academics · Fees · Messages · More |

#### Active state

Icon Filled `color/primary` · Label `color/primary`

#### Constraints

BottomBar: Left + Right + Bottom · Fix height  
Items: Equal width distribution

#### Per-app tab maps (from module specs)

| App | Tabs |
|-----|------|
| Parent | Home · Academics · Fees · Messages · More |
| Student | Home · Learn · Schedule · Results · More |
| Teacher | Home · Classes · Teach · Messages · More |
| Alumni | Home · Events · Donate · Network · More |

### 19.2 Component: `Nav/BottomBar/OverflowMenu`

Full-screen list from **More** tab · grid 2 col icons + labels

---

## 20. Step 18 — Empty States

### 20.1 Component: `Feedback/Empty`

#### Layer structure

```
Empty [V, center, gap 16, pad 48 24, fill]
├── Visual [Illustration 200×160 OR Icon 80 in circle]
├── Title [type/title/medium, center]
├── Description [type/body/medium, on-surface-variant, center, max W 320]
└── CTA [Button/Filled, optional]
```

#### Auto-layout

Vertical · Center · Gap 16 · Hug contents · Center in parent Fill

#### Variants

| Property | Values |
|----------|--------|
| `Context` | Inbox · Search · Table · Homework · Fees · Generic |
| `HasCTA` | True · False |

#### Properties

| Property | Type |
|----------|------|
| `Title` | Text |
| `Description` | Text |

#### Constraints

Center in scrollable body · Min height 280

#### Responsive

Same component all breakpoints · reduce pad to 32 on mobile

---

## 21. Step 19 — Error States

### 21.1 Component: `Feedback/Banner`

#### Layer structure

```
Banner [H, hug, pad 12 16, gap 12, radius 8, fill container]
├── Icon [24, status color]
├── Message [type/body/medium, fill]
└── Trailing [optional: action text + close]
```

#### Variants

| Property | Values |
|----------|--------|
| `Type` | Error · Warning · Success · Info |
| `HasAction` | True · False |
| `Dismissible` | True · False |

#### Fill by type

| Type | Background | Icon |
|------|------------|------|
| Error | `error-container` | `error` |
| Warning | `warning-container` | `warning` |
| Success | `success-container` | `success` |
| Info | `primary-container` | `primary` |

### 21.2 Component: `Feedback/ErrorPage`

```
ErrorPage [V, center, pad 48]
├── Icon [80, error]
├── Title [type/headline/small]
├── Description [type/body/medium]
└── Actions [H, gap 12]
    ├── Button/Outlined Retry
    └── Button/Text Go Back
```

### 21.3 Component: `Feedback/InlineError`

Single line below inputs — `type/body/small` · `color/error` — part of TextField variant

### 21.4 Responsive

Banner: Fill width · Mobile stack trailing actions below if needed

---

## 22. Step 20 — Loading States

### 22.1 Component: `Feedback/Skeleton`

#### Layer structure

```
Skeleton [V or H, gap 8]
└── Bone [×n, radius 4, fill surface-container-highest + shimmer overlay]
```

#### Variants

| Property | Values |
|----------|--------|
| `Pattern` | KPIRow · TableRows · Card · Chart · List |

#### KPI skeleton

6 bones `176×120` radius 12

#### Table skeleton

5 rows × Fill × 52h

#### Shimmer

Linear gradient animation 1.2s · **disable in reduced-motion variant**

### 22.2 Component: `Feedback/Spinner`

`Progress/Circular` 40×40 · stroke `color/primary` · use in buttons and full-page loader

### 22.3 Component: `Feedback/LoadingOverlay`

Scrim 20% + centered Spinner + optional `type/body/medium` label

### 22.4 Constraints

Skeleton bones: Fill width where mimicking text · Fixed size where mimicking KPI

---

## 23. Step 21 — Publish & Link Modules

### 23.1 Library publish

1. Page order: Foundations → Components → Shells → Templates  
2. Assets panel → Publish library  
3. Enable variable publishing with collections Theme + Spacing

### 23.2 Module file linking

| Figma folder | File | Shell component |
|--------------|------|-----------------|
| 01 | Parent App | `Shell/ParentMobileLayout` |
| 02 | Student App | `Shell/StudentMobileLayout` |
| 03 | Teacher App | `Shell/TeacherMobileLayout` |
| 04 | Management | `Shell/ManagementLayout` |
| 05 | Hostel | `Shell/HostelLayout` |
| 06 | Transport | `Shell/TransportLayout` |
| 07 | Admissions | `Shell/AdmissionsLayout` |
| 08 | Finance | `Shell/FinanceLayout` |
| 09 | HR | `Shell/HRLayout` |
| 05 | Principal | `Shell/PrincipalLayout` |
| 00 | Platform | `Shell/PlatformLayout` |

### 23.3 Per-screen build recipe (all modules)

1. Place device frame (`1440×1024` or `390×844`)  
2. Instance correct Shell · set nav `ActiveItem`  
3. AppBar: set breadcrumb + title text properties  
4. Filter bar: instance dropdowns compact  
5. KPI row: instance `Data/KPI/Standard` × 4–6  
6. Body: tables/charts from library  
7. Apply `grid/desktop-12` or `grid/mobile-4` to content area  
8. Name frame: `{MODULE}-{##}-{Name}-{D|T|M}` per module spec

---

## 24. QA Checklist

### Foundations

- [ ] All colors use semantic variables
- [ ] All 12 text styles exist and are applied
- [ ] 5 elevation styles match spec
- [ ] 4 grid presets on reference frames
- [ ] 8 spacing variables documented

### Components

- [ ] Button: 6 states × 4 types documented
- [ ] TextField: Focus ring 2px primary
- [ ] Dropdown + mobile bottom sheet select
- [ ] Table compact/comfortable + mobile card swap
- [ ] KPI 4 accents + compact variant
- [ ] ChartCard 7 chart type placeholders
- [ ] Nav rail expanded/collapsed
- [ ] AppBar web 64 + mobile 56
- [ ] Dialog 3 sizes + fullscreen mobile
- [ ] Bottom sheet half/full
- [ ] Bottom nav 4 apps
- [ ] Empty, Banner, ErrorPage, Skeleton

### Accessibility

- [ ] Touch targets ≥ 48px on mobile actions
- [ ] Focus visible on interactive variants
- [ ] Status never color-only (icon + text)
- [ ] Contrast check primary on white ≥ 4.5:1

### Integration

- [ ] Library published · 3 module files linked successfully
- [ ] Variable modes survive swap in instances
- [ ] `MobileScreenInventory.md` frames accounted for
- [ ] Approval + Audit + Report components from DesignSystem §24–26 built

---

## Appendix A — Filter Bar Component

**Component:** `Nav/FilterBar`

```
FilterBar [H, 56h, pad 8 24, gap 12, fill surface, stroke bottom]
├── Left [H, gap 12]
│   ├── Dropdown/Compact [FY]
│   ├── Dropdown/Compact [Period]
│   └── Chip/Filter [×n]
├── Spacer [Fill]
└── Right [H, gap 8]
    ├── Button/Outlined Export
    └── Button/Filled Primary CTA
```

Used on every web admin screen per Finance.md §5.

---

## Appendix B — AI Assist Chip

**Component:** `AI/AssistChip`

```
AssistChip [H, 36h, pad 8 12, gap 8, radius full, primary-container]
├── Icon/psychology [20]
└── Label ["AI Assist", type/label/medium]
```

Tapping opens `AI/ChatPanel` dock 400px desktop · fullscreen mobile.

---

## Appendix C — Component Build Time Estimates

| Step | Component | Hours |
|------|-----------|-------|
| 1–5 | Foundations | 4–6 |
| 6 | Icons | 2 |
| 7 | Buttons | 3 |
| 8–9 | Inputs + Dropdowns | 4 |
| 10 | Tables | 4 |
| 11–12 | KPI + Charts | 4 |
| 13–14 | Nav + AppBar | 4 |
| 15–16 | Dialogs + Sheets | 3 |
| 17 | Mobile nav | 2 |
| 18–20 | States | 4 |
| 21 | Publish + QA | 2 |

**Total:** ~36–40 hours for complete library v1.0

---

**End of Figma Design System Build Guide v1.0**
