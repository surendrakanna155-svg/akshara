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

## 5. PROD DEPLOYMENT + live E2E (2026-07-09, owner-authorized)

The full backlog was deployed to prod after the tenant-test rehearsal:
- **Pre-deploy backup** `predeploy_gapsweep_20260709_134956.sql.gz` (verified: gzip-ok, complete footer, 196 tables).
- **44/44 migrations applied to `akshara_db`** (as `supabase_admin` — the first attempt as `postgres` cleanly rolled back on a `schema_migrations` permission denial with 0 applied; re-run under the correct role succeeded). Prod now at `20260866`.
- **Edge redeployed** to HEAD `2568ff9b` (functions synced, `build_info.json` written, `akshara-edge` restarted); `/health` `200` version==HEAD, `/ready` db:true, `/storage` reachable, `/providers` role `erp_tenant` bypassRls:false; edge logs clean (0 uncaught/TypeError). **Smoke:** new gap-wave routes now serve (401-gated, were 404); control route still 404.
- **Live E2E through the deployed edge** (real OTP auth, real DB/RBAC), non-destructive/net-zero on invoice `b9000000…001` (outstanding 44,500 unchanged throughout, test row deleted after):
  - authed `GET /finance/fee-reductions` → 200;
  - **propose** (maker) → `pending`, moves no money; studentId/accountId server-resolved from the invoice;
  - **SoD self-approve → HTTP 403** "cannot be approved by the person who proposed it" (governance gate enforced live);
  - **reject** → 200; cleanup → invoice unchanged, 0 rows left.
- **Not run live:** the successful-approval lockstep+clamp+reversal path — the seed tenant has no second finance user and SoD (correctly) requires proposer ≠ approver; creating prod users for a cert was declined. That path stays covered by the DB-level cert (§3) + the deno unit suite (2409/0). COM-4 / R2 / Face ID were excluded from this deploy by instruction.

## 6. Verdict

**PASS (live).** Prod is deployed at HEAD and healthy; `finance_fee_reductions` guardrails (RLS + CHECK + partial-unique) are certified live, and the deployed edge enforces the maker-checker SoD gate end-to-end. Residual: the money-moving approval E2E (deferred to protect prod balances / absent 2nd seed user) — covered by DB + unit certs. Rollback assets retained: `predeploy_gapsweep_20260709_134956.sql.gz` + `functions.bak.20260709_180405`.
