-- BUS-022…BUS-027 — Transport v2 operational tables.
--
-- Implements TRANSPORT_DOMAIN_CONTRACT.md §1.2 (assignment, allocation, trip,
-- position, boarding, incident) and §3 (state machines).
--
-- This migration is where the owner's three additional production requirements
-- become STRUCTURAL rather than special cases:
--   1. driver replacement  → transport_assignment, dated, kind='substitute'
--   2. trip lifecycle      → transport_trip status machine + position binding
--   3. future-proofing     → source-agnostic position ingest; every temporary
--                            change (vehicle, driver, route diversion) is an
--                            ordinary dated row, not a schema change.

-- ── BUS-022: dated route ↔ vehicle ↔ driver ↔ attendant assignment ───────────

CREATE TABLE transport_assignment (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  route_id UUID NOT NULL REFERENCES transport_route (id) ON DELETE CASCADE,
  -- FKs by ID, never by registration/licence string (P-6). Mutating a vehicle's
  -- registration can no longer break this link.
  vehicle_id UUID REFERENCES transport_vehicle (id) ON DELETE RESTRICT,
  driver_id UUID REFERENCES transport_driver (id) ON DELETE RESTRICT,
  attendant_id UUID REFERENCES transport_driver (id) ON DELETE RESTRICT,

  effective_from DATE NOT NULL,
  -- NULL = open-ended. A permanent assignment normally has no end date.
  effective_to DATE,

  assignment_kind TEXT NOT NULL DEFAULT 'permanent'
    CHECK (assignment_kind IN ('permanent', 'substitute')),
  reason TEXT NOT NULL DEFAULT '',

  created_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT transport_assignment_range
    CHECK (effective_to IS NULL OR effective_to >= effective_from),
  -- A substitute covers a bounded period by definition; an unbounded substitute
  -- is a permanent assignment wearing the wrong label.
  CONSTRAINT transport_assignment_substitute_bounded
    CHECK (assignment_kind <> 'substitute' OR effective_to IS NOT NULL),
  CONSTRAINT transport_assignment_attendant_distinct
    CHECK (attendant_id IS NULL OR attendant_id IS DISTINCT FROM driver_id)
);

-- At most ONE open permanent assignment per route at any date. Substitutes are
-- deliberately EXCLUDED from this constraint — overlapping a permanent row is
-- the entire point (owner requirement 1: cover today without disturbing the
-- permanent arrangement).
CREATE EXTENSION IF NOT EXISTS btree_gist;
ALTER TABLE transport_assignment
  ADD CONSTRAINT transport_assignment_no_permanent_overlap
  EXCLUDE USING GIST (
    route_id WITH =,
    daterange(effective_from, COALESCE(effective_to, 'infinity'::date), '[]') WITH &&
  ) WHERE (assignment_kind = 'permanent');

CREATE INDEX transport_assignment_resolve
  ON transport_assignment (organization_id, school_id, route_id, effective_from, effective_to);
CREATE INDEX transport_assignment_by_driver
  ON transport_assignment (driver_id, effective_from, effective_to)
  WHERE driver_id IS NOT NULL;
CREATE INDEX transport_assignment_by_vehicle
  ON transport_assignment (vehicle_id, effective_from, effective_to)
  WHERE vehicle_id IS NOT NULL;

CREATE TRIGGER transport_assignment_updated_at
  BEFORE UPDATE ON transport_assignment
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

/**
 * BUS-022/BUS-051 — resolve the assignment in force for (route, date).
 *
 * Precedence, per TRANSPORT_DOMAIN_CONTRACT.md §3.3:
 *   1. a `substitute` row covering the date wins;
 *   2. otherwise the `permanent` row covering the date;
 *   3. otherwise NULL — the route is UNSTAFFED for that date and the dashboard
 *      raises it (BUS-050), rather than the school discovering it when a bus
 *      fails to arrive.
 *
 * This single function is why a substitute driver needs NO special case in the
 * driver app: BUS-065 resolves "today's trip" through here, so a substitute
 * sees the covered route exactly as the permanent driver would, and tomorrow
 * reverts automatically with zero admin cleanup.
 */
CREATE OR REPLACE FUNCTION transport_effective_assignment(
  p_route_id UUID,
  p_date DATE
)
RETURNS transport_assignment
LANGUAGE sql
STABLE
AS $$
  SELECT a.*
  FROM transport_assignment a
  WHERE a.route_id = p_route_id
    AND a.effective_from <= p_date
    AND (a.effective_to IS NULL OR a.effective_to >= p_date)
  ORDER BY (a.assignment_kind = 'substitute') DESC, a.effective_from DESC
  LIMIT 1;
$$;

-- ── BUS-023: student allocation ──────────────────────────────────────────────

CREATE TABLE transport_allocation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  route_id UUID NOT NULL REFERENCES transport_route (id) ON DELETE RESTRICT,
  -- Stops by FK. Pre-v2 these were FREE TEXT typed by an admin, and the roster
  -- grouped by exact string match — so "Green Park Gate", "Green park gate" and
  -- "Green Park gate " became three stops and a child's pickup location
  -- depended on typing accuracy. That is a safety defect, not a data-quality one.
  pickup_stop_id UUID NOT NULL REFERENCES transport_stop (id) ON DELETE RESTRICT,
  drop_stop_id UUID NOT NULL REFERENCES transport_stop (id) ON DELETE RESTRICT,

  shift TEXT NOT NULL DEFAULT 'both' CHECK (shift IN ('am', 'pm', 'both')),
  effective_from DATE NOT NULL DEFAULT CURRENT_DATE,
  effective_to DATE,
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'ended')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  CONSTRAINT transport_allocation_range
    CHECK (effective_to IS NULL OR effective_to >= effective_from)
);

-- NO denormalized display copies: no route_name, no bus_number. Pre-v2
-- allocations froze those strings at assignment time, so they went stale the
-- moment anything changed.

-- BUS-056: at most one ACTIVE allocation per student per shift. 'both' conflicts
-- with 'am' and 'pm', so the legitimate case (a distinct morning and afternoon
-- route — very common with after-school activities) is allowed while riding two
-- buses at once is not. Pre-v2 nothing checked: a double-allocated student
-- counted against both capacities, appeared on both rosters, and BOTH DRIVERS
-- expected them.
CREATE UNIQUE INDEX transport_allocation_one_per_shift
  ON transport_allocation (student_id, shift)
  WHERE status = 'active';
CREATE UNIQUE INDEX transport_allocation_no_both_with_am_pm
  ON transport_allocation (student_id)
  WHERE status = 'active' AND shift = 'both';

CREATE INDEX transport_allocation_by_route
  ON transport_allocation (organization_id, school_id, route_id, status);
-- BUS-059: the parent single-child lookup. Pre-v2 this required loading the
-- school's WHOLE allocation list, which is why the parent path read page 1 of
-- 20 and failed for ~97% of parents in an 800-student school.
CREATE INDEX transport_allocation_by_student
  ON transport_allocation (student_id, status);
CREATE INDEX transport_allocation_by_stop
  ON transport_allocation (pickup_stop_id, status);

CREATE TRIGGER transport_allocation_updated_at
  BEFORE UPDATE ON transport_allocation
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── BUS-024: trip — THE missing concept ──────────────────────────────────────

CREATE TABLE transport_trip (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  route_id UUID NOT NULL REFERENCES transport_route (id) ON DELETE RESTRICT,
  service_date DATE NOT NULL,
  shift TEXT NOT NULL CHECK (shift IN ('am', 'pm')),

  -- Resolved from transport_effective_assignment at generation time and FROZEN
  -- onto the trip, so history records who ACTUALLY drove — not who is assigned
  -- today.
  vehicle_id UUID REFERENCES transport_vehicle (id) ON DELETE RESTRICT,
  driver_id UUID REFERENCES transport_driver (id) ON DELETE RESTRICT,
  attendant_id UUID REFERENCES transport_driver (id) ON DELETE RESTRICT,
  assignment_id UUID REFERENCES transport_assignment (id) ON DELETE SET NULL,

  status TEXT NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled', 'started', 'completed', 'cancelled', 'aborted')),

  started_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  start_location GEOGRAPHY(POINT, 4326),
  end_location GEOGRAPHY(POINT, 4326),
  distance_m INT CHECK (distance_m IS NULL OR distance_m >= 0),

  -- BUS-071: a trip the driver forgot to end, closed by the safeguard. Marked,
  -- never silent.
  auto_ended BOOLEAN NOT NULL DEFAULT false,

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  -- §3.1 invariants, enforced in the database rather than trusted to handlers.
  CONSTRAINT transport_trip_started_has_time
    CHECK (status = 'scheduled' OR status = 'cancelled' OR started_at IS NOT NULL),
  CONSTRAINT transport_trip_ended_has_time
    CHECK (status <> 'completed' OR ended_at IS NOT NULL),
  CONSTRAINT transport_trip_end_after_start
    CHECK (ended_at IS NULL OR started_at IS NULL OR ended_at >= started_at)
);

CREATE UNIQUE INDEX transport_trip_route_date_shift_uniq
  ON transport_trip (route_id, service_date, shift);
-- BUS-065: "today's trip for THIS driver" — the driver app's only read.
CREATE INDEX transport_trip_driver_today
  ON transport_trip (driver_id, service_date, status)
  WHERE driver_id IS NOT NULL;
CREATE INDEX transport_trip_school_date
  ON transport_trip (organization_id, school_id, service_date, status);
-- BUS-087: the admin live fleet view reads only active trips.
CREATE INDEX transport_trip_active
  ON transport_trip (organization_id, school_id, status)
  WHERE status = 'started';

CREATE TRIGGER transport_trip_updated_at
  BEFORE UPDATE ON transport_trip
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

/**
 * BUS-072/BUS-073 — trip state machine + immutability, enforced in the database.
 *
 * Legal transitions (§3.1):
 *   scheduled → started | cancelled
 *   started   → completed | aborted
 *   completed / cancelled / aborted are TERMINAL.
 *
 * Terminal immutability is what makes trip history evidentiary. Corrections are
 * separate audited adjustment rows referencing the original — never an in-place
 * edit, which is exactly how the pre-v2 attendance row destroyed its own history
 * (re-recording replaced it, so yesterday was unrepresentable).
 */
CREATE OR REPLACE FUNCTION transport_trip_guard()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF OLD.status IN ('completed', 'cancelled', 'aborted')
     AND NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION
      'TRIP_STATE_INVALID: trip % is terminal (%) and cannot transition to %',
      OLD.id, OLD.status, NEW.status
      USING ERRCODE = 'check_violation';
  END IF;

  IF OLD.status IN ('completed', 'cancelled', 'aborted')
     AND NEW.status = OLD.status
     AND (NEW.started_at IS DISTINCT FROM OLD.started_at
       OR NEW.ended_at IS DISTINCT FROM OLD.ended_at
       OR NEW.driver_id IS DISTINCT FROM OLD.driver_id
       OR NEW.vehicle_id IS DISTINCT FROM OLD.vehicle_id
       OR NEW.route_id IS DISTINCT FROM OLD.route_id
       OR NEW.service_date IS DISTINCT FROM OLD.service_date) THEN
    RAISE EXCEPTION
      'TRIP_IMMUTABLE: completed trip % cannot be edited; record an adjustment',
      OLD.id
      USING ERRCODE = 'check_violation';
  END IF;

  IF OLD.status = 'scheduled'
     AND NEW.status NOT IN ('scheduled', 'started', 'cancelled') THEN
    RAISE EXCEPTION
      'TRIP_STATE_INVALID: scheduled → % is not a legal transition', NEW.status
      USING ERRCODE = 'check_violation';
  END IF;

  IF OLD.status = 'started'
     AND NEW.status NOT IN ('started', 'completed', 'aborted') THEN
    RAISE EXCEPTION
      'TRIP_STATE_INVALID: started → % is not a legal transition', NEW.status
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER transport_trip_state_guard
  BEFORE UPDATE ON transport_trip
  FOR EACH ROW EXECUTE FUNCTION transport_trip_guard();

-- ── BUS-025: position time-series (partitioned) ──────────────────────────────

CREATE TABLE transport_position (
  organization_id UUID NOT NULL,
  school_id UUID NOT NULL,
  trip_id UUID NOT NULL,

  recorded_at TIMESTAMPTZ NOT NULL,
  received_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  location GEOGRAPHY(POINT, 4326) NOT NULL,
  accuracy_m REAL,
  speed_mps REAL CHECK (speed_mps IS NULL OR speed_mps >= 0),
  heading_deg REAL CHECK (heading_deg IS NULL OR heading_deg BETWEEN 0 AND 360),

  -- BUS-011/BUS-076: source-agnostic. A driver phone and a hardware tracker are
  -- interchangeable adapters; nothing above the ingest boundary branches on this
  -- except integrity scoring and the device registry (owner requirement 3).
  source_type TEXT NOT NULL DEFAULT 'driver_app'
    CHECK (source_type IN ('driver_app', 'hardware_device')),
  source_id TEXT NOT NULL DEFAULT '',

  -- BUS-082: mock-location / implausible-jump flags. Flagged fixes are RETAINED
  -- and marked, never silently discarded — a discarded fix is an invisible gap
  -- in a child-safety record.
  integrity_flags JSONB NOT NULL DEFAULT '{}'::jsonb,

  CONSTRAINT transport_position_plausible
    CHECK (transport_is_plausible_point(location))
) PARTITION BY RANGE (recorded_at);

-- At 1,000 buses this receives ~2.16M rows/day (6 fixes/min × 6h). Partitioning
-- is designed in at creation because retrofitting it under that load is painful.
-- BUS-084 automates partition creation/retention; these bootstrap the current
-- and next month so the table is usable immediately.
CREATE TABLE transport_position_default PARTITION OF transport_position DEFAULT;

CREATE INDEX transport_position_trip_time
  ON transport_position (trip_id, recorded_at DESC);
CREATE INDEX transport_position_location_gix
  ON transport_position USING GIST (location);

COMMENT ON TABLE transport_position IS
  'BUS-025: range-partitioned by recorded_at. Ingest is batched and out-of-order '
  'tolerant (BUS-080 store-and-forward replays dead-zone buffers). LIVE reads do '
  'NOT come from here — BUS-083 serves last-known position from a hot store so '
  'parent/admin polling never loads the write-heavy path.';

-- ── BUS-026: boarding ────────────────────────────────────────────────────────

CREATE TABLE transport_boarding (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  -- A REAL student FK, scoped to a DATED trip. The pre-v2 attendance row had
  -- neither: it keyed on `studentName` (a display string) with no date, and
  -- re-recording replaced it in place. It therefore could not be attributed to
  -- a child, could not be joined to SIS, broke for two children with the same
  -- name, and physically could not answer "was my son on the bus last Tuesday?"
  -- — the exact question a school faces when something goes wrong.
  trip_id UUID NOT NULL REFERENCES transport_trip (id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES students (id) ON DELETE CASCADE,
  stop_id UUID REFERENCES transport_stop (id) ON DELETE SET NULL,

  event TEXT NOT NULL
    CHECK (event IN ('boarded', 'alighted', 'absent', 'no_show')),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  recorded_by UUID REFERENCES users (id),
  source TEXT NOT NULL DEFAULT 'driver'
    CHECK (source IN ('driver', 'attendant', 'geofence', 'admin')),
  location GEOGRAPHY(POINT, 4326),
  notes TEXT NOT NULL DEFAULT '',

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX transport_boarding_trip_student_event_uniq
  ON transport_boarding (trip_id, student_id, event);
CREATE INDEX transport_boarding_by_student
  ON transport_boarding (student_id, recorded_at DESC);
CREATE INDEX transport_boarding_by_trip
  ON transport_boarding (trip_id, stop_id);

-- ── BUS-027: incident ────────────────────────────────────────────────────────

CREATE TABLE transport_incident (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  trip_id UUID REFERENCES transport_trip (id) ON DELETE SET NULL,
  vehicle_id UUID REFERENCES transport_vehicle (id) ON DELETE SET NULL,
  driver_id UUID REFERENCES transport_driver (id) ON DELETE SET NULL,

  kind TEXT NOT NULL CHECK (kind IN (
    'sos', 'breakdown', 'speed_violation', 'geofence_anomaly',
    'diversion', 'no_show', 'integrity_alert'
  )),
  severity TEXT NOT NULL DEFAULT 'medium'
    CHECK (severity IN ('low', 'medium', 'high', 'critical')),

  location GEOGRAPHY(POINT, 4326),
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  reported_by UUID REFERENCES users (id),
  details JSONB NOT NULL DEFAULT '{}'::jsonb,

  acknowledged_by UUID REFERENCES users (id),
  acknowledged_at TIMESTAMPTZ,
  resolution TEXT NOT NULL DEFAULT '',
  resolved_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- BUS-114: the emergency console reads unacknowledged incidents first.
CREATE INDEX transport_incident_open
  ON transport_incident (organization_id, school_id, occurred_at DESC)
  WHERE acknowledged_at IS NULL;
CREATE INDEX transport_incident_by_trip
  ON transport_incident (trip_id) WHERE trip_id IS NOT NULL;

CREATE TRIGGER transport_incident_updated_at
  BEFORE UPDATE ON transport_incident
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- BUS-075: emergency route diversion, recorded against the TRIP so the route
-- template is untouched and tomorrow runs normally (owner requirement 3).
CREATE TABLE transport_trip_diversion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  trip_id UUID NOT NULL REFERENCES transport_trip (id) ON DELETE CASCADE,
  incident_id UUID REFERENCES transport_incident (id) ON DELETE SET NULL,
  kind TEXT NOT NULL CHECK (kind IN ('skip_stop', 'add_stop', 'alternate_path')),
  stop_id UUID REFERENCES transport_stop (id) ON DELETE SET NULL,
  reason TEXT NOT NULL DEFAULT '',
  recorded_by UUID REFERENCES users (id),
  recorded_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX transport_trip_diversion_by_trip
  ON transport_trip_diversion (trip_id);
