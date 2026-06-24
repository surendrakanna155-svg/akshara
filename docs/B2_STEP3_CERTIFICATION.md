# B2 — Entitlement Layer · Step 3 · Certification

**Date:** 2026-06-24 · **Branch:** `feature/scope-trim-school-build`
**Scope (locked):** entitlement layer only — NO billing, renewals, invoicing,
payments, MRR, addons, dedicated DBs, or white-label. Builds on Step 2 (`5f9d6bb`).

Step 3 delivers the **client entitlement layer**: it fetches the plan catalog and
the org's resolved subscription, caches them, derives the plan *ceiling*, and
replaces the app's local capability assumptions with plan-bounded effective
capabilities. **No UI work** (Step 4) and **no VPS deploy** (Step 5).

## What was built (additive, client-only)

| Piece | File | Notes |
|---|---|---|
| Models | `lib/core/entitlements/entitlement_models.dart` | `SubscriptionPlan`, `ResolvedSubscription` (+ `PlanLimits`/`PlanUsage`), `EntitlementSlugs`, `SubscriptionStatus`; `ResolvedSubscription.trialFallback()` |
| Resolver (pure) | `entitlement_resolver.dart` | `planCeiling(slugs)→SchoolCapabilities`, `intersect(local, ceiling)`, `resolveEffective`; `unrestrictedCeiling` sentinel. Mirrors the backend `effective = planAllows ∩ schoolConfigEnabled` |
| Cache | `entitlement_storage.dart` | SharedPreferences cache for the resolved subscription (last-known plan survives an outage) |
| API client | `lib/core/repositories/api/entitlements/entitlement_api_repository.dart` | read-only `GET /plans`, `GET /subscription` (no assign/pay/renew) |
| Providers | `entitlement_provider.dart` | `subscriptionProvider` (hybrid: cache/Trial seed → backend refresh), `planCatalogProvider`, `planCapabilityCeilingProvider`, repository/storage providers |
| Feature flag | `lib/core/repositories/repository_config.dart` | `entitlementApiEnabledProvider` (`ENTITLEMENT_API_ENABLED`, default off) |
| **Integration seam** | `lib/core/school_config/school_configuration_provider.dart` | `schoolCapabilitiesProvider` now returns `local ∩ planCeiling`; raw config exposed as `localSchoolCapabilitiesProvider` |

## How "effective capabilities" replaces local assumptions

`schoolCapabilitiesProvider` is the single point every gating consumer reads
(admin modules, KPIs, copilot topics, `enabledModuleIds` — 9 consumers). It now
computes:

```
effective = localSchoolConfig ∩ planCeiling(subscription.entitlements)
```

- **Entitlement API ON** → the plan bounds what the school can enable. A school
  may switch a module off, but can never switch on a module its plan lacks.
- **Entitlement API OFF (default)** → `planCapabilityCeilingProvider` returns the
  **unrestricted** ceiling, so `effective == local` and **pre-B2 behaviour is
  preserved**. No existing journey changes until the flag is turned on (Step 5).
- **Missing / unreachable subscription** → `subscriptionProvider` seeds from cache,
  else the **Trial fallback** (no optional modules). A transient outage keeps the
  last-known plan — it never silently downgrades a live org.

## Definition of Done — Step 3

| Gate | Result |
|---|---|
| Fetch `/plans` and `/subscription` | ✅ `EntitlementApiRepository` (read-only) |
| Entitlement provider + cache | ✅ `subscriptionProvider` hybrid cache + `EntitlementStorage`; `planCatalogProvider` |
| Expose effectiveCapabilities from backend | ✅ `planCapabilityCeilingProvider` + `schoolCapabilitiesProvider = local ∩ ceiling` |
| Replace local capability assumptions | ✅ all 9 `schoolCapabilitiesProvider` consumers now plan-bounded; raw toggles → `localSchoolCapabilitiesProvider` |
| Tests: Trial / Standard / Professional / Enterprise / Trial fallback | ✅ **13/13** (resolver per-plan + registry `enabledModuleIds`; provider seam; Trial fallback; unrestricted-ceiling preserves local) |
| `flutter analyze` | ✅ **No issues found** on all touched files (full-project: 0 errors; pre-existing baseline lints only, none in B2 files) |
| Existing capability consumers green | ✅ `school_config`, copilot capability filter, admin nav, workspace nav suites pass |
| Backward compatible | ✅ flag default off → unrestricted ceiling → identical to pre-B2 |
| No UI | ⏭ Step 4 (no widgets/screens added) |
| No VPS deploy | ⏭ Step 5 |

## Test commands
```
flutter test test/core/entitlements/      # 13 passed
flutter analyze lib/core/entitlements/ ... # No issues found
```

**Status: B2 Step 3 = certified (client entitlement layer + effective-capability
seam), local. Not deployed; flag default off. Next = Step 4 (UI) on owner go.**
