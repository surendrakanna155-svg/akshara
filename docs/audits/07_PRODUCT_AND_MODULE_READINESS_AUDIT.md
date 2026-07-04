# Akshara ERP — Product & Module Readiness Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** per-module reality check (real vs thin vs stub) + a pilot ship / hide / fix recommendation per module.
**Confidence:** High where an agent deep-dived a module; Medium where inferred from cross-cutting evidence (flagged).

> **Framing:** the question is not "does the screen exist" — almost all do. The question is "does the
> daily workflow actually complete, end to end, with real persistence, for a real school on day one."
> Modules split into three honest buckets: **SHIP** (real daily loop), **THIN** (core works, important
> pieces missing — ship with expectations set, or fix first), and **HIDE-FOR-PILOT** (scope creep or
> too incomplete to expose).

---

## 1. Module readiness table

| Module | Bucket | Reality | Confidence |
|---|---|---|---|
| **Auth / OTP / RBAC** | ✅ SHIP | OTP-only server-verified; no backdoor; server-side RBAC | High |
| **Parent app (notifications, fees, receipts, fee certificate)** | ✅ SHIP | Notifications complete (real count, 4 states, mark-read/ack/archive); 80C fee-certificate PDF real & own-child-scoped; no dead buttons | High |
| **Finance — fee counter, collection, receipts, defaulters, refunds** | ✅ SHIP (with 2 caveats) | Real collection loop (idempotent, row-locked, receipt PDF, maker-checker refund/concession). Caveats: `finance_collections` row_version guard is inert (money lost-update risk, ENG-1); offline idempotency ~4% (REL-1) | High |
| **Library** | ✅ SHIP | Real circulation loop (catalog, issue/return/renew, due dates, row-locked copies, overdue, fines, bulk import) | High |
| **HR — employee CRUD, leave, payroll process, salary register, payslip** | 🟡 THIN | Employee CRUD real; leave real (server-enforced guards); payslip/register PDF real. But payroll **only flips status** — no salary-structure/CTC model, no run/line-item generation → **unusable on a fresh school** without seeded payroll. Hardcoded `employeeId:'HR-EMP-102'` defect in "New leave". No employee-code uniqueness | High |
| **Hostel** | 🟡 THIN (~40% of spec) | Rooms/allocation/attendance/visitors/mess real. **Leave-apply + gate-pass NOT built** (approve/reject only); **hostel billing entirely unbuilt** (`feePending` hardcoded ₹0). For a boarding school these are daily-critical | High |
| **Alumni** | 🔴 HIDE | Directory persists but **manual-entry only** — graduation sets `students.status='alumni'` but creates no alumni record → directory never auto-populates. Donations→Finance = free-text passthrough | High |
| **Transport** | 🟡 THIN (Medium conf.) | Backend TRN-1..9 shipped (fleet CRUD, stops, bulk allocate, capacity, doc-expiry, fee demand→Finance). Live GPS tracking is Phase-2 (correctly deferred). Verify fleet CRUD + roster export end-to-end on live | Medium |
| **Inventory** | 🟡 THIN (Medium conf.) | INV-1..7 shipped (stock issue/adjust/count, maker-checker write-offs, consumables, raise-PO, register export) with a concurrency fix. Value-reducing moves are maker-checker (good). Verify stock-out loop live | Medium |
| **Admissions / SIS** | 🟡 THIN→SHIP (Medium conf.) | Lead CRM, applications, document upload+approve, enrollment wizard (auto admission #), fee handoff, approval maker-checker SoD all shipped. PSID surfacing + admission-# read-only shipped. Certificates (SIS-1 bonafide/study/conduct) + TC engine shipped recently — verify live | Medium |
| **Exams / Marks / Report cards** | ✅ SHIP (with reliability caveat) | Real marks entry + verification + publish (now audited), frozen absent/ML/DB exclusion rule tested with real numbers, report-card PDF. Caveat: marks "Save all" bypasses the reliability platform (REL-2) | High |
| **Attendance (student)** | ✅ SHIP | Teacher period-wise marking with draft autosave + crash-resume + submit gate + absentee→parent alert | High (draft is one of the 2 real-draft screens) |
| **Communication / Notices / Broadcasts** | 🟡 THIN (Medium conf.) | In-app broadcast persist + recipients + queued deliveries real; **external SMS/WhatsApp/push delivery is owner-gated OFF** (in-app only ships now). Set marketing expectations accordingly | Medium |
| **Principal / Director / Management dashboards** | 🟡 THIN (Medium conf.) | PRI-1 batch approve/reject + DIR-1/2 league/collection + audited drill-down shipped. Overlap risk: 3 principal-dashboard surfaces + multiple AI entry points (see Consolidation, master report) | Medium |
| **AI surfaces** | ✅ real / advisory | See AI audit — real Claude, determinism-first, but no cache/rate-limit/timeout | High |
| **Workflow / Academic-Ops / Continuity / Platform-Intel/Ops / Verticals / White-label** | 🔴 HIDE | UI exists, **backend flag OFF live → mock or 404**. Owner-deferred (Phase 2 / Future) | High |

---

## 2. Cross-cutting product findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| MOD-1 | **P1** | Cross-module financial integration is cosmetic for Library/Hostel/Alumni — fines/fees never post to the student Finance account | `library_aggregations.ts:256,314`; `hostel_write_handlers.ts:71`; `alumni_write_handlers.ts:196` | Either wire real Finance posting (invoice/fee-head) or clearly label these as informational and out-of-Finance for pilot. A library fine that never reaches the fee ledger will confuse the office. |
| MOD-2 | **P1** | HR payroll cannot run on a fresh school (no salary-structure model, no run generation) | `hr_write_handlers.ts:830-867`; seeded `snapshot_payroll` only | Build salary-structure + payroll-run generation before offering HR payroll, or hide payroll for pilot. |
| MOD-3 | **P1** | Hardcoded `employeeId:'HR-EMP-102'` in the "New leave" dialog attributes every leave to one phantom employee | `hr_workflow_actions.dart:119` | Fix to use the selected employee (the "Apply on behalf" dialog is already correct). Route to QA tracker. |
| MOD-4 | **P1** | ~8 backend-less UI surfaces are reachable and serve mock data in production | Engineering ENG-3 | Route-guard OFF for pilot (hide, don't mock). |
| MOD-5 | **P2** | Alumni is scope-creep for pilot day-1 (manual, disconnected from graduation + Finance) | module-wide | Hide for pilot per North-Star O3. |
| MOD-6 | **P2** | Hostel is missing the two daily-critical boarding workflows (leave/gate-pass, billing) | `hostel_write_handlers.ts` | Ship "residence-lite" (rooms/allocation/attendance/mess) with leave+billing hidden, or hide Hostel for a day-scholar pilot. |

---

## 3. Pilot ship/hide recommendation (summary)

- **Ship confidently:** Auth, Parent app, Attendance, Exams/Marks/Report-cards, Finance fee counter, Library, Admissions/SIS core (after live verify).
- **Ship with expectations set (or fix first):** HR (hide payroll), Transport (no live GPS), Inventory, Communication (in-app only), Principal/Director dashboards.
- **Hide for pilot:** Alumni, Hostel billing + leave/gate-pass (ship residence-lite or hide), Workflow/Academic-Ops/Continuity/Platform-Intel/Ops/Verticals/White-label.

## 4. Genuine strengths

- The **core academic + fee daily loop is real and well-built** — this is exactly the right thing to have working first for a school ERP.
- **Maker-checker / separation-of-duties** is real across Finance (refund, concession) and Inventory (write-off).
- **Honest empty states and no dead buttons** in the surfaces that were deep-audited (Parent notifications/fees, HR exports) — a good sign for product discipline.
- **Draft autosave + crash-resume** is genuinely delivered on attendance (the highest-frequency teacher task).

## 5. Unknowns / needs live verification

- Transport fleet CRUD, Inventory stock-out, Admissions/SIS certificate + TC engine, and the recently-shipped module client waves were verified as *code shipped*, not as *live end-to-end* (Medium confidence). These need a live-cert pass (they were built after the last pilot simulation).
- Teacher and Student mobile-app UX depth beyond attendance/marks (agent session-limited) — inferred SHIP from architecture, not per-screen verified.
