# Akshara ERP — World-Class UX Polish

**Status:** 🟢 Design specification — the screen-and-workflow polish program that takes the UX rubric from 5.5/10 to ≥8/10.
**Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Author:** Fable (World-Class Product Polish phase, Phase 2 of 5)
**Builds on:** `UI_UX_MASTER_CONSOLIDATION.md` (C-ISS/C-OPP IDs) · audit 08 (UX-1…6, Tiers 1–4) · the implemented component library in `lib/shared/widgets/`.
**Executes as:** roadmap tasks **P2-UX-1…5** (plus named P1/P3 hooks). This document is the *content* of those tasks, not a new track.

> **Safety rules (binding on every recommendation here):** preserve all business logic, providers,
> repositories, routing, RBAC/RLS and workflows; reuse existing shared widgets before creating new
> ones; no duplicate screens; anything needing backend work is explicitly tagged **[BACKEND → task]**.
> Evolution, not re-architecture.

---

## 1. What the benchmarks actually teach (principles, not paint)

| Benchmark | The transferable lesson | Akshara application |
|---|---|---|
| **Apple** | The device disappears; feedback is physical (haptics, motion continuity); settings you never need | Haptic vocabulary on the five daily tasks; motion tokens already exist (`lib/theme/motion.dart`) — use them everywhere state changes |
| **Linear** | Speed *is* the design; keyboard-first; opinionated defaults; one obvious next action per screen | Exception-first attendance, inline marks, command palette (candidate), 48h→instant perceived latency via skeletons + optimistic UI where writes are idempotent |
| **Stripe** | Money UX = ceremony + receipts + total clarity of state; errors are written by humans | Payment trust pack (C-ISS-15); error dictionary; "pending sync" receipt-gating made *visible and proud* |
| **Notion** | Empty states teach; progressive disclosure; the product feels personal | Illustration+action empty states everywhere (kit exists); per-school adaptive surfaces (P3) |
| **Google** | Material discipline, accessibility as table stakes, instant search | Finish M3 properly: dynamic type, contrast in CI (P2-UX-3/4); global search (candidate) |
| **Microsoft** | Enterprise density when needed; admin ≠ consumer; keyboard grids | Density mode for clerk screens; dense `AksharaDataTable` (P2-UX-2) |
| **Atlassian** | Queues, approvals, audit trails as first-class citizens | Cross-module Approvals Inbox; audit "who changed this?" surfacing |

**The one-line strategy:** Akshara already has the *bones* of a world-class product (tokens, shells, offline honesty, governance). World-class here is not adding surface — it is **removing friction and making the invisible trustworthy-visible** on the tasks people do 200×/day.

---

## 2. The five daily tasks — where adoption is won (C-ISS-1 → P2-UX-2)

Each spec: *today → target → click math → what's reused → tags*.

### 2.1 Attendance (teacher, ~2×/day/class)
- **Today:** full-roster list, per-student taps; draft autosave + crash-resume already real (protect it).
- **Target — exception grid:** open to "All present" pre-state; teacher taps only the exceptions (absent/late), then one confirm. Roster as a compact avatar grid (initials + PSID rule), tap = cycle state, long-press = detail. Sticky summary bar: "42 present · 2 absent · 1 late — Submit".
- **Click math:** 40-student class, 2 absentees: today ≈ 42+ interactions → target **3 taps + confirm**.
- **Reuse:** `DraftAutosaveMixin`, existing attendance provider/writes unchanged; grid is a view-layer swap. Haptic tick per state change; success view on submit (§3).
- Deep link from today's schedule row (TCH-1) so the flow starts in one tap from the morning brief.

### 2.2 Marks entry (teacher, exam seasons — the make-or-break flow)
- **Today:** row-by-row entry; "Save all" bypasses the reliability platform **[BACKEND → P1-CODE-1, already scheduled — P2-UX-2 depends on it]**.
- **Target — spreadsheet-grade grid:** number-pad keyboard locked on (C-ISS-12); Enter/Next advances down the column; out-of-range rejects inline (max-marks aware); AB/ML/DB entered via status chips **honoring the frozen NULL-marks rule — the grid never writes 0 for absent**; per-cell save state (dot = draft, check = synced) rides the outbox; column stats footer (entered/pending/avg) = live progress (EXM-2's progress board fed by the same state).
- **Click math:** 50 students today ≈ 150+ taps with keyboard juggling → target **one continuous number-pad flow**, zero keyboard switches.
- **Reuse:** one shared marks-grid component for BOTH entry chains — this is the first concrete step of the Exam Workspace consolidation (C-ISS-5) without touching either provider yet.

### 2.3 Approvals (principal/management, all day)
- **Today:** per-module queues (leave, concessions, POs, stock write-offs…); batch approve exists only in spots (PRI-1 shipped).
- **Target — one Approvals Inbox:** a single cross-module queue (Tier 2 #11) grouped by type, newest-critical first; swipe right = approve, left = reject-with-reason (bottom sheet); batch select; every card shows the *decision-critical facts* (who/what/amount/policy flag) so no drill-in is needed for 80% of items. Maker-checker items visibly badged — governance as a feature.
- **[BACKEND → candidate P1 task]** a thin read-model aggregating existing per-module approval endpoints; **no approval logic moves** — the inbox is a composition over existing RBAC'd APIs. If deferred, ship the UI per-module first (pure client).
- **Reuse:** `PrincipalApprovalCenterScreen` (exam design already mandates reusing it), PRI-1 batch pattern generalized (C-OPP-2).

### 2.4 Fee collection (office, continuous)
- **Today:** functional counter; correct offline receipt-gating; no ceremony (C-ISS-15).
- **Target — the Stripe-grade counter:** search by PSID/name/class with instant results (PSID-7 as first-class search key); one screen shows dues breakdown → amount pre-filled → collect → **success ceremony**: check-motion + haptic + receipt card with share action. Offline: the "pending sync" state presented as a *feature* — amber receipt card, "Receipt will be issued when connected · queued securely", freshness chip. Concession path clearly separated and maker-checker-badged (FIN-D4 preserved).
- **Click math:** collect a known student's term fee in **≤4 taps** from the dashboard.
- **Reuse:** existing finance providers/idempotency; ceremony = new shared `AksharaSuccessView` used product-wide (§3).

### 2.5 Grading / result review (teacher + coordinator)
- **Target:** same grid component as 2.2 in review mode; anomaly highlights are **deterministic** (blank cells, >max, class-avg outliers — SQL/client math, no model); publish action gated behind the existing approval workflow, with a pre-publish summary ("3 AB · 1 ML · rank computed · excluded from averages per frozen rule") so teachers trust what publishing means.

**Ergonomic targets (feed Gate U2 verbatim):** attendance ≤3 taps + confirm · known-student fee ≤4 taps · 50 marks in one uninterrupted keyboard flow · approval decision ≤2 gestures · zero raw enums in any of the five flows.

---

## 3. The feel & trust layer (C-ISS-2/3/4/15 → P2-UX-1)

One wave, product-wide, all view-layer:

1. **Skeletons everywhere:** implement the long-specced `Feedback/Skeleton` patterns (KPI row, table, card, list, chart) as `AksharaSkeleton` variants; rollout mechanism = migrating the 142 hand-rolled `AsyncValue.when()` sites onto `ErpAsyncBody`/`MobileAsyncBody` (C-ISS-9) so loading/empty/error become uniform *by construction*. Shimmer 1.2s, disabled under reduced-motion (already specced).
2. **Pull-to-refresh** on every list/dashboard (one today).
3. **Haptic vocabulary** (small, consistent): light tick = state toggle · success notch = submit/collect · warning buzz = destructive confirm. Respect OS settings.
4. **`AksharaSuccessView`** (new shared widget, one design): check motion (240ms `motion.dart` curve) + summary + next action. Used by fee collect, attendance submit, marks save, approval batch.
5. **Freshness chip:** surface the read-cache timestamp on money/attendance surfaces — "As of 09:42 · offline" (UX-3; infrastructure already built).
6. **Draft chips + PopScope everywhere** drafts exist; extend `DraftAutosaveMixin` to marks + fee (client part; persistence backend = P1-CODE-1).
7. **Copy & error dictionary:** human-written message per error taxonomy class (validation/permission/network/conflict/server), mapped in `api_failure_mapper.dart`; no raw `error.message` ever rendered **[BACKEND leak fix → P1-CODE-3]**. Includes the microcopy standard (₹ formatting `₹1,24,500`, dates `12 Jul 2026`, PSID always `DPSKKP-0001` form — per identity freeze).

---

## 4. Navigation & information architecture

- **Persona shells are right — keep them.** `PersonaBottomNav` (≤4 tabs + More + center AI slot) matches the North Star; do not add tabs.
- **Admin/web:** collapse the 12 per-feature `*_module_scaffold.dart` into ONE parameterized `AksharaModuleScaffold` (C-ISS-8) — identical UX, 12× less drift; lint against raw `AppBar` on product screens (P2-UX-3). Pure refactor, zero route/provider changes.
- **Exam Workspace pull-in (recommended slice of C-ISS-5):** give exam administration a real nav entry point and land the shared marks-grid (2.2). The *full* 14-surface Consolidation wave stays 👤 OWNER (DOC-8) — this slice only removes the "no top-level menu item" defect and the double-entry risk flagged as 🔴 in `EXAM_WORKSPACE_DESIGN.md`.
- **Breadcrumb + deep-link discipline (web):** every screen reachable by URL keeps state in query params (filters/tabs) so links shared between office staff land exactly where intended.
- **Candidate (master plan):** ⌘K command palette on web admin — navigate + entity search + actions ("collect fee for…"). Rides `route_names.dart` + PSID search; no new backend if scoped to navigation + existing search endpoints.

---

## 5. Dashboards, workflows, forms, dialogs

### Dashboards (pre-Adaptive-AI; P3 composes on top — do not rebuild twice)
- Enforce the §8 VISUAL_DESIGN_SYSTEM recipe as the single dashboard grammar: greeting hero → status pills → ≤3 KPI tiles → one insight → actions → content. **Max 4 primary colors; every KPI tappable to its filtered list** (TCH-6 deep-links).
- KPI truth rule: no decorative data — sparklines show real series or don't render (M15.5 gap).
- Kill dashboard-within-dashboard duplication (3 principal surfaces) only via the OWNER consolidation decision; until then, cross-link rather than duplicate widgets.

### Workflows
- Wizard doctrine (already in DESIGN_SYSTEM_V1): step indicator + sticky action bar + `AksharaUnsavedChangesGuard` + `scrollToFirstFormError` — *apply to all multi-step flows* (admissions, payroll run, onboarding), not just enrollment.
- Every destructive/irreversible step: typed confirmation or explicit summary ("This publishes results to 412 parents") — never a bare "Are you sure?".

### Forms (C-ISS-12)
- The **5-field doctrine:** any form >5 fields must justify each field or move it behind "More details" (progressive disclosure). Applies to new screens; existing dense forms fixed opportunistically during the keyboard sweep.
- Mechanical sweep (~1,402 fields): correct `keyboardType`/`inputFormatters`/`textInputAction` per field type; date pickers replace free-text dates (XCT-3 → P1-PROD-0); phone/₹ masks; validation on blur + submit (never on first keystroke).

### Dialogs
- Mobile: dialogs >2 actions or with inputs become bottom sheets (MobileScreenInventory rule — enforce); the dense create-exam dialog is the named first migration.
- Web: keep S400/M560/L720 grid; destructive variant always icon+color+verb ("Delete 3 receipts", never "OK").

---

## 6. States: empty, loading, error, offline

- **Empty:** `AksharaEmptyState` + monoline motif (kit shipped in M15.5) + ONE primary action, module-appropriate ("No fees due today — Collect for another student"). Roll out to the modules M15.5 didn't reach.
- **Loading:** skeleton if structure known, spinner only for actions <400ms expected, `LoadingOverlay` only for blocking writes. (This is the perceived-speed rule the corpus lacked — full budget table in `PREMIUM_DESIGN_SYSTEM_GUIDE.md` §6.)
- **Error:** dictionary copy (§3.7) + Retry + preserved input. Permission-denied gets its own state (not an error): "This needs the Finance Manager role" (C-gap #9).
- **Offline:** the existing `SyncBanner`/Sync Center stays the spine; add the freshness chip and the amber "queued" receipt/mark states. Never block reads that the cache can serve.

---

## 7. Accessibility (C-ISS-13 → P2-UX-4) & responsive behaviour

- Declare the bar: **WCAG 2.1 AA** for the five daily flows + parent app; contrast checker wired into CI (P2-UX-3 prerequisite); screen-reader pass over the five flows with Semantics labels verified (311 usages exist — verify, don't assume); dynamic-type support with a tested 1.3× clamp on dense grids (the only place clamping is allowed); 48dp targets already enforced in theme — add a lint.
- Responsive: keep `AksharaBreakpoints` as the single source (fix the documented 1024-vs-1199 tablet drift in favor of code: 1199). Tables collapse to `AksharaListCard` under 768 (already the rule — enforce via the same lint wave). Desktop clerk screens gain a **compact density toggle** on `AksharaVirtualizedDataTable` (row 52→40) — density is a table property, not an app mode, resolving the calm-vs-dense tension (C-gap #13).

---

## 8. Premium enterprise feel — the last 20%

- **Motion:** use the existing tokens as a *system*: page transitions 180ms standard; state changes 120ms; success ceremonies 240ms; nothing animates longer than 300ms; reduced-motion kills all of it. Continuity: KPI → detail navigations share element transitions where cheap (Hero on avatar/receipt card).
- **Atmosphere:** mesh + watermark canvas (shipped) consistently applied to all persona dashboards; glass effects stay off data tables (readability first).
- **Dark premium:** ship the toggle (P2-UX-5 — code-complete); default stays Light per owner direction; contrast-validate the obsidian palette before enabling (Premium Guide §4).
- **Numbers:** tabular numerals on every KPI/table/receipt (VISUAL_DESIGN_SYSTEM §6) — the single cheapest "feels professional" fix for a money product.

---

## 9. Execution map & guardrails

| Wave | Contents (this doc) | Roadmap task | Depends |
|---|---|---|---|
| Feel & trust | §3 (skeletons, refresh, haptics, success, freshness, drafts, copy) + §6 states | **P2-UX-1** | P0 draft infra; P1-CODE-3 for leak fix |
| Daily-task ergonomics | §2 (five tasks) + §5 forms/dialogs + keyboard/date sweep | **P2-UX-2** | **P1-CODE-1** (marks via ReliableWriter) |
| System enforcement | §4 scaffold unification + lints + goldens + contrast-in-CI | **P2-UX-3** | — |
| Accessibility | §7 | **P2-UX-4** | P2-UX-3 |
| Dark toggle | §8 | **P2-UX-5** | — |
| Approvals-inbox read-model · exam nav entry + shared grid | §2.3 / §4 | **candidate P1/P2 additions** (owner-visible in master plan §6) | OWNER awareness (DOC-8 slice) |
| Command palette · audit-trail surfacing · saved views · export-center UX | §4 / consolidation §7 | **candidates** — minted only via `PRODUCT_EXCELLENCE_MASTER_PLAN.md` | 👤 |

**Verification:** each wave = EOS-gated (UX PASS); Phase-2 exit = prior rubric re-run ≥8/10; Gate U1/U2/U4 wording already matches §2–§3 targets. **Nothing in this document changes an API contract, a permission, a workflow state machine, or a frozen decision.**

*Next: `../strategy/ADAPTIVE_AI_USER_EXPERIENCE.md` — how the same screens become quietly intelligent.*
