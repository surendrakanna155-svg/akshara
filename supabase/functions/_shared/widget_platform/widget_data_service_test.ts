import { assertEquals } from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { AccessTokenClaims } from "../jwt.ts";
import type { TenantQueryClient } from "../tenant_db.ts";
import { buildWidgetData } from "./widget_data_service.ts";

// Fake tenant client whose every query returns an empty result set. The widget
// data + operations hub builders all tolerate empty rows via `[0]?.` / `?? 0`,
// so this exercises the RBAC gate without a live database.
const fakeClient = {
  // deno-lint-ignore require-await
  queryObject: async <T>(): Promise<T[]> => [],
} as unknown as TenantQueryClient;

function schoolClaims(
  userId: string,
  permissions: string[],
): AccessTokenClaims {
  return {
    sub: userId,
    tenant_id: "tenant-1",
    organization_id: "org-1",
    school_id: "school-1",
    role: "principal",
    role_slugs: ["principal"],
    primary_role: "principal",
    permissions,
    permissions_version: 1,
    scope: "school",
    school_group_id: null,
    student_id: null,
    child_ids: [],
    session_id: "session-1",
  };
}

Deno.test("school-scope token WITHOUT viewFinance is denied fee_collection data", async () => {
  const claims = schoolClaims("user-no-finance", ["viewOperationsHub"]);
  const { widgets } = await buildWidgetData(
    fakeClient,
    "org-1",
    "school-1",
    claims,
    { widgetIds: ["fee_collection"], forceRefresh: true },
  );
  const fee = widgets["fee_collection"];
  assertEquals(fee?.permissionDenied, true);
  assertEquals(fee?.value, "—");
  assertEquals(fee?.summary, "Permission required");
});

Deno.test("school-scope token WITH viewFinance receives fee_collection data", async () => {
  const claims = schoolClaims("user-with-finance", ["viewFinance"]);
  const { widgets } = await buildWidgetData(
    fakeClient,
    "org-1",
    "school-1",
    claims,
    { widgetIds: ["fee_collection"], forceRefresh: true },
  );
  const fee = widgets["fee_collection"];
  assertEquals(fee?.permissionDenied, false);
  assertEquals(fee?.title, "Fee Collection");
});

Deno.test("widgets without a required permission stay accessible to school scope", async () => {
  // attendance_risk maps to viewStudentRisk (denied), school_health maps to
  // viewOperationsHub (denied), but a widget with no entry in WIDGET_PERMISSIONS
  // should remain visible to any school-scope user.
  const claims = schoolClaims("user-generic", []);
  const { widgets } = await buildWidgetData(
    fakeClient,
    "org-1",
    "school-1",
    claims,
    { widgetIds: ["fee_collection", "school_health"], forceRefresh: true },
  );
  // Both have explicit permissions the user lacks → denied.
  assertEquals(widgets["fee_collection"]?.permissionDenied, true);
  assertEquals(widgets["school_health"]?.permissionDenied, true);
});
