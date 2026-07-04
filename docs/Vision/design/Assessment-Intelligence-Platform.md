# Akshara — Assessment Intelligence Platform (Master Plan v3.0)

**Document ID:** `AKS-AIP-MASTER-PLAN-v3.0`
**Created:** 2026-07-02 (owner decision session)
**Status:** 🔒 **Locked long-term vision** — supersedes the v2.0 master plan as the authoritative forward architecture
**Supersedes:** `docs/archive/planning/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md` (v2.0 — architecture preserved by reference, strategy amended per §2)
**Related:** `docs/archive/design/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` (workflow design, still valid) · `AI-Question-Paper-System.md` (original track note) · `docs/archive/completed/QUESTION_INTELLIGENCE_LIVE_CERTIFICATION.md` (production baseline)

---

## 1. What this document is

The v2.0 master plan designed an **Academic Knowledge Platform** (knowledge repository, board trees, question families, exam profiles, confidence pipeline). That architecture **stands** — nothing in it is replaced here.

This v3.0 evolves it in one fundamental way and locks ten owner decisions (2026-07-02):

> **The platform's primary intelligence asset is no longer only the question bank — it is the
> response corpus.** Every student's per-question result, collected practically and cheaply,
> is the raw material from which difficulty, quality, mastery, and adaptivity are derived.
> Questions are the *instrument*; responses are the *measurement*. A question bank can be
> copied by a competitor; years of calibrated response data cannot.

Akshara is therefore not building a Question Paper Generator, and not a commercial question bank. It is building an **Assessment Intelligence Platform**: a system that continuously grows through original content, teacher and school contributions, AI-assisted generation, and — above all — real assessment evidence.

---

## 2. Locked owner decisions (2026-07-02)

These are product law for this platform. Changes require an explicit owner decision.

| # | Decision | Consequence |
|---|----------|-------------|
| **D1** | **Response-centric model.** Per-question responses, correctness, marks awarded, concept/chapter performance, and historical trends become the architectural foundation. | New response spine (§5). Paper-centric model is preserved as the *authoring* half; responses become the *evidence* half. |
| **D2** | **Practical collection — no per-student answer-sheet uploads.** Teachers evaluate normally; Akshara provides a per-question **marks grid**; teachers photograph it (or type into it); the system extracts structured per-question results with teacher confirmation. | Marks-Grid workflow (§6). Per-student answer-sheet OCR/OMR is **not pursued**. |
| **D3** | **OCR-first, AI-second.** Deterministic extraction first; AI only for ambiguous cases; teacher confirmation always last. Minimize AI token usage across all ingestion. | Ingestion doctrine (§7) applies to marks grids, bank imports, and past-paper ingestion alike. |
| **D4** | **Canonical Concept Layer.** Concepts exist once, board-independent ("Ohm's Law" is one node); AP / Telangana / CBSE / ICSE / JEE / NEET map onto it. | Core data model (§8). Board content trees stay separate (v2.0 §9 preserved); the canonical layer is the analytics/mastery spine, never a content-copy channel. |
| **D5** | **Blueprint templates are governed data**, not runtime parameters: official board structures, section rules, chapter weightage, competency quotas, internal choices, board revisions over time. | Blueprint template model (§9). The solver *satisfies* a versioned template. |
| **D6** | **Evidence-based question quality.** Difficulty and quality evolve from item statistics, duplicate detection, exposure tracking, and distractor quality as response data grows — not from labels alone. | Quality engine (§10). Teacher-declared difficulty remains the *prior*; evidence becomes the *posterior*. |
| **D7** | **AI output is never trusted automatically.** Multiple validation layers before any AI-generated question becomes a trusted question. | Verification layers (§11) extend the existing moderation gate; the live-certified publish gate is unchanged. |
| **D8** | **Original-content-first copyright strategy.** No dependency on commercial publisher question banks as a primary strategy. Primary sources: teacher-created, school-contributed, original AI-generated, curriculum-aligned original content. | Content strategy (§12). **Amends v2.0 §10:** Category B (publisher licensing) is demoted from strategic pillar to *optional, never-primary* channel. Legal guardrails of v2.0 §25 remain fully in force. |
| **D9** | **ERP-integrated, not isolated.** Question Intelligence consumes the school's real academic state: attendance, homework, class progress, completed syllabus, teaching pace, exam history, student performance, parent communication. | Academic State model (§13). |
| **D10** | **Adaptive AI per school.** The platform adapts to each school's curriculum, completed syllabus, workflows, calendar, teacher preferences, difficulty preferences, and historical assessments. Two schools on the same board receive different papers when their teaching progress differs. | Adaptation architecture (§14), bounded by the syllabus boundary and blueprint compliance. |
| **D11** | **Phased delivery.** Phase 1 completes the existing Question Intelligence platform; Phase 2 introduces structured response collection + concept intelligence; Phase 3 delivers adaptive assessment, mastery tracking, competitive exams, advanced analytics. | Roadmap (§15). Nothing advanced is built before its phase. |

---

## 3. Identity — Generator vs Assessment Intelligence Platform

| | Question Paper Generator | **Assessment Intelligence Platform (Akshara)** |
|---|---|---|
| Asset | PDF papers | Original knowledge + **response corpus** |
| Difficulty | Declared by author | Measured from evidence |
| Quality | Manual review | Trust pipeline: evidence promotes questions |
| Output | Same paper for every school on a board | Adapted to each school's academic state |
| Loop | None | Marks → concept performance → next blueprint |
| Moat | None (copyable) | Compounding, uncopyable measurement data |

---

## 4. The production foundation (Phase 1 baseline — preserve, never replace)

Live-certified 2026-06-25 (20/20, real auth/DB/RBAC/AI). This is the trust layer everything else builds on. **No decision in this document weakens it.**

| Guarantee | Enforced by |
|-----------|-------------|
| Bank-first, deterministic generation | `education_blueprint_solver.ts` (pure, reproducible) |
| Hard syllabus boundary (422 OFF_SYLLABUS) | `education_syllabus_boundary.ts`, server-side |
| AI = moderation candidates only, never auto-published | `education_ai_question_gapfill.ts` + publish gate `409 PAPER_HAS_PENDING_ITEMS` |
| Safe-by-default (no key → honest gaps, zero fabrication) | gap-fill contract |
| Governance: draft → submit → review → approve → publish; submitter ≠ approver; principal-only `approveEducation` | `edu_question_paper_reviews`, RBAC, live-certified |
| Provenance + fingerprint dedup on every bank item | `20260710000000_education_question_intelligence.sql` |

**Phase 1 completes this platform** (§15) — the known as-built gaps (solver constraints, blueprint sections, moderation UI, candidate→bank merge, paper↔exam link, multi-set, PDF quality, bank cold-start) are Phase 1 work, not redesign.

---

## 5. Architecture evolution — paper-centric ➜ response-centric (D1)

### 5.1 The response spine

Today the platform's data ends at `published paper` + one total mark per student per exam (`exam_mark_entries`). The response spine extends the chain:

```
Paper (authoring half — exists today)
  └── published → conducted as Exam
        └── edu_exam_paper_links          (paper ↔ exam event, set code)
              └── edu_student_item_responses   ← THE new atomic asset
                    ├── item_statistics        (per-question evidence)
                    ├── concept/chapter performance (via canonical concepts)
                    ├── student mastery state  (Phase 3)
                    └── next blueprint / adaptive generation (Phase 3)
```

### 5.2 Core new tables (Phase 2)

```sql
-- Link a conducted exam to the exact paper (and set) used.
edu_exam_paper_links (
  id, organization_id, school_id,
  exam_id TEXT NOT NULL,             -- matches exam_mark_entries.exam_id
  paper_id UUID REFERENCES edu_question_papers(id),
  set_code TEXT DEFAULT 'A',
  UNIQUE (organization_id, school_id, exam_id, set_code)
)

-- One row per student per question per assessment. The platform's atomic evidence.
edu_student_item_responses (
  id, organization_id, school_id,
  exam_id TEXT NOT NULL,
  paper_id UUID, paper_item_id UUID,
  bank_item_id UUID,                 -- denormalized: analytics survive paper edits
  item_version INT DEFAULT 1,        -- statistics pin to the version answered (§10.4)
  student_id UUID NOT NULL,
  max_marks NUMERIC NOT NULL,
  marks_awarded NUMERIC,             -- NULL = not evaluated yet
  is_correct BOOLEAN,                -- derived for objective items
  attempted BOOLEAN NOT NULL DEFAULT true,   -- blank/skipped detection
  chosen_option SMALLINT,            -- ONLY from digital attempts (§6.4)
  time_spent_ms INT,                 -- ONLY from digital attempts
  capture_source TEXT NOT NULL       -- 'marks_grid_ocr' | 'marks_grid_manual'
    CHECK (capture_source IN ('marks_grid_ocr','marks_grid_manual',
                              'digital_attempt','import')),
  captured_by UUID, captured_at TIMESTAMPTZ,
  UNIQUE (organization_id, school_id, exam_id, paper_item_id, student_id)
)
```

RLS: school-scoped, same pattern as `edu_question_paper_reviews`. Absent/medical-leave/debarred students follow the frozen exam-result-status design (NULL marks + status codes; excluded from statistics).

**Reconciliation invariant:** `SUM(marks_awarded) per student per exam` must equal `exam_mark_entries.marks_obtained`. Per-question capture **replaces** total-marks entry (the total is derived) — teachers do *less* work than today, not more. This is the adoption hook.

### 5.3 Schema seeded early, populated later

The response tables ship as a migration at the **end of Phase 1** (dormant, zero UI). Rationale: engines can be built any year; **data cannot be backfilled**. Every term that passes without item-level capture is moat permanently lost.

---

## 6. Practical response collection — the Marks-Grid workflow (D2)

### 6.1 Owner constraint

Schools will **not** upload every student's answer sheet. That is expensive, slow, and unrealistic. Teachers evaluate on paper, as they always have.

### 6.2 The workflow

```
1. Paper approved & published
2. Akshara generates a MARKS GRID (printable A4/A3 PDF, per section):
      rows    = students (roster order, Public Student ID + name)
      columns = Q1 … Qn (max marks printed in header; internal-choice
                columns grouped; grid cells sized for handwriting)
      + row totals column, + anchor markers for dewarping
3. Teacher evaluates answer sheets normally, writing per-question marks
   into the grid as they go (replaces their private totals notebook).
4. Capture — either path:
      a. 📷 Photo of the completed grid sheet(s)
      b. ⌨️  Direct grid entry in-app (spreadsheet-style, <20s/student)
5. Extraction pipeline (§7): deterministic grid detection + digit OCR;
   AI assist ONLY on low-confidence cells.
6. Teacher review screen: extracted grid with flagged cells highlighted;
   row totals cross-checked live; teacher corrects/confirms.
7. On confirm: edu_student_item_responses written +
   exam_mark_entries totals derived automatically (one entry flow, not two).
```

### 6.3 Why this is the right trade

| Property | Marks grid | Per-student answer-sheet OCR (rejected) |
|----------|-----------|------------------------------------------|
| Teacher effort | ≈ what they already do | New scanning burden per student |
| Photos per class exam | 1–3 sheets | 30–60 booklets |
| AI cost | Near-zero (digit OCR + rare ambiguity) | High (handwriting, layout) |
| Data captured | Per-question marks, attempted/blank | + chosen options, working |
| Reliability | High (constrained grid, checksum totals) | Low–medium |

### 6.4 What the grid cannot capture — and the complement

The grid yields **marks per question**, not **which option the student chose**. Distractor-level analytics (§10) therefore come only from **digital attempts** (in-app DPP/practice, Phase 2) — MCQ practice auto-grades and captures `chosen_option` + `time_spent_ms` natively at zero teacher cost. The two channels are complementary: formal exams feed marks-level evidence; daily practice feeds option-level evidence.

---

## 7. Ingestion doctrine — OCR-first, AI-second (D3)

Applies to **all** document ingestion: marks grids, question-bank imports, past-paper ingestion, syllabus documents.

```
PDF / Image
  → deterministic pre-processing        (dewarp, denoise, grid/segment detection)
  → OCR                                 (conventional engine; digit models for grids;
                                         no LLM tokens spent here)
  → rule-based extraction               (anchors, regex, layout templates, checksums)
  → validation                          (totals reconcile, marks ≤ max, types/enums,
                                         syllabus boundary, fingerprint dedup)
  → AI ONLY for the ambiguous residue   (single batched call for flagged cells/blocks;
                                         bounded token budget; skippable)
  → teacher confirmation                (always; the human is the last gate)
```

**Token-minimization rules (platform-wide):**
1. Never send an image/document to an LLM that deterministic tooling can parse.
2. AI sees only the *residue* (flagged cells, unparseable blocks), never the whole artifact.
3. Fingerprint-check before any generation call (never regenerate what exists — v2.0 §18 rule preserved).
4. Batch ambiguity resolution into one bounded call per artifact.
5. Every AI call logs `prompt_hash`, model, tokens, cost estimate (v2.0 §18 audit preserved).
6. Tier-1/Tier-2 model routing preserved from v2.0 §16/§18.

**The bank cold-start application (Phase 1):** a school's own past papers (Word/PDF/scans) → this same pipeline → classified, fingerprinted, moderated bank items. Legally clean (schools own their papers), converts every onboarding school's existing assets into original bank content within hours, and directly serves D8 (original content, no publisher dependency).

---

## 8. Canonical Concept Layer (D4)

### 8.1 Principle

Board syllabus trees remain **separate and never auto-mapped for content** (v2.0 §9 stands — AP Science ≠ CBSE Science). But *cognition* is board-independent: Ohm's Law is one idea whether the student sits CBSE, TS Board, or JEE. Mastery must therefore live on a **canonical spine**, or the "one platform, Nursery→12 + competitive" vision fragments into incompatible per-board silos.

```
            BOARD CONTENT TREES (separate, versioned — v2.0 §9)
   CBSE tree      TS tree      AP tree      ICSE tree     JEE profile
      │              │            │             │             │
      └──────────────┴─────┬──────┴─────────────┴─────────────┘
                           ▼   concept_board_mappings
                CANONICAL CONCEPT LAYER  (one node per idea)
                           │   concept_prerequisites (DAG)
                           ▼
        concept performance · mastery state · adaptive selection
```

### 8.2 Data model (Phase 2)

```sql
canonical_concepts (
  id, concept_code UNIQUE,          -- 'phy.electricity.ohms_law'
  title, description,
  subject_domain TEXT,              -- 'physics','mathematics',…
  typical_grade_range int4range,    -- guidance, not restriction
  status 'active'|'merged'|'retired',
  merged_into UUID                  -- concept dedup over time
)

concept_board_mappings (
  canonical_concept_id, board_id,
  syllabus_chapter_id, syllabus_topic_id,     -- where this concept appears
  exam_profile_code,                          -- board | jee_main | neet | …
  alignment 'exact'|'partial'|'extends',      -- JEE Ohm's-Law > Class-10 Ohm's-Law
  curriculum_version_id
)

concept_prerequisites (
  from_concept UUID, to_concept UUID,
  strength NUMERIC,                 -- soft weighting for remediation pathing
  PRIMARY KEY (from_concept, to_concept)      -- DAG, cycle-checked in code
)
```

`edu_question_bank_items.concept_id` (already planned in v2.0 §13.2) now references the **canonical** concept; the item's board context stays on its syllabus FK columns. The v2.0 `edu_concepts` (board-scoped) becomes the mapping layer rather than the spine.

### 8.3 Governance

- Canonical concepts are **platform-curated** (not per-school): small, high-quality, grows deliberately per subject-stage (aligned with v2.0 §21 staging).
- Question families (v2.0 §11.2) attach to canonical concepts — one family serves every board that maps the concept.
- Concept tagging of bank items: rule-based from syllabus mapping first, Tier-1 AI suggestion second, teacher confirmation last (D3 doctrine).

---

## 9. Blueprint Templates as governed data (D5)

### 9.1 From request parameters to versioned templates

Today a blueprint is *computed from* the request (marks/difficulty/type mix). World-class is inverted: the request *conforms to* a governed template.

```sql
edu_blueprint_templates (
  id, organization_id NULL,          -- NULL = platform/board official; else school-custom
  school_id NULL,
  exam_profile_code TEXT,            -- 'cbse_board','ts_board','jee_main',… (v2.0 §12)
  board_id, class_label, subject_name,
  exam_type TEXT,                    -- unit_test … annual | dpp | mock
  version_label TEXT,                -- 'CBSE-X-Science-2026-SQP'
  academic_year_label, effective_from, effective_to,
  status 'draft'|'active'|'archived',        -- board revisions: archive, never overwrite
  structure JSONB                    -- §9.2
)
```

```jsonc
// structure — expressive enough for real board patterns:
{
  "totalMarks": 80, "durationMinutes": 180,
  "generalInstructions": ["…"],
  "sections": [
    { "code": "A", "title": "Objective",
      "questionType": "mcq", "marksPerQuestion": 1, "count": 16,
      "cognitiveQuota": { "remember_understand_max_pct": 60 } },
    { "code": "B", "questionType": "short_answer", "marksPerQuestion": 3, "count": 7,
      "internalChoice": { "pool": 9, "answer": 7 } },          // "any 7 of 9"
    { "code": "C", "questionType": "long_answer", "marksPerQuestion": 5, "count": 6,
      "internalChoice": { "pool": 8, "answer": 6 },
      "cognitiveQuota": { "hots_min_count": 2 } }
  ],
  "chapterWeightage": { "mode": "explicit", "marks": { "Electricity": 12, "…": 8 } },
  "competencyQuota": { "competency_based_min_pct": 50 },       // CBSE mandate
  "difficultyCurve": { "easy": 0.3, "medium": 0.5, "hard": 0.2 }
}
```

### 9.2 Solver consequences (Phase 1)

The deterministic solver evolves from a flat slot list to **slot groups**:
- sections with per-section type/marks rules;
- internal choice = generate `pool` questions for a group scored as `answer × marks`;
- chapter weightage and cognitive quotas as **hard constraints** (solver fails a slot honestly → gap, rather than silently violating the template);
- `cognitive_level` and (Phase 2+) `concept_id` join `matchesSlot`;
- selection pool paginates the full eligible bank (removes the 100-item cap);
- multi-set (A/B/C): same solved blueprint, per-set item shuffling + per-set answer keys.

Determinism, purity, and testability of the solver are **preserved** — templates are inputs, not side effects.

### 9.3 Sources of templates

Official board structures are transcribed by the platform team from board-published specimen/sample papers (structure and weightage are facts, not copyrightable expression — consistent with D8/§12; we transcribe *patterns*, never republish *content*). Schools may clone and customize; custom templates are school-scoped rows.

---

## 10. Evidence-based question quality (D6) + the Trust Pipeline

### 10.1 Item statistics (Phase 2, derived from the response spine)

```sql
edu_item_statistics (
  bank_item_id, item_version,
  scope 'school'|'platform',        -- tenant-local always; platform-aggregate per §16.3
  response_count INT,
  p_value NUMERIC,                  -- empirical difficulty (mean score / max)
  discrimination NUMERIC,           -- point-biserial vs total score
  blank_rate NUMERIC,               -- attempted=false share
  option_distribution JSONB,        -- digital attempts only: per-option pick rates
  avg_time_ms INT,                  -- digital attempts only
  computed_at, window int4range     -- rolling recomputation windows
)
```

Derived signals, surfaced gradually as data grows:
- **Difficulty drift:** teacher label says `easy`, evidence says p=0.31 → flag for re-label (label stays the *prior*, evidence the *posterior*).
- **Broken items:** near-zero or negative discrimination; a distractor nobody picks; a distractor top-scorers pick (mis-keyed answer).
- **Duplicate detection:** fingerprint (exists) → semantic similarity via pgvector (v2.0 §14.3 timing preserved).
- **Exposure tracking:** `edu_item_exposures (bank_item_id, section_id, exam_id, used_at)` + `times_used`/`last_used_at` on bank items → rotation cooldowns (v2.0 §11) become enforceable, and leak forensics become possible.

### 10.2 The Trust Pipeline — quality emerges from evidence, not mass manual review

Owner-locked lifecycle, replacing "AI generates thousands → faculty review thousands":

```
ORIGINAL QUESTION (teacher | school | AI-candidate | family instance)
      ↓  Validation (§11: schema, syllabus, verification layers, moderation)
[validated] ─────────→ eligible ONLY for low-stakes use
      ↓  Limited practice usage (DPPs, practice worksheets — never board-pattern
      ↓  formal papers; exposure-capped; unscored slots allowed in practice sets)
      ↓  Student performance accumulates (response spine)
      ↓  Quality metrics clear thresholds
[trusted] ───────────→ full reusable bank: formal papers, mocks, competitive sets
      ↓  (evidence degrades / complaint / leak)
[retired | quarantined]
```

```sql
-- on edu_question_bank_items:
trust_status TEXT NOT NULL DEFAULT 'validated'
  CHECK (trust_status IN ('draft','validated','probation','trusted','quarantined','retired')),
trust_promoted_at TIMESTAMPTZ, trust_evidence JSONB
```

**Promotion rule (initial, tunable):** `probation → trusted` requires ≥ N responses (e.g. 100), p-value within the band declared for its difficulty label, discrimination above threshold, zero unresolved teacher flags. **Demotion is automatic** when evidence degrades. Teacher/school-authored items enter at `validated` with a lighter bar (they already carry human authority); AI-originated items always walk the full pipeline.

- Existing bank rows migrate as `trusted` (they are teacher-authored and already live).
- The solver gains a `minTrust` constraint per context: formal/board papers draw `trusted` only; DPP/practice may draw `validated+` — this is *how* probation exposure happens without risking formal exams.
- Competitive-exam content (JEE/NEET/Olympiad) **must** reach `trusted` through foundation-cohort practice evidence before appearing in any mock (§15 Phase 3).

### 10.3 Item versioning

Once an item has responses, in-place edits corrupt its evidence. Editing a `probation|trusted` item creates a new `item_version`; statistics pin to the version answered; trust status resets per policy (typo-level edits keep trust; stem/answer changes reset to `validated`).

---

## 11. AI verification layers (D7)

AI-generated questions pass **all** layers before entering even the probation pool:

| Layer | Nature | Cost |
|-------|--------|------|
| 1. Schema & format validation | Deterministic (exists today) | Zero |
| 2. Syllabus boundary | Deterministic (exists today) | Zero |
| 3. Fingerprint + semantic dedup vs bank | Deterministic (+pgvector later) | Zero |
| 4. **Answer verification** | Independent blind solve: second model answers the question without seeing the key; mismatch → reject. Numeric/symbolic items: CAS/solver check (SymPy-class microservice); unit/dimension check for physics | Tier-2, gap-residue only |
| 5. Metadata sanity | Tier-1 classification cross-check (type/Bloom/difficulty consistent with slot) | Tier-1 |
| 6. Confidence score + routing | v2.0 §11.3 pipeline (preserved): low-confidence → mandatory teacher review | — |
| 7. Human moderation | Existing candidate gate (preserved, live-certified) | Teacher time |
| 8. **Evidence** | Trust Pipeline (§10.2) — the final and strongest layer | Zero (organic) |

**Eval harness (platform practice, Phase 2+):** golden sets of teacher-rated questions per subject/grade; every prompt change, model swap, or provider fallback must pass evals before production — the content-quality equivalent of the engineering EOS gate. Provider-agnostic routing (v2.0 §16) is unsafe without this.

---

## 12. Content strategy — original-first (D8; amends v2.0 §10)

### 12.1 The amended source hierarchy

| Priority | Source | Notes |
|----------|--------|-------|
| 1 | **Teacher-created** | Highest trust; enters at `validated` |
| 2 | **School-contributed** | Incl. school's own past papers via cold-start ingestion (§7) |
| 3 | **Original AI-generated** | Full verification + trust pipeline; curriculum-aligned original content, never reproduction |
| 4 | **Curriculum-aligned platform originals** | Platform-authored seed content per stage (v2.0 §21 staging) |
| 5 | Official open sources | Syllabus structure, NCERT-open material, officially published PYQs — *pattern analysis and tagging*, never bulk republishing |
| — | ~~Publisher licensing (v2.0 Category B)~~ | **Demoted: optional, never primary, never a platform dependency.** Schema hooks (`license_id`, `license_status`) remain for the rare opportunistic deal; no roadmap item depends on one. |

### 12.2 What this means architecturally

- The **question-family engine** (v2.0 §11.2, preserved) is promoted in importance: parameterized families over canonical concepts are the *scalable original-content machine* — one verified family yields unlimited solver-checked instances. This, not licensing, is how the bank reaches competitive-exam scale.
- **PYQ store** (v2.0 §13.1) is reframed: officially published questions are stored for *pattern analysis* (topic weightage, difficulty curves, blueprint calibration) and practice-reference where legally clean — the generation engine produces **original** questions matching the *patterns*.
- All v2.0 §25 legal guardrails remain in force verbatim.

---

## 13. ERP-integrated intelligence — the Academic State (D9)

Question Intelligence stops being an island. A per-school, per-class **Academic State** becomes the standing context for every recommendation and generation:

```sql
-- Materialized/refreshed snapshot (pattern: intel_exam_intelligence_snapshots)
edu_academic_state_snapshots (
  organization_id, school_id, class_id, section_id, subject_id,
  academic_year_id, computed_at,
  state JSONB
)
```

```jsonc
// state — assembled from existing ERP modules:
{
  "syllabus":   { "completedChapters": [...], "completedTopics": [...],   // syllabus_topic_completions
                  "pace": { "planned": 14, "actual": 11, "lagDays": 12 } },
  "attendance": { "lowAttendanceStudents": [...],
                  "chaptersTaughtDuringAbsence": { "studentId": ["ch7"] } }, // predicted gaps
  "homework":   { "completionRateByTopic": {...}, "weakTopics": [...] },   // homework module
  "examHistory":{ "lastExams": [...], "weakChapters": [...],              // response spine (Phase 2+)
                  "classAvgTrend": [...] },
  "calendar":   { "currentTerm": "T2", "nextExamWindow": "2026-09-15", "daysUntil": 18 },
  "preferences":{ "teacherDifficultyPrior": {...}, "typeMixPrior": {...} } // §14
}
```

**Consumption examples:**
- Paper generation defaults `chapters` = *completed* chapters for that class (not the whole syllabus) — the request form is pre-filled with reality.
- DPP scheduler (v2.0 §13.1 `edu_dpp_schedules`) auto-proposes from completed topics + weak-topic weighting.
- Teaching-pace lag → recommends consolidation worksheets before the exam window.
- Post-exam: weak chapters → remediation homework via the existing homework-intelligence bridge → parent communication summary through the existing (deterministic, catalog-based) parent-comms localization channel.
- Read-only, RLS-scoped, snapshot-based — Question Intelligence never writes into other modules' domains; it *reads* state and *produces* education artifacts.

---

## 14. Adaptive AI per school (D10)

**Definition:** adaptation = deterministic personalization of *inputs* to the (unchanged, deterministic) generation pipeline, plus learned priors. Two schools, same board, different progress → different papers. This is mostly **not** an LLM feature.

| Adaptation dimension | Source | Mechanism |
|---------------------|--------|-----------|
| Curriculum & board version | school's board tree + curriculum version | scopes bank + boundary (exists) |
| Completed syllabus | Academic State §13 | chapter set + per-chapter weighting |
| Academic calendar | term/exam windows | exam-type + blueprint template selection |
| Teacher preferences | **learned from edits**: every swap/edit/rejection during paper review is a signal (e.g. teacher consistently replaces 1-mark MCQs with fill-blanks) | preference priors on type mix / difficulty curve, applied as soft solver weights |
| Difficulty preference | school policy + historical approved-paper difficulty profile | difficulty-curve prior |
| Historical performance | response spine | weak-concept weighting in blueprints; remediation sets |
| Workflow shape | school's review chain usage | defaults for submit/review routing |

**Hard guardrails (non-negotiable):** adaptation may *never* override the syllabus boundary, blueprint-template compliance, the trust-status floor for the context, or the approval gate. Adaptive inputs are logged onto the paper's blueprint JSON so every generated paper remains fully auditable ("why did this paper look like this?").

Phase 3 extends adaptation to the **student** level (mastery-aware practice, spaced repetition over the concept DAG) — same principle: personalization of deterministic selection, evidence-driven.

---

## 15. Phased roadmap (D11)

> Sequencing note: this program starts **after** the current module-completion → red-team → pilot track. Exception: the Phase-2 schema seed (§5.3) lands with Phase 1 because data cannot be backfilled.

### Phase 1 — Complete the existing Question Intelligence platform

*Goal: the certified foundation becomes a finished, board-compliant, daily-usable product. No new intelligence.*

| # | Work | Notes |
|---|------|-------|
| 1.1 | Flutter completion (Batch 8c scope): moderation queue, syllabus chapter/topic picker, submit/review/approve UI, gaps banner | already-planned work |
| 1.2 | Approved-AI-candidate **merge to bank** | closes the compounding leak |
| 1.3 | Solver upgrade: constraint-based slot groups, chapter coverage + Bloom as hard constraints, mixed-difficulty fix, full-bank pagination (remove 100-item cap) | §9.2 |
| 1.4 | **Blueprint templates v1** (§9): sections, internal choice, chapter weightage, competency quotas; CBSE + one state board seeded | D5 |
| 1.5 | Multi-set papers (A/B/C) + per-set answer keys | |
| 1.6 | PDF v2: sections, instructions block, school branding, answer-key separation; (diagrams/LaTeX per v2.0 Phase 2 when scheduled) | |
| 1.7 | `edu_exam_paper_links` — paper ↔ exam event | prerequisite for the spine |
| 1.8 | **Bank cold-start ingestion** (§7): school past papers → OCR-first pipeline → moderated bank | D3 + D8 flagship |
| 1.9 | Usage/exposure columns + rotation cooldown | §10.1 |
| 1.10 | **Schema seed:** response-spine + trust-status migrations (dormant) | §5.3 |

### Phase 2 — Structured response collection + concept intelligence

*Goal: the platform starts measuring.*

| # | Work |
|---|------|
| 2.1 | **Marks-Grid workflow** end-to-end (§6): grid PDF → photo/manual capture → OCR-first extraction → teacher confirm → response spine + derived totals |
| 2.2 | Item statistics engine (§10.1): p-value, discrimination, blank-rate; difficulty-drift + broken-item flags surfaced to teachers |
| 2.3 | **Canonical Concept Layer** (§8): spine + board mappings + prerequisite DAG for the active content stages; concept tagging (rule-first, AI-suggest, teacher-confirm) |
| 2.4 | Concept/chapter performance analytics — real attribution replacing the current class-label proxy; feeds Academic State |
| 2.5 | **Trust Pipeline v1** (§10.2): trust states, promotion/demotion job, solver `minTrust` floors |
| 2.6 | Digital DPP/practice attempts in-app (auto-graded objective; captures options + timing; offline-first via existing read-cache platform) |
| 2.7 | **Academic State v1** (§13): snapshot + syllabus-completion-aware generation defaults + DPP auto-proposals |
| 2.8 | AI verification layers 4–6 (§11): blind-solve answer verification, CAS check for numeric items, eval harness v1 |
| 2.9 | Item versioning (§10.3) |

### Phase 3 — Adaptive assessment, mastery, competitive exams, advanced analytics

*Goal: the intelligence pays off.*

| # | Work |
|---|------|
| 3.1 | Mastery tracking: per-student canonical-concept mastery (BKT-class model first), decay/spaced-practice scheduling over the prerequisite DAG |
| 3.2 | Adaptive generation (§14 full): learned teacher priors, weakness-weighted blueprints, student-level adaptive practice sets |
| 3.3 | Competitive exam profiles (v2.0 §12 Exam Knowledge Engine): JEE/NEET question types as first-class types, multi-subject mock composition, negative marking / evaluation rules |
| 3.4 | Competitive content at scale via **families + trust pipeline** (§10.2, §12.2) — foundation cohorts generate the evidence that promotes questions into mock-grade trust |
| 3.5 | Mock test series: cross-set equating, percentile/normalization engine, (cross-school rank simulation, consent-gated) |
| 3.6 | Pre-flight paper simulation: predicted score distribution vs class mastery before approval |
| 3.7 | Distractor intelligence: misconception-derived distractors from option-level evidence |
| 3.8 | pgvector semantic layer (v2.0 §14.3): semantic dedup, teacher search, scoped retrieval |
| 3.9 | Platform-aggregate item statistics (anonymized, cross-tenant — §16.3) |

### Explicitly deferred / not pursued

| Item | Status |
|------|--------|
| Per-student answer-sheet OCR / OMR capture | **Not pursued** (owner, 2026-07-02) — Marks Grid instead; revisit only if option-level evidence from formal exams becomes a proven need |
| Publisher bulk licensing as strategy | **Not pursued as dependency** (D8) — opportunistic only |
| Computerized Adaptive Testing (live CAT) | Phase 3+, after mastery model matures |
| Nursery–Grade 5 assessment model (observation/portfolio kinds) | **Open owner decision** (§17) — architecture reserves `assessment_kind` |
| Multilingual question content (Telugu/Hindi medium) | **Open owner decision** (§17) — intersects the frozen English-first product decision |

---

## 16. Cross-cutting notes

### 16.1 Where the existing v2.0 architecture stands unchanged
Knowledge Repository hierarchy (§8), board architecture & language-inside-board (§9), question families (§11.2), confidence pipeline (§11.3), Exam Knowledge Engine profiles (§12), storage philosophy & pgvector timing (§14), diagram/LaTeX strategy (§15), Content Generation Engine provider abstraction (§16), performance/cost strategy (§17–18), contribution model (§19), legal guardrails (§25). Consult the archived v2.0 for those sections; this document does not duplicate them.

### 16.2 Governance & RBAC additions (when phases build)
`captureExamResponses` (marks-grid entry/confirm), `viewItemAnalytics`, `manageBlueprintTemplates` (school-custom), `manageCanonicalConcepts` (platform-only), `moderateTrustPipeline` (platform/principal per policy). Same permission-catalog pattern as the certified education permissions.

### 16.3 The response corpus as a network asset
Item statistics are two-tier: **tenant-local always** (a school's own evidence, RLS-scoped) and **platform-aggregate** (anonymized, response-count-thresholded, no student identifiers — statistical parameters only). Every school using an item improves its calibration for every school. Consent/anonymization policy = open owner decision (§17) before any cross-tenant aggregation ships.

### 16.4 Early-years reservation
The response spine reserves `assessment_kind ('paper'|'observation'|'portfolio')` on future assessment records so Nursery–Grade 5 competency/observation assessment (NEP/PARAKH-style) can join the same governance and mastery spine without re-architecture.

---

## 17. Open owner decisions (explicitly NOT decided here)

| # | Question | Context |
|---|----------|---------|
| O-A | Multilingual **question content** (Telugu/Hindi medium papers) | Distinct axis from the frozen English-first *app* decision (parent-comms-only localization). Board trees already model language-inside-board; question-level translation groups + Indic PDF rendering are a real workstream needing an explicit go/no-go. |
| O-B | Nursery–Grade 5 assessment model | Observational/portfolio assessment kinds — different instrument, same platform. When (if) to design. |
| O-C | Cross-school aggregate statistics consent model | Opt-in vs default-on-anonymized; needed before §16.3 Phase 3 work. |
| O-D | Trust-pipeline thresholds | N-responses / p-value bands / discrimination floors — set with real pilot data in Phase 2. |

---

## 18. Success criteria (evolution of v2.0 §27)

| Phase | KPI | Target |
|-------|-----|--------|
| 1 | Published papers conforming to a governed blueprint template | 100% |
| 1 | School past-paper ingestion: upload → moderated bank items | < 1 day, ≥ 80% auto-extracted |
| 2 | Formal exams with per-question responses captured | ≥ 70% of exams in pilot schools |
| 2 | Teacher time for marks entry (grid vs legacy totals) | ≤ legacy (must not increase) |
| 2 | AI tokens per ingested artifact | ≥ 90% artifacts resolved with zero LLM tokens |
| 2 | Questions with ≥ 30 responses acquiring evidence-based difficulty | growing monthly |
| 3 | AI-originated questions reaching `trusted` via evidence (not manual mass-review) | the pipeline works |
| 3 | Papers adapted to school academic state (vs generic board default) | 100% of generated papers |

---

**Document status:** Locked owner vision v3.0 (2026-07-02). Evolves — does not replace — the v2.0 master plan and the live-certified production foundation. Phase work is scheduled through the standard roadmap process; nothing in this document authorizes immediate implementation.
