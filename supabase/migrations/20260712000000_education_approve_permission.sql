-- Question-paper validation governance: a distinct "approve" permission so the
-- person who VALIDATES (approves / requests changes / publishes) a paper is a
-- principal-level reviewer, not the subject teacher who built it.
--
-- Before this, submit and approve both used `manageEducation`, which teachers
-- hold — so a teacher could sign off their own paper. `approveEducation` is held
-- only by principal-level roles; teachers keep `manageEducation` (create, edit,
-- fix, moderate AI candidates, submit for review) but can no longer approve or
-- publish. Mirrors the existing approveAdmissions / approveRefunds split.

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('approveEducation', 'Education', 'approve', 'school',
   'Validate question papers: approve / request changes and publish')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'approveEducation'),
  ('schoolAdmin', 'approveEducation'),
  ('principal', 'approveEducation'),
  ('vicePrincipal', 'approveEducation')
ON CONFLICT DO NOTHING;
