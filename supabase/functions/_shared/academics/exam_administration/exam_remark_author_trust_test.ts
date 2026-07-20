// PRA-P0-10 (S3): the author DISPLAY NAME on an exam remark must be resolved
// server-side from the authenticated user's `users.display_name`, NEVER from the
// (spoofable) request body. These tests exercise upsertExamRemark through a mock
// db seam (mirroring exam_administration_authz_test.ts's MockAssignmentsDb) and
// assert the persisted author_name — both the column AND the appended history
// revision — comes from the user record, and that a spoofed name is ignored.

import {
  assert,
  assertEquals,
} from "https://deno.land/std@0.224.0/assert/mod.ts";
import type { TenantQueryClient } from "../../tenant_db.ts";
import {
  type ExamRemarkRow,
  upsertExamRemark,
} from "./exam_administration_repository.ts";

const ORG = "a1000000-0000-4000-8000-000000000001";
const SCHOOL = "a2000000-0000-4000-8000-000000000001";
const AUTHOR = "d1000000-0000-4000-8000-000000000001";

/**
 * Answers the two queries upsertExamRemark issues:
 *  - `SELECT display_name FROM users WHERE id = $1` → the seeded user rows.
 *  - `INSERT INTO exam_remarks ... RETURNING *` → echoes back the bound args so
 *    the test can inspect exactly what the repository chose to persist.
 */
class MockRemarkDb {
  public lastInsertArgs: unknown[] | null = null;

  constructor(private readonly userRows: { display_name: string | null }[]) {}

  queryObject<T>(sql: string, args: unknown[] = []): Promise<T[]> {
    if (sql.includes("SELECT display_name FROM users")) {
      return Promise.resolve(this.userRows as unknown as T[]);
    }
    if (sql.includes("INSERT INTO exam_remarks")) {
      this.lastInsertArgs = args;
      const [
        id,
        organization_id,
        school_id,
        exam_id,
        student_id,
        text,
        author_id,
        author_name,
        author_role,
        revision,
      ] = args as string[];
      const row: ExamRemarkRow = {
        id,
        organization_id,
        school_id,
        exam_id,
        student_id,
        text,
        author_id,
        author_name,
        author_role,
        history: [JSON.parse(revision)],
        created_at: "2026-06-12T00:00:00.000Z",
        updated_at: "2026-06-12T00:00:00.000Z",
      };
      return Promise.resolve([row] as unknown as T[]);
    }
    return Promise.resolve([] as T[]);
  }

  queryCount(): Promise<number> {
    return Promise.resolve(0);
  }
}

function db(userRows: { display_name: string | null }[]): {
  client: TenantQueryClient;
  mock: MockRemarkDb;
} {
  const mock = new MockRemarkDb(userRows);
  return { client: mock as unknown as TenantQueryClient, mock };
}

Deno.test("PRA-P0-10 — persisted author_name comes from users.display_name, spoof ignored", async () => {
  const { client, mock } = db([{ display_name: "Real Teacher Name" }]);

  const row = await upsertExamRemark(client, ORG, SCHOOL, {
    examId: "exam_1",
    studentId: "s1000000-0000-4000-8000-000000000001",
    text: "Strong performance in algebra.",
    authorId: AUTHOR,
    // A caller trying to spoof the display name — must be IGNORED. Cast through
    // `unknown` because `authorName` is (deliberately) no longer part of the
    // input type; this simulates a stale/hostile caller still supplying it.
    ...({ authorName: "SPOOFED — Principal Sir" } as unknown as {}),
  });

  // Column reflects the trusted user record, not the spoofed body value.
  assertEquals(row.author_name, "Real Teacher Name");
  // The append-only history revision also carries the trusted name.
  const history = row.history as Array<{ authorName: string }>;
  assertEquals(history[0].authorName, "Real Teacher Name");
  // The value actually bound to the INSERT (arg index 7) is the trusted name.
  assertEquals(mock.lastInsertArgs?.[7], "Real Teacher Name");
  // And the spoofed string never appears anywhere in the persisted args.
  assert(
    !JSON.stringify(mock.lastInsertArgs).includes("SPOOFED"),
    "spoofed author name must not reach the database",
  );
});

Deno.test("PRA-P0-10 — empty display_name falls back to the author id", async () => {
  const { client } = db([{ display_name: "   " }]);

  const row = await upsertExamRemark(client, ORG, SCHOOL, {
    examId: "exam_1",
    studentId: "s1000000-0000-4000-8000-000000000001",
    text: "Needs revision.",
    authorId: AUTHOR,
  });

  assertEquals(row.author_name, AUTHOR);
});

Deno.test("PRA-P0-10 — missing user row falls back to the author id", async () => {
  const { client } = db([]); // no matching users row

  const row = await upsertExamRemark(client, ORG, SCHOOL, {
    examId: "exam_1",
    studentId: "s1000000-0000-4000-8000-000000000001",
    text: "Absent for the test.",
    authorId: AUTHOR,
  });

  assertEquals(row.author_name, AUTHOR);
});
