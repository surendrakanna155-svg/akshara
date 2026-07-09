# Track B — Live RLS Cross-Tenant Isolation Probes (B5/B7 unblocked)

**Date:** 2026-07-09 · **HEAD:** `d8482029` · **Scope:** the 12 P0/P1 rows in
[`FINAL_QA_MASTER_TRACKER.md`](../../FINAL_QA_MASTER_TRACKER.md) blocked on
"needs `ERP_TENANT_DATABASE_URL` + live RLS" — QA-B-051/052/057/044/058/053/054/
055/056/040/041/032. **Governing law:** Constitution Part 4B (RLS) + Part 7B.
Corresponds to roadmap **Phase B, tasks B5 (tenant Postgres reachable) and B7
(tenant isolation validation)** in `docs/FINAL_QA_ROADMAP.md`.

**Verdict: PASS. Zero cross-tenant leaks found across all 12 target rows.**
233/233 pre-existing enforced probes pass live; 1 newly authored probe
(approval_requests, 6 assertions) passes live. **No P0 security finding.**

---

## 1. How the DB was reached

- Connected via the owner's existing SSH ControlMaster socket only:
  `ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 '<cmd>'`. No new SSH auth, keys,
  or config were created or changed.
- Confirmed Akshara-only containers touched: `akshara-postgres`, `akshara-edge`,
  `akshara-storage`, `akshara-rest-gateway`, `akshara-postgrest`. `velora-salon`,
  `n8n` (`root-n8n-1`), and redis crons were never queried, read, or referenced.
- **DB used: `akshara_tenant_test`** — the dedicated, pre-provisioned tenant-test
  clone of `akshara_db` (already existed on the VPS; schema parity confirmed:
  184/184 tables both DBs, checked via one read-only
  `information_schema.tables` count on each DB). **All probes, all seeded rows,
  and every rollback ran exclusively against `akshara_tenant_test`. `akshara_db`
  (the real prod tenant) was touched by exactly one read-only schema-metadata
  query (the table-count parity check above) — no business/tenant data was ever
  read from it, and zero writes of any kind were made to it, at any point in
  this task.**
- Mechanism: the already-authored, battle-tested harness
  `scripts/qa/run_tenant_isolation_enforced.sh` — it runs `deno test` **inside**
  the `akshara-edge` container (which already has Deno + network access to
  `akshara-postgres`), with `ERP_TENANT_DATABASE_URL` swapped from
  `.../akshara_db` to `.../akshara_tenant_test` **only for that one `docker exec`
  invocation**. The edge function's own running env (which points at
  `akshara_db` for real production traffic) was never modified. The connection
  string / password were read from `/opt/akshara/.env.akshara` on the VPS and
  **never printed to this transcript or persisted locally** — exactly per the
  script's own "secret-free" design note.
- The `akshara-edge` container filesystem is **read-only** (confirmed:
  `sh: can't create ... Read-only file system`), so the one newly authored probe
  (§3 below) could not be `docker cp`'d in. It was instead piped over stdin
  (`docker exec -i ... deno run --allow-all -`) directly into the container's
  Deno runtime — no file was ever written to the container, the VPS host, or
  `akshara_db`.
- Verified the deployed `tenant_isolation_probes.ts` on the VPS is **byte-identical**
  to this worktree's copy (`sha256: 0ee04643a52805f...` matches both sides) —
  the live run exercised exactly the code in this repo at `HEAD`.

## 2. Non-destructiveness guarantee

- The pre-existing 233-probe suite (`tenant_isolation_probes.ts`) is **100% read
  paths** — grepped for `INSERT/UPDATE/DELETE/TRUNCATE/DROP`: zero matches, all
  233 tasks are `SELECT count(*)` / `SELECT` reads. `withTenantContext` wraps
  each in `BEGIN…COMMIT`, but a committed read-only transaction changes no data.
- The one newly authored probe (QA-B-040, approval) DOES insert two synthetic
  rows to exercise write-time RLS `WITH CHECK`, but does so inside a single
  transaction that is **unconditionally rolled back in a `finally` block, even on
  assertion failure**. Verified post-run: `SELECT count(*) FROM approval_requests
  WHERE id IN (probe ids)` → **0**, and the table's total row count is unchanged
  at **20** (matches the pre-run baseline). Nothing was persisted.
- No DDL, no schema change, no seeding of `akshara_db`, no destructive statement
  of any kind was executed anywhere in this task.

## 3. Per-row verdict

| Row | Module | Mechanism | Verdict | Key evidence (live) |
|---|---|---|:--:|---|
| QA-B-051 | hr | pre-existing probe (`tenant_isolation_probes.ts` + `hr_read_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_hr_employee` → `visible_cross_school_employee=0`; `organization_denied_hr_employees_api` → `0`; `parent_denied_hr_employees_api` → `0`; `school_a_sees_own_hr_employee` → `1` |
| QA-B-052 | hostel | pre-existing probe (`hostel_read_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_hostel_student` → `0`; `organization_denied_hostel_students_api` → `0`; `parent_denied_hostel_students_api` → `0`; `school_a_sees_own_hostel_student` → `1` |
| QA-B-057 | finance | pre-existing probes (fee structures/assignments/accounts/invoices/collections/receipts/refunds) | **PASS — isolated** | 34 finance probes, all pass, e.g. `school_a_cannot_see_school_b_finance_invoices` → `0`, `school_a_cannot_see_school_b_collections` → `0`, `school_a_cannot_see_school_b_refunds` → `0`, `organization_denied_*` / `parent_denied_*` / `student_denied_*` on every money table → `0`; `approved_refund_updates_balances` invariant holds (`43970.00 == 43970.00`, `≤ 50000.00`) |
| QA-B-044 | parent_experience | pre-existing probe (`parent_read_repository.ts`, per-child) | **PASS — isolated** | `parent_sees_linked_child` → `1`; `parent_cannot_see_unlinked_student` → `0`; `parent_a_cannot_see_school_b_parent_probe` → `0`; `parent_a_sees_own_parent_probe` → `1` |
| QA-B-058 | control_center | pre-existing probe (`control_center_read_repository.ts`, org-vs-school) | **PASS — isolated** | `school_scope_denied_control_center_schools` → `0` (school-scope denied org/platform view); `org_sees_control_center_platform_school` → `1` (org-scope correctly sees platform aggregate); `school_scope_denied_control_center_school_detail` → `0` |
| QA-B-053 | library | pre-existing probe (`library_read_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_library_book` → `0`; `organization_denied_library_catalog_api` → `0`; `parent_denied_library_catalog_api` → `0`; `school_a_sees_own_library_book` → `1` |
| QA-B-054 | alumni | pre-existing probe (`alumni_read_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_alumni_record` → `0`; `organization_denied_alumni_registry_api` → `0`; `parent_denied_alumni_registry_api` → `0`; `school_a_sees_own_alumni_record` → `1` |
| QA-B-055 | inventory | pre-existing probe (`inventory_read_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_inventory_asset` → `0`; `organization_denied_inventory_assets_api` → `0`; `parent_denied_inventory_assets_api` → `0`; `school_a_sees_own_inventory_asset` → `1` |
| QA-B-056 | transport | pre-existing probe (`transport_read_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_transport_route` → `0`; `organization_denied_transport_routes_api` → `0`; `parent_denied_transport_routes_api` → `0`; `school_a_sees_own_transport_route` → `1` |
| QA-B-040 | approval | **NEWLY AUTHORED** rolled-back-txn probe (`approval_isolation_probe_test.ts`, real `approval_requests` table — not in the pre-existing suite) | **PASS — isolated** | School B cannot see school A's row (`0`) and vice versa (`0`); each school sees its own (`1`); org-scope denied both (`0`, `0`) — 6/6 assertions pass; ROLLBACK confirmed, 0 rows persisted |
| QA-B-041 | copilot | pre-existing probe (`copilot_repository.ts`) | **PASS — isolated** | `school_a_cannot_see_school_b_ai_copilot_session` → `0`; `school_a_sees_own_ai_copilot_session_probe` → `1` |
| QA-B-032 | student | pre-existing probe (`student_read_repository.ts` + core `students` table) | **PASS — isolated** | `student_sees_self_only` → `1`; `school_a_cannot_see_school_b_students` → `0`; `student_a_cannot_see_school_b_student_probe` → `0`; `school_scope_denied_student_probe` → `0`; `student_a_sees_own_student_probe` → `1` |

**No cross-tenant LEAK found in any of the 12 rows, or in any of the other ~200
probes covering teacher, management, admissions, SIS, academics, communication,
onboarding, entitlements, education, and audit tables.**

## 4. Run detail — pre-existing 233-probe suite (B5/B7)

Command (via `scripts/qa/run_tenant_isolation_enforced.sh`'s exact mechanism,
target DB overridden to `akshara_tenant_test`):

```
ssh -S ~/.ssh/akshara-cm.sock root@46.28.44.46 \
  "URL=\$(grep -E '^ERP_TENANT_DATABASE_URL=' /opt/akshara/.env.akshara | cut -d= -f2- \
     | sed 's#/akshara_db#/akshara_tenant_test#'); \
   docker exec -e ERP_TENANT_DATABASE_URL=\"\$URL\" akshara-edge \
     deno test --allow-all --no-lock /app/_shared/tenant_isolation_enforced_test.ts"
```

Result (2026-07-09T07:3x UTC):

```
Check _shared/tenant_isolation_enforced_test.ts
running 1 test from ./_shared/tenant_isolation_enforced_test.ts
enforced tenant isolation passes via erp_tenant direct connection ... ok (869ms)

ok | 1 passed | 0 failed (891ms)
```

A supplementary **read-only reporting run** (imports the identical, already-deployed
`runEnforcedIsolationProbes` from `tenant_isolation_probes.ts` — no probe logic
duplicated — and prints per-probe detail instead of only asserting the aggregate)
confirmed the full breakdown:

```
ENFORCED=true ROLE=erp_tenant OVERALL_PASS=true COUNT=233
... (233 lines, 233 PASS, 0 FAIL) ...
```

- `ENFORCED=true` — the connection could not silently no-op; RLS was actively
  enforced.
- `ROLE=erp_tenant` — confirms the non-bypass role was used (never `service_role`),
  per `assertEdgeTenantRole` (`tenant_db.ts`).
- **233 PASS / 0 FAIL.**

This collapses `docs/FINAL_QA_ROADMAP.md` Phase B tasks **B5** ("tenant DB
reachable; RLS active") and **B7** ("233 probes PASS live") from
STAGED/INFRA-BLOCKED to **live-Verified** — consistent with the prior
`EOS_PHASE_B_TENANT_ACCESS_HEALTH_FINDING.md` resolution (2026-07-01,
`20ae776`, also 233/233), reproduced independently today against the dedicated
test tenant.

## 5. Run detail — newly authored probe (QA-B-040, approval)

`approval_requests` has no probe in the pre-existing suite. Authored
`supabase/functions/_shared/approval/approval_isolation_probe_test.ts`
(committed) — a self-contained, rolled-back-transaction probe using the same
standing dedicated fixture schools (`SCHOOL_A`/`SCHOOL_B`/`ORG`/`STAFF_A`) every
other probe in the suite uses. It:

1. Seeds one synthetic `approval_requests` row for `SCHOOL_A` (under school A's
   own RLS context) and one for `SCHOOL_B` (under school B's own RLS context),
   switching `app.set_request_context` mid-transaction (its `set_config(...,
   true)` is transaction-local, confirmed via `pg_get_functiondef`).
2. Asserts school B cannot read school A's row and vice versa, each school sees
   its own row, and organization-scope (which has no dedicated grant on this
   table — confirmed via `\d approval_requests`, exactly one policy,
   `scope='school'` only) sees neither.
3. **Unconditionally ROLLBACKs** in a `finally`, whether assertions pass or fail.

Run (piped via stdin into the read-only `akshara-edge` container filesystem —
no file was written anywhere; same `ERP_TENANT_DATABASE_URL` → `akshara_tenant_test`
override as §4):

```
PASS: school B sees its own approval_requests row
PASS: school B must NOT see school A's approval_requests row
PASS: school A sees its own approval_requests row
PASS: school A must NOT see school B's approval_requests row
PASS: organization scope must NOT read school A's approval_requests row
PASS: organization scope must NOT read school B's approval_requests row
ROLLBACK issued — zero persisted writes.
ALL PROBES PASSED (QA-B-040 approval_requests cross-school RLS isolation)
```

Post-run verification (read-only): `SELECT count(*) FROM approval_requests
WHERE id IN (<probe ids>)` → `0`; total table row count → `20` (unchanged from
pre-run baseline). This closes the QA-B-040 INFRA remainder ("per-row
approve/reject 403 ... needs `ERP_TENANT_DATABASE_URL` + live RLS") for the RLS
half of that row — RLS on `approval_requests` denies cross-school reads/writes
at the database layer, independent of and beneath the already-Verified
application-level SoD check (`qw4_approval_route_contract_test.ts`).

## 6. Scope note — what this does NOT close

This run validates the **RLS cross-tenant isolation** half of Phase B (B5/B7).
It does **not** touch, and makes no claim about, the other Phase B tasks
(B1–B4, B6, B8–B13) — live deploy, edge/migration parity beyond what was
read-only-verified here, staff Face ID, multi-school concurrency, backup/restore,
monitoring, performance, pilot simulation, or the 7-day regression cron. Those
remain tracked separately in `docs/FINAL_QA_ROADMAP.md`.

## 7. Confirmation

- Non-Akshara services (`velora-salon`, `n8n`, redis crons) were never touched,
  read, or queried.
- No new SSH keys/auth/config were created; only the existing ControlMaster
  socket was used.
- No DDL, no destructive statement, no write survived any transaction. Every
  probe, seed, and rollback ran against `akshara_tenant_test`; `akshara_db` (the
  real prod tenant) was touched only by one read-only schema-metadata count
  query (§1) — no tenant/business data read, no write of any kind.
- No curriculum data was touched or imported.
- **No cross-tenant LEAK found.** All 12 target rows: isolation holds.
