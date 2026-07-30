-- Living Dashboard Phase 4 — user pins.
-- Design: docs/design/living-dashboard/LIVING_DASHBOARD_ARCHITECTURE.md §3.4.
--
-- Adaptive-AI design doc 04 §5 states the anti-disorientation rule plainly:
-- "user pins always win". A dashboard that reorders itself is only tolerable if
-- the user can nail down the thing they are working on, so a pin must outrank
-- BOTH the score and the lifecycle overlay:
--
--   · a pinned item sorts above every unpinned one, whatever its score;
--   · a pinned item is never hidden by an acknowledge or a snooze — pinning is
--     the user saying "keep this in front of me", and honouring that matters
--     more than obeying an earlier, weaker signal.
--
-- Stored on the existing per-(user, item) row rather than a new table: pinning
-- is one more thing this user has decided about this item, and putting it beside
-- the lifecycle state keeps the feed's read path to a single query.

ALTER TABLE dashboard_item_state
  ADD COLUMN IF NOT EXISTS pinned BOOLEAN NOT NULL DEFAULT false;

-- The feed reads every row for a user anyway, so this exists for the analytics
-- question "which items do people pin?" rather than for the hot path.
CREATE INDEX IF NOT EXISTS idx_dashboard_item_state_pinned
  ON dashboard_item_state (organization_id, school_id, user_id)
  WHERE pinned;

COMMENT ON COLUMN dashboard_item_state.pinned IS
  'Living Dashboard: user pinned this item to the top of their feed. Outranks '
  'both the priority score and any acknowledge/snooze — see item_lifecycle.ts.';
