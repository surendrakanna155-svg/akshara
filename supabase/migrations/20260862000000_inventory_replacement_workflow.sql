-- Gap-sweep 2 · Step 4 (#2) — Inventory Replacement approval workflow.
--
-- Reuses inv_student_distributions (no parallel table): the row that already
-- tracks the physical item now also carries an RMA-style approval sub-state
-- (pending -> approved -> fulfilled, or -> rejected) independent of its own
-- lifecycle `status`. `replacement_of_id` (already present since the v9.7
-- foundation migration) links the newly-issued replacement item back to the
-- original distribution once fulfilled.

ALTER TABLE inv_student_distributions
  ADD COLUMN replacement_status TEXT
    CHECK (replacement_status IN ('pending', 'approved', 'fulfilled', 'rejected')),
  ADD COLUMN replacement_requested_at TIMESTAMPTZ,
  ADD COLUMN replacement_resolved_at TIMESTAMPTZ,
  ADD COLUMN replacement_rejection_reason TEXT;

-- Fast lookup for the replacements workflow list (pending/approved/fulfilled/
-- rejected tabs), scoped per-tenant like every other query on this table.
CREATE INDEX idx_inv_student_dist_replacement_status
  ON inv_student_distributions (organization_id, school_id, replacement_status)
  WHERE replacement_status IS NOT NULL;
