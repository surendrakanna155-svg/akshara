-- ICA-A3 (P1) — receipt-number uniqueness must be scoped per (org, school), not
-- global, so a shared default prefix cannot block a second school's first
-- collection.
--
-- Root cause: finance_receipts.receipt_number was created inline as
-- `TEXT NOT NULL UNIQUE` (20260612500000_finance_slice4_collections.sql:30),
-- which Postgres backs with the auto-named constraint
-- `finance_receipts_receipt_number_key` — a GLOBAL uniqueness with no org/school
-- discriminator. The gapless per-(org, school, fiscal-year) receipt sequence
-- (finance_collections_repository.allocateReceiptNumber) formats
-- `{prefix}/{FY}/{NNNNNN}` where the counter restarts at 1 per school and the
-- prefix historically defaulted to a shared literal ("RCP"). Two schools in one
-- org sharing that default prefix + fiscal year therefore both generate the SAME
-- first number (RCP/2026-27/000001); the second school's first finance_receipts
-- INSERT raises a duplicate-key violation and the whole collection transaction
-- rolls back — that school can never record its first payment. (Gated behind the
-- default-off `receipts.receipt_sequencing` flag, so LATENT — fixed here BEFORE
-- it is enabled for any multi-school org.)
--
-- Fix: drop the global UNIQUE and re-scope uniqueness to
-- (organization_id, school_id, receipt_number). Each school keeps its own
-- receipt-number namespace, so two schools' identical human numbers no longer
-- collide, while a genuine in-school duplicate is still rejected.
--
-- Safety: the new key is a STRICT SUPERSET of the old one — any pair of rows that
-- was unique on receipt_number ALONE is still unique on
-- (organization_id, school_id, receipt_number), so NO existing row can violate the
-- new index and the DROP -> CREATE never fails on live data. Already-issued
-- receipts (legacy random `RCPT-<year>-<uuid>` numbers) are untouched — no
-- backfill, no rewrite. Forward-only, additive, idempotent (IF EXISTS /
-- IF NOT EXISTS). No new grants/RLS — the index rides the existing
-- finance_receipts privileges + school-scope policy.
--
-- The application also embeds each school's UNIQUE `code` into the default receipt
-- prefix (finance_collections_repository.ts) so numbers stay human-distinct across
-- schools; this DB invariant makes correctness independent of that string.

ALTER TABLE finance_receipts
  DROP CONSTRAINT IF EXISTS finance_receipts_receipt_number_key;

CREATE UNIQUE INDEX IF NOT EXISTS finance_receipts_org_school_receipt_number_key
  ON finance_receipts (organization_id, school_id, receipt_number);
