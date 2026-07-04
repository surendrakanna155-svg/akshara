# B9 — Advanced AI Predictions (P2) — Production Certification

**Status:** ✅ PRODUCTION CERTIFIED
**Date:** 2026-06-25
**Branch:** `feature/scope-trim-school-build`
**Cert script:** `scripts/qa/live_cert_b9_advanced_ai_predictions.py` — **11 PASS / 0 FAIL / 0 BLOCKED**

---

## 1. Scope (roadmap — unchanged)

Roadmap line: *"Advanced AI Predictions — scope + first model … on real pilot data"* (P2). Shipped
as a single gated product covering the three predictions requested: **fee-default**,
**admission-conversion**, and **student-risk**. This is the deterministic-first "first model" MVP
(scores grounded in real data) plus a real-AI narrative — not a trained ML pipeline.

## 2. Reality vs. the stale scorecard

The scorecard said *"~25–30%, client stub, no backend route."* Verified current state instead:

| Prediction | Pre-B9 reality | B9 action |
|---|---|---|
| **Student-risk** | Already real & live (`_shared/intelligence` — `computeStudentRisk` + `loadStudentSignals` + snapshots + `/intelligence/risk/*`). | **Reused** the engine (no rebuild). |
| **Fee-default** | Flutter mock model only, no backend. | Built deterministic scorer on `finance_invoices`. |
| **Admission-conversion** | Nothing (only an aggregate funnel). | Built per-lead likelihood on the admissions funnel. |

## 3. What was built

**Backend — new `_shared/predictions/` module (no migration):**
- `predictions_service.ts` — `computeFeeDefaultRisk` (outstanding + days overdue), `computeAdmissionConversion` (lead warmth + application progress − staleness decay), `computeStudentRiskList` (reuses `computeStudentRisk`/`loadStudentSignals`), `buildPredictionsBaseline`.
- `predictions_ai.ts` — `narratePredictionsWithClaude` (deterministic baseline + Claude, **safe fallback**, numbers/names locked).
- `predictions_handlers.ts` — three school-scoped read handlers, each gated by its natural domain permission (`viewFinance` / `viewAdmissions` / `viewStudentRisk`) + school-scope check; resolves AI config DB-first.
- `predictions_router.ts` — `GET /predictions/{fee-default,admission-conversion,student-risk}`.
- Registered in `api/index.ts` gated: `withEntitlement(routePredictions, "/predictions", "feature.ai_predictions")`.
- `predictions_service_test.ts` — **4/4**.

**Flutter:**
- `features/predictions/predictions_models.dart`, `predictions_providers.dart`, `predictions_screen.dart` (3 sections + AI narrative cards, client entitlement gate reusing the marketing-style `subscriptionProvider.allows` + `PlanLockedModuleView`).
- Repository: interface + `api`/`mock`/`hybrid` + remote datasource + providers; `PREDICTIONS_API_ENABLED` dart-define.
- Route `/intelligence/predictions` + launch tile on the management intelligence hub.
- QA keys; widget test green.

## 4. Entitlement & RBAC (reused — nothing new defined)

- **Entitlement:** the existing **`feature.ai_predictions`** slug — **Enterprise-only** in the catalog. The Professional pilot is therefore denied by default; access is granted via the existing per-deal **`organization_subscriptions.overrides.grant`** mechanism. The catalog seeding was **not** changed.
- **RBAC:** reused `viewFinance` / `viewAdmissions` / `viewStudentRisk` (all pre-existing). **No new permission slugs, no migration.**

## 5. Verification

- **Backend unit:** `deno test predictions_service_test.ts` → **4/4**; `deno check` clean on router + handlers + `api/index.ts`.
- **Flutter:** `flutter analyze` clean on all B9 files; `PredictionsScreen` widget test green.
- **Deploy:** `_shared/predictions/` + `api/index.ts` rsynced to the VPS, edge recreated `--no-deps`; boots clean (no import errors — the predictions module's `_shared/intelligence` + `_shared/ai` imports resolve live). **No migration.**
- **Live cert (`live_cert_b9_advanced_ai_predictions.py`, real VPS / school-scope JWT / prod DB):**

| # | Check | Result |
|---|-------|--------|
| 0 | health | PASS |
| 1 | entitlement gate **denies the Professional pilot** (402) | PASS |
| 2 | fee-default — real, grounded in finance invoices (1 item) | PASS |
| 3 | admission-conversion — real funnel likelihood (4 leads) | PASS |
| 4 | student-risk — reuses engine, sorted highest-first (4 students) | PASS |
| 5 | real-AI narrative (584-char refined narrative) | PASS |
| 6 | RBAC — fee-default needs `viewFinance` (403 without) | PASS |
| 7 | RBAC — student-risk needs `viewStudentRisk` (403 without) | PASS |
| 8 | unauthenticated → 401 | PASS |
| 9 | school-scope required (org-scope token → 403) | PASS |
| 10 | cleanup — per-deal override restored to `{}` | PASS |

**Result: 11 PASS / 0 FAIL / 0 BLOCKED.**

## 6. Certification approach for an Enterprise-only feature on a Professional pilot

Because `feature.ai_predictions` is Enterprise-only and the pilot org is Professional, the cert
proves the **whole flow**: the gate denies the pilot (402) → a per-deal `overrides.grant`
(the legitimate add-on path) enables it → real predictions return on real data → the override is
**restored to `{}`** at the end (try/finally). The pilot is left in its original Professional state;
enabling predictions for the pilot is a one-line owner action (grant the override).

## 7. Risks / flags

- **Real-AI dependency:** the narrative uses the VPS AI provider (OpenRouter→Claude). If the key is
  unset or the provider is down, it **safely falls back** to the deterministic baseline (never
  errors); the cert would then mark that single check BLOCKED, not FAIL.
- **Deterministic "first model":** scores are transparent heuristics on real signals, not a trained
  model — the intended P2 first step. A learned model is future work (still ~6–10 wk per the scorecard).
- **Pre-existing VPS postgres healthcheck** (`pg_isready` missing `-d`) — always recreate edge with
  `--no-deps`. See `docs/B6_MARKETING_ENGINE_CERTIFICATION.md` §4.
- One pre-existing unused import (`akshara_kpi_card.dart`) remains in the intelligence hub file that
  B9 added a launch tile to — not introduced by B9 (confirmed via git diff); left untouched.
