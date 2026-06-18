# F3 — SIS + Student 360 API Execution Plan

**Date:** 2026-06-17  
**Phase:** Production Backend Program **F3**  
**Prerequisite:** **F1 ✅ · F2 ✅ certified** (`docs/PHASE_F2_FINAL_CERTIFICATION.md`)  
**Analysis:** [`docs/F3_SIS_360_API_ANALYSIS.md`](./F3_SIS_360_API_ANALYSIS.md)  
**Status:** Execution plan only — **do not implement until authorized**  
**Estimated duration:** **1.5–2 weeks** (1.5 backend + 0.5 Flutter Agent A + Agent E)

---

## Mission statement

Close Class A gap **A8** by making the server the authoritative source for:

1. **SIS registry** — search, filter, paginated student list.  
2. **Student profile** — core identity + guardians (+ document metadata).  
3. **Student 360 dossier** — all **9 UI tabs** populated in API mode.  
4. **Communication timeline** — merged activity feed.

Preserve mock/UAT via `SIS_API_ENABLED=false`. **No Student 360 or SIS screen redesign.**

---

## Scope

### In scope

| Area | Deliverable |
|------|-------------|
| SIS registry + search | `GET /sis/students` parity + filter fix |
| Student profile | `GET/PUT/PATCH /sis/students/{id}` + optional summary enrichment |
| Student 360 aggregate | `GET /sis/students/{id}/360` — all domains including behaviour, transport, documents |
| Timeline | `GET /sis/students/{id}/timeline` + communication merge |
| Documents | `GET/POST /sis/students/{id}/documents` + `student_documents` migration |
| Flutter API layer | Mapper parity, fake-Dio contracts, integration test |
| ID crosswalk | UUID alignment for teacher/parent/SIS drill-down |

### Out of scope (F3)

| Item | Phase |
|------|-------|
| Exam administration CRUD | F4 |
| Attendance mark/correction writes | F5 |
| Full conduct incident management UI | F7+ |
| Activities / achievements content | Post-F3 |
| `feeStructure` / concession server orchestration | F7 |
| Separate `STUDENT_360_API_ENABLED` flag | Defer — keep `SIS_API_ENABLED` |

---

## Work breakdown

### F3.0 — Preconditions & ID alignment (Days 1–2)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F3.0.1 | Audit staging student rows vs mock seeds | Backend | Gap report |
| F3.0.2 | ID crosswalk fixture (`SIS-STU-*` → UUID) | Agent E | `test/helpers/sis_id_crosswalk.dart` |
| F3.0.3 | Fix registry filter `prospect` vs `inactive` | Agent A | `sis_registry_provider.dart` + status codec |
| F3.0.4 | Document UUID policy for `/360` routes | Backend | Allow lookup by `student_code` OR require UUID everywhere |
| F3.0.5 | Verify `viewSis` / `viewStudent360` on principal/teacher JWT | Agent D | Permission probe |

**Exit criteria:** Teacher roster id opens 360 without 404 on staging.

---

### F3.1 — SIS registry & profile (Days 2–5)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F3.1.1 | **Student search APIs** — verify `searchStudents` SQL + indexes | Backend | `sis_students_repository.ts` |
| F3.1.2 | **Student profile APIs** — enrich `GET /sis/students/{id}` optional summaries | Backend | Attendance/fees teaser OR document link to 360 |
| F3.1.3 | **Document APIs** — migration `student_documents` | Backend | `supabase/migrations/*_student_documents.sql` |
| F3.1.4 | `GET /sis/students/{id}/documents` handler | Backend | `sis_document_handlers.ts` |
| F3.1.5 | `POST /sis/students/{id}/documents` handler | Backend | Metadata + storage URI |
| F3.1.6 | Wire routes in `sis_router.ts` | Backend | List + upload |
| F3.1.7 | Flutter `sis_remote_datasource` — documents list method | Agent A | If profile needs direct fetch |
| F3.1.8 | `sis_mapper.toStudentProfile` — map server documents | Agent A | Non-empty `documents[]` |
| F3.1.9 | Fake-Dio SIS contract parity test | Agent E | Extend `sis_repository_contract_test.dart` |
| F3.1.10 | Tenant isolation probes — list + get | Agent E | School A/B |

**Exit criteria:** Registry search returns server rows; profile upload persists metadata; contract tests pass with fake Dio.

---

### F3.2 — Student 360 dossier (Days 4–8)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F3.2.1 | **Attendance summary** — verify aggregate keys match UI | Backend + A | `percent` / `present` / `absent` / `total` |
| F3.2.2 | **Marks summary** — filter published marks only | Backend | SQL guard for F2 publish alignment |
| F3.2.3 | **Homework summary** — verify completionRate calc | Backend | Unit test |
| F3.2.4 | **Behaviour APIs** — `student_conduct_incidents` migration + aggregate | Backend | `profile.behaviour` block |
| F3.2.5 | **Transport APIs** — join transport allocations | Backend | `profile.transport` block |
| F3.2.6 | **Documents in 360** — merge `student_documents` into aggregate | Backend | `profile.documents.items[]` |
| F3.2.7 | **Communication summary** — wire `communication_repository` | Backend | Replace stub `pendingNotices: 0` |
| F3.2.8 | **Communication timeline** — merge comm threads into `buildStudentTimeline` | Backend | `eventType: communication` |
| F3.2.9 | Parent view redaction audit | Agent D | Phone/fee/communication fields |
| F3.2.10 | `Phase4Mapper.student360FromApi` key normalization | Agent A | `name` ↔ `displayName` |
| F3.2.11 | Optional: extract `sis/student_360_remote_datasource.dart` | Agent A | Deprecate Phase4 paths for 360 |

**Exit criteria:** `GET /sis/students/{uuid}/360` returns non-empty behaviour, transport, documents for probe student; 9 tabs render on staging.

---

### F3.3 — Client hardening (Days 6–8)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F3.3.1 | Confirm `HybridSisRepository` has no silent mock read fallback | Agent A | Code audit |
| F3.3.2 | `student360RepositoryProvider` — document API-only behaviour | Agent A | Comment + config doc |
| F3.3.3 | `openStudent360()` — pass canonical UUID from SIS row | Agent A | Navigation fix if needed |
| F3.3.4 | Error mapping — 404 student → empty/error state | Agent A | Repository layer |
| F3.3.5 | `docs/F3_SIS_360_MIGRATION.md` | Agent F | Cutover + rollback |

**Exit criteria:** `SIS_API_ENABLED=true` QA build shows no mock dossier data.

---

### F3.4 — Certification (Days 8–10)

| ID | Task | Owner | Deliverable |
|----|------|-------|-------------|
| F3.4.1 | `f3_sis_360_api_integration_test.dart` | Agent E | Submit/search/profile/360/timeline |
| F3.4.2 | Extend `student_360_repository_contract_test.dart` — fake Dio | Agent E | API parity |
| F3.4.3 | `flutter analyze` gate | Agent G | 0 errors |
| F3.4.4 | Full test suite | Agent G | No regressions |
| F3.4.5 | Patrol `workflow_student_360_unification.yaml` | Agent E | API fixtures |
| F3.4.6 | `PHASE_F3_FINAL_CERTIFICATION.md` | Agent F | Sign-off |
| F3.4.7 | Update `ORCHESTRATOR_AGENT.md` — F3 ✅, F4 locked | Agent F | Readiness ~71% |

---

## Per-area execution checklist

Quick reference for the ten analysis domains:

| # | Domain | Primary endpoint(s) | F3 work item IDs |
|---|--------|---------------------|------------------|
| 1 | SIS repository architecture | `/sis/*` | F3.1.x, F3.3.x |
| 2 | Student 360 repository | `/360`, `/timeline` | F3.2.x, F3.3.x |
| 3 | Student profile | `GET /sis/students/{id}` | F3.1.2, F3.1.8 |
| 4 | Student search | `GET /sis/students?search=` | F3.1.1, F3.0.3 |
| 5 | Attendance summary | 360 `attendance` domain | F3.2.1 |
| 6 | Marks summary | 360 `marks` domain | F3.2.2 |
| 7 | Homework summary | 360 `homework` domain | F3.2.3 |
| 8 | Behaviour | 360 `behaviour` domain | F3.2.4 |
| 9 | Communication timeline | `/timeline` + 360 `communication` | F3.2.7, F3.2.8 |
| 10 | Documents | `/documents` + 360 `documents` | F3.1.3–F3.1.6, F3.2.6 |

---

## API contract summary (implementation target)

### SIS registry & profile

```
GET    /sis/dashboard
GET    /sis/students?page=&pageSize=&search=&status=&className=&sectionName=
POST   /sis/students
GET    /sis/students/{id}
PUT    /sis/students/{id}
PATCH  /sis/students/{id}/status
GET    /sis/students/{id}/documents          ← F3 NEW
POST   /sis/students/{id}/documents          ← F3 NEW
GET    /sis/enrollments
POST   /sis/enrollments
PUT    /sis/enrollments/{id}
POST   /sis/admissions-conversion
```

### Student 360

```
GET    /sis/students/{id}/360?viewMode=      ← enrich domains
GET    /sis/students/{id}/timeline
```

**Envelope:** `{ data: { studentId, profile: { ...domains } } }` for 360; `{ data: { studentId, items: [] } }` for timeline.

### Permissions

| Route class | Permission |
|-------------|------------|
| SIS read | `viewSis` |
| SIS write | `manageSis` |
| Student 360 read | `viewStudent360` OR `viewSis` |
| Parent scope | RLS on `student_guardians` + timeline parent policy |

---

## DTO inventory (Flutter)

### Existing — verify parity

| DTO | File |
|-----|------|
| `SisDashboardDto` | `sis/dto/sis_dashboard_dto.dart` |
| `SisStudentsResponseDto` | `sis/dto/sis_students_dto.dart` |
| `SisStudentProfileDto` | `sis/dto/sis_student_profile_dto.dart` |
| `CreateStudentRequestDto` | `sis/dto/create_student_request_dto.dart` |
| `UpdateStudentRequestDto` | `sis/dto/update_student_request_dto.dart` |
| `UploadStudentDocumentRequestDto` | `sis/dto/upload_student_document_request_dto.dart` |

### New (F3)

| DTO | Purpose |
|-----|---------|
| `StudentDocumentDto` | List item from `GET /documents` |
| `StudentDocumentsResponseDto` | `{ items: [] }` envelope |
| `Student360ProfileDto` (optional) | Typed domains vs raw `Map` — reduces mapper drift |

---

## Migration strategy (execution)

| Step | Action |
|------|--------|
| 1 | Deploy `student_documents` + `student_conduct_incidents` migrations to staging |
| 2 | Deploy Edge `api` with document routes + enriched 360 service |
| 3 | Import school roster CSV → `students` / `student_profiles` / enrollments |
| 4 | Publish ID crosswalk for QA personas (teacher class roster ↔ SIS) |
| 5 | Enable `SIS_API_ENABLED=true` on internal QA build only |
| 6 | Verify registry search, profile, 360 all tabs, timeline on staging |
| 7 | Production school build: `ENABLE_API_MODE=true` + `SIS_API_ENABLED=true` |
| 8 | Retire mock-only claims in pilot limitation sheet |

**Data migration:** No client-side migration. Users see server truth after import. Mock seeds ignored in API mode.

---

## Rollback strategy (execution)

Per analysis — execute in reverse order:

| Level | Action | Effect |
|-------|--------|--------|
| **L1 — instant** | `SIS_API_ENABLED=false` | `MockSisRepository` + `MockStudent360Repository`; UI unchanged |
| **L2 — client** | `ENABLE_API_MODE=false` | Full demo mock stack |
| **L3 — server** | Leave migrations in place | No data deletion; re-enable flag when fixed |
| **L4 — partial** | 360-only rollback N/A | Single flag controls both repos today |

**Pilot note:** Rollback restores dossier tabs with mock data — acceptable for UAT only. Document in `F3_SIS_360_MIGRATION.md`.

---

## Test strategy

### Unit / contract (CI — every PR)

```bash
flutter analyze
flutter test test/contracts/sis/
flutter test test/contracts/student_360/
flutter test test/integration/approval/   # regression — no F2 breakage
```

### F3 integration (new)

`test/integration/sis/f3_sis_360_api_integration_test.dart`:

| Scenario | Assert |
|----------|--------|
| Search students | Paginated list; `search` param forwarded |
| Get profile | Core fields + guardians |
| Upload document metadata | POST returns summary |
| Get 360 profile | All domain keys present |
| Get timeline | Ordered events; communication type present |
| 404 unknown id | `StudentNotFound` mapping |

### Server (Deno)

```bash
deno test supabase/functions/_shared/sis/
```

Extend: `student_360_service_test.ts` (new), documents handler test.

### Widget / golden

```bash
flutter test test/features/sis/
flutter test test/features/student_360/   # if present
```

### Patrol (staging)

- `qa/journeys/workflow_student_360_unification.yaml`  
- SIS registry search journey (add if missing)

### RBAC / tenant

- School A student not visible in School B list (existing probe pattern)  
- Parent JWT: 360 redaction + timeline parent policy  
- Teacher: class-scoped students only (if scope enforced)

---

## Certification gates

### Pre-implementation (this document)

- [x] F3 analysis complete  
- [x] F3 execution plan complete  
- [ ] Program Director authorizes F3 start  

### Implementation complete

| # | Gate | Command / evidence |
|---|------|-------------------|
| 1 | Static analysis | `flutter analyze` → 0 errors |
| 2 | SIS contracts | `flutter test test/contracts/sis/` |
| 3 | Student 360 contracts | `flutter test test/contracts/student_360/` |
| 4 | F3 integration | `flutter test test/integration/sis/f3_sis_360_api_integration_test.dart` |
| 5 | SIS UI regression | `flutter test test/features/sis/` |
| 6 | Server SIS tests | `deno test supabase/functions/_shared/sis/` |
| 7 | Tenant probes | Staging school A/B isolation |
| 8 | API mode flag | `SIS_API_ENABLED=true` smoke on staging |
| 9 | 360 tab walkthrough | Manual or Patrol — 9 tabs non-empty for probe student |
| 10 | Certification doc | `docs/PHASE_F3_FINAL_CERTIFICATION.md` |

### Combined gate command

```bash
flutter analyze
flutter test test/contracts/sis/ test/contracts/student_360/ \
  test/integration/sis/ test/features/sis/
deno test supabase/functions/_shared/sis/
```

---

## Parallel schedule (2-week sprint)

| Week | Track A (Backend) | Track B (Backend) | Track C (Flutter/QA) |
|------|-------------------|-------------------|----------------------|
| **W1** | F3.0 ID + documents migration/handlers | F3.2 behaviour + transport SQL | F3.0.3 filter fix; fixture crosswalk |
| **W1–2** | F3.2 communication + timeline merge | F3.2 marks/homework/attendance verify | F3.1.8 mapper; fake-Dio contracts |
| **W2** | Staging deploy + probes | 360 aggregate integration tests | F3 integration test; Patrol fixtures |
| **W2** | — | — | F3.4 certification + orchestrator update |

---

## Agent ownership

| Agent | F3 responsibilities |
|-------|---------------------|
| **A** | Flutter repos, mappers, remote datasources, navigation id fix |
| **A (Backend)** | Edge handlers, SQL aggregates, migrations |
| **D** | RBAC permissions, parent redaction, RLS review |
| **E** | Contract/integration/Patrol tests, probes |
| **F** | `F3_SIS_360_MIGRATION.md`, certification report |
| **G** | Gate enforcement, readiness recalculation (~71%) |

---

## Dependencies on other phases

| Phase | Relationship |
|-------|--------------|
| **F1 ✅** | Required — auth + permissions |
| **F2 ✅** | Soft — timeline enrichment from approvals; marks publish filter |
| **F4** | Downstream — marks freshness improves after exam API |
| **F5** | Downstream — attendance writes; F3 reads existing rows |
| **F6** | Parallel — timeline event ingestion |
| **F7** | Leave/finance orchestration unrelated to F3 reads |

**F5 is blocked on F3** for canonical `student_id` — prioritize ID alignment (F3.0).

---

## Readiness recalculation

| Metric | Pre-F3 | Post-F3 target |
|--------|--------|----------------|
| Production API overall | ~65% | **~71%** (+6%) |
| A8 SIS + Student 360 | ~40% | **~95%** |
| Pilot core (A–E) | ~69% | **~72%** |
| PB-03 (API parity) | Partial | SIS + 360 reads **connected** |

Update `docs/ORCHESTRATOR_AGENT.md` §2 readiness table on certification.

---

## Deliverables checklist

| Artifact | Path |
|----------|------|
| Analysis | `docs/F3_SIS_360_API_ANALYSIS.md` |
| Execution plan | `docs/F3_SIS_360_API_EXECUTION_PLAN.md` |
| Migration & rollback | `docs/F3_SIS_360_MIGRATION.md` (at implementation) |
| Certification | `docs/PHASE_F3_FINAL_CERTIFICATION.md` (at implementation) |
| Migration SQL | `supabase/migrations/*_student_documents.sql`, `*_student_conduct_incidents.sql` |
| Edge handlers | `sis_document_handlers.ts`, updates to `student_360_service.ts`, `sis_router.ts` |
| Flutter tests | `f3_sis_360_api_integration_test.dart`, extended contract tests |
| Orchestrator | Version bump — F3 certified, F4 locked |

---

## Stop conditions

Stop F3 implementation and escalate if:

1. Tenant isolation probe fails on student list or 360.  
2. Parent JWT exposes fee/phone fields intended redacted.  
3. UUID/id crosswalk cannot be resolved without breaking teacher roster.  
4. `flutter test` regression count increases without justification.

Do **not** proceed to **F4** until F3 certification report is approved.

---

*Analysis: [`docs/F3_SIS_360_API_ANALYSIS.md`](./F3_SIS_360_API_ANALYSIS.md) · Authority: [`docs/ORCHESTRATOR_AGENT.md`](./ORCHESTRATOR_AGENT.md)*
