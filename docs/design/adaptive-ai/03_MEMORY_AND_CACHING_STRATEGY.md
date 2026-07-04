# Adaptive AI Design 03 — Memory & Caching Strategy

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` · **Framework:** [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md) · **Consumer:** [`02_CONTEXT_ENGINE_DESIGN.md`](02_CONTEXT_ENGINE_DESIGN.md)
**Anchors:** Blueprint §3/§7 · Audit `06` findings **AI-1** (no rate-limit/spend-cap), **AI-2** (zero caching), **AI-3** (no timeout), **AI-4** (silent no-key degradation) · Roadmap **P3-AI-1** items 1/2/3/5/6.

> **Purpose.** This document is the **cost moat**. It designs (a) the four memory stores that make
> Akshara school- and person-adaptive, and (b) the cache + governance layer that holds live model
> calls to ≤5% of impressions. Ground truth (audit + code survey): today there is **no AI cache, no
> rate limit, no spend cap, no AI telemetry** — the only cache in the system is a 60-second
> process-local map in `widget_data_service.ts`. Everything below is greenfield **except** the
> stores it deliberately reuses.

---

## 1. What already exists (reuse, don't rebuild)

| Existing asset | Reused as |
|---|---|
| `ai_copilot_sessions` + `ai_copilot_messages` (RLS-scoped) | the persistence substrate of **Interaction Memory** (add summarization columns, not new tables) |
| `platform_provider_configs` + `platform_secret_vault` (`ai_settings.ts`, DB-first key resolution) | per-tenant AI config surface — extended with budget/limits fields |
| `_shared/intelligence/*` deterministic services + snapshot/rollup patterns | the compute layer behind **Fact/Signal Memory** |
| `domain_events` outbox (157 event types, transactional) | the invalidation & refresh trigger stream (doc 04 adds the consumer) |
| `parent_language_preferences` | the language dimension of every cache key |
| Widget platform RLS pattern (`dashboard_layouts` org+school scoping) | the RLS template for every new memory/cache table |

---

## 2. The four memory stores

All stores are **tenant Postgres tables under the proven RLS pattern** (org+school scoped,
`erp_tenant` grants, NOBYPASSRLS). Memory holds **facts and preferences only — never unvalidated
model output** (a cached *validated* generation lives in the cache, not in memory).

### 2.1 `ai_school_profile` — School Profile Memory (one row per school)
- **Holds:** board(s), size band, section structure, enabled modules/capabilities, branding tokens,
  term calendar shape, fee cadence, working days/hours, holiday pattern, language mix,
  **learned threshold overrides** (§2.5), `profile_version` (monotonic).
- **Written by:** onboarding + config changes (triggers bump `profile_version`) + the nightly
  threshold-learning job.
- **Read by:** every Context Engine spine load (C1); every cache key (doc 02 §4).

### 2.2 `ai_persona_memory` — Persona Memory (one row per user per school)
- **Holds:** preferred/pinned/dismissed widgets, "don't show again" flags, favourite actions,
  quiet hours, digest opt-ins, recommendation accept/dismiss counters per recommendation type,
  feature-usage frequency vector, typical active hours.
- **Written by:** interaction events (accept/dismiss/pin/dismiss-card/open) — small, idempotent
  upserts; **never** free text.
- **Read by:** dashboard composition (doc 04 §5), Recommendation Engine weights, C7/C11.

### 2.3 Interaction Memory — extend `ai_copilot_sessions`/`ai_copilot_messages`
- **Adds:** a per-session **deterministic rolling summary** (entities touched, intents resolved,
  last-K raw turns) so a copilot turn sends `summary + last K turns`, not the full transcript
  (doc 02 §7); plus per-user "recently asked" question fingerprints feeding the semantic cache.
- **Retention:** raw turns 30–90 days (owner-configurable); summaries longer; all RLS-scoped.

### 2.4 `ai_fact_signals` — Fact/Signal Memory (materialized rollups)
- **Holds:** per-scope pre-computed signals with freshness stamps: attendance % (school/class/student),
  marks-completion per teacher/exam, fee aging buckets + defaulter queue, at-risk list (from the
  existing `student_risk_engine`), overdue-book list, low-stock list, doc-expiry horizon,
  approvals-pending counts + ages.
- **Written by:** (a) event-driven incremental updates from the `domain_events` consumer (doc 04 §2),
  (b) nightly full recompute jobs (drift correction + pre-warm input).
- **Read by:** Priority Engine, widgets, briefs, C9/C10 — **this is what makes dashboards instant
  and model prompts tiny** (facts are injected pre-computed, not re-queried or re-derived).

### 2.5 Learned defaults (the adaptive heart, pure T1)
Nightly job per school, deterministic statistics only:
- fee-follow-up trigger = f(school's historical payment-delay distribution)
- "at-risk attendance" threshold = f(school's attendance base rate)
- marks-entry "overdue" = f(school's typical entry lag after exam end)
- reorder points = consumption rate × lead time (per item, per school)

Each learned value is stored in `ai_school_profile.learned_thresholds` **with its evidence**
(sample size, window, formula id) so every adaptive behaviour is explainable and revertible
(owner can pin a manual value). **Zero model calls; this is most of "adaptive."**

---

## 3. The cache layer (Tier 2)

### 3.1 `ai_response_cache` (exact-key)
```
key (doc 02 §4 hash) · school_id · surface_id · language · payload (validated output)
entity_tags[] · created_at · expires_at · hit_count · tokens_saved
```
- RLS org+school scoped (defense-in-depth beyond `school_id` in the hash).
- **Write-through:** every validated T3 output is cached unless the manifest opts out.
- **Read path:** Context Engine mints key → cache lookup → hit = serve (<150ms), miss = T3.

### 3.2 Semantic cache (paraphrase matching) — two stages
- **Stage 1 (W1, no embeddings):** deterministic **intent fingerprinting** — normalize the
  question (lowercase, strip stopwords, extract entities via the existing
  `principal_query_service`-style intent detection) → fingerprint key into `ai_response_cache`.
  Catches "fee due for Aarav?" ≈ "when is Aarav's fee due" with zero new infrastructure.
- **Stage 2 (W2):** pgvector embedding-nearest over cached Q&A per school+persona+language;
  cosine threshold tuned at pilot; embeddings are school-scoped rows (RLS), embedding calls are
  themselves cached by text hash.

### 3.3 Shared generations (P5)
A generation whose manifest declares scope `class_section` / `school` / `org` is stored once and
served to every user whose key maps to the same scope — e.g. one narrative per class-section
morning brief, one principal pulse per school per day, one director digest per org per week.
Personal greeting/name and per-user numbers are **re-applied deterministically** (T0 slots) on top
of the shared prose so nothing personal enters the shared entry.

### 3.4 Pre-warmed briefs (P6)
Nightly scheduled jobs (rides the XCT-2 rail, doc 04 §6) recompute Fact/Signal rollups, then
generate the small fixed set of next-morning narratives (teacher class-briefs, principal pulse)
into the cache. Morning logins hit T2; **the school's daily "AI experience" costs a handful of
calls made off-peak** — and if generation fails, the T1 brief renders anyway.

### 3.5 TTL & invalidation policy (volatility classes from doc 02 §2)
| Class | Examples | TTL | Invalidation |
|---|---|---|---|
| Stable | explanations of config/policy, term narratives | 7–30 d | `profile_version` bump |
| Daily | briefs, digests, pulse | to next 04:00 pre-warm | nightly job replaces |
| Event-coupled | fee answers, attendance answers, approval summaries | 24 h cap | **entity-tag invalidation** on `domain_events` (fee paid → `student:X:fees` tags die) |
| Volatile | anything on C6 recent-activity | never cached across sessions | n/a |

**Staleness rule:** an event-coupled cache entry is *invalidated by the event consumer within
seconds* of the underlying fact changing; TTL is only the backstop. Users never see a stale number
because **numbers never come from the cache** — prose comes from cache, numbers are re-rendered T1
live (P10 discipline: facts and phrasing are separable).

---

## 4. Cost governance (closes AI-1 / AI-3 / AI-4)

New `ai_call_log` (append-only, RLS): surface, user, school, model, tokens in/out, cost estimate,
latency, cache-written, fallback-used. Every T3 call logs one row — **no exceptions** (single choke
point: the Model Gateway).

| Control | Design |
|---|---|
| **Rate limit** | token-bucket per user (e.g. 30 T3 calls/hr) and per school (e.g. 500/day) — enforced in the gateway before the provider call; 429 → T1 fallback + gentle UI notice |
| **Monthly spend cap** | per-school budget in `platform_provider_configs`; at 80% → warn operator; at 100% → **soft-degrade**: T0–T2 continue (the product still feels intelligent), T3 disabled except owner-whitelisted surfaces |
| **Request timeout** | AbortController deadline (15–20s) on the provider fetch → deterministic fallback (closes AI-3) |
| **No-key health** | key absent/invalid → Control Center health signal + per-surface "AI enrichment unavailable" state; never silent substitution (closes AI-4) |
| **Budget visibility** | Control Center panel: spend vs cap, calls by surface, cache-hit ratio, tokens saved — per tenant |
| **Token bounds** | per-manifest `max_tokens` (already the pattern: copilot 1024, predictions 500, parent insights 900) — kept and enforced centrally |

---

## 5. Economics model (design target, measured at pilot)

Assume a 1,000-student school, ~60 staff, ~800 active parents.

| Surface class | Naive all-LLM (calls/day) | This design (calls/day) | Mechanism |
|---|---|---|---|
| Dashboards/widgets (all personas) | ~3,000 | **0** | T1 + Fact/Signal Memory |
| Morning briefs (teachers+principal) | ~65 | **~10** | pre-warm + shared per class-section |
| Parent Q&A / copilot | ~400 | **~30–60** | intent fingerprint + semantic cache + T1 answers for enumerable intents |
| Notifications/reminders | ~1,000 | **0** | T0 catalog + rules |
| Recommendations/priority feed | ~2,000 | **0** | T1 Priority Engine |
| Drafts (broadcast/recovery letters) | ~20 | ~15 | draft-and-hold is inherently per-use; bounded |
| **Total** | **~6,500** | **~55–85 (~99% reduction)** | |

Per-school monthly cost is then bounded by cap, dominated by copilot long-tail — and it *falls*
over time as the semantic cache fills (write-through corollary, doc 01 §2).

---

## 6. Privacy, isolation & retention

- Every memory/cache/log table: org+school RLS, `erp_tenant` grants, no cross-tenant reads —
  a cached generation **never** serves another school even on an identical key (school_id is in
  both the hash and the row scope).
- No child PII in shared-scope cache entries (personalization re-applied per user, §3.3);
  Director surfaces stay aggregate-only per the existing privacy rule.
- Interaction raw-text retention 30–90 days (owner-set); `ai_call_log` stores **hashes**, not raw
  prompts; memory tables export/wipe with the tenant (backup/DR inherits the existing rails).

---

## 7. Recommendations (rubric per doc 01 §5)

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| `ai_response_cache` + write-through | the single highest-leverage build (audit AI-2): every answer becomes reusable | 🌟🌟🌟 | 70–95% on all T3 surfaces | M | **W1** |
| Rate-limit + spend-cap + `ai_call_log` | unbounded-spend risk (AI-1) closed; cost becomes observable then optimizable | 🌟🌟 (trust/ops) | caps worst case | S–M | **W1** |
| Timeout→fallback + no-key health | closes AI-3/AI-4; AI can never hang or silently vanish | 🌟🌟 | n/a (safety) | S | **W1** |
| Fact/Signal Memory (`ai_fact_signals`) | one rollup powers widgets+feed+briefs+context; prompts shrink; dashboards go instant | 🌟🌟🌟 | enabler of T1-share ≥85% | M | **W1** |
| Learned per-school thresholds (evidence-backed, pure T1) | "adaptive" without a single model call; explainable + owner-overridable | 🌟🌟🌟 | 100% | M | **W2** |
| Intent-fingerprint cache (Stage 1 semantic) | reuses the existing deterministic intent-detection pattern; big paraphrase wins with zero new infra | 🌟🌟 | +10–20% copilot hit-rate | S | **W1** |
| pgvector semantic cache (Stage 2) | catches the long paraphrase tail once volume justifies it | 🌟 | +10–15% further | M | **W2** |
| Shared generations + pre-warmed briefs | N teachers ≠ N calls; mornings feel magical, cost pennies off-peak | 🌟🌟🌟 | up to 99% on brief surfaces | M | **W2** |
| Persona Memory accept/dismiss learning | personalization that compounds, deterministic, private | 🌟🌟 | 100% (T1) | S | **W2** |

---

*Next: [`04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md`](04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md) —
the consumer on `domain_events` that keeps this memory fresh, the Priority Engine that orders every
persona's day, and the adaptive dashboards that surface it.*
