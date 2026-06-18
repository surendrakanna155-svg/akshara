-- Exam governance authorization (P1)
--
-- Registers the granular exam permission catalog server-side and grants it per
-- role, so edge handlers can enforce the SAME granular gates the client already
-- uses. Before this, exam endpoints gated only on coarse viewSis/manageSis,
-- which meant any manageSis holder could read/edit/process/publish marks for
-- every class in the school (audit gap P1 — client/server RBAC drift).

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('viewExams',          'Exams', 'view',    'school', 'View exam sessions and schedule'),
  ('manageExams',        'Exams', 'manage',  'school', 'Create exams and run the lifecycle (schedule, open marks entry)'),
  ('manageExamMarks',    'Exams', 'manage',  'school', 'Enter and edit exam marks'),
  ('submitExamResults',  'Exams', 'submit',  'school', 'Process marks and submit results for approval'),
  ('verifyExamResults',  'Exams', 'verify',  'school', 'Coordinator verification of processed exam marks'),
  ('approveExamResults', 'Exams', 'approve', 'school', 'Approve exam results for publication'),
  ('publishExamResults', 'Exams', 'publish', 'school', 'Publish approved exam results to students and parents')
ON CONFLICT (slug) DO NOTHING;

-- Role grants mirror the client RolePermissionMatrix (lib/core/security/role_permissions.dart).
-- A plain teacher can view/enter/submit marks but cannot verify, approve, or publish.
INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  -- View exam sessions
  ('superAdmin', 'viewExams'),
  ('schoolAdmin', 'viewExams'),
  ('principal', 'viewExams'),
  ('vicePrincipal', 'viewExams'),
  ('teacher', 'viewExams'),
  -- Manage exam lifecycle (create / schedule / open marks entry)
  ('superAdmin', 'manageExams'),
  ('schoolAdmin', 'manageExams'),
  ('principal', 'manageExams'),
  ('vicePrincipal', 'manageExams'),
  -- Enter / edit marks
  ('superAdmin', 'manageExamMarks'),
  ('schoolAdmin', 'manageExamMarks'),
  ('principal', 'manageExamMarks'),
  ('vicePrincipal', 'manageExamMarks'),
  ('management', 'manageExamMarks'),
  ('teacher', 'manageExamMarks'),
  -- Process + submit for approval
  ('superAdmin', 'submitExamResults'),
  ('schoolAdmin', 'submitExamResults'),
  ('principal', 'submitExamResults'),
  ('vicePrincipal', 'submitExamResults'),
  ('management', 'submitExamResults'),
  ('teacher', 'submitExamResults'),
  -- Coordinator verification (oversight — not plain teachers)
  ('superAdmin', 'verifyExamResults'),
  ('schoolAdmin', 'verifyExamResults'),
  ('principal', 'verifyExamResults'),
  ('vicePrincipal', 'verifyExamResults'),
  ('management', 'verifyExamResults'),
  -- Approve results
  ('superAdmin', 'approveExamResults'),
  ('schoolAdmin', 'approveExamResults'),
  ('principal', 'approveExamResults'),
  ('vicePrincipal', 'approveExamResults'),
  ('management', 'approveExamResults'),
  -- Publish results
  ('superAdmin', 'publishExamResults'),
  ('schoolAdmin', 'publishExamResults'),
  ('principal', 'publishExamResults'),
  ('vicePrincipal', 'publishExamResults'),
  ('management', 'publishExamResults')
ON CONFLICT DO NOTHING;
