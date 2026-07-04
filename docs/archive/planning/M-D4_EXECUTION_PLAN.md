# M-D4 Execution Plan — Leave & Attendance Approval Adapters

**Milestone:** M-D4 — Leave & Attendance Approval Adapters  
**Program:** Phase D — Governance Foundation  
**Branch baseline:** `feature/m15-theme` @ `44ba25b`  
**Date:** 2026-06-17  
**Status:** Planning only — **no implementation authorized**  
**Analysis reference:** [`M-D4_ANALYSIS.md`](./M-D4_ANALYSIS.md)

**Hard stops:** Do not start Phase A, Phase B implementation, M-D5, Marketing, Inventory, Student360, or multi-agent execution in this milestone batch.

---

## 1. Objective

Wire **student leave**, **staff leave**, and **attendance correction** into the unified Principal Approval Center with adapter-based approve/reject side effects, dedicated RBAC, and automated certification — mirroring the M-D3 exam results pattern.

**Success statement:** A parent-submitted leave appears in the Principal inbox; principal approve updates parent-visible leave status. HR-created staff leave uses the same inbox. Attendance correction adapter is registered with mock side effects ready for Phase B UI.

---

## 2. Gaps closed

| Gap ID | Description | M-D4 coverage |
|--------|-------------|---------------|
| APR-003 | Attendance correction approval chain | Adapter + permissions (UI Phase B) |
| APR-004 | Student leave approver UI | Adapter + parent status wire |
| APR-005 | Staff leave in unified inbox | Adapter + HR wire |
| P1-PRIN-002 | Student leave principal queue | Full chain |
| P1-PRIN-003 | Same-day attendance exception queue | Stub (`attendanceException` seed) |
| P0-ATT-002 | Attendance permissions | Partial — enum + registry |
| P0-ATT-001 | Correction workflow | Partial — governance only |
| WF-005 | Parent dispute not ticketed | Phase B — adapter ready |

---

## 3. Milestones

### M-D4.0 — Preconditions (Day 0)

| # | Task | Owner | Gate |
|---|------|-------|------|
| 0.1 | Confirm M-D3 pushed @ `44ba25b` | Release | `M-D3_PUSH_REPORT.md` |
| 0.2 | Review analysis sign-off | Program Director | This doc approved |
| 0.3 | Freeze adapter payload schemas (§4) | Governance | No code until approved |

### M-D4.1 — RBAC & permissions (Day 1)

| # | Task | Type | Files |
|---|------|------|-------|
| 1.1 | Add permission enum values | NET_NEW | `permissions.dart` |
| 1.2 | Role grants (principal, teacher, parent, HR) | NET_NEW | `role_permissions.dart` |
| 1.3 | Approval type → permission map | WIRE | `approval_permissions.dart` |
| 1.4 | Mutation registry entries | WIRE | `mutation_permission_registry.dart` |
| 1.5 | Server RBAC inventory slugs | WIRE | `server_rbac_route_inventory.dart` |
| 1.6 | Update permission coverage test | WIRE | `permission_coverage_test.dart` |

**Permissions to add:**

- `markAttendance`, `viewAttendance`
- `submitAttendanceCorrection`, `approveAttendanceCorrection`, `correctAttendance`
- `submitStudentLeave`, `approveStudentLeave`
- `submitStaffLeave`, `approveStaffLeave`

### M-D4.2 — Student leave adapter (Days 1–2)

| # | Task | Type | Files |
|---|------|------|-------|
| 2.1 | `StudentLeaveApprovalAdapter` | NET_NEW | `lib/core/approvals/adapters/student_leave_approval_adapter.dart` |
| 2.2 | Wire `SubmitParentLeaveNotifier` | WIRE | `parent_mutations_provider.dart` |
| 2.3 | Leave status from approval state | WIRE | `parent_leave_provider.dart`, mock parent repo |
| 2.4 | Detail enrichment | WIRE | adapter + `approval_detail_panel.dart` |
| 2.5 | Provider invalidation on approve | WIRE | `approval_center_provider.dart` |
| 2.6 | Unit + integration tests | NET_NEW | `test/core/approvals/adapters/`, `test/integration/approval/leave_approval_integration_test.dart` |

**Acceptance:**

- [ ] Parent submit creates `studentLeave` pending item (dedup safe)
- [ ] Principal approve → `LeaveStatus.approved` in parent history
- [ ] Principal reject → rejected + comment visible

### M-D4.3 — Staff leave adapter (Days 2–3)

| # | Task | Type | Files |
|---|------|------|-------|
| 3.1 | `StaffLeaveApprovalAdapter` | NET_NEW | `staff_leave_approval_adapter.dart` |
| 3.2 | Wire `CreateHrLeaveNotifier` | WIRE | `hr_mutations_provider.dart` |
| 3.3 | HR screen inbox link / deprecate inline approve | WIRE | `hr_leave_screen.dart` |
| 3.4 | Sync approve side effect to `HrLeaveRequest` | WIRE | mock HR repo / store |
| 3.5 | Tests | NET_NEW | `staff_leave_approval_adapter_test.dart`, integration |

**Acceptance:**

- [ ] HR create leave → pending `staffLeave` in Principal inbox
- [ ] Principal approve updates HR leave list status
- [ ] Existing HR approve path documented as legacy / disabled for new items

### M-D4.4 — Attendance correction adapter (Days 3–4)

| # | Task | Type | Files |
|---|------|------|-------|
| 4.1 | `AttendanceCorrectionApprovalAdapter` | NET_NEW | `attendance_correction_approval_adapter.dart` |
| 4.2 | Mock store side effects | NET_NEW | Extend `MockAttendanceSyncStore` or new `AttendanceCorrectionStore` (minimal) |
| 4.3 | Register in `ApprovalAdapterRegistry` | WIRE | registry |
| 4.4 | Optional: `attendanceException` enum + seed | NET_NEW | `approval_request_type.dart`, demo seed |
| 4.5 | Submit helper (no UI — test-only entry) | NET_NEW | adapter public API for tests |
| 4.6 | Tests | NET_NEW | unit + `attendance_correction_approval_integration_test.dart` |

**Acceptance:**

- [ ] Approve `attendanceCorrection` demo item applies mock calendar/KPI change
- [ ] Reject stores comment without mutating attendance
- [ ] Adapter registered; Phase B can call `submitForApproval` without registry changes

**Explicitly deferred to Phase B:**

- Parent dispute form (replace WhatsApp)
- Teacher correction UI
- Post-submit lock
- ERP attendance admin

### M-D4.5 — Certification & docs (Day 5)

| # | Task | Deliverable |
|---|------|-------------|
| 5.1 | `flutter analyze` = 0 errors | CI gate |
| 5.2 | Full `flutter test` green | CI gate |
| 5.3 | M-D2/M-D3 regression gate | 64+ tests |
| 5.4 | `PHASE_D_M4_FINAL_CERTIFICATION.md` | Certification |
| 5.5 | Patrol stubs | `workflow_parent_leave_approval.yaml`, `workflow_hr_leave_approval.yaml` |
| 5.6 | Commit + push + push report | `M-D4_PUSH_REPORT.md` |

---

## 4. Adapter payload schemas (contract)

### Student leave

```json
{
  "childId": "child_ravi",
  "childName": "Ravi Kumar",
  "classLabel": "8-A",
  "fromDate": "2026-06-20",
  "toDate": "2026-06-22",
  "leaveType": "medical",
  "reason": "Fever",
  "hasAttachment": false
}
```

Entity: `entityType: student_leave`, `entityId: <leave.id>`

### Staff leave

```json
{
  "employeeId": "staff_045",
  "employeeName": "Neha Singh",
  "department": "Academics",
  "leaveType": "casual",
  "fromDate": "2026-06-18",
  "toDate": "2026-06-19"
}
```

Entity: `entityType: staff_leave`, `entityId: <leave.id>`

### Attendance correction

```json
{
  "classId": "class-6b",
  "classLabel": "6-B",
  "date": "2026-06-12",
  "studentId": "stu_042",
  "fromMark": "absent",
  "toMark": "present",
  "reason": "Bus delay",
  "requesterRole": "parent"
}
```

Entity: `entityType: attendance_day`, `entityId: att_<class>_<yyyy>_<mm>_<dd>` or per-student variant

---

## 5. Dependencies

| Upstream | Required for | Status |
|----------|--------------|--------|
| M-D1 ApprovalCenterService | All adapters | ✅ |
| M-D2 Principal UI | Approver surface | ✅ |
| M-D3 adapter pattern | Implementation template | ✅ |
| Mock parent/HR leave repos | Side effects | ✅ Built |
| Phase B AttendanceCorrectionStore | Full correction UX | ❌ Future |
| Backend approval API | Production | ❌ Future |

**Downstream consumers:**

| Consumer | Needs from M-D4 |
|----------|-----------------|
| Phase B attendance | Adapter `submitForApproval` contract |
| M-D5 finance | Independent — can parallel after M-D4 cert |
| P1-PAR-002 parent leave status | M-D4.2 |

---

## 6. Rollout strategy

### Phase 1 — Mock-only MVP (M-D4 scope)

1. Ship adapters + RBAC in mock repository mode.
2. Principal uses existing Approval Center — no new routes.
3. Parent/HR see updated statuses after decision.
4. Attendance correction testable via integration tests only.

### Phase 2 — Phase B handoff (post-M-D4)

1. Phase B adds parent/teacher correction UI calling adapter.
2. Introduce `AttendanceCorrectionStore` without changing adapter interface.
3. Enable `ATTENDANCE_CORRECTION_REQUIRES_APPROVAL=true` in builds.

### Phase 3 — API mode (future)

1. Server creates approval records on submit endpoints.
2. Client adapters become thin — or server owns side effects.
3. Contract tests against OpenAPI.

---

## 7. Rollback strategy

| Level | Action | Effect |
|-------|--------|--------|
| L1 | `LEAVE_AUTO_APPROVE=true` dart-define | Parent/HR submit auto-approves leave (skip queue) |
| L2 | Adapter registry no-op | Approve updates approval record only (M-D2 behavior) |
| L3 | Revert M-D4 commit(s) | Remove adapter files + notifier hooks |
| L4 | HR inline approve restored | Emergency fallback for staff leave |

No database migrations in mock mode. Store resets on app restart.

---

## 8. Certification gates

### Gate A — RBAC

```bash
flutter test test/security/rbac/permission_coverage_test.dart
```

- All new mutations registered
- Approve permissions mapped per type

### Gate B — Adapter unit

```bash
flutter test test/core/approvals/adapters/
```

- ≥3 new adapter test files (leave ×2, attendance ×1)
- M-D3 exam adapter tests still pass

### Gate C — Integration

```bash
flutter test test/integration/approval/
```

- Leave approval chain
- Staff leave chain
- Attendance correction chain (mock)

### Gate D — Regression

```bash
flutter test test/features/management/approval/ \
  test/contracts/approval/ test/core/approvals/
```

- M-D2 gate ≥64 tests green
- No permission mapping regression to `manageManagement` for wired types

### Gate E — Full suite

```bash
flutter analyze   # 0 errors
flutter test      # all pass
```

### Gate F — Documentation

- [ ] `PHASE_D_M4_FINAL_CERTIFICATION.md`
- [ ] `M-D4_PUSH_REPORT.md`
- [ ] Gap tracker APR-003/004/005 marked partial/closed per scope

---

## 9. File plan (implementation estimate)

### New files

```
lib/core/approvals/adapters/
  student_leave_approval_adapter.dart
  staff_leave_approval_adapter.dart
  attendance_correction_approval_adapter.dart
lib/core/config/leave_approval_config.dart          (optional LEAVE_AUTO_APPROVE)
test/core/approvals/adapters/
  student_leave_approval_adapter_test.dart
  staff_leave_approval_adapter_test.dart
  attendance_correction_approval_adapter_test.dart
test/integration/approval/
  leave_approval_integration_test.dart
  staff_leave_approval_integration_test.dart
  attendance_correction_approval_integration_test.dart
qa/journeys/
  workflow_parent_leave_approval.yaml
  workflow_hr_leave_approval.yaml
docs/
  PHASE_D_M4_FINAL_CERTIFICATION.md
  M-D4_PUSH_REPORT.md
```

### Modify

```
lib/core/approvals/approval_adapter_registry.dart
lib/core/approvals/approval_permissions.dart
lib/core/approvals/approval_request_type.dart       (optional attendanceException)
lib/core/security/permissions.dart
lib/core/security/role_permissions.dart
lib/core/security/mutation_permission_registry.dart
lib/features/parent/parent_mutations_provider.dart
lib/features/parent/leave/parent_leave_provider.dart
lib/features/hr/hr_mutations_provider.dart
lib/features/hr/leave/hr_leave_screen.dart
lib/features/management/approval/approval_center_provider.dart
lib/core/repositories/mock/mock_parent_repository.dart
lib/core/repositories/mock/mock_hr_repository.dart  (if exists)
lib/core/repositories/mock/mock_attendance_sync_store.dart
test/features/management/approval/approval_center_provider_test.dart
test/features/parent/leave/parent_leave_provider_test.dart
```

---

## 10. Timeline (single-agent estimate)

| Week | Deliverable |
|------|-------------|
| Week 1 Day 1 | M-D4.1 RBAC |
| Week 1 Day 2–3 | M-D4.2 Student leave |
| Week 1 Day 4 | M-D4.3 Staff leave |
| Week 2 Day 1–2 | M-D4.4 Attendance adapter stub |
| Week 2 Day 3 | M-D4.5 Certification + push |

**Total:** ~5–7 engineering days (aligns with analysis §9)

---

## 11. Out of scope (explicit)

| Item | Milestone |
|------|-----------|
| Phase A exam admin | M-A* |
| Phase B attendance correction UI + lock | Phase B |
| M-D5 finance adapters | M-D5 |
| Student360 navigation | Phase C |
| Marketing / Inventory modules | Separate programs |
| Multi-agent parallel execution | Post-governance |
| Full Patrol emulator validation | Post-cert stub only |
| Backend API implementation | Backend team |

---

## 12. Approval to proceed

| Role | Decision | Date |
|------|----------|------|
| Program Director | ☐ Approved / ☐ Revise | |
| Governance Agent | Analysis complete | 2026-06-17 |
| Release Manager | M-D3 push verified @ `44ba25b` | 2026-06-17 |

---

**Plan status:** Complete — awaiting implementation authorization  
**Next step after approval:** M-D4.1 RBAC (no parallel Phase A/B work)
