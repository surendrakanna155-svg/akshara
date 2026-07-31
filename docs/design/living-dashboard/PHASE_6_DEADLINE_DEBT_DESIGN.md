# Phase 6 — Deadline Debt: making `urgency` real

**Status:** 🟢 **6a IMPLEMENTED** (`390dd378`) · 🔴 **6b = OWNER DECISION, SLA targets pending** ·
🔵 **6c = POST-PILOT PRODUCT DECISION** · **Date:** 2026-07-31
**Parent workstream:** CLOSED 2026-07-31, EOS verdict PASS — see
[`LIVING_DASHBOARD_ARCHITECTURE.md`](LIVING_DASHBOARD_ARCHITECTURE.md) §7/§8.
This document stays open as the ready-to-build spec for 6b/6c.

> **The problem in one line.** The Priority Engine multiplies four factors, and
> today roughly one and a half of them vary. Everything built in Phases 1–4 ranks
> honestly — it just ranks on a signal the database mostly cannot provide.

---

## 1. What is actually broken

### 1.1 `urgency` is a near-constant

`urgencyFactor` prefers `dueInDays` and falls back to `impactClass` when there is
no date. Across **269 migrations, only 7 tables carry a real due-date column**:

`complaints.sla_due_at` · `director_compliance_items.due_date` ·
`finance_promises_to_pay.promise_date` · `growth_inquiries.follow_up_at` ·
`teacher_interventions.follow_up_at` · `edu_homework_assignments.due_date` ·
`gate_passes.scheduled_at`

**Every approval and maker-checker queue is deadline-free** — `approval_requests`,
`stock_adjustments`, `finance_fee_reductions`, `student_clearance_waivers`,
`staff_attendance_requests`, `mobile_leave_requests`, `attendance_corrections`.
So for most work items the engine falls back to a fixed severity constant, and
two items an hour apart from breaching score identically.

### 1.2 `ageBoost` is dead code

`ageBoostFactor` ramps on `factors.waitingDays`. **No generator sets it** — the
field is never populated anywhere in the repo. So `ageBoost` is permanently
`1.0`, the UI's "recency ×1.0" can never be anything else, and *"an approval
nobody has touched in two weeks climbs above a fresh one"* — the behaviour that
comment promises — does not happen.

### 1.3 Two of five item types are never produced

`approval` and `opportunity` are declared in the taxonomy and produced by **zero**
generators. Doc 04 §4's headline principal recommendation — *"8 approvals ≥48h
old (5 leave, 3 admissions)"* — is not computable today, because nothing emits an
approval item and nothing knows how long one has waited.

### 1.4 There is no assignee

Only `complaints.assigned_to` and `support_platform_incident.assigned_to` exist.
`director_compliance_items.owner` is free text, not a user FK. So "whose queue is
this?" is answered by RBAC role, never by ownership — which is why the feed can
say *"8 approvals are stale"* but never *"5 of them are yours"*.

---

## 2. Design

### 2.1 A wait clock beats a due date

**Do not** invent SLA due-dates for the approval spine first. Two reasons:

1. A due date on an approval is a **policy** decision (what IS the SLA for a
   leave request? per school? per type?) and needs owner input. A wait clock is a
   **fact** we already store — `approval_requests.created_at` — and needs none.
2. It closes §1.2 and §1.3 together: `waitingDays = now − created_at` revives
   `ageBoost` *and* makes an `approval` item expressible, with no schema change
   and no policy question.

So Phase 6 lands in two waves, cheap-and-factual first:

| Wave | Change | Schema? | Owner input? |
|---|---|---|---|
| **6a** | ✅ **DONE** — `waitingDaysSince()` + the `approval` generator | **No** | No |
| **6b** | Add `sla_due_at` to the approval spine + a per-school SLA policy table | Yes | **Yes — the SLA values** |
| **6c** | `opportunity` generator (needs 6a/6b signals to be worth anything) | No | Product |

### 2.2 Wave 6a — the approval generator

New source `approval_sources.ts`, following the existing `ops_sources.ts` shape
exactly (permission-gated loader, pure generator, one summary item per bucket —
never a row per entity, per the standing feed-flood rule):

```
itemKey:  ops:approvals:<type>            e.g. ops:approvals:staffLeave
type:     "approval"
factors:  waitingDays    = now − oldest pending created_at   ← revives ageBoost
          peopleAffected = count of pending in this bucket
          impactClass    = elevated | serious by age band
personas: SCHOOL_LEADERSHIP (principal, admin) + the type's own approver
source:   approval_queue
```

Read path: `approval_requests WHERE status='pending'`, grouped by `type`, gated on
the existing `approvalPermissionForType()` so a caller only ever sees buckets they
can actually decide. That function already exists — no new RBAC surface.

**Deliberately per-TYPE, not per-item.** A principal with 40 pending approvals
needs one actionable line per queue, not 40 cards. The card deep-links to the
Approval Center, which is where batch-decide already lives.

### 2.3 Wave 6a — populating `waitingDays` everywhere

Every generator that reads a table with `created_at` gains it. This is a
one-line-per-generator change and it is what finally makes the fourth factor
move:

| Source | Wait clock |
|---|---|
| `approval_queue` (new) | oldest pending `created_at` |
| `ops:finance:ptp_broken` | `promise_date` → days past |
| `ops:inventory:reorder` | days below reorder point (from movement ledger) |
| `ops:library:overdue` | `days_overdue` (already computed, currently unused) |
| `teacher:attendance` | periods elapsed since the class ended |
| `student_conduct_incidents` | `occurred_on` → days open |

### ✅ `RAW_MAX` — checked, and deliberately NOT changed

An earlier draft of this design called recalibrating `RAW_MAX` the highest-risk
item in Phase 6, reasoning that a live `ageBoost` lets raw scores reach 13.5
while `RAW_MAX` is 9.0, so everything above 9.0 clamps to 100 and flattens the
top of the feed. **That was wrong, and acting on it would have caused a
regression.** Two facts settle it:

1. **Ordering does not use the normalized score.** `buildFeed` sorts on
   `rawScore` (`priority_engine.ts:267`), which stays fully discriminating up to
   13.5. Display saturation cannot affect ranking.
2. **The current calibration is deliberate and its rationale still holds.** The
   comment at `priority_engine.ts:44-53` records that an earlier `AGE_MAX`
   calibration made "critical" (≥75) *unreachable on every real feed*, because a
   maximally-severe item mapped to only 64. Recalibrating to 13.5 now would
   reintroduce exactly that bug: an overdue, critical, brand-new item would
   display 64 and never count as critical.

The intended model — stated in that same comment — is that **severity alone spans
0–100, and age/learning are amplifiers that push into saturation**. A live
`ageBoost` is what that design was always waiting for.

**Real consequence of 6a, stated honestly:** more items will display 100 and the
`counts.critical` (score ≥ 75) population will grow, because age now contributes.
That is the intended behaviour, not flattening — but the critical *count* is
surfaced in the UI, so 6a should re-check that it still reads as meaningful at
pilot scale rather than becoming "everything is critical".

### 2.4 Wave 6b — SLA on the approval spine

```sql
ALTER TABLE approval_requests
  ADD COLUMN IF NOT EXISTS sla_due_at TIMESTAMPTZ;

CREATE TABLE IF NOT EXISTS approval_sla_policies (
  organization_id, school_id, approval_type,
  target_hours INT NOT NULL,
  UNIQUE NULLS NOT DISTINCT (organization_id, school_id, approval_type)
);
```

Follow `complaints.sla_due_at` exactly — it is the only working precedent in the
repo and it already carries the partial breach index worth copying:

```sql
CREATE INDEX ... ON approval_requests (organization_id, school_id, sla_due_at)
  WHERE status = 'pending';
```

`sla_due_at` is **computed at insert** from the policy (as `complaints_sla.ts`
does), never trusted from the client. Existing rows stay `NULL` and the generator
treats NULL as "no clock" — the honest-empty rule, never a fabricated deadline.

**⛔ Owner decision required before 6b:** the default `target_hours` per approval
type (10 types exist). Shipping a guessed SLA would manufacture urgency, which is
the exact failure mode this whole lane has been avoiding.

### 2.5 Wave 6c — `opportunity`

Genuinely product-gated, and worth stating plainly: an "opportunity" item is the
only type in the taxonomy that is not a problem. Candidates the data can support
today — an at-risk student whose trend turned positive, a route with idle
capacity, a lead gone quiet but still warm. Recommend deferring until 6a/6b have
run in the pilot, because an opportunity feed with nothing good to say is worse
than no opportunity feed.

---

## 3. What must not regress

Every invariant Phases 1–4 established still holds, and two are at direct risk:

1. **Purity/determinism.** `waitingDays` must be computed in the *loader* from the
   injected `nowIso`, never inside a generator via `Date.now()`. The generators
   are pure and the tests assert it.
2. **Honest empty.** A missing `created_at` or `sla_due_at` means *no clock* —
   `undefined`, never `0`. `0` reads as "due today" and would fabricate urgency,
   the same class of defect as the fabricated-data P0s in §2.1 of the parent doc.
3. Persona isolation, "AI never executes", zero model calls on the dashboard path.

---

## 4. Sequencing

```
6a  waitingDays + approval generator                            ← no schema, no owner gate
        ↓  (pilot observation: does counts.critical stay meaningful?)
6b  sla_due_at + policy table                                   ← ⛔ owner: SLA values
        ↓
6c  opportunity generator                                       ← product decision
```

**Start at 6a.** It is the only wave that needs neither a migration nor an owner
decision, and it alone converts two dead factors into live ones.
