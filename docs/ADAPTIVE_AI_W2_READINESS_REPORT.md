# Adaptive AI — W2 (P3-AI-2) Implementation Readiness Report

**Date:** 2026-07-10 · **Scope:** Adaptive Intelligence Layer (W2.0–W2.9) · **Standard:** `docs/design/adaptive-ai/` 01–09
**Method:** design re-read (00–04, 07, 09) → W1 cert review → 3 parallel read-only codebase audits (backend intelligence services · Flutter copilot/persona/dashboard · scheduling/notification/worklists) → source-level verification of the reuse surface.
**Baseline:** W1 (P3-AI-1) is **PASS / implementation-complete** (`ADAPTIVE_AI_W1_CERTIFICATION_REPORT.md`). AI+copilot backend regression **119/0** confirmed at report time.

> **Purpose.** Establish what W2 can reuse, what is genuinely missing, what is buildable immediately
> (deterministic-first, no owner gate), and what is owner/ops-gated — then sequence the build.
> **No architecture is redesigned; the design suite and roadmap are authoritative.**

---

## 1. Headline

W2 is **substantially unblocked and largely buildable now.** The W1 foundation (Model Gateway,
governance, cache, Signal Refinery, memory schema) is production-grade, and — critically — the W2
*substrate tables already exist and are RLS-covered but carry **zero application code**:
`ai_school_profile.learned_thresholds`, `ai_persona_memory` (`preferences`,
`recommendation_feedback`, `usage_stats`), and `ai_fact_signals`. The design's most valuable W2
deliverable — the **deterministic Priority + Recommendation engine (W2.0)** — is **pure Tier-1
(zero model calls)** and can be computed live from existing ERP data; it does **not** depend on the
owner-gated scheduler. The scheduling-dependent items (pre-warmed briefs/digests/pulse, W2.1/W2.4)
are the ones that inherit the existing COM-4-style ops gate.

**Recommended first build: W2.0 Priority Engine → Recommendation Engine.** Everything else composes
on top of it.

---

## 2. Reuse inventory (what NOT to rebuild)

| Asset | Path | W2 role |
|---|---|---|
| **Signal Refinery + `ai_fact_signals`** | `_shared/ai/signal_refinery.ts`, `ai_fact_signals_repository.ts` | Event→freshness + cache invalidation done. **Gap:** only single-key `getFactSignal` — no list/range read API (feed needs one). |
| **`ai_school_profile` / `ai_persona_memory`** | mig `20260868…` | **Dormant schema, RLS-covered, zero app code.** The learned-weights + persona-feedback substrate — activate, don't migrate. |
| **Predictions (3 scorers)** | `_shared/predictions/predictions_service.ts` | Fee-default · admission-conversion · student-risk — deterministic, routed. Wrap as Priority Engine item generators. |
| **`student_risk_engine`** | `_shared/intelligence/student_risk_engine.ts` | At-risk exceptions/opportunities. |
| **Fee-Recovery CRM (FIN-R1..R7)** | `_shared/finance/finance_recovery_*` | **Best worklist precedent in repo.** `callQueuePriority`/`callQueueReason` ≈ doc-04 §3.2 scoring shape — generalize it. |
| **Analytics bundle + recs** | `_shared/analytics/analytics_recommendations.ts` | Threshold→typed-rec precedent (prose only; add action payload). |
| **Principal command** | `_shared/principal_command/principal_command_service.ts` | `priorityEngineScore` + `topPriorities[]` = closest existing "priority engine" analog (ad hoc, 4 categories, not persisted). |
| **`principal_query_service`** | `_shared/intelligence/principal_query_service.ts` | Keyword NL→intent classifier — seed for per-persona intent routers. |
| **Parent / exam intelligence** | `_shared/parent_insights/*`, `_shared/intelligence/exam_intelligence_service.ts` | Parent deadline/opportunity items; exam signals. |
| **`operations_hub_item_actions`** | mig `20260865…` | Generic dismiss/complete persistence `(item_type,item_id,occurrence_date)` — pattern for per-item dismiss/snooze. |
| **Widget Platform** | `_shared/widget_platform/*`, `dashboard_layouts` | Implements the `defaults(role,pack) ∩ capabilities(school)` half of doc-04 §5. Add priority-strip/reorder/decay on top. |
| **XCT-2 rail** | `_shared/reminders/reminders_service.ts` → `communication_service.ts` | `scheduleReminder`/`runDueReminders`; 4 modules already ride it (EXM-6, TRN-8, LIB-5, INV-7). **Staged, owner-gated cron.** |
| **Parent-comms catalog** | `_shared/communication/parent_comms_localization.ts` | 3 scenarios × 7 languages, deterministic. Extend the `CATALOG` map (no schema change). |
| **Route pattern** | `api/app.ts` `moduleRouters[]` | New route = `<module>_router.ts` + `_handlers.ts` + one line in `app.ts` (or extend `intelligence_router.ts`). |
| **Flutter reuse** | `intelligence/unified/unified_recommendation_intelligence.dart`, `AksharaAiSuggestionBar`, `dynamic_widgets/`, `copilotPersonaForErpRole` | Client-side priority aggregator (principal-only today) · suggestion chrome · orphaned per-role composition engine · canonical persona resolver. |

---

## 3. Gap analysis (what W2 must build)

| # | Missing | Buildable now? | Notes |
|---|---|---|---|
| G1 | **Unified typed `priority_item` taxonomy + explainable scorer + per-persona feed** (doc 04 §3) | ✅ **Yes** | Pure T1. Consolidates ~5 siloed per-module priority lists. **Keystone.** |
| G2 | **Recommendation Engine** = item + pre-staged one-click action + accept/dismiss/snooze learning (doc 04 §4) | ✅ **Yes** | Activates `ai_persona_memory`. Pure T1. |
| G3 | **`ai_fact_signals` list/range read API** | ✅ Yes | Small repository addition; lets the feed read cached signals vs recompute. |
| G4 | **Learned per-school thresholds/weights app code** (doc 03 §2.5) | ✅ Yes | Schema dormant; deterministic nightly stats — compute-on-read acceptable interim. |
| G5 | **Digest / brief / pulse generation** (W2.1/W2.4) | ⚠️ Logic yes, **auto-fire ops-gated** | Only on-demand pull compute exists. Build generation + endpoint; scheduled pre-warm inherits COM-4 gate. |
| G6 | **Adaptive dashboard priority-strip / reorder / decay** (doc 04 §5) | ✅ Yes | Extends widget platform; ≤1 organic move/day, badged. |
| G7 | **Client: persona-aware feed on every home screen** | ✅ Yes | Promote the client aggregator from principal-only; render via `AksharaAiSuggestionBar`/priority strip. |
| G8 | **Persona intent routers (Teacher/Parent/…) T1 coverage** (doc 07) | ✅ Yes | Extend `principal_query_service` pattern per persona. |

---

## 4. Blockers & owner/ops gates (not code)

1. **Scheduler activation (owner).** The XCT-2 comms cron is **staged, not active** (`INTERNAL_CRON_TOKEN` unset on the live edge container — COM-4 runbook). The **`domain-events` drain has no cron at all** (not even staged) — Signal Refinery only runs when `POST /domain-events/process-pending` is called. → **W2 code that computes live is unaffected**; anything relying on *auto-fresh signals* or *scheduled pre-warm* is ops-gated. **Mitigation:** the Priority Engine computes from source tables live, so it is correct even with a cold signal cache; the drain-cron endpoint can be built (auto-fire owner-gated, exactly like COM-4).
2. **External channels (owner).** SMS/push/WhatsApp default to stub; real off-app delivery needs provider credentials. In-app delivery is live now.
3. **Live isolation-probe run + drain scheduling (owner/VPS).** Inherited from W1 §5 — standing VPS cert steps, not W2 code.

**None of the above blocks the W2.0 keystone.**

---

## 5. Build sequence (each phase: compile → test → regress → commit → checkpoint)

- **Phase 1 — W2.0a Priority Engine core.** Typed taxonomy (`approval|deadline|exception|follow-up|opportunity`), explainable scorer (`urgency × impact × age_boost × learned_weight`, factor breakdown exposed), per-persona feed, item generators wrapping existing deterministic sources, `GET /intelligence/priorities`. Pure T1, no migration, default weights. **[keystone]**
- **Phase 2 — W2.0b Recommendation Engine + learning.** Pre-staged one-click action registry (deep-link + payload; human confirms, AI never executes), accept/dismiss/snooze via `ai_persona_memory` (activate dormant schema), learned weights feed back into the Phase-1 scorer. `GET /intelligence/recommendations`, `POST …/feedback`.
- **Phase 3 — Signal read API + learned thresholds.** `ai_fact_signals` list/range reads; per-school learned-threshold compute (`ai_school_profile.learned_thresholds`) with evidence; feed reads signals where fresh.
- **Phase 4 — Adaptive dashboard + client wiring.** Priority strip on the widget platform (bounded reorder/decay, badged); Flutter home-screen feed via `AksharaAiSuggestionBar`; consolidate the 3 persona enums.
- **Phase 5+ — Persona rollouts (Teacher → Parent → Principal → Director → Student)** and W2.1 brief/digest logic (auto-fire ops-gated), W2.7 worklist unification, W2.9 truth-in-naming.

**Rails (doc 01 §6, non-negotiable):** no AI on writes/money/approvals; deterministic-first; RLS-scoped memory/cache; every model call logged/capped/timeout-fallbacked; explainability everywhere. W2.0–W2.4 as sequenced are **zero-model-call**.

---

*One standard, one gate: the Constitution + `/eos` decide "done" per phase.*
