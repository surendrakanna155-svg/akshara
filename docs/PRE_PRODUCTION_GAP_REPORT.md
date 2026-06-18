# Pre-Production Gap Report

**Date:** 2026-06-18  
**Branch:** `feature/m15-theme`  
**Audit type:** Read-only — pre-production workflow & API gap analysis  
**Sources:** `docs/API_PARITY_AUDIT.md`, `docs/FINAL_PILOT_CLOSURE_REPORT.md`, `docs/PILOT_READINESS_AUDIT.md`, `docs/EXPORT_PARITY_AUDIT.md`, `docs/ORCHESTRATOR_AGENT.md`  
**Constraint:** No code changes · no roadmap edits · no new features

---

## Executive summary

| Dimension | Status |
|-----------|--------|
| **Mock / UAT pilot** | **GO** — P0 closed, governance complete, 1949 unit tests, Patrol pilot closure 9/9 |
| **First real school (production backend)** | **NO-GO** until Class **A** gaps closed |
| **Operational readiness** | **~72%** (mock); **~45%** (production API path) |
| **API-complete workflows (pilot scope)** | **0 of 8** |
| **Default runtime mode** | `ENABLE_API_MODE=false` → mock repositories |

**Core finding:** The app is **functionally credible on mock data** with **local device persistence for exams only**. Every pilot-critical write path either has **no API layer**, a **full API stub**, or **hybrid mock write fallback**. Governance side effects (approvals, concessions, leave decisions) live in **in-memory stores** that do not survive reinstall or sync across devices.

---

## Implementation state legend

| State | Meaning |
|-------|---------|
| **Mock-only** | No API repository; mock is the only provider |
| **Local persistence** | SharedPreferences or on-device queue; not server-authoritative |
| **In-memory** | Singleton store; lost on process kill / reinstall |
| **Hybrid** | API reads (or partial writes); `withMockWriteFallback` on failures |
| **API stub** | `Api*Repository` throws `ApiNotConnectedException` on all methods |
| **API partial** | Some methods wired to remote; others stubbed or fallback |
| **API complete** | Remote datasource for pilot workflow steps; contract-tested |

---

## Class A — Required before first real school

*A school using a live backend, real student records, multi-user staff, and data that must survive device changes.*

### A1. Authentication & tenant session

| Field | Detail |
|-------|--------|
| **Workflow** | Login → JWT → permission sync → tenant context → logout |
| **Current state** | `MockAuthRepository` (demo); `ApiAuthRepository` exists for API mode |
| **Backend/API** | **API partial** — auth remote wired; QA builds use demo auth |
| **Production risk** | **Critical** — wrong role/tenant without production auth path |
| **Effort** | **M** (1–2 wks) — harden interceptors, permission sync, revoke |
| **Pilot impact** | None in mock pilot; blocks real school |
| **Class** | **A** |

### A2. Unified principal approval center

| Field | Detail |
|-------|--------|
| **Workflow** | Cross-module approve/reject (exam, leave×2, attendance, finance×3, inventory PO) |
| **Current state** | **Mock-only** in demo (`MockApprovalRepository`); adapters + `ApprovalCenterService` complete |
| **Backend/API** | **API stub** — `api_approval_repository.dart` throws on all methods |
| **Production risk** | **Critical** — principal decisions not persisted server-side |
| **Effort** | **XL** (4–6 wks) — unlocks 6 downstream approval workflows |
| **Pilot impact** | Mock pilot OK; production blocker for all governance |
| **Class** | **A** |

### A3. Exam administration lifecycle

| Field | Detail |
|-------|--------|
| **Workflow** | Create → schedule → marks → process → coordinator verify → principal approve → publish |
| **Current state** | **Mock-only** + **local persistence** (`ExamAdministrationPersistence` / SharedPreferences) |
| **Backend/API** | **API stub** — `api_exam_administration_repository.dart` |
| **Production risk** | **Critical** — exam data device-local; no cross-teacher/principal sync |
| **Effort** | **XL** (4–6 wks) — remote CRUD + publish + approval hooks |
| **Pilot impact** | Mock pilot OK with restart-safe device data |
| **Class** | **A** |

### A4. Teacher class attendance (mark & submit)

| Field | Detail |
|-------|--------|
| **Workflow** | Teacher marks class → submit → lock → parent KPI overlay |
| **Current state** | **In-memory** — `MockAttendanceSyncStore`; teacher repo delegates to sync store |
| **Backend/API** | **No API layer** for class attendance submit |
| **Production risk** | **High** — attendance lost on reinstall; no official school record |
| **Effort** | **L** (2–4 wks) — attendance write API + idempotent submit |
| **Pilot impact** | Patrol-validated on mock; not production-safe |
| **Class** | **A** |

### A5. Attendance correction (teacher / parent → principal)

| Field | Detail |
|-------|--------|
| **Workflow** | Submit correction → approval center → principal resolve → sync bridge |
| **Current state** | **Mock-only** — `attendanceCorrectionRepositoryProvider` always returns mock; `AttendanceCorrectionStore` in-memory |
| **Backend/API** | **Missing** — no `api_attendance_correction_repository.dart` |
| **Production risk** | **High** — corrections not durable or auditable server-side |
| **Effort** | **L** (2–3 wks) — new API repo + adapter parity |
| **Pilot impact** | UX complete on mock; production blocker |
| **Class** | **A** |

### A6. Student leave (parent submit → principal approve)

| Field | Detail |
|-------|--------|
| **Workflow** | Parent apply → principal approval center → status timeline |
| **Current state** | **Hybrid** — parent submit can use `ApiParentRepository`; approval via mock; `StudentLeaveGovernanceStore` **in-memory** |
| **Backend/API** | Parent: **API partial** · Approval: **API stub** |
| **Production risk** | **High** — approved leave may not persist if governance store-only |
| **Effort** | **L** (2–3 wks) — depends on A2; parent write contract exists |
| **Pilot impact** | Mock pilot OK |
| **Class** | **A** |

### A7. Finance — refunds & concessions (principal path)

| Field | Detail |
|-------|--------|
| **Workflow** | Create refund/concession → governance submit → principal approve → apply |
| **Current state** | Refunds: **API complete** when `FINANCE_API_ENABLED`; concessions use `FinanceApprovalGovernanceStore` (**in-memory**) + adapters |
| **Backend/API** | Refunds: **API complete** · Concessions/structures: **API partial** + governance in-memory |
| **Production risk** | **High** — concession activation may not match finance ledger without server workflow |
| **Effort** | **L** (2–4 wks) — server-side approval state; ties to A2 |
| **Pilot impact** | Refund redirect UX complete; ledger truth needs backend |
| **Class** | **A** |

### A8. SIS & Student 360 (authoritative student record)

| Field | Detail |
|-------|--------|
| **Workflow** | Registry read → profile → Student 360 dossier (9 tabs) |
| **Current state** | **Hybrid** SIS reads; Student 360: API when `SIS_API_ENABLED`, else mock |
| **Backend/API** | **API partial** — `ApiStudent360Repository` + `GET /sis/students/:id/360`; mock fallback in demo |
| **Production risk** | **Critical** — wrong/missing identity if mock used in production |
| **Effort** | **M** (1–2 wks) — enforce API mode + contract parity on all dossier domains |
| **Pilot impact** | Navigation/export complete; data truth needs API |
| **Class** | **A** |

### A9. Audit log upload (compliance)

| Field | Detail |
|-------|--------|
| **Workflow** | Client audit events → queue → batch upload → retention |
| **Current state** | **Local persistence** — `AuditUploadQueue` (SharedPreferences); uploader injectable |
| **Backend/API** | **Partial** — queue durable; production uploader endpoint must be verified |
| **Production risk** | **High** — compliance gap if upload not wired to real backend |
| **Effort** | **M** (1 wk) — wire uploader + integration test |
| **Pilot impact** | Local audit register export works (finance) |
| **Class** | **A** |

### A10. RBAC & permissions (production sync)

| Field | Detail |
|-------|--------|
| **Workflow** | Role → permissions → route guards → mutation registry |
| **Current state** | Client-side `UserPermissions.forRole` + sync on login (demo) |
| **Backend/API** | Permission sync depends on auth API; mutation registry client-complete |
| **Production risk** | **Critical** — stale or client-only permissions in production |
| **Effort** | **M** (1–2 wks) — server permission payload + refresh contract |
| **Pilot impact** | RBAC tested; production needs server source of truth |
| **Class** | **A** |

---

## Class B — Can wait until after first school pilot

*Acceptable for an initial mock/UAT or single-campus pilot with documented limitations and manual workarounds.*

### B1. Staff leave (HR create → principal approve)

| Field | Detail |
|-------|--------|
| **Current state** | **Hybrid** — `HybridHrRepository`; `createLeaveRequest` stubbed, approve/reject API wired; `StaffLeaveGovernanceStore` in-memory |
| **Backend/API** | **API partial** |
| **Production risk** | Medium — HR create falls back to mock silently |
| **Effort** | **M** |
| **Pilot impact** | Redirect to Approval Center complete |
| **Class** | **B** |

### B2. Inventory PO (maker-checker)

| Field | Detail |
|-------|--------|
| **Current state** | **Hybrid** — reads API; writes `withMockWriteFallback`; `InventoryPoGovernanceStore` in-memory |
| **Backend/API** | **API partial** |
| **Production risk** | Medium — only if school runs store/uniform shop |
| **Effort** | **L** |
| **Pilot impact** | RBAC + governance complete on mock |
| **Class** | **B** ( **A** if store in scope ) |

### B3. Fee collection & receipt PDF (ERP)

| Field | Detail |
|-------|--------|
| **Current state** | Finance **API complete** for collections; parent receipt PDF real; ERP collection detail lacks export UI; P1-FIN-008 placeholder names |
| **Backend/API** | **API complete** (reads/writes); PDF enrichment client-side |
| **Production risk** | Medium — operational friction, not data loss |
| **Effort** | **S–M** |
| **Pilot impact** | Collections work in mock/API |
| **Class** | **B** |

### B4. Admissions & enrollment

| Field | Detail |
|-------|--------|
| **Current state** | **Hybrid/API** when enabled; mock seeds for demo |
| **Backend/API** | **API partial** |
| **Production risk** | Medium — if school uses ERP admissions on day one |
| **Effort** | **L** |
| **Pilot impact** | Not in pilot closure Patrol suite |
| **Class** | **B** |

### B5. Education content (question papers, homework, remarks)

| Field | Detail |
|-------|--------|
| **Current state** | **Hybrid** `HybridEducationRepository`; PDF export real for QP/homework/remarks |
| **Backend/API** | **API partial** |
| **Production risk** | Low–medium |
| **Effort** | **M** |
| **Pilot impact** | Academics adjunct to exam chain |
| **Class** | **B** |

### B6. Teacher / parent / student mobile personas

| Field | Detail |
|-------|--------|
| **Current state** | **Mock-only** repos in demo; selective API repos exist (parent, teacher, student) |
| **Backend/API** | **API partial** per persona |
| **Production risk** | Medium — mobile is primary for parents/teachers |
| **Effort** | **L** (per persona) |
| **Pilot impact** | Patrol-validated core journeys |
| **Class** | **B** |

### B7. Cross-module exports (attendance register, enriched finance PDF)

| Field | Detail |
|-------|--------|
| **Current state** | Finance + management dashboard real; attendance register **missing**; finance email **preview stub** |
| **Backend/API** | N/A (client export) |
| **Production risk** | Low — reporting convenience |
| **Effort** | **S–M** |
| **Pilot impact** | Documented in `EXPORT_PARITY_AUDIT.md` |
| **Class** | **B** |

### B8. Full Patrol ERP regression (`ERP_COVERAGE_MODE=full`)

| Field | Detail |
|-------|--------|
| **Current state** | Pilot closure **9/9**; full ~60+ suite not gate-certified |
| **Production risk** | Medium — regression escape |
| **Effort** | **S** (infra time, not dev) |
| **Pilot impact** | Pilot gate met |
| **Class** | **B** |

### B9. Governance notification delivery

| Field | Detail |
|-------|--------|
| **Current state** | `ApprovalNotificationService` client-side; M-D7 certified on mock |
| **Backend/API** | Push/email not production-wired |
| **Production risk** | Medium — approvers may miss queue items |
| **Effort** | **M** |
| **Pilot impact** | In-app approval center sufficient for mock |
| **Class** | **B** |

### B10. P1 backlog (18 not-started items)

| Field | Detail |
|-------|--------|
| **Examples** | Exam subject CRUD, attendance history, discount rules UI, payment gateway, homework upload |
| **Production risk** | Low–medium — operational polish |
| **Effort** | **L** aggregate |
| **Pilot impact** | Does not block mock pilot |
| **Class** | **B** |

---

## Class C — Future enhancement

*Out of day-school pilot scope per `PILOT_READINESS_AUDIT.md` deployment matrix.*

| Workflow / module | Current state | Notes |
|-------------------|---------------|-------|
| **Marketing / acquisition** | Module absent | P0-MKT-001 |
| **Transport GPS & bus attendance** | Mock placeholder | P0-TRN-001/002 |
| **Inventory catalog & stock ledger** | Not started | P0-INV-001/002 |
| **Hostel operations** | Hybrid mock fallback | P1-HST-* |
| **Library operations** | Hybrid mock fallback | P1-LIB-* |
| **HR payroll disbursement** | Mock / preview exports | P1-HR-004 |
| **Payment gateway (parent)** | Not started | P1-PAR-003 |
| **Dynamic role → workspace engine** | Architecture target only | `ORCHESTRATOR_AGENT.md` |
| **Multi-school SaaS operations** | Mock-heavy | M9+ scope |
| **Industry vertical packs** | Mock/API mix | M13 scope |
| **Copilot production inference** | Stub / pipeline mock | Not pilot-critical |

---

## Consolidated workflow matrix (pilot scope)

| # | Workflow | Implementation | Backend/API | Risk | Effort | Class |
|---|----------|----------------|---------------|------|--------|-------|
| 1 | Auth & session | Demo mock / API available | Partial | Critical | M | **A** |
| 2 | Unified approval center | Mock + adapters | **Stub** | Critical | XL | **A** |
| 3 | Exam admin → publish | Mock + **local persistence** | **Stub** | Critical | XL | **A** |
| 4 | Class attendance submit | **In-memory** sync store | Missing | High | L | **A** |
| 5 | Attendance correction | **Mock-only** | Missing | High | L | **A** |
| 6 | Student leave | Hybrid + **in-memory** governance | Partial | High | L | **A** |
| 7 | Finance refund approval | API + governance store | Partial | High | L | **A** |
| 8 | Finance concession / fee structure | API + **in-memory** governance | Partial | High | L | **A** |
| 9 | Student 360 / SIS | Hybrid / API | Partial | Critical | M | **A** |
| 10 | Audit upload | **Local queue** | Partial | High | M | **A** |
| 11 | RBAC permission sync | Client-complete | Partial | Critical | M | **A** |
| 12 | Staff leave (HR) | Hybrid | Partial | Medium | M | **B** |
| 13 | Inventory PO | Hybrid + governance | Partial | Medium* | L | **B** |
| 14 | Fee collection / receipts | API + PDF gaps | Partial | Medium | S–M | **B** |
| 15 | Admissions | Hybrid | Partial | Medium | L | **B** |
| 16 | Mobile personas (T/P/S) | Mock demo | Partial | Medium | L | **B** |
| 17 | Attendance / finance exports | Partial real | N/A | Low | S–M | **B** |
| 18 | Transport / marketing / hostel / lib | Mock / placeholder | Stub/missing | Low† | XL | **C** |

\* Medium unless school runs store — then **A**.  
† Low for day-school without those modules.

---

## Governance stores — production durability gap

These hold post-approval side effects in **mock mode only** (in-memory, not server-authoritative):

| Store | Path | Survives restart? |
|-------|------|-------------------|
| `FinanceApprovalGovernanceStore` | `lib/core/finance/finance_approval_governance_store.dart` | **No** |
| `StudentLeaveGovernanceStore` | `lib/core/leave/student_leave_governance_store.dart` | **No** |
| `StaffLeaveGovernanceStore` | `lib/core/leave/staff_leave_governance_store.dart` | **No** |
| `InventoryPoGovernanceStore` | `lib/core/inventory/inventory_po_governance_store.dart` | **No** |
| `AttendanceCorrectionStore` | `lib/core/attendance/attendance_correction_store.dart` | **No** |
| `MockAttendanceSyncStore` | `lib/core/repositories/mock/mock_attendance_sync_store.dart` | **No** |
| `ExamAdministrationStore` | `lib/core/exams/exam_administration_store.dart` | **Yes** (SharedPreferences) |

**Production implication:** Only exams have device-local durability. All other approved state must move to **server-authoritative** records when API mode is enabled.

---

## API mode readiness score

| Layer | Mock pilot | Production API |
|-------|------------|----------------|
| UI / workflows | **~85%** | **~85%** |
| Governance adapters | **100%** | **100%** (client) |
| Repository API parity | N/A | **~35%** |
| Data durability | **~15%** (exams only) | Requires Class A |
| **Blended production readiness** | **~72%** | **~45%** |

---

## Production-readiness recommendation

### 1. Controlled mock / UAT pilot — **GO**

Proceed with a **demo or training school** where:

- `ENABLE_API_MODE=false` and demo auth are explicit
- Users accept device-local exam data and in-memory governance
- Limitations are documented (this report + `FINAL_PILOT_CLOSURE_REPORT.md`)
- Patrol pilot closure (9/9) stands as the journey gate

### 2. First real school (live backend, real students) — **NO-GO**

Do **not** onboard a production school until **Class A** items **A2, A3, A4, A5, A8, A10** are complete at minimum, plus **A1** and **A9** for security/compliance.

**Critical path (recommended order):**

```
A1 Auth hardening
  → A10 RBAC server sync
  → A2 Approval API (unblocks A3, A5, A6, A7)
  → A8 SIS / Student 360 API enforcement
  → A3 Exam API (replace SharedPreferences authority)
  → A4 + A5 Attendance write + correction API
  → A9 Audit upload
```

Estimated calendar: **10–14 weeks** with Agent A backend focus (parallel UI unchanged).

### 3. Production pilot candidate — **CONDITIONAL GO**

Grant **production pilot candidate** status only when:

| Criterion | Status |
|-----------|--------|
| Class A workflows API-complete | ❌ Not met |
| `ENABLE_API_MODE=true` gate tests green | ❌ Not run |
| Contract tests mock ↔ API for Class A | ❌ Partial |
| Patrol pilot closure | ✅ 9/9 |
| Unit/integration gates | ✅ 1949 pass |

**Re-certify** with `docs/FINAL_PILOT_CLOSURE_REPORT.md` + this document after Class A closure.

---

## References

| Document | Purpose |
|----------|---------|
| `docs/API_PARITY_AUDIT.md` | Pilot-scope API matrix |
| `docs/EXPORT_PARITY_AUDIT.md` | Export surface gaps |
| `docs/FINAL_PILOT_CLOSURE_REPORT.md` | Certification gate results |
| `docs/PILOT_READINESS_AUDIT.md` | P0/P1 and readiness % |
| `docs/ORCHESTRATOR_AGENT.md` | Execution authority & phase status |
| `lib/core/repositories/repository_providers.dart` | Runtime mock/API switching |
| `lib/core/repositories/repository_config.dart` | Per-module API flags |

---

**Audit completed.** No code or roadmap changes made.
