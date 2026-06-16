# Akshara ERP — Red Team Operational Remediation Plan (P0 Only)

Scope constraint: **Only** address Red Team findings that are in the **P0 critical backlog** until they are **verified fixed, tested, and documented**.  
Hard exclusions (per request):
* Do NOT start Academic Assessment Platform work
* Do NOT start Question Paper Generation work
* Do NOT start Theme Modernization
* Do NOT start UX modernization

Source of truth:
* [`docs/RED_TEAM_OPERATIONAL_AUDIT.md`](./RED_TEAM_OPERATIONAL_AUDIT.md)
* [`docs/RED_TEAM_DEFECT_CLASSIFICATION.md`](./RED_TEAM_DEFECT_CLASSIFICATION.md)

---

## 0) Current Status Snapshot

### False positives
* **#5 Parent insights/experience unguarded** → classified as **C (False positive)** because the *parent ERP role* already has the required permissions in `RolePermissionMatrix`, and ParentShell access is already restricted to `UserRole.parent`.

### Fixes completed so far (code already applied)
* **#1 Student identity consistency (partial)**  
  * Added canonical student registry + exam results sync store for mock path.
  * Updated teacher attendance/marks to align with canonical student mapping while preserving contract test IDs.
  * Updated student/parent exam views to overlay published marks from a shared sync store.
  * Aligned transport + hostel records to canonical primary student identity (`SIS-STU-10430`, Ravi Kumar).
* **#2 Finance handoff → SIS (partial, mock)**  
  * Added `MockAdmissionsSisBridge.completeFinanceHandoff()` and wired `completeFinanceHandoffAssignment` to re-queue SIS conversion in mock stores.
* **#3 API write failures (partial)**  
  * Added/wired hybrid wrappers for HR, transport, hostel, library, inventory, and director repository providers.
* **#4 RBAC bypass risk (partial)**  
  * Expanded `RouteNames.adminErpRoutes` to include many school/evolution prefixes.
* **#7 Academic ops SIS alignment** → fixed to reuse shared SIS provider (classified D)
* **#16 Principal transport/hostel access** → fixed via principal role permissions (classified D)

### Tests added
* Updated and passing:
  * `test/contracts/mobile/teacher_write_contract_test.dart`
  * `test/features/transport/transport_screens_test.dart`
  * `test/features/hostel/hostel_screens_test.dart`
  * `test/features/sis/sis_providers_test.dart`
  * `test/core/repositories/repository_test.dart`
* Full `flutter test` run passed after these updates.

### Patrol coverage added
* **None yet** (P0 remediation requires new patrol/route/journey coverage once tests pass).

---

## 1) P0 Critical Backlog (must reach “verified fixed + tested + documented”)

P0 findings: **#1, #2, #3, #4, #6, #8, #9, #10**

For each defect below, acceptance criteria are written to reflect “tomorrow’s go-live operations,” not just UI render.

---

## 2) Remediation Tasks (by defect)

### P0-1 — Student identity consistency across SIS/Teacher/Parent/Student/Transport/Hostel/Exams
**Current state:** B (transport/hostel canonical alignment completed; admissions-conversion lifecycle verification still pending).

**Fix approach**
1. Choose and freeze the canonical mock identity:
   * `MockCanonicalStudentRegistry.primaryMobileStudent` (SIS-STU-* for the canonical student).
2. Update `MockTransportRepository` and `MockHostelRepository` records to reference the **same canonical `sisStudentId`** and studentName.
3. Verify exam mark publication and result overlays use the canonical SIS id consistently.

**Acceptance criteria**
* After teacher marks update, the following must show the **same student name and SIS id** and the **same marks**:
  * Teacher exam marks view
  * Student exams results
  * Parent exams results
  * Transport allocation/roster (if surfaced)
  * Hostel roster/records (if surfaced)

**Tests to add**
* Unit test: when teacher updates mark for a canonical mark entry, sync store publishes with canonical SIS id, and student/parent exam view overlays reflect it.
* Unit test: transport and hostel mocks contain at least one record for the canonical SIS id.

**Patrol to add**
* Journey patrol: teacher enters marks → parent/student verify results (same student).
* Journey patrol: transport/hostel manager open rosters and confirm canonical SIS id exists.

**Owner:** (current agent) mock-layer & repository wiring.

---

### P0-2 — Finance handoff persistence to SIS conversion
**Current state:** B (mock re-queue implemented; requires verification via SIS conversion flow and persistence semantics).

**Fix approach**
1. Add/adjust bridge selection logic to find the correct enrollment item by:
   * `preview.admissionNumber` and/or `previewStudentId` and/or `handoffId` when present.
2. Ensure SIS conversion queue updates when finance completes.

**Acceptance criteria**
* Finance handoff completion produces a SIS conversion queue entry visible on SIS dashboard.

**Tests to add**
* Unit test: `MockAdmissionsSisBridge.completeFinanceHandoff()` updates conversion queue when an enrollment exists.

**Patrol to add**
* Journey patrol: Admissions approval → Finance fee assignment → SIS conversion queue shows the student/enrollment.

---

### P0-3 — API write failures (ApiNotConnectedException) when API mode enabled
**Current state:** A (fix pattern started; provider wiring incomplete; still breaks operations).

**Fix approach**
1. Implement hybrid write-fallback wrappers for:
   * HostelRepository
   * LibraryRepository
   * InventoryRepository
   * DirectorRepository
2. Wire those wrappers into `repository_providers.dart` when the corresponding `*_ApiEnabledProvider` is true.
3. Ensure fallback occurs for *write methods* so UI mutations don’t hard-fail.

**Acceptance criteria**
* When API mode is enabled but backend is disconnected:
  * HR leave request/employee lifecycle
  * Transport route creation/assignment
  * Hostel admit/room allocation/checkout
  * Library issue/return
  * Inventory create/approve/receive
  * Director compliance acknowledge/export
  should **not** throw `ApiNotConnectedException` during writes (mocks are used as fallback).

**Tests to add**
* Unit tests per repository wrapper: verify write method falls back on `ApiNotConnectedException`.

**Patrol to add**
* Patrol suite running representative mutations in API mode and asserting no write failure.

---

### P0-4 — RBAC bypass risk on `/school/*` / evolution routes
**Current state:** B (guard coverage expanded; needs regression tests).

**Fix approach**
1. Add regression tests that:
   * `canAccessErpRoute()` does **not** return true for school/evolution routes that require permissions.
2. Validate `RouteNames.adminErpRoutes` includes the full set of prefixes used by these routes.

**Acceptance criteria**
* FinanceAdmin (and other non-privileged roles) cannot access principal command/growth/setup/evolution routes via URL directly.

**Tests to add**
* Add test cases to `test/router/route_guards_test.dart` for representative school/evolution route prefixes.

**Patrol to add**
* Patrol: attempt direct deep-links as blocked role → verify Access Denied.

---

### P0-6 — Vice Principal role existence
**Current state:** A (role missing).

**Fix approach**
1. Add `ErpRole.vicePrincipal` to `core/security/erp_role.dart`.
2. Add `RolePermissionMatrix` entry for vicePrincipal (likely same as principal initially).
3. Update staff role demo list (`ErpRole.staffErpRoles`) and staff home route mapping (`homeRouteForStaffErp`).

**Acceptance criteria**
* Staff demo sessions can select VP role and access the VP dashboard/workflows without permission crashes.

**Tests to add**
* Unit test: RolePermissionMatrix for vicePrincipal contains expected permission set (at least viewTransport/viewHostel if intended).

**Patrol to add**
* Patrol: VP performs one daily flow (principal overview + attendance/approvals).

---

### P0-8 — Alumni graduation automation
**Current state:** A (no alumni onboarding integration with SIS exit).

**Fix approach (mock-first, consistent with current repository contracts)**
1. Make mock alumni registry mutable (remove const static list).
2. When `MockSisRepository.updateStudentStatus()` transitions a student to `SisStudentStatus.alumni`, upsert a corresponding alumni record in `MockAlumniRepository`.

**Acceptance criteria**
* Updating a SIS student status to alumni results in the alumni record appearing in the alumni registry/dashboard.

**Tests to add**
* Unit test: SIS `updateStudentStatus(... alumni ...)` triggers alumni registry update for that `sisStudentId`.

**Patrol to add**
* Patrol: SIS mark exit/alumni → Alumni module shows new graduate.

---

### P0-9 — Teacher marks flow to student/parent results
**Current state:** B (sync store overlay works for canonical student; subject scores/report card aggregates may still be incomplete).

**Fix approach**
1. Ensure publication uses canonical SIS id consistently.
2. Extend overlay to any other result fields that are expected by parent/student screens (subject scores, average percent).

**Acceptance criteria**
* Teacher marks entry updates all parent/student exam result rows for the canonical student.

**Tests to add**
* Unit test: marks update modifies both `examResults` and `averagePercent` for student/parent views.

**Patrol to add**
* Journey patrol: teacher enters marks → parent and student verify results.

---

### P0-10 — Transport tracking placeholder
**Current state:** A (map UI explicitly communicates “No live maps in MVP”).

**Fix approach**
* Minimal operational improvement: replace misleading placeholder copy with “telemetry feed unavailable” and ensure the screen shows the non-map telemetry state prominently (vehicle telemetry list already exists).
* Do NOT implement map provider integration in this phase; just remove the operationally misleading “map placeholder” expectation.

**Acceptance criteria**
* Transport tracking screen no longer promises live maps; it clearly reflects MVP telemetry availability and provides actionable telemetry rows.

**Tests to add**
* Widget test: verify the placeholder copy is updated and vehicle telemetry rows render.

**Patrol to add**
* Patrol: open transport tracking and verify meaningful content appears without placeholder confusion.

---

## 3) “Verification Gate” (how we decide P0 is done)

For each P0 defect, we will mark complete only after:
1. Code fix is in place
2. Tests pass (`flutter analyze` + affected `flutter test`)
3. A patrol/journey covers the operational scenario
4. `docs/RED_TEAM_REMEDIATION_REPORT.md` is updated with:
   * Verified vs false positives
   * What was fixed
   * Tests added
   * Patrol coverage added
   * Any remaining risks

---

## 4) Next execution step

Start with:
1. **P0-2:** add focused unit test for finance handoff → SIS conversion queue persistence.
2. **P0-4:** add regression tests for school/evolution route guard coverage.
3. **P0-6 / P0-8 / P0-10:** implement vice-principal role, alumni automation trigger, and transport tracking operational messaging cleanup.

