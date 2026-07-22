# PROGRAM D — Engineering Readiness Report
## Certified Knowledge Bank Integration & Retrieval Engine

**Date:** 2026-07-22 · **Status:** 📋 Readiness review — **documentation only** (no code, no schema, no migration,
no live API call). · **Author lane:** autonomous prep, under the owner's "prepare for Program D" directive. ·
**Spec source of truth:** master roadmap `docs/roadmap/AKSHARA_CONSTITUTION_ALIGNED_MASTER_ROADMAP.md` §5.7;
promotion contract `docs/question-intelligence-quality/R5-3_ERP_PROMOTION_CONTRACT_DESIGN.md` (D1–D6).

> **Prime directive of this report:** decide whether Program D is *implementation-ready*, and if not, name exactly
> what blocks it. It changes no roadmap decision, weakens no gate, and modifies no frozen program.

---

## 0. Executive summary

Program D connects the **QIE certified question bank** to the **ERP Education Suite** so the product becomes
**Knowledge-Bank-first, not AI-first**: *Teacher Request → Certified Question Retrieval Engine (QRE) → Certified
Bank → Deterministic Paper Assembly*, with **≈0 % live-AI on the teacher request path**.

The readiness verdict is **conditional**:

- **Engineering-plannable now: YES.** The architecture is well-specified, the locked decisions are internally
  consistent, and — the key finding of this review — Program D is **far less greenfield than the founding audit
  implied**, in two ways:
  1. The ERP already carries a large, coherent **dormant Curriculum-Intelligence schema** (item models/families,
     distractor library, canonical concept graph, exposure log + counters, rotation policy, blueprint templates,
     response/marks spine, question-trust columns) built by the CI-C/E waves — SCHEMA-ONLY, unwired.
  2. The ERP **already ships a LIVE, golden-tested, bank-first deterministic paper generator** —
     `education_blueprint_solver.ts` (pure, "no DB, no network, no randomness") driven by
     `education_question_paper_service.ts:generateQuestionPaper()`. It fills a blueprint from the ERP bank first
     and sends only the **unfillable gaps** to constrained AI as `source='ai_candidate', review_status='pending'`
     (and a paper **cannot publish** while AI candidates are pending). **This is exactly the Knowledge-Bank-first
     shape Program D wants** — it already exists, reading the *school-authored* bank.
  So Program D is mostly **wiring + reconciliation**: feed **certified QIE content** into that assembler (via the
  promotion pipeline) so the constrained-AI gap-fill trends to **≈0**, plus build the missing QIE→ERP promotion,
  measured metadata, exposure write-path, semantic near-dup, and certified-bank ranking. Little is net-new design.
- **Data-ready now: NO — this is the #1 blocker.** Program D's stated **precondition is a non-empty certified
  bank**. The bank is **empty** (`qpl_question_bank.db`: 0 product-visible certified; 23 quarantined + 1
  rejected). Program C (just closed under Option 3) certified **nothing** — the recalled 22 correctly fail the
  current gates. **There is no certified content to promote, retrieve, rank, or de-duplicate.** Until a future
  owner-approved live run against a **gate-passing cohort** (or a deterministic certified-family lane) yields
  certified items, Program D can be **built and tested against fixtures** but cannot be **operated or accepted**
  end-to-end.

**GO/NO-GO (detail in §9): GO to build Phases 1–3 (contract + wiring + QRE skeleton) against fixtures now;
NO-GO on operational acceptance until the certified bank is non-empty.** Both are owner-gated.

---

## 1. Architecture assessment

### 1.1 The two worlds (verified)
1. **QIE intelligence engine** (`curriculum/scripts/intelligence/kie/`, Python, SQLite): the certified factory
   (`qie/factory/`), certified bank `qpl_question_bank.db` (`corpus.certified_bank()`, corpus.py:511), the
   deterministic paper lane (`qpgen/`, `qie/qp_bridge.py`), the concept graph (`qie/graph/`), KC_-namespaced
   concepts, item-hash dedup (RI-9).
2. **ERP Education Suite** (`lib/` Flutter, `supabase/` Postgres+RLS, `web/`): the school-authored question bank
   `edu_question_bank_items`, exam/paper features, and a **large DORMANT Curriculum-Intelligence schema** (below).

**The disconnection (the founding-audit finding):** no ERP code references the QIE engine — `grep qie|kie|qpl|
certified.question` across `lib/ supabase/ web/` returns zero hits; `corpus.certified_bank()` has no consumer.
The two worlds share **no vocabulary** (QIE `KC_<sha14>` text vs ERP `concept_code`/UUID) and **no wire**.

### 1.2 ★ The ERP is not greenfield — a dormant CI schema already exists (new finding)
The founding audit's "zero hits" is about **QIE consumption**, and is accurate. But the ERP separately carries a
coherent **dormant, additive** schema from the Curriculum-Intelligence (CI-C/E1) waves that maps closely onto
Program D's needs. Each is **SCHEMA-ONLY** (created, RLS-governed, **no production data, no read/write wiring**):

| ERP dormant asset | Migration | Program-D relevance |
|---|---|---|
| `edu_question_templates` (Item Models), `edu_question_families`, `edu_distractors` (distractor library) | `20260858_edu_question_factory_schema` | The A2 "certified family" / I9 runtime-instantiation home + distractor library. Platform-read catalogue (I7). |
| `canonical_concepts` (graph nodes: `concept_code`, `bloom_levels`, `common_misconceptions`, `merged_into` dedup) | `20260859_edu_canonical_concept_graph` | Concept graph + **Bloom** + concept dedup. `edu_question_bank_items.concept_id` stays NULL until wired. |
| `edu_item_exposures` (usage log) + `times_used`/`last_used_at` counters; `edu_student_item_responses` (marks/response spine) + `trust_status`/`trust_evidence` | `20260853_e1a_dormant_response_trust_exposure_seed` | **Exposure intelligence** data + **measured-difficulty** signal source + question-trust seam. |
| `edu_item_rotation_policies` (cooldown/rotation config) | `20260856_edu_item_rotation_policy` | **Ranking/rotation** policy (turns exposure signals into selection order). |
| `edu_blueprint_templates`, `edu_exam_profiles` | `20260854`, `20260855` | Blueprint + exam-profile constraints for deterministic assembly. |
| `edu_question_bank_items` classification columns | `20260857_edu_question_classification_columns` | `concept_id` (UUID), difficulty, provenance seams. |

**Implication:** Program D's dominant cost is **populating + wiring** this dormant schema and **bridging it to the
QIE certified bank**, not designing new stores. The R5-3 D1 "platform-readable, platform-written" pattern already
exists as the CI **platform-read catalogue** (invariant I7).

### 1.3 The retrieval reality (nuance on "bank-first retrieval")
Three deterministic assemblers already exist; none is wired to the QIE **certified** bank:
- **ERP** `education_blueprint_solver.ts` (+ `generateQuestionPaper()`) — the **product path**: bank-first,
  golden-tested, deterministic; fills from the **school-authored** `edu_question_bank_items`, gap-fills via
  constrained AI (`ai_candidate`/pending, unpublishable). **This is the assembler Program D should feed.**
- **QIE** `qpgen/select.py` + `assemble.py` (`importance_score` ranking) — a deterministic Python selector, but it
  reads **kie.db mined `question_patterns`** (4853), **not** `certified_bank`.
- **QIE** `qp_bridge.py` — wires QIE into the Python `qpgen` lane, not the ERP.

Per **I9/A2** (`CURRENT_VS_REQUIRED_ARCHITECTURE.md`) the certified unit is a **family / Item Model**, and runtime
is **deterministic instantiation + solver verification**, not necessarily static-instance retrieval. So the QRE is
not a pure SQL SELECT over a static table — it is **deterministic selection/instantiation of certified families**,
optionally materialised as stored instances for exposure/dedup. Program D must ratify **retrieve-stored-instances
vs instantiate-certified-families** (both satisfy "≈0 % live-AI at request time") and decide whether the QRE
**feeds the existing ERP solver** (recommended — reuse the product path) or replaces it. *(Design decision — §8.)*
Note the "≈0 % live-AI" target is a **coverage** property: the ERP already gap-fills with AI **today**; Program D
drives that to ≈0 by making the certified bank rich enough — it is measurable as `ai_candidate` rate per paper.

### 1.4 The empty-bank blocker
`qpl_question_bank.db` holds **0 product-visible certified rows**. Program C (Option 3) added none. The
certified-content supply is therefore the gating input for Program D's *operation* (not its *construction*).

---

## 2. Locked-decision verification

Program D as specified **preserves every locked decision**. Verified against the spec + code:

| # | Locked decision | Preserved? | How |
|---|---|---|---|
| 1 | **Knowledge-Bank first** | ✅ | `Teacher Request → QRE → Certified Bank → Deterministic Assembly`; live-AI removed from the request path. |
| 2 | **AI only for offline expansion** | ✅ | AI confined to the offline factory / continuous expansion / cross-family certification; never the teacher request path. |
| 3 | **Runtime deterministic (I9)** | ✅ | QRE = deterministic retrieval/instantiation + solver verification; no LLM at request time. |
| 4 | **Generator family ≠ Judge family** | ✅ | Unchanged — a Program-C/factory concern; Program D only **consumes** already-certified output; it never judges. |
| 5 | **No weakening of certification** | ✅ | Promotion admits **only** `status='certified' AND certification_class='certified'` (RI-6 one product-visible bank); Program D adds no cert path and no gate. |
| 6 | **Bank-first retrieval** | ✅ | The QRE reads the certified bank; manual authoring stays as an optional parallel path. |
| 7 | **Deterministic paper assembly** | ✅ | Assembly is deterministic + explainable (reuses the deterministic selector); no live generation. |

**No locked decision requires modification. No frozen program (Program B, ERP, KIE v1.4/v1.5 index, QIE
completion record) is touched by the plan.**

---

## 3. Dependency graph

```
                 KIE frozen index (v1.5)  ─────────────┐  (read-only substrate; concept crosswalk)
                                                        ▼
  Program C (cross-family certify) ──►  QIE certified bank (qpl_question_bank)   ◄── EMPTY today
        │  (supplies certified content — PRECONDITION)      │
        │                                                   │  R5-2 concept_namespace (done)
        ▼                                                   ▼
  Program A / R5-3 promotion CONTRACT (design done) ──►  [D2] edu_concept_vocabulary (KC_↔UUID)  ── MISSING
        │  (Program D IMPLEMENTS it)                         │
        ▼                                                    ▼
  ┌──────────────────────── PROGRAM D ─────────────────────────────────────────────┐
  │  WS1 Promotion pipeline (exporter → platform bank)  ── consumes R5-3 D1/D4/D5    │
  │  WS3 Metadata completion (measured difficulty ← response spine; Bloom ← concepts)│
  │  WS2 QRE (retrieval/instantiation)  ── consumes WS1 + qpgen/select.py            │
  │  WS4 Near-dup (semantic)   WS5 Exposure (edu_item_exposures)   WS6 Ranking       │
  │  WS7 ERP integration (Education Suite paper builder ← QRE)                       │
  └────────────────────────────────────────────────────────────────────────────────┘
        ▲                                   ▲
        │                                   │
  ERP dormant CI schema (§1.2)        Response/marks spine (measured difficulty; pilot-seeded, not backfillable)
```

**Hard prerequisites:** (a) a **non-empty certified bank** (Program C output — unmet); (b) the **R5-3 contract**
(design done); (c) **R5-2 concept_namespace** (done). **Soft/parallel:** ERP dormant schema (exists, needs
wiring); measured difficulty needs **pilot response signal** (seeded at first pilot use, not backfillable).

---

## 4. Component inventory & gap analysis

Classification: **IMPLEMENTED** / **PARTIAL** / **SCHEMA-ONLY** (created but dormant/unwired) / **MISSING**.

*(Completed from the read-only component sweep — QIE-side and ERP-side cross-checked, with file:line evidence.)*

| # | Capability (component) | State | Evidence / what exists | What's missing for Program D |
|---|---|---|---|---|
| 1 | **QIE Certified Bank** | IMPLEMENTED but **EMPTY / orphan** | `corpus.py:511 certified_bank()` / `:493 product_inventory` / `:521 read_production_bank`; RI-6; role-gated. `qpl_question_bank.db` = **0 certified** (23 quar/1 rej). `factory_corpus.db` has 15 "certified" but all `trial_certified` = product-INVISIBLE. `certified_bank()` referenced only in tests. | Certified content supply; a real consumer |
| 2 | **ERP Question Bank** | IMPLEMENTED | `edu_question_bank_items` (`20260620000000`); **school-scoped RLS only** (no `_platform_read`); live teacher authoring (`education_repository.ts:181`) | The platform-bank sibling (D1); certified feed |
| 3 | **Promotion Contract (Program A / R5-3)** | PARTIAL — **design only** | R5-3 D1–D6 spec; R5-2 `concept_namespace` done (1108 rows) | Exporter, platform-bank migration+RLS, `edu_concept_vocabulary`, enum map, manifest — **all unbuilt** |
| 4 | **Retrieval Engine (QRE)** | PARTIAL | ERP `education_blueprint_solver.ts` (pure deterministic, golden-tested) + `education_question_paper_service.ts:168` do **bank-first assembly over the *school* bank**; QIE `qpgen/select.py:116` deterministic but reads **kie.db mined patterns**, not certified | The **certified-bank feed** into the ERP solver; drive AI gap-fill → ≈0 |
| 5 | **Blueprint Engine** | IMPLEMENTED (both sides) | QIE `qie/knowledge/blueprint.py:43` (generation planner → specs, predicted-uncalibrated); ERP `edu_blueprint_templates` (`20260854`) + live solver | Wire ERP blueprint templates → QRE constraints |
| 6 | **Education Suite** | IMPLEMENTED | Flutter/Supabase exams + papers; deterministic solver + manual editing + `promotePaperItemToBank` | The certified-bank-fed path (WS7) |
| 7 | **Question Paper Generator** | PARTIAL | ERP deterministic generator LIVE (`generateQuestionPaper` + solver); QIE `qpgen`/`qp_bridge.py` separate Python lane (mined patterns) | Feed certified content; reconcile the two lanes; not a rebuild |
| 8 | **Metadata models** | PARTIAL / SCHEMA-ONLY | ERP: `cognitive_level` enum (remember…hots = Bloom axis), `marks`, `concept_id` (dormant), `trust_status`; `bloom_levels` on `canonical_concepts`; QIE: declared/predicted difficulty (`difficulty_basis` **hard-coded structural_proxy**, never measured) | **Measured** difficulty (needs pilot signal), Bloom population, KC↔UUID linkage, marks mapping |
| 9 | **Concept Graph** | IMPLEMENTED (QIE) / SCHEMA-ONLY (ERP) | QIE `qie/graph/` populated (prereq 1805, namespace 1108, revisits 18), KC_ spine; ERP `canonical_concepts` (`20260859`) **dormant**, `concept_id` NULL everywhere | Populate ERP graph + the **KC_↔UUID bridge** (R5-2→D2) |
| 10 | **Exposure tracking** | SCHEMA-ONLY (dormant) | ERP `edu_student_item_responses` (response/marks spine), `edu_item_exposures`, `times_used`/`last_used_at` (`20260853`), `education_item_rotation.ts` helper — **no production writer/reader** | Write-path (log exposures) + read-path (prefer-unseen); QIE has none |
| 11 | **Duplicate detection** | PARTIAL | QIE: exact (`item_hash`) **+ lexical near-dup** (Jaccard≥0.85 ∧ difflib≥0.85, gate `near_duplicate`, gates.py:653) + bank dedup (RI-9); ERP: exact fingerprint only (`education_fingerprint.ts` FNV-1a) | **Semantic/paraphrase near-dup** — MISSING everywhere |
| 12 | **Ranking logic** | PARTIAL / MISSING (for certified) | QIE `qpgen/select.py:60 importance_score` (freq+recency+centrality+authority) over the **mined pool**; ERP `edu_item_rotation_policies` + rotation helper (dormant) | Deterministic explainable ranking **of certified items** consuming exposure+difficulty+rotation |

**Summary (12 capability areas):** IMPLEMENTED 4 · PARTIAL 6 · SCHEMA-ONLY 2 (concept-graph ERP-side, exposure) ·
MISSING as a distinct capability: **semantic near-dup** (1). Cross-cutting: the **empty-bank data blocker** and the
**absent QIE→ERP promotion wiring** are the two things gating everything. Net: the pieces exist and are
individually well-built — Program D is overwhelmingly an **integration/wiring** program, not a build-from-zero.

---

## 5. Implementation roadmap (phases)

Each phase is **additive, EOS-gated, independently verified**. Migrations are ERP-lane-owned and land in the ERP
band (current head `20260876000000`; next free ≈ `20260877000000+`, avoiding the ASIP `2026092x` band).

### Phase D0 — Foundations & fixtures (no live path)
- **Objective:** stand up the KC_↔UUID vocabulary bridge and a certified-content **fixture** so every later phase
  is buildable/testable before the real bank fills.
- **Dependencies:** R5-2 `concept_namespace` (done); R5-3 D2 design.
- **Files/modules:** new `edu_concept_vocabulary` migration + seed (D2); a Python fixture that emits N synthetic
  certified rows in the QIE bank shape (test-only).
- **Risks:** KC_ ids without a UUID → honest-null (never guess); vocabulary drift vs frozen index.
- **Testing:** round-trip KC_↔UUID; honest-null on unmapped; freeze-fingerprint pin.
- **Acceptance:** every certified KC_ concept resolves to exactly one UUID or is explicitly unmapped; 0 guessed.

### Phase D1 — Promotion pipeline (R5-3 implementation)
- **Objective:** implement the exporter `qpl_question_bank → edu_platform_question_bank` with a versioned,
  freeze-pinned manifest; promote **only** `certified/certified`.
- **Dependencies:** D0; R5-3 D1/D3/D4/D5; owner-approved platform-bank migration + RLS (I7 platform-read shape).
- **Files/modules:** `edu_platform_question_bank` (+ `edu_school_adopted_items`) migration + RLS **reusing the
  existing `_platform_read` catalogue pattern** (organization_id NULL + platform-read policy, as on
  `edu_question_templates`/`canonical_concepts`); exporter service; content-hash id (D5); manifest (D4). Enum map
  at the boundary: ERP `difficulty CHECK IN ('easy','medium','hard')` (QIE emits `moderate`→`medium`); ERP
  `question_type CHECK IN ('mcq','fill_blank','match','short_answer','long_answer','diagram')` — **lacks
  `numerical`** → owner-gated CHECK **extension** (never a weakening). Migration band: next free
  **`20260877000000+`** (current head `20260876000000_ai_semantic_cache`; monotonic counter).
- **Risks:** tenant-isolation leak (a school writing platform rows); enum CHECK failure; non-idempotent re-export;
  recall propagation. **Never weaken a CHECK — map/extend at the boundary.**
- **Testing:** live RLS/tenant-isolation ("school reads platform items it must not write"); idempotent re-export;
  recall→tombstone propagation; freeze-fingerprint mismatch refuses.
- **Acceptance:** a certified item appears once in the platform bank, readable by all tenants, writable only by the
  platform role; a recall removes/tombstones it; re-export is a no-op.

### Phase D2 — Metadata completion (measured, not declared)
- **Objective:** attach retrieval-grade metadata — measured difficulty, Bloom, marks, concept UUID, KC linkage.
- **Dependencies:** D1; the ERP **response/marks spine** (`edu_student_item_responses`, `20260853`) for measured
  difficulty (**pilot-seeded, not backfillable** — measured difficulty stays honest-null until signal exists).
- **Files/modules:** difficulty-calibration column (predicted vs measured, per R5-3 D3); Bloom population from
  `canonical_concepts.bloom_levels`; marks mapping.
- **Risks:** selling **predicted** difficulty as **measured** (forbidden — R2-5); empty pilot signal.
- **Testing:** predicted≠measured never conflated; honest-null on no-signal; measured difficulty recomputed only
  from real responses.
- **Acceptance:** every promoted item carries Bloom + marks + concept UUID; difficulty labelled predicted **or**
  measured, never blended.

### Phase D3 — QRE = certified feed into the existing ERP solver (fixture-fed)
- **Objective:** make the certified platform bank a **first-class source for the existing ERP deterministic
  assembler** (`education_blueprint_solver.ts` / `generateQuestionPaper()`), so a blueprint fills from certified
  content first and the constrained-AI gap-fill trends to **≈0**. **Reuse the product path — do not rebuild it.**
- **Dependencies:** D1/D2; ERP `education_blueprint_solver.ts` (golden-tested); `edu_blueprint_templates`/
  `edu_exam_profiles`. Ratify retrieve-stored-instances vs instantiate-certified-families (§1.3, §8).
- **Files/modules:** extend the paper service's bank source to the certified/adopted union view; a certified-item
  read model; keep the pure solver untouched (only its input pool changes).
- **Risks:** the generate-on-the-fly vs retrieve-stored ambiguity; blueprint under-fill when the bank is thin
  (falls to AI gap-fill today — must be reported as the `ai_candidate` rate, not hidden).
- **Testing:** deterministic (same request→same paper); blueprint constraints honored; explainable selection
  trace; **measured `ai_candidate` rate** per paper; graceful under-fill (honest, never a silent live-AI expansion).
- **Acceptance:** a teacher request fills from certified content with a measured, declining AI-gap-fill rate; the
  existing golden solver tests stay green (additive input, no solver behaviour change).

### Phase D4 — Exposure + near-dup + ranking
- **Objective:** prefer-unseen selection (exposure), no near-duplicates in a paper, deterministic explainable ranking.
- **Dependencies:** D3; `edu_item_exposures`, `edu_item_rotation_policies`; a semantic near-dup signal.
- **Files/modules:** exposure write/read wiring; **semantic near-dup** (new — none exists); ranking engine over
  {exposure, difficulty, rotation}.
- **Risks:** semantic near-dup is the only genuinely-new capability (embedding/similarity — must stay deterministic
  & explainable, not a black box); ranking non-determinism.
- **Testing:** two papers to one class share no near-dups; prefer-unseen honored under blueprint constraints;
  ranking reproducible + explainable.
- **Acceptance:** exposure-aware, near-dup-free, deterministically-ranked papers; every choice explainable.

### Phase D5 — ERP integration + operational acceptance (bank non-empty)
- **Objective:** wire the QRE into the Education Suite paper builder; keep manual authoring optional; operate on
  **real certified content**.
- **Dependencies:** **a non-empty certified bank** (the blocker); all prior phases.
- **Files/modules:** Flutter/web paper-builder path → QRE; `edu_question_papers` assembly; manual path preserved.
- **Risks:** empty/thin bank → poor coverage; UI math-render (LaTeX D6) debt.
- **Testing:** end-to-end teacher paper request served from certified content; live-AI request-path calls = 0;
  manual authoring still works.
- **Acceptance:** ERP serves real certified papers deterministically; **≈0 % live-AI at request time** (measured);
  EOS FEATURE+AI PASS.

---

## 6. Risk analysis & red-team

**Red-team of the proposed architecture** (adversarial "how does this go wrong / get bypassed?"):

1. **Empty-bank masking.** *Threat:* a thin/empty bank tempts a "temporary" live-AI fallback on the request path,
   silently violating I9. *Mitigation:* make under-fill an **honest failure** ("insufficient certified items"),
   never an AI fallback; assert live-AI-request-path-calls == 0 as a **test + production gate**.
2. **Promotion admits non-certified.** *Threat:* a widened WHERE clause or a provisional row leaking into the
   platform bank. *Mitigation:* exporter reads only `certified/certified`; RI-6 one-bank invariant; a red-team
   test that seeds provisional/quarantined/expired and asserts **0 promoted**.
3. **Tenant isolation break.** *Threat:* a school writes or over-reads platform rows. *Mitigation:* platform-write /
   all-tenant-read RLS (I7 shape); adversarial "school writes a platform item" test must fail closed.
4. **Predicted-as-measured difficulty.** *Threat:* selling an uncalibrated label as measured metadata.
   *Mitigation:* separate `difficulty_calibration`; honest-null until pilot signal; never blend (R2-5).
5. **Vocabulary drift / guessed UUID.** *Threat:* a KC_→UUID guess to raise coverage. *Mitigation:* honest-null
   on unmapped; freeze-fingerprint pin; round-trip test.
6. **Semantic near-dup as a black box.** *Threat:* an opaque embedding ranker breaks determinism/explainability.
   *Mitigation:* deterministic similarity with a fixed, versioned model + explainable threshold; reproducibility
   test (same inputs → same dedup verdict).
7. **Recall doesn't propagate.** *Threat:* a re-certified/recalled item stays live in the ERP. *Mitigation:*
   adoption-by-reference (not copy) + hash tombstone; recall-propagation test.
8. **Re-export duplication.** *Threat:* re-running the exporter duplicates rows. *Mitigation:* content-hash id (D5)
   idempotency; re-export = no-op test.
9. **Frozen-store drift.** *Threat:* export mutates the frozen index. *Mitigation:* export is read-only on the
   frozen substrate; manifest pins fingerprints; byte-identity check.

**Standing risks:** measured difficulty is **pilot-gated** (not backfillable); LaTeX/notation debt (R5-3 D6) should
be gated at authoring time **before** scale; the bank must reach scale for "≈0 % live-AI" to be real (a coverage,
not just correctness, property).

---

## 7. Effort estimates

Engineering + verification, not calendar. "S/M/L" = small/medium/large.

| Phase | Eng | Verify | Notes |
|---|---|---|---|
| D0 vocabulary + fixtures | S | S | reuses R5-2; migration + seed + fixture |
| D1 promotion pipeline | **L** | **H** | platform bank + RLS + exporter + manifest + enum map; cross-lane (ERP owns migrations) |
| D2 metadata completion | M | M | wiring + calibration column; blocked on pilot signal for *measured* |
| D3 QRE + assembly | **L** | **H** | the retrieve-vs-instantiate decision + deterministic selector wiring |
| D4 exposure + near-dup + ranking | M–L | H | semantic near-dup is the only net-new capability |
| D5 ERP integration + acceptance | M | H | Flutter/web wiring; gated on non-empty bank; EOS FEATURE+AI |

**Overall: LARGE** (comparable to Programs B/C combined), dominated by D1 (promotion + platform bank + RLS,
cross-lane) and D3 (QRE). Much is **wiring** the existing dormant ERP schema rather than new design, which lowers
risk but not volume. Cross-lane coordination (ERP migrations) is the main scheduling constraint.

---

## 8. Recommended execution sequence

```
D0 (vocab + fixtures)  →  D1 (promotion)  →  D2 (metadata)  →  D3 (QRE)  →  D4 (exposure/dedup/rank)  →  D5 (ERP + accept)
   buildable now            owner-gated        pilot-gated       fixture-fed     fixture-fed              bank-gated
   (fixtures)               (ERP migration)    (measured diff)                                            (non-empty bank)
```

- **Build D0–D4 against fixtures now** (no certified content required to *construct/test* them).
- **D1's migrations are owner-gated** (ERP-lane numbering + RLS approval).
- **D2's *measured* difficulty and D5's *acceptance* are data-gated** on, respectively, pilot response signal and a
  non-empty certified bank.
- **Do not start D5 operational acceptance** until the certified bank is non-empty (a gate-passing Program-C run or
  a certified-family lane).

**Owner decisions to ratify before/within Program D:**
1. Approve the **platform-bank migration + RLS** and its band numbering (D1).
2. Ratify **retrieve-stored-instances vs deterministically-instantiate-certified-families** as the QRE model
   (§1.3) — this shapes D3 and the metadata model.
3. Approve the **LaTeX authoring contract (R5-3 D6)** *before* bank growth (avoids re-authoring debt).
4. Ratify **"≈0 % live-AI at request time"** as a hard production gate (test + prod assertion).
5. Confirm the **certified-content source** for D5 acceptance (gate-passing live cohort vs certified-family lane).

---

## 9. Final GO / NO-GO

- 🟢 **GO — to author/implement Phases D0–D4 against fixtures**, under normal owner sequencing. The architecture is
  sound, the locked decisions hold, and the ERP's dormant CI schema makes most of Program D a wiring/reconciliation
  effort with low design risk.
- 🟡 **CONDITIONAL / HOLD — on operational acceptance (D5) and on any migration.** Two gates are unmet:
  1. **Data:** the certified bank is **empty** — nothing to promote/retrieve/rank until a future owner-approved
     certified-content run fills it. This is the dominant blocker.
  2. **Owner:** the D1 platform-bank migration + RLS, the QRE retrieval model (§1.3), the LaTeX contract, and the
     "≈0 % live-AI" gate are **owner decisions** not yet ratified.
- 🔴 **NO-GO on anything that would weaken a gate to compensate for the empty bank** (e.g., a live-AI request-path
  fallback, promoting provisional rows). Explicitly out of bounds.

**Recommendation:** approve Program D **planning-complete**; authorize **D0** (vocabulary bridge + fixtures) as the
first buildable, fully-additive step; keep **D1 migrations, the QRE model decision, and D5 acceptance** owner-gated
pending (a) the platform-bank/RLS approval and (b) a non-empty certified bank.

**No code, schema, migration, or live API call was produced by this review. No roadmap decision or frozen program
was modified.**
