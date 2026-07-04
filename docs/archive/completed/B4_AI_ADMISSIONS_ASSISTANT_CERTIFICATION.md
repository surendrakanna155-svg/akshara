# B4 — AI Admissions Assistant · Production Certification

**Date:** 2026-06-25
**Status:** ✅ PRODUCTION CERTIFIED (real auth + production DB + real AI)
**Live edge:** https://akshara.veloraunisexsalon.com
**Branch:** `feature/scope-trim-school-build`
**Migration:** none — B4 reuses the existing B1 CRM tables (no schema change)
**Live smoke:** `scripts/admissions_assistant_b4_smoke.sh` — **8/8 passed**

---

## What B4 delivers

The Copilot `admissions` persona existed but was **blind to its own data** — its
context loaded only a bare lead count + applications-by-status, so it could not
honestly answer "Which leads need follow-up?". B4 grounds the assistant in the
real B1 CRM funnel and adds a deterministic **next-best-action** engine, then
surfaces it both to the live AI and as a premium dashboard card.

### Backend — intelligence core (deterministic, read-only)
- **`admissions_intelligence.ts`** — a pure advisor `buildAdmissionsIntelligence()`
  that turns the funnel snapshot into a compact summary + a ranked, deep-linkable
  list of next-best-actions:
  - `stalled_hot_lead` (urgent, per-lead) — hot leads aging in non-terminal stages
  - `pending_follow_ups` (high) — open rows in `admissions_lead_follow_ups`
  - `unassigned_leads` (high) + per-lead `assign_lead` (deep-linkable)
  - `stage_bottleneck` (medium) — largest early-stage pile-up
  - `warm_leads_cooling` (medium) — warm leads with no movement > 7 days
  - `low_conversion` (low) — conversion insight on a meaningful sample
  - `empty_pipeline` — zero-lead guidance
  - Ranked urgent → high → medium → low, capped at 8.
- **`admissions_intelligence_repository.ts`** — `loadAdmissionsIntelligence()`
  reuses the B1 dashboard aggregation (`getDashboard`) and adds the two missing
  signals (pending follow-ups, unassigned leads + a hot-first sample).
- **Unit tests** — `admissions_intelligence_test.ts` (6 tests): empty pipeline,
  stalled-hot ranking/cap, follow-up + unassigned actions, stage bottleneck,
  priority ranking + cap, top-source summary.

### Backend — persona grounding
- `loadAdmissionsContext` (copilot context engine) now returns the funnel + NBA
  instead of a bare count.
- Prompt orchestrator: new `ADMISSIONS_ASSISTANT_POLICY` (prioritise the NBA in
  order, name specific leads, read-only) + funnel/NBA rendered in the stub.

### Backend — read endpoint
- `GET /admissions/intelligence` → funnel summary + ranked next-best-actions, so
  the app shows the assistant card without a chat round-trip.
- RBAC: `viewAdmissions` + school operational scope (same as the dashboard).
- Audit: emits `aiAdmissionsAssistantViewed` per read.

### App-side (Flutter)
- DTO + mapper + datasource + repository (`getIntelligence`) across the API and
  mock implementations; `admissionsIntelligenceProvider`.
- Premium **"AI Admissions Assistant — Next best actions"** card on the admissions
  dashboard: gradient hero, funnel chips, accent-coded priority tiles with
  deep-links (per-lead → lead detail; aggregate → leads list), and an
  "all caught up" state. Degrades gracefully (renders nothing while loading).
- Widget test `admissions_assistant_card_test.dart` (3 tests).

## Verification

- **Deno:** `admissions_intelligence_test` 6/6 + `_shared/admissions` + `_shared/copilot`
  suites green (12 copilot tests pass with `-A`).
- **Flutter:** `flutter analyze` 0 errors; `admissions_assistant_card_test` 3/3;
  full `test/features/admissions` + contracts **75/75** green.

## Live certification (real VPS)

Deployed by rsync of `_shared/admissions` + `_shared/copilot` to
`/opt/akshara/functions` + `akshara-edge` recreate. `scripts/admissions_assistant_b4_smoke.sh`
against the live edge — **8/8**:

1. admin login (school scope) ✓
2. `GET /admissions/intelligence` → 200 ✓
3. funnel summary complete (totalLeads/hotLeads/conversionRate/pendingFollowUps/unassignedLeads/stageCounts) ✓
4. nextBestActions well-formed (id/kind/priority/title/cta) + correctly ranked + capped ✓
5. copilot `admissions` session created ✓
6. copilot returned a grounded reply — **`stub=false` (real Claude)** ✓
7. parent scope denied `/admissions/intelligence` → **403** ✓

**Live NBA firing on real data (demonstrated + cleaned up):** created one
unassigned lead + one pending follow-up → the endpoint returned
`[high] pending_follow_ups`, `[high] unassigned_leads`, and a deep-linkable
`[medium] assign_lead: Assign owner: B4 Demo Student`, with the funnel updating
to `pendingFollowUps:1, unassignedLeads:1`. Test lead removed afterwards
(cascade) — pilot back to its original 1 lead.

**Audit trail (last 30 min):** `aiAdmissionsAssistantViewed` ×4,
`aiCopilotSessionCreated` ×1, `aiCopilotResponse` ×1.

## Scope / honesty notes

- The NBA engine is **deterministic**; the Copilot reply is **real AI** (Claude)
  grounded in that engine — no fabricated lead numbers.
- Hot-lead aging uses `daysInStage` (from `updated_at`); the `low_conversion`
  insight only fires on ≥10 leads. These paths are covered by unit tests (live
  pilot has too few leads to trigger them naturally).
- No new tables/migrations — fully reuses the B1 CRM schema.

**Next:** B5 — drop `WhatsAppContactButton` into admissions leads / fee
defaulters / transport / vendors / alumni (quick win).
