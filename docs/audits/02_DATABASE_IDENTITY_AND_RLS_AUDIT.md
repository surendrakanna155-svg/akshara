# Akshara ERP — Database, Identity & RLS Audit

**Auditor:** Fable (independent) · **Date:** 2026-07-03 · **HEAD:** `68f15cb`
**Scope:** 168 migrations, RLS/tenant isolation, the frozen Identity Platform, money/audit data integrity.
**Confidence:** High (from migration source-of-truth); live-DB drift = Unknown.

---

## 1. Executive summary

1. **Tenant model = shared-DB + Postgres RLS** (tenant boundary = `organizations.id`), scoped by transaction-local GUCs set by `app.set_request_context()`. Coherent and real.
2. **RLS is genuinely ENFORCED — the runtime role cannot bypass it.** The app connects as `erp_tenant`, created `NOSUPERUSER NOBYPASSRLS` (`20260610100000_tenant_access_foundation.sql:11-19`), across **485 `withTenantContext` call sites in 124 files**. **185/185 RLS-enabled tables have ≥1 policy; 189 FORCE statements; 0 business tables lack RLS.** Only 2 `USING(true)` policies exist (intentional global catalogs); 0 `WITH CHECK(true)`; 0 INSERT-without-WITH-CHECK. This is disciplined, well-red-teamed work.
3. **The single highest-leverage control is a deploy-time invariant:** edge functions **must** connect via the `erp_tenant` DSN, never the Supabase `service_role` key (which is `BYPASSRLS`). The entire isolation + immutability model collapses if a handler ever uses service-role for tenant data. **Verify at deploy.**
4. **CRITICAL: the runtime tenant DB password is hardcoded in a committed migration** — `PASSWORD 'akshara_erp_tenant_staging_v1'` (`20260610100000…:13`). The credential for the RLS-enforcing role is in git.
5. **The frozen Identity Platform is half-shipped in the DB and half-contradicted by reality.** Public Student ID + admission-number set-once immutability triggers **did ship**. But the platform's flagship principle — "a phone-number change never changes identity" — is **directly contradicted**: `users.phone` is `NOT NULL UNIQUE` with **no change-phone flow anywhere**, making the phone a de-facto immutable identity key.
6. **Money tables are well-built** — `NUMERIC(12,2)` throughout (no floats), `CHECK(amount>0)`, full FK chains, idempotency keys, `SELECT … FOR UPDATE` row-locking.
7. **"Immutable" ledgers are immutable by GRANT only** — `service_role`/table-owner can still mutate audit/receipt/stock history; there are no append-only reject triggers on those tables.
8. **`TD-P0-01-RLS-Enforcement` is materially STALE** — it says Finance/SIS RLS "not started," but RLS is broadly enforced across 124 files. The doc could mislead a go/no-go decision.

---

## 2. Findings

| ID | Sev | Finding | Evidence | Recommendation |
|---|---|---|---|---|
| DB-1 | **P0** | Hardcoded `erp_tenant` DB password shipped in a migration — the RLS/immutability role credential is in git | `20260610100000_tenant_access_foundation.sql:13` | Rotate to a vault secret via `ALTER ROLE … PASSWORD`; scrub + rotate **before pilot**. Confirm the live env doesn't reuse the git value. |
| DB-2 | **P0 (deploy)** | Whole isolation model depends on edge fns using `erp_tenant`, not `service_role` | `tenant_access_foundation.sql:3-19`; service_role has 3 GRANT EXECUTE only | Add a deploy-time assertion / startup self-test that the app DSN is the non-bypass role. |
| DB-3 | **P1** | `users.phone NOT NULL UNIQUE` = de-facto immutable identity; **no change-phone flow** contradicts the frozen "phone = credential, not identity" principle | `core_platform_schema.sql:35`; only `UPDATE users` (`20260615110000:27`) touches display_name/email, never phone | Build the governed change-phone flow (OTP-verify → re-point credential → keep UUID/PSID/links, audited) — the documented `PLAT-4`. Until then a parent/staff number change requires manual DB surgery. |
| DB-4 | **P1** | Cross-tenant `SECURITY DEFINER` functions trust caller-supplied org/user IDs; the DB is not the last line of defense | `20260718000000_subscription_assignment_secdef.sql:18-66`; org-builder/onboarding definers | Assert the actor's platform/superAdmin membership *inside* the function, not only at the edge gate. |
| DB-5 | **P1** | "Immutable" ledgers (audit_events, finance_receipts, stock_movements) are immutable by GRANT only — owner/service_role can UPDATE/DELETE | `stock_movements` grant `20260839000000:92`; `finance_receipts` `20260612500000:87`; `audit_events` `20260614500000:107` | Add `BEFORE UPDATE/DELETE` reject triggers (like the PSID/admission triggers) on true ledgers. |
| DB-6 | **P1** | Audit retention / partitioning / hash-chain tamper-evidence is **documented-only**; `audit_events` grows unbounded, no tamper-evidence | `AuditArchitecture.md:74-96,187-190` vs no such migration | Implement partitioning + retention job, or correct the doc to match shipped reality. |
| DB-7 | **P2** | `admission_number` per-school UNIQUE added ~2 months post-creation; pre-existing duplicates may persist and the set-once trigger won't fix them | created non-unique `20260613000000:18`; UNIQUE `20260814000000:39` | Run a duplicate-admission_number audit on live data before pilot. |
| DB-8 | **P2** | Student identity split across 2 tables (`students` + `student_profiles`, 1:1) with 5 identifiers total | `phase2_rls_scope.sql:7`; `sis_slice0_foundation.sql:13-30` | Enforce profile existence (trigger/constraint) or consolidate; document canonical ownership. |
| DB-9 | **P2** | `TD-P0-01-RLS-Enforcement.md` materially understates shipped RLS | doc says "Finance/SIS not started" vs 485 enforcement sites | Update the debt doc; re-scope residual to auth plumbing only. |
| DB-10 | **P3** | 71 write policies omit explicit `WITH CHECK` (isolation still intact via USING reuse); duplicate permissive `domain_events` UPDATE policy | RLS coverage sweep | Add explicit `WITH CHECK` on money/attendance write policies; drop the USING-only `domain_events` duplicate. `ops_backup_runs`/`ops_restore_drills` are the only ENABLE-without-FORCE tables — add FORCE. |

---

## 3. Identity architecture verdict

**Shipped (verified in migrations):**
- `public_student_id` column + global partial-unique index + per-school never-reused counter (`school_public_id_counters`) + idempotent backfill + `BEFORE UPDATE` immutability trigger `reject_public_student_id_change()` (`20260848000000_public_student_id.sql`).
- `admission_number` set-once `BEFORE UPDATE` trigger `reject_admission_number_change()` (`20260847000000`) + per-school UNIQUE.
- Operational student FKs unified to `students(id) ON DELETE CASCADE` (`20260708000000_student_identity_fks.sql`).

**Documented-only / unresolved:**
- **Phone-as-identity (conflict IC-1/IC-2) is REAL and unmitigated** (DB-3). This is the sharpest identity risk and it **contradicts the frozen platform's own Identity-Permanence Invariant**. The freeze documented the conflict but did not fix it; it must be fixed before the identity platform can be called true.
- **Parent/Teacher/Staff Public IDs** are a future model (formats undecided, `PLAT-0`).
- **5 identifiers, 2 tables** (DB-8) — UUID + `student_code` + `admission_number` + `public_student_id` + `roll_number`. Manageable (all FKs point to `students.id`) but is identifier sprawl that needs a documented keep/retire policy.

**Verdict:** the identity *decision* is sound and partly implemented; the *invariant it is named for* is currently false in the database. Prioritize `PLAT-4` (change-phone flow) before advertising "identity is permanent."

## 4. Migration hygiene & data integrity

- **168 migrations, strict timestamp prefixes, no collisions, no destructive `DROP TABLE`/`TRUNCATE`/unguarded `DELETE`, idempotent, `search_path` pinned on all SECURITY DEFINER fns.** Forward-only (no down-migrations — acceptable for Supabase, but DB-1/DB-7 fixes need forward migrations).
- **Money:** NUMERIC(12,2), CHECK amount>0, full FK chain student→invoice→account→receipt, idempotency partial-unique indexes, `FOR UPDATE` locking, `row_version` optimistic-lock trigger. **Solid.**
- **The previously-flagged `inventory_stock_valuations` WITH-CHECK hole is FIXED** (`20260839000000:32-44`).

## 5. Unknowns

- Whether the live `erp_tenant` password was rotated vs the git value (DB-1).
- Whether pre-2026-08-14 duplicate admission numbers actually exist on live data (DB-7).
- Whether every edge route reaching the cross-tenant definers is actually permission-gated (DB-4 — verified the function trusts args; did not trace all routes).
- Whether the tenant-isolation self-test (`run_tenant_isolation_enforced_test`) passes live (harness exists; not executed here — and see QA audit: it has never run in CI).
