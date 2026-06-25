# B3 — Parent Insights · Production Certification

**Date:** 2026-06-25
**Status:** ✅ PRODUCTION CERTIFIED (real auth + production DB + real AI)
**Live edge:** https://akshara.veloraunisexsalon.com
**Branch:** `feature/scope-trim-school-build`
**Migration:** `20260725000000_parent_insights_parent_scope_rls.sql` (applied to `akshara_db`)
**Live smoke:** `scripts/parent_insights_b3_smoke.sh` — **13/13 passed**

---

## What B3 delivers

Parent Insights is an AI-generated summary of a child's recent progress
(attendance, homework, strengths, areas to improve, suggestions, teacher
remarks) in the parent's chosen language (English / Hindi / Telugu). The
backend already existed but was **switched off and unreachable**. B3 surfaces
it to parents as a finished, premium feature and closes the backend gaps that
surfacing exposed.

## App-side changes (Flutter)

- **Un-hidden:** removed `parentInsights` from `SchoolBuildScope.hiddenRoutePrefixes`
  (it was blocked as "experimental" → `AccessDeniedScreen` for everyone).
- **Entry points:** added an **Insights** item to the parent "More" tab
  ([parent_shell.dart](../lib/features/parent/shell/parent_shell.dart)) and a
  **Parent Insights** card on the Home dashboard
  ([parent_dashboard_screen.dart](../lib/features/parent/dashboard/parent_dashboard_screen.dart)),
  wired via `parent_insights` nav action.
- **Premium redesign:** gradient hero, sectioned accent-coded insight cards,
  segmented period generation, language switcher — to the approved "School OS"
  design system ([parent_insights_screen.dart](../lib/features/evolution/parent_insights_screen.dart)).
- **Honest actions:** real PDF print/share
  ([parent_insights_pdf_service.dart](../lib/features/evolution/parent_insights_pdf_service.dart),
  reuses the `pdf`/`printing` stack); removed the fake "voice-ready" icon and
  logged read-aloud (TTS) to `IDEAS_BACKLOG.md`.
- **Generation feedback:** in-progress spinner, disabled state, success/error
  toasts; promoted "Generate" to a primary action.
- **Edge cases:** no-child / multi-child handled gracefully; empty state.
- **Test:** [parent_insights_screen_test.dart](../test/features/evolution/parent_insights_screen_test.dart)
  (empty state + generate → premium card render).

## Backend gaps surfacing exposed (all fixed)

1. **Parents were blocked from their own insights.** Handlers required
   `requireSchoolOperationalScope` (scope `school`), but parents authenticate
   with scope `parent`. Added `requireParentInsightsScope` (allows `parent` +
   `school`); per-child authorization is enforced by RLS.
2. **Entitlement resolver couldn't read the org plan under parent scope.**
   `organization_subscriptions` read RLS allowed only org/school scope, so the
   `withEntitlement` wrap resolved parents to *Trial* and wrongly returned
   `402`. Read now allows parent/student (server-side resolution only; the raw
   row never reaches the client).
3. **Per-child RLS was missing.** The original snapshot/language-pref policies
   were school-only and did not scope to the parent's children. Rewrote both to
   the canonical `student_guardians` pattern: a parent touches only snapshots
   for their linked active students, and only their own language rows.
4. **Persona-scope audit/outbox writes failed.** `domain_events` insert policy
   excluded parent scope, and both `audit_events` and `domain_events` used
   `INSERT … RETURNING`, which re-checks the table's **read** policy against the
   new row (correctly excluding persona scopes) and aborted the audited
   mutation. Fixed the `domain_events` insert/update policies and removed the
   unused `RETURNING` from the server-side audit/outbox writes (a server audit
   must not depend on the actor's SELECT RLS). Read policies stay tight (no leak).
5. **Edge entitlement enforcement** added: `withEntitlement(routeParentInsights,
   "/parent-insights", "feature.parent_insights")` (was previously unwrapped).

## Live smoke results (13/13)

`API_BASE_URL=https://akshara.veloraunisexsalon.com scripts/parent_insights_b3_smoke.sh`

- superAdmin login (org scope) · org resolved · parent login · org on Professional
- language preference saved + read (Telugu)
- generated weekly insight (real AI) · listed insights include it · carries Telugu
- entitlement gate: Standard → `402 PLAN_UPGRADE_REQUIRED`; Professional → `201`
- final plan restored to Professional

## Independent verification

- **Audit (atomic):** `audit_events` row `parentInsightGenerated` (role `parent`,
  source `server`) + `domain_events` `parent_insights.snapshot.generated`
  (`published`) recorded with each generation.
- **Real AI:** generated summaries are natural Telugu prose (OpenRouter →
  Claude), not the deterministic English fallback.
- **Per-child privacy:** under parent scope, the parent sees their own child's
  snapshots and **0** rows for another student (RLS verified at the DB).

## Quality gate

- `flutter analyze` — no new issues (pre-existing baseline only; none in B3 files).
- Flutter tests — affected suites green (220 passed).
- Edge tests — `audit/`, `parent_insights/`, `entitlements/`, `validation/` green (49 passed).

## Locked decisions respected

WhatsApp untouched (wa.me only) · entitlement scope unchanged · owner-gated
items (SMS/push/keystore) remain paused.

## Deferred (backlog)

- Parent Insights read-aloud (multilingual TTS) — `IDEAS_BACKLOG.md` (2026-06-25).
