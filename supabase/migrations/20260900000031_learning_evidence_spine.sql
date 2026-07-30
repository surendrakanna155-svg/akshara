-- EIP-6 (Learning Evidence spine) — ACTIVATE the dormant response spine.
--
-- Prior state: `edu_student_item_responses` (created DORMANT by
-- 20260853000000_e1a_dormant_response_trust_exposure_seed) existed with ZERO
-- callers — the E1a seam so that per-item response evidence "has somewhere to
-- land" once capture begins ("this data cannot be backfilled — the seam must
-- exist before capture begins"). This migration turns that seam into a LIVE,
-- governed evidence-capture spine: it is the FOUNDATIONAL prerequisite for W5
-- Assessment Intelligence (owner #15) and the contract EIP-7 (concept mastery)
-- consumes.
--
-- What this changes — ADDITIVE ONLY, no destructive change:
--   1. Four evidence columns the E1a seed did not carry (attempt_no, confidence,
--      hints_used, evidence_source, occurred_at). The certified E1a marks-grid
--      shape (capture_source, marks_awarded, is_correct, …) is UNCHANGED; the new
--      columns are additive and (except attempt_no/hints_used, which default) are
--      nullable, so the existing dormant seam stays byte-compatible. The table is
--      dormant (zero rows), so every NOT NULL DEFAULT / new CHECK validates
--      instantly with zero data impact.
--   2. A partial UNIQUE index that is the idempotency backstop of the evidence
--      lane: one row per (org, school, student, item, attempt, source). Replays of
--      the same attempt can never double-count; a genuinely new attempt (higher
--      attempt_no) is a distinct row. Scoped `WHERE evidence_source IS NOT NULL`
--      so it governs ONLY the new evidence lane and never the certified E1a
--      marks-grid rows (which leave evidence_source NULL). The existing
--      UNIQUE (org, school, exam_id, paper_item_id, student_id) constraint is
--      untouched — evidence rows key on the durable bank_item_id and leave
--      paper_item_id NULL, so they never collide with it.
--   3. A student-self RLS policy so a student-scope session may record + read its
--      OWN evidence (practice / homework self-attempts). The certified
--      `_school_scope` policy is untouched — teachers / principals (school scope)
--      still read every row in their school and school-scope producers
--      (marks-grid / OMR) still write. RLS combines same-command policies with OR,
--      so the two coexist. `student_id = app_current_student_id()` fences a
--      student to their own rows.
--
-- Grants: the E1a seed already GRANTed SELECT, INSERT to erp_tenant. The spine is
-- APPEND-ONLY evidence (no UPDATE, no DELETE) so that grant is exactly right and
-- is deliberately NOT widened here.

-- ── 1. Evidence columns ──────────────────────────────────────────────────────
ALTER TABLE edu_student_item_responses
  -- Monotonic attempt counter per (student, item, source). Attempt 1 = first try.
  ADD COLUMN IF NOT EXISTS attempt_no INT NOT NULL DEFAULT 1
    CHECK (attempt_no >= 1),
  -- Self-reported confidence, 0..100 (nullable — not every producer collects it).
  ADD COLUMN IF NOT EXISTS confidence SMALLINT
    CHECK (confidence IS NULL OR (confidence >= 0 AND confidence <= 100)),
  -- How many hints the student consumed before answering (nullable-safe default).
  ADD COLUMN IF NOT EXISTS hints_used INT NOT NULL DEFAULT 0
    CHECK (hints_used >= 0),
  -- The learning-evidence lane — DISTINCT from the existing technical
  -- `capture_source` (how the row was captured: OCR / manual / digital / import).
  -- Nullable so certified E1a marks-grid rows (which never set it) are unchanged;
  -- the evidence writer always sets it, and the idempotency index keys on it.
  ADD COLUMN IF NOT EXISTS evidence_source TEXT
    CHECK (evidence_source IS NULL OR evidence_source IN ('practice', 'homework', 'exam', 'omr')),
  -- When the interaction actually happened (distinct from captured_at = when it
  -- was recorded; for OMR these differ — occurred during the exam, captured at scan).
  ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ;

-- ── 2. Evidence idempotency backstop (partial: evidence lane only) ────────────
-- Identity of one evidence attempt = (org, school, student, item, attempt, source).
-- COALESCE on bank_item_id keeps the key well-defined (mirrors the certified
-- canonical_concepts_identity / edu_blueprint_templates_identity COALESCE style);
-- the evidence writer requires a non-null bank_item_id, so the zero-uuid sentinel
-- is never actually stored — it only makes the index total.
CREATE UNIQUE INDEX IF NOT EXISTS edu_student_item_responses_evidence_idem
  ON edu_student_item_responses (
    organization_id,
    school_id,
    student_id,
    COALESCE(bank_item_id, '00000000-0000-0000-0000-000000000000'::uuid),
    attempt_no,
    evidence_source
  )
  WHERE evidence_source IS NOT NULL;

-- Covering index for the per-item aggregate (item-analysis) read path.
CREATE INDEX IF NOT EXISTS edu_student_item_responses_item_evidence
  ON edu_student_item_responses (organization_id, school_id, bank_item_id)
  WHERE evidence_source IS NOT NULL;

-- Covering index for the per-student history + concept roll-up read path.
CREATE INDEX IF NOT EXISTS edu_student_item_responses_student_evidence
  ON edu_student_item_responses (organization_id, school_id, student_id, occurred_at)
  WHERE evidence_source IS NOT NULL;

-- ── 3. Student-self RLS: a student records + reads its OWN evidence ───────────
-- Additive to the certified `edu_student_item_responses_school_scope` (which is
-- left exactly as-is). A student-scope session is fenced to its own student_id.
DROP POLICY IF EXISTS edu_student_item_responses_student_self ON edu_student_item_responses;
CREATE POLICY edu_student_item_responses_student_self ON edu_student_item_responses
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'student'
    AND school_id = app_current_school_id()
    AND student_id = app_current_student_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'student'
    AND school_id = app_current_school_id()
    AND student_id = app_current_student_id()
  );
