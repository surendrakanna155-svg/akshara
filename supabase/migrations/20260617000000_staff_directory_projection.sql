-- Sprint 4 Phase 5C.0e — Staff directory projection on school_memberships
-- Replaces transitional users_school_staff_directory with member_display_name snapshot.
-- Idempotent: safe to re-apply.

ALTER TABLE school_memberships
  ADD COLUMN IF NOT EXISTS member_display_name TEXT;

-- Backfill active and inactive memberships from canonical users.display_name.
UPDATE school_memberships sm
SET member_display_name = u.display_name,
    updated_at = timezone('utc', now())
FROM users u
WHERE u.id = sm.user_id
  AND (
    sm.member_display_name IS NULL
    OR sm.member_display_name IS DISTINCT FROM u.display_name
  );

UPDATE school_memberships
SET member_display_name = COALESCE(member_display_name, '')
WHERE member_display_name IS NULL;

-- Propagate user display-name changes to all school membership snapshots.
CREATE OR REPLACE FUNCTION sync_school_membership_display_names()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE school_memberships sm
    SET member_display_name = NEW.display_name,
        updated_at = timezone('utc', now())
    WHERE sm.user_id = NEW.id;
  ELSIF NEW.display_name IS DISTINCT FROM OLD.display_name THEN
    UPDATE school_memberships sm
    SET member_display_name = NEW.display_name,
        updated_at = timezone('utc', now())
    WHERE sm.user_id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS users_sync_school_membership_display_names ON users;
CREATE TRIGGER users_sync_school_membership_display_names
  AFTER INSERT OR UPDATE OF display_name ON users
  FOR EACH ROW
  EXECUTE FUNCTION sync_school_membership_display_names();

-- Snapshot display name when a membership row is created (membership writes use elevated paths).
CREATE OR REPLACE FUNCTION snapshot_school_membership_display_name()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.member_display_name IS NULL OR btrim(NEW.member_display_name) = '' THEN
    SELECT u.display_name
    INTO NEW.member_display_name
    FROM users u
    WHERE u.id = NEW.user_id;
    NEW.member_display_name := COALESCE(NEW.member_display_name, '');
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS school_memberships_snapshot_display_name ON school_memberships;
CREATE TRIGGER school_memberships_snapshot_display_name
  BEFORE INSERT ON school_memberships
  FOR EACH ROW
  EXECUTE FUNCTION snapshot_school_membership_display_name();

REVOKE ALL ON FUNCTION snapshot_school_membership_display_name() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION snapshot_school_membership_display_name() TO postgres;

-- Restore users tenant read model: self-access only (drop 5C.0d expansion).
DROP POLICY IF EXISTS users_school_staff_directory ON users;
