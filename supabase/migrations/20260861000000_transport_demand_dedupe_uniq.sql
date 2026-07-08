-- Gap-sweep wave 2 · step 2 (money-adjacent hardening) —
-- TRN-9 duplicate-demand race backstop.
--
-- handleRaiseTransportDemand (transport_write_handlers.ts) dedupes a raised
-- Finance transport-fee demand on dedupeKey = sisStudentId::routeId::
-- academicYear::term via a plain read-then-write
-- (writeStore.findAll(...).find(...) followed by writeStore.insert(...)).
-- That is a TOCTOU: two concurrent identical raise-demand requests can both
-- pass the read check before either has written, and both insert a `demand`
-- row for the same (student, route, year, term).
--
-- Money itself is contained downstream — Finance's assignment uniqueness
-- already blocks a double-invoice — but a duplicate `demand` entity row is
-- still a data-integrity defect (double-counted in any demand-facing report,
-- confusing to ops). This adds the DB-layer backstop: one demand per
-- dedupeKey per school. Partial (`WHERE entity_type = 'demand' AND payload ?
-- 'dedupeKey'`) so:
--   • it only constrains `demand` rows, never other transport_entities types
--     (route/vehicle/driver/attendance/...) sharing the same table;
--   • legacy demand rows written before dedupeKey existed (payload lacks the
--     key) are never collapsed against each other by this index.
--
-- The handler-side race recovery (SAVEPOINT + catch 23505 → idempotent reread)
-- is added alongside this migration in transport_write_handlers.ts.

CREATE UNIQUE INDEX IF NOT EXISTS transport_entities_demand_dedupe_key_uniq
  ON transport_entities (organization_id, school_id, (payload ->> 'dedupeKey'))
  WHERE entity_type = 'demand' AND payload ? 'dedupeKey';
