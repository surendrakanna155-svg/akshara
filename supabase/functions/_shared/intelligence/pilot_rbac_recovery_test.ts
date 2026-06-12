import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";

const RECOVERY_PATH = new URL(
  "../../../migrations/20260627110000_pilot_rbac_permission_recovery.sql",
  import.meta.url,
);

const CATALOG_PATH = new URL(
  "../../../migrations/20260627105000_pilot_permission_catalog_recovery.sql",
  import.meta.url,
);

const sql = await Deno.readTextFile(RECOVERY_PATH);
const catalogSql = await Deno.readTextFile(CATALOG_PATH);

Deno.test("pilot permission catalog recovery seeds required definitions", () => {
  assert(catalogSql.includes("('viewSubjects',"));
  assert(catalogSql.includes("('viewFinanceIntelligence',"));
  assert(catalogSql.includes("('viewParentExperience', 'Parent', 'view', 'self'"));
  assert(catalogSql.includes("ON CONFLICT (slug) DO NOTHING"));
});

Deno.test("pilot RBAC recovery grants schoolAdmin viewSubjects", () => {
  assert(sql.includes("('schoolAdmin', 'viewSubjects')"));
  assert(sql.includes("('schoolAdmin', 'viewFinanceIntelligence')"));
  assert(sql.includes("('schoolAdmin', 'viewCommunicationAnalytics')"));
});

Deno.test("pilot RBAC recovery grants parent insight permissions only", () => {
  assert(sql.includes("('parent', 'viewParentExperience')"));
  assert(sql.includes("('parent', 'viewParentAcademicSummary')"));
  assert(!sql.includes("viewAiCopilot"));
});

Deno.test("pilot RBAC recovery bumps permissions_version", () => {
  assert(sql.includes("UPDATE school_memberships SET permissions_version"));
  assert((sql.match(/ON CONFLICT DO NOTHING/g) ?? []).length >= 3);
});
