-- BUS-016 — enable PostGIS for the Transport v2 schema.
--
-- WHY THIS MUST COME FIRST
--
-- Nearest-stop resolution, geofence entry/exit, distance-to-stop and route
-- corridor checks are all impossible without a real geography type. The old
-- module stored coordinates as JSON floats in seed fixtures only — the write
-- path never accepted them at all, so every stop a real school created sat at
-- 0°N 0°E, in the Atlantic Ocean off Ghana.
--
-- Adding PostGIS AFTER live geographic data exists means migrating that data.
-- It is enabled before the first coordinate is stored, per roadmap principle
-- P-5 and TRANSPORT_DOMAIN_CONTRACT.md §1.
--
-- CONVENTIONS FIXED HERE (binding on every later transport migration):
--   * coordinates are GEOGRAPHY(POINT, 4326) — geography, not geometry, so
--     ST_Distance returns metres on a spheroid without per-call projection.
--   * every geography column carries a GiST index.
--   * bounding-box sanity is enforced by CHECK, not by application code.

CREATE EXTENSION IF NOT EXISTS postgis;

-- ── Shared helpers ───────────────────────────────────────────────────────────

/**
 * BUS-016 — plausibility guard for a stored coordinate.
 *
 * Rejects the two failure modes the audit found in practice:
 *   (a) NULL Island (0,0) — what the old model produced for EVERY stop created
 *       through the product, because the write path silently dropped
 *       coordinates and the client mapper defaulted them to 0;
 *   (b) out-of-range latitude/longitude from a malformed device payload.
 *
 * Deliberately NOT a per-school bounding box: schools near the prime meridian
 * or equator are legitimate, and a tight box would reject valid data. The
 * per-school range check lives in the application layer (BUS-037), where the
 * school's own location is known.
 */
CREATE OR REPLACE FUNCTION transport_is_plausible_point(pt GEOGRAPHY)
RETURNS BOOLEAN
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT pt IS NOT NULL
     AND ST_X(pt::geometry) BETWEEN -180 AND 180
     AND ST_Y(pt::geometry) BETWEEN -90 AND 90
     -- NULL Island: the exact signature of a dropped coordinate.
     AND NOT (ABS(ST_X(pt::geometry)) < 0.0001 AND ABS(ST_Y(pt::geometry)) < 0.0001);
$$;

COMMENT ON FUNCTION transport_is_plausible_point(GEOGRAPHY) IS
  'BUS-016: rejects NULL Island (0,0) and out-of-range coordinates. (0,0) was '
  'the value every stop got in the pre-v2 model when the write path dropped it.';
