# Wave 4 — AI Moderation Gate + Dispatch Performance — PRODUCTION CERTIFICATION

**Date:** 2026-06-26
**Status:** ✅ **PRODUCTION CERTIFIED** — live **20/20** vs VPS pilot
**Roadmap:** `docs/FINAL_COMPLETION_ROADMAP.md` Wave 4 (Themes E + perf)
**Cert script:** `scripts/qa/live_cert_completion_wave4.py`
**Release-review:** see §Release gate.

Real VPS (`https://akshara.veloraunisexsalon.com`) + real Postgres (`akshara_db`)
+ edge-minted JWTs (real RBAC). Fixtures seeded as `supabase_admin`; every
assertion runs through the deployed edge under real tenant context / RLS.

---

## What was closed (all 6 Wave 4 items)

| ID | Item | Result |
|----|------|--------|
| **AI-1** | Rejected/unmoderated AI items could reach the student paper | `paperExportDocument` now prints **only `review_status='approved'`** items, renumbers the questions, and **rebuilds the answer key from the survivors** (stale stored `answer_key` ignored). The client-side `EducationPdfService.printQuestionPaper` filters identically. A human-rejected or still-pending AI question can no longer print. |
| **AI-2** | Export endpoint bypassed the publish gate | `handleExportQuestionPaper` is gated on `review_status='published'` → **409 `PAPER_NOT_PUBLISHED`** for any draft/submitted/approved-but-unpublished paper (positive control: a published paper is 200). |
| **PERF-1** | Unbounded sequential N+1 in broadcast/notification dispatch | Cohort **bounded to 5000**; recipients + push deliveries written as **two multi-row INSERTs** (`insertBroadcastRecipientsBatch` / `enqueueDeliveriesBatch`) instead of 2N round-trips; the per-recipient send is **moved out of the request** via `EdgeRuntime.waitUntil` (bounded background drain; inline fallback for non-edge/test). Broadcast returns `status:'queued'`. The same batching applied to the publisher fan-out (`publisher_dispatch.ts`). |
| **PERF-2** | SIS registry search fetched per keystroke | New reusable `lib/core/utils/Debouncer`; the registry search field debounces (350 ms) so a fetch fires once typing settles. |
| **AI-3** | Publisher captions used env-only AI key | `enhanceCaptionsWithAi` resolves AI via **`resolveAiConfig(db, orgId)`** (admin Control-Center panel config wins; env fallback), so a panel-configured org gets AI captions instead of silently deterministic ones. |
| **AI-5** | Composition chips read 0 | Summary mapper reads `bankReuseCount`/`aiGeneratedCount` from **`blueprint`** (AI count stored as `aiCandidateCount`) with a top-level fallback; safe `num→int` coercion. |

---

## Live evidence (20/20)

`python3 scripts/qa/live_cert_completion_wave4.py` → **20/20 PASS**.

**AI-1 (moderation gate, the headline check)** — a published paper seeded with 4
items (2 approved, 1 **rejected**, 1 **pending**):
- export is 200 and prints **exactly the 2 approved** questions
  (`Q_APPROVED_ALPHA`, `Q_APPROVED_BRAVO`);
- the rejected (`Q_REJECTED_XRAY`) and pending (`Q_PENDING_PAPA`) text are
  **absent**;
- the answer key is **rebuilt + renumbered 1..N** from the survivors
  (`ANS_ALPHA`/`ANS_BRAVO`), and the stale stored key (`STALE`) is ignored.

**AI-2 (export gate)** — draft paper export → **409 `PAPER_NOT_PUBLISHED`**;
published paper export → **200**.

**PERF-1 (batched, bounded, async dispatch)** — `POST /communications/broadcasts`
returns **201** in **0.36 s** with `status:'queued'`, `droppedOverCap:0`;
`comm_recipients` rows == `recipientCount` (3, batch insert), one
`notification_deliveries` row per recipient (3, batch enqueue), and the queued
deliveries are **attempted off-request** (3/3 — observed in the background, with
no `process-queue` call forced) → `EdgeRuntime.waitUntil` is live on the VPS
runtime.

**AI-5 (contract)** — the question-paper read carries the counts inside
`blueprint` (`bankReuseCount=2`, `aiCandidateCount=1`) — the exact shape the
fixed Flutter chip mapper now reads.

**PERF-2 / AI-3 / client-side export filter** — unit-/build-covered (see Gates);
no separate live surface (PERF-2 + the PDF print are client-side; AI-3's
behavioral delta needs a panel AI key — the code path is deployed and `deno
check`-clean, with the deterministic fallback preserved).

---

## Gates

- `flutter analyze` — **0 issues**.
- `flutter test` — **2389 passed / 1 skipped / 0 failed** (baseline 2383 + 6 new:
  3 summary-mapper + 3 debouncer; added `fake_async` dev dep).
- `deno check supabase/functions/api/index.ts` (whole graph) — **clean**.
- `deno test --allow-env --allow-read supabase/functions/_shared/` —
  **679 passed / 0 failed / 2 ignored** (baseline 672 + 7 new: 3 export-moderation
  filter + 4 batch-insert SQL shape).

---

## Deploy

**No migration** (all changes are edge TS + Flutter). Edge files rsynced to
`/opt/akshara/functions/_shared/` + `docker restart akshara-edge`:

- `communication/communication_handlers.ts`, `communication_repository.ts`,
  `communication_service.ts`
- `education/education_handlers.ts`, `education_mapper.ts`
- `promotion/achievement_promotion_handlers.ts`, `publisher_ai_captions.ts`,
  `publisher_dispatch.ts`

Flutter changes (debouncer, PDF print filter, summary mapper) ship in the app
build; proven by the unit suite above. Post-deploy live verify = the 20/20 cert.

---

## Release gate

`/release-review`: Engineering quality (gates green, conventions matched,
additive blast radius — no migration, no schema change, reused the existing
queue-drain endpoint and `resolveAiConfig` seam), QA evidence (**20/20** live
N/N with real auth/DB/RBAC, including the headline "rejected item never exports"
proof), and release safety (no migration to sequence; edge restart recipe;
`EdgeRuntime.waitUntil` confirmed live with an inline fallback) all satisfied →
**GO**.
