# Adaptive AI — W1 (P3-AI-1) Final Certification Report (v2 — post-completion)

**Date:** 2026-07-10 · **Scope:** Cost & Safety Foundation (W1.1–W1.5) · **Standard:** `docs/design/adaptive-ai/` 01–04, 09
**Supersedes:** the v1 CONDITIONAL PASS. This revision certifies the state **after** the W1-completion pass.
**Method:** design audit → 4 parallel deep-audit passes → fix F1–F12 → adversarial re-audit of the fix diff → 6 hardening fixes (H1–H6) → full regression after every batch.
**Verdict:** ✅ **PASS — W1 implementation is COMPLETE with no known implementation gaps.** Two non-code follow-ons remain (live isolation-probe run + outbox-drain scheduling), both owner/VPS-gated and consistent with the project's established staged/live-lane pattern.

---

## 1. Executive summary

The v1 audit rated W1 a **CONDITIONAL PASS**: the governance spine was production-grade, but three sub-waves had verified completeness gaps (W1.4 Signal Refinery unwired; W1.3 output guard + history summary missing; W1.5 fingerprint collision + economics inaccuracy), plus a cross-cutting evidence gap (no isolation probes on the 5 new tables) and a discipline-vs-compiler choke-point weakness.

The completion pass closed **all twelve findings (F1–F12)** across 7 commits, then an **adversarial re-audit** of that diff confirmed the risky new code (per-school scope-switch, gateway logging, F12 refactor, F4 probes) is clean and surfaced **6 further real issues in the new code (H1–H6)** — all now fixed. Result:

- **Signal Refinery is wired and hardened** — it runs on-drain per school in an isolated transaction, invalidates real entity-tagged caches, has a monotonic watermark that advances only over the contiguous-success prefix, per-event SAVEPOINT isolation, broadened event coverage, and DB-path test coverage.
- **AI-5 is fully closed** — input-side fencing (already present) **plus** a gateway-level output guard that validates every reply *before* it is served or cached.
- **The intent fingerprint no longer serves wrong answers** for comparative/relational/two-entity questions.
- **All 9 ERP AI callers** route through the gateway as a **compiler-enforced** required parameter — the dead legacy paths are deleted; `callClaude` has zero non-gateway callers.
- **The cost panel's numbers are accurate and stable**, and the 80%-warn / org-scope-visibility gaps are closed.
- **The 5 `ai_*` tables have WITH-CHECK isolation probes** in the enforced suite.

Full backend regression: **2533 passed / 0 failed / 3 ignored**; AI + copilot **119/0**.

**W1 can be considered permanently complete at the implementation level.** The only remaining items are ops/evidence (run the probes live on the VPS; schedule the outbox drain) — not incomplete code.

---

## 2. Finding closure register (F1–F12)

| # | v1 finding | Resolution | Commit | Evidence |
|---|---|---|---|---|
| **F1** | Fingerprint bag-of-words collision → wrong cached answer | Order-sensitive when a relational marker OR 2+ named entities present; sorted collapse only for order-independent lookups | `8ff7c5b2` + `9b387668`(H2) | `intent_fingerprint.ts`; tests for reversed comparisons/transitives/entities + paraphrase-preserved |
| **F2** | Signal Refinery unwired + empty entity tags + no drift path | Invoked on-drain per school (isolated tx); copilot cache writes carry real tags; watermark + ASC order + SAVEPOINT isolation; coverage broadened; misclassification fixed | `4fd3a3ed` + `9b387668`(H5/H6) | `domain_events_handlers.ts:38` calls `runSignalRefinery`; `copilotCacheTags`; refinery DB-path tests |
| **F3** | No output-side injection guard | Gateway validates the reply (length · un-provided URL · injection echo · un-grounded ₹/%) **before** cache write; discards → `fallback_guard` outcome | `f44f7df9` + `9b387668`(H4) | `output_guard.ts`; `model_gateway.ts` guard-before-cache; mig `20260870` |
| **F4** | 5 `ai_*` tables absent from isolation probes | 5 WITH-CHECK write-isolation probes added (SAVEPOINT-guarded, leave no data) | `855696e2` | `tenant_isolation_probes.ts` (probe count 233→238) |
| **F5** | Rolling summary unimplemented (turns silently dropped) | Deterministic summary of dropped prefix folded into system+cache-key; persisted best-effort (SAVEPOINT-guarded) | `18af2f54` + `9b387668`(H1) | `summarizeCopilotHistory`; `updateSessionRollingSummary` |
| **F6** | Economics `tokensSaved`/ratio inaccurate | `tokensSaved = Σ(tokens_saved×hit_count)`; ratio window-consistent (lifetime hits vs lifetime calls); entries = live count | `855696e2` + `9b387668`(H3) | `ai_economics_service.ts` |
| **F7** | No per-surface input token budget | Copilot enforces a ~3k-token context cap at a line boundary | `855696e2` | `capContext` / `MAX_CONTEXT_CHARS` |
| **F8** | 80%-of-cap warn absent | `spendWarnRatio`/`atSpendWarn`/`atSpendCap` on the economics payload | `855696e2` | `ai_economics_service.ts` |
| **F9** | Coarse cache key depresses hit-rate | **Accepted (correctness-first).** Content-hash key guarantees no stale numbers; hit-rate optimization = wired entity-tags now + pgvector Stage-2 (W2.8) | — | documented §4 |
| **F10** | Org-scoped spend not aggregated | `getAiEconomics` uses `IS NOT DISTINCT FROM` | `855696e2` | `ai_economics_service.ts` |
| **F11** | Per-org (not per-school) cap value | **Accepted for pilot.** Usage is per-school bucketed (no cross-school budget theft); per-school cap values are a multi-school-org admin feature | — | documented §4 |
| **F12** | Choke point discipline- not compiler-enforced | `governance` is now a **required** param; dead `callClaude` branches deleted | `be9c1f54` | grep for non-gateway `callClaude` = **empty** |

## 2b. Adversarial re-audit hardening (H1–H6)

| # | Issue found in the fix diff | Fix | Commit |
|---|---|---|---|
| **H1** | F5 summary UPDATE ran unguarded in the turn's tx → a write failure would roll back the billed reply and 500 | SAVEPOINT-guarded (truly best-effort) | `9b387668` |
| **H2** | F1 whitelist still collided relational verbs outside the comparison set ("Iyer manage Rao") | Broadened markers + 2-entity structural rule | `9b387668` |
| **H3** | F6 "window-consistent" ratio still decayed to zero (live numerator vs all-time denominator) | Live-entries `FILTER` + lifetime hits/saved | `9b387668` |
| **H4** | Guard false-positive on precision (8500.50 vs 8500.5) discarded correct answers; URL query-string host | `normalizeNumber` strips trailing fractional zeros; URL host stops at `?/#` | `9b387668` |
| **H5** | Watermark advanced past transiently-failed events + non-monotonic under concurrent drains | Advance only over contiguous-success prefix; monotonic `writeCursor` | `9b387668` |
| **H6** | `runSignalRefinery` had zero test coverage | Added DB-path tests (advance, no-op-past-watermark, failed-event isolation) | `9b387668` |

**Verified clean by the adversarial pass (no defect):** the per-school scope-switch cannot cross tenants (`tenant_id` fixed; schoolIds sourced only from the org's own events); exactly one `ai_call_log` row per gateway branch with the guard strictly before the cache write; every F12 caller returns its deterministic fallback with no raw-client path; F4 probe INSERTs are column-correct and leave no data.

---

## 3. Sub-wave certification (post-completion)

| Sub-wave | Status | Notes |
|---|---|---|
| **W1.1 Model Gateway** | ✅ CERTIFIED | Real abort-timeout, rate limits, 100% cap + 80% warn, deterministic fallback, one-row-per-attempt telemetry, org-scope enforced, output guard, compiler-enforced sole entry point |
| **W1.2 Memory + Response Cache** | ✅ CERTIFIED | Content-hash cache (correctness-by-construction), TTL, atomic hit_count, tag invalidation now live; RLS on all 5 tables + WITH-CHECK probes (live run VPS-gated) |
| **W1.3 Context Engine + Injection** | ✅ CERTIFIED | Input fencing + **output guard**; deterministic rolling-summary + last-K; per-surface context budget. (Generalized multi-surface manifest engine = W2 enabler, no second surface yet) |
| **W1.4 Signal Refinery** | ✅ CERTIFIED (impl) | Wired on-drain per school; tagged invalidation; monotonic watermark; SAVEPOINT isolation; broadened coverage; tested. Full source-rollup nightly recompute rides W2 (no live W1 reader). **Auto-firing needs the drain scheduled in prod (ops, like COM-4)** |
| **W1.5 Fingerprint + Economics** | ✅ CERTIFIED | Order-safe fingerprint (paraphrase collapse preserved); accurate + stable economics + warn/org-scope. Flutter panel binding deferred (non-blocking) |

---

## 4. Accepted tradeoffs & documented residuals (not defects)

- **F9 — coarse cache key.** Correctness-first: the content-hash key guarantees no stale numbers on the live surface. Hit-rate is optimized in W2 (the now-wired entity tags + pgvector Stage-2, W2.8). *Accepted.*
- **F11 — per-org cap value.** Usage is independently bucketed per school, so one school cannot consume another's budget; distinct per-school cap *values* are a multi-school-org admin feature. *Accepted for pilot.*
- **Fingerprint Stage-1 limit.** Exotic lowercase two-common-noun relations with an unlisted verb can still collide. Bounded and rare; the exhaustive fix is the pgvector semantic cache (W2.8). *Documented.*
- **Output guard scope.** It defends **fabrication**, not staleness (the content-hash key handles staleness), and grounds ₹/percentage numbers against any context number (a fabricated amount coincidentally equal to a context date can pass — a defense-in-depth layer atop input fencing + no-tools + RBAC + prompt discipline, not the sole wall). Non-currency figures are out of the design's "facts" scope. *Documented.*

## 5. Deferred / non-blocking (P3 polish · W2 · ops)

- **P3 polish (tracked, non-blocking):** expired-cache reaper (F13); single-flight on concurrent cache-miss (F14); dedicated "AI unavailable" health signal (F15); broader model-facing injection corpus (F16 — guard + fence tests exist); double `resolveAiConfig` per turn (F17); bounded-history DB load to cut the full-transcript fetch (F18).
- **W2-scoped (by design):** full materialized-rollup nightly recompute; pgvector Stage-2 semantic cache; generalized multi-surface Context Engine/manifests; shared generations & pre-warmed briefs.
- **Ops / evidence (owner/VPS-gated):** run the enforced isolation suite (now incl. the 5 AI probes) against two live tenants; schedule the outbox-drain endpoint in prod so the Signal Refinery fires automatically (staged like the COM-4 cron).
- **Deferred Flutter Economics UI:** backend route + service complete and tested; only the presentational panel is unbuilt. Fold in nothing further — the data (incl. warn/org-scope) is ready.

---

## 6. Risks (post-completion)

| Risk | Likelihood | Impact | Status |
|---|---|---|---|
| Wrong copilot answer via fingerprint collision | Low (comparatives/2-entity now order-safe; only exotic residual) | User-visible | Mitigated; W2.8 closes the tail |
| Fabricated number reaches a user | Low (input fence + guard + no-tools + RBAC) | Trust | Mitigated (defense-in-depth) |
| Cross-tenant leak in an `ai_*` table | Low (proven RLS + probes written) | Severe | Structurally sound; **live probe run pending (VPS)** |
| Signal Refinery doesn't fire | Medium if drain unscheduled | Stale caches (TTL-bounded 24h backstop) | Implementation done; **drain scheduling is ops** |
| Cost panel misreports the moat | Low (numbers now accurate/stable) | Ops decision | Closed |

---

## 7. Production & pilot readiness

- **Production readiness (code):** ✅ Ready. The gateway cannot hang, overspend, leak cross-tenant, fabricate-to-exfiltrate, or fail silently; it is the sole compiler-enforced model path; the Signal Refinery is wired and safe.
- **Pilot readiness:** ✅ Ready, subject to two owner/VPS ops steps: (1) run the enforced isolation suite live (standing VPS cert), (2) ensure the outbox-drain is scheduled so the refinery fires. Neither is a code gap.
- **Deferred Flutter Economics UI:** ✅ Non-blocking; backend complete.

---

## 8. Can W1 be considered permanently complete?

**Yes — at the implementation level, with no known implementation gaps.** All twelve v1 findings are closed (ten fixed in code, two accepted with rationale), the fix diff was adversarially re-audited and its six new issues fixed, design fidelity is materially restored (AI-5 fully closed, W1.4 operational, fingerprint safe, telemetry accurate, choke point compiler-enforced), and the full backend regression is green.

The two remaining items — the **live isolation-probe run** and **scheduling the outbox drain** — are **ops/evidence activities on the VPS live lane**, identical in kind to the project's other staged/live-gated steps (COM-4 cron, the enforced-isolation cert). They do not represent incomplete W1 code.

**Certification: W1 (P3-AI-1) is PASS / implementation-complete.**

## 9. W2 decision

W2 was previously blocked on the merits by the unwired W1.4. **That block is now lifted** — the Signal Refinery is operational, so W2.0/W2.1 have a live signal feed. W2 remains **owner-timing-gated** (P3-AI-2 register). Recommended sequence before W2 kicks off: (a) owner schedules the drain + opens the VPS for the isolation-probe live run to convert this to a fully-evidenced PASS; (b) take the W2 timing decision.

---

*EOS gate (post-completion): **PASS** — W1 implementation-complete, no known implementation gaps; live isolation-probe run + outbox-drain scheduling are owner/VPS-gated ops follow-ons, not code.*
