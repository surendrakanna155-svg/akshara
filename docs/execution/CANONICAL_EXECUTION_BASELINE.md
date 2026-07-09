# Akshara ERP — Canonical Execution Baseline

> **Status as of 2026-07-09.** This is the **new canonical execution baseline for all future sessions** (owner-directed). It supersedes ad-hoc "complete" claims. Read this first, alongside `docs/execution/AGENT_REGISTRY.md` and the memory pointers.
>
> **Reporting law:** acquisition is described as **"Acquisition engine complete. Curriculum repository still incomplete"** until the coverage matrix converges. Nothing is "GA-certified" until the production blockers below are cleared on the live lane.

---

## 0. Completion summary (at-a-glance)

*Estimates — honest, qualified; the autonomous acquisition lane's matrix report is authoritative for Curriculum Repository.*

| Track | Progress | % |
|---|---|---:|
| **ERP** (functionally feature-complete for Pilot) | `██████████████████░░` | **92%** |
| **Curriculum Engine** (deterministic done; AI-engine waves P3-gated) | `██████████████████░░` | **90%** |
| **Curriculum Repository** (736-cell matrix; CBSE-heavy, AP/TS thin, CISCE 0) | `████░░░░░░░░░░░░░░░░` | **~20%** |
| **Assessment** (schema seeded; platform post-pilot / P3-gated) | `██░░░░░░░░░░░░░░░░░░` | **~10%** |
| **Infrastructure** (RLS✅ backup✅; off-site/COM-4 staged, deploy + 7-day cron pending) | `██████████████░░░░░░` | **70%** |
| **Production Readiness** (RLS+backup cleared; matrix/Face-ID/deploy/cert/pilot remain) | `████████░░░░░░░░░░░░` | **40%** |

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
- **Live RLS cross-tenant isolation VERIFIED** on the VPS: all 12 QA-B rows PASS + 233/233 enforced probes, **zero leaks** (non-destructive).
- **Nightly backup verified GREEN** (restorable).

**Cumulative regression GREEN:** deno `_shared` 2308/0 · `flutter analyze` 0 · goldens 70/70 · full flutter suite 3761/0 (as of step-3).

**Remaining ERP (owner-gated / follow-ups):** P1-CODE-4 (Identity platform), P1-CODE-6/7/8 (Finance-posting MOD-1 / Hostel / Alumni scope); fee-reduction follow-ups (Approval-Center type wiring + full client propose-award UX); exam-override client polish (narrow, `EXAM_APPROVAL_REQUIRED=false` builds); COM-4 per-school scheduled-broadcast RLS (P2).

---

## 2. Curriculum — **engine complete; repository INCOMPLETE**

- **Acquisition ENGINE complete (proven):** crawler ran clean, integrity proven; the deterministic Board→Class→Subject→DocType pipeline (`scripts/acquisition/run_acquisition.py`) is the canonical acquirer (broad crawler retired). See `docs/curriculum-intelligence/ACQUISITION_STATUS.md`.
- **Repository INCOMPLETE:** success = the **736-cell coverage matrix** (CBSE 176 + AP 160 + TS 160 + CISCE 240) filled with **verified** cells. Today CBSE-heavy, AP/TS thin, **CISCE 0**. The matrix lane runs autonomously to convergence — **do not interrupt/replace/spawn-another**.
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

1. **Curriculum repository convergence** — the 736-cell `Board→Class→Subject→DocType` matrix filled with verified cells (autonomous lane, in progress).
2. **Remaining live deployment** — deploy this session's new backend to `akshara-edge` (fee-reductions migration + COM-4 cron-token path); **activate COM-4 cron** (set `INTERNAL_CRON_TOKEN` + install cron); **activate off-site backup** (supply R2 credentials, 3-2-1); sustain the **7-day cron green** (scheduled-broadcast/reminder + monitoring). All runbooks staged.
3. **Live certification** — apply + cert `finance_fee_reductions` on the live tenant DB (RLS/CHECK/partial-unique/FOR-UPDATE + concurrent approve/reverse/clamp; currently pattern-matched, not live-run) + any deploy-time re-cert of the new endpoints.
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
Acquisition engine proven + repository-incomplete terminology locked · gap-sweep waves 1+2 · live RLS all-pass · backup GREEN · off-site R2 + COM-4 token staged · discounts→billing maker-checker + full financial regression. All reviewer-gated, committed, tree clean (except the autonomous acquisition lane's own `curriculum/` working state, owned by that lane).
