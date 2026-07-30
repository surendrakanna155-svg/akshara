-- BUS-017…BUS-021 — Transport v2 core entities.
--
-- Implements TRANSPORT_DOMAIN_CONTRACT.md §1.2 (vehicle, driver, stop, route,
-- route_stop). Replaces the single schemaless `transport_entities` JSONB table,
-- in which:
--   * there was not ONE foreign key in the entire module;
--   * a route referenced its vehicle by REGISTRATION STRING, so changing a
--     registration silently orphaned the link with no error and no cascade;
--   * stops were a nested JSON array — unqueryable, unindexable, unshareable,
--     and carrying no coordinates;
--   * stop times were unvalidated free text, making schedule adherence, delay
--     detection and any ETA baseline arithmetically impossible.
--
-- Additive only. `transport_entities` is untouched here; BUS-030 migrates the
-- data and BUS-031 decommissions it once Phases 3–6 read exclusively from v2.

-- ── BUS-017: vehicle ─────────────────────────────────────────────────────────

CREATE TABLE transport_vehicle (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  -- Mutable business identifier. NEVER used as a link target (see the
  -- transport_assignment FK) — mutating it must not be able to break a
  -- relationship, which is exactly what the pre-v2 model allowed.
  registration TEXT NOT NULL,
  model TEXT NOT NULL DEFAULT '',
  capacity INT NOT NULL DEFAULT 0 CHECK (capacity >= 0),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'maintenance', 'retired')),

  -- TRN-2 statutory documents. Typed DATE, not free text: BUS-054 gates
  -- assignment on these and BUS-125 reports on them, both of which need real
  -- date arithmetic. Strict ISO validation in the write path is PRESERVED.
  insurance_expiry DATE,
  fitness_expiry DATE,
  puc_expiry DATE,
  permit_expiry DATE,
  road_tax_expiry DATE,

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- Per-school registration uniqueness, enforced by the DATABASE. The pre-v2
-- model loaded every vehicle into application memory and compared normalised
-- strings — O(n) per write and racy.
CREATE UNIQUE INDEX transport_vehicle_registration_uniq
  ON transport_vehicle (organization_id, school_id, upper(btrim(registration)));
CREATE INDEX transport_vehicle_school_status
  ON transport_vehicle (organization_id, school_id, status);

CREATE TRIGGER transport_vehicle_updated_at
  BEFORE UPDATE ON transport_vehicle
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── BUS-018: driver ──────────────────────────────────────────────────────────

CREATE TABLE transport_driver (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  -- BUS-062: the auth link. Its absence is the ROOT CAUSE of the entire
  -- tracking gap — with no driver login there is no GPS source, and with no
  -- GPS source live tracking is unreachable by construction. Nullable until
  -- the account is provisioned (BUS-063 provisions on driver creation).
  user_id UUID REFERENCES users (id),

  name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  licence_number TEXT NOT NULL,
  licence_expiry DATE,
  licence_class TEXT NOT NULL DEFAULT '',

  -- Safety / compliance record. None of this existed pre-v2: a driver was
  -- name + licence + phone. Schools are accountable for who drives their
  -- children, and competitors capture these.
  photo_ref TEXT,
  address TEXT,
  police_verification_status TEXT NOT NULL DEFAULT 'not_verified'
    CHECK (police_verification_status IN ('not_verified', 'pending', 'verified', 'expired')),
  police_verification_expiry DATE,
  medical_check_date DATE,
  eyesight_check_date DATE,
  blood_group TEXT,
  emergency_contact TEXT,

  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'on_leave', 'inactive')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE UNIQUE INDEX transport_driver_licence_uniq
  ON transport_driver (organization_id, school_id, upper(btrim(licence_number)));
CREATE INDEX transport_driver_school_status
  ON transport_driver (organization_id, school_id, status);
-- BUS-065 resolves "today's trip" from the authenticated driver identity.
CREATE INDEX transport_driver_user
  ON transport_driver (user_id) WHERE user_id IS NOT NULL;

CREATE TRIGGER transport_driver_updated_at
  BEFORE UPDATE ON transport_driver
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- BUS-050: dated availability. Marking a driver unavailable is what RAISES the
-- substitution-needed flag (owner requirement 1) — without dates there is no
-- way to know a route is unstaffed tomorrow.
CREATE TABLE transport_driver_availability (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  driver_id UUID NOT NULL REFERENCES transport_driver (id) ON DELETE CASCADE,
  from_date DATE NOT NULL,
  to_date DATE NOT NULL,
  kind TEXT NOT NULL DEFAULT 'leave'
    CHECK (kind IN ('leave', 'sick', 'rest', 'suspended', 'training')),
  reason TEXT NOT NULL DEFAULT '',
  recorded_by UUID REFERENCES users (id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT transport_driver_availability_range CHECK (to_date >= from_date)
);

CREATE INDEX transport_driver_availability_lookup
  ON transport_driver_availability (organization_id, school_id, driver_id, from_date, to_date);

-- ── BUS-019: stop (THE gating entity for the whole tracking feature) ─────────

CREATE TABLE transport_stop (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  name TEXT NOT NULL,

  -- THE single most consequential column in the schema. Without it there is no
  -- geofence, no distance-to-stop, no arrival detection, no ETA and no map —
  -- permanently, regardless of what else is built.
  --
  -- NULL is allowed ONLY while status = 'needs_location', which exists solely
  -- so BUS-030 can migrate legacy stops that never had a coordinate WITHOUT
  -- fabricating one. A needs_location stop blocks route publication (BUS-042),
  -- so the gap is loud rather than silent.
  location GEOGRAPHY(POINT, 4326),
  geofence_radius_m INT NOT NULL DEFAULT 100
    CHECK (geofence_radius_m BETWEEN 20 AND 2000),

  -- Geocoded ONCE at creation/import and stored forever (roadmap P-7).
  -- Re-geocoding per view is how map bills explode.
  address_text TEXT NOT NULL DEFAULT '',
  landmark TEXT NOT NULL DEFAULT '',

  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'needs_location', 'retired')),

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  -- An 'active' stop MUST have a plausible coordinate. This is the constraint
  -- that makes the audit's worst structural defect unrepresentable.
  CONSTRAINT transport_stop_location_required CHECK (
    (status = 'needs_location' AND location IS NULL)
    OR (status <> 'needs_location'
        AND location IS NOT NULL
        AND transport_is_plausible_point(location))
  )
);

CREATE INDEX transport_stop_location_gix
  ON transport_stop USING GIST (location);
CREATE INDEX transport_stop_school
  ON transport_stop (organization_id, school_id, status);
CREATE UNIQUE INDEX transport_stop_name_uniq
  ON transport_stop (organization_id, school_id, lower(btrim(name)))
  WHERE status <> 'retired';

CREATE TRIGGER transport_stop_updated_at
  BEFORE UPDATE ON transport_stop
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── BUS-020: route (TEMPLATE ONLY) ───────────────────────────────────────────

CREATE TABLE transport_route (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),

  name TEXT NOT NULL,
  code TEXT NOT NULL DEFAULT '',
  direction TEXT NOT NULL DEFAULT 'pickup'
    CHECK (direction IN ('pickup', 'drop')),
  shift TEXT NOT NULL DEFAULT 'am' CHECK (shift IN ('am', 'pm')),
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'inactive')),

  default_departure_time TIME,
  default_return_time TIME,
  distance_m INT CHECK (distance_m IS NULL OR distance_m >= 0),

  -- BUS-041: cached road-following geometry, regenerated on stop-set change and
  -- served from cache. NEVER fetched per map render (P-7).
  path_geometry GEOGRAPHY(LINESTRING, 4326),
  path_generated_at TIMESTAMPTZ,

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- DELIBERATELY ABSENT: assigned_vehicle_id / assigned_driver_id / stop_count /
-- student_count.
--
-- The pre-v2 route carried `assignedBus` as a scalar that NO endpoint ever
-- wrote, which silently disabled the capacity guard, the vehicle-in-use delete
-- guard and the driver-in-use delete guard — three correct, well-tested
-- features that never once executed. Operational links live in
-- transport_assignment as DATED rows (P-3); derived counts are computed on read.

CREATE UNIQUE INDEX transport_route_name_uniq
  ON transport_route (organization_id, school_id, lower(btrim(name)), shift)
  WHERE status <> 'inactive';
CREATE INDEX transport_route_school_status
  ON transport_route (organization_id, school_id, status, shift);

CREATE TRIGGER transport_route_updated_at
  BEFORE UPDATE ON transport_route
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ── BUS-021: route ↔ stop junction ───────────────────────────────────────────

CREATE TABLE transport_route_stop (
  organization_id UUID NOT NULL REFERENCES organizations (id),
  school_id UUID NOT NULL REFERENCES schools (id),
  route_id UUID NOT NULL REFERENCES transport_route (id) ON DELETE CASCADE,
  stop_id UUID NOT NULL REFERENCES transport_stop (id) ON DELETE RESTRICT,

  sequence INT NOT NULL CHECK (sequence > 0),

  -- REAL TIME values, not strings. Free-text times ("7:05 AM", "7.05", "0705",
  -- "morning" — all of which persisted pre-v2) cannot be sorted, diffed or
  -- subtracted, which made schedule adherence and any ETA baseline impossible.
  -- That ceiling is why the old dashboard could DISPLAY "94% On-Time" but never
  -- COMPUTE it.
  scheduled_pickup_time TIME,
  scheduled_drop_time TIME,
  dwell_seconds INT NOT NULL DEFAULT 60 CHECK (dwell_seconds >= 0),

  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),

  PRIMARY KEY (route_id, stop_id)
);

-- Contiguous 1..n ordering. DEFERRABLE so a reorder can shuffle inside one
-- transaction — PRESERVING the row-locked resequencing semantics of the pre-v2
-- implementation, which were genuinely well-engineered (P-10).
CREATE UNIQUE INDEX transport_route_stop_sequence_uniq
  ON transport_route_stop (route_id, sequence);
ALTER TABLE transport_route_stop
  ADD CONSTRAINT transport_route_stop_sequence_deferrable
  UNIQUE (route_id, sequence) DEFERRABLE INITIALLY IMMEDIATE;
DROP INDEX IF EXISTS transport_route_stop_sequence_uniq;

CREATE INDEX transport_route_stop_by_stop
  ON transport_route_stop (stop_id);

COMMENT ON TABLE transport_route_stop IS
  'BUS-021/BUS-040: many-to-many so ONE physical stop is shared by the AM and '
  'PM routes with independent times. Pre-v2 stops were embedded per-route JSON, '
  'so the same gate existed twice and fixing its location fixed only one.';
