# Akshara ERP — Canonical Execution Baseline

> **Status as of 2026-07-09.** This is the **new canonical execution baseline for all future sessions** (owner-directed). It supersedes ad-hoc "complete" claims. Read this first, alongside `docs/execution/AGENT_REGISTRY.md` and the memory pointers.
>
> **Reporting law:** acquisition is described as **"Acquisition engine complete. Curriculum repository still incomplete"** until the coverage matrix converges. Nothing is "GA-certified" until the production blockers below are cleared on the live lane.

---

## 0. Completion summary (at-a-glance)

*Only **Curriculum Repository** has an authoritative quantitative metric — the **Coverage Matrix** (verified cells ÷ 736 expected), owned by the acquisition lane (`curriculum/reports/COVERAGE_MATRIX.md`). Every other track uses a **qualitative status label** (High / Medium / Early / Pending) derived from measurable roadmap-wave completion — deliberately NOT a subjective percentage, so this baseline does not go stale. Replace a label with a derived % only when a track exposes a real completion metric.*

| Track | Status | Basis (measurable) |
|---|---|---|
| **ERP** | **High** — functionally feature-complete for Pilot | Phase-C C0–C21 + P1-non-gated + P2 (5 waves) + gap-sweep 1–2 + **final gap-sweep (3 P0 / 7 P1 built) + P2 cleanup** all closed & regression-green (`docs/GAP_SWEEP_CERTIFICATION.md`); remaining = owner-gated P1-CODE + deploy/cert |
| **Curriculum Engine** | **High** — deterministic engine complete | CI-C1/C3/C7/C8/C4-schema + B12/E1b done; AI-engine waves (C5/C6/C10/C11) P3-gated (future) |
| **Curriculum Repository** | **Coverage Matrix — live SSOT (~14.1% at 2026-07-09), advancing** | `curriculum/reports/COVERAGE_MATRIX.md` is the authoritative, always-current metric (verified cells ÷ 736), owned by the separate acquisition lane — read it for the live figure/by-board split. Not an ERP-pilot dependency (see §5 note). **Hands-off** — do not interrupt/replace/spawn-another. |
| **Assessment** | **Early** — schema dormant-seeded only | B12/E1b tables exist; platform (Question Factory / Diagram / adaptive) post-pilot + P3-gated |
| **Infrastructure** | **Medium** — live RLS ✅ + backup ✅; activation/deploy pending | off-site R2 + COM-4 cron staged (not activated); new backend not deployed; 7-day cron pending |
| **Production Readiness** | **Early** — 2 of 6 blockers cleared (RLS, backup) | matrix convergence + deploy + live-cert + Face-ID + pilot remain (see §5) |

---

## 1. ERP — **functionally feature-complete for Pilot** (live deployment + certification + pilot still pending)

**Built + tested (local + now partially live-verified):**
- **Phase-C module program C0–C21 COMPLETE** — Finance, Attendance, Exams, HR, SIS, Transport, Inventory, Library, Communication, Admissions, Parent, Teacher, Principal, Director (build + discovery-first close + tests).
- **P1 non-gated code lane COMPLETE**; **P2 UI/UX COMPLETE** (5 sub-waves: feel/trust, five-daily-tasks, design-system enforcement, accessibility, dark theme).
- **Gap-sweep waves 1 + 2 COMPLETE** (2026-07-09):
  - Security: 3 SoD holes (PO self-approval, approval requester-spoof, admissions status-flip), exam-publish override permission, TRN9 idempotency, 4 ISO-COUNT tripwires.
  - Money-math: aging, `waiveLateFee` lockstep, and **discounts/scholarships → billing** via finance-owned two-person maker-checker (`finance_fee_reductions`, lockstep + clamp + idempotent + head-ledger-consistent) — **full financial-flow regression PASSED**.
  - Correctness: attendance-% unified to ONE canonical formula.
  - Wiring/completion: SIS-conversion GET, timetable reassign-teacher, finance archive/cancel UI, Inventory Replacement backend.
  - **3 false positives eliminated by verify-first** (Management placeholder, mgmt-resolve dead code, SIS academic-assignment deprecated route).
- **Final gap-sweep CLOSED (2026-07-09)** — a fresh discovery pass found **3 P0 + 7 P1**, all **built** (no stubs) + tested + integrated (student-404 fallback, 5 timetable-workforce endpoints, inventory-replacement RLS consistency, admissions fee-structures GET, alumni report keys, operations-hub dismiss/complete, parent message/ack routes, honest WhatsApp/onboarding status). Verify-first discarded **4** false positives; re-cert caught + fixed **1** DS-enforcement regression the wave had introduced. See `docs/GAP_SWEEP_CERTIFICATION.md`.
- **P2 cleanup CLOSED (2026-07-09)** — `student_profiles`/`student_guardians` student-scope RLS read policy (`20260866`), education-only vertical-pack picker gate (UI + backend), report-card real school-name (parent+student), orphaned `DynamicDashboardScreen` removed. Verify-first kept 6 "dead code" candidates that were actually reachable/no-UI.
- **Live RLS cross-tenant isolation VERIFIED** on the VPS: all 12 QA-B rows PASS + 233/233 enforced probes, **zero leaks** (non-destructive).
- **Nightly backup verified GREEN** (restorable).

**Cumulative regression GREEN:** deno `_shared` **2409/0** · `flutter analyze` **0** · goldens 70/70 · full flutter suite **3766/0** (1 skipped) — as of the final gap-sweep + P2 close, 2026-07-09.

**Remaining ERP (owner-gated / follow-ups):** P1-CODE-4 (Identity platform), P1-CODE-6/7/8 (Finance-posting MOD-1 / Hostel / Alumni scope); fee-reduction follow-ups (Approval-Center type wiring + full client propose-award UX); exam-override client polish (narrow, `EXAM_APPROVAL_REQUIRED=false` builds); COM-4 per-school scheduled-broadcast RLS (P2).

---

## 2. Curriculum — **engine complete; repository INCOMPLETE**

- **Acquisition ENGINE complete (proven):** crawler ran clean, integrity proven; the deterministic Board→Class→Subject→DocType pipeline (`scripts/acquisition/run_acquisition.py`) is the canonical acquirer (broad crawler retired). See `docs/curriculum-intelligence/ACQUISITION_STATUS.md`.
- **Repository INCOMPLETE — authoritative Coverage Matrix is the live SSOT** (`curriculum/reports/COVERAGE_MATRIX.md`), ~14.1% at 2026-07-09 and **actively advancing** (the separate acquisition lane is running; the earlier "converged at 10.1%" snapshot is superseded). Read the matrix for the current figure + by-board split — do not hardcode a number here (it goes stale). Raising coverage is the **lane's own domain** (source-ladder expansion → fresh passes); **do not interrupt/replace/spawn-another.**
- **Deterministic ENGINE layer complete (pre-pilot):** CI-C1 (template solver) · CI-C3 (multi-set export) · CI-C7 (exam profiles) · CI-C8 (item rotation) · CI-C4-schema · B12 Question-Factory + CI-E1b concept-graph dormant seeds. Additive/dormant, invariants I1–I8 intact.
- **AI-dependent curriculum waves GATED** (CI-C5/C6/C9/C10/C11) — depend on P3 Adaptive AI + canonical concepts (content).

---

## 3. Assessment (Assessment Intelligence Platform) — **schema seeded; platform POST-PILOT / P3-gated**

- **Schema dormant-seeded:** B12 (`edu_question_families`/`edu_question_templates`/`edu_distractors`) + CI-E1b (`canonical_concepts`/`concept_prerequisites`/`concept_board_mappings`) — dead schema until wired.
- **Platform build (Master Plan v3.0) NOT started** — Question Factory (CI-C10), Diagram Intelligence (CI-C11), evidence-trust pipeline, ERP-integrated adaptive AI. Runs **post-pilot**, gated on P3 + content (concepts/PYQ).
- **Amendment A2 (per-student deterministic practice/DPP)** — planning-only, pending owner ratification; extends CI-C10/C1/C3/C8.

---

## 4. Remaining owner-gated work
- **P3 Adaptive AI** (the entire AI wave; unblocks curriculum CI-C5/C6/C10 too) — owner-timing-gated ("do not build yet").
- **P1-CODE-4** (Identity platform F1/F2) · **P1-CODE-6/7/8** (module scope decisions).
- **Assessment Intelligence Platform** build timing + **Amendment A2** ratification.
- **Fee-reduction integration follow-ups** (Approval-Center type + full client flow).
- **Curriculum Amendment A2**, **Student Clearance / No-Dues engine** (verdict: next roadmap post module-completion).

---

## 5. Remaining PRODUCTION BLOCKERS — in execution priority (Must-Before-GA)

*(Live RLS isolation + nightly backup already **cleared** this session.)*

1. **Curriculum repository convergence** — the 736-cell `Board→Class→Subject→DocType` matrix filled with verified cells (live SSOT `COVERAGE_MATRIX.md`, ~14.1% and advancing). Lane's own domain (source-ladder expansion → fresh passes). **NOTE:** this is a **GA / Assessment-platform** dependency, **not** an ERP-pilot blocker — the ERP pilot runs without it.
2. **Live deployment — ✅ DONE (2026-07-09).** The full 44-migration backlog (`20260819–20260866`, incl. fee-reductions/inv-replacement/operations-hub/student-read RLS) was applied to prod `akshara_db` (now `20260866`) after a verified predeploy backup, and the edge redeployed to HEAD `2568ff9b` (all `/health` green, edge logs clean, smoke: new routes serve). Still owner-gated: **COM-4 cron** (`INTERNAL_CRON_TOKEN`), **off-site R2** (creds), **7-day cron green**.
3. **Live certification — ✅ DONE (2026-07-09).** `finance_fee_reductions` guardrails certified live: DB-level (RLS/CHECK/partial-unique) on `akshara_tenant_test` (rolled back) + app-level E2E through the deployed prod edge (auth+read+propose+**SoD 403**+reject, net-zero). Money-moving approval E2E (lockstep/clamp/reversal) deferred (no 2nd seed finance user; DB+unit-covered). See `docs/FINANCE_FEE_REDUCTIONS_LIVE_CERTIFICATION.md`.
4. **Staff Face ID attendance certification** (GPS geofence + anti-mock + live camera face; separate Must-Before-GA track).
5. **Pilot run** (representative-pass) on the live lane.
6. **General Availability** — the final gate; declared only once blockers 1–5 are cleared and green.

---

## 6. Post-GA roadmap
- **Assessment Intelligence Platform** (full: Question Factory, Diagram Intelligence, adaptive) + **Amendment A2** per-student practice.
- **Adaptive AI** (per-school config/roles/lang/branding; proactive role dashboards; ≥90% zero-call).
- **Student Clearance / No-Dues** cross-module engine.
- **Identity platform** F1/F2 (Public Student ID rollout).
- **Phase-D commercial** (billing/GPS/white-label = Phase 2; geo/RFID/QR + student Face ID = Future Vision).
- WAL/PITR (post-pilot; ~24h nightly RPO accepted for pilot).

---

### Session provenance (2026-07-09)
Acquisition engine proven + repository-incomplete terminology locked · gap-sweep waves 1+2 · live RLS all-pass · backup GREEN · off-site R2 + COM-4 token staged · discounts→billing maker-checker + full financial regression. **2026-07-09 addendum:** final gap-sweep (3 P0 / 7 P1 built) + P2 cleanup CLOSED, one DS-enforcement regression caught + fixed at re-cert, regression green (deno 2409/0 · analyze 0 · flutter 3766/0); deploy + live-cert staged and blocked on the SSH socket. All reviewer-gated, committed, tree clean (except the autonomous acquisition lane's own `curriculum/` working state, owned by that lane).
