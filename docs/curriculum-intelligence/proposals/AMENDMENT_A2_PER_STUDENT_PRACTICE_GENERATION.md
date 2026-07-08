# Curriculum Intelligence — Planning Amendment **A2** (PROPOSAL)
## Deterministic Per-Student Practice & DPP Generation Engine

> **Lifecycle state:** 🟡 **PENDING OWNER RATIFICATION.** The owner has **approved the
> architectural DIRECTION and decisions D-7 + I9 (2026-07-08)**; this amendment remains a
> *tracked planning proposal* until final ratification folds it into the frozen specs. Until
> then it does **NOT** modify the frozen `FINAL_EXECUTION_MASTER_ROADMAP.md`, the frozen
> Curriculum specs (AIMS / MCIP / v3.0 Master Plan — kept verbatim as owner drops), the frozen
> owner decisions D-1…D-6, or the certified invariants I1–I8; it does not change implementation
> sequencing; nothing is implemented. It exists to show **exactly where** the owner's approved
> capabilities integrate into the existing Curriculum Intelligence specifications *before*
> implementation begins.
>
> **Approval status:** **direction APPROVED** by owner (2026-07-08); **D-7 APPROVED**, **I9
> APPROVED**; six supporting principles added (§12). **Full spec merge = pending final
> ratification.**
>
> **Provenance:** Owner directives, 2026-07-08 (this session) — (1) "Prepare a planning-only
> Curriculum amendment. Lock the following architectural decisions… Do NOT modify the roadmap
> yet." (2) "I approve these architectural decisions: D-7… I9… Please extend Amendment A2 with
> these additional owner decisions before final ratification… make Amendment A2 an officially
> tracked planning proposal that is fully discoverable and traceable… while remaining pending
> until final owner ratification."
> **Authority it extends (never replaces — D-1):** `OPUS_IMPLEMENTATION_HANDOFF.md`,
> `audits/GAP_ANALYSIS.md` (A1-*), `audits/BACKWARD_COMPATIBILITY_PLAN.md` (I1–I8, B12),
> `planning/IMPLEMENTATION_SEQUENCE.md` (CI-C1/C3/C5/C7/C8/C10), `spec/` (AIMS + MCIP),
> `docs/Vision/design/Assessment-Intelligence-Platform.md` (v3.0 §12.2, §13).

---

## 0. One-paragraph verdict

The owner's eight decisions are **already ~80% the frozen doctrine.** The offline-AI /
deterministic-runtime split ("never invoke AI per paper"), **bank-first determinism (I1)**,
**AI = candidates only (I3)**, the **L3-Certified-Bank-only** production rule (D-3), the
**D-6 trust lifecycle**, the **Question Factory with "zero runtime AI" (CI-C10)**, and even
"**one verified family yields unlimited solver-checked instances**" (v3.0 §12.2) are all
locked today. **Exactly one architectural extension is genuinely new:** make the certified
unit the **Question *Family*** (template + parameter rules + distractor rules + validation/
solver rules) rather than each individual generated *instance*, so the runtime can
**deterministically instantiate unlimited per-student variants** that *inherit* the family's
certification — with **no runtime AI**. That extension is fully compatible with I1 and I3
(runtime stays deterministic and AI-free); it touches only **D-3/D-6's definition of "what a
certified production source is."** Everything else (per-student modes, overlap/uniqueness
controls, cross-day non-repetition, competitive framing) is an **additive layer** on the
already-planned waves **CI-C1 / CI-C3 / CI-C7 / CI-C8 / CI-C10** and the **v3.0 §13 DPP
scheduler**. No new lane is required; the frozen pre-pilot ERP path is untouched.

---

## 1. The eight locked decisions → disposition

| # | Owner decision (2026-07-08) | Already in frozen doctrine? | New work? | Owning integration point |
|---|---|---|---|---|
| **1** | Runtime generation must NOT use AI; AI only offline (creation, review, enrichment, certification) | ✅ **YES** — AIMS "offline-AI / deterministic-runtime split (never invoke AI per paper)" (`OPUS_IMPLEMENTATION_HANDOFF.md:65`); CI-C10 "**zero runtime AI**" (`IMPLEMENTATION_SEQUENCE.md:62`); I1 bank-first determinism | Affirm only | §2 (confirm) + new invariant **I9** (§3) |
| **2** | Deterministic engine on certified Families, Templates, Parameter Rules, Distractors, Blueprint Rules, Validation Rules | ✅ **Mostly** — CI-C1 solver (blueprint rules), CI-C10 `edu_question_templates`/`edu_question_families`/`edu_distractors` (B12), CI-C5 validation | Family = certified unit (§3) | CI-C1 + CI-C10 |
| **3** | Build a very large certified repository (→ thousands–millions of families); runtime reuses it, not AI | ✅ **YES (direction)** — D-3 three-layer, **L3 Certified Bank = only default production source**; v3.0 §12.2 "families = the scalable original-content machine" | Scale target is new; content depends on data lane | CI-C10 (factory) + DATA lane CI-A1…A6 (⏳ owner/network-gated) |
| **4** | Each certified Family generates **unlimited deterministic parameterized instances** preserving objective, competency, difficulty, blueprint, answer-correctness | 🟡 **Partial** — v3.0 §12.2 "one verified family yields **unlimited solver-checked instances**"; but frozen CI-C10 certifies **each instance** (`GENERATED→…→CERTIFIED` per item) | **The one real amendment: family-level certification + runtime instantiation** | **§3** — CI-C10 (certify the family) + CI-C1 (instantiate at assembly) |
| **5** | Generation modes: Same paper · N unique sets · One unique paper per student · Daily DPP · Unlimited practice | 🟡 **Partial** — multi-set A/B/C (CI-C3); DPP scheduler (v3.0 §13, Phase 2). **Per-student-unique + unlimited-practice modes are new** | New "Generation Modes" spec + params | **§4** — CI-C1/CI-C3 + v3.0 §13 |
| **6** | Controls: max overlap · non-repetition window · student uniqueness · parameter variation · option variation · equivalent structures · blueprint preservation | 🟡 **Partial** — variation (CI-C10 families/distractors); blueprint preservation (CI-C1 constraints); exposure/rotation + selection-reason (CI-C8). **Per-student exposure + max-overlap + uniqueness are new** | Extend exposure to per-student; add assembly controls | **§5** — CI-C8 (per-student exposure) + CI-C1 (assembly constraints) |
| **7** | Fast, offline-capable where possible, deterministic, zero-runtime-AI by default | ✅ **YES** — deterministic solver is already the production engine (I1); zero-runtime-AI (CI-C10) | Affirm + perf/offline targets | §7 (integration matrix) + acceptance tests §11 |
| **8** | Major differentiator for IIT/JEE/NEET, Olympiad, Foundation, daily practice | 🟡 **Partial** — CI-C7 profiles (JEE/NEET/Olympiad/Foundation); competitive first-class types = v3.0 **Phase 3** | Keep the *engine* board/exam-agnostic (not Phase-3-gated); stage *content* depth | **§6** — CI-C7 + v3.0 Phase 3 |

---

## 2. What is ALREADY locked (decisions 1, 2, 3, 7) — affirm, do not re-litigate

These require **no change** — the amendment only strengthens/records them:

- **Zero runtime AI (decisions 1, 7).** AIMS binding pattern: *"offline-AI / deterministic-runtime
  split (never invoke AI per paper)"* (`OPUS_IMPLEMENTATION_HANDOFF.md:65`). CI-C10 exit gate:
  *"candidates only (I3/I4) — **zero runtime AI**"* (`IMPLEMENTATION_SEQUENCE.md:62`). Invariant
  **I1** = bank-first determinism (`BACKWARD_COMPATIBILITY_PLAN.md §1`).
- **Deterministic engine on certified assets (decision 2).** The production engine is the
  **bank-first deterministic blueprint solver** (`education_blueprint_solver.ts`, golden-pinned in
  P1-CI-0). CI-C1 upgrades it (slot groups, choice pools, chapter/cognitive quotas as hard
  constraints). Families/templates/distractors are the greenfield **B12** tables
  (`edu_question_templates`, `edu_question_families`, `edu_distractors`).
- **Certified repository is the only production source (decision 3).** Owner **D-3**: three-layer
  model, **L3 Certified Question Bank = the only default production source** (`GAP_ANALYSIS.md:66`);
  **D-6**: *only CERTIFIED generates by default*. v3.0 §12.2 already names families *"the scalable
  original-content machine … one verified family yields unlimited solver-checked instances."*

**Net:** decisions 1–3 and 7 are ratifications of existing doctrine. The only thing decision 3
adds is an explicit **scale ambition** (thousands→millions of families), which is a **content**
goal owned by the **DATA lane (CI-A1…A6, ⏳ owner/network-gated)** + the **CI-C10 factory**, not an
engine change.

---

## 3. The single architectural extension (decision 4): **family-level certification + deterministic instantiation**

### 3.1 The gap (precise)
Frozen **CI-C10** performs *offline batch generation* where **every generated instance** walks the
D-6 lifecycle `GENERATED → AI_VALIDATED (CI-C5) → TEACHER_VALIDATED → CERTIFIED`
(`IMPLEMENTATION_SEQUENCE.md:62`). Under instance-level certification, "100 fresh questions daily
per class" would each need a teacher to certify them — **impossible at scale**. The owner's
decision 4 requires the *family* to be the certified unit, so unlimited instances can be minted
**deterministically at runtime** without a per-instance teacher gate.

### 3.2 The amendment
**Certify the generative process, not each output.** A **Question Family** is CERTIFIED when its
`{template stem, parameter variables + constraint ranges, distractor rules, blueprint/competency/
objective binding, difficulty model, and a deterministic answer solver/validator}` have passed
`GENERATED → AI_VALIDATED (CI-C5) → TEACHER_VALIDATED → CERTIFIED`. Thereafter, a **runtime
instance** of that family is **CERTIFIED-equivalent** iff **all** of:
- (a) it was produced by the certified template + certified parameter rules,
- (b) its parameters fall inside the certified constraint ranges,
- (c) its answer is produced/verified by the certified **deterministic solver** (no AI),
- (d) it passes the Curriculum Boundary Engine v2 (I2) and the metadata-completeness gate,
- (e) its distractors come from the certified distractor rules for that family.

No AI runs at instantiation; the instance is a deterministic derivation, not new authored content.

### 3.3 Invariant reconciliation (this is the load-bearing part)
| Invariant | Effect of the amendment |
|---|---|
| **I1 — bank-first determinism** | **PRESERVED & EXTENDED.** The "bank" now includes **certified generative families** alongside certified static items. Runtime remains fully deterministic (seeded parameters + solver). |
| **I3 — AI output = candidates only; publish gate** | **PRESERVED, UNTOUCHED.** Runtime does **not** call AI. AI is used **only offline** to *author/validate the family*, and its offline outputs remain **candidates** until a teacher certifies the family. There is no new "AI auto-approves content" path. |
| **D-3 — L3 Certified Bank = only production source** | **CLARIFIED.** "Certified production source" = certified static items **∪ certified families**. L1/L2 still never auto-flow into L3. |
| **D-6 — only CERTIFIED generates** | **EXTENDED.** The certified *unit* may be a family; its deterministic instances inherit CERTIFIED status per §3.2 (a)–(e). Static-item and singleton AI-authored paths keep **instance-level** certification unchanged. |
| **I2 — syllabus boundary (422)** | **PRESERVED.** Every instance is boundary-checked at instantiation (reuses `education_syllabus_boundary.ts`; A1-2 "generation-time" hook already lists CI-C10). |

### 3.4 Owner decisions this section requires
- **D-7 (proposed — ratified by this directive):** *Certification granularity is family-level for
  parameterized families*; instance-level certification remains for static items and one-off
  AI-authored singletons.
- **I9 (proposed — new certified invariant):** *"Runtime question generation is deterministic and
  AI-free. A runtime instance is valid only if produced by a CERTIFIED family under its certified
  parameter and validation rules, with a solver-verified answer, boundary-clean and
  metadata-complete. The runtime never mints uncertified content and never calls a model."*
  (Formalises decisions 1, 4, 7 as an inviolable guarantee, extending I1–I8.)

### 3.5 Where it integrates
- **CI-C10** — extend the Question Factory so **family certification** is a first-class output
  (certify template + parameter rules + solver + distractor rules), not only per-instance
  certification. B12 tables gain: `certification_scope` (`instance` | `family`),
  `parameter_constraints` JSON, `solver_ref`/`validation_rules`, `objective_id`/`competency_id`,
  `difficulty_model`.
- **CI-C1** — the blueprint solver becomes **instantiation-aware**: when a slot resolves to a
  certified family, it **deterministically instantiates** an instance (seeded) within constraints
  instead of only selecting a static row. *Template/family absent ⇒ legacy behaviour (B1).*
- **CI-E1b** — concept read-path already required by CI-C10 (AIMS Rule 2: never generate without a
  concept mapping). Unchanged.

---

## 4. Generation modes (decision 5)

Add a first-class **Generation Mode** to the paper-configuration spec (MCIP "PAPER
CONFIGURATION" / AIMS "Pipeline 7 — Paper Assembly"):

| Mode | Meaning | Frozen coverage | Integration |
|---|---|---|---|
| **Same paper** | One identical paper for all | ✅ default assembly | CI-C1 |
| **N unique sets** | Teacher picks N; N distinct papers (shuffle + variant) | 🟡 generalises A/B/C | **CI-C3** (A/B/C → arbitrary N + per-set keys) |
| **One unique paper per student** | Class size → one distinct paper each | ❌ **new** | **CI-C1 + CI-C3** (per-student loop over families + uniqueness controls §5) |
| **Daily DPP** | A fresh set each day, per student/class | 🟡 scheduler exists | **v3.0 §13 `edu_dpp_schedules`** (Phase 2) driving CI-C1 |
| **Unlimited practice** | Student regenerates on demand within a topic/difficulty | ❌ **new** | **CI-C1** instantiation + CI-C8 per-student exposure (§5) |

New config params (additive to MCIP "PAPER CONFIGURATION → Number of Questions"):
`generation_mode` enum · `set_count` (N) · `target_audience` (class | per-student) ·
`per_student_uniqueness` (bool) · `daily` (bool). All optional; **absent ⇒ "Same paper" legacy
behaviour (B1)**.

---

## 5. Engine controls (decision 6)

| Control | Frozen coverage | Integration |
|---|---|---|
| **Parameter variation** | ✅ CI-C10 Item Models (numeric/variable/context) | CI-C10 |
| **Option variation** | ✅ CI-C10 distractor rules | CI-C10 |
| **Equivalent problem structures** | 🟡 family isomorphism (v3.0 §12.2) | CI-C10 (family = the equivalence class) |
| **Blueprint preservation** | ✅ CI-C1 hard constraints (chapter weightage, cognitive quotas) | CI-C1 |
| **Non-repetition window** | 🟡 exposure/rotation + exclusion windows (CI-C8, MCIP duplicate-prevention) | **CI-C8 — extend to per-student** |
| **Student uniqueness** | ❌ **new** (multi-set is A/B/C hall-scale, not per-student) | **CI-C1 assembly constraint + per-student exposure ledger** |
| **Max question overlap** | ❌ **new** | **CI-C1** — cap shared items/families across a batch of papers |

Extensions:
- **CI-C8** — generalise `edu_item_exposures` (v3.0 §10.1, `times_used`/`last_used_at`) with a
  **per-student dimension** so "no repeat instance/family within an *N*-day window per student"
  is enforceable. Owner sets the default window *N* (§9).
- **CI-C1** — add assembly-time constraints: `max_overlap_pct` across a paper batch, and a
  per-student uniqueness pass that draws distinct instances/families per student. Deterministic
  (seeded per `student_id × date`), so DPP mode is reproducible and auditable.

---

## 6. Competitive differentiator (decision 8)

- Profiles for **JEE / NEET / Olympiad / NTSE / Foundation** already exist in **CI-C7** (Exam
  Profile Engine; foundation = *depth-not-scope*) and v3.0 Phase 3.3–3.4 (competitive types as
  first-class). ("IIT" is not a spec term; competitive prep is framed JEE/NEET/Olympiad.)
- **Amendment:** the **family + deterministic-instantiation engine is board/exam-agnostic** and is
  **not gated behind Phase 3.** The *engine capability* (per-student unlimited practice) is
  available for any profile the moment certified families exist; competitive **content depth**
  (question-type coverage, negative marking, multi-subject mocks) stays staged with the data lane
  + v3.0 Phase 3. This lets daily-practice/DPP ship for regular boards first and light up
  competitive prep as certified families accrue — the differentiator scales with content, not with
  a phase gate.

---

## 7. Integration matrix (where every capability lands — no new lane)

| Capability | Owning wave | Spec anchor | New/extended assets | Invariant reconciliation | Depends on |
|---|---|---|---|---|---|
| Zero-runtime-AI guarantee | (all) | AIMS split; CI-C10 | — | **I9** (new) affirms I1/I3 | — |
| Family-level certification | **CI-C10** | AIMS Pipeline 4; v3.0 §12.2 | B12 + `certification_scope`, `parameter_constraints`, `solver_ref` | **D-7**, D-6 extend | CI-C5, CI-E1b |
| Deterministic runtime instantiation | **CI-C1** | v3.0 §12.2; CI-C1 solver | solver instantiation path | I1 extend; I2 boundary at gen-time | CI-C10 families |
| N sets / per-student / unlimited modes | **CI-C1 + CI-C3** | MCIP Paper Config; AIMS Pipeline 7 | `generation_mode` params | B1 (absent ⇒ legacy) | CI-C1 |
| Daily DPP scheduling | **v3.0 §13** (Phase 2) | `edu_dpp_schedules` | scheduler → CI-C1 | additive | CI-C1 |
| Per-student non-repetition / overlap / uniqueness | **CI-C8 + CI-C1** | v3.0 §10.1; MCIP duplicate-prevention | per-student `edu_item_exposures`; assembly constraints | additive | CI-C1 |
| Answer keys at scale / auto-grade unique papers | **v3.0 response spine (E1a)** + marks-grid | v3.0 §5.2/§10 | per-instance key from solver | I6 exam-results integrity | CI-C1 instantiation |
| Competitive profiles (JEE/NEET/Olympiad/Foundation) | **CI-C7** + v3.0 Phase 3 | CI-C7; v3.0 §15 | profile config | I2 depth-not-scope | CI-C1 |

---

## 8. Dependencies & proposed sequencing (NOT committed — for owner scheduling)

- **Engine legs** (family certification CI-C10, instantiation CI-C1, modes CI-C3, per-student
  exposure CI-C8) sit in **v3.0 Phase 1 (code lane)** — i.e. **post-pilot**, consistent with the
  frozen **Option A** decision (`INTEGRATION_AND_READINESS_REVIEW.md:108`). They do **not** change
  the pre-pilot ERP path (P2 → P3-AI-1 → P4).
- **Content** (decision 3's large certified repository) depends on the **DATA lane
  (CI-A1…A6 → Repository Certification D-5)**, which is **⏳ owner/network + licence-gated**, plus
  the CI-C10 factory. **The engine can ship before the repository is huge** — it operates on
  whatever families are certified; value scales with content.
- **Scoped red-team re-run** applies when these AI-adjacent surfaces ship (same rule as
  CI-C5/C6/C7/C10) — not a second global P4.
- **DPP scheduler + competitive first-class types** are **v3.0 Phase 2/3** (owner-timed).

*Suggested epic name for owner scheduling (non-binding):* **"Deterministic Practice Generation
Engine (DPGE)"** — grouping CI-C10 (family certification) + CI-C1 (instantiation) + CI-C3 (modes)
+ CI-C8 (per-student non-repetition) + v3.0 §13 (DPP), gated behind D-7/I9 ratification and a
certified family repository.

---

## 9. Owner decisions — status

1. **D-7 — certification granularity = family-level** (for parameterized families). ✅ **OWNER-APPROVED
   (2026-07-08).** *Record in `GAP_ANALYSIS.md` D-register on final ratification.*
2. **I9 — runtime-instantiation invariant** (zero-AI, certified-family-only, solver-verified).
   ✅ **OWNER-APPROVED (2026-07-08).** *Add to `BACKWARD_COMPATIBILITY_PLAN.md §1` as a new
   inviolable invariant on final ratification.*
3. **Generation-mode set** (Same / N sets / per-student / Daily DPP / Unlimited practice) as
   first-class config. ✅ **APPROVED (2026-07-08, §12.3).** *Needs the MCIP/AIMS spec section on merge.*
4. **Engine controls** (max overlap % / non-repetition window / student uniqueness / parameter
   variation / option variation / equivalent structures / blueprint preservation). ✅ **APPROVED
   (2026-07-08, §12.4).**
5. **Exam-agnostic architecture** — one engine for school exams / worksheets / homework / DPP /
   Foundation / Olympiad / IIT-JEE / NEET / scholarship / any future profile. ✅ **APPROVED
   (2026-07-08, §12.5).**
6. **Repository-First + Large-Repository Vision** — certified repository is the primary product
   asset; scale to lakhs→millions of certified families; runtime AI is never the production
   strategy. ✅ **APPROVED (2026-07-08, §12.1 / §12.6).**

**Still-open parameters (owner to set on ratification):**
- **Per-student non-repetition window default *N*** (e.g. "no repeat instance within 14 days").
- **Answer-key-at-scale / auto-grading** for per-student-unique papers — confirm the v3.0 response
  spine (E1a) + marks-grid capture handle a distinct key per student (needs an explicit acceptance
  check when the wave opens).

---

## 10. Acceptance criteria (proposed — for when it is implemented)

- **Family → unlimited instances:** a CERTIFIED family produces *K* deterministic instances, **all**
  solver-correct, **same** objective/competency/difficulty/blueprint, boundary-clean,
  metadata-complete (extends **AT-C10.1**).
- **Per-student uniqueness at scale:** 100 students → 100 papers, pairwise overlap ≤ configured
  `max_overlap_pct`, no per-student repeat within window *N*, every item solver-verified.
- **Zero runtime AI (regression guard):** generation of any mode emits **0 LLM tokens**
  (assert against the model gateway) — formalises **I9**.
- **Daily DPP freshness:** *M* consecutive days produce non-repeating per-student sets, bounded by
  family pool + rotation; reproducible from `(student_id, date)` seed.
- **Legacy safety:** `generation_mode` absent ⇒ byte-identical to today's single-paper output
  (B1); static-item certification path unchanged.

---

## 11. Explicit non-actions (scope guard)

- **No** frozen roadmap file modified. **No** frozen spec (AIMS/MCIP/v3.0) modified. **No** owner
  decision D-1…D-6 or invariant I1–I8 changed. **No** code written. **No** wave opened.
- This document is a **proposal awaiting owner ratification**; on approval, its D-7/I9 and the
  spec deltas above would be folded into the frozen Curriculum specs and the CI wave scopes as an
  amendment, and scheduled **post-pilot (v3.0 Phase 1+)** per Option A.
- The current active ERP wave (**P2-UX-4 accessibility**) is unrelated and unaffected.

---

## 12. Owner-approved architectural principles (2026-07-08)

The owner approved the direction and asked to lock the following six principles into A2 before
final ratification. They are recorded here as the **binding intent** the eventual spec merge must
honour. (They restate/tighten §§2–6; nothing here conflicts with I1–I8 or D-1…D-6.)

### 12.1 Repository-First (formal architectural principle)
**The certified repository is the primary product asset. Runtime AI is never the production
strategy.** Production paper/practice generation draws **only** from the L3 Certified Question Bank
— certified static items **∪ certified Question Families (D-7)** — never from a runtime model call.
AI's role is confined to **offline** content creation, review, enrichment, and certification. This
elevates the existing D-3 ("L3-only") + I1 (bank-first determinism) into a stated **product
principle**: *the moat is the certified repository, not a model.*

### 12.2 Adaptive (deterministic) Generation Engine
The **deterministic engine — not AI — performs all runtime generation.** It:
- selects certified Question Families (blueprint- and profile-driven),
- generates parameter values (seeded, within certified constraint ranges),
- generates equivalent instances (family = the equivalence class),
- selects distractors (from certified distractor rules),
- shuffles options,
- preserves **blueprint**, **competency**, and **difficulty**,
- and **guarantees deterministic, reproducible output** (seeded by e.g. `student_id × date × config`).

"Adaptive" here means *adapts the selection/parameterisation to the request (class, subject,
chapter, topic, difficulty, count, per-student uniqueness)* — **deterministically**, with **zero
runtime AI (I9)**. Adaptivity is a property of the deterministic selector, never of a runtime model.

### 12.3 Teacher Generation Modes (approved set)
First-class modes (see §4 for wave mapping): **Same Paper · N Unique Sets · One Unique Paper Per
Student · Daily DPP · Unlimited Practice.** `generation_mode` absent ⇒ "Same Paper" legacy
behaviour (B1).

### 12.4 Generation Controls (approved set)
Configurable (see §5 for wave mapping): **Maximum overlap % · Non-repetition window · Student
uniqueness · Parameter variation · Option variation · Equivalent problem structures · Blueprint
preservation.**

### 12.5 Exam-Agnostic Architecture (principle)
**One engine, one architecture, every exam type.** The family + deterministic-instantiation engine
is generic and reusable for: **School Exams · Practice Worksheets · Homework · Daily DPP ·
Foundation · Olympiad · IIT-JEE · NEET · Scholarship Exams · any future competitive profile.**
**No exam type may require a different architecture** — exam-specific behaviour is expressed as
**profile configuration** (CI-C7: blueprint, question-type mix, marking, reasoning depth,
difficulty), never as a forked engine. This makes the engine capability **not** Phase-3-gated;
competitive *content depth* is staged with the data lane + v3.0 Phase 3, but the *engine* serves
any profile the moment certified families exist.

### 12.6 Large Repository Vision (long-term objective)
The long-term objective is to **continuously expand the certified repository into hundreds of
thousands and eventually millions of certified Question Families** across boards, subjects, classes,
and competitive profiles — so runtime generation remains **deterministic, scalable, and AI-free**
at any volume. This is a **content** program owned by the DATA lane (CI-A1…A6, ⏳ owner/network-gated)
+ the CI-C10 factory; the engine ships and operates on whatever families are certified, and its
value compounds as the repository grows. *Repository growth is the roadmap; runtime AI is never the
fallback.*

---

## 13. Lifecycle & ratification tracking

| Field | Value |
|---|---|
| **Lifecycle state** | 🟡 **Pending Owner Ratification** |
| **Direction approved** | ✅ 2026-07-08 (owner) |
| **Decisions approved** | D-7 ✅ · I9 ✅ · Generation modes ✅ · Controls ✅ · Exam-agnostic ✅ · Repository-First/Large-repo ✅ (§12) |
| **Open parameters** | non-repetition window *N*; answer-key-at-scale acceptance check (§9) |
| **Blocks on** | final owner ratification → then fold D-7/I9 + §12 into frozen specs (GAP_ANALYSIS D-register, BACKWARD_COMPATIBILITY_PLAN §1, MCIP/AIMS generation-mode section) |
| **Does NOT** | modify the frozen master roadmap · change CI sequencing · merge into verbatim specs · start implementation |
| **Implements as** | post-pilot v3.0 Phase 1+ (Option A); epic "Deterministic Practice Generation Engine (DPGE)" across CI-C10/C1/C3/C8 + v3.0 §13 |

---

*Amendment A2 · planning-only · 2026-07-08 · extends the Curriculum Intelligence program (D-1:
extend never replace). Direction + D-7/I9 + §12 owner-approved; full spec merge pending final
ratification. Supersedes nothing.*
