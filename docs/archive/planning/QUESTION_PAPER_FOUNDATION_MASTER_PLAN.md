# Akshara — Academic Knowledge Platform & Question Intelligence Master Plan

> ⚠️ **SUPERSEDED (2026-07-02)** by `docs/Vision/design/Assessment-Intelligence-Platform.md`
> (Master Plan **v3.0**, locked owner decisions). v3.0 preserves this document's architecture
> by reference but **amends §10** (publisher licensing demoted — original-content-first) and
> adds the response-centric spine, marks-grid collection, canonical concepts, governed
> blueprint templates, trust pipeline, ERP integration, and adaptive AI. Use v3.0 for all
> forward planning; this file remains the v2.0 architecture record.

**Document ID:** `AKS-QP-FOUNDATION-PLAN-v2.0`  
**Created:** June 2026 · **Revised:** June 2026 (architecture refinement)  
**Purpose:** Enterprise product architecture — long-term vision (10+ year roadmap) for Akshara's **Academic Knowledge Platform** and **Question Intelligence Platform**. Question paper generation, DPP, foundation tracks (Class 6 → Inter), and competitive exam modules are **features built on top of structured academic knowledge** — not the product itself.  
**Related docs:** `docs/ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md` · `docs/QUESTION_INTELLIGENCE_PLATFORM_AUDIT.md` · `docs/Vision/design/AI-Question-Paper-System.md`

---

## Table of Contents

1. [Executive summary](#1-executive-summary)
2. [Vision — Academic Knowledge Platform](#2-vision--academic-knowledge-platform)
3. [How real publishers work (reference model)](#3-how-real-publishers-work-reference-model)
4. [Content sources — where papers come from](#4-content-sources--where-papers-come-from)
5. [What Akshara HAS today (verified inventory)](#5-what-akshara-has-today-verified-inventory)
6. [What Akshara DOES NOT HAVE (gaps)](#6-what-akshara-does-not-have-gaps)
7. [Target architecture](#7-target-architecture)
8. [Knowledge Repository](#8-knowledge-repository)
9. [Board architecture](#9-board-architecture)
10. [Content acquisition strategy](#10-content-acquisition-strategy)
11. [Question Intelligence Engine](#11-question-intelligence-engine)
12. [Exam Knowledge Engine](#12-exam-knowledge-engine)
13. [Data model extensions needed](#13-data-model-extensions-needed)
14. [Database storage philosophy & vector strategy](#14-database-storage-philosophy--vector-strategy)
15. [Diagram & math rendering strategy](#15-diagram--math-rendering-strategy)
16. [AI policy & Content Generation Engine](#16-ai-policy--content-generation-engine)
17. [Performance & scalability](#17-performance--scalability)
18. [Cost strategy](#18-cost-strategy)
19. [Future contribution model](#19-future-contribution-model)
20. [Phased implementation plan](#20-phased-implementation-plan)
21. [Long-term roadmap (10-year stages)](#21-long-term-roadmap-10-year-stages)
22. [Pilot recommendation (first real deployment)](#22-pilot-recommendation-first-real-deployment)
23. [Roles, permissions & workflow](#23-roles-permissions--workflow)
24. [Student & parent delivery](#24-student--parent-delivery)
25. [Legal & copyright guardrails](#25-legal--copyright-guardrails)
26. [Effort & timeline estimates](#26-effort--timeline-estimates)
27. [Success criteria & KPIs](#27-success-criteria--kpis)
28. [Risk register](#28-risk-register)
29. [Telugu summary (10 lines)](#29-telugu-summary-10-lines)

---

## 1. Executive summary

**What is Akshara building?**  
Not a "Question Paper Generator." Akshara is building an **Academic Knowledge Platform** — a long-term, structured repository of syllabus-aligned academic knowledge — with a **Question Intelligence Platform** on top. Question papers, DPPs, mocks, and PDFs are **outputs** of that knowledge. The real company asset is **structured academic knowledge** (concepts, outcomes, questions, solutions, diagrams, metadata, provenance) — not ephemeral PDF files.

**Can we implement complete real-world question papers in Akshara?**  
**Yes.** The platform scaffold (database, API, UI shell, PDF export, syllabus module, exam approval lifecycle) already exists. What is missing is the **Knowledge Repository**, **real content**, **diagram assets**, **Question Intelligence Engine**, **foundation/JEE program layer**, **deterministic blueprint engine**, and **unified exam ↔ paper ↔ marks loop**.

**Competitive advantage:** Akshara wins through **knowledge acquisition** (official syllabus, textbooks, teacher content, licensed publishers, provenance) — not through dependence on any single AI vendor. AI is a **tool** routed through a provider-agnostic **Content Generation Engine** (Gemini, OpenAI, Claude, local models, future LLMs). Akshara must never depend on one provider. Optional research assistants (e.g. NotebookLM) may assist content teams later — they are **not** architecture dependencies.

**Key insight:** Publishers (Career Point Kota, Disha, MTG) do not magically download 20 years of papers. They combine NCERT-aligned syllabus, faculty-authored questions, PYQ *pattern analysis*, graduated difficulty, and pre-rendered diagram assets. Akshara should replicate this **knowledge pipeline digitally**, not scrape copyrighted PDFs.

**Recommended sequence:**
1. Knowledge Repository + bank-first real questions (teacher + import + licensed PYQ tagging)
2. Deterministic paper/DPP blueprint engine (SQL + rules — no vector DB required initially)
3. Question Intelligence Engine (classification, fingerprinting, confidence scoring)
4. Diagram + LaTeX rendering
5. Foundation program tracks (JEE/NEET/NTSE) via shared Exam Knowledge Engine
6. Provider-agnostic AI gap-fill with confidence pipeline (high-confidence auto-queue; low-confidence → teacher review)

**Fastest credible path:** Stage 1 pilot — **CBSE Class 8 Science** (see §21) — before scaling boards, classes, and competitive modules.

---

## 2. Vision — Academic Knowledge Platform

### 2.1 Product goal

Akshara's long-term product is an **Academic Knowledge Platform** with a **Question Intelligence Platform** layer. Paper generation is **one feature** among many (DPP, homework, mocks, analytics, adaptive improvement) — all reading from the same Knowledge Repository.

The platform supports:

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

### 2.3 What the real asset is

| Asset | Long-term value |
|-------|-----------------|
| Structured academic knowledge (concepts, outcomes, questions, solutions, diagrams) | **Primary IP** — compounds over years |
| Provenance, licensing, versioning | Legal defensibility + trust |
| Question Intelligence (fingerprinting, families, analytics) | Moat — improves with usage |
| PDF question papers | **Output artifact** — regenerable from knowledge |

### 2.4 Non-negotiable quality rules

1. **Knowledge first, AI second** — primary content from Category A/B sources (§10); AI is Category C gap-fill only.
2. **Teacher control on low-confidence content** — high-confidence pipeline output may auto-queue; uncertain items require human review (§11.4).
3. **Syllabus boundary** — every knowledge item references typed syllabus IDs within its **board hierarchy**, not free text.
4. **Diagrams are assets** — never inline plain text; fixed layout boxes for print.
5. **Provenance & licensing metadata** — every item records source, license, and version.
6. **Closed loop** — marks → weak chapters → next blueprint adapts.
7. **Provider independence** — Content Generation Engine abstracts all LLM vendors; no single-provider lock-in.

### 2.5 Differentiator vs generic generators (e.g. theprashna.com)

Akshara owns the full chain: **Knowledge Repository → Question Intelligence → blueprint → paper → exam marks → analytics → adaptive improvement**. Competitors generate PDFs; Akshara **accumulates and compounds structured academic knowledge** across boards, years, and exam types — then learns which concepts and question families teach best.

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
| One pilot (CBSE Class 8 Science — Stage 1) | 80–120 questions + 30 concepts |
| Engineering demo (Class 9 Math JEE Foundation) | 80–120 questions (optional parallel) |
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
- v8.5 Question Intelligence / paper assembly feature (P2) — one output of Academic Knowledge Platform
- v8.6 Knowledge Repository / question bank (P2)
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
| Real LLM behind provider-agnostic Content Generation Engine | AI assist not production-ready | P3 |
| Knowledge Repository hierarchy (concept, formula, versioning) | Questions only — no full knowledge graph | P1 |
| Question Intelligence Engine (fingerprint, families, confidence) | Stub picker only | P1 |
| Vector store / pgvector embeddings | Not required for v1 paper generation | P3 |
| Exam Knowledge Engine (shared competitive module plug-in) | Separate silos per exam type | P2 |
| OCR import pipeline | Slow bulk ingestion | P3 |
| Publisher license import format | No partnership channel | P3 |

### 6.3 Stubbed behavior to replace

**Client mock** (`mock_education_repository.dart`): hardcoded bank items + fake AI strings.  
**Server generator** (`education_generator.ts`): template questions like “Multiple choice: Mathematics — Algebra (medium)”.  
**Server picker** (`education_question_paper_service.ts`): greedy marks fill — no type/difficulty/portions constraints.

---

## 7. Target architecture

### 7.1 Academic Knowledge Engine (long-term core)

The Academic Knowledge Engine is Akshara's central intellectual architecture. All exam modules (school, board, foundation, competitive, government) plug into the same engine. Only **syllabus**, **blueprint rules**, **question types**, **difficulty curves**, and **evaluation rules** change per module — not the underlying platform.

```
Knowledge Sources
        ↓
Knowledge Repository
        ↓
Question Intelligence
        ↓
Blueprint Engine
        ↓
Paper Generation          ← one feature output
        ↓
Assessment
        ↓
Analytics
        ↓
Adaptive Improvement      ← feeds next blueprint
```

| Layer | Responsibility |
|-------|----------------|
| **Knowledge Sources** | Official textbooks, syllabus docs, PYQs (legal), teacher/school content, licensed publishers, AI-generated originals (Category C) |
| **Knowledge Repository** | Structured storage: board hierarchy → concepts → questions → solutions → diagrams → formulae → metadata (§8) |
| **Question Intelligence** | Generation assist, verification, classification, fingerprinting, families, confidence scoring, rotation (§11) |
| **Blueprint Engine** | Deterministic SQL + rules: marks, types, difficulty, portions, dedup — **no vector DB required** for initial generation |
| **Paper Generation** | Assembles approved knowledge items into DPP / unit / monthly / mock papers; PDF queue |
| **Assessment** | Exam sessions, student attempts, marks entry, approval-gated publish |
| **Analytics** | Item analysis, weak chapters, concept mastery, question usage stats |
| **Adaptive Improvement** | Next DPP/blueprint weighted to weakness; question rotation; family parameter selection |

### 7.2 Operational pipeline (current build target)

The diagram below reflects the **near-term implementation path** already partially built in Akshara. It maps to the Academic Knowledge Engine layers above and must converge over time — not remain a parallel silo.

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        KNOWLEDGE SOURCES (Category A/B/C)                │
│  NCERT + Syllabus Templates │ Official PYQs │ Teacher Bank │ Licensed   │
│  Publisher Content        │ OCR Import (review) │ AI Candidates (queue) │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              KNOWLEDGE REPOSITORY + SYLLABUS BOUNDARY                    │
│  Board → Academic Year → Class → Subject → Chapter → Topic → Concept     │
│  school_completion │ edu_question_bank_items │ assets │ versioning      │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                   QUESTION INTELLIGENCE ENGINE                           │
│  Classification │ Fingerprint │ Families │ Confidence │ Rotation       │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    BLUEPRINT ENGINE (deterministic)                      │
│  Inputs: exam_type | program | chapters completed | difficulty mix      │
│  Outputs: DPP slot plan | monthly paper | full mock blueprint           │
│  Constraints: marks, types, chapters, dedup, HOTS minimum               │
│  Storage: PostgreSQL queries + blueprint rules — NOT vector search       │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│         CONTENT GENERATION ENGINE (provider-agnostic, gap-fill)          │
│  Gemini │ OpenAI │ Claude │ Local models │ Future LLMs                   │
│  Routed via AiInferencePipeline │ JSON schema │ syllabus scope token     │
│  → confidence pipeline → moderation queue (never auto-publish papers)    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│           MODERATION & APPROVAL (reuse exam_admin pattern)              │
│  High-confidence → auto-queue │ Low-confidence → teacher review          │
│  Coordinator review → Principal approve → publish                        │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         DELIVERY                                         │
│  PDF print (branded, queue-based) │ Student app DPP │ Teacher assign    │
└───────────────────────────────┬─────────────────────────────────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│              EXAM → MARKS → ANALYTICS → ADAPTIVE IMPROVEMENT             │
│  exam_administration_store │ item analysis │ weak chapter intelligence  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 8. Knowledge Repository

The Knowledge Repository stores **knowledge** — not only questions. Questions are one **representation** of underlying academic concepts. This repository is Akshara's long-term intellectual property.

### 8.1 Hierarchy

```
Board
  ↓
Academic Year
  ↓
Class
  ↓
Subject
  ↓
Chapter
  ↓
Topic
  ↓
Learning Outcome
  ↓
Concept
  ↓
Questions          ← one representation
Solutions
Diagrams
Formulae
References
Metadata           (provenance, license, Bloom, difficulty, exam type, version)
```

### 8.2 Entity relationships

| Entity | Role |
|--------|------|
| **Concept** | Atomic teachable idea (e.g. "Area of circle", "Ohm's law") |
| **Question** | Assessment instance linked to concept(s); may belong to a **question family** |
| **Solution** | Step-by-step working; may include alternate methods |
| **Diagram** | SVG/PNG/graph spec asset linked to concept or question |
| **Formula** | LaTeX representation linked to concept/chapter |
| **Reference** | Textbook page, NCERT exercise ref, official PYQ ref, publisher license ref |
| **Metadata** | Source category, confidence score, usage count, rotation policy |

### 8.3 Mapping to current schema

Today `edu_question_bank_items` stores flat question rows. Phase 1 extends linkage to syllabus IDs; Phase 2+ introduces explicit `edu_concepts`, `edu_formulae`, `edu_knowledge_references` tables (see §13). Existing bank items migrate upward into the Knowledge Repository without data loss.

### 8.4 Private vs global knowledge

- **School-private:** Teacher drafts, unreleased content — RLS scoped to tenant.
- **School-approved → optional global contribution:** After moderation, may promote to shared repository (§19).
- **Platform-curated:** Official syllabus, licensed publisher packs, verified PYQ tags.

---

## 9. Board architecture

Each board has an **independent academic structure**. Akshara does **not** assume boards are interchangeable or that content can be blindly translated between them.

### 9.1 Supported board model

```
Board (CBSE | ICSE | AP State | TS State | … | International)
  ↓
Academic Year
  ↓
Class
  ↓
Subject
  ↓
Chapter
  ↓
Topic
  ↓
Language              ← inside board hierarchy, NOT above it
```

**Language lives inside the board hierarchy.** A CBSE Class 8 Science chapter in Telugu medium is a distinct knowledge path from the same chapter in English medium — linked where syllabus-equivalent, never assumed identical.

### 9.2 Translation policy

| Scenario | Policy |
|----------|--------|
| Same board, different medium (EN ↔ TE ↔ HI) | Controlled translation with syllabus-equivalence flag |
| Different boards (e.g. AP Science vs CBSE Science) | **Separate trees** — do not auto-map chapters |
| Equivalent topics manually linked | Optional `syllabus_equivalence_links` for analytics only — not for blind content copy |
| Competitive exams (JEE, NEET) | Separate **Exam Knowledge Engine** profile (§12) referencing board foundation where applicable |

### 9.3 Content versioning per board

Every board node supports **Academic Year**, **Curriculum Version**, and **Revision**. Old versions are **archived, never overwritten** (see §14.3).

---

## 10. Content acquisition strategy

**Akshara wins through knowledge acquisition — not AI.** AI assists ingestion and gap-fill; it does not replace primary sources.

### 10.1 Category A — Primary sources (preferred)

| Source | Use |
|--------|-----|
| Official textbooks (NCERT, state board) | Concept definitions, examples, exercise patterns |
| Official syllabus / curriculum documents | Chapter/topic/outcome structure |
| Official previous-year papers (where legally available) | PYQ tagging, pattern analysis — not redistribution |
| Teacher-created content | Highest-trust bank entries |
| School-created content | Institution-standard questions and rubrics |

**Never present Category C AI content as if it were Category A.**

### 10.2 Category B — Licensed sources

| Source | Use |
|--------|-----|
| Publisher partnerships (Disha, CP Kota, MTG, etc.) | Bulk structured import with license metadata |
| Institution partnerships | Coaching chains contributing moderated content |
| Licensed digital libraries | Reference material linked to concepts |

Requires: `license_id`, `license_expiry`, `redistribution_allowed` flags on every imported item.

### 10.3 Category C — AI-generated (supplementary only)

| Use | Policy |
|-----|--------|
| Gap filling when blueprint cannot be satisfied from A/B | Confidence pipeline (§11.4) |
| Question variations (parameterized families) | Solver-verified |
| Metadata generation (Bloom, difficulty tags) | Spot-check sampling |
| OCR structuring assist | Teacher verification mandatory |

AI-generated items carry `source=ai_generated`, `confidence_score`, and remain candidates until approved.

### 10.4 Optional research tools (non-architecture)

Tools such as **NotebookLM** may optionally assist content teams with research summarization or draft exploration. They are **not** core architecture components, generation engines, or platform dependencies. All production content flows through the Knowledge Repository and Content Generation Engine abstraction.

### 10.5 Cross-reference: §4 Content sources

Section 4 lists specific legal PYQ URLs and volume targets. Section 10 defines the **strategic acquisition policy** those sources implement.

---

## 11. Question Intelligence Engine

The Question Intelligence Engine sits between the Knowledge Repository and the Blueprint Engine. It is **not** the same as raw LLM generation — it is deterministic + ML-assisted intelligence over stored knowledge.

### 11.1 Responsibilities

| Capability | Description |
|------------|-------------|
| **Question generation assist** | Invokes Content Generation Engine for gap-fill; outputs structured candidates |
| **Answer verification** | Independent solver pass validates numeric/symbolic answers |
| **Explanation generation** | Step-by-step solutions linked to concepts |
| **Difficulty classification** | easy / medium / hard + competitive tier |
| **Bloom classification** | remember → create |
| **Learning outcome classification** | Maps to syllabus outcome IDs |
| **Duplicate detection** | Fingerprint hash + later semantic similarity |
| **Semantic similarity** | pgvector-powered (Phase 4+) — find near-duplicates |
| **Question fingerprinting** | Normalized hash of stem + options + answer |
| **Question family detection** | Groups parameterized variants under one concept |
| **Metadata generation** | Tags, marks suggestions, type classification |
| **Diagram linking** | Associates assets to questions/concepts |
| **Question usage analytics** | Times used, classes, exams, avg score |
| **Question rotation** | Prevents over-exposure; enforces cooldown windows |
| **Confidence scoring** | Composite score drives review routing (§11.4) |

### 11.2 Question family concept

One academic **concept** can produce many **questions** without duplication:

```
Concept: Area of Circle (A = πr²)
        ↓
Family: area_circle_radius
        ↓
Instance: r = 5   (easy)
Instance: r = 8   (easy)
Instance: r = 12  (medium)
Instance: r = 20  (medium)
Instance: r = 7.5, units conversion (hard)
```

| Field | Purpose |
|-------|---------|
| `concept_id` | Parent concept in Knowledge Repository |
| `family_id` | Shared template / parameter schema |
| `family_params` | JSON `{ "radius": 5 }` — varies per instance |
| `template_stem` | Parameterized question template with placeholders |

**Benefits:** Reduces storage duplication; enables infinite practice with controlled difficulty progression; blueprint engine selects from family pools.

### 11.3 Confidence pipeline

Replace naive "AI generates → teacher approves everything" with a **multi-stage confidence pipeline**:

```
Generation AI (Content Generation Engine — inexpensive model tier)
        ↓
Independent Solver AI / symbolic validator (stronger tier for numeric answers)
        ↓
Metadata AI (classification, Bloom, outcome tags — inexpensive tier)
        ↓
Duplicate Detection (fingerprint + optional vector similarity)
        ↓
Confidence Score (0.0 – 1.0 composite)
        ↓
Routing:
  • score ≥ threshold (e.g. 0.85) → auto-queue for batch spot-check; may enter bank after policy timer
  • score < threshold → mandatory teacher review before bank merge
  • diagram present → always human review until diagram QA automated
```

**Published papers** still require coordinator/principal approval regardless of confidence — confidence routing applies to **bank ingestion**, not final paper publish.

### 11.4 Integration with existing approval workflow

Paper-level governance (§23) remains unchanged: Teacher draft → Coordinator → Principal → publish. Confidence pipeline optimizes **how much teacher time** is spent reviewing individual question candidates.

---

## 12. Exam Knowledge Engine

Akshara must **not** build separate systems per exam type. One **Exam Knowledge Engine** serves all modules. Each module is a **configuration profile** plugged into the Academic Knowledge Engine.

### 12.1 Plug-in model

```
Exam Knowledge Engine (common core)
        │
        ├── Profile: school_exam
        ├── Profile: board_exam (CBSE, ICSE, State)
        ├── Profile: foundation (Class 6–10)
        ├── Profile: olympiad | NTSE
        ├── Profile: jee_foundation | jee_main | jee_advanced
        ├── Profile: neet | cuet
        ├── Profile: upsc | ssc | rrb | banking | police | defence
        └── Profile: navodaya | sainik | groups
```

### 12.2 What changes per profile

| Dimension | Varies by profile |
|-----------|-------------------|
| Syllabus tree | Board + exam-specific scope |
| Blueprint rules | Marks, sections, negative marking, duration |
| Question types | MCQ, numerical, integer, matrix, comprehension, … |
| Difficulty curve | Foundation vs competitive |
| Evaluation rules | Partial marks, integer tolerance, OMR mapping |
| PYQ reference store | Exam-specific archive |

### 12.3 What stays common

- Knowledge Repository schema
- Question Intelligence Engine
- Blueprint Engine core solver
- Content Generation Engine abstraction
- Approval workflow
- PDF generation queue
- Marks → analytics → adaptive loop

### 12.4 Mapping to current `edu_program_tracks`

The proposed `edu_program_tracks` table (§13) evolves into **Exam Knowledge Engine profiles** — not separate codebases per exam.

---

## 13. Data model extensions needed

### 13.1 New tables (proposed)

```sql
-- Exam Knowledge Engine profile (replaces standalone program track over time)
edu_exam_knowledge_profiles (
  id, profile_code,  -- 'cbse_board', 'jee_main', 'neet', 'ssc', ...
  syllabus_root_id, blueprint_rules JSONB, question_type_catalog JSONB,
  evaluation_rules JSONB, status
)

-- Knowledge Repository: concepts and families
edu_concepts (
  id, board_id, syllabus_topic_id, concept_code, title, description,
  curriculum_version, status
)

edu_question_families (
  id, concept_id, family_code, template_stem, param_schema JSONB,
  difficulty_range, status
)

-- Content versioning (per board)
edu_curriculum_versions (
  id, board_id, academic_year_label, version_code, revision,
  effective_from, effective_to, status  -- 'active' | 'archived'
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
  source_url, license_status, license_id
)

-- Question confidence & fingerprinting
-- (columns also on edu_question_bank_items — see 13.2)

-- Global contribution queue (optional school → platform)
edu_knowledge_contributions (
  id, school_id, bank_item_id, contribution_type,
  status,  -- 'submitted', 'moderated', 'accepted', 'rejected'
  moderator_user_id, reviewed_at
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

### 13.2 Extensions to existing tables

**`edu_question_bank_items` — add columns:**
- `syllabus_chapter_id UUID` (FK, replaces free-text chapter)
- `syllabus_topic_id UUID` (FK)
- `concept_id UUID` (FK → `edu_concepts`)
- `family_id UUID` (FK → `edu_question_families`)
- `family_params JSONB` — parameterized instance values
- `exam_profile_code TEXT` — Exam Knowledge Engine profile
- `jee_question_type TEXT` — `numerical`, `integer`, `matrix_match`, `assertion_reason`, `comprehension`
- `cognitive_level TEXT` — `remember`, `understand`, `apply`, `analyze`, `hots`
- `source TEXT` — `teacher`, `school`, `import`, `pyq`, `publisher`, `ai_generated`
- `source_category TEXT` — `A`, `B`, `C` (acquisition category)
- `source_reference TEXT`
- `license_id TEXT`, `license_status TEXT`
- `learning_outcome TEXT`
- `fingerprint TEXT` — hash for dedup
- `confidence_score NUMERIC(4,3)` — Question Intelligence composite
- `curriculum_version_id UUID` — links to archived syllabus version

**`edu_question_papers` — add columns:**
- `program_track TEXT`
- `review_status TEXT` — `draft`, `submitted`, `approved`, `published`, `archived`
- `approved_by UUID`, `approved_at TIMESTAMPTZ`
- `pdf_storage_path TEXT`

### 13.3 Flutter model extensions

Extend `lib/features/education/education_models.dart`:
- `QuestionAsset` class
- `FoundationProgram` enum
- `JeeQuestionType` enum
- `PaperReviewStatus` enum
- Link `GenerateQuestionPaperRequest.chapters` → `List<String> syllabusChapterIds`

---

## 14. Database storage philosophy & vector strategy

Separate storage by responsibility. Do not store everything in PostgreSQL rows or everything in object storage.

### 14.1 PostgreSQL (Supabase) — structured truth

| Stores | Why |
|--------|-----|
| Questions, concepts, families | Relational queries, blueprint filtering, RLS |
| Metadata (Bloom, difficulty, provenance, confidence) | Indexed filtering for deterministic selection |
| Blueprints, paper definitions, versions | Transactional consistency |
| Relationships (concept ↔ question ↔ syllabus ↔ exam profile) | Join performance |
| Versions (curriculum_version, archived syllabus) | Immutable history |

**Paper generation uses PostgreSQL + blueprint rules.** Proper indexing on `(board_id, class, subject, chapter_id, difficulty, question_type, status)` supports millions of question rows with sub-second blueprint queries.

### 14.2 Object storage (R2 / S3) — binary assets

| Stores | Why |
|--------|-----|
| Textbook PDFs (reference) | Large files; not queried relationally |
| Published paper PDFs | Generated artifacts; versioned blobs |
| SVG, PNG diagrams | Render assets; CDN-friendly |
| OCR upload batches | Pre-ingestion staging |
| Graph spec exports | Pre-rendered PNG cache |

Store **pointers** (`storage_path`, `width_px`, `height_px`) in PostgreSQL; bytes in object storage.

### 14.3 Vector store — semantic layer (later phase)

**Vector DB is NOT required for initial paper generation.**

Introduce **pgvector** (Supabase-compatible) in a later phase for:

| Use case | When |
|----------|------|
| Duplicate detection (semantic) | Phase 4+ — complements fingerprint hash |
| Find similar questions | Teacher search, blueprint dedup |
| Knowledge retrieval for AI context | Scoped RAG within syllabus boundary |
| Question recommendation | Adaptive DPP |
| Teacher search | Natural-language discovery over bank |

**Not used for:** initial blueprint slot filling (deterministic SQL suffices).

Embeddings table (proposed):

```sql
edu_question_embeddings (
  bank_item_id UUID REFERENCES edu_question_bank_items (id),
  embedding vector(1536),  -- pgvector
  model_version TEXT,
  created_at TIMESTAMPTZ
);
CREATE INDEX ON edu_question_embeddings USING ivfflat (embedding vector_cosine_ops);
```

### 14.4 Content versioning

Every board supports immutable curriculum history:

| Field | Rule |
|-------|------|
| Academic Year | e.g. `2025-26` |
| Curriculum Version | e.g. `cbse_2025_v1` |
| Revision | Minor updates within year |
| Archive policy | Old versions **read-only archived** — never overwrite |

When a state board revises Class 8 Science:
1. Create new `edu_curriculum_versions` row.
2. Clone or migrate applicable knowledge with version FK.
3. Existing papers remain linked to their generation version.
4. Analytics compare across versions explicitly.

---

## 15. Diagram & math rendering strategy

### 15.1 Problem

JEE/foundation papers without aligned diagrams are **unusable**. Storing “draw a circuit diagram” as plain text fails in app and print.

### 15.2 Asset types

| Type | Storage | Flutter render | PDF render |
|------|---------|----------------|------------|
| Math equations | LaTeX string in DB | `flutter_math_fork` | Pre-render or LaTeX→PDF widget |
| Static figures (triangle, ray, circuit) | SVG in R2 | `flutter_svg` | Embed SVG/PNG in `pdf` package |
| Graphs / coordinate geometry | JSON spec (points, axes, curves) | `CustomPainter` or JSXGraph webview | Pre-render to PNG at fixed DPI |
| Complex diagrams | PNG @2x + SVG fallback | `Image` with `width`/`height` | Fixed aspect ratio box |

### 15.3 Layout rules (critical)

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

### 15.4 AI policy for diagrams

| Action | Allowed |
|--------|---------|
| AI suggests graph spec JSON | Yes → teacher approves |
| AI generates circuit diagram PNG | No auto-publish |
| Teacher uploads SVG/PNG | Yes — primary path |
| Template-based parameterized graphs (e.g. parabola with random `a`) | Yes — validate programmatically |

### 15.5 Implementation packages (Flutter)

- `flutter_math_fork` or `flutter_tex` — LaTeX
- `flutter_svg` — SVG assets
- `pdf` + `printing` — already in use; extend for images

---

## 16. AI policy & Content Generation Engine

### 16.1 Core philosophy

| Principle | Statement |
|-----------|-----------|
| **AI is NOT the product** | Knowledge Repository is the product and long-term IP |
| **AI is a tool** | Used for gap-fill, classification, verification assist — routed through abstraction |
| **Knowledge is primary** | Category A/B sources fill blueprints first; Category C last |
| **No vendor lock-in** | Provider-agnostic Content Generation Engine |

### 16.2 Content Generation Engine (provider abstraction)

Akshara defines a generic **Content Generation Engine** interface — not a binding to Gemini, OpenAI, Claude, or any single vendor.

```
ContentGenerationEngine (interface)
        │
        ├── Provider: Gemini
        ├── Provider: OpenAI
        ├── Provider: Claude (Anthropic)
        ├── Provider: Local / on-prem models
        └── Provider: Future LLMs (plug-in)
```

**Existing hook:** `lib/core/ai/AiInferencePipeline` — extend with provider registry, model tier routing, cost accounting, and fallback chain. Education flows **must** route through this pipeline (today they bypass it).

**Model tier routing (see §18):**
- **Tier 1 (inexpensive):** generation, classification, metadata tagging
- **Tier 2 (stronger):** answer verification, complex competitive reasoning, solver independence

**Optional future tool:** NotebookLM or similar may assist human content researchers with summarization — never as a required runtime dependency.

### 16.3 Policy (from ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md — evolved)

1. **Bank-first / knowledge-first** — select from Knowledge Repository + PYQ store first.
2. **AI only for gaps** — when blueprint cannot be satisfied from Category A/B.
3. **Confidence pipeline** — not all AI output requires full teacher review (§11.4); low-confidence always does.
4. **AI output = candidates** — never `published` paper directly; never presented as Category A.
5. **Syllabus-scoped** — pass chapter/topic/concept IDs only; no whole-book context.
6. **Structured JSON output** — strict schema; low temperature (0.1–0.3) for generation tier.
7. **Reuse stored knowledge** — do not regenerate questions that already exist (fingerprint check first).
8. **Wire through Content Generation Engine** — RBAC + audit + provenance on every call.

### 16.4 Safe AI use cases

| Use case | Tier | Risk | Mitigation |
|----------|------|------|------------|
| Tag PYQs by chapter/difficulty | 1 | Low | Human spot-check 10% sample |
| Generate numeric family variations | 1 + solver 2 | Low | Symbolic validation |
| Metadata / Bloom classification | 1 | Low | Sampling audit |
| Fill blueprint gaps (MCQ/short) | 1 + verify 2 | Medium | Confidence pipeline |
| OCR scanned pages → structured draft | 1 | Medium | Teacher verifies; copyright check |
| Full DPP auto-generation | 1 | High | Do not ship without review |
| Physics circuit diagram generation | — | High | Teacher upload only |

### 16.5 What AI cannot replace

- Category A/B knowledge acquisition at scale
- Licensed publisher libraries
- Faculty judgment on "exam-like" difficulty
- Principal sign-off on published papers
- Legally safe bulk content without license or original authorship
- The Knowledge Repository as company IP

---

## 17. Performance & scalability

Millions of questions in the Knowledge Repository is **expected and acceptable** — not a failure state. Paper generation remains fast through architecture discipline.

### 17.1 Query performance

| Technique | Application |
|-----------|-------------|
| Composite indexes | `(school_id, subject, chapter_id, difficulty, status)` |
| Partial indexes | `WHERE status = 'active'` |
| Blueprint pre-filter | SQL narrows candidate pool before in-memory solver |
| Pagination | Teacher bank UI — never load full corpus |
| Read replicas | Analytics queries off primary (future) |

### 17.2 Caching

| Layer | Caches |
|-------|--------|
| Blueprint templates | Per exam profile — immutable until admin change |
| Syllabus trees | Per board + curriculum version |
| Hot question pools | Frequently used DPP families |
| PDF artifacts | Published paper PDFs in object storage — regenerate only on edit |
| Content Generation Engine | Prompt prefix caching for stable syllabus descriptors |

### 17.3 Background processing

| Job | Pattern |
|-----|---------|
| PDF generation | Queue-based workers — not synchronous HTTP |
| Bulk import validation | Async job + progress UI |
| Embedding generation | Batch worker when pgvector enabled |
| Confidence pipeline | Async multi-step job per candidate batch |
| Analytics snapshots | Scheduled — `intel_exam_intelligence_snapshots` pattern |

### 17.4 Horizontal scalability

- Stateless Edge functions for API + blueprint solver
- Object storage CDN for diagram assets
- Queue (Supabase Edge + pg_cron or external worker) for PDF and AI batches
- No single-node assumption — tenant RLS preserved at DB layer

### 17.5 Realistic expectations

Do **not** claim unlimited concurrent AI generation without cost controls. Do **not** state hard caps like "max 10,000 questions" — proper indexing and filtering support **millions** of indexed rows; practical limits are **cost**, **moderation capacity**, and **content quality** — not raw row count.

---

## 18. Cost strategy

Minimize AI spend by **reusing stored knowledge** and routing models by task complexity.

### 18.1 Tier 1 — inexpensive models

Use for high-volume, lower-risk tasks:
- Question stem generation (gap-fill)
- Bloom / difficulty / outcome classification
- Metadata tagging
- OCR structuring drafts
- Duplicate candidate pre-screening

### 18.2 Tier 2 — stronger models

Use sparingly, only when needed:
- Independent answer verification (solver independence)
- Complex competitive reasoning (JEE Advanced tier)
- Cross-check of Tier 1 output when confidence < threshold
- Hard physics/chemistry multi-step validation

### 18.3 Cost controls

| Control | Implementation |
|---------|----------------|
| Fingerprint before generate | Skip API call if question exists |
| Generate only missing blueprint slots | Not full paper regeneration |
| Syllabus-scoped context | Minimize tokens |
| Batch jobs | Off-peak embedding + classification |
| Provider fallback | Route to cheaper provider when quality sufficient |
| Per-tenant quotas | School-level AI budget caps |
| Audit log | `prompt_hash`, `model`, `tokens`, `cost_estimate` per call |

**Rule:** Never regenerate existing questions. Always query Knowledge Repository first.

---

## 19. Future contribution model

Schools may **optionally** contribute to the platform-wide academic knowledge corpus. Contribution is never mandatory; schools retain full control over private content.

### 19.1 Contributable artifacts

| Artifact | Moderation |
|----------|------------|
| Teacher-created questions | Subject expert review |
| Question improvements / corrections | Diff review |
| Solutions & explanations | Accuracy check |
| Translations (within board equivalence rules) | Bilingual reviewer |
| Diagrams | Visual QA |
| Metadata corrections | Lightweight admin review |

### 19.2 Contribution flow

```
School private bank item
        ↓
Teacher opts in "Contribute to Akshara Knowledge"
        ↓
edu_knowledge_contributions (status: submitted)
        ↓
Platform moderation queue
        ↓
Accepted → promoted to global repository (anonymized or attributed per policy)
Rejected → remains school-private with feedback
```

### 19.3 Governance

- Schools **retain ownership** of private content until explicit contribution acceptance.
- Global repository items carry `contributor_school_id`, `license`, `moderation_audit`.
- No automatic upload — opt-in only.
- RBAC: `contributeKnowledge`, `moderateKnowledgeContributions`.

---

## 20. Phased implementation plan

### Phase 0 — Prerequisites (1–2 weeks)

**Goal:** Unblock data quality before feature work.

| Task | Owner | Deliverable |
|------|-------|-------------|
| Confirm education migration applied on staging | DevOps | Tables live |
| Wire `EducationRepository` to API (not mock) in pilot school | Agent A/B | Hybrid repo default |
| Document CBSE Class 8 Science syllabus in `school_completion` | Academic team | Stage 1 board tree + curriculum version |

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

**Exit criteria:** CBSE Class 8 Science unit/monthly paper with 100% Category A/B bank-sourced questions, principal-approved PDF.

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

### Phase 5 — Content Generation Engine + confidence pipeline (4–6 weeks) — P2/P3

| # | Task |
|---|------|
| 5.1 | Provider-agnostic Content Generation Engine behind `AiInferencePipeline` |
| 5.2 | Tier 1 / Tier 2 model routing (§18) |
| 5.3 | Gap-fill endpoint: only missing blueprint slots; fingerprint check first |
| 5.4 | Confidence pipeline: generation → solver → metadata → dedup → score (§11.4) |
| 5.5 | AI candidate moderation queue UI (low-confidence mandatory review) |
| 5.6 | Numeric family variation generator with answer validation |
| 5.7 | OCR import assist (optional) |

**Exit criteria:** When bank is 80% sufficient, AI fills 20% as candidates; high-confidence items queue efficiently; teacher reviews only low-confidence + all diagrams.

---

### Phase 6 — Vector search + scale (ongoing)

| # | Task |
|---|------|
| 6.1 | pgvector embeddings + semantic duplicate detection |
| 6.2 | Teacher semantic search over Knowledge Repository |
| 6.3 | License negotiation with Disha / CP Kota / MTG (Category B) |
| 6.4 | Bulk import pipeline for publisher format |
| 6.5 | Exam Knowledge Engine profiles beyond school/board (JEE, NEET, …) |
| 6.6 | Multi-set mocks (Set A/B/C) for competitive profiles |
| 6.7 | Global contribution moderation (§19) |

**Note:** Phase numbering aligns with engineering delivery. Long-term **content** stages follow §21 (CBSE Class 8 Science first — not all classes at once).

---

## 21. Long-term roadmap (10-year stages)

**Do NOT build everything at once.** Expand board, class, subject, and exam profile coverage sequentially. Software (Exam Knowledge Engine) should lead content by one stage — never the reverse.

| Stage | Scope | Content focus | Platform focus |
|-------|--------|---------------|----------------|
| **Stage 1** | CBSE Class 8 Science | Official NCERT + teacher bank; monthly + unit papers | Knowledge Repository + blueprint + approval + PDF |
| **Stage 2** | CBSE Classes 8–10 (Science stream) | Expand concepts, families, DPP | Question Intelligence fingerprinting |
| **Stage 3** | AP State Board (Class 8 Science first) | Separate board tree — no CBSE translation assumption | Board architecture (§9) |
| **Stage 4** | Maths + Science complete (CBSE 8–10 + AP parallel) | Full PCM foundation corpus | Diagram assets at scale |
| **Stage 5** | Foundation Programs (NTSE, Olympiad patterns) | Category A PYQ patterns | Exam profile: `foundation` |
| **Stage 6** | JEE Foundation (Class 9–10) | Original + family-generated questions | Exam profile: `jee_foundation` |
| **Stage 7** | JEE Main (Class 11–12) | Official PYQ tagging | Exam profile: `jee_main` |
| **Stage 8** | NEET | Separate profile; do not reuse JEE diagrams blindly | Exam profile: `neet` |
| **Stage 9** | Additional boards (ICSE, TS, international) | Licensed + faculty content per board | Multi-board versioning |
| **Stage 10** | Government Exam Engine | UPSC, SSC, RRB, Banking, Police, Defence, Navodaya, Sainik, Groups | Shared Exam Knowledge Engine (§12) |

Each stage completes **content + moderation + analytics** for its scope before the next stage begins.

---

## 22. Pilot recommendation (first real deployment)

### 22.1 Pilot scope (aligned with Stage 1)

| Parameter | Value |
|-----------|-------|
| Board | CBSE |
| Class | 8 |
| Subject | Science |
| Program | Board + foundation readiness (not full JEE yet) |
| Paper type | Unit test + monthly test |
| DPP | 10–15 questions/day (optional in pilot week 3+) |
| Duration | 4-week pilot with one section (8-A) |

**Engineering alternate pilot:** If JEE foundation demo is needed earlier for sales, Class 9 Mathematics JEE Foundation (original §22 scope) may run in parallel — but **content strategy** still prioritizes Stage 1 CBSE Class 8 Science as canonical starting point.

### 22.2 Pilot content pack

| Content | Count | Source (Category) |
|---------|-------|-------------------|
| Bank MCQ | 40 | A — Faculty-authored |
| Bank short answer | 20 | A — Faculty-authored |
| NCERT-aligned concept entries | 30 | A — Official textbook mapping |
| Diagram questions | 10 | A — Faculty SVG upload |
| PYQ-tagged (pattern reference) | 10 | A — Official where legal |

### 22.3 Pilot workflow

1. Academic head sets **CBSE Class 8 Science** syllabus in `school_completion` with curriculum version.
2. Teachers enter/import 80+ knowledge items (questions + concepts) with syllabus chapter IDs.
3. Question Intelligence assigns fingerprints; duplicate check runs.
4. System generates unit/monthly paper from deterministic blueprint.
5. Coordinator reviews portion alignment.
6. Principal approves → queue-based PDF published.
7. (Optional) DPP auto-scheduled from completed chapters.
8. Teacher enters marks in exam admin.
9. Analytics report shows weak topics → inputs next blueprint.

### 22.4 Pilot success metrics

- 0 stub/placeholder questions in published papers
- 100% questions linked to syllabus chapter IDs
- Diagram QA pass: 10/10 print correctly
- Teacher time to create monthly paper < 30 minutes (after bank populated)
- Student DPP completion rate > 60%

---

## 23. Roles, permissions & workflow

### 23.1 Recommended workflow

```
Subject Teacher
  → creates paper draft from bank (or requests DPP generation)
Exam Coordinator
  → reviews portion alignment, type distribution, marks total
Principal / Academic Head
  → approves → system generates print PDF → publish to class
```

### 23.2 Permissions to add

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

### 23.3 Reuse exam approval pattern

Copy governance from `exam_administration_store.dart`:
- Status machine with rejection comments
- Audit log on approve/publish
- Principal-only final publish

---

## 24. Student & parent delivery

### 24.1 Mobile screens

| Screen ID | Purpose | Status |
|-----------|---------|--------|
| S-11 PracticePapers-M | Student DPP / practice | 📋 Spec only — not built |
| S-12 ExamResults-M | Results after publish | ✅ Partial |
| P-12 ReportCards-M | Parent academic view | ✅ Partial |

### 24.2 Delivery modes

| Mode | Use case |
|------|----------|
| In-app attempt | DPP daily — MCQ + numerical input |
| PDF print | Monthly/unit tests — school exam hall |
| PDF download | Homework / holiday package |
| Teacher assign | Push DPP to class section via homework flow |

### 24.3 Phase 3 deliverable

New `StudentPracticeScreen`:
- List today's DPP
- Timer (optional)
- Submit answers (MCQ auto-grade; numerical manual/scaffold)
- Show solution after submit (if school policy allows)

---

## 25. Legal & copyright guardrails

### 25.1 Prohibited practices

| Prohibition | Rationale |
|-------------|-----------|
| **Do NOT scrape copyrighted coaching materials** | Kota DPPs, institute PDFs — criminal/civil copyright risk |
| **Do NOT redistribute copyrighted DPPs** | Even internally without license |
| **Do NOT import copyrighted books without licensing** | Category B requires explicit `license_id` |
| **Do NOT present AI content as official textbook content** | Category C must never masquerade as Category A |
| **Do NOT assume board equivalence for content copy** | AP Science ≠ CBSE Science (§9) |

### 25.2 Required practices

| Requirement | Implementation |
|-------------|----------------|
| Study official syllabus | Category A curriculum documents — structure source of truth |
| Study official exam patterns | PYQ analysis for patterns — not bulk republishing |
| Create original questions | Faculty + parameterized families |
| Maintain provenance | `source`, `source_category`, `source_reference` on every item |
| Maintain licensing metadata | `license_id`, `license_status`, `redistribution_allowed` |
| Teacher attestation on publish | "I confirm originality / licensed use" checkbox |
| Student data not in AI prompts | Class-level context only; anonymize |
| Archive curriculum versions | Never overwrite — legal and academic audit trail |

### 25.3 Implementation controls

| Rule | Implementation |
|------|----------------|
| No scrape copyrighted publisher PDFs | Product policy + import audit |
| PYQ from official sources only | `source_url` + `license_status` on `edu_pyq_items` |
| AI-generated content = Category C draft | Provenance `source=ai_generated`, `confidence_score` |
| Contribution legal clarity | Terms of contribution grant platform usage rights on acceptance only |

---

## 26. Effort & timeline estimates

### 26.1 Engineering

| Phase | Duration | Team |
|-------|----------|------|
| Phase 0 — Prerequisites | 1–2 weeks | 1 backend + 1 Flutter |
| Phase 1 — Real bank + papers | 4–6 weeks | 1 backend + 1 Flutter + 1 QA |
| Phase 2 — Diagrams + LaTeX | 3–4 weeks | 1 Flutter + 1 backend |
| Phase 3 — Foundation + DPP | 4–6 weeks | 2 Flutter + 1 backend |
| Phase 4 — PYQ + analytics | 4–6 weeks | 1 backend + 1 data |
| Phase 5 — Content Generation Engine | 4–6 weeks | 1 AI/backend |
| Phase 6 — Vector + scale | Ongoing | 1 backend + 1 data |
| **Total to Stage 1 pilot** | **~3–4 months** | |

### 26.2 Content (parallel track — academic team)

| Scope | Duration |
|-------|----------|
| Stage 1 pilot (CBSE Class 8 Science) | 2–4 weeks faculty |
| Stage 2–4 (CBSE 8–10 + AP board) | 6–12 months |
| Stage 5–8 (Foundation → JEE → NEET) | 12–24 months |
| Publisher-licensed bulk (Category B) | 1–3 months after legal agreement |

**Software can reach Stage 1 pilot in ~3 months. Full 10-stage content program is a multi-year academic investment — the Knowledge Repository compounds over time.**

---

## 27. Success criteria & KPIs

### 27.1 Platform KPIs

| KPI | Target (pilot) |
|-----|----------------|
| Stub questions in published papers | 0% |
| Knowledge items with syllabus ID linkage | 100% |
| Category A/B share of published paper content | > 80% |
| Papers passing principal approval | 100% |
| Diagram print QA pass rate | > 95% |
| Paper generation time (after bank ready) | < 5 minutes |
| Student DPP weekly completion | > 60% |

### 27.2 Business KPIs

| KPI | Target |
|-----|--------|
| Coaching schools adopting foundation track | 3 pilots in 6 months |
| Teacher NPS on paper tool | > 7/10 |
| Schools contributing to Knowledge Repository | Opt-in growth metric |
| Reduction in manual paper prep time | > 50% |

---

## 28. Risk register

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Insufficient real questions in bank | High | High | Pilot content sprint; faculty incentives |
| Diagram misalignment in PDF | Medium | High | Fixed layout boxes; print QA checklist |
| Copyright violation from import | Medium | High | Provenance + license flags; legal review |
| AI hallucination in JEE questions | Medium | High | Bank-first; AI candidates only; no auto-publish |
| Teacher adoption resistance | Medium | Medium | Start with one subject; training; DPP time savings |
| Exam ↔ paper disconnect persists | Medium | Medium | Phase 1.7 link table; Phase 4 unification |
| AI vendor lock-in | Medium | High | Content Generation Engine abstraction; multi-provider |
| Over-reliance on AI vs knowledge acquisition | High | High | Category A/B first; AI is Category C only |
| Board content wrongly translated | Medium | High | Separate board trees (§9); no AP=CBSE assumption |
| Scope creep (all exam types at once) | High | High | 10-stage roadmap (§21); Stage 1 only first |

---

## 29. Telugu summary (10 lines)

1. **Akshara product = Academic Knowledge Platform** — PDF papers output మాత్రమే; real asset structured knowledge.
2. **Question Intelligence Platform** దానిపై build అవుతుంది — paper generator ఒక feature.
3. **Database, API, PDF, syllabus** ఇప్పటికే ఉన్నాయి — real knowledge content fill చేయాలి.
4. **AI tool మాత్రమే, product కాదు** — Gemini/OpenAI/Claude లాంటి providers; single vendor dependency లేదు.
5. **Diagrams SVG/PNG assets** — plain text లో కాదు; LaTeX for math.
6. **Board-wise separate structure** — AP Science ≠ CBSE; language board లోపల.
7. **Category A (official + teacher) primary** — AI Category C gap-fill మాత్రమే.
8. **Confidence pipeline** — low-confidence questions కే teacher review; high-confidence efficient queue.
9. **Stage 1 pilot: CBSE Class 8 Science** — అన్ని classes ఒకేసారి కాదు.
10. **10-year roadmap** — Stage 10 వరకు government exams; Knowledge Repository company IP.

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

## Appendix D — Architecture section index (v2.0)

| Section | Topic |
|---------|-------|
| §7.1 | Academic Knowledge Engine |
| §8 | Knowledge Repository hierarchy |
| §9 | Board architecture (language inside board) |
| §10 | Content acquisition (Category A/B/C) |
| §11 | Question Intelligence Engine + families + confidence pipeline |
| §12 | Exam Knowledge Engine (JEE, NEET, UPSC, …) |
| §14 | PostgreSQL / object storage / pgvector split |
| §16 | Content Generation Engine (provider-agnostic) |
| §17–§18 | Performance + cost strategy |
| §19 | Future school contribution model |
| §21 | 10-year content roadmap stages |

---

**Document status:** Architecture refinement v2.0 — enterprise product vision for 10+ year roadmap. Planning reference for Academic Knowledge Platform; not a feature implementation spec.  
**Next action when approved:** Stage 1 kickoff (CBSE Class 8 Science) — migration spec for Knowledge Repository linkage + `docs/Releases/vX.X-Academic-Knowledge-Platform.md`.
