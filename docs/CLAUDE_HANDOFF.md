# Claude Audit Handoff

**Date:** 2026-06-18  
**Tag:** `pre-claude-audit-v1` @ `70194d6`  
**Branch:** `feature/m15-theme`  
**Backup:** `backup/pre-claude-audit`

---

## Entry point

Read in order:

1. **This file** — current state summary
2. [`PRE_CLAUDE_HANDOFF_REPORT.md`](./PRE_CLAUDE_HANDOFF_REPORT.md) — full snapshot
3. [`ORCHESTRATOR_AGENT.md`](./ORCHESTRATOR_AGENT.md) — program authority + PRE-CLAUDE FREEZE section
4. [`BACKEND_ARCHITECTURE_DECISION.md`](./BACKEND_ARCHITECTURE_DECISION.md) — locked stack
5. [`PATROL_QA_ORCHESTRATOR.md`](./PATROL_QA_ORCHESTRATOR.md) — QA program status

---

## Current state

### Governance Foundation

→ **Complete** (Phase D, M-D1–M-D7)  
Certification: [`GOVERNANCE_COMPLETION_REPORT.md`](./GOVERNANCE_COMPLETION_REPORT.md)

### F1 Auth + RBAC

→ **Complete**  
Certification: [`PHASE_F1_FINAL_CERTIFICATION.md`](./PHASE_F1_FINAL_CERTIFICATION.md)  
Production API readiness contribution: **~53%**

### F2 Approval API

→ **Complete**  
Certification: [`PHASE_F2_FINAL_CERTIFICATION.md`](./PHASE_F2_FINAL_CERTIFICATION.md)  
Production API readiness contribution: **~65%**

### F3 SIS + Student 360 API

→ **Complete**  
Certification: [`PHASE_F3_FINAL_CERTIFICATION.md`](./PHASE_F3_FINAL_CERTIFICATION.md)  
Production API readiness contribution: **~71%**

### F4 Exams API

→ **Complete**  
Certification: [`PHASE_F4_FINAL_CERTIFICATION.md`](./PHASE_F4_FINAL_CERTIFICATION.md)  
Production API readiness contribution: **~81%**

### F5 Attendance API

→ **Complete** (Patrol certification pending infrastructure validation)  
Certification: [`PHASE_F5_FINAL_CERTIFICATION.md`](./PHASE_F5_FINAL_CERTIFICATION.md)  
Production API readiness contribution: **~89%**

---

## Readiness summary

| Track | Score |
|-------|------:|
| **Production API readiness** | **~89%** |
| **Mock / UAT readiness** | **~72%+** |
| **Patrol certified journeys** | **116** |
| **Patrol QA coverage (weighted)** | **~46%** |

---

## Known unresolved issue — Batch 02b

**Workflow:** Parent Attendance Correction → Principal Inbox

**Patrol failure:**

```
TimeoutException: Finder with text "Attendance correction — Ravi Kumar" did not find any visible widgets
```

**Suite:** `patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart` (test 2)

**Status:** **Needs root-cause analysis.**

Possible causes to investigate:

1. Parent correction submit does not enqueue approval request with expected title format
2. Principal inbox filter excludes attendance correction type
3. Mock store not shared across persona switch boundary
4. Title string mismatch (em dash, student name, adapter label)
5. Timing — request not visible within 30s timeout

**Emulator instability** (`adb offline`, flash-close after boot script exits) is **infrastructure only** — **not a confirmed ERP defect**. Partial 02b run achieved 1/4 chain green (finance concession → principal approve) when emulator stayed attached.

---

## Patrol program position

| Batch | Status |
|-------|--------|
| Batch 01 | ✅ 12/12 certified |
| Batch 02 | ✅ 14/14 certified |
| **Batch 02b** | ⚠️ Implemented — **not certified** (1 pass, 1 fail, 2 not run) |
| Batch 03 | ⏸ Not started — **do not begin** |

---

## Locked work (do not start)

| Item | Reason |
|------|--------|
| **F6** Audit / event upload | Awaiting Claude audit + program director |
| **F7** Production GO gate | Depends on F6 |
| **Batch 03** Patrol | 02b must certify first |
| **New features** | Freeze active |

---

## Key code paths for 02b investigation

| Area | Path |
|------|------|
| Parent correction workflow | `lib/features/parent/attendance/parent_attendance_workflow.dart` |
| Correction store | `lib/core/attendance/attendance_correction_store.dart` |
| Approval adapter | `lib/core/approvals/adapters/attendance_correction_approval_adapter.dart` |
| Patrol helpers | `patrol_test/helpers/approval_center_journey_helpers.dart` |
| Persona switch | `patrol_test/helpers/patrol_helpers.dart` (`switchQaPersona`) |
| Batch 02b suite | `patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart` |

---

## Validation commands

```bash
# Unit / integration (no emulator)
flutter analyze
flutter test

# Patrol Batch 02b (requires stable emulator)
AKSHARA_EMULATOR_HEADLESS=1 scripts/qa/start_emulator.sh
export PATH="${PATH}:${HOME}/.pub-cache/bin"
patrol test \
  -t patrol_test/workflows/patrol_batch2b_approval_chains_e2e_test.dart \
  -t patrol_test/auth/qa_persona_switch_test.dart \
  --device emulator-5554 \
  --dart-define=APP_ENV=development \
  --dart-define=ENABLE_QA_LOGIN=true \
  --dart-define=ENABLE_DEMO_AUTH=true \
  --dart-define=ENABLE_API_MODE=false
```

**Tip:** Run emulator boot and Patrol in a **single long-lived shell session** — emulator may exit when boot script terminates.

---

## Audit focus areas (suggested)

1. Batch 02b parent attendance correction → principal inbox root cause
2. Cross-persona state isolation in mock approval stores
3. F5 API vs mock parity for attendance corrections
4. Documentation consolidation (see [`PROJECT_CLEANUP_RECOMMENDATIONS.md`](./PROJECT_CLEANUP_RECOMMENDATIONS.md))
5. Production readiness gap closure plan for F6/F7

---

**STOP — Await Claude audit. No development authorized until audit completes.**
