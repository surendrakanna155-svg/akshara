# Adaptive AI Design 07 — Persona AI: Teacher · Parent · Student · Principal · Director

**Status:** 🟢 Design-final (no code) · **Author:** Fable · **Date:** 2026-07-03
**Suite:** `docs/design/adaptive-ai/` · **Framework:** [`01_AI_DECISION_FRAMEWORK.md`](01_AI_DECISION_FRAMEWORK.md) · **Machinery:** docs [`02`](02_CONTEXT_ENGINE_DESIGN.md)–[`04`](04_EVENT_INTELLIGENCE_AND_PRIORITY_ENGINE.md) · **Module internals:** docs [`05`](05_MODULE_AI_DESIGN_ACADEMIC.md)/[`06`](06_MODULE_AI_DESIGN_OPERATIONS.md)
**Anchors:** Blueprint §5 (per-persona routers) · Audit `06` (copilot: 8 RBAC-scoped personas) · Roadmap **P3-AI-2** item 8 (rollout order Teacher → Parent → Principal → …).

> **Purpose.** Modules provide surfaces; **personas provide the day**. This document designs the
> five persona routers — how each role's whole experience composes from the module machinery, what
> their copilot resolves at which tier, what their memory learns, and what arrives proactively.
> A persona router *always* renders its deterministic core; model output is optional enrichment
> with a safe fallback (the audited pattern, generalized). Rollout order: **Teacher → Parent →
> Principal → Director → Student** (Teacher and Parent carry adoption; Principal carries the sale).

---

## 1. Teacher

### 1.1 Persona ground truth
- Highest-frequency operator: geo+face check-in, period attendance (draft autosave), homework, marks entry, timetable + substitutions, parent messaging, leave.
- `T-04` home: today's classes, pending-attendance alert, homework-to-review, unread messages, check-in chip. `T-17` AI (worksheet generator, weak-student list); teacher copilot persona exists (RBAC-scoped).
- Pains: EXM-1 marks ≈60 taps/class · ATT-3 no absentees-only fast-mark · TCH-1 no deep-link from schedule row · TCH-2 no marks-pending on home · TCH-3 homework re-typed per section · TCH-9 no self "My Attendance."

### 1.2 The adaptive day
- **07:40, opens app.** Morning brief is already there — generated at 04:00 [T2/P6, shared per class-section, doc 03 §3.3/3.4] above live cards [T1]: "6-B first period. 2 items due today: Unit-2 marks (12/30 entered, due Fri) · yesterday's absentees — 3 parents not yet notified." No model call happened this morning.
- **08:05, period 1.** Taps the schedule row → attendance marker opens on 6-B [P11, closes TCH-1], pre-set to **absentees-only fast-mark** [T1, closes ATT-3]. Submit → `attendance.submitted` → Signal Refinery updates class % and clears her priority item within seconds [doc 04 §2]. Her feed reorders; the "unmarked" card sinks [T1].
- **10:30, free period.** Feed's top card: "Enter Unit-2 marks — resume at row 13" [P11 → bulk grid, EXM-1]. As she saves, marks-completion signals update; the principal's exception board (doc 05 §4) reflects it without either of them asking.
- **13:00.** Creates one homework, targets **three sections at once** [T1, TCH-3]; due date is a real date (post-HWK-1), so due-tomorrow reminders schedule themselves [T0 rule, XCT-2].
- **16:00.** Taps "explain" on a student's trend chip: first tap this term generates the narrative [T3/P10, facts injected from `student_risk_engine` signals], cached — the same question from the co-class-teacher tomorrow hits cache [T2].
- **Total model calls caused by her entire day: 0–1.**

### 1.3 Router design
- **Deterministic core (always rendered, T1):** today's periods · unmarked classes · marks-pending per exam with due-in [EXM-6] · homework due/not-submitted counts · at-risk students *in her classes* (existing risk engine) · leave status · own attendance summary [TCH-9] · unread threads.
- **Copilot tiers:** enumerable intents resolve deterministically via intent detection [T1 — the `principal_query_service` pattern applied to teacher scope]: "who's absent today," "which marks are pending," "show 6-B homework gaps." Paraphrases of answered questions → fingerprint/semantic cache [T2]. Genuinely open questions ("how do I help Meera improve in fractions?") → model [T3/P10] grounded in her class's T1 facts; answer cached per student+topic.
- **Memory:** Persona Memory learns marking rhythm (nudge timing), favourite actions (quick-action strip order), dismissed card types; Interaction Memory keeps worksheet-generator context. Learned default: her school's marks-entry lag tunes when "due soon" turns urgent [doc 03 §2.5].
- **Dashboard:** priority strip pinned first; frequently-used (marks grid in exam season) rises ≤1 move/day, badged "moved up — Unit-2 due Friday" [doc 04 §5].
- **Proactive (T0):** attendance-cutoff nudge (only if unmarked at T-10 min) · marks-deadline T-2/T-0 · substitution assignment alert · leave decision. Quiet outside working hours; overflow folds into one end-of-day digest.
- **One-click:** schedule-row → marker [TCH-1] · absentees-fast-mark [ATT-3] · resume-marks-at-row [EXM-1] · notify-absentee-parents batch (T0 catalog, draft-and-hold if free-text added) · multi-section homework [TCH-3].

### 1.4 Recommendations
| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Teacher priority strip + pre-staged actions (TCH-1/2, ATT-3, EXM-1 links) | converts the ERP's two highest-frequency chores into taps; pure T1 | 🌟🌟🌟 | 100% | M | **W2** (first persona) |
| Pre-warmed class-section morning brief (shared) | "personal AI" feel at ~1 call/class-section/day, off-peak | 🌟🌟🌟 | ~98% vs per-teacher calls | M | **W2** |
| Teacher intent-router (T1 answers for enumerable questions) | most teacher questions are lookups — zero-cost, instant, offline-friendly | 🌟🌟 | 60–80% of copilot volume | M | **W2** |
| Explain-on-demand on trend/risk chips (cached per student+topic) | ad-hoc narrative only when asked; write-through makes it free for the next asker | 🌟🌟 | 80–90% over term | S | **W2** |

---

## 2. Parent

### 2.1 Persona ground truth
- Daily: check child's attendance/homework/marks, pay fees (Razorpay), receipts/report cards, message teachers, PTM booking; multi-child switcher (`parent_student_map`).
- `P-04` home: child hero, 3 quick actions (Pay Fee / Contact Teacher / Download Report Card), today's summary, notices, AI tip card; `P-22` copilot. **Parent Insights AI exists** (deterministic snapshot + optional warm in-language enrichment, numbers verbatim, ≤900 tokens); `parent_language_preferences` (7 languages).
- Pains: PAR-5 no proactive in-app reminders (fee/exam/PTM) · PAR-2 Apply Leave buried · PAR-1/6 PTM RSVP half-wired · PAR-4 80C export (shipped PAR-D3).

### 2.2 The adaptive day
- **07:30.** Opens app in Telugu preference. Family strip [T1, sibling-aware — doc 08 N4]: "Aarav — present, homework due today · Ananya — fee installment due Friday ₹8,500." The fee banner is a **rule, not a model** [T1/P2, closes PAR-5], its text a catalog template in Telugu [T0, frozen deterministic catalog].
- **07:31.** Taps the banner → Pay Fee opens with child+invoice pre-selected [P11]; pays; `finance.fee_collected` → banner gone, receipt notification [T0] in seconds [doc 04 §2].
- **13:00.** Weekly insights card: deterministic snapshot enriched *once* in Telugu [T3→T2: generated off-peak weekly per child, cached; numbers re-rendered live]. "Why did Ananya's maths dip?" → first ask generates [T3/P10 grounded in exam intelligence facts]; her husband asking the same tonight hits the semantic cache [T2/P7].
- **19:00.** PTM slot suggestion arrives — back-to-back slots for both children [T1 family logic]; one tap RSVP [PAR-1]. Digest-first defaults keep her at ≤2 notifications/day [doc 04 §6].
- **Model calls caused: ~1/week per child, amortized across the family and the cache.**

### 2.3 Router design
- **Deterministic core (T1):** own-children-only (RLS): attendance calendar · homework due · marks after publish · fee status/installments · bus route notices · PTM slots · receipts/certificates.
- **Copilot tiers:** the audit's flagship enumerable set resolves T1 ("when is the next fee due," "attendance this month," "when is the exam") via intent detection; T2 semantic cache catches paraphrases *and sibling-parents' repeats* (family-scoped keys where data is shared, child-scoped where not); T3 reserved for open guidance ("how can I help at home?") — generated **natively in the parent's language** (allowed split: generation ≠ translation), empathetic tone, facts verbatim.
- **Language:** UI English-first; all proactive comms via the frozen T0 catalog variants; AI features generate in `parent_language_preferences`. **No LLM ever in the send path.**
- **Memory:** engagement window (best-moment delivery, N5), digest opt-ins, preferred quick actions, dismissed tips; family graph from `parent_student_map` (no new identity surface — identity freeze respected).
- **Dashboard:** quick actions reorder by season and usage (fee window → Pay Fee first; report week → Report Card first) [T1, ≤1 move/day, badged].
- **Proactive (T0):** fee T-3/T-0/T+7 ladder · exam datesheet on publish · PTM T-1 · homework-due-tomorrow (opt-in) · absent-today (existing gated fan-out). All catalog-templated, family-deduped, quiet-hours aware.
- **One-click:** pay-exact-invoice · RSVP PTM · apply leave from absence context [PAR-2] · download report/80C cert [PAR-4] · reply-to-teacher.

### 2.4 Recommendations
| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| Proactive T0 banner/reminder ladder (PAR-5) | parents' most-requested gap; pure rules + catalog; measurably lifts on-time fee payment | 🌟🌟🌟 | 100% | M (needs XCT-2) | **W2** |
| Family-scope consolidation (N4) | fewer, better notifications; one payment journey for N children | 🌟🌟🌟 | 100% + reduces sends | M | **W2** |
| Parent intent-router + semantic cache in 7 languages | the highest-volume copilot; enumerable intents + paraphrase cache absorb the tail | 🌟🌟🌟 | 85–95% of parent Q&A volume | M | **W2** |
| Weekly in-language insights (pre-generated, cached, numbers live) | bespoke-feeling AI at ~1 call/child/week off-peak | 🌟🌟 | ~95% vs on-demand | S (exists — reschedule + cache) | **W2** |

---

## 3. Student

### 3.1 Persona ground truth
- View-own-data only; no messaging (parent-mediated), no fees. `S-04` home: greeting, timetable snippet, homework-due count, attendance today, announcements, quick actions. `S-18` AI Study Assistant (explain concepts, practice, weak-subject hints). Homework submission offline-queued.
- **Strictest guardrails of any persona:** age-appropriate, motivational, never shaming, study-scope only, no open-ended chat.

### 3.2 The adaptive day
- **07:50.** Home shows today's periods, "2 homeworks due — Maths today, Science tomorrow" [T1], and one gentle streak chip ("submitted 6 days in a row") [T1 — encouragement from counters, not a model].
- **17:00.** Opens Study Assistant on fractions (flagged weak from `exam_intelligence` + homework signals [T1]). The concept explanation comes from the **school-scoped explanation cache** — another student asked this topic last week [T2/P7]. A fresh topic would generate once [T3, moderated register, grade-banded vocabulary] and join the cache.
- **17:30.** Practice questions come from the existing moderation-gated question bank patterns — never auto-published AI content [existing governance].
- **Model calls caused: ~0 most days;** the study cache converges fast because a class shares a syllabus.

### 3.3 Router design
- **Deterministic core (T1):** timetable · homework due/submitted state · own attendance · published results · announcements · online-class join links.
- **Copilot tiers:** no general chat. The Study Assistant accepts **topic-scoped asks only** (subject/topic picker, not free chat): T1 for "what's due / my marks / my timetable"; T2 school-scoped topic-explanation cache (the biggest win — syllabus is shared, so hit-rates are naturally high); T3 first-generation explanations with grade-band style rules, output-guarded [doc 02 §5], cached per school+grade+topic+language.
- **Tone rules (hard):** encourage effort, never rank publicly, never compare to named peers, never mention fee/family data (not in the bundle anyway — RBAC), no discouraging language; violations fail output validation → T1 fallback.
- **Memory:** streaks, practiced topics, dismissed nudges. No behavioural profiling beyond study signals; retention short.
- **Dashboard:** homework card leads on due days; exam-countdown card auto-appears in datesheet window [T1 seasonal rules]; ≤1 organic move/day.
- **Proactive (T0):** due-tomorrow reminder · exam-schedule notice · results-published (after approval gate). Deliberately minimal — students get the fewest notifications of any persona.
- **One-click:** submit-homework (camera-first, offline queue — existing) · join class · practice-weak-topic.

### 3.4 Recommendations
| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| School-scoped topic-explanation cache for Study Assistant | shared syllabus ⇒ natural ~90%+ hit-rate; safe content reviewed once, reused N times | 🌟🌟🌟 | ~90–95% | S (on doc 03 cache) | **W2** |
| Topic-scoped (not free-chat) assistant + tone guard | child-safety by construction; smallest injection/abuse surface; cheap to certify | 🌟🌟🌟 (trust) | bounds T3 to first-asks | S | **W2** |
| Deterministic streaks/encouragement chips | motivation without a model and without ranking shame | 🌟🌟 | 100% | S | **W2** |
| Student persona ships **last** in rollout | least operational leverage; benefits from a matured cache + guard rails proven on adults first | — (sequencing) | — | — | **W2-tail** |

---

## 4. Principal

### 4.1 Persona ground truth
- Morning triage → approvals (leave + admissions, canonical audited queues) → timetable governance/substitutes → announcements → discipline/PTM/certificates. **No finance/salary visibility** (SRS rule — the Context Engine must never load finance sections for this persona beyond fee *operational* exceptions explicitly permitted by RBAC).
- `PR-01`: 6 KPIs, trends, split approval queues, AI at-risk list, AI morning briefing; `PR-16` AI Insights Hub. **Existing deterministic assets:** `principal_query_service` (NL intent → structured query, no LLM) and `principal_intelligence_service` (school health score, exportable summaries).
- Pains: PRI-1 single-select approvals (5–15/day one-by-one) · PRI-2 no pending-marks exception list · PRI-3 daily-report compose · PRI-4 no weekly digest · PRI-5 stale-approval escalation inert · **audit flags 3 overlapping principal dashboards + multiple AI entry points → consolidate to ONE hub.**

### 4.2 The adaptive day
- **07:30.** One home (consolidated hub). Top: the **daily pulse**, pre-warmed at 04:00 [T2/P6, one per school]: "Attendance 91% (6-C low, marker absent — substitute suggested). 9 approvals, 3 aging >48h. Marks: 2 teachers past deadline. 4 admissions awaiting you." Under it, live exception cards [T1/P4].
- **07:40.** Approvals: **batch-select** leave rows, each with a one-line deterministic summary chip (dates, cover status, balance) [T1, closes PRI-1]; approves 5 at once (the *decision* stays hers; AI only ordered and summarized). A leave approval fires substitution pre-staging [N8] — the plan is waiting; one tap applies.
- **09:00.** "3 classes drive 70% of this month's absence variance" [T1 Pareto, N12] — she taps through to the class-day heatmap; taps "explain" and gets the cached narrative [T2].
- **13:00.** Drafts a PTM announcement: model drafts once [T3/P9 draft-and-hold], parent copies localize via **T0 catalog**, she edits and sends. Delivery/read tracking is deterministic [COM-1].
- **18:00.** End-of-day auto-summary [T2, one generation, becomes PRI-3's daily report export via XCT-1].
- **Model calls caused by her day: ~2–3 (pulse pre-warm amortized, one draft, maybe one explain).**

### 4.3 Router design
- **Deterministic core (T1):** approvals queue with age + summary chips · unmarked-attendance board [ATT-4] · marks-completion board [EXM-2/PRI-2] · at-risk list (existing engine) · attendance/exam KPIs + Pareto decompositions · substitute suggestions · PTM/discipline/certificates worklists.
- **Copilot tiers:** extend `principal_query_service` intents (T1) — it already proves the pattern; add coverage (substitutes, marks status, admissions funnel). T2 for repeated analytical narratives; T3 for open synthesis ("what should I raise at tomorrow's staff meeting?") grounded in pulse facts, cached daily.
- **Memory:** triage order (approvals-first vs exceptions-first) learns from behaviour; threshold overrides she pins; dismissed insight types; escalation ladder preferences [PRI-5: stale >48h → top-strip, learned].
- **Dashboard:** ONE hub (consolidation is a precondition, see §4.4); priority strip → approvals → exceptions → KPIs; seasonal cards (exam season: marks board rises) [T1 rules].
- **Proactive (T0):** stale-approval escalation · unmarked-by-cutoff · marks-deadline breach · doc-expiry (school-scope) · daily pulse push at her learned open time; weekly digest [PRI-4] = deterministic tables + one cached narrative paragraph.
- **One-click:** batch-approve · apply-substitution-plan · nudge-marks-owing-teacher (T0 template) · announce-from-template · export daily report [XCT-1].

### 4.4 Recommendations
| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| **Consolidate to one principal hub before adding AI** (audit finding) | 3 overlapping dashboards + scattered AI entries would triple cache keys, split memory, and confuse the persona — consolidation is a W2 precondition, not polish | 🌟🌟🌟 | avoids 2–3× duplicate surface cost | M | **W2 (first)** |
| Batch-approval with deterministic summary chips (PRI-1) | clears the #1 principal pain; decisions stay human; zero model involvement | 🌟🌟🌟 | 100% | M | **W2** |
| Pre-warmed daily pulse + end-of-day summary (PRI-3/4) | one generation each per school per day, off-peak, cached — the "AI principal assistant" story at ~₹2/day | 🌟🌟🌟 | ~97% vs on-demand | M | **W2** |
| Extend the deterministic intent router before widening T3 copilot | `principal_query_service` proves most principal questions are lookups; grow T1 coverage first | 🌟🌟 | 60–80% of copilot volume | S–M | **W2** |

---

## 5. Director

### 5.1 Persona ground truth
- Multi-school portfolio oversight, **aggregate-only — no student/parent PII** (privacy banner every screen; the Context Engine enforces this: no student-row loaders exist in this persona's manifests, doc 02 §3).
- `DR-01`: 5 KPIs, school health gauges, growth, marketing ROI, funnel, **AI executive summary (exists — Claude with deterministic fallback)**; `DR-08` compliance calendar.
- Pains: DIR-1 no league table ("Compare Schools" dead) · DIR-2 no consolidated per-school collection report · DIR-3 export PDF-only.

### 5.2 The adaptive day (weekly rhythm — directors are not daily operators)
- **Monday 09:00.** Weekly digest ready [T2/P6, one per org per week]: portfolio narrative over deterministic KPIs. League table [T1, closes DIR-1]: schools ranked on health score with movement arrows and Pareto note ("School C drives 62% of the collection gap" [N12]).
- **09:15.** Drills into School C — aggregate collection trend, aging mix, target-vs-actual [T1, DIR-2]. Taps "explain the dip" → cached narrative if any exec asked before [T2], else one grounded generation [T3/P10].
- **09:30.** Compliance radar [T1]: "2 fire NOCs expire in 30 days; School B's transport permit in 14." One-click: assign task to school admin + reminder ladder [T0].
- **Board week.** One tap: board pack assembles deterministic tables/charts [T1 + XCT-1 export, CSV per DIR-3] with one cached executive narrative [T2].
- **Model calls: ~1–2/week/org.**

### 5.3 Router design
- **Deterministic core (T1):** league table + health gauges · cross-school collection/enrollment/attendance aggregates · funnel + marketing ROI · compliance horizon · anomaly flags (school deviating from its own baseline — learned thresholds at org scope).
- **Copilot tiers:** T1 intents ("collection this quarter by school," "which schools are at risk") over org-scope aggregates; T2 cached comparisons; T3 for open synthesis (board narrative, cross-school diagnosis) — **context bundles contain aggregates only**, enforced by manifest (no student sections exist for this persona), so even a successful prompt injection cannot surface a child's data.
- **Memory:** watched schools/KPIs pin first; digest day/time; accepted recommendation types (e.g., always acts on compliance, ignores marketing) reweight the feed.
- **Dashboard:** portfolio strip → league → watched schools → compliance; a school entering "at-risk" band auto-rises with badge [T1, ≤1 move/day].
- **Proactive (T0):** compliance expiry ladder T-30/T-14/T-7 · school-anomaly alert (aggregate) · weekly digest push.
- **One-click:** assign compliance task · export board pack (PDF/CSV) · open school drill-down · schedule review meeting (calendar draft).

### 5.4 Recommendations
| Rec | Why better | Impact | API savings | Cx | Pri |
|---|---|---|---|---|---|
| League table + drill-downs + CSV (DIR-1/2/3) as pure T1 | the entire "director intelligence" promise is aggregation — no model needed until the narrative | 🌟🌟🌟 | 100% | M | **W2** |
| Weekly pre-warmed org digest (one generation/org/week) | executive-grade AI feel at the lowest call volume of any persona | 🌟🌟 | ~98% | S | **W2** |
| Aggregate-only manifests as a hard platform rule (not UI discipline) | privacy by construction — the audit's Director privacy rule becomes unfalsifiable | 🌟🌟🌟 (trust) | n/a | S | **W2** |
| Org-scope anomaly detection via per-school learned baselines | "schools at risk" becomes evidence-backed, explainable, per-trust calibrated | 🌟🌟 | 100% | M | **W2–W3** |

---

## 6. Cross-persona coherence

1. **One engine, five filters.** All personas ride the same Context Engine, Priority Engine, and caches — a persona router is configuration (manifests, intents, feeds), not a fork. New personas (Office/Admin, Finance clerk — Blueprint §5) reuse the same shape in W2-tail.
2. **Shared facts, private views.** The same `ai_fact_signals` row (e.g., class attendance %) powers teacher, principal, and director surfaces at their RBAC scopes — computed once.
3. **Rollout = Teacher → Parent → Principal → Director → Student**, matching roadmap P3-AI-2; each rollout step is its own EOS-gated wave (doc 09).
4. **The pulse/brief/digest family is one platform feature** (pre-warm + shared generation + T0 assembly) instantiated per persona — build once in W2, configure five times.
5. **Copilot economics rank:** Parent (highest volume → build the T1 intent router + 7-language cache first among copilots) > Teacher > Principal > Director > Student (cache-fed, guard-railed, last).

---

*Companions: [`05_MODULE_AI_DESIGN_ACADEMIC.md`](05_MODULE_AI_DESIGN_ACADEMIC.md) · [`06_MODULE_AI_DESIGN_OPERATIONS.md`](06_MODULE_AI_DESIGN_OPERATIONS.md) (module internals these routers consume) ·
next: [`08_NOVEL_ADAPTIVE_AI_IDEAS.md`](08_NOVEL_ADAPTIVE_AI_IDEAS.md) · [`09_IMPLEMENTATION_WAVES_AND_METRICS.md`](09_IMPLEMENTATION_WAVES_AND_METRICS.md).*
