# F4 — Exam Administration API Execution Plan

**Date:** 2026-06-17  
**Phase:** Production Backend Program **F4**  
**Prerequisite:** **F1 ✅ · F2 ✅ · F3 ✅ certified** (`docs/PHASE_F3_FINAL_CERTIFICATION.md`)  
**Analysis:** [`docs/F4_EXAM_API_ANALYSIS.md`](./F4_EXAM_API_ANALYSIS.md)  
**Status:** Execution plan only — **do not implement until authorized**  
**Estimated duration:** **3–4 weeks** (2 backend + 1 Flutter Agent A + Agent E)

---

## Mission statement

Close Class A gap **A3** by making the server the authoritative source for:

1. **Exam session lifecycle** — draft → scheduled → marks entry → processed → published.  
2. **Marks CRUD** — roster provisioned from SIS enrollments.  
3. **Approval-gated publish** — F2 `examResults` approval required before publish.  
4. **Published results read** — parent/student/360 consume server-published marks only.

Preserve mock/UAT via `EXAM_API_ENABLED=false`. **No exam administration UI redesign.**

---

## Scope

### In scope

| Area | Deliverable |
|------|-------------|
| Schema | `exam_sessions` + extend `exam_mark_entries` |
| ERP academics API | `/academics/exams/*` full lifecycle |
| Flutter API layer | Remote, DTOs, mapper, provider gate |
| F2 publish hook | Server validates approval; client adapter API-mode guard |
| Teacher delegation | `/teacher/exams/*` → shared repository |
| Tests | Contract fake-Dio, integration (publish + approval), Patrol |
| Certification | `PHASE_F4_FINAL_CERTIFICATION.md` |

### Out of scope (F4)

| Item | Phase |
|------|-------|
| Attendance correction API | F5 |
| Full education catalog API | `EDUCATION_API_ENABLED` |
| Bulk OMR / seating | Post-F4 |
| Removing mock store entirely | F7 GO gate |

---

## Work breakdown

### F4.0 — Schema & prerequisites (Days 1–3)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.0.1 | `exam_sessions` migration (phase, metadata, coordinator) | Backend | `supabase/migrations/*_exam_sessions.sql` |
| F4.0.2 | Extend `exam_mark_entries` — `session_id` FK, `published`, `grade` | Backend | Alter migration |
| F4.0.3 | RLS school scope + `erp_tenant` grants | Backend | Policies |
| F4.0.4 | Probe fixtures (School A `exam_math_8a` parity) | Backend | Seed rows |
| F4.0.5 | Reuse F3 `resolveStudentId` for mark slots | Backend | Import from `sis_student_resolver.ts` |

**Exit:** Migrations apply; probe student marks queryable.

---

### F4.1 — Edge academics module (Days 3–10)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.1.1 | `exam_sessions_repository.ts` — CRUD + phase transitions | Backend | Repository |
| F4.1.2 | `exam_marks_repository.ts` — list/update, roster provision | Backend | Repository |
| F4.1.3 | `exam_administration_handlers.ts` | Backend | Handlers |
| F4.1.4 | `exam_administration_router.ts` + `api/index.ts` wire | Backend | Router |
| F4.1.5 | Publish handler — validate F2 approval + idempotency | Backend | `publishExamResults` |
| F4.1.6 | Published results read endpoint | Backend | Parent/360 consumer |
| F4.1.7 | Deno unit tests for phase transition guards | Backend | `*_test.ts` |

**Exit:** Postman/curl create → publish chain works on staging with principal JWT.

---

### F4.2 — Flutter API repository (Days 8–14)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.2.1 | `exam_api_paths.dart` | Agent A | Path constants |
| F4.2.2 | DTOs + `ExamMapper` | Agent A | `lib/core/repositories/api/exam_administration/` |
| F4.2.3 | `ExamRemoteDataSource` | Agent A | Fake-Dio testable |
| F4.2.4 | Replace `ApiExamAdministrationRepository` stub | Agent A | Full implementation |
| F4.2.5 | `examAdministrationRepositoryProvider` — `EXAM_API_ENABLED` gate | Agent A | `repository_providers.dart` |
| F4.2.6 | Demote `ExamAdministrationPersistence` to offline cache | Agent A | Read-through / queue only |

**Exit:** Contract tests pass with fake Dio; mock fallback unchanged.

---

### F4.3 — Approval & API-mode guards (Days 12–16)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.3.1 | `ExamResultsApprovalAdapter` — skip local publish when API enabled | Agent A | Adapter |
| F4.3.2 | Server publish requires `approvalId` + status `approved` | Backend | Handler guard |
| F4.3.3 | Integration test: submit approval → approve → publish | Agent E | `f4_exam_api_integration_test.dart` |
| F4.3.4 | Audit events for phase transitions | Backend | `mutation_audit_catalog.ts` |

**Exit:** Cannot publish without approved F2 row; adapter does not double-publish locally.

---

### F4.4 — Teacher mobile delegation (Days 14–18)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.4.1 | Teacher marks list → `exam_marks_repository` | Backend | `teacher_handlers.ts` |
| F4.4.2 | Teacher process/publish → academics handlers | Backend | Shared service |
| F4.4.3 | Teacher contract parity test | Agent E | Extend teacher integration |

**Exit:** Teacher marks entry works against same DB rows as ERP marks screen.

---

### F4.5 — Tests & parity (Days 16–20)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.5.1 | Extend `exam_administration_repository_contract_test.dart` — fake Dio | Agent E | API parity |
| F4.5.2 | Tenant isolation probes — School A/B exam rows | Agent E | Security |
| F4.5.3 | Student 360 marks filter — published only | Agent E | F3 regression |
| F4.5.4 | Restart test → offline cache semantics | Agent E | Rename integration test |

---

### F4.6 — Certification (Days 20–22)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F4.6.1 | `flutter analyze` 0 errors | Agent G | Gate |
| F4.6.2 | Full affected `flutter test` | Agent G | Gate |
| F4.6.3 | Patrol `workflow_exam_publish_approval.yaml` + pilot closure exam tests | Agent E | Green |
| F4.6.4 | `PHASE_F4_FINAL_CERTIFICATION.md` | Agent F | Sign-off |
| F4.6.5 | `F4_EXAM_MIGRATION.md` | Agent F | Rollback doc |
| F4.6.6 | Orchestrator → ~81% | Agent F | `ORCHESTRATOR_AGENT.md` v1.8 |

**Exit:** F4 commit; production API readiness **~81%**.

---

## Validation order

```
flutter analyze
→ test/contracts/exam_administration/
→ test/integration/exam_administration/
→ test/integration/approval/ (exam publish chain)
→ emulator (non-blocking)
→ Patrol exam workflows
→ PHASE_F4_FINAL_CERTIFICATION.md
→ commit (F4-scoped files only)
```

---

## Commit scope template

**Include:**

- `supabase/migrations/*exam*`
- `supabase/functions/_shared/academics/exam_*`
- `lib/core/repositories/api/exam_administration/**`
- `lib/core/approvals/adapters/exam_results_approval_adapter.dart` (API guard only)
- `lib/core/repositories/repository_providers.dart` (exam gate only)
- `test/contracts/exam_administration/**`
- `test/integration/exam_administration/f4_*`
- `docs/F4_*`, `docs/PHASE_F4_FINAL_CERTIFICATION.md`
- `docs/ORCHESTRATOR_AGENT.md` (readiness bump)

**Exclude:** Unrelated pilot UI, governance, inventory, HR changes.

---

## Risk register

| Risk | Mitigation |
|------|------------|
| SharedPreferences data fork on cutover | One-time import endpoint + export script before flag flip |
| Duplicate publish (adapter + server) | API-mode guard in adapter (F2 pattern) |
| `exam_id` TEXT vs UUID mismatch | Session table UUID PK; keep legacy `exam_code` column for mock ids |
| Teacher mobile stale snapshots | Invalidate `mobile_entities` exam snapshots on publish |

---

## Authorization gate

Implementation starts only when Program Director sends an explicit F4 mission block (same format as F3). This document is **planning only**.
