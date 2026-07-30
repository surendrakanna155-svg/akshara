// ICA-G3 — static guard over migration 20260920000200_tenant_custom_roles.sql.
// The full backend suite runs with only --allow-env --allow-read (no DB), so the
// DB-level enforcement (RLS, org-match trigger, detector, uniqueness) is asserted
// by SHAPE over the migration text here, and exercised live at deploy/cert time.
// Also proves the migration is safely re-runnable via the shared guard.

import { assert, assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { findRerunnabilityViolations } from "../migration_rerunnability_guard_test.ts";

const MIG = new URL(
  "../../../migrations/20260920000200_tenant_custom_roles.sql",
  import.meta.url,
);
const SQL = Deno.readTextFileSync(MIG);

Deno.test("G3 migration: adds nullable organization_id to both catalog tables", () => {
  assert(/ALTER TABLE role_definitions[\s\S]*?ADD COLUMN IF NOT EXISTS organization_id UUID/i.test(SQL));
  assert(/ALTER TABLE role_permissions[\s\S]*?ADD COLUMN IF NOT EXISTS organization_id UUID/i.test(SQL));
});

Deno.test("G3 migration: enforces the system/custom consistency invariant", () => {
  assert(SQL.includes("role_definitions_system_org_chk"));
  assert(/organization_id IS NULL AND is_system = true/i.test(SQL));
  assert(/organization_id IS NOT NULL AND is_system = false/i.test(SQL));
});

Deno.test("G3 migration: re-scopes uniqueness for the custom namespace", () => {
  assert(/CREATE UNIQUE INDEX IF NOT EXISTS role_definitions_org_slug_uq[\s\S]*?WHERE organization_id IS NOT NULL/i.test(SQL));
  assert(/CREATE UNIQUE INDEX IF NOT EXISTS role_definitions_org_dispname_uq/i.test(SQL));
});

Deno.test("G3 migration: RLS makes system rows read-only to tenants, org-scoped writes", () => {
  assert(/ALTER TABLE role_definitions ENABLE ROW LEVEL SECURITY/i.test(SQL));
  assert(/ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY/i.test(SQL));
  assert(/GRANT SELECT, INSERT, UPDATE, DELETE ON role_definitions TO erp_tenant/i.test(SQL));

  // Write policies must require own-org AND non-system (system rows immutable).
  for (const policy of ["role_definitions_tenant_insert", "role_definitions_tenant_update", "role_definitions_tenant_delete"]) {
    assert(SQL.includes(policy), `missing policy ${policy}`);
  }
  // The update + delete gates must both require organization_id = tenant and is_system = false.
  const updateBlock = SQL.slice(SQL.indexOf("role_definitions_tenant_update"), SQL.indexOf("role_definitions_tenant_delete"));
  assert(/organization_id = app_current_tenant_id\(\)/.test(updateBlock));
  assert(/is_system = false/.test(updateBlock));
  const deleteBlock = SQL.slice(SQL.indexOf("role_definitions_tenant_delete"), SQL.indexOf("role_permissions_tenant_read"));
  assert(/organization_id = app_current_tenant_id\(\)/.test(deleteBlock));
  assert(/is_system = false/.test(deleteBlock));
});

Deno.test("G3 migration: org-match invariant trigger on both membership tables", () => {
  assert(SQL.includes("app_enforce_membership_role_org"));
  assert(/CREATE OR REPLACE TRIGGER school_membership_roles_org_match/i.test(SQL));
  assert(/CREATE OR REPLACE TRIGGER organization_membership_roles_org_match/i.test(SQL));
  // System roles (org NULL) must always pass — the "no regression" guarantee.
  assert(/IF v_role_org IS NULL THEN[\s\S]*?RETURN NEW/i.test(SQL));
});

Deno.test("G3 migration: role_permissions.organization_id auto-synced from its role", () => {
  assert(SQL.includes("app_sync_role_permission_org"));
  assert(/CREATE OR REPLACE TRIGGER role_permissions_org_sync/i.test(SQL));
});

Deno.test("G3 migration: privileged violation detector (E2/F5 posture)", () => {
  assert(SQL.includes("app_detect_custom_role_violations"));
  assert(/REVOKE ALL ON FUNCTION app_detect_custom_role_violations\(\) FROM PUBLIC/i.test(SQL));
  assert(/GRANT EXECUTE ON FUNCTION app_detect_custom_role_violations\(\) TO service_role/i.test(SQL));
});

Deno.test("G3 migration: is safely re-runnable (shared idempotency guard)", () => {
  assertEquals(findRerunnabilityViolations(SQL), []);
});
