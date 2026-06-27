# Onboarding & Dynamic Configuration — Gap Audit

**Date:** 2026-06-27
**Branch:** `feature/scope-trim-school-build`
**Scope (locked):** AI School Builder · Organization Builder · School Onboarding ·
Initial Configuration · Dynamic Module Configuration · Feature Visibility ·
Navigation · Dashboard generation · RBAC generation · Entitlements · School
Settings. **No other modules inspected. No new features. No roadmap change.**

Method: four parallel gap-check agents read the actual edge handlers **and** the
actual Flutter repos/mappers (not assumptions), anchored on the existing
certifications (B2, B7, B10, B11) — certified-and-unchanged areas were skipped,
not re-audited. Live backend confirmed reachable on the VPS pilot.

---

## Headline

The individual building blocks are real and already certified in isolation
(B2 capability gating, B7 AI school builder + onboarding, B10 organization
builder, B11 dynamic widgets). What was **never certified end-to-end** is the
*first-time-school experience*: does choosing a school type actually produce the
right ERP, and does turning a module off actually remove it **everywhere**.

That end-to-end view exposes **one systemic root cause** plus a set of surface
gaps that all trace back to it.

### Systemic root cause — "module choice is captured but not wired to the gate"

There are **two independent representations** of "which modules this school has"
and they are not connected:

| Representation | Written by | Read by the runtime gate? |
|----------------|-----------|---------------------------|
| `schools.settings.startupOnboarding.modules_enabled` | Onboarding go-live (`startup_onboarding_provision_service.ts:60-83`) | **No — read by nobody** |
| `school_configuration.capabilities` (the 8 flags) | School Discovery wizard (B2) | **Yes** — nav, route guard, dashboard adapter, AI copilot all gate on it |

Onboarding writes the first; the entire gating engine reads the second.
**Result:** the founder's module selection during onboarding has *no* runtime
effect. A school that "didn't pick Transport" still gets Transport everywhere,
because the gate reads `school_configuration.capabilities`, which onboarding
never populates (defaults = all optional modules ON).

Every onboarding/dynamic-config gap below is either this disconnect or a surface
that forgot to read the resolved capability.

---

## Confirmed gaps (prioritized)

### G1 — [High] Onboarding module/facility choice never reaches the runtime gate
- **Evidence:** `startup_onboarding_provision_service.ts:60-83` writes
  `modules_enabled` only into `schools.settings`; `grep modules_enabled` across
  the gating engine, nav, widgets = 0 reads. Gating reads
  `school_configuration.capabilities` (`entitlement_resolver.ts:107-115`,
  `admin_navigation_provider.dart:239-251`).
- **Impact:** module selection at onboarding is cosmetic; wrong ERP per school type.
- **Fix direction:** on go-live, translate the selected modules/facilities into
  the 8 `school_configuration.capabilities` flags and upsert the
  `school_configuration` row, so the founder's choice drives the gate.

### G2 — [High] Onboarding brief UI never collects facilities
- **Evidence:** brief sheet `unified_onboarding_flow_screen.dart:540-548`
  collects 7 fields and never sets `interestedModules`/`languages`, although the
  engine already keys modules + fee categories off them
  (`ai_school_builder_service.ts:142-161`).
- **Impact:** the only path to Transport/Hostel is `schoolType==residential`;
  Library/Inventory fee categories + non-English default are unreachable from the
  UI. A day school with a library gets a generic proposal.
- **Fix direction:** add a facilities multi-select (+ optional language) to the
  brief sheet → `interestedModules`/`languages`. No backend change.

### G3 — [High] Backend does not enforce *school-disabled* modules (only plan-locked)
- **Evidence:** `entitlement_middleware.ts:74` enforces `resolved.entitlements`
  (plan-allowed) but ignores `resolved.capabilities` (plan ∩ school-config,
  already computed at `entitlement_service.ts:80`). A school that disables
  Transport but whose plan allows it can still `POST /transport` → 200.
- **Impact:** matrix surface 6 (API rejection) fails for the school-disabled case;
  defense-in-depth hole.
- **Fix direction:** in `enforceEntitlement`, when the slug maps to a capability
  flag, also return `403 MODULE_DISABLED` when `capabilities[flag] === false`.
  Keep `402` for the plan-locked case.

### G4 — [High] Organization Builder is unreachable in the live app
- **Evidence:** Org Builder nav + route gate on `claims.isChainOrganization`
  (`chain_scope.dart:62-64`), but **no backend path emits that flag**
  (`grep is_chain|chain_organization supabase/functions` = 0). Both claim
  builders default it to `false` (`auth_claims.dart:144`).
- **Impact:** the certified B10 backend can never be reached by a real
  chain/trust org → the **Multi-school Trust** scenario is dead end-to-end.
- **Fix direction:** backend computes chain status (org has >1 active school, or
  `trustOrganization`/`multiBranch` capability on) and emits it in the login
  `user` payload **and** the JWT claims; map through `AuthUser`→`AuthClaims`.

### G5 — [Medium] Dashboard default layout ignores the school's enabled modules
- **Evidence:** `GET /widgets/layouts/:role` returns
  `packDefaultLayout(role, "school")` (`widget_layout_handlers.ts:34,147`),
  hardcoded pack, never consulting effective capabilities. Partly mitigated by
  per-widget permission filtering (`widget_data_service.hasWidgetAccess`).
- **Impact:** a school without finance/intelligence still gets Fee-Collection /
  Student-Risk widgets on its default dashboard.
- **Fix direction:** filter the returned layout widgets by the school's resolved
  capabilities before returning.

### G6 — [Medium] Global search does not exclude disabled/locked modules
- **Evidence:** `global_search_registry.dart:192` filters by RBAC permission
  only; no capability/plan check. A disabled Inventory still appears in search;
  tapping → `AccessDeniedScreen` (dead link). Matrix surfaces 8 + 10.
- **Fix direction:** pass effective capabilities + plan ceiling into the search
  and drop (or mark-locked) entries whose module is not enabled.

### G7 — [Medium] Notifications inbox not capability-filtered
- **Evidence:** `notifications_provider.dart:121` never consults
  `schoolCapabilitiesProvider`; transport/hostel categories exist
  (`notifications_models.dart:8`). A school that disabled Transport still sees
  Transport notifications. (Impact tempered — push is flag-ready, not fully live.)
- **Fix direction:** map `NotificationCategory` → capability flag, drop disabled
  categories from the visible list.

### G8 — [Medium] Startup go-live provisions no subjects and no syllabus
- **Evidence:** `startup_onboarding_provision_service.ts` creates
  academic-year/classes/sections/fees/branding but (unlike
  `setup_wizard_provision_service.ts`) imports no subjects/syllabus service.
- **Impact:** a school that goes live via the AI builder lands with **zero
  subjects** — teachers can't be assigned, exams/timetable have nothing to hang on.
- **Fix direction:** provision a default subject set (+ syllabus) on go-live;
  converge both onboarding paths on the same end-state.

### G9 — [Medium] Setup-wizard provision has no idempotency guard
- **Evidence:** `setup_wizard_provision_service.ts:39-71` calls
  create-academic-year/class/section with no duplicate handling, unlike the
  startup path which catches `DuplicateClassError`/`DuplicateSectionError`.
- **Impact:** running the wizard twice (or after startup-onboarding) throws
  `SETUP_WIZARD_ERROR 500` mid-write — partial classes inserted, no rollback.
- **Fix direction:** apply the same find-or-create / duplicate-catch pattern.

### G10 — [Medium] Hybrid widget repo silently falls back to in-app mock
- **Evidence:** `hybrid_evolution_repository.dart:249-266` returns the mock
  layout on any exception **or** empty response, with no log/telemetry/degraded
  signal. The dashboard looks alive while showing mock data.
- **Fix direction:** log + surface a degraded-state indicator on fallback
  (render-don't-crash is fine; the silent substitution must be observable).

### G11 — [Medium] Org provisioning never returns the new org/branch ids
- **Evidence:** `provision()` builds `newOrganizationId`/`newBranchId`
  (`organization_builder_repository.ts:564-573`) but the handler returns only the
  job (`organization_builder_handlers.ts:250`) and `resolvedConfig` is the draft
  preview (`:603`). The client can't open the tenant it just created.
- **Fix direction:** surface the created ids on the job/provision response.

### G12 — [Low] School-config save failure is swallowed silently
- **Evidence:** `school_configuration_provider.dart:79-105` optimistically
  applies, PUTs, and on failure `catch (Object)` is silent (`:101-103`) — local
  state diverges from the durable row with no retry/error surface.
- **Fix direction:** surface the failure (or set a pending-sync flag + retry).

---

## Accepted as-is (not defects — documented for honesty)

- **RBAC permissions are not revoked when a module is disabled** (capability and
  RBAC are intentionally separate layers; the route guard composes them, so
  access *is* denied). The only real symptom was search (G6); fixing G6 closes it.
- **AI "interview" is a single static brief form**, not a conversational
  multi-question interview. The FUTURE_VISION doc is explicitly aspirational and
  the B7 cert scopes the full interview as later-phase → **roadmap, not a gap.**
  Recommendation quality is genuinely grounded in real input (board/type/grades/
  size) once G2 feeds facilities in.
- **Vertical-pack (salon/hospital/restaurant) widgets have no data source.**
  Latent only — school is the sole live vertical in the pilot; wiring new
  verticals is net-new scope (roadmap), so the fix is "don't expose dead
  vertical widgets," tracked but out of this certification's pilot path.
- **Dynamic-widget drill-down route guard** — no dead links today (all catalog
  routes are registered); a guard for tenant-overridden layouts is hardening, low.

---

## Verified healthy (no gap — evidence in agent traces)

- Onboarding persistence is real: go-live performs actual inserts into
  `academic_years`, `classes`, `sections`, `fee_structures`, branding.
- Client↔backend contracts match for onboarding, startup, setup-wizard, school
  config, org-builder, widgets (paths + payload + response shapes align;
  camel/snake tolerant mappers).
- Live wiring is real, not mock: `config/live_release.json` enables API mode;
  repos fall back to mock only on genuine `ApiNotConnectedException`.
- RBAC seeding for a new school is real: startup onboarding seeds memberships
  against the global role/permission catalog; org-builder idempotently seeds
  `role_definitions` + `role_permissions` (migration `20260806000010`).
- School Config read/write is durable + RBAC-scoped + RLS-isolated; single-school
  org path works end-to-end.
- Backend already correctly enforces **plan-locked** modules (402) and the
  "show-locked + upgrade CTA" UX is intentional per the B2 cert.

---

## Dynamic-configuration matrix (optional module, DISABLED)

| # | Surface | Before this audit | Root |
|---|---------|-------------------|------|
| 1 | Navigation hidden | ✅ (school-disabled) | reads capabilities |
| 2 | Dashboard widgets hidden | ⚠️ default layout ignores modules | G5 |
| 3 | Reports hidden | ✅ (route-prefix gated) | — |
| 4 | Buttons / tiles hidden | ✅ | — |
| 5 | Permissions removed | accepted as-is (layered) | — |
| 6 | APIs rejected | ❌ school-disabled allowed | G3 |
| 7 | Notifications disabled | ❌ | G7 |
| 8 | Search excludes it | ❌ | G6 |
| 9 | AI ignores it | ✅ | — |
| 10 | No dead links | ⚠️ search → AccessDenied | G6 |

Plus the precondition for the whole matrix to mean anything: **onboarding must
actually set the capabilities** (G1) and the **founder must be able to choose**
(G2).

→ Fix plan in `ONBOARDING_COMPLETION_ROADMAP.md`.
