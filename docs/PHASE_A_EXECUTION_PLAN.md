# Phase A — Exams & Academic Governance: Execution Plan

**Version:** 1.0  
**Date:** 2026-06-17  
**Branch:** `feature/m15-theme`  
**Duration:** 6–8 weeks (engineering)  
**Companion docs:** [`OPERATIONAL_GAP_MASTER_TRACKER.md`](./OPERATIONAL_GAP_MASTER_TRACKER.md) · [`OPERATIONAL_REMEDIATION_ROADMAP.md`](./OPERATIONAL_REMEDIATION_ROADMAP.md) · [`PHASE_D_EXECUTION_PLAN.md`](./PHASE_D_EXECUTION_PLAN.md)

**Status:** Planning only — no code, tests, routes, or commits.

---

## 1. Phase objective

Enable a real school academic cycle:

1. Academic coordinator **creates and schedules** exams (weekly → annual).
2. Subject teachers **enter marks** for assigned class/section/subject only.
3. Coordinator **verifies** marks completeness.
4. Principal **approves** before results are visible to parents/students.
5. Exam data **persists** across app restarts (repository layer, not singleton memory).

**Readiness target:** Academics & Exams **25% → 65%** · Teacher App **55% → 68%** · Parent App **60% → 68%**.

---

## 2. Gap scope (Phase A)

| Gap ID | Severity | Type | Milestone |
|--------|----------|------|-----------|
| P0-EXAM-001 | P0 | WIRE | M-A1, M-A2 |
| P0-EXAM-002 | P0 | WIRE | M-A4 |
| P0-EXAM-003 | P0 | NET_NEW | M-A5 |
| P0-EXAM-004 | P0 | NET_NEW | M-A3 |
| P1-EXAM-001 | P1 | WIRE | M-A7 |
| P1-EXAM-002 | P1 | WIRE | M-A7 |
| P1-EXAM-003 | P1 | WIRE | M-A7 |
| P1-EXAM-004 | P1 | NET_NEW | M-A6 |
| P1-EXAM-005 | P1 | NET_NEW | M-A4 |
| P1-EXAM-006 | P1 | NET_NEW | M-A5 |
| P1-EXAM-007 | P1 | WIRE | M-A4 |
| P1-EXAM-008 | P1 | WIRE | M-A5 |
| P1-PAR-001 | P1 | DISCONNECT | M-A8 |
| P1-AUD-001 | P1 | WIRE | M-A5 |
| P1-AUD-002 | P1 | WIRE | M-A7 |
| WF-001 | — | DISCONNECT | M-A1 |
| WF-002 | — | — | M-A5 |
| WF-003 | — | — | M-A7 |
| DISC-001 | — | DISCONNECT | M-A1 |
| DISC-002 | — | DISCONNECT | M-A2, M-A4 |
| DISC-004 | — | DISCONNECT | M-A8 |
| APR-001 | — | — | M-A2 (schedule approval optional MVP) |
| APR-002 | — | — | M-A5 (requires Phase D) |
| RBAC-001 | P1 | NET_NEW | M-A5 |
| RBAC-002 | P1 | NET_NEW | M-A5 |

**Out of scope (defer):** P2-EXAM-001–008, question bank rebuild, `ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` full platform, co-scholastic, exam calendar/invigilation.

**Phase D dependency:** P0-EXAM-003 principal approval uses Phase D inbox (M-D2). **Fallback:** temporary approve screen on `ManagementTasksScreen` until D ships (Week 5–6).

---

## 3. Existing code to reuse

| Asset | Path | Reuse for |
|-------|------|-----------|
| `ExamAdministrationStore` | `lib/core/exams/exam_administration_store.dart` | Domain model, lifecycle (`draft→scheduled→marksEntry→processed→published`), grade bands, seed data |
| `ExamLifecyclePhase`, `ExamSession`, `ExamMarkRecord` | same | DTOs for repository interface |
| `EduExamType` enum | `lib/features/education/education_models.dart` | Exam type dropdown (unit/weekly/monthly/quarterly/halfYearly/annual) |
| `EducationScreen` | `lib/features/education/education_screen.dart` | Link-only entry to question papers (do not duplicate) |
| `TeacherExamsScreen` | `lib/features/teacher/exams/teacher_exams_screen.dart` | Marks entry UI shell |
| `teacher_exams_provider.dart` | `lib/features/teacher/exams/` | Provider pattern for marks list |
| `teacher_mutations_provider.dart` | `lib/features/teacher/` | `updateExamMark`, `publishExamResults` + audit pattern |
| `MockTeacherRepository` | `lib/core/repositories/mock/mock_teacher_repository.dart` | Delegates to store — swap to `ExamRepository` |
| `mock_exam_results_sync_store.dart` | `lib/core/repositories/mock/` | Cross-persona invalidation pattern |
| `exam_administration_chain_test.dart` | `test/core/exams/` | Chain test template (extend for approval gate) |
| `teacher_repository_contract_test.dart` | `test/contracts/mobile/` | Contract test pattern |
| `SchoolCompletionRepository` | `lib/core/repositories/interfaces/school_completion_repository.dart` | Subject catalog CRUD |
| `subjects_screen.dart` | `lib/features/school_completion/` | Subject list shell |
| `subject_assignment_screen.dart` | `lib/features/school_completion/` | Teacher–class–subject matrix for RBAC |
| `AcademicRepository` | `lib/core/repositories/interfaces/academic_repository.dart` | Class/section/year pickers |
| `academic_catalog_provider.dart` | `lib/core/repositories/academic/` | Enriched class/section labels |
| `parent_exams_screen.dart` / providers | `lib/features/parent/exams/` | Results visibility (post-publish) |
| `student_exams_screen.dart` / providers | `lib/features/student/exams/` | Same |
| `student_report_card_screen.dart` | `lib/features/student/progress/` | Report card from published results |
| `parent_academic_report_screen.dart` | `lib/features/parent/academics/` | Wire to live marks |
| `management_academics_screen.dart` | `lib/features/management/` | Read-only oversight KPIs |
| `exam_intelligence_screen.dart` | `lib/features/intelligence/exam/` | Analytics (read-only, no change) |
| `approveAdmission` pattern | `lib/features/admissions/admissions_mutations_provider.dart` | Approval mutation + audit + invalidate |
| `teacher_api_paths.dart` | `lib/core/network/paths/` | Extend with exam admin CRUD paths |
| `QaTestKeys` | `lib/core/testing/qa_test_keys.dart` | Patrol key hooks |

---

## 4. Implementation milestones

### M-A1 — Assessment domain foundation (Week 1)

**Gaps:** P0-EXAM-001 (partial), DISC-001, WF-001  
**Type:** WIRE + NET_NEW (interface only)

| Task | Type | Description |
|------|------|-------------|
| A1.1 | NET_NEW | Define `ExamAdministrationRepository` interface: `listExams`, `createExam`, `scheduleExam`, `openMarksEntry`, `processResults`, `submitForApproval`, `approveResults`, `publishResults`, `listMarks`, `updateMark` |
| A1.2 | WIRE | Map interface methods to existing `ExamAdministrationStore` in `MockExamAdministrationRepository` |
| A1.3 | NET_NEW | Add `examType` field to `ExamSession` (use `EduExamType`) — migrate store seed |
| A1.4 | WIRE | Register repository in `repository_config.dart` / `repository_providers.dart` |
| A1.5 | DISCONNECT | Document single entry: ERP Exam Admin owns scheduling; Education Suite owns question papers only (banner link) |

**Files affected (new):**
```
lib/core/repositories/interfaces/exam_administration_repository.dart
lib/core/repositories/mock/mock_exam_administration_repository.dart
lib/core/repositories/api/exam_administration/  (stub → ApiNotConnectedException until backend)
test/contracts/exam_administration/exam_administration_repository_contract_test.dart
test/contracts/exam_administration/exam_administration_fixture_builder.dart
```

**Files affected (modify):**
```
lib/core/exams/exam_administration_store.dart
lib/core/repositories/repository_config.dart
lib/core/repositories/repository_providers.dart
lib/features/education/education_screen.dart  (cross-link banner only)
```

**Acceptance criteria:**
- [ ] Contract test passes mock ↔ interface parity for all CRUD lifecycle methods
- [ ] `EduExamType.annual` mappable on `ExamSession`
- [ ] Store remains default backing until API flag enabled
- [ ] No UI changes yet — tests green

**Flutter tests:**
- `exam_administration_repository_contract_test.dart` — create, schedule, open marks, process, publish
- Extend `exam_administration_chain_test.dart` — assert repository delegation

**Patrol tests:** None (no UI).

**Rollback:** Remove interface + mock; restore direct store usage. Feature flag `EXAM_REPOSITORY_ENABLED=false`.

---

### M-A2 — ERP Exam Administration UI (Week 2)

**Gaps:** P0-EXAM-001, DISC-002 (partial), APR-001 (optional MVP)

| Task | Type | Description |
|------|------|-------------|
| A2.1 | NET_NEW | `ExamAdministrationScreen` — list exams by phase filter (draft/scheduled/marks entry/processed/published) |
| A2.2 | NET_NEW | Create exam dialog: academic year, class, section, subject (from School Completion + Academic catalog), `EduExamType`, max marks, date, time, venue |
| A2.3 | WIRE | Actions: Schedule, Open marks entry — call repository |
| A2.4 | WIRE | Navigation: School Completion hub or Management → Academics drill-down |
| A2.5 | NET_NEW | Route + `viewExams` / `manageExams` permissions (add to `permissions.dart`) |

**Files affected (new):**
```
lib/features/academics/exam_admin/
  exam_admin_navigation.dart
  exam_administration_screen.dart
  exam_administration_provider.dart
  widgets/exam_create_dialog.dart
  widgets/exam_lifecycle_actions.dart
  exam_admin_models.dart
lib/router/  (exam admin routes)
test/features/academics/exam_admin/exam_administration_screen_test.dart
test/features/academics/exam_admin/exam_administration_provider_test.dart
```

**Files affected (modify):**
```
lib/core/security/permissions.dart
lib/core/security/rbac_service.dart
lib/router/route_guards.dart
lib/router/route_names.dart
lib/features/school_completion/school_completion_hub_screen.dart
lib/features/management/academics/management_academics_screen.dart
lib/core/testing/qa_test_keys.dart
```

**Acceptance criteria:**
- [ ] Coordinator creates "Class 8-A Mathematics Half-Yearly, 80 marks, 15 Mar 2026"
- [ ] Exam appears in scheduled list; "Open marks entry" transitions phase
- [ ] Route guarded: `viewExams` read, `manageExams` write
- [ ] Subject picker uses School Completion `listSubjects`, not free text

**Flutter tests:**
- Widget: create dialog validation (required fields, max marks > 0)
- Provider: create → schedule → openMarksEntry state transitions
- Route inventory: exam admin routes in protected route test

**Patrol tests (new journey):**
```
qa/journeys/biz_erp_exam_administration.yaml
```
Steps: staff login (Principal/Admin) → School Completion or Management → Exam Administration → create exam → schedule → open marks entry → screenshot.

**Rollback:** Hide route via feature flag `EXAM_ADMIN_UI_ENABLED=false`; exams remain seed-only.

---

### M-A3 — Persistent exam repository (Week 2–3)

**Gaps:** P0-EXAM-004

| Task | Type | Description |
|------|------|-------------|
| A3.1 | NET_NEW | `ApiExamAdministrationRepository` + remote datasource DTOs (snake_case envelope) |
| A3.2 | NET_NEW | Mock persistence layer: `SharedPreferences` or local Hive/file mock for dev (survives restart in QA) |
| A3.3 | WIRE | `repository_config.dart`: `EXAM_API_ENABLED` dart-define |
| A3.4 | NET_NEW | Integration test with fake Dio |
| A3.5 | NET_NEW | Backend contract doc / OpenAPI paths alignment (`teacher_api_paths.dart` extend) |

**Files affected (new):**
```
lib/core/repositories/api/exam_administration/
  api_exam_administration_repository.dart
  remote/exam_administration_remote_datasource.dart
  dto/exam_session_dto.dart
  mappers/exam_administration_mapper.dart
test/integration/exam_administration/exam_administration_integration_test.dart
test/contracts/exam_administration/exam_administration_write_contract_test.dart
docs/ClientBackendAlignment.md  (exam endpoints section — doc update only)
```

**Files affected (modify):**
```
lib/core/network/paths/teacher_api_paths.dart
lib/core/repositories/mock/mock_exam_administration_repository.dart
lib/core/exams/exam_administration_store.dart  (optional: store becomes cache)
```

**Acceptance criteria:**
- [ ] App restart preserves exams created in session (mock persistent or API)
- [ ] `ApiNotConnectedException` when API enabled but unreachable
- [ ] Integration test: create exam via fake Dio → read back

**Flutter tests:**
- Integration: fake Dio CRUD round-trip
- Contract: mock ↔ API mapper parity
- Regression: `exam_administration_chain_test.dart` uses repository not raw store

**Patrol tests:** Extend `biz_erp_exam_administration.yaml` — restart app mid-journey (if Patrol supports), or manual QA checklist item.

**Rollback:** Force `EXAM_API_ENABLED=false` + in-memory store; no data loss if mock persistence file kept.

---

### M-A4 — Teacher marks entry selectors & validation (Week 3–4)

**Gaps:** P0-EXAM-002, P1-EXAM-005, P1-EXAM-007, DISC-002

| Task | Type | Description |
|------|------|-------------|
| A4.1 | WIRE | Replace `teacherActiveExamIdProvider` single-exam with selector: class → section → subject → exam |
| A4.2 | WIRE | Filter exams to `marksEntry` / `processed` phase only |
| A4.3 | NET_NEW | RBAC filter: teacher sees only exams matching `subject_assignment_screen` assignments |
| A4.4 | NET_NEW | Marks validation: 0 ≤ marks ≤ maxMarks; absent (`AB`) / exempt codes |
| A4.5 | WIRE | Section picker on subject assignment dialog (P1-EXAM-007) |
| A4.6 | NET_NEW | Explicit Save row + bulk save (not keyboard-submit only) |

**Files affected (modify):**
```
lib/features/teacher/exams/teacher_exams_screen.dart
lib/features/teacher/exams/teacher_exams_provider.dart
lib/features/teacher/exams/exam_models.dart
lib/core/repositories/mock/mock_teacher_repository.dart
lib/features/school_completion/subject_assignment_screen.dart
test/features/teacher/exams/teacher_exams_provider_test.dart
test/features/teacher/exams/teacher_exams_screen_test.dart  (new)
```

**Acceptance criteria:**
- [ ] Teacher with only 9-B Science cannot open 8-A Mathematics marks
- [ ] Switching exam updates student roster from canonical registry for that class
- [ ] Entering 95/80 shows validation error
- [ ] Absent code saves as non-numeric result

**Flutter tests:**
- Provider: scoped exam list per teacher assignment
- Provider: validation rejects over-max marks
- Widget: selector changes reload marks list
- Security: teacher without assignment gets empty list

**Patrol tests (extend):**
```
qa/journeys/biz_teacher_exams.yaml
```
Add: select exam from dropdown → enter mark → save → screenshot marks entry.

**Rollback:** Feature flag `TEACHER_EXAM_SELECTORS_ENABLED=false` → revert to single active exam.

---

### M-A5 — Publish governance & approval gate (Week 4–5)

**Gaps:** P0-EXAM-003, P1-EXAM-006, P1-EXAM-008, WF-002, APR-002, RBAC-001, RBAC-002, P1-AUD-001

| Task | Type | Description |
|------|------|-------------|
| A5.1 | WIRE | Expose `processResults` in teacher UI — "Submit for verification" (not publish) |
| A5.2 | NET_NEW | Replace direct `publishExamResults` with `submitExamResultsForApproval` → creates approval item |
| A5.3 | WIRE | Phase D: principal approves in Approval Center → `publishExamResults` |
| A5.4 | FALLBACK | If Phase D not ready: `ManagementTasksScreen` filter type `examResults` + approve action |
| A5.5 | NET_NEW | Permissions: `manageExamMarks`, `submitExamResults`, `approveExamResults`, `publishExamResults` |
| A5.6 | WIRE | Fix audit: `AuditEventType.examMarkUpdated`, `examResultsSubmitted`, `examResultsPublished` |
| A5.7 | WIRE | `mutation_permission_registry.dart` entries for exam mutations |

**Files affected (modify):**
```
lib/features/teacher/exams/teacher_exams_screen.dart
lib/features/teacher/teacher_mutations_provider.dart
lib/core/security/permissions.dart
lib/core/security/mutation_permission_registry.dart
lib/core/audit/audit_event.dart
lib/features/management/management_models.dart  (add ManagementApprovalType.examResults)
lib/features/management/management_mutations_provider.dart
test/features/teacher/exams/teacher_exams_provider_test.dart
test/core/security/mutation_permission_registry_test.dart
test/integration/exam_administration/exam_publish_approval_integration_test.dart  (new)
```

**Files affected (Phase D — see PHASE_D_EXECUTION_PLAN.md):**
```
lib/features/management/approval/  (shared approval queue)
```

**Acceptance criteria:**
- [ ] Teacher cannot publish directly — button says "Submit for approval"
- [ ] Parent/student exam results empty until principal approves
- [ ] `processResults` required before submit (incomplete marks blocked)
- [ ] Audit log shows correct event types
- [ ] RBAC: only `approveExamResults` role can publish

**Flutter tests:**
- Chain: marks → process → submit → pending approval → approve → parent sees results
- Security: teacher without `approveExamResults` cannot publish
- Regression: `exam_administration_chain_test.dart` updated for approval gate

**Patrol tests (new):**
```
qa/journeys/workflow_exam_publish_approval.yaml
```
Teacher submit → Principal login → Approval Center → approve → Parent login → results visible.

**Rollback:** Feature flag `EXAM_APPROVAL_REQUIRED=false` restores direct publish (pilot emergency only).

---

### M-A6 — Grading scheme configuration (Week 5)

**Gaps:** P1-EXAM-004

| Task | Type | Description |
|------|------|-------------|
| A6.1 | NET_NEW | `GradingScheme` model: pass marks, grade bands (A+–D or CBSE 9-point MVP) |
| A6.2 | NET_NEW | Settings screen under School Completion or Exam Admin |
| A6.3 | WIRE | `ExamAdministrationStore._gradeForPercent` reads configured scheme |

**Files affected (new):**
```
lib/core/exams/grading_scheme.dart
lib/features/academics/exam_admin/grading_scheme_screen.dart
test/core/exams/grading_scheme_test.dart
```

**Acceptance criteria:**
- [ ] Principal sets pass marks 33%; grade bands editable
- [ ] Published results use configured bands

**Flutter tests:** Unit tests for grade calculation edge cases (boundary percentages).

**Patrol:** Optional settings screenshot in exam admin journey.

**Rollback:** Default hardcoded bands if settings missing.

---

### M-A7 — Subject catalog hardening (Week 5–6)

**Gaps:** P1-EXAM-001, P1-EXAM-002, P1-EXAM-003, WF-003, P1-AUD-002

| Task | Type | Description |
|------|------|-------------|
| A7.1 | WIRE | Replace FAB with `SubjectCreateDialog` (code, name, category, grades) |
| A7.2 | WIRE | Edit subject sheet using `updateSubject` |
| A7.3 | WIRE | `assertManageSubjects` on create/update mutations |
| A7.4 | WIRE | `recordAudit` on subject create/update |

**Files affected (modify):**
```
lib/features/school_completion/subjects_screen.dart
lib/features/school_completion/widgets/  (new dialogs)
lib/core/security/mutation_permission_validator.dart
test/contracts/school_completion/school_completion_repository_contract_test.dart
test/features/school_completion/subjects_screen_test.dart  (new)
```

**Acceptance criteria:**
- [ ] No hardcoded NEW/New Subject records
- [ ] Duplicate subject code rejected
- [ ] Audit event on create/update

**Flutter tests:** Widget dialog validation; RBAC deny without `manageSubjects`.

**Patrol:** Extend School Completion journey with add subject flow.

**Rollback:** Revert dialog; keep list read-only.

---

### M-A8 — Parent academic report from live marks (Week 6)

**Gaps:** P1-PAR-001, DISC-004

| Task | Type | Description |
|------|------|-------------|
| A8.1 | WIRE | `mock_parent_repository.getAcademicSummary` reads published results from exam repository |
| A8.2 | WIRE | `parent_academic_report_screen.dart` — subject scores from live data |
| A8.3 | WIRE | API parent repository same mapping |

**Files affected (modify):**
```
lib/core/repositories/mock/mock_parent_repository.dart
lib/core/repositories/api/parent/  (mapper)
lib/features/parent/academics/parent_academic_report_screen.dart
test/features/parent/academics/parent_academic_report_provider_test.dart  (new)
test/contracts/mobile/parent_repository_contract_test.dart
```

**Acceptance criteria:**
- [ ] Parent academic report reflects marks only after principal publish
- [ ] Subject averages match student exam results

**Flutter tests:** Provider test with publish chain fixture.

**Patrol:** Extend `biz_parent_exams.yaml` — academic report shows published scores.

**Rollback:** Static mock fallback via feature flag.

---

## 5. Wiring vs net-new summary

| Category | Count | % effort |
|----------|-------|----------|
| **WIRE** | 18 tasks | ~45% |
| **NET_NEW** | 14 tasks | ~40% |
| **DISCONNECT** (unify) | 4 tasks | ~15% |

**Highest ROI wiring (do first):** M-A1 store→repository, M-A4 selectors, M-A5 audit fix, M-A8 parent report.

---

## 6. Implementation order (strict)

```
Week 1:  M-A1 (repository interface + contract tests)
Week 2:  M-A2 (exam admin UI) ║ M-A3 start (persistence)
Week 3:  M-A3 complete ║ M-A4 start (selectors)
Week 4:  M-A4 complete ║ M-A5 start (approval — coordinate with Phase D Week 2)
Week 5:  M-A5 complete ║ M-A6 (grading) ║ Phase D M-D2 (exam approval type)
Week 6:  M-A7 (subjects) ║ M-A8 (parent report)
Week 7:  Integration hardening, Patrol, docs update
Week 8:  Buffer, pilot sign-off, rollback drill
```

**Parallel with Phase D:** M-A5 must align with M-D1 (approval infrastructure) by Week 4.

---

## 7. Required Flutter test matrix

| Layer | New/updated tests | Gate |
|-------|-------------------|------|
| **Unit** | `grading_scheme_test.dart` | `flutter test test/core/exams/` |
| **Contract** | `exam_administration_repository_contract_test.dart`, `exam_administration_write_contract_test.dart` | `flutter test test/contracts/exam_administration/` |
| **Provider** | `exam_administration_provider_test.dart`, `teacher_exams_provider_test.dart` (extend) | `flutter test test/features/academics/ test/features/teacher/exams/` |
| **Widget** | `exam_administration_screen_test.dart`, `teacher_exams_screen_test.dart`, `subjects_screen_test.dart` | Same |
| **Integration** | `exam_administration_integration_test.dart`, `exam_publish_approval_integration_test.dart` | `flutter test test/integration/exam_administration/` |
| **Security** | `mutation_permission_registry_test.dart` (exam entries), RBAC route inventory | `flutter test test/security/` |
| **Regression** | `exam_administration_chain_test.dart`, `parent_repository_contract_test.dart`, `student_exams_provider_test.dart` | `flutter test` full |
| **Route inventory** | Update `router_route_protection_inventory_test.dart` | Required |

**CI gate (Phase A complete):** `flutter analyze` (0 issues) + all above suites green.

---

## 8. Patrol / Maestro test matrix

| Journey | File | Priority | Covers |
|---------|------|----------|--------|
| ERP exam administration | `qa/journeys/biz_erp_exam_administration.yaml` | P0 | M-A2 create/schedule/open marks |
| Teacher marks entry | `qa/journeys/biz_teacher_exams.yaml` (extend) | P0 | M-A4 selectors + save |
| Exam publish approval | `qa/journeys/workflow_exam_publish_approval.yaml` | P0 | M-A5 + Phase D |
| Parent results visibility | `qa/journeys/biz_parent_exams.yaml` (extend) | P1 | M-A5 post-approval |
| Student results | `qa/journeys/workflow_exams.yaml` (extend) | P1 | M-A5 |
| School Completion subjects | existing + extend | P2 | M-A7 |
| Parent academic report | `qa/journeys/biz_parent_exam_readiness.yaml` (extend) | P1 | M-A8 |

**Register in:** `qa/patrol/journey_manifest.json`

**Run command:** `bash qa/patrol/run_erp_coverage.sh` (FULL after Phase A)

**QA keys to add:** `QaTestKeys.examAdminCreateButton`, `examMarksSubmitApproval`, `examPrincipalApprove` (planning IDs — implement in M-A2/M-A5).

---

## 9. Rollback strategy

### 9.1 Feature flags (dart-define)

| Flag | Default | Effect when false |
|------|---------|-------------------|
| `EXAM_REPOSITORY_ENABLED` | false | Use legacy `ExamAdministrationStore` singleton |
| `EXAM_ADMIN_UI_ENABLED` | false | Hide exam admin routes; seed data only |
| `TEACHER_EXAM_SELECTORS_ENABLED` | false | Single active exam marks entry |
| `EXAM_APPROVAL_REQUIRED` | false | Direct teacher publish (pre-Phase A behaviour) |
| `PARENT_LIVE_ACADEMIC_SUMMARY` | false | Static mock academic report |

### 9.2 Rollback levels

| Level | Trigger | Action |
|-------|---------|--------|
| **L1 — UI** | Exam admin UI bugs | `EXAM_ADMIN_UI_ENABLED=false` |
| **L2 — Workflow** | Approval blocks pilot demo | `EXAM_APPROVAL_REQUIRED=false` |
| **L3 — Data** | Repository corruption | Revert to store seed via `ExamAdministrationStore.reset()` |
| **L4 — Full** | Phase A abandoned | Git revert phase branch; restore pre-A `teacher_exams` behaviour |

### 9.3 Data safety

- Mock persistence file: versioned schema; migration rollback script deletes `exam_admin_mock_v1.json`
- API mode: backend owns data — client rollback is read-only fallback to cache
- Published results: never auto-unpublish on rollback (manual principal action only)

### 9.4 Rollback verification

After any L1–L2 rollback:
1. `flutter test test/core/exams/exam_administration_chain_test.dart`
2. `qa/journeys/biz_teacher_exams.yaml` (legacy path)
3. Parent/student see last published results only

---

## 10. Phase A exit checklist

- [ ] P0-EXAM-001 through P0-EXAM-004 closed
- [ ] P0-EXAM-003 uses Phase D approval (or documented fallback)
- [ ] P1-EXAM-001 through P1-EXAM-008 closed (except defer P2 items)
- [ ] P1-PAR-001 closed
- [ ] `flutter analyze` = 0
- [ ] Contract + integration tests for exam repository
- [ ] Patrol journeys registered and passing on emulator
- [ ] `docs/PilotSchoolChecklist.md` academics section updated
- [ ] Readiness: Academics **≥ 65%**

---

## 11. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Phase D delayed | Fallback approve on `ManagementTasksScreen` (M-A5.4) |
| Backend API not ready | Mock persistence (M-A3.2) for pilot |
| Scope creep into question bank | Explicit deferral to `ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` |
| Teacher assignment data incomplete | Seed assignments in mock; block marks if unassigned |
| RBAC regression | Extend `rbac_validation_suite_test.dart` before merge |

---

## Change log

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-06-17 | Initial Phase A execution plan |
