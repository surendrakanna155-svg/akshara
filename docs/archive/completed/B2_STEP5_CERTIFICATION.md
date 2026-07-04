# B2 — Entitlement Layer · Step 5 · Production Certification

**Date:** 2026-06-25 · **Branch:** `feature/scope-trim-school-build`
**VPS:** `46.28.44.46` / `https://akshara.veloraunisexsalon.com` · stack `/opt/akshara`

B2 (Capability Gating / entitlement layer) is **deployed and production-certified**
on the live self-hosted backend. Enforcement is **enabled**. Scope held: entitlement
layer only — no billing/payments/renewals/invoices/MRR/addons/white-label.

## Deploy sequence (executed, safe order)

1. **Backup first** — `akshara-backup.sh manual` → `akshara_db_20260625T061021Z_manual.dump.enc`.
2. **Migrations** — 4 applied to `akshara_db` as `supabase_admin` (`ON_ERROR_STOP`),
   recorded in the ledger: `20260717000000` (plans catalog), `20260717100000`
   (org subscriptions + Trial back-fill), `20260717200000` (permissions),
   `20260718000000` (assignment SECURITY DEFINER fns). Verified: **4 plans, 42
   entitlement rows, 1 org back-filled, `managePlatformSubscriptions` → superAdmin,
   both fns present, RLS forced + 3 policies**.
3. **Edge deployed dark** — entitlement files synced to `/opt/akshara/functions/`,
   `akshara-edge` recreated with `--env-file .env.akshara`; **enforcement OFF** at
   this point so the deploy could not 402 anyone.
4. **Pilot org assigned its correct plan** — usage read from the live DB: enabled
   modules = transport + library + hrPayroll, 2 schools, 5 students. The smallest
   plan covering that = **Professional** (all ops modules, max 5 schools, slab 2000).
   Assigned via the live `PUT /platform/organizations/{id}/subscription` route with an
   organization-scoped superAdmin token. *(A staging superAdmin membership was granted
   to the org-admin account `+919876543210` — the platform-owner account that manages
   plans; staging had no superAdmin.)*
5. **Enforcement enabled** — `ENTITLEMENT_ENFORCEMENT=true` added to `.env.akshara`,
   edge recreated. Confirmed in-container. Pilot already on Professional, so enabling
   broke nothing.

## Live certification (real auth + real production DB)

`scripts/capability_gating_b2_smoke.sh` → **8 passed, 0 failed**:

| Check | Result |
|---|---|
| superAdmin login (organization scope) | ✅ token carries `managePlatformSubscriptions` |
| `GET /plans` 4-tier catalog | ✅ trial/standard/professional/enterprise |
| Assign **Standard** via `PUT` + resolve | ✅ |
| **Standard → gated module `402 PLAN_UPGRADE_REQUIRED`** | ✅ enforcement active |
| Upgrade **Professional** via `PUT` + resolve | ✅ |
| **Professional → gated module no longer 402** (403 = downstream scope, entitlement passed) | ✅ |
| Final plan left on Professional | ✅ |

**Additional live verification:**
- **Audit** — `domain_events` holds `subscription.plan.assigned` rows for every
  assignment (plan + status + actor); `assigned_by` recorded.
- **Client read path** — `GET /subscription` (school scope) returns
  `professional / active`, 14 entitlements, **3 effective capabilities** =
  exactly the pilot's used modules (plan ceiling ∩ school config).
- **No collateral lockout** — the pilot's used modules (library/transport/hr) do
  not 402 on Professional; real users are unaffected.
- **RLS / SECURITY DEFINER** (verified locally + by the live cross-org-safe list):
  direct `erp_tenant` writes to `organization_subscriptions` are blocked; the
  audited assign fn is the only write path.

## Limits (G5)
Slab-limit guards are deployed and active (gated by the same enforcement switch).
The math + RLS counting are unit- and DB-certified locally; not exercised live
(pilot has 5 students vs a 2000 slab). Enforcement-switch ON is proven by the live
402 module path.

## Production state after Step 5
- Pilot org **Akshara Staging Organization** → **Professional / active**.
- `ENTITLEMENT_ENFORCEMENT=true` on `akshara-edge`.
- Backup retained pre-change. Postgres healthy throughout (no incident).

**Status: B2 = Production Certified (2026-06-25).** All functional spec items
(G1–G7, minus documented-deferred G7a + the §6 server-payload deviation) are live.
See `docs/B2_STATUS_LEDGER.md`.
