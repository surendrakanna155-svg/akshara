-- PRA-P0-10 (S3): backfill exam_remarks.author_name from the trusted user record.
--
-- GAP: exam_administration_handlers.ts:990 set
--        authorName: String(body.authorName ?? body.author_name ?? claims.sub)
--      i.e. the author DISPLAY NAME was taken from the request body (spoofable),
--      while authorId (:989) was correctly the authenticated claims.sub. That
--      client-supplied name was persisted to exam_remarks.author_name (and into
--      the append-only history[] jsonb) via upsertExamRemark
--      (exam_administration_repository.ts:1543). The code fix now resolves
--      author_name SERVER-SIDE from users.display_name keyed on author_id and
--      ignores the body value.
--
-- This migration rewrites the CURRENT author_name column for existing rows so the
-- stored value reflects the trusted user record, correcting any spoofed names
-- already persisted. author_id is a users.id (see exam_administration_handlers.ts
-- passing claims.sub as authorId), so the join is on u.id = er.author_id.
--
-- users.display_name is `TEXT NOT NULL DEFAULT ''` (20260607100000_core_platform_schema.sql:37),
-- so guard against overwriting a real name with an empty string: only rewrite when
-- the user record actually carries a non-empty display name (u.display_name <> '').
-- Rows whose author_id is NULL (or no matching user) are left untouched.
--
-- ⚠ APPEND-ONLY AUDIT TRAIL — NOT REWRITTEN:
--   The exam_remarks.history jsonb array is an append-only audit trail. Historical
--   entries record what was submitted AT THE TIME and are deliberately left EXACTLY
--   as recorded. This migration touches ONLY the current author_name column; it does
--   NOT modify, rewrite, or backfill any history[] entry. Going forward, new history
--   entries carry the server-resolved trusted name (see upsertExamRemark).

UPDATE exam_remarks er
   SET author_name = u.display_name
  FROM users u
 WHERE u.id = er.author_id
   AND u.display_name IS NOT NULL
   AND u.display_name <> ''
   AND er.author_name IS DISTINCT FROM u.display_name;
