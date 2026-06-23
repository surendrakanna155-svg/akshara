# CLAUDE Master Audit — ERP Hardening Execution Status

Single source of truth for the cross-domain authorization/correctness hardening.
Per-domain detail lives in code + tests; this file tracks **status only**.

Legend: ✅ done & certified · 🟡 in progress · ⬜ not started

---

# ✅ WORKSPACE & UX CONSOLIDATION = COMPLETE (all batches 1–5, 2026-06-23)

> ERP Hardening + Domain Certification = **COMPLETE** (everything below the divider).
> Phase goal was: make Akshara feel **simple, modern, fast, beautiful, premium —
> demo-grade so schools buy on sight.** NOT adding features/modules/domains.
> **STATUS: all 5 batches done & certified; the two final items were owner decisions,
> now made (verticals shelved behind a disabled flag; phase4/5 fold-in skipped).
> No open Flutter-side audit work remains — next work is backend-dependent (mocks).**
> Audit-driven (WORKSPACE_ARCHITECTURE_AUDIT, MASTER_RECOMMENDATION_REPORT,
> UI_UX_AUDIT_REPORT, MOBILE_FIRST_AUDIT, SCREEN_CONSOLIDATION_REPORT,
> REAL_WORLD_SCHOOL_AUDIT, PROJECT_HEALTH_AUDIT, IDEAS_BACKLOG).
> Batches: 1 Workspace Architecture Enforcement · 2 Navigation Simplification ·
> 3 Mobile-first · 4 Dashboard modernization · 5 Screen consolidation.
> Per batch: Audit → Plan → Implement → Test → Certify → update this file.

## 🎨 VISUAL DESIGN SYSTEM — APPROVED DIRECTION (2026-06-20)
Owner reviewed the live app (real-font renders) and judged it "generic ERP/
government portal." Decision: adopt a **"Premium School OS"** visual system —
Akshara must feel like a premium modern product, not a traditional ERP. Full spec:
**`docs/design/VISUAL_DESIGN_SYSTEM.md`**; owner-approved concept renders:
`docs/design/mockups/parent_home_light.png` + `parent_home_dark.png`.
- **Theme decision:** **Premium Light = default**, **Dark Premium = mode toggle**
  (build light first, dark after).
- **Core language:** soft gradient canvas · white/dark cards w/ hairline border +
  soft indigo-tinted shadow · indigo→violet brand gradient · status-only color ·
  **subtle monoline line-art illustrations (5–15% opacity)** per module ·
  greeting-hero dashboards · AI suggestion bar + center docked AI action ·
  illustrated empty states · branded workspace landings. Token-driven so the
  future **AI School Builder** can emit per-school themes (color + motif pack +
  workspace set; light/dark per user).
- **Status:** Rollout = Phase A (tokens in `lib/theme/` light-first + shared
  primitives + Parent-home reference screen, certified) → Phase B (dashboards/
  workspaces; folds in Batch 3b mobile work + Batch 4 modernization) → Phase C
  (dark toggle). This system governs Batch 4 Dashboard modernization and informs
  the paused Batch 3b sweep.

### ✅ Phase A — Foundation + Parent-home reference = DONE & CERTIFIED (2026-06-20)
Built the reusable premium layer and applied it to **Parent Home only** (the
visual benchmark for the platform); no other screen touched.
- **Tokens:** `lib/theme/premium_tokens.dart` — `AksharaPremiumTokens`
  ThemeExtension (brand indigo→violet gradient, hero/AI/canvas gradients, soft +
  lifted tinted shadows, premium surface/border, line-art stroke/opacity) for
  **light + dark**, registered in `app_theme.dart`; `context.premium` accessor.
  `withBrand()` is the AI-School-Builder per-school theming hook.
- **Primitives** (`lib/shared/widgets/premium/`, barrel-exported):
  `AksharaLineArt` + `AksharaMotif` (9 monoline motifs — cap/book/chart/growth/
  bus/bookshelf/campus/message/nodes/spark), `AksharaPremiumBackground` (soft
  gradient canvas + faint motif), `AksharaGradientHero` (greeting hero + pills +
  motif), `AksharaPremiumKpiCard`, `AksharaAiSuggestionBar`,
  `AksharaPremiumEmptyState`, `AksharaWorkspaceLanding`, `AksharaMountFade`.
- **Parent Home** rewired to the premium look: gradient hero, premium KPI row,
  premium academic card with gradient progress bar, AI suggestion bar, soft
  canvas. QA keys preserved. Live render verified (real fonts) — premium, not
  ERP/portal. (Entrance `AksharaMountFade` kept in the library but not wired onto
  Parent Home yet — golden/test-timing safety; revisit in Phase B.)
- **AI School Builder / school-type compatibility (design-only, verified):**
  every premium component is data-driven (KPI/hero/workspace stats + motif passed
  in) and the brand is overridable via `withBrand()`, so the builder can emit
  per-school-type dashboards/KPIs/workspaces (IIT/NEET Foundation, Residential,
  Semi-Residential, Corporate, Small, Day) with **no structural change**. Not
  built — only enabled. (`docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md` §1–4.)
- **Certified:** `flutter analyze` **0 errors** (new code clean; only pre-existing
  warnings in workspace_switcher/glass remain); parent goldens regenerated; full
  Flutter suite **2157 pass** (1 staging-only skip). Bugs caught & fixed in
  certification: a Stack-collapse + an infinite-height (unbounded Stack) + three
  text-overflow cases (hero pills, KPI row, academic header) surfaced only at 2×
  text scale / long-data stress.
- **STOP per owner:** Parent Home is the approved reference; do NOT roll to other
  screens until owner reviews the live Parent Home. **(Owner approved 2026-06-20 →
  Phase B rollout underway.)**

### ✅ Phase B — Platform rollout = DONE & CERTIFIED (all sub-batches B.1–B.4)
- **B.1 — Consumer dashboards = DONE & CERTIFIED.** Teacher + Student dashboards
  rewired to the premium look (gradient canvas + `AksharaGradientHero` + premium
  AI bar; teacher motif=book, student motif=growth). Robustness fixes: AI bar
  action button made `Flexible` (overflow at narrow/tablet + long data). Full
  suite **2157 pass**; consumer goldens regenerated.
- **B.2 — App-wide AI surface = DONE & CERTIFIED.** Instead of swapping 57 call
  sites, **retrofitted `AksharaInsightCard` to render the premium
  `AksharaAiSuggestionBar`** — every AI insight across the app (finance, HR,
  library, hostel, transport, inventory, management, director, alumni, SIS,
  admissions, parent/student/teacher sub-screens…) now shows the consistent
  brand-gradient AI bar with **zero call-site churn**. All premium widgets made
  defensive (`premiumOrNull ?? light()`) so bare-theme tests don't crash. Admin
  dashboards keep their breadcrumb chrome (correct for a web ERP — gradient heros
  are for consumer greeting screens only). Full suite **2157 pass**; all goldens
  regenerated.
- **B.3 — Workspace landing pages = DONE & CERTIFIED.** Wired the prebuilt
  `AksharaWorkspaceLanding` hero into the admin hub
  (`admin_hub_screen.dart`): brand-gradient banner with workspace name +
  line-art motif + 2–3 curated headline stats, above the module grid. Per-
  workspace config (motif + eyebrow + stats) lives in
  `lib/features/admin/workspace_landing_config.dart` — curated demo figures for
  all 7 staff workspaces (Administration, Finance, Front Office, Inventory,
  Transport, Hostel, Library); name-only fallback for any without a config.
  Fixed a latent overflow in the shared primitive (stats `Row`→`Wrap`, so it
  reflows on phones instead of overflowing). Full suite **2157 pass**, analyze
  0 err; only the `workspace_switcher` golden regenerated.
- **B.4 — Fold in paused Batch 3b mobile sweep = DONE & CERTIFIED (all 5 sub-batches).**
  Decisions: table sweep done in one pass (all ~67 widgets isMobile→useCardLayout
  + 9 unguarded tables get card fallback); shared wizard = build primitive +
  adopt one flow (migrate the other 6 later). Order: a) AI notch, b) bottom-sheet
  filters, c) Director responsive, d) shared wizard primitive, e) table sweep.
  - **B.4a — AI-center notch in admin/staff mobile nav = DONE & CERTIFIED.** The
    persona shells already floated the `CopilotBottomNavAiSlot`; the admin shell's
    `AdminBottomNav` did not. Wrapped its `NavigationBar` in the same
    `Stack(clipBehavior: Clip.none)` + slot, so staff get the raised center AI
    button (self-gates on AI-access pref + mobile breakpoint; routes staff to the
    full ERP copilot). Full suite **2157 pass**, analyze 0 err, no golden churn
    (slot gated off in default golden state).
  - **B.4b — Bottom-sheet filters = DONE & CERTIFIED.** `AdminFilterBar` (rendered
    centrally by `AdminContentScaffold`, so one fix covers every module using
    `showFilterBar`) now branches on `AdminLayout.isMobile`: tablet/desktop keep the
    inline chip strip (extracted verbatim to `_InlineChips`); phones collapse to a
    compact "Filters" pill (`_MobileTrigger`) showing the active filter, which opens
    a drag-handle `showModalBottomSheet` (`_FilterSheet`) with options stacked +
    check on the active one. Same `filters`/`selectedIndex`/`onFilterSelected`
    contract — zero caller changes. Added 3 qa keys + `admin_filter_bar_test.dart`
    (3 cases: desktop inline, phone trigger, sheet-select fires callback). Certified:
    analyze 0 err, full suite **2160 pass** (+3 new). Golden delta = the **8 mobile
    filter-bar goldens** only (390/428 for approval_center, finance/management/
    inventory dashboards) — proven isolated: the pre-regen run mismatched only those
    8; 834/desktop goldens were untouched (isMobile gate). Regenerated just the 2
    affected test files.
  - **B.4c — Director portal responsive = DONE & CERTIFIED.** Fixed every phone
    breakage in `lib/features/director/`: (1) **content-card Wraps** now stretch
    full-width on phones (gate `AdminLayout.isMobile`, portrait tablets keep the
    grid) — `DirectorKpiRow` (was 240×140 floating tiles), dashboard school cards
    (320), and reports cards (**360 → overflowed the ~358px phone column**, now
    full-width via extracted `_reportCard`). (2) **3 unguarded DataTables** get a
    card fallback (gate `AdminLayout.useCardLayout` = phones **+** portrait tablets,
    the B.4e end-state so no double-touch): `_SchoolCard` (schools, 8 cols),
    `_RevenueCard` (revenue, 5 cols), `_ComplianceCard` (compliance, 7 cols — keeps
    the Acknowledge button + its qa key + snackbar via a shared `_acknowledge`
    handler used by both table row and card). (3) **Bonus fix surfaced by the phone
    shot:** the filter-bar trailing `DirectorAiAssistantLink` (~200px labelled
    button) overflowed the mobile filter bar by 24px next to the B.4b "Filters"
    pill — now collapses to a compact `IconButton.filled` (label → tooltip) on
    phones. Certified: analyze 0 err, full suite **2160 pass** / 1 skip / 0 fail
    (2 finance tests flaked once under full-suite concurrency, pass in isolation +
    on clean re-run — untouched by B.4c). No director golden coverage exists, so no
    golden churn. Screenshots (schools + compliance @390) verified the card
    fallbacks + non-overflowing AI icon.
  - **B.4d — Shared multi-step wizard primitive = DONE & CERTIFIED.** Built two
    shared primitives in `lib/shared/forms/` (barrel-exported): (1)
    **`AksharaStepIndicator`** (`stepLabels` + `currentIndex`, no enum coupling) —
    generalizes the old `AdmissionsEnrollmentStepIndicator`. **Responsive:**
    tablet/desktop keep the full numbered-circles + connectors + labels row;
    **phones** collapse to a compact `Step N of M` eyebrow + current-step title +
    `Next: …` hint + a thin `LinearProgressIndicator` (the 4-label circle row is
    too cramped at ~358px). (2) **`AksharaMultiStepForm`** — the wizard chrome
    every flow repeats: optional `Form(formKey, autovalidateMode)` → scrollable
    `[indicator + content]` in an `Expanded` → `Divider` → footer
    `Row(leading? · Spacer · trailing)`. Host keeps state/validation/scroll.
    **Adopted in admissions enrollment ONLY** (B.4d scope): rewired
    `admissions_enrollment_screen.dart` onto `AksharaMultiStepForm` (passes
    `EnrollmentStep` labels + index, the `_formKey`/`_scrollController`, Back as
    `leading`, Continue/Submit as `trailing` via `_buildPrimaryAction`); deleted
    the superseded `admissions_enrollment_step_indicator.dart` (nothing else
    referenced it) + dropped the now-unused `spacing` import. Other 6 wizard flows
    migrate later. Coverage: `akshara_step_indicator_test.dart` (desktop full row /
    phone compact + progress value / last-step no-Next + full bar) +
    `akshara_multi_step_form_test.dart` (indicator+content+trailing render,
    leading optional, Form-wrap on/off). Certified: analyze 0 err, full suite
    **2167 pass** / 1 staging skip / 0 fail (existing enrollment "renders wizard
    steps" + "advances to parent step" tests stay green — behavior unchanged). No
    enrollment golden coverage exists, so no golden churn. Screenshots @390 +
    @1200 verified the compact mobile indicator vs the full desktop circle row.
  - **B.4e — Tables→cards full sweep = DONE & CERTIFIED.** Two parts. **Part A
    (66 files):** migrated every already-responsive table from the phone-only
    `AdmissionsLayout.isMobile` gate to `AdminLayout.useCardLayout` (phones **+**
    portrait tablets), so a dense table no longer overflows a portrait iPad. The
    table gate was always the **direct** `if (AdminLayout.isMobile(context))`
    (often inside a dedicated `_XxxTable` widget); the local-var
    `final isMobile = …` is for charts/maps/grid-columns and was deliberately left
    phone-only. Scoped perl swap of the guard form handled the direct sites; 4
    files whose table is gated via a local var were fixed by hand
    (finance defaulters/collection_detail/discounts → added/renamed a `useCards`
    var, keeping `isMobile` for discounts' header-stacking; hostel/mess menu).
    **Part B (6 unguarded tables):** added a card fallback to the tables that had
    none — admissions reports (source/counselor/status), control-center platform
    intelligence + org trust-intelligence (school comparison), finance
    reconciliation (AP postings), and school-completion substitute-manager +
    teacher-reassignment (row actions preserved: the Select button + its
    `ValueKey`, and the reassignment Checkbox + key, moved into the card's
    `trailing`). Built one shared **`AksharaKeyValueCard`**
    (`lib/shared/widgets/`, barrel-exported): hairline-bordered card, title (string
    or widget e.g. a status chip) + optional trailing action, then `label · value`
    lines — used by all 6 so the fallbacks are consistent. **Why low churn:** the
    swap only changes behavior at portrait-tablet width (at mobile width both flags
    are already true; at desktop both false), so mobile/desktop goldens are
    untouched. Golden delta = the **4 portrait-tablet (834×1194) goldens** that
    legitimately flip to cards (finance/inventory/management dashboards +
    approval_center); regenerated only those two test files. Certified: analyze
    **0 err**, full suite **2167 pass** / 1 staging skip / 0 fail. Screenshots
    verified the finance dashboard card fallback @834 + the shared card look.
- **B.4 = COMPLETE** — all 5 sub-batches (a–e) done & certified.

### ✅ Phase C — Dark-mode toggle = DONE & CERTIFIED (2026-06-22)
Akshara now has a working Settings-only Light/Dark/System switch. Groundwork that
already existed: `AksharaAppTheme.dark()` (M15 obsidian) + premium dark tokens
(`AksharaPremiumTokens.dark()`); `app.dart` already passed `darkTheme:`, but
`themeMode:` was **hardcoded `ThemeMode.light`** (now wired to the pref). All 4
steps complete:
- **C.1 — Theme-mode preference = DONE & CERTIFIED.** Built device-level (not
  per-user) appearance persistence: `lib/theme/theme_mode_storage.dart`
  (`ThemeModePreferenceStorage` — stable `light`/`dark`/`system` storage strings,
  defaults Light) + `lib/theme/theme_mode_provider.dart` (`themeModeProvider`
  Notifier + `themeModePreferenceStorageProvider`). Wired `app.dart` `themeMode:`
  to `ref.watch(themeModeProvider)`. **Robustness vs the mirrored AI-access
  pattern:** the storage provider reads SharedPreferences directly inside a
  `try/StateError` (not `ref.exists`), because the theme is watched at the very
  top of `MaterialApp` build — earlier than any other prefs consumer — so an
  `exists` gate spuriously returned null on first launch. Bare widget tests
  (no prefs override) still default to Light, so existing AksharaApp tests are
  unaffected. Coverage: `test/theme/theme_mode_preference_test.dart` (7 — enum
  round-trip, storage default/persist, provider initial-from-prefs + setThemeMode
  persists). analyze 0 err.
- **C.2 — Toggle UI = DONE & CERTIFIED. Owner decision: SETTINGS-ONLY** (no
  app-bar quick toggle). Built `lib/features/settings/appearance_settings_screen.dart`
  — a premium Light/Dark/System selector (selected card = primaryContainer +
  check) wired to `themeModeProvider`; route `RouteNames.appearanceSettings`
  (`/settings/appearance`) registered in `app_router.dart`. Guard: new
  `_isSharedSettingsRoute` (persona-agnostic, authorized on authentication alone
  like AI-assistant settings) added to `_isProtectedRoute` + `_canAccessRoute`;
  NOT an admin ERP route, so the route-protection-inventory test is unaffected.
  "Appearance" link added to **parent profile, student profile, and management
  settings** (mirroring the AI Assistant link placement). QA keys
  `appearanceSettingsLink` + `appearanceModeOption(mode)`. **~~Known gap~~ →
  CLOSED 2026-06-22 (see "C.2 follow-up — teacher settings" below):** teacher
  persona had no dedicated profile/settings screen, so no Appearance link there —
  now fixed. Coverage:
  `test/features/settings/appearance_settings_screen_test.dart` (3). Certified:
  analyze 0 err (only 2 pre-existing `prefer_const` infos on teacher
  NoTransitionPage routes); affected suites (router, app startup, parent/student
  profile, settings, theme) **148 pass**. Full-suite + dark renders deferred to C.4.
- **C.2 follow-up — teacher settings entry point = DONE & CERTIFIED (2026-06-22).**
  Closed the C.2 known gap: the teacher persona was the one shell with no
  profile/settings screen, so the device-global Light/Dark/System toggle was
  unreachable from it. Added a dedicated **`TeacherSettingsScreen`**
  (`lib/features/teacher/settings/`) — a clean Preferences screen mirroring the
  parent/student pattern (AI Assistant + Appearance `ProfileInfoRow`s reusing the
  shared `aiAssistantSettingsLink` / `appearanceSettingsLink` QA keys, pushing the
  shared `/settings/ai-assistant` + `/settings/appearance` routes). Wired as
  `RouteNames.teacherSettings` (`/teacher/settings`) inside the teacher `ShellRoute`
  and surfaced as a **"Settings" entry in the teacher More tab** (`TeacherShell.navSpec`).
  No guard change needed: `/teacher/settings` is a `/teacher`-prefixed route, so the
  existing persona guard authorizes it for the teacher role (and multi-hat staff who
  hold it); the pushed appearance/AI routes are already shared-settings routes. New
  QA key `teacherSettingsScreen`. Coverage:
  `test/features/teacher/settings/teacher_settings_screen_test.dart` (3 — both links
  render with their keys; tapping each navigates to the shared settings route).
  **Certified:** `flutter analyze` **0 errors** (104 pre-existing warnings/infos in
  untouched files, incl. the 2 known teacher `NoTransitionPage` `prefer_const` infos);
  full Flutter suite **2198 pass** / 1 staging skip / 0 fail (+3). No golden churn
  (no goldens for the teacher shell's More screens). Note: this is a settings entry
  point, not a full teacher *profile* (no teacher profile data model exists yet);
  add profile fields if/when a teacher profile is built.
- **C.3 — Dark-correctness sweep = DONE & CERTIFIED — NO FIXES NEEDED.** Expected
  to be "the big/risky part", but the app was built theme-first so the literal
  sweep came up essentially empty. Comprehensive grep across **all** of `lib`:
  almost every `Color(0x…)` lives in the theme/token files (the source of truth,
  with dark variants); the only feature-screen `Colors.white` (admissions chart
  segment label) is text on a saturated colored bar — correct in both themes;
  premium-widget whites (`akshara_ai_suggestion_bar`, `akshara_workspace_landing`)
  are white-on-brand-gradient — correct; all `BoxShadow`s are theme-color-tinted
  (primary/segment/foreground · alpha), not raw black; named colors
  (green/red/orange/grey) are intentional status indicators; AppBar
  `systemOverlayStyle` already switches on `scheme.brightness` so status-bar icons
  adapt. **Verified by rendering, not just grep:** added `test/golden/
  dark_mode_render_test.dart` (reuses the golden harness with a new `dark:` flag on
  `pumpGoldenDashboard`/`pumpGoldenErpScreen`, default false = zero impact on
  existing goldens) and visually inspected 6 dark renders — parent/student/teacher
  dashboards (390), admin hub/workspace landing + finance dashboard (834), and the
  new Appearance screen. All show dark canvas, preserved brand gradients + line-art,
  readable status colors, **no white patches / no invisible text**.
- **C.4 — Certify = DONE.** `flutter analyze` **0 errors** (36 warnings + 68 infos
  all pre-existing in untouched files; none in any Phase-C file). Full Flutter
  suite **2183 pass** / 1 staging-only skip / 0 fail (+16 vs prior 2167: 7
  theme-mode + 3 appearance-screen + 6 dark-golden). The 6 dark renders are kept as
  committed dark goldens (the "few dark goldens" C.4 called for), locking in
  dark-correctness against future regressions.
- **Note:** UX Batch 3b (mobile-first sweep) was **PAUSED** pending this visual
  direction (F1 breakpoint helper + #7 KPI text-scale heights already landed &
  green; #8/#5/#9/#10/#4 pending). With Phase C done, it can resume folded into the
  visual rollout so screens are swept and restyled in one pass, not twice.

### ✅ UX Batch 3b — Mobile-first carry-over = DONE & CERTIFIED (2026-06-22)
On audit, the only carry-over still open was **#9 (shared multi-step wizard)** —
B.4d built the `AksharaStepIndicator` + `AksharaMultiStepForm` primitives and
adopted them in admissions enrollment only, leaving the *other wizard flows* to
migrate later. (#4 AI slot, #5 Director responsive, #8 tablet tables, #10
bottom-sheet filters, #7 card heights were all already done in 3a/B.4.) Found and
migrated **8 remaining wizard flows** off bespoke chrome (mostly Flutter's raw
`Stepper`, cramped/non-premium on phones) onto the shared responsive primitive:
- **Full `AksharaMultiStepForm`** (true Back/Next forms, one active step + pinned
  footer, bounded-height): `multi_school/school_onboarding_wizard_screen`,
  `school_config/school_discovery_screen`, `evolution/setup_wizard_screen`
  (dynamic steps), `organization_builder/organization_builder_interview_screen`
  (7-step).
- **`AksharaStepIndicator` only** (screens where the stepper was just a progress
  display, or that live in an existing scroll body — swap the indicator, keep the
  flow): `continuity/continuity_migration_screen`,
  `school_completion/substitute_manager_screen` +
  `teacher_reassignment_screen` (native `Stepper`→indicator + plain step blocks,
  all qa keys/notify switches/assign buttons preserved),
  `sis/academic_operations/sis_promotion_screen` (bare "Step 1–5" chips → named
  responsive indicator), `onboarding/unified_onboarding_flow_screen` (9-step;
  bare `LinearProgressIndicator` → indicator).
- **Test fixes:** two `school_completion` tests used a bare `MaterialApp` (no
  `AksharaAppTheme`) — added the theme so the indicator's `context.aksharaText`
  resolves (same precedent as the Phase C appearance screen). Added qa key
  `schoolDiscoveryContinueButton`.
- **Result:** every multi-step flow in the app now shares ONE wizard look that is
  responsive by construction (numbered-circle row on tablet/desktop, compact
  "Step N of M" + progress bar on phones). No more raw `Stepper` in feature
  screens.
- **Certified:** `flutter analyze` **0 errors** (only pre-existing infos remain,
  incl. 3 `DropdownButtonFormField(value:)` deprecations in untouched
  unified_onboarding code); full Flutter suite **2183 pass** / 1 staging skip / 0
  fail (no regressions; the migrated-screen widget tests pumpAndSettle the real
  screens at 800px + 1440px, proving the bounded-height `Expanded` is correct).
  Render screenshots @390 + @1200 verified the compact-vs-full indicator and the
  pinned footer (temp goldens, not committed). **UX Batch 3 (3a + 3b) = COMPLETE.**

## ✅ UX Batch 5 — Screen Consolidation = DONE & CERTIFIED (completed 2026-06-23)
Goal reframed by owner (2026-06-22): the bar is **stable, production-ready, no
leaks/gaps, complete the full work** — NOT demo polish. Consolidation is pursued
for production code health, and every step is certified at the production bar
(analyze 0 err + full suite green). Driven by `docs/SCREEN_CONSOLIDATION_REPORT.md`
(2026-06-18), re-verified against current code first.

**Audit-vs-current deltas found (2026-06-22):** several report items are already
done — `academic/`→`academics/` merge complete. (§E dead-actions were *thought*
closed because the narrow `onPressed/onTap/onAction: () {}` patterns were clean —
but a custom-param-name sweep later found a real cluster; closed for good in
**Batch 5E** below.) **Batch 4 (Dashboard modernization):
in-scope *visual* work is already done** via the Premium-School-OS Phase B rollout
(consumer dashboards, app-wide AI bar, workspace landings); the OWNER_DASHBOARD_AUDIT's
remaining items (export wiring, KPI drill-down, write actions, notification center)
are **functional features**, tracked separately — not visual/consolidation work.

### ✅ 5a — `inventory_distribution/` → `inventory/distribution/` = DONE & CERTIFIED (2026-06-22)
Merged the standalone `inventory_distribution/` feature folder (4 files:
distribution + replacement screens, models, mutations provider) into
`inventory/distribution/` (it now sits beside inventory's other subfolders —
procurement/assets/vendors/…). 52→51 feature folders. `git mv` (history
preserved); fixed relative-import depth in the 3 moved files (`../../`→`../../../`,
`../phase4`→`../../phase4`) + the moved test files' `test_helpers` import; updated
all 8 external import sites (mock/api/interface repos, `phase4_navigation.dart`,
2 widget tests, 1 contract test) from `features/inventory_distribution/` to
`features/inventory/distribution/`. Route paths (`/inventory/distribution`) + qa
keys already read "inventory/distribution" — unchanged. **Certified:** flutter
analyze **0 errors**, full suite **2183 pass** / 1 skip / 0 fail.

### ✅ 5-HARDENING — Production leak/gap hunt + fixes = DONE & CERTIFIED (2026-06-22)
Owner reframed the goal to **stable, production-ready, close every leak/gap**. Ran
a parallel audit (authorization/routing leaks · dead/stub actions · half-wired
flows) over the whole app and closed the real findings:
- **🔴 HIGH — privilege escalation in `erpRoutePermissionFor` (route_guards.dart) =
  FIXED.** The route→permission resolver iterated `kErpRouteViewPermissions` in
  insertion order and returned the **first** prefix match, so a specific child
  route resolved to its broader parent's (weaker) permission: `/finance/intelligence`
  → `viewFinance` (not `viewFinanceIntelligence`), `/finance/executive` →
  `viewFinance`, `/inventory/copilot` + `/inventory/lifecycle` → `viewInventory`
  (not `viewInventoryIntelligence`), `/intelligence/teacher-effectiveness` →
  `viewStudentRisk` (not `viewTeacherEffectiveness`). Roles holding only the broad
  perm (principal/VP/management/storekeeper) wrongly reached the specific screens.
  Fixed to **longest-prefix match** (most-specific key wins); also closes the
  latent `/inventory/distribution` case. Regression tests added to
  `route_protection_inventory_test.dart`: (a) the 6 nested routes resolve to their
  specific permission, (b) a role with only the parent perm cannot reach the child.
- **Dead/stub UI controls (audit §E follow-through) = FIXED (15 controls).** 13 AI-
  insight cards passed `onAction: () {}` → a visible, labeled, tappable button that
  no-ops (`AksharaInsightCard` renders the CTA only when `onAction != null`); set to
  `onAction: null` so the dead CTA is suppressed and only the honest insight text
  shows (control_center/success, hostel/attendance, sis/dashboard ×2, student/
  attendance, parent/homework, admissions/dashboard, admissions/documents, hr/
  performance, hr/leave, finance/collection_detail, finance/discounts, finance/
  defaulters). Admissions follow-ups table dead row-action (`onAction: (_) {}`)
  dropped → IconButton renders in its honest disabled state. Finance receipt-link
  tile was a fake button (`onTap: () {}` + `Semantics(button:true)`) whose only
  target `parentReceiptRoute` is a **parent-shell** route that the cross-shell guard
  would bounce from admin — converted to a static display row (no admin receipt view
  exists yet).
- **Verified SAFE (no leak):** out-of-scope verticals fully locked down (no school
  role holds healthcare/salon/restaurant/accommodation/whiteLabel/industry/platformOps
  perms — superAdmin only); cross-shell entry blocked; Control Center double-gated;
  no unauthenticated-reachable route. Several OWNER_DASHBOARD_AUDIT gaps were
  confirmed **already wired** (MG-08 settings save, FY/Q filter→repo requery, main
  executive KPI drill-down, Management/HR/Finance-exec exports).
- **M3 — ✅ DONE 2026-06-22 in Batch 5d (see "M3 — DONE & CERTIFIED" below): gated
  behind a chain flag (`ChainScope` + `isChainOrgProvider`).** (original finding kept for context:)
  `principal`/`vicePrincipal`
  (and `schoolAdmin`) hold `viewFranchiseOperations`/`viewMultiSchoolOperations`/
  `viewOrganizationBuilder`, so a *single-school* principal can reach franchise /
  multi-school / org-builder screens. Code comments mark this as intentional for
  chains — needs owner's call on whether single-school principals should manage
  franchises. Also minor: a few export buttons show an honest "preview only — pipeline
  not connected" snackbar (by-design pilot behavior), and ~18 operational Add/Edit
  buttons show "recorded in preview mode (no server write)" — both truthful, not dead.
- **Certified:** flutter analyze **0 errors**, full suite **2185 pass** / 1 skip / 0
  fail (+2 route-protection regression tests; no golden churn — affected screens lack
  golden coverage).

### ✅ 5b — AI surface (report C5): fold `ai_content/` → `copilot/content/` = DONE & CERTIFIED (2026-06-22)
Consolidated the AI surface into the single copilot AI module. **Scope correction
from the report:** C5 also proposed moving `inventory_copilot_screen` as a "stray
AI screen that duplicates the copilot surface" — on inspection it does **NOT**
duplicate the copilot chat; it's a distinct inventory **forecasting** screen wired
to `inventory_intelligence_provider` and living beside it in
`inventory/intelligence/`. Moving it would *fragment* inventory intelligence
(split screen from its provider), so it was **left in place** (same judgment as the
phase4/phase5 deferral). The real, defensible C5 work done:
- `git mv` the 4 `lib/features/ai_content/*.dart` files → `lib/features/copilot/content/`
  (history preserved); `ai_content/` folder removed (52→51 top-level feature folders
  net for 5b; one fewer). Fixed relative-import depth in the moved files
  (`../../core/`→`../../../core/`, `../../shared/`→`../../../shared/`); sibling
  imports unchanged.
- Moved the route builder `aiContentRouteBuilder` from the `phase5_navigation.dart`
  grab-bag into `lib/router/copilot_navigation.dart` (AI routes now live with the AI
  module's nav), dropping the now-unused `ai_content` import from phase5_navigation.
  `app_router.dart` already imports `copilot_navigation.dart` (line 75) so the
  builder resolves with **no app_router change**. Route name/path (`/ai-content`),
  the route-guard entry (`runAiCopilot`), and all QA keys are **unchanged** — zero
  user-facing churn.
- `git mv` the 2 test files → `test/features/copilot/content/`; updated their
  `package:` import paths.
- **Deferred (intentional, same reasoning as phase4/phase5):** a cosmetic
  `copilot/`→`ai/` folder rename (~64 import sites) — high-touch, zero functional
  benefit, nonzero regression risk; the module name "copilot" is accurate. Available
  if owner wants pure clarity later.
- **Certified:** `flutter analyze` **0 errors** (only pre-existing test-file lint
  remains); full suite **2185 pass** / 1 skip / 0 fail (same count — tests relocated,
  not added). No golden churn (no goldens for these screens).

### ✅ 5c — Intelligence hubs (report C3): 4 folders → one `intelligence/` module = DONE & CERTIFIED (2026-06-22)
Collapsed the four scattered analytics folders into the single canonical
`intelligence/` module, using subfolders to avoid filename collisions (both the
old `intelligence/` root **and** `management/intelligence/` had
`intelligence_models.dart` + `intelligence_provider.dart`, so a flat merge was
impossible). New structure:
- `organization_intelligence/` (2 files: trust hub screen + providers) → **`intelligence/trust/`**
- `homework_intelligence/` (2 files) → **`intelligence/homework/`**
- `management/intelligence/` (4 files) → **`intelligence/management/`**

50→48 top-level feature folders (organization_intelligence + homework_intelligence
removed; management/intelligence was a sub-folder). All `git mv` (history
preserved).
- **Depth-aware import fixes.** `trust/` + `homework/` moved depth-2→depth-3, so
  their internal relative imports went +1 level (`../../core/`→`../../../core/`,
  `../control_center/`→`../../control_center/`, `../phase4/`→`../../phase4/`, etc.).
  `management/intelligence/`→`intelligence/management/` is depth-preserving (both
  exactly 2 levels under `features/`) **and** uses no single-`../` parent refs, so
  its files needed **zero** forced edits; only normalized its now-self-referential
  `../../intelligence/operations|unified/` paths to `../operations|unified/` for
  clean code (same target, verified by certify).
- **External importers** (core repos: analytics/homework/phase4 mock+api+interface
  +mapper+dto; routers; tests; golden helpers) fixed by 3 path subs that work for
  both relative **and** `package:` import forms (only the `features/X/` segment
  changes): `features/management/intelligence/`→`features/intelligence/management/`,
  `features/organization_intelligence/`→`features/intelligence/trust/`,
  `features/homework_intelligence/`→`features/intelligence/homework/`. Route
  paths/names + QA keys (`trustIntelligenceScreen`, etc.) are **unchanged** — zero
  user-facing churn.
- **Router fold (mirrors 5b):** the stray 1-route
  `lib/router/organization_intelligence_navigation.dart` was folded into
  `intelligence_navigation.dart` (`organizationIntelligenceRouteBuilder` now lives
  with the other intelligence builders) and deleted; dropped its
  `app_router.dart` import (the builder resolves from the already-imported
  intelligence nav). Left in place by design: the homework route builder
  (in the `phase4_navigation.dart` grab-bag — deferred per report) and the
  management-intelligence builder (in `management_navigation.dart`) — moving those
  is cosmetic, not a fold of a dedicated stray file.
- **Tests** moved to mirror source: trust hub test → `test/features/intelligence/trust/`,
  the 2 management-intel tests → `test/features/intelligence/management/`; fixed the
  trust test's `../../test_helpers.dart`→`../../../test_helpers.dart` (also depth +1).
- **Certified:** `flutter analyze` **0 errors**; full suite **2185 pass** / 1 skip /
  0 fail (same count — tests relocated, not added). No golden churn (route/screen
  visuals unchanged; golden images are name-keyed, not path-keyed).

### ✅ 5d — Org/tenant tier (report C4): 7 folders → one `platform/` module + M3 chain gate = DONE & CERTIFIED (2026-06-22)
Collapsed the biggest fragmentation cluster into one admin-only `platform/`
module, using subfolders (nothing deleted; all `git mv`, history preserved):
- `multi_school`, `branch`, `franchise`, `white_label`, `platform_operations`,
  `organization_builder`, `control_center` → **`lib/features/platform/<name>/`**
  (7→1). Test folders mirrored to `test/features/platform/<name>/`.
- **Depth-aware import fixes.** The 6 flat folders (+ control_center's top-level
  files) all moved depth-2→depth-3, so every escaping `../` import went +1.
  control_center's subfolder (depth-3) files were fixed surgically: single-`../`
  (self) and `../../control_center/` (self-ref, auto-tracks) left untouched;
  `../../<sibling-feature>` and `../../../<lib-dir>` bumped +1.
- **External importers** (core repos: control_center/platform_intelligence/multi_school/
  white_label/platform_operations/organization_builder mock+api+interface+mapper+dto;
  repository_providers; 7 routers; tests; integration/contract suites) fixed by one
  substring sub per folder, `features/X/`→`features/platform/X/`, which covers both
  relative **and** `package:` import forms. The `intelligence/trust/` cross-link
  (`../../control_center/intelligence/platform_intelligence_*`) re-pointed to
  `../../platform/control_center/intelligence/...`. No cross-imports existed among
  the 7. Route paths/names + QA keys **unchanged** — zero user-facing churn.
- **M3 chain-flag gate (implemented here).** franchise / multi-school /
  organization-builder now surface **only when the active org is a chain**:
  - New `AuthClaims.isChainOrganization` (backend-supplied; default `false` =
    single independent school) → `isChainOrgProvider` (`lib/core/config/chain_scope.dart`).
  - `ChainScope` holds the chain-only route prefixes (franchise, multi-school
    portfolio/onboarding, organization-builder + children, school-config discovery)
    and chain-only admin modules (organization-builder). Enforced in `ErpRouteGuard`
    (blocks the route regardless of permission, like `SchoolBuildScope.isRouteHidden`)
    and `adminNavDestinationsProvider` (hides the nav entry).
  - `SchoolBuildScope` no longer hides franchise/organization-builder (moved to the
    runtime chain gate so real chains can reach them); white-label + platform-ops
    stay shelved there per report §B. **Role permissions unchanged** — gating is at
    the route/nav layer, so a single-school principal keeps the perm but can't reach
    the route; a chain principal can.
- **Certified:** `flutter analyze` **0 errors**; full suite **2195 pass** / 1 skip /
  0 fail (+10: new `chain_scope_test.dart` + chain nav/route cases; updated
  `school_build_scope_test.dart` + `admin_navigation_provider_test.dart` +
  `workspace_scoped_nav_test.dart`). No golden churn.

### ✅ M3 — DONE & CERTIFIED (2026-06-22, in Batch 5d): gate franchise/multi-school/org-builder behind a chain flag.
Owner chose: keep the franchise / multi-school / org-builder screens, but only
surface/permit them when the school's org is actually part of a **chain** (multi-
school tenant). A single independent school never sees them; real chains do.
**Implemented in Batch 5d (see above):** `AuthClaims.isChainOrganization` →
`isChainOrgProvider` → `ChainScope` gate in `ErpRouteGuard` + `adminNavDestinationsProvider`;
`SchoolBuildScope` updated. Default is single-school (`false`), so today's behaviour
is "hidden for everyone" until a real chain org is flagged by the backend — matching
"a single independent school never sees them."

### ✅ 5E — Dead-action cleanup (report §E, re-opened) = DONE & CERTIFIED (2026-06-22)
§E was previously marked closed on the strength of a narrow grep
(`onPressed/onTap/onAction: () {}` = 0). A **custom-param-name** sweep
(`<anyParam>: (…) {}`) re-opened it: **19 genuinely dead handlers** under
non-standard param names, all now removed/suppressed so each surface shows its
honest state:
- **`onAiTap: () {}` ×6** (parent attendance/notices/homework/exams/events/leave) —
  `AksharaAppBar.onAiTap` is optional and the AI button only renders `if (showAi)`;
  all six pass `showAi: false`, so the arg was dead **and** the button never showed.
  Removed the dead lines.
- **`onSelectChanged: (_) {}` ×9** (transport attendance/drivers/vehicles/routes;
  hr attendance/recruitment/payroll/performance/leave) — in
  `AksharaVirtualizedDataTable` a non-null `onSelectChanged` wires the row's
  `InkWell.onTap`, so every row showed a **tap ripple + looked interactive but did
  nothing** (no checkbox column was set). Removed → rows are honestly
  non-interactive display rows.
- **`onVerify: (_) {}` ×2** (admissions documents, mobile + desktop layouts) —
  rendered a dead per-row **"Verify"** button; real verification is the **wired**
  checklist Approve/Reject (`runApproveDocument`/`runRejectDocument`). Removed the
  dead arg → the redundant per-row button (`if (onVerify != null)`) is suppressed.
- **`onFilterSelected: (_) {}` ×1** (finance reconciliation) — the screen uses a
  `TabBar`, not the filter bar, and passed `filters: const []` with a no-op handler.
  `FinanceModuleScaffold.showFilterBar` **defaults true**, so simply dropping the
  filter args would have fallen back to the scaffold's **default chips with a null
  handler** (creating 3 *new* dead chips). Correct fix: **`showFilterBar: false`** to
  suppress the bar entirely; removed the now-unused filter args.
- **`onSettingsTap: () {}` ×1** (student profile, via `app_router.dart`) — drove a
  visible **chevron + `Semantics(button: true)`** "App settings — coming soon"
  `ListTile` that went nowhere. Made the affordance conditional on a real handler:
  chevron + button-semantics only render when `onSettingsTap != null`; otherwise it's
  a plain informational "coming soon" row (no ripple, not announced as a button).
  Dropped the `onSettingsTap: () {}` from the route builder (defaults null).
  (Parent profile never passed `onSettingsTap`, so its insight-card CTA was already
  suppressed — no change needed.)
- **Certified:** `flutter analyze` **0 errors**; full suite **2195 pass** / 1 skip /
  0 fail (behavior-only suppression; no new tests, no golden churn — none of the
  removed affordances had test coverage). §E now closed against the broader pattern.

### Remaining Batch-5 items — assessed against current code (honest risk notes)
- **phase4/phase5 fold-in (report A1) — ✅ CLOSED: owner decided SKIP (2026-06-23).**
  Re-check shows `phase4_navigation.dart`/`phase5_navigation.dart` are *router-builder
  collections* for modules that **have no nav files of their own**, so "fold into
  owning modules" would *fragment* into ~10 tiny nav files (worse, not better).
  `phase5` also backs `core/security/phase5_staging_route_manifest.dart` (a
  server-route RBAC regression guard with a passing readiness test). The names are
  ugly but functionally correct + well-tested; a pure rename is high-touch
  (~27 files incl. a security manifest) for **zero functional benefit** and nonzero
  regression risk → not a good production trade. **Owner reviewed the net-negative
  assessment and chose to skip the fold-in permanently** — left as-is by decision,
  no longer an open item.
### ✅ D1 + D2 clarity renames = DONE & CERTIFIED (2026-06-23)
The two pure-clarity folder renames are now done (the third, `copilot/`→`ai/`, is
**declined** — see below). Both were route/QA-key-preserving (persona route paths
and keys are unchanged), depth-preserving (`features/X/` → `features/Y/`, same
level, so internal `../../core/` imports stay valid), and every external reference
was a `package:` import — so each was a clean `git mv` + one substring swap, the
same pattern as 5a–5d.
- **D1 — `features/student/` → `features/student_app/`** (32 import sites + the
  `test/features/student/` folder). Disambiguates the student-facing **app** from
  `student_360/` and the SIS student-records domain. Route paths (`/student/*`),
  the `RouteNames.student` persona constant, and all QA keys are unchanged →
  **zero user-facing churn**. No `../student/` sibling-relative imports existed, so
  no hand edits — pure substring swap.
- **D2 — `features/promotion/` → `features/achievement_promotion/`** (1 external
  importer: `phase5_navigation.dart`). The folder is **achievement / marketing
  promotion** (`AchievementPromotionScreen`, `PromotionImageGenerator`), which
  collided in name with **grade promotion** (`sis_promotion_screen`,
  `promotion_readiness_*`). Renamed to match the classes it already holds; route
  `/promotions` (`achievementPromotion`) is unchanged.
- **`copilot/`→`ai/` (report C5 cosmetic tail) — DECLINED, not deferred.** Unlike
  D1/D2 this is **not** a clarity win: "copilot" is the accurate, specific product
  name; "ai" is strictly vaguer. It would also churn the `/copilot` + `/inventory/
  copilot` routes and the `runAiCopilot` guard for negative clarity value. Renaming
  accurate code to a vaguer name fails the production-code-health bar, so it's
  intentionally left as `copilot/`.
- **Certified:** `flutter analyze` **0 errors** (105 issues, all pre-existing — no
  new lint); full Flutter suite **2208 pass** / 1 staging skip / 0 fail (no
  regressions; goldens are name-keyed not path-keyed, so no golden churn).
- **Shelve `verticals/` (restaurant/salon/healthcare/accommodation) + SaaS/org tier
  — ✅ CLOSED: owner chose SHELVE BEHIND A DISABLED FLAG (2026-06-23).** These are
  real built product lines tied to the multi-vertical / AI-School-Builder future, so
  the owner chose the reversible "hide, don't delete" path over removal. **No code
  change was needed — this is already the implemented state:**
  - `lib/features/verticals/` (healthcare/salon/restaurant/accommodation) and
    `lib/features/industry/` remain in the repo untouched.
  - `SchoolBuildScope` (master flag `enabled = true`, reversible) hides every vertical
    + SaaS/white-label/platform-ops module from admin nav (`isModuleHidden`, wired in
    `admin_navigation_provider.dart`) **and** blocks their routes
    (`isRouteHidden` → `AccessDeniedScreen` in `route_guards.dart`). Verified the
    `startsWith` guard covers all sub-routes (`/healthcare/*`, `/salon/*`,
    `/restaurant/*`, `/accommodation/*`, `/industry/*`).
  - School roles also hold no vertical view-perms (Batch 1 V4), so it's not even a
    latent permission leak — it's locked at the perm, nav, **and** route layers.
  - Reversal path is one line: flip `SchoolBuildScope.enabled = false` to bring
    everything back, or drop a single entry to revive just one module. (Org/tenant
    chain tier — franchise/multi-school/org-builder — is separately gated by the
    runtime `ChainScope` chain flag, default off; see 5d/M3.)
  - Decision is therefore satisfied with the existing flag; nothing further to build.
- **Bigger merges** — intelligence hubs (C3) = ✅ DONE (5c); AI surface (C5) = ✅
  DONE (5b); org/tenant tier (C4) = ✅ DONE (5d, incl. the M3 chain-flag gate).
  All report merges (C1–C5) now complete. Clarity renames D1/D2 = ✅ DONE (above);
  `copilot/`→`ai/` = declined (above). The two final owner-gated items are now
  **both resolved (2026-06-23): phase4/phase5 fold-in = SKIP** (owner accepted the
  net-negative assessment) and **shelving `verticals/` + SaaS/org tier = SHELVE
  BEHIND DISABLED FLAG** (already the implemented state via `SchoolBuildScope` /
  `ChainScope` — no code change needed).

### ✅ Batch 5 / Flutter-side audit = COMPLETE (2026-06-23)
With both owner-gated items closed above, there is **no open Flutter-side audit
work**. All report merges (C1–C5), clarity renames (D1/D2), the dead-action sweep
(5E), and the production leak/gap hunt (5-HARDENING) are done & certified; the two
remaining items were owner decisions, now both made and recorded. The only work
that remains for the product is **backend-dependent** (the app still runs on mocks
— see PROJECT_CONTEXT / "no production backend yet"), which is out of scope for the
Flutter-only audit. Last certified state: `flutter analyze` **0 errors**, full
suite **2208 pass** / 1 staging skip / 0 fail.

## ✅ UX Batch 1 — Workspace Architecture Enforcement = DONE & CERTIFIED (2026-06-20)
All 5 steps complete. Certified end-to-end: `flutter analyze` **0 errors**; full
Flutter suite **2112 pass** (1 staging-only skip); +19 new tests across the steps.
- **Step 1** Multi-role identity (a user holds several roles; permissions union).
- **Step 2** First-class `Workspace` abstraction (lib/core/workspace/) + role→workspace
  registry (many-to-many) + providers (userWorkspaces, activeWorkspace, hasMultiple).
- **Step 3** Persona leaks closed — schoolAdmin/management no longer hold
  Salon/Restaurant/Healthcare/Accommodation/Industry/WhiteLabel/PlatformOps perms
  (superAdmin remains platform owner); nav already gated by SchoolBuildScope.
- **Step 4** Workspace-scoped Admin Hub (grid shows only the active workspace's
  modules) + **premium workspace switcher** (gradient chips) for multi-hat users +
  premium graphic module cards + **QA "Teacher + Inventory" (Surendra) demo persona**.
- **Step 5** Cross-shell leak closed — `/teacher/*` reachable only by staff who
  actually hold the teacher role (multi-hat); non-teaching staff bounced. Also
  removed the latent staff→/parent,/student fall-through.

### Switcher reachability — FIXED (2026-06-20, follow-up; was wrongly deferred)
The earlier "switcher only on Admin Hub" was a **functional gap**, not polish: a
multi-hat user could enter a workspace but not switch to another without returning
to the hub or logging out. Now closed:
- New compact `WorkspaceSwitcherButton` (app-bar pill → "Switch workspace" bottom
  sheet) lives in **every shell's chrome**: `AdminAppBar` (admin/staff) and the
  shared `AksharaAppBar` (teacher/parent/student). Auto-hides for single-workspace
  users, so single-role personas see zero change (goldens stay pixel-identical).
- A multi-role user can move between assigned workspaces **from any screen, any
  shell**, both directions (admin→teacher AND teacher→admin), at any time.
- Startup verified: a multi-hat user lands where the switcher is present.
- `WorkspaceSwitcher` file moved to `lib/shared/widgets/` (it's now cross-cutting).
- Coverage: 3 router integration tests (startup reachable; switch admin→teacher;
  switch back teacher→inventory) + a visual golden of the multi-hat hub.
- Visually validated (golden render): app-bar switcher + gradient active/outline
  chips + workspace-scoped grid + premium gradient module cards.
- Certified: `flutter analyze` 0 errors; full suite **2116 pass** (1 staging skip).

### Original plan (for reference)

**Target model:** USER → ROLE → WORKSPACE → TASK. **Today:** USER → ROLE →
(one flat 22-module ERP grid) → TASK. The WORKSPACE layer is missing.

**Findings — all re-verified against current code (2026-06-20):**
- V1 🔴 No `Workspace` abstraction exists in `lib/` (confirmed: 0 results).
- V2 🔴 Single-role model — `AuthState.role` (auth_models.dart:152) & `erpRole`
  (auth_claims.dart:21) are single-valued; a Teacher+InventoryManager is
  unrepresentable.
- V3 🟠 Flat global grid — `kAllAdminNavDestinations` (admin_navigation_provider.dart:13-190)
  lists 22 modules incl. 6 non-school verticals (Healthcare, Salon, Restaurant,
  Accommodation, White Label, Platform Ops), filtered subtractively.
- V4 🟠 Persona leak — `schoolAdmin` (role_permissions.dart:190-194) & `management`
  (535-547) receive all 5 vertical view-perms; a school admin can see
  Salon/Restaurant/Healthcare. (principal/VP already clean.)
- V5 🟠 Cross-shell leak — any `UserRole.staff` may enter `/teacher/*`
  unconditionally (`app_router.dart:2272-2273`; `route_guards.dart:177-179`).
- V6 🟠 No workspace switcher UI in production (QA-only switcher = logout).

**Scope decision (RESOLVED 2026-06-20 — owner chose MULTI-ROLE REWRITE FIRST):**
build the many-roles-per-user identity model as the foundation, then scope
workspaces on top. Larger/riskier (touches auth/claims/token/test accounts) but
the correct end-state and the true precondition for the workspace model.

**Planned steps (each ends with tests + `flutter analyze` 0-err certification):**
1. ✅ **Multi-role identity model = DONE & CERTIFIED (2026-06-20).** A user can now
   hold several `ErpRole`s. `AuthClaims.erpRoles` is the source of truth (ordered,
   primary first); legacy `erpRole`/`role`/`forRole`/`demoForRole(erpRole:)` kept
   as primary-role shims so all ~60 existing RBAC tests + call sites are
   unchanged. `UserPermissions.forRoles` / `RolePermissionMatrix.permissionsForRoles`
   **union** permissions across all held roles; `RbacService` gains `roles` +
   `hasRole`. Role guards (RoleGuard, ControlCenterGuard) now satisfy on ANY held
   role. Session round-trips multiple roles (toJson writes `roles`; fromJson reads
   `roles`, falls back to legacy `role`). `signInStaff(erpRoles:)` can mint a
   multi-hat session (Step 4 switcher will consume it; demo-login UI wiring +
   Surendra Teacher+Inventory account deferred to Step 4). Proof: Teacher+Inventory
   union has both markAttendance AND manageInventory, neither alone leaks the
   other, neither grants control center. Certified: `flutter analyze` 0 errors;
   full suite **2093 pass** (+7 new multi-role tests; 1 staging-only skip).
2. **Workspace abstraction** — first-class `Workspace` (Teacher, Principal, Exam,
   Finance, Front Office, Inventory, Transport, Hostel, Library + Parent/Student
   app shells) + a many-to-many `role → workspace(s)` registry (now genuinely
   multi-hat). Model + mapping + tests; no UI yet.
3. **Scope trim / strip persona leaks** — remove vertical view-perms from school
   roles; gate non-school verticals out of the default school build's nav. A
   principal/schoolAdmin never sees Salon/Restaurant/Healthcare/etc.
4. **Workspace-scoped navigation + switcher** — replace the flat 22-card grid
   with workspace-scoped nav; premium launcher + hat-switcher for multi-workspace
   users. Demo-grade visuals (new graphic cards, clean hierarchy).
5. **Close cross-shell leakage** — `/teacher/*` reachable only by users whose
   roles include teaching; fix any guard-bypassing routes (principal-command,
   growth). Guard tests.

**Future-readiness check (per phase mandate — design only, validated in step 2):**
- Future school types (IIT/NEET Foundation, Residential, Semi-Residential,
  Corporate, Small) = different workspace SETS over the same abstraction → the
  step-2 `Workspace` + registry supports them as data, no structural block.
- AI School Builder evolution (School Profile → AI config → dynamic workspaces /
  dashboards / nav / cards) sits directly on the step-2 registry: "AI config"
  becomes the producer of the role→workspace map. Step 2 is the enabling layer.
- **Explicit guardrail:** do NOT build future school types or AI School Builder
  now; only ensure Batch 1 doesn't preclude them. (See IDEAS_BACKLOG +
  docs/FUTURE_VISION_AI_SCHOOL_BUILDER.md.)

---

## ✅ UX Batch 2 — Navigation Simplification = DONE & CERTIFIED (2026-06-20)
Goal: ≤5 primary bottom-nav items (4 tabs + a "More" tab), fix the bottom-nav
selected-state highlight, and surface the workspace switcher consistently.
Owner decisions honoured: Admin NavigationRail left as-is (admin mobile → Batch
3); Parent **Messages promoted** to a primary tab; switcher kept in the app bar
**and** surfaced in the More sheet; **Parent done first** (largest UX issue).

- **Step 1 — Shared nav model.** New `PersonaNavSpec` (primary + overflow
  destinations) + `PersonaBottomNav` / `MoreNavSheet`
  (lib/shared/navigation/persona_nav.dart) replace the three hand-rolled
  per-shell `_destinations` lists and `_selectedIndex` ladders. Single source of
  truth — the teacher/student/parent shells now just declare a `navSpec`.
  `PersonaNavDestination.matchPrefixes` carries the route→tab mapping that used
  to drift in the per-shell ladders.
- **Step 2 — Selected-state highlight fixed.** Root cause: the selected bottom-nav
  icon was `scheme.primary` sitting **inside** the `primaryContainer` indicator
  pill — a low-contrast, washed-out highlight. Now `onPrimaryContainer` (matches
  the drawer theme) in `_navigationBarTheme` (lib/theme/app_theme.dart). Fixes
  all three bottom-nav personas at once.
- **Step 3 — "More" tab + ≤5 primary.** Each bottom-nav shell now shows 4 primary
  tabs + a premium "More" grid sheet:
  - Parent: Home · Academics · Fees · **Messages** · More
    (More = Leave, Notices, Events, PTM, Transport, Profile). This **un-buries
    the 8 screens** that were previously folded invisibly into the Home tab —
    the batch's biggest win.
  - Teacher: Home · Classes · Teach · Messages · More
    (More = Timetable, Leave, Parent Concerns).
  - Student: Home · Learn · Schedule · Results · More
    (More = Report Card, Progress, Notices, Profile).
- **Step 4 — Workspace switcher consistency.** Kept in every shell's app bar
  (Batch 1) **and** surfaced at the top of the More sheet (auto-hidden for
  single-workspace users). A multi-hat user can now switch from the More sheet
  too.
- **Coverage (+30 tests):** persona_nav_spec_test (17 — ≤4 primary invariant,
  no-duplicate-routes, every More route lights the More tab not Home, Parent
  Messages-promoted + un-buried decisions), persona_bottom_nav_test (7 — More
  tab/sheet renders, navigates + closes, route-aware selection, switcher shown
  for multi-hat / hidden for single-workspace), navigation_bar_highlight_test
  (6 — selected icon = onPrimaryContainer, light + dark).
- **Certified:** `flutter analyze` **0 errors** (only pre-existing test-file
  lint warnings remain); full Flutter suite **2146 pass** (1 staging-only skip).

---

## ✅ UX Batch 3 — Mobile-first = DONE & CERTIFIED (3a + 3b complete) — split into 3a + 3b
Goal: bring the admin shell to the same phone-quality bar the consumer apps
already meet, and close the remaining MOBILE_FIRST_AUDIT items (#1/#2 were done
in Batch 2). Owner-approved plan: **3a = Steps 1–2** (breakpoints + admin mobile
nav, the deferred-from-Batch-2 headline), **3b = Steps 3–5** (Director portal,
polish cluster, shared wizard + bottom-sheet filters). Owner decisions honoured:
admin gets a **bottom nav + the drawer kept reachable from "More"**.

### ✅ UX Batch 3a — DONE & CERTIFIED (2026-06-20)
- **Step 1 — One breakpoint system (MOBILE_FIRST_AUDIT #6).** `lib/theme/
  breakpoints.dart` is now the single source of truth: added named tiers
  (`tabletMinWidth` 768, `largeMobileMinWidth` 428, `narrowMobileMaxWidth` 360)
  + content widths (`compactContentMaxWidth` 480, `readingContentMaxWidth` 640)
  + helpers (`isTabletUp`/`isLargeMobileUp`/`isNarrowMobile`). `MobileDashboardLayout`
  now forwards to it, and **33 feature files** that had inlined the same raw
  literals (`768`/`480`/`428`) were migrated to reference the canonical
  constants — same values, so zero behaviour change; the win is no future drift.
- **Step 2 — Admin mobile navigation (MOBILE_FIRST_AUDIT #3; deferred from
  Batch 2).** Two parts:
  - **2a Admin bottom nav on phones.** New `AdminBottomNav`
    (lib/features/admin/admin_bottom_nav.dart) gives the web ERP a bottom
    `NavigationBar` on ≤767px — up to 4 of the **active workspace's** modules
    (active module always kept visible) + a "More" tab that opens the full
    module drawer (owner's "bottom nav + keep drawer" decision). Tablet/desktop
    rail untouched.
  - **2b One collapsing sub-nav.** New shared `AksharaModuleSubNav`
    (lib/shared/widgets/akshara_navigation.dart) replaces the **12 hand-rolled**
    horizontal sub-nav strips (Finance 14, Control Center 15, Inventory 10,
    Director 9, … which used to run off-screen with no scroll cue). On phones it
    shows ≤4 inline tabs (scrollable) with a **pinned** "More" button → premium
    bottom sheet of the overflow screens; the selected screen is swapped inline
    so you always see where you are. Tablet/desktop = the original strip.
- **Coverage (+ ~13 tests):** breakpoints_test (canonical thresholds + helper
  boundaries + MobileDashboardLayout-forwarding), akshara_module_sub_nav_test
  (phone collapse, More-sheet, selected-overflow swap, tablet-all-inline),
  admin_shell_test (mobile bottom nav present + drawer reachable; hidden on
  tablet/desktop). Mobile-width dashboard goldens (finance/inventory/
  intelligence/approval) regenerated for the intended collapsed-sub-nav look
  (tablet goldens unchanged — change is mobile-only).
- **Certified:** `flutter analyze` **0 errors**; full Flutter suite **2154 pass**
  (1 staging-only skip).
- **Carry-over to 3b:** Director portal responsive (#5), AI center slot (#4),
  card-height truncation (#7), tablet-portrait tables (#8), shared multi-step
  wizard (#9), bottom-sheet filters (#10).

---

## Batches

| # | Domain | Status | Certification |
|---|--------|--------|---------------|
| — | **Exams** (P1 granular perms + P2 teacher scoping, server) | ✅ | deno authz 5/5; flutter exam 70/70; analyze 0 err |
| 0 | **Cross-cutting safety net** | ✅ | full edge graph `deno check` 0 err; CI gate added; deno unit 491 pass (only live-DB self-test skipped locally) |
| 1 | Finance (invoices/collections/refunds/concessions) | ✅ | already hardened; verified — 76 finance deno tests pass; granular approve perms + self-approve block + scope confirmed |
| 2 | SIS & Attendance | ✅ | **fixed**: attendance correction status endpoint now requires `approveAttendanceCorrection` (was `manageSis` — approval bypass). SIS read/write split verified. 89 deno tests pass |
| 3 | Admissions | ✅ | verified — approve=`approveAdmissions`, manage=`manageAdmissions`, read=`viewAdmissions` across 13 write routes; tests pass |
| 4 | HR / Staff | ✅ | verified — hr read-only (`viewHr`); employee writes `manageEmployees`; staff/student leave approval via granular approve perms; tests pass |
| 5 | Operations (transport/hostel/library/inventory) | ✅ | verified — transport/hostel/library read-only (factory-gated `viewX`, 0 write routes); inventory writes `manageInventory`/`manageAssetLifecycle`/`manageProcurementWorkflow`; tests pass |
| 6 | Governance & Intelligence | ✅ | verified — approval enforces per-type granular approve perms + blocks self-approval; intelligence gated on `viewXIntelligence`; tests pass |

**Whole-backend certification:** full edge graph `deno check` = 0 errors; deno unit suite = 491 pass (only `tenant_isolation_test` needs a live DB — runs in CI/staging).

## Batch 0 — what was done
- **CI gate**: `deno check supabase/functions/api/index.ts` added to `backend_staging.yml` before unit tests — type-checks the entire wired edge graph (not just test-reachable files), so "wired but never compiled" modules can't recur.
- **Fixed pre-existing breakage surfaced by the gate** (53 errors across 18 files), all pre-existing, none caught before because no test imported these modules:
  - Approval: `claims.name` (nonexistent) → dropped; `ApprovalRequestRow` import moved to its canonical source.
  - Attendance handlers: same `withAuth`/`tenantIds`/`claims.userId→sub` bugs as exams.
  - 8 routers: route-lookup ternary typed `| undefined` (benign false-positive, now correct).
  - ~35 `body` null-guards added across memories / parent_experience / promotion / attendance / inventory_intelligence handlers.
  - inventory_intelligence: `jsonResponse(..., 201)` → `{ status: 201 }`; `readJson` null coalesce.
  - parent_experience services: two row/return shape mismatches corrected.

## Batch 1 — Finance (findings)
Audited authz parity; **no fixes needed** — finance was built correctly:
- read = `viewFinance`, write = `manageFinance` (split confirmed across invoices, collections, fee structures).
- refund approval = `approveRefunds` (dedicated handler) ; concession = `approveFeeConcession` (generic approval). Per-type granular approve perms enforced in `approval_handlers` via `approvalPermissionForType`.
- self-approval blocked (`ApprovalSelfApproveDeniedError`); school/org scope enforced + tested.
- Certified: 76 finance deno tests pass.
- Carry-over (minor parity, not a hole): client has `approveFeeStructure` but fee-structure changes are gated by `manageFinance` with no approval flow server-side — wiring a fee-structure approval type is a feature, deferred.

## Exam domain — feature completion (Slices 1–6)
Closed end-to-end: grading engine → workspace hub → marks wiring → approve/publish
→ parent/student results → **report card with class rank** (parent + student;
rank shown per `showRankToParents`; attendance line from the shared attendance
store). Full exam Flutter suite green (84). Deferred by design:
- **Report card remark** — no data model/entry yet; needs a product decision (who writes it, where stored).
- **PDF export** — owner explicitly deferred ("downloadable PDF later").

## ✅ EXAM DOMAIN = CLOSED (100%)
All slices (1–6) + server authz hardening + per-exam-session remarks + PDF report
card complete and certified.
- Remarks: per (student, exam session), class-teacher authored, audit trail,
  shown on report card; app + server parity; only the class teacher may write.
- PDF report card (parent + student share): branding/logo placeholder, student
  details, class/section, subject marks, grades, total, %, rank (only when the
  school enables it), attendance %, class-teacher remark, principal-signature +
  school-seal placeholders; identical layout across grading systems.
- Certified: flutter analyze 0 errors; exam Flutter suite 94 pass; PDF generation
  verified (valid PDF); full edge `deno check` 0 errors; exam/approval server
  tests 12 pass.
- Deferred by owner: nothing blocking. ~~(Future extension: principal / vice-
  principal remarks — schema already allows those author roles.)~~ **→ DONE &
  CERTIFIED 2026-06-23 (see "#16 PRINCIPAL/VP EXAM REMARKS" below).**

## ✅ #16 PRINCIPAL/VP EXAM REMARKS = DONE & CERTIFIED (2026-06-23, Flutter-only, mock-backed)
Closed the exam-domain "future extension": the principal / vice-principal can now
author a report-card remark, distinct from the class-teacher remark, with **no
schema change** — the `ExamRemarkAuthorRole` model already permitted those roles.
Real report cards carry *both* a class-teacher line and a leadership line, so the
design uses **two independent remark slots** per (student, exam session) rather
than one author overwriting another.
- **Store (`exam_administration_store.dart`):** `_remarkKey` now carries a slot
  suffix (`teacher` | `leadership`); `remarkFor(examId, sis, {leadership})` reads a
  slot; `upsertRemark` derives the slot from `authorRole.isLeadership`
  (principal/VP → leadership, everyone else → teacher). Snapshot import re-keys by
  the author role's slot. The class-teacher path is unchanged (slot defaults to
  teacher), so all existing remark tests + the teacher authoring screen are
  untouched.
- **Model (`exam_remark.dart`):** added `ExamRemarkAuthorRoleX` extension
  (`isLeadership`, `reportCardRemarkTitle` → "Class teacher remark" / "Principal's
  remark" / "Vice Principal's remark").
- **Report card (`exam_report_card.dart`):** `ExamReportCard` gained
  `remarkAuthorRole` + `leadershipRemark`/`leadershipRemarkAuthorName`/
  `leadershipRemarkAuthorRole`; the builder tracks the most-recent remark **per
  slot** across the term's sessions.
- **Display:** in-app `ReportCardView` and the PDF export both render the
  class-teacher and leadership remarks as separate titled blocks (role-aware
  titles), via a shared `_RemarkBlock` widget / `_remarkBlock` PDF helper. New QA
  key `reportCardLeadershipRemark`.
- **Authoring surface:** principal/VP hold `manageExamMarks`, so they already reach
  the exam **marks-entry** screen. Added a per-student "Leadership remark" icon
  button to each row, **role-gated** by `canAuthorLeadershipExamRemarkProvider`
  (principal *or* vice-principal; resolves to principal when both are held) — a
  coordinator/teacher sees no button. The dialog mirrors the teacher's; saving
  stamps the author's role via `saveLeadershipExamRemark` (author id/name from the
  auth session, role from `examLeadershipRemarkRoleProvider`). Post-publish the
  student list stays reachable for leadership via a new "Student remarks" button in
  `ExamLifecycleActions` (published phase only), so a remark can still be added/
  edited after results are out. New QA keys `examLeadershipRemark{Field,SaveButton,
  Button}` + `examAdminReviewRemarksButton`.
- **Coverage (+5):** report-card builder — leadership + teacher slots coexist
  without overwrite; VP shares the leadership slot (createdAt preserved, teacher
  slot stays empty). `ReportCardView` renders both blocks with role titles. Marks-
  entry screen — principal authors a leadership remark end-to-end (persists in the
  leadership slot); non-leadership staff see no button. PDF test extended to carry
  the leadership remark.
- **Certified:** `flutter analyze` **0 errors** (no new lint — working tree 105
  issues, all pre-existing, vs 123 on HEAD); full Flutter suite **2208 pass** / 1
  staging skip / 0 fail (+5).

## ✅ FEES & PAYMENTS = CLOSED
Payment loop now works end-to-end: a confirmed payment marks the installment
paid, lowers the amount due, updates progress, and adds a receipt to history
(was previously static). Receipt PDF download/share added (real PDF). Report
card PDF reused from exams. Certified: app analyze 0 errors; fees/payments/
finance suites 67 pass; PDF generation verified.
Carry-over: live Razorpay server path exists but is exercised only in
CI/staging; the in-app experience runs on the mock loop.

## ✅ ATTENDANCE = CLOSED
Teacher marks attendance → updates the parent KPI AND now the student view
(student was previously static; merge centralized in
MockAttendanceSyncStore.mergedMonth, used by both). Correction flow (submit →
principal approve, gated on approveAttendanceCorrection — Batch 2) updates the
sync store. Certified: app analyze 0 errors; attendance suites 16 pass (incl. F5
correction submit→approve integration).
Carry-over: aggregate class counts drive the single-primary-student mock;
per-student daily records are a backend (F-series) concern.

## ✅ MESSAGES & NOTICES = CLOSED
School broadcast → now reaches the targeted audience's notices (parents and/or
students), newest first, on top of the standing notices (was static before).
Existing pieces confirmed: teacher→parent concern inbox (read/acknowledge,
governance-gated), parent/student notices, language localization. Certified:
app analyze 0 errors; communication/notices/messages suites 17 pass.

## ✅ ADMISSIONS = CLOSED (already complete — verified, no fixes)
Full chain works end-to-end and is store-backed: lead → application → documents
→ approve → fee handoff ("Ready for fee setup") → SIS conversion queue (via
MockAdmissionsSisBridge). approveAdmission creates the handoff; submitEnrollment
queues the SIS conversion; admissions→finance bridge persists fee assignment.
Server authz certified earlier (Batch 3: approveAdmissions / manageAdmissions /
viewAdmissions). Certified: admissions feature + integration (e2e journey,
admissions→finance e2e) + SIS-bridge + write-contract suites all green (~78);
app analyze 0 errors. No code changes required.

## ✅ HOMEWORK = CLOSED
Loop complete: teacher assigns → student sees → student submits → teacher
reviews → grade + comment now reach the student AND parent (was teacher-side
only). Shared SchoolHomeworkStore records review per (homework, student);
student/parent items show a "Reviewed · Grade X — comment" line. Certified: app
analyze 0 errors; homework suites 13 pass.
~~Carry-over: full per-student "reviewed" lifecycle status (vs the additive
grade/comment line) would need a status-enum change across both apps — deferred.~~
**→ DONE & CERTIFIED 2026-06-22 (per-student reviewed lifecycle):** added
`reviewed` as a first-class terminal value to `StudentHomeworkStatus` +
`ParentHomeworkStatus` (lifecycle: pending → submitted → reviewed; overdue =
unsubmitted+past-due). The store now derives status **per (homework, student)** —
`toStudentItem`/`toParentItem` return `reviewed` when a review exists for *that*
student, so classmates on the same assignment stay at submitted/pending until
each is graded. `reviewed` is a sub-state of submitted: new `status.isSubmitted`
helper backs the KPI `submittedCount` and the "Submitted" filter (both now include
reviewed); added `reviewedCount`. Both list rows render a distinct "Reviewed" pill
(student: primary-tint; parent: `KpiAccent.primary`) and the grade line dropped its
now-redundant "Reviewed · " prefix (→ "Grade A — comment"). API enum codecs are
`.name`-based so the new value round-trips with no contract change. Coverage:
extended `homework_review_loop_test` (status→reviewed end-to-end + per-student
isolation: classmate does not flip) + new `homework_status_lifecycle_test` (label/
isSubmitted/count semantics for both personas). Certified: analyze **0 errors**;
full suite **2203 pass** / 1 staging skip / 0 fail (+5). No golden churn (mock
data carries no reviewed items, so default renders are unchanged).

## Everyday loops — status after the closing sweep
Closed & tested: Exams, Fees & Payments, Attendance, Messages & Notices,
Admissions, Homework, plus **Leave** (parent requests → principal approves →
parent sees approved/rejected; verified — `applyDecision` updates the parent's
own list; approval integration suites green).

Remaining areas are a **different kind of work** (no clean broken loop to close):
- **Timetable** — persona views render static weekly schedules (functional); a
  big integration would wire the academics scheduler/editor → teacher/student/
  parent grids. Large project, not a one-gap fix.
- **Transport / Library / Hostel / Inventory** — admin/operational modules that
  work (read views + staff CRUD), with an intentional live-tracking placeholder
  (future). No broken parent/student loop.

## ✅ #1 LEAVE BY CLASS TEACHER = DONE (app + server)
Student leave is now the class teacher's job (not principal). App: class-teacher
dashboard "Leave requests" lists their own class's pending leaves with
approve/reject (scoped via classTeacherOwnsLeave); reuses the approval pipeline
so the parent sees the decision; principal keeps visibility. Server: registered
approveStudentLeave (was uncatalogued → would 403 everyone) + granted to
oversight roles + teacher; approval handler scopes a teacher to their own class
(isClassTeacherForClass), principals/management unscoped. Certified: app analyze
0 err, RBAC/approval suites 151 pass; edge deno check 0 err, +1 scope test.
Follow-up: sibling approve perms (approveStaffLeave, approveAttendanceCorrection,
approveFeeConcession, approvePurchaseOrder) were also uncatalogued server-side —
NOW FIXED (see "APPROVAL PERMISSION CATALOG GAP" below).

## ✅ #2 ATTENDANCE BY CLASS TEACHER = DONE (app)
getAttendanceClasses scoped to the class teacher's own class (non-class-teacher
sees none). Tests green. Server note: there is **no attendance MARKING write
endpoint** server-side (sessions are read-only GET; the only writes are
corrections: create=manageSis, status decision=approveAttendanceCorrection), so
there is no marking route to class-teacher-scope. The real server gap turned out
to be the uncatalogued approve permission — see below.

## ✅ APPROVAL PERMISSION CATALOG GAP = FIXED (server)
Same class of bug as approveStudentLeave: four approve permissions were required
by edge handlers + present in the client matrix but never in the server catalog,
so they'd 403 everyone. Registered + granted (client-parity roles) in
20260701000000_approval_permissions_catalog_gap.sql:
- approveStaffLeave, approveAttendanceCorrection → leadership
  (superAdmin/schoolAdmin/principal/vicePrincipal/management)
- approveFeeConcession → + financeAdmin
- approvePurchaseOrder → + inventoryManager
Added a regression test (approval_permission_catalog_test.ts) that fails if any
F2_APPROVAL_TYPES permission is missing from the migration catalog — prevents
recurrence. Certified: deno check 0 err; approval/academic/attendance deno tests
125 pass.

## 🚧 #3 TIMETABLE auto-substitute — staged
- [x] Stage 1: rule-based substitution engine (DailyTimetableEngine) + tests —
  cover-by-free-teacher, subject preference, no double-booking, unfilled,
  coordinator override. No AI (plain rules), deterministic.
- [x] Stage 2: coordinator review screen ("Today's timetable & cover" from the
  Smart Timetable hub) — mark a teacher on leave → auto-fill → Substitute/Needs-
  cover badges → reassign via picker. MockDailyTimetableStore + tests (8 total).
- [x] Stage 3a: teacher "Today's classes" view (incl. "Covering X" subs).
- [x] Stage 3b: substitutions AUTO-derive from APPROVED staff leave for the
  viewed date (teachersOnLeaveForDate) — no daily manual marking. Base timetable
  is fixed; coordinator screen = pick date + view auto-cover + override. Owner
  design correction applied. Tests green.
- [ ] Stage 3c (only when live): truly-scheduled morning run is a server cron;
  in-app it computes on open for the selected date (same effect).

#3 TIMETABLE auto-substitute = effectively COMPLETE for the mock app (the only
remainder is the server cron, which needs the live backend).

## 🚧 TIMETABLE GENERATOR (first-time auto-build) — staged
Owner vision: after school setup (curriculum already chosen) + all teachers
added with subjects/classes, one **Generate** builds the full fixed weekly
timetable; coordinator/principal then tweak; leave-substitution (done) runs on
top. Plain rules, no AI. Start order chosen by owner: setup + templates → real
generator → coordinator tweak.

What already exists in the app (reused, not rebuilt):
- Curriculum is chosen at setup (`SchoolCurriculum` enum: cbse/icse/stateBoard/
  ib/cambridge/custom).
- Classes + sections captured in onboarding (`UnifiedOnboardingState`).
- Subjects + periods/week + class-subject + teacher-subject assignments exist
  (`school_completion`: AcademicSubject, ClassSubjectAssignment,
  TeacherSubjectAssignment, subject_assignment_screen).
- `mock_timetable_repository.generate()` is a STUB (round-robin subjects, one
  fake teacher, no clash checks) — must be replaced by the real generator.
- Class teacher is still HARD-CODED (`TeacherAssignmentRegistry`) — needs to
  become real per-section data.

Owner design rules to honour in the generator:
- Curriculum is NOT a fixed default — it follows the school's setup choice; the
  template proposes grade-appropriate subjects from that choice.
- Grade-appropriate: grades 1–5 combined EVS (no Physics/Chem/Bio), 6–8 combined
  Science + Social Science, 9–10 heavier load.
- Activities (Games/Computer/Library/Art) are weekly/twice-weekly with a room
  (Playground/Computer Lab/Library) — generator must not double-book a room.
- **First period of every section = its class teacher's period** (the class
  teacher takes attendance there). Generator reserves period 1 for the class
  teacher.
- After first-period attendance → auto polite notification to absent students'
  parents ("your child is absent"). Connects teacher↔parents. (Wording/flow to
  be discussed later — recorded, not built yet.)

- [x] Step 1a: curriculum templates catalog
  (lib/core/timetable/curriculum_templates.dart) — grade-band aware
  (lowerPrimary/middle/secondary), board-aware languages, room-bound activities,
  weekly-load helper. 11 tests pass; analyze clean.
- [x] Step 2: rule-based generator engine
  (lib/core/timetable/timetable_generator.dart) — reserves period 1 for the
  class teacher (their subject if needed, else homeroom), never double-books a
  teacher, one class per shared room per slot, spreads subjects, fills/free +
  plain warnings for anything unplaceable. 10 tests pass; analyze clean. Pure &
  deterministic.
- [x] Step 1b: class-teacher-per-section as real, editable data
  (lib/core/timetable/class_teacher_assignments.dart, seeded from the registry:
  8-A→Priya, 8-B→Patel) + a "Class Teachers" screen under School Completion hub
  (pick one teacher per section) + route. Feeds the generator's classTeacherId.
- [x] Step 2-wire: `mock_timetable_repository.generate()` now runs the real
  engine across all configured sections at once (clash-free), reserves period 1
  for each class teacher, 8×6 grid so the full CBSE curriculum fits, maps to
  TimetablePeriod and upserts entries. Old stub kept only for constructor seed.
  9 wiring/store tests + 141 affected-suite tests pass; analyze 0 errors.
  Carry-over: mock uses CBSE template (no provider access in repo) — live backend
  supplies the school's actual curriculum + teacher_subject_assignments.
- [x] Step 3: coordinator review/tweak of the generated grid. Editor tab now
  shows teacher NAMES (mockTimetableTeacherDirectory) not raw ids, fixes the
  move math to use the entry's real periodsPerDay (was hardcoded 6 — broke the
  8/day generated grid), and adds **Change teacher** per period. New
  `reassignPeriodTeacher` wired through interface + mock + api + hybrid + remote
  + paths. 2 editor/screen + 1 reassign test added; analyze 0 errors.
- [ ] Later: first-period absent-parent notification (polite messaging) —
  parked for owner wording discussion.

#3 TIMETABLE GENERATOR = effectively COMPLETE for the mock app: set class
teacher → Generate real clash-free timetable (period 1 = class teacher) → view &
tweak (move + reassign teacher). Live backend supplies real curriculum/teacher
assignments + the scheduled cron.
- [ ] Later: first-period absent-parent notification (polite messaging).

## ✅ EXAM SEPARATION OF DUTIES = DONE (server)
The coordinator who VERIFIED an exam's results can no longer also APPROVE/publish
them — verify and approve must be different people. Enforced in the single
approval chokepoint (`decideApproval`): on an `examResults` approval it looks up
the exam session's `coordinator_verified_by` and, if it equals the approver,
throws `ApprovalSeparationOfDutiesError` → 403 (mirrors the existing "can't
approve your own purchase order" rule). Rejections by the verifier are still
allowed (only approval is blocked); unverified sessions don't false-trip.
Certified: 5 new SoD tests + full approval/exam suites = 18 pass; edge
`deno check` 0 err.

## ✅ EXAM READ-MODEL teacher_id GAP = DONE (server)
The denormalized teacher read-model (`teacher_entities`) was only school-scoped —
any teacher/staff could read every teacher's snapshot rows (dashboard, exam
marks, messages...). Added a `teacher_id` owner column + per-teacher RLS so each
teacher only sees their own rows, bringing it to parity with its siblings
`parent_entities`/`student_entities` (which already scope by owner via RLS).
Migration `20260702000000_teacher_entities_teacher_scope.sql`: add+backfill+NOT
NULL `teacher_id`, re-key PK to `(org, school, teacher_id, entity_type, id)`,
new index, and replace `teacher_entities_school_scope` with
`teacher_entities_teacher_scope` (`teacher_id = app_current_user_id()`). No app
code change — the generic `entity_read_store` relies on RLS for owner scoping,
same as students/parents. Added a live-DB probe
(`teacher_b_cannot_see_other_teacher_probe_same_school`) so a second teacher in
the same school proves the scoping. Certified: full edge `deno check` 0 err;
deno `_shared` suite 499 pass (only the live-DB `tenant_isolation_test` is
skipped locally — runs in CI/staging).

## ✅ ROUTE GUARD GAP = FIXED (app)
Certification sweep caught it: `classTeacherAssignments` (the "Class Teachers"
screen added with the timetable generator) was registered as a route + reachable
from the School Completion hub, but was **missing from the route-permission guard
map** (`erpRoutePermissionFor` in route_guards.dart) — i.e. the screen was not
protected by a permission. Mapped it to `manageAcademicTimetable`, matching its
siblings Substitute Manager / Teacher Reassignment (held by superAdmin,
schoolAdmin, principal, vicePrincipal — the leadership roles that set class
teachers). The existing `route_protection_inventory_test` ("all ERP prefixes map
to a permission") now passes; it was the only red test in the suite.

## ✅ FULL CERTIFICATION SWEEP = GREEN (whole app + backend)
Ran the complete certification end-to-end after closing the exam carry-overs:
- `flutter analyze` = **0 errors** (only test-file lint warnings remain).
- Flutter test suite = **2086 pass** (1 skip), after fixing the route-guard gap
  above (was the single failing test).
- Backend: full edge `deno check` = **0 errors**; deno `_shared` suite =
  **499 pass** (only the live-DB `tenant_isolation_test` skipped locally —
  runs in CI/staging).
All major school domains (Exams, Finance/Fees, SIS/Attendance, Admissions,
HR/Staff, Operations, Governance/Intelligence, Messages, Homework, Leave,
Timetable generator + auto-substitute) are closed and certified.

## Known carry-overs (tracked, not blocking)
- Live-DB tests (`tenant_isolation_test.ts`) require a tenant DB; run in CI/staging only.
- Owner-parked feature (do not start without owner): first-period absent-parent
  polite notification (timetable generator) — awaiting wording decision.
