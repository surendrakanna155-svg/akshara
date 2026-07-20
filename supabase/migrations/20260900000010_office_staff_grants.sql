-- PRA-P1-05 (S2) — Reception (officeStaff) becomes a usable, least-privilege
-- front-office role, and a write path for permission overrides is enabled.
--
-- Evidence: 20260608100000_rbac_foundation.sql:238 granted officeStaff a single
-- permission ('officeStaff','viewAdminHub') — an empty admin-hub shell — while
-- membership_permission_overrides was read-only (permission_resolver.ts:114-117
-- SELECTs it; nothing writes it). Reception was therefore either useless or had
-- to be promoted to schoolAdmin (full finance). This migration seeds a realistic
-- front-desk grant set and the accompanying write path (code) unblocks per-user
-- overrides for the exceptions.

-- ─── Reception grant set (least privilege) ──────────────────────────────────
-- Every slug is verified to exist via the INNER JOIN on permission_definitions
-- (self-verifying: a typo'd or non-existent slug is simply skipped, never a FK
-- error), mirroring the recovery-migration convention (20260627110000).
--
-- Why each slug is reception-safe:
--   viewAdminHub         reception's landing surface (already granted; here for
--                        completeness — ON CONFLICT keeps it idempotent).
--   viewSis              front-desk student lookup (name/class/section/contact)
--                        to answer walk-ins and route visitors — READ ONLY.
--   viewAdmissions       front desk fields admission enquiries and sees status.
--   manageAdmissions     front-office data entry: capture walk-in enquiries and
--                        applicant details. NOT approveAdmissions — the admit
--                        DECISION stays with counselor/principal.
--   viewAcademicTimetable reception answers "which class is where / when" —
--                        READ ONLY schedule visibility.
--
-- Deliberately NOT granted (front office must never hold these): any finance
-- (viewFinance/manageFinance/approveRefunds), HR (viewHr/manageHr), exam publish
-- / management (viewManagement/manageManagement), approveAdmissions (approval
-- authority), or manageSis (editing the student master record is registrar-level).
INSERT INTO role_permissions (role_slug, permission_slug)
SELECT v.role_slug, v.permission_slug
FROM (VALUES
  ('officeStaff', 'viewAdminHub'),
  ('officeStaff', 'viewSis'),
  ('officeStaff', 'viewAdmissions'),
  ('officeStaff', 'manageAdmissions'),
  ('officeStaff', 'viewAcademicTimetable')
) AS v(role_slug, permission_slug)
INNER JOIN role_definitions rd ON rd.slug = v.role_slug
INNER JOIN permission_definitions pd ON pd.slug = v.permission_slug
ON CONFLICT DO NOTHING;

-- Force existing officeStaff sessions to re-resolve at their next request (pick
-- up the new grants) instead of waiting out the 15-min token TTL. Targeted: only
-- memberships that actually hold officeStaff. (role_permissions is NOT a trigger
-- table for 20260900000011, so this seed does not auto-bump — do it explicitly.)
UPDATE school_memberships sm
   SET permissions_version = permissions_version + 1
  FROM school_membership_roles smr
 WHERE smr.school_membership_id = sm.id
   AND smr.role_slug = 'officeStaff'
   AND smr.status = 'active';

-- ─── Access model for the override write path (deliberate: NO erp_tenant grant) ──
-- The write path added in this batch (rbac/rbac_handlers.ts) writes
-- membership_permission_overrides through the SERVICE-ROLE client, exactly as the
-- READ path already does (permission_resolver.ts uses createServiceClient). This
-- table carries NO row-level-security policy (verified: rbac_foundation enables
-- none) and NO grants to erp_tenant. Granting erp_tenant direct INSERT/UPDATE here
-- WITHOUT an RLS policy would open a cross-tenant hole — an erp_tenant connection
-- scoped to tenant A could grant/deny permissions on tenant B's memberships. So we
-- intentionally do NOT add an erp_tenant grant; tenant isolation for overrides is
-- enforced in the handler (the target membership must resolve within the caller's
-- own claims.school_id) and the endpoint is gated on manageSchoolSetup + audited.
-- No GRANT statement is emitted on purpose.
