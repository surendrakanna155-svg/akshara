-- Approval-permission catalog gap fix.
--
-- approveStaffLeave, approveAttendanceCorrection, approveFeeConcession and
-- approvePurchaseOrder are required by the edge handlers
-- (approval_permissions.ts + attendance_handlers.ts) and already exist in the
-- client RBAC matrix (role_permissions.dart) — but they were never registered
-- in the server permission catalog. Like approveStudentLeave before this, an
-- uncatalogued permission is granted to no role, so every one of these approval
-- decisions would 403 for everyone. Register them and grant to the same roles
-- the client matrix grants them to, keeping client/server parity.

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('approveStaffLeave', 'Approvals', 'approve', 'school', 'Approve or reject a staff leave request'),
  ('approveAttendanceCorrection', 'Approvals', 'approve', 'school', 'Approve or reject an attendance correction'),
  ('approveFeeConcession', 'Finance', 'approve', 'school', 'Approve or reject a fee concession'),
  ('approvePurchaseOrder', 'Inventory', 'approve', 'school', 'Approve or reject a purchase order')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  -- approveStaffLeave: leadership only (not teachers).
  ('superAdmin', 'approveStaffLeave'),
  ('schoolAdmin', 'approveStaffLeave'),
  ('principal', 'approveStaffLeave'),
  ('vicePrincipal', 'approveStaffLeave'),
  ('management', 'approveStaffLeave'),
  -- approveAttendanceCorrection: teacher submits, leadership approves.
  ('superAdmin', 'approveAttendanceCorrection'),
  ('schoolAdmin', 'approveAttendanceCorrection'),
  ('principal', 'approveAttendanceCorrection'),
  ('vicePrincipal', 'approveAttendanceCorrection'),
  ('management', 'approveAttendanceCorrection'),
  -- approveFeeConcession: leadership + finance.
  ('superAdmin', 'approveFeeConcession'),
  ('schoolAdmin', 'approveFeeConcession'),
  ('principal', 'approveFeeConcession'),
  ('vicePrincipal', 'approveFeeConcession'),
  ('management', 'approveFeeConcession'),
  ('financeAdmin', 'approveFeeConcession'),
  -- approvePurchaseOrder: leadership + inventory.
  ('superAdmin', 'approvePurchaseOrder'),
  ('schoolAdmin', 'approvePurchaseOrder'),
  ('principal', 'approvePurchaseOrder'),
  ('vicePrincipal', 'approvePurchaseOrder'),
  ('management', 'approvePurchaseOrder'),
  ('inventoryManager', 'approvePurchaseOrder')
ON CONFLICT DO NOTHING;
