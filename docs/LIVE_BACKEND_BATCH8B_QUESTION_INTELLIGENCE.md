# Batch 8b — Question Intelligence foundation (bank-first + constrained AI)

**Branch:** `feature/scope-trim-school-build`
**Scope decision (owner):** Backend-complete this batch; Flutter moderation /
syllabus-picker UI deferred to **Batch 8c**.
**Provider:** Claude (Anthropic), reusing the Batch 8 shared client.

Implements the bank-first half of `docs/plans/QUESTION_PAPER_FOUNDATION_MASTER_PLAN.md`
(Phase 1 foundation) plus the constrained-AI gap-fill (Phase 5) that the plan
gates behind the bank. The old paper generator fabricated questions with template
strings ("Explain {topic} in 3–4 sentences") and silently mixed them into papers.
That stub path is removed.

## What changed

### 1. Schema — `20260710000000_education_question_intelligence.sql`
All ALTERs are additive with safe defaults; existing rows stay valid.

- **`edu_question_bank_items`** gains provenance + syllabus linkage + dedup:
  `source` (`teacher|school|import|pyq|publisher|ai_candidate`, default `teacher`),
  `source_reference`, `program_track` (`board|jee_foundation|neet_foundation|ntse|olympiad`),
  `jee_question_type`, `cognitive_level` (Bloom), `syllabus_chapter_id` /
  `syllabus_topic_id` (FK → real `syllabus_chapters` / `syllabus_topics`),
  `learning_outcome`, `fingerprint` (dedup hash), `review_status`
  (`pending|approved|rejected`, default `approved`). Two new indexes (fingerprint
  lookup, selection filter).
- **`edu_question_papers`** gains governance: `program_track`, `review_status`
  (`draft|submitted|changes_requested|approved|published|archived`),
  `submitted_by/at`, `approved_by/at`. Existing published/archived rows are
  back-filled into the new lifecycle column.
- **`edu_question_paper_items`**: `source` CHECK widened to include
  `ai_candidate`; new `review_status` (`pending|approved|rejected`).
- **New `edu_question_paper_reviews`** — per-round governance trail (RLS
  school-scoped, SELECT/INSERT to `erp_tenant`).

### 2. Deterministic blueprint solver — `education_blueprint_solver.ts`
Pure, no DB/network/randomness. Builds a fixed slot plan whose per-slot marks sum
**exactly** to `totalMarks`, then fills it **bank-first** (exact type + marks
match, difficulty match unless mixed, approved+active only, deduped by id and
fingerprint). Slots it can't fill become precise **gaps** (exact type / difficulty
/ marks / chapter). Replaces the old greedy `pickBankItems` + stub-fill.

### 3. Constrained AI gap-fill — `education_ai_question_gapfill.ts`
Claude authors **only** the gap slots, strictly inside the syllabus scope
(subject / class / chapters — **no student data**). Output is **moderation
candidates**: `source='ai_candidate'`, `review_status='pending'`. Every candidate
is validated (type must match the gap, marks must match, MCQ must carry its
correct option, non-empty text/answer) — invalid ones are dropped, leaving the
gap unfilled. **Safe-by-default** (same contract as Batch 8): no key / refusal /
bad JSON / transport error → zero candidates, never a fabricated question.

### 4. Paper service — `education_question_paper_service.ts` (rewritten)
Bank-first → gaps → (optional) AI candidates. Paper is always created
`review_status='draft'`. **No placeholder/stub text is ever written into a paper.**
The response now reports `aiCandidateCount`, `unfilledGapCount`, and the `gaps`
list. `allowAiGapFill` (default true) and `programTrack` are new request fields.

### 5. Governance + publish gate
New endpoints (all under `/education/question-papers`):
- `POST /{id}/submit` — draft/changes_requested → submitted (+ review row).
- `POST /{id}/review` — `{decision: approved|changes_requested, comments}`.
- `GET  /{id}/reviews` — the review trail.
- `POST /{id}/items/{itemId}/moderate` — `{decision: approved|rejected}` for AI
  candidates.

**Publish gate** (`publishQuestionPaper`): (1) **hard, always** — any pending AI
candidate blocks publish (`409 PAPER_HAS_PENDING_ITEMS`); (2) if a review is in
flight (submitted/changes_requested), the paper must reach `approved` first
(`409 PAPER_NOT_APPROVED`). A plain draft with **no** pending AI candidates still
publishes directly — so existing 100%-bank flows are unaffected until the 8c UI.

### 6. Import dedup
`importQuestionBankItems` now dedups by fingerprint within the school (skips
duplicates gracefully, returns `skippedDuplicates` count) — never a hard failure.

### 7. Provenance plumbed through
`createQuestionBankItem` computes and stores the fingerprint and accepts all
provenance/syllabus fields. Mapper exposes them. Audit catalog gains
`questionPaperSubmitted`, `questionPaperReviewed`, `questionPaperItemModerated`.

## Safety properties (production bar)
- No `ANTHROPIC_API_KEY` → generation is pure bank-first; gaps are reported, not
  faked; papers publish as before. Nothing fabricated.
- With a key → AI fills gaps as **candidates only**; they cannot reach students
  until a human approves each one (hard publish gate). AI prompt carries
  class-level syllabus scope only — no student data.

## Certification
- `deno check` clean on `api/index.ts` + all new/changed files + test files.
- `deno test` — 26 education tests pass (16 new: fingerprint ×3, solver ×6,
  gap-fill ×7; existing generator ×6 + router ×4 still green). All network-free
  (fetch stubbed). Run with `--allow-net --allow-env`.
- No Dart changed (API responses additive; Dart ignores unknown keys), so the
  Flutter app and `flutter analyze` are unaffected.

## NOT done here (Batch 8c)
- Flutter UI: syllabus chapter/topic picker on bank create; AI-candidate
  moderation queue; submit/review/approve buttons; gaps/“N marks unfilled” banner.
- Merging an approved AI candidate back into the reusable bank (needs the 8c edit
  UI to set chapter/difficulty before merge — deliberately not half-done here).
- Diagram/LaTeX assets, DPP scheduler, PYQ store, item analytics (later phases).

## Deploy (when scheduled)
Migration + edge are NOT yet on the VPS. Apply
`20260710000000_education_question_intelligence.sql` via psql as `supabase_admin`,
`NOTIFY pgrst, 'reload schema'`, then redeploy the edge container. AI gap-fill
only activates once `ANTHROPIC_API_KEY` is set (the Batch 8 deploy step).
