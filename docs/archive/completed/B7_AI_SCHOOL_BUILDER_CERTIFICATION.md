# B7 — AI School Builder (Phase 1) — Production Certification

**Status:** ✅ PRODUCTION CERTIFIED · **Date:** 2026-06-25 · **Plan tier:** Professional + Enterprise

The first **P2 (Strategic Differentiation)** item. AI pre-fill of a school's
structure/config, built on the already-certified B7 onboarding foundation
(`/onboarding/startup`). A founder gives a short brief; Akshara proposes a
complete, board-appropriate startup configuration — classes, section labels, fee
model + categories, default language, modules — for the admin to review, refine,
and go-live with the existing endpoints. **Non-destructive: the endpoint proposes
only; it never writes.**

## What shipped

### Backend (`supabase/functions/_shared/onboarding/`)
- **`ai_school_builder_service.ts`** — deterministic, board-aware blueprint
  (`buildSchoolBlueprint`). Slices a canonical K-12 grade ladder from the brief's
  range (or school-type default), derives section count from students/sections,
  picks fee categories + modules (residential ⇒ hostel/transport), warns on
  missing required fields and bad teacher–student ratio. **Always succeeds; no LLM.**
- **`ai_school_builder_ai.ts`** — optional Claude refinement
  (`enrichSchoolBlueprintWithClaude`). Mirrors the parent-insights pattern:
  gated on `aiApiKey()`, constrained JSON output, every field re-validated
  (classes must be real grades, fee model from an allowed set, bounded lists),
  and **safe fallback to the deterministic baseline** on no-key/refusal/bad-JSON/error.
- **`ai_school_builder_handlers.ts`** — `POST /onboarding/startup/ai-prefill`
  (RBAC `manageOnboarding` + school scope). Resolves AI config DB-first
  (`resolveAiConfig`), returns `{ proposal, source, rationale, warnings }`.
- Route registered in `onboarding_router.ts`; **entitlement-gated** in
  `api/index.ts` via `withEntitlement(routeOnboarding, "/onboarding/startup/ai-prefill", "feature.ai_school_builder")`
  — only the AI path is gated; the rest of `/onboarding` (the certified
  foundation) passes through untouched.
- **Migration `20260726000000_ai_school_builder_entitlement.sql`** — grants
  `feature.ai_school_builder` to Professional + Enterprise (pilot is Professional).
- Unit tests: `ai_school_builder_service_test.ts` (11) + `ai_school_builder_ai_test.ts` (6) — **17/17**.

### Flutter
- `features/onboarding/ai_school_builder_models.dart` — `SchoolBrief` + `SchoolBlueprintResult`.
- Repository layer: `aiPrefill` on the interface + API/hybrid/mock repos;
  `StartupOnboardingMapper.applyProposal` merges a proposal onto wizard state
  (non-empty fields only — a sparse proposal never wipes entered data).
- Provider: `UnifiedOnboardingNotifier.aiPrefill(brief)` applies + persists the
  proposal so it survives reload, returning the metadata.
- UI: **"AI Quick Setup"** card + brief bottom-sheet on the onboarding flow
  (QA keys `unifiedOnboardingAiPrefillButton` / `…ApplyButton`).
- Tests: `test/features/onboarding/ai_school_builder_test.dart` — **8/8**.

## Deployment (VPS `46.28.44.46`, stack `/opt/akshara`)
1. Migration applied to `akshara_db` (`INSERT 0 2`) + recorded in
   `supabase_migrations.schema_migrations` (version `20260726000000`).
2. `rsync supabase/functions/ → /opt/akshara/functions/`.
3. `docker compose -f docker-compose.akshara.yml up -d --no-deps --force-recreate akshara-edge`
   (`--no-deps` avoids the pre-existing-broken postgres healthcheck).
4. Health 200; edge serving new code.

AI provider on the VPS edge: **OpenRouter** (`AI_PROVIDER=openrouter`, key set,
model defaults to `anthropic/claude-sonnet-4-6`), enforcement on
(`ENTITLEMENT_ENFORCEMENT=true`).

## Live certification — `scripts/qa/live_cert_b7_ai_school_builder.py`
Real VPS + real OTP auth + prod DB + **real AI**. **10 PASS / 0 FAIL / 0 BLOCKED.**

| Check | Result |
|---|---|
| health | PASS (HTTP 200) |
| admin OTP→JWT auth | PASS |
| entitlement: Professional grants AI builder (DB) | PASS (rows=1, pilot_plan=professional) |
| AI pre-fill returns complete, go-live-shaped proposal | PASS (source=**ai**, 5 classes / 4 sections / 5 fee categories) |
| proposal is valid grade structure (range respected) | PASS (Grade 1 → Grade 5) |
| **real AI engaged** (live model refined the proposal) | PASS (`source=ai`) |
| non-destructive (config + DB row count unchanged) | PASS (rows 0→0) |
| entitlement wrapper leaves onboarding foundation intact | PASS (HTTP 200) |
| empty brief → deterministic baseline, never 500 | PASS (HTTP 200, 13 classes) |
| unauthenticated request rejected | PASS (HTTP 401) |

## Notes / scope
- **Phase 1 only** — AI *pre-fills* structure/config on the certified onboarding
  foundation. The full no-touch builder (subjects/timetable/syllabus generation,
  full provisioning automation) is later-phase.
- Safe-by-construction: if the AI provider is ever unavailable, the deterministic
  baseline still returns a complete, valid proposal (verified — empty-brief path).
- Owner-flagged (carried from B6): the VPS postgres healthcheck is
  pre-existing-broken (`pg_isready` missing `-d`); use `--no-deps` on edge restarts.
