# B2 — Capability Gating (Entitlement Layer) · Pre-flight Review

**Status:** REVIEW ONLY — no code, no migrations, no tables, no routes, no UI.
**Gate:** B1 is Production Certified (2026-06-24) ✅, so this pre-flight is unblocked.
B2 execution begins only on explicit owner go, within the approved entitlement-layer scope
(`docs/B2_CAPABILITY_GATING_SPEC.md` §0).

---

## 1. Spec validated against current code

| Spec assumption | Verified in code | Verdict |
|---|---|---|
| `SchoolCapabilities` = 8 flags, reusable as the gating substrate | all 8 present in `lib/core/school_config/school_configuration_models.dart`; 9 consumers across `lib/` | ✅ accurate |
| Live per-school config table to build entitlement onto | `school_configuration` (migration `20260714000000`), FORCE RLS school-scope, GET/PUT `/school-config` | ✅ accurate |
| Permissions are catalog-driven (slug, group, action, scope, desc) + role grants | confirmed pattern in `20260623400000_evolution_permissions.sql` (e.g. `manageSchoolSetup` granted to superAdmin/schoolAdmin) | ✅ — add `managePlatformSubscriptions` (superAdmin only) + `viewSubscription` the same way |
| A superAdmin/org-scope route pattern exists for `PUT /platform/.../subscription` | Director portal enforces organization scope (`director_handlers.ts`: 403 if not org scope); middleware has `requirePermission`, `requireSchoolOperationalScope`, `organizationIdFromClaims` | ✅ — reuse this org-scope + permission gate; no new scope machinery |
| `organizations` table exists as FK target | `CREATE TABLE organizations` present | ✅ |
| Enforcement helper `requireEntitlement` returning `402 PLAN_UPGRADE_REQUIRED` | none today (routes only check RBAC) | ➕ new, additive — one shared helper in `_shared/entitlements/` |

**Corrections to the spec:** none material. Two clarifications folded in:
- The `PUT /platform/organizations/{id}/subscription` route must gate on **both** `managePlatformSubscriptions` **and** organization scope (mirror Director's 403-if-not-org-scope), not school scope.
- `GET /subscription` for an org admin runs in **school scope** (the common pilot token) — it resolves the org's plan via `organizationIdFromClaims`, so it does not require org-scope tokens.

## 2. No overlap with existing school capability flags — confirmed

B2 is strictly a **layer on top**, not a duplicate:
- The 8 `SchoolCapabilities` flags and `SchoolCapabilityRegistry` **stay as-is** (the personalization layer).
- B2 adds **plan entitlements** (what the org is *allowed*) and resolves
  `effectiveCapability = planAllows(cap) AND schoolConfigEnabled(cap)`.
- `SchoolCapabilityRegistry` is **extended to read the effective capability**, not rewritten; the 9 existing consumers keep working unchanged (they receive a `SchoolCapabilities` that has already been intersected with the plan).
- No flag is renamed, removed, or re-homed. `school_configuration.capabilities` JSONB is untouched.
- Entitlement slugs (`module.transport`, …) **map onto** the existing flags (spec §4), so there is one source of truth for "is transport on", now bounded by the plan.

**Risk of overlap:** low. The only integration seam is the single function that produces the
effective `SchoolCapabilities` — covered by unit tests in the plan below.

## 3. Migration ordering — confirmed

- Latest applied migration (local + VPS ledger) = **`20260716000000`** (B1).
- B2's additive migrations must be timestamped **`20260717000000+`** so they sort strictly after B1 and after the AI/onboarding/school-config migrations already live.
- Proposed B2 migrations (additive only): `20260717000000_subscription_plans_catalog.sql`,
  `20260717100000_organization_subscriptions.sql` (+ seed + default-to-Trial), `20260717200000_subscription_permissions.sql`.
- No table renames/drops; no edits to `school_configuration` or `admissions_*`. FORCE RLS + `erp_tenant` grants per house pattern. Follows the `erp_tenant`-no-DELETE rule (status flips, no deletes).

## 4. Implementation plan (for execution — on owner go only)

Sequenced; each step ends with its own analyze/test gate. Stays inside approved scope
(plan catalog · org subscription assignment · entitlement resolution · server-side enforcement
· locked/upgrade UX · audit). **No billing/MRR/renewals/payment/dedicated-DB/white-label/addons.**

1. **Data model & seed** (`20260717*` migrations) — `subscription_plans`, `plan_entitlements`,
   `organization_subscriptions` (default `trial`); seed Trial/Standard/Professional/Enterprise +
   entitlement rows; catalog tables for `managePlatformSubscriptions`/`viewSubscription` in the
   permission catalog. Validate locally via `supabase migration up`. *(blocks 2–4)*
2. **Backend entitlement service + enforcement** —
   `_shared/entitlements/` resolver (plan ∪ enterprise overrides ∩ school config; no-row ⇒ Trial
   fail-safe); `GET /plans`, `GET /subscription`; `PUT /platform/organizations/{id}/subscription`
   (superAdmin + org-scope, audited via `emitMutationAudit`); reusable `requireEntitlement(slug)`
   → `402 PLAN_UPGRADE_REQUIRED` wired into the gated routers (transport/hostel/library/inventory/
   alumni/hr/director-control-center); slab limit checks on enrollment + school-create. Deno
   type-check + unit tests.
3. **Client entitlement layer** — entitlement provider (extend the school-config fetch to carry
   resolved entitlements + plan summary); `SchoolCapabilityRegistry` reads the effective
   capability; hybrid cache preserved. Resolution unit tests; `flutter analyze`.
4. **UI** — plan badge; read-only Plan & Entitlements screen with **wa.me upgrade CTA** (no
   payment); locked module/KPI states; School Discovery wizard respects the plan ceiling; copilot
   plan-locked message; superAdmin assign-plan screen. Widget tests.
5. **Tests & certification** — contract + integration/E2E (assign Standard → transport 402 →
   upgrade Professional → 200); author `scripts/capability_gating_b2_smoke.sh`; **VPS production
   cert** via the B1 deploy pattern (`--env-file .env.akshara`, backup first, smoke against the
   live URL with a pilot phone). Cert doc + roadmap flip + memory.

**Agent split (when execution starts):** 1 → (2 ∥ 3) → 4 → 5. Reuse Approvals/Audit/RBAC/
WhatsApp(wa.me); extend the capability engine, don't rebuild; migrations additive.

**Owner inputs still needed before/within execution (all data-driven in DB):** final plan
prices/slabs, exact per-tier module split (spec §4 is the seed), trial length + grace %,
hide-vs-show-locked UX, whether AI-predictions is Enterprise-included or per-deal override.

---
**Pre-flight verdict:** spec is consistent with the live code; no overlap risk beyond the single
intersection seam (test-covered); migration ordering is clean at `20260717+`. **Ready to execute
on owner go**, within the locked entitlement-layer scope.
