# Onboarding & Dynamic Configuration — Completion Roadmap

**Date:** 2026-06-27 · **Branch:** `feature/scope-trim-school-build`
**Source of gaps:** `docs/ONBOARDING_DYNAMIC_CONFIGURATION_AUDIT.md`
**Discipline:** completion mode — fix genuine gaps only, no new features, no
roadmap change. Each wave ends green (`flutter analyze` + tests + Deno tests) and
is proven against the live VPS pilot before certification.

The waves are ordered so the **keystone** (onboarding choice → the gate) lands
first, because it is what makes every other dynamic-config fix observable.

---

## Wave 1 — Keystone: onboarding choice drives the gate
*Makes "the right ERP per school type" real and gives the matrix something to enforce.*

| ID | Fix | Files | Layer |
|----|-----|-------|-------|
| G1 | Go-live translates selected modules/facilities → `school_configuration.capabilities` (upsert the row) | `startup_onboarding_provision_service.ts` (+ repo) | Backend |
| G2 | Brief UI collects facilities (+ optional language) → `interestedModules`/`languages` | `unified_onboarding_flow_screen.dart` | Flutter |
| G8 | Go-live provisions a default subject set (+ syllabus) | `startup_onboarding_provision_service.ts` | Backend |
| G9 | Setup-wizard provision becomes idempotent (find-or-create) | `setup_wizard_provision_service.ts` | Backend |

## Wave 2 — Enforce the matrix everywhere a disabled module must vanish
*Closes the surfaces that ignored the resolved capability.*

| ID | Fix | Files | Layer |
|----|-----|-------|-------|
| G3 | Backend rejects school-disabled modules (`403 MODULE_DISABLED`) | `entitlement_middleware.ts` (+ reverse map in resolver) | Backend |
| G5 | Dashboard default layout filtered by effective capabilities | `widget_layout_handlers.ts` | Backend |
| G6 | Global search excludes disabled/locked modules | `global_search_registry.dart` / overlay | Flutter |
| G7 | Notifications inbox filtered by capability | `notifications_provider.dart` | Flutter |

## Wave 3 — Multi-school reachability + honesty polish
*Unblocks the Trust scenario and removes silent failure modes.*

| ID | Fix | Files | Layer |
|----|-----|-------|-------|
| G4 | Emit `isChainOrganization` from backend → map through claims | `auth_handlers.ts` + `auth_provider.dart` / `auth_session_manager.dart` / `auth_claims.dart` | Cross |
| G11 | Provision response surfaces new org/branch ids | `organization_builder_repository.ts` / handlers | Backend |
| G10 | Widget repo logs + signals degraded state on mock fallback | `hybrid_evolution_repository.dart` | Flutter |
| G12 | School-config save failure surfaced (no silent swallow) | `school_configuration_provider.dart` | Flutter |

---

## Out of scope (tracked, not in these waves)
- Conversational AI interview / workspaces (roadmap — B7 later-phase).
- New verticals' widget data sources (net-new scope) — only ensure dead vertical
  widgets aren't exposed in the school pilot.
- RBAC-permission revocation on module disable (layered design; G6 closes the
  only real symptom).

## Verification gate per wave
1. `flutter analyze` → 0 issues
2. `flutter test` (affected suites) green
3. Deno tests for touched backend modules green
4. Deploy backend changes to VPS (`/deploy` recipe)
5. Live cert checks against the VPS pilot (real auth + real DB + real RBAC)

On all waves green + live N/N honest → write
`ONBOARDING_DYNAMIC_CONFIGURATION_CERTIFICATION.md`, update `ProjectStatus.md`,
refresh memory, commit, push.

---

## ✅ COMPLETE — PRODUCTION CERTIFIED (2026-06-27)

All three waves implemented, all 12 gaps (G1–G12) closed. The first real
**go-live** (never executed live before — B7 only certified the propose-only AI
prefill) additionally surfaced **three latent production bugs**, all fixed:

1. `permission denied for table schools` → SECURITY DEFINER
   `onboarding_update_school_profile` (migration `20260813000000`).
2. `syllabus_generations_source_check` violation (`startup_onboarding` → `template`).
3. `finance_fee_structures_status_check` violation (`draft` → `inactive`, both
   onboarding provision paths).

Because the provision runs in one transaction, these motivated the G9
find-or-create idempotency hardening (a caught JS error still aborts the txn).

**Live cert:** `scripts/qa/live_cert_onboarding_dynamic_config.py` → **17/17**
(real auth + DB + RBAC, isolated throwaway school, pilot untouched). Backend Deno
102/102, `flutter analyze` 0, `flutter test` green. See
`ONBOARDING_DYNAMIC_CONFIGURATION_CERTIFICATION.md`.
