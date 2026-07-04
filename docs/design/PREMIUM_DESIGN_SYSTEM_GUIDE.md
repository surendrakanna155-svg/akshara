# Akshara ERP — Premium Design System Guide (v2)

**Status:** 🟢 The single reconciled design-system specification — resolves the System A ("Enterprise M3 Blue") vs System B ("Premium School OS") split and the documentation↔code drift.
**Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Author:** Fable (World-Class Product Polish phase, Phase 4 of 5)
**Authority:** For **visual direction** this guide inherits the owner-approved `VISUAL_DESIGN_SYSTEM.md` (2026-06-20). For **component anatomy** the `DesignSystem.md` family remains reference. For **current truth** the code is canon: `lib/theme/` + `lib/shared/widgets/`.
**Executes as:** P2-UX-3 (enforcement) · P2-UX-4 (a11y) · P2-UX-5 (dark toggle) · a Premium-completion visual wave (M15-pattern, owner-timed — §13).

> **Prime rule (learned from M15/M15.5):** the design system changes by **token swap + shared-widget
> edit only** — never by touching routes, providers, RBAC, or workflows. Goldens, Patrol, and
> `dashboard_stress_test.dart` guard every visual wave.

---

## 1. The ruling — one system

**Akshara Premium Design System v2** = System B's look (indigo, gradient atmosphere, soft depth, monoline motifs, dark premium) **on** System A's skeleton (8pt grid, component anatomy, breakpoints, a11y constants) **anchored to the code as implemented** (which already quietly resolved several doc conflicts — see radius, §7).

- `VISUAL_DESIGN_SYSTEM.md` stays the approved *mood* document; this guide is its buildable spec.
- `DesignSystem.md` / `FlutterDesignSystem.md` / `FigmaDesignSystemBuildGuide.md` are **demoted to anatomy reference**: their palette, heading weights, and shadow tables are superseded here. Add a pointer banner to each (docs task, no code).
- Token tables live in **one place going forward: the code** (`lib/theme/*.dart`). Documents describe *intent and rules*, never re-list hex values in four files (fixes C-ISS-7's 4-file duplication).

---

## 2. Token reconciliation — the drift, settled

| Token | Docs (System A) | Code today | Premium target (System B) | **v2 decision** |
|---|---|---|---|---|
| Primary | `#1565C0` | `#1A56DB` (`blue800`) | `#5B5BF0` + gradient `#6366F1→#8B5CF6` | **`#5B5BF0`** — completes the approved direction; shipped via Premium-completion wave (§13); until then `#1A56DB` remains interim canon |
| Success | `#2E7D32` | `#15803D` | `#1A7F46` on `#E7F8EE` | **Premium pair** (wave) |
| Warning | `#F57C00` | `#D97706` | `#B0700E` on `#FEF3E2` | **Premium pair** (wave) — note: darker warn ink passes AA on tint, the old orange didn't |
| Error | `#D32F2F` | `#DC2626` | `#C0392B` on `#FDECEE` | **Premium pair** (wave) |
| Card radius | 12 | **16 (`AksharaRadius.card`)**, KPI 20, dialog 24 | 20–24 | **Code is canon:** card 16 · hero/KPI/premium surfaces 20 · dialog/sheet 24. (Code already split the difference correctly; docs update only) |
| Shadows | 4-level gray Y-offset | `elevation.dart` + `shadows.dart` layered soft | 3-level tinted (`rgba(91,91,240,.10)` family) | **Premium 3-level tinted** mapped onto the existing `AksharaElevation` API (values swap, API stays) |
| Headline weight | 400 | 400/w600 KPI | 800, −0.5 ls | **Display/KPI 700–800 with −0.5 ls; body scale unchanged.** 800 only ≥28px |
| Font | Roboto (+Noto UI stack) | Roboto + RobotoMono | **Inter** intended | **Inter for UI** (bundled, offline-safe), RobotoMono stays for IDs/receipts/mono. Noto *UI* fallback stack retired per English-first (parent-comms text renders fine via system fallback) |
| Numerals | — | partial | tabular | **Tabular numerals mandatory** on KPIs, tables, money, receipts |
| Page canvas | flat `#F8FAFC` | flat + mesh on premium dashboards | gradient `#F6F7FB→#F3F1FB→#FBF1F7` | **Gradient canvas on dashboards/heroes; flat `surfaceContainerLow` on dense work screens** (calm where you glance, quiet where you work) |
| Tablet breakpoint | 1024 (V1 doc) vs 1199 | **1199 (`breakpoints.dart`)** | — | **1199. Code is canon**; V1 doc corrected by banner |
| KPI heights | 120/88/132/112 across 4 docs | varies | — | **One rule:** KPI strip 112 (M15.5) · comfortable card ≥120 · compact 88. Enforced by using `AksharaKpiCard` variants only (C-ISS-8) |
| Motion | *(unspecified in all docs)* | `motion.dart`: 80/120/180/240ms + curves | — | **Code is canon — now specified as a system, §6** |
| Dark mode | "P2 placeholder" | obsidian palette code-complete, locked light | full dark palette specced | **Ship toggle (P2-UX-5)** after §4 validation |

**White-label × premium × dark collision rule (closes consolidation gap #14):** a school's brand color replaces `primary` and *derives* the gradient as `primary → primary rotated +18° hue / +8% lightness` (deterministic derivation, no per-school design work); status colors never rebrand; dark mode derives the brand primary's dark variant via the existing `ColorScheme.fromSeed` path with a minimum-contrast guard — if the brand color fails AA on either mode, the system falls back to tinted-neutral surfaces with brand confined to accents. One rule, three systems reconciled.

---

## 3. Color usage doctrine

- **≤4 hues per screen** (VISUAL_DESIGN_SYSTEM §8): primary + one status + neutrals + one accent. Rainbow dashboards are a lint violation, not a taste question.
- **Semantic only in features:** features consume `context.colors.*` roles; primitives (`blue800`…) are theme-internal. Already true for hex (zero literals in `lib/features/`); extend the lint to the 7 files using `Colors.*` named colors (code survey).
- **Status = icon + text + color, never color alone** (existing a11y rule, now CI-checked).
- **Charts:** keep the 4-series palette; add the missing rules — series >4 = group into "Other"; adjacent-series contrast validated once against deuteranopia simulation (one-time design task); chart empty/loading states use skeleton + "No data for this range" with action.

---

## 4. Dark Premium — from code-complete to shippable

The obsidian palette (`#0A0B0D…#3D4250` surfaces, `#9FA0FF` primary) exists in `color_tokens.dart`. To ship the toggle (P2-UX-5):
1. **Contrast validation pass** with the existing `accessibility.dart` WCAG helpers across all semantic pairs (the certified-pairs list extends to dark).
2. **Component mapping rules:** elevation in dark = lighter surface, not bigger shadow (M3 standard); mesh/watermark opacity ranges shift to the documented 10–22%; glass effects get a darker scrim floor; charts swap to the dark grid token.
3. **Assets:** monoline motifs are single-color strokes — they invert by token, no asset duplication.
4. **Persistence & default:** user toggle persisted (`theme_mode_storage.dart` exists); default stays **Light** (owner decision); "follow system" offered as the third option.
5. Golden re-baseline for persona shells in dark (bounded set, per M15 lesson).

---

## 5. Typography v2

- **Scale unchanged** (the 12-style M3 scale + `kpiValue/kpiLabel/tableHeader/tableCell/monoBody` extensions in `typography.dart` are right).
- **Face:** Inter, bundled. Display/headline 700; `kpiValue` 800 with −0.5 letter-spacing and tabular figures; body/label weights unchanged. Line-height 1.4–1.5 body (already true).
- **Rules the corpus lacked:** max line length 68ch on web reading surfaces; truncation = single-line ellipsis + tooltip (web) / two-line clamp (mobile); never letter-space body text; minimum text size 11 (labelSmall) — nothing smaller, ever.

---

## 6. Motion & perceived speed (fills consolidation gap #1 and #5)

**Tokens (as built, `motion.dart` — now the specified system):** `instant 80ms` (hover/press) · `fast 120ms` (state toggles, chips) · `standard 180ms` (page transitions, sheet raise) · `slow 240ms` (success ceremony, hero transitions). Curves: easeOutCubic in, easeInCubic out. **Ceiling 300ms** — nothing in a school office should ever wait for a flourish. All motion dies under reduced-motion/`disableAnimations` (already wired).

**Choreography rules:**
- Enter = fade+8px rise (mount-fade exists in `premium/`); exit = fade only (leaving must be faster than arriving).
- Shared-element (Hero) only for: avatar → student detail, receipt card → receipt view. Nowhere else.
- Never animate layout under interaction (Adaptive-AI §1.6 rule applies system-wide).

**Perceived-speed budget (binding):**
| Expected wait | Show |
|---|---|
| <150ms | Nothing (render when ready) |
| 150ms–400ms | Subtle inline progress on the triggering control |
| >400ms structured content | **Skeleton** (never spinner) |
| >400ms action/write | Button-integrated progress; optimistic UI only where the write is idempotent + outbox-backed |
| Blocking write (money, publish) | `LoadingOverlay` + explicit result state |

---

## 7. Spacing, radius, elevation — confirmations & one fix

- **8pt scale (`spacing.dart`) unchanged and canonical**, including the semantic tokens (`cardPadding 20`, `sectionPadding 24`, `minTouchTarget 48`). Fix the drift: V1 doc's desktop margin 32 vs code 24 → **24**, wide-desktop gutters come from the 1136 content constraint, not margins.
- **Radius:** per §2 ruling (16/20/24 + input 8, chips 8, buttons 12 as in `radius.dart`).
- **Elevation:** outline-first stays (cards level0 + hairline — it's why the UI feels crisp); tinted shadows only at hover-lift, overlays, and premium hero surfaces. The "soft depth, no hard grey boxes" premium principle is delivered by *tint and radius*, not by shadowing everything.
- **Raw `EdgeInsets` cleanup:** 284 files pass raw values (mostly wrapping tokens); lint rule = `EdgeInsets` literals must reference `AksharaSpacing` constants (P2-UX-3 sweep, mechanical).

---

## 8. Component consistency — the ten mandates (P2-UX-3 lint targets)

Every product screen:
1. Scaffolds via `AksharaAppBar` (persona) or the ONE unified `AksharaModuleScaffold` (admin — folds the 12 per-feature copies, C-ISS-8).
2. Async bodies via `ErpAsyncBody`/`MobileAsyncBody` — no hand-rolled `AsyncValue.when` on product screens (C-ISS-9).
3. KPIs via `AksharaKpiCard`/`AksharaExecutiveKpiCard` variants only — no inline KPI `Card`s (the `dynamic_dashboard_screen.dart` tiles are the named first migration).
4. States via the `AksharaEmpty/Loading/ErrorState` trio + skeletons (§6 budget).
5. Text via `context.text` styles; colors via `context.colors` — lints already implied by V1, now CI-enforced with the contrast checker.
6. Tables via `AksharaVirtualizedDataTable` (+ new density toggle) with `AksharaListCard` fallback <768.
7. Dialogs via `AksharaDialog` sizes; mobile input dialogs = bottom sheets.
8. Forms via the `AksharaFormField` family + wizard doctrine (sticky action bar, unsaved-changes guard, scroll-to-error).
9. Feedback via `AksharaSuccessView` (new, one design) + snackbar rules (§10).
10. Offline via `SyncBanner` + freshness chip — no screen invents its own offline treatment.

**Definition of done for any new screen:** all ten by construction — the checklist is the lint set, not a document to remember.

---

## 9. Content & formatting standards (fills gaps #4, #7)

- **Numbers:** `₹1,24,500` Indian grouping; lakh/crore only on executive surfaces (`₹1.2L` with full value on tap); percentages 0-decimal on dashboards.
- **Dates:** `12 Jul 2026` UI · `12 Jul, 9:42 AM` timestamps · relative ("2h ago") only <24h and always with absolute on tap.
- **Identity display:** Public Student ID (`DPSKKP-0001`) is the human identifier everywhere; UUIDs never render (PSID-5 honored at the design-system level).
- **Error taxonomy → tone:** validation ("Enter marks between 0–80") · permission ("Needs the Finance Manager role") · network ("You're offline — saved and queued") · conflict ("Updated by Priya 2 min ago — review before saving") · server ("Something failed on our side — nothing was charged"). Human, specific, blame-free, action-first. No raw enums, ever (rides P1-CODE-3 + P2-UX-1 dictionary).
- **Voice:** verbs on buttons ("Collect ₹4,500", never "Submit"/"OK" for consequential actions); sentence case everywhere; no exclamation marks in error or money contexts.

---

## 10. Icons, illustration, notifications

- **Icons:** Material Symbols Rounded; Outlined default, Filled = active nav only; sizes 16/20/24/28/40; never color-only meaning (unchanged, now linted).
- **Illustration:** the monoline motif kit (one motif per module) is the brand signature — empty states (primary use), dashboard watermarks at 3–8% light / 10–22% dark, onboarding heroes. Never as decoration on dense data screens.
- **Notifications & snackbars (fills gap #6):** snackbar = transient confirmation only, one at a time, queue-replace not stack, action optional, 4s; banner (`AksharaWarningBanner`) = persistent condition; the notification center anatomy (grouped by module, actionable buttons deep-linking like priority cards) ships with the Adaptive-AI presentation layer — one anatomy shared between "notification" and "priority card" so the product has one interruption grammar.

---

## 11. Responsive layout canon

`breakpoints.dart` is the single source: mobile ≤767 · tablet 768–1199 · desktop ≥1200 · content 1136 in 1440. KPI columns 2/3/4–6. Tables → cards on phones + portrait tablets (`useCardLayout()`). Mobile: bottom nav 80 + safe areas, filters as bottom sheets, FAB or sticky CTA for primary actions. Desktop adds (not swaps): density toggle on tables, hover states, keyboard focus rings 2px/2px offset — the clerk gets an enterprise tool, the teacher gets an app, one codebase.

---

## 12. Governance (fills gap #17)

- **Source of truth:** tokens = code (`lib/theme/`); intent/rules = this guide; mood = `VISUAL_DESIGN_SYSTEM.md`. Any doc re-listing token values must instead link here/to code.
- **Change process:** token changes ship as M15-pattern visual waves — scoped, golden-guarded, EOS-gated, zero logic diffs. Each wave appends to a `## Changelog` section here.
- **Deprecation:** System A docs banner-marked (anatomy reference only); `DESIGN_SYSTEM_V1.md` marked "as-built snapshot, superseded by v2 guide".
- **Enforcement is the system:** the P2-UX-3 lint set (no raw colors/TextStyles/EdgeInsets literals/AppBars, contrast-in-CI, persona goldens) is what makes v2 real on the long tail — a design system that isn't linted is a suggestion.

---

## 13. Execution mapping

| Work | Vehicle | Notes |
|---|---|---|
| Lints + contrast CI + goldens + scaffold/async/KPI consolidation sweeps | **P2-UX-3** | mechanical, golden-guarded |
| WCAG AA pass, dynamic type, semantics verification | **P2-UX-4** | after P2-UX-3 |
| Dark toggle (§4) | **P2-UX-5** | default Light |
| Premium-completion visual wave (palette §2, Inter §5, tinted shadows, canvas rules) | **M15-pattern wave — owner-timed** (natural slot: with/just after P2-UX-3; visual tokens only) | 👤 confirm timing; white-label derivation rule §2 included |
| Skeleton/success/freshness components | **P2-UX-1** (specs in `WORLD_CLASS_UX_POLISH.md` §3) | — |
| Doc banners/demotions | P0-DOC-tier housekeeping | no code |

*This guide is the design-system half of `PRODUCT_EXCELLENCE_MASTER_PLAN.md` — the final phase-5 plan sequences everything above.*
