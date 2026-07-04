# Akshara ERP — Master Design System Specification

**Document ID:** `AKS-DS-SPEC-v1.0`  
**Scope:** All Akshara ERP products — mobile apps, web portals, admin modules  
**Foundation:** Material 3 · 8pt grid · Enterprise SaaS  
**Source:** SRS Part 8, Part 16 · Finance Module Specification · PROJECT_CONTEXT.md

---

## Table of Contents

1. [Design System Overview](#1-design-system-overview)
2. [Design Principles](#2-design-principles)
3. [Frame Presets & Grid](#3-frame-presets--grid)
4. [Color Tokens](#4-color-tokens)
5. [Typography](#5-typography)
6. [Spacing System](#6-spacing-system)
7. [Elevation & Shape](#7-elevation--shape)
8. [Iconography](#8-iconography)
9. [Layout Shells](#9-layout-shells)
10. [Buttons & Actions](#10-buttons--actions)
11. [Form Controls](#11-form-controls)
12. [Data Tables](#12-data-tables)
13. [Charts & KPIs](#13-charts--kpis)
14. [Dialogs & Wizards](#14-dialogs--wizards)
15. [Navigation](#15-navigation)
16. [Feedback & States](#16-feedback--states)
17. [AI Copilot Components](#17-ai-copilot-components)
18. [Responsive Rules](#18-responsive-rules)
19. [Accessibility Standards](#19-accessibility-standards)
20. [White Label & Theming](#20-white-label--theming)
21. [Figma Library Organization](#21-figma-library-organization)
22. [Component Variant Matrix](#22-component-variant-matrix)
24. [Platform Audit Components](#24-platform-audit-components)
25. [Shared Approval Components](#25-shared-approval-components)
26. [Shared Report Components](#26-shared-report-components)
27. [Build Checklist](#27-build-checklist)

---

## 1. Design System Overview

### Purpose

Single source of truth for visual design, component behavior, and Figma build standards across Parent, Student, Teacher, Principal, and all administrative portals.

### Platforms

| Platform | Primary use |
|----------|-------------|
| Mobile `390×844` | Parent, Student, Teacher apps |
| Tablet `834×1194` | Hybrid admin, class teacher |
| Desktop `1440×1024` | Finance, Management, Admissions, HR, etc. |

### Token Architecture

```
Primitive Colors → Semantic Colors → Component Tokens
Primitive Spacing → Layout Spacing → Component Padding
Type Scale → Text Styles → Component Labels
```

---

## 2. Design Principles

| Principle | Rule |
|-----------|------|
| Mobile first | Parent/Student/Teacher optimized for rural connectivity |
| Enterprise clean | Minimal shadow; tonal surfaces over heavy elevation |
| Education focused | Large touch targets, readable type, multilingual |
| 3-click rule | High-frequency actions ≤3 taps/clicks from dashboard |
| Security visible | Role-gated UI; disabled actions show tooltip reason |
| Consistent shell | Every web module uses shared nav + app bar + filter bar |

**Brand defaults:** Primary Blue · White Background · Red Alerts · Green Success

---

## 3. Frame Presets & Grid

| Breakpoint | Frame | Columns | Margin | Gutter | Content max |
|------------|-------|---------|--------|--------|-------------|
| Mobile | `390×844` | 4 | 16 | 16 | 358 |
| Mobile Large | `428×926` | 4 | 16 | 16 | 396 |
| Tablet | `834×1194` | 8 | 24 | 24 | 786 |
| Desktop | `1440×1024` | 12 | 24 | 24 | 1136 (with 256 nav) |
| Desktop Wide | `1920×1080` | 12 | 32 | 24 | 1856 |

**Baseline grid:** 8pt · **Safe areas:** Top 59 · Bottom 34 (mobile)

---

## 4. Color Tokens

### Primitive Palette

| Token | Hex |
|-------|-----|
| `blue/800` | `#1565C0` |
| `blue/50` | `#E3F2FD` |
| `blue/900` | `#0D47A1` |
| `neutral/0` | `#FFFFFF` |
| `neutral/50` | `#F8FAFC` |
| `neutral/200` | `#E2E8F0` |
| `neutral/500` | `#64748B` |
| `neutral/900` | `#1E293B` |
| `red/500` | `#D32F2F` |
| `red/50` | `#FFEBEE` |
| `green/600` | `#2E7D32` |
| `green/50` | `#E8F5E9` |
| `amber/600` | `#F57C00` |
| `amber/50` | `#FFF3E0` |

### Semantic Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `color/primary` | `#1565C0` | CTAs, active nav, links |
| `color/on-primary` | `#FFFFFF` | Text on primary |
| `color/primary-container` | `#E3F2FD` | Chips, AI panels, selected |
| `color/on-primary-container` | `#0D47A1` | Text on primary container |
| `color/surface` | `#FFFFFF` | Cards, inputs, modals |
| `color/surface-container-low` | `#F8FAFC` | Page background |
| `color/surface-container-highest` | `#E8EDF3` | Table headers |
| `color/on-surface` | `#1E293B` | Body text |
| `color/on-surface-variant` | `#64748B` | Labels, metadata |
| `color/outline-variant` | `#E2E8F0` | Borders |
| `color/error` | `#D32F2F` | Errors, overdue, absent |
| `color/error-container` | `#FFEBEE` | Alert backgrounds |
| `color/success` | `#2E7D32` | Success, present, paid |
| `color/success-container` | `#E8F5E9` | Success backgrounds |
| `color/warning` | `#F57C00` | Pending, due soon |
| `color/warning-container` | `#FFF3E0` | Warning backgrounds |
| `color/scrim` | `#1E293B` 40% | Modal overlay |

### Chart Tokens

`chart/1` `#1565C0` · `chart/2` `#42A5F5` · `chart/3` `#7E57C2` · `chart/4` `#26A69A` · `chart/grid` `#E2E8F0`

---

## 5. Typography

### Font Families

| Role | Family |
|------|--------|
| Latin | Roboto |
| Telugu | Noto Sans Telugu |
| Hindi | Noto Sans Devanagari |
| Tamil | Noto Sans Tamil |
| Kannada | Noto Sans Kannada |
| Malayalam | Noto Sans Malayalam |
| Urdu | Noto Nastaliq Urdu |
| Mono | Roboto Mono (IDs, receipts) |

### Type Scale

| Style | Size/LH/Weight | Use |
|-------|----------------|-----|
| `type/headline/medium` | 28/36/400 | Web page titles |
| `type/headline/small` | 24/32/400 | Mobile page titles, KPI values |
| `type/title/large` | 22/28/500 | Card headers |
| `type/title/medium` | 16/24/500 | Section titles |
| `type/title/small` | 14/20/500 | Compact KPI values |
| `type/body/large` | 16/24/400 | Table cells, inputs |
| `type/body/medium` | 14/20/400 | Secondary body |
| `type/body/small` | 12/16/400 | Captions, breadcrumbs |
| `type/label/large` | 14/20/500 | Buttons, tabs |
| `type/label/medium` | 12/16/500 | Chips, nav labels |
| `type/label/small` | 11/16/500 | Table headers |

---

## 6. Spacing System

| Token | px | Use |
|-------|-----|-----|
| `space/1` | 4 | Tight icon gap |
| `space/2` | 8 | Chip internal, compact |
| `space/3` | 12 | Card list gap |
| `space/4` | 16 | Standard padding, mobile margin |
| `space/5` | 20 | KPI desktop padding |
| `space/6` | 24 | Section gaps, desktop padding |
| `space/8` | 32 | Large breaks |
| `space/12` | 48 | Min touch target |

**Defaults:** Section pad `24` · Card gap `16` · Form field gap `24` · Table cell `12×16`

---

## 7. Elevation & Shape

| Level | Shadow | Use |
|-------|--------|-----|
| `elevation/0` | None | Flat cards with border |
| `elevation/1` | Y1 Blur3 8% | KPI cards |
| `elevation/2` | Y2 Blur6 10% | Menus |
| `elevation/3` | Y4 Blur12 12% | Dialogs, FAB |
| `elevation/4` | Y8 Blur24 14% | Bottom sheets |

| Radius | px | Use |
|--------|-----|-----|
| `radius/sm` | 8 | Chips, badges |
| `radius/md` | 12 | Cards, tables |
| `radius/lg` | 16 | Modals |
| `radius/xl` | 20 | Buttons (pill) |
| `radius/full` | 999 | Avatars |

---

## 8. Iconography

**Library:** Material Symbols Rounded  
**Sizes:** 16 · 20 · 24 (default) · 28 · 40 · 80  
**Rules:** Outlined default · Filled for active nav only · Never color-only status

---

## 9. Layout Shells

### Web Admin Shell

```
Shell [H Fill×Fill]
├── Nav/Rail [256×Fill]
└── Main [V Fill×Fill scroll]
    ├── AppBar [64]
    ├── FilterBar [56]
    ├── Body sections
    └── Spacer [32]
```

### Mobile Shell

```
Scaffold
├── AppBar [56]
├── Body [scroll]
└── BottomNav [80]
```

---

## 10. Buttons & Actions

| Variant | Height | Radius | Fill |
|---------|--------|--------|------|
| Filled | 48 | 20 | `primary` |
| Tonal | 48 | 20 | `primary-container` |
| Outlined | 40 | 20 | `surface` + 1px outline |
| Text | 40 | — | transparent |
| IconButton | 40 (48 hit area) | full | transparent |
| FAB | 56 | 16 | `primary` |

**States:** Default · Hovered · Pressed · Focused · Disabled · Loading

---

## 11. Form Controls

| Control | Height | Notes |
|---------|--------|-------|
| TextField Outlined | 56 | 2px focus ring `primary` |
| TextField Compact | 40 | Filter bars |
| Dropdown | 56 | Menu max 304px height |
| DatePicker trigger | 56 | Calendar popover 328px |
| Checkbox | 18 | Row select tables |
| TextArea | min 96 | Character count below |

---

## 12. Data Tables

| Part | Spec |
|------|------|
| Header | 48px · `surface-container-highest` · `label/small` |
| Row compact | 52px |
| Row comfortable | 64px |
| Pagination | 56px |
| Container | radius 12 · border 1px `outline-variant` |
| Mobile fallback | `Data/Table/MobileCard` |

---

## 13. Charts & KPIs

### KPI Standard `176×120`

Icon 40×40 · Label `body/small` · Value `headline/small` · Optional delta chip

### KPI Compact `272×88`

Icon 32×32 · Value `title/small`

### ChartCard

Min `400×320` desktop · Header 48 · Legend 40 · Plot area flex

**Types:** Line · Area · Bar · StackedBar · Donut · Funnel · Heatmap · Bullet

---

## 14. Dialogs & Wizards

| Size | Width | Use |
|------|-------|-----|
| Small | 400 | Confirm |
| Medium | 560 | Forms |
| Large | 720 | Wizards |
| Fullscreen | 100% | Mobile all dialogs |

**Anatomy:** Title pad 24 · Content pad 24/16 · Actions H end gap 8

---

## 15. Navigation

| Pattern | Platform | Spec |
|---------|----------|------|
| BottomNav | Mobile | 4–5 items · height 80 |
| NavRail expanded | Web | 256px · item 48px |
| NavRail collapsed | Tablet | 72px |
| Tabs primary | Web | 48px underline indicator |
| Breadcrumb | Web | `body/small` |

---

## 16. Feedback & States

| Component | Spec |
|-----------|------|
| Banner | Pad 12×16 · radius 8 · Error/Warning/Success/Info |
| Snackbar | min 48 · max 568 · inverse surface |
| Empty | Illustration 200×160 or icon 80 · title + description + CTA |
| Loading skeleton | Shimmer on `surface-container-high` |
| Error page | Icon 80 `error` · Retry + Go Back |

---

## 17. AI Copilot Components

| Component | Spec |
|-----------|------|
| ChatPanel dock | 400px desktop · fullscreen mobile |
| User bubble | `primary` fill · radius 16/16/4/16 |
| AI bubble | `primary-container` · radius 16/16/16/4 |
| InsightCard | 4px left accent · priority colors |
| SuggestedPrompts | Horizontal chips 32px |
| VoiceOverlay | 360×360 · waveform pulse |

---

## 18. Responsive Rules

| Element | Desktop | Tablet | Mobile |
|---------|---------|--------|--------|
| Nav | 256 expanded | 72 collapsed | Drawer |
| KPI grid | 6 or 4 col | 3×2 | 2×2 |
| Charts | Side-by-side | Stacked | Stacked 280h |
| Tables | Full cols | Hide low priority | Card list |
| Dialogs | Fixed width | 90% | Fullscreen |
| AI panel | Right dock | Bottom sheet | Fullscreen |

---

## 19. Accessibility Standards

| Rule | Spec |
|------|------|
| Touch target | Min 48×48px |
| Contrast body | ≥ 4.5:1 |
| Contrast large text | ≥ 3:1 |
| Focus ring | 2px `primary` offset 2px |
| Status | Icon + text, never color alone |
| Charts | Data table fallback link required |
| Screen reader | `aria-label` on icon-only buttons |
| Motion | Respect reduced motion · disable shimmer loop |

---

## 20. White Label & Theming

Per school (SRS Part 4 §16):
- Override `color/primary` only (default `#1565C0`)
- School logo on splash, login, app bar
- Optional login background image
- Fonts remain Noto family for regional scripts

---

## 21. Figma Library Organization

```
📁 Akshara — Master Design System
├── Foundations (Colors, Type, Spacing, Effects)
├── Components — Actions
├── Components — Inputs
├── Components — Data Display
├── Components — Navigation
├── Components — Feedback
├── Components — AI
├── Shells — Mobile / Web
└── Templates — Dashboard / Form / Table
```

**Naming:** `Category/Component/Variant/State`

---

## 22. Component Variant Matrix

| Component | Properties |
|-----------|------------|
| Button | Type × Size × State × FullWidth |
| TextField | Type × State × Size × Leading × Trailing |
| KPI | Accent × Trend × Size |
| Table Row | State × Density × Selectable |
| Dialog | Size × Type × Actions |
| NavRail | Module × Expanded × ActiveItem |
| Chip | Type × Selected × Removable |
| Banner | Type × HasAction × Dismissible |

---

## 24. Platform Audit Components

> Canonical event schema: **Audit.md**. Primary viewer: Finance FN-10.

| Component | Size | States |
|-----------|------|--------|
| `Audit/LogRow` | H `72` | Default · Unread critical |
| `Audit/DetailDrawer` | W `480` | Before/after diff · metadata |
| `Audit/SeverityChip` | chip | info · warning · critical |
| `Audit/FilterBar` | H `56` | Module · severity · date · user |
| `Audit/DiffViewer` | Fill | Field-level before → after |

### Severity Colors

| Severity | Container | Text |
|----------|-----------|------|
| info | `surface-container-low` | `on-surface-variant` |
| warning | `warning-container` | `on-surface` |
| critical | `error-container` | `error` |

---

## 25. Shared Approval Components

Used by MG-03, AD-08, PR-06/07, HO-D-08, FN-09 (AR-057):

| Component | Size | Use |
|-----------|------|-----|
| `Approval/QueueRow` | H `88` | Management MG-03 |
| `Approval/AcademicQueueRow` | H `88` | Principal PR-06/07 |
| `Approval/DetailDialog` | W `720` | Shared approve/reject with AI rec |
| `Approval/AIRecChip` | chip | Approve · Review · Reject risk |
| `Approval/RejectReason` | dialog `400` | Required reason field |

### Approval Detail Dialog Anatomy

Header · requester · amount/context · AI recommendation · attachment list · Approve primary · Reject outlined · audit note footer

---

## 26. Shared Report Components

> Canonical catalog: **Reports.md**

| Component | Size | Use |
|-----------|------|-----|
| `Report/CatalogCard` | `272×120` | Report launcher tile |
| `Report/ParameterDrawer` | W `400` | Dynamic filters per RPT-ID |
| `Report/PreviewPane` | Fill | PDF iframe or table |
| `Report/ScheduleChip` | chip | Scheduled report indicator |

---

## 27. Build Checklist

| Step | Task |
|------|------|
| 1 | Create Figma variables (color, spacing) |
| 2 | Publish text styles (Latin + 6 regional) |
| 3 | Build button, input, chip set |
| 4 | Build KPI, table, chart card |
| 5 | Build shells (mobile + web) |
| 6 | Build dialog, banner, snackbar, empty, loading |
| 7 | Build AI copilot components |
| 8 | Document variants matrix |
| 9 | Link library to all module Figma files |
| 10 | Accessibility annotation pass |

---

**End of Master Design System Specification v1.0**
