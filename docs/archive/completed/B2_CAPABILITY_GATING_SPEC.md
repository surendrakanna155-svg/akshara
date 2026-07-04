# B2 — Capability Gating → Entitlement Layer · Gap Report & Execution Spec

**Status:** SPEC ONLY — no code. Execution begins only after **B1 is production-certified on the VPS**.
**Roadmap:** P1 "quick win — finalize tier/package definitions → tiered entitlements live".
**Aligns with:** `docs/Releases/v6.1-SaaS-Platform-Addendum.md` (subscription/entitlement design).
B2 implements the **entitlement-layer MVP slice** of that design — **not a billing platform**.

---

## 0. APPROVED SCOPE (locked 2026-06-24 by owner)

**B2 is an entitlement layer only.** Plans: **Trial · Standard · Professional · Enterprise**.
Names, prices, limits and entitlements are stored **entirely in the database** (data-driven —
changing them is data, never code).

**Pilot posture:** new organizations **default to Trial**; **no** payment collection, **no**
invoicing, **no** renewal workflows.

**B2 includes exactly these six:**
1. Plan catalog
2. Organization subscription assignment
3. Entitlement resolution
4. Server-side enforcement
5. Locked / upgrade UX
6. Audit trail

**B2 explicitly EXCLUDES** (do not expand into): billing, MRR, renewals, payment gateways,
dedicated databases, white-label automation, priced addons. (These remain P2–P3 / owner-gated.)

**Locked rules honoured:** WhatsApp = wa.me only ("contact sales / upgrade" deep-link, no Meta
API, no in-app payment); reuse Approvals/Audit/RBAC/WhatsApp; extend the existing capability
engine, don't rebuild; migrations additive.

---

## 1. Current state (what's already live — the "~85%")

| Layer | What exists | Evidence |
|---|---|---|
| Capability model | `SchoolCapabilities` — 8 flags: transport, hostel, library, inventory, alumni, hrPayroll, multiBranch, trustOrganization (defaults: 6 ops ON, multiBranch/trust OFF) | `lib/core/school_config/school_configuration_models.dart` |
| Gating engine | `SchoolCapabilityRegistry` gates admin modules, KPIs, copilot topics, `enabledModuleIds`; `CopilotCapabilityFilter` blocks copilot Q&A on disabled topics | `lib/core/school_config/school_capability_registry.dart`, `lib/features/copilot/copilot_capability_filter.dart` |
| Persistence | `school_configuration` table — 1 row/school, JSONB `capabilities` + school_type/curriculum/operations_model/branch_count; FORCE RLS school-scope; `erp_tenant` grants | migration `20260714000000_school_configuration.sql` |
| Backend API | `GET`/`PUT /school-config`; reads gate on `viewSchoolSetup`, writes on `manageSchoolSetup` | `supabase/functions/_shared/school_config/*` |
| Client wiring | `SchoolConfigurationNotifier` — hybrid in-memory → SharedPreferences cache → tenant-authoritative API when `SCHOOL_CONFIG_API_ENABLED`; optimistic writes | `lib/core/school_config/school_configuration_provider.dart` |
| UI | Smart School Discovery wizard (pick type/curriculum/ops + toggle modules) | `lib/features/school_config/school_discovery_screen.dart` |
| Industry layer | `IndustryCapabilityRegistry` maps industry → modules/widget-pack/copilot key (vertical scaffolding, not entitlements) | `lib/core/industry/industry_capability_registry.dart` |

**In one line:** the gating *mechanism* is live, but it is **self-service personalization** —
driven entirely by the school's own toggles, with no plan tying capabilities to an entitlement.

## 2. Remaining gaps (the real B2)

No commercial entitlement layer exists. Confirmed: no plan/subscription concept anywhere in
`lib/`, `supabase/`, or config (only the v6.1 addendum *design*).

| # | Gap | Today | Needed |
|---|---|---|---|
| G1 | **Plan catalog** | none | `subscription_plans` + `plan_entitlements` (trial/standard/professional/enterprise), DB-seeded, data-driven |
| G2 | **Org → plan assignment** | none | `organization_subscriptions`; new orgs default to Trial; reassignable by platform/superAdmin only |
| G3 | **Entitlement resolution** | school freely toggles any flag | effective = (plan entitlements ∪ enterprise `overrides`) **∩** school self-config |
| G4 | **Server-side enforcement** | module routes check only RBAC | shared `requireEntitlement(slug)` guard on gated module routes (defense-in-depth) |
| G5 | **Limits** | none | per-plan `limit.students` / `limit.schools` (data-driven slab) + grace buffer |
| G6 | **Locked/upgrade UX** | disabled modules hidden | lock chips + "Upgrade" CTA (wa.me to sales, no payment); plan badge; plan/entitlements screen |
| G7 | **Audit** | config writes audited | plan assign/change/override audited (`subscriptionPlanAssigned`, `subscriptionOverrideApplied`) |

## 3. Plan model (4 plans; ALL values live in the DB — illustrative only here)

Annual reference only; **no payment is collected in B2**. Prices/slabs/module-splits are data
the owner edits in `subscription_plans` / `plan_entitlements` — engineering reads them.

| Plan (`slug`) | tier_rank | Target | Student slab (data) | Max schools (data) | Notes |
|---|---|---|---|---|---|
| **Trial** (`trial`) | 0 | New pilots (**default for all new orgs**) | 0–100 | 1 | time-boxed `trial_ends_at`; Standard-equivalent entitlements |
| **Standard** (`standard`) | 1 | Single school | 0–500 | 1 | core modules |
| **Professional** (`professional`) | 2 | Growing / multi-school | slab-tiered | up to 5 | + ops modules + multiBranch + parent insights |
| **Enterprise** (`enterprise`) | 3 | Large groups / trusts | custom | unlimited (contract) | + trustOrganization; per-deal `overrides` JSONB |

## 4. Feature gating matrix (entitlement slug → plan)

Slugs follow addendum §6.3 (`module.*`, `feature.*`, `limit.*`). Maps onto the existing
`SchoolCapabilities` flags so the gating engine is reused, not replaced. The matrix below is the
**seed proposal**; the authoritative copy lives in `plan_entitlements`.

| Entitlement slug | Maps to flag / surface | Trial | Standard | Professional | Enterprise |
|---|---|:--:|:--:|:--:|:--:|
| `module.admissions/finance/sis/management/attendance/exams` | core | ✅ | ✅ | ✅ | ✅ |
| `module.transport` | `transport` | — | — | ✅ | ✅ |
| `module.hostel` | `hostel` | — | — | ✅ | ✅ |
| `module.library` | `library` | — | — | ✅ | ✅ |
| `module.inventory` | `inventory` | — | — | ✅ | ✅ |
| `module.alumni` | `alumni` | — | — | ✅ | ✅ |
| `module.hr_payroll` | `hrPayroll` | — | — | ✅ | ✅ |
| `module.multi_branch` | `multiBranch` → director/control-center | — | — | ✅ | ✅ |
| `module.trust_org` | `trustOrganization` | — | — | — | ✅ |
| `feature.parent_insights` | parent insights surface | — | — | ✅ | ✅ |
| `feature.ai_predictions` | predictions surface | — | — | — | ✅ (or per-deal override) |
| `limit.students` | slab cap + grace | 100 | 500 | slab | custom |
| `limit.schools` | branch cap | 1 | 1 | 5 | ∞ |

**Resolution rule:** `effectiveCapability(cap) = planAllows(cap) AND schoolConfigEnabled(cap)`.
A school may *narrow* within its plan but can never *exceed* it. (`api_access` / `white_label`
are NOT in B2.)

## 5. Data model (additive migrations; mirrors addendum §6.2, billing fields omitted)

- `subscription_plans(slug PK, name, tier_rank, student_slab_min, student_slab_max, max_schools, grace_buffer_percent, base_price_paise /* display-only, no payment */, is_public, is_active)` — **seeded**, platform-global, read-only to tenants.
- `plan_entitlements(plan_slug FK, entitlement_slug, PRIMARY KEY(plan_slug, entitlement_slug))`.
- `organization_subscriptions(organization_id PK/unique → organizations, plan_slug FK, status CHECK(trial|active|grace|suspended) DEFAULT 'trial', student_slab_max, trial_ends_at, student_count_cached, started_at, assigned_by, overrides JSONB DEFAULT '{}')`.
- **Default-to-Trial:** new orgs get a `trial` row at creation (seed/trigger or org-provisioning path). No subscription row ⇒ treated as Trial (fail-safe).
- Keep `school_configuration.capabilities` as within-plan personalization (unchanged).
- RLS: org row readable by that org's tokens (status/plan only); writable **only by platform/superAdmin** (`managePlatformSubscriptions`). Catalog tables: readable to authenticated, no tenant writes. Audit via existing `emitMutationAudit`.
- No DELETE (status flips only) — follows `erp_tenant`-no-DELETE rule.
- **NOT created in B2:** `subscription_addons`, `organization_subscription_addons`, any invoice/renewal/payment/dedicated-DB tables.

## 6. API impact

**New routes**
- `GET /plans` — public catalog (plans + entitlements).
- `GET /subscription` — current org's plan, status, resolved entitlements, limits, usage (student/school counts vs slab). Drives client gating.
- `PUT /platform/organizations/{id}/subscription` — assign/change plan, slab, status, overrides. **`managePlatformSubscriptions` (superAdmin) only**; audited. (Assignment only — no payment.)

**Modified**
- `GET /school-config` → also returns **resolved effective capabilities** (plan ∩ config) + plan summary, so the client gates against entitlement, not raw config.
- Gated module routers (transport, hostel, library, inventory, alumni, hr, director/control-center) → add shared `requireEntitlement("module.X")` guard returning `402 PLAN_UPGRADE_REQUIRED` (distinct from `403` RBAC). One reusable helper in `_shared/entitlements/`.
- Limit checks (`limit.students`, `limit.schools`) on count-growing create paths (enrollment, school creation) with data-driven grace buffer.

**New permissions:** `managePlatformSubscriptions` (superAdmin), `viewSubscription` (org admins).

## 7. UI impact

- **Plan badge** on Management dashboard + Settings (plan name, status, trial-ends date).
- **Plan & Entitlements screen** (org admin, read-only): current plan, included modules, usage vs limits, **"Upgrade" CTA → wa.me deep-link to sales** (reuse `WhatsAppContactButton`/`whatsapp_launcher`). **No in-app payment, no invoices.**
- **Locked module states:** gated-but-unavailable modules/KPIs show a lock + "Upgrade to unlock" (config: hide-vs-lock). Reuses `SchoolCapabilityRegistry` with the effective entitlement.
- **School Discovery wizard:** modules outside the plan render locked/disabled with an upgrade hint; toggles operate only within the plan ceiling.
- **Copilot:** `CopilotCapabilityFilter` disabled-topic message extended to plan-locked topics.
- **Platform/superAdmin:** assign-plan screen (Control Center / Director area) to set org plan/slab/status/overrides.

## 8. Tests

- **Unit (Dart):** entitlement resolution (plan ∪ overrides ∩ config); `effectiveCapability` truth table; locked-vs-enabled registry output per plan; slab/limit + grace math; no-subscription ⇒ Trial fail-safe.
- **Backend (Deno):** plan/entitlement seed integrity; default-to-Trial on org create; `organization_subscriptions` RLS (org reads own, cannot write); `PUT subscription` rejects non-superAdmin (403) + is audited; `requireEntitlement` returns 402 for Trial/Standard hitting `module.transport`, 200 after upgrade; limit enforcement at slab cap + grace.
- **Contract:** new routes against the OpenAPI/contract suite; school-config GET carries resolved entitlements.
- **Widget:** plan badge; locked module tile + upgrade CTA fires wa.me intent; wizard respects ceiling.
- **Integration / E2E (mock):** assign Standard → transport locked → upgrade to Professional → transport unlocked.
- **Live cert (VPS):** smoke `scripts/capability_gating_b2_smoke.sh` (to author): superAdmin assigns plan → org GET subscription reflects it → gated module 402 then 200 after upgrade → RBAC/RLS negatives → audit rows present. Mirrors the B1 smoke pattern.

## 9. Agent split (for when execution starts — NOT now)

Parallelizable workstreams, each with its own analyze/test gate:
1. **Data model & seed** — 2 additive migrations (catalog + org subscription) + trial/standard/professional/enterprise seed + entitlement rows + default-to-Trial. *(blocks 2–4)*
2. **Backend entitlements + enforcement** — resolution service, `GET /plans|/subscription`, `PUT /platform/.../subscription`, reusable `requireEntitlement` guard wired into gated routers + limit checks; audit + RBAC (`managePlatformSubscriptions`).
3. **Client entitlement layer** — entitlement provider (extend school-config fetch), `SchoolCapabilityRegistry` reads effective entitlement, hybrid cache; resolution unit tests.
4. **UI** — plan badge, Plan & Entitlements screen + wa.me upgrade CTA, locked module/KPI states, wizard ceiling, copilot message; superAdmin assign-plan screen.
5. **Tests & live cert** — contract/integration/E2E + VPS smoke; certification doc.

> Sequencing: 1 → (2 ∥ 3) → 4 → 5. Reuse existing Approvals/Audit/RBAC/WhatsApp; extend the
> capability engine, don't rebuild. Migrations additive.

## 10. Open decisions for the owner (before execution — all data-driven, set in DB)

- Final plan **prices** (`base_price_paise`, display-only) and **student slabs**.
- Exact module split per tier (the §4 matrix is the seed proposal).
- Trial length (`trial_ends_at`) and grace-buffer percent.
- Locked-module UX: **hide** vs **show-locked-with-upgrade** (recommend show-locked for sales).
- Whether `feature.ai_predictions` is Enterprise-included or per-deal override.
