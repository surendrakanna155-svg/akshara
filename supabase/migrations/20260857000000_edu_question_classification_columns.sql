-- CI-C4-schema (Curriculum Intelligence) — outcome/competency tagging columns +
-- forward-reference placeholders for question-family / concept linkage.
--
-- GAP_ANALYSIS A1-2 (Curriculum Boundary Engine v2 — competency dimension,
-- alongside the existing `learning_outcome` column from migration
-- 20260710000000) + A1-5 (question-family / concept-ID tagging columns on bank
-- items — CI-C10 "soft: CI-C4 (family/tag columns)" dependency).
--
-- DORMANT + additive-only: three nullable columns, zero data seed, zero
-- backfill, zero required-field enforcement (B11 in BACKWARD_COMPATIBILITY_PLAN:
-- legacy rows are grandfathered, generation never requires these fields —
-- invariant I1 unaffected). Existing rows are untouched; this is a metadata-only
-- ALTER (no NOT NULL, no default beyond NULL, no table rewrite).
--
-- `competency` mirrors `learning_outcome` exactly: free-text, teacher-confirmed.
-- The Tier-1 rule-first classifier (`education_question_classifier.ts`, this
-- wave) only ever SUGGESTS a value in memory — it has zero DB access and never
-- writes; a value lands here only when a teacher confirms it through
-- `updateQuestionBankItem` (D3 doctrine: rule-first, AI-suggest later,
-- teacher-confirm always — never auto-write, mirrors the AI gap-fill
-- candidate-only contract, invariant I3).
--
-- `question_family_id` / `concept_id` are schema-only placeholders: their
-- referenced tables do not exist yet (`edu_question_families` lands with
-- CI-C10/B12; the canonical concept graph lands with CI-E1b) — no code path
-- reads or writes them in this wave. This is the SAME loose-reference pattern
-- already certified by the E1a dormant seed (20260853000000):
-- `edu_student_item_responses.bank_item_id` / `edu_item_exposures.bank_item_id`
-- are plain UUID columns with no FK, and the real FOREIGN KEY constraint gets
-- added later, by the migration that creates the referenced table — never
-- before. Following that precedent here rather than inventing a second pattern.
--
-- Certified RLS/grants on `edu_question_bank_items` are unchanged; this
-- migration adds columns only.

ALTER TABLE edu_question_bank_items
  ADD COLUMN competency TEXT,
  ADD COLUMN question_family_id UUID,
  ADD COLUMN concept_id UUID;
