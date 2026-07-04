# Adaptive AI Design 06 — Module AI Design: Operations (Finance · HR · Library · Transport · Inventory)

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` · **Framework:** [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md) · **Machinery:** [`02_CONTEXT_ENGINE_DESIGN.md`](02_CONTEXT_ENGINE_DESIGN.md) · [`03_MEMORY_AND_CACHING_STRATEGY.md`](03_MEMORY_AND_CACHING_STRATEGY.md) · [`04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md`](04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md)
**Anchors:** [`../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md`](../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md) §5/§6/§10 · [`../../audits/06_AI_ARCHITECTURE_AUDIT.md`](../../audits/06_AI_ARCHITECTURE_AUDIT.md) (ground truth) · Roadmap **P3-AI-2** item 8 (Finance → Transport/Library/Inventory routers) · Frozen decisions: **FIN-D4**, **TRN-9**, **inventory stock governance**, **attendance-auth**.
**Wave-tag precedence:** where a `Pri` tag in this document disagrees with [`09_IMPLEMENTATION_WAVES_AND_METRICS.md`](09_IMPLEMENTATION_WAVES_AND_METRICS.md), **doc 09 governs** (W1 = platform plumbing only; module/persona surfaces ship in W2; HWK-1/FIN-6/TRN-2/MOD-1 are P1 preconditions, not AI waves).

> **Purpose.** This document applies the Serving Ladder (doc 01), the Context Engine (doc 02), the
> memory/cache stores (doc 03), and the Signal Refinery / Priority Engine / notification rail
> (doc 04) to the five **operations modules**: Finance, HR, Library, Transport, Inventory. These are
> the modules where money moves, stock moves, and compliance clocks tick — so the design bias is
> even harder toward **T0/T1 determinism**: the model never touches an amount, an approval, or a
> ledger. Every surface below is placed on a tier, mapped to a pattern (P1–P12), grounded in a
> backlog ID, and ready for autonomous implementation.

**Shared conventions for all five modules**

- Every surface registers a **manifest** (doc 02 §3) and mints its cache key via the Context Engine.
- Every signal named below is a row-family in `ai_fact_signals` (doc 03 §2.4), refreshed by the
  Signal Refinery mappings in doc 04 §2 and corrected by the nightly recompute.
- Every proactive message is a **T0 catalog template** (doc 04 §6) riding the XCT-2 rail — no LLM in
  any send path; external channels stay owner-gated.
- **Money rail (absolute):** on any Finance-adjacent surface, AI may *prioritize, phrase, and
  draft* — it **never computes an amount, never triggers a payment, never touches maker-checker**
  (FIN-D4, refund/concession/expense/payroll/vendor SoD, inventory value-reducing SoD all untouched).
- Deterministic surfaces are labeled **Analytics/Smart**, not "AI" (truth-in-naming, closes AI-6).

---

## 1. Finance

### 1.1 Snapshot (ground truth)

- **Readiness ✅** — the strongest module; caveats ENG-1 (`row_version`) and REL-1 (idempotency)
  are Phase 0/1 fixes, not AI concerns. Fee counter is idempotent and row-locked.
- **Strongest governance module:** maker-checker live on refund, concession (FIN-D4 frozen),
  expense, payroll, vendor. Receipts with SMS + PDF; defaulters with aging buckets + WhatsApp.
- **Existing intelligence:** FN-01 (6 KPIs, trend, top-5 defaulters, unaudited-modification banner),
  FN-03 defaulters widget with an "AI smart-reminder-timing" card; a **deterministic fee-default
  predictor already exists** (`predictions_service.ts`: outstanding + days overdue).
- **Flagship backlog:** Fee-Recovery CRM (P1) — FIN-R1 recovery dashboard, FIN-R2 telecaller call
  queue, FIN-R3 promise-to-pay worklist, FIN-R4 immutable contact history, FIN-R5 collector
  performance; P2: FIN-R6 targets, FIN-R7 PDC/cheque.
- **Module fixes AI depends on:** FIN-6 installment due-schedule (replaces hardcoded +30d — real
  due dates are the fuel for C9 deadlines and reminder timing); MOD-1 (library/hostel fines must
  post to the Finance ledger, never side-ledgers).
- **Frozen:** TRN-9 — transport fees reuse the per-year student account; **Finance is the sole
  payment engine** (Transport/Library raise demand signals only).

### 1.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| FN-01 KPI widget (collection %, dues, trend, top-5 defaulters) | T1 | P4 | Exists. Served from `ai_fact_signals` fee-aging rollups; event-fresh, zero calls |
| Unaudited-modification banner | T1 | P2 | Exists. Governance exception surface; stays pure rule |
| FN-03 defaulter list + aging buckets | T1 | P4 | Exists. Becomes the data spine of FIN-R1 |
| Smart reminder timing (FN-03 card) | T1 | P2/P12 | **Re-placed:** currently branded AI; correct build = learned per-school send-time from payment-delay distribution (doc 03 §2.5). No model |
| Fee-default risk score | T1 | P2 | Exists (`predictions_service.ts`). Stays deterministic; feeds recovery queue pre-staging |
| FIN-R1 recovery dashboard (aging × class × route, target-vs-collected) | T1 | P4 | New. Pure rollup views over fee-aging signals; route dimension honors TRN-9 |
| FIN-R2 telecaller call queue ("who to call today") | T1 | P3 + P11 | New. Priority Engine instance: amount × aging × broken-PTP × learned weights; rows carry one-click call/WhatsApp + outcome log |
| FIN-R3 promise-to-pay kept/broken worklist | T1 | P2/P4 | New. PTP dates are C9 deadlines; broken PTP = exception item, boosts queue score |
| FIN-R5 collector performance | T1 | P4 | New. Deterministic aggregates over FIN-R4 contact history (which itself is a record, not AI) |
| Recovery message draft (per family, escalation tone) | T3 | P9 | New. Draft-and-hold for the *hard-case* letter only; routine reminders stay T0. Human edits and sends; ≤1 call/draft |
| Fee reminder sends (T-3/T0/T+7, PTP-due) | T0 | P1 | Catalog template + slots + parent language variant; scheduled via XCT-2 on FIN-6 real due dates |
| Daily collection pulse (principal/finance head) | T2 | P6/P5 | New. One shared generation per school per day, pre-warmed nightly from T1 facts; T1 table renders if generation fails |
| "Explain this number / this family's ledger" | T2/T3 | P8/P10 | On-demand only; facts injected from T1, answer write-through cached, siblings hit semantic cache |
| Finance copilot Q&A | T3→T2 | P7/P10 | Exists (real call). Gains intent-fingerprint + semantic cache; enumerable intents (dues of X, today's collection) answered at T1 |

### 1.3 Design decisions

- **Where AI (the model) is used** — exactly three places: (1) copilot Q&A after cache miss,
  (2) the daily collection-pulse narrative (pre-warmed, shared), (3) draft-and-hold recovery
  messaging for escalated cases. Explicitly **NOT** AI: every amount, aging bucket, defaulter rank,
  reminder time, call-queue order, PTP status, collector score, receipt, and reminder text — all
  T0/T1. The "smart-reminder-timing" card is deterministic learned thresholds, relabeled *Smart*.
- **Cached & shared generations** — collection pulse: scope `school`, TTL to next 04:00 pre-warm,
  replaced nightly. Copilot/explain answers: scope `persona_scope+entity`, event-coupled class,
  24h cap, invalidated by `student:X:fees` tags. Recovery drafts are per-use (never cached — they
  carry family PII and human edits).
- **Event-driven intelligence** — `finance.fee_collected` → fee-aging, defaulter queue,
  target-vs-collected, kill `student:X:fees` + `school:fees` tags, drop family from today's call
  queue in seconds. `finance.invoice_created/due` → dues horizon + C9. PTP recorded (FIN-R3) →
  C9 deadline; PTP date passes unpaid (XCT-2 scan) → broken-PTP exception + queue score boost.
  Refund/concession maker-checker events → pending-approvals signal only (never AI-advised).
- **Dashboard adaptivity** — cards: KPIs, priority strip (call queue top-N, broken PTPs, stale
  refund approvals), defaulters, collection trend, pulse header. Reordering per doc 04 §5: pins
  win; ≤1 organic reposition/day, badged ("moved up — 12 PTPs broke this week"); telecaller persona
  learns queue-first ordering via accept/dismiss weights (P12).
- **Deterministic insights** — collection % vs target; aging drift week-over-week; top defaulter
  movements; PTP kept-rate; collector league; route/class-wise dues concentration; reminder→payment
  conversion by send-time. **AI insights** — pulse narrative phrasing; "explain why collections
  dipped" on demand; drafted escalation letters. Nothing else.
- **One-click actions** — call-queue row → dialer/WhatsApp with T0 template pre-selected + outcome
  logger + PTP capture form (FIN-R2/R3); defaulter card → "schedule reminder" pre-filled;
  parent-side "Fee due Friday" → Pay Fee deep link with child + invoice pre-selected (PAR-5).
  Confirmation is always human; payment execution is always the existing Finance rail.
- **Auto-summaries** — daily collection pulse (T2 pre-warmed, shared per school); weekly recovery
  summary for the principal (T1 table + optional cached T2 narrative); month-end collection
  digest (T1). No summary is generated live-on-open.
- **Proactive notifications** — T0 catalog: fee due T-3/T0/T+7 (FIN-6 dates), PTP due today,
  PTP broken (staff-facing), large-payment receipt confirmation (existing), unaudited-modification
  alert to principal. Parent messages respect language preference + digest-first default; staff
  overflow folds into the daily digest; quiet hours from Persona Memory.
- **Predictive workflows** — fee-default risk ↑ crossing the learned threshold → family enters the
  recovery queue at soft-reminder tier *before* due date (doc 04 §7); predicted chronic defaulter
  (repeat broken PTPs) → pre-staged escalation checklist for the finance head. Predictions come
  from the existing deterministic predictor; the model may only narrate them (P10).

### 1.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Build FIN-R2 call queue as a Priority Engine instance (not a bespoke feature) | one platform scorer with explainable factors + P12 learning instead of a hardcoded list; closes the flagship P1 | 🌟🌟🌟 | 100% (pure T1) | M | **W2** |
| Learned reminder-timing + follow-up thresholds per school (doc 03 §2.5) | "smart timing" becomes real, explainable, and free — vs an LLM guessing send times | 🌟🌟🌟 | 100% | S | **W2** |
| Wire FIN-6 real due-schedules into C9/XCT-2 reminder rules | reminders and aging stop lying (+30d hardcode); prerequisite for every timing feature above | 🌟🌟🌟 | 100% (T0) | S | **P1 precondition** (FIN-6, doc 09 §0) |
| PTP lifecycle as signals (recorded → due → kept/broken) driving queue boosts | FIN-R3 becomes self-maintaining via events instead of manual review | 🌟🌟 | 100% | S | **W2** |
| Pre-warmed shared daily collection pulse | one call/school/day off-peak vs a call per principal per open; T1 fallback always renders | 🌟🌟 | ~98% | S | **W2** |
| Draft-and-hold recovery letter (escalated cases only) | model does the one thing templates can't — tone-graded hard-case drafts — bounded ≤1 call/draft, human sends | 🌟🌟 | n/a (new; bounded) | S | **W3** |
| Copilot intent-fingerprint answers for enumerable finance intents | "dues of Aarav?" is T1, not a model call; biggest copilot-cost lever in this module | 🌟🌟 | 95%+ on those intents | S | **W1** |

---

## 2. HR

### 2.1 Snapshot (ground truth)

- **Readiness 🟡** — employee CRUD, recruitment kanban, leave approve, performance reviews shipped;
  staff attendance = geo + live-camera face per the **frozen attendance-auth decision** (never
  device biometric).
- **Existing intelligence:** Employee Intelligence (workload/burnout — deterministic, rename to
  Analytics per AI-6); an **AI attrition-risk card on HR-01** (audit: HR dashboard insight is one
  of the ~9 real Claude calls, deterministic fallback).
- **Governance:** maker-checker on leave and on manual attendance override (audited).
- **Key pains:** MOD-2 payroll cannot run on a fresh school (salary-structure model missing —
  **P1-CODE-5 builds it**); HR-2 payslips; HR-3 batch leave approve; HR-6 muster export;
  HR-7 document/probation expiry alerts; HR-8 no auto employee-provisioning.

### 2.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| HR-01 KPI widget (headcount, attendance, leave load, open positions) | T1 | P4 | Exists; re-based on `ai_fact_signals` staff rollups |
| Workload/burnout analytics | T1 | P2/P4 | Exists, deterministic. Relabel Analytics; thresholds become learned per school |
| Attrition-risk **score** | T1 | P2 | **Split:** the score = deterministic signals (attendance dips, leave patterns, tenure, review trend) with evidence shown |
| Attrition-risk **narrative** (HR-01 card) | T2/T3 | P10/P8 | Exists as live call → becomes explain-on-demand, cached per school per week; T1 factor list always renders |
| Leave-approval queue (aged, batch-selectable) | T1 | P3 + P11 | New surface of the Priority Engine; HR-3 batch approve = pre-staged multi-select, approval itself stays human + maker-checker |
| Doc/probation/contract expiry horizon | T1 | P2 | New (HR-7). C9 deadline family; learned lead times; feeds T0 alerts |
| Substitute suggestion on leave approval | T1 | P11 | Doc 04 §7: timetable × approved-leave join pre-computes free eligible teachers; suggestion only |
| Recruitment funnel next-action | T1 | P3 | Stage-age rules on the kanban (stale candidate, interview unscheduled); no model |
| Offer/appointment/experience letter draft | T3 | P9 | Draft-and-hold from templates + candidate facts; human edits; HR-2 payslips stay **pure T0 documents** (never AI) |
| New-joiner provisioning checklist | T0/T1 | P11 | HR-8: rule-generated task list (account, role, class links) pre-staged on `hr.employee_created`; each step human-confirmed |
| HR copilot Q&A ("who is on leave next week?") | T1→T3 | P7/P10 | Enumerable intents answered T1; novel questions T3 with write-through cache |
| Weekly staffing summary (principal) | T2 | P6/P5 | One shared generation per school per week from T1 facts |

### 2.3 Design decisions

- **Where AI (the model) is used** — (1) attrition/burnout narrative on demand (P8, cached),
  (2) letter drafts (P9), (3) copilot long-tail, (4) weekly staffing summary phrasing. Explicitly
  **NOT** AI: payroll (all math deterministic; MOD-2/P1-CODE-5 is a data-model build, no AI role),
  payslips (T0 documents), leave decisions, attendance/face verification (frozen design — AI never
  judges presence), muster export HR-6 (deterministic report), provisioning writes, review scores.
- **Cached & shared generations** — attrition narrative: scope `school`, stable class, 7d TTL,
  invalidated on `profile_version` bump or weekly signal recompute. Staffing summary: scope
  `school`, weekly pre-warm. Letter drafts: per-use, never cached. Copilot answers: event-coupled,
  invalidated by `school:approvals` / staff-entity tags.
- **Event-driven intelligence** — `hr.leave_requested/decided` → approvals-pending count+age,
  substitute pre-compute on approve, invalidate `school:approvals`. `hr.employee_created` →
  provisioning checklist + headcount signals. Attendance-device events → staff-attendance rollups.
  XCT-2 scans (time-driven, no natural event): doc/probation/contract expiry horizon, stale
  recruitment stages.
- **Dashboard adaptivity** — cards: KPIs, priority strip (aged approvals, expiring docs, unstaffed
  periods), burnout watchlist, recruitment funnel, staffing summary header. Doc 04 §5 rules: pinned
  first; approvals card auto-rises when count ≥ learned threshold, badged with the reason; ≤1
  organic move/day.
- **Deterministic insights** — leave-load heatmap by week; approval SLA (median age); attrition
  factor breakdown; workload variance across teachers; doc-expiry horizon; funnel conversion by
  stage. **AI insights** — attrition narrative ("what pattern is driving this score"); staffing
  summary prose; drafted letters. 
- **One-click actions** — "8 leave requests ≥48h" → batch-select approval screen (HR-3);
  "3 documents expire in 30 days" → renewal task + reminder schedule pre-filled (HR-7);
  "6-B uncovered Thursday P3" → substitute picker pre-filtered; stale candidate → schedule-interview
  form pre-filled. Approvals and writes remain human + maker-checker.
- **Auto-summaries** — weekly staffing summary (T2 shared); monthly HR digest — attrition
  watchlist + hiring + leave trends (T1 table, optional cached narrative); daily "who's out today"
  line on principal brief (pure T1 into doc 07's brief).
- **Proactive notifications** — T0 catalog: leave decision notices (existing), approval stale >48h
  (principal), doc/probation expiry T-30/T-7 (HR-7), interview-tomorrow reminder, provisioning
  step pending >3d. Staff-facing, digest-folded, quiet-hours aware. No parent-facing HR comms.
- **Predictive workflows** — attrition risk crossing learned threshold → pre-staged retention
  conversation checklist for principal (private to principal role); leave-approval about to vacate
  periods → substitute suggestion pre-staged *at decision time*, not after; probation ending →
  confirmation-review task auto-created T-14. All T1; narrative optional P10.

### 2.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Split attrition card: T1 evidence-backed score + cached on-demand narrative | today's always-on live call becomes ≤1 call/school/week; score gains explainability | 🌟🌟 | ~95% on this surface | S | **W2** (W2.7 ops worklists) |
| Leave-approval queue on the Priority Engine + HR-3 batch one-click | closes a named P1 pain with the platform scorer; approval SLA becomes visible | 🌟🌟🌟 | 100% | M | **W2** |
| Doc/probation expiry signals + T0 alert rules (HR-7) | compliance clock served by rules — the naive build would poll or ask a model to "check" | 🌟🌟 | 100% | S | **W2** |
| Substitute pre-staging on leave approval | prediction becomes an action at the moment of decision; pure timetable join | 🌟🌟 | 100% | M | **W2–W3** |
| Provisioning checklist on `hr.employee_created` (HR-8) | rule automation with human confirmation — no AI needed, big admin pain closed | 🌟🌟 | 100% | S | **W2** |
| Letter drafts as P9 (offer/appointment/experience) | model earns its cost only where a human edits anyway; payslips explicitly excluded | 🌟 | n/a (bounded ≤1/draft) | S | **W3** |

---

## 3. Library

### 3.1 Snapshot (ground truth)

- **Readiness ✅** — catalog, issue/return (14-day due, row-locked), fines with audited waive,
  members, digital resources all live.
- **Existing intelligence:** LB-01 KPI widget only — overdue **count** exists as a KPI, with no
  actionable list behind it.
- **Key pains:** LIB-1 no actionable overdue list; LIB-2 no catalog CSV import; LIB-5 overdue
  reminders unbuilt (needs XCT-2); MOD-1 fines never post to the Finance ledger (Finance is the
  sole payment engine — library raises the demand only, mirroring TRN-9).

### 3.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| LB-01 KPIs (issued, overdue count, fines, active members) | T1 | P4 | Exists; re-based on overdue-list signal so count and list can never disagree |
| Overdue worklist (student, book, days, fine accrued) | T1 | P4 + P11 | New (LIB-1). The count becomes actionable rows with contact affordances |
| Overdue reminders (parent-facing) | T0 | P1 | New (LIB-5). Catalog template + slots + language variant, scheduled T+1/T+7 via XCT-2 |
| Chronic-offender escalation note | T3 | P9 | Draft-and-hold for repeat cases only (≥3 overdues, learned); routine reminders never touch the model |
| Fine accrual → Finance demand | T1 | — | Not AI: MOD-1 posting rule; the signal ("₹340 uncollected fines") is T1 |
| Circulation trends / dead-stock list | T1 | P4 | Books never issued in N months, class-wise reading rates — pure rollups |
| Catalog CSV import (LIB-2) + column-mapping suggestion | T0/T1 | — | Import is a deterministic tool; header-mapping suggestions = string-similarity rules, **not** a model |
| "Explain circulation trend" | T2/T3 | P8 | Optional affordance on the trends card; cached per school per term |

### 3.3 Design decisions

- **Where AI (the model) is used** — only (1) the chronic-offender escalation draft (P9) and
  (2) explain-on-demand for trends (P8). Explicitly **NOT** AI: overdue detection and ordering
  (due-date rules), fine amounts (policy math, posted to Finance per MOD-1), reminder text (T0
  catalog), CSV import mapping (deterministic heuristics), member management. Library is the
  cleanest proof that "an intelligent module" can be ~98% model-free.
- **Cached & shared generations** — trend explanation: scope `school`, stable class, 7–30d TTL,
  `profile_version`-invalidated. Escalation drafts: per-use, uncached. Nothing else in Library
  warrants a cache entry.
- **Event-driven intelligence** — `library.loan_created/returned` → overdue list, fine accrual,
  circulation counters; invalidate `student:X:library`. Nightly XCT-2 scan promotes loans past due
  into the overdue signal and schedules the T+1/T+7 reminder rules; return event cancels pending
  reminders for that loan (dedupe rail).
- **Dashboard adaptivity** — cards: KPIs, overdue worklist (auto-rises when overdue count crosses
  the learned threshold, badged "14 overdue >7 days"), circulation trend, dead-stock. Librarian
  pins win; ≤1 organic move/day per doc 04 §5.
- **Deterministic insights** — overdue aging distribution; fines outstanding vs collected (via
  Finance); most/least circulated titles; class-wise reading rate; dead-stock candidates;
  lost-book rate. **AI insights** — trend explanation on demand; escalation-note drafts. Two items,
  by design.
- **One-click actions** — overdue row → send reminder (T0 template pre-selected, parent language) +
  mark-returned shortcut; worklist header → batch-remind selected (staged, human-confirmed);
  dead-stock row → add to stock-take/weed list; fines card → "raise Finance demand" (MOD-1 rail)
  pre-filled, posted by Finance not by Library.
- **Auto-summaries** — monthly circulation digest for the principal: T1 table (issues, overdues,
  fines, top titles) with an optional cached T2 narrative header — never generated live-on-open.
- **Proactive notifications** — T0 catalog: overdue T+1 (gentle, parent language), T+7 (firmer,
  fine stated from policy math), librarian daily worklist line, chronic-offender flag to class
  teacher (in-app). Parents default digest-first; per-family dedupe (one message covering multiple
  overdue books, slot-filled list).
- **Predictive workflows** — "will go overdue" = due-in ≤2 days with a due-tomorrow nudge already
  scheduled (a rule, honestly not a prediction — named accordingly); chronic-offender threshold
  crossing → escalation draft pre-staged for the librarian; reorder/weeding candidates from
  circulation rates → stock-take list pre-staged for year-end.

### 3.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Overdue worklist (LIB-1) as exception surface + one-click remind | turns a dead KPI into daily-actionable rows; pure T1 | 🌟🌟🌟 | 100% | S | **W2** |
| Overdue reminder rules on XCT-2 with T0 catalog (LIB-5) | naive build would LLM-write each reminder; catalog + slots costs zero forever | 🌟🌟🌟 | 100% | S (after XCT-2) | **W2** |
| MOD-1 fine demand → Finance ledger as a signal-carrying rail | one payment engine (TRN-9 symmetry); recovery CRM sees library dues too | 🌟🌟 | 100% | M | **P1 precondition** (MOD-1 👤, doc 09 §0) |
| Dead-stock + circulation rollups | catalog-cleanup worklist for free from data already written | 🌟 | 100% | S | **W3** |
| Chronic-offender escalation as P9 draft | the only Library surface where language work has value; bounded, rare | 🌟 | n/a (bounded) | S | **W3** |

---

## 4. Transport

### 4.1 Snapshot (ground truth)

- **Readiness 🟡** — TRN-1..9 backend shipped, **verify live**. Routes/stops, vehicle + driver CRUD
  with doc-expiry fields (insurance/fitness/PUC/permit/license), allocation + occupancy, delay
  broadcast.
- **Live GPS = Phase 2 (O8)** — this design deliberately contains **no GPS feature**; anything
  needing live location is out of scope until O8 lands.
- **Existing intelligence:** TR-01 KPIs + an "AI route-optimization" card + an "AI Transport
  Copilot" (delay prediction, absent-pickup risk) — both re-placed honestly below.
- **Frozen TRN-9:** Transport raises fee **demand only**; Finance is the sole payment engine —
  transport dues surface inside Finance's recovery machinery, not here.
- **Key pains:** TRN-2 expiry fields are free-text (must become typed dates before any alerting);
  TRN-3 stop-wise roster print; TRN-7 no over-allocation warning.

### 4.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| TR-01 KPIs (vehicles, routes, occupancy, dues raised) | T1 | P4 | Exists; occupancy from allocation signals |
| Doc-expiry horizon (insurance/fitness/PUC/permit/license) | T1 | P2 | Requires TRN-2 typed dates; C9 deadline family; T-30/T-7 alert rules |
| Over-allocation warning (TRN-7) | T1 | P2 | Hard rule at allocation time (block/warn per policy) **and** a standing exception card |
| Route-load balance suggestions | T1 | P4/P11 | **Re-placed** "route optimization": without GPS this is stop-load × capacity arithmetic — suggest moving N students from over- to under-loaded route; suggestion only |
| Absent-pickup list (today) | T1 | P4 | **Re-placed** copilot claim: absent-today students ⨯ route roster join — pure T1, refreshed on `attendance.submitted` |
| Delay broadcast composer | T0 + T3 | P1/P9 | Standard delays = T0 catalog templates (route, ETA slots, parent language). Unusual incident text = optional P9 draft; human sends; localization stays T0 catalog |
| Stop-wise roster print (TRN-3) | T0 | — | Not AI: a deterministic document template |
| Transport copilot Q&A ("which routes have space?") | T1→T3 | P7 | Enumerable intents (capacity, roster, expiry) answered T1; long-tail T3 with cache |
| Compliance digest (fleet documents status) | T1 | P4/P6 | Weekly deterministic table; no narrative needed |

### 4.3 Design decisions

- **Where AI (the model) is used** — (1) optional incident-broadcast draft (P9), (2) copilot
  long-tail (rare; the transport question space is mostly enumerable). Explicitly **NOT** AI:
  route "optimization" (deterministic load-balance math until GPS exists — the current AI card is
  relabeled *Smart route load*), delay **prediction** (no live GPS signal exists to predict from —
  the honest W-now build is historical delay patterns per route as a T1 stat; true prediction
  waits for O8), absent-pickup risk (a join, not a model), doc-expiry (rules), fee math (Finance's,
  per TRN-9), allocation decisions.
- **Cached & shared generations** — copilot answers: event-coupled, invalidated by
  `school:transport` tags. Broadcast drafts: per-use, uncached. Route-load suggestions: T1, no
  cache needed beyond `ai_fact_signals` freshness. Transport generates almost no cacheable prose —
  correct for a rules-dominant module.
- **Event-driven intelligence** — `transport.allocation` → occupancy per route, over-capacity
  exception (TRN-7), invalidate `school:transport`. `transport.doc_update` → expiry horizon
  recompute. `attendance.submitted` → absent-pickup list for afternoon routes. XCT-2 scans:
  expiry T-30/T-7 rules; allocation-vs-capacity drift check nightly.
- **Dashboard adaptivity** — cards: KPIs, priority strip (expiring docs, over-capacity routes),
  absent-pickup list (rises on days it is non-empty — the strongest "appears when relevant"
  example in this doc), load-balance suggestions, compliance digest. Doc 04 §5 constraints apply;
  transport-in-charge pins win.
- **Deterministic insights** — occupancy % per route/vehicle; expiry horizon (days-to, per
  document); over-capacity list; historical delay frequency per route (once delay broadcasts are
  logged); allocation churn; dues-raised vs collected (read from Finance signals, TRN-9).
  **AI insights** — incident-broadcast draft; copilot long-tail answers. Nothing else.
- **One-click actions** — "Bus 7 permit expires in 21 days" → renewal task + reminder schedule
  pre-filled (doc 04 §4); over-capacity card → allocation screen filtered to that route with
  candidate under-loaded routes side-by-side; absent-pickup row → notify-driver template (T0,
  owner-gated channel); delay event → broadcast composer with route + stops + template pre-filled.
- **Auto-summaries** — weekly fleet-compliance digest (T1 table: every vehicle × every document ×
  days-to-expiry) to principal + transport-in-charge; monthly occupancy summary (T1). No model
  narrative is warranted — tables are the right form for compliance data.
- **Proactive notifications** — T0 catalog: doc expiry T-30/T-7 (staff), route over-capacity on
  allocation (immediate, staff), delay broadcast (parent-facing, per-route fan-out, language
  variant, owner-gated channels), fee-demand raised confirmation (parent, via Finance rail).
  Per-route dedupe: one delay message per route per event.
- **Predictive workflows** — expiry horizon → renewal workflow pre-staged at T-30 with documents
  checklist; persistent over-capacity (≥N days, learned) → re-allocation proposal pre-staged
  (load-balance suggestion promoted to a task); recurring route-delay pattern (T1 stat) →
  suggest standing early-dispatch note to that route's parents (T0, human-approved).

### 4.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| TRN-2 typed expiry dates → C9 signals + T0 alert rules | unlocks the entire compliance clock; free-text dates make every alert impossible today | 🌟🌟🌟 | 100% | S | **P1 precondition** (TRN-2, doc 09 §0) |
| Over-allocation rule at write time + standing exception card (TRN-7) | prevention beats detection; one rule serves both | 🌟🌟 | 100% | S | **W2** |
| Re-place "route optimization" as deterministic load-balance suggestions | honest, explainable, free — and actually actionable without GPS | 🌟🌟 | 100% (vs a fake AI card) | S | **W2** |
| Absent-pickup list on `attendance.submitted` | the copilot's flagship claim served as a join, fresh within seconds | 🌟🌟 | 100% | S | **W2** |
| Delay broadcast: T0 catalog templates + optional P9 incident draft | routine delays cost zero; the model only writes the unusual | 🌟🌟 | ~95% | S | **W2** |
| Historical delay-pattern stats (defer true prediction to O8/GPS) | keeps the promise honest; the T1 stat is still useful for parents | 🌟 | 100% | S | **W3** |

---

## 5. Inventory

### 5.1 Snapshot (ground truth)

- **Readiness 🟡** — INV-1..7 shipped, **verify live**. Asset registry, PO → approve → GRN, stock
  issue/adjust/count, consumables with reorder thresholds, low-stock prediction display.
- **Frozen inventory governance:** value-reducing movements (damage/wastage write-off, negative
  variance) = **maker-checker** (SoD, reusing FIN-D4 machinery); stock-in/opening/positive
  variance = single-approver; hard-block negative stock (DB CHECK); weighted-avg costing;
  immutable posted slips (reversal-only); immutable `stock_movements` ledger.
- **Key pains:** INV-4 reorder recommendations not linked to `createPurchaseOrder`; INV-6 physical
  stock-take; INV-7 alerts are display-only (needs XCT-2 to actually notify).

### 5.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| Stock KPIs (value, low-stock count, open POs, pending GRNs) | T1 | P4 | Exists; value from weighted-avg costing (never AI-computed) |
| Reorder point per item (learned) | T1 | P2 | Doc 01 §7 worked example: consumption rate × lead time, learned per school per item; evidence stored (doc 03 §2.5) |
| Low-stock alert (actually notifies) | T0 | P1 | INV-7: Signal Refinery match → catalog-templated notification via XCT-2; today it is display-only |
| Reorder → pre-filled PO | T1 | P11 | INV-4: recommendation row carries a draft PO into `createPurchaseOrder` (item, qty = reorder gap, last vendor, last price); approval chain untouched |
| Consumption anomaly flags | T1 | P4 | Spike vs item's own baseline (write-off surge, issue-rate jump); routes to review, and value-reducing cases into the existing maker-checker queue |
| Stock-take variance worklist (INV-6) | T1 | P4 | Count session → variance rows ranked by value impact; negative variance auto-enters maker-checker per frozen governance |
| Dead/slow-moving stock list | T1 | P4 | No issues in N months (learned N); year-end disposal candidates |
| "Explain this consumption trend" | T2/T3 | P8/P10 | Optional affordance; facts injected; cached per item-category per term |
| Inventory copilot Q&A ("how much chalk left?") | T1→T3 | P7 | Stock questions are enumerable → T1 intents; long-tail T3 cached |

### 5.3 Design decisions

- **Where AI (the model) is used** — (1) explain-on-demand on consumption trends (P8, cached),
  (2) copilot long-tail. Explicitly **NOT** AI: reorder quantities and points (learned arithmetic —
  the shipped "low-stock prediction display" is relabeled *Smart reorder*), stock valuation
  (weighted-avg, frozen), variance math, anomaly thresholds (statistical baselines), PO/GRN/write-off
  decisions (approval chains + maker-checker, frozen), negative-stock prevention (DB CHECK).
  Inventory demand in a school is seasonal and small-N — statistics beat a model here on both
  accuracy and cost.
- **Cached & shared generations** — trend explanations: scope `school+item_category`, stable class,
  7–30d TTL. Copilot answers: event-coupled, invalidated by `school:inventory`. Nothing money- or
  movement-related is ever served from cache — stock numbers always render live T1 (doc 03 §3.5
  staleness rule: prose from cache, numbers live).
- **Event-driven intelligence** — `inventory.grn` → stock level, open-PO close, reorder-gap
  recompute; `inventory.issue` → consumption rate update, low-stock check against learned reorder
  point; `inventory.adjustment` → anomaly screen + (if value-reducing) maker-checker queue signal;
  all invalidate `school:inventory`. Nightly: reorder-point re-learning, dead-stock scan,
  anomaly-baseline refresh.
- **Dashboard adaptivity** — cards: KPIs, priority strip (below-reorder items, pending GRNs, aged
  PO approvals, open variance reviews), reorder recommendations, anomaly flags, dead stock. The
  reorder card rises as the below-reorder count grows (badged with the count); storekeeper pins
  win; ≤1 organic move/day.
- **Deterministic insights** — items below reorder point (+ days-to-stockout at current rate);
  consumption rate per item/category vs last term; write-off value trend; variance summary per
  count session; vendor lead-time actuals (GRN date − PO date); dead-stock value. **AI insights** —
  trend explanation on demand; copilot long-tail. Two items.
- **One-click actions** — "Chalk below reorder point" → pre-filled PO draft into
  `createPurchaseOrder` (INV-4; human submits, approval chain unchanged); anomaly flag → movement
  ledger filtered to the item + review-note form; variance row → adjustment slip pre-filled
  (maker-checker path auto-selected for negative values); dead-stock row → add to disposal/
  write-off proposal (maker-checker).
- **Auto-summaries** — monthly stock summary (T1: value movement, top consumption, write-offs,
  variance) for principal/trustee; stock-take session close → variance summary (T1) to the checker
  role. Narrative optional and cached (P10) — tables carry compliance weight here, prose does not.
- **Proactive notifications** — T0 catalog via XCT-2 (closes INV-7's display-only gap): low-stock
  when crossing reorder point (storekeeper, deduped per item per week), GRN pending >N days after
  PO, variance review pending (checker), stock-take session reminder (term calendar). All in-app
  first; external channels owner-gated.
- **Predictive workflows** — days-to-stockout (rate arithmetic) < lead time → PO pre-staged
  *before* the low-stock alert would fire (the reorder recommendation is the predictive workflow);
  term-start consumption surge (seasonal pattern from last year) → pre-term stock-up checklist
  pre-staged; recurring write-off pattern on an item → review task suggesting spec/vendor change.
  All T1; model narrates only on request.

### 5.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Learned reorder points (rate × lead time, evidence-backed) | the canonical doc 01 worked example; adaptive per school with zero model calls | 🌟🌟🌟 | 100% | S | **W2** |
| Reorder → pre-filled `createPurchaseOrder` (INV-4) | recommendation becomes an action; reuses the existing PO path per frozen decision | 🌟🌟🌟 | 100% | S | **W2** |
| Low-stock + GRN/variance notification rules on XCT-2 (INV-7) | alerts that alert; naive build would poll or LLM-summarize stock daily | 🌟🌟 | 100% | S (after XCT-2) | **W2** |
| Consumption anomaly baselines feeding the maker-checker queue | governance gets an early-warning input without touching the approval design | 🌟🌟 | 100% | M | **W2–W3** |
| Stock-take variance worklist (INV-6) ranked by value impact | makes the physical count actionable; negative variance auto-routes to SoD | 🌟🌟 | 100% | M | **W3** |
| Explain-on-demand on consumption trends | the only model surface Inventory needs; cached per category per term | 🌟 | ~95% | S | **W3** |

---

## 6. Cross-module invariants (operations cluster)

1. **One payment engine.** Library fines (MOD-1) and transport fees (TRN-9) raise demand signals
   into Finance; the Fee-Recovery CRM (§1) is therefore the *single* collection surface for all
   money across this cluster — no per-module recovery features.
2. **One compliance clock.** HR doc/probation expiry (HR-7), transport document expiry (TRN-2),
   and library/inventory scheduled scans are all C9 deadline signals + T0 rules on the same XCT-2
   rail — one scanner pattern, four consumers.
3. **Maker-checker is a boundary, not a surface.** In all five modules AI may *fill queues that
   lead to* an approval (anomalies, variances, refund contexts) but no tier — including T1 — ever
   auto-decides, batches-without-selection, or reorders an approver's legal obligations.
4. **Tier accounting.** Across the ~45 surfaces mapped above, 3 are T0, ~32 are T1, ~5 are T2, and
   ~5 are T3-capable (all P8/P9 opt-in or cache-fronted) — comfortably inside the ≥90% T0–T2
   impression invariant, since the T3 surfaces fire only on explicit taps or bounded drafts.
5. **Verify-live first.** Transport (TRN-1..9) and Inventory (INV-1..7) carry "shipped, verify
   live" status; their W2 items assume that verification passes and must re-scope if it does not.

---

*Companions: [`05_MODULE_AI_DESIGN_ACADEMIC.md`](05_MODULE_AI_DESIGN_ACADEMIC.md) (academic modules) ·
[`07_PERSONA_AI_DESIGN.md`](07_PERSONA_AI_DESIGN.md) (persona routers that consume these surfaces).*
