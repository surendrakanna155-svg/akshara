# Akshara Academic Assessment Platform Design

> **Status:** ⏸ **DEFERRED** (June 2026) — Design only. Explicitly excluded from Red Team remediation scope.  
> **SSOT for deferral:** `docs/DOCUMENTATION_SYNC_REPORT.md` · `docs/Vision/FutureVision.md` §O  
> **Distinct from:** Evolution AI suite (FV-23–27) for practice/homework content.
>
> ⚠️ **FOLDED INTO v3.0 (2026-07-02):** the forward vision now lives in
> `docs/Vision/design/Assessment-Intelligence-Platform.md` (locked owner decisions).
> The bank-first workflow, governance, and AI policy designed here shipped in Batches 8b/8c
> and are live-certified; the remaining ideas (lifecycle integration, copilot insights) are
> sequenced in v3.0's Phase 2/3 roadmap. Do not plan from this file.

This document designs a **school-trusted** assessment platform for weekly tests, unit tests, monthly tests, quarterly exams, half-yearly exams, and annual exams. It is designed to be **bank-first** (teacher-controlled) with **optional, gated AI** (no uncontrolled AI generation).

## 0) Guiding principles

1. **Teacher control first**: AI never directly publishes final question papers or results.
2. **Curriculum + portion alignment**: every paper is traceable to curriculum structure (chapter/topic/learning outcomes).
3. **Quality gates**: draft → teacher review → coordinator/principal approval → publish/print.
4. **Provenance everywhere**: question sources (teacher/manual/import/AI) and versions must be auditable.
5. **Bank-first generation**: question papers are generated from the question bank first; AI is an add-on only when coverage is insufficient.
6. **Deterministic constraints**: blueprint math and selection constraints are rule-based; AI is used only for content suggestions.

---

## 1) Architecture overview

### 1.1 Major domains (modules)

1. **Curriculum & Syllabus Domain**
   - Curriculum templates (CBSE / State Board / ICSE / Custom)
   - School syllabus (chapters + topics)
   - Chapter/topic completion tracking
2. **Question Bank Domain**
   - Question catalog (metadata + content)
   - Question sources (teacher, school, import, publisher-derived entry, optional AI)
3. **Assessment Domain (Paper Engine)**
   - Exam definitions (weekly/unit/monthly/quarterly/half-yearly/annual)
   - Paper blueprint (marks + difficulty + type distribution)
   - Paper generation draft from question bank
   - Teacher/coordinator review workflow
4. **Exam Lifecycle Domain**
   - Exam schedule (when exams happen)
   - Marks entry
   - Result processing
   - Report card publishing
5. **AI Orchestration Domain (Optional)**
   - AI “additional questions” generation in a strict review queue
   - Copy-safe structured generation (no free-form)
   - Token/cost controls and provenance tracking
6. **Insights Domain**
   - Exam analytics (weak chapters, class performance, forecasting)
   - Copilot surfaces for teacher/principal/parent (suggestions only)

### 1.2 Data layer (existing foundation already fits bank-first)

Akshara already contains an Education Suite foundation for question bank and papers:

- `edu_question_bank_items`: question metadata + content (subject/chapter/topic/difficulty/question_type/marks/options/text/answer/status).
- `edu_question_papers`: paper header (class/section/subject/chapters/difficulty/total_marks/exam_type/title/status/blueprint/answer_key).
- `edu_question_paper_items`: paper items (bank reference + generated content provenance).

Curriculum/syllabus is represented using:

- `subject_templates` (board/subject_code/subject_name/grade_label/chapters JSON template)
- `syllabus_chapters` (school-specific chapter list for an academic year)
- `syllabus_topics` (school-specific topics under a subject/chapter with ordering)
- `syllabus_generations` (manual/template/clone/wizard generation tracking)
- `syllabus_topic_completions` (completion tracking by teacher)

Exam marks and report artifacts exist as:

- `exam_mark_entries` (student marks recorded per exam context in pilot tables)
- `edu_report_card_remarks` (teacher/principal/subject teacher remark generation & publish status)
- `parent_academic_summaries` (structured parent summary JSON fields for academic view)

Exam intelligence exists as:

- `intel_exam_intelligence_snapshots` (snapshots: analytics, weak chapters, result intelligence, forecasting, etc.)

This design leverages these foundations and adds **missing workflow/status tables** where needed (paper review queue, approvals, exam-paper linking, PDF artifacts, provenance logs for AI add-ons).

### 1.3 Services (how the system “thinks”)

At runtime, the platform behaves as a set of deterministic services:

1. **Blueprint Service**
   - Given (class, subject, exam_type, chapters, difficulty mix) → compute a blueprint:
     - total marks
     - per-chapter marks allocation (“portion aligned”)
     - question type distribution
     - difficulty bucket counts
     - learning outcome targets (if available)
2. **Bank Selection Service**
   - Selects question bank items to satisfy blueprint constraints:
     - chapter/topic coverage constraints
     - difficulty mix constraints
     - marks totals
     - type distribution
     - deduplication constraints
3. **Paper Draft Builder**
   - Creates `edu_question_papers` (status remains within the existing enum: `draft/published/archived`)
   - and creates a separate review workflow (recommended) via a `edu_question_paper_reviews` / `approval_events` table or a dedicated `review_state` column.
4. **Review/Approval Orchestrator**
   - Controls who can edit, submit, request changes, and approve.
5. **AI Additional Questions Service (optional)**
   - Only called when coverage gaps exist.
   - Produces *candidates* for teacher review with provenance and structured fields.
6. **Render & Publish Service**
   - Generates printable PDF for approved papers.
   - Stores PDF assets in R2 (Cloudflare) with versioning.
7. **Marks → Results → Report Card Service**
   - Converts paper items + marks entries into grades, remarks, and final report card snapshots.

---

## 2) Recommended ownership & workflow (paper creation)

### 2.1 Evaluate the requested options

**Option A: Subject Teacher → creates papers**
- Pros: content expertise; fast.
- Cons: no standardized oversight; quality variance across teachers.

**Option B: Class Teacher → creates papers**
- Pros: holistic view across subjects/portion.
- Cons: weaker subject depth for technical correctness and exam-format alignment.

**Option C: Exam Coordinator → creates papers**
- Pros: standardization.
- Cons: coordinator becomes bottleneck and depends on teachers for content.

**Option D: Subject Teacher creates → Principal/Coordinator approves (Recommended)**
- Pros: real-world practice in schools; strong subject correctness + governance.
- Cons: needs a review step, but that’s the point of trust.

### 2.2 Final recommended workflow (best real-world model)

1. **Subject Teacher** creates a **paper draft** from question bank:
   - chooses class/subject/exam_type/chapters
   - chooses difficulty mix
   - triggers bank-first paper draft generation
2. **Exam Coordinator (or Principal/Academic Head)** reviews the draft for:
   - portion alignment (chapter marks distribution)
   - exam format consistency (type distribution, marks totals)
   - school policy (e.g., minimum HOTS presence)
3. **Principal/Academic Head approves**:
   - paper status becomes *approved/published*
4. **System generates the print-ready PDF** from the approved blueprint + school branding.

In small schools, Coordinator + Principal can be the same role.

---

## 3) Curriculum structure design

### 3.1 Target curriculum model (matches the requested hierarchy)

Curriculum → Subject → Chapters → Topics → Learning Outcomes

In Akshara’s current data model, this maps to:

- **Subject templates** (`subject_templates`): board + subject + grade + chapter structure JSON.
- **Chapters** (`syllabus_chapters`): school-specific chapters per academic year.
- **Topics** (`syllabus_topics`): school-specific ordered topics under each subject/class.
- **Learning outcomes**: to fully meet the “learning outcomes” requirement, add:
  - either `learning_outcomes` JSONB at `syllabus_topics` level, or
  - a separate `syllabus_learning_outcomes` table keyed to `topic_id`.

### 3.2 Where does syllabus data come from?

Real schools typically have one of these realities:

1. **Publisher templates**: printed books or PDF syllabi (no structured API)
2. **School-managed syllabus spreadsheets**: Excel/Google Sheets
3. **Legacy documentation**: scanned documents / images
4. **Teacher-generated internal mapping**: chapters/topics created by teachers over time

### 3.3 Should schools upload syllabus, import syllabus, use templates, or mix?

Recommendation: **Mix (templates + import + teacher edits)**.

Proposed approach:

1. **Template-first onboarding (fastest)**
   - Use prebuilt templates for:
     - CBSE
     - ICSE
     - selected State Boards
2. **Import for school-specific deviations**
   - Schools upload/import their “portion/sequence” corrections.
   - These updates update `syllabus_chapters` and `syllabus_topics`.
3. **Teacher corrections**
   - Teachers refine chapter/topic order and learning outcomes mapping (manual UI).
4. **Publisher fallback**
   - If a school has only printed material, they can OCR/import content and then teacher verifies.

Use `syllabus_generations` to track whether data came from `wizard/template/clone/manual`.

---

## 4) Question bank strategy

### 4.1 Question metadata (requested fields)

Question metadata:
- Class (or grade)
- Subject
- Chapter
- Topic
- Difficulty
- Marks
- Question type
- Learning outcome

Existing `edu_question_bank_items` covers most fields:
- `subject_name`
- `chapter`, `topic`
- `difficulty` (easy/medium/hard)
- `question_type`
- `marks`

Required additions to fully satisfy your “learning outcome” requirement:
- Add `learning_outcome` (string) and/or `learning_outcome_tags` (array).

### 4.2 Map requested question types to real implementation types

Requested question types:
- MCQ
- One mark
- Two mark
- Short answer
- Long answer
- HOTS
- Case study

Practical mapping strategy:

1. Use `marks` + `question_type` together:
   - MCQ → `question_type=mcq`
   - One mark / Two mark → `question_type=short_answer` or a dedicated `question_type=one_mark/two_mark`
   - Short answer / Long answer → `question_type=short_answer/long_answer`
2. Represent HOTS and case studies as **difficulty + semantic tags**:
   - Add `cognitive_level` (e.g., `lows`, `hots`)
   - Add `question_variant_tags` (e.g., `case_study`, `application`, `scenario`)

This avoids exploding `question_type` enums while still enabling strict selection.

### 4.3 How questions enter the bank (sources)

Allowed sources:
1. **Teacher-created** (best quality)
   - Teacher writes question + correct answer + options (if applicable)
2. **School-created**
   - Academic admin creates “school standard” questions/patterns
3. **Imported**
   - Spreadsheet import with validation (marks/type/chapter/topic)
4. **AI-generated** (only as *candidates*)
   - Added into a teacher review queue (separate from the active bank)
5. **Publisher-derived (manual entry)**
   - Because publisher books often have no structured API, import is content extraction + teacher normalization:
     - teachers create a question bank item record referencing the publisher chapter/topic

Provenance policy:
- Every question bank item must store:
  - `source` (teacher/school/import/publisher_manual/ai_generated)
  - `source_reference` (e.g., spreadsheet row id, OCR batch id, “Publisher Book X, Chapter Y”)

Note: the current `edu_question_bank_items` schema already has `status` (active/archived) but does not yet define `source`/`source_reference`. This design treats them as required **schema additions** (or an equivalent provenance table) for auditable AI + import workflows.

---

## 5) Publisher content reality (no structured API)

Publisher reality: most schools receive **printed books** or scanned PDFs.

Therefore, ingestion must be designed as a staged pipeline:

### 5.1 Recommended practical workflow

1. **Bulk spreadsheet import (recommended first)**
   - School converts publisher questions into a spreadsheet (even a semi-structured one).
   - System validates:
     - chapter/topic match
     - marks and question_type
     - missing answer options
2. **OCR-assisted import (for scanned pages)**
   - School uploads scans.
   - OCR + parser extracts question text/options/marks.
   - AI is used only to help structuring extraction output.
   - Teacher review is mandatory before publishing to active bank.
3. **Manual entry for edge cases**
   - Diagrams, graph-based problems, “case study” scenarios often require manual normalization.

### 5.2 What “recommendation” means here

For sustainability:
- Start with **spreadsheet import + teacher review**
- Add **OCR assisted import** only once teachers trust the tooling.

---

## 6) Question paper generation design (bank-first, not AI-first)

### 6.1 Teacher selection inputs

Teacher selects:
- Class
- Subject
- Exam type
- Chapters (subset of syllabus)
- Difficulty mix (example: Easy 30%, Medium 50%, Hard 20%)

### 6.2 Blueprint generation (deterministic)

Blueprint generation rules:

1. **Exam type → paper totals**
   - Example:
     - weekly_test: smaller total marks
     - annual: larger total marks with balanced distribution
2. **Chapters → marks portion alignment**
   - Default strategy:
     - proportional to number of topics in each chapter
   - Teacher override:
     - adjust per-chapter marks.
3. **Marks → question counts**
   - Determine number of questions per type:
     - MCQ count
     - short answer count
     - long answer count
     - HOTS/case study distribution (e.g., at least 1 HOTS set for quarterly/half-yearly)
4. **Difficulty mix → bucket constraints**
   - For each type bucket, define counts for easy/medium/hard.

### 6.3 Question selection from bank (coverage + no duplicates)

Given a blueprint, the system selects from `edu_question_bank_items`:

Selection constraints:
1. **Chapter coverage**:
   - For each selected chapter, pick at least a minimum marks count.
2. **Difficulty balancing**:
   - For the total marks in each difficulty bucket, pick matching difficulty questions.
3. **Type balancing**:
   - MCQ vs short vs long vs HOTS/case study must meet requested distribution.
4. **Duplicate prevention**:
   - No repeated `bank_item_id` within the same paper.
   - Optional stronger rule (recommended):
     - “question fingerprint” hash computed from normalized question + options + answer.
     - Prevent the same fingerprint from appearing in repeated papers in a configured period.

### 6.4 Paper statuses and review gates

Keep publishing status simple:
- `draft` (work-in-progress)
- `published` (print-ready PDF created)
- `archived` (end of lifecycle)

All governance steps (teacher submit, coordinator request changes, principal approval, AI candidate acceptance) should live in a separate review workflow:
- `edu_question_paper_reviews` (per review round with timestamps + comments)
- `edu_question_paper_approvals` (who approved which version)

### 6.5 Storage of blueprint + answer keys

Store in:
- `edu_question_papers.blueprint` (JSONB)
- `edu_question_papers.answer_key` (JSONB)

Paper items store:
- reference to bank item (when chosen from the bank)
- `source` (bank vs ai_generated) for provenance

---

## 7) AI usage strategy (optional, gated, bank-first)

### 7.1 AI activation model (the exact policy)

Teachers click:
**“Generate Additional Questions”**

AI is used only when:
- For selected chapters, the bank does not satisfy blueprint constraints
  - e.g., not enough HOTS questions
  - difficulty bucket shortfall
  - insufficient marks total for a specific question type

If bank coverage is sufficient, the system never calls AI.

### 7.2 AI output type (restricted)

AI may generate:
- MCQs
- HOTS questions (scenario/application)
- Variations/rephrasings of existing teacher-approved patterns

AI must be constrained to **selected chapters only**.

### 7.3 Teacher review is mandatory

AI output must enter a **teacher review queue**:
1. A “question candidate” state in a separate review queue (recommended), so teacher approval does not pollute the active question bank.
2. Or directly insert paper candidate items with `edu_question_paper_items.source=ai_generated`, while the paper stays in `draft` until teacher acceptance and coordinator/principal approval gates unlock `published`.

### 7.4 Token cost controls (practical controls)

Cost controls should be implemented as product constraints:

1. **Chapter-scoped context only**
   - Don’t send entire syllabus; send only:
     - selected chapters
     - relevant topic learning outcomes
     - a small set of retrieved similar questions
2. **Request only missing slots**
   - AI generates exactly the count of questions the bank is missing.
3. **Structured output**
   - Use strict JSON schemas (prevents verbose free-form text).
4. **Temperature control**
   - Low temperature for consistency (e.g., 0.1–0.3).
5. **Prompt caching + batch (where possible)**
   - Cache stable syllabus/chapter descriptors.
   - For bulk import/large generation, use asynchronous batch jobs.

### 7.5 “Uncontrolled AI generation” prevention checklist

Hard requirements:
- AI can’t publish papers.
- AI can’t modify approved/published papers without new approval.
- AI can’t generate outside selected chapters.
- AI results must have provenance + teacher approval.

---

## 8) Permissions design (roles + actions)

### 8.1 Existing permission posture in Akshara

Akshara currently has:
- `viewEducation`
- `manageEducation`

Those cover the broad “education content” area, but a trusted assessment platform needs **more fine-grained actions**.

### 8.2 Define required actions for a trusted platform

Recommended new permission catalog (proposed):

Curriculum & Syllabus
- `manageSyllabus` (already exists in platform)
- `viewAcademicProgress` (already exists)
- `manageAcademicProgress` (already exists)

Question Bank
- `viewQuestionBank`
- `manageQuestionBank` (create/edit/archive)
- `approveQuestionBankItems` (optional; if AI candidates require approval)

Question Papers / Exams
- `createQuestionPaperDraft`
- `editQuestionPaperDraft`
- `requestPaperChanges` (coordinator)
- `approveQuestionPaper`
- `publishQuestionPaper` (create printable PDF)
- `printQuestionPaper` (if separate)

Marks & Results
- `enterExamMarks`
- `processResults`
- `publishResults`

Report Cards
- `viewReportCards` (principal/admin)
- `downloadReportCardPDF`

Insights
- `viewExamIntelligence` (already exists)

### 8.3 Role mapping to required permissions

| Role | Create draft | Review edits | Approve | Publish PDF | Enter marks | View report cards |
|------|--------------|--------------|----------|--------------|-------------|--------------------|
| Subject Teacher | ✅ | ✅ | ❌ (optional: teacher approval only for bank items) | ❌ | ✅ (assigned) | 👁 only if allowed |
| Class Teacher | ✅ (if allowed) | ✅ | ❌ | ❌ | ✅ (optional) | limited |
| Exam Coordinator | ✅ (or acts as editor) | ✅ | ✅ (recommended) | ✅ (recommended) | ⚠️ usually not | 👁 |
| Principal / Academic Head | ❌/✅ draft | ✅ review | ✅ | ✅ | ❌/✅ (school policy) | 👁 |

### 8.4 Recommended “who creates papers” final statement

Best real-world workflow:
- **Subject Teacher creates paper draft**
- **Exam Coordinator/Principal approves**
- **Principal/Coordinator publishes (print PDF)**

This prevents accidental “teacher draft = final paper” while keeping day-to-day responsibility with the subject experts.

---

## 9) Storage design (database + document storage)

### 9.1 Database (structured)

Data model storage (Postgres via Supabase):

- Curriculum:
  - `subject_templates`, `syllabus_chapters`, `syllabus_topics`, `syllabus_generations`, `syllabus_topic_completions`
- Question bank:
  - `edu_question_bank_items`
- Paper generation:
  - `edu_question_papers` (paper header + blueprint + status)
  - `edu_question_paper_items` (paper lines + bank/AI provenance)
- Exam lifecycle:
  - create/extend:
    - a linking table between “exam schedule” and “paper”
    - marks processing outputs (grades, attendance integration, etc.)
- Report artifacts:
  - `edu_report_card_remarks`
  - `parent_academic_summaries`
  - add a new published report card table for PDFs & snapshots (recommended)

### 9.2 Document storage (PDF + scans)

Use Cloudflare R2 (signed URL upload/download).

Proposed R2 path prefix:
- `{school_id}/assessment/papers/{academic_year_id}/{paper_id}/paper_{paper_id}.pdf`
- `{school_id}/assessment/papers/{academic_year_id}/{paper_id}/answer_key_{paper_id}.pdf` (if separate)
- `{school_id}/assessment/imports/{batch_id}/original_scan_*.jpg|pdf`
- `{school_id}/assessment/templates/{school_id}/logo/...` (if not already stored by branding)

### 9.3 Future scaling notes

Scaling strategies:
1. **Indexing**
   - Always index on `(organization_id, school_id, subject_name, chapter)` for bank queries.
   - Index paper lookups by `(organization_id, school_id, academic_year_label, class_name, subject_name, exam_type)`.
2. **Academic year partitioning**
   - All “paper/publish” operations must be scoped to `academic_year_id` to reduce query size.
3. **Versioning**
   - Keep a new record for each approval/publish cycle instead of overwriting content.

---

## 10) Exam lifecycle end-to-end workflow (no missing steps)

Below is the complete lifecycle from curriculum through copilot insights.

### 10.1 Lifecycle state machine (high level)

```text
Curriculum
  → Syllabus
    → Chapter completion (teacher tracking)
      → Question Bank (questions sourced + reviewed)
        → Exam Blueprint (marks/type/difficulty/portion aligned)
          → Question Paper (draft from bank)
            → Teacher review
              → Coordinator/Principal approval
                → Publish (print-ready PDF + branding)
                  → Conduct exam
                    → Marks entry
                      → Result processing
                        → Report card build (marks/grades/attendance/remarks/branding)
                          → Parent view + Student view
                            → Copilot insights (explain trends + interventions)
```

### 10.2 Ownership by stage

1. Curriculum/Syllabus
   - Principal/Academic admin sets templates and school syllabus.
   - Teachers track completions.
2. Chapter completion
   - Teachers mark topic completion (feeds portion alignment).
3. Question bank
   - Teachers add/revise questions.
   - Coordinators approve bank items if governance requires.
4. Exam blueprint
   - Subject teacher (or coordinator) selects:
     - chapters + difficulty mix
   - System computes portion aligned blueprint using syllabus/topic info.
5. Paper draft generation
   - System generates paper from question bank only.
6. Review
   - Subject teacher reviews and requests edits for consistency.
7. Approval
   - Coordinator/Principal approves.
8. Print & conduct
   - System publishes PDF; school conducts exam.
9. Marks entry
   - Teacher enters marks per student for that exam/paper.
10. Results processing
   - System computes grades + pass/fail + subject scores.
11. Report cards
   - Principal/Academic admin triggers report card generation/publishing.
   - Remarks can be AI-assisted but must be reviewable.
12. Parent/student views
   - Parents see structured summary; students see their results.
13. Copilot insights
   - Uses stored exam intelligence snapshots to guide interventions.

---

## 11) Report card integration design

### 11.1 Report card content (requested)

Report card fields:
- Marks
- Grades
- Attendance %
- Teacher remarks
- AI insights (optional) with editability
- School branding (header colors/logo)

### 11.2 Parent vs student visibility

Parent visibility:
- exam results overview
- subject-wise breakdown
- teacher remarks and AI insights (explain trends)
- PDF download (if policy allows)

Student visibility:
- personal subject-wise marks/grades
- teacher remarks (personal)
- PDF (optional)

### 11.3 PDF export

Use a print-ready template engine:
1. Assemble a render payload from:
   - final grades
   - attendance %
   - remarks (principal + teacher)
   - school branding assets
2. Render to PDF and store in R2 with versioning:
   - `{school_id}/reports/{academic_year}/{student_id}/{term}/{report_card_id}.pdf`

### 11.4 Use existing structures

Leverage:
- `edu_report_card_remarks` for remark generation + approval state
- `parent_academic_summaries` for parent-facing structured summaries

Recommended new table for robust publishing:
- `edu_report_cards` (one record per published student report card, including PDF URL, grade template version, and computed snapshot JSON).

---

## 12) Copilot integration design (role-specific)

### 12.1 Teacher Copilot

Teacher Copilot suggestions:
- identify weak topics from:
  - recent exam performance
  - chapter/topic mastery signals
- propose revision plans (chapter-wise plan)
- suggest additional question variations (optional, but teacher-reviewed)

Policy:
- Copilot outputs are “suggestions” only.
- If a teacher accepts suggested question variations, they enter the question bank review queue.

### 12.2 Principal Copilot

Principal Copilot suggestions:
- compare results across exam types (weekly vs quarterly vs half-yearly)
- identify weak classes and subjects
- recommend intervention:
  - re-teach topics
  - schedule remedial worksheets

Implementation reuse:
- Use `intel_exam_intelligence_snapshots` and derived aggregations.

### 12.3 Parent Copilot

Parent Copilot explanations:
- “performance trends” over time
- “what to focus on next”

Policy:
- must reference exam dates and subject names
- no direct grade changes

---

## 13) Cost analysis & token cost model

### 13.1 OpenAI token pricing basis (for estimates)

For planning, assume OpenAI `gpt-4o-mini` style pricing:
- Input: ~$0.15 per 1M tokens
- Output: ~$0.60 per 1M tokens
- Cached input: ~$0.075 per 1M tokens
- Batch API: discounted input/output (used for async jobs)

(Exact pricing should be re-verified at implementation time.)

### 13.2 Define “AI actions” in this product

Only a small number of AI calls exist:
1. **Generate Additional Questions** (AI add-on)
2. (Optional later) OCR structuring for imports (could use AI heavily but only during import batches)
3. (Optional later) remark wording (AI can assist but must be reviewable)

### 13.3 Scenario models

Let:
- `N_papers` = number of papers per school per month
- `Q_ai` = number of AI-generated questions per paper
- `T_in` = average input tokens per AI call (context + selected chapters + retrieved similar questions + constraints)
- `T_out` = average output tokens per paper for AI-generated questions

AI cost per paper (rough):

`cost ≈ (T_in/1M)*0.15 + (T_out/1M)*0.60`

#### Scenario 1: Question bank only
- AI calls: 0 (after bank ingestion)
- AI cost: near zero
- Cost drivers:
  - OCR/import costs (if used)
  - teacher time and review UI

#### Scenario 2: Hybrid bank + AI add-on
- AI calls happen only when bank coverage is missing.
- Example policy:
  - AI generates only 10–20% of questions on average.

Rough example (illustrative):
- `Q_ai = 6` additional questions per paper
- One AI call generates a batch of these.
- Estimated token usage:
  - `T_in ≈ 6,000` tokens
  - `T_out ≈ 12,000` tokens
- Cost per paper ≈
  - input: 6,000/1,000,000 * $0.15 ≈ $0.0009
  - output: 12,000/1,000,000 * $0.60 ≈ $0.0072
  - total ≈ **$0.008/paper**

If a school generates 300 papers/month:
- AI cost ≈ 300 * $0.008 ≈ **$2.40/month**

This is why bank-first is sustainable: AI touches only gaps.

#### Scenario 3: AI-first generation
- AI generates full papers for all exam cycles.
- Example:
  - 30-question paper → AI generates 30 questions every time
  - `T_in ≈ 12,000` tokens
  - `T_out ≈ 30,000` tokens
- Cost per paper ≈
  - input: 12k * $0.15 / 1M ≈ $0.0018
  - output: 30k * $0.60 / 1M ≈ $0.018
  - total ≈ **$0.02/paper**

With 300 papers/month:
- AI cost ≈ 300 * $0.02 ≈ **$6/month**

Even this looks small for small schools, but real usage expands due to:
- multiple regeneration attempts
- richer context (learning outcomes, style rules, multilingual)
- OCR-heavy pipelines
- using a more capable model for reasoning/consistency

Therefore, **bank-first with gap-only AI** remains the best policy.

### 13.4 Recommendation for Akshara

Adopt **Scenario 2** (Hybrid, gap-only AI) as the default sustainable model:
- It preserves teacher trust
- It bounds token spend
- It builds a reusable question bank over time (compounding quality)

---

## 14) Implementation phases (no implementation yet)

### Phase 0 — Model alignment (Foundation)
1. Confirm question bank schema supports requested types:
   - add learning outcome tags
   - add HOTS/case study tags (via `cognitive_level`/tags)
2. Confirm paper blueprint fields:
   - difficulty mix + portion aligned chapter weights
3. Add approval workflow tables:
   - paper review events
   - approval audit log
4. Add RBAC permissions required for trusted workflow:
   - manageQuestionBank
   - approveQuestionPaper
   - publishQuestionPaper
   - enterExamMarks / processResults / publishResults

### Phase 1 — Bank-first question paper drafting + approval
1. Teacher selects exam parameters.
2. System generates draft from question bank only.
3. Teacher review UI (replace/reorder/archival).
4. Coordinator/Principal approval gate.
5. Publish print-ready PDF (R2 storage).

### Phase 2 — AI add-on (Generate Additional Questions)
1. Coverage detection:
   - identify blueprint slots missing from bank.
2. AI generates candidate questions for missing slots.
3. Candidates enter teacher review queue.
4. Teacher accepts candidates → paper remains reviewable until approval.
5. Store AI provenance + token usage for audit & cost analytics.

### Phase 3 — Exam lifecycle integration + results + report cards
1. Link “exam schedule” → “paper version” used.
2. Marks entry → result processing pipeline.
3. Report card generation wizard:
   - marks/grades/attendance
   - teacher remarks
   - optional AI remark suggestions (reviewable)
4. Publish report card snapshots and PDFs.
5. Parent + student visibility rules.

### Phase 4 — Copilot insights (teacher/principal/parent)
1. Compute “weak topics” from exam intelligence snapshots.
2. Provide teacher revision plans and question variation suggestions.
3. Provide principal intervention recommendations.
4. Provide parent trend explanations.

### Phase 5 — Publisher ingestion & scaling
1. Build import flows:
   - spreadsheet import
   - OCR assisted import
2. Enforce normalization:
   - teacher mapping to chapters/topics/learning outcomes
3. Add quality scoring:
   - duplicates, similarity clusters, syllabus alignment checks

---

## 15) Summary: what makes this platform “school-trusted”

This design is not “an AI question paper generator”. It is a governed platform where:
- Teachers build and approve content in a question bank.
- Papers are generated from that bank with deterministic blueprint constraints.
- AI is only used to fill missing bank gaps and always routes into teacher review.
- Every paper is auditable: sources, blueprint, versions, and approvals.
- Results and report cards are built and published through gated workflows with parent/student visibility controls.

