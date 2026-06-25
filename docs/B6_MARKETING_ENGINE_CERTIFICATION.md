# B6 — Marketing Engine MVP · Production Certification

**Date:** 2026-06-25 · **Status:** ✅ PRODUCTION CERTIFIED (live on VPS, real auth + real prod DB)
**Scope (roadmap):** Marketing Engine MVP — lead capture · campaigns (on the live growth
platform) · source attribution → Admissions CRM handoff.

---

## 1. What B6 found (targeted gap-check, not a repo audit)

The growth/marketing engine was **~70% built** but **invisible and half-wired**:

| # | Gap | Evidence |
|---|-----|----------|
| G1 | **Surface hidden.** `RouteNames.growthPlatform` was in `SchoolBuildScope.hiddenRoutePrefixes` — invisible in the school build (like `parentInsights` pre-B3). No nav entry. | `school_build_scope.dart` |
| G2 | **Broken client↔backend contract (404 live).** The campaigns UI called `POST /growth/campaigns/:id/pause`, `PUT /growth/campaigns/:id`, and `GET /growth/campaigns/history` — **none existed** (live probe: `…/pause` → 404). Pause/Activate were dead buttons. | `growth_platform_screen.dart:150-155`, `growth_router.ts` |
| G3 | **Data loss on create.** The create dialog sent `audience` + `scheduledAt`; the backend dropped them (no columns). | create handler |
| G4 | **Not entitlement-gated (B2 inconsistency).** `routeGrowth` had no `withEntitlement`; no `module.marketing` capability existed. | `api/index.ts:112` |
| G5 | **Never B6-certified.** Deployed but no batch smoke/cert. | — |

## 2. What B6 shipped

**Backend** (`supabase/functions/_shared/growth/*`, `audit/mutation_audit_catalog.ts`, `api/index.ts`):
- New routes: `PUT /growth/campaigns/:id` (partial update), `POST /growth/campaigns/:id/pause`,
  `GET /growth/campaigns/history` — all return the full campaign in the shape the Flutter
  mapper expects. Create + list now persist/return `audience` + `scheduledAt`.
- New audit specs `growthCampaignUpdated` / `growthCampaignPaused`; both are repeatable, so the
  outbox idempotency key is suffixed with the row's post-update `updated_at` (no dedup of real edits).
- `routeGrowth` now wrapped with `withEntitlement("/growth", "module.marketing")` — B2-consistent.

**Migration** `20260719000000_growth_marketing_completion.sql`:
- `growth_campaigns` += `audience TEXT DEFAULT 'all'`, `scheduled_at TIMESTAMPTZ`.
- `plan_entitlements` += `module.marketing` for **Professional** + **Enterprise** (pilot is Professional → inherits it).

**Client**:
- Un-hid `growthPlatform`; added an `AdminModule.marketing` nav tile → `/growth` (label "Marketing",
  `viewGrowthPlatform`), wired into the School-Administration + Front-Office workspaces.
- Marketing plan-lock resolves from the entitlement set directly (`module.marketing`) — it is **not**
  one of the 8 `SchoolCapabilities` flags, so the certified B2 resolver/model were left untouched.
  The route is wrapped in `EntitlementModuleGate` (locked → upgrade view; server also enforces 402).

## 3. Live certification (VPS — real auth + real prod DB)

`scripts/marketing_engine_b6_smoke.sh` against `https://akshara.veloraunisexsalon.com` → **13/13 PASS**:

1. admin login · 2. create campaign (audience + scheduledAt) · 3. list round-trips both fields ·
4. pause → `paused` · 5. reactivate via PUT → `active` · 6. history GET 200 · 7. create inquiry
(lead capture) · 8. list inquiries · 9. convert → CRM lead · 10. converted lead present in the
Admissions CRM **with source attribution** · 11. funnel exposes source + campaign attribution ·
12. dashboard 200 (**entitlement allowed — pilot Professional**) · 13. parent denied managing growth (**403**).

**Audit verified live** (last 10 min): `audit_events` recorded `growthCampaignCreated/Updated/Paused`,
`growthInquiryCreated/Converted`; `domain_events` recorded `growth.campaign.created/updated/paused`
(separate update vs pause events — version-keyed idempotency works).

**Deploy:** migration applied to `akshara_db` + recorded in `schema_migrations`; 4 edge files
(`growth_handlers.ts`, `growth_router.ts`, `mutation_audit_catalog.ts`, `api/index.ts`) rsynced to
`/opt/akshara/functions/`; edge recreated. Previously-404 `…/pause` + `…/history` now return 401 (live, auth-gated).

**Tests:** `flutter analyze` clean; new `marketing_module_gating_test.dart` 4/4; updated
`school_build_scope_test` + `admin_navigation_provider_test`; backend `deno check` clean +
`deno test _shared/{entitlements,audit}` green.

## 4. Known / flagged (not B6 app scope)

- **⚠️ VPS postgres healthcheck is broken (pre-existing infra).** The compose healthcheck runs
  `pg_isready` with a malformed `-d` (no argument) → the container reports **unhealthy** even though
  the DB serves normally. Because `akshara-edge depends_on: service_healthy`, a
  `docker compose up --force-recreate akshara-edge` leaves the edge stuck in `Created`. **Workaround
  used:** `docker start akshara-edge` (the DB is up; edge connects fine). **Owner action:** fix the
  `pg_isready` healthcheck (`-d akshara_db`) in `docker-compose.akshara.yml` so future deploys don't stall.
- **Golden:** the `dark_admin_hub` dark-mode golden has an expected pixel delta (the new Marketing
  tile in the admin hub grid). Goldens are Linux-baked; regenerate on the CI runner via
  `flutter test --update-goldens test/golden/dark_mode_render_test.dart`. (Pre-existing parent-dashboard
  / SIS test failures on macOS are platform/data, unrelated to B6.)
- Out of MVP scope (full Marketing SRS MK-01→MK-10): AI Poster Studio, social publishing, content
  planner, WhatsApp automation templates, referrals — deferred; not part of the B6 MVP slice.

**Next P1:** none — B6 was the last P1 item. Next is **B7** (AI School Builder, P2) — not started here.
