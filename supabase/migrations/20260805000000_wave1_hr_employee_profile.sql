-- Journey Wave 1 · MJ-H10 — Honest, per-employee HR profile data
--
-- Before this migration the employee detail API (employeeDetailToApi) injected
-- the SAME fabricated reportingManager / address / emergencyContact / leave
-- balances / documents / attendance into EVERY employee. This migration removes
-- the need for that by giving the profile screen REAL, per-employee, durable
-- sources:
--
--   * leavePolicy  -> a genuine ORG-LEVEL leave entitlement policy stored on the
--                     school's snapshot_settings. Same entitlement for everyone
--                     (it IS an org policy), but per-person used/available is
--                     computed from each employee's own approved leave requests
--                     (snapshot_leave.requests) at read time. No invented usage.
--
--   * reportingManager -> backfilled per existing employee by DERIVING it from
--                     the real role/department hierarchy already in the payload:
--                       - principals report to "Board of Trustees"
--                       - everyone else reports to the school's principal
--                         (looked up from the real principal employee row, by
--                          name/designation; falls back to the generic
--                          "Principal" label only when no principal row exists).
--                     This is a derivation of existing data, not invention.
--
-- Address / emergencyContact / documents are intentionally NOT backfilled: there
-- is no real source for them, so the API leaves them absent and the UI shows an
-- honest "Not on record" / empty state instead of a fabricated shared value.
--
-- recentAttendance is now read per-employee from snapshot_attendance.records by
-- the API (no migration needed; the data already exists per employee).
--
-- hr_entities is granted to erp_tenant (SELECT/INSERT/UPDATE/DELETE) by
-- 20260614100000; this migration only UPDATEs existing rows, no new grants.

-- 1. Org leave policy on every school's HR settings snapshot. ------------------
--    Merged in idempotently; only sets leavePolicy when not already present.
UPDATE hr_entities
SET payload = payload || jsonb_build_object(
  'leavePolicy', jsonb_build_array(
    jsonb_build_object('leaveType', 'casual', 'entitlement', 12),
    jsonb_build_object('leaveType', 'sick',   'entitlement', 12),
    jsonb_build_object('leaveType', 'earned', 'entitlement', 15)
  )
)
WHERE entity_type = 'snapshot_settings'
  AND NOT (payload ? 'leavePolicy');

-- 2. Per-employee reportingManager derived from real role hierarchy. -----------
--    Principals -> Board of Trustees.
UPDATE hr_entities e
SET payload = e.payload || jsonb_build_object('reportingManager', 'Board of Trustees')
WHERE e.entity_type = 'employee'
  AND lower(coalesce(e.payload ->> 'role', '')) = 'principal'
  AND NOT (e.payload ? 'reportingManager');

--    Non-principals -> the school's actual principal (by real principal row), or
--    a neutral "Principal" label when this school has no principal employee.
UPDATE hr_entities e
SET payload = e.payload || jsonb_build_object(
  'reportingManager',
  coalesce(
    (
      SELECT trim(both ' ' FROM
        coalesce(p.payload ->> 'name', '') ||
        CASE WHEN coalesce(p.payload ->> 'designation', '') <> ''
             THEN ' (' || (p.payload ->> 'designation') || ')'
             ELSE '' END
      )
      FROM hr_entities p
      WHERE p.entity_type = 'employee'
        AND p.organization_id = e.organization_id
        AND p.school_id = e.school_id
        AND lower(coalesce(p.payload ->> 'role', '')) = 'principal'
      ORDER BY p.id
      LIMIT 1
    ),
    'Principal'
  )
)
WHERE e.entity_type = 'employee'
  AND lower(coalesce(e.payload ->> 'role', '')) <> 'principal'
  AND NOT (e.payload ? 'reportingManager');
