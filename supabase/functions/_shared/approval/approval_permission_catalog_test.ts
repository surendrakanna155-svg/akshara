import { assert } from "https://deno.land/std@0.224.0/assert/mod.ts";
import { F2_APPROVAL_TYPES } from "./approval_types.ts";
import { approvalPermissionForType } from "./approval_permissions.ts";

// Regression guard for the "uncatalogued approval permission → 403 for everyone"
// class of bug (hit by approveStudentLeave, then approveStaffLeave /
// approveAttendanceCorrection / approveFeeConcession / approvePurchaseOrder).
//
// Every permission an approval type requires MUST be registered in the server
// permission catalog (a permission_definitions INSERT in some migration). If it
// isn't, no role is granted it and the decision endpoint denies everyone.

async function migrationCatalogText(): Promise<string> {
  // This test file lives at supabase/functions/_shared/approval/ — walk up to
  // the repo root and read every migration's SQL.
  const here = new URL(".", import.meta.url);
  const migrationsDir = new URL("../../../migrations/", here);
  let combined = "";
  for await (const entry of Deno.readDir(migrationsDir)) {
    if (!entry.isFile || !entry.name.endsWith(".sql")) continue;
    combined += await Deno.readTextFile(new URL(entry.name, migrationsDir));
    combined += "\n";
  }
  return combined;
}

Deno.test("every approval-type permission is registered in the catalog", async () => {
  const catalog = await migrationCatalogText();
  for (const type of F2_APPROVAL_TYPES) {
    const permission = approvalPermissionForType(type);
    assert(permission, `no permission mapped for approval type ${type}`);
    // The slug must appear in a permission_definitions INSERT, e.g. ('slug',...).
    assert(
      catalog.includes(`'${permission}'`),
      `approval permission "${permission}" (type ${type}) is not registered in ` +
        `any migration's permission catalog — it would 403 for every role`,
    );
  }
});
