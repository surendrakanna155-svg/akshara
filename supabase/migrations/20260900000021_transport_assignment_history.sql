-- W4 — Transport assignment history (Owner decision #5, FINAL/approved):
-- FULL history preservation via Valid-From / Valid-To effective dating.
-- A student's transport assignment must NEVER be overwritten-in-place; the
-- system must be able to reconstruct which route/stop a student rode as-of ANY
-- past date.
--
-- WHERE ASSIGNMENTS LIVE TODAY
--   A student↔route/stop allocation is a JSONB row in the generic
--   transport_entities store (entity_type='allocation', PK
--   (organization_id, school_id, entity_type, id), the id being the stable
--   enrolment id referenced by demands.allocationId, the roster read, and the
--   transfer/stop handlers). Every re-assignment / transfer / stop UPDATEs that
--   single row in place (writeStore.replace), so the prior route/stop is
--   destroyed — exactly the history loss this decision forbids.
--
-- DESIGN — a dedicated, append-only effective-dated timeline table (NOT temporal
-- fields crammed onto the opaque allocation payload):
--   * transport_entities.allocation stays the denormalized "current pointer"
--     the rest of the module already reads (roster / occupancy / demand-revoke).
--     It is UNTOUCHED here — zero risk to existing behaviour.
--   * transport_allocation_history is the SOURCE OF TRUTH for history: one
--     IMMUTABLE row per assignment period, keyed on allocation_id (the stable
--     enrolment id — route changes ride the SAME id, so its timeline IS the
--     student's route history) with sis_student_id denormalized for per-student
--     timeline reads. valid_from = when the period opened; valid_to = when it
--     was superseded (NULL = the currently-open period). A change CLOSEs the open
--     row (stamps valid_to once) and INSERTs a fresh open row — the historical
--     route/stop snapshot is never mutated.
--   * Real typed valid_from/valid_to TIMESTAMPTZ columns give clean as-of range
--     queries and a proper supporting index — a JSONB payload cannot.
--   * PARTIAL UNIQUE INDEX on (org, school, allocation_id) WHERE valid_to IS NULL
--     is the DB-level terminal-write guard: at most ONE open period per
--     allocation can ever exist, so two concurrent re-assignments cannot
--     double-open — the losing INSERT raises 23505 (mirrors the existing
--     transport_entities_demand_dedupe_key_uniq money-race backstop). The
--     repository catches it in a SAVEPOINT and rejects the racing double-open.
--   * Reuses the EXACT transport_entities RLS shape (org + scope='school' +
--     school) and erp_tenant grant conventions.
--   * GRANT SELECT, INSERT, UPDATE only — NO DELETE. History is append-only;
--     UPDATE exists solely to stamp valid_to when a period closes.

CREATE TABLE transport_allocation_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  -- Stable enrolment id (soft ref into transport_entities; that store's ids are TEXT).
  allocation_id TEXT NOT NULL,
  -- Denormalized for per-student "where did this child ride as-of date D" reads.
  sis_student_id TEXT,
  route_id TEXT,
  pickup_stop TEXT,
  drop_stop TEXT,
  shift TEXT,
  -- Full allocation snapshot captured at the moment this period opened (immutable).
  payload JSONB NOT NULL DEFAULT '{}',
  -- Effective dating. valid_to IS NULL ⇔ the currently-open period.
  valid_from TIMESTAMPTZ NOT NULL,
  valid_to TIMESTAMPTZ,
  changed_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  -- A period can only close at or after it opened.
  CONSTRAINT transport_allocation_history_valid_range
    CHECK (valid_to IS NULL OR valid_to >= valid_from)
);

-- Terminal-write guard: at most ONE open period per allocation per school.
-- A racing concurrent re-assignment that tries to open a second period raises
-- 23505 here (recovered/rejected in transport_allocation_history_repository.ts).
CREATE UNIQUE INDEX transport_allocation_history_open_uniq
  ON transport_allocation_history (organization_id, school_id, allocation_id)
  WHERE valid_to IS NULL;

-- As-of + timeline reads by allocation (valid_from <= d AND (valid_to IS NULL OR valid_to > d)).
CREATE INDEX idx_transport_allocation_history_asof
  ON transport_allocation_history (organization_id, school_id, allocation_id, valid_from, valid_to);

-- As-of + full-timeline reads by student.
CREATE INDEX idx_transport_allocation_history_student
  ON transport_allocation_history (organization_id, school_id, sis_student_id, valid_from, valid_to);

ALTER TABLE transport_allocation_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_allocation_history FORCE ROW LEVEL SECURITY;

-- Identical scope to transport_entities_school_scope: a school session sees/edits
-- only its own school's history; cross-school/cross-tenant rows are invisible.
CREATE POLICY transport_allocation_history_school_scope ON transport_allocation_history
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

-- SELECT, INSERT, UPDATE (to stamp valid_to on close) — deliberately NO DELETE
-- (append-only, immutable timeline). RBAC reuses the existing viewTransport
-- (read) + manageTransport (write) permissions — no new slug.
GRANT SELECT, INSERT, UPDATE ON transport_allocation_history TO erp_tenant;

-- ── Backfill: open the timeline for every existing allocation ────────────────
-- 1:1 with the current allocation rows (each allocation_id appears once in the
-- store, so this can never violate the open-period partial unique index):
--   * currently-riding students  → an OPEN period (valid_to NULL);
--   * already soft-stopped rows (payload.stoppedAt set by the DELETE/stop path)
--     → a CLOSED period at stoppedAt, so a stopped child does not read as still
--     riding when the timeline is reconstructed as-of today.
INSERT INTO transport_allocation_history
  (id, organization_id, school_id, allocation_id, sis_student_id, route_id,
   pickup_stop, drop_stop, shift, payload, valid_from, valid_to, changed_by, created_at)
SELECT
  gen_random_uuid(),
  te.organization_id,
  te.school_id,
  te.id AS allocation_id,
  NULLIF(te.payload ->> 'sisStudentId', ''),
  NULLIF(te.payload ->> 'routeId', ''),
  NULLIF(te.payload ->> 'pickupStop', ''),
  NULLIF(te.payload ->> 'dropStop', ''),
  NULLIF(te.payload ->> 'shift', ''),
  te.payload,
  te.created_at AS valid_from,
  CASE
    WHEN COALESCE(te.payload ->> 'stoppedAt', '') <> ''
      -- GREATEST clamps to valid_from so a same-day stop (stoppedAt is a bare
      -- date → 00:00) can never land before created_at and trip the range CHECK.
      THEN GREATEST(te.created_at, (te.payload ->> 'stoppedAt')::timestamptz)
    ELSE NULL
  END AS valid_to,
  NULL::uuid,
  te.created_at
FROM transport_entities te
WHERE te.entity_type = 'allocation';
