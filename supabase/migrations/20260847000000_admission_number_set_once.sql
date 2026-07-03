-- Identity rule C5 ("an id never changes") — admission_number is SET-ONCE.
--
-- The frozen Akshara Identity Platform requires a student's admission_number to
-- be a permanent, immutable identity value: legitimately SET on create, then
-- locked forever with NO self-service override. student_profiles.admission_number
-- is the canonical location for that value.
--
-- The application already refuses a change in updateStudent() (409
-- ADMISSION_NUMBER_IMMUTABLE) and audits the rejected attempt. This trigger is
-- defense-in-depth: it backstops that guard against ANY direct/rogue UPDATE
-- (psql, a future code path, a bad migration) that would try to alter an
-- already-assigned admission_number. Legitimate set-on-create still works
-- because the pre-image (OLD.admission_number) is NULL on the INSERT and this is
-- a BEFORE UPDATE trigger only. A no-op UPDATE (same value) is allowed via the
-- IS DISTINCT FROM comparison, so unrelated profile-field edits are unaffected.
--
-- Idempotent: CREATE OR REPLACE FUNCTION + DROP TRIGGER IF EXISTS / CREATE
-- TRIGGER so re-applying this migration is safe.

CREATE OR REPLACE FUNCTION reject_admission_number_change()
RETURNS TRIGGER AS $$
BEGIN
  -- Set-once: once a non-empty admission_number is assigned it cannot change to
  -- a DIFFERENT value. NULL/first-time assignment and idempotent same-value
  -- writes are permitted. IS DISTINCT FROM treats NULL correctly (no false
  -- positive when OLD is NULL — that branch is excluded by OLD ... IS NOT NULL).
  IF OLD.admission_number IS NOT NULL
     AND OLD.admission_number IS DISTINCT FROM NEW.admission_number THEN
    RAISE EXCEPTION 'admission_number_immutable: admission_number is set-once and cannot be changed (current: %, attempted: %).',
      OLD.admission_number, NEW.admission_number
      USING ERRCODE = 'check_violation';
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS student_profiles_reject_admission_number_change ON student_profiles;

CREATE TRIGGER student_profiles_reject_admission_number_change
  BEFORE UPDATE ON student_profiles
  FOR EACH ROW EXECUTE FUNCTION reject_admission_number_change();
