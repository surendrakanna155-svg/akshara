# Akshara ERP — Pre-Claude Handoff Report

**Date:** 2026-06-18  
**Purpose:** Frozen project snapshot before Claude audit  
**Authority:** Program freeze checkpoint — no F6/F7/Batch 03 work authorized

---

## Git snapshot

| Field | Value |
|-------|-------|
| **Current branch** | `feature/m15-theme` |
| **Current commit (tagged)** | `70194d6` — *Pre-Claude audit freeze checkpoint* |
| **Tag** | `pre-claude-audit-v1` |
| **Latest pushed commit (pre-freeze)** | `47f6d47` — *Phase F5 — Attendance correction API with approval-gated mark apply.* |
| **Backup branch** | `backup/pre-claude-audit` |
| **Uncommitted at freeze** | None — all Patrol Batch 01/02/02b work included in `70194d6` |

---

## Current readiness

| Dimension | Score | Notes |
|-----------|------:|-------|
| **Production API readiness** | **~89%** | F1–F5 certified; F6/F7 not started |
| **Mock / UAT operational readiness** | **~72%+** | Governance complete; Patrol depth expanding |
| **App layer (mock pilot)** | **97/100** | Per `docs/Roadmap.md` — env-dependent live integrations |
| **Patrol QA coverage (weighted)** | **~46%** | 116 certified journeys |
| **Certified Patrol journeys** | **116** | Batch 01 (12) + pilot (9) + manifest (81) + Batch 02 (14) |
| **Flutter test gate** | **1971 passed**, 1 skipped | At F5 certification |
| **`flutter analyze`** | **0 errors** | Style infos pre-existing |

---

## Backend phase status (F1–F7)

| Phase | Name | Status | Certification |
|-------|------|--------|---------------|
| **Governance** | Phase D (M-D1–M-D7) | ✅ **Complete** | [`GOVERNANCE_COMPLETION_REPORT.md`](./GOVERNANCE_COMPLETION_REPORT.md) |
| **F1** | Auth + RBAC | ✅ **Complete** | [`PHASE_F1_FINAL_CERTIFICATION.md`](./PHASE_F1_FINAL_CERTIFICATION.md) · API ~53% |
| **F2** | Approval API | ✅ **Complete** | [`PHASE_F2_FINAL_CERTIFICATION.md`](./PHASE_F2_FINAL_CERTIFICATION.md) · API ~65% |
| **F3** | SIS + Student 360 API | ✅ **Complete** | [`PHASE_F3_FINAL_CERTIFICATION.md`](./PHASE_F3_FINAL_CERTIFICATION.md) · API ~71% |
| **F4** | Exams API | ✅ **Complete** | [`PHASE_F4_FINAL_CERTIFICATION.md`](./PHASE_F4_FINAL_CERTIFICATION.md) · API ~81% |
| **F5** | Attendance API | ✅ **Complete** | [`PHASE_F5_FINAL_CERTIFICATION.md`](./PHASE_F5_FINAL_CERTIFICATION.md) · API ~89% |
| **F6** | Audit / event upload | ⏸ **Not started** | Locked — do not begin |
| **F7** | Remaining production APIs | ⏸ **Not started** | Locked — do not begin |

**Backend stack:** Supabase (PostgreSQL + RLS + Edge Functions) — locked per [`BACKEND_ARCHITECTURE_DECISION.md`](./BACKEND_ARCHITECTURE_DECISION.md).

---

## Patrol status

| Batch | Suite | Status | Result |
|-------|-------|--------|--------|
| Pilot closure | `pilot_closure_workflows_e2e_test.dart` | ✅ Certified | 9/9 |
| Batch 01 | `patrol_batch1_p0_expansion_e2e_test.dart` | ✅ Certified | 12/12 |
| Batch 02 | `patrol_batch2_approval_write_e2e_test.dart` | ✅ Certified | 14/14 |
| **Batch 02b** | `patrol_batch2b_approval_chains_e2e_test.dart` | ⚠️ **Implemented — not certified** | Partial: 1/4 chains green; 1 confirmed fail |
| Persona switch | `qa_persona_switch_test.dart` | ⚠️ **Not certified** | Blocked by 02b completion |
| Batch 03 | — | ⏸ **Not started** | Locked |

**Batch 02b partial run (2026-06-18):**

| # | Journey | Result |
|---|---------|--------|
| 1 | Finance concession → principal approve | ✅ PASS |
| 2 | Parent attendance correction → principal approve | ❌ FAIL — `Attendance correction — Ravi Kumar` not in principal inbox |
| 3 | Inventory PO → principal approve | Not completed |
| 4 | Exam publish → parent sees results | Not run |

---

## Known blockers

| ID | Area | Blocker | Classification |
|----|------|---------|----------------|
| B-01 | Patrol 02b | Parent attendance correction not visible in principal approval inbox | **Needs root-cause analysis** — may be app defect or test data/title mismatch |
| B-02 | Patrol infra | Android emulator flash-close / `adb offline` after `start_emulator.sh` exits | **Infrastructure only** — mitigated by chained boot+Patrol in single session |
| B-03 | Production | `ENABLE_API_MODE=false` default — Class A gaps remain for F6/F7 | **Expected** — F6/F7 not started |
| B-04 | Golden QA | Stale `test/golden/failures/approval_center_*` artifacts | **QA hygiene** — re-run golden to clear |

---

## Known risks

| Risk | Severity | Detail |
|------|----------|--------|
| Uncommitted Patrol work at freeze | Medium | Checkpoint commit captures pending 02b; tag documents state |
| Cross-persona approval chains untested | High | Only finance chain certified end-to-end in 02b |
| Server RBAC enforcement | High | Client RBAC complete; server parity P0 debt |
| Exam data device-local in mock mode | Medium | SharedPreferences persistence — not server-authoritative |
| Emulator instability on CI/macOS | Medium | Blocks Patrol certification velocity |
| Documentation sprawl | Low | 600+ markdown files — see [`PROJECT_CLEANUP_RECOMMENDATIONS.md`](./PROJECT_CLEANUP_RECOMMENDATIONS.md) |

---

## Open defects

| ID | Severity | Area | Status |
|----|----------|------|--------|
| UX-005 | Medium | Maestro `/qa-login` OTP stall | Open (mitigated — QA APK) |
| UX-001 | Low | Golden failure artifacts | Open (QA) |
| UX-002 | Medium | Cross-module export preview stubs | Open (out of pilot scope) |
| UX-B02b-01 | Medium | Emulator Patrol infra | Open |
| **B02b-ATT-01** | **High** | Parent correction → principal inbox | **Open — Patrol failure** |

Detail: [`UI_UX_AUDIT_BACKLOG.md`](./UI_UX_AUDIT_BACKLOG.md)

---

## Active roadmap

| Document | Role |
|----------|------|
| [`ORCHESTRATOR_AGENT.md`](./ORCHESTRATOR_AGENT.md) | Program SSOT — F-phases, gates, stop rules |
| [`PRODUCTION_BACKEND_ROADMAP.md`](./PRODUCTION_BACKEND_ROADMAP.md) | F1–F7 API program |
| [`PATROL_EXPANSION_ROADMAP.md`](./PATROL_EXPANSION_ROADMAP.md) | Patrol batches 01–03+ |
| [`PATROL_QA_ORCHESTRATOR.md`](./PATROL_QA_ORCHESTRATOR.md) | Live QA tracker |
| [`PRE_PRODUCTION_GAP_REPORT.md`](./PRE_PRODUCTION_GAP_REPORT.md) | Class A/B gaps |
| [`Roadmap.md`](./Roadmap.md) | Master product roadmap |
| [`OPERATIONAL_REMEDIATION_ROADMAP.md`](./OPERATIONAL_REMEDIATION_ROADMAP.md) | Client phase sequencing |

---

## Governance + F-phase summary

```
Governance Foundation (Phase D)  →  ✅ Complete (M-D1–M-D7)
F1 Auth + RBAC                 →  ✅ Complete (~53% API)
F2 Approval API                →  ✅ Complete (~65% API)
F3 SIS + Student 360 API       →  ✅ Complete (~71% API)
F4 Exams API                   →  ✅ Complete (~81% API)
F5 Attendance API              →  ✅ Complete (~89% API)
F6 Audit upload                →  ⏸ Not started
F7 Production GO gate          →  ⏸ Not started
Patrol Batch 02b               →  ⚠️ Implemented, cert pending
```

---

## Handoff artifacts

| Document | Purpose |
|----------|---------|
| [`CLAUDE_HANDOFF.md`](./CLAUDE_HANDOFF.md) | Claude audit entry point |
| [`PROJECT_CLEANUP_RECOMMENDATIONS.md`](./PROJECT_CLEANUP_RECOMMENDATIONS.md) | Doc classification (no deletions) |
| `docs/ORCHESTRATOR_AGENT.md` § PRE-CLAUDE FREEZE | Freeze marker in orchestrator |

---

## Explicit stop rules

- **Do not start F6**
- **Do not start F7**
- **Do not start Batch 03**
- **Do not implement new features**
- **Wait for Claude audit**
