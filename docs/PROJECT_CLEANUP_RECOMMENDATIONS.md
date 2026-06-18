# Project Cleanup Recommendations

**Date:** 2026-06-18  
**Purpose:** Classify documentation and report artifacts for future consolidation  
**Rule:** **No files deleted** — recommendations only

---

## Classification legend

| Class | Meaning |
|-------|---------|
| **KEEP** | Active SSOT or referenced by orchestrator / current program |
| **ARCHIVE** | Historical value; move to `docs/archive/` when consolidating |
| **DELETE_CANDIDATE** | Superseded duplicate; safe to remove only after link audit |

---

## Active program docs — KEEP

| Path | Reason |
|------|--------|
| `docs/ORCHESTRATOR_AGENT.md` | Program SSOT |
| `docs/CLAUDE_HANDOFF.md` | Audit entry point |
| `docs/PRE_CLAUDE_HANDOFF_REPORT.md` | Freeze snapshot |
| `docs/BACKEND_ARCHITECTURE_DECISION.md` | Locked architecture |
| `docs/PRODUCTION_BACKEND_ROADMAP.md` | F1–F7 program |
| `docs/PRE_PRODUCTION_GAP_REPORT.md` | Class A/B gaps |
| `docs/PATROL_QA_ORCHESTRATOR.md` | Live QA tracker |
| `docs/PATROL_COVERAGE_AUDIT.md` | Module inventory |
| `docs/PATROL_EXPANSION_ROADMAP.md` | Batch roadmap |
| `docs/UI_UX_AUDIT_BACKLOG.md` | Open UX defects |
| `docs/GOVERNANCE_COMPLETION_REPORT.md` | Phase D complete |
| `docs/PHASE_F1_FINAL_CERTIFICATION.md` | F1 cert |
| `docs/PHASE_F2_FINAL_CERTIFICATION.md` | F2 cert |
| `docs/PHASE_F3_FINAL_CERTIFICATION.md` | F3 cert |
| `docs/PHASE_F4_FINAL_CERTIFICATION.md` | F4 cert |
| `docs/PHASE_F5_FINAL_CERTIFICATION.md` | F5 cert |
| `docs/PATROL_BATCH_01_CERTIFICATION.md` | Batch 01 cert |
| `docs/PATROL_BATCH_02_CERTIFICATION.md` | Batch 02 cert |
| `docs/PATROL_BATCH_02B_CERTIFICATION.md` | Batch 02b (pending cert) |
| `docs/F1_AUTH_MIGRATION.md` | F1 implementation record |
| `docs/F2_APPROVAL_MIGRATION.md` | F2 implementation record |
| `docs/F3_SIS_360_MIGRATION.md` | F3 implementation record |
| `docs/F4_EXAM_MIGRATION.md` | F4 implementation record |
| `docs/F5_ATTENDANCE_MIGRATION.md` | F5 implementation record |
| `docs/Roadmap.md` | Master product roadmap |
| `docs/MULTI_AGENT_EXECUTION_PLAN.md` | Multi-agent coordination |
| `AGENTS.md` | Agent ownership |
| `docs/CURSOR_WORKFLOW.md` | Session lifecycle |

---

## F-phase analysis / execution plans — ARCHIVE (after F5)

| Path | Reason |
|------|--------|
| `docs/F2_APPROVAL_API_ANALYSIS.md` | Superseded by migration + cert |
| `docs/F2_APPROVAL_API_EXECUTION_PLAN.md` | Execution complete |
| `docs/F3_SIS_360_API_ANALYSIS.md` | Superseded by migration + cert |
| `docs/F3_SIS_360_API_EXECUTION_PLAN.md` | Execution complete |
| `docs/F4_EXAM_API_ANALYSIS.md` | Superseded by migration + cert |
| `docs/F4_EXAM_API_EXECUTION_PLAN.md` | Execution complete |
| `docs/F5_ATTENDANCE_API_ANALYSIS.md` | Keep until F5 audit; then archive |

---

## Phase D milestone docs — ARCHIVE (governance complete)

| Path | Reason |
|------|--------|
| `docs/PHASE_D_M1_FINAL_CERTIFICATION.md` | Rolled into governance report |
| `docs/PHASE_D_M2_FINAL_CERTIFICATION.md` | Same |
| `docs/PHASE_D_M3_FINAL_CERTIFICATION.md` | Same |
| `docs/PHASE_D_M4_FINAL_CERTIFICATION.md` | Same |
| `docs/PHASE_D_M5_FINAL_CERTIFICATION.md` | Same |
| `docs/PHASE_D_M6_FINAL_CERTIFICATION.md` | Same |
| `docs/PHASE_D_M7_FINAL_CERTIFICATION.md` | Same |
| `docs/PHASE_D_M1_COMPLETION_REPORT.md` | Duplicate of cert |
| `docs/PHASE_D_M2_COMPLETION_REPORT.md` | Duplicate of cert |
| `docs/PHASE_D_EXECUTION_PLAN.md` | Phase complete |
| `docs/M-D3_ANALYSIS.md` | Historical |
| `docs/M-D3_PRECHECK_REPORT.md` | Historical |
| `docs/M-D3_PUSH_REPORT.md` | Historical |
| `docs/M-D4_ANALYSIS.md` | Historical |
| `docs/M-D4_EXECUTION_PLAN.md` | Historical |
| `docs/PRE_F4_STABILIZATION_REPORT.md` | Point-in-time |
| `docs/PRE_F4_STABILIZATION_PUSH_REPORT.md` | Point-in-time |

---

## Week execution reports — ARCHIVE

| Path | Reason |
|------|--------|
| `docs/WEEK1_EXECUTION_REPORT.md` | Sprint log |
| `docs/WEEK2_EXECUTION_REPORT.md` | Sprint log |
| `docs/WEEK3_EXECUTION_REPORT.md` | Sprint log |
| `docs/WEEK4_EXECUTION_REPORT.md` | Sprint log |
| `docs/WEEK5_EXECUTION_REPORT.md` | Sprint log |

---

## Pilot / pre-production audits — KEEP (reference) / partial ARCHIVE

| Path | Class | Reason |
|------|-------|--------|
| `docs/FINAL_PILOT_CLOSURE_REPORT.md` | KEEP | Pilot closure authority |
| `docs/PILOT_READINESS_AUDIT.md` | KEEP | Gap reference |
| `docs/API_PARITY_AUDIT.md` | KEEP | API inventory |
| `docs/EXPORT_PARITY_AUDIT.md` | KEEP | Export gaps |
| `docs/PILOT_READINESS_REPORT.md` | ARCHIVE | Superseded by audit + closure |
| `docs/PILOT_SIGNOFF_REPORT.md` | ARCHIVE | Superseded |
| `docs/PILOT_DEPLOYMENT_CHECKLIST.md` | KEEP | Ops reference |

---

## Patrol certification history — ARCHIVE (superseded by batch certs)

| Path | Class | Reason |
|------|-------|--------|
| `docs/PATROL_CERTIFICATION_REPORT.md` | ARCHIVE | Pre-batch era |
| `docs/PATROL_FINAL_CERTIFICATION.md` | ARCHIVE | Superseded |
| `docs/PATROL_CURRENT_STATUS.md` | DELETE_CANDIDATE | Stale point-in-time |
| `docs/FINAL_PRE_PATROL_STATUS.md` | DELETE_CANDIDATE | Stale |
| `docs/PATROL_RECERTIFICATION_PLAN.md` | ARCHIVE | Superseded by expansion roadmap |
| `docs/QA/PATROL_EXPANSION_PLAN.md` | DELETE_CANDIDATE | Duplicate of `PATROL_EXPANSION_ROADMAP.md` |
| `docs/QA/PATROL_MASTER_INVENTORY.md` | ARCHIVE | Superseded by `PATROL_COVERAGE_AUDIT.md` |

---

## Red team / truth audits — ARCHIVE

| Path | Reason |
|------|--------|
| `docs/RED_TEAM_OPERATIONAL_AUDIT.md` | Pre-remediation baseline |
| `docs/RED_TEAM_REMEDIATION_PLAN.md` | Executed |
| `docs/RED_TEAM_REMEDIATION_REPORT.md` | Historical |
| `docs/RED_TEAM_DEFECT_CLASSIFICATION.md` | Historical |
| `docs/FINAL_TRUTH_AUDIT.md` | Point-in-time |
| `docs/REAL_SCHOOL_OPERATIONS_AUDIT.md` | Reference — archive after F7 |

---

## M15 theme / UX reports — ARCHIVE

| Path | Reason |
|------|--------|
| `docs/M15_CERTIFICATION_REPORT.md` | Theme shipped |
| `docs/PRE_M15_CERTIFICATION_REPORT.md` | Pre-ship |
| `docs/M15.5_PREMIUM_TRANSFORMATION_REPORT.md` | Historical |
| `docs/M15_THEME_MODERNIZATION_READINESS.md` | Historical |
| `docs/UX_MODERNIZATION_REPORT.md` | Superseded |
| `docs/UX_STABILIZATION_REPORT.md` | Superseded |
| `docs/UX_STABILIZATION_FINAL.md` | Superseded |
| `docs/AKSHARA_UX_MODERNIZATION_PLAN.md` | Executed |

---

## Duplicate roadmaps / status — DELETE_CANDIDATE (after link audit)

| Path | Reason |
|------|--------|
| `docs/AKSHARA_FINAL_ROADMAP.md` | Overlaps `Roadmap.md` |
| `docs/MASTER_MILESTONE_TRACKER.md` | Overlaps orchestrator |
| `docs/PROJECT_STATUS_SYNC_REPORT.md` | Point-in-time sync |
| `docs/GIT_READINESS_REPORT.md` | Point-in-time |
| `docs/WORKSPACE_STABILIZATION_REPORT.md` | Point-in-time |
| `docs/AKSHARA_V1_FINAL_STATUS.md` | Superseded by orchestrator |
| `docs/FINAL_GAP_INVENTORY.md` | Superseded by `PRE_PRODUCTION_GAP_REPORT.md` |

---

## v1.0 RC / signoff cluster — ARCHIVE (retain for compliance)

| Path | Class |
|------|-------|
| `docs/AKSHARA_V1_RC_LOCK.md` | KEEP |
| `docs/AKSHARA_V1_RELEASE_CANDIDATE.md` | ARCHIVE |
| `docs/AKSHARA_V1_FINAL_SIGNOFF.md` | ARCHIVE |
| `docs/PRODUCTION_SIGNOFF_REPORT.md` | ARCHIVE |
| `docs/PRODUCTION_READINESS_FINAL.md` | ARCHIVE |
| `docs/PRODUCTION_HARDENING_REPORT.md` | ARCHIVE |

---

## QA subdirectory — mixed

| Path | Class | Reason |
|------|-------|--------|
| `docs/QA/FINAL_COVERAGE_REPORT.md` | ARCHIVE | Pre-Patrol-batch baseline |
| `docs/QA/TEST_COVERAGE_BASELINE.md` | ARCHIVE | Baseline only |
| `docs/QA/ACTION_COVERAGE_MATRIX.md` | KEEP | Reference matrix |
| `docs/QA/UNTESTED_ACTIONS_REPORT.md` | ARCHIVE | Partially addressed |
| `docs/QA/p0_5_completion_report.md` | ARCHIVE | Historical |
| `docs/QA/vision_completion_progress.md` | ARCHIVE | Historical |

---

## Test artifacts — DELETE_CANDIDATE (not docs, but related)

| Path | Reason |
|------|--------|
| `test/golden/failures/approval_center_*` | Stale golden diff PNGs — regenerate or delete after golden pass |
| `android/.kotlin/` | Build cache — add to `.gitignore`, do not commit |

---

## Recommended consolidation action (future)

1. Create `docs/archive/2026-06-pre-claude/` and move all **ARCHIVE** items
2. Run link checker across `docs/` before any **DELETE_CANDIDATE** removal
3. Add `docs/README.md` index pointing to 5 SSOT files (orchestrator, roadmap, patrol orchestrator, handoff, gap report)
4. Deduplicate patrol status docs into `PATROL_QA_ORCHESTRATOR.md` only

**No deletions performed at freeze.**
