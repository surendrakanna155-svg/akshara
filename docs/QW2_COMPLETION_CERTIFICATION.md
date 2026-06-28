# QW2 — Module Write/Persistence E2E · COMPLETION CERTIFICATION

**Date:** 2026-06-28 · **Branch:** `feature/data-reliability-platform`
**Gate:** Engineering Operating System (`/eos`) per [`engineering/ENGINEERING_GATE_POLICY.md`](engineering/ENGINEERING_GATE_POLICY.md).
**Companion:** [`FINAL_QA_MASTER_TRACKER.md`](FINAL_QA_MASTER_TRACKER.md) · [`FINAL_QA_ROADMAP.md`](FINAL_QA_ROADMAP.md) · [`engineering/eos/EOS_RUN_LEDGER.md`](engineering/eos/EOS_RUN_LEDGER.md).

---

## Verdict

> **EOS gate: PASS** for all locally-verifiable QW2 work. The wave is **CONDITIONAL at the
> program level** pending 4 genuinely feature/infrastructure-blocked rows. **No locally-fixable
> P1 remains open.**

**QW2 row status (32-row wave): 28 Verified · 4 Open (blocked/deferred, each with an explicit reason).**

---

## Approach

QW2's theme is *per-module write/persistence under the correct persona*. Almost every row's
write **persistence** was already proven by an existing e2e suite running as **superAdmin**; the
QW2 gap was proving the **scoped persona — not a god-login** — is authorized for that write (and
denied the others). The closeout proves this deterministically against the **same gates the real
mutations use**: `MutationPermissionRegistry`, `RolePermissionMatrix`, the route guard
`canAccessErpRoute`/`isRouteEnabledForCapabilities`, and `EntitlementResolver`. Persistence is
cited per row from the existing suite; the UI-under-persona run is the Patrol follow-up.

8 deterministic test files, **32/32 green**, `flutter analyze` clean:

| Batch | Rows | Test file |
|---|---|---|
| HR employee (opener) | J-020 | `test/features/hr/qw2_hr_employee_persona_authz_test.dart` |
| Staff functional | J-022/026/027/028/029/030 | `test/features/security/qw2_staff_functional_write_authz_test.dart` |
| HR import + finance→parent | J-021/025 | `test/features/security/qw2_hr_import_finance_parent_authz_test.dart` |
| Teacher | J-015/016/017 | `test/features/teacher/qw2_teacher_write_authz_test.dart` |
| School Admin / SIS | J-040/041/042/043/044 | `test/features/sis/qw2_schooladmin_write_authz_test.dart` |
| Principal | J-033/034/035/036 | `test/features/management/qw2_principal_write_authz_test.dart` |
| Platform/Director/Entitlement | J-049/053/054/068/069 | `test/features/platform/qw2_platform_director_entitlement_authz_test.dart` |
| Education + attendance loop | J-064/066 | `test/features/education/qw2_education_attendance_loop_authz_test.dart` |

### Notable proofs
- **Verb anti-escalation** — storekeeper holds `createProcurementOrder` but NOT
  `approveProcurementHandoff` (J-029); admissions counselor manages leads but cannot
  `approveApplication` (J-030); teacher submits an attendance correction but cannot resolve it,
  and cannot self-validate exam results (J-066/064); teacher cannot self-approve their own leave
  (J-017).
- **Longest-prefix RBAC** — principal reaches `/finance` (holds `viewFinance`) but is denied
  `/finance/intelligence` (resolves to the stronger `viewFinanceIntelligence` it lacks) — no
  parent-permission escalation (J-036), via the real `canAccessErpRoute`.
- **Capability + entitlement gating** — a Discovery-disabled module is route-denied regardless of
  permission (J-068); a Trial plan's `planCeiling` gates plan-locked modules off while a granting
  plan lifts the ceiling (J-069/J-054) — via the real `SchoolCapabilityRegistry` + `EntitlementResolver`.

---

## Remaining QW2 rows — genuinely blocked (NOT locally fixable)

| Row | Why blocked | Lane |
|---|---|---|
| **QA-J-004** | In-app results view already covered (patrol_batch2b); the remaining leg — a PUSH notification firing on publish + deep-link — needs FCM on a device | device/FCM CI lane (with QA-X-010/012) |
| **QA-J-063** | AI-assistant persona scope (no cross-tenant/other-child leakage) is enforced by the copilot BACKEND against JWT claims — not assertable headlessly | live-server / RLS lane (with QA-B-051/052/057) |
| **QA-J-005** | Parent–Teacher Meetings is `SchoolBuildScope`-hidden — the PTM backend has not shipped (mock-only, CORE-1/PAR-4) | re-wave when the PTM backend ships |
| **QA-J-010** | `ErpRole.student` has 0 permissions by design; no student-initiated message/leave write surface is wired to a backend yet | build item — student self-service comms backend |

---

## Bottom line

Every QW2 row whose write path exists and is provable on local hardware is **Verified** (28/32).
The only open rows need FCM-on-device, a live multi-tenant backend, or a feature that has not yet
shipped. **QW2's locally-verifiable scope is COMPLETE.**
