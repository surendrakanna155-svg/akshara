-- BUS-009 / BUS-004 / BUS-005 — remove FABRICATED transport fixtures.
--
-- Migration 20260614100000 seeded a set of `snapshot_*` documents directly into
-- a schema migration. They were never recomputed by any code path, so whatever a
-- school saw on the transport dashboard was frozen migration content:
--
--   snapshot_dashboard  "18 Active Buses", "94% On-Time", "842 Students Picked",
--                       and a fuel KPI whose own seed annotated it
--                       "Finance integration placeholder" while it rendered as a
--                       live money figure (BUS-005).
--   snapshot_tracking   two buses at fixed Hitech City coordinates, with the
--                       literal note "GPS architecture placeholder" — there is
--                       no position source in the system at all.
--   snapshot_reports    static on-time / delay / fuel trend arrays.
--   snapshot_occupancy  a fixed 860/842/88% occupancy triple.
--
-- BUS-004 replaced handleDashboard with counts computed from live rows, so
-- snapshot_dashboard and snapshot_occupancy are now dead data. Tracking and
-- reports have no honest computable source yet (Phase 9 / BUS-123), so their
-- handlers correctly return an empty envelope which the client renders as a
-- "not configured" state. Leaving these rows in place would keep serving the
-- fiction to any tenant that inherited them.
--
-- WHAT IS DELIBERATELY KEPT:
--   * the two `route` rows referenced by the tenant-isolation probes
--     (TRANSPORT_ROUTE_SCHOOL_A / _SCHOOL_B in transport_read_repository.ts).
--     Dropping them would silently disable cross-school isolation probes.
--   * the demo vehicle / driver / allocation / attendance rows, which are
--     legitimate demo-tenant content, not fabricated measurements.
--   * `snapshot_settings`, minus its fake GPS-provider entry (below).
--
-- Scoped by exact entity_type so a real tenant that never received the seed is
-- unaffected. Forward-only and idempotent.

DELETE FROM transport_entities
WHERE entity_type IN (
  'snapshot_dashboard',
  'snapshot_tracking',
  'snapshot_reports',
  'snapshot_occupancy'
);

-- BUS-009 — the settings snapshot advertised a GPS provider that does not exist:
--   {"id": "gps_provider", "value": "Placeholder — Mapbox",
--    "description": "Live tracking integration", "editable": false}
-- No map SDK is integrated on any platform (BUS-086 selects and wires one), so
-- this line told a transport admin the product had a capability it did not.
-- Strip that item; keep the rest of the settings document intact.
UPDATE transport_entities
SET payload = jsonb_set(
  payload,
  '{sections}',
  COALESCE(
    (
      SELECT jsonb_agg(
        CASE
          WHEN section ? 'items' THEN jsonb_set(
            section,
            '{items}',
            COALESCE(
              (
                SELECT jsonb_agg(item)
                FROM jsonb_array_elements(section -> 'items') AS item
                WHERE item ->> 'id' IS DISTINCT FROM 'gps_provider'
              ),
              '[]'::jsonb
            )
          )
          ELSE section
        END
      )
      FROM jsonb_array_elements(payload -> 'sections') AS section
    ),
    '[]'::jsonb
  )
)
WHERE entity_type = 'snapshot_settings'
  AND payload -> 'sections' IS NOT NULL
  AND payload::text LIKE '%gps_provider%';
