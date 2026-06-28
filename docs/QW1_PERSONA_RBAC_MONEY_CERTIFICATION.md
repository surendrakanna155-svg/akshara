# QW1 — QA Personas, RBAC-Isolation Journeys & Money Loop Certification

**Date:** 2026-06-28 · **Wave:** QW1 · **Branch:** `feature/data-reliability-platform`
**Scope:** the 4 missing RBAC personas + their isolation journeys, the staff→teacher cross-shell gate, and the parent money loop.
**Rows:** `QA-J-019`, `QA-J-024`, `QA-J-037`, `QA-J-047`, `QA-J-058` (personas/isolation), `QA-J-061` (cross-shell), `QA-J-001`, `QA-J-060` (money loop).
**EOS gate:** **PASS** (0 open P0 / 0 open P1; one P1 found-and-fixed in-flight, below). See [EOS_RUN_LEDGER](engineering/eos/EOS_RUN_LEDGER.md).

> Decision (owner, 2026-06-28): build **QA-harness personas only** — scoped QA-login identities, **no change to the production `ErpRole` model** (stays within completion-mode).

---

## What landed

| Area | Change | File(s) |
|------|--------|---------|
| Personas | Added `QaLoginPersona.hr / schoolAdmin / director / staff` (librarian). School Admin + Staff reuse existing narrow `ErpRole`s; HR + Director carry **curated permission subsets** (`customPermissions`) since they have no dedicated role. | `lib/features/auth/qa_login_persona.dart` |
| Session wiring | `signInQaPersona` → `signInStaff(permissions:)` → `AuthClaims.demoForRole(permissions:)` threads the curated subset into the session claims. | `lib/features/auth/auth_provider.dart` |
| **Fix (P1)** | `userPermissionsProvider` (QA-login branch) now honors an explicit curated permission subset when present, instead of always using the full role-matrix union. Without this, HR/Director inherited their staff-shell base role's broad permissions (e.g. HR reached `/finance`). **QA-login-only — production resolution path untouched.** | `lib/core/security/rbac_service.dart` |
| Test-harness | `loginAsQaPersona` scrolls the persona button into view (the list grew past one screen). | `patrol_test/helpers/patrol_app.dart` |
| Unit scoping | New deterministic test proving each persona resolves to correctly scoped permissions via the same `UserPermissions.fromClaims` path the guards use. | `test/features/auth/qa_persona_permissions_test.dart` |
| RBAC journeys | HR/School-Admin/Director/Librarian reach their own module and are denied others + Control-Center; librarian redirected away from the teacher shell. | `patrol_test/workflows/qw1_persona_rbac_isolation_e2e_test.dart` |
| Money loop | Parent completes a fee payment end-to-end; the returned receipt id loads its detail screen (persistence proof). | `patrol_test/workflows/qw1_parent_money_loop_e2e_test.dart` |

## Evidence (local, this branch, on emulator `Medium_Phone_API_36.0`)

- **Patrol (consolidated): 5 / 5 green** — `qw1-rbac` HR, School Admin, Director, Librarian + `qw1-money` parent payment.
- **Unit: persona scoping 5 / 5 green**; security + auth + navigation suites **88 / 88 green** (no regression from the lib changes).
- `flutter analyze --fatal-infos` clean on every changed file.

## P1 found and fixed in-flight (evidence-driven)

The first RBAC-journey run **failed correctly**: HR (base role `management`) landed on `/finance/dashboard`. Root cause: `userPermissionsProvider` resolved QA-login permissions purely from the role matrix (`forRoles(erpRoles)`), ignoring the curated `claims.permissions`. This would have made the new isolation personas test almost nothing (they'd inherit a broad role). Fixed by honoring the explicit subset in the QA-login branch only; re-run went 4/4 then 5/5. The production (server-synced) resolution path is unchanged.

## Not in this batch (tracked, still Open)

- `QA-J-048` — Director **ChainScope** (franchise/multi-school/org-builder routes; needs `isChainOrganization` threading).
- `QA-J-052` — full Control-Center negative matrix (superAdmin allowed + schoolAdmin/director/**finance** denied) — schoolAdmin + director denial proven here; finance leg outstanding.

## Operator notes

- Curated subsets live in `QaLoginPersona.customPermissions`; they take effect **only** in QA-login builds (`ENABLE_QA_LOGIN=true`).
- Patrol test names must avoid `()`/`/`/`,` — they break the Android parametrized-test orchestrator (the first journey run discovered 0 tests until names were simplified).
- The floating AI dock overlays bottom-right CTAs; disable it per-test with `copilotDockVisibleProvider.overrideWithValue(false)` (see the money-loop test).
