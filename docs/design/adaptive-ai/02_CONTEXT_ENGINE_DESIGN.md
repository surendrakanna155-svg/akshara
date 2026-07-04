# Adaptive AI Design 02 — The Context Engine

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` · **Framework:** [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md)
**Anchors:** Blueprint §4 (Context Engine) · Audit `06` (copilot context pattern, AI-5 injection finding) · Roadmap **P3-AI-1** items 1/4/6.

> **Purpose.** One engine assembles the context for *every* intelligent surface — deterministic
> widgets, priority feeds, cached answers, and the rare live model call. It generalizes the audited
> copilot context loader into a platform service with three jobs:
> **(1)** build the smallest RBAC-safe, tenant-safe context bundle;
> **(2)** mint the **cache key** that makes API-minimization work (doc 03);
> **(3)** neutralize prompt injection by construction (closes AI-5).

---

## 1. Position in the architecture

```
caller (widget · feed · copilot · router · nightly job)
        │  ContextRequest {surface, user, screen, subject?, question?}
        ▼
┌──────────────── CONTEXT ENGINE ────────────────┐
│ 1 Resolve identity & role  (JWT claims)         │
│ 2 Resolve permissions      (RBAC scope-set)     │
│ 3 Load context sections    (only what RBAC +    │
│   the surface's manifest allow)                 │
│ 4 Delimit & label all untrusted data            │
│ 5 Compact + cap size (per-surface token budget) │
│ 6 Mint cache key + language + persona flags     │
└────────────────────────────────────────────────┘
        │  ContextBundle + CacheKey
        ▼
T1 renderers · T2 cache lookup · T3 Model Gateway
```

The engine itself is **pure T1** — deterministic reads, no model calls. It is consumed identically
whether the eventual answer is a widget (no model) or a copilot reply (maybe model): this is what
lets the cache tier sit *in front of* the model transparently.

---

## 2. The eleven context dimensions

Each dimension is a **section loader**: an independent, RBAC-guarded, parameterized query (or memory
read) returning a compact typed block. Surfaces declare which sections they need in a **surface
manifest**; the engine never loads more.

| # | Dimension | Contents | Source | Volatility (drives cache TTL, doc 03) |
|---|---|---|---|---|
| C1 | **School context** | school id/name/code, board(s), size band, sections, enabled modules/capabilities, branding, fee cadence, working days/hours, holiday pattern | **School Profile Memory** (doc 03 §2) | LOW — changes on config edits (versioned: `profile_version`) |
| C2 | **Academic context** | academic year, current term/semester, active exam cycle, grading scheme, timetable position ("period 3 now"), week type | academic config + calendar | LOW–MED — advances on schedule |
| C3 | **User role & persona** | persona (Teacher/Parent/…), role(s), staff/guardian links, class-teacher-of, subjects taught, children (parent), schools (director) | JWT claims + SIS links | LOW |
| C4 | **Permissions** | resolved RBAC scope-set for this user at this school; per-section allow/deny | RBAC engine (existing) | LOW — invalidated on role change |
| C5 | **Language** | UI language (English-first), parent's comms language preference, per-child overrides | `parent_language_preferences` + user prefs | LOW |
| C6 | **Recent activity** | last N screens/actions, last data entries, in-flight drafts, recent searches | client telemetry ring + Interaction Memory | HIGH — session-scoped, never cached across users |
| C7 | **Preferences** | pinned/dismissed widgets, favourite actions, quiet hours, digest opt-ins, "don't show again" | **Persona Memory** (doc 03 §2) | LOW–MED |
| C8 | **Calendar** | today/this-week events: exams, PTMs, holidays, fee-due dates, deadlines from every module | unified calendar view (T1 union query) | MED — event-invalidated |
| C9 | **Deadlines** | this persona's open obligations with due dates: marks-entry due, attendance unmarked, approvals pending, fees due, docs expiring, books overdue | **Fact/Signal Memory** rollups (doc 03 §2) | MED–HIGH — event-invalidated |
| C10 | **Alerts** | active exceptions above learned thresholds: at-risk students, defaulter spikes, low stock, capacity breaches, anomalies | Priority Engine output (doc 04) | HIGH — event-invalidated |
| C11 | **Historical behaviour** | accepted/dismissed recommendations, feature-usage frequency, typical login rhythm, threshold-tuning history | Persona Memory + Interaction Memory | LOW — aggregated, slowly-moving |

**Design rule:** C1–C5 are the **identity spine** — cheap, near-static, loaded for every request.
C6–C11 are **on-manifest** — loaded only when the surface declares them.

---

## 3. Surface manifests

Every intelligent surface registers a manifest (a static declaration, reviewed like code):

```
surface: teacher_morning_brief
persona: teacher
sections: [C1, C2, C3, C4, C8, C9, C10]          # no C6 free-text, no parent language
tier_path: T1 → T2(pre-warm, shared by class-section) → T3(narrative)
token_budget: 1200                                # hard cap on assembled context
cache: {scope: class_section, ttl: to_next_event, prewarm: nightly}
untrusted_fields: [student_names, remark_texts]   # will be delimited (§5)
```

Manifests give the platform three guarantees: **least-context** (injection surface and token cost
are bounded per surface), **reviewability** (a new AI surface = a manifest PR, visible in EOS AI
gate), and **cache-key stability** (§4).

---

## 4. Cache-key minting (the linchpin)

```
cache_key = hash(
    surface_id,
    school_id,                     # tenant isolation — never shared across schools
    persona_scope,                 # role + the RBAC scope-set hash (not raw user id when shareable)
    inputs_signature,              # hash of the loaded section values that the surface declares key-relevant
    language,
    profile_version,               # school profile version — config change rolls all keys
    prompt_template_version        # deploy-time constant — new prompt rolls the cache
)
```

- **Shareability by construction:** for shared generations (P5), `persona_scope` deliberately
  excludes the user id — every teacher of class 6-B with identical RBAC scope maps to the same key.
  For personal surfaces (parent Q&A), the user/child id is in scope and the entry is private.
- **Event invalidation:** each key registers the **entity tags** it depends on
  (`student:…`, `class:…`, `fees:…`); `domain_events` consumers invalidate by tag (doc 03 §5).
- **Security property:** `school_id` inside the hash **and** an RLS-scoped cache table (doc 03)
  give defense-in-depth against cross-tenant cache hits.

---

## 5. Prompt-injection hardening (closes AI-5)

All model-bound context is assembled as **labeled, delimited blocks** — never raw concatenation:

1. **Segregate trust classes.** System instructions (ours) · deterministic facts (T1 outputs) ·
   untrusted text (names, remarks, user questions) — three distinct, labeled channels.
2. **Delimit untrusted data** with unambiguous fenced markers and an explicit instruction that
   fenced content is data, not instructions (the manifest's `untrusted_fields` list drives this).
3. **Output-side guard:** validate the reply against the surface's expected shape (numbers must
   match the injected T1 facts; no URLs/instructions we didn't provide; length caps). On violation →
   discard, serve T1 fallback, log.
4. **No tools, read-only** stays absolute: the model gateway exposes zero function-calling on ERP
   actions, so a successful injection can at worst mis-phrase text it was already allowed to see.
5. **RBAC pre-filter is the real wall:** the bundle never contains data the user couldn't read via
   the normal API — injection cannot exfiltrate what was never loaded.

---

## 6. Assembly algorithm (deterministic, cacheable itself)

```
build(request):
  claims  = verifyJwt(request)                       # persona, school, roles
  scopes  = rbac.resolve(claims)                     # C4
  m       = manifests[request.surface]               # unknown surface → refuse
  assert m.persona ∈ claims.personas
  spine   = loadSpine(claims)                        # C1–C5, memoized per session
  extra   = [loadSection(s, scopes) for s in m.sections if allowed(s, scopes)]
  bundle  = compact(spine + extra, m.token_budget)   # drop lowest-priority facts first, never truncate mid-fact
  key     = mintKey(m, bundle, claims)               # §4
  return {bundle, key, language: spine.C5, tags: entityTags(bundle)}
```

Properties: **idempotent** (same state → same bundle → same key), **bounded** (token budget is a
hard cap), **fail-closed** (a section loader error drops the section and flags the bundle degraded —
it never widens scope or blocks the T1 render).

---

## 7. Sizing & latency budgets

| Path | Budget |
|---|---|
| Spine load (C1–C5, warm) | <20ms (session-memoized; School Profile is one row) |
| Full bundle (manifest sections) | <100ms p95 — section loaders run in parallel, each a single indexed query or memory read |
| Bundle size | per-manifest `token_budget`; global hard cap ~2k tokens for T3 surfaces (keeps every call cheap and fast) |
| Copilot history | last-K-turns window from Interaction Memory, summarized deterministically (turn count + entities), never the full transcript re-sent (fixes the audit's "re-sends full history every turn") |

---

## 8. Recommendations (rubric per doc 01 §5)

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| One engine for all surfaces (extend copilot's loader, don't fork per feature) | single RBAC/injection/caching choke point; every future AI surface inherits safety for free | 🌟🌟🌟 (indirect: everything rides it) | enabler of all T2 savings | M | **W1** |
| Surface manifests (declarative least-context) | reviewable AI surface registry; bounded injection + token cost; stable cache keys | 🌟🌟 | ~30–50% smaller prompts on T3 calls | S | **W1** |
| Cache-key minting with shareable `persona_scope` | turns N identical calls into 1 (P5 shared generation) — the single biggest cost lever | 🌟🌟 | up to 99% on brief/digest surfaces | S (with engine) | **W1** |
| Delimit/label + output guard (AI-5) | closes the audit's injection finding by construction, not per-surface discipline | 🌟 (trust) | n/a (safety) | S | **W1** |
| Deterministic copilot-history summarization | kills the costliest current pattern (full history re-sent per turn) | 🌟🌟 | ~50–70% tokens per copilot turn | S | **W1** |
| Unified calendar/deadline sections (C8/C9) as T1 services | one query powers dashboards, feeds, briefs AND context — computed once, used everywhere | 🌟🌟🌟 | 100% (pure T1) | M | **W2** |

---

*Next: [`03_MEMORY_AND_CACHING_STRATEGY.md`](03_MEMORY_AND_CACHING_STRATEGY.md) — the stores this
engine reads (School Profile, Persona, Interaction, Fact/Signal) and the cache tiers its keys unlock.*
