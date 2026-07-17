# Web-Discovered ERP Tasks — Closure Report

**Date:** 2026-07-17 · **ERP lane tip:** `416f878b` · **Prod migration head:** `20260897`
(all Web-gap work was CODE-ONLY — no schema change) · **Backend deno:** 3488/0/3 ·
**Prod:** health 200, 0 edge errors.

This closes the register `docs/roadmap/WEB_DISCOVERED_ERP_TASKS.md` (ERP-WT-001..010 /
WEB-001..010) surfaced by the Unified Web Platform track. Each buildable item was
implemented against the ERP backend, deno-tested, deployed to prod, and **live-certified**
with real-Postgres probes as the `erp_tenant` role (the method that catches what the
fake-DB suite cannot: JOINs, GROUP BY, grants, RLS, DB constraints).

## Per-item reconciliation

| Item | Endpoint(s) | Status | Commit | Live-cert evidence |
|------|-------------|--------|--------|--------------------|
| **WEB-001** | `GET /dashboard/overview` | ✅ **LIVE CERTIFIED** | `190482e9` | new `dashboard` router composing certified SIS snapshot + finance daily summary + MTD-collections + canonical school-wide attendance-today. Probes 3–4 + isolation in `live_cert_web_batch2_readapis.sql` (11/11). |
| **WEB-002** | icon-font subset | ✅ Complete (web-side) | web track | 4.5 MB→408 KB; not an ERP-backend change. |
| **WEB-003** | live GPS tracking API | ⏸ **DEFERRED — external/owner-gated** | — | GPS is Phase-2 per scope (owner-idea 14 = owner-gated); needs device/hardware integration + real-time infra. NOT autonomously buildable. |
| **WEB-004** | `GET /inventory/stock`, `GET /inventory/stock/approvals` | ✅ **LIVE CERTIFIED** | `190482e9` | new repo fns over `inventory_stock_valuations` / `stock_adjustments`; `viewInventory`. Probes 1–2 + isolation (11/11). |
| **WEB-005** | `POST /sis/promotion`, `/sis/reshuffle`, `/sis/section-balance`, `GET /sis/academic-assignment` | ✅ **LIVE CERTIFIED** | `416f878b` | transactional executor over the certified `createEnrollment`/`updateEnrollment` with per-student SAVEPOINT isolation. `live_cert_web005_sis_workflows.sql` (8/8): promote + idempotency UNIQUE + reshuffle + roster + RLS-WITH-CHECK write isolation. |
| **WEB-006** | `GET /intelligence/ai-economics`, `GET /intelligence/trust` | ✅ **LIVE CERTIFIED** | `190482e9` | second-mount of the certified `getAiEconomics`; `computeAiTrust` governance lens (pure, +2 unit tests). Probe 5 + isolation (11/11). |
| **WEB-007** | `GET /finance/student-accounts` | ✅ **LIVE CERTIFIED** | `2e0228fa` | paginated list join; `live_cert_web007_student_accounts_list.sql` (7/7): projection + COUNT + pagination + free-text filter + RLS both directions. |
| **WEB-008** | fix `GET /academics/exams/progress` 500 | ✅ Complete (prior) | `d818342b` | GROUP BY fix, verified on prod. |
| **WEB-009** | fix `GET /school/pilot/dashboard` 500 | ✅ Complete (prior) | `ff1c917f` | SAVEPOINT-resilient degrade, deployed. |
| **WEB-010** | `GET /communications/analytics/{summary,parent-adoption}` | ✅ **LIVE CERTIFIED** | `190482e9` | alias to the EXISTING (contract-tested, Flutter-wired) `school_completion` analytics handlers — no duplicate aggregation. Probes 6–7 (11/11). |
| **WEB-011** | edge CORS for the web origin | ✅ **ALREADY RESOLVED** | pre-existing | `corsHeaders` applied to every response via `withCors` + `OPTIONS` preflight (`api/app.ts:90,253,271`). Live probe 2026-07-17: OPTIONS + GET both return `Access-Control-Allow-Origin: *` + `Authorization`/`x-tenant-id`/`x-school-id`/`x-api-version` in allowed headers. `*` is correct for a Bearer-token API (no cookies). No work needed. |

## Discipline invariants held

- **No duplicate implementations.** WEB-006 re-mounts a certified service; WEB-010 aliases
  certified handlers; WEB-001/004/005 compose certified primitives. New SQL was added only
  where no equivalent existed (stock levels+reorder, MTD collections, school-wide
  attendance-today, the bulk executors).
- **Reuse / minimal / backward-compatible.** All 6 were code-only — zero migrations, zero
  schema change, no existing behaviour altered.
- **Gated + inventoried.** Every new route enforces auth + an existing permission slug and
  was added to `RBAC_ROUTE_INVENTORY` (12 rules) → covered by the RBAC matrix + forced-auth
  tests.
- **Evidence-based certification.** Each endpoint: 401-gate proof through the edge (reachable,
  not 404) + real-Postgres `erp_tenant` probes proving the query/mutation, RLS isolation, and
  (WEB-005) the idempotency constraint. Cert scripts in `scripts/qa/live_cert_web*.sql`.

## Verdict

**10 of 11 Web-discovered items are IMPLEMENTED / LIVE-CERTIFIED / ALREADY-RESOLVED**
(WEB-001/002/004/005/006/007/008/009/010/011). **1 (WEB-003 GPS) is proven genuinely
external/owner-gated** (Phase-2 hardware). No buildable Web-discovered item remains open.
This clears the register for the final Autonomous Engineering Freeze.

(The register grew to WEB-011 after this session began — the web lane appended a CORS gap;
verified already-resolved on prod. Both registers `WEB_DISCOVERED_ERP_TASKS.md` +
`WEB_TRACK_BACKEND_GAPS.md` are synced 🟢/⏸.)
