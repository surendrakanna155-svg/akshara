-- RT-11-6 (P4-RT-1 round 3) — comm_broadcasts had NO index beyond its primary key,
-- so the Universal Search "communications" category (search_repository.ts
-- searchBroadcasts: organization_id/school_id scope + lower(title) LIKE) fell back
-- to a full sequential scan of the WHOLE table (every broadcast, every school) that
-- worsens monotonically as broadcast history accumulates platform-wide.
--
-- This closes it, mirroring the established search-index pattern (20260871/20260874)
-- + pg_trgm for the leading-wildcard title-CONTAINS fallback. Additive/dormant:
-- indexes only, touches no data, changes no results.
-- NOTE (prod-scale): on a very large existing table prefer CREATE INDEX CONCURRENTLY
-- (outside a txn); kept plain for the migration runner, matching 20260871/20260874,
-- and cheap here (the table is small on the pilot).

CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tenant scoping: bound the scan to one org/school (the leading organization_id
-- column also covers the school_id IS NULL org-wide broadcasts the query unions in).
CREATE INDEX IF NOT EXISTS idx_comm_broadcasts_org_school
  ON comm_broadcasts (organization_id, school_id);

-- Title match: a trigram GIN serves BOTH the prefix (lower(title) LIKE 'x%') and the
-- contains (LIKE '%x%') paths that searchBroadcasts uses.
CREATE INDEX IF NOT EXISTS idx_comm_broadcasts_title_trgm
  ON comm_broadcasts USING gin (lower(title) gin_trgm_ops);
