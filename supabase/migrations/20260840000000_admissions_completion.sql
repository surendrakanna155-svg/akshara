-- Admissions completion — unblocked B1 items.
-- Additive only. No admission-number scheme change (ADM-D3 deferred), no
-- approval Separation-of-Duties change (deferred).
--
-- Covers:
--   #1  Enrollment idempotency: a partial unique index on
--       admissions_enrollments(application_id) so a double-click / retry on an
--       approved application can never mint a SECOND student + admission number
--       + fee handoff. application_id is nullable (walk-in enrollments have no
--       application), so a partial index — not a table constraint — is used.
--   #4  ADM-D1 mark-lost reason: a nullable lost_reason column on
--       admissions_leads (small fixed picklist enforced in the repo layer:
--       fees_high | competitor | distance | other).

-- ─── #1 Enrollment idempotency backstop ──────────────────────────────────────
-- One admissions_enrollment per application. Partial (WHERE application_id IS
-- NOT NULL) so multiple null-application walk-in enrollments remain allowed.
-- The repository also guards with a SELECT ... FOR UPDATE lock anchor before
-- inserting; this index is the concurrency-safe backstop that turns a racing
-- double-submit into a 23505 the repo maps to the idempotent existing row.
CREATE UNIQUE INDEX IF NOT EXISTS admissions_enrollments_application_uniq
  ON admissions_enrollments (application_id)
  WHERE application_id IS NOT NULL;

-- ─── #4 ADM-D1 lost-reason ───────────────────────────────────────────────────
-- Nullable; only set when a lead is moved to stage='lost'. Value is validated
-- against the fixed picklist in the repository (markLeadLost).
ALTER TABLE admissions_leads
  ADD COLUMN IF NOT EXISTS lost_reason TEXT;
