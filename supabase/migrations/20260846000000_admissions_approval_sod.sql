-- Admissions approval Separation-of-Duties (maker-checker).
-- Additive only. Implements the SoD change deferred in 20260840000000.
--
-- Owner-approved (2026-07-03): the person who SUBMITTED an admissions
-- application (the "maker") must NOT be the same person who APPROVES it (the
-- "checker"), because approval creates a fee handoff (a payable) — a money-path
-- separation-of-duties gap. This mirrors the FIN-D4 / generic-approval SoD
-- guard (approval_repository.decideApproval: requester_id === actorId → 409).
--
-- Columns added:
--   • admissions_applications.submitted_by — the maker: the user who moved the
--     application draft → submitted (populated in the repo on submitApplication).
--     Nullable so pre-existing rows (submitted before this migration) stay valid;
--     the SoD guard only fires when the column is populated, exactly like the
--     inventory maker_id / FIN-D4 requester_id guards (maker_id && maker===checker).
--   • admissions_approvals.decided_by / decided_at — the checker + when: recorded
--     on the approval decision (approve/reject), matching decided_by_id/decided_at
--     on the generic approval_requests table.

ALTER TABLE admissions_applications
  ADD COLUMN IF NOT EXISTS submitted_by UUID REFERENCES users (id);

ALTER TABLE admissions_approvals
  ADD COLUMN IF NOT EXISTS decided_by UUID REFERENCES users (id);

ALTER TABLE admissions_approvals
  ADD COLUMN IF NOT EXISTS decided_at TIMESTAMPTZ;
