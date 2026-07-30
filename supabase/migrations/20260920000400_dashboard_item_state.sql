-- Living Dashboard — per-user item lifecycle state.
-- Design: docs/design/living-dashboard/LIVING_DASHBOARD_ARCHITECTURE.md §3.2.
--
-- WHAT THIS REPLACES
-- ------------------
-- Until now the ONLY record of "the user put this away" was
-- `ai_persona_memory.preferences.dismissedKeys` — an unbounded JSONB string
-- array in a single row per user, carrying no timestamp, no actor, no expiry and
-- no severity baseline, never pruned. Combined with the engine filtering those
-- keys out BEFORE scoring, a dismissal was permanent and irreversible: an item
-- dismissed at "8 approvals overdue" stayed gone at 40, and no other surface
-- could learn it had been put away.
--
-- This table gives each (user, item_key) a real row so the deterministic
-- resolver in `_shared/intelligence/priority/item_lifecycle.ts` can decide when
-- work legitimately comes back.
--
-- SHAPE follows `operations_hub_item_actions` (20260865000000) — the existing
-- per-item action ledger whose `occurrence_date` trick already encodes "an
-- unresolved condition deserves attention again tomorrow".
--
-- RLS follows `legal_acceptances` (20260816000000), NOT the school-scoped
-- pattern. This is a genuinely per-user table, so the policy must NOT include
-- `app_current_scope() = 'school'`: that clause is for school-SHARED resources,
-- and copying it here is exactly the defect migration 20260873000000 had to
-- repair for `ai_persona_memory`, where it silently prevented parent and student
-- sessions from persisting their own dismissals.
--
-- NO SCHEDULER: snooze expiry and acknowledge day-rollover are resolved at READ
-- time against the caller's clock. Nothing here needs a cron, which matters
-- because defect XMOD-016 records nine periodic jobs in this repo with zero
-- schedulers actually installed.

CREATE TABLE dashboard_item_state (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  -- Nullable: org/director-scope users carry no school, same as legal_acceptances.
  school_id UUID REFERENCES schools (id),
  user_id UUID NOT NULL,

  -- Joins to RawPriorityItem.itemKey — the engine's stable identity for a
  -- real-world item (e.g. `risk:student:<uuid>`, `ops:finance:call_queue`).
  item_key TEXT NOT NULL,

  -- Informational: the feed item's type at action time. NULL for rows migrated
  -- from the legacy array, which recorded no type. Learned weights continue to
  -- live in ai_persona_memory.recommendation_feedback, so nothing reads this for
  -- scoring — it is for analytics and debugging only.
  item_type TEXT
    CHECK (item_type IS NULL OR item_type IN
      ('approval', 'deadline', 'exception', 'follow_up', 'opportunity')),

  state TEXT NOT NULL
    CHECK (state IN
      ('new', 'urgent', 'acknowledged', 'snoozed',
       'completed', 'expired', 'escalated', 'resolved')),

  -- Only meaningful while state = 'snoozed'.
  snoozed_until TIMESTAMPTZ,

  -- Severity watermark: the normalized 0-100 score when the user acted. NULL
  -- means "no baseline" (legacy migrated row) and the resolver then refuses to
  -- claim the item got worse, rather than fabricating a comparison.
  score_at_action INTEGER
    CHECK (score_at_action IS NULL OR (score_at_action BETWEEN 0 AND 100)),

  -- Deadline watermark: factors.dueInDays when the user acted. NULL = the item
  -- had no clock then (or, on legacy rows, unknown).
  due_at_action INTEGER,

  acted_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  actor_id UUID NOT NULL,

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  -- One lifecycle row per item per user. Upserted on every action.
  --
  -- NULLS NOT DISTINCT is load-bearing, not decoration. `school_id` is NULL for
  -- org/director-scope users, and under the default NULLS DISTINCT semantics
  -- Postgres considers two NULL school_ids unequal — so a director would
  -- accumulate a duplicate row on every action, `ON CONFLICT` would never fire,
  -- and the overlay's Map would arbitrarily pick one of them. Verified against
  -- both PG15 (supabase/config.toml) and PG17 (deploy image), where this clause
  -- is supported.
  UNIQUE NULLS NOT DISTINCT (organization_id, school_id, user_id, item_key),

  -- A snooze without an end is a permanent bury. The resolver fails open on a
  -- missing value, but the write path must never create one.
  CONSTRAINT dashboard_item_state_snooze_has_deadline
    CHECK (state <> 'snoozed' OR snoozed_until IS NOT NULL)
);

-- The feed read: every request loads this user's rows for the overlay pass.
CREATE INDEX idx_dashboard_item_state_user
  ON dashboard_item_state (organization_id, school_id, user_id);

-- Lets a snoozed-item sweep or analytics query skip the settled rows.
CREATE INDEX idx_dashboard_item_state_snoozed
  ON dashboard_item_state (organization_id, snoozed_until)
  WHERE state = 'snoozed';

CREATE TRIGGER dashboard_item_state_updated_at
  BEFORE UPDATE ON dashboard_item_state
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

ALTER TABLE dashboard_item_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE dashboard_item_state FORCE ROW LEVEL SECURITY;

CREATE POLICY dashboard_item_state_self ON dashboard_item_state
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  );

GRANT SELECT, INSERT, UPDATE ON dashboard_item_state TO erp_tenant;

-- ---------------------------------------------------------------------------
-- Backfill from the legacy array.
--
-- Every existing dismissal becomes an 'acknowledged' row with NULL watermarks —
-- honest, because the old array recorded no score or deadline to compare
-- against. The resolver treats a NULL score_at_action as "no baseline" and will
-- not claim such an item escalated; it still returns on the next IST day
-- boundary, so nothing stays buried forever.
--
-- The source keys are deliberately LEFT IN PLACE rather than deleted: this
-- migration is then reversible by simply pointing the feed service back at
-- ai_persona_memory, and the duplicate has no effect once the service stops
-- passing `dismissedKeys`.
-- ---------------------------------------------------------------------------
INSERT INTO dashboard_item_state (
  organization_id, school_id, user_id, item_key,
  state, score_at_action, due_at_action, acted_at, actor_id, created_at
)
SELECT
  m.organization_id,
  m.school_id,
  m.user_id,
  key.value #>> '{}'          AS item_key,
  'acknowledged'              AS state,
  NULL::INTEGER               AS score_at_action,
  NULL::INTEGER               AS due_at_action,
  COALESCE(m.updated_at, timezone('utc', now())) AS acted_at,
  m.user_id                   AS actor_id,
  COALESCE(m.created_at, timezone('utc', now())) AS created_at
FROM ai_persona_memory m
CROSS JOIN LATERAL jsonb_array_elements(
  CASE
    WHEN jsonb_typeof(m.preferences -> 'dismissedKeys') = 'array'
      THEN m.preferences -> 'dismissedKeys'
    ELSE '[]'::jsonb
  END
) AS key(value)
WHERE jsonb_typeof(key.value) = 'string'
  AND length(key.value #>> '{}') > 0
ON CONFLICT (organization_id, school_id, user_id, item_key) DO NOTHING;

COMMENT ON TABLE dashboard_item_state IS
  'Living Dashboard: per-user lifecycle for one priority-feed item. Visibility '
  'is resolved at read time by _shared/intelligence/priority/item_lifecycle.ts; '
  'no scheduler is involved. Supersedes ai_persona_memory.preferences.dismissedKeys.';
