# P1 — Integration Certification (B1–B6 work together)

**Date:** 2026-06-25 · **Status:** ✅ P1 INTEGRATION CERTIFIED (live on VPS, real auth + real prod DB)
**Goal:** verify the completed P1 batches interoperate end-to-end — not a per-batch re-test
(each batch already has its own cert), but the **seams between batches**. No new features.

Artifact: `scripts/p1_integration_smoke.sh` → **11/11 PASS** against
`https://akshara.veloraunisexsalon.com`.

## Seams verified

| Chain | Seam | Result |
|-------|------|--------|
| **Marketing → CRM** (B6→B1) | growth inquiry → convert → admissions lead carries **source + campaign** attribution | ✅ |
| **CRM → AI Admissions Assistant** (B1→B4) | the converted lead surfaces in `/admissions/intelligence` next-best-actions (assign-owner) and raises `unassignedLeads`; funnel `topSource` reflects the marketing source | ✅ (after fix) |
| **Capability Gating** (B2 × B6/B1) | pilot (Professional) entitled consistently across `/growth` + `/admissions` | ✅ |
| **Parent Insights** (B3) | parent reads own child's insights (200) in the integrated system | ✅ |
| **RBAC / scope** (B1/B4/B6) | parent denied `/admissions/intelligence`, `/admissions/leads`, `POST /growth/campaigns` (403/403/403) | ✅ |
| **WhatsApp readiness** (B5 × B6→B1) | converted lead carries a phone → `wa.me` deep-link constructable; the button safely hides when a phone is absent | ✅ |

## The one real integration gap found — and fixed

**Gap (B6 ↔ B1 ↔ B4): the Marketing→CRM handoff wrote a raw UUID as the lead's owner.**
`handleConvertGrowthInquiry` set `counselor: auth.claims.sub` (the converting user's UUID).
But in B1 `counselor` is a **display name** (e.g. "Meera N."), and B4's intelligence treats
`counselor = ''` as the **"assign an owner"** signal. The consequences, confirmed live:
- the CRM showed a raw UUID as the lead's counselor;
- the converted lead was **invisible to the AI Admissions Assistant's** assign-counselor
  next-best-action (it counted as "already assigned"), so the Marketing→CRM→AI handoff
  loop silently dropped every marketing-sourced lead.

Pre-fix smoke reproduced it exactly: `counselor=a3000000-…`, `unassignedLeads` stayed `0`
after conversion.

**Fix (single, minimal):** the handoff now leaves the lead **unassigned** (`counselor: ''`),
so it appears correctly in the CRM and surfaces in B4's assign next-best-action for an
admissions counselor to pick up. Provenance (the converting user) is preserved in the lead
`notes` and the audit log. Stale rows on the live DB (UUID counselors from earlier smokes)
were normalized to `''`.

Files: `supabase/functions/_shared/growth/growth_handlers.ts` (convert handler).
Deployed (edge recreated with `--no-deps`); re-cert **11/11**.

## Notes
- `flutter analyze` clean; backend `deno check` clean; `deno test _shared/{admissions,entitlements}` 37/0.
- Marketing→CRM **attribution** (source + campaign) was already correct pre-fix — only the
  ownership/handoff seam was broken.
- Deploy lesson: recreate the edge with `docker compose up -d --no-deps --force-recreate
  akshara-edge` so the pre-existing-broken postgres healthcheck doesn't stall the edge
  (see `docs/B6_MARKETING_ENGINE_CERTIFICATION.md` §4 — owner still needs to fix the
  `pg_isready` healthcheck in the compose file).
- Out of scope (unchanged): converted lead's `student_name` falls back to the parent's name
  because growth inquiries don't capture a student name — a B6 data-capture limitation, not a
  between-batch integration gap; left as-is.

**P1 (Revenue & Pilot Success), B1–B6, is now integration-certified.** Next is P2 / B7 — not started.
