# Akshara ERP — UX Redesign Strategy (Phase 3 of 4)

**Date:** 2026-07-02 · **Auditor:** Fable (Claude)
**Basis:** Phase 1 (product audit) + Phase 2 (screen-by-screen). This phase is deliberately **not constrained by the current implementation** — it challenges layouts, workflows, and navigation where a better approach exists, and says why.
**Benchmarks used:** Apple HIG (clarity, deference, one-thing-per-screen), Linear (speed, triage inbox, command layer), Notion (progressive disclosure, templates-first creation), Stripe Dashboard (enterprise tables, restraint, copy quality), Google Material 3 (already the base), Microsoft Fluent (density modes, admin ergonomics).

**North-star check:** every recommendation below serves the locked product thesis — *easiest mobile-first school ERP; USER→ROLE→WORKSPACE→TASK* — nothing here adds scope; it removes friction.

---

## The 7 redesign principles (adopt as law)

| # | Principle | Stolen from | One-line test |
|---|---|---|---|
| 1 | **Action-first, status-second** | Apple, Things | The first thing on any home screen is what the user should *do*, not what the system *knows* |
| 2 | **Exceptions, not entries** | Great POS/field tools | Never make a user assert the default 40 times; they touch only what differs |
| 3 | **Every list is operable** | Stripe, Gmail | Select → bulk act; every KPI filters; every row has its next action inline |
| 4 | **Progressive disclosure everywhere** | Notion | ≤5 essential fields visible; everything else behind "Advanced"; templates before blank forms |
| 5 | **Optimistic + undoable** | Gmail, Linear | Apply instantly, offer Undo (10s), queue the write — never a confirm dialog for reversible acts |
| 6 | **One pattern per job** | Design-system discipline | One search, one filter bar, one form kit, one approval card — everywhere |
| 7 | **Honest data** | Enterprise trust | Cached data says so; approvals show where they're stuck; totals reconcile visibly |

---

## R1. Reshape every persona home around "Today" 🔥

**Replace** KPI-stacked dashboards **with** a two-layer home:

```
┌──────────────────────────────┐
│  TODAY (action layer)        │  ← urgency-sorted, cross-source, actionable
│  • Period 3 — 8B Maths in 10 min   [Mark attendance]
│  • 12 marks pending — Unit Test    [Enter]
│  • Leave request from R. Devi      [Approve] [View]
├──────────────────────────────┤
│  PULSE (status layer)        │  ← the current KPI cards, demoted
│  attendance % · fees · alerts│
└──────────────────────────────┘
```

- **Teacher Today:** now/next period with one-tap attendance, pending marks, submissions to grade, approvals awaiting them.
- **Parent Today ("Needs attention"):** aggregated **across children**, sorted overdue → due-today → upcoming; each row deep-links to the exact action (pay this installment, acknowledge this notice).
- **Student Today's Focus:** overdue n / due-today n / exam in n days, then the rest.
- **Principal Today:** approvals inbox summary + anomalies (see R3, R10).

**Why better:** the current dashboards make users *derive* their to-do list from 6–8 status sections (Phase 1 §5). Apple's clarity principle and every world-class daily tool (Things, Linear's Inbox, Google Classroom's to-do) converge on the same answer: the home screen answers "what now?" in one glance. This single change touches every user, every open, forever.

## R2. Rebuild the four data-entry workhorses as "exception grids" 🔥

Attendance, marks entry, homework grading, HR/hostel attendance — one shared interaction model:

- **Smart defaults pre-applied** (all present; blank marks; ungraded) — teacher touches only exceptions (Principle 2).
- **Grid ergonomics:** number-pad keyboards, Enter/Tab advances, long-press or drag to range-select, sticky header with live progress ("32/40 · Σ marks OK").
- **Autosave is the save** — the only explicit act is *Submit for approval* (the governance gate stays).
- **Desktop:** full keyboard-first spreadsheet behavior (arrow keys, type-through), Microsoft-grade density toggle.
- **Anomaly checks before submit:** all-zero class, marks > max, sum mismatches — inline, not post-approval rejection.

**Why better:** these flows are the product's highest frequency × highest friction quadrant (Phase 2 #1/#2). A 40-student class drops from ~12 interactions + 40 taps to *open → fix 3 exceptions → submit*. This is the difference between "we tolerate the ERP" and "the ERP is faster than the paper register" — the entire adoption battle for Indian schools is won on this screen.

## R3. One Approvals Inbox for the whole school 🔥

**Replace** per-module approval surfaces (exam marks, leave, question papers, refunds, admissions, hostel outpass) **with** a single **Approvals** destination in the admin/teacher shells:

- Inbox list: type chip, requester, age, SLA state; **bulk approve** with per-type guardrails; approve/reject/request-changes inline; every item deep-links to full context.
- Kanban-free, Linear-triage-style: newest-blocking first, keyboard j/k + a/r on desktop.
- Requesters see the mirror: "Where is my request?" status with the current holder and age.

**Why better:** approving is *one job* — the principal's most frequent job — currently scattered across 6+ module screens with modal-only visibility (Phase 1 §4). Linear's triage and GitHub's notification inbox prove the pattern: centralizing heterogeneous "decide" items into one ranked queue collapses time-to-decision and makes SLAs visible. It also reuses the existing per-module approval backends — this is IA reorganization, not new governance.

## R4. Command layer for admin desktop; quick-actions layer for mobile

- **Desktop admin:** ⌘K command palette on top of the existing global-search registry — entities *and* actions ("collect fee → student search", "new broadcast", "approve leaves"). Recent items, fuzzy match, keyboard-first.
- **Mobile personas:** a single FAB/quick-bar per persona with its top-3 actions (teacher: mark attendance / assign homework / message class); Android app-shortcuts + iOS long-press with the same three.
- **Notifications become deep links** (325 routes already exist — use them): "Fee reminder" opens *that installment's* payment screen; "3 leaves pending" opens the Approvals inbox filtered.

**Why better:** Linear/Stripe/Notion all converged on command layers because navigation trees don't scale with feature count — Akshara's admin has 17 modules and a 21-screen setup area (Phase 2 D8). A command layer makes depth irrelevant for experts while the rail stays for learners. Deep-linked notifications convert every push into a 1-tap task instead of a 4-tap hunt.

## R5. Tables that respect the phone; tables that respect the clerk

One responsive **AksharaDataTable** contract:
- **≥768px:** dense Stripe-style table — sticky header, column sort, inline row actions, select-column for bulk, CSV export, saved filters.
- **<768px:** automatic card-list transform — primary fact + status + one action per card, secondary facts behind the tap. (The breakpoint infra `useCardLayout()` already exists — make it the *only* path; delete per-screen table improvisations.)

**Why better:** 7–9-column tables horizontally scrolled on a 390px phone (collections, defaulters, ledgers) are the single worst mobile pattern in the app (Phase 2 D1). Stripe's dashboard proves dense tables are an *asset* on desktop; Material's guidance is unambiguous that they're a liability on phones. One component, both truths.

## R6. Forms: the 5-field doctrine

- ≤5 essential fields on screen; everything else in a collapsed **Advanced** section (Notion-style).
- **Templates before blank:** creation flows open with "start from…" (exam templates, broadcast templates, leave types, fee structures) — blank is the fallback, not the default.
- One **AksharaFormKit**: inline validation on blur, correct `keyboardType` everywhere (1,402 fields to fix), autofocus first field, submit disabled-while-busy, dirty-state PopScope guard, visible "Draft saved · 12:41" chip (the draft infra already exists — surface it).
- Multi-step wizards: max 4 steps, per-step validation with named-field errors, progress %, resumable.

**Why better:** forms are the #1 cognitive-load source (Phase 1 §6) and the #1 error source (no keyboard hints, post-hoc validation). Notion and Typeform demonstrated that field count *shown* — not field count *collected* — determines perceived difficulty. The onboarding wizard alone (60 decisions → ~18 visible) is the difference between a self-serve school setup and a hand-held one.

## R7. The feel layer: perceived performance & feedback

Ship as one cross-cutting package (it's mostly mechanical):
- **Skeleton loaders** on every async screen (the token exists, unused) — kills blank-then-pop.
- **Haptics** on commits, approvals, payments, errors (0 → standard).
- **Pull-to-refresh** on every list/dashboard (1 → standard).
- **Optimistic apply + Undo snackbar** for reversible actions (delete draft, mark attendance row, acknowledge notice) — replaces confirm dialogs (Principle 5).
- **Success moments:** payment success and marks-submitted get a real confirmation view (check animation, receipt number, next step) — not a SnackBar.
- **List virtualization sweep:** convert the 161 non-builder ListViews; pagination affordances ("loading more…").

**Why better:** this is the entire gap between "works" and "feels premium" (Phase 1 §2 — feedback rated 2/10). Apple's fluidity, Linear's speed obsession, and Material motion all monetize the same psychology: response < 100ms + acknowledgment = trust. For parents comparing against WhatsApp/GPay every day, feel *is* quality.

## R8. Honest offline, honest processes

- **Freshness chip** on data served from cache: "As of 09:12 · offline" (interceptor already flags `offline_cache` — render it). Amber banner when stale > policy threshold for money/attendance surfaces.
- **Process status banners** wherever an approval gate exists: "Submitted → awaiting principal (2h)" with the holder named — for teachers' marks, papers, leave, refunds.
- Sync center stays the deep view; the chip is ambient.

**Why better:** the offline platform is excellent engineering rendered invisible (Phase 1 §9) — worse, silently risky, since stale "paid" states mislead. Honest-state UX (Figma's offline chip, Google Docs' "saving…") converts an infrastructure strength into user-visible trust — a genuine differentiator for low-connectivity Indian schools that competitors handle badly.

## R9. IA surgery on the admin side

- **School Completion (21 screens) → 3 task-centered workspaces:** *Setup* (subjects, syllabus, rooms, class-teachers) · *Timetable Studio* (generate → review conflicts → optimize → publish, with manual edits preserved across regenerations) · *Daily Ops* (substitutions, lesson logs, coverage analytics).
- **Settings:** one settings surface per module (tabs inside), reachable from a predictable place; kill icon-button config scatter.
- **Intelligence hub:** context (class/student) picked once, persists across tabs; every insight carries an action button.
- **Director:** school-switcher as persistent pill bar; every aggregate chart drills to the school; compliance as school×policy matrix with remediation links.

**Why better:** these are the areas where "can a clerk use it without training?" currently fails hardest (Phase 2 D7/D8). Task-centered grouping (Microsoft admin centers went through exactly this evolution) cuts the 21-screen maze to three purposeful rooms.

## R10. Copy & tone system

- A 1-page voice guide: sentence case, verbs first, no ALL-CAPS labels, no codes.
- Error dictionary completion: the remaining ~30% raw enums (`PAYROLL_RUN_ALREADY_PROCESSED` → "This payroll period is already processed. Contact HR to reopen it.") — every error names the next step.
- Terminology lock: Student/Teacher/School (never learner/faculty/tenant in UI).
- Empty states always answer "what now" with an action (30/208 today → all).

**Why better:** Stripe's docs-grade microcopy is a moat nobody attributes to engineering. Copy is the cheapest premium-feel upgrade available to Akshara — zero architecture, immediate trust.

## R11. Design-system enforcement (make the 8/10 system a 8/10 reality)

- Custom lints: no raw `Colors.*`/hex, no raw `TextStyle(`, spacing only from scale — warnings on legacy, errors on new code.
- Migration sweep of the long tail (172 TextStyles, ~186 colors, 21→6 spacing values).
- Contrast checker into CI; golden baselines for the three persona shells (not just admin); dark-mode validation ride-along.
- Component completions: AksharaDataTable (R5), AksharaFormKit (R6), ApprovalCard (R3), FreshnessChip (R8), StatusChip with icon+label (kills color-only status).

**Why better:** Phase 1's sharpest finding — excellent system, unenforced (§7). Every hour of enforcement pays compound interest; every new screen written without it adds debt. This is also the hard prerequisite for the School Branding work already on the product backlog.

---

## What deliberately does NOT change

- **Persona bottom-tab shells** — correct model, keep.
- **Approval governance itself** (principal gates, maker-checker) — the redesign changes *where* approving happens, never *whether*.
- **Material 3 as the visual base** — no rebrand; polish within it.
- **Offline/Data-Reliability architecture** — presentation changes only.
- **English-first** (frozen decision) — R10 is about tone, not localization.

## Sequencing sketch (detail in the master report)

1. **Wave 1 — Feel + fixes (low effort, product-wide):** R7 package, R10 copy pass, payment-flow trust pack, urgency-first reordering (R1-lite on existing dashboards).
2. **Wave 2 — Workhorses:** R2 exception grids (attendance first), R3 Approvals inbox, R5 table contract, R6 form kit on the worst five forms.
3. **Wave 3 — IA:** R9 admin surgery, R4 command layer, R1 full Today homes.
4. **Continuous:** R11 enforcement from day one (lint rules land first, sweep runs alongside).

*Continued in `audit_by_fable_phase4.md`.*
