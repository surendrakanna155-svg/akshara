# Akshara ERP — Product UI/UX Audit (Phase 1 of 4)

**Date:** 2026-07-02 · **Auditor:** Fable (Claude) · **Method:** full-codebase review — app shell, router, theme system, 63-screen mobile inventory, ~120 admin screens (334 screen files), plus quantitative consistency metrics measured across `lib/` (grep-verified counts)
**Companion reports:** Phase 2 (screen-by-screen) · Phase 3 (redesign strategy) · Phase 4 (innovation) · Final master report

---

## 0. Product snapshot

| Surface | Model | State |
|---|---|---|
| **Parent / Student / Teacher apps** | Persona bottom-tab shells (M3 `NavigationBar`, 4–5 tabs + "More") | Mobile-first, phone-portrait canonical (390/428) |
| **Admin / ERP / Principal / Director** | Responsive shell: drawer (mobile) → 72px rail (tablet) → 260px rail + 1440px content (desktop) | Desktop-leaning, mobile fallback |
| **Design system** | M15 token system: primitives → semantic tokens → M3 ColorScheme; typography, spacing (8pt), radius, elevation, breakpoints all tokenized | Excellent system, **uneven adoption** (§7) |
| **Offline** | Data Reliability Platform: draft autosave, SyncBanner, OfflineReadCacheInterceptor, sync center | Strong infra, **weak user-facing signals** (§9) |

**Overall product experience maturity: 5.5 / 10** — a well-architected foundation with genuinely good bones (token system, persona shells, offline infra, state components), dragged down by uneven execution across the long tail of screens, data-entry friction in the highest-frequency workflows, and missing "feel" polish (skeletons, haptics, refresh, undo).

---

## 1. Overall UI — 6/10

**Strengths**
- Modern Material 3 visual language; gradient heroes, KPI cards, chips and segmented controls give the product a coherent contemporary look on its best screens (parent dashboard, admin shell, finance dashboard).
- The M15 theme (`lib/theme/`) is real engineering: 50+ color primitives, semantic tokens, locale-aware typography with Indic font fallback, white-label primary override, dark palette prepared.
- 124+ usages of shared `AksharaKpiCard` / `AksharaCard` / button variants on refactored surfaces.

**Weaknesses**
- **Two-speed codebase.** M15-refactored surfaces are token-clean; the long tail is not: ~85 `Colors.*` + ~101 raw hex usages, **172 raw `TextStyle(` vs 26 themed**, and **21 distinct spacing values** across ~2,100 raw `SizedBox`es where the scale defines 6. The product *has* a design system and *also* ignores it, depending on which screen you open. (Some hardcoding is legitimate — PDF export uses `PdfColors` — but the trend is real.)
- Dark mode is built (obsidian palette, provider, a settings toggle) but untested beyond 3 admin golden screens — effectively shippable-looking but unshipped.
- Status is often communicated by **color alone** (chips: red/green/amber) — an accessibility and print problem.

## 2. UX — 5/10

**Strengths**
- The highest-stakes flows have serious safety UX: approval gates (marks, papers), draft autosave with resume, offline write queue with sync center.
- Async state handling is structurally sound: 257 `AsyncValue.when()` sites; shared loading/empty/error components exist (`AksharaLoadingState`, `AksharaEmptyState` with 208 usages, `AksharaErrorState` with failure mapping).

**Weaknesses**
- **The daily workhorses have the worst ergonomics.** Marking 40 students' attendance ≈ 9–12 taps + per-row tapping; grading homework ≈ 5–8 taps *per student* through a modal; marks entry has no inline/tab-through editing; approving 50 leave requests ≈ 100 taps. Frequency × friction makes these the product's biggest UX cost — and they're all fixable with bulk-select + inline-edit patterns.
- **Feedback layer is missing.** 0 haptic calls in the entire app; 1 `RefreshIndicator` in 289 screens; 0 skeleton loaders (blank-then-pop on slow networks); success = plain SnackBar even for a fee payment.
- **No undo anywhere** — destructive/committing actions rely on confirm dialogs instead of optimistic-apply + undo, which is slower *and* less safe.

## 3. Navigation — 6/10

**Strengths**
- Persona bottom tabs are the right model for parents/teachers/students; 2–3 level depth; core tasks reachable in 3–4 taps.
- Admin shell navigation (rail + breadcrumbs in `AdminContentScaffold`) is genuinely good desktop IA; global search overlay exists at admin level.

**Weaknesses**
- **325 routes defined, ~0 deep links used in product surfaces** — notifications and shortcuts don't take users to the exact record; campaigns/reminders can't land on a payment screen.
- **4 `PopScope` guards in 289 screens** — back-button data loss is a systemic risk on every form (partially mitigated by draft autosave on some).
- No route inventory doc; timetables lack "today" jump; no in-context cross-links (a period row doesn't link to "mark attendance for this period").
- Admin "School Completion" area is a 21-screen maze (setup, timetable, rooms, substitutes, analytics all flattened into one hub).

## 4. Information Architecture — 6/10

**Strengths**
- USER→ROLE→WORKSPACE→TASK is visible in the architecture: persona shells, role-gated modules, workspace scoping. That's the correct enterprise spine, and few competitors have it.

**Weaknesses**
- Inside workspaces the IA is **module-first, not task-first**: users think "collect this fee / approve these leaves / send this notice," but must navigate Module → Screen → Tab → Dialog.
- Approvals — the most important admin *task class* — are scattered per module (exam approval, leave approval, paper review, refund approval) with no unified inbox.
- Settings sprawl: per-module configuration split across 3–5 surfaces (screens + dialogs + sheets + icon buttons).
- Tab-bar fragmentation (389 TabBar usages): related steps of one task split across tabs (broadcast compose/templates/schedule; intelligence hub re-asks context per tab).

## 5. Visual hierarchy — 5/10

- Dashboards front-load **status** (KPI cards) instead of **action**: teacher's "mark attendance now" is buried mid-screen; parent's urgent items (overdue homework, due fees) sit below heroes and carousels; insight cards render *below* the lists they summarize (parent homework).
- 6–8 stacked sections per dashboard with only ~1.5 visible above the fold; no urgency sorting ("overdue" mixed with "due next week").
- On the good side: KPI card typography scale and hero cards do establish clear scanning order *within* components.

## 6. Cognitive load & simplicity — 5/10

- **Forms are the biggest load generator:** onboarding wizard ≈ 6 steps × 10 fields = 60 decisions with generic "complete required fields" errors; admission enrollment 4 steps × 15 fields; almost no progressive disclosure (advanced options inline with essentials).
- 1,402 numeric/phone/email fields lack `keyboardType` hints — full QWERTY for phone numbers is a per-keystroke tax on every clerk.
- Dense DataTables (7–9 columns) on phone screens force horizontal scrolling per row (collections, defaulters, ledgers).
- Redundant affordances (hero Pay button + sticky-footer Pay button) and unexplained toggles (exam rank visibility) add micro-confusion.

## 7. Consistency — 4/10

Measured, not impressionistic:

| Metric | Count | Verdict |
|---|---|---|
| Hardcoded `Colors.*` / hex vs theme | ~186 vs ~109 sampled sites | Token adoption ~40–60% depending on module age |
| Raw `TextStyle(` vs themed | 172 vs 26 | Long tail ignores type scale |
| Distinct spacing values | 21 (scale defines 6) | Visual rhythm broken |
| List separators | `Divider()` and `SizedBox` mixed | Two visual languages |
| Search | Material `SearchBar` and ad-hoc `TextField` | Inconsistent affordance |
| Modal vs bottom-sheet for same task class | Mixed | No decision rule |
| Empty-state icons | Per-screen improvisation | No catalog |
| App bars | `AksharaAppBar` vs plain `AppBar` | Mixed |

The design system is **excellent as a library and unenforced as a law** — there is no lint/CI rule binding screens to tokens, so entropy wins on every non-flagship screen.

## 8. Accessibility — 6/10

**Strengths:** real infrastructure — `lib/theme/accessibility.dart` computes WCAG 2.1 contrast on critical pairs; 332 explicit `Semantics` containers (~40% coverage); text scaling supported and clamped sanely (1.0–1.6×); Indic script line-height headroom; 48dp targets in tokens.
**Weaknesses:** contrast checker not wired to CI (violations can ship); color-only status chips; no reduced-motion guards; keyboard navigation untested on desktop admin; a11y coverage is a property of flagship screens, not the product.

## 9. Mobile / Desktop usability — 6/10 mobile · 5/10 desktop

- **Mobile:** right-shaped shells and touch targets, but list-rendering debt (161 non-builder `ListView`s vs 80 builders — 2:1 the wrong way) risks jank exactly where schools live (long rosters); no pull-to-refresh mental model; admin tables unusable on phones.
- **Desktop admin:** good shell, but no keyboard-first data entry (marks/attendance), no command palette, no bulk-select tables, tablet-landscape band (1200–1440) untested. Desktop is where clerks spend hours; it currently behaves like a stretched phone app with a rail.
- **Offline:** infrastructure excellent; *presentation* dishonest — cached data renders with **zero staleness indication** (a parent can see "paid" from an hour-old cache). SyncBanner covers writes, not read freshness.

## 10. Design system — 8/10 system · 4/10 adoption

Already detailed in §1/§7. One-line verdict: **stop growing the system, start enforcing it.** The highest-leverage design-system work is a lint rule + migration sweep, not new components.

## 11. Enterprise quality — 6/10

**Strengths:** RBAC-gated UI (`AksharaManageAction`), QA keys instrumented across screens, golden tests (3 admin dashboards × 3 viewports × light/dark), audit trails in backend, white-label seed override, error-code → human-message mapper (~70% coverage).
**Weaknesses:** developer-ese leaks (~147 raw error enums like `PAYROLL_RUN_ALREADY_PROCESSED` reachable; "tenant"/"org scope" phrasing near user surfaces); no bulk operations anywhere; no CSV/import ergonomics on admin lists; no per-record change-history surfaced to users; no copy/tone guide; empty states passive (30 of 208 have an action).

---

## 12. Pain points, friction, confusion — consolidated

**Top pain points (by frequency × severity)**
1. **Attendance marking ergonomics** (daily × every teacher) — needs bulk/range marking, autosave-not-submit.
2. **Marks & homework grading throughput** (weekly × every teacher) — needs inline/tab-through entry, batch actions.
3. **Approval scatter** (daily × every principal/admin) — needs one inbox.
4. **Form friction everywhere** — keyboard types, inline validation, progressive disclosure, drafts visibility.
5. **Perceived slowness** — skeletons/haptics/refresh/optimistic updates absent.

**Most confusing areas**
- School Completion hub (21 screens, no "what next"); Intelligence hub (5 tabs re-asking context); broadcast composer error-states-before-input; AI quick-setup button with unexplained behavior; exam settings hidden behind an unlabeled icon.

**Unnecessary complexity to remove**
- Tab-fragmented single tasks; duplicate CTAs; separate screens for steps that are one decision (reconciliation's 3-screen match flow); 4 export buttons where one menu suffices; per-module settings scatter.

---

## 13. Prioritized findings

| P | Finding | Impact | Evidence |
|---|---|---|---|
| **P0** | High-frequency data entry (attendance/marks/grading/leave-approval) lacks bulk & inline patterns | Hours/week per school; the product's core promise ("easiest ERP") broken exactly where usage concentrates | Phase 2: TA-02, TA-04, TA-05, HR-Leave |
| **P0** | 1,402 input fields without keyboard hints; validation manual & post-hoc | Error rates + entry speed for every user, every day | grep counts §6 |
| **P0** | Offline reads show no staleness cue | Wrong decisions on stale money/attendance data; trust risk | §9 |
| **P0** | List-rendering debt (161 non-builder ListViews) | Jank on real school data sizes; "cheap app" feel on budget Androids | §9 |
| **P1** | No feedback layer: 0 haptics, 1 refresh indicator, 0 skeletons, no undo | Product feels unresponsive and unpolished vs any consumer app parents use | §2 |
| **P1** | Design-token adoption unenforced (172 raw TextStyles, 21 spacing values, ~186 hardcoded colors) | Visual inconsistency; blocks School Branding/white-label; compounding debt | §7 |
| **P1** | Approvals scattered across modules | Principal's #1 job has no home | §4 |
| **P1** | Dashboards status-first not action-first; no urgency sorting | Daily "what do I do now" moment unserved for all personas | §5 |
| **P1** | Back-button/data-loss guards nearly absent (4/289) | Data loss + rage moments on forms | §3 |
| **P2** | Deep links defined but unused by notifications/shortcuts | Longer paths for every notification-driven task | §3 |
| **P2** | Raw error enums / developer-ese reachable in UI (~30% unmapped) | Trust + support burden | §11 |
| **P2** | Color-only status; a11y checks not in CI | Compliance risk; excludes users | §8 |
| **P2** | Settings sprawl + 21-screen setup hub | Training cost; "needs 2–3h per module" today | §4 |
| **P3** | Dark mode built but unvalidated; tablet-landscape band untested; no mobile golden baselines | Latent regressions | §1 |

---

## 14. Scorecard

| Dimension | Score |
|---|---|
| Overall UI | 6 |
| UX (task ergonomics) | 5 |
| Navigation | 6 |
| Information architecture | 6 |
| Visual hierarchy | 5 |
| Cognitive load / simplicity | 5 |
| Consistency | 4 |
| Accessibility | 6 |
| Mobile usability | 6 |
| Desktop usability | 5 |
| Design system (system / adoption) | 8 / 4 |
| Enterprise quality | 6 |
| **Product experience overall** | **5.5 / 10** |

**The one-paragraph verdict:** Akshara's UX foundation is better than its UX. The architecture (persona shells, token system, offline platform, approval governance) is genuinely strong — stronger than most school ERPs ship with. What stands between this and a world-class experience is not redesign of the foundation but (a) ruthless ergonomic work on the five daily workflows, (b) enforcement of the design system that already exists, (c) a feedback/perceived-performance layer, and (d) task-first reorganization of the admin IA. Phases 2–4 detail exactly that.

*Continued in `audit_by_fable_phase2.md`.*
