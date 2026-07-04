# B10 — Organization Builder (P3) — Production Certification

**Status:** ✅ PRODUCTION CERTIFIED
**Date:** 2026-06-25
**Branch:** `feature/scope-trim-school-build`
**Cert script:** `scripts/qa/live_cert_b10_organization_builder.py` — **17 PASS / 0 FAIL / 0 BLOCKED**

---

## 1. Scope (roadmap — unchanged)

Roadmap line: *"B10 Organization Builder — backend first, then UI"* (P3, Platform Expansion;
*"needs a backend before meaningful UI"*, ~10% today, OFF in live config). The first P3 item.
Shipped exactly to the frozen Flutter contract — no scope added, no new UI invented.

## 2. Reality vs. the scorecard

The scorecard was right that Org Builder was "backend-less". What it understated: the **entire
Flutter surface already shipped** — hub, 7-step interview wizard, config preview, provisioning
screen, models, mock + API repos, RBAC permissions, chain-gating, and a `ORGANIZATION_BUILDER_API_ENABLED`
dart-define. The six endpoints it calls simply 404'd. So B10 is a pure backend build to a
pre-existing contract + wiring it live.

| Layer | Pre-B10 | B10 action |
|---|---|---|
| Flutter UI + repos + contract test | Fully built (mock-backed) | Unchanged; flipped the API flag on |
| Backend module | None | Built `_shared/organization_builder/` |
| DB | None | New migration (3 tables, perms, RLS, entitlement) |
| Live config | OFF ("would 404") | `ORGANIZATION_BUILDER_API_ENABLED: true` |

## 3. What was built

**Migration `20260727000000_organization_builder.sql`:**
- `org_builder_packs` — vertical-pack **catalog** (reference data), seeded with the four packs
  (school / salon / hospital / restaurant); org-agnostic, read-only to tenants.
- `org_builder_interview_drafts` — one row per interview. **PK is TEXT** because the client
  supplies the draft id (`draft_<ts>`); `answers` + `recommendations` persisted as JSONB.
- `org_builder_provisioning_jobs` — one row per provisioning run, with persisted `steps` and
  `resolved_config` JSONB.
- Permissions `viewOrganizationBuilder` / `manageOrganizationBuilder` (organization scope),
  granted to org/group leadership + super admin.
- Entitlement `feature.organization_builder` → **Enterprise only** (chains/trusts; mirrors
  `module.trust_org` / `feature.ai_predictions`), per-deal override-grantable.
- Org-scope RLS on all three tables (catalog readable by any org-scope caller; stateful tables
  hard-scoped to `organization_id = app_current_tenant_id()` — mirrors the Director portal).

**Backend — new `_shared/organization_builder/` module:**
- `organization_builder_repository.ts` — packs, drafts (create-on-demand, step merge/advance),
  pure `buildPreview` (modules incl. universal-employee/auth/analytics + per-vertical
  roles/widgets/workflows), and **real provisioning** (`provision` — synchronous, persisted,
  six real step outcomes; flips the draft to `provisioned`). No simulated timers.
- `organization_builder_ai.ts` — `recommendForStep` (deterministic baseline + Claude, **safe
  fallback**, PII-locked, stable per-step id).
- `organization_builder_handlers.ts` — auth → RBAC (view/manage) → org-scope → entitlement
  (router) → audit. Reads view-gated, writes manage-gated; provision emits
  `orgBuilder.organization.provisioned`.
- `organization_builder_router.ts` — owns both contract prefixes (`/platform/org-builder/...`
  **and** `/platform/provisioning-jobs/:id`) and **self-enforces** the entitlement once for both
  (a single `withEntitlement` wrapper can only match one prefix).
- Registered plain in `api/index.ts` (entitlement is internal).
- `organization_builder_repository_test.ts` — **3/3** (preview shape, per-vertical config,
  deterministic baseline).

**Flutter:** no code change — flipped `ORGANIZATION_BUILDER_API_ENABLED` to `true` in
`config/live_release.json` (and corrected the header comment). Module stays chain-gated +
Enterprise-entitlement-gated at runtime, so single-school / non-Enterprise pilots never see it.

## 4. Endpoints (frozen contract)

| Method | Path | Gate |
|---|---|---|
| GET | `/platform/org-builder/packs` | view |
| GET | `/platform/org-builder/interview/drafts` | view |
| GET | `/platform/org-builder/interview/drafts/:id` | view (create-on-demand) |
| POST | `/platform/org-builder/interview/drafts/:id/step` | manage (+ real AI rec) |
| POST | `/platform/org-builder/preview` | manage |
| POST | `/platform/org-builder/provision` | manage (audited) |
| GET | `/platform/provisioning-jobs/:id` | view |

All seven are entitlement-gated by `feature.organization_builder` and require organization scope.

## 5. Verification

- Backend: `deno check` clean (module + `api/index.ts`); Deno tests **3/3**.
- Flutter: `flutter analyze` clean; org-builder contract + RBAC + hub + interview tests **9/9**.
- Deploy: migration applied as `supabase_admin` in a single transaction + ledger row; module +
  `api/index.ts` rsynced to `/opt/akshara/functions/`; edge recreated `--no-deps`; `/health` 200.
- **Live cert 17/17** (`live_cert_b10_organization_builder.py`, real VPS + prod DB + org-scope
  JWT minted on the edge):
  - entitlement gate **denies the Professional pilot (402)** → per-deal `overrides.grant` enables it;
  - packs catalog from DB (4); draft create-on-demand; interview step advances with a **real AI
    recommendation** (137-char refined, not the deterministic baseline); reaches
    `ready_for_preview`; preview resolves salon roles + universal-employee module;
  - **real provisioning** completes (6/6 steps), job status persisted, draft flipped to
    `provisioned`, audit row written;
  - RBAC: provision needs manage (403), packs needs view (403), org-scope required (school token
    403), unauth 401;
  - cleanup: override restored to `{}`, cert rows removed.

## 6. Gotchas / notes

- **Draft id is client-supplied TEXT**, not a UUID — the PK and FKs are TEXT; GET draft and
  save-step both create-on-demand (mirrors the prior mock so the existing UI flow works unchanged).
- **Two disjoint path prefixes, one entitlement** → enforced inside the router, not via
  `withEntitlement` (which matches a single prefix). The provisioning-jobs GET would otherwise be
  ungated.
- **Provisioning is real, not a timer** — it resolves + persists the configuration and records
  each step's actual outcome synchronously; wiring it into live tenant creation (creating real
  `organizations`/`schools` rows for a new vertical) is a deliberate later phase, consistent with
  the P3 "backend first" framing — not silently skipped.
- VPS deploy uses the owner's SSH control-master socket; edge recreate uses `--no-deps` to dodge
  the pre-existing-broken postgres healthcheck (see `B6_MARKETING_ENGINE_CERTIFICATION.md` §4).
