-- RT-9-2 (P4-RT-1 round 3) — close the referential-integrity + SoD gaps on
-- student_clearance_waivers (added in 20260878), matching this codebase's own
-- maker-checker precedent inventory_stock_movements (20260839):
--   * student_id / maker_id / checker_id gained NO foreign keys
--   * the maker != checker separation-of-duties was enforced only in app code,
--     with no DB-level CHECK backstop.
-- The Red Team flagged this as a latent defense-in-depth gap (currently not
-- exploitable — students are never hard-deleted and the repository is the sole
-- writer — but a real schema inconsistency vs. the established pattern).
--
-- Additive + forward-fixing. The table is EMPTY in production (verified
-- 2026-07-14), so the plain ADD CONSTRAINTs validate instantly and are fully
-- enforcing from here. If a non-production environment holds a row that violates
-- one of these, the migration fails loudly — the correct outcome for surfacing
-- genuinely bad data. No data is written or dropped.

ALTER TABLE student_clearance_waivers
  ADD CONSTRAINT clearance_waiver_student_fk
    FOREIGN KEY (student_id) REFERENCES students (id),
  ADD CONSTRAINT clearance_waiver_maker_fk
    FOREIGN KEY (maker_id) REFERENCES users (id),
  ADD CONSTRAINT clearance_waiver_checker_fk
    FOREIGN KEY (checker_id) REFERENCES users (id),
  -- DB-level separation of duties: the checker can never be the maker (mirrors
  -- inventory_stock_movements' CHECK (checker_id IS NULL OR checker_id <> maker_id)).
  -- Defense-in-depth behind the repository's decideWaiver SELF_APPROVE_DENIED guard.
  ADD CONSTRAINT clearance_waiver_sod_check
    CHECK (checker_id IS NULL OR checker_id <> maker_id);
