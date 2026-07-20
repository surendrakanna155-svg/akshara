// PRA-P0-16 / P1-44 (S5): the shared student→guardian resolution that both the
// teacher "Send to parent" enqueue (P0-16) and the transport route-delay alert
// (P1-44) rely on to notify EXACTLY the affected students' active guardians —
// never the whole school. These pin the query shape (scope, active-only,
// student_code ANY) and the de-dup/empty behaviour against a capturing fake db.

import { assert, assertEquals } from "jsr:@std/assert@1";
import { guardianUserIdsForStudents } from "./guardian_recipients.ts";
import type { TenantQueryClient } from "../tenant_db.ts";

interface Captured {
  sql: string;
  args: unknown[];
}

function fakeDb(
  guardianIds: string[],
): { db: TenantQueryClient; calls: Captured[] } {
  const calls: Captured[] = [];
  const db = {
    // deno-lint-ignore no-explicit-any
    queryObject(sql: string, args: unknown[] = []): Promise<any[]> {
      calls.push({ sql, args });
      return Promise.resolve(guardianIds.map((id) => ({ guardian_user_id: id })));
    },
  } as unknown as TenantQueryClient;
  return { db, calls };
}

Deno.test("guardianUserIdsForStudents scopes by org+school, active links, and student_code ANY", async () => {
  const { db, calls } = fakeDb(["g1", "g2"]);
  const ids = await guardianUserIdsForStudents(db, "org", "school", [
    "SIS-STU-1",
    "SIS-STU-2",
  ]);

  assertEquals(ids, ["g1", "g2"]);
  assertEquals(calls.length, 1);
  const { sql, args } = calls[0];
  assert(sql.includes("FROM students s"));
  assert(sql.includes("JOIN student_guardians sg ON sg.student_id = s.id"));
  assert(sql.includes("s.organization_id = $1"));
  assert(sql.includes("s.school_id = $2"));
  assert(sql.includes("s.student_code = ANY($3::text[])"));
  // Only ACTIVE guardian links are ever notified (matches migration 20260900000012).
  assert(sql.includes("sg.status = 'active'"));
  // DISTINCT so a student with two active guardians never double-enqueues.
  assert(sql.includes("SELECT DISTINCT sg.guardian_user_id"));
  assertEquals(args[0], "org");
  assertEquals(args[1], "school");
  assertEquals(args[2], ["SIS-STU-1", "SIS-STU-2"]);
});

Deno.test("guardianUserIdsForStudents de-duplicates codes and drops blanks", async () => {
  const { db, calls } = fakeDb(["g1"]);
  await guardianUserIdsForStudents(db, "org", "school", [
    "SIS-1",
    " SIS-1 ",
    "",
    "  ",
    "SIS-2",
  ]);
  // Trimmed, de-duplicated, blanks removed.
  assertEquals(calls[0].args[2], ["SIS-1", "SIS-2"]);
});

Deno.test("guardianUserIdsForStudents returns [] with no query when there are no codes", async () => {
  const { db, calls } = fakeDb(["should-not-be-returned"]);
  const ids = await guardianUserIdsForStudents(db, "org", "school", ["", "  "]);
  assertEquals(ids, []);
  assertEquals(calls.length, 0); // no round-trip on an empty cohort
});

Deno.test("guardianUserIdsForStudents returns [] when no active guardian is linked", async () => {
  const { db } = fakeDb([]); // resolution finds nobody
  const ids = await guardianUserIdsForStudents(db, "org", "school", ["SIS-1"]);
  assertEquals(ids, []); // caller reports an honest 0 recipients, not a fake "sent"
});
