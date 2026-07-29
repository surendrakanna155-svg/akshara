# ASIP — Remediation Register (post-final-audit, planning only)

**Status:** 🟡 **CONDITIONAL CERTIFIED (Certified with Conditions)** — accepted by owner 2026-07-21.
**Authoritative audit record:** [`ASIP_FINAL_CERTIFICATION_AUDIT_2026-07-21.md`](ASIP_FINAL_CERTIFICATION_AUDIT_2026-07-21.md) (do not alter its findings; this register is the *actionable* companion).
**This register:** the single source of truth for the **5 mandatory pre-deployment conditions** that gate ASIP-8 production certification and canonical-trunk fold-in.

**▶ EXECUTION STATUS (2026-07-29).** RC-1 ✅ · RC-2 ✅ · RC-3 ✅ · RC-4 ✅ · RC-5 ✅ — **all five closed**. Readiness report: [`ASIP_8_PRODUCTION_READINESS_REPORT.md`](ASIP_8_PRODUCTION_READINESS_REPORT.md).
Regression: `deno check` 0 errors · `deno test supabase/functions/_shared/` **2972 passed, 0 failed, 3 ignored**.
Still **not deployed** and **not production-certified** — the live cert (`scripts/qa/live_cert_asip_vps.sh`, 23 checks) has not been re-run, and deploy remains owner-gated.

| # | Status | Note |
|---|---|---|
| RC-1 | ✅ done | Renumbered to `20260920000210_support_kb.sql`. The register's "≥…100" target was **stale** — the trunk had since taken …100/110/130/140/160/170/180/190/200. Verified free across every local branch (global max was `…000201` on `integration/aip-onto-w0`). The validation test now locates the migration by the `*_support_kb.sql` **suffix**, so a future renumber cannot silently break it, plus a guard asserting exactly one such migration exists. |
| RC-2 | ✅ done | Clamp moved into `clusterTitle()` itself (`CLUSTER_TITLE_MAX = 400`) so **both** call sites are covered — `module_key` is bounded nowhere, not by DB constraint nor request validation. KB learning moved OUT of the resolve transaction into `learnFromResolutionBestEffort()`, its own tx after the resolve commits. |
| RC-3 | ✅ done | `resolved` removed from the `/support-status` transition set via the pure predicate `isSettableSupportStatus()`, shared by handler and test; 422 with a message pointing at `/resolve`. Web console dropdown no longer offers it. |
| RC-4 | ✅ done | `listUnresolvedClusterIncidentIds()` filters already-resolved rows; a single re-resolve is a no-op returning count 0 with no propagation, no notification, no KB delta. **Note:** `listClusterIncidentIds` is retained and NOT interchangeable — cluster *size* (investigation confidence, engineering handoff) must still count every member. |
| RC-5 | ✅ done | Full mirror reconcile wired into `handleCollectEvidence` via `reconcileMirrorBestEffort()` (upserts, so a no-op when already mirrored), and the false comment corrected — it claimed retry "can re-run via collect-evidence" when no such path existed. `handleTransitionStatus` now runs a full reconcile (header-only left evidence-less mirrors the console could not diagnose). `POST /support/mirror/reconcile` added — bounded re-mirror sweep, fail-closed cron token or `manageSupport` JWT. `autoCluster` declines to cluster on an empty signature, which previously collapsed every evidence-less incident in a category+module into one junk cluster. Route/auth/fail-closed tested. |


---

## ▶ RESUME POINT — start future AI Support work HERE

> The final independent certification audit is **COMPLETE and ACCEPTED. Do NOT re-run the audit.**
> The AI Support Engineering Program is engineering-complete (ASIP-1…8 built + green; ASIP-1…7 PRODUCTION CERTIFIED + LIVE and **not voided**).
>
> **"Continue / resume AI Support work" = execute the 5 remediation conditions below (ASIP-RC-1 … ASIP-RC-5), in priority order, then run the ASIP-8 live cert.** These are the ONLY open AI Support engineering items.
>
> - **Do RC-1 (migration renumber) FIRST** — it is a hard fold-in/deploy blocker and unblocks everything downstream.
> - All 5 are **MANDATORY pre-deployment conditions** — ASIP-8 must NOT be deployed/production-certified until every one is remediated and re-verified.
> - Execute inside the **unified ERP pilot deployment phase** (do NOT deploy/activate ASIP-8 standalone).
> - Lane: worktree `Akshara_ERP-asip`, branch `feature/asip-support-intelligence` (audit head `170553ed`).
> - After remediation: renumber-and-apply the KB migration, re-run `scripts/qa/live_cert_asip_vps.sh` (23 checks), then mark ASIP-8 PRODUCTION CERTIFIED.
> - The 16 P2 + 19 P3 items (audit report §5) are backlog — they do **not** gate certification.

---

## Conditions (priority order) — all MANDATORY pre-deployment

| # | Audit ID | Title | Severity | Blocks | File:line |
|---|---|---|---|---|---|
| RC-1 | **P1-D** | Migration version `20260920000060` collides with the canonical trunk | P1 | **Trunk fold-in + deploy (hard blocker)** | `supabase/migrations/20260920000060_support_kb.sql` |
| RC-2 | **P1-A** | KB article title not clamped to `CHECK(≤400)` → rolls back the school-facing resolution | P1 | ASIP-8 correctness | `supabase/functions/_shared/support/support_kb_service.ts:143` |
| RC-3 | **P1-B** | `/support-status = resolved` skips propagate/notify/learn (divergent resolve path) | P1 | Workflow integrity | `supabase/functions/_shared/support/support_platform_handlers.ts:145` |
| RC-4 | **P1-C** | `handlePlatformResolve` not idempotent → duplicate notification + inflated KB count | P1 | Workflow integrity | `supabase/functions/_shared/support/support_platform_handlers.ts:279-326` |
| RC-5 | **P1-E** | Best-effort mirror has no reconciliation; documented recovery path does not exist | P1 | Ops robustness | `supabase/functions/_shared/support/support_mirror.ts:61-86` |

---

### RC-1 (P1-D) — Migration version collision `20260920000060` `[HARD DEPLOY BLOCKER — DO FIRST]`
- **Traceability:** ASIP `supabase/migrations/20260920000060_support_kb.sql` vs canonical trunk `integration/w0-canonical:supabase/migrations/20260920000060_finance_recovery_minor_backfill.sql`. `merge-base(ASIP, w0-canonical) = e37a75e2` (ASIP-8 not yet in trunk).
- **Evidence (git, reproduced twice):** both branches carry a `…000060_*.sql`; `git merge-tree --write-tree` exits 0 (no *git* conflict) yet the merged tree holds **two files at the same 14-digit version**. `supabase db push` on the folded dir sees a duplicate version → deploy error / non-deterministic apply.
- **⚠ Updated target (2026-07-21):** the trunk band has since advanced under **PROGRAM ICA** — slots `…060/062/070/080/090` are now consumed. **Renumber the ASIP-8 KB migration to the next free slot ≥ `20260920000100` (`20260920000100_support_kb.sql`), verifying the current ceiling at fold-in time** (the trunk is actively advancing; do not hardcode a slot without re-checking).
- **Remediation (plan):** `git mv` the migration to the chosen ≥`…100` slot; update the hardcoded path + comment in `support_kb_migration_validation_test.ts` (or switch it to a `migrations/*_support_kb.sql` glob) **in the same change** (the standalone "test hardcodes path" finding was correctly refuted and folded here); re-run `deno test` + the migration-validation test.
- **Verification when fixed:** unique+monotonic version in the folded tree; `deno test _shared/support` green; migration applies cleanly in a fold-in dry run.

### RC-2 (P1-A) — KB title not length-clamped rolls back the resolution `[ASIP-8 correctness]`
- **Traceability:** `support_kb_service.ts:143` (`title: clusterTitle(...)` — no `.slice()`, while `rootCause.slice(0,2000)` / `resolution.slice(0,4000)` are clamped) · DB constraint `supabase/migrations/20260920000060_support_kb.sql:53` `CHECK (char_length(title) <= 400)` · `learnFromResolution` runs inside the resolve tx (`support_platform_handlers.ts:305`, within `withTenantContext` opened at `:279`).
- **Failure:** long client-set `module_key` + long failing `topErrorPath` → `clusterTitle` > 400 chars → KB INSERT violates the CHECK → the exception aborts the resolve tx → `propagateResolution` (school notified + status) rolls back; incident stuck, school never told.
- **Remediation (plan):** clamp the title (`clusterTitle(...).slice(0, 400)`) in `learnFromResolution`; **and** isolate KB learning from the resolution write — learn best-effort in its own transaction *after* the resolve commits (mirror `embedArticleBestEffort`), so a KB failure can never roll back a school-facing resolution.
- **Verification when fixed:** unit test with an over-length title asserts the resolution still commits and the KB failure is swallowed; live-cert learn step still passes.

### RC-3 (P1-B) — `/support-status = resolved` is a divergent resolve path `[workflow integrity]`
- **Traceability:** `support_platform_handlers.ts:131-150` (esp. `:145`) — `handlePlatformSupportStatus` accepts `resolved` (in `SUPPORT_STATUS_ORDER`) and calls only `setPlatformSupportStatus` (mirror-only UPDATE); no `propagateResolution`, notification, or `learnFromResolution`. Web exposes both a status dropdown (incl. "Resolved") and a separate Resolve button.
- **Failure:** agent picks "Resolved" from the dropdown → console shows closed, but the school incident stays unresolved, the reporter is never notified, and no KB article is learned — the "school is informed" promise breaks silently.
- **Remediation (plan):** remove `resolved` from the `/support-status` transition set (force resolution only through `/resolve`), **or** route a `resolved` status change through the same propagate+notify+learn path with an already-resolved idempotency guard (see RC-4).
- **Verification when fixed:** a test asserts that setting `resolved` via `/support-status` either 422s or performs full propagation+notify+learn; web dropdown no longer offers a silent-resolve.

### RC-4 (P1-C) — `handlePlatformResolve` is not idempotent `[workflow integrity]`
- **Traceability:** `support_platform_handlers.ts:279-326` (loads incident `:280`, no status check; `propagateResolution` `:292`; `learnFromResolution` `:305`) · bridge `supabase/migrations/20260920000050_support_resolution_notify.sql:38` (`resolved_at` guarded) vs `:49` (unconditional notification INSERT, no dedupe) · `support_kb_repository.ts:75` (`resolved_count = resolved_count + 1`).
- **Failure:** resolve A and B individually (each reporter gets one push; KB count = 2), then "Resolve the whole cluster" including A and B → each reporter gets a **second** "resolved" push and KB `resolved_count`/`schools_seen` inflate.
- **Remediation (plan):** skip targets whose `support_status` is already `resolved` (or add `AND status <> 'resolved'` to the bridge UPDATE and gate the notification INSERT on the row actually transitioning); bump KB counters only on a genuine new resolution.
- **Verification when fixed:** a test resolves twice and asserts exactly one notification + a single KB delta per real transition.

### RC-5 (P1-E) — Best-effort mirror has no reconciliation `[ops robustness]`
- **Traceability:** `support_mirror.ts:61-86` (comment `:82-85` claims "re-run via collect-evidence"). `mirrorEvidence` is called **only** inside `mirrorIncidentBestEffort` (`:70-74`), invoked **only** from `handleCreateIncident` (`support_handlers.ts:215`). `handleCollectEvidence` does not re-mirror; no reconcile job exists. Header-only fallback (`mirrorIncidentHeaderBestEffort`) can create a mirror incident without evidence → auto-cluster on empty diagnostics.
- **Failure:** a transient DB error aborts the create-time mirror; the school report still succeeds (201) but no mirror row exists; if the school never changes status the incident is permanently invisible in the support console with no recovery. *(Not data-loss — the school-side incident is intact; only the mirror copy is missing.)*
- **Remediation (plan):** add a reconciliation path — re-invoke the full best-effort mirror (incident + evidence) from `handleCollectEvidence` and `handleTransitionStatus`, and/or a periodic reconcile that mirrors any school incident missing from the mirror; correct the misleading comment; make auto-cluster tolerant of missing/empty diagnostics.
- **Verification when fixed:** a test simulates a failed create-mirror then a status change / collect-evidence and asserts the mirror (incident + evidence) is reconciled; auto-cluster does not bucket on an empty signature.

---

## Backlog (does NOT gate certification)
16 P2 + 19 P3 items — de-duplicated in the audit report §5 (`ASIP_FINAL_CERTIFICATION_AUDIT_2026-07-21.md`). Highlights: `schools_seen` counts incidents not distinct schools; `public_ref` 32-bit collision risk at scale; KB embeddings bypass the governed gateway; coarse cluster fingerprint mis-recall; no KB retire/edit lifecycle; unindexed queue sort / semantic scan; mirror + embedding layers untested; `escalate` lacks a from-status guard. Schedule separately.

## Sign-off
- **Verdict:** CONDITIONAL CERTIFIED — accepted 2026-07-21. **0 P0**; security-RLS + SECURITY-DEFINER both 9/10; org wall holds; ASIP-8 adds no new SECURITY DEFINER. Overall ≈7.4/10.
- **ASIP-1…7:** PRODUCTION CERTIFIED + LIVE — not voided.
- **ASIP-8 + trunk fold-in:** blocked on RC-1…RC-5 above, then the owner-gated deploy.
