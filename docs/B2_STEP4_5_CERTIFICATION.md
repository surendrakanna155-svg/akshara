# B2 — Entitlement Layer · Step 4.5 · Certification

**Date:** 2026-06-24 · **Branch:** `feature/scope-trim-school-build`
**Purpose:** allow safe assignment of Trial / Standard / Professional / Enterprise
**before** enabling B2 in production. Builds on Step 4 (`63861a3`).
**Scope (locked):** plan assignment only — NO billing, payments, renewals, invoices,
MRR, addons, white-label, or subscription-management workflows. Not deployed.

## What was built (additive)

### Backend
| Piece | File | Notes |
|---|---|---|
| SECURITY DEFINER fns | `supabase/migrations/20260718000000_subscription_assignment_secdef.sql` | `assign_organization_subscription(org, plan, status, actor)` (validated upsert) + `list_subscription_assignments()` (orgs + current plan). EXECUTE granted to `erp_tenant` only; the tenant role gains no new table rights — these are the only cross-org path |
| Pure helpers | `_shared/entitlements/subscription_assignment.ts` | `parseAssignmentBody` (validates plan + status), `defaultStatusForPlan` |
| Repository | `_shared/entitlements/entitlement_repository.ts` | `listAssignableOrganizations`, `assignOrganizationSubscription` |
| Handlers | `_shared/entitlements/subscription_admin_handlers.ts` | `GET /platform/subscriptions`, `PUT /platform/organizations/{id}/subscription` — both gate on **`managePlatformSubscriptions`** (superAdmin); assignment is **audited** |
| Audit event | `_shared/audit/mutation_audit_catalog.ts` | `subscriptionAudit.planAssigned` → `subscription.plan.assigned`, keyed off a per-event id so every change is recorded |
| Router | `_shared/entitlements/entitlement_router.ts` | regex-matches the PUT path; GET list |

### Client (read-only except the single assign action)
| Piece | File | Notes |
|---|---|---|
| Model | `lib/core/entitlements/entitlement_models.dart` | `OrganizationPlanAssignment` |
| API client | `.../api/entitlements/entitlement_api_repository.dart` | `fetchAssignableOrganizations`, `assignSubscription` |
| Providers | `lib/core/entitlements/subscription_admin_provider.dart` | `canAssignOrganizationPlansProvider` (superAdmin), `assignableOrganizationsProvider`, assign action |
| Screen | `lib/features/entitlements/organization_plan_assignment_screen.dart` | **select organization → view current plan → change plan → save**; superAdmin-gated; "no payment is taken" note |
| Entry + route | `plan_entitlements_screen.dart`, `route_names.dart`, `app_router.dart` | `/admin/plan/assign`; superAdmin-only action on the Plan & Entitlements screen |

## Security model

`managePlatformSubscriptions` is seeded to **superAdmin only**. The SECURITY DEFINER
functions bypass RLS (required for cross-org assignment); the permission check in
the handlers is the security boundary, mirroring the established privileged-op
pattern (`onboarding_rollback_student`). Direct `erp_tenant` writes to
`organization_subscriptions` remain blocked by the Step-1 RLS — verified below.

## Definition of Done — Step 4.5

| Gate | Result |
|---|---|
| `PUT /platform/organizations/{id}/subscription` | ✅ superAdmin-only, audited |
| `managePlatformSubscriptions` enforced | ✅ handler `requirePermission`; seeded superAdmin-only (DB-verified) |
| Audit event for plan changes | ✅ `subscription.plan.assigned`, unique key per change |
| Minimal assignment screen (select org / view plan / change / save) | ✅ superAdmin-gated |
| **Backend tests** | ✅ Deno **24/24** in the entitlement suite (incl. body parse/validate, default status) |
| **RBAC tests** | ✅ superAdmin passes; non-superAdmin → 403 |
| **Audit tests** | ✅ event/payload/entity shape + unique-key-per-event |
| DB-level verify | ✅ on local DB as `erp_tenant`/platform scope: assign Professional→Enterprise via fn; **RLS negative — direct UPDATE blocked (0 rows)**; `assigned_by` recorded; invalid plan rejected (FK→400); superAdmin-only grant |
| **flutter analyze** | ✅ **0 errors** project-wide; no warnings/errors in any B2 file |
| **widget tests** | ✅ **3/3** assignment screen (superAdmin sees selector + current plan + disabled-until-changed Save; changing plan enables Save; non-superAdmin blocked); Step-4 screen/badge tests still green (gate override added); admin suite 22/22 |
| Scope held | ✅ no billing/payments/renewals/invoices/MRR/addons/white-label/management workflows |
| Not deployed | ✅ local only |

## Test commands
```
cd supabase/functions && deno test _shared/entitlements/      # 24 passed
flutter test test/features/entitlements/ test/core/entitlements/   # all passed
flutter analyze                                                # 0 errors
```

**Status: B2 Step 4.5 = certified locally (platform plan assignment). Not deployed.
Step 5 (tests + VPS cert) is next on owner go — assign the live pilot org a plan
via this screen before enabling B2.**
