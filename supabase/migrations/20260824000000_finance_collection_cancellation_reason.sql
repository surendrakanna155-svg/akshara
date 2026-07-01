-- FIN-D3 — Receipt/collection cancellation reason + cancelled register.
--
-- A cancelled fee collection had no recorded reason and no cancelled-by/at
-- trail, so the "cancelled register" a cashier/auditor needs (who cancelled a
-- receipt, when, and why) could not be produced. These columns are ADDITIVE and
-- do NOT change the existing cancellation payment-reversal math in
-- cancelCollection() — they only capture the mandatory reason + actor + time.
--
-- All columns are nullable (existing rows have no reason); the API layer REQUIRES
-- a non-empty reason on new cancellations (422 before any DB write). RBAC is the
-- existing finance gate (manageFinance to cancel, viewFinance to read the
-- register); no new permission is introduced.

ALTER TABLE finance_collections
  ADD COLUMN cancellation_reason TEXT,
  ADD COLUMN cancelled_by UUID REFERENCES users (id),
  ADD COLUMN cancelled_at TIMESTAMPTZ;

-- Index the cancelled register lookup (status='cancelled' ordered by when).
CREATE INDEX idx_finance_collections_cancelled
  ON finance_collections (organization_id, school_id, cancelled_at DESC)
  WHERE collection_status = 'cancelled';
