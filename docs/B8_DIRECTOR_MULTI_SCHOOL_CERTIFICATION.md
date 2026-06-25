# B8 — Director Multi-School (P2) — Production Certification

**Status:** ✅ PRODUCTION CERTIFIED
**Date:** 2026-06-25
**Branch:** `feature/scope-trim-school-build`
**Cert script:** `scripts/qa/live_cert_b8_director_multi_school.py` — **13 PASS / 0 FAIL / 0 BLOCKED**

---

## 1. Scope (roadmap — unchanged)

Roadmap line: *"Director Multi-School — light polish for multi-branch sales"* (P2). The
heavy lifting shipped and was certified in **Batch 6** (live org-wide aggregation, org-scope
RBAC, audit) and dual-track A1 (the `module.multi_branch` entitlement gate). B8 is the
last-mile polish — **no new module, no new screens beyond a metric-input editor, no
migration, no scope expansion.**

## 2. The three gaps closed

Each was a *leak* where a multi-branch buyer saw something fake or empty:

| # | Gap | Fix |
|---|-----|-----|
| **A** | The `director_metric_inputs` table (marketing spend, operating expense, capacity) was **read** by Revenue (expenses/margin), Marketing (spend/CPL/ROI) and Growth (capacity %) but had **no write path** — so those metrics were permanently ₹0 / 0%. | Added `GET /director/metric-inputs` (view-gated) and `POST /director/metric-inputs` (manage-gated, audited, school-ownership-validated, idempotent upsert). Flutter: `DirectorMetricInput`/`Draft` models, a manage-gated metric-input editor sheet on the Revenue screen. |
| **B** | `POST /director/reports/:id/export` only stamped a timestamp and returned a synthetic reference string — **no actual document**. | `buildBoardPack` assembles a real board-pack from live aggregates (KPIs, per-school table, financials, funnel, marketing, compliance, executive summary). The export endpoint returns it; the client renders a real PDF via the existing `AksharaReportExportService` (`buildDirectorBoardPackPdf` → `Printing.sharePdf`). |
| **C** | The "Generate AI Executive Summary" button called a deterministic string template (code comment: *"AI = Batch 8"*) — **not AI**. | `director_ai.ts` `refineExecutiveSummaryWithClaude`: deterministic baseline (every number final) refined by Claude, gated on `resolveAiConfig` / `aiApiKey()`, **safe fallback** to the baseline on any failure (mirrors B3/B7). |

## 3. What was deliberately NOT changed

- The 12 Batch-6 endpoints, org-scope RLS, and the `module.multi_branch` entitlement gate
  (`withEntitlement(routeDirector, "/director", "module.multi_branch")`, Professional+Enterprise) —
  already shipped, untouched.
- No new DB tables / **no migration** — the Batch-6 `director_metric_inputs` table is reused.
- No franchise-onboarding wizard, no new Director sub-modules, no B9 work.

## 4. Files

**Backend (`supabase/functions/_shared/director/`)**
- `director_repository.ts` — `getMetricInputs`, `upsertMetricInput` (ownership-validated), `buildBoardPack`.
- `director_ai.ts` *(new)* — `refineExecutiveSummaryWithClaude` (safe fallback).
- `director_handlers.ts` — `handleMetricInputs`, `handleSaveMetricInput` (422 validation, audit), `handleExportReport` now returns `{reference, document}`, `handleSummary` now real-AI.
- `director_router.ts` — `GET`/`POST /director/metric-inputs` routes.
- `director_repository_test.ts` — **10/10** (metric upsert/list, ownership refusal, board pack, AI safe-fallback).

**Flutter**
- `features/director/director_models.dart` — `DirectorMetricInput`, `DirectorMetricInputDraft`, `DirectorBoardPack`, `DirectorBoardPackKpi`.
- `core/repositories/interfaces/director_repository.dart` — `getMetricInputs`, `saveMetricInput`; `exportReport` now returns `DirectorBoardPack`.
- `core/repositories/api/director/{remote/director_remote_datasource,api_director_repository,hybrid_director_repository}.dart` + `mock/mock_director_repository.dart`.
- `features/director/{director_providers,director_mutations_provider}.dart` — `directorMetricInputsProvider`, `saveMetricInput` (invalidates revenue/marketing/growth/dashboard).
- `features/director/widgets/director_metric_input_editor.dart` *(new)* — the editor sheet.
- `features/director/director_revenue_screen.dart` — "Enter portfolio inputs" (manage-gated); `director_reports_screen.dart` — real PDF export.
- `core/reports/akshara_report_export_service.dart` — `buildDirectorBoardPackPdf` / `shareDirectorBoardPackPdf`.
- `core/testing/qa_test_keys.dart` — `directorManageInputsButton`, `directorMetricInput{SchoolField,SaveButton,SavedSnackbar}`.

## 5. Verification

- **Backend unit:** `deno test director_repository_test.ts` → **10/10**; `deno check` clean on router + `api/index.ts`.
- **Flutter:** `flutter analyze` clean on all touched files; Director widget + RBAC coverage tests pass (19).
- **Deploy:** edge files rsynced to `/opt/akshara/functions/_shared/director/`, edge recreated `--no-deps` (dodges the pre-existing broken postgres healthcheck); boots clean ("Listening on …", no import errors). **No migration.**
- **Live cert (`live_cert_b8_director_multi_school.py`, real VPS / org-JWT / prod DB / RBAC):**

| # | Check | Result |
|---|-------|--------|
| 0 | health | PASS |
| 1 | org-scope JWT minted on edge + accepted by Director | PASS |
| 2 | entitlement: professional grants `module.multi_branch` | PASS |
| 3 | multi-school aggregation (2 schools, 5 KPIs, summary, no PII) | PASS |
| 4 | RBAC — org scope required (school-scope token → 403) | PASS |
| 5 | RBAC — write requires `manageDirectorPortal` (view-only → 403) | PASS |
| 6 | unauthenticated → 401 | PASS |
| 7 | metric-input upsert persists (DB row verified) | PASS |
| 8 | entered inputs reflected in live aggregates (expensesCr=0.2, spend=5 L) | PASS |
| 9 | real board-pack export (KPIs + 2 schools + summary; regen bumped) | PASS |
| 10 | real-AI executive summary (799-char refined narrative) | PASS |
| 11 | input validation (missing schoolId → 422) | PASS |
| 12 | audit row recorded (`director.report.exported`) | PASS |

**Result: 13 PASS / 0 FAIL / 0 BLOCKED.**

## 6. Org-scope token note

Director is organization-scope; the pilot has no seeded org persona, so the cert mints an
`organization`-scope JWT on the edge with the live `JWT_SECRET` (jose, `scope=organization`,
`tenant_id=org`, `school_id=null`, explicit perms) — the same approach Batch 6 used. The `sub`
is a real `users.id` so the export's `generated_by` FK is satisfied.

## 7. Risks / flags

- **Real AI dependency:** the executive summary uses the VPS AI provider (OpenRouter→Claude).
  If the key is unset or the provider is down, it **safely falls back** to the deterministic
  baseline (never errors) — the cert would then mark that single check BLOCKED, not FAIL.
- **Pre-existing VPS postgres healthcheck** (`pg_isready` missing `-d`) can stall
  compose-based edge restarts — always recreate edge with `--no-deps`. See
  `docs/B6_MARKETING_ENGINE_CERTIFICATION.md` §4.
- Cert run leaves one realistic metric-input row in the staging org (SCHOOL_A, 2026-06) —
  staging QA data, non-destructive.
