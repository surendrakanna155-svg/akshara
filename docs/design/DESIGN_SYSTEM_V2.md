# Akshara Design System V2

**Status:** ACTIVE (owner-locked 2026-07-21). The long-term design direction for the entire Akshara product. Memory: `akshara-design-system-v2`. Lane: `feature/uxr-flutter-remediation` (Flutter mobile this program; web follows when unfrozen).

## 1. Objective
Evolve Akshara into a **visually premium, modern, polished, enterprise-grade SaaS product** — comparable to modern SaaS in visual quality — **while preserving every certified UX flow and business behavior.** Current UI reads as "too basic / default Material"; V2 raises visual quality (hierarchy, polish, readability), not just recolors.

First-impression target: premium · modern · trustworthy · enterprise · beautiful · clean · consistent.

## 2. One unified system (no more three identities)
Before V2 there were three stacked identities — **M15** (`color_tokens.dart`, `m15_design_system.dart`), **Premium** (`premium_tokens.dart`), and **Stitch** persona palettes (`stitch_palettes.dart`, forced per-persona brightness). V2 collapses to ONE:

- one **design-token** system (colors, type, spacing, radius, elevation, motion) — the M15 unified `AksharaColorTokens.light()` / `.dark()` base is the single source; Premium/Stitch become historical.
- one **typography** (`typography.dart` Roboto scale), one **spacing** (`spacing.dart`), one **elevation/shadows** (`elevation.dart`/`shadows.dart`), one **radius** (`radius.dart`), one **motion** (`motion.dart`), one **a11y** standard (`accessibility.dart`), one component library.
- **one Light theme + one Dark theme.**
- **Persona identity = a subtle ACCENT** (primary hue) + icons/illustrations/branding over the SHARED neutral surfaces — NOT a different UI system per persona.

**Token pipeline is preserved** (a NEVER-CHANGE): consumers keep reading `context.colors` / `context.aksharaText` / the `AksharaThemeExtension`. V2 changes the token *values* and *how a persona theme is assembled*, never the access mechanism.

## 3. Appearance (Light/Dark) must genuinely work
Root `MaterialApp` already wires `theme: AksharaAppTheme.light`, `darkTheme: AksharaAppTheme.dark`, `themeMode: themeModeProvider`. The bug (F-002): each persona **ShellRoute** wraps its subtree in `Theme(data: AksharaAppTheme.stitch(fixedPalette))`, whose brightness is hard-forced (parent=light, teacher/student/admin=dark) — so the setting is a no-op inside every persona.

**Fix:** each shell resolves the effective brightness from `themeModeProvider` (+ platform brightness for `ThemeMode.system`) and builds the unified theme at that brightness with its persona accent. No shell may force brightness. (Resolves old J1/J7.)

### Persona accent map (mid-tone hues legible on BOTH light and dark surfaces)
| Persona | Accent | Notes |
|---|---|---|
| Parent | `#2170E4` (blue) | friendly portal blue |
| Student | `#10B981` (emerald) | gamified energy |
| Teacher | `#6366F1` (indigo) | classroom command |
| Admin / Principal | `#6366F1` (indigo) | executive; may deepen later |

Accents are applied via `AksharaColorTokens.light/dark(primaryOverride: accent)` so they overlay the shared surfaces. (Chosen mid-tone so contrast holds in both modes; refine per-mode variants in a later slice if a11y checks warrant.)

## 4. Visual upgrade scope (improve, don't recolor)
Layouts, spacing, type, padding/margin, radius, elevation/shadows, cards, dialogs, bottom sheets, nav, app bars, buttons, text fields, chips, search, filters, tables, dashboards, charts, AI panels, loading/empty/success/error states, settings, onboarding.

## 5. PRESERVE (presentation only — never change)
Navigation architecture · workflow · business logic · certified UX behavior · persona navigation (≤4-primary+More) · honest-state · parent-OTP model · amber money ceremony · token pipeline · AB/ML/DB semantics · 48dp touch floors.

## 6. Rollout (incremental — never rewrite in one step; analyze + test + golden after EACH slice)
1. **Phase 1 — Foundation ✅ DONE:** unified persona theming that honors Appearance (the 4 shells now resolve brightness from `themeModeProvider` + apply the persona accent over the M15 light/dark base via `AksharaAppTheme.persona`); persona-accent map (`persona_accents.dart`); 4 persona-shell goldens re-baselined to the unified production rendering (F-008 + F-002 resolved). The Light/Dark toggle now works app-wide on one token base. **Note:** the accent currently drives `primary` (buttons/FABs/links/selected states in real screens); the M3 nav + secondary-based chrome stay neutral M15 — making the persona accent *visibly distinct across the nav + chrome* is the **first task of Phase 2**.
2. **Phase 2 — Shared components (persona-accent visibility FIRST, then premium pass):** make the persona accent visible in the nav + chrome (so parent/teacher/student/admin read distinctly), then a premium pass on the reusable widgets (cards, buttons, app bars, dialogs, bottom sheets, chips, inputs, status chips, KPI tiles, empty/error/loading states) — elevation, radius, spacing, hierarchy, motion.
3. **Phase 3 — Shared layouts:** scaffolds, dashboard grids, nav chrome, list/detail shells.
4. **Phase 4 — Screens:** per persona/module, incrementally; re-baseline intended golden changes and eyeball each.

**Owner priority: product quality > engineering effort.** When choosing, pick the more premium, maintainable, polished implementation.

## 7. Phase 2 execution log (branded, premium)
Each slice: `flutter analyze` clean → touched tests green → golden re-baselined (intended) + eyeballed → independently committed. Full list in `docs/roadmap/UXR_FLUTTER_LANE_LOG.md`.

- **P2-1 — Branded persona nav chrome ✅** — the selected item in the bottom nav / rail / drawer now reads in the **persona accent**: a full-strength `primary` icon + label on a crisp accent-tinted **stadium** pill (`primary` @ 16% bottom nav / 14% rail / 12% drawer). Replaces the washed M3 `primaryContainer` pill + dark `onPrimaryContainer` icon that made all personas look alike. Contrast holds (16% tint keeps the pill pale enough that the full-strength icon clears 3:1 — asserted in `navigation_bar_highlight_test.dart`). Parent=blue, Student=emerald, Teacher/Admin=indigo now read distinctly in the nav. 4 persona-shell goldens re-baselined.
