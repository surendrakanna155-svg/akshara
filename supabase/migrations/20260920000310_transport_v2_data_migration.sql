-- BUS-030 — migrate transport_entities (JSONB) → Transport v2 relational tables.
--
-- THE HARD PART IS WHAT CANNOT MIGRATE CLEANLY.
--
-- Three classes of legacy data have no honest destination:
--   * stops have NO coordinates (the write path never accepted them), so there
--     is nothing to put in transport_stop.location;
--   * stop times are unparseable free text ("7:05 AM", "7.05", "0705", "morning"
--     all persisted, unvalidated);
--   * allocations reference stops by STRING, matched by exact equality, so
--     "Green Park Gate" / "Green park gate " may or may not be the same stop.
--
-- The wrong move — and the tempting one — is to default a missing coordinate to
-- (0,0). That would embed the audit's worst structural defect into the new
-- schema permanently and silently. Instead these rows land in an explicit
-- `needs_location` state that BLOCKS route publication (BUS-042), and every
-- unresolved item is written to a per-school reconciliation report for a human.
--
-- Idempotent (safe to re-run) and additive — transport_entities is READ ONLY
-- here and is not dropped until BUS-031, after Phases 3–6 read exclusively from
-- v2. That retention IS the rollback.

-- ── Reconciliation report ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS transport_migration_reconciliation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL,
  school_id UUID NOT NULL,
  entity_kind TEXT NOT NULL,
  legacy_id TEXT NOT NULL,
  issue TEXT NOT NULL,
  detail JSONB NOT NULL DEFAULT '{}'::jsonb,
  resolved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS transport_migration_reconciliation_open
  ON transport_migration_reconciliation (organization_id, school_id, resolved);

COMMENT ON TABLE transport_migration_reconciliation IS
  'BUS-030: everything the legacy JSONB model could not express, itemised for a '
  'human. A school MUST work this list before its routes can be published — the '
  'alternative was fabricating coordinates and times, which is how the pre-v2 '
  'module reached the state the audit found.';

-- ── Vehicles ─────────────────────────────────────────────────────────────────

INSERT INTO transport_vehicle (
  organization_id, school_id, registration, model, capacity, status,
  insurance_expiry, fitness_expiry, puc_expiry, permit_expiry, road_tax_expiry
)
SELECT
  e.organization_id,
  e.school_id,
  COALESCE(NULLIF(btrim(e.payload ->> 'registration'), ''),
           'LEGACY-' || e.id) AS registration,
  COALESCE(e.payload ->> 'model', ''),
  GREATEST(COALESCE((e.payload ->> 'capacity')::INT, 0), 0),
  CASE WHEN e.payload ->> 'status' IN ('active', 'maintenance', 'retired')
       THEN e.payload ->> 'status' ELSE 'active' END,
  -- Legacy free-text expiries ("Dec 2026") are NOT parseable into a DATE.
  -- Cast only strict ISO; anything else becomes NULL and is reconciled below.
  CASE WHEN e.payload ->> 'insuranceExpiry' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (e.payload ->> 'insuranceExpiry')::DATE END,
  CASE WHEN e.payload ->> 'fitnessExpiry' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (e.payload ->> 'fitnessExpiry')::DATE END,
  CASE WHEN e.payload ->> 'pucExpiry' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (e.payload ->> 'pucExpiry')::DATE END,
  CASE WHEN e.payload ->> 'permitExpiry' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (e.payload ->> 'permitExpiry')::DATE END,
  CASE WHEN e.payload ->> 'roadTaxExpiry' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (e.payload ->> 'roadTaxExpiry')::DATE END
FROM transport_entities e
WHERE e.entity_type = 'vehicle'
  AND NOT EXISTS (
    SELECT 1 FROM transport_vehicle v
    WHERE v.organization_id = e.organization_id
      AND v.school_id = e.school_id
      AND upper(btrim(v.registration)) =
          upper(btrim(COALESCE(NULLIF(btrim(e.payload ->> 'registration'), ''),
                               'LEGACY-' || e.id)))
  );

-- Flag unparseable document dates: BUS-054 gates assignment on these, so a
-- silently-NULLed expiry would let an uninsured bus be assigned.
INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT e.organization_id, e.school_id, 'vehicle', e.id,
       'document_expiry_unparseable',
       jsonb_build_object(
         'insuranceExpiry', e.payload ->> 'insuranceExpiry',
         'fitnessExpiry', e.payload ->> 'fitnessExpiry')
FROM transport_entities e
WHERE e.entity_type = 'vehicle'
  AND (
    (e.payload ->> 'insuranceExpiry' IS NOT NULL
     AND e.payload ->> 'insuranceExpiry' !~ '^\d{4}-\d{2}-\d{2}$')
    OR (e.payload ->> 'fitnessExpiry' IS NOT NULL
     AND e.payload ->> 'fitnessExpiry' !~ '^\d{4}-\d{2}-\d{2}$')
  )
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation r
    WHERE r.legacy_id = e.id AND r.issue = 'document_expiry_unparseable'
  );

-- ── Drivers ──────────────────────────────────────────────────────────────────

INSERT INTO transport_driver (
  organization_id, school_id, name, phone, licence_number, licence_expiry, status
)
SELECT
  e.organization_id,
  e.school_id,
  COALESCE(NULLIF(btrim(e.payload ->> 'name'), ''), 'Unnamed driver'),
  COALESCE(e.payload ->> 'phone', ''),
  COALESCE(NULLIF(btrim(e.payload ->> 'licenseNumber'), ''), 'LEGACY-' || e.id),
  CASE WHEN e.payload ->> 'licenseExpiry' ~ '^\d{4}-\d{2}-\d{2}$'
       THEN (e.payload ->> 'licenseExpiry')::DATE END,
  CASE WHEN e.payload ->> 'status' IN ('active', 'inactive') THEN e.payload ->> 'status'
       WHEN e.payload ->> 'status' = 'onLeave' THEN 'on_leave'
       ELSE 'active' END
FROM transport_entities e
WHERE e.entity_type = 'driver'
  AND NOT EXISTS (
    SELECT 1 FROM transport_driver d
    WHERE d.organization_id = e.organization_id
      AND d.school_id = e.school_id
      AND upper(btrim(d.licence_number)) =
          upper(btrim(COALESCE(NULLIF(btrim(e.payload ->> 'licenseNumber'), ''),
                               'LEGACY-' || e.id)))
  );

-- Every migrated driver needs a login before they can ever be tracked.
INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT d.organization_id, d.school_id, 'driver', d.id::TEXT,
       'driver_has_no_login',
       jsonb_build_object('name', d.name, 'phone', d.phone)
FROM transport_driver d
WHERE d.user_id IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation r
    WHERE r.legacy_id = d.id::TEXT AND r.issue = 'driver_has_no_login'
  );

-- ── Routes ───────────────────────────────────────────────────────────────────

INSERT INTO transport_route (
  organization_id, school_id, name, shift, status, direction
)
SELECT
  e.organization_id,
  e.school_id,
  COALESCE(NULLIF(btrim(e.payload ->> 'name'), ''), 'Route ' || e.id),
  CASE WHEN e.payload ->> 'shift' IN ('am', 'pm') THEN e.payload ->> 'shift'
       ELSE 'am' END,  -- legacy 'both' has no v2 equivalent: a route is one shift
  CASE WHEN e.payload ->> 'status' IN ('active', 'draft', 'inactive')
       THEN e.payload ->> 'status' ELSE 'draft' END,
  'pickup'
FROM transport_entities e
WHERE e.entity_type = 'route'
  AND NOT EXISTS (
    SELECT 1 FROM transport_route r
    WHERE r.organization_id = e.organization_id
      AND r.school_id = e.school_id
      AND lower(btrim(r.name)) =
          lower(btrim(COALESCE(NULLIF(btrim(e.payload ->> 'name'), ''),
                               'Route ' || e.id)))
  );

-- A legacy 'both' route becomes ONE am route plus a reconciliation item: the
-- school must decide whether the PM leg is the same stop order reversed.
INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT e.organization_id, e.school_id, 'route', e.id,
       'both_shift_route_split_required',
       jsonb_build_object('name', e.payload ->> 'name',
                          'amDeparture', e.payload ->> 'amDeparture',
                          'pmDeparture', e.payload ->> 'pmDeparture')
FROM transport_entities e
WHERE e.entity_type = 'route'
  AND e.payload ->> 'shift' = 'both'
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation r
    WHERE r.legacy_id = e.id AND r.issue = 'both_shift_route_split_required'
  );

-- ── Stops (the class that cannot migrate honestly) ───────────────────────────

INSERT INTO transport_stop (
  organization_id, school_id, name, location, status
)
SELECT DISTINCT ON (e.organization_id, e.school_id, lower(btrim(s.value ->> 'name')))
  e.organization_id,
  e.school_id,
  btrim(s.value ->> 'name'),
  -- Take a coordinate ONLY when the legacy row has a plausible one. Seed
  -- fixtures did; anything created through the product did not.
  CASE
    WHEN (s.value ->> 'latitude') IS NOT NULL
     AND (s.value ->> 'longitude') IS NOT NULL
     AND transport_is_plausible_point(
           ST_SetSRID(ST_MakePoint((s.value ->> 'longitude')::FLOAT,
                                   (s.value ->> 'latitude')::FLOAT), 4326)::geography)
    THEN ST_SetSRID(ST_MakePoint((s.value ->> 'longitude')::FLOAT,
                                 (s.value ->> 'latitude')::FLOAT), 4326)::geography
  END,
  CASE
    WHEN (s.value ->> 'latitude') IS NOT NULL
     AND (s.value ->> 'longitude') IS NOT NULL
     AND transport_is_plausible_point(
           ST_SetSRID(ST_MakePoint((s.value ->> 'longitude')::FLOAT,
                                   (s.value ->> 'latitude')::FLOAT), 4326)::geography)
    THEN 'active'
    -- NO fabricated coordinate. This state blocks publication until a human
    -- places the pin (BUS-037).
    ELSE 'needs_location'
  END
FROM transport_entities e
CROSS JOIN LATERAL jsonb_array_elements(
  CASE WHEN jsonb_typeof(e.payload -> 'stops') = 'array'
       THEN e.payload -> 'stops' ELSE '[]'::jsonb END) AS s(value)
WHERE e.entity_type = 'route'
  AND btrim(COALESCE(s.value ->> 'name', '')) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM transport_stop st
    WHERE st.organization_id = e.organization_id
      AND st.school_id = e.school_id
      AND lower(btrim(st.name)) = lower(btrim(s.value ->> 'name'))
      AND st.status <> 'retired'
  );

INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT st.organization_id, st.school_id, 'stop', st.id::TEXT,
       'stop_missing_location',
       jsonb_build_object('name', st.name)
FROM transport_stop st
WHERE st.status = 'needs_location'
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation r
    WHERE r.legacy_id = st.id::TEXT AND r.issue = 'stop_missing_location'
  );

-- ── Route ↔ stop, with unparseable times flagged ─────────────────────────────

INSERT INTO transport_route_stop (
  organization_id, school_id, route_id, stop_id, sequence,
  scheduled_pickup_time, scheduled_drop_time
)
SELECT DISTINCT ON (r.id, st.id)
  e.organization_id, e.school_id, r.id, st.id,
  COALESCE((s.value ->> 'sequence')::INT, s.ordinality::INT),
  -- Free text is NOT coerced. Unparseable → NULL + a reconciliation row.
  CASE WHEN COALESCE(s.value ->> 'pickupTime', s.value ->> 'scheduledTime')
            ~* '^\d{1,2}:\d{2}\s*(am|pm)?$'
       THEN to_timestamp(
              COALESCE(s.value ->> 'pickupTime', s.value ->> 'scheduledTime'),
              'HH12:MI AM')::TIME END,
  CASE WHEN (s.value ->> 'dropTime') ~* '^\d{1,2}:\d{2}\s*(am|pm)?$'
       THEN to_timestamp(s.value ->> 'dropTime', 'HH12:MI AM')::TIME END
FROM transport_entities e
CROSS JOIN LATERAL jsonb_array_elements(
  CASE WHEN jsonb_typeof(e.payload -> 'stops') = 'array'
       THEN e.payload -> 'stops' ELSE '[]'::jsonb END) WITH ORDINALITY AS s(value, ordinality)
JOIN transport_route r
  ON r.organization_id = e.organization_id AND r.school_id = e.school_id
 AND lower(btrim(r.name)) = lower(btrim(COALESCE(NULLIF(btrim(e.payload ->> 'name'), ''),
                                                 'Route ' || e.id)))
JOIN transport_stop st
  ON st.organization_id = e.organization_id AND st.school_id = e.school_id
 AND lower(btrim(st.name)) = lower(btrim(s.value ->> 'name'))
WHERE e.entity_type = 'route'
  AND btrim(COALESCE(s.value ->> 'name', '')) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM transport_route_stop rs
    WHERE rs.route_id = r.id AND rs.stop_id = st.id
  );

INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT rs.organization_id, rs.school_id, 'route_stop',
       rs.route_id::TEXT || ':' || rs.stop_id::TEXT,
       'stop_time_unparseable', '{}'::jsonb
FROM transport_route_stop rs
WHERE rs.scheduled_pickup_time IS NULL
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation r
    WHERE r.legacy_id = rs.route_id::TEXT || ':' || rs.stop_id::TEXT
      AND r.issue = 'stop_time_unparseable'
  );

-- ── Allocations: string stop refs become an admin confirmation queue ─────────

INSERT INTO transport_allocation (
  organization_id, school_id, student_id, route_id,
  pickup_stop_id, drop_stop_id, shift, status
)
SELECT DISTINCT ON (stu.id, COALESCE(e.payload ->> 'shift', 'both'))
  e.organization_id, e.school_id, stu.id, r.id, ps.id, ds.id,
  CASE WHEN e.payload ->> 'shift' IN ('am', 'pm', 'both')
       THEN e.payload ->> 'shift' ELSE 'both' END,
  'active'
FROM transport_entities e
JOIN students stu
  ON stu.organization_id = e.organization_id AND stu.school_id = e.school_id
 AND (stu.id::TEXT = e.payload ->> 'sisStudentId'
   OR stu.student_code = e.payload ->> 'sisStudentId')
JOIN transport_route r
  ON r.organization_id = e.organization_id AND r.school_id = e.school_id
 AND lower(btrim(r.name)) = lower(btrim(e.payload ->> 'routeName'))
-- Exact-match the free-text stop strings. A miss is NOT guessed at.
JOIN transport_stop ps
  ON ps.organization_id = e.organization_id AND ps.school_id = e.school_id
 AND lower(btrim(ps.name)) = lower(btrim(e.payload ->> 'pickupStop'))
JOIN transport_stop ds
  ON ds.organization_id = e.organization_id AND ds.school_id = e.school_id
 AND lower(btrim(ds.name)) = lower(btrim(e.payload ->> 'dropStop'))
WHERE e.entity_type = 'allocation'
  AND btrim(COALESCE(e.payload ->> 'routeId', '')) <> ''
  AND NOT EXISTS (
    SELECT 1 FROM transport_allocation a
    WHERE a.student_id = stu.id AND a.status = 'active'
  );

-- Anything that did not join is queued for a human — never silently dropped and
-- never fuzzy-matched into a possibly-wrong stop. A child at the wrong pickup
-- point is a safety incident.
INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT e.organization_id, e.school_id, 'allocation', e.id,
       'allocation_unresolved',
       jsonb_build_object(
         'studentName', e.payload ->> 'studentName',
         'sisStudentId', e.payload ->> 'sisStudentId',
         'routeName', e.payload ->> 'routeName',
         'pickupStop', e.payload ->> 'pickupStop',
         'dropStop', e.payload ->> 'dropStop')
FROM transport_entities e
WHERE e.entity_type = 'allocation'
  AND btrim(COALESCE(e.payload ->> 'routeId', '')) <> ''
  AND NOT EXISTS (
    SELECT 1
    FROM students stu
    JOIN transport_allocation a ON a.student_id = stu.id AND a.status = 'active'
    WHERE stu.organization_id = e.organization_id
      AND stu.school_id = e.school_id
      AND (stu.id::TEXT = e.payload ->> 'sisStudentId'
        OR stu.student_code = e.payload ->> 'sisStudentId')
  )
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation r
    WHERE r.legacy_id = e.id AND r.issue = 'allocation_unresolved'
  );

-- ── Vehicle → route assignment: DELIBERATELY NOT MIGRATED ────────────────────
--
-- There is nothing to migrate. `route.assignedBus` was written as "" at route
-- creation and NO endpoint ever set it — that missing writer is what silently
-- disabled the capacity guard and both delete guards. Every legacy route is
-- therefore unassigned by definition, and BUS-043/BUS-048 are where a school
-- assigns a bus and driver for the first time.
INSERT INTO transport_migration_reconciliation
  (organization_id, school_id, entity_kind, legacy_id, issue, detail)
SELECT r.organization_id, r.school_id, 'route', r.id::TEXT,
       'route_needs_vehicle_and_driver_assignment',
       jsonb_build_object('name', r.name)
FROM transport_route r
WHERE NOT EXISTS (
    SELECT 1 FROM transport_assignment a WHERE a.route_id = r.id
  )
  AND NOT EXISTS (
    SELECT 1 FROM transport_migration_reconciliation rec
    WHERE rec.legacy_id = r.id::TEXT
      AND rec.issue = 'route_needs_vehicle_and_driver_assignment'
  );

ALTER TABLE transport_migration_reconciliation ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_migration_reconciliation FORCE ROW LEVEL SECURITY;
CREATE POLICY transport_migration_reconciliation_staff
  ON transport_migration_reconciliation FOR ALL
  USING (transport_is_school_staff(organization_id, school_id))
  WITH CHECK (transport_is_school_staff(organization_id, school_id));
GRANT SELECT, INSERT, UPDATE, DELETE ON transport_migration_reconciliation TO erp_tenant;
