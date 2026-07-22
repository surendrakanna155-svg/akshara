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
- **P2-2 — Premium surface depth ✅** — light dashboards read flat because white cards sat on a near-white canvas with only a hairline border. Resting/hover cards now get a **soft diffuse float** (`shadows.dart` level-1 → `(0,2) blur 8 spread -2`; opacity curve nudged ~+0.01/level, still < 0.10 at level 2) so they lift gently — elegant, not heavy. Fixed a latent bug: `ColorScheme.shadow` was `onSurface` in **both** modes, painting a *light* halo on dark surfaces (inverted shadow) — dark now uses near-black so elevation drops instead of glowing (dark goldens visually unchanged, correctness restored). App bars gained `scrolledUnderElevation: 3` + a soft shadow so the bar detaches once content scrolls beneath (flat at rest, no color change). Full golden suite re-baselined (59 surfaces picked up the softer float); theme+widget 137/0.
- **P2-3 — Branded SegmentedButton + component gallery ✅** — the M3 `SegmentedButton` (exams/events/leave/messages/intelligence) had **no theme** — raw default Material (pale `secondaryContainer` selected segment). Now branded like the rest of the chrome: an **accent-tinted selected segment** (`primary` @ 14%) with a full-strength `primary` label + checkmark on a hairline outline, 44dp min height. Added a **DS V2 component-gallery golden** (`ds_v2_component_gallery_golden_test.dart`, Light + Dark) that pins the core shared controls (buttons · chips · input · segmented) — most control-heavy screens have no golden of their own, so this is their visual safety net. analyze clean; full golden 72/72 (only the gallery changed — no dashboard renders a segmented button).
- **P2-4 — Persona-cohesive premium surfaces ✅** — the greeting hero / AI bar / premium canvas came from the **fixed** indigo→violet `AksharaPremiumTokens`, so a blue Parent got a *violet* hero — incohesive with the branded nav. New `AksharaPremiumTokens.forAccent(accent)` re-tones every accent-dependent surface (hero + canvas gradients, AI-bar gradient, brand, line-art stroke, and a soft **accent-tinted** hero shadow in light) to the persona hue while keeping the neutral premium surface/border/on-hero (so light heroes stay pale → dark on-hero text still clears contrast). Wired via `_build(accent:)`: `persona()` passes its accent; `light()/dark()` pass `whiteLabel?.primary`. Parent=blue, Student=emerald, Teacher/Admin=indigo heroes now match their chrome. New `ds_v2_persona_hero_golden_test.dart` proves it. analyze clean; full golden 73/73.
- **P2-5 — Persona-themed dashboard golden coverage ✅** — closed the fidelity gap P2-4 flagged: the base dashboard goldens render under `AksharaAppTheme.light()`, but the real app wraps each dashboard in its **persona** theme. Added a `personaAccent` option to `pumpGoldenDashboard` and a `ds_v2_persona_dashboard_golden_test.dart` pinning the parent/student/teacher dashboards under their persona themes — capturing the **cumulative** premium result (P2-1..P2-4) on real screens: cohesive hero + accent chrome + floating cards. Verified by eye: parent reads all-blue, student all-emerald, teacher all-indigo, each premium and cohesive. analyze clean; new goldens 3/3, full golden suite green.
- **P2-6 — Dark-mode persona coverage ✅** — added **Dark** variants of the persona-hero and persona-dashboard goldens (both tests now loop Light + Dark). Verified by eye: the accent re-toning holds in dark — deep blue/emerald/indigo heroes over obsidian, cards floating with correct (near-black) shadows, cohesive per persona. No dark-mode fixes needed. Full golden suite 80/80.

### Known follow-ups (P2 backlog, not owner-gated)
- **Tonal-button hierarchy** — `filledButtonTheme` styles both `FilledButton` and `FilledButton.tonal`, so 22 of 25 naive `FilledButton.tonal` call-sites render as **solid primary** instead of tonal (secondary emphasis). Fixing well needs per-call-site review (some may intend primary) or a theme split that also touches `ElevatedButton` — deferred as judgment-heavy. The `tonalButtonStyle` helper is the intended path (used in the gallery).
