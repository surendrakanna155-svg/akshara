# Akshara — Question Paper & IIT/JEE Foundation Master Plan

**Document ID:** `AKS-QP-FOUNDATION-PLAN-v1.0`  
**Created:** June 2026  
**Purpose:** Save-for-future reference — complete idea, inventory (have vs need), and phased implementation plan for real-world question papers, DPP, and foundation (Class 6 → Inter) in Akshara ERP.  
**Related docs:** `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` · `docs/QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md` · `docs/Vision/design/AI-Question-Paper-System.md`

---

## Table of Contents

1. [Executive summary](#1-executive-summary)
2. [Vision — what we are building](#2-vision--what-we-are-building)
3. [How real publishers work (reference model)](#3-how-real-publishers-work-reference-model)
4. [Content sources — where papers come from](#4-content-sources--where-papers-come-from)
5. [What Akshara HAS today (verified inventory)](#5-what-akshara-has-today-verified-inventory)
6. [What Akshara DOES NOT HAVE (gaps)](#6-what-akshara-does-not-have-gaps)
7. [Target architecture](#7-target-architecture)
8. [Data model extensions needed](#8-data-model-extensions-needed)
9. [Diagram & math rendering strategy](#9-diagram--math-rendering-strategy)
10. [AI strategy (bank-first)](#10-ai-strategy-bank-first)
11. [Phased implementation plan](#11-phased-implementation-plan)
12. [Pilot recommendation (first real deployment)](#12-pilot-recommendation-first-real-deployment)
13. [Roles, permissions & workflow](#13-roles-permissions--workflow)
14. [Student & parent delivery](#14-student--parent-delivery)
15. [Legal & copyright guardrails](#15-legal--copyright-guardrails)
16. [Effort & timeline estimates](#16-effort--timeline-estimates)
17. [Success criteria & KPIs](#17-success-criteria--kpis)
18. [Risk register](#18-risk-register)
19. [Telugu summary (10 lines)](#19-telugu-summary-10-lines)

---

## 1. Executive summary

**Can we implement complete real-world question papers in Akshara?**  
**Yes.** The platform scaffold (database, API, UI shell, PDF export, syllabus module, exam approval lifecycle) already exists. What is missing is **real question content**, **diagram assets**, **foundation/JEE program layer**, **deterministic blueprint engine**, and **unified exam ↔ paper ↔ marks loop**.

**Key insight:** Publishers (Career Point Kota, Disha, MTG) do not magically download 20 years of papers. They combine NCERT-aligned syllabus, faculty-authored questions, PYQ *pattern analysis*, graduated difficulty, and pre-rendered diagram assets. Akshara should replicate this **pipeline digitally**, not scrape copyrighted PDFs.

**Recommended sequence:**
1. Bank-first real questions (teacher + import + licensed PYQ tagging)
2. Deterministic paper/DPP blueprint engine
3. Diagram + LaTeX rendering
4. Foundation program tracks (JEE/NEET/NTSE)
5. Constrained AI gap-fill only (teacher approval required)

**Fastest credible path:** Pilot **Class 9 Mathematics · JEE Foundation · Monthly test** with ~80 real bank questions before scaling to all classes.

---

## 2. Vision — what we are building

### 2.1 Product goal

A **school-trusted Question Intelligence Platform** inside Akshara that supports:

| Track | Classes | Paper types |
|-------|---------|-------------|
| Board (CBSE / State / ICSE) | 6–12 | Weekly, unit, monthly, quarterly, half-yearly, annual |
| JEE Foundation | 6–10 | DPP (daily), weekly drills, monthly consolidation |
| JEE Main / Advanced prep | 11–12 (Inter) | DPP, chapter tests, full mocks |
| NTSE / Olympiad foundation | 8–10 | Pattern-based practice sets |

### 2.2 Three-layer content model

```
LAYER 1 — PROGRAM
  Board track  +  Foundation track (JEE | NEET | NTSE | Olympiad)

LAYER 2 — ACADEMIC CALENDAR
  Month → Syllabus chapters completed → Topics → Learning outcomes

LAYER 3 — ASSESSMENT TYPES
  DPP (daily) → Weekly → Monthly → Unit → Quarterly → Half-yearly → Annual → Full mock
```

### 2.3 Non-negotiable quality rules

1. **Teacher control first** — AI never auto-publishes final papers.
2. **Syllabus boundary** — every question references typed syllabus IDs, not free text.
3. **Diagrams are assets** — never inline plain text; fixed layout boxes for print.
4. **Provenance** — every question records source (teacher / import / PYQ / AI candidate).
5. **Closed loop** — marks → weak chapters → next blueprint adapts.

### 2.4 Differentiator vs generic generators (e.g. theprashna.com)

Akshara owns the full chain: **syllabus completion + question bank + paper engine + exam marks + analytics**. Competitors generate papers; Akshara should **learn** which topics/classes struggle and adapt the next DPP/monthly paper.

---

## 3. How real publishers work (reference model)

Understanding Kota-style publishers (Career Point, Disha, Origin Educare, MTG):

| Step | What they do |
|------|----------------|
| 1 | Map NCERT chapter order to competitive exam patterns |
| 2 | Faculty SMEs write original questions (not copy-paste PYQs) |
| 3 | Analyze PYQs for *patterns* — topic weightage, question types, difficulty curve |
| 4 | Build DPP sheets: 15–30 Q per chapter, time limit, marks, cutoff |
| 5 | Progress difficulty: Class 6–8 basics → 9–10 foundation → 11–12 JEE pattern |
| 6 | Render diagrams in LaTeX/TikZ, Inkscape, or CAD → export SVG/PNG |
| 7 | Senior faculty reviews every sheet before print |

**DPP structure (typical):**
- 20–30 MCQ/numerical per sheet (chapter-wise)
- Time limit + max marks + qualifying score
- Mix: subjective, single/multiple correct, integer, comprehension, matrix match
- Answer key + detailed solutions (separate PDF)

Akshara digital equivalent: **same workflow, stored in DB, delivered via app + print PDF**.

---

## 4. Content sources — where papers come from

### 4.1 Legitimate sources

| Source | Coverage | How to use in Akshara |
|--------|----------|------------------------|
| [JEE Advanced official archive](https://jeeadv.ac.in/archive.html) | 2007–2025 + AAT | PYQ store — tag by chapter/topic; pattern analysis |
| [NTA JEE Main documents](https://jeemain.nta.nic.in/documents/) | Recent sessions + answer keys | PYQ for 11–12; verify against official keys |
| NCERT textbooks | Class 6–12 | Open — base theory, examples, exercises |
| NTSE / Olympiad (HBCSE patterns) | Class 8–10 | Foundation competitive style templates |
| **School faculty** | All classes | Primary bank — best quality, zero copyright risk |
| Spreadsheet import | Bulk entry | School converts internal question sets to CSV |
| **Publisher license** | Disha, CP Kota, MTG | Structured bulk import — requires legal agreement |

### 4.2 What NOT to do

- Do **not** scrape or republish copyrighted DPP books without license.
- Do **not** expect a single “20-year JEE Main download” — NTA archive is fragmented pre-2020.
- Do **not** auto-publish AI-generated JEE questions without teacher review.
- Do **not** store diagrams as unformatted text inside `question_text`.

### 4.3 Content volume targets (realistic)

| Scope | Minimum bank size per subject |
|-------|--------------------------------|
| One pilot (Class 9 Math JEE Foundation) | 80–120 questions |
| One class, all subjects (PCM) | 500–800 questions |
| Full school 6–12 foundation | 5,000–15,000 questions |
| Kota-scale coaching library | 50,000+ (multi-year faculty program or publisher license) |

---

## 5. What Akshara HAS today (verified inventory)

### 5.1 Database (Supabase) — ✅ REAL

**Migration:** `supabase/migrations/20260620000000_education_suite_foundation.sql`

| Table | Purpose | Status |
|-------|---------|--------|
| `edu_question_bank_items` | Question catalog | ✅ Schema + RLS |
| `edu_question_papers` | Paper header (class, subject, exam type, blueprint, answer key) | ✅ Schema + RLS |
| `edu_question_paper_items` | Paper line items (bank ref or AI source) | ✅ Schema + RLS |
| `edu_homework_assignments` | Homework / worksheet jobs | ✅ Schema |
| `edu_report_card_remarks` | AI remark generation | ✅ Schema |

**Question bank fields today:** `subject_name`, `chapter`, `topic`, `difficulty`, `question_type`, `marks`, `question_text`, `answer_text`, `options`, `status`.

**Question types supported:** `mcq`, `fill_blank`, `match`, `short_answer`, `long_answer`, `diagram`.

**Exam types supported:** `unit_test`, `weekly_test`, `monthly_test`, `quarterly`, `half_yearly`, `annual`.

**Paper statuses:** `draft`, `published`, `archived` only — no review/approval sub-states.

### 5.2 Backend API (Supabase Edge) — ✅ REAL (logic partially stubbed)

| File | Purpose |
|------|---------|
| `supabase/functions/_shared/education/education_router.ts` | Route handlers |
| `supabase/functions/_shared/education/education_handlers.ts` | HTTP handlers |
| `supabase/functions/_shared/education/education_repository.ts` | DB CRUD |
| `supabase/functions/_shared/education/education_question_paper_service.ts` | Paper generation orchestration |
| `supabase/functions/_shared/education/education_generator.ts` | Question templates + blueprint builder |
| `supabase/functions/_shared/education/education_generator_test.ts` | Generator unit tests |

**Generation behavior today:**
- Picks matching bank items by subject/chapter/difficulty
- Fills remaining marks with **stub AI questions** (template strings like “Explain {topic} in 3–4 sentences”)
- Builds blueprint JSON (type distribution, marks by type)
- **Not** a real constraint solver; **not** real LLM

### 5.3 Flutter client — ✅ REAL (admin UI shell)

| File | Purpose |
|------|---------|
| `lib/features/education/education_models.dart` | Domain models + enums |
| `lib/features/education/education_screen.dart` | 4-tab UI: Papers, Bank, Homework, Remarks |
| `lib/features/education/education_provider.dart` | Riverpod providers |
| `lib/features/education/education_pdf_service.dart` | A4 PDF print (text only) |
| `lib/router/education_navigation.dart` | Route to Education Suite |
| `lib/core/repositories/interfaces/education_repository.dart` | Repository interface |
| `lib/core/repositories/api/education/` | API + hybrid + mapper |
| `lib/core/repositories/mock/mock_education_repository.dart` | Mock for offline dev |

**Repository methods available:**
- `listQuestionBank`, `createQuestionBankItem`
- `listQuestionPapers`, `generateQuestionPaper`, `getQuestionPaper`, `publishQuestionPaper`, `exportQuestionPaper`
- `generateHomework`, `publishHomework`, `exportHomework`
- `generateReportRemark`, `publishReportRemark`

### 5.4 Syllabus & school completion — ✅ REAL (not wired to questions)

| File / area | Purpose |
|-------------|---------|
| `lib/features/school_completion/school_completion_models.dart` | `SubjectTemplate`, `SyllabusChapter`, topics |
| `lib/features/school_completion/subjects_screen.dart` | Subject catalog UI |
| `lib/features/school_completion/syllabus_automation_screen.dart` | Syllabus wizard |
| `supabase/functions/_shared/school_completion/syllabus_automation_service.ts` | Syllabus generation backend |

**Exists:** Board → class → subject → chapter → topic taxonomy.  
**Missing:** Link from question bank to syllabus **IDs** (still free-text chapter strings).

### 5.5 Exam administration — ✅ REAL (separate from question papers)

| File | Purpose |
|------|---------|
| `lib/core/exams/exam_administration_store.dart` | Exam lifecycle: draft → scheduled → marks entry → processed → published |
| `lib/core/exams/exam_grading.dart` | Grade bands |
| `lib/features/teacher/exams/teacher_exams_screen.dart` | Teacher marks entry UI |
| `lib/features/academics/exam_admin/` | ERP exam admin screens |

**Good pattern to reuse:** Principal approval gate before publish (proven for marks).  
**Gap:** Question papers and exam sessions are **not linked** — marks and questions live in separate worlds.

### 5.6 AI infrastructure — ✅ ARCHITECTURE REAL, ❌ INFERENCE STUBBED

| File | Purpose |
|------|---------|
| `lib/core/ai/` | `AiInferencePipeline` — cache, RBAC, telemetry, provider selection |

**Today:** All providers simulated. Education paper flow **bypasses** the AI pipeline entirely.  
**Design docs:** Bank-first AI policy documented in `ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md`.

### 5.7 PDF export — ✅ BASIC

`lib/features/education/education_pdf_service.dart`:
- Prints title, total marks, numbered questions, options, answer key
- **No** diagrams, LaTeX math, school branding, section headers, or instructions block

### 5.8 Tests — ✅ PARTIAL

| Test file | Coverage |
|-----------|----------|
| `test/core/repositories/education/education_repository_test.dart` | Repository contract |
| `test/features/education/education_screens_test.dart` | UI smoke |
| `supabase/functions/_shared/education/education_generator_test.ts` | Generator unit tests |

### 5.9 Roadmap placement

`docs/Vision/ImplementationRoadmap.md`:
- v8.5 Question Paper Generator (P2)
- v8.6 Question Bank (P2)
- v8.7 Homework / Worksheet Generator (P2)

`docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` — **DEFERRED** (design complete, not built).

---

## 6. What Akshara DOES NOT HAVE (gaps)

### 6.1 Content & intelligence gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| Real question content in bank | Papers feel fake | P0 |
| PYQ (previous year question) store | No JEE pattern analysis | P1 |
| Foundation program dimension (JEE/NEET/NTSE) | Cannot plan Class 6–10 foundation track | P1 |
| DPP blueprint (daily 10–20 Q, not full paper) | No Kota-style daily practice | P1 |
| JEE question types (integer, matrix match, assertion-reason, comprehension) | Cannot match real exam format | P1 |
| Learning outcomes / Bloom taxonomy | Weak syllabus alignment | P2 |
| Question provenance (`source`, `source_reference`) | No audit trail | P1 |
| Question fingerprint / deduplication | Same Q repeats across papers | P2 |
| Item analytics (p-value, discrimination) | No adaptive blueprints | P2 |

### 6.2 Technical gaps

| Gap | Impact | Priority |
|-----|--------|----------|
| Syllabus ID linkage (questions use free text) | Syllabus boundary not enforced | P0 |
| Deterministic blueprint solver | Random/stub selection | P0 |
| Diagram asset storage + rendering | JEE Physics/Chem unusable | P0 |
| LaTeX math rendering | Math papers unreadable | P0 |
| Paper review / approval workflow | No governance (unlike marks) | P0 |
| Paper ↔ exam session link | Marks disconnected from questions | P1 |
| Multi-set papers (Set A/B/C) + shuffled keys | Real exam practice incomplete | P2 |
| Student practice delivery screen | Students cannot attempt DPP in app | P1 |
| Monthly auto-plan from syllabus completion | Manual planning only | P2 |
| Real LLM behind `AiInferencePipeline` | AI assist not production-ready | P3 |
| OCR import pipeline | Slow bulk ingestion | P3 |
| Publisher license import format | No partnership channel | P3 |

### 6.3 Stubbed behavior to replace

**Client mock** (`mock_education_repository.dart`): hardcoded bank items + fake AI strings.  
**Server generator** (`education_generator.ts`): template questions like “Multiple choice: Mathematics — Algebra (medium)”.  
**Server picker** (`education_question_paper_service.ts`): greedy marks fill — no type/difficulty/portions constraints.

---

## 7. Target architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        CONTENT SOURCES                                   │
│  NCERT + Syllabus Templates │ Official PYQs │ Teacher Bank │ Licensed   │
│  Publisher Content        │ OCR Import (review) │ AI Candidates (queue) │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   SYLLABUS BOUNDARY (school_completion)                │
│  Program: Board + Foundation (JEE|NEET|NTSE|Olympiad)                   │
│  Board → Class → Subject → Chapter → Topic → Learning Outcome (IDs)     │
│  Topic completion tracking (monthly portion)                             │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      QUESTION BANK + ASSETS                              │
│  edu_question_bank_items + edu_question_assets (SVG/PNG/LaTeX/graph)    │
│  PYQ store │ provenance │ Bloom │ difficulty │ JEE type tags            │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    BLUEPRINT ENGINE (deterministic)                      │
│  Inputs: exam_type | program | chapters completed | difficulty mix      │
│  Outputs: DPP slot plan | monthly paper | full mock blueprint           │
│  Constraints: marks, types, chapters, dedup, HOTS minimum               │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              CONSTRAINED AI (gap-fill only, optional)                    │
│  AiInferencePipeline │ syllabus scope token │ JSON schema │ low temp    │
│  → moderation queue (never auto-publish)                                 │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│           MODERATION & APPROVAL (reuse exam_admin pattern)              │
│  Teacher draft → Coordinator review → Principal approve → publish        │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         DELIVERY                                         │
│  PDF print (branded) │ Student app DPP │ Teacher assign │ Parent view   │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              EXAM → MARKS → ANALYTICS → NEXT BLUEPRINT                   │
│  exam_administration_store │ item analysis │ weak chapter intelligence  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Data model extensions needed

### 8.1 New tables (proposed)

```sql
-- Foundation / competitive program track
edu_program_tracks (
  id, school_id, program_code,  -- 'jee_foundation', 'neet_foundation', 'ntse', 'board_only'
  grade_labels[], status
)

-- Diagram / math assets (separate from question text)
edu_question_assets (
  id, school_id, asset_type,  -- 'svg', 'png', 'latex_block', 'graph_spec_json'
  storage_path, width_px, height_px,
  alt_text, created_by
)

-- Link questions to assets
edu_question_bank_item_assets (
  bank_item_id, asset_id, placement,  -- 'above', 'below', 'inline_left', 'options_right'
  sort_order
)

-- Previous year questions (tagged, not necessarily in active bank)
edu_pyq_items (
  id, exam_code,  -- 'jee_main', 'jee_advanced', 'ntse'
  year, session, shift,
  subject, chapter_id, topic_id,
  question_type, marks, difficulty,
  question_text, options, answer_text,
  source_url, license_status
)

-- Paper review workflow (governance)
edu_question_paper_reviews (
  id, paper_id, round_number, status,  -- 'submitted', 'changes_requested', 'approved'
  reviewer_user_id, comments, created_at
)

-- DPP schedule (daily plan)
edu_dpp_schedules (
  id, school_id, class_name, subject_id, program_track_id,
  scheduled_date, blueprint_template_id, paper_id (nullable until generated),
  chapters_covered[]
)

-- Link published paper to exam session
edu_exam_paper_links (
  exam_session_id, paper_id, set_code  -- 'A', 'B', 'C'
)
```

### 8.2 Extensions to existing tables

**`edu_question_bank_items` — add columns:**
- `syllabus_chapter_id UUID` (FK, replaces free-text chapter)
- `syllabus_topic_id UUID` (FK)
- `program_track TEXT` — `board`, `jee_foundation`, `neet_foundation`, `ntse`
- `jee_question_type TEXT` — `numerical`, `integer`, `matrix_match`, `assertion_reason`, `comprehension`
- `cognitive_level TEXT` — `remember`, `understand`, `apply`, `analyze`, `hots`
- `source TEXT` — `teacher`, `school`, `import`, `pyq`, `publisher`, `ai_candidate`
- `source_reference TEXT`
- `learning_outcome TEXT`
- `fingerprint TEXT` — hash for dedup

**`edu_question_papers` — add columns:**
- `program_track TEXT`
- `review_status TEXT` — `draft`, `submitted`, `approved`, `published`, `archived`
- `approved_by UUID`, `approved_at TIMESTAMPTZ`
- `pdf_storage_path TEXT`

### 8.3 Flutter model extensions

Extend `lib/features/education/education_models.dart`:
- `QuestionAsset` class
- `FoundationProgram` enum
- `JeeQuestionType` enum
- `PaperReviewStatus` enum
- Link `GenerateQuestionPaperRequest.chapters` → `List<String> syllabusChapterIds`

---

## 9. Diagram & math rendering strategy

### 9.1 Problem

JEE/foundation papers without aligned diagrams are **unusable**. Storing “draw a circuit diagram” as plain text fails in app and print.

### 9.2 Asset types

| Type | Storage | Flutter render | PDF render |
|------|---------|----------------|------------|
| Math equations | LaTeX string in DB | `flutter_math_fork` | Pre-render or LaTeX→PDF widget |
| Static figures (triangle, ray, circuit) | SVG in R2 | `flutter_svg` | Embed SVG/PNG in `pdf` package |
| Graphs / coordinate geometry | JSON spec (points, axes, curves) | `CustomPainter` or JSXGraph webview | Pre-render to PNG at fixed DPI |
| Complex diagrams | PNG @2x + SVG fallback | `Image` with `width`/`height` | Fixed aspect ratio box |

### 9.3 Layout rules (critical)

Every question with a diagram stores:
```json
{
  "placement": "above_question",
  "width": 280,
  "height": 200,
  "align": "center"
}
```

PDF and app **must use the same pixel box** — never auto-flow diagram inline with text.

### 9.4 AI policy for diagrams

| Action | Allowed |
|--------|---------|
| AI suggests graph spec JSON | Yes → teacher approves |
| AI generates circuit diagram PNG | No auto-publish |
| Teacher uploads SVG/PNG | Yes — primary path |
| Template-based parameterized graphs (e.g. parabola with random `a`) | Yes — validate programmatically |

### 9.5 Implementation packages (Flutter)

- `flutter_math_fork` or `flutter_tex` — LaTeX
- `flutter_svg` — SVG assets
- `pdf` + `printing` — already in use; extend for images

---

## 10. AI strategy (bank-first)

### 10.1 Policy (from ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md)

1. **Bank-first** — select from approved bank + PYQ store first.
2. **AI only for gaps** — when blueprint cannot be satisfied from bank.
3. **AI output = candidates** — moderation queue; never `published` directly.
4. **Syllabus-scoped** — pass chapter/topic IDs only; no whole-book context.
5. **Structured JSON output** — strict schema; low temperature (0.1–0.3).
6. **Wire through `AiInferencePipeline`** — RBAC + audit + provenance.

### 10.2 Safe AI use cases

| Use case | Risk | Mitigation |
|----------|------|------------|
| Tag PYQs by chapter/difficulty | Low | Human spot-check 10% sample |
| Generate numeric variations of approved Q | Low | Symbolic math validation (SymPy backend) |
| Fill blueprint gaps (MCQ/short) | Medium | Teacher review required |
| OCR scanned pages → structured draft | Medium | Teacher verifies; copyright check |
| Full DPP auto-generation | High | Do not ship without review |
| Physics circuit diagram generation | High | Teacher upload only |

### 10.3 What AI cannot replace

- 50,000-question licensed publisher libraries
- Faculty judgment on “exam-like” difficulty
- Principal sign-off on published papers
- Legally safe bulk content without license or original authorship

---

## 11. Phased implementation plan

### Phase 0 — Prerequisites (1–2 weeks)

**Goal:** Unblock data quality before feature work.

| Task | Owner | Deliverable |
|------|-------|-------------|
| Confirm education migration applied on staging | DevOps | Tables live |
| Wire `EducationRepository` to API (not mock) in pilot school | Agent A/B | Hybrid repo default |
| Document one real subject syllabus in `school_completion` | Academic team | Class 9 Math chapters |

**Exit criteria:** API CRUD for bank items works end-to-end on staging.

---

### Phase 1 — Real bank + real papers (4–6 weeks) — P0

**Goal:** Teacher can build and print a **real** monthly paper from real questions.

| # | Task | Files / area |
|---|------|--------------|
| 1.1 | Add `syllabus_chapter_id`, `syllabus_topic_id`, `source` to bank schema | New migration |
| 1.2 | Syllabus chapter picker in bank create UI (not free text) | `education_screen.dart` |
| 1.3 | Spreadsheet CSV import with validation | New import service + UI |
| 1.4 | Deterministic blueprint solver (marks, type mix, difficulty buckets, chapter portions) | Replace `education_generator.ts` picker |
| 1.5 | Paper review workflow: submit → approve → publish | New table + UI; pattern from `exam_administration_store` |
| 1.6 | Improved PDF: instructions, sections, school branding | `education_pdf_service.dart` + branding from `school_completion` |
| 1.7 | Link paper to exam session (optional MVP: manual link) | `edu_exam_paper_links` |
| 1.8 | Tests: blueprint solver, import validation, approval gate | `test/` |

**Exit criteria:** Class 9 Math monthly paper with 100% bank-sourced questions, principal-approved PDF.

---

### Phase 2 — Diagrams + LaTeX (3–4 weeks) — P0

| # | Task |
|---|------|
| 2.1 | `edu_question_assets` table + R2 upload |
| 2.2 | Asset upload UI on question create/edit |
| 2.3 | LaTeX field + renderer in question preview |
| 2.4 | PDF embed diagrams with fixed layout boxes |
| 2.5 | 10-question diagram pilot QA (print + mobile) |

**Exit criteria:** Physics/Math questions with diagrams render identically in app preview and printed PDF.

---

### Phase 3 — Foundation track + DPP (4–6 weeks) — P1

| # | Task |
|---|------|
| 3.1 | `edu_program_tracks` + UI to assign class to JEE foundation |
| 3.2 | DPP blueprint templates (10 / 15 / 20 Q per day) |
| 3.3 | `edu_dpp_schedules` — calendar view per class/subject |
| 3.4 | Auto-suggest DPP chapters from `syllabus_topic_completions` |
| 3.5 | JEE question types in schema + UI |
| 3.6 | Student practice screen (new or extend `S-11 PracticePapers-M`) |

**Exit criteria:** Class 9 JEE Foundation gets auto-scheduled weekly DPP from completed chapters.

---

### Phase 4 — PYQ + intelligence loop (4–6 weeks) — P1

| # | Task |
|---|------|
| 4.1 | Import JEE Advanced archive (2007+) into `edu_pyq_items` |
| 4.2 | PYQ tagging UI (chapter/topic/difficulty) |
| 4.3 | Blueprint can pull from PYQ store (with license flag) |
| 4.4 | Unify marks: paper items ↔ `exam_mark_entries` |
| 4.5 | Item analytics: % correct per question → weak chapter report |
| 4.6 | Next paper blueprint suggests more weak-topic questions |

**Exit criteria:** After monthly test, teacher sees “Class 9-A weak in Quadratic Equations” and generates next DPP weighted to that topic.

---

### Phase 5 — AI assist (4–6 weeks) — P2/P3

| # | Task |
|---|------|
| 5.1 | Real LLM provider behind `AiInferencePipeline` |
| 5.2 | Gap-fill endpoint: only missing blueprint slots |
| 5.3 | AI candidate moderation queue UI |
| 5.4 | Numeric variation generator with answer validation |
| 5.5 | OCR import assist (optional) |

**Exit criteria:** When bank is 80% sufficient, AI fills 20% as candidates; teacher approves before bank merge.

---

### Phase 6 — Scale content + publisher partnerships (ongoing)

| # | Task |
|---|------|
| 6.1 | License negotiation with Disha / CP Kota / MTG |
| 6.2 | Bulk import pipeline for publisher format |
| 6.3 | Class 6–12 full subject expansion (faculty content program) |
| 6.4 | Multi-set mocks (Set A/B/C) for Inter JEE |

---

## 12. Pilot recommendation (first real deployment)

### 12.1 Pilot scope

| Parameter | Value |
|-----------|-------|
| Class | 9 |
| Subject | Mathematics |
| Program | JEE Foundation |
| Paper type | Monthly test (50 marks) |
| DPP | 15 questions/day, Mon–Fri |
| Duration | 4-week pilot with one section (9-A) |

### 12.2 Pilot content pack

| Content | Count | Source |
|---------|-------|--------|
| Bank MCQ | 40 | Faculty-authored |
| Bank numerical | 20 | Faculty-authored |
| Bank short answer | 15 | Faculty-authored |
| PYQ-tagged (pattern reference) | 15 | JEE Advanced (official) |
| Questions with diagrams | 10 | Faculty SVG upload |

### 12.3 Pilot workflow

1. Academic head sets Class 9 Math syllabus in `school_completion`.
2. Teachers enter/import 80+ questions with chapter tags.
3. System generates monthly paper from blueprint.
4. Coordinator reviews portion alignment.
5. Principal approves → PDF published.
6. DPP auto-scheduled Mon–Fri from completed chapters.
7. Students attempt DPP in app (or print).
8. Teacher enters marks in exam admin.
9. Report shows weak topics for next month.

### 12.4 Pilot success metrics

- 0 stub/placeholder questions in published papers
- 100% questions linked to syllabus chapter IDs
- Diagram QA pass: 10/10 print correctly
- Teacher time to create monthly paper < 30 minutes (after bank populated)
- Student DPP completion rate > 60%

---

## 13. Roles, permissions & workflow

### 13.1 Recommended workflow

```
Subject Teacher
  → creates paper draft from bank (or requests DPP generation)
Exam Coordinator
  → reviews portion alignment, type distribution, marks total
Principal / Academic Head
  → approves → system generates print PDF → publish to class
```

### 13.2 Permissions to add

| Permission | Action |
|------------|--------|
| `manageQuestionBank` | CRUD bank items + assets |
| `importQuestionBank` | Bulk CSV/OCR import |
| `generateQuestionPaper` | Run blueprint engine |
| `submitQuestionPaper` | Send for review |
| `reviewQuestionPaper` | Coordinator review |
| `approveQuestionPaper` | Principal approve |
| `publishQuestionPaper` | Release to students |
| `manageDppSchedule` | Calendar planning |
| `viewPyqStore` | Read PYQ archive |

**Today:** only `viewEducation` / `manageEducation` (coarse).

### 13.3 Reuse exam approval pattern

Copy governance from `exam_administration_store.dart`:
- Status machine with rejection comments
- Audit log on approve/publish
- Principal-only final publish

---

## 14. Student & parent delivery

### 14.1 Mobile screens (from MobileScreenInventory)

| Screen ID | Purpose | Status |
|-----------|---------|--------|
| S-11 PracticePapers-M | Student DPP / practice | 📋 Spec only — not built |
| S-12 ExamResults-M | Results after publish | ✅ Partial |
| P-12 ReportCards-M | Parent academic view | ✅ Partial |

### 14.2 Delivery modes

| Mode | Use case |
|------|----------|
| In-app attempt | DPP daily — MCQ + numerical input |
| PDF print | Monthly/unit tests — school exam hall |
| PDF download | Homework / holiday package |
| Teacher assign | Push DPP to class section via homework flow |

### 14.3 Phase 3 deliverable

New `StudentPracticeScreen`:
- List today's DPP
- Timer (optional)
- Submit answers (MCQ auto-grade; numerical manual/scaffold)
- Show solution after submit (if school policy allows)

---

## 15. Legal & copyright guardrails

| Rule | Implementation |
|------|----------------|
| No scrape copyrighted publisher PDFs | Product policy + import audit |
| PYQ from official sources only | `source_url` + `license_status` on `edu_pyq_items` |
| AI-generated content = school-owned draft | Provenance `source=ai_candidate` |
| Teacher attestation on publish | "I confirm originality / licensed use" checkbox |
| Student data not in AI prompts | Class-level context only; anonymize |

---

## 16. Effort & timeline estimates

### 16.1 Engineering

| Phase | Duration | Team |
|-------|----------|------|
| Phase 0 — Prerequisites | 1–2 weeks | 1 backend + 1 Flutter |
| Phase 1 — Real bank + papers | 4–6 weeks | 1 backend + 1 Flutter + 1 QA |
| Phase 2 — Diagrams + LaTeX | 3–4 weeks | 1 Flutter + 1 backend |
| Phase 3 — Foundation + DPP | 4–6 weeks | 2 Flutter + 1 backend |
| Phase 4 — PYQ + analytics | 4–6 weeks | 1 backend + 1 data |
| Phase 5 — AI assist | 4–6 weeks | 1 AI/backend |
| **Total to production pilot** | **~3–4 months** | |

### 16.2 Content (parallel track — academic team)

| Scope | Duration |
|-------|----------|
| Pilot bank (1 subject, Class 9) | 2–4 weeks faculty |
| One class all PCM subjects | 2–3 months |
| Full school 6–12 foundation | 12–18 months |
| Publisher-licensed bulk | 1–3 months after legal agreement |

**Software can be pilot-ready in ~3 months. Full content library is a 1–2 year academic program.**

---

## 17. Success criteria & KPIs

### 17.1 Platform KPIs

| KPI | Target (pilot) |
|-----|----------------|
| Stub questions in published papers | 0% |
| Questions with syllabus ID linkage | 100% |
| Papers passing principal approval | 100% |
| Diagram print QA pass rate | > 95% |
| Paper generation time (after bank ready) | < 5 minutes |
| Student DPP weekly completion | > 60% |

### 17.2 Business KPIs

| KPI | Target |
|-----|--------|
| Coaching schools adopting foundation track | 3 pilots in 6 months |
| Teacher NPS on paper tool | > 7/10 |
| Reduction in manual paper prep time | > 50% |

---

## 18. Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Insufficient real questions in bank | High | High | Pilot content sprint; faculty incentives |
| Diagram misalignment in PDF | Medium | High | Fixed layout boxes; print QA checklist |
| Copyright violation from import | Medium | High | Provenance + license flags; legal review |
| AI hallucination in JEE questions | Medium | High | Bank-first; AI candidates only; no auto-publish |
| Teacher adoption resistance | Medium | Medium | Start with one subject; training; DPP time savings |
| Exam ↔ paper disconnect persists | Medium | Medium | Phase 1.7 link table; Phase 4 unification |
| Scope creep (all classes at once) | High | High | Enforce pilot-first policy |

---

## 19. Telugu summary (10 lines)

1. **Akshara లో complete real question papers implement చేయడం 100% possible** — database, API, PDF, syllabus ఇప్పటికే ఉన్నాయి.
2. **కానీ ఇప్పుడు questions fake/stub** — real JEE/foundation content fill చేయాలి.
3. **Publishers secret database లేదు** — NCERT syllabus + faculty questions + PYQ pattern analysis వాడతారు.
4. **Diagrams plain text లో కాదు** — SVG/PNG images + LaTeX math గా store చేయాలి.
5. **Class 6 నుంచి Inter వరకు** — DPP, weekly, monthly, unit, annual papers syllabus completion కి link అవ్వాలి.
6. **Workflow:** Teacher draft → Coordinator review → Principal approve → publish (marks approval లాగే).
7. **AI సహాయం మాత్రమే** — auto-publish చేయకూడదు; teacher review తప్పనిసరి.
8. **Phase 1 (4–6 weeks):** real bank + import + blueprint engine + approval.
9. **Pilot:** Class 9 Maths JEE Foundation — 80 real questions తో monthly paper + DPP.
10. **Software ~3 నెలల్లో pilot ready;** full 6–12 content library 1–2 years — faculty లేదా publisher license తో.

---

## Appendix A — Key file reference

| Area | Path |
|------|------|
| DB migration | `supabase/migrations/20260620000000_education_suite_foundation.sql` |
| Paper generator (server) | `supabase/functions/_shared/education/education_question_paper_service.ts` |
| Stub generator | `supabase/functions/_shared/education/education_generator.ts` |
| Flutter models | `lib/features/education/education_models.dart` |
| Flutter UI | `lib/features/education/education_screen.dart` |
| PDF service | `lib/features/education/education_pdf_service.dart` |
| Repository interface | `lib/core/repositories/interfaces/education_repository.dart` |
| Syllabus models | `lib/features/school_completion/school_completion_models.dart` |
| Exam lifecycle | `lib/core/exams/exam_administration_store.dart` |
| Design doc (deferred) | `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` |
| Platform audit | `docs/QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md` |
| Roadmap | `docs/Vision/ImplementationRoadmap.md` (v8.5–v8.8) |

---

## Appendix B — Class-wise assessment ladder (reference)

| Class | Program focus | DPP size | Monthly paper | Mock |
|-------|---------------|----------|---------------|------|
| 6–7 | NCERT + logic | 5–10 Q/day | 20–30 marks | — |
| 8 | NTSE foundation | 10–15 Q/day | 40 marks | NTSE pattern quarterly |
| 9–10 | JEE/NEET foundation | 15–20 Q/day | 50–80 marks | Half-yearly foundation mock |
| 11 | JEE Main pattern | 20–25 Q/day | 100 marks | Monthly chapter tests |
| 12 (Inter) | JEE Main + Advanced | 25–30 Q/day | Full syllabus tests | Full 3-hour mocks |

---

## Appendix C — JEE question type catalog (to implement)

| Type | JEE Main | JEE Advanced | Foundation (9–10) |
|------|----------|--------------|-------------------|
| Single correct MCQ | ✅ | ✅ | ✅ |
| Multiple correct MCQ | ✅ | ✅ | Optional |
| Numerical / Integer | ✅ | ✅ | Simplified numerical |
| Matrix match | ✅ | ✅ | — |
| Assertion–Reason | — | ✅ | — |
| Comprehension (passage) | ✅ | ✅ | Short passage |
| Integer type | ✅ | ✅ | — |
| Diagram-based | ✅ | ✅ | ✅ (asset required) |

---

**Document status:** Planning reference — ready for Phase 0 kickoff when prioritized on roadmap.  
**Next action when approved:** Create `docs/Releases/vX.X-Question-Paper-Foundation.md` + Phase 1 migration spec for `syllabus_chapter_id` linkage.
