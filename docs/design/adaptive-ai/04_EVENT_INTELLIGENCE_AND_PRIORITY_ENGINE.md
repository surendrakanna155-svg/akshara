# Adaptive AI Design 04 — Event Intelligence, Priority Engine & Adaptive Dashboards

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` · **Framework:** [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md) · **Feeds on:** [`03_MEMORY_AND_CACHING_STRATEGY.md`](03_MEMORY_AND_CACHING_STRATEGY.md)
**Anchors:** Blueprint §6/§8/§9/§10 · Roadmap **P3-AI-1** item 5, **P3-AI-2** items 7/9/10/12 · Depends on **P1-PROD-0 (XCT-2 reminder/scheduling rail)**.

> **Purpose.** This document designs the *proactive* half of Adaptive AI — and it is almost
> entirely **Tier 1 (zero model calls)**. Ground truth: `domain_events` already records **157 event
> types** through a transactional outbox (`audit/audit_repository.ts`), but the worker only flips
> `pending→published` — **there are no consumers, no scheduler, no reminder rail**. This design
> adds the missing nervous system: events keep memory fresh, memory feeds a Priority Engine,
> priorities become recommendations with one-click actions, and dashboards reorder themselves —
> all deterministic, all explainable, all free.

---

## 1. Architecture

```
domain_events (157 types, existing outbox)
      │ consume (new: Signal Refinery worker)
      ▼
┌─ SIGNAL REFINERY (T1) ─────────────────────────────┐
│ event → ① update ai_fact_signals (incremental)      │
│         ② invalidate cache entries by entity_tag    │
│         ③ re-score affected priority items          │
│         ④ match notification rules → T0 emissions   │
└────────────────────────────────────────────────────┘
      ▼                          ▼
PRIORITY ENGINE (T1)      NOTIFICATION RULES (T0)
ordered per-persona feed   templated, deduped, quiet-hours
      ▼
RECOMMENDATION ENGINE (T1 + P11 one-click actions)
      ▼
ADAPTIVE DASHBOARD COMPOSER (Widget Platform, T1)
      +  optional Explain/Narrate affordances (T2/T3, doc 01 P8/P10)
```

**Scheduler dependency (explicit):** nightly recompute, pre-warm, digests, and deadline scans ride
the **XCT-2 reminder/scheduling rail** (P1-PROD-0). XCT-2 is a Phase-1 deliverable; this design
consumes it and adds AI-specific jobs — it does not duplicate it. Until XCT-2 lands, the Signal
Refinery can run on-drain (piggybacking the existing outbox drain endpoint); scheduled jobs cannot.

---

## 2. The Signal Refinery (the new `domain_events` consumer)

A single idempotent worker (at-least-once safe: every step is an upsert or tag-invalidate) mapping
event families to actions. Representative mappings (full catalog to be enumerated at build time from
`mutation_audit_catalog.ts` — 157 types, ~40 carry signal value):

| Event (family) | Fact/Signal update | Cache tags invalidated | Notification rule (T0) |
|---|---|---|---|
| `finance.fee_collected` | fee-aging bucket, defaulter queue, collection-vs-target | `student:X:fees`, `school:fees` | receipt confirmation (existing) |
| `finance.invoice_created / due` | dues horizon, C9 deadlines | `student:X:fees` | fee-due reminder (schedule via XCT-2) |
| `attendance.submitted` | class/school attendance %, absentee list, chronic-absentee counters | `class:Y:attendance` | absent-alert fan-out (existing, gated) |
| `attendance.not_marked_by_cutoff` *(derived — scan job)* | unmarked-classes exception list | `school:attendance` | nudge teacher; escalate to principal at T+n (ATT-4) |
| `exam.marks_saved / published` | marks-completion per teacher, weak-subject rollups, at-risk re-score | `exam:Z`, `student:*:marks` | results-published notice (existing gate) |
| `homework.assigned / submitted` | submission-rate, not-submitted list | `class:Y:homework` | due-tomorrow reminder (needs HWK-1 real dates) |
| `hr.leave_requested / decided` | approvals-pending count+age | `school:approvals` | decision notice (existing) |
| `admissions.stage_changed` | funnel counts, follow-up-due queue, conversion signals | `school:admissions` | follow-up-due (counselor) |
| `library.loan_created / returned` | overdue list, fine accrual | `student:X:library` | overdue reminder (LB-5) |
| `inventory.grn / issue / adjustment` | stock levels vs reorder points | `school:inventory` | low-stock alert (INV-7) |
| `transport.allocation / doc_update` | capacity per route, doc-expiry horizon | `school:transport` | expiry warnings (TRN-2/8) |

**Idempotency & ordering:** per-entity monotonic `occurred_at` guard; replays are harmless
(upserts); a full nightly recompute (XCT-2 job) corrects any drift — the event path is an
*accelerator*, the nightly job is the *guarantee*.

---

## 3. The Priority Engine (T1 — the "what matters now" layer)

### 3.1 Item taxonomy
Every actionable thing becomes a typed **priority item**: `approval` (leave/admission/refund/PO…),
`deadline` (marks due, fee due, doc expiry, PTM), `exception` (unmarked attendance, not-submitted,
low stock, over-capacity, broken PTP), `follow-up` (lead call due, defaulter call, overdue book),
`opportunity` (at-risk student improving, idle capacity).

### 3.2 Scoring (deterministic, explainable)
```
score = urgency(due_in, escalation_age)
      × impact(money_at_stake | students_affected | compliance_class)
      × age_boost(waiting_time)
      × learned_weight(school, persona, item_type)     # from accept/dismiss history (doc 03 §2.2/2.5)
```
Every score carries its factor breakdown — the UI can always answer **"why is this first?"**
(explainability rail, doc 01 §6). Weights start from sane global defaults; the nightly job tunes
them per school from behaviour (a school that always clears approvals first keeps approvals up top;
one that ignores library nudges sees them fold into the digest).

### 3.3 Per-persona feeds
One engine, persona-filtered outputs: the teacher sees *her* classes' items; the principal sees
school-level exceptions + approvals; the director sees only aggregate/compliance items (privacy
rule preserved). Feeds are served from `ai_fact_signals` + item store — **<150ms, zero model calls,
always on**, even offline-cached for first paint.

---

## 4. The Recommendation Engine (T1 + one-click actions)

A recommendation = **priority item + pre-staged action** (pattern P11). The action carries a
deep-link and a pre-filled payload; the human confirms — **AI never executes** (governance rail).

| Persona | Recommendation | One-click action (pre-staged) | Backlog it closes |
|---|---|---|---|
| Teacher | "2 classes unmarked — 6-B has 4 absentees pending" | open marker with **absentees-only fast-mark** | ATT-3, TCH-1 |
| Teacher | "Marks for Unit-2 Maths due in 2 days, 12/30 entered" | open bulk marks grid at row 13 | EXM-1/6, TCH-2 |
| Principal | "8 approvals ≥48h old (5 leave, 3 admissions)" | **batch-select Approval Center**, summary per row | PRI-1/5 |
| Principal | "3 teachers owe marks past deadline" | marks-completion board → one-tap nudge (T0 template) | EXM-2, PRI-2 |
| Finance/Office | "Today's call queue: 8 defaulters (₹1.2L, aging 60+)" | telecaller queue: call/WhatsApp + outcome log + PTP capture | FIN-R2/R3 |
| Office/Counselor | "5 follow-ups due today, 2 hot leads idle 3 days" | actionable follow-up rows (call/log/reschedule) | ADM-4 |
| Parent | "Fee installment due Friday — ₹8,500" | Pay Fee (Razorpay) pre-selected child+invoice | PAR-5 |
| Librarian | "14 books overdue >7 days" | overdue worklist + reminder batch (draft-and-hold) | LIB-1/5 |
| Storekeeper | "Chalk below reorder point (learned)" | pre-filled PO → `createPurchaseOrder` | INV-4/7 |
| Transport | "Bus 7 permit expires in 21 days" | renewal task + reminder schedule | TRN-2/8 |

**Learning loop (P12):** accept → weight up; dismiss → weight down; "don't show again" → suppress
class. All Persona Memory, all T1. The model is involved **only** if the user taps "explain" (P8)
or a draft is requested (P9).

---

## 5. Adaptive dashboards (on the existing Widget Platform)

Composition, per login, deterministic:
```
layout = defaults(role, vertical_pack)                 # existing widget_pack_catalog
       ∩ capabilities(school)                          # existing filterLayoutByCapabilities
       + priority_strip(top-N feed items)              # NEW — pinned strip, always first
       ↑ reorder by usage_frequency (persona memory)   # NEW — frequently-used rise
       ↓ decay dismissed/never-opened widgets          # NEW — sink, then fold into "More"
```
**Stability constraints (anti-disorientation):** user pins always win; at most **one** organic
reposition per day; a moved card is badged "moved up — 3 unmarked classes" (explainability);
layout changes are per-user rows in `dashboard_layouts` (existing table — the tenant/role override
mechanism already supports this shape).

Widgets stay deterministic-first with optional **Explain** (P8) and, where designed, a cached
narrative header (P6). The 60s in-memory widget cache is superseded by `ai_fact_signals` freshness
(event-driven, seconds-fresh, cross-isolate).

---

## 6. Proactive notifications & digests (T0)

- **Every proactive message is catalog-templated** (extend the frozen deterministic comms catalog +
  `communication_generator` scenarios) — slot-filled, language-variant by
  `parent_language_preferences`. **No LLM in the send path, ever.**
- **Rules fire from the Signal Refinery** (event) or XCT-2 scans (time): fee due T-3/T0/T+7 ·
  homework due-tomorrow · marks-deadline T-2 · doc/permit expiry T-30/T-7 · PTM T-1 ·
  approval stale >48h · low stock · broken PTP.
- **Dedupe + digestion:** per-user per-day budget (learned quiet hours, doc 03); overflow folds
  into a single daily digest; parents default to digest-first (adoption-safe).
- **Channel governance unchanged:** in-app now; push/SMS/WhatsApp remain owner-gated (existing
  `Notifications.md` dispatch model).

## 7. Predictive workflows (T1 predictions + pre-staging)

Reuse the three deterministic predictors (`predictions_service.ts`: fee-default,
admission-conversion, student-risk) and **act on them earlier in the workflow**:
- fee-default risk ↑ → student enters the recovery queue *before* the due date (soft-reminder tier);
- admission-conversion band → next-best-action on the lead card (call vs visit vs document nudge);
- student-risk ↑ → intervention checklist pre-staged for class teacher + counselor (at-risk list
  already computed by `student_risk_engine`);
- substitute suggestion pre-computed when a leave approval would vacate periods (timetable × leave
  join — pure T1).

Optional model narrative on any of these stays P10 (facts computed, phrasing cached).

---

## 8. Recommendations (rubric per doc 01 §5)

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Signal Refinery consumer on `domain_events` | turns an existing, already-emitting stream into live intelligence; no polling, no recompute storms | 🌟🌟🌟 | enabler (keeps T1/T2 fresh so T3 stays rare) | M | **W1** |
| Priority Engine (typed items + explainable score) | "what matters now" for every persona with zero model calls; the moat competitors fake with chatbots | 🌟🌟🌟 | 100% (pure T1) | M–L | **W2** |
| Recommendation Engine + one-click pre-staged actions | closes a dozen named backlog pains (PRI-1, ADM-4, FIN-R2, ATT-3…) as one platform pattern instead of N features | 🌟🌟🌟 | 100% (T1; P8/P9 opt-in only) | L | **W2** |
| Adaptive dashboard reordering (bounded, badged) | per-user adaptivity that never disorients; rides existing `dashboard_layouts` | 🌟🌟 | 100% | M | **W2** |
| Notification rules + digests on XCT-2 (all T0) | proactivity without spam or spend; parents' most-requested gap (PAR-5) | 🌟🌟🌟 | 100% | M (after XCT-2) | **W2** |
| Predictive pre-staging on existing predictors | predictions become *actions*, not charts; zero new model surface | 🌟🌟 | 100% | M | **W2–W3** |

---

*Next: docs [`05`](05_MODULE_AI_DESIGN_ACADEMIC.md)/[`06`](06_MODULE_AI_DESIGN_OPERATIONS.md)/[`07`](07_PERSONA_AI_DESIGN.md)
apply this machinery module-by-module and persona-by-persona.*
