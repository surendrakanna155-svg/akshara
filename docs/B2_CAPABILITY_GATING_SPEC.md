# B2 — Capability Gating → Tiered Pricing · Gap Report & Execution Spec

**Status:** SPEC ONLY — no code. Execution begins only after **B1 is production-certified**.
**Roadmap:** P1 "quick win — finalize tier/package definitions → tiered pricing live".
**Aligns with:** `docs/Releases/v6.1-SaaS-Platform-Addendum.md` (authoritative subscription/
entitlement architecture). B2 implements the **MVP slice** of that design; it does NOT
build the full renewal/billing/dedicated-DB sagas (those stay P2–P3, owner-gated).
**Locked rules honoured:** WhatsApp = wa.me only (upgrade/"contact sales" deep-links, no
Meta API); reuse Approvals/Audit/RBAC/WhatsApp; extend the existing capability engine,
don't rebuild.

---

## 1. Current state (what's already live — the "~85%")

| Layer | What exists | Evidence |
|---|---|---|
| Capability model | `SchoolCapabilities` — 8 boolean flags: transport, hostel, library, inventory, alumni, hrPayroll, multiBranch, trustOrganization (defaults: 6 ops ON, multiBranch/trust OFF) | `lib/core/school_config/school_configuration_models.dart` |
| Gating engine | `SchoolCapabilityRegistry` gates admin modules, KPIs, copilot topics, `enabledModuleIds`; `CopilotCapabilityFilter` blocks copilot Q&A on disabled topics | `lib/core/school_config/school_capability_registry.dart`, `lib/features/copilot/copilot_capability_filter.dart` |
| Persistence | `school_configuration` table — 1 row/school, JSONB `capabilities` + school_type/curriculum/operations_model/branch_count; FORCE RLS school-scope; `erp_tenant` grants | migration `20260714000000_school_configuration.sql` |
| Backend API | `GET`/`PUT /school-config`; reads gate on `viewSchoolSetup`, writes on `manageSchoolSetup` | `supabase/functions/_shared/school_config/*` |
| Client wiring | `SchoolConfigurationNotifier` — hybrid in-memory → SharedPreferences cache → tenant-authoritative API when `SCHOOL_CONFIG_API_ENABLED`; optimistic writes | `lib/core/school_config/school_configuration_provider.dart` |
| UI | Smart School Discovery wizard (pick type/curriculum/ops + toggle modules) | `lib/features/school_config/school_discovery_screen.dart` |
| Industry layer | `IndustryCapabilityRegistry` maps industry → modules/widget-pack/copilot key (vertical scaffolding, not pricing) | `lib/core/industry/industry_capability_registry.dart` |

**In one line:** the gating *mechanism* works end-to-end and is live, but it is **self-service
personalization** ("which modules my school uses"), driven entirely by the school's own toggles.

## 2. Remaining gaps (the real B2)

There is **no commercial entitlement layer**. Confirmed: no plan/edition/subscription/billing
concept exists anywhere in `lib/`, `supabase/`, or config (only the v6.1 addendum *design*).

| # | Gap | Today | Needed |
|---|---|---|---|
| G1 | **Plan catalog** | none | `subscription_plans` + `plan_entitlements` (Standard/Professional/Enterprise), seeded |
| G2 | **Org → plan assignment** | none | `organization_subscriptions` (status/slab/trial), set by platform/superAdmin only |
| G3 | **Entitlement resolution** | school freely toggles any flag | effective = (plan ∪ addons ∪ overrides) **∩** school self-config; school can't enable what the plan excludes |
| G4 | **Server-side enforcement** | module routes check only RBAC | shared `requireEntitlement(slug)` guard on gated module routes (defense-in-depth, not just client) |
| G5 | **Limits** | none | per-plan `limit.students` / `limit.schools` (slab) + grace buffer |
| G6 | **Locked/upgrade UX** | disabled modules simply hidden | lock chips + "Upgrade" CTA (wa.me to sales); plan badge; billing/plan screen |
| G7 | **Fast gate signal** | client reads config | plan summary in entitlement fetch (and optional `subscription_warning` JWT claim per addendum §4) |
| G8 | **Audit** | config writes audited | plan assign/change/override audited (`subscriptionPlanAssigned`, `subscriptionOverrideApplied`) |

**Explicitly OUT of B2** (later/owner-gated, per addendum §7–§9): renewal saga, invoicing/MRR,
quotes, dedicated-DB migration, platform CRM deals, white-label, offboarding/export.

## 3. Pricing / tier model (PROPOSED — final names, prices, slabs are OWNER's decision)

Three public plans + addons, annual billing (per addendum §6). Prices are placeholders for
the owner to set; engineering reads them from the DB, so changing them is data, not code.

| Plan (`slug`) | tier_rank | Target | Student slab | Max schools | Core modules | Differentiator modules |
|---|---|---|---|---|---|---|
| **Standard** (`standard`) | 1 | Single school <500 | 0–500 | 1 | admissions, finance, sis, management, attendance, exams | basic copilot |
| **Professional** (`professional`) | 2 | Growing / multi-school | slab-tiered | up to 5 (addon +5) | + transport, hostel, library, inventory, alumni, hrPayroll | + parent insights, full copilot, director (multiBranch) |
| **Enterprise** (`enterprise`) | 3 | Large groups / trusts | custom | unlimited (contract) | all | + trustOrganization, AI predictions, white-label*, API access* (*= P2+/addon) |
| **Pilot/Trial** (`trial`) | 0 | New pilots | 0–100 | 1 | Standard set | time-boxed (`trial_ends_at`) |

**Addons** (`subscription_addons`): `addon.extra_school_pack` (+5 schools), `addon.ai_pack`
(predictions), `addon.dedicated_db` (Enterprise, P2+). Enterprise per-deal `overrides` JSONB.

## 4. Feature gating matrix (capability slug → min plan)

Entitlement slugs follow addendum §6.3 (`module.*`, `feature.*`, `limit.*`, `tier.*`). Maps onto
the existing `SchoolCapabilities` flags so the gating engine is reused, not replaced.

| Entitlement slug | Maps to flag / surface | Standard | Professional | Enterprise |
|---|---|:--:|:--:|:--:|
| `module.admissions/finance/sis/management/attendance/exams` | core (always) | ✅ | ✅ | ✅ |
| `module.transport` | `transport` | — | ✅ | ✅ |
| `module.hostel` | `hostel` | — | ✅ | ✅ |
| `module.library` | `library` | — | ✅ | ✅ |
| `module.inventory` | `inventory` | — | ✅ | ✅ |
| `module.alumni` | `alumni` | — | ✅ | ✅ |
| `module.hr_payroll` | `hrPayroll` | — | ✅ | ✅ |
| `module.multi_branch` | `multiBranch` → director/control-center | — | ✅ | ✅ |
| `module.trust_org` | `trustOrganization` | — | — | ✅ |
| `feature.parent_insights` | parent insights surface | — | ✅ | ✅ |
| `feature.ai_predictions` | predictions (addon) | — | addon | ✅ |
| `feature.api_access` / `feature.white_label` | platform features | — | — | ✅ (P2+) |
| `limit.students` | slab cap + 10% grace | 500 | slab | custom |
| `limit.schools` | branch cap | 1 | 5 (+addon) | ∞ |

**Resolution rule:** `effectiveCapability(cap) = planAllows(cap) AND schoolConfigEnabled(cap)`.
A school may *narrow* within its plan (turn off a module it doesn't use) but can never *exceed* it.

## 5. Data model (additive migrations, mirror addendum §6.2)

- `subscription_plans(slug PK, name, tier_rank, student_slab_min, student_slab_max, max_schools, grace_buffer_percent, billing_period, base_price_paise, is_public, is_active)` — **seeded**, platform-global (no tenant scope; read-only to tenants).
- `plan_entitlements(plan_slug FK, entitlement_slug, PRIMARY KEY(plan_slug, entitlement_slug))`.
- `subscription_addons(slug PK, name, entitlement_slug, price_paise_annual)`.
- `organization_subscriptions(organization_id PK/unique → organizations, plan_slug FK, status CHECK(trial|active|grace|suspended), student_slab_max, trial_ends_at, student_count_cached, started_at, assigned_by, overrides JSONB DEFAULT '{}')`.
- `organization_subscription_addons(organization_id, addon_slug, status, PRIMARY KEY(organization_id, addon_slug))`.
- Keep `school_configuration.capabilities` as **within-plan personalization** (unchanged).
- RLS: org rows readable by that org's tokens (status/plan only); writable **only by platform/superAdmin** (`managePlatformBilling`). Catalog tables: world-readable to authenticated, no tenant writes. Audit via existing `emitMutationAudit`.
- No DELETE needed (status flips); follows `erp_tenant`-no-DELETE rule.

## 6. API impact

**New routes**
- `GET /billing/plans` — public catalog (plans + entitlements + addons).
- `GET /billing/subscription` — current org's plan, status, resolved entitlements, limits, usage (student/school counts vs slab). Drives client gating.
- `PUT /platform/organizations/{id}/subscription` — assign/change plan, slab, status, overrides. **`managePlatformBilling` (superAdmin) only**; audited.
- `POST /platform/organizations/{id}/addons` — attach/detach addon (superAdmin; audited).

**Modified**
- `GET /school-config` → also returns **resolved effective capabilities** (plan ∩ config) + plan summary, so the client gates against entitlement, not raw config.
- Gated module routers (transport, hostel, library, inventory, alumni, hr, director/control-center) → add shared `requireEntitlement("module.X")` guard returning `402 PLAN_UPGRADE_REQUIRED` (distinct from `403` RBAC). One reusable helper in `_shared/entitlements/`.
- Limit checks (`limit.students`, `limit.schools`) enforced on the create paths that grow counts (enrollment, school creation) with grace-buffer per addendum §5.

**New permissions:** `managePlatformBilling` (superAdmin), `viewSubscription` (org admins).

## 7. UI impact

- **Plan badge** on Management dashboard + Settings (plan name, status, renewal/trial date).
- **Plans & Billing screen** (org admin, read-only): current plan, included modules, usage vs limits, **"Upgrade" CTA → wa.me deep-link to sales** (reuse `WhatsAppContactButton`/`whatsapp_launcher`). No in-app payment in B2.
- **Locked module states:** instead of silently hiding, gated-but-unavailable modules/KPIs show a lock + "Upgrade to unlock" (config: hide-vs-lock toggle). Reuses `SchoolCapabilityRegistry` with the effective entitlement.
- **School Discovery wizard:** modules outside the plan render locked/disabled with an upgrade hint; toggles only operate within the plan ceiling.
- **Copilot:** `CopilotCapabilityFilter` disabled-topic message extended to plan-locked topics ("That module isn't in your current plan").
- **Platform/superAdmin:** assign-plan screen (in Control Center / Director platform area) to set org plan/slab/addons/overrides.

## 8. Tests

- **Unit (Dart):** entitlement resolution (plan ∪ addons ∪ overrides ∩ config); `effectiveCapability` truth table; locked-vs-enabled registry output per plan; slab/limit math + grace.
- **Backend (Deno):** plan/entitlement seed integrity; `organization_subscriptions` RLS (org reads own, cannot write); `PUT subscription` rejects non-superAdmin (403) and is audited; `requireEntitlement` returns 402 on a Standard org hitting `module.transport`, 200 after upgrade; limit enforcement at slab cap + grace.
- **Contract:** new routes against the OpenAPI/contract suite; school-config GET now carries resolved entitlements.
- **Widget:** plan badge; locked module tile + upgrade CTA fires wa.me intent; wizard respects ceiling.
- **Integration / E2E (mock):** assign Standard → transport locked → upgrade to Professional → transport unlocked, all live-scoped.
- **Live cert (VPS):** smoke `scripts/capability_gating_b2_smoke.sh` (to be authored): superAdmin assigns plan → org GET subscription reflects it → gated module 402 then 200 after upgrade → RBAC/RLS negatives → audit rows present. Mirrors the B1 smoke pattern.

## 9. Agent split (for when execution starts — NOT now)

Parallelizable workstreams, each finishing with its own analyze/test gate:
1. **Data model & seed** — 2 additive migrations (catalog + org subscription/addons) + Standard/Professional/Enterprise/trial seed + entitlement rows. *(blocks 2–4)*
2. **Backend entitlements + enforcement** — resolution service, `GET /billing/*`, `PUT /platform/.../subscription`, reusable `requireEntitlement` guard wired into gated routers + limit checks; audit + RBAC (`managePlatformBilling`).
3. **Client entitlement layer** — entitlement provider (extend school-config fetch), `SchoolCapabilityRegistry` reads effective entitlement, hybrid cache; capability resolution unit tests.
4. **UI** — plan badge, Plans & Billing screen + wa.me upgrade CTA, locked module/KPI states, wizard ceiling, copilot message; superAdmin assign-plan screen.
5. **Tests & live cert** — contract/integration/E2E + the VPS smoke; certification doc.

> Sequencing: 1 → (2 ∥ 3) → 4 → 5. Reuse existing Approvals/Audit/RBAC/WhatsApp; do not
> rebuild the capability engine — extend it. Keep migrations additive.

## 10. Open decisions for the owner (before execution)

- Final plan **names**, **annual prices** (`base_price_paise`), and **student slabs**.
- Exact module split per tier (the §4 matrix is a proposal).
- Trial length (`trial_ends_at`) and grace-buffer percent.
- Locked-module UX: **hide** vs **show-locked-with-upgrade** (recommend show-locked for sales).
- Whether AI predictions / API access / white-label are tier-included or addons.
