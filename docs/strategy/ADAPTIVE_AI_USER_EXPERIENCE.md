# Akshara ERP — Adaptive AI User Experience

**Status:** 🟢 Strategy / design-only (no code) — the *user experience layer* of the Adaptive AI platform.
**Date:** 2026-07-03 · **HEAD:** `68f15cb` · **Author:** Fable (World-Class Product Polish phase, Phase 3 of 5)
**Builds directly on:** `ADAPTIVE_AI_MASTER_BLUEPRINT.md` (the architecture — referenced by section, never duplicated). Where the Blueprint defines *how the system works*, this document defines *what each person feels*.
**Executes as:** roadmap **P3-AI-2** (gated on **P3-AI-1** + 👤 owner timing). **DO NOT BUILD YET** — owner ordering stands: roadmap gaps → UI/UX wave → Adaptive AI wave → Red Team → Pilot → Prod Cert.

> **Inherited non-negotiables (Blueprint §1, §11):** determinism-first (the model never invents a
> number); AI read-only and off all write/money paths; <10% of AI-surface impressions may reach the
> model; per-tenant isolation; suggest-then-confirm (never silent writes, never automate what
> maker-checker owns); parent-comms catalog stays deterministic; English-first UI. Nothing below
> bends any of these.

---

## 1. Experience principles — what "invisible, fast, naturally helpful" means

1. **The AI is the ordering of the screen, not a destination.** Nobody "goes to the AI." The dashboard's *sequence* — what's first, what's big, what's badged — IS the intelligence (Priority Engine, Blueprint §6). A chatbot exists (copilot) but is the escape hatch, not the front door.
2. **Instant or absent.** Everything a user sees at open is deterministic-tier or warmed cache (<150ms, Blueprint §13). Model enrichment streams in *afterwards* or on demand — the UI never shows a spinner waiting for a model.
3. **Facts first, phrasing second.** Every card leads with deterministic facts (numbers, names, counts); the model may add one sentence of phrasing/explanation. Strip the model output and the card still works.
4. **One tap from insight to action.** Every card carries exactly one primary action that deep-links into the *existing* screen with context pre-filled (the World-Class UX Polish flows). AI proposes; the certified workflow disposes.
5. **Explain on demand, always.** Every surfaced number/priority has a "why" affordance showing its deterministic evidence (Blueprint §11) — "8 defaulters: fees >30 days overdue, sorted by amount."
6. **Quietly personal, never erratic.** Adaptation (rise/sink, learned thresholds — Blueprint §3/§9) applies **between sessions, never mid-session**. A screen must not reorganize under someone's thumb. Dismissals are remembered (Persona Memory); the same suggestion never returns unchanged.
7. **Honest when degraded.** No key / cap reached / timeout → the deterministic surface simply stands alone, with an operator-visible health signal (closes AI-4). Users never see an AI error state; operators always can.
8. **Truth in labeling.** Deterministic analytics say "Analytics"; only genuinely model-touched surfaces carry the AI mark (AI-6 rename rides P3-AI-2).

---

## 2. The shared experience anatomy (all personas)

**The Brief** — the first thing every persona sees at open (composed at login from warmed cache, Blueprint §8: "first login of the day is instant *and* free"):
> Greeting + one-line day summary (deterministic template + optional cached phrasing) → **Priority Feed** (top 3–5 items) → adaptive widget canvas.

**Priority card anatomy** (one shared component, all personas):
```
[icon+type chip]  Fact line (deterministic, bold numbers)
                  One-line context or model phrasing (optional, cached)
[Primary action →]                      [Why? · Dismiss]
```
- *Fact line* — always present, always SQL-derived.
- *Primary action* — deep-link with context (e.g. "Mark 6B attendance" → exception grid pre-loaded).
- *Why?* — evidence popover. *Dismiss* — writes Persona Memory; feeds accept/dismiss learning (Blueprint §6).

**Smart summaries** — daily principal pulse, weekly director digest, parent weekly digest (Blueprint §10): deterministic catalog skeleton + optional model phrasing, generated once per school/scope and reused (Blueprint §7 batch rule), delivered in-app on the XCT-2 rail (external channels stay owner-gated).

**Predictive alerts** — only from the existing audited Predictions module (fee-default, admission-conversion, student-risk), always with signal traceability ("based on: 4 late payments, attendance ↓12%"), always advisory-badged, never auto-acting.

**The degradation ladder (user-visible behavior):**
| Tier state | User sees | Never sees |
|---|---|---|
| Deterministic + cache hit | Full brief, instantly | — |
| Model tier live | Phrasing streams in under facts | Layout shift |
| Timeout / no key / spend-cap | Facts only; clean layout | Error toast, empty card, "AI failed" |
| Offline | Cached brief + freshness chip ("As of 07:30") | Blocked screen |

---

## 3. Persona experiences — a day with the adaptive ERP

Personas 3.1–3.9 map 1:1 to the Blueprint §5 routers (build order: Teacher → Parent → Principal → Finance → Office → Director → Transport/Library/Inventory). 3.10–3.11 are **UX designs for router extensions not yet in the Blueprint** — flagged as candidates, owner-timed.

### 3.1 Teacher — "the morning brief that runs my day"
Opens at 8:10: *"Good morning, Lakshmi. 3 classes, 6B attendance not marked, 24 Science marks due Friday."* Priority cards: mark 6B (→ exception grid, one tap) · marks progress (24/50, → grid at next empty cell) · 2 at-risk students in *her* classes (→ student view, "why" = attendance+marks signals). Adaptation: her most-used action rises; homework card sinks if she never uses it; thresholds tuned per school (Blueprint §3 learned defaults). **Never:** auto-marking anything, publishing anything, exposing students outside her RBAC scope.

### 3.2 Parent — "someone who knows my child answers me"
Opens to child-centric brief (own-child RLS): *"Aarav: present today · Science test Friday · ₹4,500 due 15 Jul."* Q&A answers **natively in the parent's language** (Blueprint §11); guidance is empathetic and next-step-oriented ("what should I do"). Proactive reminder banners (PAR-5) replace the lone mock AI tip. One-click: pay (→ existing fee flow), acknowledge notice, message teacher (existing channels). The 👤 PAR-D4 "action inbox" decision, if approved, becomes this priority feed — one build, not two. **Never:** LLM-translated official comms (catalog stays deterministic); marks speculation ("likely to fail") without the Predictions module's traceable signals.

### 3.3 Principal — "the school fits in one screen"
Brief = approvals + exceptions + pulse: *"5 approvals waiting (2 >48h) · 3 classes unmarked by 10am · fee collection 71% vs 78% this time last term."* Priority feed composes onto the cross-module Approvals Inbox (Polish §2.3) — the AI orders the same queue, it doesn't create a second one. One-click: batch-approve routine leaves (→ confirm), nudge unmarked classes (draft-and-hold, teacher-visible in-app). Daily pulse each evening — deterministic, one generation. **Never:** auto-approval (maker-checker is sacred), broadcast without draft-confirm.

### 3.4 Student — read-only encouragement *(extension candidate — not in Blueprint §5)*
Constraints first: student login = OTP to parent (identity freeze); no direct AI chat with minors in v1. UX = adaptive *ordering* only: today's timetable, due homework, "Science test Friday — 3 chapters, syllabus attached." Tone rules if a router is ever added: informational, never comparative-shaming (no rank prods), never predictive-negative to the student. 👤 Owner decision required before any student-facing model call.

### 3.5 Office / front desk — "the queue works itself"
Brief: admissions funnel movement, document gaps ("4 admissions missing birth certificates — request all"), today's follow-ups, front-desk tasks. Drafted letters/replies from deterministic templates + optional phrasing, always human-sent. Deep integration with the clerk's dense-table world (Polish §7): AI ordering appears as a "Today" rail beside the worklist, never replacing the grid. **Never:** auto-sending anything external (owner-gated rail).

### 3.6 Finance — "the recovery CRM thinks ahead"
The FIN-R1–R5 Recovery CRM *is* the deterministic core; AI orders it: today's call queue ranked by amount × age × promise-history (Priority Engine weights, school-learned); promise-to-pay follow-ups surface on their due date; day-close anomalies flagged deterministically ("cash variance ₹500"). One-click: call (dialer), log outcome (existing FIN-R4 flow), draft reminder batch (→ maker-checker where required, FIN-D4 untouched). **Never:** auto-messaging defaulters, touching ledger math.

### 3.7 Director — "every school, one glance, no meetings"
Weekly digest + live brief: cross-school league (DIR-1 makes "Compare Schools" real), collection/attendance/margin trends, one-line narrative per exception school (cached, one generation per org). Drill-down = existing per-school dashboards (DIR-D1 scoping decision stands as 👤). **Never:** cross-tenant leakage — org-scope RLS is the boundary; no school's data phrased into another's context.

### 3.8 Transport — "problems surface before the route does"
Deterministic alerts ordered by urgency: doc expiries (15/7/1-day ladder), over-capacity routes, transport dues (demand only — Finance collects, TRN-9 frozen). One-click: renew-doc task, reallocation suggestion (→ confirm screen). Model use ≈ zero; this persona proves the "AI-quiet" end of the spectrum — same brief anatomy, near-100% deterministic tier.

### 3.9 Library & Inventory — worklists that rank themselves
Library: overdue follow-up queue (class-grouped so one teacher visit clears many), catalog gaps. Inventory: low-stock/reorder suggestions with consumption-trend "why", write-off queue always maker-checker-badged (governance decision INV frozen). One-click: draft reorder PO via existing `createPurchaseOrder` (INV-4) → normal approval path.

### 3.10 HR — *(extension candidate — not in Blueprint §5)*
Brief: leave requests pending, staff attendance exceptions (geofence+face rail per attendance-auth freeze — the AI only *reads* outcomes), payroll-run readiness ("2 employees missing bank details") once P1-CODE-5 makes payroll real. Until then HR AI is out of scope — **do not surface intelligence over a thin module** (C-ISS-6 lesson).

### 3.11 Principal-as-teacher, multi-role users
Role composition, not duplication: a user with two roles gets one brief with sectioned priorities (persona routers already RBAC-scoped); the workspace switcher (existing More-sheet) filters the feed. No "which dashboard am I on?" ambiguity — one person, one brief.

---

## 4. Adaptive dashboards — composition UX (Blueprint §9 on the Dynamic Widget Platform)

- **Composition = School Profile × Persona × Priority Engine**, rendered by the *existing* `widget_registry`/`dashboard_layouts` platform (C-ISS-10: the static persona dashboards migrate ONTO it; no parallel system).
- **Motion of adaptation:** widgets rise/sink between sessions only (§1.6); a "New here" dot marks a risen widget once; user pins beat the algorithm always (pin = Persona Memory, permanent until unpinned).
- **User control surface:** long-press → pin / hide / "why is this here?". Hidden widgets live under "More widgets" — adaptation is reversible, discoverable, and explainable or it is creepy.
- **Per-school character:** School Profile (board/type/modules/branding) selects the widget *palette* and vocabulary (an IIT-foundation school sees weekly-test widgets; a residential school sees hostel tiles) — the AI School Builder vision delivered on existing gating rails, no fork (Blueprint §2 "adapt, don't rebuild").
- **Empty-tenant day 1:** before any history exists, layouts fall back to the certified static defaults per role — a fresh school never sees a confused dashboard (cold-start rule).

---

## 5. Speed, cost & caching — engineered into the experience

The Blueprint's three-tier serving (§7) *as felt by users*:
- **Impression budget as a UX contract:** ≥90% of what users see cost zero model calls — which is why it can all be instant. The UI treats a model call like an image load: the page is complete without it.
- **Cache warming = the "morning miracle":** nightly rollups + brief pre-generation (XCT-2 rail) mean the 8am rush hits warm cache. Same-class teacher briefs share one generation (batch rule) — invisible to users, decisive for cost.
- **Event-driven freshness:** `domain_events` (fee paid, marks published, attendance submitted) invalidate exactly the affected cards — a principal watches the unmarked-classes count fall in near-real-time without polling, and the freshness chip timestamps every cached view.
- **Budget states (operator UX, Control Center):** per-tenant spend meter, cap-approaching warning, soft-degrade notice ("model tier paused — deterministic mode") — cost governance visible (Gate A4), never a user-facing failure.

---

## 6. Trust & safety as experienced

- **"Why?" everywhere** (§1.5) — the anti-hallucination UI: since every claim carries evidence, a wrong-feeling card is refutable in one tap.
- **Advisory badging:** predictions and suggestions carry a consistent advisory mark; deterministic analytics carry none (post-rename honesty, AI-6).
- **Prompt-injection hardening is invisible** but its UX corollary is visible: free-text from records (names, notes) renders as *data* inside cards, never as instructions — no card ever "speaks" school-entered text as its own voice.
- **Auditability:** every model call logged (surface/tokens/cost/cache-hit — Gate A4); "AI activity" is inspectable per tenant in Control Center.
- **Red-team alignment:** this design's failure modes are exactly Red Team Domain 4/5 attacks (fabrication, spend exhaustion, silent degradation, stale-without-chip) — each principle above is the corresponding defense, so P4-RT-1 verifies this document's promises.

---

## 7. Rollout & measures (P3-AI-2, after P3-AI-1 foundation)

1. Persona order per Blueprint §12: **Teacher → Parent → Principal → Finance → Office → Director → Transport/Library/Inventory**; each persona ships brief + priority feed + one-click actions, EOS-gated.
2. Dashboard migration to Widget-Platform composition rides the same waves (per-persona, disjoint file ownership rule respected).
3. Extensions (Student 3.4, HR 3.10) = 👤 owner-timed candidates, recorded in `PRODUCT_EXCELLENCE_MASTER_PLAN.md` §Future.
4. **Experience metrics** (adds UX lens to Blueprint §13): brief-open rate · time-from-open-to-first-action (target <10s teacher/principal) · recommendation accept rate rising, dismiss-repeat rate ~0 · zero user-facing AI error states in Patrol runs · per-school layout divergence measurable with zero code forks.

*The goal restated: a teacher should never say "the AI told me" — she should say "the app already had it ready."*
