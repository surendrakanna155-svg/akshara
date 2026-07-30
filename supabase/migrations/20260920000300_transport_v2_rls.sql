-- BUS-028 — RLS + tenant policies for every Transport v2 table.
--
-- Carries forward the ONE part of the pre-v2 module the audit rated genuinely
-- solid: forced RLS, matching USING/WITH CHECK, per-connection tenant context.
-- That standard must not regress (roadmap P-10).
--
-- What is NEW and where the risk sits: the pre-v2 policy was
-- `app_current_scope() = 'school'` for everything, which is correct for staff
-- and FATAL for parents and drivers. It is exactly why the parent transport
-- screen 403'd in the live build, and why a driver could never have read a trip
-- even if the role had existed.
--
-- Implements the visibility matrix in TRANSPORT_DOMAIN_CONTRACT.md §5:
--
--   staff    → their school, everything
--   driver   → ONLY trips assigned to them (and the rows those trips reach)
--   parent   → ONLY their own children's allocations + ACTIVE trips
--   student  → ONLY their own allocation
--
-- Enforced HERE, at the database, not in handlers (P-8). The audit's finding
-- was that visibility had been treated as a client-side filter over a
-- school-wide payload — which would have shipped other children's names,
-- admission numbers and PICKUP STOP LOCATIONS to every parent.

-- ── Scope helpers ────────────────────────────────────────────────────────────

/** True when the caller is school-scoped staff for this org/school. */
CREATE OR REPLACE FUNCTION transport_is_school_staff(p_org UUID, p_school UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT p_org = app_current_tenant_id()
     AND app_current_scope() = 'school'
     AND p_school = app_current_school_id();
$$;

/**
 * The transport_driver row belonging to the authenticated driver, if any.
 * A driver's identity is their `users.id`; transport_driver.user_id is the link
 * added by BUS-018.
 */
CREATE OR REPLACE FUNCTION transport_current_driver_id()
RETURNS UUID LANGUAGE sql STABLE AS $$
  SELECT d.id
  FROM transport_driver d
  WHERE d.user_id = app_current_user_id()
    AND d.organization_id = app_current_tenant_id()
  LIMIT 1;
$$;

/** True when the caller drives or attends this trip TODAY. */
CREATE OR REPLACE FUNCTION transport_is_trip_crew(p_trip transport_trip)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT app_current_scope() = 'driver'
     AND transport_current_driver_id() IS NOT NULL
     AND (p_trip.driver_id = transport_current_driver_id()
       OR p_trip.attendant_id = transport_current_driver_id())
     -- BUS-012: today only. A driver has no business reading last month's
     -- manifest of children.
     AND p_trip.service_date = CURRENT_DATE;
$$;

/** True when the authenticated parent is an active guardian of this student. */
CREATE OR REPLACE FUNCTION transport_is_guardian_of(p_student UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
  SELECT app_current_scope() = 'parent'
     AND EXISTS (
       SELECT 1 FROM student_guardians sg
       WHERE sg.student_id = p_student
         AND sg.guardian_user_id = app_current_parent_user_id()
         AND sg.organization_id = app_current_tenant_id()
         AND sg.status = 'active'
     );
$$;

-- ── Staff-only master data ───────────────────────────────────────────────────
-- Vehicles, drivers, availability, routes, route-stops and assignments are
-- school-staff surfaces. A driver reads their trip, not the fleet.

DO $$
DECLARE t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'transport_vehicle',
    'transport_driver',
    'transport_driver_availability',
    'transport_route',
    'transport_route_stop',
    'transport_assignment',
    'transport_incident',
    'transport_trip_diversion'
  ] LOOP
    EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
    EXECUTE format($f$
      CREATE POLICY %1$I_staff ON %1$I FOR ALL
      USING (transport_is_school_staff(organization_id, school_id))
      WITH CHECK (transport_is_school_staff(organization_id, school_id))
    $f$, t);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON %I TO erp_tenant', t);
  END LOOP;
END $$;

-- A driver must read their OWN transport_driver row (name, licence status) to
-- render the app profile. Read-only, self only.
CREATE POLICY transport_driver_self_read ON transport_driver FOR SELECT
  USING (
    app_current_scope() = 'driver'
    AND organization_id = app_current_tenant_id()
    AND user_id = app_current_user_id()
  );

-- ── Stops: staff manage; crew/parent/student read only what they need ────────

ALTER TABLE transport_stop ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_stop FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_stop_staff ON transport_stop FOR ALL
  USING (transport_is_school_staff(organization_id, school_id))
  WITH CHECK (transport_is_school_staff(organization_id, school_id));

-- Crew read stops on today's trip route (BUS-066 stop list).
CREATE POLICY transport_stop_crew_read ON transport_stop FOR SELECT
  USING (
    app_current_scope() = 'driver'
    AND EXISTS (
      SELECT 1
      FROM transport_trip t
      JOIN transport_route_stop rs ON rs.route_id = t.route_id
      WHERE rs.stop_id = transport_stop.id
        AND transport_is_trip_crew(t)
    )
  );

-- A parent reads ONLY the two stops their own child uses. Not the route's other
-- stops — publishing where other people's children stand each morning is the
-- child-safety failure this matrix exists to prevent.
CREATE POLICY transport_stop_parent_read ON transport_stop FOR SELECT
  USING (
    app_current_scope() = 'parent'
    AND EXISTS (
      SELECT 1 FROM transport_allocation a
      WHERE (a.pickup_stop_id = transport_stop.id OR a.drop_stop_id = transport_stop.id)
        AND a.status = 'active'
        AND transport_is_guardian_of(a.student_id)
    )
  );

CREATE POLICY transport_stop_student_read ON transport_stop FOR SELECT
  USING (
    app_current_scope() = 'student'
    AND EXISTS (
      SELECT 1 FROM transport_allocation a
      WHERE (a.pickup_stop_id = transport_stop.id OR a.drop_stop_id = transport_stop.id)
        AND a.status = 'active'
        AND a.student_id = app_current_student_id()
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON transport_stop TO erp_tenant;

-- ── Allocation: the table the pre-v2 leak would have come from ───────────────

ALTER TABLE transport_allocation ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_allocation FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_allocation_staff ON transport_allocation FOR ALL
  USING (transport_is_school_staff(organization_id, school_id))
  WITH CHECK (transport_is_school_staff(organization_id, school_id));

-- BUS-059: a parent sees ONE child's row. There is no query a parent can issue
-- against this table that returns another family's data — enforced here, so it
-- holds even if a handler is written carelessly.
CREATE POLICY transport_allocation_parent_read ON transport_allocation FOR SELECT
  USING (transport_is_guardian_of(student_id));

CREATE POLICY transport_allocation_student_read ON transport_allocation FOR SELECT
  USING (
    app_current_scope() = 'student'
    AND student_id = app_current_student_id()
  );

-- Crew read the manifest for TODAY'S trip only (BUS-067).
CREATE POLICY transport_allocation_crew_read ON transport_allocation FOR SELECT
  USING (
    app_current_scope() = 'driver'
    AND EXISTS (
      SELECT 1 FROM transport_trip t
      WHERE t.route_id = transport_allocation.route_id
        AND transport_is_trip_crew(t)
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON transport_allocation TO erp_tenant;

-- ── Trip ─────────────────────────────────────────────────────────────────────

ALTER TABLE transport_trip ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_trip FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_trip_staff ON transport_trip FOR ALL
  USING (transport_is_school_staff(organization_id, school_id))
  WITH CHECK (transport_is_school_staff(organization_id, school_id));

-- BUS-065: the driver app's single read. Today, theirs, nothing else.
CREATE POLICY transport_trip_crew ON transport_trip FOR SELECT
  USING (transport_is_trip_crew(transport_trip));

-- BUS-070/BUS-071: start/end. Same predicate, so a driver can never mutate a
-- trip they do not crew or one from another date.
CREATE POLICY transport_trip_crew_operate ON transport_trip FOR UPDATE
  USING (transport_is_trip_crew(transport_trip))
  WITH CHECK (transport_is_trip_crew(transport_trip));

-- BUS-096: a parent sees the trip carrying THEIR child, and only while it is
-- running. Outside the active window there is nothing to see — position data is
-- not browsable history for a parent.
CREATE POLICY transport_trip_parent_read ON transport_trip FOR SELECT
  USING (
    app_current_scope() = 'parent'
    AND status = 'started'
    AND service_date = CURRENT_DATE
    AND EXISTS (
      SELECT 1 FROM transport_allocation a
      WHERE a.route_id = transport_trip.route_id
        AND a.status = 'active'
        AND transport_is_guardian_of(a.student_id)
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON transport_trip TO erp_tenant;

-- ── Position ─────────────────────────────────────────────────────────────────

ALTER TABLE transport_position ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_position FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_position_staff ON transport_position FOR ALL
  USING (transport_is_school_staff(organization_id, school_id))
  WITH CHECK (transport_is_school_staff(organization_id, school_id));

-- BUS-081: a driver WRITES fixes only for a trip they crew that is STARTED.
-- A fix for any other trip or state is rejected at the database.
CREATE POLICY transport_position_crew_write ON transport_position FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM transport_trip t
      WHERE t.id = transport_position.trip_id
        AND t.status = 'started'
        AND transport_is_trip_crew(t)
    )
  );

-- BUS-096: a parent reads positions only for their child's ACTIVE trip.
CREATE POLICY transport_position_parent_read ON transport_position FOR SELECT
  USING (
    app_current_scope() = 'parent'
    AND EXISTS (
      SELECT 1
      FROM transport_trip t
      JOIN transport_allocation a ON a.route_id = t.route_id AND a.status = 'active'
      WHERE t.id = transport_position.trip_id
        AND t.status = 'started'
        AND t.service_date = CURRENT_DATE
        AND transport_is_guardian_of(a.student_id)
    )
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON transport_position TO erp_tenant;

-- ── Boarding ─────────────────────────────────────────────────────────────────

ALTER TABLE transport_boarding ENABLE ROW LEVEL SECURITY;
ALTER TABLE transport_boarding FORCE ROW LEVEL SECURITY;

CREATE POLICY transport_boarding_staff ON transport_boarding FOR ALL
  USING (transport_is_school_staff(organization_id, school_id))
  WITH CHECK (transport_is_school_staff(organization_id, school_id));

-- BUS-103: crew mark boarding on today's trip.
CREATE POLICY transport_boarding_crew ON transport_boarding FOR ALL
  USING (
    EXISTS (SELECT 1 FROM transport_trip t
            WHERE t.id = transport_boarding.trip_id AND transport_is_trip_crew(t))
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM transport_trip t
            WHERE t.id = transport_boarding.trip_id
              AND t.status = 'started'
              AND transport_is_trip_crew(t))
  );

-- BUS-106: a parent reads their OWN child's boarding history — the record that
-- answers "was my son on the bus last Tuesday?", which the pre-v2 model could
-- not store at all.
CREATE POLICY transport_boarding_parent_read ON transport_boarding FOR SELECT
  USING (transport_is_guardian_of(student_id));

CREATE POLICY transport_boarding_student_read ON transport_boarding FOR SELECT
  USING (
    app_current_scope() = 'student'
    AND student_id = app_current_student_id()
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON transport_boarding TO erp_tenant;

-- ── Crew-raised incidents (BUS-113 SOS) ──────────────────────────────────────

CREATE POLICY transport_incident_crew_raise ON transport_incident FOR INSERT
  WITH CHECK (
    app_current_scope() = 'driver'
    AND organization_id = app_current_tenant_id()
    AND EXISTS (SELECT 1 FROM transport_trip t
                WHERE t.id = transport_incident.trip_id AND transport_is_trip_crew(t))
  );

CREATE POLICY transport_incident_crew_read ON transport_incident FOR SELECT
  USING (
    app_current_scope() = 'driver'
    AND EXISTS (SELECT 1 FROM transport_trip t
                WHERE t.id = transport_incident.trip_id AND transport_is_trip_crew(t))
  );
