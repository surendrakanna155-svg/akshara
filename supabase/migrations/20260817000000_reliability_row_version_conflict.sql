-- Data Reliability Platform (Phase 0b) — row versioning + conflict detection.
--
-- Adds an optimistic-concurrency `row_version` to the entities that participate
-- in queued/offline writes (design §8.2). A BEFORE-UPDATE trigger increments it
-- on every update, so a write that was queued offline can carry the version it
-- was based on; if the row changed underneath it the server returns
-- `409 CONFLICT` with the current row, which the client resolves (low-risk
-- last-write-wins re-applies with the new version; high-risk parks for the user).
--
-- Additive and backward-compatible: every existing row defaults to version 1 and
-- a write that does NOT send `expectedVersion` behaves exactly as before.

-- Shared trigger: bump row_version on every UPDATE.
CREATE OR REPLACE FUNCTION bump_row_version()
RETURNS TRIGGER AS $$
BEGIN
  NEW.row_version := COALESCE(OLD.row_version, 0) + 1;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- exam_mark_entries — per-cell marks (the primary UPDATE path: two teachers can
-- edit the same grid).
ALTER TABLE exam_mark_entries
  ADD COLUMN IF NOT EXISTS row_version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS exam_mark_entries_row_version ON exam_mark_entries;
CREATE TRIGGER exam_mark_entries_row_version
  BEFORE UPDATE ON exam_mark_entries
  FOR EACH ROW EXECUTE FUNCTION bump_row_version();

-- finance_collections — money record-of-truth (high-risk).
ALTER TABLE finance_collections
  ADD COLUMN IF NOT EXISTS row_version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS finance_collections_row_version ON finance_collections;
CREATE TRIGGER finance_collections_row_version
  BEFORE UPDATE ON finance_collections
  FOR EACH ROW EXECUTE FUNCTION bump_row_version();

-- mobile_leave_requests — parent/teacher leave applications.
ALTER TABLE mobile_leave_requests
  ADD COLUMN IF NOT EXISTS row_version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS mobile_leave_requests_row_version ON mobile_leave_requests;
CREATE TRIGGER mobile_leave_requests_row_version
  BEFORE UPDATE ON mobile_leave_requests
  FOR EACH ROW EXECUTE FUNCTION bump_row_version();

-- attendance_corrections — correction requests.
ALTER TABLE attendance_corrections
  ADD COLUMN IF NOT EXISTS row_version INTEGER NOT NULL DEFAULT 1;
DROP TRIGGER IF EXISTS attendance_corrections_row_version ON attendance_corrections;
CREATE TRIGGER attendance_corrections_row_version
  BEFORE UPDATE ON attendance_corrections
  FOR EACH ROW EXECUTE FUNCTION bump_row_version();
