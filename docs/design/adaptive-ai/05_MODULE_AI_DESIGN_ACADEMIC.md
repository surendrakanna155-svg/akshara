# Adaptive AI Design 05 — Module AI Design: Academic Core (Admissions · SIS · Attendance · Exams · Homework · Communication)

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` (index: [`00_ADAPTIVE_AI_DESIGN_INDEX.md`](00_ADAPTIVE_AI_DESIGN_INDEX.md)) · **Framework:** [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md)
**Machinery:** [`02_CONTEXT_ENGINE_DESIGN.md`](02_CONTEXT_ENGINE_DESIGN.md) · [`03_MEMORY_AND_CACHING_STRATEGY.md`](03_MEMORY_AND_CACHING_STRATEGY.md) · [`04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md`](04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md)
**Anchors:** [`../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md`](../../strategy/ADAPTIVE_AI_MASTER_BLUEPRINT.md) §5/§6 · [`../../audits/06_AI_ARCHITECTURE_AUDIT.md`](../../audits/06_AI_ARCHITECTURE_AUDIT.md) · Roadmap **P3-AI-2** items 8/9/10.
**Wave-tag precedence:** where a `Pri` tag in this document disagrees with [`09_IMPLEMENTATION_WAVES_AND_METRICS.md`](09_IMPLEMENTATION_WAVES_AND_METRICS.md), **doc 09 governs** (W1 = platform plumbing only; module/persona surfaces ship in W2; HWK-1/FIN-6/TRN-2/MOD-1 are P1 preconditions, not AI waves).

> **Purpose.** This document applies the Serving Ladder (doc 01) module-by-module to the six
> academic-core modules — the daily heartbeat of a school. For each module it states the ground
> truth, maps every intelligent surface to a tier and pattern, makes the eleven design decisions
> the owner requires, and ends with rubric-scored recommendations. Everything here rides the shared
> machinery (Context Engine, memory stores, Signal Refinery, Priority Engine, notification rules) —
> **no module builds its own AI plumbing.** The dominant tier throughout is T1; T3 appears only
> where language is genuinely novel, and always behind a cache.

**Reading conventions**
- Tiers T0–T3 and patterns P1–P12 are exactly those of doc 01 §1/§4. "Existing" surfaces cite what
  is already in the codebase; "NEW" surfaces are proposed here.
- Every T1 signal named below lives in `ai_fact_signals` (doc 03 §2.4), refreshed by the Signal
  Refinery event mappings (doc 04 §2) — modules never poll or recompute per-request.
- Every proactive message is a deterministic catalog template (extension of
  `parent_comms_localization.ts` / `communication_generator`) — **no LLM anywhere in a send path.**
- Priority-feed and dashboard behaviour follows doc 04 §3/§5 (explainable score, ≤1 organic
  reposition/day, pins win); one-click actions follow doc 04 §4 (deep link + pre-filled payload,
  human confirms, AI never executes).
- Per doc 01 §6.7 (truth in naming), deterministic surfaces below are labeled **Smart/Analytics**
  in the UI; only P8/P9/P10 affordances are labeled **AI**.

---

## 1. Admissions

### 1.1 Snapshot (ground truth)

- Readiness 🟡. Lead pipeline with 7 stages (New → … → Joined), follow-up logging, registration
  wizard, fee handoff. Principal approval SoD shipped (approval decision is maker-checker — off
  limits to AI by governance rail 1).
- Existing intelligence: AD-01 widget set — 6 KPIs, funnel, source donut, follow-ups-due-today
  table, counselor leaderboard, AI insight card — plus an AI admission score on the approval queue.
- A **deterministic conversion predictor already exists** (`predictions_service.ts`): admission-
  conversion likelihood per lead from funnel progression + warmth. This is the module's T1 spine.
- Pains: **ADM-2** WhatsApp/call activity not auto-logged; **ADM-3** no bulk lead actions;
  **ADM-4** follow-ups-due rows are inert (visible but not actionable); **ADM-1** export is a stub.

### 1.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| AD-01 KPI/funnel/source-donut/leaderboard widgets (existing) | T1 | P4 | Deterministic rollups; move source queries onto `ai_fact_signals` (admissions family, doc 04 §2); relabel "Analytics" |
| Conversion likelihood per lead (existing) | T1 | P2 | Keep as-is; score + factor breakdown shown on the lead card (explainability rail) |
| Admission score on approval queue (existing) | T1 | P2/P4 | Deterministic score ranks the queue; the approval itself stays human/SoD — AI never touches the decision |
| Counselor follow-up worklist (NEW — activates ADM-4) | T1 | P3/P11 | Follow-ups-due + idle-hot-leads as priority items; each row carries call/log/reschedule pre-staged actions |
| Next-best-action chip on lead card (NEW) | T1 | P2/P12 | Conversion band → deterministic action table (call / schedule visit / document nudge / fee-plan share); accept/dismiss tunes weights |
| Stale-lead & idle-hot-lead alert (NEW) | T1 | P2 | "Hot lead untouched N days" — N is a learned per-school threshold (doc 03 §2.5) from historical touch-to-convert lag |
| Funnel-stall exception (NEW) | T1 | P4 | Stage-dwell time vs school's learned norms; flags cohorts stuck in a stage |
| Daily admissions insight card (existing, re-served) | T2 | P5/P6 | Today one card = one live call risk; becomes ONE pre-warmed shared generation per school per day over T1 funnel facts |
| Follow-up message draft (NEW) | T3 | P9 | Counselor taps "draft message" on a lead → model drafts from T1 lead facts; human edits/sends; localization via T0 catalog; ≤1 call/tap, cached by lead-stage signature |
| "Explain this score" on lead/queue (NEW) | T2/T3 | P8 | On-demand phrasing of the predictor's factor breakdown; write-through cached; T1 factor list is the fallback |
| Admissions copilot Q&A (existing) | T2→T3 | P7/P10 | Rides intent-fingerprint + semantic cache (doc 03 §3.2); enumerable intents ("how many leads this week") answered pure T1 |

### 1.3 Design decisions

**Where AI (the model) is used** — only three places: the once-daily shared insight narrative (P5/P6),
draft-and-hold follow-up messages (P9), and explain/copilot on demand (P8/P10). Explicitly NOT AI:
lead scoring and queue ranking (T1 predictor), the approval decision (SoD, humans only), bulk lead
actions ADM-3 (plain feature), the export ADM-1 (plain feature on the XCT-1 export rail), and every
reminder (T0 catalog).

**Cached & shared generations** — the daily insight card: scope `school`, generated nightly (P6),
TTL to next 04:00 pre-warm, invalidated early by `admissions.stage_changed` bursts (entity tag
`school:admissions`). Draft messages: cached per (school, lead-stage, intent) signature so a second
counselor drafting for the same situation hits T2. Explain answers: write-through per doc 01 §2.

**Event-driven intelligence** — `admissions.stage_changed` → funnel counts, follow-up-due queue,
conversion re-score, stale-lead timers (doc 04 §2); `admissions.followup_logged` (and, when ADM-2
lands, auto-logged WhatsApp/call events) → resets idle timers and re-scores the lead. No polling,
no per-dashboard recompute — AD-01 reads signals.

**Dashboard adaptivity** — cards: KPI strip, funnel, follow-up worklist, source donut, leaderboard,
insight card. The priority strip (doc 04 §5) pins the worklist first whenever follow-ups-due > 0 or
a hot lead is idle; a counselor who always opens the leaderboard sees it rise (usage frequency);
dismissed insight cards decay (Persona Memory).

**Deterministic insights vs AI insights** — *Deterministic:* funnel conversion %, stage-dwell
times, source ROI ranking, counselor throughput, conversion likelihood + factors, stale/idle
exceptions, follow-up SLA compliance. *AI:* the daily narrative over those facts, drafted outreach
text, on-demand explanations. Nothing numeric ever comes from the model.

**One-click actions** — worklist row → dialer/WhatsApp intent + outcome-log form pre-filled with
lead id and suggested next stage (closes ADM-4); next-best-action chip → deep link to the staged
step (visit scheduler with lead prefilled, document-request nudge with T0 template selected);
approval-queue row → registration review screen. Confirmation always human.

**Auto-summaries** — one shared daily admissions pulse (T2, P6) for principal + admissions head:
"12 new leads, 3 hot idle, conversion pacing −8% vs last cycle" — narrative cached, numbers
rendered live T1. Weekly source-performance summary folds into the principal digest (doc 07).

**Proactive notifications** — all T0: follow-up-due (counselor, at slot time), hot-lead-idle
(counselor, threshold crossing, ≤1/day/lead), funnel-stall (admissions head, weekly),
registration-approved welcome (parent, existing catalog scenario). Deduped and folded into the
per-user daily digest on overflow (doc 04 §6); quiet hours respected.

**Predictive workflows** — the conversion band pre-stages the pipeline: high-band leads entering
"Visit done" auto-stage a registration-invite task; decaying scores pre-stage a win-back call into
tomorrow's worklist; document-missing leads pre-stage a T0 document nudge. All deterministic
(doc 04 §7); the predictor is never recomputed by a model.

### 1.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Activate follow-up rows as a priority worklist with pre-staged actions (ADM-4) | turns an inert table into the counselor's day; pure T1 vs "AI assistant" chatbot | 🌟🌟🌟 | 100% | S | **W2** |
| Next-best-action chip from existing conversion bands | reuses a shipped predictor; action table beats an LLM suggestion (explainable, instant) | 🌟🌟 | 100% | S | **W2** |
| Learned stale-hot-lead thresholds per school | adaptive without a model call; a metro school's "idle" ≠ a rural school's | 🌟🌟 | 100% | S | **W2** |
| Re-serve the AI insight card as pre-warmed shared generation | one call/school/day instead of one per viewer per open | 🌟🌟 | 95–99% | S | **W2** (W2.1 shared-generation platform) |
| Draft-and-hold follow-up messages (localized via T0 catalog) | good starting text is real model value; bounded ≤1 call/tap, cached by stage signature | 🌟 | bounded (~5–10 calls/school/day worst case) | M | **W3** |
| Funnel-stall exception surface | catches revenue leaks no widget shows today; zero cost | 🌟🌟 | 100% | S | **W2** |

---

## 2. SIS / Student Records

### 2.1 Snapshot (ground truth)

- Readiness 🟡. Student-360 (9 tabs), promotion/transfer/TC/exit flows, parent mapping, document
  vault. Maker-checker on promotion bulk threshold and TC + Finance no-dues (FN-03).
- Widgets SIS-08: enrollment by class, gender ratio, admission trend, document-compliance % — all
  deterministic.
- Frozen identity law: PSID `<SCHOOL_CODE>-<NNNN>`, UUID is the only PK; certificate generator
  (SIS-1) recently shipped with PSID surfacing — certificates are **T0 templates, never AI**.
- Pains: **SIS-3** document Verify action unwired; **SIS-4** no sibling/family view; **SIS-6** no
  single-student doc upload; data-completeness is visible as a % but not actionable.

### 2.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| SIS-08 widgets (existing) | T1 | P4 | Enrollment/gender/trend/doc-compliance rollups; sources move to `ai_fact_signals`; relabel "Analytics" |
| Certificate generator (existing, SIS-1) | T0 | P1 | Template + slots + branding + PSID; explicitly not AI, listed to fix its tier forever |
| Document-gap worklist (NEW — activates SIS-3/SIS-6) | T1 | P4/P11 | Per-class ranked list of students with missing/expiring/unverified docs; rows carry verify / request-upload actions |
| Doc-expiry horizon (NEW) | T1 | P2 | Feeds C9 deadlines; expiry warnings T-30/T-7 via T0 rules |
| Sibling/family detection (NEW — SIS-4) | T1 | P2 | Deterministic candidate match on shared guardian id / phone / address; office confirms link (human write); powers family view + fee-concession context |
| Data-completeness score per student/class (NEW) | T1 | P4 | Weighted field/doc checklist; drives the office worklist, not a vanity % |
| At-risk flag inside Student-360 (existing engine, new surface) | T1 | P2 | `student_risk_engine` output shown on the Overview tab with factor breakdown |
| Student-360 "story so far" summary (NEW) | T2 | P10/P8 | On-demand narrative over the 9 tabs' T1 facts (attendance %, marks trend, fees state, incidents); cached per student, entity-tag invalidated; T1 fact list is the fallback |
| Clearance pre-check for TC/promotion/exit (NEW) | T1 | P4/P11 | Deterministic contributor sweep (fees, library, inventory, docs) surfaced *before* the workflow starts; aligns with the Clearance Engine idea and FN-03 |
| SIS copilot Q&A (existing) | T2→T3 | P7/P10 | Enumerable intents ("how many students in 6-B") answered T1; long tail rides the caches |

### 2.3 Design decisions

**Where AI (the model) is used** — exactly two places: the on-demand Student-360 narrative (P10,
cached) and copilot long-tail Q&A. Explicitly NOT AI: certificates and TC documents (T0 templates —
publishing path, governance rail 1), sibling matching (deterministic joins beat embeddings here and
are explainable to a registrar), promotion/transfer decisions (maker-checker), completeness scoring,
and the Verify action itself (SIS-3 is a plain feature; AI only *queues* it).

**Cached & shared generations** — the Student-360 narrative is **private scope** (per student,
viewer-RBAC-checked by the Context Engine), TTL 24h cap, invalidated by tags `student:X:marks`,
`student:X:attendance`, `student:X:fees` the moment any change; parents and the class teacher
asking about the same child share the cache entry only when their RBAC scope-set reads identical
sections — otherwise separate keys (doc 02 §4). Nothing in SIS warrants school-scope sharing.

**Event-driven intelligence** — `sis.student_admitted/section_changed` → enrollment rollups +
capacity signals; `sis.document_uploaded/verified` → completeness score + doc-gap worklist +
`student:X:docs` tag invalidation; `sis.guardian_linked` → sibling-candidate re-scan for that
family; `exit/tc.initiated` → clearance pre-check fan-in. Doc-expiry is a nightly XCT-2 scan
(time-based, not event-based).

**Dashboard adaptivity** — office/registrar dashboard cards: doc-gap worklist, enrollment by class,
admission trend, expiring-docs strip, clearance queue. Priority strip promotes the doc-gap worklist
in admission season and the clearance queue at year-end (C2 academic-calendar context drives this —
seasonal adaptivity with zero model calls). Usage/dismiss learning per doc 04 §5.

**Deterministic insights vs AI insights** — *Deterministic:* enrollment/capacity by class, gender
ratio, admission trend, doc-compliance % + per-student gaps, expiry horizon, sibling candidates,
completeness scores, clearance blockers, at-risk flags. *AI:* the on-demand student narrative and
copilot phrasing. That is the entire list — SIS is ~95% T0/T1 by design.

**One-click actions** — doc-gap row → Verify screen for that document (wires SIS-3) or a pre-filled
parent upload-request nudge (T0 template; pairs with SIS-6); expiring-doc row → renewal reminder
schedule; sibling candidate → confirm-link form pre-filled with both students; clearance blocker →
deep link into the owning module's resolution screen (e.g. fee dues → Finance collection).

**Auto-summaries** — none generate automatically in SIS (the student narrative is on-demand by
design — generating 1,000 student summaries nightly would be waste). The weekly enrollment/
compliance digest for the principal is T1 numbers in a T0 digest template.

**Proactive notifications** — all T0: doc-expiry T-30/T-7 (office + parent), verification-pending
aging >7d (registrar), admission-season capacity threshold crossed (principal), clearance-blocked
TC (registrar). Parent-facing variants use the frozen catalog with language preference.

**Predictive workflows** — year-end promotion pre-staging: the clearance pre-check runs for the
whole cohort *before* promotion season opens, so the registrar starts with a blocker list, not a
surprise (deterministic sweep). Rising at-risk students pre-stage an intervention checklist for
class teacher + counselor (doc 04 §7, reuses `student_risk_engine`). No model involvement.

### 2.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Document-gap worklist + one-click verify/request (SIS-3/SIS-6) | converts a passive compliance % into a finishable queue; pure T1 | 🌟🌟🌟 | 100% | M | **W2** |
| Deterministic sibling/family detection (SIS-4) | explainable joins beat any ML matcher for a registrar; unlocks family fee context | 🌟🌟 | 100% | M | **W2** |
| Clearance pre-check surface before TC/promotion | prevents year-end firefighting; rides FN-03 + contributor registry idea | 🌟🌟 | 100% | M | **W2** |
| Cached on-demand Student-360 narrative (P10/P8) | one tap, one call, then cached + tag-invalidated; the only SIS surface where prose earns its cost | 🌟🌟 | 70–90% | S (on W1 machinery) | **W3** |
| Doc-expiry T0 rules on XCT-2 | compliance proactivity with zero spend | 🌟🌟 | 100% | S (after XCT-2) | **W2** |
| Seasonal dashboard promotion via C2 academic context | the dashboard "knows" it's admission/exam/promotion season — adaptivity for free | 🌟 | 100% | S | **W2** |

---

## 3. Attendance

### 3.1 Snapshot (ground truth)

- Readiness ✅ — the highest-frequency daily task in the product. Teacher period-wise marking with
  draft autosave + submit gate; correction workflow; parent/student calendar views.
- Principal PR-02 analytics: chronic-absentee table with an "AI risk" column (deterministic —
  rename per AI-6) and class×day heatmap.
- `attendance.absent` → parent fan-out already exists (owner-gated channel governance).
- Pains: **ATT-1** office register has no screen; **ATT-2** no monthly register export; **ATT-3**
  no absentees-only fast-mark; **ATT-4** no school-wide not-yet-marked monitor by cutoff.

### 3.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| Marking screen (existing) | — | — | Deliberately not an AI surface; speed comes from UX (ATT-3), not intelligence |
| Not-marked-by-cutoff monitor (NEW — ATT-4) | T1 | P4/P2 | XCT-2 scan derives `attendance.not_marked_by_cutoff` (doc 04 §2); school-wide exception board for principal; teacher nudge at cutoff, escalation at T+n |
| Absentees-only fast-mark entry (NEW — ATT-3) | T1 | P11 | The unmarked-class recommendation opens the marker in "all present, tap exceptions" mode; yesterday's absentees pre-highlighted |
| Chronic-absentee table (existing PR-02) | T1 | P2 | Keep; threshold becomes a learned per-school value (base-rate-relative, doc 03 §2.5); rename column "Risk (computed)" |
| Class×day heatmap (existing PR-02) | T1 | P4 | Keep; source moves to `ai_fact_signals` attendance rollups |
| Absence-pattern detection (NEW) | T1 | P2 | Statistical flags: Monday/post-holiday patterns, sudden streaks, class-wide dips (event on campus? bus issue?); pure aggregation |
| Absent → parent notification (existing) | T0 | P1 | Frozen catalog template, language variant, gated channels; unchanged |
| "Explain this student's attendance trend" (NEW) | T2/T3 | P8/P10 | On-demand for teacher/parent; facts (streaks, pattern, comparison to class) computed T1; phrasing cached per student, tag-invalidated |
| Monthly register export (ATT-2) | — | — | Not AI — plain document on the XCT-1 export rail; listed to keep it off the model forever |
| Teacher morning-brief attendance section | T1 (+T2 header) | P6 | "6-B unmarked, 3 chronic absentees back today" — brief body T1; narrative header shared per class-section (doc 03 §3.3) |

### 3.3 Design decisions

**Where AI (the model) is used** — only the on-demand trend explanation (P8) and the shared
morning-brief narrative header (P6). Everything else in the module — the highest-frequency surface
in the product — is T0/T1. Explicitly NOT AI: marking, correction approval (workflow), risk
scoring (deterministic formula), the register/export documents, and every notification.

**Cached & shared generations** — brief narrative: scope `class_section`, pre-warmed nightly,
replaced at next pre-warm, early-invalidated by `attendance.submitted` for that class (tag
`class:Y:attendance`). Trend explanations: private per student, 24h cap, invalidated on any new
attendance event for that student. Numbers always re-rendered live T1 (doc 03 §3.5 staleness rule).

**Event-driven intelligence** — `attendance.submitted` → class/school %, absentee list, chronic
counters, heatmap rollups, cache-tag invalidation, absent fan-out rule match; derived
`attendance.not_marked_by_cutoff` (scan) → exception list + teacher nudge + principal escalation;
`attendance.corrected` → recompute affected student signals. The 60s widget cache is superseded by
seconds-fresh signals (doc 04 §5).

**Dashboard adaptivity** — teacher: "mark now" card pinned first until today's classes are
submitted, then it folds and the day's exceptions (absentee follow-ups) surface — state-driven, not
model-driven. Principal: unmarked-classes board auto-promotes to the priority strip after cutoff
with a "moved up — 4 classes unmarked" badge (doc 04 §5); heatmap/chronic table order tuned by
usage frequency.

**Deterministic insights vs AI insights** — *Deterministic:* attendance % at every scope, absentee
and chronic lists, learned risk thresholds, heatmaps, pattern flags, unmarked-by-cutoff exceptions,
correction-pending queue. *AI:* on-demand trend phrasing and the brief's narrative sentence. Ratio
by impression volume: attendance should be **>99% T0/T1** — it is the module that anchors the
global ≥90% invariant.

**One-click actions** — unmarked-class nudge → absentees-only fast-marker for that period (ATT-3 —
one recommendation closes two pains); chronic-absentee row → pre-filled parent-meeting request or
counselor referral; pattern flag → drill-down view with the affected roster; correction request →
approval screen. Escalation nudge to a teacher is a T0 template the principal confirms.

**Auto-summaries** — daily school attendance pulse (T1 numbers in T0 template) folded into the
principal digest; weekly parent digest includes the child's attendance line (T0 catalog). The only
generated prose is the shared brief header (T2, pre-warmed).

**Proactive notifications** — T0 rules: absent-today fan-out to parents (existing, near-real-time
on submit); not-marked nudge to teacher at cutoff, escalation to principal at T+30min; chronic
threshold crossed → class teacher (≤1/week/student, digest-folded); streak-broken positive nudge to
parent (optional, Persona-Memory opt-in). All deduped, quiet-hours aware.

**Predictive workflows** — chronic-risk crossing pre-stages the intervention checklist (shared with
SIS §2.3); a leave approval that vacates periods pre-computes substitute suggestions (timetable ×
leave join, doc 04 §7) so attendance ownership never lapses; pattern flags pre-stage a "verify bus
route / event clash" task for the office. All T1.

### 3.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Not-marked-by-cutoff monitor + nudge/escalation (ATT-4) | the single most-requested principal control; scan + rule, zero cost | 🌟🌟🌟 | 100% | M | **W2** |
| Absentees-only fast-mark as the one-click action on unmarked nudges (ATT-3) | pairs the recommendation with the fix; marking drops to seconds | 🌟🌟🌟 | 100% | S–M | **W2** |
| Learned chronic-absentee thresholds (base-rate-relative) | a 92%-attendance school and a 97% school get different, correct sensitivity | 🌟🌟 | 100% | S | **W2** |
| Absence-pattern detection (statistical) | surfaces causes (bus, day-of-week) no static widget shows | 🌟🌟 | 100% | S | **W2** |
| Shared pre-warmed brief header per class-section | N teachers ≠ N calls; mornings feel bespoke for pennies | 🌟🌟 | ~98% | S (on W1 machinery) | **W2** |
| Rename PR-02 "AI risk" → computed risk (AI-6) | truth in naming; protects trust in the surfaces that ARE AI | 🌟 | n/a | S | **W2.9** (truth-in-naming wave) |

---

## 4. Exams

### 4.1 Snapshot (ground truth)

- Readiness ✅ — top-priority module (O2), with one reliability caveat: **REL-2** on Save-all in
  the marks grid (fix belongs to Phase 1; this design assumes it lands).
- Marks grid, board-aware grading, coordinator-verify → principal-approve chain, report-card PDF.
  **Frozen rule:** AB/ML/DB = NULL marks + status code, excluded from totals/avg/rank/pass-fail —
  a T0 rule table this design must never route around.
- Principal PR-08: pass %, distribution, AI weak-subject table, at-risk list. Deterministic
  `exam_intelligence_service` exists (avg, pass rate, subject trend). Question-paper **AI gap-fill
  exists** — moderation-gated, never auto-published (correct governance, audit §5).
- Pains: **EXM-1** no fast bulk marks entry (~60 taps/class); **EXM-2** no cross-teacher
  marks-completion board; **EXM-3** tabulation register; **EXM-4** merit list; **EXM-6** no
  marks-entry deadline field/nudge; **EXM-7** datesheet PDF.

### 4.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| Marks entry, grading, totals, rank, AB/ML/DB handling (existing) | — | — | Never AI (governance rail 1 + frozen rule); EXM-1 fast entry is UX, not intelligence |
| Marks-completion board (NEW — EXM-2) | T1 | P4 | Per-teacher × per-exam completion % from `ai_fact_signals` (updated on `exam.marks_saved`); principal view + coordinator view |
| Marks-deadline nudges (NEW — EXM-6) | T0/T1 | P2/P1 | Deadline field (plain feature) + rules: T-2 reminder, overdue nudge, principal escalation; "overdue" default is a learned per-school entry-lag threshold |
| PR-08 pass %, distribution, weak-subject, at-risk (existing) | T1 | P4 | Keep on `exam_intelligence_service`; relabel weak-subject table "Analytics"; at-risk re-scored on publish events |
| Post-publish class-performance narrative (NEW) | T2 | P5/P10 | One shared generation per (exam, class-section) after publish: "10-B: pass 91%, Maths dragging, 4 students flipped to at-risk" — facts T1, prose cached, served to principal + class teacher + coordinator |
| Question-paper AI gap-fill (existing) | T3 | P9 | Keep exactly as governed (moderation-gated, never auto-published); add T2 reuse: cache generated items per (school, subject, grade, blueprint-section) signature — school-scoped only, no cross-tenant reuse (rail 3) |
| "Explain this student's result trend" (NEW) | T2/T3 | P8/P10 | Teacher/parent on-demand; facts = marks deltas vs class, subject trend, AB history; cached per student+exam, invalidated on `exam.marks_saved/published` |
| Report-card remark draft (NEW, optional) | T3 | P9 | Teacher taps "suggest remark" → draft from T1 facts; teacher edits; remark then flows through the existing verify→approve chain like any human text; never auto-inserted |
| Tabulation register (EXM-3), merit list (EXM-4), datesheet PDF (EXM-7) | T0/T1 | — | Deterministic documents (compute + template); explicitly not AI; ride the export rail |
| Result-published parent notice (existing gate) | T0 | P1 | Catalog template + language variant; fires only on the publish event |

### 4.3 Design decisions

**Where AI (the model) is used** — four bounded places: the shared post-publish narrative (P5/P10),
question gap-fill (P9, pre-existing and governed), on-demand result explanations (P8), and optional
remark drafts (P9, human-owned through the approval chain). Explicitly NOT AI: every mark, total,
grade, rank, pass/fail, the AB/ML/DB rule, verify/approve decisions, tabulation/merit/datesheet
documents, and result notifications. The marks pipeline is a **zero-AI corridor** end to end.

**Cached & shared generations** — class narrative: scope `exam × class_section`, generated once on
publish (event-triggered, not nightly — results are bursty), TTL 30d (stable after publish),
invalidated only by correction/re-publish events. Gap-fill items: school-scoped cache by blueprint
signature — a teacher regenerating a similar section reuses moderated items first. Explain answers:
private, write-through, sibling paraphrases hit the semantic cache (doc 03 §3.2).

**Event-driven intelligence** — `exam.marks_saved` → completion board %, deadline-overdue timers,
tag invalidation (`exam:Z`); `exam.marks_published` → weak-subject rollups, at-risk re-score,
class-narrative generation trigger, parent notice rule, `student:*:marks` tag sweep;
`exam.result_corrected` → narrative + explanation invalidation for the affected scope. Replaces
any dashboard-time recomputation of PR-08.

**Dashboard adaptivity** — during an exam cycle (C2 context), teacher dashboards pin "marks due"
with per-class completion; the principal's priority strip promotes the completion board as the
deadline approaches and swaps to the results narrative + weak-subject view after publish. Season-
state drives composition; Persona Memory tunes the rest. Outside exam season these cards fold away
entirely — adaptivity as absence, too.

**Deterministic insights vs AI insights** — *Deterministic:* pass %, grade distribution, subject
averages/trends, weak-subject ranking, completion %, deadline compliance, at-risk deltas, merit
ordering, AB/ML/DB exclusions. *AI:* the class narrative, explain-on-demand phrasing, remark
drafts, generated question candidates. The model never sees an ungraded script and never computes
a statistic.

**One-click actions** — completion-board row → bulk marks grid opened at the first empty row
(pairs with EXM-1's fast-entry UX; EXM-1 itself is a plain feature); overdue-teacher row → one-tap
nudge (T0 template, principal confirms — doc 04 §4); weak-subject cell → drill-down to question/
chapter analysis; flipped-at-risk student → intervention checklist (shared with SIS/Attendance).

**Auto-summaries** — the post-publish class narrative generates automatically per class-section
(T2, one call each — a 30-section school's entire result-day narrative costs ~30 calls, then serves
hundreds of views); the school-level result summary in the principal digest is T1 numbers in a T0
template with the cached narrative attached. Nothing per-student is auto-generated.

**Proactive notifications** — T0 rules: marks-deadline T-2 (teacher), overdue (teacher, then
principal escalation at learned lag), results-published (parent, existing gate), verification-
pending aging (coordinator). Result-day notices are burst-deduped: one notice per child per exam,
digest-folded if multiple classes publish together.

**Predictive workflows** — at-risk re-score on publish pre-stages intervention checklists before
PTM season; completion-lag prediction (teacher's historical entry lag vs deadline) pre-stages the
principal's nudge list *before* the deadline passes — deterministic, from `ai_fact_signals`
history. Datesheet publication (EXM-7, plain feature) feeds C8 calendar so homework-clash rules
(§5.3) and parent reminders fire without new wiring.

### 4.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Marks-completion board + deadline rules (EXM-2 + EXM-6) | closes the principal's biggest exam-season blind spot with a rollup + rules; no model | 🌟🌟🌟 | 100% | M | **W2** |
| Post-publish shared class narrative (P5/P10, event-triggered) | one call per class-section per exam serves every stakeholder; result day feels premium for ~30 calls | 🌟🌟 | ~97% | M | **W2** |
| Pre-deadline nudge pre-staging from learned entry-lag | escalation happens before the miss, not after; pure history math | 🌟🌟 | 100% | S | **W2** |
| School-scoped T2 reuse for question gap-fill | moderated items become reusable assets; respects tenant isolation | 🌟 | 30–50% of gap-fill calls | S | **W3** |
| Explain-on-demand for result trends (teacher/parent) | phrasing of computed evidence is the highest-trust AI exams can offer | 🌟🌟 | 70–90% | S (on W1 machinery) | **W3** |
| Remark-draft (P9) through the existing verify→approve chain | drafting help without touching publishing governance; teacher owns every word | 🌟 | bounded (≤1 call/remark tap) | M | **W3** |

---

## 5. Homework

### 5.1 Snapshot (ground truth)

- Teacher create/publish/review; student submit (text + photo, offline queue); parent view.
- `homework_intelligence_service` exists (deterministic): weak-topic detection, risk students,
  revision suggestions. AI worksheet generator shipped (real T3 surface).
- **KEYSTONE GAP — HWK-1:** due date is a free-text `due_label`, not a real date. This blocks
  reminders, overdue detection, and sorting. HWK-1 is a Phase-1 fix; **every time-based design in
  this section is explicitly gated on it.**
- Pains: **HWK-2** no not-submitted list; **HWK-3** no multi-section assign; **HWK-6** no bulk
  mark-reviewed; **HWK-8** no due-tomorrow reminder; **HWK-10** no homework-load/clash oversight.

### 5.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| Weak-topic / risk / revision suggestions (existing service) | T1 | P2/P4 | Keep; feed outputs into `ai_fact_signals` so briefs and the priority feed reuse them; relabel "Analytics" |
| Not-submitted list (NEW — HWK-2) | T1 | P4/P11 | Per-assignment exception list from `homework.submitted` events; rows carry a parent-nudge action |
| Due-tomorrow reminder (NEW — HWK-8, gated on HWK-1) | T0 | P1 | XCT-2 evening scan → catalog template to student/parent, language variant, digest-folded |
| Overdue & submission-rate signals (NEW, gated on HWK-1) | T1 | P2 | Per-class submission rate, chronic non-submitter counters (feeds student-risk) |
| Homework-load/clash monitor (NEW — HWK-10) | T1 | P2/P4 | Rule: assignments/class/day vs learned norm + clash with exam datesheet (C8); principal/coordinator exception view |
| AI worksheet generator (existing) | T3 | P9 | Keep (teacher reviews before publish); add school-scoped T2 cache by (subject, grade, topic, difficulty) signature — repeat requests hit cache; never cross-tenant (rail 3) |
| Revision-plan suggestion post-exam (existing service, new surface) | T1 | P2 | Weak topics × upcoming syllabus → suggested revision homework; teacher one-taps to create a draft assignment |
| Parent "how do I help with this topic" (NEW) | T3→T2 | P10/P7 | Parent-AI guidance in parent's language (generation, not translation — allowed split); grounded in the assignment's T1 facts; semantic-cached per school+topic+language |
| Teacher brief homework section | T1 | P6 | "2 assignments due tomorrow, 6-B at 40% submitted"; rides the shared brief |
| Multi-section assign (HWK-3), bulk mark-reviewed (HWK-6) | — | — | Plain features, not AI; HWK-6's button becomes the one-click action on the review-pending recommendation |

### 5.3 Design decisions

**Where AI (the model) is used** — worksheet generation (existing P9), parent topic guidance
(P10, cached), and nothing else. Explicitly NOT AI: due-date logic (blocked purely by HWK-1, a
schema fix — do not "solve" free-text dates with an LLM parser; fix the field), weak-topic/risk
analytics (existing deterministic service), all reminders, submission tracking, load/clash rules,
and review workflows (HWK-3/HWK-6 are plain features).

**Cached & shared generations** — worksheets: school-scoped cache keyed on the generation
signature; a hit serves instantly and costs nothing; moderation state travels with the cached
item. Parent topic guidance: scope school+topic+language (no child PII in the shared entry — the
child-specific line is a T0 slot on top, doc 03 §3.3), TTL 30d (syllabus-stable), semantic cache
catches paraphrases. Brief sections ride the class-section shared entry (§3.3).

**Event-driven intelligence** — `homework.assigned` → load-counter per class/day, clash check
against C8 datesheet, due-date registration for the reminder scan; `homework.submitted` →
submission-rate + not-submitted list + `class:Y:homework` tag invalidation; `homework.reviewed` →
review-pending counters. Due-tomorrow and overdue are XCT-2 time scans over real dates (HWK-1).

**Dashboard adaptivity** — teacher: review-pending card rises as submissions accumulate; "create
revision homework" suggestion card appears only in the post-exam window (C2 context) and only if
weak topics exist; dismissals suppress per Persona Memory. Parent: homework-due card pinned on
evenings with due-tomorrow items. Coordinator/principal: load/clash exception card appears only
when a rule fires (P4 — absence of exceptions = absence of card).

**Deterministic insights vs AI insights** — *Deterministic:* submission rates, not-submitted and
chronic non-submitter lists, weak topics, risk students, revision-topic suggestions, load/clash
flags, due/overdue states. *AI:* worksheet content and parent topic guidance. Homework's model
spend is entirely opt-in taps.

**One-click actions** — not-submitted row → pre-filled parent nudge (T0 template, teacher
confirms; HWK-2); review-pending recommendation → bulk mark-reviewed screen (HWK-6); revision
suggestion → assignment composer pre-filled with topic, class, and suggested due date; clash flag
→ reschedule form with the conflicting datesheet entry shown; due-tomorrow parent card → the
assignment view.

**Auto-summaries** — the teacher brief's homework line and the parent weekly digest's homework
paragraph are T1 numbers in T0 templates. No generated prose is automatic; worksheet and guidance
generation are always user-initiated.

**Proactive notifications** — T0 rules (all gated on HWK-1): due-tomorrow (student + parent,
evening slot, digest-folded), overdue (parent, T+1, ≤1/assignment), chronic non-submitter weekly
flag (class teacher), load-rule breach (coordinator). Quiet hours + per-day budget per doc 04 §6.

**Predictive workflows** — chronic non-submission feeds the student-risk signal (shared spine);
post-exam weak topics pre-stage revision-assignment drafts for the teacher's next planning session;
datesheet publication pre-stages "no-homework window" suggestions for exam-eve days (rule from
HWK-10's clash logic). All deterministic; the worksheet generator is only invoked if the teacher
taps the pre-staged draft's "generate practice sheet" affordance.

### 5.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| **Land HWK-1 (real due dates) before any homework intelligence** | every reminder/overdue/clash design above is blocked without it; a schema fix, not an AI problem | 🌟🌟🌟 (enabler) | n/a | S | **P1 precondition** (doc 09 §0 — not an AI wave) |
| Due-tomorrow T0 reminders + overdue rules (HWK-8) | parents' most tangible daily value; template + scan, zero spend | 🌟🌟🌟 | 100% | S (after HWK-1 + XCT-2) | **W2** |
| Not-submitted list + one-click parent nudge (HWK-2) | closes the teacher's follow-up loop in one tap; pure T1 | 🌟🌟🌟 | 100% | S | **W2** |
| Homework-load/clash monitor (HWK-10) | oversight nobody has today; rule over existing data + datesheet calendar | 🌟🌟 | 100% | M | **W2** |
| School-scoped worksheet cache | repeat generations become free; teachers share moderated assets within the school | 🌟🌟 | 40–70% of generator calls | S | **W2** |
| Parent topic guidance (shared, in-language, semantic-cached) | genuine parent-AI value; generation-not-translation split preserved; cost falls as cache fills | 🌟🌟 | 80–95% over time | M | **W3** |

---

## 6. Communication

### 6.1 Snapshot (ground truth)

- Readiness 🟡 — in-app only today; external channels (push/SMS/WhatsApp) remain owner-gated.
- Built: broadcast composer + queue, templates CRUD, threads, announcements wizard
  (multi-language). NT-D-05 maker-checker governs bulk sends >500 SMS.
- **Frozen law:** the deterministic multilingual comms catalog (7 languages, placeholder
  substitution) — no LLM translation, ever. `communication_generator` exists: deterministic drafts
  for 8 scenarios × 6 languages. These two assets are the module's T0 spine.
- Pains: **COM-1** delivery/read report unbuilt; **COM-2** audience picker is 5 fixed presets;
  **COM-3** no resend-to-unread; **COM-4** schedule-send unwired (needs XCT-2); **COM-5** composer
  ignores the template store.

### 6.2 AI surface map

| Surface | Tier | Pattern | What it does / notes |
|---|---|---|---|
| Catalog localization + `communication_generator` scenarios (existing) | T0 | P1 | The first-line answer for every routine message; frozen law; extended (not bypassed) as new scenarios arise |
| Composer template suggestion (NEW — COM-5) | T1 | P2/P12 | Ranks template store + generator scenarios by context match (screen, audience, season) and usage history; accept/dismiss tunes ranking |
| Signal-driven audience segments (NEW — COM-2) | T1 | P4 | Deterministic segments from `ai_fact_signals`: "parents of 6-B", "fee-overdue 30+", "absent today", "not submitted HW-42"; RBAC/RLS-scoped; replaces the 5 fixed presets |
| Delivery/read analytics (NEW — COM-1) | T1 | P4 | Per-broadcast funnel (queued → delivered → read); prerequisite for COM-3 |
| Resend-to-unread (NEW — COM-3) | T1 | P4/P11 | Exception list of unread recipients + one-click "resend / escalate channel" (channel change stays owner-gated) |
| Schedule-send (COM-4) | T0 | — | Plain feature on XCT-2; listed so nobody "solves" scheduling with intelligence |
| Broadcast draft assist (NEW) | T3 | P9 | Principal taps "draft" → model writes the English master from T1 facts (event, dates, audience); human edits; **localization then via T0 catalog only**; ≤1 call/broadcast (doc 01 §7 worked example) |
| Thread summary (NEW) | T2/T3 | P8 | "Summarize this 40-message thread" on demand; cached per thread version, invalidated on new message; T1 fallback = participants + last message |
| Announcement wizard (existing) | T0 (+opt T3) | P1/P9 | Stays catalog-driven; the optional "polish wording" affordance is the same P9 draft path |
| Notification dedupe + digests (platform) | T0 | P1 | Doc 04 §6 owns this; communication module is its send surface |

### 6.3 Design decisions

**Where AI (the model) is used** — two opt-in affordances only: draft-and-hold broadcast/
announcement text (P9, English master) and on-demand thread summaries (P8). Explicitly NOT AI —
and permanently so: **all translation/localization (frozen catalog law)**, all routine/proactive
messages (T0 scenarios), audience construction (deterministic segments — an LLM picking recipients
would violate both explainability and RLS discipline), send/schedule execution (XCT-2 + NT-D-05
maker-checker), and delivery analytics.

**Cached & shared generations** — broadcast drafts: cached by (school, scenario-signature,
audience-class) so "holiday tomorrow" drafted twice in a year hits T2; the catalog's localized
variants are T0 and need no cache. Thread summaries: private to thread participants
(RBAC-scope-keyed), invalidated by the next message event, write-through. Template-suggestion
rankings: pure T1, no cache needed beyond signal freshness.

**Event-driven intelligence** — `communication.sent/delivered/read` (COM-1 instrumentation) →
delivery funnel signals + unread exception lists; `communication.thread_message` → thread-summary
tag invalidation + unread counters; Signal Refinery emissions from *other* modules (fee due,
absent, marks published) arrive here as templated sends — communication is the T0 rail's exit
point, so its own intelligence is mostly about *who was reached*.

**Dashboard adaptivity** — communication owner/office dashboard: pending-queue card, delivery
funnel of the last broadcast, unread-exception card (appears only when reach < learned norm —
P4), scheduled-sends calendar. The priority strip promotes a failing broadcast ("32% unread after
48h — resend?") over routine cards. Composer adapts via COM-5 ranking, not layout gimmicks.

**Deterministic insights vs AI insights** — *Deterministic:* delivery/read rates, unread lists,
best-send-time statistics (per-school read-time histogram — a learned default, doc 03 §2.5),
template-usage rankings, audience sizes and previews, digest composition. *AI:* the drafted
English master text and thread summaries. Nothing the module *sends* is model-generated at send
time.

**One-click actions** — unread-exception card → resend-to-unread with the segment pre-selected
(COM-3); "draft" on any recommendation elsewhere in the suite (e.g. exam publish, fee reminder
wave) → composer pre-filled with the matched catalog scenario + audience segment; scheduled-send
suggestion ("send at 17:30 — your parents' peak read time") → schedule form pre-filled (COM-4).
Bulk sends still cross NT-D-05 maker-checker — pre-staging never bypasses it.

**Auto-summaries** — a per-broadcast outcome summary (T1 numbers in a T0 template: "sent 812,
read 74% in 24h, 210 unread") posts back to the sender automatically; weekly communication health
line folds into the principal digest. Thread summaries are never automatic — on-demand only.

**Proactive notifications** — the module *carries* the platform's T0 catalog rules (doc 04 §6:
fee due T-3/T0/T+7, homework due-tomorrow, marks deadline, doc expiry, PTM T-1, approval stale,
low stock) with dedupe, quiet hours, per-day budget, and digest folding. Module-native rules:
broadcast-underperforming (sender, 48h), scheduled-send-upcoming (sender, T-1h), unread-critical
for flagged-important notices (office). External-channel escalation remains owner-gated.

**Predictive workflows** — the read-time histogram pre-stages send-time suggestions per school;
recurring-event detection (deterministic: same catalog scenario ≈ same calendar week last year)
pre-stages next year's announcement draft from C8; a planned broadcast to a segment with an
active quiet-hours overlap pre-stages a reschedule suggestion. All T1 over send history.

### 6.4 Recommendations

| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Composer template-first flow (COM-5): catalog + generator ranked before any draft button | the deterministic asset base finally gets used; most composes end at T0 with zero calls | 🌟🌟🌟 | 100% for routine sends | S | **W2** |
| Signal-driven audience segments (COM-2) | recommendations everywhere else need "parents of the affected students" as a target; one T1 segment service powers all of them | 🌟🌟🌟 | 100% | M | **W2** |
| Delivery/read instrumentation (COM-1) → unread exceptions → resend-to-unread (COM-3) | closes the loop from "sent" to "reached"; prerequisite chain built once, pure T1 | 🌟🌟 | 100% | M | **W2** |
| Draft-and-hold broadcast assist with catalog-only localization | model where language is genuinely novel; frozen translation law preserved by construction; ≤1 call/broadcast, draft-cache for repeats | 🌟🌟 | bounded (~15–20 calls/school/day worst case, per doc 03 §5) | M | **W2–W3** |
| Best-send-time learned default + schedule pre-staging (COM-4 on XCT-2) | measurable read-rate lift from a histogram, not a model | 🌟 | 100% | S (after XCT-2) | **W3** |
| Thread summary on demand (P8, version-cached) | the only honest use of AI in threads; costs only when tapped, then cached | 🌟 | 70–90% | S (on W1 machinery) | **W3** |

---

## 7. Cross-module coherence checks

- **Tier discipline:** across all six modules, the only T3 surfaces are: admissions follow-up
  drafts, question gap-fill, remark drafts, worksheet generation, parent topic guidance, broadcast/
  announcement drafts, thread summaries, and P8 explain affordances — every one opt-in (a tap), every
  one cached write-through, every one with a stated T1 fallback (doc 01 §2 corollary 3). All
  always-on surfaces (widgets, feeds, boards, reminders, digests) are T0/T1: the academic core
  comfortably clears the ≥90% T0–T2 invariant because its *impression volume* is dominated by
  attendance, homework, and dashboard surfaces that never call the model at all.
- **Shared spine, no forks:** at-risk students (SIS §2, Attendance §3, Exams §4, Homework §5) are
  ONE signal from `student_risk_engine` in `ai_fact_signals` — each module contributes inputs and
  consumes the same list; intervention checklists are one pre-staged workflow, not four.
  Communication §6 is the single T0 exit for every other module's notification rules.
- **Governance re-affirmed:** no AI in the marks corridor, the approval/SoD chains, certificate/TC
  publishing, money paths, or any send path; comms localization stays the frozen deterministic
  catalog; all caches/memory school-scoped RLS; every T3 call logged, rate-limited, and under the
  spend cap (doc 03 §4).
- **Dependencies owned elsewhere:** HWK-1 (real due dates) and REL-2 (Save-all) are Phase-1 fixes
  this design assumes; XCT-1/XCT-2 rails carry exports, scans, schedules, and pre-warm jobs; W1
  machinery (Context Engine, caches, Signal Refinery) precedes every W2 item above.

---

*Next: [`06_MODULE_AI_DESIGN_OPERATIONS.md`](06_MODULE_AI_DESIGN_OPERATIONS.md) — the same treatment
for Finance, HR, Transport, Library, Inventory, and the platform/ops surfaces.*
