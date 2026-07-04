# QUESTION INTELLIGENCE PLATFORM AUDIT — Akshara ERP

> **Audit date:** 2026-06-18 · **Base commit:** `70194d6`
> **Benchmark (reference only, do not copy):** theprashna.com — a question-paper generator. **Goal: build something significantly stronger — a Question *Intelligence* Platform.**
> **Headline:** Akshara has a **good scaffold but a hollow core.** The pieces of intelligence (a syllabus model, a clean AI pipeline with RBAC, a real marks-approval lifecycle) exist — but the question-generation core is **fake**, there is **no real LLM**, and the **syllabus is not wired as the AI boundary**. The vision is achievable and well-designed on paper (`ACADEMIC_ASSESSMENT_PLATFORM_DESIGN.md`, currently DEFERRED) — it is simply unbuilt.

---

## 1. What exists today (verified in code)

### Two disconnected exam subsystems
1. **Education suite** (`lib/features/education/`, `lib/core/repositories/.../education/`) — question bank + paper generation.
   - Real models: `QuestionBankItem` (subject, chapter, topic, difficulty, type, marks, options, status), `QuestionPaperSummary/Detail/Item`.
   - **Generation is a stub:** `generateQuestionPaper` takes the first 2 bank items and appends 1–2 hardcoded `"AI generated: <subject> — <chapter>"` long-answer items with answer "Sample model answer" (`mock_education_repository.dart:126-193`). The "blueprint" is a hardcoded map. No solver, no dedup, no difficulty buckets.
   - Coarse RBAC only (`viewEducation`/`manageEducation`); paper states only `draft`/`published`; **no moderation/approval gate.**
2. **Exam administration** (`lib/core/exams/`, `lib/features/academics/exam_admin/`) — the *real* one.
   - `exam_administration_store.dart`: create → marks-entry → **approval-gated publish**, coordinator verification, rejection comments. Good governance pattern.
   - **But it shares nothing with the question bank/paper suite.** Marks and questions live in separate worlds.

### AI layer — well-structured but simulated
- `lib/core/ai/` has a real `AiInferencePipeline` (cache + RBAC gate + telemetry + provider selection). Genuinely good architecture.
- **Every provider is fake:** `EdgeAiProvider` explicitly "Simulated live inference" returning hardcoded markdown; `StubAiProvider` canned strings. Search for `openai|anthropic|gpt-|claude-|gemini` → **zero** real clients.
- **The question-paper flow doesn't even use the pipeline** — it bypasses it entirely. So there are **no prompt constraints, no syllabus-bounding, no JSON schema, no temperature control.**

### Syllabus taxonomy — exists, but not an AI boundary
- `lib/features/school_completion/school_completion_models.dart`: `SubjectTemplate` (board, subject, grade, chapters), `SyllabusTemplateChapter` (name + topics), `SyllabusChapter` (year, subject, class, sequence).
- **But:** it stops at Chapter→Topic (no Learning Outcome, no Bloom, no exam-pattern, no Foundation/Board program dimension), and **nothing connects it to questions or AI.** `GenerateQuestionPaperRequest` passes free-text `chapters: List<String>`, not validated syllabus IDs.

## 2. Gap to the vision

| Vision pillar | Today | Gap |
|---------------|-------|-----|
| Question bank | Real model + CRUD; flat schema | No provenance/source, no learning outcome, no cognitive level, no usage/quality scoring |
| **Syllabus as AI boundary** | Taxonomy exists, **unwired** | The "AI must never leave Board→Class→Subject→Chapter→Topic→Outcome" guarantee is **architecturally absent** — no scope token passed to any AI call, no validator |
| Blueprint engine | Hardcoded `{mcq:1, long:N}` | No deterministic solver for marks/type/difficulty/portion allocation |
| Previous-year papers (PYQ) | **Absent** (0 hits) | Entire domain missing |
| Bloom taxonomy / learning outcomes | **Absent** | Not in any model |
| Answer keys / multi-set papers | Untyped key; **no multi-set** | No A/B/C shuffling, no per-set keys |
| Question moderation | **Absent** (draft/published only) | Needs review queue + RBAC actions |
| Difficulty tagging | Single enum | No HOTS/case-study; no per-paper difficulty mix |
| **Foundation programs** (IIT/JEE/NEET/Olympiad/NTSE) | **Absent** | No exam-pattern model, no competitive blueprint |
| Analytics | Mock-fed shapes only | No item analysis (p-value/discrimination); not tied to topic mastery |
| Teacher = final authority | Marks side gated ✅; question side **ungated** | Extend governance to question/paper lifecycle |
| Real AI | Simulated only | No live, constrained LLM anywhere |

## 3. The differentiator: "Generator" vs "Intelligence Platform"

theprashna and similar tools are **generators**: pick chapters → produce a paper. To be *significantly stronger*, Akshara should be an **intelligence platform** built on three ideas the benchmark lacks:

1. **The syllabus is a hard, typed boundary.** AI can only retrieve/generate within an explicit scope (Board → Class → Subject → Chapter → Topic → Learning Outcome → Difficulty → Exam Type). Every generated item is validated against that scope and rejected if it strays. This is a *correctness guarantee*, not a feature.
2. **Bank-first, AI-as-candidate.** The system prefers approved bank/PYQ questions; AI only fills *gaps*, and AI output lands as **candidates in a moderation queue** — never auto-published. Teacher is final authority, enforced by the same approval pattern already proven in `exam_administration_store.dart`.
3. **Closed feedback loop (the real moat).** Real marks → item analytics (difficulty, discrimination) → chapter/outcome weakness per student and per class → next paper's blueprint adapts. A generator produces papers; an *intelligence platform* learns which questions teach and which students struggle, and feeds that back. **No competitor does this well because it requires owning the whole chain (syllabus + bank + exam + marks + analytics) — which Akshara already owns the pieces of.**

## 4. Target architecture (design only — no code now)

```
SYLLABUS LIBRARY (typed, the boundary)
  Board/Program → Class → Subject → Chapter → Topic → Learning Outcome
        │ (every question & paper references these as IDs, not free text)
        ▼
QUESTION BANK ──┬── Teacher-authored (approved)
  + provenance  ├── Imported / textbook
  + Bloom level ├── PYQ store (school/public/foundation/competitive, tagged)
  + difficulty  └── AI-candidate (queued, never auto-published)
        │
        ▼
BLUEPRINT ENGINE (deterministic solver: marks/type/difficulty/portion, multi-set, dedup)
        │            ↑ constrained by syllabus scope + exam pattern
        ▼
CONSTRAINED AI (gap-fill only): syllabus-scoped context · strict JSON schema · low temp · → moderation queue
        │
        ▼
MODERATION (teacher = final authority) → PUBLISH (approval-gated, reuse exam store pattern)
        │
        ▼
EXAM → MARKS (existing real lifecycle) → ITEM ANALYTICS → MASTERY/WEAKNESS → feeds next BLUEPRINT
```

## 5. Recommendations (priority-ordered)

1. **Make the syllabus a typed, referenceable boundary.** Promote chapters/topics to IDs; add `LearningOutcome` + `Board/Program` dimension (CBSE/ICSE/State + Foundation: JEE/NEET/NTSE/Olympiad). Every question references syllabus IDs.
2. **Unify the two exam subsystems.** Bridge `lib/core/exams/` (marks + approval) with `lib/features/education/` (bank + papers) so analytics can attribute weakness to topics/outcomes.
3. **Build the deterministic blueprint engine** (rule-based, not AI): marks/type/difficulty/portion allocation, dedup via fingerprint, multi-set generation, per-set answer keys.
4. **Add a real moderation layer + fine-grained RBAC** (`manageQuestionBank`, `approveQuestionPaper`, `publishQuestionPaper`); add provenance to every question; AI items are candidates only.
5. **Wire one real, constrained LLM behind `AiInferencePipeline`** (gap-fill only, syllabus-scoped, JSON schema, low temp); make the education flow actually call the pipeline (it currently bypasses it).
6. **Add PYQ store + item analytics + Bloom tagging** — the true differentiators.
7. **Add foundation-program patterns** (IIT/JEE/NEET/Olympiad/NTSE blueprints + question types).
8. **Correct the status docs** — treat `AI_INTELLIGENCE_AUDIT.md` (honest) as the baseline, not the optimistic `AI_COPILOT_STATUS.md`.

## 6. Is this worth it? — Yes, but sequence it

Question Intelligence is Akshara's **best differentiator** and aligns with the Indian market (board exams, foundation/competitive prep). **But it must come *after* the school product is real** (durable data, working basic exam chain, server backend). Build the boundary + bank + blueprint (deterministic, no AI risk) first; add constrained AI last. That order de-risks it: even with zero AI, a syllabus-bounded bank + blueprint engine + analytics already beats a plain generator.

**Effort:** this is a multi-month program, not a feature. Scope it as its own track *after* "make it real for one school" (see `ROADMAP_REVIEW.md` Phase 3 and `FIRST_10_SCHOOLS_STRATEGY.md`).

**Bottom line:** Akshara is one good design doc and a focused build away from a category-defining product — but today the "intelligence" is simulated. The fastest credible path is **deterministic intelligence first (syllabus boundary + bank + blueprint + analytics), constrained AI second.**
