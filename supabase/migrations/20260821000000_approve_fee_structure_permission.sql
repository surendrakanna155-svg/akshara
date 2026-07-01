-- Approval catalog gap #2 — approveFeeStructure.
--
-- `feeStructure` is a client approval type (approval_request_type.dart) mapped to
-- Permission.approveFeeStructure (approval_permissions.dart) and granted in the
-- client RBAC matrix to 6 leadership/finance roles — but the server never
-- registered the permission NOR recognised `feeStructure` as an approval type, so
-- a fee-structure approval 422'd on submit and, even if submitted, the structure
-- was never flipped from `inactive` to `active`. This registers the permission
-- (the type + activation are wired in approval_types.ts / approval_type_handlers.ts)
-- and grants it to the same roles the client matrix grants it to (parity with
-- approveFeeConcession).

INSERT INTO permission_definitions (slug, module, action, scope, description) VALUES
  ('approveFeeStructure', 'Finance', 'approve', 'school', 'Approve or reject a fee structure')
ON CONFLICT (slug) DO NOTHING;

INSERT INTO role_permissions (role_slug, permission_slug) VALUES
  ('superAdmin', 'approveFeeStructure'),
  ('schoolAdmin', 'approveFeeStructure'),
  ('principal', 'approveFeeStructure'),
  ('vicePrincipal', 'approveFeeStructure'),
  ('management', 'approveFeeStructure'),
  ('financeAdmin', 'approveFeeStructure')
ON CONFLICT DO NOTHING;
