# Adaptive AI Design 09 — Implementation Waves, Acceptance Criteria & Metrics

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` · **Executes as:** Master Roadmap **Phase 3** (`P3-AI-1`, `P3-AI-2`) under [`../../roadmap/AUTONOMOUS_EXECUTION_PLAN.md`](../../roadmap/AUTONOMOUS_EXECUTION_PLAN.md) (Executor: Opus 4.8, one wave → one `/eos` PASS → one commit)
**Traceability:** audit findings AI-1…AI-6 · Blueprint §12 build sequence · backlog IDs cited per item in docs 05–07.

> **Purpose.** This document turns the suite (docs 01–08) into an executable wave plan. Every wave
> has scope, dependencies, done-when, evidence, and its EOS gate. **W1 must complete before any W2
> item** (roadmap hard gate P3-AI-1 → P3-AI-2). W2 timing is an owner decision (👤 roadmap
> register); W3 items are post-GA candidates surfaced in a batch, never blocking.

---

## 0. Dependency preconditions (owned by other phases — verify, don't build here)

| Precondition | Owner | Blocks |
|---|---|---|
| Phase 0 complete (truth, safety, CI) | P0 | all of W1 |
| XCT-2 reminder/scheduling rail | P1-PROD-0 | W1.4 nightly jobs · all pre-warm/digest/reminder items |
| XCT-1 export pipeline | P1-PROD-0 | report/board-pack/daily-report exports |
| HWK-1 real homework due dates | P1 backlog wave | homework reminders/overdue intelligence (doc 05 §5) |
| FIN-6 real installment due-schedules (kills +30d hardcode) | P1 backlog wave | fee reminder ladders, C9 fee deadlines, recovery timing (doc 06 §1) |
| TRN-2 typed doc-expiry dates | P1 backlog wave | transport compliance clock (doc 06 §4) |
| MOD-1 library/hostel fines post to Finance ledger | P1 backlog wave (👤) | unified recovery CRM scope (doc 06 §3/§6) |
| COM-1 delivery/read tracking | P1 backlog wave | best-moment delivery (N5), resend-to-unread |
| Principal hub consolidation | P2 UX (or W2.3 first step) | Principal persona rollout (doc 07 §4.4) |
| Live AI key + OpenRouter config verified (AI-4 live part) | P0/ops | any T3 behaviour in pilot |

---

## W1 — P3-AI-1 · Cost & Safety Foundation (build first; 🟠; EOS gate: AI)

*Everything here is platform plumbing — no persona features. Sub-waves in order; W1.1–W1.3 are
independent files/modules and may proceed as sequential commits by one stream (owner file-ownership
rule).*

### W1.1 Model Gateway hardening (closes AI-1, AI-3, AI-4)
- **Scope:** single choke point around `_shared/ai/anthropic_client.ts` callers: per-request
  AbortController timeout (15–20s) → deterministic fallback · token-bucket rate limits (per user +
  per school) · monthly spend cap with 80% warn / 100% soft-degrade · `ai_call_log` append-only
  telemetry · no-key/invalid-key → Control Center health signal + per-surface "AI unavailable"
  state (never silent).
- **Done-when:** forced-timeout test falls back deterministically; limit/cap tests return 429-path
  fallback; every T3 call in the test suite writes exactly one log row; no-key boot shows the
  health signal. **Evidence:** deno tests + a live smoke on the VPS. **Cx:** M.

### W1.2 Memory stores + response cache (closes AI-2 core)
- **Scope:** migrations for `ai_school_profile` (+`profile_version` bump triggers, learned-threshold
  columns) · `ai_persona_memory` · `ai_fact_signals` · `ai_response_cache` (entity-tags, TTL,
  hit counters) — all on the proven org+school RLS pattern (`erp_tenant`, NOBYPASSRLS, WITH CHECK) ·
  Interaction-Memory summarization columns on `ai_copilot_sessions`.
- **Done-when:** RLS probes (extend the 233-probe suite) prove cross-tenant isolation on every new
  table; write-through cache serves a repeated copilot question with 0 model calls. **Evidence:**
  isolation suite green; cache-hit integration test. **Cx:** M–L.

### W1.3 Context Engine generalization (closes AI-5)
- **Scope:** extract/extend the copilot context loader per doc 02: surface manifests · section
  loaders C1–C11 · cache-key minting (shareable `persona_scope`) · delimit/label untrusted fields +
  output-side guard · per-manifest token budgets · copilot history = summary + last-K turns.
- **Done-when:** injection test corpus (names/remarks/questions carrying instructions) cannot alter
  behaviour beyond phrasing of permitted data; identical state twice → identical cache key;
  copilot turn tokens drop ≥40% vs full-history baseline. **Evidence:** injection suite + token
  telemetry diff. **Cx:** M–L.

### W1.4 Signal Refinery + event invalidation
- **Scope:** the `domain_events` consumer (doc 04 §2): idempotent signal upserts into
  `ai_fact_signals` · entity-tag cache invalidation · derived-event scans (unmarked-by-cutoff) and
  nightly recompute/pre-warm jobs on XCT-2 (or on-drain interim if XCT-2 not yet landed).
- **Done-when:** a `fee_collected` event invalidates the student's fee-tagged cache entries and
  updates aging signals within seconds in test; replay/duplicate events cause no drift (idempotency
  test); nightly job repairs an artificially drifted signal. **Evidence:** event-flow integration
  tests. **Cx:** M.

### W1.5 Intent-fingerprint cache (Stage-1 semantic) + cost panel (N10)
- **Scope:** deterministic question normalization/fingerprinting on the copilot path (reuse the
  `principal_query_service` intent pattern) · Control Center AI economics panel over `ai_call_log`
  (spend vs cap, calls by surface, cache-hit ratio, tokens saved).
- **Done-when:** paraphrase pairs hit the same cache entry in test; panel renders live per-tenant
  numbers. **Cx:** S–M.

**W1 EXIT (EOS AI gate):** all AI-1…AI-5 findings closed with tests · ≥90% of AI-surface
impressions in the staging exercise served with 0 model calls · spend-cap enforcement demonstrated ·
no fabricated numbers in any T3 output validation · isolation suite green on all new tables.

---

## W2 — P3-AI-2 · Adaptive Wave (👤 owner timing; EOS gate: AI per sub-wave)

*Order: platform engines → personas (Teacher → Parent → Principal → Director → Student). Each
sub-wave = one EOS-gated commit. Module surfaces (docs 05/06) ship inside the persona wave that
consumes them.*

| Sub-wave | Scope (docs) | Key deliverables | Done-when (headline) |
|---|---|---|---|
| **W2.0 Priority + Recommendation engines** | doc 04 §3–4 | typed priority items · explainable scoring · per-persona feeds · accept/dismiss learning (P12) · one-click action registry (P11) | feed <150ms p95, 0 model calls; "why is this first?" renders factor breakdown; accept/dismiss reweights in test |
| **W2.1 Brief/digest platform** | doc 03 §3.3–3.4, doc 07 §6.4 | shared-generation scopes · pre-warm jobs · T0 digest assembly | one generation serves N same-scope users (log proof); morning brief served from cache at first login |
| **W2.2 Teacher rollout** | doc 07 §1 + doc 05 (Attendance/Exams/Homework surfaces) | priority strip, fast-mark/marks deep-links, class-section briefs, teacher intent router | teacher day exercise: ≤1 model call; EXM-1/ATT-3/TCH-1/2 flows live |
| **W2.3 Parent rollout** | doc 07 §2 + doc 05 (Communication/Finance parent surfaces) | T0 reminder ladders (PAR-5), family consolidation (N4), parent intent router + 7-language semantic cache, weekly insights rescheduled to pre-warm | reminder ladder fires from events; parent Q&A ≥85% zero-call in staging corpus |
| **W2.4 Principal rollout** | doc 07 §4 + doc 05/06 exception boards | hub consolidation precondition · batch-approvals with summary chips (PRI-1) · daily pulse + weekly digest (PRI-3/4) · marks/attendance exception boards (EXM-2/ATT-4) · substitution pre-staging (N8) | one hub; batch-approve live; pulse = 1 call/school/day off-peak |
| **W2.5 Director rollout** | doc 07 §5 | league table + drill-downs + CSV (DIR-1/2/3) · weekly org digest · aggregate-only manifests enforced | zero student-row loaders reachable for the persona (test); digest = 1 call/org/week |
| **W2.6 Student rollout** | doc 07 §3 | topic-scoped study assistant on the school-scoped explanation cache · tone guard · streak chips | tone-guard corpus passes; explanation cache hit-rate ≥80% by week 2 of staging |
| **W2.7 Ops-module worklists** | doc 06 | recovery call queue + PTP (FIN-R2/R3) feeds · reorder→PO one-click (INV-4) · expiry radars (TRN-2/8, HR-7) · overdue worklists (LIB-1/5) | each worklist live from Signal Refinery, 0 model calls |
| **W2.8 pgvector semantic cache (Stage 2)** | doc 03 §3.2 | embedding-nearest per school+persona+language | measured +hit-rate over Stage-1 baseline; embeddings RLS-scoped |
| **W2.9 Truth-in-naming** | audit AI-6 | rename deterministic "Intelligence" surfaces → "Analytics" | no deterministic surface labeled AI |

**W2 EXIT (EOS AI gate):** dashboards/thresholds measurably differ per school with no code change ·
per-persona zero-call ratios hit targets (§ Metrics) · cost bounded under cap at pilot scale ·
recommendation accept-rate being measured.

---

## W3 — Post-GA / owner-decision candidates (surface in a batch — never blocking)

Handover packs (N3) · best-moment delivery (N5, needs COM-1) · cross-module promise graph (N6 full)
· peer benchmarks (N7 👤 consent design) · circular-to-action (N9) · predictive pre-staging
extensions (doc 04 §7 tail) · Office/Admin + Finance-clerk persona routers (doc 07 §6.1).

---

## Metrics (the EOS AI gate measures these; targets from Blueprint §13, refined)

| Dimension | Target | Measured via |
|---|---|---|
| API minimization | ≥90% of AI-surface impressions with 0 model calls (per persona: Teacher ≥95%, Parent ≥85%, Principal ≥90%, Director ≥95%, Student ≥90%) | `ai_call_log` + impression telemetry |
| Cache effectiveness | copilot cache-hit (fingerprint+semantic) ≥50% by pilot week 4, rising | cache hit counters |
| Cost | per-school monthly spend ≤ cap; median tracked from pilot week 1 (₹X set at pilot) | cost panel (N10) |
| Latency | T0/T1/T2 <150ms p95 · T3 <2s p95 with timeout fallback ≤20s hard | request telemetry |
| Adaptivity | ≥3 learned thresholds diverged (with evidence rows) per pilot school by week 4; dashboards differ per school | `ai_school_profile` diff |
| Adoption | brief open-rate and recommendation accept-rate trending up over pilot | Persona Memory counters |
| Safety | 0 cross-tenant leakage (probe suite) · 0 AI-caused writes · 100% T3 calls logged · injection corpus green · 0 fabricated numbers in validation | suites + log audit |

---

## Standing test assets (built in W1, run every AI wave — per AUTONOMOUS_EXECUTION_PLAN §3/§5)

1. **Injection corpus** (names/remarks/questions with embedded instructions, per doc 02 §5).
2. **Determinism validator** — every T3 output's numbers must equal the injected T1 facts.
3. **Isolation probes** for every `ai_*` table (extends the 233-probe suite).
4. **Cost regression** — a wave may not raise the zero-call ratio's denominator without raising the
   numerator (i.e., no new surface ships below its declared tier).
5. **Fallback drills** — no-key, timeout, over-cap, over-rate: every path must render the T1 core.

---

## Traceability

| Audit finding | Closed by |
|---|---|
| AI-1 rate-limit/spend-cap | W1.1 |
| AI-2 no caching | W1.2 + W1.5 + W2.8 |
| AI-3 no timeout | W1.1 |
| AI-4 silent no-key | W1.1 (+ live key verified per P0) |
| AI-5 prompt injection | W1.3 |
| AI-6 "Intelligence" naming | W2.9 |

Backlog IDs are cited inline in docs 05–07 per item (FIN-R*, EXM-*, ATT-*, PRI-*, PAR-*, DIR-*,
TRN-*, INV-*, LIB-*, HWK-*, COM-*, ADM-*, SIS-*, TCH-*); the enhancement backlog remains the frozen
source of truth for their product scope — this suite adds the intelligence layer on top, it does
not re-scope them.

---

*Suite index: [`00_ADAPTIVE_AI_DESIGN_INDEX.md`](00_ADAPTIVE_AI_DESIGN_INDEX.md).*
