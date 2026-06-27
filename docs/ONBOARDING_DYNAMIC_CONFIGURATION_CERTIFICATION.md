# Onboarding & Dynamic Configuration — Certification

**Status:** ✅ PRODUCTION CERTIFIED (2026-06-27)
**Branch:** `feature/scope-trim-school-build`
**Roadmap:** Completion-mode certification of the onboarding experience + dynamic
module configuration. Does **not** add features or change the roadmap — it closes
the gaps found in `docs/ONBOARDING_DYNAMIC_CONFIGURATION_AUDIT.md` and proves the
result live.
**Live cert:** `scripts/qa/live_cert_onboarding_dynamic_config.py` — **17/17**
against the VPS pilot (`akshara.veloraunisexsalon.com`), real OTP auth, real DB,
real RBAC.

---

## What this certifies

> Akshara builds the **right ERP for each school**, and **disabling a module
> removes it everywhere** (and re-enabling restores it).

The individual building blocks were already certified in isolation (B2 capability
gating, B7 AI school builder + onboarding, B10 organization builder, B11 dynamic
widgets). What had **never** been certified is the first-time-school flow
end-to-end. Doing so exposed one systemic root cause and several latent bugs in a
code path (startup **go-live** provisioning) that prior certs never executed
live — B7 only certified the propose-only AI prefill.

## Scope & gap (what was actually missing/broken)

Systemic root cause: **the founder's module selection never reached the runtime
gate.** Onboarding wrote `schools.settings.modules_enabled`; the entire gating
engine (nav, routes, dashboards, AI) reads `school_configuration.capabilities`.
The two were unconnected, so module choice had zero runtime effect.

Gaps closed (see audit for evidence):

| ID | Gap | Fix |
|----|-----|-----|
| G1 | Go-live never wrote `school_configuration.capabilities` | Derive the 8 capability flags from the selected modules and upsert the config row on go-live |
| G2 | Onboarding brief UI never collected facilities | Facilities multi-select + language → `interestedModules`/`languages` (backend already honoured them) |
| G3 | Backend enforced only plan-locked modules, not school-disabled | `gateModuleAccess` now returns **403 MODULE_DISABLED** when the plan allows a module the school switched off |
| G4 | Organization Builder unreachable — chain flag never emitted | Backend computes `isChainOrganization` (org runs >1 school) and emits it in the login payload + JWT; client maps it through `AuthClaims` |
| G5 | Dashboard default layout didn't honour disabled modules | Layout GET filters widgets by the school's effective capabilities |
| G6 | Global search showed disabled/locked modules (dead links) | Search filtered by the same `SchoolCapabilityRegistry` the nav uses |
| G7 | Notifications inbox not capability-filtered | Inbox drops disabled optional-module categories |
| G8 | Startup go-live created **no subjects/syllabus** | Provisions a default subject set + syllabus, matching the setup-wizard end-state |
| G9 | Setup-wizard / go-live provision not idempotent | Pre-check **find-or-create** for year/class/section/subject/fee — re-run never aborts the transaction |
| G10 | Widget repo silently served mock on failure | Logs + degraded signal on fallback |
| G11 | Org provisioning didn't return the created tenant ids | `ProvisioningJobView` now surfaces `newOrganizationId`/`newBranchId` |
| G12 | School-config save failure swallowed silently | Failure is logged + surfaced (snackbar) instead of silent divergence |

### Latent bugs found *during* live certification (go-live had never run live)

The first real go-live surfaced three production-breaking defects, all fixed:

1. **`permission denied for table schools`** — the edge `erp_tenant` role has
   SELECT-only on the core `schools` table. Go-live's school-profile write now
   goes through a scoped **SECURITY DEFINER** function
   (`onboarding_update_school_profile`, migration `20260813000000`), the same
   pattern used for every other `erp_tenant`-restricted write.
2. **`syllabus_generations_source_check` violation** — provision passed
   `source: "startup_onboarding"`; the constraint allows
   `wizard|template|clone|manual`. Fixed to `template`.
3. **`finance_fee_structures_status_check` violation** — both onboarding
   provision paths passed `status: "draft"`; the constraint allows
   `active|inactive`. Fixed to `inactive` (the finance module's own default).

Because the whole provision runs in **one transaction**, any one of these PG
errors aborted the transaction and 500'd go-live even though the JS caught it —
which is also why G9's pre-check find-or-create hardening matters.

## What was built

**Backend (Deno edge):**
- `entitlements/entitlement_middleware.ts` — pure `gateModuleAccess` (402 plan /
  403 school-disabled) + `ENTITLEMENT_TO_CAPABILITY` reverse map.
- `onboarding/startup_onboarding_provision_service.ts` — capability derivation +
  upsert (G1), default subjects/syllabus (G8), full find-or-create idempotency
  (G9), SECDEF school-profile write.
- `setup_wizard/setup_wizard_provision_service.ts` — idempotent provision (G9),
  fee status fix.
- `widget_platform/widget_layout_handlers.ts` — capability filter on layout GET (G5).
- `auth_context.ts` / `auth_handlers.ts` / `jwt.ts` — `isChainOrganization`
  resolution + emission in payload and JWT (G4).
- `organization_builder/organization_builder_repository.ts` — created tenant ids
  on the job view (G11).

**Flutter:**
- Onboarding brief facilities/language (G2); global search + notifications
  capability filtering (G6/G7); widget-repo fallback observability (G10);
  school-config save-failure surfacing (G12); `isChainOrganization` mapping
  through `AuthUser`→`AuthClaims` and JWT→`AuthClaims` (G4).

**Migration:** `20260813000000_onboarding_update_school_profile_secdef.sql`
(SECURITY DEFINER `onboarding_update_school_profile`, EXECUTE → `erp_tenant`).
Applied to the live DB and verified (`has_function_privilege` = t).

**Persistence & constraints:** capabilities persist in `school_configuration`
(erp_tenant has INSERT/SELECT/UPDATE). The `schools` write is SECURITY DEFINER
because `erp_tenant` is SELECT-only there (consistent with the no-DELETE/no-write
constraint and `org_builder_provision_tenant`). Provision is idempotent via
pre-check find-or-create — safe under the single transaction.

## Live cert evidence — 17/17

```
0.health                          PASS  HTTP 200
1.auth:admin-otp(scoped)          PASS  HTTP 200
G4.auth-me-chain-flag             PASS  isChainOrganization=True
G4.jwt-chain-claim                PASS  is_chain_organization=True
G2.prefill-honours-facilities     PASS  fees incl transport+library; modules incl transport+library
G1.startup-upsert                 PASS  HTTP 200
G1.go-live                        PASS  provisioned=True
G1.capabilities-applied           PASS  capabilitiesApplied=True
G8.subjects-provisioned           PASS  subjectCount=3 syllabusTopics=9
G1.db-capabilities-match-modules  PASS  transport/library=true; hostel/inventory/alumni=false
G8.db-subjects-exist              PASS  academic_subjects=3
G9.go-live-idempotent             PASS  HTTP 200 (re-run, no abort)
G3.disabled-module-403            PASS  /hostel → 403 MODULE_DISABLED
G3.enabled-module-passes          PASS  /transport → 200
G3.unauth-401                     PASS  HTTP 401
G3.toggle-round-trip              PASS  disable→MODULE_DISABLED ; enable→restored
G5.layout-no-disabled-widget      PASS  no disabled-module widget leaked
```

The cert runs entirely against an **isolated throwaway school** in the pilot org
(one OTP login, self-scrubbing teardown) — the live pilot school is untouched
(verified: school A config unchanged after the run).

## Dynamic-configuration matrix — after certification

| # | Surface | Disabled-module behaviour | Proven by |
|---|---------|---------------------------|-----------|
| 1 | Navigation | hidden | B2 + unchanged |
| 2 | Dashboard widgets | filtered out (G5) | unit + live G5 |
| 3 | Reports | route-prefix gated | B2 |
| 4 | Buttons / tiles | hidden | B2 |
| 5 | Permissions | layered (route-composed); search symptom closed | by design |
| 6 | **APIs rejected** | **403 MODULE_DISABLED** (G3) | **live G3** |
| 7 | Notifications | filtered (G7) | unit |
| 8 | Search | excluded (G6) | unit (G6 test) |
| 9 | AI | ignores | B2 |
| 10 | No dead links | search no longer reaches AccessDenied (G6) | unit |

Precondition now true: onboarding **sets** the capabilities (G1, live) and the
founder can **choose** them (G2, live).

## Quality gates
- `flutter analyze` → 0 issues
- `flutter test` → full suite green
- Deno tests (onboarding, setup_wizard, entitlements, widget_platform,
  organization_builder, jwt, permission) → 102/102, incl. new `gateModuleAccess`
  (G3) and `filterLayoutByCapabilities` (G5) unit tests
- Live cert → 17/17 against the VPS pilot

## Out of scope (tracked, not defects)
- Conversational AI interview / workspaces (B7 later-phase roadmap).
- New verticals' widget data sources (net-new scope).
- RBAC-permission revocation on module disable (layered design; G6 closed the
  only real symptom).
- AI-prefill real-Claude refinement currently falls back to deterministic on the
  pilot because `erp_tenant` lacks read on `platform_provider_configs` — observed
  during cert, **out of this scope** (AI provider config / B8 area); G2's
  deterministic module+fee mapping is what onboarding correctness depends on and
  it is certified.

**Onboarding and dynamic configuration are PRODUCTION CERTIFIED.**
