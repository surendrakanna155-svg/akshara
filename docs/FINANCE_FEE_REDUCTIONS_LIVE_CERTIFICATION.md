# finance_fee_reductions — Live Certification (tenant_test)

**Date:** 2026-07-09 · **DB:** `akshara_tenant_test` on the VPS (`akshara-postgres`) · **Mode:** NON-DESTRUCTIVE (all cert writes in a transaction that was ROLLED BACK; 0 rows persisted). **Prod `akshara_db` was NOT touched** (verified still at `20260818`, no `finance_fee_reductions` table; edge still `bcebbf12`). · **Harness:** `scripts/qa/live_cert_fee_reductions.sql`.

## 1. Context — this was a full-backlog rehearsal, not a 4-migration top-up

Pre-flight discovery found prod + tenant_test both at migration **`20260818000000`**, i.e. **44 migrations behind HEAD** (`20260819…20260866`); the edge is `bcebbf12` (built 2026-07-01). So certifying `finance_fee_reductions` (`20260863`) live first required applying the whole backlog. Per owner decision, the backlog was applied to **`akshara_tenant_test` only** (isolated from prod) as a deploy rehearsal.

## 2. Rehearsal finding — a real deploy blocker, caught + fixed

Applying the backlog in order **halted at `20260838000000_communication_audience_and_acknowledge.sql`**:

```
ERROR: check constraint "comm_broadcasts_audience_check" of relation
       "comm_broadcasts" is violated by some row
```

**Root cause (confirmed):** `20260729000000` (school_publisher) had widened the audience CHECK to include `'all_staff'`, and `'all_staff'` broadcasts exist in **both** tenant_test **and prod `akshara_db`** (2 rows each, verified read-only). `20260838` then dropped + re-added the constraint **omitting `'all_staff'`**, so it is violated by those rows. The later `20260851000000` even documents restoring `'all_staff'` — but it runs 13 migrations downstream, so a sequential run dies at `20260838` first. **This would have failed the prod deploy mid-way, leaving prod half-migrated.**

**Fix:** `20260838000000` now includes `'all_staff'` in its CHECK list (aligned with `20260729`/`20260851`; the migration is unapplied everywhere, so edited in place). After the fix the remaining **26 migrations applied cleanly** → tenant_test at `20260866`.

## 3. Certification results (all PASS)

**C0 — schema guardrails present (introspection):** table `finance_fee_reductions` with 6 CHECK constraints (`source_ck`, `value_ck`, `applied_nonneg_ck`, `source_kind`, `reduction_kind`, `status`), both partial-unique indexes (`uq_…_live_scholarship`, `uq_…_live_discount`), RLS **enabled + forced**, policy `finance_fee_reductions_school_scope` (ALL). ✅

**C1 — RLS school-scope isolation** (run AS `erp_tenant`; `postgres`/`supabase_admin` bypass RLS, so the SELECTs were executed under `SET ROLE erp_tenant`):
| Probe | Expect | Result |
|---|---|---|
| same school + `scope='school'` | 1 (visible) | **1** ✅ |
| different school | 0 (blocked) | **0** ✅ |
| `scope='parent'` | 0 (blocked) | **0** ✅ |

**C2 — CHECK constraints reject bad data** (each raised as designed): `source_ck` (scholarship + discount both set), `value_ck` (percent=0, percent=150, percent+fixed both set), `applied_nonneg_ck` (negative). ✅

**C3 — partial-unique idempotency:** a 2nd LIVE (`pending`) reduction for the same `(invoice, scholarship)` is **blocked**; a `reversed` duplicate is **allowed** (the partial predicate only covers `pending`/`approved`). ✅

## 4. Scope boundary (honest)

C0–C3 certify the **database-level money guardrails live**. The **application-level invariants** — SoD (`approved_by ≠ created_by`), lockstep (`invoice.outstanding ↔ account.outstanding` move by the same delta), and clamp-to-outstanding (no negative payable, exact reversal) — live in `finance_fee_reductions_repository.ts` and are proven by the deno unit suite (green in the `_shared` 2409/0 run). A full **live end-to-end** approve/reverse/clamp through the edge requires the new edge deployed against a tenant DB; that runs **after the prod deploy** (owner-gated) and is the one remaining item to close this cert end-to-end.

## 5. Verdict

**DB-level cert: PASS (live, non-destructive).** The `finance_fee_reductions` schema + RLS + constraint guardrails behave exactly as designed on real Postgres. The backlog is now **prod-deploy-ready** (the `20260838` blocker is fixed and the full chain applied cleanly on the tenant mirror). Prod deploy remains **paused pending owner go** (owner chose test-tenant-first).
