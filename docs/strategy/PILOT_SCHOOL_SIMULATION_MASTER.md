# Akshara ERP — Pilot School Simulation Master Blueprint

**Status:** Strategy / design-only (no code) · **Author:** Fable · **Date:** 2026-07-03
**Grounded in:** the Fable Final Audit (`docs/audits/`) and live VPS verification (`11_LIVE_VPS_VERIFICATION_ADDENDUM.md`).
**Maps to:** Master Roadmap **Phase 6** (`P6-PILOT-1`). **Gate:** passing this simulation = **PILOT-READY**.

> **Purpose.** Prove Akshara can run a *real school's real year* end-to-end, **unattended**, on the live
> stack, with real auth/DB/RBAC/gateway — not a demo, not on mocks. The audit's central caution was
> "local proof ≠ live proof"; this simulation is the answer. It exercises **every role and every major
> workflow across a full academic year**, collects **hard evidence**, and fails loudly on any P0.

---

## 1. Simulation design

- **Two runs.** (A) **Single-school** representative pass (all ~22 stage types). (B) **Multi-school concurrent** (N=3: a small State-board, a CBSE, an ICSE) to prove isolation + no interference — the audit live-verified RLS isolation (report 11 §3b); this exercises it under concurrent load.
- **Live, unattended.** Real VPS, real Postgres (RLS as `erp_tenant`), real edge, real gateway. **No manual intervention** between stages; any stage that needs a human = a finding.
- **Representative scale.** ~600–1,200 students/school, 40–80 staff, 20–40 sections, a full fee cadence, real term calendar. Enough to surface N+1 and pagination issues (audit ENG-6).
- **Evidence-first.** Every stage emits a machine-readable result (JSON: pass/fail, counts, timings, IDs) committed as a run artifact (closes audit QA-5).
- **Prerequisite gate:** Master Roadmap **Phase 0** complete (off-site backup + WAL + alerts + release hardening + money row_version + CI green) and **Phase 5** (Red-Team fixes) done. Do not run the pilot cert on an unsafe base.

---

## 2. Personas exercised (every role)

Parent · Student · Teacher · Class-Teacher · Principal · Vice-Principal/Coordinator · School Admin · Front-Office/Admissions clerk · Accountant/Fee-counter · HR · Storekeeper · Librarian · Transport in-charge · Hostel warden (if enabled) · Director (multi-school) · Super-Admin/Platform. Each acts **under its own RBAC persona** (the audit stressed "not a god-login").

---

## 3. Day-by-day / stage-by-stage operations (a school year in fast-forward)

Each stage lists **actor → workflow → evidence to collect → failure condition.**

### Stage 0 — Onboarding & configuration (Day −7 → Day 0)
- **Super-Admin/Founder:** create school → School Code set-once-locked (audit identity: PSID depends on it) → choose board, modules, term calendar, working hours, fee cadence, branding.
- **Evidence:** school row + `school_configuration.capabilities` written; disabled modules hidden everywhere; Public Student ID scheme active; branding applied.
- **Fail:** module choice doesn't reach the runtime gate; disabled module still reachable; school code editable after lock.

### Stage 1 — Academic-year setup (Day 0)
- **School Admin:** academic year, classes, sections, subjects, timetable, class-teacher assignment.
- **Evidence:** year/classes/sections persisted; timetable renders; per-teacher workload rollup correct.
- **Fail:** section-balance or timetable commit not durable.

### Stage 2 — Admissions & enrollment (Week 1)
- **Front-Office:** leads → applications → document upload → **principal approval (maker-checker SoD)** → enrollment wizard → **admission number + Public Student ID issued** → fee handoff to Finance.
- **Evidence:** enrollment idempotent (no dup on retry — audit money fix); PSID unique per school, never reused; fee account created.
- **Fail:** duplicate enrollment on retry; PSID collision; approval self-approvable.

### Stage 3 — Student identity & records (Week 1–2)
- **Office:** Student 360, guardian linking, documents, certificates (bonafide/study/conduct), ID cards showing PSID.
- **Evidence:** PSID + admission# both shown; admission# read-only (set-once trigger); certificate PDFs generate.
- **Fail:** editable identity; UUID shown as human id.

### Stage 4 — Daily attendance (ongoing, every school day)
- **Teacher:** period-wise marking with **draft autosave + crash-resume**; all-present/absent; absentee→parent alert (gated).
- **Office:** attendance register + not-yet-marked compliance monitor.
- **Evidence:** draft survives app-kill mid-entry (audit REL-3 target); absentee alerts queued; register exports.
- **Fail:** marks lost on interruption; alert not fired; cross-school student visible.

### Stage 5 — Homework (ongoing)
- **Teacher:** create + publish → **Student:** submit + persist → not-submitted list.
- **Evidence:** submission persists; non-submitters computed from roster diff.
- **Fail:** submission lost; roster diff wrong.

### Stage 6 — Exams, marks & report cards (mid-term + term-end)
- **Teacher:** **fast bulk marks entry** (grid, save-all) — must route through reliable writer (audit REL-2); verification → **Principal** publish (audited).
- **System:** absent/ML/debarred → NULL + AB/ML/DB, **excluded from totals/avg/rank** (frozen decision, audit-verified rule); report-card PDF.
- **Evidence:** whole-class save durable; exclusion rule correct on real data; publish audited; report cards render with PSID.
- **Fail:** partial marks lost; absent student counted in average/rank; publish unaudited.

### Stage 7 — Fees, collections & receipts (ongoing + due cycles)
- **Accountant:** raise invoices (installment schedule) → **collect (idempotent, row-locked)** → auto receipt + PDF → SMS (gated) → day-close.
- **Recovery:** defaulter list + aging → call queue → promise-to-pay → contact history → collector performance.
- **Money-integrity checks:** concurrent double-collect prevented (audit ENG-1 — the row_version fix must be live); refund maker-checker; concession maker-checker; offline collect shows "pending sync," receipt only on confirm (audit R1).
- **Evidence:** no duplicate financial transaction under retry/concurrency; receipt numbers unique; ledger balances; day-close locks.
- **Fail:** duplicate receipt; lost-update on concurrent collect; refund self-approvable; offline collect mints receipt before sync.

### Stage 8 — Communication (ongoing)
- **Principal/Teacher:** broadcasts + notices (audience picker, delivery/read report); **parent-facing comms in the parent's language** (deterministic catalog).
- **Evidence:** per-recipient localization; delivery/read report; in-app delivery (external channels owner-gated).
- **Fail:** wrong-language parent copy; broadcast not delivered/recorded.

### Stage 9 — Transport (ongoing, if enabled)
- **Transport in-charge:** fleet + driver registration, stop-wise roster, capacity, doc-expiry, **transport fee demand → Finance** (Transport defines, Finance collects).
- **Evidence:** roster exports; over-capacity warned; transport demand appears in Finance (no duplicate payment engine).
- **Fail:** duplicate payment logic; capacity not enforced.

### Stage 10 — Library / Inventory (ongoing, if enabled)
- **Librarian:** issue/return/renew, due dates, overdue, fines. **Storekeeper:** stock issue/adjust/count, **maker-checker write-offs**, reorder, raise-PO.
- **Evidence:** circulation loop durable; negative-stock blocked; write-off requires checker; immutable stock ledger.
- **Fail:** stock goes negative; write-off single-approver; ledger mutable.

### Stage 11 — HR & payroll (monthly)
- **HR:** employee directory, leave (apply/approve, balance, batch), staff attendance muster; payroll run (salary register + payslips) — **note audit MOD-2: payroll engine must exist for a fresh school.**
- **Evidence:** leave immutability + balance enforced; payslips generate; muster exports.
- **Fail:** leave double-decided; payroll can't run without seeded data; hardcoded employeeId (audit MOD-3).

### Stage 12 — Staff attendance (daily, if in scope)
- **Staff:** geofence + anti-mock GPS + live-camera-face check-in/out (frozen auth decision); manual request + manual-close (maker-checker); **Principal** real-time summary.
- **Evidence:** ledger append-only; self-insert RLS; no device-biometric/PIN path.
- **Fail:** device-biometric accepted; cross-staff insert.

### Stage 13 — Leadership (weekly/monthly)
- **Principal:** approvals inbox (batch), daily pulse, exceptions. **Director:** cross-school league, collection, board pack (org-scope RLS).
- **Evidence:** batch approve audited per item; director sees only own org (audit-verified isolation); board pack PDF.
- **Fail:** cross-org leakage; unaudited approval.

### Stage 14 — Parent & Student apps (ongoing)
- **Parent:** child switch, attendance/marks/fees/homework/notices, **pay fee end-to-end (real gateway)**, fee certificate (80C), leave apply, PTM RSVP.
- **Student:** profile (PSID), homework submit, results.
- **Evidence:** own-child isolation; real payment → receipt; certificate PDF.
- **Fail:** sees another child; payment not reconciled; wrong-language comms.

### Stage 15 — Year-end closing (Year end)
- **School Admin:** exam finalization → report cards → **promotion/reshuffle/balance commit** → transfer certificates (TC) → **no-dues/clearance** across modules → alumni/exit.
- **Evidence:** promotion commit durable + audited; TC generated; clearance aggregates dues across Finance/Library/Transport/Hostel/Inventory; year rolls over.
- **Fail:** promotion not durable; TC issued with unpaid dues (if no-dues gating chosen); data lost on rollover.

### Stage 16 — Operational resilience (interleaved throughout)
- **Offline/interruption:** kill app mid-attendance/marks/fee; airplane mode; reconnect + auto-sync.
- **DR:** trigger the **live backup → restore-drill → integrity** (audit LV-8 shows this passes) + confirm off-site (after Phase 0 P0-INFRA-1).
- **Monitoring:** trip a watchdog check; confirm the alert **reaches a human** (after P0-INFRA-3).
- **Evidence:** no data lost; outbox drains on reconnect (audit REL-4 target); restore integrity == source; alert delivered.
- **Fail:** queued write lost; restore mismatch; alert not delivered.

---

## 4. Success criteria (the PILOT-READY gate)

All must hold, with committed evidence:

- [ ] All ~22 stage types complete **unattended** (no manual intervention) on the live stack, single-school **and** 3-school-concurrent.
- [ ] **Zero P0** (data loss, security/RBAC breach, tenant-isolation leak, duplicate financial transaction, broken auth/sync, critical crash).
- [ ] **Money integrity:** no duplicate receipts, no lost-updates under concurrency, maker-checker enforced, day-close locks.
- [ ] **Tenant isolation:** zero cross-school/cross-org read or write bleed under concurrent operation (extends audit LV-11).
- [ ] **Reliability:** draft-resume works on the 4 pilot-critical writes; outbox drains on reconnect; offline receipt-gating holds.
- [ ] **DR:** live backup + restore-drill green; off-site confirmed; restore integrity == source.
- [ ] **Monitoring:** every health/alert/job triggered + observed reaching a human.
- [ ] **Comms:** parent-facing copy in the correct per-recipient language; delivery/read recorded.
- [ ] **No mock/backend-less surface reachable** (audit ENG-3 / P0-CODE-2 confirmed).
- [ ] **Performance:** p95 within `PERFORMANCE_TARGETS.md` at representative scale (large rosters, marks sessions, dashboards, reports).
- [ ] **Evidence committed:** machine-readable run artifacts per stage (closes QA-5).

## 5. Expected outcomes

- A reproducible, evidence-backed demonstration that a real school's full year runs on Akshara without hand-holding.
- A punch-list of any friction/latency items → feed the UX wave (Phase 2) and Prod-Cert (Phase 7).
- A truthful "what works live" baseline that supersedes the local/contract/mock proofs the audit flagged.

## 6. Failure conditions (any → simulation FAILS, fix before re-run)

- Any P0 (§4). · Any stage needing manual intervention to proceed. · Any cross-tenant leak under concurrency. · Any duplicate financial transaction. · Any lost data on interruption/restart. · Restore integrity mismatch. · An alert that never reaches a human. · A reachable surface serving mock data. · A parent receiving another child's data or the wrong language.

## 7. Governance

Every stage is EOS-gated; the whole simulation is `QA-R-001/002` (live). Reuse the staged harnesses the audit identified (`scripts/qa/live_cert_pilot_full_year.py`, `live_cert_multi_school_concurrent.py`, the isolation probes, the k6 probe, the backup/restore drill) — **run them for real, commit the artifacts.** Passing this blueprint's §4 gate is the entry condition for [`PRODUCTION_CERTIFICATION_FRAMEWORK.md`](PRODUCTION_CERTIFICATION_FRAMEWORK.md) (Phase 7).
