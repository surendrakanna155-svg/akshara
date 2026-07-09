-- Gap-remediation wave · P0-3 — Inventory Replacement RLS/payment consistency.
--
-- `requestReplacement()` (inventory_distribution_repository.ts) is reachable by
-- BOTH staff (scope='school') AND the item's own parent/guardian (scope=
-- 'parent') — see `handleRequestReplacement`'s explicit
-- `if (auth.claims.scope !== "parent") { requireDistWrite(...) }` bypass. Under
-- a parent session it: (1) SELECTs the distribution (allowed by the existing
-- `inv_student_dist_parent_read` policy), (2) INSERTs a `payment_request` when
-- the item isn't free (allowed by `payment_requests_parent_scope`), then
-- (3) UPDATEs `inv_student_distributions` to flip `status`/`replacement_status`.
--
-- Step 3 had NO parent-scope policy at all — only the school-only
-- `inv_student_dist_school_scope` FOR ALL policy existed for writes. Postgres
-- does not error on an UPDATE whose RLS predicate excludes every row; it just
-- returns 0 rows. The repository's `updated[0]!` masked that at compile time
-- only (a `!` non-null assertion has no runtime effect), so a parent-initiated
-- replacement could commit a real payment_request while the distribution's
-- own status/replacement_status silently never moved — an orphaned payment
-- pointing at a distribution the staff-facing replacements queue (which
-- filters `WHERE replacement_status IS NOT NULL`) would never surface.
--
-- Fix (paired with the `inventory_distribution_repository.ts` change that
-- makes the same UPDATE throw instead of silently swallowing a 0-row result,
-- so the enclosing `withTenantContext` transaction rolls back the
-- payment_request together with the failed status change): grant the parent
-- exactly the one legitimate transition they can reach through
-- `requestReplacement()` — nothing else. Every other replacement-lifecycle
-- transition (approve/fulfill/reject) and every other distribution status
-- (distributed/lost/damaged/reissued/...) remains staff-only via the
-- untouched `inv_student_dist_school_scope` FOR ALL policy. Purely additive:
-- no existing policy is dropped or altered.
CREATE POLICY inv_student_dist_parent_request_replacement
  ON inv_student_distributions
  FOR UPDATE
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    -- Not already mid-replacement — one open request at a time per item.
    AND replacement_status IS NULL
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_user_id()
        AND sg.organization_id = app_current_tenant_id()
        AND sg.status = 'active'
    )
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'parent'
    -- Exactly the two outcomes requestReplacement() can produce: 'pending'
    -- with status flipped to 'replacement_requested' (free item) or
    -- 'payment_pending' (paid item, payment_request created alongside).
    AND replacement_status = 'pending'
    AND status IN ('replacement_requested', 'payment_pending')
    AND student_id IN (
      SELECT sg.student_id
      FROM student_guardians sg
      WHERE sg.guardian_user_id = app_current_user_id()
        AND sg.organization_id = app_current_tenant_id()
        AND sg.status = 'active'
    )
  );
