# B2 — Entitlement Layer · Step 2 · Certification

**Date:** 2026-06-24 · **Branch:** `feature/scope-trim-school-build`
**Scope (locked):** entitlement layer only — NO billing, renewals, invoicing,
payments, MRR, addons, dedicated DBs, or white-label. Builds on Step 1 (`f006cba`).

Step 2 delivers the **read + enforcement** half of the entitlement layer:
`GET /plans`, `GET /subscription`, the pure resolution rule, and the
`requireEntitlement` 402 guard wired onto the plan-gated modules. No client/UI
changes (that is Step 3) and **no VPS deployment** (that is Step 5).

## What was built (additive, backend-only)

| Piece | File | Notes |
|---|---|---|
| Resolution rule (pure) | `_shared/entitlements/entitlement_resolver.ts` | `effectiveCapability = planAllows ∩ schoolConfigEnabled`; capability→slug map; Trial-default capabilities; override grant/revoke |
| Data access (read-only) | `entitlement_repository.ts` | `listPublicPlans`, `getPlanWithEntitlements`, `getOrgSubscription`, `getSchoolCapabilities` |
| Resolution service | `entitlement_service.ts` | `resolveSubscription(org, school)` → plan/status/entitlements/capabilities/limits/usage; **missing subscription → Trial fail-safe** |
| `GET /plans` | `entitlement_handlers.ts` + `entitlement_router.ts` | public plan catalog (auth required, no special perm) |
| `GET /subscription` | same | gates on `viewSubscription` + school scope; resolved view for caller org |
| `requireEntitlement` / `enforceEntitlement` / `withEntitlement` | `entitlement_middleware.ts` | returns **`402 PLAN_UPGRADE_REQUIRED`** (distinct from 403 RBAC); resolves plan off the RLS connection; non-invasive router wrapper |
| Wiring | `api/index.ts` | `routeEntitlements` registered; gated modules wrapped (see below) |

## Modules gated with `requireEntitlement` (per spec §6)

Each wrapped non-invasively in `index.ts` via `withEntitlement(router, prefix, slug)`:

| Path prefix | Entitlement slug | Plans that pass |
|---|---|---|
| `/transport` | `module.transport` | Professional, Enterprise |
| `/hostel` | `module.hostel` | Professional, Enterprise |
| `/library` | `module.library` | Professional, Enterprise |
| `/inventory` | `module.inventory` | Professional, Enterprise |
| `/alumni` | `module.alumni` | Professional, Enterprise |
| `/hr` | `module.hr_payroll` | Professional, Enterprise |
| `/director` | `module.multi_branch` | Professional, Enterprise |

**Deliberately NOT gated in Step 2:** `/control-center`. The spec pairs it with
`/director` under `module.multi_branch`, but Control Center is the management/owner
aggregation surface that overlaps **core `module.management`** (granted to every
plan). Gating it on `multi_branch` would deny core management to Trial/Standard
single-school orgs. The `multi_branch` ceiling is enforced via `/director`; if
Control-Center plan-gating is desired it should ride on a dedicated slug — flagged
for owner decision, not silently expanded here. `/inventory-distribution` is also
left ungated (a sub-feature; the named `/inventory` module carries the gate).

## Definition of Done — Step 2

| Gate | Result |
|---|---|
| Resolution rule implemented | ✅ `planAllows ∩ schoolConfigEnabled`, pure & DB-free |
| Resolver unit tests | ✅ **11/11** — Trial · Standard · Professional · Enterprise · school-level disable override · missing-subscription→Trial (+ override grant/revoke, default-capability) |
| Enforcement unit tests | ✅ **4/4** — `requireEntitlement` returns null when allowed, `402 PLAN_UPGRADE_REQUIRED` when not (Set + array inputs; Trial 402s on paid module) |
| Deno type-check | ✅ clean across `api/index.ts` full import graph + all entitlement files |
| DB-level repository/RLS verification | ✅ on the real seeded local DB as `erp_tenant` in school scope: `GET /plans` = 4 active+public plans, 42 entitlement rows (6+6+14+16), own-org subscription = `trial/trial` (back-fill), **RLS negative: other orgs' subscriptions invisible (0 rows)** |
| Scope held | ✅ no billing/payments/renewals/invoicing/MRR/addons/dedicated-DB/white-label; 402 is purely an entitlement signal, never a charge |
| Client/UI | ⏭ Step 3 (untouched — no Dart changed; `flutter analyze` unaffected) |
| VPS deployment + live smoke | ⏭ Step 5 (not deployed) |

## Test commands
```
cd supabase/functions
deno test _shared/entitlements/          # 15 passed, 0 failed
deno check api/index.ts _shared/entitlements/*.ts   # clean
```

**Status: B2 Step 2 = certified (resolver + GET endpoints + enforcement), local.
Not deployed. Next = Step 3 (client entitlement layer) on owner go.**
