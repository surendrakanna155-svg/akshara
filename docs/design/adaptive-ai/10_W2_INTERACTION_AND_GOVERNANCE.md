# Adaptive AI Design 10 — W2 Interaction Model & AI Governance (Enterprise Addendum)

**Status:** 🟢 Design review (no code) · **Author:** Opus 4.8 · **Date:** 2026-07-10
**Suite:** `docs/design/adaptive-ai/` · **Layers on:** 01 (Decision Framework), 02 (Context Engine), 03 (Memory/Cache), 04 (Event/Priority), 07 (Persona), 09 (Waves) · **W1 foundation:** `ADAPTIVE_AI_W1_CERTIFICATION_REPORT.md`

> **This document does not rewrite the architecture.** It formalizes the *interaction model* and
> *governance rails* for W2 as an enterprise-grade **School AI**, reusing the W1 Model Gateway,
> governance, cache, Signal Refinery, the W2.0a Priority Engine (committed `2752be65`), Persona
> Memory, Widget Platform, Predictions, Analytics, and Copilot. It answers the owner's nine
> principles, **challenges the weak ones**, and refines the strong ones into one coherent model.

---

## 0. The thesis in one line

**Akshara AI is a governed, school-domain-bounded, deterministic-first decision surface where the
LLM is a small, metered, last-resort enrichment layer behind a five-gate firewall** — not a chatbot
with a school theme. The moat is the architecture and the governance, not the model.

---

## 1. The Interaction Ladder (refines doc 01 T0–T3)

Every user interaction resolves at the **highest-numbered cheap layer that can answer it**. The LLM
is reached only when a request is *inherently* generative (explain / summarize / rewrite / reason).

```
 L0  NAVIGATE   Universal School Search → jump to the record/module      (§8, zero tokens)
 L1  SHOW       Deterministic Insight Panels + Priority/Recommendation    (§6, zero tokens)
 L2  ANSWER     Intent-routed deterministic Quick Actions                 (§7, zero tokens)
 L3  REUSE      Response cache (exact + fingerprint + shared + semantic)  (§9, zero tokens)
 L4  GENERATE   Governed LLM — domain-gated, RBAC-bounded, quota'd        (§3–§6, metered)
```

L0–L3 are **Tier 0–2** (deterministic / cached, zero model calls); L4 is **Tier 3**. Target:
**≥97% of impressions resolve at L0–L3** (owner's 95–99%, tightened from the design's ≥90% because
Search + Quick Actions absorb most of the copilot long tail). Measured live via `ai_call_log`
impressions-vs-calls per persona.

---

## 2. The AI Firewall — five gates every LLM entry point MUST pass, in order

This is the enterprise control the design implied but never named. **No surface may reach the model
without traversing all five, in this order.** The W1 Model Gateway is gate 5; this addendum makes
gates 1–4 mandatory and centralizes them so a *new* AI surface inherits them for free.

| # | Gate | Rejects | Cost of rejection | Where it lives |
|---|---|---|---|---|
| **G1** | **Domain gate** (§3) | off-school-topic requests | **0 tokens** (deterministic) | Context Engine entry |
| **G2** | **RBAC / Context firewall** (§4) | data the user can't read | 0 tokens (pre-context) | Context Engine assembly |
| **G3** | **Deterministic resolver** (§6/§7) | anything a rule/query can answer | 0 tokens (T0–T1) | Quick-action + panel pipelines |
| **G4** | **Cache** (§9) | repeats & paraphrases | 0 tokens (T2) | `ai_response_cache` (W1.2/1.5) |
| **G5** | **Governed Gateway** (W1.1) | over-quota / no-key / timeout / bad output | fallback, logged | `model_gateway.ts` |

**Design rule:** the LLM is called **only** for requests that survive G1–G4. Everything else is free.

---

## 3. Principle 1 — School-only AI (the Domain Gate) · **AGREE, strengthen**

**Verdict: correct and essential. Build it server-side, deterministic, zero-token, reject-closed.**

- **Where:** a new pre-flight **Domain Gate** at the Context Engine entry — *before* any context
  load and *before* the gateway. It runs on the copilot/open-chat path (Quick Actions and Panels
  are already domain-bounded by construction — they have no free-text).
- **How (deterministic, no LLM):** two-tier classification.
  1. **Allow by intent match** — if the message maps to a known school intent (the per-persona
     intent router, seeded by `principal_query_service`), it is in-domain by definition. Covers the
     vast majority.
  2. **Screen the residual** — a deterministic out-of-domain detector: a curated block-lexicon
     (politics, movies, sports, code, medical, recipes, travel, celebrities, general trivia…) +
     a school-lexicon presence check + heuristics (URLs, code fences, "write me a…"). No intent
     match **and** off-domain signal → reject.
- **Reject-closed for open chat's ambiguous tail is acceptable** because a rejected in-domain
  question degrades to "rephrase or use a Quick Action," not silence. **Never spend a token to
  decide domain.**
- **Canned refusal (T0 catalog, localizable):** *"I'm the Akshara School Assistant — I can only help
  with school activities like attendance, homework, exams, fees, and student progress."* Logged to
  `ai_call_log` as `refused` (already an outcome) with **0 tokens**.
- **Defense in depth:** the domain boundary is *also* asserted in the system prompt and re-checked by
  the W1 **output guard** — but the guard is the backstop, the deterministic gate is the wall.
- **Challenge / refinement:** a pure block-list is brittle (false positives on e.g. "sports day
  attendance", "science *movie* screening permission"). Mitigation: the **school-lexicon presence
  check wins ties** — if the message contains strong school entities/intents, it is in-domain even
  if a block word appears. This keeps legitimate school phrasing (sports day, movie permission slip,
  medical leave) from being wrongly rejected. The block-list only fires when there is **no** school
  signal.

> **Cross-cutting win:** the same intent router that powers the Domain Gate also powers Quick
> Actions (§7) and the fingerprint cache (§9). One classifier, three payoffs.

---

## 4. Principle 2 — RBAC before AI · **AGREE, make it structural**

**Verdict: this is already a design rail (doc 02 §5 rule 5). The gap is that it's enforced
per-surface, not through one choke point. Fix that.**

- **Order is law:** `authenticate → resolve RBAC scope-set → assemble context bounded by RBAC →
  (only now) domain gate / cache / model`. Context is **never** assembled before permissions.
- **Structural fix — the Context Firewall:** consolidate context assembly onto the manifest-driven
  Context Engine (doc 02). A surface declares a **manifest**; the engine loads **only**
  `intersection(manifest.sections, resolved RBAC scope-set)`. A section the user can't read is never
  loaded, so **injection cannot exfiltrate what was never in the bundle**. This is the single
  reviewable registry the EOS AI gate inspects.
- **Audit of every current AI entry point** (must all pass RBAC-before-context):

| Entry point | RBAC gate today | Status |
|---|---|---|
| Copilot send-message | `runAiCopilot` + assistant's `requiredViewPermission` + per-section `claimsHasPermission` in `loadCopilotContext` | ✅ enforced (per-surface) |
| Parent Insights | parent/school scope + RLS own-children | ✅ |
| Predictions | `feature.ai_predictions` entitlement + RLS | ✅ |
| Priority Feed (W2.0a) | school scope + **per-source** permission gate (analytics/risk); `degraded` flag | ✅ (this pattern is the template) |
| Quick Actions (W2) | **must** inherit the same per-pipeline gate | ⚠️ to build on this rule |
| Universal Search (W2) | **must** RBAC-scope every result row | ⚠️ to build on this rule |

- **Enterprise addition:** **PII minimization in prompts** — even RBAC-allowed context should send
  IDs + aggregates, not raw PII, wherever the answer doesn't require the literal name. Shrinks the
  blast radius of any leak and the token bill.

---

## 5. Principle 3 — Principal access & the enterprise RBAC model · **REFINE (do not blindly accept)**

**The owner's instinct — "principal sees the whole school but not org/multi-school" — is directionally
right on scope, but "entire school" is too coarse for an enterprise model and conflicts with a frozen
SRS rule. Recommended model below.**

### 5.1 Recommended model: scope-bounded **capability sets** (ABAC-lite), not role-name visibility

Mature ERPs (Workday security groups, SAP authorization objects) never hardcode "principal sees X."
They compose access from **(scope) × (capability grants)**. Adopt the same:

- **Scope hierarchy the AI context can NEVER cross:** `Self  <  Class/Section  <  School  <  Organization  <  Platform`.
  - Parent/Student → **Self**. Teacher → **Class/Section** (own classes). **Principal → School.**
    Director/Correspondent → **Organization** (aggregate-only, doc 07 §5). Super Admin → Platform.
  - **Principal is pinned to School scope and can never receive Organization/multi-school rows** —
    the manifest for the principal persona simply contains no org-level loaders (privacy by
    construction, same mechanism that keeps per-student rows out of the director feed). ✅ agrees
    with the owner.

- **Within School scope, visibility = a capability set, not "everything":** the principal's default
  capability set is broad **read + monitoring** across academics, attendance, exams, discipline,
  complaints, transport, inventory, HR-attendance/leave, and **fee-collection health**.

### 5.2 The two carve-outs "entire school" must respect

1. **Monitoring ≠ sensitive detail.** Principal should see *aggregates and health* (collection %,
   defaulter counts, staff attendance/leave, headcount) but **not** sensitive PII/operational detail
   — individual **salaries, payroll runs, staff bank/PII** — by default. This resolves the conflict
   with **doc 07 §4.1** ("Principal: no finance/salary visibility") and a literal reading of the
   owner's "finance monitoring, HR monitoring": the synthesis is **aggregate monitoring = yes,
   sensitive detail = no, per-school grantable**.
2. **View ≠ act.** Broad read does not imply approval rights. *Acting* (refund/concession approval,
   payroll) stays gated by specific permissions + maker-checker (the existing FIN-D4 / SoD model).
   **AI never acts regardless** — it only reads and drafts.

### 5.3 The AI rule that makes it self-maintaining

**AI context manifest = intersection(persona sections, resolved capability set).** A school that
grants its principal finance-detail automatically lets the principal-AI discuss it; a school that
doesn't, can't — **no code change, data-driven per tenant.** This is exactly right for SaaS
multi-school deployment: security is configuration, not a fork.

> **⚠️ Owner decision (5-A):** confirm the **default** principal capability set — specifically that
> **sensitive finance/HR detail (salaries/payroll/bank PII) is default-OFF, per-school grantable**,
> while aggregate monitoring is default-ON. My recommendation: **default-OFF for sensitive detail.**

---

## 6. Principle 4 — Action-first, AI-last (Deterministic Insight Panels) · **STRONGLY AGREE**

**Verdict: this is the heart of the whole design. Formalize the pattern and reuse what exists.**

- **The Deterministic Insight Panel** — for any entity (student, class, teacher, route, invoice…),
  the default surface is a **zero-token panel**: trends + reason + suggested next action, computed by
  rules. The owner's student example maps 1:1 to assets that already exist:
  - attendance / marks / homework trend → analytics + exam_intelligence + attendance repos
  - risk **reason** → `student_risk_engine` (already emits reasons) / `TeacherStudentRiskService`
  - suggested next action → the **W2.0a Priority/Recommendation action registry** (committed)
- **AI is an *affordance on* the panel, not the panel:** an optional **Explain / Summarize / Draft**
  button. First tap generates (T3), write-through caches; the next viewer gets it free (T2).
- **Measurement:** the EOS AI gate tracks panel-impressions vs. explain-taps; target ≥97% of entity
  views never call the model.

---

## 7. Principle 5 — Persona Quick Actions (typed registry) · **AGREE, formalize**

**Verdict: correct. Build a server-driven, typed, per-persona Quick Action Registry; retire the
client's 6 hardcoded stub actions (`copilot_quick_action.dart`).**

- **Each Quick Action declares:** persona(s), a **tier**, a **deterministic pipeline**, and an
  optional **AI-enrichment step** used *only if* the deterministic result is inherently prose.
- **Tiering the owner's examples** (most are pure T1):

| Quick Action | Tier | Resolver |
|---|---|---|
| Today's priorities · High-risk students · Fee collection summary · Attendance/Homework summary · Weak chapters · Staff requiring attention | **T1** | Priority Engine / risk engine / analytics / exam_intelligence — **0 tokens** |
| Complaint summary | **T1→T2** | deterministic rollup; optional cached narrative |
| "Why is this student at risk?" · "Explain score drop" | **T1 reason + optional T3** | risk engine reason is deterministic; narrative only on explicit "explain" |
| "Exam preparation" (parent) · open guidance | **T3 (cached)** | genuinely generative → model, grounded in T1 facts, cached per topic |

- **Governance:** a Quick Action that *can* answer deterministically **must** — the AI-enrichment
  step is reached only when the deterministic pipeline yields no prose answer. This is gate G3.
- **Reuse:** the registry is the server-side twin of the W2.0a action registry — same shape (typed +
  deep-link + tier), extended with a resolver pipeline.

---

## 8. Principle 6 — Limit open chat (governance) · **AGREE model, CHALLENGE priority-queues**

**Verdict: govern open chat as a *metered privilege*. Reuse W1's rate-limit + spend-cap. Add per-role
daily quotas + a soft-degrade order. Reject per-request priority queues as over-engineering.**

Layered controls (least → most severe):

1. **Domain gate (§3)** — off-topic never bills.
2. **Deterministic-first (§6/§7)** — most "chat" is answered by a Quick Action, never reaching chat.
3. **Per-role daily open-chat quota** *(new, small extension to the W1 token-bucket)* — e.g. Teacher
   20/day, Parent 10/day, Principal 30/day, Student 10/day, Director 15/week. Open chat is the
   expensive tail; cap *it*, not deterministic surfaces.
4. **Per-school monthly token budget** *(built — W1 spend cap)* — 80% warn / 100% soft-degrade.
5. **Cooldown / burst** *(built — token bucket)*.
6. **Soft-degrade ORDER when a school nears cap** *(new, a policy in the gateway):* disable
   **open-chat T3 first** → then **quick-action T3 enrichment** → **deterministic L0–L2 never
   degrade.** The product stays fully useful at zero incremental cost under budget pressure.

- **❌ Challenge — priority queues.** Per-request LLM priority queuing adds latency, ordering, and
  starvation complexity for negligible benefit in a school ERP (traffic is bursty-diurnal, not a
  sustained firehose). The correct levers are **quota + cache + soft-degrade**, which are simpler,
  observable, and already 80% built. **Recommend against queues.** (If a single school ever
  sustains cap, degrade — don't queue.)
- All of this is already visible in the **W1 economics panel** (spend, calls by surface, hit-ratio).

---

## 9. Principle 7 — Cost optimization · **AGREE; here are the additional levers, ranked**

The owner's ladder = the T0–T3 ladder. Beyond what's built, ranked by leverage:

| Lever | Savings | Status |
|---|---|---|
| Deterministic-answer-first for Quick Actions/Panels (§6/§7) | cuts copilot volume 60–80% | **W2 (this design)** |
| Universal Search absorbs "find/navigate" traffic (§8) | removes a whole class of would-be prompts | **W2 (this design)** |
| **Shared generations** (one brief/class-section, one pulse/school) | up to ~99% on brief surfaces | W2.1 (planned) |
| **Pre-warm off-peak** (04:00) — amortize the daily "AI feel" | ~97% vs on-demand | W2.1 (ops-gated cron) |
| **Model tiering** — smallest capable model per task (Haiku for short enrich, Opus only for hard reasoning) | 3–10× on enrich calls | **new lever — add a per-task model policy to the gateway** |
| Fingerprint cache (Stage-1) / pgvector (Stage-2) | +20–35% hit-rate | W1.5 done / W2.8 |
| PII-minimized, manifest-bounded prompts (§2/§4) | 30–50% smaller prompts | doc 02 (enforce in W2) |
| Batch/digest instead of per-event generation | fewer, bigger calls | W2.1 |
| Cache reuse across siblings / co-teachers (scoped keys) | family/class amortization | doc 03 §3.3 |

**New recommendation worth calling out: model tiering.** The gateway currently routes all governed
calls to one configured model. A per-task **model policy** (task class → model tier) is a large,
cheap win the design under-emphasizes. It stays inside the existing gateway (one policy table), so
it's reuse-first.

---

## 10. Principle 8 — Universal School Search · **STRONGLY AGREE, scope carefully**

**Verdict: yes — a global command/search bar is a hallmark of enterprise ERPs (Workday, SAP,
Salesforce) and directly serves the 95–99% zero-token goal. Build it, but start as an entity
resolver, not full-text-everything.**

- **What:** a deterministic, RBAC-scoped **entity resolver + navigator**. Typing "Ravi", "Bus 12",
  "Library", "Fee", "Complaint" resolves to the record/module and **navigates** — **zero tokens.**
- **Scope discipline (challenge):** full free-text search over every table is a large, costly index
  build. **Recommend Phase-1 = a typeahead entity resolver** over a curated, indexed set (students,
  staff, classes, routes/buses, complaints, invoices, library items, modules) with Postgres FTS /
  trigram + RLS on every result row. Expand to deep full-text later if pilots demand it.
- **Boundary with the copilot:** **Search = "find / go to"; AI = "explain / reason."** A search box
  that silently calls an LLM is the anti-pattern; keep them distinct. Search may *offer* "Ask AI
  about this" as an explicit next step (which then re-enters the firewall).
- **Security:** every result is RBAC-filtered at query time (a parent's search never returns another
  child; a teacher's never returns other classes). Same RLS the rest of the system uses.

> **⚠️ Owner decision (10-A):** confirm Universal Search is **in W2 scope** (recommended, as its own
> workstream **W2.S**) vs. deferred. My recommendation: **in-scope, Phase-1 entity resolver.**

---

## 11. Principle 9 — Enterprise cross-cutting (things not asked but required)

For credible multi-school SaaS governance, add/confirm:

- **Per-tenant AI kill switch** — an owner/admin toggle to disable AI per school (compliance,
  incident response). The product must fully function with AI off (it does — L0–L3 are deterministic).
- **Full auditability** — every AI interaction already logs one `ai_call_log` row (W1); extend the
  telemetry to Quick Actions/Search impressions for the zero-call-ratio metric.
- **Explainability everywhere** — every recommendation/priority carries its "why" (Priority Engine
  does; extend to panels).
- **Prompt versioning + eval harness** — prompts are deploy-time constants in the cache key (doc 02
  §4); add a small regression eval (injection corpus + determinism validator, already standing test
  assets, doc 09) run each AI wave.
- **Provider/model abstraction** — the gateway already abstracts the provider; model tiering (§9)
  extends it.
- **Data residency / isolation** — org+school RLS on every AI table (built + probed).

---

## 12. Consolidated governance rails (non-negotiable, extends doc 01 §6)

1. **No AI on writes / money / approvals.** AI reads and drafts; humans act (maker-checker).
2. **Five-gate firewall (§2) on every LLM entry point.** New surface = a manifest PR, reviewed at
   the EOS AI gate.
3. **RBAC before context; context = intersection(manifest, RBAC).** AI never sees un-permitted data.
4. **School-domain-bounded; off-topic costs 0 tokens.**
5. **Deterministic-first: a rule/query/cache that can answer, must.** LLM is last resort.
6. **Every model call logged, quota'd, timeout-fallbacked, output-guarded** (W1).
7. **Explainable + auditable + per-tenant-disableable.**

---

## 13. Impact on the W2 build sequence

This review **reorders and adds** to the readiness-report plan — it does not discard it. Revised:

- **W2.0a Priority Engine** — ✅ done (`2752be65`).
- **W2.0b Recommendation Engine + Persona Memory learning** — resume (drafted; unchanged by review).
- **W2-GATE Domain Gate + Context Firewall consolidation** — **promote to before open-chat work**
  (§3/§4). The intent router built here is reused by Quick Actions + fingerprint cache.
- **W2-QA Persona Quick Action Registry** (§7) + **Deterministic Insight Panels** (§6) — the
  action-first surfaces; highest zero-token leverage.
- **W2-CHAT open-chat governance** — per-role quotas + soft-degrade order (§8), on the W1 gateway.
- **W2.S Universal School Search** (§10) — parallel workstream, entity-resolver first.
- **W2-COST model-tiering policy** (§9) — small gateway addition.
- Then persona rollouts (doc 07) + W2.1 brief/digest (ops-gated) + W2.8 semantic cache as designed.

Each ships as its own compile → test → regress → commit → checkpoint, EOS-gated.

---

## 14. Owner decisions gating continued implementation

| # | Decision | Resolution |
|---|---|---|
| **5-A** | Default principal capability set — sensitive finance/HR detail (salaries/payroll/bank PII) | 🔒 **LOCKED — Option 1: default-OFF, aggregate-monitoring ON, per-school grantable via ERP permissions** |
| **8/10-A** | Universal School Search in W2 scope? | 🔒 **LOCKED — YES, W2.S Phase-1 entity resolver (deterministic, zero-token)** |
| **6-A** | Per-role daily open-chat quotas | **Accept proposed defaults as starting values; tune at pilot from `ai_call_log`** |
| **13-A** | Build order | 🔒 **LOCKED — Option 1: finish W2.0b → Domain Gate + Context Firewall + Quick Actions → Universal Search** |

---

## 15. 🔒 LOCKED owner decisions (2026-07-10) — the W2 governance law

These supersede any looser reading above and are **non-negotiable inputs to every W2 phase**.

### 15.1 RBAC & AI authorization (principal scope resolved — Option 1)
1. **AI inherits the existing ERP RBAC permissions EXACTLY. Never create separate AI permissions**
   or a parallel authorization path. One permission engine, reused.
2. **Principal AI may access all school-*operational* data** (students, teachers, attendance,
   academics, complaints, discipline, transport, inventory, approvals, **finance summaries**,
   **HR summaries**) — strictly per the caller's existing ERP permissions.
3. **Principal AI must NOT access sensitive finance/HR by default** — individual salaries, payroll
   detail, bank accounts, PAN/Aadhaar or other sensitive PII. Hidden unless **explicitly granted via
   an ERP permission**.
4. **Finance visibility is summary-level by default** (collection %, pending fees, defaulters,
   revenue trends, budget utilization, finance alerts) — **never individual payroll**.
5. **Every AI response passes the SAME permission engine as the ERP.** If the user cannot view it in
   the UI, AI must never reveal it. (This is gate G2, made absolute.)
6. **School-only.** Any out-of-scope request (general knowledge, coding, politics, entertainment, …)
   → polite refusal, **0 tokens** (gate G1).
7. **Deterministic-first.** No LLM for lookups, searches, dashboards, KPIs, reports, or predefined
   explanations — those are answered from ERP data / rules / cache.
8. **LLM only for genuine value-add** — reasoning, summarization, recommendations, drafting
   communications, planning, natural-language analysis.
9. **Token efficiency is a first-class requirement.** Prevent unnecessary AI calls; enforce
   role-based capability; a large school must not burn its quota on routine usage.
   **Reuse existing RBAC, dashboard permissions, repositories, routing — no duplication.**

### 15.2 Universal School Search — W2.S Entity Resolver (locked scope)
1. Dedicated **Universal School Search (Entity Resolver)** ships in W2.
2. **No LLM — fully deterministic, DB-driven, zero tokens.**
3. **Respects existing ERP RBAC** — users only see entities they may already access.
4. Covers all major entities: students, parents, staff, classes & sections, subjects, attendance,
   exams, fees & invoices, transport, library, inventory, complaints, approvals, circulars, events,
   modules, and other school entities.
5. Results **grouped by category** (Students, Staff, Finance, Transport, Library, …).
6. **Never assume names are unique** — show all matches with identifying info (full name,
   class & section, roll number, admission number, photo if available, other non-sensitive
   identifiers); the user disambiguates.
7. **Match priority:** Admission Number → Student/Employee ID → Phone (permission-based) →
   Roll Number + Class → Full Name → Partial Name (typeahead).
8. Selecting a result **navigates directly** to the ERP screen — **no AI call**.
9. Principle **Search First → AI Later**: if deterministic search/ERP data can answer, never invoke
   AI; invoke AI only for reasoning/explanation/summarization/recommendations/planning.
10. Built for **very large schools (10k–100k+ records)** — indexed search, pagination, fast typeahead.
11. **Reuse existing repositories, RBAC, routing, navigation, dashboard** — no duplicate search or
    permission systems.
12. Designed as the **foundation for future full-text search**, but W2 = the fast deterministic
    entity resolver first.

### 15.3 Build order (locked)
**W2.0b (Recommendation Engine + Persona Memory) → W2-GATE (Domain Gate + Context Firewall + Quick
Action Registry) → W2.S (Universal School Search entity resolver).** Each: compile → test → regress →
commit → checkpoint, EOS-gated. Reuse existing architecture; do not redesign or duplicate systems.

---

*One standard, one gate: this addendum sets the interaction/governance law; the Constitution + `/eos`
decide "done." It rewrites nothing in 01–09 — it makes their rails enforceable and enterprise-ready.*
