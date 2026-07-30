-- ICA-A2 (P0) — offline-instrument reconcile double-credit guard.
--
-- Root cause: two concurrent reconciles of one cheque/DD/PDC both read the
-- instrument as 'pending_reconciliation' (an unlocked SELECT), both pass the
-- reconciled-check, both post a collection, and both terminal UPDATEs succeed
-- (the old guard was `AND status <> 'bounced'`) → TWO collections for ONE
-- instrument (a double credit).
--
-- The application fix serializes reconciles on a FOR UPDATE row lock and tightens
-- the terminal write to `AND status = 'pending_reconciliation'` + throw-on-0-rows
-- (finance_offline_payments_repository.ts). This migration adds the DATABASE
-- invariant that makes "≤ 1 collection per instrument" un-bypassable even if the
-- application guard is ever regressed:
--
--   * finance_collections.offline_payment_id — the instrument a collection
--     settles (NULL for the normal collection-screen path; the reconcile path
--     stamps it).
--   * a PARTIAL UNIQUE index on that column (WHERE NOT NULL) — a second collection
--     for the same instrument raises a unique violation, which the reconcile /
--     createCollection path replays (idempotent) rather than double-crediting.
--
-- Forward-only, additive, idempotent (IF NOT EXISTS). No data backfill — existing
-- collections keep offline_payment_id = NULL and are unaffected by the partial
-- index. No new grants/RLS needed: the column rides the existing
-- finance_collections privileges + school-scope policy.

ALTER TABLE finance_collections
  ADD COLUMN IF NOT EXISTS offline_payment_id UUID REFERENCES finance_offline_payments (id);

CREATE UNIQUE INDEX IF NOT EXISTS finance_collections_offline_payment_uq
  ON finance_collections (offline_payment_id) WHERE offline_payment_id IS NOT NULL;
