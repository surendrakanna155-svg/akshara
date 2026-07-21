# ASIP — Final Independent Certification Audit (AI Support Engineering Program)

**Date:** 2026-07-21 · **Scope:** the entire Akshara AI Support Intelligence Platform (ASIP-1…8) — backend edge module, mirror domain + SECURITY DEFINER bridges, ASIP-8 Continuous Learning / Knowledge Base, AI investigation pipeline, support-intelligence workflows, API contracts, web console, Flutter client, migrations, docs, live-cert, and canonical-trunk integration.
**Method:** independent multi-agent audit — **14 parallel dimension reviewers → adversarial verifier per finding (default-refute) → main-loop synthesis + independent re-verification of every P1 and every verifier-errored finding.** 62 agents, 55 completed, 7 verifier connection errors (all on P2/P3 findings, independently re-verified here). Read-only; no code, production, or deployment changes were made.
**Branch audited:** `feature/asip-support-intelligence` @ `2197e13b` (worktree `Akshara_ERP-asip`).
**Disposition:** ✅ **OWNER-ACCEPTED (2026-07-21).** This document is the **authoritative audit record** (findings preserved as-issued). Actionable, tracked remediation lives in the companion SSOT [`ASIP_REMEDIATION_REGISTER.md`](ASIP_REMEDIATION_REGISTER.md) (conditions ASIP-RC-1…RC-5). *Annotation added post-acceptance: P1-D's renumber target is superseded — see the bracket in §4/P1-D.*

---

## 1. Overall verdict

# 🟡 CONDITIONAL — CERTIFIED WITH CONDITIONS

- **0 P0** (no ship-blocking defect survived adversarial verification).
- **No Part 7B automatic-failure:** tenant isolation, privilege boundaries, and SECURITY DEFINER usage were the most heavily scrutinized dimensions and both scored **9/10** — the org wall holds, and ASIP-8 introduces **no new SECURITY DEFINER**.
- **5 confirmed P1s** (correctness / workflow-integrity / ops-robustness / one hard **fold-in deploy blocker**) — none security/isolation/data-loss, but each must be remediated before **ASIP-8 production certification** and **canonical-trunk fold-in**.
- **16 P2 + 19 P3** quality / performance / governance / maintainability items (≈25 distinct issues after de-duplication) for the backlog.

**What this verdict means, precisely:**
- **ASIP-1…7 remain validly PRODUCTION CERTIFIED + LIVE** on the pilot. None of the P1s retroactively void that certification: P1-A and P1-C are ASIP-8 code (not deployed); P1-D is a fold-in deploy concern (ASIP-8 not deployed); P1-B and P1-E are Phase-2 edge-case robustness issues, not security/data-loss.
- **ASIP-8 (Continuous Learning) and the canonical-trunk fold-in are CONDITIONALLY certified** — the design and implementation are sound (asip8-kb scored 9/10), but the 5 P1 conditions below gate its production certification. This is consistent with the already-agreed posture that ASIP-8's live run is deferred to the unified ERP pilot deployment phase.

The audit is **not clean**, so a clean "COMPLETE and CERTIFIED" is **not** declared. The correct disposition is **CONDITIONAL**, with the remediation plan in §5 folded into the roadmap as pre-deploy conditions.

---

## 2. Scores by category (0–10)

| Dimension | Score | One-line rationale |
|---|---|---|
| Security — RLS / tenant isolation | **9.0** | 11/11 ASIP tables ENABLE+FORCE RLS with USING+WITH CHECK; org wall holds; RLS (not the WHERE filter) is the real backstop on a NOBYPASSRLS edge role. |
| Security — SECURITY DEFINER usage | **9.0** | 4 bridges derive source org/school from the session GUC (never a param); pinned search_path; REVOKE PUBLIC/GRANT erp_tenant; ASIP-8 adds none. |
| ASIP-8 Continuous Learning impl. | **9.0** | Fingerprint reuse aligns recall with clustering; deterministic-first; best-effort embed in its own tx; `applyPriorResolutions` correct. |
| API contracts | **8.5** | Routing/validation/envelope/pagination sound; normalizers tolerate snake+camel; minor verb→404-vs-405 nit. |
| Architecture & engineering quality | **8.0** | Clean router→handler→service→repo layering; genuinely reuse-first; type-only import acyclic at runtime; a few P2/P3 smells. |
| Data integrity & migrations | **8.0** | Strictly additive, monotonic, idempotent, well-constrained; pgvector guard dormant-safe; one latent `public_ref` scale issue. |
| Production readiness & deploy | **7.5** | Additive deploy shape; live-cert hermetic/non-destructive (23 checks); rollback/owner-gating documented. |
| Performance & scalability | **7.0** | Core paths indexed; several unindexed sorts/scans + O(N) round-trips at pilot-acceptable scale. |
| AI investigation pipeline | **6.5** | Governed gateway + deterministic-first + own-tx isolation; but embeddings bypass the gateway and raw title/desc reach the model/embedder. |
| Web UI | **6.5** | Honest no-backend states, permission-gated, no mock data; keystroke-refetch, page-scoped counts, a11y gaps. |
| Long-term ops & regression risk | **6.5** | No retention/reconciliation; env-flag-driven behavior; mirror/embedding layers untested. |
| Support-intelligence workflows | **6.0** | Clustering + resolve-many work; but a divergent resolve path, non-idempotent resolve, unguarded escalate. |
| Knowledge Base design & governance | **6.0** | Recall works and is explainable; no correct/retire lifecycle; coarse fingerprint can mis-recall; narrative overwrite w/o history. |
| Canonical trunk integration | **6.0** | Additive, no source deletions; **but a hard migration-version collision (20260920000060) blocks the fold-in deploy.** |
| **Weighted overall** | **≈7.4** | Solid, tenant-safe platform with a bounded set of pre-deploy conditions. |

---

## 3. Findings summary

| Severity | Count (surviving verification) | Disposition |
|---|---|---|
| **P0** | **0** | — none |
| **P1** | **5** | Conditions — remediate before ASIP-8 prod-cert / trunk fold-in (§4) |
| **P2** | 16 (≈10 distinct) | Backlog — quality/perf/governance (§5) |
| **P3** | 19 | Backlog — minor/nits (§5) |
| Refuted | 1 | Correctly dismissed (test path coupling — folded into P1-D) |

Raised: 48 · Confirmed: 37 · Plausible: 3 · Refuted: 1 · Verifier-errored (re-verified here, all P2/P3): 7.

---

## 4. P1 findings — evidence, traceability, and remediation (planning only)

> Every P1 below was CONFIRMED by the workflow's adversarial verifier **and** independently re-verified against the code during synthesis.

### P1-A — KB article title is not length-clamped; a >400-char title rolls back the school-facing resolution `[ASIP-8 correctness]`
- **Location:** `supabase/functions/_shared/support/support_kb_service.ts:143` · constraint `supabase/migrations/20260920000060_support_kb.sql:53`.
- **Evidence:** `learnFromResolution` passes `title: clusterTitle(incident.category, incident.module_key, diag)` with **no `.slice()`**, while `rootCause.slice(0,2000)` and `resolution.slice(0,4000)` **are** clamped. `clusterTitle` embeds the client-set `module_key` and the failing `topErrorPath`. The KB table enforces `CHECK (char_length(title) <= 400)`. `learnFromResolution` runs **inside the resolve transaction** (`support_platform_handlers.ts:305`, within the `withTenantContext` opened at `:279`).
- **Failure scenario:** an incident with a long `module_key` and a long failing path yields a >400-char title → the KB INSERT violates the CHECK → the exception aborts the whole resolve transaction → `propagateResolution` (school notified + status) is rolled back. The support agent sees a failure; the school is never told; the incident is stuck.
- **Verdict:** CONFIRMED (verifier + independent re-read).
- **Remediation (plan):** clamp the title (`clusterTitle(...).slice(0, 400)`) in `learnFromResolution`, mirroring the existing root-cause/resolution slices; **and** isolate KB learning from the resolution write (learn best-effort in its own transaction after the resolve commits, like `embedArticleBestEffort`) so a KB failure can never roll back a school-facing resolution.

### P1-B — `/support-status = resolved` is a divergent resolve path (skips propagation, notification, and KB learning) `[workflow integrity]`
- **Location:** `supabase/functions/_shared/support/support_platform_handlers.ts:131-150` (esp. `:145`).
- **Evidence:** `handlePlatformSupportStatus` validates `status` against `SUPPORT_STATUS_ORDER` (which **includes `resolved`**) and, on `resolved`, calls only `setPlatformSupportStatus(...,'resolved')` — a **mirror-only** UPDATE. It does **not** call `propagateResolution`, the reporter notification, or `learnFromResolution`. The web console exposes both a Support-status dropdown (including "Resolved") and a separate Resolve button.
- **Failure scenario:** a support agent picks "Resolved" from the dropdown → the console shows the incident closed, but `support_incident.status` on the school side stays unresolved, the reporter is never notified, and no KB article is learned. The "school is informed" promise breaks silently.
- **Verdict:** CONFIRMED.
- **Remediation (plan):** either remove `resolved` from the `/support-status` transition set (force resolution only through `/resolve`), or route a `resolved` status change through the same propagate+notify+learn path with an already-resolved idempotency guard (see P1-C).

### P1-C — `handlePlatformResolve` is not idempotent: re-resolve duplicates the reporter notification and double-applies the KB delta `[workflow integrity]`
- **Location:** `support_platform_handlers.ts:279-326` (loads incident `:280`, no status check; `propagateResolution` `:292`; `learnFromResolution` `:305`) · bridge `supabase/migrations/20260920000050_support_resolution_notify.sql:38,49` · `support_kb_repository.ts:75`.
- **Evidence:** the handler never inspects `support_status`/`source_status`; it calls `propagateResolution` per target and `learnFromResolution` once per request. In the bridge, `resolved_at` is guarded (set once) but the **notification INSERT is unconditional** (no dedupe/ON CONFLICT). The KB upsert does `resolved_count = resolved_count + 1` unconditionally.
- **Failure scenario:** resolve incidents A and B individually (each reporter gets one push; KB count for signature = 2), then click "Resolve the whole cluster" including A and B → each reporter gets a **second** "resolved" push and the KB `resolved_count` for that signature is inflated.
- **Verdict:** CONFIRMED.
- **Remediation (plan):** skip targets whose `support_status` is already `resolved` (or add `AND status <> 'resolved'` to the bridge UPDATE and gate the notification on the row actually transitioning); bump KB `resolved_count`/`schools_seen` only on a genuine new resolution.

### P1-D — Migration version `20260920000060` collides between ASIP (`support_kb`) and the canonical trunk (`finance_recovery_minor_backfill`) — **hard fold-in deploy blocker** `[trunk integration]`
- **Location:** `supabase/migrations/20260920000060_support_kb.sql` vs trunk `integration/w0-canonical:supabase/migrations/20260920000060_finance_recovery_minor_backfill.sql`.
- **Evidence (git, independently reproduced):** ASIP tip `2197e13b` has `…000060_support_kb.sql`; `integration/w0-canonical` (`97fb9d2c`) has `…000060_finance_recovery_minor_backfill.sql` (plus `…000062/…000070/…000080` from PROGRAM ICA). `merge-base(ASIP, w0-canonical) = e37a75e2` (so ASIP-8 is not yet in the trunk). `git merge-tree --write-tree` exits 0 (no *git* conflict) and the merged tree contains **both** files at the same 14-digit version.
- **Failure scenario:** folding ASIP into the trunk and running `supabase db push` on the merged `migrations/` dir presents two files at version `20260920000060` → the CLI errors on the duplicate version (deploy fails) or applies them non-deterministically.
- **Verdict:** CONFIRMED. (The related P3 "test hardcodes the migration path" was correctly **REFUTED** as a standalone finding and is folded into this remediation.)
- **Remediation (plan):** before fold-in, renumber the ASIP-8 migration to a version above the trunk's highest `20260920` slot, keeping versions unique and strictly monotonic; in the **same** change update the hardcoded path + comment in `support_kb_migration_validation_test.ts` (or switch it to a `migrations/*_support_kb.sql` glob). This is the single most important pre-deploy condition and belongs in the unified ERP pilot deployment phase. **[Post-acceptance update 2026-07-21: the trunk band has since advanced under PROGRAM ICA (slots `…060/062/070/080/090` consumed), so the earlier `…090` suggestion is superseded — renumber to the next free slot ≥ `20260920000100`, verifying the ceiling at fold-in time. Tracked as ASIP-RC-1.]**

### P1-E — Best-effort mirror has no reconciliation; the documented recovery path does not exist `[ops robustness]`
- **Location:** `supabase/functions/_shared/support/support_mirror.ts:61-86` (comment `:82-85`).
- **Evidence:** `mirrorEvidence` is called **only** inside `mirrorIncidentBestEffort` (`:70-74`), which is invoked **only** from `handleCreateIncident` (`support_handlers.ts:215`). The comment claims a failed mirror "can re-run via collect-evidence," but `handleCollectEvidence` does not re-mirror; no reconcile job exists. The header-only fallback (`mirrorIncidentHeaderBestEffort`, from status change) can create a mirror incident **without** evidence, so a later auto-cluster computes a fingerprint from empty diagnostics.
- **Failure scenario:** a transient DB error aborts the create-time mirror. The school report still succeeds (201), but no mirror row exists; if the school never changes status, the incident is permanently invisible in the support console with no recovery. If only the header later mirrors, the incident clusters on an empty ("none") signature.
- **Verdict:** CONFIRMED. (Robustness/ops — not data-loss: the school-side incident is intact; only the support mirror copy is missing.)
- **Remediation (plan):** add a reconciliation path — re-invoke the full best-effort mirror (incident + evidence) from `handleCollectEvidence` and `handleTransitionStatus`, and/or a periodic reconcile that mirrors any school incident missing from the mirror; correct the misleading comment. Ensure auto-cluster tolerates missing/empty diagnostics.

---

## 5. P2 / P3 backlog (de-duplicated; planning only)

**P2 (quality / performance / governance):**
- **`schools_seen` counts cluster incidents, not distinct schools, and only ratchets up** (`support_platform_handlers.ts:310`) — inflated breadth shown to support and to the model. *(Reported by 4 reviewers; one distinct issue.)* → count DISTINCT `source_school_id`.
- **`public_ref` = 32-bit UUID prefix under a GLOBAL unique index with no collision handling** (`migration 20260920000000:30`) — legitimate incident creates can hard-fail at scale. → widen the ref or add retry-on-conflict.
- **Coarse cluster fingerprint can make distinct bugs collide** and surface as a high-confidence "Known issue" with the wrong prior fix (`support_platform_service.ts:198`). → include a stronger discriminator; cap confidence when the fingerprint is weak.
- **ASIP-8 KB embedding calls bypass the governed gateway** (no telemetry/spend-cap/rate-limit) (`support_kb_service.ts:229`). *(Note: `embedText` itself is env-gated + timeout-bounded, so this is a governance-consistency gap, not an uncontrolled spend.)* → route embeddings through the governed economics path or add ASIP-surface telemetry.
- **Raw incident title/description (potential PII) is sent to the model and the third-party embedder** despite "no raw PII" framing (`incident_package.ts:222`, KB embed). → minimize/scrub free-text before it leaves the tenant, or document the accepted boundary.
- **`escalate` unconditionally sets `support_status='awaiting_engineering'` with no from-status guard** (`support_platform_repository.ts:190`) — can un-resolve a resolved incident. → add a from-status guard.
- **Web:** KB search refetches/loses focus every keystroke (`SupportKbPage.tsx:18`) → debounce/client-filter; queue status-tab counts reflect only the first page (`SupportQueuePage.tsx:62`) → count server-side; table rows not keyboard-operable (`DataTable.tsx:103`, shared component — treat carefully vs the frozen viewer).
- **Perf:** queue sorts on unindexed `escalated_at` (`support_platform_repository.ts:108`); `resolveCluster` O(4N) round-trips with 2 no-op writes/incident (`support_platform_handlers.ts:290`); KB semantic recall is an unindexed exact scan (`support_kb_repository.ts:229`).
- **`runAnalysis` holds the caller's write transaction open across the model call**, pinning two pool connections/request (`support_service.ts:177-197`). *(Independently confirmed here.)* → assemble deterministically, commit, then enrich; or enrich before opening the write tx.
- **KB has no correct/edit/retire lifecycle** — the `archived` status is dead capability; a wrong article keeps being recalled (`kb-governance`). → add a retire/supersede endpoint that flips `status`.
- **Mirror + semantic/embedding best-effort layers have zero test coverage** (`support_mirror.ts:61`) → add unit tests (the exact class of bug behind P1-A/E).
- **Mirror/cluster/KB tables grow unbounded with no retention** (`ops`) → define a retention/archival policy.

**P3 (minor / nits, 19):** verb→404-instead-of-405 on some routes (`support_router.ts:72`); `cluster.root_cause` overwritten with `''` on cluster-resolve (`:298`); type-only cyclic import footgun between `support_kb_service` ↔ `support_platform_service` (`:13`); mirror-write bridge doesn't verify the source incident exists/owned on INSERT (defense-in-depth, `migration …040:236-241`); AI-enriched investigation path can override the exact-match confidence floor / "Known issue" fix (`support_platform_service.ts:298`); permissions-fetch failure renders a definitive denial instead of an error state (`shell.tsx:32`); `clusterSize` fetches all incident UUIDs just for `.length` (`:217`); ILIKE search with no trigram index (`support_kb_repository.ts:150`); `incident_count` full `COUNT(*)` on every link (`support_platform_repository.ts:247`); enabling embeddings later never backfills existing KB articles (`support_kb_service.ts:163`); pre-auth route-shape enumeration (validation before 401/403); GET-incident performs cluster writes; redefined `Page<T>`; constant-vs-claims tenant-scoping idiom mix; triple-guarded "set resolved" smell; concurrent-first-view cluster-count drift (cosmetic).

---

## 6. What the audit affirmed (no P0; strengths)

- **Tenant isolation holds.** Every mirror + KB table is `ENABLE`+`FORCE` RLS with `app_current_tenant_id() = PLATFORM_ORG` USING+WITH CHECK; the edge runs as the NOBYPASSRLS `erp_tenant` role, so RLS — not the `WHERE platform_org_id=…` filter — is the real backstop. A school session can never read the mirror/KB; a PLATFORM_ORG session matches no school row.
- **SECURITY DEFINER surface is textbook-correct.** All bridges take source org/school from the session GUC (never a parameter), pin `search_path`, `REVOKE PUBLIC`/`GRANT erp_tenant`, and the resolution bridge asserts the caller IS PLATFORM_ORG and bounds every write to the exact recorded source incident. No dynamic SQL. **ASIP-8 introduces no new SECURITY DEFINER.**
- **ASIP-8 design is sound.** The KB is keyed by the same deterministic cluster fingerprint as clustering (recall aligns with "investigate once, resolve many"), deterministic recall needs no embeddings, the semantic layer is dormant-safe, and `applyPriorResolutions` correctly floors/caps confidence without lowering a stronger base.
- **Migrations are additive, monotonic, idempotent, and well-constrained;** the pgvector guard degrades with a NOTICE (dormant-safe).
- **The live-cert is genuinely hermetic** (cert-unique path; cleanup removes incident + KB article + cluster; 0 residue) and asserts the ASIP-8 learn+recall path (23 checks).

---

## 7. Roadmap disposition

- **ASIP engineering roadmap (ASIP-1…8): COMPLETE** (built + green). Unchanged.
- **ASIP-1…7: PRODUCTION CERTIFIED + LIVE.** Unchanged — not voided by this audit.
- **ASIP-8 + canonical-trunk fold-in: CONDITIONAL** — production certification gated on remediating **P1-A…E**. **P1-D (migration renumber) is a hard prerequisite for any trunk fold-in / deploy.** These conditions are recorded in roadmap §5.6 and belong to the **unified ERP pilot deployment phase** (no standalone deploy).
- P2/P3 backlog recorded here for scheduling; none gate certification.

## 8. Recommendation

Accept the **CONDITIONAL certification**. Because the audit is not clean (5 confirmed P1s), do **not** close the program as unconditionally CERTIFIED. Keep ASIP-8's production certification and the trunk fold-in gated behind the §4 remediation plan (P1-D first), fold that plan into the unified ERP pilot deployment phase, and — since no P0 exists and the live pilot is unaffected — the AI Support engineering session may be closed with these conditions carried forward. **No fixes, deploys, or production changes were made during this audit.**
