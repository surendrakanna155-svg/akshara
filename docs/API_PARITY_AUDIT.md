# API Parity Audit — Pilot Scope

**Date:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Scope:** Phase A–E pilot workflows only (no Marketing, no optional F/G/H modules)  
**Classification:** Complete · Partial · Missing

---

## Executive summary

| Classification | Count | Meaning |
|----------------|-------|---------|
| **Complete** | 0 | Mock + API + contract parity for all pilot steps |
| **Partial** | 8 | Mock operational; API stubbed, hybrid, or read-only |
| **Missing** | 0 | No mock path (all pilot workflows have mock) |

**Verdict:** Pilot runs on **mock + SharedPreferences persistence** with selective API reads (finance refunds, Student 360, HR leave reads). Production backend parity is **not** a pilot blocker; it is a **production-pilot** blocker (PB-03).

---

## Workflow matrix

| Workflow | Mock | API | Contract test | Status |
|----------|------|-----|---------------|--------|
| Exam administration (create → marks → process → publish → approval) | `mock_exam_administration_repository.dart` | `api_exam_administration_repository.dart` (full stub) | `exam_administration_repository_contract_test.dart` | **Partial** |
| Attendance correction | `mock_attendance_correction_repository.dart` | None (mock-only provider) | `attendance_correction_repository_contract_test.dart` | **Partial** |
| Student leave (parent submit → principal approve) | `mock_parent_repository.dart` + `mock_approval_repository.dart` | Parent: real submit/read · Approval: full stub | `parent_write_contract_test.dart`, `approval_repository_contract_test.dart` | **Partial** |
| Staff leave (HR) | `mock_hr_repository.dart` | `api_hr_repository.dart` + hybrid (create stubbed) | `hr_repository_contract_test.dart` (reads only) | **Partial** |
| Finance concession approval | Governance store + adapters | Finance catalog real; approval API stub | `finance_write_contract_test.dart`, `approval_repository_contract_test.dart` | **Partial** |
| Finance refund approval | `mock_finance_repository.dart` | `api_finance_repository.dart` (full CRUD) | `finance_repository_contract_test.dart`, `finance_write_contract_test.dart` | **Partial** |
| Student 360 dossier read | `mock_student_360_repository.dart` | `ApiStudent360Repository` (`SIS_API_ENABLED`) | `student_360_repository_contract_test.dart` (**added**) | **Partial** |
| Inventory PO (pilot M-D6) | `mock_inventory_repository.dart` | Hybrid: reads real, writes stub + mock fallback | `inventory_repository_contract_test.dart` (reads) | **Partial** |

---

## Cross-cutting blocker

**Unified approval repository** (`api_approval_repository.dart`) is a **full stub**. This blocks API-mode principal approval for:

- Exam results publish
- Student leave
- Attendance correction
- Finance concession (when governance on)

Mock mode + governance stores are **pilot-complete**.

---

## Pilot-critical gaps implemented this sprint

| Gap | Action |
|-----|--------|
| Student 360 no contract test | Added `test/contracts/student_360/student_360_repository_contract_test.dart` |
| Exam persistence not restart-safe | P0-EXAM-004: `ExamAdministrationPersistence` + migration from `akshara_exam_results_sync_v1` |

## Deferred (production-pilot, not mock pilot)

1. `ApiExamAdministrationRepository` — remote datasource + DTO mapper  
2. `ApiAttendanceCorrectionRepository` — new API layer  
3. `ApiApprovalRepository` — unlocks all principal-approve paths in API mode  
4. Inventory PO write endpoints  
5. HR `createLeaveRequest` remote wiring  

---

## Feature flags

| Flag | Module |
|------|--------|
| `EXAM_API_ENABLED` | Exam administration |
| `FINANCE_API_ENABLED` | Finance refunds / catalog |
| `SIS_API_ENABLED` | Student 360 |
| `HR_API_ENABLED` | HR leave |
| `INVENTORY_API_ENABLED` | Inventory PO |
| `APPROVAL_API_ENABLED` | Unified approval center |

Default QA/Patrol builds use `ENABLE_API_MODE=false` → mock providers.
