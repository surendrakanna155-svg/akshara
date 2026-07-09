-- Gap-remediation wave, item #6 — Operations Hub Dismiss/Complete persistence.
--
-- buildOperationsHub (operations_hub_service.ts) synthesises criticalAlerts /
-- pendingActions from LIVE aggregate queries each call (fixed category ids
-- such as 'student-risk', 'inventory-replacement', 'fee-alerts', 'inv-pending',
-- 'inv-payment' — see operations_hub_service.ts). There was no backend for the
-- client's dismiss/complete buttons at all (404s), so this table gives those
-- actions somewhere real to land: one row per (school, item, day) records that
-- an admin dismissed an alert or completed a pending action FOR TODAY. The hub
-- is explicitly a "Daily Summary" (todayAttendance/todayCollections/...), so a
-- dismissal/completion is scoped to the calendar day the underlying aggregate
-- was computed for — if the same condition is still true tomorrow, a fresh
-- alert legitimately reappears; if it has resolved, it naturally stays gone.
CREATE TABLE operations_hub_item_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  -- Which collection the synthetic id belongs to; a dismissal only ever
  -- applies to an alert and a completion only ever applies to a pending
  -- action (enforced below), matching the two distinct client actions.
  item_type TEXT NOT NULL CHECK (item_type IN ('alert', 'action')),
  item_id TEXT NOT NULL,
  item_action TEXT NOT NULL CHECK (item_action IN ('dismissed', 'completed')),

  occurrence_date DATE NOT NULL DEFAULT (timezone('utc', now())::date),
  actor_id UUID NOT NULL REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT operations_hub_item_actions_kind_ck CHECK (
    (item_type = 'alert' AND item_action = 'dismissed')
    OR (item_type = 'action' AND item_action = 'completed')
  )
);

-- One live dismissal/completion per item per school per day; a repeat
-- dismiss/complete call is an idempotent refresh (see operations_hub_service.ts
-- dismissOperationsAlert/completeOperationsAction — INSERT ... ON CONFLICT).
CREATE UNIQUE INDEX uq_operations_hub_item_actions_item_day
  ON operations_hub_item_actions (organization_id, school_id, item_type, item_id, occurrence_date);

-- Read pattern used by buildOperationsHub: all of today's actions for a school.
CREATE INDEX idx_operations_hub_item_actions_lookup
  ON operations_hub_item_actions (organization_id, school_id, occurrence_date);

ALTER TABLE operations_hub_item_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE operations_hub_item_actions FORCE ROW LEVEL SECURITY;

CREATE POLICY operations_hub_item_actions_school_scope ON operations_hub_item_actions
  FOR ALL
  USING (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  )
  WITH CHECK (
    organization_id = app_current_tenant_id()
    AND app_current_scope() = 'school'
    AND school_id = app_current_school_id()
  );

GRANT SELECT, INSERT, UPDATE ON operations_hub_item_actions TO erp_tenant;
